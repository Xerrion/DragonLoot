-------------------------------------------------------------------------------
-- MasterLootListener_Classic.lua
-- Classic (TBC Anniversary + MoP Classic) master loot picker event listener
--
-- Bridges Blizzard's master loot flow into DragonLoot's custom picker UI.
-- OPEN_MASTER_LOOT_LIST fires after a master looter clicks a loot slot, but
-- the event carries no payload identifying which slot triggered it. We
-- capture the slot index at click time via ns.pendingMasterLootSlot (set in
-- Display/LootFrame.lua's OnSlotClick) and consume it here.
--
-- A dedicated private event frame (CreateFrame("Frame")) owns the event
-- registrations rather than the AceEvent-3.0 mixin on ns.Addon. This keeps
-- the master-loot event surface isolated from the rest of the addon's
-- event traffic and lets us tear it down cleanly without touching the
-- AceEvent registry.
--
-- Supported versions: MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...

-------------------------------------------------------------------------------
-- Version guard: skip on Retail
-------------------------------------------------------------------------------

if not ns.IsClassic then
    return
end

-------------------------------------------------------------------------------
-- Cached WoW API
-------------------------------------------------------------------------------

local CreateFrame = CreateFrame
local GetMasterLootCandidate = GetMasterLootCandidate

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

-- Iterating up to MAX_RAID_MEMBERS covers both party (5) and raid (40)
-- configurations; GetMasterLootCandidate returns nil for empty indices.
local MAX_RAID_MEMBERS = 40

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

local eventFrame

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function CollectCandidates(slot)
    local candidates = {}
    for i = 1, MAX_RAID_MEMBERS do
        local name = GetMasterLootCandidate(slot, i)
        if name then
            candidates[#candidates + 1] = { name = name, index = i }
        end
    end
    return candidates
end

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

local function OnOpenMasterLootList()
    local slot = ns.pendingMasterLootSlot
    ns.pendingMasterLootSlot = nil

    if not slot then
        ns.DebugPrint("OPEN_MASTER_LOOT_LIST fired with no pending slot")
        return
    end

    local candidates = CollectCandidates(slot)
    if #candidates == 0 then
        ns.DebugPrint("OPEN_MASTER_LOOT_LIST: no candidates for slot " .. tostring(slot))
        return
    end

    -- Picker UI is implemented in a later phase; guard so the listener works
    -- in isolation during development and tests.
    if ns.MasterLootFrame and ns.MasterLootFrame.Show then
        ns.MasterLootFrame:Show(slot, candidates)
    end
end

local function OnLootClosed()
    ns.pendingMasterLootSlot = nil

    if ns.MasterLootFrame and ns.MasterLootFrame.Hide then
        ns.MasterLootFrame:Hide()
    end
end

local EVENT_HANDLERS = {
    OPEN_MASTER_LOOT_LIST = OnOpenMasterLootList,
    LOOT_CLOSED = OnLootClosed,
}

local function OnEvent(_, event, ...)
    local handler = EVENT_HANDLERS[event]
    if handler then
        handler(...)
    end
end

-------------------------------------------------------------------------------
-- Public Interface: ns.MasterLootListener
-------------------------------------------------------------------------------

ns.MasterLootListener = ns.MasterLootListener or {}

function ns.MasterLootListener.Initialize()
    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:RegisterEvent("OPEN_MASTER_LOOT_LIST")
    eventFrame:RegisterEvent("LOOT_CLOSED")

    ns.DebugPrint("Classic Master Loot Listener initialized")
end

function ns.MasterLootListener.Shutdown()
    if eventFrame then
        eventFrame:UnregisterEvent("OPEN_MASTER_LOOT_LIST")
        eventFrame:UnregisterEvent("LOOT_CLOSED")
        eventFrame:SetScript("OnEvent", nil)
        eventFrame = nil
    end

    ns.pendingMasterLootSlot = nil
    ns.DebugPrint("Classic Master Loot Listener shut down")
end
