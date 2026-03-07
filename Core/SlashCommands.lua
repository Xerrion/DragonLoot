-------------------------------------------------------------------------------
-- SlashCommands.lua
-- Slash command handler for DragonLoot
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local ADDON_NAME, ns = ...

local print = print
local strtrim = strtrim

local L = ns.L

-------------------------------------------------------------------------------
-- Help Display
-------------------------------------------------------------------------------

local function PrintHelp()
    print(ns.COLOR_GOLD .. L["--- DragonLoot Commands ---"] .. ns.COLOR_RESET)
    print("  " .. L["/dl - Toggle addon on/off"])
    print("  " .. L["/dl config - Open settings panel"])
    print("  " .. L["/dl minimap - Toggle minimap icon"])
    print("  " .. L["/dl enable - Enable addon"])
    print("  " .. L["/dl disable - Disable addon"])
    print("  " .. L["/dl reset - Reset loot frame position"])
    print("  " .. L["/dl test - Show test loot"])
    print("  " .. L["/dl testroll - Show test roll frames"])
    print("  " .. L["/dl history - Toggle loot history"])
    print("  " .. L["/dl status - Show current settings"])
    print("  " .. L["/dl help - Show this help"])
end

-------------------------------------------------------------------------------
-- Status Display
-------------------------------------------------------------------------------

local function PrintStatus()
    local db = ns.Addon.db.profile

    print(ns.COLOR_GOLD .. L["--- DragonLoot Status ---"] .. ns.COLOR_RESET)

    local enabledStr = db.enabled
        and (ns.COLOR_GREEN .. L["Yes"] .. ns.COLOR_RESET)
        or (ns.COLOR_RED .. L["No"] .. ns.COLOR_RESET)
    print("  " .. L["Enabled:"] .. " " .. enabledStr)

    print("  " .. L["Loot Window:"] .. " " .. (db.lootWindow.enabled and L["Yes"] or L["No"]))
    print("  " .. L["Roll Frame:"] .. " " .. (db.rollFrame.enabled and L["Yes"] or L["No"]))
    print("  " .. L["History:"] .. " " .. (db.history.enabled and L["Yes"] or L["No"]))
    print("  " .. L["Animations:"] .. " " .. (db.animation.enabled and L["Yes"] or L["No"]))
    print("  " .. L["Minimap Icon:"] .. " " .. (not db.minimap.hide and L["Yes"] or L["No"]))
end

-------------------------------------------------------------------------------
-- Command Router
-------------------------------------------------------------------------------

local function ToggleAddon()
    local db = ns.Addon.db.profile
    db.enabled = not db.enabled
    if db.enabled then
        ns.Addon:OnEnable()
        ns.Print(L["Addon enabled"])
    else
        ns.Addon:OnDisable()
        ns.Print(L["Addon disabled"])
    end
end

local commandHandlers = {
    ["config"]   = function() if ns.ToggleConfigWindow then ns.ToggleConfigWindow() end end,
    ["options"]  = function() if ns.ToggleConfigWindow then ns.ToggleConfigWindow() end end,
    ["settings"] = function() if ns.ToggleConfigWindow then ns.ToggleConfigWindow() end end,
    ["minimap"]  = function() if ns.MinimapIcon.Toggle then ns.MinimapIcon.Toggle() end end,
    ["toggle"]   = ToggleAddon,
    ["status"]   = PrintStatus,
    ["help"]     = PrintHelp,
    ["?"]        = PrintHelp,
    ["reset"] = function()
        if ns.LootFrame.ResetAnchor then
            ns.LootFrame.ResetAnchor()
            ns.Print(L["Loot frame position reset."])
        else
            ns.Print(L["Loot frame not yet available."])
        end
    end,
    ["test"] = function()
        if ns.LootFrame.ShowTestLoot then
            ns.LootFrame.ShowTestLoot()
        else
            ns.Print(L["Test loot not yet available."])
        end
    end,
    ["testroll"] = function()
        if ns.RollFrame.ShowTestRoll then
            ns.RollFrame.ShowTestRoll()
        else
            ns.Print(L["Test roll not yet available."])
        end
    end,
    ["history"] = function()
        if ns.HistoryFrame.Toggle then
            ns.HistoryFrame.Toggle()
        else
            ns.Print(L["Loot history not yet available."])
        end
    end,
}

function ns.HandleSlashCommand(input)
    local cmd = strtrim((input or ""):lower())

    if cmd == "" then
        PrintHelp()
        return
    end

    local handler = commandHandlers[cmd]
    if handler then
        handler()
    else
        ns.Print(L["Unknown command:"] .. " " .. ns.COLOR_WHITE .. cmd .. ns.COLOR_RESET)
        PrintHelp()
    end
end
