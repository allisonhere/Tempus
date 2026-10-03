-- Tempus UI: Layered DPS track, scale. Decides what DPS the full width of the track stands
-- for, and eases displayed values toward their targets so nothing visibly jumps.
local _, T = ...
local DT = T.DPSTrack or {}
T.DPSTrack = DT

local Scale = {}
DT.Scale = Scale

Scale.HEADROOM = 0.88       -- dynamic mode puts the group top at 88% of the track
Scale.GROW_AT = 0.95        -- ... and rescales once it passes 95%
Scale.SHRINK_AT = 0.6       -- ... or falls below 60%

-- prev: the current target (nil after a reset). mode: TOP | DYNAMIC | FIXED.
-- Dynamic headroom only moves when the top leaves the 60-95% band, so the track stays still
-- through normal swings and the red segment never pins itself to the end of the frame.
function Scale.Target(prev, mode, top, fixedMax)
    if mode == "FIXED" then return math.max(1, tonumber(fixedMax) or 1) end
    top = (type(top) == "number" and top > 0) and top or 0
    if mode == "TOP" then return math.max(1, top) end
    if not prev or prev <= 1 or top > prev * Scale.GROW_AT or top < prev * Scale.SHRINK_AT then
        return math.max(1, top / Scale.HEADROOM)
    end
    return prev
end

-- Frame-rate independent exponential ease. speed 0 means no smoothing.
function Scale.Approach(cur, target, speed, dt)
    if not speed or speed <= 0 or not cur then return target end
    return cur + (target - cur) * (1 - math.exp(-speed * dt))
end
