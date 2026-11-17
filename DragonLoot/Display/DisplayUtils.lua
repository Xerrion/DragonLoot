-------------------------------------------------------------------------------
-- DisplayUtils.lua
-- Shared display utilities for backdrop, font, and quality color helpers
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...

-------------------------------------------------------------------------------
-- Cached WoW API
-------------------------------------------------------------------------------

local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS

local LSM = LibStub("LibSharedMedia-3.0")

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local WHITE8x8 = "Interface\\Buttons\\WHITE8x8"
local chatFont = _G.ChatFontSmall
local MODERN_FONT = (chatFont and chatFont.GetFont and chatFont:GetFont())
    or STANDARD_TEXT_FONT
    or "Fonts\\FRIZQT__.TTF"

-- Core owns its media and palette; the load-on-demand options library is optional.
LSM:Register("font", "Dragon UI", MODERN_FONT, 255)
LSM:Register("border", "Dragon UI", WHITE8x8)
LSM:Register("statusbar", "Dragon UI", WHITE8x8)

-------------------------------------------------------------------------------
-- Module table
-------------------------------------------------------------------------------

local DisplayUtils = {}
ns.DisplayUtils = DisplayUtils

DisplayUtils.WHITE8x8 = WHITE8x8
DisplayUtils.TITLE_BAR_HEIGHT = 24
DisplayUtils.Style = {
    panel = { 0.035, 0.047, 0.065, 0.98 },
    border = { 0.22, 0.28, 0.35, 1 },
    title = { 0.065, 0.085, 0.115, 1 },
    text = { 0.91, 0.94, 0.97 },
    muted = { 0.62, 0.68, 0.75 },
    accent = { 0.28, 0.83, 0.73 },
}
local Style = DisplayUtils.Style

-------------------------------------------------------------------------------
-- GetQualityColor(quality) - returns r, g, b for an item quality
-------------------------------------------------------------------------------

function DisplayUtils.GetQualityColor(quality)
    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local qc = ITEM_QUALITY_COLORS[quality]
        return qc.r, qc.g, qc.b
    end
    if quality and ns.QUALITY_COLORS and ns.QUALITY_COLORS[quality] then
        local qc = ns.QUALITY_COLORS[quality]
        return qc.r, qc.g, qc.b
    end
    return 1, 1, 1
end

-------------------------------------------------------------------------------
-- GetFont(db) - returns fontPath, fontSize, fontOutline
-------------------------------------------------------------------------------

function DisplayUtils.GetFont(db)
    local appearance = db.profile.appearance
    local fontPath = LSM:Fetch("font", appearance.font) or MODERN_FONT
    return fontPath, appearance.fontSize, appearance.fontOutline
end

-------------------------------------------------------------------------------
-- ApplyFontShadow(fontString, db) - apply or remove text shadow
-------------------------------------------------------------------------------

function DisplayUtils.ApplyFontShadow(fontString, db)
    if not fontString or not fontString.SetShadowOffset then
        return
    end
    local appearance = db and db.profile and db.profile.appearance
    if not appearance then
        return
    end
    if appearance.fontShadow then
        fontString:SetShadowOffset(1, -1)
        fontString:SetShadowColor(0, 0, 0, 1)
    else
        fontString:SetShadowOffset(0, 0)
    end
end

-------------------------------------------------------------------------------
-- GetBackdropSettings(db) - returns a backdrop table
-------------------------------------------------------------------------------

function DisplayUtils.GetBackdropSettings(db)
    local appearance = db.profile.appearance
    local bgTexture = LSM:Fetch("background", appearance.backgroundTexture) or WHITE8x8
    local settings = { bgFile = bgTexture }
    if (appearance.borderSize or 1) > 0 then
        local edgeFile = LSM:Fetch("border", appearance.borderTexture)
        if edgeFile then
            settings.edgeFile = edgeFile
            settings.edgeSize = appearance.borderSize
        end
    end
    return settings
end

-------------------------------------------------------------------------------
-- ApplyBackdrop(frame, db) - applies backdrop, background color, border color
-------------------------------------------------------------------------------

function DisplayUtils.ApplyBackdrop(frame, db)
    if not db or not db.profile then
        return
    end
    local appearance = db.profile.appearance
    if not appearance then
        return
    end

    frame:SetBackdrop(DisplayUtils.GetBackdropSettings(db))

    local bg = appearance.backgroundColor
    if bg then
        frame:SetBackdropColor(
            bg.r or Style.panel[1],
            bg.g or Style.panel[2],
            bg.b or Style.panel[3],
            appearance.backgroundAlpha or Style.panel[4]
        )
    else
        frame:SetBackdropColor(
            Style.panel[1],
            Style.panel[2],
            Style.panel[3],
            appearance.backgroundAlpha or Style.panel[4]
        )
    end

    local border = appearance.borderColor
    if border then
        frame:SetBackdropBorderColor(
            border.r or Style.border[1],
            border.g or Style.border[2],
            border.b or Style.border[3],
            1
        )
    else
        frame:SetBackdropBorderColor(unpack(Style.border))
    end
