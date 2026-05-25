-------------------------------------------------------------------------------
-- MasterLootFrame.lua
-- Master loot candidate picker (Classic-only).
--
-- Bridges MasterLootListener_Classic's CollectCandidates result into a
-- styled modal: a vertical list of class-colored candidate names and a
-- Cancel button. Selecting a row calls GiveMasterLoot(slot, index).
--
-- Master Loot was removed from Retail in 9.0, so this entire file is gated
-- behind ns.IsClassic. The TOC loads the file unconditionally; the guard
-- below makes it a harmless no-op on Retail.
--
-- Supported versions: MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...

if not ns.IsClassic then
    return
end

-------------------------------------------------------------------------------
-- Cached WoW API
-------------------------------------------------------------------------------

local CreateFrame = CreateFrame
local UIParent = UIParent
local UnitClass = UnitClass
local GiveMasterLoot = GiveMasterLoot
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local UISpecialFrames = UISpecialFrames
local tinsert = table.insert

local L = ns.L
local DU = ns.DisplayUtils

-------------------------------------------------------------------------------
-- Layout constants
-------------------------------------------------------------------------------

local FRAME_NAME = "DragonLootMasterLootFrame"
local FRAME_WIDTH = 200
local TITLE_HEIGHT = 22
local ROW_HEIGHT = 22
local ROW_SPACING = 2
local CANCEL_HEIGHT = 24
local CANCEL_TOP_GAP = 6
local CONTENT_PADDING = 8

-------------------------------------------------------------------------------
-- Module state
-------------------------------------------------------------------------------

local frame
local titleText
local cancelButton
local rowPool = {}
local activeRows = {}

-------------------------------------------------------------------------------
-- Class color lookup
--
-- UnitClass(name) only resolves for group members within range. When the
-- candidate is out of range or otherwise unresolvable, fall back to the
-- common-quality color (white) so the row is still legible.
-------------------------------------------------------------------------------

local function GetCandidateColor(name)
    local _, classFile = UnitClass(name)
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

-------------------------------------------------------------------------------
-- Row pool
-------------------------------------------------------------------------------

local function OnRowClick(self)
    local slot = self._slot
    local index = self._candidateIndex
    if not slot or not index then
        return
    end
    GiveMasterLoot(slot, index)
    ns.MasterLootFrame.Hide()
end

local function CreateRow()
    local row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.15)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row:SetScript("OnClick", OnRowClick)
    return row
end

local function AcquireRow()
    local row = table.remove(rowPool)
    if not row then
        row = CreateRow()
    end
    return row
end

local function ReleaseRow(row)
    row:Hide()
    row:ClearAllPoints()
    row._slot = nil
    row._candidateIndex = nil
    row.label:SetText("")
    tinsert(rowPool, row)
end

local function ReleaseAllRows()
    for i = #activeRows, 1, -1 do
        ReleaseRow(activeRows[i])
        activeRows[i] = nil
    end
end

-------------------------------------------------------------------------------
-- Styling
--
-- Theme values live in ns.Addon.db.profile.appearance and are shared with
-- LootFrame via DisplayUtils. Re-fetched on every Show so live config
-- changes take effect without a teardown.
-------------------------------------------------------------------------------

local function ApplyTheme()
    if not frame or not ns.Addon or not ns.Addon.db then
        return
    end
    DU.ApplyBackdrop(frame, ns.Addon.db)

    local fontPath, fontSize, fontOutline = DU.GetFont(ns.Addon.db)
    titleText:SetFont(fontPath, fontSize, fontOutline)
    DU.ApplyFontShadow(titleText, ns.Addon.db)

    for _, row in ipairs(activeRows) do
        row.label:SetFont(fontPath, fontSize, fontOutline)
        DU.ApplyFontShadow(row.label, ns.Addon.db)
    end

    if cancelButton and cancelButton.text then
        cancelButton.text:SetFont(fontPath, fontSize, fontOutline)
        DU.ApplyFontShadow(cancelButton.text, ns.Addon.db)
    end
end

-------------------------------------------------------------------------------
-- Anchoring
--
-- Prefer the visible loot bag so the picker reads as a modal attached to
-- the loot session. Fall back to screen center when DragonLootFrame is
-- absent (e.g. a Show invoked outside the normal loot flow).
-------------------------------------------------------------------------------

