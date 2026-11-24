-- Flight timer: a bar while you ride a flight path. The first time you fly a route it counts up; Tempus
-- remembers how long the flight took (averaging later trips), so the next time it counts down the time left.
local _, T = ...
local FT = { defaults = { enabled = true, width = 240, height = 22, point = { "TOP", "UIParent", "TOP", 0, -190 }, times = {} } }
T.FlightTimer = FT

local MIN_FLIGHT = 3          -- seconds; anything shorter was not a real flight
local PENDING_FOR = 90        -- seconds a chosen flight waits for take-off before it is forgotten

function FT.Key(from, to) return tostring(from) .. " > " .. tostring(to) end

function FT.Clock(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- Remember a finished flight: the first time as it was, later ones averaged with what is known.
function FT.Record(times, key, seconds)
    if type(seconds) ~= "number" or seconds < MIN_FLIGHT then return nil end
    local old = times[key]
    times[key] = old and math.floor((old + seconds) / 2 + 0.5) or math.floor(seconds + 0.5)
    return times[key]
end

-- What the bar shows after `elapsed` seconds: a fill 0..1 and the time text. With a known flight length it
-- counts down; without one it counts up and the fill stays empty.
function FT.State(elapsed, known)
    if type(known) == "number" and known > 0 then
        return math.min(1, math.max(0, elapsed / known)), FT.Clock(known - elapsed), true
    end
    return 0, FT.Clock(elapsed), false
end

-- The flight map's nodes, as the origin's name and a name for each slot you can pick.
function FT:ReadMap()
    self.origin, self.slots = nil, {}
    local mapID = (GetTaxiMapID and GetTaxiMapID()) or nil
    local ok, nodes = pcall(C_TaxiMap and C_TaxiMap.GetAllTaxiNodes or error, mapID)
    if not (ok and type(nodes) == "table") then return end
    local current = Enum and Enum.FlightPathState and Enum.FlightPathState.Current or 0
    for _, node in ipairs(nodes) do
        if node.state == current then self.origin = node.name end
        if node.slotIndex then self.slots[node.slotIndex] = node.name end
    end
end

function FT:Chosen(slot)
    local to = self.slots and self.slots[slot]
    if self.origin and to then self.pending = { from = self.origin, to = to, at = GetTime() } end
end

function FT:Begin(now)
    local p = self.pending
    self.pending = nil
    if not p then return end
    self.flight = { key = FT.Key(p.from, p.to), from = p.from, to = p.to, start = now }
end

function FT:End(now)
    local f = self.flight
    self.flight = nil
    if f and self.db then FT.Record(self.db.times, f.key, now - f.start) end
end

-- One step of the watch loop; returns the fill and text to draw, or nil when there is no flight to show.
function FT:Step(now, onTaxi)
    if self.pending and now - self.pending.at > PENDING_FOR then self.pending = nil end
    if not self.flight and onTaxi and self.pending then self:Begin(now) end
    if self.flight and not onTaxi then self:End(now) return nil end
    local f = self.flight
    if not f then return nil end
    local fill, text, counting = FT.State(now - f.start, self.db and self.db.times[f.key])
    return fill, text, f, counting
end

T:NewModule("flighttimer", {
    label = "Flight timer",
    desc = "A bar while you ride a flight path: it learns how long each route takes and counts down the time left.",
    defaults = FT.defaults,
    OnEnable = function()
        FT.db = T.db.flighttimer
        local S = T.Style
        local f = CreateFrame("Frame", "TempusFlightTimer", UIParent)
        f:SetSize(FT.db.width, FT.db.height)
        f:SetFrameStrata("MEDIUM")
        S.Backdrop(f, {})
        f.fill = S.Tex(f, "ARTWORK")
        f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
        S.Accent(f.fill, 0.55)
        f.hourglass = S.Tex(f, "OVERLAY")
        f.hourglass:SetTexture("Interface\\AddOns\\Tempus\\media\\hourglass-animated")
        f.hourglass.tempus = true
        f.hourglass:SetSize(FT.db.height, FT.db.height)
        f.hourglass:SetPoint("LEFT", 2, 0)
        f.learning = S.Text(f, 11, S.C.text, "OUTLINE")
        f.learning:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 3)
        f.learning:SetText("Learning route")
        f.learning:Hide()
        -- Use the same sand-and-flip timing as the settings header.
        local index, accumulated = 1, 0
        f:SetScript("OnUpdate", function(_, elapsed)
            if T.db.animate == false then
                index, accumulated = 1, 0
            else
                accumulated = accumulated + elapsed
                local changes = 0
                local duration = (index <= 19 and 0.18) or (index == 20 and 0.76) or 0.07
                while accumulated >= duration and changes < 4 do
                    accumulated = accumulated - duration
                    index = index % 30 + 1
                    duration = (index <= 19 and 0.18) or (index == 20 and 0.76) or 0.07
                    changes = changes + 1
                end
                if changes == 4 then accumulated = 0 end
            end
            local col, row = (index - 1) % 8, math.floor((index - 1) / 8)
            f.hourglass:SetTexCoord(col / 8, (col + 1) / 8, row / 4, (row + 1) / 4)
        end)
        f.hourglass:SetTexCoord(0, 1 / 8, 0, 1 / 4)
        f.name = S.Text(f, 11, S.C.text)
        f.name:SetPoint("LEFT", FT.db.height + 4, 0)
        f.name:SetWidth(math.max(1, FT.db.width - FT.db.height - 74))
        f.name:SetJustifyH("LEFT")
        f.name:SetWordWrap(false)
        f.time = S.Text(f, 12, S.C.text, "OUTLINE")
        f.time:SetPoint("RIGHT", -6, 0)
        FT.frame = f
        T.Movers.ApplyPoint(f, FT.db)
        T.Movers:Register(f, {
            label = "Flight timer", page = "flighttimer",
            cfg = function() return FT.db end,
            corner = function() return FT.db.point[1] end,
            enabled = function() return FT.db.enabled end,
        })
        if hooksecurefunc then pcall(hooksecurefunc, "TakeTaxiNode", function(slot) FT:Chosen(slot) end) end
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("TAXIMAP_OPENED")
        ev:SetScript("OnEvent", T:Wrap("flighttimer.map", function() FT:ReadMap() end))
        local acc = 0
        -- Keep watching while the display is hidden: hidden frames do not receive OnUpdate.
        ev:SetScript("OnUpdate", T:Wrap("flighttimer.tick", function(_, elapsed)
            acc = acc + elapsed
            if acc < 0.2 then return end
            acc = 0
            local fill, text, flight, counting = FT:Step(GetTime(), UnitOnTaxi and UnitOnTaxi("player"))
            local show = FT.db.enabled and fill ~= nil
            f.learning:SetShown(show and not counting)
            if show then
                f.name:SetText(flight.to or "")
                f.time:SetText(text)
                f.fill:SetWidth(math.max(1, (FT.db.width - 2) * fill))
            end
            f:SetShown(show or not T.db.locked)
        end))
        f:SetShown(not T.db.locked)
    end,
    OnSettings = function()
        FT.db = T.db.flighttimer
        if FT.frame then
            FT.frame:SetSize(FT.db.width, FT.db.height)
            FT.frame.hourglass:SetSize(FT.db.height, FT.db.height)
            FT.frame.name:SetPoint("LEFT", FT.db.height + 4, 0)
            FT.frame.name:SetWidth(math.max(1, FT.db.width - FT.db.height - 74))
            T.Movers.ApplyPoint(FT.frame, FT.db)
        end
    end,
})
