-------------------------------------------------------------------------------
-- EncounterListener_Classic_spec.lua
-- Tests for ENCOUNTER_START capture and HistoryListener_Classic tag-time guard
-------------------------------------------------------------------------------

local mock = require("spec.wow_mock")

-- Force the Classic runtime guard (WOW_PROJECT_ID != WOW_PROJECT_MAINLINE) for
-- the duration of this spec. Restore on teardown so other specs are unaffected.
local savedProjectID
local CLASSIC_PROJECT_ID = 5

local function NewClassicNamespace()
    local ns = mock.CreateNamespace()
    ns.IsRetail = false
    ns.IsClassic = true
    ns.ListenerShared = {
        GetItemTexture = function()
            return 0
        end,
    }
    return ns
end

local function StubLootHistorySingleItem(itemLink)
    rawset(_G, "C_LootHistory", {
        GetNumItems = function()
            return 1
        end,
        GetItem = function()
            -- returns: rollID, itemLink, numPlayers, isDone, winnerIdx
            return 1, itemLink, 1, true, 1
        end,
        GetPlayerInfo = function()
            return "Winner", "WARRIOR", 1, 50
        end,
    })
end

local function MakeAddonStub()
    local addon = {}
    function addon:RegisterEvent() end
    function addon:UnregisterEvent() end
    return addon
end

describe("EncounterListener_Classic", function()
    before_each(function()
        mock.Reset()
        savedProjectID = _G.WOW_PROJECT_ID
        rawset(_G, "WOW_PROJECT_ID", CLASSIC_PROJECT_ID)
    end)

    after_each(function()
        rawset(_G, "WOW_PROJECT_ID", savedProjectID)
    end)

    it("sets ns.currentEncounter on ENCOUNTER_START", function()
        local ns = NewClassicNamespace()
        mock.SetInstance(409) -- Molten Core
        mock.SetTime(123)

        mock.LoadFile(ns, "DragonLoot/Listeners/EncounterListener_Classic.lua")

        assert.is_nil(ns.currentEncounter)

        mock.FireEvent("ENCOUNTER_START", 663, "Lucifron", 9, 40)

        assert.is_not_nil(ns.currentEncounter)
        assert.are.equal(663, ns.currentEncounter.id)
        assert.are.equal("Lucifron", ns.currentEncounter.name)
        assert.are.equal(9, ns.currentEncounter.difficulty)
        assert.are.equal(40, ns.currentEncounter.groupSize)
        assert.are.equal(409, ns.currentEncounter.instanceID)
        assert.are.equal(123, ns.currentEncounter.startTime)
    end)

    it("tags a Classic history entry when instanceID matches", function()
        local ns = NewClassicNamespace()
        local captured
        ns.HistoryFrame = {
            SetEntries = function(entries)
                captured = entries
            end,
        }

        mock.SetInstance(409)
        mock.LoadFile(ns, "DragonLoot/Listeners/EncounterListener_Classic.lua")
        mock.FireEvent("ENCOUNTER_START", 663, "Lucifron", 9, 40)

        StubLootHistorySingleItem("|cffa335ee|Hitem:18814::::::::60:::::|h[Choker]|h|r")
        mock.LoadFile(ns, "DragonLoot/Listeners/HistoryListener_Classic.lua")
        ns.HistoryListener.Initialize(MakeAddonStub())

        assert.is_not_nil(captured)
        assert.are.equal(1, #captured)
        assert.are.equal(663, captured[1].encounterID)
        assert.are.equal("Lucifron", captured[1].encounterName)
    end)

    it("drops the tag when player has left the instance (instanceID differs)", function()
        local ns = NewClassicNamespace()
        local captured
        ns.HistoryFrame = {
            SetEntries = function(entries)
                captured = entries
            end,
        }

        mock.SetInstance(409)
        mock.LoadFile(ns, "DragonLoot/Listeners/EncounterListener_Classic.lua")
        mock.FireEvent("ENCOUNTER_START", 663, "Lucifron", 9, 40)

        -- Player leaves the instance before loot arrives.
        mock.SetInstance(0)

        StubLootHistorySingleItem("|cffa335ee|Hitem:18814::::::::60:::::|h[Choker]|h|r")
        mock.LoadFile(ns, "DragonLoot/Listeners/HistoryListener_Classic.lua")
        ns.HistoryListener.Initialize(MakeAddonStub())

        assert.is_not_nil(captured)
        assert.are.equal(1, #captured)
        assert.is_nil(captured[1].encounterID)
        assert.is_nil(captured[1].encounterName)
    end)

    it("writes no encounter fields when no ENCOUNTER_START ever fired", function()
        local ns = NewClassicNamespace()
        local captured
        ns.HistoryFrame = {
            SetEntries = function(entries)
                captured = entries
            end,
        }

        mock.SetInstance(409)
        mock.LoadFile(ns, "DragonLoot/Listeners/EncounterListener_Classic.lua")
        -- No ENCOUNTER_START fired.

        StubLootHistorySingleItem("|cffa335ee|Hitem:18814::::::::60:::::|h[Choker]|h|r")
        mock.LoadFile(ns, "DragonLoot/Listeners/HistoryListener_Classic.lua")
        ns.HistoryListener.Initialize(MakeAddonStub())

        assert.is_nil(ns.currentEncounter)
        assert.is_not_nil(captured)
        assert.are.equal(1, #captured)
        assert.is_nil(captured[1].encounterID)
        assert.is_nil(captured[1].encounterName)
    end)
end)
