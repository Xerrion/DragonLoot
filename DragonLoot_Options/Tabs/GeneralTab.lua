-------------------------------------------------------------------------------
-- GeneralTab.lua
-- General settings tab: enabled, minimap icon, debug mode
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local ADDON_NAME, ns = ...
local L = ns.L

-------------------------------------------------------------------------------
-- Cached globals
-------------------------------------------------------------------------------

local math_abs = math.abs

-------------------------------------------------------------------------------
-- Namespace references
-------------------------------------------------------------------------------

local dlns

-------------------------------------------------------------------------------
-- Build the General tab content
-------------------------------------------------------------------------------

local function CreateContent(parent)
    dlns = ns.dlns
    local LC = ns.LayoutConstants
    local W = ns.Widgets
    local db = dlns.Addon.db
    local yOffset = LC.PADDING_TOP

    ---------------------------------------------------------------------------
    -- Header: General
    ---------------------------------------------------------------------------
    local header = W.CreateHeader(parent, L["General"])
    yOffset = LC.AnchorWidget(header, parent, yOffset) - LC.SPACING_AFTER_HEADER

    ---------------------------------------------------------------------------
    -- Toggle: Enable DragonLoot
    ---------------------------------------------------------------------------
    local enableToggle = W.CreateToggle(parent, {
        label = L["Enable DragonLoot"],
        tooltip = L["Enable or disable the DragonLoot addon"],
        get = function() return db.profile.enabled end,
        set = function(value)
            db.profile.enabled = value
            if value then
                dlns.Addon:OnEnable()
            else
                dlns.Addon:OnDisable()
            end
        end,
    })
    yOffset = LC.AnchorWidget(enableToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    ---------------------------------------------------------------------------
    -- Toggle: Show Minimap Icon
    ---------------------------------------------------------------------------
    local minimapToggle = W.CreateToggle(parent, {
        label = L["Show Minimap Icon"],
        tooltip = L["Show or hide the minimap button"],
        get = function() return not db.profile.minimap.hide end,
        set = function(value)
            db.profile.minimap.hide = not value
            if dlns.MinimapIcon and dlns.MinimapIcon.Refresh then
                dlns.MinimapIcon.Refresh()
            end
        end,
    })
    yOffset = LC.AnchorWidget(minimapToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    ---------------------------------------------------------------------------
    -- Toggle: Debug Mode
    ---------------------------------------------------------------------------
    local debugToggle = W.CreateToggle(parent, {
        label = L["Debug Mode"],
        tooltip = L["Enable verbose debug output in chat"],
        get = function() return db.profile.debug end,
        set = function(value)
            db.profile.debug = value
        end,
    })
    yOffset = LC.AnchorWidget(debugToggle, parent, yOffset) - LC.SPACING_BETWEEN_WIDGETS

    ---------------------------------------------------------------------------
    -- Set content height for scroll frame
    ---------------------------------------------------------------------------
    parent:SetHeight(math_abs(yOffset) + LC.PADDING_BOTTOM)
end

-------------------------------------------------------------------------------
-- Register tab
-------------------------------------------------------------------------------

ns.Tabs = ns.Tabs or {}
ns.Tabs[#ns.Tabs + 1] = {
    id = "general",
    label = L["General"],
    order = 1,
    createFunc = CreateContent,
}
