-------------------------------------------------------------------------------
-- AutoLootTab.lua
-- Smart auto-loot settings tab: enable, quality filter, whitelist, blacklist
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
-- Constants
-------------------------------------------------------------------------------

local ITEM_LIST_HEIGHT = 220

-------------------------------------------------------------------------------
-- Build the Auto-Loot tab content
-------------------------------------------------------------------------------

local function CreateContent(scrollChild)
    dlns = ns.dlns
    local db = dlns.Addon.db

    local stack = LDF.CreateStackLayout(scrollChild)
    stack:SetPoint("TOPLEFT", scrollChild, "TOPLEFT")
    stack:SetPoint("RIGHT", scrollChild, "RIGHT")

    ---------------------------------------------------------------------------
    -- Section: Smart Auto-Loot (toggle + quality dropdown)
    ---------------------------------------------------------------------------

    local settingsSection = LDF.CreateSection(scrollChild, L["Smart Auto-Loot"], { columns = 1 })

    local settingsStack = LDF.CreateStackLayout(settingsSection.content)
    settingsStack:SetPoint("TOPLEFT", settingsSection.content, "TOPLEFT")
    settingsStack:SetPoint("RIGHT", settingsSection.content, "RIGHT")
    settingsStack:HookScript("OnSizeChanged", function(_, _, h)
        settingsSection.content:SetHeight(h)
    end)

    -- Description
    local settingsDesc = LDF.CreateDescription(settingsSection.content,
        L["Automatically loot items that meet your criteria. Items on the whitelist are always"
        .. " picked up. Items on the blacklist are never auto-looted. Everything else is evaluated"
        .. " against the minimum quality threshold."])
    settingsStack:AddChild(settingsDesc)

    -- Toggle: Enable Smart Auto-Loot
    local enableToggle = LDF.CreateToggle(settingsSection.content, {
        label = L["Enable Smart Auto-Loot"],
        tooltip = L["When enabled, qualifying items are automatically looted based on your filter rules"],
        get = function() return db.profile.autoLoot.enabled end,
        set = function(value) db.profile.autoLoot.enabled = value end,
    })
    settingsStack:AddChild(enableToggle)

    -- Dropdown: Minimum Quality
    local qualityDropdown = LDF.CreateDropdown(settingsSection.content, {
        label = L["Minimum Quality"],
        values = ns.QualityValues,
        get = function() return tostring(db.profile.autoLoot.minQuality) end,
        set = function(value) db.profile.autoLoot.minQuality = tonumber(value) end,
    })
    settingsStack:AddChild(qualityDropdown)

    stack:AddChild(settingsSection)

    ---------------------------------------------------------------------------
    -- Section: Whitelist item grid
    ---------------------------------------------------------------------------

    local whitelistSection = LDF.CreateSection(scrollChild, L["Whitelist"], { columns = 1 })

    local whitelistStack = LDF.CreateStackLayout(whitelistSection.content)
    whitelistStack:SetPoint("TOPLEFT", whitelistSection.content, "TOPLEFT")
    whitelistStack:SetPoint("RIGHT", whitelistSection.content, "RIGHT")
    whitelistStack:HookScript("OnSizeChanged", function(_, _, h)
        whitelistSection.content:SetHeight(h)
    end)

    -- Description
    local whitelistDesc = LDF.CreateDescription(whitelistSection.content,
        L["Items on this list are always looted automatically, regardless of quality."
        .. " Drag an item from your bags onto an empty slot to add it."])
    whitelistStack:AddChild(whitelistDesc)

    -- Item list
    local whitelistItems = LDF.CreateItemList(whitelistSection.content, {
        get = function() return db.profile.autoLoot.whitelist end,
        set = function(t) db.profile.autoLoot.whitelist = t end,
        emptyText = L["No items - drag items here to add"],
    })
    whitelistItems:SetHeight(ITEM_LIST_HEIGHT)
    whitelistStack:AddChild(whitelistItems)

    stack:AddChild(whitelistSection)

    ---------------------------------------------------------------------------
    -- Section: Blacklist item grid
    ---------------------------------------------------------------------------

    local blacklistSection = LDF.CreateSection(scrollChild, L["Blacklist"], { columns = 1 })

    local blacklistStack = LDF.CreateStackLayout(blacklistSection.content)
    blacklistStack:SetPoint("TOPLEFT", blacklistSection.content, "TOPLEFT")
    blacklistStack:SetPoint("RIGHT", blacklistSection.content, "RIGHT")
    blacklistStack:HookScript("OnSizeChanged", function(_, _, h)
        blacklistSection.content:SetHeight(h)
    end)

    -- Description
    local blacklistDesc = LDF.CreateDescription(blacklistSection.content,
        L["Items on this list are never auto-looted, even if they meet the quality threshold."
        .. " They will remain in the loot window for manual pickup."])
    blacklistStack:AddChild(blacklistDesc)

    -- Item list
    local blacklistItems = LDF.CreateItemList(blacklistSection.content, {
        get = function() return db.profile.autoLoot.blacklist end,
        set = function(t) db.profile.autoLoot.blacklist = t end,
        emptyText = L["No items - drag items here to add"],
    })
    blacklistItems:SetHeight(ITEM_LIST_HEIGHT)
    blacklistStack:AddChild(blacklistItems)

    stack:AddChild(blacklistSection)
end

-------------------------------------------------------------------------------
-- Register tab
-------------------------------------------------------------------------------

ns.Tabs = ns.Tabs or {}
ns.Tabs[#ns.Tabs + 1] = {
    id = "autoLoot",
    label = L["Auto-Loot"],
    order = 5,
    createFunc = CreateContent,
}
