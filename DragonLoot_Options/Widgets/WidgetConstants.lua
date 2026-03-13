-------------------------------------------------------------------------------
-- WidgetConstants.lua
-- Shared constants and helpers for DragonLoot_Options widgets
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...

local GameTooltip = GameTooltip

-------------------------------------------------------------------------------
-- Shared constants used across multiple widget files
-------------------------------------------------------------------------------

ns.WidgetConstants = {
    FONT_PATH = "Fonts\\FRIZQT__.TTF",
    FONT_SIZE = 12,
    WHITE8x8 = "Interface\\Buttons\\WHITE8x8",
    WHITE_COLOR = { 1, 1, 1 },
    DISABLED_COLOR = { 0.5, 0.5, 0.5 },
    GRAY_COLOR = { 0.7, 0.7, 0.7 },
    EMPTY_ICON = "Interface\\PaperDoll\\UI-Backpack-EmptySlot",
}

-------------------------------------------------------------------------------
-- Shared tooltip handlers (used by Toggle, Button)
-------------------------------------------------------------------------------

function ns.WidgetConstants.ShowTooltip(frame)
    if not frame._tooltipText then return end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(frame._tooltipText, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

function ns.WidgetConstants.HideTooltip()
    GameTooltip:Hide()
end
