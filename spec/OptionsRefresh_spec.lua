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
            assert.are.equal("sidebar", config.navigation)
            assert.is_true(config.settingsLayout)
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
        W.CreateSection = function(parent)
            local section = context.widget("Frame", nil, parent)
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
        return recorded, options.Tabs[1].refreshFunc
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
end)
