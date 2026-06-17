-------------------------------------------------------------------------------
-- EncounterListener_Classic.lua
-- Captures ENCOUNTER_START context for tagging Classic loot history entries
--
-- Supported versions: MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...

-------------------------------------------------------------------------------
-- Version guard: Retail uses C_LootHistory encounter info directly; skip.
-------------------------------------------------------------------------------

if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    return
end

-------------------------------------------------------------------------------
-- Cached WoW API
-------------------------------------------------------------------------------

local CreateFrame = CreateFrame
local GetTime = GetTime
local GetInstanceInfo = GetInstanceInfo

-------------------------------------------------------------------------------
-- ns.currentEncounter contract
--
-- Single-writer convention: this listener is the only writer of
-- ns.currentEncounter. HistoryListener_Classic (and any future readers) read
-- the cache; they MUST NOT mutate it. The cache is sticky - never explicitly
-- cleared - and staleness is bounded at read time by comparing the cached
-- instanceID against GetInstanceInfo()'s current instanceID (see ADR-0004).
--
-- A private unnamed frame is used instead of addon:RegisterEvent to avoid the
-- shared AceEvent30Frame taint vector documented in workspace AGENTS.md.
-------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, encounterID, encounterName, difficultyID, groupSize)
    if event ~= "ENCOUNTER_START" then
        return
    end
    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    ns.currentEncounter = {
        id = encounterID,
        name = encounterName,
        difficulty = difficultyID,
        groupSize = groupSize,
        instanceID = instanceID,
        startTime = GetTime(),
    }
end)

-------------------------------------------------------------------------------
-- Public Interface: ns.EncounterListener_Classic
-------------------------------------------------------------------------------

local function Initialize(_)
    frame:RegisterEvent("ENCOUNTER_START")
end

local function Shutdown()
    frame:UnregisterEvent("ENCOUNTER_START")
end

-- Minimal handle for tests; production code should read ns.currentEncounter.
ns.EncounterListener_Classic = {
    _frame = frame,
    Initialize = Initialize,
    Shutdown = Shutdown,
}