local function AnchorFrame()
    frame:ClearAllPoints()
    local lootFrame = _G.DragonLootFrame
    if lootFrame and lootFrame:IsShown() then
        frame:SetPoint("CENTER", lootFrame, "CENTER", 0, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-------------------------------------------------------------------------------
-- Frame construction
-------------------------------------------------------------------------------

local function CreateCancelButton(parent)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetHeight(CANCEL_HEIGHT)
    btn:SetText(L["Cancel"])
    btn:SetScript("OnClick", function()
        ns.MasterLootFrame.Hide()
    end)
    btn.text = btn:GetFontString()
    return btn
end

local function CreateContainerFrame()
    local f = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetClampedToScreen(true)
    f:SetWidth(FRAME_WIDTH)
    f:EnableMouse(true)
    f:Hide()

    titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", f, "TOP", 0, -CONTENT_PADDING)
    titleText:SetText(L["Master Loot"])
    titleText:SetTextColor(1, 0.82, 0)

    cancelButton = CreateCancelButton(f)

    -- Register for Escape-to-close. UISpecialFrames keys on the frame's
    -- global name, which is why FRAME_NAME is the second arg to CreateFrame.
    tinsert(UISpecialFrames, FRAME_NAME)

    return f
end

-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------

local function LayoutRows()
    local rowsTop = -(CONTENT_PADDING + TITLE_HEIGHT)
    for i, row in ipairs(activeRows) do
        row:ClearAllPoints()
        local y = rowsTop - (i - 1) * (ROW_HEIGHT + ROW_SPACING)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_PADDING, y)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CONTENT_PADDING, y)
    end

    local rowsHeight = #activeRows * ROW_HEIGHT + math.max(0, #activeRows - 1) * ROW_SPACING

    cancelButton:ClearAllPoints()
    cancelButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", CONTENT_PADDING, CONTENT_PADDING)
    cancelButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONTENT_PADDING, CONTENT_PADDING)

    local totalHeight = CONTENT_PADDING + TITLE_HEIGHT + rowsHeight + CANCEL_TOP_GAP + CANCEL_HEIGHT + CONTENT_PADDING
    frame:SetHeight(totalHeight)
end

-------------------------------------------------------------------------------
-- Public Interface: ns.MasterLootFrame
-------------------------------------------------------------------------------

ns.MasterLootFrame = ns.MasterLootFrame or {}

function ns.MasterLootFrame.Initialize()
    if frame then
        return
    end
    frame = CreateContainerFrame()
    ApplyTheme()
    ns.DebugPrint("MasterLootFrame initialized")
end

function ns.MasterLootFrame.Shutdown()
    if not frame then
        return
    end
    ReleaseAllRows()
    frame:Hide()
    ns.DebugPrint("MasterLootFrame shut down")
end

-- Show is invoked colon-style by MasterLootListener_Classic
-- (ns.MasterLootFrame:Show(slot, candidates)); the leading parameter is
-- the receiver self-table and is intentionally ignored.
function ns.MasterLootFrame.Show(_, slot, candidates)
    -- Defensive: skip if called before Initialize (e.g. addon disabled).
    if not frame then
        return
    end
    if type(slot) ~= "number" or type(candidates) ~= "table" or #candidates == 0 then
        return
    end

    ReleaseAllRows()

    local fontPath, fontSize, fontOutline = DU.GetFont(ns.Addon.db)

    for _, candidate in ipairs(candidates) do
        local row = AcquireRow()
        row._slot = slot
        row._candidateIndex = candidate.index
        row.label:SetFont(fontPath, fontSize, fontOutline)
        DU.ApplyFontShadow(row.label, ns.Addon.db)
        row.label:SetText(candidate.name)
        local r, g, b = GetCandidateColor(candidate.name)
        row.label:SetTextColor(r, g, b)
        row:Show()
        activeRows[#activeRows + 1] = row
    end

    ApplyTheme()
    LayoutRows()
    AnchorFrame()
    frame:Show()
end

function ns.MasterLootFrame.Hide()
    if not frame then
        return
    end
    ReleaseAllRows()
    frame:Hide()
end

function ns.MasterLootFrame.IsShown()
    return frame ~= nil and frame:IsShown()
end
