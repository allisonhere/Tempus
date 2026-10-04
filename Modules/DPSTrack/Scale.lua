-- Tempus UI: damage meter helpers shared with Combat Pulse, scale. Decides what DPS the full
-- width of the DPS bar stands for, and eases displayed values toward their targets so nothing visibly jumps.
local _, T = ...
local DT = T.DPSTrack or {}
T.DPSTrack = DT

local Scale = {}
DT.Scale = Scale

Scale.HEADROOM = 0.88       -- dynamic mode puts the group top at 88% of the track
Scale.GROW_AT = 0.95        -- ... and rescales once it passes 95%
Scale.STALE = 50            -- a saved range this many times the readable top is stale

-- prev: the current target (nil after a reset). mode: TOP | DYNAMIC | FIXED.
-- Dynamic range grows near the right edge and never shrinks before a meter reset.
function Scale.Target(prev, mode, top, fixedMax)
    if mode == "FIXED" then return math.max(1, tonumber(fixedMax) or 1) end
    top = (type(top) == "number" and top > 0) and top or 0
    if mode == "TOP" then return math.max(1, top) end
    if not prev or prev <= 1 or top > prev * Scale.GROW_AT then
        return math.max(1, top / Scale.HEADROOM)
    end
    return prev
end

-- Combat values cannot be compared to rescale. Hold twice the last readable top
-- so solo DPS changes remain visible even when the player is the group leader.
function Scale.Restore(saved, lastTop, peak)
    if type(saved) == "number" and saved > 1 then return saved end
    local top = math.max(lastTop or 0, peak or 0)
    if top > 0 then return math.max(1, top * 2) end
end

-- Frame-rate independent exponential ease. speed 0 means no smoothing.
function Scale.Approach(cur, target, speed, dt)
    if not speed or speed <= 0 or not cur then return target end
    return cur + (target - cur) * (1 - math.exp(-speed * dt))
end
