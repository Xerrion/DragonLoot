local harness = require("spec.preview_harness")
local mock = require("spec.wow_mock")

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[key] = copy(child)
    end
    return result
end

local function CreateController(context, ns, host)
    local WC = {
        FONT_PATH = "font",
        FONT_SIZE_SMALL = 11,
        GRAY_COLOR = { 0.5, 0.5, 0.5 },
        ACCENT_COLOR = { 0.2, 0.8, 0.7 },
    }
    local opts = { dlns = ns, L = ns.L, DW = { WidgetConstants = WC, Widgets = {} } }
    opts.DW.Widgets.CreateButton = function(parent, args)
        local button = context.widget("Button", nil, parent)
        button:SetScript("OnClick", args.onClick)
        return button
    end
    mock.LoadFile(opts, "DragonLoot_Options/Preview.lua")
    return opts.CreatePreview(host)
end

describe("isolated settings previews", function()
    local context, ns, parent
    before_each(function()
        context = harness.Start()
        ns = context.ns
        parent = context.widget("Frame")
        parent:SetSize(800, 220)
    end)
    after_each(function()
        context:Restore()
    end)

    it("uses anonymous host-owned frames without gameplay input, timers, or persistence", function()
        local db = copy(ns.Addon.db)
        local history = copy(ns.historyData)
        local views = {}
        for _, kind in ipairs({ "LootFrame", "RollFrame", "HistoryFrame" }) do
            views[#views + 1] = ns[kind].CreatePreview(parent)
            views[#views]:Refresh()
            assert.are.equal(parent, views[#views]:GetParent())
        end
        for _, frame in ipairs(context.created) do
            assert.is_nil(frame.name)
            for _, event in ipairs({ "OnClick", "OnUpdate", "OnDragStart", "OnDragStop", "OnEnter", "OnLeave" }) do
                assert.is_nil(frame:GetScript(event))
            end
        end
        assert.are.same(db, ns.Addon.db)
        assert.are.same(history, ns.historyData)
        assert.are.equal(3, #views[1].previewRows)
        assert.are.equal(2, #views[3].previewRows)
    end)

    it("redraws existing real-renderer samples from a replaced profile", function()
        local loot = ns.LootFrame.CreatePreview(parent)
        local roll = ns.RollFrame.CreatePreview(parent)
        local history = ns.HistoryFrame.CreatePreview(parent)
        local count = #context.created
        ns.Addon.db.profile = copy(ns.Addon.db.profile)
        local profile = ns.Addon.db.profile
        profile.appearance.lootIconSize = 54
        profile.appearance.rollIconSize = 48
        profile.appearance.historyIconSize = 32
        profile.appearance.fontSize = 16
        profile.appearance.qualityBorder = false
        profile.lootWindow.width = 360
        profile.lootWindow.height = 420
        profile.rollFrame.frameWidth = 450
        profile.rollFrame.buttonSize = 30
        profile.rollFrame.timerBarStyle = "minimal"
        profile.rollFrame.timerBarMinimalHeight = 5
        profile.history.rowHeightPadding = 10
        loot:Refresh()
        roll:Refresh()
        history:Refresh()
        assert.are.equal(count, #context.created)
        assert.are.equal(360, loot:GetWidth())
        assert.are.equal(420, loot:GetHeight())
        assert.are.equal(54, loot.previewRows[1].iconFrame:GetWidth())
        assert.are.equal(16, loot.previewRows[1].itemName.font[2])
        assert.is_false(loot.previewRows[1].iconBorder:IsShown())
        assert.are.equal(450, roll:GetWidth())
        assert.are.equal(30, roll.needButton:GetWidth())
        assert.are.equal(5, roll.timerBar.container:GetHeight())
        assert.is_false(roll.needButton.mouse)
        assert.are.equal(32, history.previewRows[1].icon:GetWidth())
        assert.are.equal(42, history.previewRows[1]:GetHeight())
        assert.is_false(history.previewRows[1].iconBorder:IsShown())
    end)

    it("selects the relevant preview on tab changes and keeps manual choices during edits", function()
        local preview = CreateController(context, ns, parent)
        preview:Refresh("lootRoll")
        assert.are.equal("roll", preview.selected)
        assert.is_true(preview.frames.roll:IsShown())
        assert.is_true(preview.frames.roll.scale <= 1)
        preview.buttons.history:GetScript("OnClick")()
        preview:Refresh("lootRoll")
        assert.are.equal("history", preview.selected)
        assert.is_false(preview.frames.roll:IsShown())
        assert.is_true(preview.frames.history:IsShown())
        preview:Refresh("lootWindow")
        assert.are.equal("loot", preview.selected)
        preview:OnHide()
        for _, frame in pairs(preview.frames) do
            assert.is_false(frame:IsShown())
        end
    end)

    it("defaults to configured size in a clipped viewport and fits without changing settings", function()
        ns.Addon.db.profile.lootWindow.scale = 1.2
        local profile = copy(ns.Addon.db.profile)
        local preview = CreateController(context, ns, parent)
        preview:Refresh("lootWindow")
        local sample = preview.frames.loot
        local canvas = sample:GetParent()
        local viewport = canvas:GetParent()
        assert.are.equal("ScrollFrame", viewport.kind)
        assert.are.equal(canvas, viewport.scrollChild)
        assert.is_false(viewport.mouse)
        assert.is_nil(viewport:GetScript("OnMouseWheel"))
        assert.are.equal(1.2, sample.scale)
        assert.are.equal("TOP", sample.points[1][1])
        assert.is_true(preview.buttons.actual.selectionMark:IsShown())
        local caption
        for _, child in ipairs(parent.children) do
            if child.kind == "FontString" then
                caption = child
            end
        end
        assert.is_truthy(caption:GetText():find("Clipped preview", 1, true))

        local count = #context.created
        preview.buttons.fit:GetScript("OnClick")()
        assert.are.equal(1.2, sample.scale) -- shared scheduler owns the redraw
        preview:Refresh("lootWindow")
        assert.is_true(sample.scale < 1)
        assert.is_true(sample:GetHeight() * sample.scale <= parent:GetHeight() - 56)
        assert.are.equal("CENTER", sample.points[1][1])
        assert.is_true(preview.buttons.fit.selectionMark:IsShown())
        assert.is_nil(caption:GetText():find("Clipped preview", 1, true))

        preview.buttons.actual:GetScript("OnClick")()
        preview:Refresh("lootWindow")
        assert.are.equal(1.2, sample.scale)
        assert.are.equal(count, #context.created)
        assert.are.same(profile, ns.Addon.db.profile)
    end)

    it("wraps the toolbar and reduces the viewport when its host shrinks", function()
        local preview = CreateController(context, ns, parent)
        preview.buttons.fit:GetScript("OnClick")()
        preview:Refresh("history")
        local sample = preview.frames.history
        local canvas = sample:GetParent()
        local viewport = canvas:GetParent()
        parent:SetWidth(320)
        preview:Refresh("history")
        for _, button in pairs(preview.buttons) do
            local x = button.points[1][4]
            assert.is_true(x >= 12)
            assert.is_true(x + button:GetWidth() <= parent:GetWidth() - 12)
        end
        assert.are.equal(-4, preview.buttons.loot.points[1][5])
        assert.are.equal(-36, preview.buttons.actual.points[1][5])
        assert.are.equal(-36, preview.buttons.fit.points[1][5])
        assert.are.equal(-64, viewport.points[1][5])
        assert.are.equal(24, viewport.points[2][5])
        assert.are.equal(parent:GetHeight() - 88, canvas:GetHeight())
        assert.is_true(sample:GetHeight() * sample.scale <= canvas:GetHeight())

        parent:SetWidth(800)
        preview:Refresh("history")
        assert.are.equal(-4, preview.buttons.fit.points[1][5])
        assert.are.equal(-32, viewport.points[1][5])
        assert.are.equal(parent:GetHeight() - 56, canvas:GetHeight())
    end)
end)
