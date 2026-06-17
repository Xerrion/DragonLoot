-------------------------------------------------------------------------------
-- HistoryFrame.lua
-- Loot history display with scrollable list of recent loot events
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...

-------------------------------------------------------------------------------
-- Cached WoW API
-------------------------------------------------------------------------------

local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local UIParent = UIParent
local GetTime = GetTime
local time = time
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local HandleModifiedItemClick = HandleModifiedItemClick
local IsShiftKeyDown = IsShiftKeyDown
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth
local UIDropDownMenu_SetText = UIDropDownMenu_SetText
local EJ_GetEncounterInfo = EJ_GetEncounterInfo
local math_floor = math.floor
local math_abs = math.abs
local string_format = string.format
local string_lower = string.lower
local string_match = string.match
local string_find = string.find
local table_sort = table.sort
local tostring = tostring

local L = ns.L
local DU = ns.DisplayUtils

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local FRAME_WIDTH = 350
local FRAME_HEIGHT = 400
local TITLE_BAR_HEIGHT = 24
local FILTER_BAR_HEIGHT = 26
local SCROLL_STEP = 3
local SCROLLBAR_WIDTH = 14
local SCROLLBAR_GAP = 2
local DEFAULT_HISTORY_X_OFFSET = 200
local SCROLLBAR_THUMB_HEIGHT = 30
local TIME_REFRESH_INTERVAL = 10
local DETAIL_ROW_HEIGHT = 16
local DETAIL_PADDING = 4

local function GetHistoryDB()
    return ns.Addon.db and ns.Addon.db.profile and ns.Addon.db.profile.history
end

local function GetEntrySpacing()
    local historyDB = GetHistoryDB()
    return historyDB and historyDB.entrySpacing or 2
end

local function GetContentPadding()
    local historyDB = GetHistoryDB()
    return historyDB and historyDB.contentPadding or 6
end

-------------------------------------------------------------------------------
-- Frame references
-------------------------------------------------------------------------------

local containerFrame
local scrollFrame
local scrollChild
local scrollBar

-------------------------------------------------------------------------------
-- Entry frame pool
-------------------------------------------------------------------------------

local entryPool = {}
local entryCount = 0
local activeEntries = {}
local expandedEntries = {}
local detailRowPool = {}

-------------------------------------------------------------------------------
-- History data (populated by listeners)
-------------------------------------------------------------------------------

ns.historyData = {}

-------------------------------------------------------------------------------
-- Filter state (Phase 3: widgets only; Phase 4 will read this in the filter
-- pipeline; Phase 6 will sync with db.profile.history.filter)
-------------------------------------------------------------------------------

-- Sentinel for filterState.encounterID meaning "only entries with nil
-- encounterID" (i.e. loot recorded outside a tracked encounter). Any non-nil
-- value that can't collide with a real encounterID works; -1 is conventional
-- and reads clearly at callsites. Immutable after this assignment.
local UNKNOWN_ENCOUNTER = -1

-- [encounterID] = resolved display name. Populated lazily on Retail via
-- EJ_GetEncounterInfo when the dropdown is opened; Classic entries carry
-- entry.encounterName captured at ENCOUNTER_START and bypass this cache.
local encounterNameCache = {}

local filterState = {
    encounterID = nil, -- nil means "All Encounters"
    search = "",
}

-- Pure: depends only on its two arguments, cached Lua stdlib, and the
-- module-immutable UNKNOWN_ENCOUNTER upvalue (a constant, so the function
-- remains a function of its inputs). Returns true if `entry` should be
-- visible under `state`. See spec/HistoryFilter_spec.lua.
local function MatchesFilter(entry, state)
    if not entry or not state then
        return true
    end

    if state.encounterID == UNKNOWN_ENCOUNTER then
        if entry.encounterID ~= nil then
            return false
        end
    elseif state.encounterID ~= nil and entry.encounterID ~= state.encounterID then
        return false
    end

    local search = state.search
    if not search or search == "" then
        return true
    end

    local needle = string_lower(search)

    local itemLink = entry.itemLink
    if itemLink then
        local itemName = string_match(itemLink, "%[(.-)%]")
        if itemName and string_find(string_lower(itemName), needle, 1, true) then
            return true
        end
    end

    local winner = entry.winner
    if winner and winner ~= "" then
        if string_find(string_lower(winner), needle, 1, true) then
            return true
        end
    end

    return false
end

