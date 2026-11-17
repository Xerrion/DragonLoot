-------------------------------------------------------------------------------
-- LootCompatibility_spec.lua
-- Regression tests for loot event isolation and skinned Blizzard frames.
-------------------------------------------------------------------------------

local mock = require("spec.wow_mock")

local function LoadModule(ns, path, environment)
    local chunk = assert(loadfile(path))
    setfenv(chunk, environment)("DragonLoot", ns)
end

local function NewLootSession(projectID)
    local session = { open = true, shows = {}, messages = {}, updates = {}, closes = 0 }
    local environment = setmetatable({ WOW_PROJECT_ID = projectID }, { __index = _G })
    environment._G = environment
    environment.CloseLoot = function()
        session.open = false
        session.closes = session.closes + 1
    end

    local blizzard = CreateFrame("Frame")
    function blizzard:Show()
        if self._shown then
            return
        end
        self._shown = true
        local handler = self:GetScript("OnShow")
        if handler then
            handler(self)
        end
    end

    function blizzard:Hide()
        if not self._shown then
            return
        end
        self._shown = false
        local handler = self:GetScript("OnHide")
        if handler then
            handler(self)
        end
    end

    function blizzard:SetShown(shown)
        if shown then
            self:Show()
        else
            self:Hide()
        end
    end

    function blizzard:HookScript(script, hook)
        local original = self:GetScript(script)
        self:SetScript(script, function(...)
            if original then
                original(...)
            end
            hook(...)
        end)
    end

    blizzard:SetScript("OnHide", environment.CloseLoot)
    blizzard:SetScript("OnEvent", function(self, event)
        if event == "LOOT_OPENED" then
            self:Show()
            if not self:IsShown() then
                environment.CloseLoot()
            end
        end
    end)
    blizzard:RegisterEvent("LOOT_OPENED")
    blizzard:RegisterEvent("LOOT_CLOSED")
    environment.LootFrame = blizzard

    local ns = mock.CreateNamespace()
    LoadModule(ns, "DragonLoot/Core/Init.lua", environment)
    ns.Addon.db = { profile = { enabled = true, lootWindow = { enabled = true } } }
    ns.Addon.SendMessage = function(_, ...)
        session.messages[#session.messages + 1] = { ... }
    end
    ns.LootFrame.Show = function(autoLoot)
        if not session.open then
            return false
        end
        session.shows[#session.shows + 1] = autoLoot
        session.visible = not autoLoot or session.blockedLoot == true
        return session.visible
    end
    ns.LootFrame.Hide = function()
        session.visible = false
    end
    ns.LootFrame.UpdateSlot = function(slot)
        session.updates[#session.updates + 1] = slot
    end
    LoadModule(ns, "DragonLoot/Listeners/ListenerShared.lua", environment)
    local listener = projectID == 2 and "Classic" or "Retail"
    LoadModule(ns, "DragonLoot/Listeners/LootListener_" .. listener .. ".lua", environment)
    return ns, session, blizzard, environment
end

describe("Loot UI compatibility", function()
    before_each(function()
        mock.Reset()
    end)

    it("matches Forever roll completions to their roll handles with all source flavors loaded", function()
        local ns, _, _, environment = NewLootSession(18)
        local events, starts, completions = {}, {}, {}
        ns.Addon.RegisterEvent = function(_, event, handler)
            events[event] = handler
        end
        ns.RollManager.StartRoll = function(rollID, duration)
            starts[#starts + 1] = { rollID, duration }
        end
        ns.RollManager.OnRollComplete = function(rollID)
            completions[#completions + 1] = rollID
        end
        environment.GetActiveLootRollIDs = function()
            return {}
        end

        LoadModule(ns, "DragonLoot/Core/Lifecycle.lua", environment)
        LoadModule(ns, "DragonLoot/Listeners/RollListener_Retail.lua", environment)
        LoadModule(ns, "DragonLoot/Listeners/RollListener_Classic.lua", environment)
        ns.RollListener.Initialize(ns.Addon)

        events.START_LOOT_ROLL("START_LOOT_ROLL", 7, 30000, 99)
        events.LOOT_ROLLS_COMPLETE("LOOT_ROLLS_COMPLETE", 99)

        assert.are.same({ { 7, 30 } }, starts)
        assert.are.same({ 7 }, completions)
    end)

    for _, flavor in ipairs({
        { name = "Retail", id = 1 },
        { name = "Forever", id = 18 },
        { name = "Classic", id = 2 },
    }) do
        describe(flavor.name, function()
            it("keeps a loot session open when suppressing a skinned Blizzard frame", function()
                local ns, session, blizzard = NewLootSession(flavor.id)
                blizzard:Show()

                ns.SuppressBlizzardLootFrame()
                ns.Listeners.Initialize(ns.Addon)
                mock.FireEvent("LOOT_OPENED", false)

                assert.is_true(session.open)
                assert.is_true(session.visible)
                assert.is_false(blizzard:IsShown())
                assert.are.equal(0, session.closes)
            end)

            it("survives a skin re-registering and showing the stock loot frame", function()
                local ns, session, blizzard = NewLootSession(flavor.id)
                ns.SuppressBlizzardLootFrame()
                ns.Listeners.Initialize(ns.Addon)
                blizzard:RegisterEvent("LOOT_OPENED")
                blizzard:SetShown(true)

                mock.FireEvent("LOOT_READY", false)
                mock.FireEvent("LOOT_OPENED", false)
                mock.FireEvent("LOOT_SLOT_CHANGED", 2)
                mock.FireEvent("LOOT_SLOT_CLEARED", 1)

                assert.is_true(session.open)
                assert.is_true(session.visible)
                assert.is_false(blizzard:IsShown())
                assert.are.same({ 2, 1 }, session.updates)
                assert.are.same({ { "DRAGONTOAST_SUPPRESS", "DragonLoot" } }, session.messages)
            end)

            it("opens manual loot independently of the shared AceEvent dispatcher", function()
                local ns, session = NewLootSession(flavor.id)
                ns.Addon.RegisterEvent = function() end
                ns.SuppressBlizzardLootFrame()
                ns.Listeners.Initialize(ns.Addon)
                ns.Listeners.Initialize(ns.Addon)

                mock.FireEvent("LOOT_OPENED", false)
                mock.FireEvent("LOOT_OPENED", false)

                assert.is_true(session.visible)
                assert.are.same({ false }, session.shows)

                mock.FireEvent("LOOT_CLOSED")
                assert.is_false(session.visible)
                local suppress = { "DRAGONTOAST_SUPPRESS", "DragonLoot" }
                local unsuppress = { "DRAGONTOAST_UNSUPPRESS", "DragonLoot" }
                assert.are.same({ suppress, unsuppress }, session.messages)

                mock.FireEvent("LOOT_OPENED", false)
                assert.is_true(session.visible)
                assert.are.same({ false, false }, session.shows)
            end)

            for _, autoLoot in ipairs({ true, 1, false, 0 }) do
                it("uses the current LOOT_OPENED auto-loot value " .. tostring(autoLoot), function()
                    local ns, session = NewLootSession(flavor.id)
                    ns.SuppressBlizzardLootFrame()
                    ns.Listeners.Initialize(ns.Addon)
                    mock.FireEvent("LOOT_READY", true)
                    mock.FireEvent("LOOT_OPENED", autoLoot)
                    local expected = autoLoot == true or autoLoot == 1

                    assert.are.same({ expected }, session.shows)
                    assert.are.equal(not expected, session.visible)
                    if expected then
                        assert.are.same({}, session.messages)
                    else
                        assert.are.same({ { "DRAGONTOAST_SUPPRESS", "DragonLoot" } }, session.messages)
                    end
                end)
            end

            it("suppresses toasts when auto-loot leaves an item requiring interaction", function()
                local ns, session = NewLootSession(flavor.id)
                session.blockedLoot = true
                ns.SuppressBlizzardLootFrame()
                ns.Listeners.Initialize(ns.Addon)

                mock.FireEvent("LOOT_OPENED", true)

                assert.is_true(session.visible)
                assert.are.same({ { "DRAGONTOAST_SUPPRESS", "DragonLoot" } }, session.messages)
            end)

            it("leaves disabled loot windows to Blizzard and UI skins", function()
                local ns, session, blizzard = NewLootSession(flavor.id)
                ns.Addon.db.profile.lootWindow.enabled = false
                ns.Listeners.Initialize(ns.Addon)

                mock.FireEvent("LOOT_OPENED", false)

                assert.is_true(blizzard:IsShown())
                assert.is_true(session.open)
                assert.are.same({}, session.shows)
                assert.are.same({}, session.messages)
            end)

            it("restores stock frame behavior and stops listening on addon disable", function()
                local ns, session, blizzard = NewLootSession(flavor.id)
                ns.Addon:OnEnable()
                mock.FireEvent("LOOT_OPENED", false)
                assert.is_true(session.visible)

                ns.Addon:OnDisable()
                mock.FireEvent("LOOT_OPENED", false)

                assert.is_false(session.visible)
                assert.are.same({ false }, session.shows)
                assert.is_true(blizzard:IsShown())
                blizzard:Hide()
                assert.is_false(session.open)
                assert.are.equal(1, session.closes)

                session.open = true
                ns.Addon:OnEnable()
                mock.FireEvent("LOOT_OPENED", false)
                assert.is_true(session.visible)
                assert.is_false(blizzard:IsShown())
                assert.is_true(session.open)
            end)

            it("restores Blizzard loot and reports a failed custom window", function()
                local ns, session, blizzard = NewLootSession(flavor.id)
                ns.LootFrame.Show = function()
                    error("loot display failed", 0)
                end
                ns.SuppressBlizzardLootFrame()
                ns.Listeners.Initialize(ns.Addon)

                assert.has_error(function()
                    mock.FireEvent("LOOT_OPENED", false)
                end, "loot display failed")
                mock.FireEvent("LOOT_OPENED", false)

                assert.is_true(session.open)
                assert.is_true(blizzard:IsShown())
                blizzard:Hide()
                assert.is_false(session.open)
            end)
        end)
    end
end)
