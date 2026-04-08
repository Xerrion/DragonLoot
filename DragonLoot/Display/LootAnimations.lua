-------------------------------------------------------------------------------
-- LootAnimations.lua
-- Open/close animations for the loot frame using LibAnimate
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local _, ns = ...

-------------------------------------------------------------------------------
-- Cached WoW API
-------------------------------------------------------------------------------

local UIParent = UIParent

local LOOT_ANIMATION_DISTANCE = 50

-------------------------------------------------------------------------------
-- LibAnimate reference
-------------------------------------------------------------------------------

local lib = LibStub("LibAnimate")

-------------------------------------------------------------------------------
-- DisplayUtils shorthand
-------------------------------------------------------------------------------

local DU = ns.DisplayUtils

-------------------------------------------------------------------------------
-- State flag: true while a close animation is in progress
-------------------------------------------------------------------------------

ns.LootAnimations.isClosing = false

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

--- Restore the frame's anchor to the saved DB position so the next open starts correctly.
local function RestoreDbAnchor(frame)
    local db = ns.Addon.db and ns.Addon.db.profile and ns.Addon.db.profile.lootWindow
    if not db then
        return
    end
    frame:ClearAllPoints()
    if db.point then
        frame:SetPoint(db.point, UIParent, db.relativePoint, db.x or 0, db.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-------------------------------------------------------------------------------
-- Public Interface: ns.LootAnimations
-------------------------------------------------------------------------------

function ns.LootAnimations.PlayOpen(frame)
    local db = ns.Addon.db and ns.Addon.db.profile
    if not db then
        frame:Show()
        return
    end
    local lootWindow = db.lootWindow or {}
    local animation = db.animation or {}
    local scale = lootWindow.scale or 1.0

    ns.LootAnimations.isClosing = false

    if not animation.enabled then
        frame:SetAlpha(1)
        frame:SetScale(scale)
        frame:Show()
        return
    end

    -- Stop any running animation (e.g. an in-progress close) BEFORE setting
    -- initial state. lib:Stop restores pre-animation values, so we must call
    -- StopAll first, then overwrite with our desired initial state.
    ns.LootAnimations.StopAll(frame)

    local duration = animation.openDuration or 0.3

    frame:SetAlpha(0)
    frame:SetScale(scale)
    frame:Show()

    local animName = animation.lootOpenAnim or "fadeIn"
    local ok = pcall(lib.Animate, lib, frame, animName, {
        duration = duration,
        distance = LOOT_ANIMATION_DISTANCE,
        onFinished = function()
            local profile = ns.Addon.db and ns.Addon.db.profile
            local s = profile and profile.lootWindow and profile.lootWindow.scale or 1.0
            frame:SetScale(s)
        end,
    })
    if not ok then
        frame:SetAlpha(1)
        frame:SetScale(scale)
    end
end

function ns.LootAnimations.PlayClose(frame, onFinished)
    local db = ns.Addon.db and ns.Addon.db.profile
    if not db then
        frame:Hide()
        if onFinished then
            onFinished()
        end
        return
    end
    local animation = db.animation or {}

    ns.LootAnimations.isClosing = true

    if not animation.enabled then
        ns.LootAnimations.isClosing = false
        frame:Hide()
        if onFinished then
            onFinished()
        end
        return
    end

    local duration = animation.closeDuration or 0.5

    -- Snapshot where the frame visually is RIGHT NOW (mid-open-animation or idle).
    local curAlpha, curScale, curPoint, curRelTo, curRelPoint, curX, curY = DU.CaptureVisualState(frame)

    -- StopAll restores the frame to its pre-animation state (e.g. alpha=0 if the
    -- open animation was still running). We immediately overwrite with the snapshot
    -- so the close animation starts from where the user actually saw the frame.
    ns.LootAnimations.StopAll(frame)
    DU.RestoreVisualState(frame, curAlpha, curScale, curPoint, curRelTo, curRelPoint, curX, curY)

    local animName = animation.lootCloseAnim or "fadeOut"
    local ok = pcall(lib.Animate, lib, frame, animName, {
        duration = duration,
        distance = LOOT_ANIMATION_DISTANCE,
        onFinished = function()
            local profile = ns.Addon.db and ns.Addon.db.profile
            local scale = profile and profile.lootWindow and profile.lootWindow.scale or 1.0
            frame:SetAlpha(1)
            frame:SetScale(scale)
            frame:Hide()

            -- Restore the DB-saved anchor so the next open starts at the right spot
            RestoreDbAnchor(frame)

            ns.LootAnimations.isClosing = false
            if onFinished then
                onFinished()
            end
        end,
    })
    if not ok then
        local profile = ns.Addon.db and ns.Addon.db.profile
        local scale = profile and profile.lootWindow and profile.lootWindow.scale or 1.0
        frame:SetAlpha(1)
        frame:SetScale(scale)
        frame:Hide()
        RestoreDbAnchor(frame)
        ns.LootAnimations.isClosing = false
        if onFinished then
            onFinished()
        end
    end
end

function ns.LootAnimations.StopAll(frame)
    lib:ClearQueue(frame)
end
