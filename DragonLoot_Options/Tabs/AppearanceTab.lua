-------------------------------------------------------------------------------
-- AppearanceTab.lua
-- Appearance settings tab: font, icons, background, border
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
-- Font outline dropdown values
-------------------------------------------------------------------------------

local FONT_OUTLINE_VALUES = {
    { value = "", text = L["None"] },
    { value = "OUTLINE", text = L["Outline"] },
    { value = "THICKOUTLINE", text = L["Thick Outline"] },
    { value = "MONOCHROME", text = L["Monochrome"] },
}

-------------------------------------------------------------------------------
-- Slot background dropdown values
-------------------------------------------------------------------------------

local SLOT_BG_VALUES = {
    { value = "gradient", text = L["Gradient"] },
    { value = "flat", text = L["Flat"] },
    { value = "stripe", text = L["Stripe"] },
    { value = "none", text = L["None"] },
}

-------------------------------------------------------------------------------
-- Section builders
-------------------------------------------------------------------------------

local function CreateFontSection(scrollChild, stack, db)
    local section = LDF.CreateSection(scrollChild, L["Font"], { columns = 1 })

    local sectionStack = LDF.CreateStackLayout(section.content)
    sectionStack:SetPoint("TOPLEFT", section.content, "TOPLEFT")
    sectionStack:SetPoint("RIGHT", section.content, "RIGHT")
    sectionStack:HookScript("OnSizeChanged", function(_, _, h)
        section.content:SetHeight(h)
    end)

    local fontDropdown = LDF.CreateDropdown(section.content, {
        label = L["Font Family"],
        values = function() return ns.BuildLSMValues("font") end,
        sort = true,
        mediaType = "font",
        get = function() return db.profile.appearance.font end,
        set = function(value)
            db.profile.appearance.font = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(fontDropdown)

    local fontSizeSlider = LDF.CreateSlider(section.content, {
        label = L["Font Size"],
        tooltip = L["Base font size for all DragonLoot frames"],
        min = 8,
        max = 20,
        step = 1,
        format = "%d",
        get = function() return db.profile.appearance.fontSize end,
        set = function(value)
            db.profile.appearance.fontSize = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(fontSizeSlider)

    local outlineDropdown = LDF.CreateDropdown(section.content, {
        label = L["Font Outline"],
        values = FONT_OUTLINE_VALUES,
        get = function() return db.profile.appearance.fontOutline end,
        set = function(value)
            db.profile.appearance.fontOutline = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(outlineDropdown)

    stack:AddChild(section)
end

local function CreateIconSection(scrollChild, stack, db)
    local section = LDF.CreateSection(scrollChild, L["Icon Sizes"], { columns = 1 })

    local sectionStack = LDF.CreateStackLayout(section.content)
    sectionStack:SetPoint("TOPLEFT", section.content, "TOPLEFT")
    sectionStack:SetPoint("RIGHT", section.content, "RIGHT")
    sectionStack:HookScript("OnSizeChanged", function(_, _, h)
        section.content:SetHeight(h)
    end)

    local lootIconSlider = LDF.CreateSlider(section.content, {
        label = L["Loot Icon Size"],
        tooltip = L["Icon size in the loot window"],
        min = 16,
        max = 64,
        step = 2,
        format = "%d",
        get = function() return db.profile.appearance.lootIconSize end,
        set = function(value)
            db.profile.appearance.lootIconSize = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(lootIconSlider)

    local rollIconSlider = LDF.CreateSlider(section.content, {
        label = L["Roll Icon Size"],
        tooltip = L["Icon size in the roll frame"],
        min = 16,
        max = 64,
        step = 2,
        format = "%d",
        get = function() return db.profile.appearance.rollIconSize end,
        set = function(value)
            db.profile.appearance.rollIconSize = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(rollIconSlider)

    local historyIconSlider = LDF.CreateSlider(section.content, {
        label = L["History Icon Size"],
        tooltip = L["Icon size in the history frame"],
        min = 16,
        max = 48,
        step = 2,
        format = "%d",
        get = function() return db.profile.appearance.historyIconSize end,
        set = function(value)
            db.profile.appearance.historyIconSize = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(historyIconSlider)

    local qualityBorderToggle = LDF.CreateToggle(section.content, {
        label = L["Quality Border"],
        tooltip = L["Show quality-colored borders on item icons"],
        get = function() return db.profile.appearance.qualityBorder end,
        set = function(value)
            db.profile.appearance.qualityBorder = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(qualityBorderToggle)

    local slotBgDropdown = LDF.CreateDropdown(section.content, {
        label = L["Slot Background"],
        values = SLOT_BG_VALUES,
        get = function() return db.profile.appearance.slotBackground end,
        set = function(value)
            db.profile.appearance.slotBackground = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(slotBgDropdown)

    stack:AddChild(section)
end

local function CreateBackgroundSection(scrollChild, stack, db)
    local section = LDF.CreateSection(scrollChild, L["Background"], { columns = 1 })

    local sectionStack = LDF.CreateStackLayout(section.content)
    sectionStack:SetPoint("TOPLEFT", section.content, "TOPLEFT")
    sectionStack:SetPoint("RIGHT", section.content, "RIGHT")
    sectionStack:HookScript("OnSizeChanged", function(_, _, h)
        section.content:SetHeight(h)
    end)

    local bgColorPicker = LDF.CreateColorPicker(section.content, {
        label = L["Background Color"],
        hasAlpha = false,
        get = function()
            local c = db.profile.appearance.backgroundColor
            return c.r, c.g, c.b
        end,
        set = function(r, g, b)
            db.profile.appearance.backgroundColor.r = r
            db.profile.appearance.backgroundColor.g = g
            db.profile.appearance.backgroundColor.b = b
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(bgColorPicker)

    local bgAlphaSlider = LDF.CreateSlider(section.content, {
        label = L["Background Opacity"],
        tooltip = L["Opacity of the frame background"],
        min = 0,
        max = 1,
        step = 0.05,
        isPercent = true,
        get = function() return db.profile.appearance.backgroundAlpha end,
        set = function(value)
            db.profile.appearance.backgroundAlpha = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(bgAlphaSlider)

    local bgTextureDropdown = LDF.CreateDropdown(section.content, {
        label = L["Background Texture"],
        values = function() return ns.BuildLSMValues("background") end,
        sort = true,
        mediaType = "background",
        get = function() return db.profile.appearance.backgroundTexture end,
        set = function(value)
            db.profile.appearance.backgroundTexture = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(bgTextureDropdown)

    stack:AddChild(section)
end

local function CreateBorderSection(scrollChild, stack, db)
    local section = LDF.CreateSection(scrollChild, L["Border"], { columns = 1 })

    local sectionStack = LDF.CreateStackLayout(section.content)
    sectionStack:SetPoint("TOPLEFT", section.content, "TOPLEFT")
    sectionStack:SetPoint("RIGHT", section.content, "RIGHT")
    sectionStack:HookScript("OnSizeChanged", function(_, _, h)
        section.content:SetHeight(h)
    end)

    local borderColorPicker = LDF.CreateColorPicker(section.content, {
        label = L["Border Color"],
        hasAlpha = false,
        get = function()
            local c = db.profile.appearance.borderColor
            return c.r, c.g, c.b
        end,
        set = function(r, g, b)
            db.profile.appearance.borderColor.r = r
            db.profile.appearance.borderColor.g = g
            db.profile.appearance.borderColor.b = b
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(borderColorPicker)

    local borderSizeSlider = LDF.CreateSlider(section.content, {
        label = L["Border Size"],
        tooltip = L["Thickness of the frame border"],
        min = 0,
        max = 4,
        step = 1,
        format = "%d",
        get = function() return db.profile.appearance.borderSize end,
        set = function(value)
            db.profile.appearance.borderSize = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(borderSizeSlider)

    local borderTextureDropdown = LDF.CreateDropdown(section.content, {
        label = L["Border Texture"],
        values = function() return ns.BuildLSMValues("border") end,
        sort = true,
        mediaType = "border",
        get = function() return db.profile.appearance.borderTexture end,
        set = function(value)
            db.profile.appearance.borderTexture = value
            ns.NotifyAppearanceChange()
        end,
    })
    sectionStack:AddChild(borderTextureDropdown)

    stack:AddChild(section)
end

-------------------------------------------------------------------------------
-- Build the Appearance tab content
-------------------------------------------------------------------------------

local function CreateContent(scrollChild)
    dlns = ns.dlns
    local db = dlns.Addon.db

    local stack = LDF.CreateStackLayout(scrollChild)
    stack:SetPoint("TOPLEFT", scrollChild, "TOPLEFT")
    stack:SetPoint("RIGHT", scrollChild, "RIGHT")

    CreateFontSection(scrollChild, stack, db)
    CreateIconSection(scrollChild, stack, db)
    CreateBackgroundSection(scrollChild, stack, db)
    CreateBorderSection(scrollChild, stack, db)
end

-------------------------------------------------------------------------------
-- Register tab
-------------------------------------------------------------------------------

ns.Tabs = ns.Tabs or {}
ns.Tabs[#ns.Tabs + 1] = {
    id = "appearance",
    label = L["Appearance"],
    order = 6,
    createFunc = CreateContent,
}
