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

    before_each(function()
        mock.Reset()
        local ns = mock.CreateNamespace()
        ns.historyData = {}
        mock.LoadFile(ns, "DragonLoot/Display/HistoryFrame.lua")
        MatchesFilter = ns.HistoryFrame._MatchesFilter
        assert.is_function(MatchesFilter)
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
end)
