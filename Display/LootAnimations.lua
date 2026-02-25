-------------------------------------------------------------------------------
-- LootAnimations.lua
-- Open/close animations for the loot frame using LibAnimate
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local ADDON_NAME, ns = ...

-------------------------------------------------------------------------------
-- LibAnimate reference
-------------------------------------------------------------------------------

local lib = LibStub("LibAnimate")

-------------------------------------------------------------------------------
-- Public Interface: ns.LootAnimations
-------------------------------------------------------------------------------

function ns.LootAnimations.PlayOpen(frame)
    local db = ns.Addon.db.profile

    if not db.animation.enabled then
        frame:SetAlpha(1)
        frame:SetScale(1)
        frame:Show()
        return
    end

    local duration = db.animation.openDuration or 0.3

    frame:SetAlpha(0)
    frame:SetScale(0.9)
    frame:Show()

    ns.LootAnimations.StopAll(frame)

    lib:Animate(frame, "fadeIn", { duration = duration })
end

function ns.LootAnimations.PlayClose(frame, onFinished)
    local db = ns.Addon.db.profile

    if not db.animation.enabled then
        if onFinished then onFinished() end
        return
    end

    local duration = db.animation.closeDuration or 0.5

    ns.LootAnimations.StopAll(frame)

    lib:Animate(frame, "fadeOut", {
        duration = duration,
        onFinished = function()
            frame:SetAlpha(1)
            frame:SetScale(1)
            if onFinished then onFinished() end
        end,
    })
end

function ns.LootAnimations.StopAll(frame)
    lib:ClearQueue(frame)
end
