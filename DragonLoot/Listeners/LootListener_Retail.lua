-------------------------------------------------------------------------------
-- LootListener_Retail.lua
-- Mainline loot window event listener
--
-- Supported versions: Retail, Forever
-------------------------------------------------------------------------------

local _, ns = ...

local CreateFrame = CreateFrame
local pcall, error = pcall, error

-------------------------------------------------------------------------------
-- Version guard: Mainline APIs (Retail and Forever)
-------------------------------------------------------------------------------

if not ns.IsMainline then
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
    -- LOOT_OPENED supplies this session's flag directly. LOOT_READY is also
    -- consumed by EllesmereUI Quick Loot and need not follow LOOT_OPENED.
    local ok, shown = pcall(ns.LootFrame.Show, autoLoot == true or autoLoot == 1)
    if not ok then
        -- Relinquish the session to Blizzard rather than leave loot inaccessible.
        ns.Listeners.Shutdown()
        ns.RestoreBlizzardLootFrame()
        error(shown, 0)
    end

    if shown then
        ns.Addon:SendMessage("DRAGONTOAST_SUPPRESS", "DragonLoot")
    end
    ns.DebugPrint("LOOT_OPENED fired (Mainline)")
end

local function OnLootSlotCleared(slotIndex)
    ns.ListenerShared.OnLootSlotCleared(isLootOpen, slotIndex)
end

local function OnLootSlotChanged(slotIndex)
    ns.ListenerShared.OnLootSlotChanged(isLootOpen, slotIndex)
end

local function OnLootClosed()
    isLootOpen = ns.ListenerShared.OnLootClosed(isLootOpen, "Mainline")
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

    ns.DebugPrint("Mainline Loot Listener initialized")
end

function ns.Listeners.Shutdown()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
        eventFrame = nil
    end

    OnLootClosed()
    ns.DebugPrint("Mainline Loot Listener shut down")
end
