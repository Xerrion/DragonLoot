-------------------------------------------------------------------------------
-- AnimationTab.lua
-- Animation settings tab: enable/disable, durations, per-frame animation types
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local LDF = LibDragonFramework

-------------------------------------------------------------------------------
-- Cached globals
-------------------------------------------------------------------------------

local ipairs = ipairs
local LibStub = LibStub

-------------------------------------------------------------------------------
-- Namespace references
-------------------------------------------------------------------------------

local dlns

-------------------------------------------------------------------------------
-- Build entrance/exit animation name values from LibAnimate
-------------------------------------------------------------------------------

local function GetEntranceValues()
    local lib = LibStub("LibAnimate", true)
    if not lib then return {} end
    local names = lib:GetEntranceAnimations()
    local values = { { value = "none", text = L["None"] } }
    for _, name in ipairs(names) do
        values[#values + 1] = { value = name, text = name }
    end
    return values
end

local function GetExitValues()
    local lib = LibStub("LibAnimate", true)
    if not lib then return {} end
    local names = lib:GetExitAnimations()
    local values = { { value = "none", text = L["None"] } }
    for _, name in ipairs(names) do
        values[#values + 1] = { value = name, text = name }
    end
    return values
end

-------------------------------------------------------------------------------
-- Build the Animation tab content
-------------------------------------------------------------------------------

local function CreateContent(scrollChild)
    dlns = ns.dlns
    local db = dlns.Addon.db

    local stack = LDF.CreateStackLayout(scrollChild)
    stack:SetPoint("TOPLEFT", scrollChild, "TOPLEFT")
    stack:SetPoint("RIGHT", scrollChild, "RIGHT")

    ---------------------------------------------------------------------------
    -- Section: Animation (global toggle + durations)
    ---------------------------------------------------------------------------

    local animSection = LDF.CreateSection(scrollChild, L["Animation"], { columns = 1 })

    local animStack = LDF.CreateStackLayout(animSection.content)
    animStack:SetPoint("TOPLEFT", animSection.content, "TOPLEFT")
    animStack:SetPoint("RIGHT", animSection.content, "RIGHT")
    animStack:HookScript("OnSizeChanged", function(_, _, h)
        animSection.content:SetHeight(h)
    end)

    -- Toggle: Enable Animations
    local enableToggle = LDF.CreateToggle(animSection.content, {
        label = L["Enable Animations"],
        tooltip = L["Enable or disable all DragonLoot animations"],
        get = function() return db.profile.animation.enabled end,
        set = function(value)
            db.profile.animation.enabled = value
            ns.NotifyAppearanceChange()
        end,
    })
    animStack:AddChild(enableToggle)

    -- Slider: Open Duration
    local openDuration = LDF.CreateSlider(animSection.content, {
        label = L["Open Duration"],
        tooltip = L["Duration of open/show animations in seconds"],
        min = 0.1, max = 1, step = 0.05,
        format = "%.2f",
        get = function() return db.profile.animation.openDuration end,
        set = function(value)
            db.profile.animation.openDuration = value
            ns.NotifyAppearanceChange()
        end,
    })
    animStack:AddChild(openDuration)

    -- Slider: Close Duration
    local closeDuration = LDF.CreateSlider(animSection.content, {
        label = L["Close Duration"],
        tooltip = L["Duration of close/hide animations in seconds"],
        min = 0.1, max = 1, step = 0.05,
        format = "%.2f",
        get = function() return db.profile.animation.closeDuration end,
        set = function(value)
            db.profile.animation.closeDuration = value
            ns.NotifyAppearanceChange()
        end,
    })
    animStack:AddChild(closeDuration)

    stack:AddChild(animSection)

    ---------------------------------------------------------------------------
    -- Section: Loot Window (animation type selection)
    ---------------------------------------------------------------------------

    local lootSection = LDF.CreateSection(scrollChild, L["Loot Window"], { columns = 1 })

    local lootStack = LDF.CreateStackLayout(lootSection.content)
    lootStack:SetPoint("TOPLEFT", lootSection.content, "TOPLEFT")
    lootStack:SetPoint("RIGHT", lootSection.content, "RIGHT")
    lootStack:HookScript("OnSizeChanged", function(_, _, h)
        lootSection.content:SetHeight(h)
    end)

    -- Dropdown: Open Animation
    local lootOpenDropdown = LDF.CreateDropdown(lootSection.content, {
        label = L["Open Animation"],
        values = GetEntranceValues,
        get = function() return db.profile.animation.lootOpenAnim end,
        set = function(value)
            db.profile.animation.lootOpenAnim = value
            ns.NotifyAppearanceChange()
        end,
    })
    lootStack:AddChild(lootOpenDropdown)

    -- Dropdown: Close Animation
    local lootCloseDropdown = LDF.CreateDropdown(lootSection.content, {
        label = L["Close Animation"],
        values = GetExitValues,
        get = function() return db.profile.animation.lootCloseAnim end,
        set = function(value)
            db.profile.animation.lootCloseAnim = value
            ns.NotifyAppearanceChange()
        end,
    })
    lootStack:AddChild(lootCloseDropdown)

    stack:AddChild(lootSection)

    ---------------------------------------------------------------------------
    -- Section: Roll Frame (animation type selection)
    ---------------------------------------------------------------------------

    local rollSection = LDF.CreateSection(scrollChild, L["Roll Frame"], { columns = 1 })

    local rollStack = LDF.CreateStackLayout(rollSection.content)
    rollStack:SetPoint("TOPLEFT", rollSection.content, "TOPLEFT")
    rollStack:SetPoint("RIGHT", rollSection.content, "RIGHT")
    rollStack:HookScript("OnSizeChanged", function(_, _, h)
        rollSection.content:SetHeight(h)
    end)

    -- Dropdown: Show Animation
    local rollShowDropdown = LDF.CreateDropdown(rollSection.content, {
        label = L["Show Animation"],
        values = GetEntranceValues,
        get = function() return db.profile.animation.rollShowAnim end,
        set = function(value)
            db.profile.animation.rollShowAnim = value
            ns.NotifyAppearanceChange()
        end,
    })
    rollStack:AddChild(rollShowDropdown)

    -- Dropdown: Hide Animation
    local rollHideDropdown = LDF.CreateDropdown(rollSection.content, {
        label = L["Hide Animation"],
        values = GetExitValues,
        get = function() return db.profile.animation.rollHideAnim end,
        set = function(value)
            db.profile.animation.rollHideAnim = value
            ns.NotifyAppearanceChange()
        end,
    })
    rollStack:AddChild(rollHideDropdown)

    stack:AddChild(rollSection)
end

-------------------------------------------------------------------------------
-- Register tab
-------------------------------------------------------------------------------

ns.Tabs = ns.Tabs or {}
ns.Tabs[#ns.Tabs + 1] = {
    id = "animation",
    label = L["Animation"],
    order = 7,
    createFunc = CreateContent,
}
