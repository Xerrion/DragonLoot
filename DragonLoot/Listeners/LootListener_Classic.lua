-------------------------------------------------------------------------------
-- LootListener_Classic.lua
-- Classic (TBC Anniversary + MoP Classic) loot window event listener
--
-- Supported versions: MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...

local CreateFrame = CreateFrame
local pcall, error = pcall, error

-------------------------------------------------------------------------------
-- Version guard: skip Mainline clients (Retail and Forever)
-------------------------------------------------------------------------------

if not ns.IsClassic then
    return
end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

local eventFrame
local isLootOpen = false

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

local function OnLootOpened(autoLoot)
    if isLootOpen then
        return
    end

    local db = ns.Addon.db and ns.Addon.db.profile
    if not db or not db.enabled or not db.lootWindow or not db.lootWindow.enabled then
        return
    end

    isLootOpen = true
    ns.SuppressBlizzardLootFrame()
    local ok, shown = pcall(ns.LootFrame.Show, autoLoot == true or autoLoot == 1)
    if not ok then
        -- Relinquish the session to Blizzard rather than leave loot inaccessible.
        ns.Listeners.Shutdown()
        ns.RestoreBlizzardLootFrame()
        error(shown, 0)
    end

    -- Only suppress DragonToast when the loot window is actually visible.
    -- With auto-loot enabled, Show() may still display the window for items
    -- the engine cannot auto-loot (rolls, BoP confirms, dungeon chests).
    if shown then
        ns.Addon:SendMessage("DRAGONTOAST_SUPPRESS", "DragonLoot")
    end
    ns.DebugPrint("LOOT_OPENED fired (Classic)")
end

local function OnLootSlotCleared(slotIndex)
    ns.ListenerShared.OnLootSlotCleared(isLootOpen, slotIndex)
end

local function OnLootSlotChanged(slotIndex)
    ns.ListenerShared.OnLootSlotChanged(isLootOpen, slotIndex)
end

local function OnLootClosed()
    isLootOpen = ns.ListenerShared.OnLootClosed(isLootOpen, "Classic")
end

local EVENT_HANDLERS = {
    LOOT_OPENED = OnLootOpened,
    LOOT_SLOT_CLEARED = OnLootSlotCleared,
    LOOT_SLOT_CHANGED = OnLootSlotChanged,
    LOOT_CLOSED = OnLootClosed,
}

local function OnEvent(_, event, ...)
    local handler = EVENT_HANDLERS[event]
    if handler then
        handler(...)
    end
end

-------------------------------------------------------------------------------
-- Public Interface: ns.Listeners
-------------------------------------------------------------------------------

function ns.Listeners.Initialize()
    if eventFrame then
        return
    end

    -- Keep loot traffic off the shared AceEvent30Frame used by other addons.
    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:RegisterEvent("LOOT_OPENED")
    eventFrame:RegisterEvent("LOOT_SLOT_CLEARED")
    eventFrame:RegisterEvent("LOOT_SLOT_CHANGED")
    eventFrame:RegisterEvent("LOOT_CLOSED")

    ns.DebugPrint("Classic Loot Listener initialized")
end

function ns.Listeners.Shutdown()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
        eventFrame = nil
    end

    OnLootClosed()
    ns.DebugPrint("Classic Loot Listener shut down")
end