local function GetVisibleEntries()
    local out = {}
    for i = 1, #ns.historyData do
        local e = ns.historyData[i]
        if MatchesFilter(e, filterState) then
            out[#out + 1] = e
        end
    end
    return out
end

-- Mirror the in-memory filterState into db.profile.history.filter so the
-- selection survives /reload and session boundaries. Called AFTER every
-- mutation and BEFORE Refresh, so a Refresh failure cannot leave the
-- persisted state stale relative to filterState.
local function PersistFilter()
    local db = ns.Addon and ns.Addon.db
    if not db or not db.profile or not db.profile.history or not db.profile.history.filter then
        return
    end
    local persisted = db.profile.history.filter
    persisted.encounterID = filterState.encounterID
    persisted.search = filterState.search
end

-- Pull persisted filter selection back into filterState. Silent on missing
-- db so it is safe to call from early init paths.
local function RestoreFilter()
    local db = ns.Addon and ns.Addon.db
    if not db or not db.profile or not db.profile.history or not db.profile.history.filter then
        return
    end
    local persisted = db.profile.history.filter

    local persistedEncounterID = persisted.encounterID
    if persistedEncounterID ~= nil and type(persistedEncounterID) ~= "number" then
        persistedEncounterID = nil
    end
    filterState.encounterID = persistedEncounterID

    local persistedSearch = persisted.search
    if type(persistedSearch) ~= "string" then
        persistedSearch = ""
    end
    filterState.search = persistedSearch
end

-- Expose pure filter for unit tests; not part of the public API.
ns.HistoryFrame._MatchesFilter = MatchesFilter
ns.HistoryFrame._UNKNOWN_ENCOUNTER = UNKNOWN_ENCOUNTER
ns.HistoryFrame._PersistFilter = PersistFilter
ns.HistoryFrame._RestoreFilter = RestoreFilter

local function ShouldShowFilterBar()
    local db = ns.Addon and ns.Addon.db and ns.Addon.db.profile
    if not db or not db.history or not db.history.filter then
        return true
    end
    return db.history.filter.barVisible ~= false
end

local function GetTopBarOffset()
    return TITLE_BAR_HEIGHT + (ShouldShowFilterBar() and FILTER_BAR_HEIGHT or 0)
end

-- Forward declaration for RefreshHistory (used by OnEntryClick)
local RefreshHistory

-------------------------------------------------------------------------------
-- Persistence helpers (db.char.history.entries)
-------------------------------------------------------------------------------

local function BuildDedupKey(entry)
    if not entry then
        return nil
    end
    local bucket = entry.wallTime and math_floor(entry.wallTime / 86400) or 0
    if entry.dropKey then
        return entry.dropKey .. "|" .. bucket
    end
    local link = entry.itemLink or "?"
    local winner = entry.winner or "?"
    return link .. "|" .. winner .. "|" .. bucket
end

ns.HistoryFrame_BuildDedupKey = BuildDedupKey

local function PersistEntries()
    local db = ns.Addon and ns.Addon.db
    if not db or not db.char or not db.char.history then
        return
    end
    local store = db.char.history.entries
    if type(store) ~= "table" then
        store = {}
        db.char.history.entries = store
    end
    wipe(store)
    for i, entry in ipairs(ns.historyData) do
        store[i] = entry
    end
end

local function LoadPersistedEntries()
    local db = ns.Addon and ns.Addon.db
    if not db or not db.char or not db.char.history then
        return
    end
    local stored = db.char.history.entries
    if type(stored) ~= "table" or #stored == 0 then
        return
    end

    local maxEntries = (db.profile and db.profile.history and db.profile.history.maxEntries) or 100
    local limit = #stored
    if limit > maxEntries then
        limit = maxEntries
    end

    wipe(ns.historyData)
    for i = 1, limit do
        ns.historyData[i] = stored[i]
    end

    if db.profile and db.profile.debug then
        ns.DebugPrint("HistoryFrame loaded " .. #ns.historyData .. " persisted entries")
    end
end

-------------------------------------------------------------------------------
-- Backdrop and font wrappers (delegate to DisplayUtils)
-------------------------------------------------------------------------------

local function GetFont()
    return DU.GetFont(ns.Addon.db)
end

local function ApplyBackdrop(frame)
    DU.ApplyBackdrop(frame, ns.Addon.db)
end

local function GetHistoryIconSize()
    return ns.Addon.db.profile.appearance.historyIconSize or 24
end

local function GetEntryHeight()
    local historyDB = GetHistoryDB()
    local padding = historyDB and historyDB.rowHeightPadding or 6
    return GetHistoryIconSize() + padding
end

local function AlignEntryHeader(entry)
    local entryHeight = GetEntryHeight()
    local iconSize = GetHistoryIconSize()
    local iconOffset = (entryHeight - iconSize) / 2
    entry.icon:ClearAllPoints()
    entry.icon:SetPoint("TOPLEFT", entry, "TOPLEFT", 2, -iconOffset)
end

local function ApplyLayoutOffsets(frame)
    local borderSize = ns.Addon.db.profile.appearance.borderSize or 1
    local padding = GetContentPadding()

    -- Title bar spans across the top, inset by border
    local titleBar = frame.titleBar
    titleBar:ClearAllPoints()
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", borderSize, -borderSize)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -borderSize, -borderSize)

    -- Scroll frame and scrollbar insets
    local topBarOffset = GetTopBarOffset()
    if scrollFrame then
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", padding + borderSize, -(topBarOffset + padding + borderSize))
        scrollFrame:SetPoint(
            "BOTTOMRIGHT",
            frame,
            "BOTTOMRIGHT",
            -(padding + SCROLLBAR_WIDTH + SCROLLBAR_GAP + borderSize),
            padding + borderSize
        )
    end
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint(
            "TOPRIGHT",
            frame,
            "TOPRIGHT",
            -(padding + borderSize),
            -(topBarOffset + padding + borderSize)
        )
        scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(padding + borderSize), padding + borderSize)
    end
end

-------------------------------------------------------------------------------
-- Class color helper
-------------------------------------------------------------------------------

local function GetClassColor(class)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local cc = RAID_CLASS_COLORS[class]
        return cc.r, cc.g, cc.b
    end
    return 0.7, 0.7, 0.7
end

-------------------------------------------------------------------------------
-- Roll type text helper
-------------------------------------------------------------------------------

local function GetRollTypeText(rollType)
    return ns.RollTypeNames[rollType] or ""
end

-------------------------------------------------------------------------------
-- Time formatting helper
-------------------------------------------------------------------------------

local function FormatTimeAgo(entry)
    if not entry then
        return ""
    end

    local sessionElapsed
    if entry.timestamp then
        sessionElapsed = GetTime() - entry.timestamp
        if sessionElapsed < 0 then
            sessionElapsed = nil
        end
    end

    local wallElapsed
    if entry.wallTime then
        wallElapsed = time() - entry.wallTime
        if wallElapsed < 0 then
            wallElapsed = nil
        end
    end

    local elapsed
    if wallElapsed and sessionElapsed and math_abs(wallElapsed - sessionElapsed) > 300 then
        -- Disagreement larger than 5 minutes: persisted entry from prior session. Trust wall clock.
        elapsed = wallElapsed
    else
        elapsed = sessionElapsed or wallElapsed or 0
    end

    if elapsed < 60 then
        return string_format(L["%ds ago"], math_floor(elapsed))
    elseif elapsed < 3600 then
        return string_format(L["%dm ago"], math_floor(elapsed / 60))
    else
        return string_format(L["%dh ago"], math_floor(elapsed / 3600))
    end
end

-------------------------------------------------------------------------------
-- Entry frame creation
-------------------------------------------------------------------------------

local function CreateEntryFrame()
    entryCount = entryCount + 1
    local frameName = "DragonLootHistoryEntry" .. entryCount

    local entry = CreateFrame("Button", frameName, scrollChild)
    local entryHeight = GetEntryHeight()
    entry:SetHeight(entryHeight)
    entry:EnableMouse(true)
    entry:RegisterForClicks("LeftButtonUp")

    -- Icon
    entry.icon = entry:CreateTexture(nil, "ARTWORK")
    local iconSize = GetHistoryIconSize()
    entry.icon:SetSize(iconSize, iconSize)
    AlignEntryHeader(entry)
    entry.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Icon border
    entry.iconBorder = entry:CreateTexture(nil, "OVERLAY")
    entry.iconBorder:SetPoint("TOPLEFT", entry.icon, "TOPLEFT", -1, 1)
    entry.iconBorder:SetPoint("BOTTOMRIGHT", entry.icon, "BOTTOMRIGHT", 1, -1)
    entry.iconBorder:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    entry.icon:SetDrawLayer("OVERLAY", 1)

    -- Item name (anchored to row top so rowHeightPadding pushes it away from winnerName)
    entry.itemName = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.itemName:SetPoint("LEFT", entry.icon, "RIGHT", 4, 0)
    entry.itemName:SetPoint("TOP", entry, "TOP", 0, -2)
    entry.itemName:SetPoint("RIGHT", entry, "RIGHT", -60, 0)
    entry.itemName:SetJustifyH("LEFT")
    entry.itemName:SetJustifyV("TOP")
    entry.itemName:SetWordWrap(false)

    -- Winner name (anchored to row bottom so rowHeightPadding pushes it away from itemName)
    entry.winnerName = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.winnerName:SetPoint("LEFT", entry.icon, "RIGHT", 4, 0)
    entry.winnerName:SetPoint("BOTTOM", entry, "BOTTOM", 0, 2)
    entry.winnerName:SetJustifyH("LEFT")
    entry.winnerName:SetJustifyV("BOTTOM")
    entry.winnerName:SetWordWrap(false)

    -- Pending highest roller (occupies the same slot as winnerName, never both visible)
    entry.pendingText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.pendingText:SetPoint("LEFT", entry.icon, "RIGHT", 4, 0)
    entry.pendingText:SetPoint("BOTTOM", entry, "BOTTOM", 0, 2)
    entry.pendingText:SetJustifyH("LEFT")
    entry.pendingText:SetJustifyV("BOTTOM")
    entry.pendingText:SetWordWrap(false)
    entry.pendingText:Hide()

    -- Roll info (e.g. "Need 87")
    entry.rollInfo = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.rollInfo:SetPoint("LEFT", entry.winnerName, "RIGHT", 6, 0)
    entry.rollInfo:SetJustifyH("LEFT")
    entry.rollInfo:SetTextColor(0.8, 0.8, 0.8)

    -- Time text
    entry.timeText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.timeText:SetPoint("RIGHT", entry, "RIGHT", -4, 0)
    entry.timeText:SetJustifyH("RIGHT")
    entry.timeText:SetTextColor(0.5, 0.5, 0.5)

    -- Highlight
    entry.highlight = entry:CreateTexture(nil, "HIGHLIGHT")
    entry.highlight:SetAllPoints()
    entry.highlight:SetColorTexture(1, 1, 1, 0.05)

    -- Detail container for expanded roll results
    entry.detailContainer = CreateFrame("Frame", nil, entry)
    entry.detailContainer:SetPoint("TOPLEFT", entry, "TOPLEFT", 2, -GetEntryHeight())
    entry.detailContainer:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
    entry.detailContainer:Hide()

    -- Expand indicator
    entry.expandIndicator = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.expandIndicator:SetPoint("BOTTOMRIGHT", entry.icon, "BOTTOMRIGHT", -1, 1)
    entry.expandIndicator:SetTextColor(1, 0.82, 0)
    entry.expandIndicator:Hide()

    entry.detailRows = {}

    return entry
end

-------------------------------------------------------------------------------
-- Detail row creation and pool management
-------------------------------------------------------------------------------

local function CreateDetailRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(DETAIL_ROW_HEIGHT)

    local fontPath, fontSize, fontOutline = GetFont()

    row.playerName = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.playerName:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.playerName:SetFont(fontPath, fontSize - 2, fontOutline)
    row.playerName:SetJustifyH("LEFT")

    row.rollType = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rollType:SetPoint("CENTER", row, "CENTER", 0, 0)
    row.rollType:SetFont(fontPath, fontSize - 2, fontOutline)
    row.rollType:SetJustifyH("CENTER")
    row.rollType:SetTextColor(0.8, 0.8, 0.8)

    row.rollValue = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rollValue:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.rollValue:SetFont(fontPath, fontSize - 2, fontOutline)
    row.rollValue:SetJustifyH("RIGHT")
    row.rollValue:SetTextColor(0.9, 0.9, 0.9)

    return row
end

local function AcquireDetailRow(parent)
    local row = table.remove(detailRowPool)
    if not row then
        row = CreateDetailRow(parent)
    else
        row:SetParent(parent)
    end
    row:Show()
    return row
end

local function ReleaseDetailRow(row)
    row:Hide()
    row:ClearAllPoints()
    row.playerName:SetText("")
    row.rollType:SetText("")
    row.rollValue:SetText("")
    table.insert(detailRowPool, row)
end

local function ReleaseEntryDetails(entry)
    if entry.detailRows then
        for i = #entry.detailRows, 1, -1 do
            ReleaseDetailRow(entry.detailRows[i])
            entry.detailRows[i] = nil
        end
    end
    if entry.detailContainer then
        entry.detailContainer:Hide()
    end
end

local function GetEntryKey(data)
    if data.dropKey then
        return data.dropKey
    end
    return (data.timestamp or 0) .. "|" .. (data.itemLink or "") .. "|" .. (data.winner or "")
end

-------------------------------------------------------------------------------
-- Entry pool management
-------------------------------------------------------------------------------

local function AcquireEntry()
    local entry = table.remove(entryPool)
    if not entry then
        entry = CreateEntryFrame()
    end
    entry._isPooled = false
    return entry
end

local function ReleaseEntry(entry)
    if entry._isPooled then
        return
    end
    entry._isPooled = true
    ReleaseEntryDetails(entry)
    entry:Hide()
    entry:ClearAllPoints()
    entry.itemLink = nil
    entry.quality = nil
    entry.timestamp = nil
    entry.wallTime = nil
    entry._entryKey = nil
    entry._rollResults = nil
    entry.icon:SetTexture(nil)
    entry.itemName:SetText("")
    entry.winnerName:SetText("")
    entry.pendingText:SetText("")
    entry.pendingText:Hide()
    entry.rollInfo:SetText("")
    entry.timeText:SetText("")
    if entry.expandIndicator then
        entry.expandIndicator:Hide()
    end
    entry:SetScript("OnClick", nil)
    entry:SetScript("OnEnter", nil)
    entry:SetScript("OnLeave", nil)
    table.insert(entryPool, entry)
end

local function ReleaseAllEntries()
    for i = #activeEntries, 1, -1 do
        ReleaseEntry(activeEntries[i])
        activeEntries[i] = nil
    end
end

-------------------------------------------------------------------------------
-- Entry interaction handlers (shared across all entries to avoid closures)
-------------------------------------------------------------------------------

local function OnEntryEnter(self)
    if not self.itemLink then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(self.itemLink)

    local rollResults = self._rollResults
    if rollResults and #rollResults > 0 then
        -- Build a sorted copy: highest non-pass roll first, then passes at the bottom.
        local sorted = {}
        for i = 1, #rollResults do
            sorted[i] = rollResults[i]
        end
        table_sort(sorted, function(a, b)
            local aPass = (a.rollType == 0) or not a.roll
            local bPass = (b.rollType == 0) or not b.roll
            if aPass ~= bPass then
                return not aPass -- non-pass first
            end
            return (a.roll or 0) > (b.roll or 0)
        end)

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Rolls:"], 1, 0.82, 0)

        for i = 1, #sorted do
            local result = sorted[i]
            local cr, cg, cb = GetClassColor(result.playerClass)
            local typeName = ns.RollTypeNames and ns.RollTypeNames[result.rollType] or L["Unknown"]
            local rightText
            if result.rollType == 0 or not result.roll then
                rightText = typeName
            else
                rightText = string_format("%d (%s)", result.roll, typeName)
            end
            GameTooltip:AddDoubleLine(result.playerName or "?", rightText, cr, cg, cb, 1, 1, 1)
        end
    end

    GameTooltip:Show()
end

local function OnEntryLeave()
    GameTooltip:Hide()
end

local function OnEntryClick(self, _button)
    if not self.itemLink then
        return
    end

    local db = ns.Addon.db.profile
    local canExpand = db.history.showRollDetails and self._rollResults and #self._rollResults > 0

    -- Shift-click always inserts item link
    if IsShiftKeyDown() then
        HandleModifiedItemClick(self.itemLink)
        return
    end

    -- Toggle expand/collapse if roll details are available
    if canExpand then
        local key = self._entryKey
        if expandedEntries[key] then
            expandedEntries[key] = nil
        else
            expandedEntries[key] = true
        end
        RefreshHistory()
        return
    end

    -- Default: insert item link
    HandleModifiedItemClick(self.itemLink)
end

-------------------------------------------------------------------------------
-- Populate detail rows for an expanded entry
-------------------------------------------------------------------------------

local function PopulateEntryDetails(entry, rollResults)
    ReleaseEntryDetails(entry)

    if not rollResults or #rollResults == 0 then
        entry.detailContainer:Hide()
        return
    end

    local fontPath, fontSize, fontOutline = GetFont()
    entry.detailRows = {}

    -- Re-anchor detail container to account for icon size config changes since frame creation
    entry.detailContainer:ClearAllPoints()
    entry.detailContainer:SetPoint("TOPLEFT", entry, "TOPLEFT", 2, -GetEntryHeight())
    entry.detailContainer:SetPoint("RIGHT", entry, "RIGHT", 0, 0)

    for idx, result in ipairs(rollResults) do
        local row = AcquireDetailRow(entry.detailContainer)
        row:SetPoint("TOPLEFT", entry.detailContainer, "TOPLEFT", 0, -((idx - 1) * DETAIL_ROW_HEIGHT))
        row:SetPoint("RIGHT", entry.detailContainer, "RIGHT", 0, 0)

        -- Font
        row.playerName:SetFont(fontPath, fontSize - 2, fontOutline)
        DU.ApplyFontShadow(row.playerName, ns.Addon.db)
        row.rollType:SetFont(fontPath, fontSize - 2, fontOutline)
        DU.ApplyFontShadow(row.rollType, ns.Addon.db)
        row.rollValue:SetFont(fontPath, fontSize - 2, fontOutline)
        DU.ApplyFontShadow(row.rollValue, ns.Addon.db)

        -- Player name (class colored)
        local cr, cg, cb = GetClassColor(result.playerClass)
        row.playerName:SetText(result.playerName or "")
        row.playerName:SetTextColor(cr, cg, cb)

        -- Roll type
        row.rollType:SetText(GetRollTypeText(result.rollType))

        -- Roll value
        row.rollValue:SetText(result.roll and tostring(result.roll) or "-")

        entry.detailRows[idx] = row
    end

    local containerHeight = #rollResults * DETAIL_ROW_HEIGHT + DETAIL_PADDING
    entry.detailContainer:SetHeight(containerHeight)
    entry.detailContainer:Show()
end

-------------------------------------------------------------------------------
-- Populate an entry frame with history data
-------------------------------------------------------------------------------

local function PopulateEntry(entry, data)
    if not entry or not data then
        return
    end

    local iconSize = GetHistoryIconSize()
    entry.icon:SetSize(iconSize, iconSize)
    AlignEntryHeader(entry)

    entry.itemLink = data.itemLink
    entry.timestamp = data.timestamp
    entry.wallTime = data.wallTime
    entry.quality = data.quality

    -- Icon
    entry.icon:SetTexture(data.itemTexture)

    -- Quality border
    local qr, qg, qb = DU.GetQualityColor(data.quality)
    if ns.Addon.db.profile.appearance.qualityBorder then
        entry.iconBorder:SetColorTexture(qr, qg, qb, 0.8)
        entry.iconBorder:Show()
    else
        entry.iconBorder:Hide()
    end

    -- Item name (quality colored)
    local fontPath, fontSize, fontOutline = GetFont()
    entry.itemName:SetFont(fontPath, fontSize - 1, fontOutline)
    DU.ApplyFontShadow(entry.itemName, ns.Addon.db)
    if data.itemLink then
        -- Extract name from link for display, fallback to link itself
        local name = data.itemLink:match("%[(.-)%]") or data.itemLink
        entry.itemName:SetText(name)
    else
        entry.itemName:SetText(L["Unknown Item"])
    end
    entry.itemName:SetTextColor(qr, qg, qb)

    -- Winner name (class colored) OR pending highest roller
    entry.winnerName:SetFont(fontPath, fontSize - 2, fontOutline)
    DU.ApplyFontShadow(entry.winnerName, ns.Addon.db)
    entry.pendingText:SetFont(fontPath, fontSize - 2, fontOutline)
    DU.ApplyFontShadow(entry.pendingText, ns.Addon.db)

    if data.winner then
        -- Resolved: show class-colored winner, hide pending text
        local cr, cg, cb = GetClassColor(data.winnerClass)
        entry.winnerName:SetText(data.winner)
        entry.winnerName:SetTextColor(cr, cg, cb)
        entry.winnerName:Show()
        entry.pendingText:Hide()
    else
        -- In progress or no winner: show pending leader (if any rolls), hide winnerName
        entry.winnerName:SetText("")
        entry.winnerName:Hide()

        local leaderName, leaderClass, leaderRoll = nil, nil, nil
        if data.rollResults then
            for _, result in ipairs(data.rollResults) do
                -- Skip Pass (rollType 0); look for highest non-pass roll
                if result.rollType and result.rollType ~= 0 and result.roll then
                    if not leaderRoll or result.roll > leaderRoll then
                        leaderName = result.playerName
                        leaderClass = result.playerClass
                        leaderRoll = result.roll
                    end
                end
            end
        end

        if leaderName and leaderRoll then
            local cr, cg, cb = GetClassColor(leaderClass)
            entry.pendingText:SetText(string_format(L["Highest: %s (%d)"], leaderName, leaderRoll))
            entry.pendingText:SetTextColor(cr, cg, cb)
            entry.pendingText:Show()
        elseif data.rollResults and #data.rollResults > 0 then
            -- All passes - rare but possible
            entry.pendingText:SetText(L["(waiting on rolls)"])
            entry.pendingText:SetTextColor(0.6, 0.6, 0.6)
            entry.pendingText:Show()
        else
            -- No roll data yet (very early in event flow, or direct loot)
            entry.pendingText:Hide()
        end
    end

    -- Roll info
    entry.rollInfo:SetFont(fontPath, fontSize - 2, fontOutline)
    DU.ApplyFontShadow(entry.rollInfo, ns.Addon.db)
    if data.isDirectLoot then
        entry.rollInfo:SetText(L["Looted"])
        entry.rollInfo:SetTextColor(0.6, 0.6, 0.6)
    else
        local rollText = GetRollTypeText(data.rollType)
        if data.roll then
            rollText = rollText .. " " .. data.roll
        end
        entry.rollInfo:SetText(rollText)
        entry.rollInfo:SetTextColor(0.8, 0.8, 0.8)
    end

    -- Time
    entry.timeText:SetFont(fontPath, fontSize - 2, fontOutline)
    DU.ApplyFontShadow(entry.timeText, ns.Addon.db)
    entry.timeText:SetText(FormatTimeAgo(data))

    -- Roll details expand/collapse
    local db = ns.Addon.db.profile
    local entryKey = GetEntryKey(data)
    entry._entryKey = entryKey
    entry._rollResults = data.rollResults

    if db.history.showRollDetails and data.rollResults and #data.rollResults > 0 then
        local fontPath2, fontSize2, fontOutline2 = GetFont()
        entry.expandIndicator:SetFont(fontPath2, fontSize2 - 3, fontOutline2)
        DU.ApplyFontShadow(entry.expandIndicator, ns.Addon.db)
        if expandedEntries[entryKey] then
            entry.expandIndicator:SetText("-")
            entry.expandIndicator:Show()
            PopulateEntryDetails(entry, data.rollResults)
        else
            entry.expandIndicator:SetText("+")
            entry.expandIndicator:Show()
            ReleaseEntryDetails(entry)
        end
    else
        entry.expandIndicator:Hide()
        ReleaseEntryDetails(entry)
    end

    -- Interaction scripts (named functions, no per-entry closures)
    entry:SetScript("OnEnter", OnEntryEnter)
    entry:SetScript("OnLeave", OnEntryLeave)
    entry:SetScript("OnClick", OnEntryClick)

    entry:Show()
end

-------------------------------------------------------------------------------
-- Scroll bar update helper
-------------------------------------------------------------------------------

local function UpdateScrollBar()
    if not scrollBar or not scrollFrame then
        return
    end
    local contentHeight = scrollChild:GetHeight()
    local visibleHeight = scrollFrame:GetHeight()
    local maxScroll = contentHeight - visibleHeight
    if maxScroll < 0 then
        maxScroll = 0
    end

    scrollBar:SetMinMaxValues(0, maxScroll)
    if maxScroll == 0 then
        scrollBar:Hide()
    else
        scrollBar:Show()
    end
end

-------------------------------------------------------------------------------
-- Refresh history display
-------------------------------------------------------------------------------

RefreshHistory = function()
    if not containerFrame or not containerFrame:IsShown() then
        return
    end

    ReleaseAllEntries()

    local db = ns.Addon.db.profile
    local entryHeight = GetEntryHeight()
    local entrySpacing = GetEntrySpacing()
    local visible = GetVisibleEntries()
    local yOffset = 0
    for i, data in ipairs(visible) do
        local entry = AcquireEntry()
        PopulateEntry(entry, data)
        entry:ClearAllPoints()
        entry:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        entry:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
        activeEntries[i] = entry

        -- Variable height: base + expanded detail rows
        local thisHeight = entryHeight
        local entryKey = GetEntryKey(data)
        if db.history.showRollDetails and expandedEntries[entryKey] and data.rollResults and #data.rollResults > 0 then
            thisHeight = entryHeight + (#data.rollResults * DETAIL_ROW_HEIGHT) + DETAIL_PADDING
        end
        entry:SetHeight(thisHeight)
        yOffset = yOffset + thisHeight + entrySpacing
    end

    -- Resize scroll child to fit all entries (use accumulated yOffset)
    local totalHeight = yOffset
    if totalHeight < 1 then
        totalHeight = 1
    end
    scrollChild:SetHeight(totalHeight)

    if containerFrame.filterBar and containerFrame.filterBar.countText then
        containerFrame.filterBar.countText:SetText(string_format("%d/%d", #visible, #ns.historyData))
    end

    UpdateScrollBar()
end

-------------------------------------------------------------------------------
-- Position persistence
-------------------------------------------------------------------------------

local function SaveFramePosition()
    if not containerFrame then
        return
    end
    local db = ns.Addon.db.profile
    if not db.history then
        return
    end
    local point, _, relativePoint, x, y = containerFrame:GetPoint()
    if point then
        db.history.point = point
        db.history.relativePoint = relativePoint
        db.history.x = x
        db.history.y = y
    end
end

local function RestoreFramePosition()
    if not containerFrame then
        return
    end
    local db = ns.Addon.db.profile
    if not db.history then
        return
    end
    containerFrame:ClearAllPoints()
    if db.history.point then
        containerFrame:SetPoint(
            db.history.point,
            UIParent,
            db.history.relativePoint,
            db.history.x or 0,
            db.history.y or 0
        )
    else
        containerFrame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_HISTORY_X_OFFSET, 0)
    end
end

-------------------------------------------------------------------------------
-- Title bar creation
-------------------------------------------------------------------------------

local function CreateTitleBar(parent)
    local titleBar = CreateFrame("Frame", nil, parent)
    titleBar:SetHeight(TITLE_BAR_HEIGHT)
    titleBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

    local fontPath, fontSize, fontOutline = GetFont()
    titleBar.text = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleBar.text:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    titleBar.text:SetFont(fontPath, fontSize, fontOutline)
    DU.ApplyFontShadow(titleBar.text, ns.Addon.db)
    titleBar.text:SetText(L["DragonLoot - Loot History"])
    titleBar.text:SetTextColor(1, 0.82, 0)

    -- Close button
    local ok, closeBtn = pcall(CreateFrame, "Button", nil, titleBar, "UIPanelCloseButtonNoScripts")
    if not ok or not closeBtn then
        closeBtn = CreateFrame("Button", nil, titleBar)
        closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
        closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    end
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        ns.HistoryFrame.Hide()
    end)

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, titleBar)
    clearBtn:SetSize(16, 16)
    clearBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    clearBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    clearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    clearBtn:SetScript("OnClick", function()
        ns.HistoryFrame.ClearHistory()
    end)
    clearBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Clear History"])
        GameTooltip:Show()
    end)
    clearBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return titleBar
