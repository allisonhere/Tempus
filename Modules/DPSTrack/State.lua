-- Tempus UI: Layered DPS track, fight state. Turns a stream of (live, group top) readings
-- into the three milestones the track draws: live, your peak this fight, and the group top.
local _, T = ...
local DT = T.DPSTrack or {}
T.DPSTrack = DT

local State = {}
DT.State = State

local function Clean(v)
    return (type(v) == "number" and v == v and v > 0 and v < math.huge) and v or 0
end

function State.New()
    return { live = 0, peak = 0, top = 0, groupTop = 0 }
end

function State.Reset(s)
    s.live, s.peak, s.top, s.groupTop = 0, 0, 0, 0
end

-- live and groupTop must be readable numbers. The peak only rises until a reset. groupTop is
-- what the meter reports; top is the red edge, which never sits below the peak, so while you
-- lead the group the gold and red edges coincide and the red segment has no width.
function State.Update(s, live, groupTop)
    live, groupTop = Clean(live), Clean(groupTop)
    s.live = live
    if live > s.peak then s.peak = live end
    s.groupTop = math.max(groupTop, live)
    s.top = math.max(s.groupTop, s.peak)
    return s
end

-- 782K, 1.08M: short enough to sit under a thin bar.
function DT.Format(v)
    if type(v) ~= "number" or v ~= v or v < 0 then return "0" end
    if v >= 999.5e6 then return ("%.2fB"):format(v / 1e9) end
    if v >= 999.5e3 then return ("%.2fM"):format(v / 1e6) end
    if v >= 99.95e3 then return ("%dK"):format(math.floor(v / 1e3 + 0.5)) end
    if v >= 999.5 then return ("%.1fK"):format(v / 1e3) end
    return ("%d"):format(math.floor(v + 0.5))
end
