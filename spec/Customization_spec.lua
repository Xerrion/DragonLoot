local harness = require("spec.preview_harness")
local mock = require("spec.wow_mock")

local function findFrame(context, name)
    for _, frame in ipairs(context.created) do
        if frame.name == name then
            return frame
        end
    end
    error("Missing frame " .. name)
end

describe("display customization", function()
    local context, ns
    before_each(function()
        mock.Reset()
    end)
    after_each(function()
        if context then
            context:Restore()
        end
    end)

    it("preserves default loot details and updates preview content and intensity in place", function()
        context = harness.Start()
        ns = context.ns
        local preview = ns.LootFrame.CreatePreview(context.widget("Frame"))
        local potion, epic = preview.previewRows[1], preview.previewRows[3]
        assert.is_true(potion.quantity:IsShown())
        assert.is_true(potion.subText:IsShown())
        assert.is_false(epic.iconGlow:IsShown())
        assert.are.equal(0.08, epic.rowBg.color[4])
        local count = #context.created
        local cfg = ns.Addon.db.profile.lootWindow
        cfg.showQuantity, cfg.showDetails, cfg.qualityGlow = false, false, false
        cfg.backgroundIntensity = 0
        ns.Addon.db.profile.appearance.slotBackground = "gradient"
        preview:Refresh()
        assert.is_false(potion.quantity:IsShown())
        assert.is_false(potion.subText:IsShown())
        assert.is_false(epic.iconGlow:IsShown())
        assert.are.equal(0, epic.rowBg.gradient[2][4])

        cfg.showQuantity, cfg.showDetails, cfg.qualityGlow = true, true, true
        cfg.backgroundIntensity = 2
        ns.Addon.db.profile.appearance.slotBackground = "stripe"
        preview:Refresh()
        assert.is_true(potion.quantity:IsShown())
        assert.is_true(potion.subText:IsShown())
        assert.is_true(epic.iconGlow:IsShown())
        assert.are.equal(1, epic.accentStripe.color[4])
        ns.Addon.db.profile.appearance.slotBackground = "flat"
        preview:Refresh()
        assert.are.equal(0.16, epic.rowBg.color[4])
        ns.Addon.db.profile.appearance.slotBackground = "none"
        preview:Refresh()
        assert.is_false(epic.rowBg:IsShown())
        assert.is_false(epic.accentStripe:IsShown())
        assert.are.equal(count, #context.created)
    end)

    it("keeps preview timer text optional and never clears unsupported native scripts", function()
        context = harness.Start()
        ns = context.ns
        local preview = ns.RollFrame.CreatePreview(context.widget("Frame"))
        assert.is_false(preview:HasScript("OnClick"))
        assert.has_error(function()
            preview:SetScript("OnClick", nil)
        end)
        assert.is_true(preview.timerBar.text:IsShown())
        local cfg = ns.Addon.db.profile.rollFrame
        cfg.showTimerText = false
        preview:Refresh()
        assert.is_false(preview.timerBar.text:IsShown())
        cfg.showTimerText = true
        cfg.timerBarStyle = "minimal"
        preview:Refresh()
        assert.is_false(preview.timerBar.text:IsShown())
        cfg.timerBarStyle = "normal"
        preview:Refresh()
        assert.is_true(preview.timerBar.text:IsShown())
    end)

    it("refreshes history preview dimensions and timestamp space without changing saved data", function()
        context = harness.Start()
        ns = context.ns
        local preview = ns.HistoryFrame.CreatePreview(context.widget("Frame"))
        local row = preview.previewRows[1]
        assert.are.equal(350, preview:GetWidth())
        assert.are.equal(400, preview:GetHeight())
        assert.is_true(row.timeText:IsShown())
        local savedEntries = ns.Addon.db.char.history.entries
        local cfg = ns.Addon.db.profile.history
        cfg.width, cfg.height, cfg.showTimestamp = 610, 250, false
        preview:Refresh()
        assert.are.equal(610, preview:GetWidth())
        assert.are.equal(250, preview:GetHeight())
        assert.is_false(row.timeText:IsShown())
        assert.are.equal(-4, row.itemName.points[#row.itemName.points][4])
        cfg.showTimestamp = true
        preview:Refresh()
        assert.is_true(row.timeText:IsShown())
        assert.are.equal(-60, row.itemName.points[#row.itemName.points][4])
        assert.are.equal(savedEntries, ns.Addon.db.char.history.entries)
        assert.are.equal(1, #savedEntries)
    end)

    it("updates visible loot content immediately while preserving quest borders", function()
        context = harness.Start({
            allowGameplay = true,
            globals = {
                GetNumLootItems = function()
                    return 1
                end,
                GetLootSlotType = function()
                    return 1
                end,
                GetLootSlotLink = function()
                    return "[Quest Item]"
                end,
                GetLootSlotInfo = function()
                    return 123, "Quest Item", 3, nil, 4, false, true
                end,
                C_Item = {
                    GetItemInfo = function()
                        return "Quest Item", nil, 4, 226, nil, nil, "Quest"
                    end,
                },
            },
        })
        ns = context.ns
        ns.LootAnimations = {}
        ns.LootFrame.Initialize()
        assert.is_true(ns.LootFrame.Show(false))
        local slot = findFrame(context, "DragonLootSlot1")
        assert.is_true(slot.subText:IsShown())
        assert.is_true(slot.quantity:IsShown())
        local cfg = ns.Addon.db.profile.lootWindow
        cfg.showDetails, cfg.showQuantity, cfg.qualityGlow = false, false, false
        cfg.backgroundIntensity = 0.5
        ns.LootFrame.ApplySettings()
        assert.is_false(slot.subText:IsShown())
        assert.is_false(slot.quantity:IsShown())
        assert.is_false(slot.iconGlow:IsShown())
        assert.are.equal(0.04, slot.rowBg.color[4])
        assert.are.same({ 1, 0.82, 0, 0.9 }, slot.iconBorder.color)
        assert.is_true(slot.iconBorder:IsShown())
        ns.Addon.db.profile.appearance.qualityBorder = false
        cfg.showDetails, cfg.showQuantity, cfg.qualityGlow = true, true, true
        ns.LootFrame.ApplySettings()
        assert.is_true(slot.subText:IsShown())
        assert.is_true(slot.quantity:IsShown())
        assert.is_true(slot.iconGlow:IsShown())
        assert.are.same({ 1, 0.82, 0, 0.9 }, slot.iconBorder.color)
        assert.is_true(slot.iconBorder:IsShown())
    end)

    it("updates live history geometry and timestamps without moving or rewriting history", function()
        context = harness.Start({ allowGameplay = true })
        ns = context.ns
        ns.Addon.db.char.history.entries = {
            { itemLink = "[Saved Item]", itemTexture = 123, quality = 4, winner = "TestPlayer", timestamp = GetTime() },
        }
        local cfg = ns.Addon.db.profile.history
        cfg.point, cfg.relativePoint, cfg.x, cfg.y = "CENTER", "CENTER", 25, -40
        ns.HistoryFrame.Initialize()
        ns.HistoryFrame.Show()
        local frame = findFrame(context, "DragonLootHistoryFrame")
        local row = findFrame(context, "DragonLootHistoryEntry1")
        local savedEntries = ns.Addon.db.char.history.entries
        cfg.width, cfg.height, cfg.scale, cfg.showTimestamp = 620, 240, 1.4, false
        ns.HistoryFrame.ApplySettings()
        assert.are.equal(620, frame:GetWidth())
        assert.are.equal(240, frame:GetHeight())
        assert.are.equal(1.4, frame.scale)
        assert.is_false(row.timeText:IsShown())
        context.timers[1]()
        assert.is_false(row.timeText:IsShown())
        cfg.showTimestamp = true
        ns.HistoryFrame.ApplySettings()
        assert.is_true(row.timeText:IsShown())
        assert.are.equal(25, cfg.x)
        assert.are.equal(-40, cfg.y)
        assert.are.equal(savedEntries, ns.Addon.db.char.history.entries)
        assert.are.equal("[Saved Item]", savedEntries[1].itemLink)
    end)

    it("keeps live roll timer updates hidden until timer text is enabled", function()
        context = harness.Start({
            allowGameplay = true,
            globals = {
                GetLootRollItemInfo = function()
                    return 123, "Roll Item", 1, 4, false, true, true, true
                end,
            },
        })
        ns = context.ns
        ns.Addon.db.profile.appearance.showItemLevel = false
        ns.RollAnimations = { PlayShow = function() end }
        ns.RollManager.GetActiveRolls = function()
            return {}
        end
        ns.RollFrame.Initialize()
        ns.RollFrame.ShowRoll(1, 99)
        local frame = findFrame(context, "DragonLootRoll1")
        local cfg = ns.Addon.db.profile.rollFrame
        cfg.showTimerText = false
        ns.RollFrame.ApplySettings()
        ns.RollFrame.UpdateTimer(1, 12, 30)
        assert.is_false(frame.timerBar.text:IsShown())
        cfg.showTimerText = true
        ns.RollFrame.ApplySettings()
        assert.is_true(frame.timerBar.text:IsShown())
        assert.are.equal("12", frame.timerBar.text:GetText())
        cfg.timerBarStyle = "minimal"
        ns.RollFrame.ApplySettings()
        ns.RollFrame.UpdateTimer(1, 11, 30)
        assert.is_false(frame.timerBar.text:IsShown())
    end)
end)
