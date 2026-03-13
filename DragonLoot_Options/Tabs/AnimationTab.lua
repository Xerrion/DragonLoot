-------------------------------------------------------------------------------
-- AnimationTab.lua
-- Animation settings tab: enable/disable, durations, per-frame animation types
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L
local LC = ns.LayoutConstants

-------------------------------------------------------------------------------
-- Cached globals
-------------------------------------------------------------------------------

local math_abs = math.abs
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
-- Create an animation dropdown for a given db key
-------------------------------------------------------------------------------

local function CreateAnimDropdown(parent, W, db, yOffset, label, key, valuesFn)
    local dropdown = W.CreateDropdown(parent, {
        label = label,
        values = valuesFn,
        get = function() return db.profile.animation[key] end,
        set = function(value)
            db.profile.animation[key] = value
            LC.NotifyAppearanceChange()
        end,
    })
    return LC.AnchorWidget(dropdown, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS
end

-------------------------------------------------------------------------------
-- Build the Animation tab content
-------------------------------------------------------------------------------

local function CreateContent(parent)
    dlns = ns.dlns
    local W = ns.Widgets
    local db = dlns.Addon.db
    local yOffset = LC.PADDING_TOP

    ---------------------------------------------------------------------------
    -- Section: Animation (global toggle + durations)
    ---------------------------------------------------------------------------
    local header = W.CreateHeader(parent, L["Animation"])
    yOffset = LC.AnchorWidget(header, parent, yOffset) - LC.SPACING_AFTER_HEADER

    local enableToggle = W.CreateToggle(parent, {
        label = L["Enable Animations"],
        tooltip = L["Enable or disable all DragonLoot animations"],
        get = function() return db.profile.animation.enabled end,
        set = function(value)
            db.profile.animation.enabled = value
            LC.NotifyAppearanceChange()
        end,
    })
    yOffset = LC.AnchorWidget(enableToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    local openDuration = W.CreateSlider(parent, {
        label = L["Open Duration"],
        tooltip = L["Duration of open/show animations in seconds"],
        min = 0.1,
        max = 1,
        step = 0.05,
        format = "%.2f",
        get = function() return db.profile.animation.openDuration end,
        set = function(value)
            db.profile.animation.openDuration = value
            LC.NotifyAppearanceChange()
        end,
    })
    yOffset = LC.AnchorWidget(openDuration, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    local closeDuration = W.CreateSlider(parent, {
        label = L["Close Duration"],
        tooltip = L["Duration of close/hide animations in seconds"],
        min = 0.1,
        max = 1,
        step = 0.05,
        format = "%.2f",
        get = function() return db.profile.animation.closeDuration end,
        set = function(value)
            db.profile.animation.closeDuration = value
            LC.NotifyAppearanceChange()
        end,
    })
    yOffset = LC.AnchorWidget(closeDuration, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    ---------------------------------------------------------------------------
    -- Section: Loot Window animation types
    ---------------------------------------------------------------------------
    local lootHeader = W.CreateHeader(parent, L["Loot Window"])
    yOffset = LC.AnchorWidget(lootHeader, parent, yOffset) - LC.SPACING_AFTER_HEADER

    yOffset = CreateAnimDropdown(
        parent, W, db, yOffset, L["Open Animation"], "lootOpenAnim", GetEntranceValues
    )
    yOffset = CreateAnimDropdown(
        parent, W, db, yOffset, L["Close Animation"], "lootCloseAnim", GetExitValues
    )

    -- Extra section spacing before next header
    yOffset = yOffset - LC.SPACING_BETWEEN_SECTIONS + LC.SPACING_BETWEEN_WIDGETS

    ---------------------------------------------------------------------------
    -- Section: Roll Frame animation types
    ---------------------------------------------------------------------------
    local rollHeader = W.CreateHeader(parent, L["Roll Frame"])
    yOffset = LC.AnchorWidget(rollHeader, parent, yOffset) - LC.SPACING_AFTER_HEADER

    yOffset = CreateAnimDropdown(
        parent, W, db, yOffset, L["Show Animation"], "rollShowAnim", GetEntranceValues
    )
    yOffset = CreateAnimDropdown(
        parent, W, db, yOffset, L["Hide Animation"], "rollHideAnim", GetExitValues
    )

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
    id = "animation",
    label = L["Animation"],
    order = 7,
    createFunc = CreateContent,
}
