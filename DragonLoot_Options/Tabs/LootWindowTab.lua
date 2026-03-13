-------------------------------------------------------------------------------
-- LootWindowTab.lua
-- Loot window settings tab: enable, lock, scale, dimensions, spacing
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local ADDON_NAME, ns = ...
local L = ns.L

-------------------------------------------------------------------------------
-- Cached globals
-------------------------------------------------------------------------------

local math_abs = math.abs

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

local function CreateContent(parent)
    dlns = ns.dlns
    local LC = ns.LayoutConstants
    local W = ns.Widgets
    local db = dlns.Addon.db
    local yOffset = LC.PADDING_TOP

    ---------------------------------------------------------------------------
    -- Header: Loot Window
    ---------------------------------------------------------------------------
    local header = W.CreateHeader(parent, L["Loot Window"])
    yOffset = LC.AnchorWidget(header, parent, yOffset) - LC.SPACING_AFTER_HEADER

    ---------------------------------------------------------------------------
    -- Toggle: Enable Custom Loot Window
    ---------------------------------------------------------------------------
    local enableToggle = W.CreateToggle(parent, {
        label = L["Enable Custom Loot Window"],
        tooltip = L["Replace the default loot window with DragonLoot's custom frame"],
        get = function() return db.profile.lootWindow.enabled end,
        set = function(value)
            db.profile.lootWindow.enabled = value
            ApplyLootSettings()
        end,
    })
    yOffset = LC.AnchorWidget(enableToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    ---------------------------------------------------------------------------
    -- Toggle: Lock Position
    ---------------------------------------------------------------------------
    local lockToggle = W.CreateToggle(parent, {
        label = L["Lock Position"],
        tooltip = L["Prevent the loot window from being moved"],
        get = function() return db.profile.lootWindow.lock end,
        set = function(value)
            db.profile.lootWindow.lock = value
        end,
    })
    yOffset = LC.AnchorWidget(lockToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    ---------------------------------------------------------------------------
    -- Toggle: Position at Cursor
    ---------------------------------------------------------------------------
    local cursorToggle = W.CreateToggle(parent, {
        label = L["Position at Cursor"],
        tooltip = L["Open the loot window at the mouse cursor instead of the saved position"],
        get = function() return db.profile.lootWindow.positionAtCursor end,
        set = function(value)
            db.profile.lootWindow.positionAtCursor = value
        end,
    })
    yOffset = LC.AnchorWidget(cursorToggle, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    ---------------------------------------------------------------------------
    -- Header: Layout
    ---------------------------------------------------------------------------
    local layoutHeader = W.CreateHeader(parent, L["Layout"])
    yOffset = LC.AnchorWidget(layoutHeader, parent, yOffset) - LC.SPACING_AFTER_HEADER

    ---------------------------------------------------------------------------
    -- Slider: Scale
    ---------------------------------------------------------------------------
    local scaleSlider = W.CreateSlider(parent, {
        label = L["Scale"],
        min = 0.5, max = 2, step = 0.05,
        get = function() return db.profile.lootWindow.scale end,
        set = function(value)
            db.profile.lootWindow.scale = value
            ApplyLootSettings()
        end,
    })
    yOffset = LC.AnchorWidget(scaleSlider, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    ---------------------------------------------------------------------------
    -- Slider: Width
    ---------------------------------------------------------------------------
    local widthSlider = W.CreateSlider(parent, {
        label = L["Width"],
        min = 150, max = 400, step = 10,
        format = "%d",
        get = function() return db.profile.lootWindow.width end,
        set = function(value)
            db.profile.lootWindow.width = value
            ApplyLootSettings()
        end,
    })
    yOffset = LC.AnchorWidget(widthSlider, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    ---------------------------------------------------------------------------
    -- Slider: Height
    ---------------------------------------------------------------------------
    local heightSlider = W.CreateSlider(parent, {
        label = L["Height"],
        min = 150, max = 600, step = 10,
        format = "%d",
        get = function() return db.profile.lootWindow.height end,
        set = function(value)
            db.profile.lootWindow.height = value
            ApplyLootSettings()
        end,
    })
    yOffset = LC.AnchorWidget(heightSlider, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    ---------------------------------------------------------------------------
    -- Slider: Slot Spacing
    ---------------------------------------------------------------------------
    local slotSpacingSlider = W.CreateSlider(parent, {
        label = L["Slot Spacing"],
        min = 0, max = 12, step = 1,
        format = "%d",
        get = function() return db.profile.lootWindow.slotSpacing end,
        set = function(value)
            db.profile.lootWindow.slotSpacing = value
            ApplyLootSettings()
        end,
    })
    yOffset = LC.AnchorWidget(slotSpacingSlider, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    ---------------------------------------------------------------------------
    -- Slider: Content Padding
    ---------------------------------------------------------------------------
    local contentPaddingSlider = W.CreateSlider(parent, {
        label = L["Content Padding"],
        min = 0, max = 12, step = 1,
        format = "%d",
        get = function() return db.profile.lootWindow.contentPadding end,
        set = function(value)
            db.profile.lootWindow.contentPadding = value
            ApplyLootSettings()
        end,
    })
    yOffset = LC.AnchorWidget(contentPaddingSlider, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    ---------------------------------------------------------------------------
    -- Set content height for scroll frame
    ---------------------------------------------------------------------------
    parent:SetHeight(math_abs(yOffset) + LC.PADDING_BOTTOM)
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
