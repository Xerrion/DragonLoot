-- Recording UI harness for isolated display previews; no implicit mock methods.
local mock = require("spec.wow_mock")
local M = {}

function M.Start()
    local previous, created = {}, {}
    local function override(name, value)
        previous[name] = { rawget(_G, name) }
        rawset(_G, name, value)
    end
    local function widget(kind, name, parent)
        local object = {
            kind = kind,
            name = name,
            parent = parent,
            shown = true,
            width = 0,
            height = 0,
            scripts = {},
            points = {},
            children = {},
            level = 0,
        }
        if parent and parent.children then
            table.insert(parent.children, object)
        end
        table.insert(created, object)
        function object:SetPoint(...)
            self.points[#self.points + 1] = { ... }
        end
        function object:ClearAllPoints()
            self.points = {}
        end
        function object:SetSize(w, h)
            self.width, self.height = w, h
        end
        function object:SetWidth(w)
            self.width = w
        end
        function object:SetHeight(h)
            self.height = h
        end
        function object:GetWidth()
            return self.width
        end
        function object:GetHeight()
            return self.height
        end
        function object:Show()
            self.shown = true
        end
        function object:Hide()
            self.shown = false
        end
        function object:IsShown()
            return self.shown
        end
        function object:SetShown(value)
            self.shown = value
        end
        function object:SetScript(event, fn)
            self.scripts[event] = fn
        end
        function object:GetScript(event)
            return self.scripts[event]
        end
        function object:HookScript(event, fn)
            local old = self.scripts[event]
            self.scripts[event] = function(...)
                if old then
                    old(...)
                end
                fn(...)
            end
        end
        function object:EnableMouse(value)
            self.mouse = value
        end
        function object:GetParent()
            return self.parent
        end
        function object:SetParent(value)
            self.parent = value
        end
        function object:SetFont(path, size, flags)
            self.font = { path, size, flags }
        end
        function object:SetText(value)
            self.text = value
        end
        function object:GetText()
            return self.text
        end
        function object:GetStringWidth()
            return #(self.text or "") * 6
        end
        function object:GetStringHeight()
            return self.font and self.font[2] or 12
        end
        function object:SetTextColor(...)
            self.textColor = { ... }
        end
        function object:SetBackdrop(value)
            self.backdrop = value
        end
        function object:SetBackdropColor(...)
            self.background = { ... }
        end
        function object:SetBackdropBorderColor(...)
            self.borderColor = { ... }
        end
        function object:SetTexture(value)
            self.texture = value
        end
        function object:SetColorTexture(...)
            self.color = { ... }
        end
        function object:SetValue(value)
            self.value = value
        end
        function object:SetScale(value)
            self.scale = value
        end
        function object:SetScrollChild(value)
            self.scrollChild = value
        end
        function object:SetFrameLevel(value)
            self.level = value
        end
        function object:GetFrameLevel()
            return self.level
        end
        function object:SetHighlightTexture()
            self.highlight = self.highlight or widget("Texture", nil, self)
        end
        function object:GetHighlightTexture()
            return self.highlight
        end
        function object:CreateTexture()
            return widget("Texture", nil, self)
        end
        function object:CreateFontString()
            return widget("FontString", nil, self)
        end
        function object:Enable()
            self.enabled = true
        end
        function object:Disable()
            self.enabled = false
        end
        function object:SetStatusBarTexture(value)
            self.statusTexture = value
        end
        function object:SetStatusBarColor(...)
            self.statusColor = { ... }
        end
        function object:SetFontString(value)
            self.fontString = value
        end
        function object:RegisterEvent()
            error("preview registered an event")
        end
        for _, method in ipairs({
            "SetAllPoints",
            "SetAlpha",
            "SetBlendMode",
            "SetGradient",
            "SetVertexColor",
            "SetTexCoord",
            "SetDrawLayer",
            "SetJustifyH",
            "SetJustifyV",
            "SetWordWrap",
            "SetNonSpaceWrap",
            "SetShadowColor",
            "SetShadowOffset",
            "RegisterForClicks",
            "RegisterForDrag",
            "SetMovable",
            "SetClampedToScreen",
            "SetFrameStrata",
            "SetNormalTexture",
            "SetPushedTexture",
            "SetDesaturated",
            "SetMinMaxValues",
            "SetHighlightAtlas",
            "SetAtlas",
        }) do
            object[method] = function() end
        end
        return object
    end
    override("CreateFrame", widget)
    override("CreateColor", function(...)
        return { ... }
    end)
    local function forbidden()
        error("preview reached gameplay, timers, or item queries")
    end
    for _, name in ipairs({
        "LootSlot",
        "CloseLoot",
        "GetLootSlotInfo",
        "GetNumLootItems",
        "GetLootSlotType",
        "GetLootSlotLink",
        "GetLootRollItemInfo",
        "GetLootRollItemLink",
        "RollOnLoot",
    }) do
        override(name, forbidden)
    end
    override("C_Timer", { After = forbidden, NewTicker = forbidden })
    override("C_Item", { GetItemInfo = forbidden, GetDetailedItemLevelInfo = forbidden })
    local oldLibStub = LibStub
    override("LibStub", function(name, ...)
        if name == "LibSharedMedia-3.0" then
            return {
                Fetch = function(_, _, value)
                    return value
                end,
                HashTable = function()
                    return {}
                end,
            }
        end
        return oldLibStub(name, ...)
    end)
    local ns = mock.CreateNamespace()
    ns.IsMainline = true
    ns.L = setmetatable({}, {
        __index = function(_, key)
            return key
        end,
    })
    mock.LoadConfig(ns)
    ns.InitializeDB(ns.Addon)
    ns.Addon.db.char = { history = { entries = { { itemLink = "real saved entry" } } } }
    ns.Addon.ScheduleTimer = forbidden
    ns.Addon.ScheduleRepeatingTimer = forbidden
    ns.Print = forbidden
    ns.RollTypeNames = {}
    mock.LoadFile(ns, "DragonLoot/Display/DisplayUtils.lua")
    for _, name in ipairs({ "LootFrame", "RollFrame", "HistoryFrame" }) do
        mock.LoadFile(ns, "DragonLoot/Display/" .. name .. ".lua")
    end
    ns.historyData[1] = { itemLink = "real live entry" }
    local context = { ns = ns, created = created, widget = widget }
    function context:Restore()
        for name, value in pairs(previous) do
            rawset(_G, name, value[1])
        end
    end
    return context
end

return M
