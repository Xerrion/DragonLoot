-------------------------------------------------------------------------------
-- Preview.lua
-- Pinned samples rendered by the real display modules, isolated from gameplay.
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L
local W = ns.DW.Widgets
local WC = ns.DW.WidgetConstants
local CreateFrame = CreateFrame
local math_min, math_max, math_floor = math.min, math.max, math.floor
local string_format = string.format

local KINDS = {
    { id = "loot", module = "LootFrame", label = L["Loot Window"], profile = "lootWindow" },
    { id = "roll", module = "RollFrame", label = L["Roll Frame"], profile = "rollFrame" },
    { id = "history", module = "HistoryFrame", label = L["History"], profile = "history" },
}
local TAB_PREVIEW = { lootWindow = "loot", lootRoll = "roll", history = "history" }

function ns.CreatePreview(host)
    local controller = { selected = "loot", fit = false, frames = {}, buttons = {} }
    local stage = CreateFrame("ScrollFrame", nil, host)
    stage:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -32)
    stage:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -12, 24)
    stage:EnableMouse(false)
    local canvas = CreateFrame("Frame", nil, stage)
    canvas:EnableMouse(false)
    stage:SetScrollChild(canvas)

    local caption = host:CreateFontString(nil, "OVERLAY")
    caption:SetFont(WC.FONT_PATH, WC.FONT_SIZE_SMALL, "")
    caption:SetTextColor(WC.GRAY_COLOR[1], WC.GRAY_COLOR[2], WC.GRAY_COLOR[3])
    caption:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 12, 7)
    caption:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -12, 7)
    caption:SetJustifyH("CENTER")
    caption:SetWordWrap(false)

    local function CreateChoice(id, label, width, x, onClick)
        local button = W.CreateButton(host, {
            text = label,
            width = width,
            onClick = onClick,
        })
        button:SetPoint("TOPLEFT", host, "TOPLEFT", x, -4)
        local marker = button:CreateTexture(nil, "OVERLAY")
        marker:SetColorTexture(WC.ACCENT_COLOR[1], WC.ACCENT_COLOR[2], WC.ACCENT_COLOR[3], 1)
        marker:SetHeight(2)
        marker:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 0)
        marker:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 0)
        button.selectionMark = marker
        controller.buttons[id] = button
    end
    for i, kind in ipairs(KINDS) do
        CreateChoice(kind.id, kind.label, 104, 12 + (i - 1) * 110, function()
            controller.selected = kind.id
        end)
    end
    CreateChoice("actual", L["Actual size"], 104, 354, function()
        controller.fit = false
    end)
    CreateChoice("fit", L["Fit"], 64, 464, function()
        controller.fit = true
    end)

    local function LayoutToolbar(availableWidth)
        local narrow = host:GetWidth() < 540
        local choiceWidth = math_min(104, math_max(1, (availableWidth - 12) / 3))
        for i, kind in ipairs(KINDS) do
            local button = controller.buttons[kind.id]
            button:SetWidth(choiceWidth)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", host, "TOPLEFT", 12 + (i - 1) * (choiceWidth + 6), -4)
        end
        local modeScale = narrow and math_min(1, availableWidth / 174) or 1
        local modeX, modeY = narrow and 12 or 354, narrow and -36 or -4
        controller.buttons.actual:SetWidth(104 * modeScale)
        controller.buttons.actual:ClearAllPoints()
        controller.buttons.actual:SetPoint("TOPLEFT", host, "TOPLEFT", modeX, modeY)
        controller.buttons.fit:SetWidth(64 * modeScale)
        controller.buttons.fit:ClearAllPoints()
        controller.buttons.fit:SetPoint("TOPLEFT", host, "TOPLEFT", modeX + 110 * modeScale, modeY)
        local stageTop = narrow and 64 or 32
        stage:ClearAllPoints()
        stage:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -stageTop)
        stage:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -12, 24)
        return stageTop
    end

    function controller:Refresh(tabId)
        if tabId and tabId ~= self.lastTab then
            self.selected = TAB_PREVIEW[tabId] or self.selected
            self.lastTab = tabId
        end
        local dl = ns.dlns
        if not dl or not dl.Addon or not dl.Addon.db then
            return
        end
        local availableWidth = math_max(1, host:GetWidth() - 24)
        local stageTop = LayoutToolbar(availableWidth)
        local availableHeight = math_max(1, host:GetHeight() - stageTop - 24)
        canvas:SetSize(availableWidth, availableHeight)
        self.buttons.actual.selectionMark:SetShown(not self.fit)
        self.buttons.fit.selectionMark:SetShown(self.fit)
        for _, kind in ipairs(KINDS) do
            local selected = self.selected == kind.id
            self.buttons[kind.id].selectionMark:SetShown(selected)
            local frame = self.frames[kind.id]
            if selected then
                local module = dl[kind.module]
                if not frame and module and module.CreatePreview then
                    frame = module.CreatePreview(canvas)
                    self.frames[kind.id] = frame
                end
                if frame then
                    frame:Refresh()
                    local width = frame.previewWidth or frame:GetWidth()
                    local height = frame.previewHeight or frame:GetHeight()
                    local cfg = dl.Addon.db.profile[kind.profile]
                    local scale = cfg.scale or 1
                    if self.fit then
                        scale = math_min(
                            1,
                            scale,
                            availableWidth / math_max(1, width),
                            availableHeight / math_max(1, height)
                        )
                    end
                    frame:SetScale(scale)
                    frame:ClearAllPoints()
                    if self.fit then
                        frame:SetPoint("CENTER", canvas, "CENTER", 0, 0)
                    else
                        frame:SetPoint("TOP", canvas, "TOP", 0, -math_max(0, height - frame:GetHeight()) / 2)
                    end
                    frame:Show()
                    local text = string_format(
                        L["%d x %d · %d%% · %s"],
                        frame:GetWidth(),
                        frame:GetHeight(),
                        math_floor(scale * 100 + 0.5),
                        self.fit and L["Fit"] or L["Actual size"]
                    )
                    if not self.fit and (width * scale > availableWidth or height * scale > availableHeight) then
                        text = text .. " · " .. L["Clipped preview"]
                    end
                    if cfg.enabled == false then
                        text = text .. " · " .. L["Feature disabled"]
                    end
                    caption:SetText(text)
                else
                    caption:SetText(L["Preview unavailable"])
                end
            elseif frame then
                frame:Hide()
            end
        end
    end

    function controller:OnHide()
        for _, frame in pairs(self.frames) do
            frame:Hide()
        end
    end

    return controller
end
