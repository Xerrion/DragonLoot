-------------------------------------------------------------------------------
-- LootWindowTab.lua
-- Loot window settings tab: enable, lock, scale, dimensions, spacing
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
-- Helper: call LootFrame.ApplySettings if available
-------------------------------------------------------------------------------

local function ApplyLootSettings()
    if dlns.LootFrame and dlns.LootFrame.ApplySettings then
        dlns.LootFrame.ApplySettings()
    end
end

local SLOT_BG_VALUES = {
    { value = "gradient", text = L["Gradient"] },
    { value = "flat", text = L["Flat"] },
    { value = "stripe", text = L["Stripe"] },
    { value = "none", text = L["None"] },
}

-------------------------------------------------------------------------------
-- Build the Loot Window tab content
-------------------------------------------------------------------------------

local function CreateContent(parent)
    dlns = ns.dlns
    local db = dlns.Addon.db
    local yOffset = LC.PADDING_TOP
    local layoutWidgets = {}

    ---------------------------------------------------------------------------
    -- Section: Loot Window
    ---------------------------------------------------------------------------
    local lootSection = W.CreateSection(parent, L["Loot Window"])
    local lootContent = lootSection.content
    local lootY = -LC.SECTION_PADDING_TOP

    -- Toggle: Enable Custom Loot Window
    local enableToggle = W.CreateToggle(lootContent, {
        label = L["Enable Custom Loot Window"],
        tooltip = L["Replace the default loot window with DragonLoot's custom frame"],
        get = function()
            return db.profile.lootWindow.enabled
        end,
        set = function(value)
            db.profile.lootWindow.enabled = value
            ApplyLootSettings()
            if RefreshState then
                RefreshState()
            end
        end,
    })
    lootY = LC.AnchorWidget(enableToggle, lootContent, lootY) - LC.SPACING_BETWEEN_WIDGETS

    lootSection:SetContentHeight(math_abs(lootY) + LC.SECTION_PADDING_BOTTOM)
    yOffset = LC.AnchorSection(lootSection, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    ---------------------------------------------------------------------------
    -- Section: Layout
    ---------------------------------------------------------------------------
    local layoutSection = W.CreateSection(parent, L["Layout"])
    local layoutContent = layoutSection.content
    local layoutY = -LC.SECTION_PADDING_TOP

    -- Slider: Width
    local widthSlider = W.CreateSlider(layoutContent, {
        label = L["Width"],
        min = 150,
        max = 400,
        step = 10,
        format = "%d",
        get = function()
            return db.profile.lootWindow.width
        end,
        set = function(value)
            db.profile.lootWindow.width = value
            ApplyLootSettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = widthSlider
    layoutY = LC.AnchorWidget(widthSlider, layoutContent, layoutY) - LC.SPACING_BETWEEN_WIDGETS

    -- Slider: Height
    local heightSlider = W.CreateSlider(layoutContent, {
        label = L["Height"],
        min = 150,
        max = 600,
        step = 10,
        format = "%d",
        get = function()
            return db.profile.lootWindow.height
        end,
        set = function(value)
            db.profile.lootWindow.height = value
            ApplyLootSettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = heightSlider
    layoutY = LC.AnchorWidget(heightSlider, layoutContent, layoutY) - LC.SPACING_BETWEEN_WIDGETS

    -- Slider: Scale
    local scaleSlider = W.CreateSlider(layoutContent, {
        label = L["Scale"],
        min = 0.5,
        max = 2,
        step = 0.05,
        get = function()
            return db.profile.lootWindow.scale
        end,
        set = function(value)
            db.profile.lootWindow.scale = value
            ApplyLootSettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = scaleSlider
    layoutY = LC.AnchorWidget(scaleSlider, layoutContent, layoutY) - LC.SPACING_BETWEEN_WIDGETS

    local lootIconSlider = W.CreateSlider(layoutContent, {
        label = L["Loot Icon Size"],
        tooltip = L["Icon size in the loot window"],
        min = 16,
        max = 64,
        step = 2,
        format = "%d",
        get = function()
            return db.profile.appearance.lootIconSize
        end,
        set = function(value)
            db.profile.appearance.lootIconSize = value
            ApplyLootSettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = lootIconSlider
    layoutY = LC.AnchorWidget(lootIconSlider, layoutContent, layoutY) - LC.SPACING_BETWEEN_WIDGETS

    -- Slider: Slot Spacing
    local slotSpacingSlider = W.CreateSlider(layoutContent, {
        label = L["Slot Spacing"],
        min = 0,
        max = 12,
        step = 1,
        format = "%d",
        get = function()
            return db.profile.lootWindow.slotSpacing
        end,
        set = function(value)
            db.profile.lootWindow.slotSpacing = value
            ApplyLootSettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = slotSpacingSlider
    layoutY = LC.AnchorWidget(slotSpacingSlider, layoutContent, layoutY) - LC.SPACING_BETWEEN_WIDGETS

    -- Slider: Content Padding
    local contentPaddingSlider = W.CreateSlider(layoutContent, {
        label = L["Content Padding"],
        min = 0,
        max = 12,
        step = 1,
        format = "%d",
        get = function()
            return db.profile.lootWindow.contentPadding
        end,
        set = function(value)
            db.profile.lootWindow.contentPadding = value
            ApplyLootSettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = contentPaddingSlider
    layoutY = LC.AnchorWidget(contentPaddingSlider, layoutContent, layoutY) - LC.SPACING_BETWEEN_WIDGETS

    layoutSection:SetContentHeight(math_abs(layoutY) + LC.SECTION_PADDING_BOTTOM)
    yOffset = LC.AnchorSection(layoutSection, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    ---------------------------------------------------------------------------
    -- Section: Content
    ---------------------------------------------------------------------------
    local contentSection = W.CreateSection(parent, L["Content"])
    local content = contentSection.content
    local innerY = -LC.SECTION_PADDING_TOP

    local detailsToggle = W.CreateToggle(content, {
        label = L["Show Item Details"],
        tooltip = L["Show item level, binding, and item type below the item name"],
        get = function()
            return db.profile.lootWindow.showDetails
        end,
        set = function(value)
            db.profile.lootWindow.showDetails = value
            ApplyLootSettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = detailsToggle
    innerY = LC.AnchorWidget(detailsToggle, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    local quantityToggle = W.CreateToggle(content, {
        label = L["Show Stack Counts"],
        tooltip = L["Show stack quantities on loot item icons"],
        get = function()
            return db.profile.lootWindow.showQuantity
        end,
        set = function(value)
            db.profile.lootWindow.showQuantity = value
            ApplyLootSettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = quantityToggle
    innerY = LC.AnchorWidget(quantityToggle, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    contentSection:SetContentHeight(math_abs(innerY) + LC.SECTION_PADDING_BOTTOM)
    yOffset = LC.AnchorSection(contentSection, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    ---------------------------------------------------------------------------
    -- Section: Item Style
    ---------------------------------------------------------------------------
    local styleSection = W.CreateSection(parent, L["Item Style"])
    content = styleSection.content
    innerY = -LC.SECTION_PADDING_TOP

    local slotBgDropdown = W.CreateDropdown(content, {
        label = L["Slot Background"],
        values = SLOT_BG_VALUES,
        get = function()
            return db.profile.appearance.slotBackground
        end,
        set = function(value)
            db.profile.appearance.slotBackground = value
            ApplyLootSettings()
            if RefreshState then
                RefreshState()
            end
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = slotBgDropdown
    innerY = LC.AnchorWidget(slotBgDropdown, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    local intensitySlider = W.CreateSlider(content, {
        label = L["Background Intensity"],
        tooltip = L["Strength of the quality-colored item background"],
        min = 0,
        max = 2,
        step = 0.05,
        isPercent = true,
        get = function()
            return db.profile.lootWindow.backgroundIntensity
        end,
        set = function(value)
            db.profile.lootWindow.backgroundIntensity = value
            ApplyLootSettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = intensitySlider
    innerY = LC.AnchorWidget(intensitySlider, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    local glowToggle = W.CreateToggle(content, {
        label = L["Quality Glow"],
        tooltip = L["Show a quality-colored glow around Rare and better loot icons"],
        get = function()
            return db.profile.lootWindow.qualityGlow
        end,
        set = function(value)
            db.profile.lootWindow.qualityGlow = value
            ApplyLootSettings()
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = glowToggle
    innerY = LC.AnchorWidget(glowToggle, content, innerY) - LC.SPACING_BETWEEN_WIDGETS

    styleSection:SetContentHeight(math_abs(innerY) + LC.SECTION_PADDING_BOTTOM)
    yOffset = LC.AnchorSection(styleSection, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    ---------------------------------------------------------------------------
    -- Section: Behavior
    ---------------------------------------------------------------------------
    local behaviorSection = W.CreateSection(parent, L["Behavior"])
    local behaviorContent = behaviorSection.content
    local behaviorY = -LC.SECTION_PADDING_TOP

    -- Toggle: Lock Position
    local lockToggle = W.CreateToggle(behaviorContent, {
        label = L["Lock Position"],
        tooltip = L["Prevent the loot window from being moved"],
        get = function()
            return db.profile.lootWindow.lock
        end,
        set = function(value)
            db.profile.lootWindow.lock = value
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = lockToggle
    behaviorY = LC.AnchorWidget(lockToggle, behaviorContent, behaviorY) - LC.SPACING_BETWEEN_WIDGETS

    -- Toggle: Position at Cursor
    local cursorToggle = W.CreateToggle(behaviorContent, {
        label = L["Position at Cursor"],
        tooltip = L["Open the loot window at the mouse cursor instead of the saved position"],
        get = function()
            return db.profile.lootWindow.positionAtCursor
        end,
        set = function(value)
            db.profile.lootWindow.positionAtCursor = value
        end,
    })
    layoutWidgets[#layoutWidgets + 1] = cursorToggle
    behaviorY = LC.AnchorWidget(cursorToggle, behaviorContent, behaviorY) - LC.SPACING_BETWEEN_WIDGETS

    behaviorSection:SetContentHeight(math_abs(behaviorY) + LC.SECTION_PADDING_BOTTOM)
    yOffset = LC.AnchorSection(behaviorSection, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    ---------------------------------------------------------------------------
    -- Apply initial disabled state
    ---------------------------------------------------------------------------
    RefreshState = function()
        for _, widget in ipairs(layoutWidgets) do
            widget:SetDisabled(not db.profile.lootWindow.enabled)
        end
        intensitySlider:SetDisabled(not db.profile.lootWindow.enabled or db.profile.appearance.slotBackground == "none")
    end
    RefreshState()

    ---------------------------------------------------------------------------
    -- Set content height for scroll frame
    ---------------------------------------------------------------------------
    parent:SetHeight(math_abs(yOffset) + LC.PADDING_BOTTOM)
end

-------------------------------------------------------------------------------
-- Register tab
-------------------------------------------------------------------------------

ns.Tabs[#ns.Tabs + 1] = {
    id = "lootWindow",
    label = L["Loot Window"],
    order = 2,
    createFunc = CreateContent,
    refreshFunc = function()
        if RefreshState then
            RefreshState()
        end
    end,
}