end

function DisplayUtils.ApplyButtonSurface(button)
    button:SetBackdrop({ bgFile = WHITE8x8, edgeFile = WHITE8x8, edgeSize = 1 })
    button:SetBackdropColor(unpack(Style.title))
    button:SetBackdropBorderColor(unpack(Style.border))
    button:SetHighlightTexture(WHITE8x8)
    button:GetHighlightTexture():SetVertexColor(Style.accent[1], Style.accent[2], Style.accent[3], 0.16)
end

function DisplayUtils.ApplyCloseButtonFont(button, db)
    local font = DisplayUtils.GetFont(db)
    button.label:SetFont(font, 18, "")
    button.label:SetTextColor(unpack(Style.muted))
end

function DisplayUtils.CreateCloseButton(parent, db)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(20, 20)
    DisplayUtils.ApplyButtonSurface(button)
    button.label = button:CreateFontString(nil, "OVERLAY")
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    DisplayUtils.ApplyCloseButtonFont(button, db)
    button.label:SetText("\195\151")
    return button
end

function DisplayUtils.ApplyTitleBar(titleBar, db)
    local parent = titleBar:GetParent()
    local border = db.profile.appearance.borderSize or 1
    titleBar:SetHeight(DisplayUtils.TITLE_BAR_HEIGHT)
    titleBar:ClearAllPoints()
    titleBar:SetPoint("TOPLEFT", parent, "TOPLEFT", border, -border)
    titleBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -border, -border)

    local close = titleBar.closeButton
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -2, -2)
    DisplayUtils.ApplyCloseButtonFont(close, db)

    local font, size, flags = DisplayUtils.GetFont(db)
    local action = titleBar.clearButton
    if action then
        action:SetHeight(close:GetHeight())
        action:ClearAllPoints()
        action:SetPoint("RIGHT", close, "LEFT", -4, 0)
        action.text:SetFont(font, size, flags)
        DisplayUtils.ApplyFontShadow(action.text, db)
        action:SetWidth(action.text:GetStringWidth() + 12)
    end

    titleBar.text:ClearAllPoints()
    titleBar.text:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    titleBar.text:SetPoint("RIGHT", action or close, "LEFT", -8, 0)
    titleBar.text:SetJustifyH("LEFT")
    titleBar.text:SetFont(font, size, flags)
    DisplayUtils.ApplyFontShadow(titleBar.text, db)
end

function DisplayUtils.CreateTitleBar(parent, db, title)
    local titleBar = CreateFrame("Frame", nil, parent)
    titleBar.background = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBar.background:SetAllPoints()
    titleBar.background:SetColorTexture(unpack(Style.title))
    titleBar.accent = titleBar:CreateTexture(nil, "ARTWORK")
    titleBar.accent:SetSize(2, 12)
    titleBar.accent:SetPoint("LEFT", titleBar, "LEFT", 0, 0)
    titleBar.accent:SetColorTexture(Style.accent[1], Style.accent[2], Style.accent[3], 1)
    titleBar.separator = titleBar:CreateTexture(nil, "ARTWORK")
    titleBar.separator:SetHeight(1)
    titleBar.separator:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    titleBar.separator:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    titleBar.separator:SetColorTexture(unpack(Style.border))
    titleBar.text = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleBar.text:SetWordWrap(false)
    titleBar.text:SetTextColor(unpack(Style.text))
    titleBar.closeButton = DisplayUtils.CreateCloseButton(titleBar, db)
    DisplayUtils.ApplyTitleBar(titleBar, db)
    titleBar.text:SetText(title)
    return titleBar
end

-------------------------------------------------------------------------------
-- CaptureVisualState / RestoreVisualState - shared by animation modules
-------------------------------------------------------------------------------

function DisplayUtils.CaptureVisualState(frame)
    local alpha = frame:GetAlpha()
    local scale = frame:GetScale()
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    return alpha, scale, point, relativeTo, relativePoint, x, y
end

function DisplayUtils.RestoreVisualState(frame, alpha, scale, point, relativeTo, relativePoint, x, y)
    frame:SetAlpha(alpha)
    frame:SetScale(scale)
    if point then
        frame:ClearAllPoints()
        frame:SetPoint(point, relativeTo, relativePoint, x, y)
    end
end
