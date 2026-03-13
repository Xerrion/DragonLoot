-------------------------------------------------------------------------------
-- HistoryTab.lua
-- History settings tab: enable, auto-show, direct loot tracking, layout
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local LDF = LibDragonFramework

-------------------------------------------------------------------------------
-- Cached globals
-------------------------------------------------------------------------------

local tostring = tostring
local tonumber = tonumber

-------------------------------------------------------------------------------
-- Namespace references
-------------------------------------------------------------------------------

local dlns

-------------------------------------------------------------------------------
-- Helper: call HistoryFrame.ApplySettings if available
-------------------------------------------------------------------------------

local function ApplyHistorySettings()
    if dlns.HistoryFrame and dlns.HistoryFrame.ApplySettings then
        dlns.HistoryFrame.ApplySettings()
    end
end

-------------------------------------------------------------------------------
-- Build the History tab content
-------------------------------------------------------------------------------

local function CreateContent(scrollChild)
    dlns = ns.dlns
    local db = dlns.Addon.db

    local stack = LDF.CreateStackLayout(scrollChild)
    stack:SetPoint("TOPLEFT", scrollChild, "TOPLEFT")
    stack:SetPoint("RIGHT", scrollChild, "RIGHT")

    ---------------------------------------------------------------------------
    -- Section: History (toggles + quality dropdown)
    ---------------------------------------------------------------------------

    local historySection = LDF.CreateSection(scrollChild, L["History"], { columns = 1 })

    local historyStack = LDF.CreateStackLayout(historySection.content)
    historyStack:SetPoint("TOPLEFT", historySection.content, "TOPLEFT")
    historyStack:SetPoint("RIGHT", historySection.content, "RIGHT")
    historyStack:HookScript("OnSizeChanged", function(_, _, h)
        historySection.content:SetHeight(h)
    end)

    -- Toggle: Enable History
    local enableToggle = LDF.CreateToggle(historySection.content, {
        label = L["Enable History"],
        get = function() return db.profile.history.enabled end,
        set = function(value)
            db.profile.history.enabled = value
            ApplyHistorySettings()
        end,
    })
    historyStack:AddChild(enableToggle)

    -- Toggle: Auto Show on Loot
    local autoShowToggle = LDF.CreateToggle(historySection.content, {
        label = L["Auto Show on Loot"],
        get = function() return db.profile.history.autoShow end,
        set = function(value) db.profile.history.autoShow = value end,
    })
    historyStack:AddChild(autoShowToggle)

    -- Forward-declare so the toggle set closure captures the variable
    local qualityDropdown

    -- Toggle: Track Direct Loot (set callback updates dropdown enabled state)
    local trackToggle = LDF.CreateToggle(historySection.content, {
        label = L["Track Direct Loot"],
        tooltip = L["Track items you pick up directly (not from a loot window)"],
        get = function() return db.profile.history.trackDirectLoot end,
        set = function(value)
            db.profile.history.trackDirectLoot = value
            if qualityDropdown then
                qualityDropdown:SetEnabled(value)
            end
        end,
    })
    historyStack:AddChild(trackToggle)

    -- Dropdown: Minimum Quality
    qualityDropdown = LDF.CreateDropdown(historySection.content, {
        label = L["Minimum Quality"],
        values = ns.QualityValues,
        get = function() return tostring(db.profile.history.minQuality) end,
        set = function(value) db.profile.history.minQuality = tonumber(value) end,
    })
    historyStack:AddChild(qualityDropdown)

    -- Apply initial enabled state based on current trackDirectLoot value
    qualityDropdown:SetEnabled(db.profile.history.trackDirectLoot)

    stack:AddChild(historySection)

    ---------------------------------------------------------------------------
    -- Section: Layout (sliders)
    ---------------------------------------------------------------------------

    local layoutSection = LDF.CreateSection(scrollChild, L["Layout"], { columns = 1 })

    local layoutStack = LDF.CreateStackLayout(layoutSection.content)
    layoutStack:SetPoint("TOPLEFT", layoutSection.content, "TOPLEFT")
    layoutStack:SetPoint("RIGHT", layoutSection.content, "RIGHT")
    layoutStack:HookScript("OnSizeChanged", function(_, _, h)
        layoutSection.content:SetHeight(h)
    end)

    -- Slider: Max Entries
    local maxEntriesSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Max Entries"],
        min = 10, max = 500, step = 10,
        format = "%d",
        get = function() return db.profile.history.maxEntries end,
        set = function(value) db.profile.history.maxEntries = value end,
    })
    layoutStack:AddChild(maxEntriesSlider)

    -- Slider: Entry Spacing
    local entrySpacingSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Entry Spacing"],
        min = 0, max = 12, step = 1,
        format = "%d",
        get = function() return db.profile.history.entrySpacing end,
        set = function(value)
            db.profile.history.entrySpacing = value
            ApplyHistorySettings()
        end,
    })
    layoutStack:AddChild(entrySpacingSlider)

    -- Slider: Content Padding
    local contentPaddingSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Content Padding"],
        min = 0, max = 12, step = 1,
        format = "%d",
        get = function() return db.profile.history.contentPadding end,
        set = function(value)
            db.profile.history.contentPadding = value
            ApplyHistorySettings()
        end,
    })
    layoutStack:AddChild(contentPaddingSlider)

    stack:AddChild(layoutSection)
end

-------------------------------------------------------------------------------
-- Register tab
-------------------------------------------------------------------------------

ns.Tabs = ns.Tabs or {}
ns.Tabs[#ns.Tabs + 1] = {
    id = "history",
    label = L["History"],
    order = 4,
    createFunc = CreateContent,
}
