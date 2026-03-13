-------------------------------------------------------------------------------
-- GeneralTab.lua
-- General settings tab: enabled, minimap icon, debug mode
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local LDF = LibDragonFramework

-------------------------------------------------------------------------------
-- Build the General tab content
-------------------------------------------------------------------------------

local function CreateContent(scrollChild)
    local dlns = ns.dlns
    local db = dlns.Addon.db

    local stack = LDF.CreateStackLayout(scrollChild)
    stack:SetPoint("TOPLEFT", scrollChild, "TOPLEFT")
    stack:SetPoint("RIGHT", scrollChild, "RIGHT")

    ---------------------------------------------------------------------------
    -- Section: General
    ---------------------------------------------------------------------------

    local section = LDF.CreateSection(scrollChild, L["General"], { columns = 1 })

    local contentStack = LDF.CreateStackLayout(section.content)
    contentStack:SetPoint("TOPLEFT", section.content, "TOPLEFT")
    contentStack:SetPoint("RIGHT", section.content, "RIGHT")
    contentStack:HookScript("OnSizeChanged", function(_, _, h)
        section.content:SetHeight(h)
    end)

    -- Toggle: Enable DragonLoot
    local enableToggle = LDF.CreateToggle(section.content, {
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
    contentStack:AddChild(enableToggle)

    -- Toggle: Show Minimap Icon
    local minimapToggle = LDF.CreateToggle(section.content, {
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
    contentStack:AddChild(minimapToggle)

    -- Toggle: Debug Mode
    local debugToggle = LDF.CreateToggle(section.content, {
        label = L["Debug Mode"],
        tooltip = L["Enable verbose debug output in chat"],
        get = function() return db.profile.debug end,
        set = function(value)
            db.profile.debug = value
        end,
    })
    contentStack:AddChild(debugToggle)

    stack:AddChild(section)
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
