-- Recording UI harness for isolated display previews; no implicit mock methods.
local mock = require("spec.wow_mock")
local M = {}

function M.Start(options)
    options = options or {}
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
            assert(self:HasScript(event), self.kind .. " does not support " .. event)
            self.scripts[event] = fn
        end
        function object:HasScript(event)
            if self.kind == "Texture" or self.kind == "FontString" then
                return false
            end
            if event == "OnClick" then
                return self.kind == "Button"
            elseif event == "OnValueChanged" then
                return self.kind == "Slider"
            end
            return event == "OnEnter"
                or event == "OnLeave"
                or event == "OnUpdate"
                or event == "OnDragStart"
                or event == "OnDragStop"
                or event == "OnMouseWheel"
                or event == "OnSizeChanged"
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
            if self.kind == "FontString" and value ~= nil and value ~= "" then
                assert(self.font or self.fontTemplate, "FontString:SetText(): Font not set")
            end
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
        function object:SetJustifyH(value)
            self.justifyH = value
        end
        function object:SetAllPoints(relative)
            self.allPoints = relative or self.parent
        end
        function object:SetShadowOffset(...)
            self.shadowOffset = { ... }
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
        function object:SetGradient(...)
            self.gradient = { ... }
        end
        function object:SetValue(value)
            self.value = value
        end
        function object:GetValue()
            return self.value or 0
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
        function object:CreateFontString(fontName, _, template)
            local fontString = widget("FontString", fontName, self)
            fontString.fontTemplate = template
            return fontString
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
            "SetAlpha",
            "SetBlendMode",
            "SetVertexColor",
            "SetTexCoord",
            "SetDrawLayer",
            "SetJustifyV",
            "SetWordWrap",
            "SetNonSpaceWrap",
            "SetShadowColor",
            "RegisterForClicks",
            "RegisterForDrag",
            "SetMovable",
            "SetClampedToScreen",
            "SetFrameStrata",
            "SetNormalTexture",
            "SetPushedTexture",
            "SetDesaturated",
            "SetMinMaxValues",
            "EnableMouseWheel",
            "SetOrientation",
            "SetValueStep",
            "SetThumbTexture",
            "SetVerticalScroll",
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
    for _, name in
        ipairs(options.allowGameplay and {} or {
            "LootSlot",
            "CloseLoot",
            "GetLootSlotInfo",
            "GetNumLootItems",
            "GetLootSlotType",
            "GetLootSlotLink",
            "GetLootRollItemInfo",
            "GetLootRollItemLink",
            "RollOnLoot",
        })
    do
        override(name, forbidden)
    end
    if not options.allowGameplay then
        override("C_Timer", { After = forbidden, NewTicker = forbidden })
        override("C_Item", { GetItemInfo = forbidden, GetDetailedItemLevelInfo = forbidden })
    end
    for name, value in pairs(options.globals or {}) do
        override(name, value)
    end
    local oldLibStub = LibStub
    local media, registrations = {}, {}
    local mediaLibrary = {
        Register = function(_, kind, name, value, languageMask)
            media[kind] = media[kind] or {}
            media[kind][name] = value
            registrations[#registrations + 1] = { kind, name, value, languageMask }
        end,
        Fetch = function(_, kind, value)
            return media[kind] and media[kind][value] or value
        end,
        HashTable = function(_, kind)
            return media[kind] or {}
        end,
    }
    override("LibStub", function(name, ...)
        if name == "LibSharedMedia-3.0" then
            return mediaLibrary
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
    local timers = {}
    local function RecordTimer(_, callback)
        timers[#timers + 1] = callback
        return #timers
    end
    ns.Addon.ScheduleTimer = options.allowGameplay and RecordTimer or forbidden
    ns.Addon.ScheduleRepeatingTimer = options.allowGameplay and RecordTimer or forbidden
    ns.Print = options.allowGameplay and function() end or forbidden
    ns.RollTypeNames = {}
    mock.LoadFile(ns, "DragonLoot/Display/DisplayUtils.lua")
    for _, name in ipairs({ "LootFrame", "RollFrame", "HistoryFrame" }) do
        mock.LoadFile(ns, "DragonLoot/Display/" .. name .. ".lua")
    end
    ns.historyData[1] = { itemLink = "real live entry" }
    local context = {
        ns = ns,
        created = created,
        widget = widget,
        timers = timers,
        media = media,
        registrations = registrations,
    }
    function context:Restore()
        for name, value in pairs(previous) do
            rawset(_G, name, value[1])
        end
    end
    return context
end

return M