end

-------------------------------------------------------------------------------
-- Filter bar creation (encounter dropdown + search box)
-------------------------------------------------------------------------------

-- Resolve a display name for an encounterID. Priority:
--   1. nil ID -> localized "Unknown encounter".
--   2. entry.encounterName captured at ENCOUNTER_START (Classic listener).
--   3. Cached lookup from a previous EJ_GetEncounterInfo call.
--   4. EJ_GetEncounterInfo when available (Retail; may be absent on Classic).
--   5. tostring(id) fallback so the user can always filter.
local function ResolveEncounterName(encounterID, entry)
    if encounterID == nil then
        return L["Unknown encounter"]
    end
    if entry and entry.encounterName and entry.encounterName ~= "" then
        return entry.encounterName
    end
    local cached = encounterNameCache[encounterID]
    if cached then
        return cached
    end
    if EJ_GetEncounterInfo then
        local name = EJ_GetEncounterInfo(encounterID)
        if name and name ~= "" then
            encounterNameCache[encounterID] = name
            return name
        end
    end
    local fallback = tostring(encounterID)
    encounterNameCache[encounterID] = fallback
    return fallback
end

-- Fires on every dropdown open, so the option list always reflects current
-- ns.historyData -- no manual invalidation needed when entries arrive while
-- the dropdown is closed.
local function InitEncounterDropdown(self, level, _menuList)
    if level ~= 1 then
        return
    end

    -- Walk current history once: collect distinct encounterIDs (keeping the
    -- first entry seen for each, used as the encounterName source for Classic)
    -- and remember whether any entry lacks an encounterID at all.
    local seen = {}
    local hasUnknown = false
    for i = 1, #ns.historyData do
        local e = ns.historyData[i]
        local id = e.encounterID
        if id == nil then
            hasUnknown = true
        elseif not seen[id] then
            seen[id] = e
        end
    end

    local options = {}
    for id, entry in pairs(seen) do
        options[#options + 1] = { id = id, name = ResolveEncounterName(id, entry) }
    end
    table_sort(options, function(a, b)
        if a.name == b.name then
            return a.id < b.id
        end
        return a.name < b.name
    end)

    local info = UIDropDownMenu_CreateInfo()
    info.text = L["All Encounters"]
    info.checked = (filterState.encounterID == nil)
    info.func = function()
        filterState.encounterID = nil
        PersistFilter()
        UIDropDownMenu_SetText(self, L["All Encounters"])
        ns.HistoryFrame.Refresh()
    end
    UIDropDownMenu_AddButton(info, level)

    for _, opt in ipairs(options) do
        info = UIDropDownMenu_CreateInfo()
        info.text = opt.name
        info.checked = (filterState.encounterID == opt.id)
        info.func = function()
            filterState.encounterID = opt.id
            PersistFilter()
            UIDropDownMenu_SetText(self, opt.name)
            ns.HistoryFrame.Refresh()
        end
        UIDropDownMenu_AddButton(info, level)
    end

    if hasUnknown then
        info = UIDropDownMenu_CreateInfo()
        info.text = L["Unknown encounter"]
        info.checked = (filterState.encounterID == UNKNOWN_ENCOUNTER)
        info.func = function()
            filterState.encounterID = UNKNOWN_ENCOUNTER
            PersistFilter()
            UIDropDownMenu_SetText(self, L["Unknown encounter"])
            ns.HistoryFrame.Refresh()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

local function CreateFilterBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(FILTER_BAR_HEIGHT)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -TITLE_BAR_HEIGHT)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -TITLE_BAR_HEIGHT)

    -- Encounter dropdown (legacy UIDropDownMenu API).
    -- Parented to the main container so popup anchor math works correctly.
    local encounterDropdown =
        CreateFrame("Frame", "DragonLootHistoryEncounterDropdown", parent, "UIDropDownMenuTemplate")
    encounterDropdown:SetPoint("LEFT", bar, "LEFT", 4, 0)
    encounterDropdown.displayMode = "MENU"
    UIDropDownMenu_Initialize(encounterDropdown, InitEncounterDropdown)
    UIDropDownMenu_SetWidth(encounterDropdown, 150)
    UIDropDownMenu_SetText(encounterDropdown, L["All Encounters"])

    -- Search box (SearchBoxTemplate gives clear-X + placeholder for free).
    local searchBox = CreateFrame("EditBox", nil, bar, "SearchBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("LEFT", encounterDropdown, "RIGHT", 6, 2)
    searchBox:SetAutoFocus(false)
    searchBox:HookScript("OnTextChanged", function(eb)
        filterState.search = eb:GetText() or ""
        PersistFilter()
        ns.HistoryFrame.Refresh()
    end)

    -- Visible-count placeholder (wired in Phase 4).
    local countText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
    countText:SetText("")

    bar.encounterDropdown = encounterDropdown
    bar.searchBox = searchBox
    bar.countText = countText

    if ShouldShowFilterBar() then
        bar:Show()
    else
        bar:Hide()
    end

    return bar
end

-------------------------------------------------------------------------------
-- Apply restored filterState to the live widgets at Initialize-time.
-- Module-local: only the Initialize-time restore path needs this today.
-------------------------------------------------------------------------------

local function ApplyFilterToWidgets()
    if not containerFrame or not containerFrame.filterBar then
        return
    end
    local bar = containerFrame.filterBar
    local label
    if filterState.encounterID == nil then
        label = L["All Encounters"]
    elseif filterState.encounterID == UNKNOWN_ENCOUNTER then
        label = L["Unknown encounter"]
    else
        label = ResolveEncounterName(filterState.encounterID, nil)
    end
    UIDropDownMenu_SetText(bar.encounterDropdown, label)

    -- SetText triggers SearchBoxTemplate's OnTextChanged, which our HookScript
    -- mirrors back to filterState.search. The value already matches, so the
    -- hook is a no-op; PersistFilter writes the same value it just read.
    bar.searchBox:SetText(filterState.search or "")
end

-------------------------------------------------------------------------------
-- Scroll frame creation
-------------------------------------------------------------------------------

local function OnScrollBarValueChanged(_, value)
    if scrollFrame then
        scrollFrame:SetVerticalScroll(value)
    end
end

local function CreateScrollComponents(parent)
    local padding = GetContentPadding()
    local topBarOffset = GetTopBarOffset()

    -- Scroll frame (clip region)
    local sf = CreateFrame("ScrollFrame", "DragonLootHistoryScroll", parent)
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", padding, -(topBarOffset + padding))
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(padding + SCROLLBAR_WIDTH + SCROLLBAR_GAP), padding)

    -- Scroll child
    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(sf:GetWidth() or (FRAME_WIDTH - padding * 2 - SCROLLBAR_WIDTH - SCROLLBAR_GAP))
    child:SetHeight(1)
    sf:SetScrollChild(child)

    -- Scroll bar
    local bar = CreateFrame("Slider", "DragonLootHistoryScrollBar", parent, "BackdropTemplate")
    bar:SetWidth(SCROLLBAR_WIDTH)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -padding, -(topBarOffset + padding))
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -padding, padding)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:SetValueStep(GetEntryHeight())
    bar:SetBackdrop({
        bgFile = DU.WHITE8x8,
    })
    bar:SetBackdropColor(0.1, 0.1, 0.1, 0.5)

    -- Thumb texture
    bar.thumb = bar:CreateTexture(nil, "OVERLAY")
    bar.thumb:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    bar.thumb:SetSize(SCROLLBAR_WIDTH - SCROLLBAR_GAP, SCROLLBAR_THUMB_HEIGHT)
    bar:SetThumbTexture(bar.thumb)

    bar:SetScript("OnValueChanged", OnScrollBarValueChanged)
    bar:Hide()

    -- Mouse wheel scrolling
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(_, delta)
        local current = bar:GetValue()
        local step = GetEntryHeight() * SCROLL_STEP
        bar:SetValue(current - (delta * step))
    end)

    -- Update child width when scroll frame resizes
    sf:SetScript("OnSizeChanged", function(self)
        child:SetWidth(self:GetWidth())
    end)

    return sf, child, bar
