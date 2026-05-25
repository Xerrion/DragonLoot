-------------------------------------------------------------------------------
-- MasterLoot_spec.lua
-- End-to-end tests for the Classic master-loot pipeline:
--   LootFrame.OnSlotClick  -> ns.pendingMasterLootSlot
--   OPEN_MASTER_LOOT_LIST  -> ns.MasterLootFrame:Show(slot, candidates)
--   row click              -> GiveMasterLoot(slot, index)
--   LOOT_CLOSED            -> picker hidden, state cleared
--   Shutdown               -> event registrations and frames torn down
-------------------------------------------------------------------------------

local mock = require("spec.wow_mock")

-------------------------------------------------------------------------------
-- Stub DisplayUtils so MasterLootFrame can be loaded without pulling in
-- LibSharedMedia-3.0. Each function mirrors the real signature with a no-op
-- body sufficient for the picker's Show/Hide/Theme code paths.
-------------------------------------------------------------------------------

local function StubDisplayUtils(ns)
    ns.DisplayUtils = {
        ApplyBackdrop = function() end,
        GetFont = function()
            return "Fonts\\FRIZQT__.TTF", 12, "OUTLINE"
        end,
        ApplyFontShadow = function() end,
    }
end

-------------------------------------------------------------------------------
-- Build a namespace pre-configured for Classic listener/picker execution.
-------------------------------------------------------------------------------

local function NewClassicNamespace()
    local ns = mock.CreateNamespace()
    ns.IsRetail = false
    ns.IsClassic = true
    ns.L = setmetatable({}, {
        __index = function(_, key)
            return key
        end,
    })
    StubDisplayUtils(ns)
    ns.Addon = {
        db = { profile = { appearance = {} } },
    }
    return ns
end

-------------------------------------------------------------------------------
-- OnSlotClick contract test
--
-- OnSlotClick is a file-local in Display/LootFrame.lua, so loading the entire
-- module just to reach it would require stubbing a large surface of the loot
-- pipeline. Instead, extract the function body from the live source file and
-- evaluate it in an isolated sandbox. This still tests the *real* code -- any
-- edit to the OnSlotClick body in LootFrame.lua is reflected here.
-------------------------------------------------------------------------------

local function ExtractOnSlotClick(ns, recorder)
    local f = assert(io.open("DragonLoot/Display/LootFrame.lua", "r"))
    local source = f:read("*a")
    f:close()

    local body = source:match("local%s+function%s+OnSlotClick%s*%(%s*self%s*%)%s*\r?\n(.-)\r?\nend%s*\r?\n")
    assert(body, "OnSlotClick definition not found in LootFrame.lua")

    local env = setmetatable({
        ns = ns,
        LootSlot = function(slot)
            recorder.lastLootSlot = slot
            recorder.lootCalls = (recorder.lootCalls or 0) + 1
        end,
    }, { __index = _G })

    local chunk = assert(loadstring("return function(self)\n" .. body .. "\nend", "OnSlotClick"))
    setfenv(chunk, env)
    return chunk()
end

