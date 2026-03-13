-------------------------------------------------------------------------------
-- LootRollTab.lua
-- Loot Roll settings tab: roll frame layout, notifications, instance filters
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local ADDON_NAME, ns = ...
local L = ns.L

-------------------------------------------------------------------------------
-- Cached globals
-------------------------------------------------------------------------------

local math_abs = math.abs
local tostring = tostring
local tonumber = tonumber

-------------------------------------------------------------------------------
-- Namespace references
-------------------------------------------------------------------------------

local dlns

-------------------------------------------------------------------------------
-- Notify roll manager helper
-------------------------------------------------------------------------------

local function NotifyRollManager()
    if dlns.RollManager and dlns.RollManager.ApplySettings then
        dlns.RollManager.ApplySettings()
    end
end

-------------------------------------------------------------------------------
-- Section: Roll Frame (basic settings)
-------------------------------------------------------------------------------

local function CreateRollFrameSection(parent, W, db, yOffset, LC)
    local header = W.CreateHeader(parent, L["Roll Frame"])
    yOffset = LC.AnchorWidget(header, parent, yOffset) - LC.SPACING_AFTER_HEADER

    local enableToggle = W.CreateToggle(parent, {
        label = L["Enable Custom Roll Frame"],
        tooltip = L["Replace the default Blizzard roll frame with DragonLoot's custom version"],
        get = function() return db.profile.rollFrame.enabled end,
        set = function(value)
            db.profile.rollFrame.enabled = value
            NotifyRollManager()
        end,
    })
    yOffset = LC.AnchorWidget(enableToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    local lockToggle = W.CreateToggle(parent, {
        label = L["Lock Position"],
        tooltip = L["Prevent the roll frame from being dragged"],
        get = function() return db.profile.rollFrame.lock end,
        set = function(value) db.profile.rollFrame.lock = value end,
    })
    yOffset = LC.AnchorWidget(lockToggle, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    return yOffset
end

-------------------------------------------------------------------------------
-- Section: Layout (sliders + texture dropdown)
-------------------------------------------------------------------------------

local function CreateLayoutSlider(parent, W, db, yOffset, LC, label, tooltip, key, min, max, step, fmt)
    local slider = W.CreateSlider(parent, {
        label = label,
        tooltip = tooltip,
        min = min,
        max = max,
        step = step,
        format = fmt,
        get = function() return db.profile.rollFrame[key] end,
        set = function(value)
            db.profile.rollFrame[key] = value
            NotifyRollManager()
        end,
    })
    yOffset = LC.AnchorWidget(slider, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS
    return yOffset
end

local function CreateLayoutSection(parent, W, db, yOffset, LC)
    local header = W.CreateHeader(parent, L["Layout"])
    yOffset = LC.AnchorWidget(header, parent, yOffset) - LC.SPACING_AFTER_HEADER

    yOffset = CreateLayoutSlider(parent, W, db, yOffset, LC,
        L["Scale"], L["Roll frame scale"], "scale", 0.5, 2, 0.05, "%.2f")
    yOffset = CreateLayoutSlider(parent, W, db, yOffset, LC,
        L["Frame Width"], L["Width of the roll frame"], "frameWidth", 200, 500, 10, "%d")
    yOffset = CreateLayoutSlider(parent, W, db, yOffset, LC,
        L["Row Spacing"], L["Vertical spacing between roll rows"], "rowSpacing", 0, 16, 1, "%d")
    yOffset = CreateLayoutSlider(parent, W, db, yOffset, LC,
        L["Timer Bar Height"], L["Height of the countdown timer bar"], "timerBarHeight", 6, 24, 1, "%d")
    yOffset = CreateLayoutSlider(parent, W, db, yOffset, LC,
        L["Timer Bar Spacing"], L["Space between item row and timer bar"], "timerBarSpacing", 0, 16, 1, "%d")
    yOffset = CreateLayoutSlider(parent, W, db, yOffset, LC,
        L["Content Padding"], L["Inner padding of the roll frame"], "contentPadding", 0, 12, 1, "%d")
    yOffset = CreateLayoutSlider(parent, W, db, yOffset, LC,
        L["Button Size"], L["Size of Need/Greed/Pass buttons"], "buttonSize", 16, 36, 1, "%d")
    yOffset = CreateLayoutSlider(parent, W, db, yOffset, LC,
        L["Button Spacing"], L["Spacing between roll buttons"], "buttonSpacing", 0, 12, 1, "%d")
    yOffset = CreateLayoutSlider(parent, W, db, yOffset, LC,
        L["Frame Spacing"], L["Spacing between multiple roll frames"], "frameSpacing", 0, 16, 1, "%d")

    local textureDropdown = W.CreateDropdown(parent, {
        label = L["Timer Bar Texture"],
        values = function() return LC.BuildLSMValues("statusbar") end,
        sort = true,
        mediaType = "statusbar",
        get = function() return db.profile.rollFrame.timerBarTexture end,
        set = function(value)
            db.profile.rollFrame.timerBarTexture = value
            NotifyRollManager()
        end,
    })
    yOffset = LC.AnchorWidget(textureDropdown, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    return yOffset
end

-------------------------------------------------------------------------------
-- Section: Roll Notifications
-------------------------------------------------------------------------------

local function CreateNotificationSection(parent, W, db, yOffset, LC)
    local header = W.CreateHeader(parent, L["Roll Notifications"])
    yOffset = LC.AnchorWidget(header, parent, yOffset) - LC.SPACING_AFTER_HEADER

    -- Forward declarations for cross-widget disable logic
    local groupWinsToggle, selfRollsToggle, groupRollsToggle

    local showRollWon = W.CreateToggle(parent, {
        label = L["Show Roll Won"],
        tooltip = L["Show a notification when someone wins a roll"],
        get = function() return db.profile.rollNotifications.showRollWon end,
        set = function(value)
            db.profile.rollNotifications.showRollWon = value
            if groupWinsToggle then groupWinsToggle:SetDisabled(not value) end
        end,
    })
    yOffset = LC.AnchorWidget(showRollWon, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    groupWinsToggle = W.CreateToggle(parent, {
        label = L["Show Group Wins"],
        tooltip = L["Show notifications when other group members win rolls"],
        get = function() return db.profile.rollNotifications.showGroupWins end,
        set = function(value) db.profile.rollNotifications.showGroupWins = value end,
        disabled = not db.profile.rollNotifications.showRollWon,
    })
    yOffset = LC.AnchorWidget(groupWinsToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    local showRollResults = W.CreateToggle(parent, {
        label = L["Show Roll Results"],
        tooltip = L["Show individual roll result notifications"],
        get = function() return db.profile.rollNotifications.showRollResults end,
        set = function(value)
            db.profile.rollNotifications.showRollResults = value
            if selfRollsToggle then selfRollsToggle:SetDisabled(not value) end
            if groupRollsToggle then groupRollsToggle:SetDisabled(not value) end
        end,
    })
    yOffset = LC.AnchorWidget(showRollResults, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    selfRollsToggle = W.CreateToggle(parent, {
        label = L["Show My Rolls"],
        tooltip = L["Show notifications for your own roll results"],
        get = function() return db.profile.rollNotifications.showSelfRolls end,
        set = function(value) db.profile.rollNotifications.showSelfRolls = value end,
        disabled = not db.profile.rollNotifications.showRollResults,
    })
    yOffset = LC.AnchorWidget(selfRollsToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    groupRollsToggle = W.CreateToggle(parent, {
        label = L["Show Group Rolls"],
        tooltip = L["Show notifications for other group members' roll results"],
        get = function() return db.profile.rollNotifications.showGroupRolls end,
        set = function(value) db.profile.rollNotifications.showGroupRolls = value end,
        disabled = not db.profile.rollNotifications.showRollResults,
    })
    yOffset = LC.AnchorWidget(groupRollsToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    local qualityDropdown = W.CreateDropdown(parent, {
        label = L["Minimum Quality"],
        values = ns.QualityValues,
        get = function() return tostring(db.profile.rollNotifications.minQuality) end,
        set = function(value) db.profile.rollNotifications.minQuality = tonumber(value) or 0 end,
    })
    yOffset = LC.AnchorWidget(qualityDropdown, parent, yOffset) - LC.SPACING_BETWEEN_SECTIONS

    return yOffset
end

-------------------------------------------------------------------------------
-- Section: Instance Filters
-------------------------------------------------------------------------------

local function CreateInstanceFilterSection(parent, W, db, yOffset, LC)
    local header = W.CreateHeader(parent, L["Instance Filters"])
    yOffset = LC.AnchorWidget(header, parent, yOffset) - LC.SPACING_AFTER_HEADER

    local worldToggle = W.CreateToggle(parent, {
        label = L["Show in Open World"],
        tooltip = L["Show roll notifications while in the open world"],
        get = function() return db.profile.rollNotifications.showInWorld end,
        set = function(value) db.profile.rollNotifications.showInWorld = value end,
    })
    yOffset = LC.AnchorWidget(worldToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    local dungeonToggle = W.CreateToggle(parent, {
        label = L["Show in Dungeons"],
        tooltip = L["Show roll notifications while in dungeons"],
        get = function() return db.profile.rollNotifications.showInDungeon end,
        set = function(value) db.profile.rollNotifications.showInDungeon = value end,
    })
    yOffset = LC.AnchorWidget(dungeonToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    local raidToggle = W.CreateToggle(parent, {
        label = L["Show in Raids"],
        tooltip = L["Show roll notifications while in raids"],
        get = function() return db.profile.rollNotifications.showInRaid end,
        set = function(value) db.profile.rollNotifications.showInRaid = value end,
    })
    yOffset = LC.AnchorWidget(raidToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    return yOffset
end

-------------------------------------------------------------------------------
-- Build the Loot Roll tab content
-------------------------------------------------------------------------------

local function CreateContent(parent)
    dlns = ns.dlns
    local LC = ns.LayoutConstants
    local W = ns.Widgets
    local db = dlns.Addon.db
    local yOffset = LC.PADDING_TOP

    yOffset = CreateRollFrameSection(parent, W, db, yOffset, LC)
    yOffset = CreateLayoutSection(parent, W, db, yOffset, LC)
    yOffset = CreateNotificationSection(parent, W, db, yOffset, LC)
    yOffset = CreateInstanceFilterSection(parent, W, db, yOffset, LC)

    parent:SetHeight(math_abs(yOffset) + LC.PADDING_BOTTOM)
end

-------------------------------------------------------------------------------
-- Register tab
-------------------------------------------------------------------------------

ns.Tabs = ns.Tabs or {}
ns.Tabs[#ns.Tabs + 1] = {
    id = "lootRoll",
    label = L["Loot Roll"],
    order = 3,
    createFunc = CreateContent,
}
