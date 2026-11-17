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

local function assertHeader(frame, border)
    local header = frame.titleBar
    local close = header.closeButton
    assert.are.equal(24, header:GetHeight())
    assert.are.same({
        { "TOPLEFT", frame, "TOPLEFT", border, -border },
        { "TOPRIGHT", frame, "TOPRIGHT", -border, -border },
    }, header.points)
    assert.are.equal(header, header.background.allPoints)
    assert.are.equal("LEFT", header.text.justifyH)
    assert.are.same({
        { "LEFT", header, "LEFT", 12, 0 },
        { "RIGHT", header.clearButton or close, "LEFT", -8, 0 },
    }, header.text.points)
    assert.are.same({ { "TOPRIGHT", header, "TOPRIGHT", -2, -2 } }, close.points)
    assert.are.equal(20, close:GetWidth())
    assert.are.equal(20, close:GetHeight())
    assert.are.same({ { "LEFT", header, "LEFT", 0, 0 } }, header.accent.points)
    assert.are.same({
        { "BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0 },
        { "BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0 },
    }, header.separator.points)
    if header.clearButton then
        assert.are.equal(close:GetHeight(), header.clearButton:GetHeight())
        assert.are.same({ { "RIGHT", close, "LEFT", -4, 0 } }, header.clearButton.points)
        assert.are.same(header.text.font, header.clearButton.text.font)
    end
end

describe("modern display style", function()
    local context
    before_each(function()
        mock.Reset()
    end)
    after_each(function()
        if context then
            context:Restore()
        end
    end)

    for _, case in ipairs({
        {
            name = "localized chat",
            chat = "Fonts\\LocalizedSans.ttf",
            standard = "Fonts\\Standard.ttf",
            expected = "Fonts\\LocalizedSans.ttf",
        },
        { name = "standard UI", standard = "Fonts\\Standard.ttf", expected = "Fonts\\Standard.ttf" },
        { name = "legacy fallback", expected = "Fonts\\FRIZQT__.TTF" },
    }) do
        it("registers the " .. case.name .. " font for every locale without the options library", function()
            context = harness.Start({
                globals = {
                    DragonWidgetsNS = false,
                    ChatFontSmall = {
                        GetFont = function()
                            return case.chat
                        end,
                    },
                    STANDARD_TEXT_FONT = case.standard or false,
                },
            })
            assert.are.same({ "font", "Dragon UI", case.expected, 255 }, context.registrations[1])
            assert.are.equal(case.expected, context.ns.DisplayUtils.GetFont(context.ns.Addon.db))
            assert.are.equal("Interface\\Buttons\\WHITE8x8", context.media.border["Dragon UI"])
            assert.are.equal("Interface\\Buttons\\WHITE8x8", context.media.statusbar["Dragon UI"])
        end)
    end

    it("uses modern surfaces and typography for all real-renderer previews", function()
        context = harness.Start({ globals = { ITEM_QUALITY_COLORS = { [4] = { r = 0.64, g = 0.21, b = 0.93 } } } })
        local ns = context.ns
        local parent = context.widget("Frame")
        local loot = ns.LootFrame.CreatePreview(parent)
        local history = ns.HistoryFrame.CreatePreview(parent)
        local roll = ns.RollFrame.CreatePreview(parent)
        assertHeader(loot, 1)
        assertHeader(history, 1)
        for _, frame in ipairs({ loot, history, roll }) do
            assert.are.same({ 0.035, 0.047, 0.065, 0.98 }, frame.background)
            assert.are.same({ 0.22, 0.28, 0.35, 1 }, frame.borderColor)
            assert.are.equal("Interface\\Buttons\\WHITE8x8", frame.backdrop.edgeFile)
        end
        assert.are.same({ 0.91, 0.94, 0.97 }, loot.title.textColor)
        assert.are.same(loot.title.textColor, history.titleBar.text.textColor)
        assert.are.same({ 0.065, 0.085, 0.115, 1 }, loot.titleBackground.color)
        assert.are.same(loot.titleBackground.color, history.titleBar.background.color)
        assert.are.same({ 0, 0 }, loot.title.shadowOffset)
        assert.are.equal("", loot.title.font[3])
        assert.are.same(loot.closeBtn.background, history.titleBar.closeButton.background)
        assert.are.equal("\195\151", loot.closeBtn.label:GetText())
        assert.are.same({ 0.28, 0.83, 0.73 }, roll.timerBar.statusColor)
        assert.are.same({ 0.065, 0.085, 0.115, 1 }, roll.timerBar.bg.color)
        assert.are.equal("Interface\\Buttons\\WHITE8x8", roll.timerBar.statusTexture)
        -- Rarity and class meaning remain outside the neutral chrome palette.
        local r, g, b = ns.DisplayUtils.GetQualityColor(4)
        assert.are.same({ r, g, b }, loot.previewRows[3].itemName.textColor)
        assert.are.same({ r, g, b }, roll.itemName.textColor)
        assert.are.same({ 0.64, 0.21, 0.93 }, roll.itemName.textColor)
    end)

    it("refreshes existing live frames and previews together while preserving customized geometry", function()
        context = harness.Start({
            allowGameplay = true,
            globals = {
                GetLootRollItemInfo = function()
                    return 123, "Roll Item", 1, 4, false, true, true, true
                end,
            },
        })
        local ns = context.ns
        local cfg = ns.Addon.db.profile
        cfg.appearance.font = "Custom Font"
        cfg.appearance.fontSize = 17
        cfg.appearance.backgroundColor = { r = 0.4, g = 0.2, b = 0.1 }
        cfg.appearance.borderSize = 3
        cfg.appearance.showItemLevel = false
        cfg.rollFrame.timerBarColor = { r = 1, g = 0, b = 0 }
        cfg.history.width, cfg.history.height, cfg.history.scale = 620, 240, 1.3
        cfg.lootWindow.x, cfg.lootWindow.y = 35, -80
        ns.LootAnimations = {}
        ns.RollAnimations = { PlayShow = function() end }
        ns.RollManager.GetActiveRolls = function()
            return {}
        end
        ns.RollManager.ApplySettings = ns.RollFrame.ApplySettings
        ns.LootFrame.Initialize()
        ns.HistoryFrame.Initialize()
        ns.RollFrame.Initialize()
        ns.RollFrame.ShowRoll(1, 99)
        local parent = context.widget("Frame")
        local previews = {
            ns.LootFrame.CreatePreview(parent),
            ns.HistoryFrame.CreatePreview(parent),
            ns.RollFrame.CreatePreview(parent),
        }
        local live = {
            findFrame(context, "DragonLootFrame"),
            findFrame(context, "DragonLootHistoryFrame"),
            findFrame(context, "DragonLootRoll1"),
        }
        for i, frame in ipairs(live) do
            assert.are.same({ 0.4, 0.2, 0.1, 0.98 }, frame.background)
            assert.are.same(frame.background, previews[i].background)
        end
        for i = 1, 2 do
            assertHeader(live[i], 3)
            assertHeader(previews[i], 3)
        end
        assert.are.same({ 1, 0, 0 }, live[3].timerBar.statusColor)
        ns.ApplyModernStyle()
        local historyScroll = findFrame(context, "DragonLootHistoryScroll")
        local liveScrollAnchors = historyScroll.points
        for i, preview in ipairs(previews) do
            preview:Refresh()
            assert.are.equal(liveScrollAnchors, historyScroll.points)
            assert.are.same({ 0.035, 0.047, 0.065, 0.98 }, live[i].background)
            assert.are.same(live[i].background, preview.background)
            assert.are.same(live[i].borderColor, preview.borderColor)
        end
        for i = 1, 2 do
            assertHeader(live[i], 1)
            assertHeader(previews[i], 1)
        end
        assert.are.same(live[1].title.font, previews[1].title.font)
        assert.are.same(live[2].titleBar.text.font, previews[2].titleBar.text.font)
        assert.are.same(live[3].timerBar.bg.color, previews[3].timerBar.bg.color)
        assert.are.same({ 0.28, 0.83, 0.73 }, live[3].timerBar.statusColor)
        assert.are.same(live[3].timerBar.statusColor, previews[3].timerBar.statusColor)
        assert.are.equal(17, cfg.appearance.fontSize)
        assert.are.equal(620, live[2]:GetWidth())
        assert.are.equal(240, live[2]:GetHeight())
        assert.are.equal(1.3, live[2].scale)
        assert.are.equal(35, cfg.lootWindow.x)
        assert.are.equal(-80, cfg.lootWindow.y)
        assert.is_function(live[1].closeBtn:GetScript("OnClick"))
        assert.is_function(live[2].titleBar.closeButton:GetScript("OnClick"))
        assert.is_function(live[2].titleBar.clearButton:GetScript("OnClick"))
        assert.is_nil(previews[1].closeBtn:GetScript("OnClick"))
        assert.is_nil(previews[2].titleBar.clearButton:GetScript("OnClick"))
    end)
end)
