-------------------------------------------------------------------------------
-- HistoryTab.lua
-- History settings tab: enable, auto-show, direct loot tracking, layout
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...

local L = ns.L
-------------------------------------------------------------------------------
-- Cached globals
-------------------------------------------------------------------------------

local math_abs = math.abs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber
local StaticPopup_Show = StaticPopup_Show
local StaticPopupDialogs = StaticPopupDialogs
local YES = YES
local NO = NO

-------------------------------------------------------------------------------
-- DragonWidgets references
-------------------------------------------------------------------------------

local W = ns.DW.Widgets
local LC = ns.DW.LayoutConstants

-------------------------------------------------------------------------------
-- Namespace references
-------------------------------------------------------------------------------

local dlns
local RefreshState

-------------------------------------------------------------------------------
-- Static popup dialogs (defined at file scope)
-------------------------------------------------------------------------------

StaticPopupDialogs["DRAGONLOOT_CLEAR_HISTORY"] = {
    text = L["Are you sure you want to clear all loot history? This cannot be undone."],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        local dl = ns.dlns
        if not dl or not dl.HistoryFrame or not dl.HistoryFrame.ClearHistory then
            return
        end
        dl.HistoryFrame.ClearHistory()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-------------------------------------------------------------------------------
-- Helper: call HistoryFrame.ApplySettings if available
-------------------------------------------------------------------------------

local function ApplyHistorySettings()
    if dlns.HistoryFrame and dlns.HistoryFrame.ApplySettings then
        dlns.HistoryFrame.ApplySettings()
    end
end

local function CreateHistorySection(parent, db, yOffset)
    local section = W.CreateSection(parent, L["History"])
    local content = section.content
    local innerY = -LC.SECTION_PADDING_TOP

    -- Enable History
    local enableToggle = W.CreateToggle(content, {
        label = L["Enable History"],
        get = function()
            return db.profile.history.enabled
        end,
        set = function(value)
            db.profile.history.enabled = value
            ApplyHistorySettings()
            if RefreshState then
                RefreshState()
            end
        end,
    })
    innerY = LC.AnchorWidget(enableToggle, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    section:SetContentHeight(math_abs(innerY) + LC.SECTION_PADDING_BOTTOM)
    yOffset = LC.AnchorSection(section, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    return yOffset
end

local function CreateLayoutSection(parent, db, yOffset, layoutWidgets)
    local section = W.CreateSection(parent, L["Layout"])
    local content = section.content
    local innerY = -LC.SECTION_PADDING_TOP

    local widthSlider = W.CreateSlider(content, {
        label = L["Width"],
        min = 250,
        max = 800,
        step = 10,
        format = "%d",
        get = function()
            return db.profile.history.width
        end,
        set = function(value)
            db.profile.history.width = value
            ApplyHistorySettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = widthSlider
    innerY = LC.AnchorWidget(widthSlider, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    local heightSlider = W.CreateSlider(content, {
        label = L["Height"],
        min = 150,
        max = 800,
        step = 10,
        format = "%d",
        get = function()
            return db.profile.history.height
        end,
        set = function(value)
            db.profile.history.height = value
            ApplyHistorySettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = heightSlider
    innerY = LC.AnchorWidget(heightSlider, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    local scaleSlider = W.CreateSlider(content, {
        label = L["Scale"],
        min = 0.5,
        max = 2,
        step = 0.05,
        format = "%.2f",
        get = function()
            return db.profile.history.scale
        end,
        set = function(value)
            db.profile.history.scale = value
            ApplyHistorySettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = scaleSlider
    innerY = LC.AnchorWidget(scaleSlider, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    local historyIconSlider = W.CreateSlider(content, {
        label = L["History Icon Size"],
        tooltip = L["Icon size in the history frame"],
        min = 16,
        max = 48,
        step = 2,
        format = "%d",
        get = function()
            return db.profile.appearance.historyIconSize
        end,
        set = function(value)
            db.profile.appearance.historyIconSize = value
            ApplyHistorySettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = historyIconSlider
    innerY = LC.AnchorWidget(historyIconSlider, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    -- Slider: Entry Spacing
    local entrySpacingSlider = W.CreateSlider(content, {
        label = L["Entry Spacing"],
        min = 0,
        max = 12,
        step = 1,
        format = "%d",
        get = function()
            return db.profile.history.entrySpacing
        end,
        set = function(value)
            db.profile.history.entrySpacing = value
            ApplyHistorySettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = entrySpacingSlider
    innerY = LC.AnchorWidget(entrySpacingSlider, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    -- Slider: Content Padding
    local contentPaddingSlider = W.CreateSlider(content, {
        label = L["Content Padding"],
        min = 0,
        max = 12,
        step = 1,
        format = "%d",
        get = function()
            return db.profile.history.contentPadding
        end,
        set = function(value)
            db.profile.history.contentPadding = value
            ApplyHistorySettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = contentPaddingSlider
    innerY = LC.AnchorWidget(contentPaddingSlider, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    -- Slider: Row Height Padding
    local rowHeightPaddingSlider = W.CreateSlider(content, {
        label = L["Row Height Padding"],
        min = 2,
        max = 20,
        step = 1,
        format = "%d",
        get = function()
            return db.profile.history.rowHeightPadding or 6
        end,
        set = function(value)
            db.profile.history.rowHeightPadding = value
            ApplyHistorySettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = rowHeightPaddingSlider
    innerY = LC.AnchorWidget(rowHeightPaddingSlider, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    section:SetContentHeight(math_abs(innerY) + LC.SECTION_PADDING_BOTTOM)
    yOffset = LC.AnchorSection(section, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    return yOffset
end

local function CreateContentSection(parent, db, yOffset, layoutWidgets)
    local section = W.CreateSection(parent, L["Content"])
    local content = section.content
    local innerY = -LC.SECTION_PADDING_TOP

    -- Show Roll Details toggle
    local rollDetailsToggle = W.CreateToggle(content, {
        label = L["Show Roll Details"],
        tooltip = L["Click history entries to expand and see all player rolls"],
        get = function()
            return db.profile.history.showRollDetails
        end,
        set = function(value)
            db.profile.history.showRollDetails = value
            ApplyHistorySettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = rollDetailsToggle
    innerY = LC.AnchorWidget(rollDetailsToggle, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    local timestampToggle = W.CreateToggle(content, {
        label = L["Show Timestamps"],
        tooltip = L["Show elapsed time beside each history entry"],
        get = function()
            return db.profile.history.showTimestamp
        end,
        set = function(value)
            db.profile.history.showTimestamp = value
            ApplyHistorySettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = timestampToggle
    innerY = LC.AnchorWidget(timestampToggle, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    section:SetContentHeight(math_abs(innerY) + LC.SECTION_PADDING_BOTTOM)
    yOffset = LC.AnchorSection(section, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    return yOffset
end

local function CreateRecordingSection(parent, db, yOffset, layoutWidgets, reapplySubState)
    local section = W.CreateSection(parent, L["Recording"])
    local content = section.content
    local innerY = -LC.SECTION_PADDING_TOP

    -- Forward-declare so the toggle set closure captures the variable
    local qualityDropdown

    -- Track Direct Loot (set callback updates dropdown disabled state)
    local trackToggle = W.CreateToggle(content, {
        label = L["Track Direct Loot"],
        tooltip = L["Track items you pick up directly (not from a loot window)"],
        get = function()
            return db.profile.history.trackDirectLoot
        end,
        set = function(value)
            db.profile.history.trackDirectLoot = value
            if RefreshState then
                RefreshState()
            end
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = trackToggle
    innerY = LC.AnchorWidget(trackToggle, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    -- Minimum Quality dropdown
    qualityDropdown = W.CreateDropdown(content, {
        label = L["Minimum Quality"],
        values = ns.QualityValues,
        get = function()
            return tostring(db.profile.history.minQuality)
        end,
        set = function(value)
            db.profile.history.minQuality = tonumber(value) or 0
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = qualityDropdown
    innerY = LC.AnchorWidget(qualityDropdown, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    reapplySubState[#reapplySubState + 1] = function()
        qualityDropdown:SetDisabled(not db.profile.history.trackDirectLoot)
    end

    -- Slider: Max Entries
    local maxEntriesSlider = W.CreateSlider(content, {
        label = L["Max Entries"],
        min = 10,
        max = 500,
        step = 10,
        format = "%d",
        get = function()
            return db.profile.history.maxEntries
        end,
        set = function(value)
            db.profile.history.maxEntries = value
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = maxEntriesSlider
    innerY = LC.AnchorWidget(maxEntriesSlider, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    section:SetContentHeight(math_abs(innerY) + LC.SECTION_PADDING_BOTTOM)
    yOffset = LC.AnchorSection(section, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    return yOffset
end

local function CreateBehaviorSection(parent, db, yOffset, layoutWidgets)
    local section = W.CreateSection(parent, L["Behavior"])
    local content = section.content
    local innerY = -LC.SECTION_PADDING_TOP

    -- Lock Position
    local lockToggle = W.CreateToggle(content, {
        label = L["Lock Position"],
        tooltip = L["Prevent the history frame from being moved"],
        get = function()
            return db.profile.history.lock
        end,
        set = function(value)
            db.profile.history.lock = value
            ApplyHistorySettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = lockToggle
    innerY = LC.AnchorWidget(lockToggle, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    -- Auto Show on Loot
    local autoShowToggle = W.CreateToggle(content, {
        label = L["Auto Show on Loot"],
        get = function()
            return db.profile.history.autoShow
        end,
        set = function(value)
            db.profile.history.autoShow = value
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = autoShowToggle
    innerY = LC.AnchorWidget(autoShowToggle, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    section:SetContentHeight(math_abs(innerY) + LC.SECTION_PADDING_BOTTOM)
    yOffset = LC.AnchorSection(section, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    return yOffset
end

local function CreateActionsSection(parent, yOffset)
    local section = W.CreateSection(parent, L["History Actions"])
    local content = section.content
    local innerY = -LC.SECTION_PADDING_TOP

    -- Clear History button (destructive action)
    local clearBtn = W.CreateButton(content, {
        text = L["Clear History"],
        width = 160,
        tooltip = L["Permanently delete all stored loot history entries"],
        onClick = function()
            StaticPopup_Show("DRAGONLOOT_CLEAR_HISTORY")
        end,
    })
    innerY = LC.AnchorWidget(clearBtn, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    section:SetContentHeight(math_abs(innerY) + LC.SECTION_PADDING_BOTTOM)
    yOffset = LC.AnchorSection(section, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    return yOffset
end

-------------------------------------------------------------------------------
-- Build the History tab content
-------------------------------------------------------------------------------

local function CreateContent(parent)
    dlns = ns.dlns
    local db = dlns.Addon.db
    local yOffset = LC.PADDING_TOP
    local layoutWidgets = {}
    local reapplySubState = {}

    yOffset = CreateHistorySection(parent, db, yOffset)
    yOffset = CreateLayoutSection(parent, db, yOffset, layoutWidgets)
    yOffset = CreateContentSection(parent, db, yOffset, layoutWidgets)
    yOffset = CreateRecordingSection(parent, db, yOffset, layoutWidgets, reapplySubState)
    yOffset = CreateBehaviorSection(parent, db, yOffset, layoutWidgets)
    yOffset = CreateActionsSection(parent, yOffset)

    RefreshState = function()
        for _, widget in ipairs(layoutWidgets) do
            widget:SetDisabled(not db.profile.history.enabled)
        end
        if db.profile.history.enabled then
            for _, fn in ipairs(reapplySubState) do
                fn()
            end
        end
    end
    RefreshState()

    parent:SetHeight(math_abs(yOffset) + LC.PADDING_BOTTOM)
end

-------------------------------------------------------------------------------
-- Register tab
-------------------------------------------------------------------------------

ns.Tabs[#ns.Tabs + 1] = {
    id = "history",
    label = L["History"],
    order = 4,
    createFunc = CreateContent,
    refreshFunc = function()
        if RefreshState then
            RefreshState()
        end
    end,
}