end

-------------------------------------------------------------------------------
-- Container frame creation
-------------------------------------------------------------------------------

local function CreateContainerFrame()
    local frame = CreateFrame("Frame", "DragonLootHistoryFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Backdrop
    ApplyBackdrop(frame)

    -- Title bar
    frame.titleBar = CreateTitleBar(frame)

    -- Filter bar (encounter dropdown + search)
    frame.filterBar = CreateFilterBar(frame)

    -- Dragging
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        local db = ns.Addon.db.profile
        if db.history.lock then
            return
        end
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveFramePosition()
    end)

    return frame
end

-------------------------------------------------------------------------------
-- Time refresh ticker
-------------------------------------------------------------------------------

local timeRefreshHandle

local function StartTimeRefresh()
    if timeRefreshHandle then
        return
    end
    timeRefreshHandle = ns.Addon:ScheduleRepeatingTimer(function()
        if not containerFrame or not containerFrame:IsShown() then
            return
        end
        for _, entry in ipairs(activeEntries) do
            if entry.timestamp or entry.wallTime then
                entry.timeText:SetText(FormatTimeAgo(entry))
            end
        end
    end, TIME_REFRESH_INTERVAL)
end

local function StopTimeRefresh()
    if timeRefreshHandle and ns.Addon then
        ns.Addon:CancelTimer(timeRefreshHandle)
        timeRefreshHandle = nil
    end
