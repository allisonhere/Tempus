-- Tempus UI: Layered DPS track. One bar split into contiguous segments: purple to your live
-- DPS, gold on to your peak this fight, red on to the group's top DPS, then the empty track.
-- The three segments are status bars stacked on one track, all filling from 0: the top bar
-- is drawn first and the live bar last, so each shows only past the end of the one above it.
-- Every edge is a bar's own fill edge, which is also what the markers anchor to.
local _, T = ...
local S = T.Style
local DT = T.DPSTrack
local State, Scale, Source = DT.State, DT.Scale, DT.Source

DT.defaults = {
    enabled = true,
    width = 320, height = 12, scale = 1,
    liveColor = { 0.62, 0.32, 1 },
    peakColor = { 1, 0.78, 0.18 },
    topColor = { 0.92, 0.3, 0.3 },
    trackColor = { 0.13, 0.135, 0.15 },
    liveAlpha = 1, peakAlpha = 0.75, topAlpha = 0.6,
    labels = true, markers = true,
    scaleMode = "DYNAMIC",      -- DYNAMIC | TOP | FIXED
    fixedMax = 1000000,
    smoothing = 8,
    resetOn = "COMBAT",         -- COMBAT | ENCOUNTER
    hideOOC = true,
    test = false,
    point = { "CENTER", "UIParent", "CENTER", 0, -170 },
}

local POLL = 0.25           -- seconds between damage meter reads
local LAYERS = { "top", "peak", "live" }    -- drawn bottom to top
local NAMES = { live = "Live", peak = "Peak", top = "Top" }

DT.state = State.New()
DT.disp = { live = 0, peak = 0, top = 0, max = 1 }
DT.acc = 0

local function Tint(c, a) return c[1], c[2], c[3], a end
local function Lighter(c) return c[1] + (1 - c[1]) * 0.35, c[2] + (1 - c[2]) * 0.35, c[3] + (1 - c[3]) * 0.35 end

local function Build()
    local f = CreateFrame("Frame", "TempusDPSTrack", UIParent)
    f:SetFrameStrata("MEDIUM")
    S.Backdrop(f)
    f.bars, f.ticks, f.labels = {}, {}, {}
    for i, key in ipairs(LAYERS) do
        local b = S.StatusBar(f)
        b:SetPoint("TOPLEFT", 1, -1)
        b:SetPoint("BOTTOMRIGHT", -1, 1)
        b:SetFrameLevel(f:GetFrameLevel() + i)
        b:SetMinMaxValues(0, 1)
        b:SetValue(0)
        if key ~= "top" then b.bg:Hide() end   -- the bottom bar's background is the empty track
        f.bars[key] = b
    end
    local over = CreateFrame("Frame", nil, f)
    over:SetAllPoints(f)
    over:SetFrameLevel(f:GetFrameLevel() + #LAYERS + 2)
    -- A faint glow at the live edge; the live segment is the one to watch.
    f.spark = over:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    f.spark:SetBlendMode("ADD")
    f.spark:SetAlpha(0.55)
    f.spark:SetPoint("CENTER", f.bars.live:GetStatusBarTexture(), "RIGHT")
    for _, key in ipairs(LAYERS) do
        local fill = f.bars[key]:GetStatusBarTexture()
        local tick = over:CreateTexture(nil, "OVERLAY", nil, 2)
        tick:SetTexture(S.WHITE)
        tick:SetPoint("TOP", fill, "TOPRIGHT", 0, 3)
        tick:SetPoint("BOTTOM", fill, "BOTTOMRIGHT", 0, -3)
        f.ticks[key] = tick
        local label = over:CreateFontString(nil, "OVERLAY")
        S.ApplyFont(label, 10)      -- a FontString needs a font before SetText
        f.labels[key] = label
    end
    f.labels.live:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -4)
    f.labels.peak:SetPoint("LEFT", f.labels.live, "RIGHT", 12, 0)
    f.labels.top:SetPoint("LEFT", f.labels.peak, "RIGHT", 12, 0)
    return f
end

function DT:SetLabels(live, peak, top)
    local f, db = self.frame, self.db
    if not db.labels then return end
    for key, v in pairs({ live = live, peak = peak, top = top }) do
        f.labels[key]:SetFormattedText("%s  %s", NAMES[key], DT.Format(v))
    end
end

-- Readable values: smoothed by OnUpdate, drawn on a shared scale.
function DT:Draw(live, peak, top, max)
    local f, db = self.frame, self.db
    local values = { live = live, peak = peak, top = top }
    for _, key in ipairs(LAYERS) do
        local b = f.bars[key]
        b:SetMinMaxValues(0, max)
        b:SetValue(math.min(values[key], max))
        f.ticks[key]:SetShown(db.markers and values[key] > 0)
    end
    f.spark:SetShown(live > 0)
end

