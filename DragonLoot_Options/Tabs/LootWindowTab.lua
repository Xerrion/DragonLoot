-------------------------------------------------------------------------------
-- LootWindowTab.lua
-- Loot window settings tab: enable, lock, scale, dimensions, spacing
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local LDF = LibDragonFramework

-------------------------------------------------------------------------------
-- Namespace references
-------------------------------------------------------------------------------

local dlns

-------------------------------------------------------------------------------
-- Helper: call LootFrame.ApplySettings if available
-------------------------------------------------------------------------------

local function ApplyLootSettings()
    if dlns.LootFrame and dlns.LootFrame.ApplySettings then
        dlns.LootFrame.ApplySettings()
    end
end

-------------------------------------------------------------------------------
-- Build the Loot Window tab content
-------------------------------------------------------------------------------

local function CreateContent(scrollChild)
    dlns = ns.dlns
    local db = dlns.Addon.db

    local stack = LDF.CreateStackLayout(scrollChild)
    stack:SetPoint("TOPLEFT", scrollChild, "TOPLEFT")
    stack:SetPoint("RIGHT", scrollChild, "RIGHT")

    ---------------------------------------------------------------------------
    -- Section: Loot Window (3 toggles)
    ---------------------------------------------------------------------------

    local lootSection = LDF.CreateSection(scrollChild, L["Loot Window"], { columns = 1 })

    local lootStack = LDF.CreateStackLayout(lootSection.content)
    lootStack:SetPoint("TOPLEFT", lootSection.content, "TOPLEFT")
    lootStack:SetPoint("RIGHT", lootSection.content, "RIGHT")
    lootStack:HookScript("OnSizeChanged", function(_, _, h)
        lootSection.content:SetHeight(h)
    end)

    local enableToggle = LDF.CreateToggle(lootSection.content, {
        label = L["Enable Custom Loot Window"],
        tooltip = L["Replace the default loot window with DragonLoot's custom frame"],
        get = function() return db.profile.lootWindow.enabled end,
        set = function(value)
            db.profile.lootWindow.enabled = value
            ApplyLootSettings()
        end,
    })
    lootStack:AddChild(enableToggle)

    local lockToggle = LDF.CreateToggle(lootSection.content, {
        label = L["Lock Position"],
        tooltip = L["Prevent the loot window from being moved"],
        get = function() return db.profile.lootWindow.lock end,
        set = function(value)
            db.profile.lootWindow.lock = value
        end,
    })
    lootStack:AddChild(lockToggle)

    local cursorToggle = LDF.CreateToggle(lootSection.content, {
        label = L["Position at Cursor"],
        tooltip = L["Open the loot window at the mouse cursor instead of the saved position"],
        get = function() return db.profile.lootWindow.positionAtCursor end,
        set = function(value)
            db.profile.lootWindow.positionAtCursor = value
        end,
    })
    lootStack:AddChild(cursorToggle)

    stack:AddChild(lootSection)

    ---------------------------------------------------------------------------
    -- Section: Layout (5 sliders)
    ---------------------------------------------------------------------------

    local layoutSection = LDF.CreateSection(scrollChild, L["Layout"], { columns = 1 })

    local layoutStack = LDF.CreateStackLayout(layoutSection.content)
    layoutStack:SetPoint("TOPLEFT", layoutSection.content, "TOPLEFT")
    layoutStack:SetPoint("RIGHT", layoutSection.content, "RIGHT")
    layoutStack:HookScript("OnSizeChanged", function(_, _, h)
        layoutSection.content:SetHeight(h)
    end)

    local scaleSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Scale"],
        min = 0.5, max = 2, step = 0.05,
        get = function() return db.profile.lootWindow.scale end,
        set = function(value)
            db.profile.lootWindow.scale = value
            ApplyLootSettings()
        end,
    })
    layoutStack:AddChild(scaleSlider)

    local widthSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Width"],
        min = 150, max = 400, step = 10,
        format = "%d",
        get = function() return db.profile.lootWindow.width end,
        set = function(value)
            db.profile.lootWindow.width = value
            ApplyLootSettings()
        end,
    })
    layoutStack:AddChild(widthSlider)

    local heightSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Height"],
        min = 150, max = 600, step = 10,
        format = "%d",
        get = function() return db.profile.lootWindow.height end,
        set = function(value)
            db.profile.lootWindow.height = value
            ApplyLootSettings()
        end,
    })
    layoutStack:AddChild(heightSlider)

    local slotSpacingSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Slot Spacing"],
        min = 0, max = 12, step = 1,
        format = "%d",
        get = function() return db.profile.lootWindow.slotSpacing end,
        set = function(value)
            db.profile.lootWindow.slotSpacing = value
            ApplyLootSettings()
        end,
    })
    layoutStack:AddChild(slotSpacingSlider)

    local contentPaddingSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Content Padding"],
        min = 0, max = 12, step = 1,
        format = "%d",
        get = function() return db.profile.lootWindow.contentPadding end,
        set = function(value)
            db.profile.lootWindow.contentPadding = value
            ApplyLootSettings()
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
    id = "lootWindow",
    label = L["Loot Window"],
    order = 2,
    createFunc = CreateContent,
}
