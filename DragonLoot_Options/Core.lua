-------------------------------------------------------------------------------
-- Core.lua
-- Entry point for DragonLoot_Options companion addon
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...

-------------------------------------------------------------------------------
-- Library references
-------------------------------------------------------------------------------

local LDF = LibDragonFramework

-------------------------------------------------------------------------------
-- Locale bridge from main addon
-------------------------------------------------------------------------------

ns.L = LibStub("AceLocale-3.0"):GetLocale("DragonLoot")

-------------------------------------------------------------------------------
-- Tab registry (populated by subsequent tab files)
-------------------------------------------------------------------------------

ns.Tabs = {}

-------------------------------------------------------------------------------
-- Shared dropdown values (used by multiple tab files)
-------------------------------------------------------------------------------

local L = ns.L

ns.QualityValues = {
    { value = "0", text = "|cff9d9d9d" .. L["Poor"] .. "|r" },
    { value = "1", text = "|cffffffff" .. L["Common"] .. "|r" },
    { value = "2", text = "|cff1eff00" .. L["Uncommon"] .. "|r" },
    { value = "3", text = "|cff0070dd" .. L["Rare"] .. "|r" },
    { value = "4", text = "|cffa335ee" .. L["Epic"] .. "|r" },
    { value = "5", text = "|cffff8000" .. L["Legendary"] .. "|r" },
}

-------------------------------------------------------------------------------
-- Shared helpers
-------------------------------------------------------------------------------

local LSM = LibStub("LibSharedMedia-3.0")
local pairs = pairs
local table_sort = table.sort

--- Build a sorted values table from a LibSharedMedia media type.
--- @param mediaType string LSM media type key (e.g. "font", "statusbar")
--- @return table values Array of {value=key, text=key}
function ns.BuildLSMValues(mediaType)
    local hash = LSM:HashTable(mediaType)
    local values = {}
    for key in pairs(hash) do
        values[#values + 1] = { value = key, text = key }
    end
    table_sort(values, function(a, b) return a.text < b.text end)
    return values
end

--- Notify all DragonLoot display frames to re-apply their settings.
--- Safe to call at any time; missing modules are silently skipped.
function ns.NotifyAppearanceChange()
    local dl = ns.dlns
    if not dl then return end
    if dl.LootFrame and dl.LootFrame.ApplySettings then dl.LootFrame.ApplySettings() end
    if dl.RollManager and dl.RollManager.ApplySettings then dl.RollManager.ApplySettings() end
    if dl.HistoryFrame and dl.HistoryFrame.ApplySettings then dl.HistoryFrame.ApplySettings() end
end

-------------------------------------------------------------------------------
-- Panel state
-------------------------------------------------------------------------------

local optionsWindow

-------------------------------------------------------------------------------
-- Create the options window (called lazily on first Open)
-------------------------------------------------------------------------------

local function CreateOptionsWindow()
    ns.dlns = _G.DragonLootNS
    if not ns.dlns then
        print("|cffff6600[DragonLoot_Options]|r " .. L["DragonLoot namespace not found."])
        return
    end

    optionsWindow = LDF.CreateWindow({
        name = "DragonLootOptionsFrame",
        title = "DragonLoot",
        width = 800,
        height = 600,
    })

    -- Tab group inside the window content area
    LDF.CreateTabGroup(optionsWindow.content, ns.Tabs)
end

-------------------------------------------------------------------------------
-- Global API
-------------------------------------------------------------------------------

DragonLoot_Options = {}

function DragonLoot_Options.Open()
    if not optionsWindow then
        CreateOptionsWindow()
    end
    if not optionsWindow then return end
    optionsWindow:Show()
end

function DragonLoot_Options.Close()
    if not optionsWindow then return end
    optionsWindow:Hide()
end

function DragonLoot_Options.Toggle()
    if optionsWindow and optionsWindow:IsShown() then
        DragonLoot_Options.Close()
    else
        DragonLoot_Options.Open()
    end
end
