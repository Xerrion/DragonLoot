-------------------------------------------------------------------------------
-- HistoryFilter_spec.lua
-- Tests for the pure MatchesFilter predicate used by the history filter bar
-------------------------------------------------------------------------------

local mock = require("spec.wow_mock")

local function MakeEntry(overrides)
    local entry = {
        itemLink = "|cffffffff|Hitem:1234::::::::40:0:0:0:0|h[Onyxia's Tooth]|h|r",
        winner = "Thrall",
        encounterID = 1084,
        encounterName = "Onyxia",
    }
    if overrides then
        for k, v in pairs(overrides) do
            entry[k] = v
        end
    end
    return entry
end

describe("MatchesFilter", function()
    local MatchesFilter
    local UNKNOWN_ENCOUNTER

    before_each(function()
        mock.Reset()
        local ns = mock.CreateNamespace()
        ns.historyData = {}
        mock.LoadFile(ns, "DragonLoot/Display/HistoryFrame.lua")
        MatchesFilter = ns.HistoryFrame._MatchesFilter
        UNKNOWN_ENCOUNTER = ns.HistoryFrame._UNKNOWN_ENCOUNTER
        assert.is_function(MatchesFilter)
        assert.is_not_nil(UNKNOWN_ENCOUNTER)
    end)

    it("returns true for any entry when filter is empty", function()
        local entry = { itemLink = nil, winner = nil, encounterID = nil }
        assert.is_true(MatchesFilter(entry, { encounterID = nil, search = "" }))

        local rich = MakeEntry()
        assert.is_true(MatchesFilter(rich, { encounterID = nil, search = "" }))
    end)

    it("matches when entry encounterID equals filter encounterID", function()
        local entry = MakeEntry({ encounterID = 1084 })
        assert.is_true(MatchesFilter(entry, { encounterID = 1084, search = "" }))
    end)

    it("rejects entry with nil encounterID when a specific encounter is filtered", function()
        local entry = MakeEntry()
        entry.encounterID = nil
        assert.is_false(MatchesFilter(entry, { encounterID = 1084, search = "" }))
    end)

    it("rejects entry with different encounterID", function()
        local entry = MakeEntry({ encounterID = 663 })
        assert.is_false(MatchesFilter(entry, { encounterID = 1084, search = "" }))
    end)

    it("matches item name case-insensitively", function()
        local entry = MakeEntry()
        assert.is_true(MatchesFilter(entry, { encounterID = nil, search = "ONY" }))
        assert.is_true(MatchesFilter(entry, { encounterID = nil, search = "tooth" }))
    end)

    it("matches winner name case-insensitively", function()
        local entry = MakeEntry({ winner = "Jaina" })
        assert.is_true(MatchesFilter(entry, { encounterID = nil, search = "jai" }))
        assert.is_true(MatchesFilter(entry, { encounterID = nil, search = "JAINA" }))
    end)

    it("returns false when neither item nor winner contains the search", function()
        local entry = MakeEntry({ winner = "Thrall" })
        assert.is_false(MatchesFilter(entry, { encounterID = nil, search = "zzz" }))
    end)

    it("returns false when both itemLink and winner are nil and search is non-empty", function()
        local entry = { itemLink = nil, winner = nil, encounterID = nil }
        assert.is_false(MatchesFilter(entry, { encounterID = nil, search = "any" }))
    end)

    it("combined filter: encounter matches AND search matches -> pass", function()
        local entry = MakeEntry({ encounterID = 1084, winner = "Thrall" })
        assert.is_true(MatchesFilter(entry, { encounterID = 1084, search = "thrall" }))
    end)

    it("combined filter: encounter matches but search fails -> fail", function()
        local entry = MakeEntry({ encounterID = 1084, winner = "Thrall" })
        assert.is_false(MatchesFilter(entry, { encounterID = 1084, search = "zzz" }))
    end)

    it("combined filter: encounter fails even if search would match -> fail", function()
        local entry = MakeEntry({ encounterID = 663, winner = "Thrall" })
        assert.is_false(MatchesFilter(entry, { encounterID = 1084, search = "thrall" }))
    end)

    it("malformed item link (no bracketed name) falls back to winner-only search", function()
        local entry = MakeEntry({ itemLink = "|cffffffff|Hitem:1234::|h|r", winner = "Thrall" })
        -- "thrall" hits winner
        assert.is_true(MatchesFilter(entry, { encounterID = nil, search = "thrall" }))
        -- "ony" would have hit item name but link has no [...], and winner has no "ony"
        assert.is_false(MatchesFilter(entry, { encounterID = nil, search = "ony" }))
    end)

    it("UNKNOWN_ENCOUNTER state matches entry with nil encounterID", function()
        local entry = MakeEntry()
        entry.encounterID = nil
        entry.encounterName = nil
        assert.is_true(MatchesFilter(entry, { encounterID = UNKNOWN_ENCOUNTER, search = "" }))
    end)

    it("UNKNOWN_ENCOUNTER state rejects entry with a real encounterID", function()
        local entry = MakeEntry({ encounterID = 1084 })
        assert.is_false(MatchesFilter(entry, { encounterID = UNKNOWN_ENCOUNTER, search = "" }))
    end)
end)