end

-------------------------------------------------------------------------------
-- Public Interface: ns.HistoryFrame
-------------------------------------------------------------------------------

function ns.HistoryFrame.Initialize()
    if containerFrame then
        return
    end
    containerFrame = CreateContainerFrame()
    scrollFrame, scrollChild, scrollBar = CreateScrollComponents(containerFrame)
    ApplyLayoutOffsets(containerFrame)
    ns.HistoryFrame.ApplySettings()
    RestoreFramePosition()
    LoadPersistedEntries()
    RestoreFilter()
    ApplyFilterToWidgets()
    ns.DebugPrint("HistoryFrame initialized")
end

function ns.HistoryFrame.Shutdown()
    StopTimeRefresh()
    if not containerFrame then
        return
    end
    ReleaseAllEntries()
    containerFrame:Hide()
    ns.DebugPrint("HistoryFrame shut down")
end

function ns.HistoryFrame.Show()
    if not containerFrame then
        return
    end
    local db = ns.Addon.db.profile
    if not db.history.enabled then
        return
    end
    containerFrame:Show()
    RefreshHistory()
    StartTimeRefresh()
end

function ns.HistoryFrame.Hide()
    if not containerFrame then
        return
    end
    StopTimeRefresh()
    containerFrame:Hide()
end

