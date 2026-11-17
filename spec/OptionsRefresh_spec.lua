local harness = require("spec.preview_harness")
local mock = require("spec.wow_mock")

describe("options profile refresh", function()
    local context, originalNamespace, originalAPI
    before_each(function()
        context = harness.Start()
        originalNamespace = rawget(_G, "DragonLootNS")
        originalAPI = rawget(_G, "DragonLoot_Options")
    end)
    after_each(function()
        rawset(_G, "DragonLootNS", originalNamespace)
        rawset(_G, "DragonLoot_Options", originalAPI)
        context:Restore()
    end)

    it("registers profile callbacks before the Profiles page exists", function()
        local callbacks, refreshes, config = {}, 0, nil
        context.ns.Addon.db.RegisterCallback = function(_, event, fn)
            callbacks[event] = fn
        end
        rawset(_G, "DragonLootNS", context.ns)
        local originalDW = rawget(_G, "DragonWidgetsNS")
        rawset(_G, "DragonWidgetsNS", {
            On = function() end,
            CreateOptionsPanel = function(value)
                config = value
                return {
                    Open = function() end,
                    RefreshVisibleWidgets = function()
                        refreshes = refreshes + 1
                    end,
                }
            end,
        })
        local options = {}
        local ok, err = pcall(function()
            mock.LoadFile(options, "DragonLoot_Options/Core.lua")
            assert.is_function(callbacks.OnProfileChanged)
            assert.is_function(callbacks.OnProfileCopied)
            assert.is_function(callbacks.OnProfileReset)
            callbacks.OnProfileChanged()
            assert.are.equal(0, refreshes)
            rawget(_G, "DragonLoot_Options").Open()
            callbacks.OnProfileChanged()
            callbacks.OnProfileCopied()
            callbacks.OnProfileReset()
            assert.are.equal(3, refreshes)
            options.RefreshVisibleWidgets()
            assert.are.equal(4, refreshes)
            assert.is_nil(config.width)
            assert.is_nil(config.height)
            assert.is_nil(config.navigation)
            assert.is_nil(config.settingsLayout)
            assert.are.equal(220, config.preview.height)
        end)
        rawset(_G, "DragonWidgetsNS", originalDW)
        if not ok then
            error(err)
        end
    end)

    local function buildTab(file)
        local recorded = {}
        local W = {}
        for _, kind in ipairs({ "Toggle", "Slider", "Dropdown", "ColorPicker", "ItemList", "Button", "TextInput" }) do
            W["Create" .. kind] = function(parent, args)
                local widget = context.widget("Frame", nil, parent)
                widget:SetHeight(30)
                widget.disabled = not not args.disabled
                widget.options = args
                function widget:SetDisabled(value)
                    self.disabled = not not value
                end
                function widget:Refresh()
                    self.value = args.get and args.get()
                end
                function widget:GetValue()
                    return self.value
                end
                function widget:SetValue(value)
                    self.value = value
                end
                recorded[args.label or args.text or kind] = widget
                return widget
            end
        end
        W.CreateSection = function(parent, label)
            local section = context.widget("Frame", nil, parent)
            section.label = label
            section.content = context.widget("Frame", nil, section)
            function section:SetContentHeight(height)
                self:SetHeight(height + 40)
            end
            return section
        end
        W.CreateDescription = function(parent)
            local widget = context.widget("Frame", nil, parent)
            widget:SetHeight(20)
            return widget
        end
        local LC = {
            PADDING_TOP = -10,
            PADDING_BOTTOM = 20,
            PADDING_SIDE = 10,
            SECTION_PADDING_TOP = 8,
            SECTION_PADDING_BOTTOM = 12,
            SPACING_BETWEEN_WIDGETS = 6,
            SPACING_BETWEEN_SECTIONS = 16,
            BuildLSMValues = function()
                return {}
            end,
            NotifyAppearanceChange = function() end,
        }
        LC.AnchorWidget = function(widget, _, offset)
            return offset - widget:GetHeight()
        end
        LC.AnchorSection = LC.AnchorWidget
        local options = {
            dlns = context.ns,
            L = context.ns.L,
            DW = { Widgets = W, LayoutConstants = LC },
            Tabs = {},
            QualityValues = {},
        }
        mock.LoadFile(options, "DragonLoot_Options/Tabs/" .. file .. ".lua")
        options.Tabs[1].createFunc(context.widget("Frame"))
        return recorded, options.Tabs[1].refreshFunc, options.Tabs[1], options
    end

    for _, test in ipairs({
        { file = "LootWindowTab", path = "lootWindow", key = "enabled", label = "Lock Position" },
        { file = "AnimationTab", path = "animation", key = "enabled", label = "Open Duration" },
        { file = "HistoryTab", path = "history", key = "trackDirectLoot", label = "Minimum Quality" },
        { file = "AutoLootTab", path = "autoLoot", key = "enabled", label = "Minimum Quality" },
        { file = "NotificationsTab", path = "rollNotifications", key = "showRollWon", label = "Show Group Wins" },
    }) do
        it("recomputes dependent disabled controls in " .. test.file, function()
            local widgets, refresh = buildTab(test.file)
            context.ns.Addon.db.profile[test.path][test.key] = false
            refresh()
            assert.is_true(widgets[test.label].disabled)
            context.ns.Addon.db.profile[test.path][test.key] = true
            refresh()
            assert.is_false(widgets[test.label].disabled)
        end)
    end

    it("restores roll master and subordinate disabled states together", function()
        local widgets, refresh = buildTab("LootRollTab")
        local cfg = context.ns.Addon.db.profile.rollFrame
        cfg.enabled = false
        refresh()
        assert.is_true(widgets["Scale"].disabled)
        cfg.enabled = true
        cfg.compactTextLayout = true
        refresh()
        assert.is_false(widgets["Scale"].disabled)
        assert.is_true(widgets["Frame Height"].disabled)
        cfg.compactTextLayout = false
        refresh()
        assert.is_false(widgets["Frame Height"].disabled)
    end)

    it("recomputes loot content and background dependencies after a profile replacement", function()
        local widgets, refresh = buildTab("LootWindowTab")
        local db = context.ns.Addon.db
        local originalProfile = db.profile
        originalProfile.lootWindow.showDetails = false
        db.profile = { lootWindow = { enabled = false, showDetails = false }, appearance = { slotBackground = "flat" } }
        refresh()
        for _, label in ipairs({ "Show Item Details", "Show Stack Counts", "Quality Glow", "Background Intensity" }) do
            assert.is_true(widgets[label].disabled)
        end
        widgets["Show Item Details"]:Refresh()
        assert.is_false(widgets["Show Item Details"].value)
        db.profile.lootWindow.enabled = true
        refresh()
        assert.is_false(widgets["Show Item Details"].disabled)
        assert.is_false(widgets["Background Intensity"].disabled)
        widgets["Slot Background"].options.set("none")
        assert.is_true(widgets["Background Intensity"].disabled)
        widgets["Slot Background"].options.set("gradient")
        assert.is_false(widgets["Background Intensity"].disabled)
        widgets["Show Item Details"].options.set(true)
        assert.is_true(db.profile.lootWindow.showDetails)
        assert.is_false(originalProfile.lootWindow.showDetails)
    end)

    it("keeps timer text disabled for minimal bars and disabled roll frames", function()
        local widgets, refresh = buildTab("LootRollTab")
        local cfg = context.ns.Addon.db.profile.rollFrame
        assert.is_false(widgets["Show Timer Text"].disabled)
        widgets["Timer Bar Style"].options.set("minimal")
        assert.is_true(widgets["Show Timer Text"].disabled)
        cfg.enabled = false
        cfg.timerBarStyle = "normal"
        refresh()
        assert.is_true(widgets["Show Timer Text"].disabled)
        assert.is_true(widgets["Show Item Level"].disabled)
        cfg.enabled = true
        refresh()
        assert.is_false(widgets["Show Timer Text"].disabled)
        widgets["Show Timer Text"].options.set(false)
        assert.is_false(cfg.showTimerText)
    end)

    it("refreshes new history geometry and content controls with the feature state", function()
        local widgets, refresh = buildTab("HistoryTab")
        local cfg = context.ns.Addon.db.profile.history
        cfg.enabled = false
        refresh()
        for _, label in ipairs({ "Width", "Height", "Scale", "History Icon Size", "Show Timestamps" }) do
            assert.is_true(widgets[label].disabled)
        end
        cfg.enabled = true
        cfg.trackDirectLoot = false
        refresh()
        assert.is_false(widgets["Show Timestamps"].disabled)
        assert.is_true(widgets["Minimum Quality"].disabled)
        widgets["Width"].options.set(600)
        widgets["Height"].options.set(240)
        widgets["Scale"].options.set(1.3)
        widgets["Show Timestamps"].options.set(false)
        assert.are.equal(600, cfg.width)
        assert.are.equal(240, cfg.height)
        assert.are.equal(1.3, cfg.scale)
        assert.is_false(cfg.showTimestamp)
    end)

    it("keeps moved appearance controls on their feature pages using the existing saved keys", function()
        for _, test in ipairs({
            { "LootWindowTab", "Loot Icon Size", "lootIconSize", 48 },
            { "LootRollTab", "Roll Icon Size", "rollIconSize", 54 },
            { "HistoryTab", "History Icon Size", "historyIconSize", 32 },
            { "LootRollTab", "Show Item Level", "showItemLevel", false },
        }) do
            local widgets = buildTab(test[1])
            widgets[test[2]].options.set(test[4])
            assert.are.equal(test[4], context.ns.Addon.db.profile.appearance[test[3]])
            assert.are.equal(test[4], widgets[test[2]].options.get())
        end
        local shared = buildTab("AppearanceTab")
        assert.is_nil(shared["Loot Icon Size"])
        assert.is_nil(shared["Roll Icon Size"])
        assert.is_nil(shared["History Icon Size"])
        assert.is_nil(shared["Show Item Level"])
        assert.is_not_nil(shared["Quality Border"])
    end)

    it("applies the visible modern style action and requests controls and preview refresh", function()
        local widgets, _, _, options = buildTab("AppearanceTab")
        local profile = context.ns.Addon.db.profile
        profile.appearance.font = "Custom Font"
        profile.appearance.fontSize = 17
        profile.lootWindow.x = 123
        local refreshes = 0
        options.RefreshVisibleWidgets = function()
            refreshes = refreshes + 1
        end
        widgets["Apply Modern Style"].options.onClick()
        assert.are.equal("Dragon UI", profile.appearance.font)
        assert.are.equal(17, profile.appearance.fontSize)
        assert.are.equal(123, profile.lootWindow.x)
        assert.are.equal(1, refreshes)
        assert.are.equal("Style", widgets["Apply Modern Style"]:GetParent():GetParent().label)
    end)

    it("declares presentation pages before behavior and keeps actions in their own final sections", function()
        for _, test in ipairs({
            { "AppearanceTab", 5 },
            { "AnimationTab", 6 },
            { "AutoLootTab", 7 },
            { "NotificationsTab", 8 },
        }) do
            local _, _, tab = buildTab(test[1])
            assert.are.equal(test[2], tab.order)
        end
        local roll = buildTab("LootRollTab")
        assert.are.equal("Position and Testing", roll["Test Roll"]:GetParent():GetParent().label)
        local history = buildTab("HistoryTab")
        assert.are.equal("History Actions", history["Clear History"]:GetParent():GetParent().label)
    end)
end)