-- Secret values (in combat on some content) can be drawn but not compared or scaled, so the
-- peak is unknown: the live and top bars take the raw values on the last readable scale.
function DT:DrawSecret(live, top)
    local f, db = self.frame, self.db
    local bars = f.bars
    if self.disp.max <= 1 and top ~= nil then
        for _, key in ipairs(LAYERS) do pcall(bars[key].SetMinMaxValues, bars[key], 0, top) end
    end
    pcall(bars.live.SetValue, bars.live, live)
    pcall(bars.top.SetValue, bars.top, top or 0)
    bars.peak:SetValue(0)
    f.ticks.peak:Hide()
    f.ticks.live:SetShown(db.markers)
    f.ticks.top:SetShown(db.markers and top ~= nil)
    f.spark:Show()
    if db.labels then
        local abbr = AbbreviateNumbers or tostring
        if not pcall(function() f.labels.live:SetFormattedText("Live  %s", abbr(live)) end) then
            f.labels.live:SetText("Live")
        end
        f.labels.peak:SetText("Peak  -")
        if top == nil or not pcall(function() f.labels.top:SetFormattedText("Top  %s", abbr(top)) end) then
            f.labels.top:SetText("Top")
        end
    end
end

function DT:Poll()
    local db = self.db
    local live, top, secret
    if db.test then
        live, top, secret = Source.Test(GetTime() - (self.testStart or 0))
    else
        live, top, secret = Source.Read()
    end
    if live == nil then return end
    self.secret = secret
    if secret then
        self:DrawSecret(live, top)
        return
    end
    local s = State.Update(self.state, live, top)
    self.scaleTarget = Scale.Target(self.scaleTarget, db.scaleMode, s.top, db.fixedMax)
    self:SetLabels(s.live, s.peak, s.groupTop)
end

function DT:OnUpdate(elapsed)
    self.acc = self.acc + elapsed
    if self.acc >= POLL then
        self.acc = 0
        self:Poll()
    end
    if self.secret then return end
    local d, s, speed = self.disp, self.state, self.db.smoothing
    d.max = Scale.Approach(d.max, self.scaleTarget or 1, speed, elapsed)
    d.live = Scale.Approach(d.live, s.live, speed, elapsed)
    d.peak = math.max(Scale.Approach(d.peak, s.peak, speed, elapsed), d.live)
    d.top = math.max(Scale.Approach(d.top, s.top, speed, elapsed), d.peak)
    self:Draw(d.live, d.peak, d.top, math.max(d.max, 1))
end

-- A new fight: the peak starts over, the scale is recomputed and the bars start from empty
-- (the track was usually hidden since the last fight, so easing down from it would mislead).
function DT:Reset()
    State.Reset(self.state)
    local d = self.disp
    d.live, d.peak, d.top = 0, 0, 0
    self.scaleTarget = nil
    self.secret = false
    if self.frame and self.db.labels then self:SetLabels(0, 0, 0) end
end

function DT:UpdateShown()
    local f, db = self.frame, self.db
    if not (f and db) then return end
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
    local show = db.enabled and (db.test or not db.hideOOC or inCombat or not T.db.locked)
    f:SetShown(show and true or false)
end

function DT:Refresh()
    local f, db = self.frame, self.db
    if not (f and db) then return end
    f:SetScale(db.scale)
    f:SetSize(db.width, db.height)
    local colors = { live = db.liveColor, peak = db.peakColor, top = db.topColor }
    local alphas = { live = db.liveAlpha, peak = db.peakAlpha, top = db.topAlpha }
    for _, key in ipairs(LAYERS) do
        f.bars[key]:SetStatusBarColor(Tint(colors[key], alphas[key]))
        f.ticks[key]:SetVertexColor(Lighter(colors[key]))
        f.ticks[key]:SetWidth(S.Pixel() * 2)
        f.labels[key]:SetTextColor(Lighter(colors[key]))
        S.ApplyFont(f.labels[key], 10)
        f.labels[key]:SetShown(db.labels)
    end
    f.bars.top.bg:SetVertexColor(Tint(db.trackColor, 0.9))
    f.spark:SetSize(10, db.height * 2)
    if db.test ~= self.testing then
        self.testing = db.test
        self.testStart = GetTime()
        self:Reset()
    end
    if not self.secret then self:SetLabels(self.state.live, self.state.peak, self.state.groupTop) end
    self:UpdateShown()
end

T:NewModule("dpstrack", {
    label = "Layered DPS track",
    desc = "One bar with your live DPS, your peak this fight and the group's top DPS, from Blizzard's damage meter.",
    defaults = DT.defaults,
    OnEnable = function()
        DT.db = T.db.dpstrack
        DT.db.test = false      -- test mode never survives a reload
        local f = Build()
        DT.frame = f
        T.Movers.ApplyPoint(f, DT.db)
        T.Movers:Register(f, {
            label = "Layered DPS track", page = "dpstrack",
            cfg = function() return DT.db end,
            corner = function() return DT.db.point[1] end,
            enabled = function() return DT.db.enabled end,
        })
        f:SetScript("OnUpdate", T:Wrap("dpstrack.update", function(_, elapsed) DT:OnUpdate(elapsed) end))
        local ev = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ENCOUNTER_START",
            "PLAYER_ENTERING_WORLD" }) do
            pcall(ev.RegisterEvent, ev, event)
        end
        ev:SetScript("OnEvent", T:Wrap("dpstrack.events", function(_, event)
            if event == "ENCOUNTER_START" or (event == "PLAYER_REGEN_DISABLED" and DT.db.resetOn == "COMBAT") then
                if not DT.db.test then DT:Reset() end
            end
            DT:UpdateShown()
        end))
        DT:Refresh()
    end,
    OnSettings = function()
        DT.db = T.db.dpstrack
        if DT.frame then
            T.Movers.ApplyPoint(DT.frame, DT.db)
            DT:Refresh()
        end
    end,
})