function ns.HistoryFrame.Toggle()
    if not containerFrame then
        return
    end
    if containerFrame:IsShown() then
        ns.HistoryFrame.Hide()
    else
        ns.HistoryFrame.Show()
    end
end

function ns.HistoryFrame.Refresh()
    RefreshHistory()
end

function ns.HistoryFrame.ApplySettings()
    if not containerFrame then
        return
    end

    -- Update backdrop
    ApplyBackdrop(containerFrame)

    -- Honor filter bar visibility toggle live
    if containerFrame.filterBar then
        containerFrame.filterBar:SetShown(ShouldShowFilterBar())
    end

    -- Update layout offsets for border thickness
    ApplyLayoutOffsets(containerFrame)

    -- Update title font
    local fontPath, fontSize, fontOutline = GetFont()
    containerFrame.titleBar.text:SetFont(fontPath, fontSize, fontOutline)
    DU.ApplyFontShadow(containerFrame.titleBar.text, ns.Addon.db)

    -- Update visible entries with current icon size and entry height
    local db = ns.Addon.db.profile
    local iconSize = GetHistoryIconSize()
    local entryHeight = GetEntryHeight()
    for _, entry in ipairs(activeEntries) do
        if entry:IsShown() then
            entry:SetHeight(entryHeight)
            entry.icon:SetSize(iconSize, iconSize)
            AlignEntryHeader(entry)
            entry.itemName:SetFont(fontPath, fontSize - 1, fontOutline)
            DU.ApplyFontShadow(entry.itemName, ns.Addon.db)
            entry.winnerName:SetFont(fontPath, fontSize - 2, fontOutline)
            DU.ApplyFontShadow(entry.winnerName, ns.Addon.db)
            entry.pendingText:SetFont(fontPath, fontSize - 2, fontOutline)
            DU.ApplyFontShadow(entry.pendingText, ns.Addon.db)
            entry.rollInfo:SetFont(fontPath, fontSize - 2, fontOutline)
            DU.ApplyFontShadow(entry.rollInfo, ns.Addon.db)
            entry.timeText:SetFont(fontPath, fontSize - 2, fontOutline)
            DU.ApplyFontShadow(entry.timeText, ns.Addon.db)

            -- Update detail rows if expanded
            if entry.detailRows then
                for _, row in ipairs(entry.detailRows) do
                    row.playerName:SetFont(fontPath, fontSize - 2, fontOutline)
                    DU.ApplyFontShadow(row.playerName, ns.Addon.db)
                    row.rollType:SetFont(fontPath, fontSize - 2, fontOutline)
                    DU.ApplyFontShadow(row.rollType, ns.Addon.db)
                    row.rollValue:SetFont(fontPath, fontSize - 2, fontOutline)
                    DU.ApplyFontShadow(row.rollValue, ns.Addon.db)
                end
            end

            -- Refresh quality border visibility
            if entry.itemLink and db.appearance.qualityBorder then
                if entry.quality then
                    local qr, qg, qb = DU.GetQualityColor(entry.quality)
                    entry.iconBorder:SetColorTexture(qr, qg, qb, 0.8)
                end
                entry.iconBorder:Show()
            elseif entry.itemLink then
                entry.iconBorder:Hide()
            end
        end
    end

    -- Re-layout entries if visible
    if containerFrame:IsShown() then
        RefreshHistory()
    end
