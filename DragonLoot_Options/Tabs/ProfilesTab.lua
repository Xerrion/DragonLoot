-------------------------------------------------------------------------------
-- ProfilesTab.lua
-- Profile management tab: switch, create, copy, reset, delete profiles
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local LDF = LibDragonFramework

-------------------------------------------------------------------------------
-- Cached globals
-------------------------------------------------------------------------------

local table_sort = table.sort
local StaticPopup_Show = StaticPopup_Show
local StaticPopupDialogs = StaticPopupDialogs
local YES = YES
local NO = NO

-------------------------------------------------------------------------------
-- Namespace references
-------------------------------------------------------------------------------

local dlns

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local NEW_PROFILE_INPUT_WIDTH = 250

-------------------------------------------------------------------------------
-- Static popup dialogs (defined at file scope)
-------------------------------------------------------------------------------

StaticPopupDialogs["DRAGONLOOT_RESET_PROFILE"] = {
    text = L["Are you sure you want to reset the current profile to defaults?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        local db = dlns.Addon.db
        db:ResetProfile()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["DRAGONLOOT_DELETE_PROFILE"] = {
    text = L["Are you sure you want to delete profile \"%s\"?"],
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-------------------------------------------------------------------------------
-- Build sorted profile values from AceDB
-------------------------------------------------------------------------------

local function GetProfileValues(db)
    local profiles = db:GetProfiles({})
    table_sort(profiles)
    local values = {}
    for i = 1, #profiles do
        values[#values + 1] = { value = profiles[i], text = profiles[i] }
    end
    return values
end

-------------------------------------------------------------------------------
-- Build profile values excluding the current profile
-------------------------------------------------------------------------------

local function GetOtherProfileValues(db)
    local current = db:GetCurrentProfile()
    local profiles = db:GetProfiles({})
    table_sort(profiles)
    local values = {}
    for i = 1, #profiles do
        if profiles[i] ~= current then
            values[#values + 1] = { value = profiles[i], text = profiles[i] }
        end
    end
    return values
end

-------------------------------------------------------------------------------
-- Build the Profiles tab content
-------------------------------------------------------------------------------

local function CreateContent(scrollChild)
    dlns = ns.dlns
    local db = dlns.Addon.db

    local stack = LDF.CreateStackLayout(scrollChild)
    stack:SetPoint("TOPLEFT", scrollChild, "TOPLEFT")
    stack:SetPoint("RIGHT", scrollChild, "RIGHT")

    -- Forward-declare widget refs for refresh closure
    local activeDropdown, copyDropdown, deleteDropdown

    local function RefreshProfileWidgets()
        if activeDropdown then activeDropdown:Refresh() end
        if copyDropdown then copyDropdown:Refresh() end
        if deleteDropdown then deleteDropdown:Refresh() end
    end

    ---------------------------------------------------------------------------
    -- Description
    ---------------------------------------------------------------------------

    local desc = LDF.CreateDescription(scrollChild,
        L["Profiles allow you to save different settings configurations. You can switch between"
        .. " profiles, copy settings from another profile, or reset to defaults."])
    stack:AddChild(desc)

    ---------------------------------------------------------------------------
    -- Section: Current Profile
    ---------------------------------------------------------------------------

    local currentSection = LDF.CreateSection(scrollChild, L["Current Profile"], { columns = 1 })

    local currentStack = LDF.CreateStackLayout(currentSection.content)
    currentStack:SetPoint("TOPLEFT", currentSection.content, "TOPLEFT")
    currentStack:SetPoint("RIGHT", currentSection.content, "RIGHT")
    currentStack:HookScript("OnSizeChanged", function(_, _, h)
        currentSection.content:SetHeight(h)
    end)

    -- Dropdown: Active Profile
    activeDropdown = LDF.CreateDropdown(currentSection.content, {
        label = L["Active Profile"],
        values = function() return GetProfileValues(db) end,
        get = function() return db:GetCurrentProfile() end,
        set = function(value)
            db:SetProfile(value)
            RefreshProfileWidgets()
        end,
    })
    currentStack:AddChild(activeDropdown)

    -- TextInput: New Profile (added to stack for vertical flow)
    local newProfileInput = LDF.CreateTextInput(currentSection.content, {
        label = L["New Profile"],
        width = NEW_PROFILE_INPUT_WIDTH,
        maxLength = 64,
    })
    currentStack:AddChild(newProfileInput)

    -- Button: Create (positioned beside the text input, NOT in stack)
    local createBtn = LDF.CreateButton(currentSection.content, {
        text = L["Create"],
        width = 80,
        tooltip = L["Create a new profile with the entered name and switch to it"],
        onClick = function()
            local name = newProfileInput:GetValue()
            if not name or name == "" then return end
            db:SetProfile(name)
            newProfileInput:SetValue("")
            RefreshProfileWidgets()
        end,
    })
    createBtn:ClearAllPoints()
    createBtn:SetPoint("LEFT", newProfileInput._ldf.editBox, "RIGHT", 8, 0)

    stack:AddChild(currentSection)

    ---------------------------------------------------------------------------
    -- Section: Profile Actions
    ---------------------------------------------------------------------------

    local actionsSection = LDF.CreateSection(scrollChild, L["Profile Actions"], { columns = 1 })

    local actionsStack = LDF.CreateStackLayout(actionsSection.content)
    actionsStack:SetPoint("TOPLEFT", actionsSection.content, "TOPLEFT")
    actionsStack:SetPoint("RIGHT", actionsSection.content, "RIGHT")
    actionsStack:HookScript("OnSizeChanged", function(_, _, h)
        actionsSection.content:SetHeight(h)
    end)

    -- Dropdown: Copy From
    copyDropdown = LDF.CreateDropdown(actionsSection.content, {
        label = L["Copy From"],
        values = function() return GetOtherProfileValues(db) end,
        get = function() return nil end,
        set = function(value)
            db:CopyProfile(value)
            RefreshProfileWidgets()
        end,
    })
    actionsStack:AddChild(copyDropdown)

    -- Button: Reset Current Profile
    local resetBtn = LDF.CreateButton(actionsSection.content, {
        text = L["Reset Current Profile"],
        width = 160,
        tooltip = L["Reset all settings in the current profile to their default values"],
        onClick = function()
            StaticPopup_Show("DRAGONLOOT_RESET_PROFILE")
        end,
    })
    actionsStack:AddChild(resetBtn)

    -- Dropdown: Delete Profile
    deleteDropdown = LDF.CreateDropdown(actionsSection.content, {
        label = L["Delete Profile"],
        values = function() return GetOtherProfileValues(db) end,
        get = function() return nil end,
        set = function(value)
            StaticPopupDialogs["DRAGONLOOT_DELETE_PROFILE"].OnAccept = function()
                db:DeleteProfile(value)
                RefreshProfileWidgets()
            end
            StaticPopup_Show("DRAGONLOOT_DELETE_PROFILE", value)
        end,
    })
    actionsStack:AddChild(deleteDropdown)

    stack:AddChild(actionsSection)
end

-------------------------------------------------------------------------------
-- Register tab
-------------------------------------------------------------------------------

ns.Tabs = ns.Tabs or {}
ns.Tabs[#ns.Tabs + 1] = {
    id = "profiles",
    label = L["Profiles"],
    order = 8,
    createFunc = CreateContent,
}
