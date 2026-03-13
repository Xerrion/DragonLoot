-------------------------------------------------------------------------------
-- LootRollTab.lua
-- Loot Roll settings tab: roll frame layout, notifications, instance filters
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
-- Notify roll manager helper
-------------------------------------------------------------------------------

local function NotifyRollManager()
    if dlns.RollManager and dlns.RollManager.ApplySettings then
        dlns.RollManager.ApplySettings()
    end
end

-------------------------------------------------------------------------------
-- Build the Loot Roll tab content
-------------------------------------------------------------------------------

local function CreateContent(scrollChild)
    dlns = ns.dlns
    local db = dlns.Addon.db

    local stack = LDF.CreateStackLayout(scrollChild)
    stack:SetPoint("TOPLEFT", scrollChild, "TOPLEFT")
    stack:SetPoint("RIGHT", scrollChild, "RIGHT")

    ---------------------------------------------------------------------------
    -- Section: Roll Frame (basic settings)
    ---------------------------------------------------------------------------

    local rollSection = LDF.CreateSection(scrollChild, L["Roll Frame"], { columns = 1 })

    local rollStack = LDF.CreateStackLayout(rollSection.content)
    rollStack:SetPoint("TOPLEFT", rollSection.content, "TOPLEFT")
    rollStack:SetPoint("RIGHT", rollSection.content, "RIGHT")
    rollStack:HookScript("OnSizeChanged", function(_, _, h)
        rollSection.content:SetHeight(h)
    end)

    local enableToggle = LDF.CreateToggle(rollSection.content, {
        label = L["Enable Custom Roll Frame"],
        tooltip = L["Replace the default Blizzard roll frame with DragonLoot's custom version"],
        get = function() return db.profile.rollFrame.enabled end,
        set = function(value)
            db.profile.rollFrame.enabled = value
            NotifyRollManager()
        end,
    })
    rollStack:AddChild(enableToggle)

    local lockToggle = LDF.CreateToggle(rollSection.content, {
        label = L["Lock Position"],
        tooltip = L["Prevent the roll frame from being dragged"],
        get = function() return db.profile.rollFrame.lock end,
        set = function(value) db.profile.rollFrame.lock = value end,
    })
    rollStack:AddChild(lockToggle)

    stack:AddChild(rollSection)

    ---------------------------------------------------------------------------
    -- Section: Layout (sliders + texture dropdown)
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
        tooltip = L["Roll frame scale"],
        min = 0.5, max = 2, step = 0.05,
        format = "%.2f",
        get = function() return db.profile.rollFrame.scale end,
        set = function(value)
            db.profile.rollFrame.scale = value
            NotifyRollManager()
        end,
    })
    layoutStack:AddChild(scaleSlider)

    local frameWidthSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Frame Width"],
        tooltip = L["Width of the roll frame"],
        min = 200, max = 500, step = 10,
        format = "%d",
        get = function() return db.profile.rollFrame.frameWidth end,
        set = function(value)
            db.profile.rollFrame.frameWidth = value
            NotifyRollManager()
        end,
    })
    layoutStack:AddChild(frameWidthSlider)

    local rowSpacingSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Row Spacing"],
        tooltip = L["Vertical spacing between roll rows"],
        min = 0, max = 16, step = 1,
        format = "%d",
        get = function() return db.profile.rollFrame.rowSpacing end,
        set = function(value)
            db.profile.rollFrame.rowSpacing = value
            NotifyRollManager()
        end,
    })
    layoutStack:AddChild(rowSpacingSlider)

    local timerBarHeightSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Timer Bar Height"],
        tooltip = L["Height of the countdown timer bar"],
        min = 6, max = 24, step = 1,
        format = "%d",
        get = function() return db.profile.rollFrame.timerBarHeight end,
        set = function(value)
            db.profile.rollFrame.timerBarHeight = value
            NotifyRollManager()
        end,
    })
    layoutStack:AddChild(timerBarHeightSlider)

    local timerBarSpacingSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Timer Bar Spacing"],
        tooltip = L["Space between item row and timer bar"],
        min = 0, max = 16, step = 1,
        format = "%d",
        get = function() return db.profile.rollFrame.timerBarSpacing end,
        set = function(value)
            db.profile.rollFrame.timerBarSpacing = value
            NotifyRollManager()
        end,
    })
    layoutStack:AddChild(timerBarSpacingSlider)

    local contentPaddingSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Content Padding"],
        tooltip = L["Inner padding of the roll frame"],
        min = 0, max = 12, step = 1,
        format = "%d",
        get = function() return db.profile.rollFrame.contentPadding end,
        set = function(value)
            db.profile.rollFrame.contentPadding = value
            NotifyRollManager()
        end,
    })
    layoutStack:AddChild(contentPaddingSlider)

    local buttonSizeSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Button Size"],
        tooltip = L["Size of Need/Greed/Pass buttons"],
        min = 16, max = 36, step = 1,
        format = "%d",
        get = function() return db.profile.rollFrame.buttonSize end,
        set = function(value)
            db.profile.rollFrame.buttonSize = value
            NotifyRollManager()
        end,
    })
    layoutStack:AddChild(buttonSizeSlider)

    local buttonSpacingSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Button Spacing"],
        tooltip = L["Spacing between roll buttons"],
        min = 0, max = 12, step = 1,
        format = "%d",
        get = function() return db.profile.rollFrame.buttonSpacing end,
        set = function(value)
            db.profile.rollFrame.buttonSpacing = value
            NotifyRollManager()
        end,
    })
    layoutStack:AddChild(buttonSpacingSlider)

    local frameSpacingSlider = LDF.CreateSlider(layoutSection.content, {
        label = L["Frame Spacing"],
        tooltip = L["Spacing between multiple roll frames"],
        min = 0, max = 16, step = 1,
        format = "%d",
        get = function() return db.profile.rollFrame.frameSpacing end,
        set = function(value)
            db.profile.rollFrame.frameSpacing = value
            NotifyRollManager()
        end,
    })
    layoutStack:AddChild(frameSpacingSlider)

    local textureDropdown = LDF.CreateDropdown(layoutSection.content, {
        label = L["Timer Bar Texture"],
        values = function() return ns.BuildLSMValues("statusbar") end,
        sort = true,
        mediaType = "statusbar",
        get = function() return db.profile.rollFrame.timerBarTexture end,
        set = function(value)
            db.profile.rollFrame.timerBarTexture = value
            NotifyRollManager()
        end,
    })
    layoutStack:AddChild(textureDropdown)

    stack:AddChild(layoutSection)

    ---------------------------------------------------------------------------
    -- Section: Roll Notifications (cross-widget disable logic)
    ---------------------------------------------------------------------------

    local notifSection = LDF.CreateSection(scrollChild, L["Roll Notifications"], { columns = 1 })

    local notifStack = LDF.CreateStackLayout(notifSection.content)
    notifStack:SetPoint("TOPLEFT", notifSection.content, "TOPLEFT")
    notifStack:SetPoint("RIGHT", notifSection.content, "RIGHT")
    notifStack:HookScript("OnSizeChanged", function(_, _, h)
        notifSection.content:SetHeight(h)
    end)

    -- Forward declarations for cross-widget enable/disable logic
    local groupWinsToggle, selfRollsToggle, groupRollsToggle

    local showRollWon = LDF.CreateToggle(notifSection.content, {
        label = L["Show Roll Won"],
        tooltip = L["Show a notification when someone wins a roll"],
        get = function() return db.profile.rollNotifications.showRollWon end,
        set = function(value)
            db.profile.rollNotifications.showRollWon = value
            if groupWinsToggle then groupWinsToggle:SetEnabled(value) end
        end,
    })
    notifStack:AddChild(showRollWon)

    groupWinsToggle = LDF.CreateToggle(notifSection.content, {
        label = L["Show Group Wins"],
        tooltip = L["Show notifications when other group members win rolls"],
        get = function() return db.profile.rollNotifications.showGroupWins end,
        set = function(value) db.profile.rollNotifications.showGroupWins = value end,
    })
    notifStack:AddChild(groupWinsToggle)
    groupWinsToggle:SetEnabled(db.profile.rollNotifications.showRollWon)

    local showRollResults = LDF.CreateToggle(notifSection.content, {
        label = L["Show Roll Results"],
        tooltip = L["Show individual roll result notifications"],
        get = function() return db.profile.rollNotifications.showRollResults end,
        set = function(value)
            db.profile.rollNotifications.showRollResults = value
            if selfRollsToggle then selfRollsToggle:SetEnabled(value) end
            if groupRollsToggle then groupRollsToggle:SetEnabled(value) end
        end,
    })
    notifStack:AddChild(showRollResults)

    selfRollsToggle = LDF.CreateToggle(notifSection.content, {
        label = L["Show My Rolls"],
        tooltip = L["Show notifications for your own roll results"],
        get = function() return db.profile.rollNotifications.showSelfRolls end,
        set = function(value) db.profile.rollNotifications.showSelfRolls = value end,
    })
    notifStack:AddChild(selfRollsToggle)
    selfRollsToggle:SetEnabled(db.profile.rollNotifications.showRollResults)

    groupRollsToggle = LDF.CreateToggle(notifSection.content, {
        label = L["Show Group Rolls"],
        tooltip = L["Show notifications for other group members' roll results"],
        get = function() return db.profile.rollNotifications.showGroupRolls end,
        set = function(value) db.profile.rollNotifications.showGroupRolls = value end,
    })
    notifStack:AddChild(groupRollsToggle)
    groupRollsToggle:SetEnabled(db.profile.rollNotifications.showRollResults)

    local qualityDropdown = LDF.CreateDropdown(notifSection.content, {
        label = L["Minimum Quality"],
        values = ns.QualityValues,
        get = function() return tostring(db.profile.rollNotifications.minQuality) end,
        set = function(value) db.profile.rollNotifications.minQuality = tonumber(value) or 0 end,
    })
    notifStack:AddChild(qualityDropdown)

    stack:AddChild(notifSection)

    ---------------------------------------------------------------------------
    -- Section: Instance Filters
    ---------------------------------------------------------------------------

    local filterSection = LDF.CreateSection(scrollChild, L["Instance Filters"], { columns = 1 })

    local filterStack = LDF.CreateStackLayout(filterSection.content)
    filterStack:SetPoint("TOPLEFT", filterSection.content, "TOPLEFT")
    filterStack:SetPoint("RIGHT", filterSection.content, "RIGHT")
    filterStack:HookScript("OnSizeChanged", function(_, _, h)
        filterSection.content:SetHeight(h)
    end)

    local worldToggle = LDF.CreateToggle(filterSection.content, {
        label = L["Show in Open World"],
        tooltip = L["Show roll notifications while in the open world"],
        get = function() return db.profile.rollNotifications.showInWorld end,
        set = function(value) db.profile.rollNotifications.showInWorld = value end,
    })
    filterStack:AddChild(worldToggle)

    local dungeonToggle = LDF.CreateToggle(filterSection.content, {
        label = L["Show in Dungeons"],
        tooltip = L["Show roll notifications while in dungeons"],
        get = function() return db.profile.rollNotifications.showInDungeon end,
        set = function(value) db.profile.rollNotifications.showInDungeon = value end,
    })
    filterStack:AddChild(dungeonToggle)

    local raidToggle = LDF.CreateToggle(filterSection.content, {
        label = L["Show in Raids"],
        tooltip = L["Show roll notifications while in raids"],
        get = function() return db.profile.rollNotifications.showInRaid end,
        set = function(value) db.profile.rollNotifications.showInRaid = value end,
    })
    filterStack:AddChild(raidToggle)

    stack:AddChild(filterSection)
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