end

function ns.HistoryFrame.AddEntry(data)
    local db = ns.Addon.db.profile
    local maxEntries = db.history.maxEntries or 100

    -- Insert at front (newest first)
    table.insert(ns.historyData, 1, data)

    -- Trim to maxEntries
    while #ns.historyData > maxEntries do
        table.remove(ns.historyData)
    end

    PersistEntries()

    -- Refresh display if visible
    if containerFrame and containerFrame:IsShown() then
        RefreshHistory()
    end
end

function ns.HistoryFrame.UpdateEntryByKey(dropKey, newData)
    for i, data in ipairs(ns.historyData) do
        if data.dropKey == dropKey then
            -- Preserve the original first-observation wall clock so persisted
            -- timestamps survive cross-session re-seeds. The drop happened when
            -- we first saw it, not when the API replayed it back to us.
            if data.wallTime and (not newData.wallTime or data.wallTime < newData.wallTime) then
                newData.wallTime = data.wallTime
            end
            if data.timestamp and not newData.timestamp then
                newData.timestamp = data.timestamp
            end
            ns.historyData[i] = newData
            PersistEntries()
            if containerFrame and containerFrame:IsShown() then
                RefreshHistory()
            end
            return
        end
    end
    -- Not found, treat as new (AddEntry persists)
    ns.HistoryFrame.AddEntry(newData)
end

function ns.HistoryFrame.SetEntries(entries)
    local db = ns.Addon.db.profile
    local maxEntries = db.history.maxEntries or 100

    -- Replace all data
    wipe(ns.historyData)
    for i, entry in ipairs(entries) do
        if i > maxEntries then
            break
        end
        ns.historyData[i] = entry
    end

    PersistEntries()

    -- Refresh display if visible
    if containerFrame and containerFrame:IsShown() then
        RefreshHistory()
    end
end

function ns.HistoryFrame.ClearHistory()
    wipe(expandedEntries)
    wipe(ns.historyData)
    PersistEntries()
    if containerFrame and containerFrame:IsShown() then
        RefreshHistory()
    end
end
