-------------------------------------------------------------------------------
-- HistoryItemAPI_spec.lua
-- Tests history event handlers with C_Item APIs and removed global aliases.
-------------------------------------------------------------------------------

local mock = require("spec.wow_mock")

local ITEM_LINK = "|cffa335ee|Hitem:190198::::::::::::|h[Namespace Helm]|h|r"
local ITEM_ICON = 135028

local function LoadModule(ns, path, environment)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    setfenv(chunk, environment)("DragonLoot", ns)
end

local function NewHistoryNamespace(projectID)
    local recorder = { entries = {}, notifications = {}, events = {}, timers = {}, refreshes = 0 }
    local environment = setmetatable({
        WOW_PROJECT_ID = projectID,
        LOOT_ITEM_SELF = "You receive loot: %s.",
        LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d.",
        time = function()
            return 1700000000
        end,
        C_Timer = {
            After = function(_, callback)
                recorder.timers[#recorder.timers + 1] = callback
            end,
        },
    }, {
        __index = function(_, key)
            if key == "GetItemInfo" or key == "GetItemInfoInstant" then
                return nil
            end
            return _G[key]
        end,
    })
    environment._G = environment

    local ns = mock.CreateNamespace()
    ns.historyData = recorder.entries
    ns.NOTIFICATION_STATE_MAP = { [0] = 1 }
    ns.HistoryFrame = {
        AddEntry = function(entry)
            recorder.entries[#recorder.entries + 1] = entry
        end,
        SetEntries = function(entries)
            recorder.entries = entries
            ns.historyData = entries
        end,
        Refresh = function()
            recorder.refreshes = recorder.refreshes + 1
        end,
    }
    ns.RollTally.Refresh = function() end
    ns.RollManager.SendRollResultNotification = function(...)
        recorder.notifications[#recorder.notifications + 1] = { ... }
    end
    ns.Addon = {
        db = {
            profile = {
                history = { trackDirectLoot = true, minQuality = 2, autoShow = false },
            },
        },
        RegisterEvent = function(_, event, handler)
            recorder.events[event] = handler
        end,
        UnregisterEvent = function(_, event)
            recorder.events[event] = nil
        end,
    }

    LoadModule(ns, "DragonLoot/Core/Lifecycle.lua", environment)
    LoadModule(ns, "DragonLoot/Listeners/ListenerShared.lua", environment)
    return ns, recorder, environment
end

local function AssertItemEntry(entry, quality)
    assert.are.equal(ITEM_LINK, entry.itemLink)
    assert.are.equal(ITEM_ICON, entry.itemTexture)
    assert.are.equal(quality, entry.quality)
end

describe("History item APIs without legacy globals", function()
    before_each(function()
        mock.Reset()
        mock._items[ITEM_LINK] = { itemID = 190198, name = "Namespace Helm", quality = 4, icon = ITEM_ICON }
        mock._group.units.player = { className = "Warrior", classFile = "WARRIOR", classID = 1 }
    end)

    it("records Retail encounter drops and roll-result item details", function()
        local ns, recorder, environment = NewHistoryNamespace(1)
        LoadModule(ns, "DragonLoot/Listeners/HistoryListener_Retail.lua", environment)
        LoadModule(ns, "DragonLoot/Listeners/HistoryListener_Classic.lua", environment)
        ns.HistoryListener.Initialize(ns.Addon)
        mock._lootHistory.drops[42] = {
            {
                lootListID = 7,
                itemHyperlink = ITEM_LINK,
                winner = { playerName = "Winner", playerClass = "MAGE" },
                currentLeader = { state = 0, roll = 98 },
                rollInfos = {
                    { playerName = "Winner", playerGUID = "Player-1", playerClass = "MAGE", state = 0, roll = 98 },
                },
            },
        }

        recorder.events.LOOT_HISTORY_UPDATE_DROP("LOOT_HISTORY_UPDATE_DROP", 42, 7)

        assert.are.equal(1, #recorder.entries)
        AssertItemEntry(recorder.entries[1], 4)
        assert.are.equal("Winner", recorder.entries[1].winner)
        assert.is_true(recorder.entries[1].isComplete)
        local expected = { ITEM_LINK, "Namespace Helm", 4, ITEM_ICON, "Winner", "MAGE", 1, 98 }
        assert.are.same(expected, recorder.notifications[1])
    end)

    it("records directly looted items", function()
        local ns, recorder, environment = NewHistoryNamespace(1)
        LoadModule(ns, "DragonLoot/Listeners/LootHistoryChat.lua", environment)
        ns.LootHistoryChat.Initialize(ns.Addon)

        recorder.events.CHAT_MSG_LOOT("CHAT_MSG_LOOT", "You receive loot: " .. ITEM_LINK .. ".")

        assert.are.equal(1, #recorder.entries)
        AssertItemEntry(recorder.entries[1], 4)
        assert.are.equal("TestPlayer", recorder.entries[1].winner)
        assert.are.equal("WARRIOR", recorder.entries[1].winnerClass)
        assert.is_true(recorder.entries[1].isDirectLoot)
        assert.is_true(recorder.entries[1].isComplete)
    end)

    it("retrieves uncached direct-loot quality through the namespaced retry", function()
        local ns, recorder, environment = NewHistoryNamespace(1)
        mock._items[ITEM_LINK].quality = nil
        LoadModule(ns, "DragonLoot/Listeners/LootHistoryChat.lua", environment)
        ns.LootHistoryChat.Initialize(ns.Addon)

        recorder.events.CHAT_MSG_LOOT("CHAT_MSG_LOOT", "You receive loot: " .. ITEM_LINK .. ".")

        assert.are.equal(1, #recorder.entries)
        assert.is_nil(recorder.entries[1].quality)
        assert.are.equal(ITEM_ICON, recorder.entries[1].itemTexture)
        assert.are.equal(1, #recorder.timers)
        mock._items[ITEM_LINK].quality = 3
        recorder.timers[1]()

        AssertItemEntry(recorder.entries[1], 3)
        assert.is_nil(recorder.entries[1].qualityRetryToken)
        assert.are.equal(1, recorder.refreshes)
    end)

    it("applies the direct-loot quality filter to namespaced item data", function()
        local ns, recorder, environment = NewHistoryNamespace(1)
        mock._items[ITEM_LINK].quality = 1
        LoadModule(ns, "DragonLoot/Listeners/LootHistoryChat.lua", environment)
        ns.LootHistoryChat.Initialize(ns.Addon)

        recorder.events.CHAT_MSG_LOOT("CHAT_MSG_LOOT", "You receive loot: " .. ITEM_LINK .. ".")

        assert.are.equal(0, #recorder.entries)
        assert.are.equal(0, #recorder.timers)
    end)

    it("refreshes Classic history and reports roll-result item details", function()
        local ns, recorder, environment = NewHistoryNamespace(5)
        LoadModule(ns, "DragonLoot/Listeners/HistoryListener_Classic.lua", environment)
        LoadModule(ns, "DragonLoot/Listeners/HistoryListener_Retail.lua", environment)
        ns.HistoryListener.Initialize(ns.Addon)
        mock._lootHistory.items[1] = {
            rollID = 7,
            itemLink = ITEM_LINK,
            numPlayers = 1,
            isDone = true,
            winnerIndex = 1,
        }
        mock._lootHistory.players[1] = {
            { name = "Winner", class = "MAGE", rollType = 1, roll = 98, isWinner = true },
        }

        recorder.events.LOOT_HISTORY_FULL_UPDATE("LOOT_HISTORY_FULL_UPDATE")

        assert.are.equal(1, #recorder.entries)
        AssertItemEntry(recorder.entries[1], 4)
        assert.are.equal("Winner", recorder.entries[1].winner)
        assert.is_true(recorder.entries[1].isComplete)

        recorder.events.LOOT_HISTORY_ROLL_CHANGED("LOOT_HISTORY_ROLL_CHANGED", 1, 1)

        local expected = { ITEM_LINK, "Namespace Helm", 4, ITEM_ICON, "Winner", nil, 1, 98 }
        assert.are.same(expected, recorder.notifications[1])
        AssertItemEntry(recorder.entries[1], 4)
    end)
end)
