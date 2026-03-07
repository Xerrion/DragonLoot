-------------------------------------------------------------------------------
-- RollAnimations.lua
-- LibAnimate-driven animations for roll frame entrance and exit
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local ADDON_NAME, ns = ...

-------------------------------------------------------------------------------
-- LibAnimate reference
-------------------------------------------------------------------------------

local lib = LibStub("LibAnimate")

-------------------------------------------------------------------------------
-- State flag: true while a hide animation is in progress
-------------------------------------------------------------------------------

ns.RollAnimations.isClosing = false

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

--- Capture the frame's current visual state before StopAll wipes it.
local function CaptureVisualState(frame)
    local alpha = frame:GetAlpha()
    local scale = frame:GetScale()
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    return alpha, scale, point, relativeTo, relativePoint, x, y
end

--- Restore a previously captured visual state onto the frame.
local function RestoreVisualState(frame, alpha, scale, point, relativeTo, relativePoint, x, y)
    frame:SetAlpha(alpha)
    frame:SetScale(scale)
    if point then
        frame:ClearAllPoints()
        frame:SetPoint(point, relativeTo, relativePoint, x, y)
    end
end

-------------------------------------------------------------------------------
-- Public Interface: ns.RollAnimations
-------------------------------------------------------------------------------

function ns.RollAnimations.PlayShow(frame)
    local db = ns.Addon.db.profile
    local scale = db.rollFrame.scale or 1.0

    ns.RollAnimations.isClosing = false

    if not db.animation.enabled then
        frame:SetAlpha(1)
        frame:SetScale(scale)
        frame:Show()
        return
    end

    -- Stop any running animation (e.g. an in-progress hide) BEFORE setting
    -- initial state. lib:Stop restores pre-animation values, so we must call
    -- StopAll first, then overwrite with our desired initial state.
    ns.RollAnimations.StopAll(frame)

    local duration = db.animation.openDuration or 0.3

    frame:SetAlpha(0)
    frame:SetScale(scale)
    frame:Show()

    local animName = db.animation.rollShowAnim or "slideInRight"
    local ok = pcall(lib.Animate, lib, frame, animName, {
        duration = duration,
        distance = 50,
        onFinished = function()
            local s = ns.Addon.db and ns.Addon.db.profile.rollFrame.scale or 1.0
            frame:SetScale(s)
        end,
    })
    if not ok then
        frame:SetAlpha(1)
        frame:SetScale(scale)
    end
end

function ns.RollAnimations.PlayHide(frame, onFinished)
    local db = ns.Addon.db.profile

    ns.RollAnimations.isClosing = true

    if not db.animation.enabled then
        ns.RollAnimations.isClosing = false
        if onFinished then onFinished() end
        return
    end

    local duration = db.animation.closeDuration or 0.5

    -- Snapshot where the frame visually is RIGHT NOW (mid-show-animation or idle).
    local curAlpha, curScale, curPoint, curRelTo, curRelPoint, curX, curY =
        CaptureVisualState(frame)

    -- StopAll restores the frame to its pre-animation state (e.g. alpha=0 if the
    -- show animation was still running). We immediately overwrite with the snapshot
    -- so the hide animation starts from where the user actually saw the frame.
    ns.RollAnimations.StopAll(frame)
    RestoreVisualState(frame, curAlpha, curScale, curPoint, curRelTo, curRelPoint, curX, curY)

    local animName = db.animation.rollHideAnim or "fadeOut"
    local ok = pcall(lib.Animate, lib, frame, animName, {
        duration = duration,
        distance = 50,
        onFinished = function()
            local scale = ns.Addon.db and ns.Addon.db.profile.rollFrame.scale or 1.0
            frame:SetAlpha(1)
            frame:SetScale(scale)
            frame:Hide()

            ns.RollAnimations.isClosing = false
            if onFinished then onFinished() end
        end,
    })
    if not ok then
        local scale = ns.Addon.db and ns.Addon.db.profile.rollFrame.scale or 1.0
        frame:SetAlpha(1)
        frame:SetScale(scale)
        frame:Hide()
        ns.RollAnimations.isClosing = false
        if onFinished then onFinished() end
    end
end

function ns.RollAnimations.StopAll(frame)
    lib:ClearQueue(frame)
end