describe("Master Loot pipeline", function()
    local ns

    before_each(function()
        mock.Reset()
        ns = NewClassicNamespace()
    end)

    ---------------------------------------------------------------------------
    -- MasterLootListener_Classic: candidate collection
    ---------------------------------------------------------------------------

    describe("MasterLootListener candidate collection", function()
        local captured

        before_each(function()
            mock.LoadFile(ns, "DragonLoot/Listeners/MasterLootListener_Classic.lua")

            captured = {}
            ns.MasterLootFrame = {
                Show = function(_, slot, candidates)
                    captured.slot = slot
                    captured.candidates = candidates
                end,
                Hide = function() end,
            }

            ns.MasterLootListener.Initialize()
        end)

        it("collects contiguous candidates with their original indices", function()
            mock._masterLoot.candidates[3] = { [1] = "Alice", [2] = "Bob", [3] = "Carol" }
            ns.pendingMasterLootSlot = 3

            mock.FireEvent("OPEN_MASTER_LOOT_LIST")

            assert.are.equal(3, captured.slot)
            assert.are.equal(3, #captured.candidates)
            assert.are.same({ name = "Alice", index = 1 }, captured.candidates[1])
            assert.are.same({ name = "Bob", index = 2 }, captured.candidates[2])
            assert.are.same({ name = "Carol", index = 3 }, captured.candidates[3])
        end)

        it("preserves original indices when there are gaps in the candidate table", function()
            mock._masterLoot.candidates[1] = { [1] = "Alice", [3] = "Carol", [7] = "Gus" }
            ns.pendingMasterLootSlot = 1

            mock.FireEvent("OPEN_MASTER_LOOT_LIST")

            assert.are.equal(1, captured.slot)
            assert.are.equal(3, #captured.candidates)
            assert.are.same({ name = "Alice", index = 1 }, captured.candidates[1])
            assert.are.same({ name = "Carol", index = 3 }, captured.candidates[2])
            assert.are.same({ name = "Gus", index = 7 }, captured.candidates[3])
        end)

        it("clears pendingMasterLootSlot after the event is consumed", function()
            mock._masterLoot.candidates[2] = { [1] = "Alice" }
            ns.pendingMasterLootSlot = 2

            mock.FireEvent("OPEN_MASTER_LOOT_LIST")

            assert.is_nil(ns.pendingMasterLootSlot)
        end)

        it("does not invoke the picker when no candidates are present", function()
            ns.pendingMasterLootSlot = 9

            mock.FireEvent("OPEN_MASTER_LOOT_LIST")

            assert.is_nil(captured.slot)
            assert.is_nil(captured.candidates)
        end)
    end)

    ---------------------------------------------------------------------------
    -- LootFrame.OnSlotClick contract
    ---------------------------------------------------------------------------

    describe("LootFrame.OnSlotClick", function()
        it("sets ns.pendingMasterLootSlot to self.slotIndex and forwards to LootSlot", function()
            local recorder = {}
            local OnSlotClick = ExtractOnSlotClick(ns, recorder)

            OnSlotClick({ slotIndex = 5 })

            assert.are.equal(5, ns.pendingMasterLootSlot)
            assert.are.equal(5, recorder.lastLootSlot)
            assert.are.equal(1, recorder.lootCalls)
        end)

        it("is a no-op when slotIndex is missing", function()
            local recorder = {}
            local OnSlotClick = ExtractOnSlotClick(ns, recorder)

            OnSlotClick({})

            assert.is_nil(ns.pendingMasterLootSlot)
            assert.is_nil(recorder.lootCalls)
        end)
    end)

    ---------------------------------------------------------------------------
    -- MasterLootFrame: candidate selection -> GiveMasterLoot
    ---------------------------------------------------------------------------

    describe("MasterLootFrame", function()
        local function FindCandidateRows(snapshot)
            local rows = {}
            for _, f in ipairs(mock.FramesSince(snapshot)) do
                -- CreateRow always assigns frame.highlight; the cancel
                -- button and container frame do not.
                if f.highlight and f._scripts and f._scripts.OnClick then
                    rows[#rows + 1] = f
                end
            end
            return rows
        end

        before_each(function()
            mock.LoadFile(ns, "DragonLoot/Display/MasterLootFrame.lua")
            mock.LoadFile(ns, "DragonLoot/Listeners/MasterLootListener_Classic.lua")
            ns.MasterLootFrame.Initialize()
            ns.MasterLootListener.Initialize()
        end)

        it("Show renders one row per candidate and the container frame is visible", function()
            local candidates = {
                { name = "Alice", index = 2 },
                { name = "Bob", index = 5 },
            }
            local before = mock.FrameCount()

            ns.MasterLootFrame:Show(4, candidates)

            local rows = FindCandidateRows(before)
            assert.are.equal(2, #rows)
            assert.is_true(ns.MasterLootFrame.IsShown())
        end)

        it("clicking a row calls GiveMasterLoot(slot, candidate.index) and hides the picker", function()
            local candidates = {
                { name = "Alice", index = 2 },
                { name = "Bob", index = 5 },
            }
            local before = mock.FrameCount()

            ns.MasterLootFrame:Show(4, candidates)

            local rows = FindCandidateRows(before)
            assert.are.equal(2, #rows)

            -- Click the second row.
            local secondRow = rows[2]
            secondRow._scripts.OnClick(secondRow)

            assert.are.equal(1, #mock._masterLoot.given)
            assert.are.same({ slot = 4, index = 5 }, mock._masterLoot.given[1])
            assert.is_false(ns.MasterLootFrame.IsShown())
        end)

        it("Hide releases active rows and hides the frame", function()
            ns.MasterLootFrame:Show(1, { { name = "Alice", index = 1 } })
            assert.is_true(ns.MasterLootFrame.IsShown())

            ns.MasterLootFrame.Hide()

            assert.is_false(ns.MasterLootFrame.IsShown())
        end)

        it("LOOT_CLOSED hides the MasterLootFrame and clears pendingMasterLootSlot", function()
            ns.pendingMasterLootSlot = 9
            ns.MasterLootFrame:Show(2, { { name = "Alice", index = 1 } })
            assert.is_true(ns.MasterLootFrame.IsShown())

            mock.FireEvent("LOOT_CLOSED")

            assert.is_nil(ns.pendingMasterLootSlot)
            assert.is_false(ns.MasterLootFrame.IsShown())
        end)
    end)

    ---------------------------------------------------------------------------
    -- Shutdown cleanup
    ---------------------------------------------------------------------------

    describe("Shutdown", function()
        it("MasterLootListener.Shutdown unregisters events and clears pending state", function()
            mock.LoadFile(ns, "DragonLoot/Listeners/MasterLootListener_Classic.lua")
            local before = mock.FrameCount()
            ns.MasterLootListener.Initialize()

            local listenerFrames = mock.FramesSince(before)
            assert.are.equal(1, #listenerFrames)
            local ev = listenerFrames[1]
            assert.is_true(ev:IsEventRegistered("OPEN_MASTER_LOOT_LIST"))
            assert.is_true(ev:IsEventRegistered("LOOT_CLOSED"))
            assert.is_not_nil(ev:GetScript("OnEvent"))

            ns.pendingMasterLootSlot = 7
            ns.MasterLootListener.Shutdown()

            assert.is_false(ev:IsEventRegistered("OPEN_MASTER_LOOT_LIST"))
            assert.is_false(ev:IsEventRegistered("LOOT_CLOSED"))
            assert.is_nil(ev:GetScript("OnEvent"))
            assert.is_nil(ns.pendingMasterLootSlot)
        end)

        it("MasterLootListener.Shutdown is idempotent (safe second call)", function()
            mock.LoadFile(ns, "DragonLoot/Listeners/MasterLootListener_Classic.lua")
            ns.MasterLootListener.Initialize()

            ns.MasterLootListener.Shutdown()
            assert.has_no.errors(function()
                ns.MasterLootListener.Shutdown()
            end)
        end)

        it("MasterLootFrame.Shutdown hides the frame and releases active rows", function()
            mock.LoadFile(ns, "DragonLoot/Display/MasterLootFrame.lua")
            ns.MasterLootFrame.Initialize()

            ns.MasterLootFrame:Show(1, {
                { name = "Alice", index = 1 },
                { name = "Bob", index = 2 },
            })
            assert.is_true(ns.MasterLootFrame.IsShown())

            ns.MasterLootFrame.Shutdown()

            assert.is_false(ns.MasterLootFrame.IsShown())
        end)

        it("MasterLootFrame.Shutdown is a no-op before Initialize", function()
            mock.LoadFile(ns, "DragonLoot/Display/MasterLootFrame.lua")

            assert.has_no.errors(function()
                ns.MasterLootFrame.Shutdown()
            end)
            assert.is_false(ns.MasterLootFrame.IsShown())
        end)
    end)
end)