describe("Filter persistence", function()
    local function LoadFrame(profileSeed)
        mock.Reset()
        mock._profileSeed = profileSeed
        local ns = mock.CreateNamespace()
        ns.historyData = {}
        mock.LoadFile(ns, "DragonLoot/Display/HistoryFrame.lua")
        -- Mimic the addon init wiring so ns.Addon.db exists for the helpers.
        ns.Addon.db = LibStub("AceDB-3.0"):New("DragonLootDB", { profile = {} }, true)
        return ns
    end

    it("RestoreFilter copies persisted encounterID and search into filterState", function()
        local ns = LoadFrame({
            history = { filter = { encounterID = 1084, search = "thrall", barVisible = true } },
        })

        ns.HistoryFrame._RestoreFilter()

        -- PersistFilter then mirrors filterState back; round-trip must preserve values.
        ns.HistoryFrame._PersistFilter()
        local stored = ns.Addon.db.profile.history.filter
        assert.equals(1084, stored.encounterID)
        assert.equals("thrall", stored.search)
    end)

    it("RestoreFilter defaults search to empty string when persisted value is nil", function()
        local ns = LoadFrame({
            history = { filter = { barVisible = true } },
        })

        ns.HistoryFrame._RestoreFilter()
        ns.HistoryFrame._PersistFilter()
        local stored = ns.Addon.db.profile.history.filter
        assert.is_nil(stored.encounterID)
        assert.equals("", stored.search)
    end)

    it("PersistFilter writes UNKNOWN_ENCOUNTER sentinel through unchanged", function()
        local UNKNOWN = -1
        local ns = LoadFrame({
            history = { filter = { encounterID = UNKNOWN, search = "" } },
        })
        assert.equals(UNKNOWN, ns.HistoryFrame._UNKNOWN_ENCOUNTER)

        ns.HistoryFrame._RestoreFilter()
        ns.HistoryFrame._PersistFilter()
        assert.equals(UNKNOWN, ns.Addon.db.profile.history.filter.encounterID)
    end)

    it("RestoreFilter is a no-op when ns.Addon.db is unset", function()
        mock.Reset()
        local ns = mock.CreateNamespace()
        ns.historyData = {}
        mock.LoadFile(ns, "DragonLoot/Display/HistoryFrame.lua")
        ns.Addon.db = nil

        assert.has_no.errors(function()
            ns.HistoryFrame._RestoreFilter()
        end)
        assert.has_no.errors(function()
            ns.HistoryFrame._PersistFilter()
        end)
    end)
end)
