-- Tempus UI: Combat Pulse. One compact strip that gathers what matters in a fight: the layered
-- DPS bar (live, your peak, group top), a thin swing line, and small chips for an interruptible
-- target cast, a buff you can purge, threat trouble and the execute range. Signals come from
-- the shared damage meter helpers (Modules/DPSTrack), the swing timer and the nameplate
-- helpers; nothing is recomputed here. Everything is event driven, apart from a 4 Hz meter
-- read while fighting and a frame update on the swing line only while a swing is running.
-- Values the client hides in combat are only ever drawn (bar fills, texture alpha), never
-- compared.
local _, T = ...
local S = T.Style
local DT = T.DPSTrack
local NP = T.Nameplates
local CP = T.CombatPulse
local Fight, Rules = DT.State, CP.State     -- the meter's fight state; this module's signal rules
local Scale, Source = DT.Scale, DT.Source
local Bool, Plain = NP.Bool, NP.Plain

CP.defaults = {
    enabled = true,
    mode = "STANDARD",          -- MINIMAL | STANDARD | FULL
    width = 260, height = 12, scale = 1, opacity = 1,
    hideOOC = true,
    showDPS = true, showSwing = true, showKick = true, showPurge = true, showThreat = true, showExecute = true,
    liveColor = { 0.62, 0.32, 1 },
    peakColor = { 1, 0.78, 0.18 },
    topColor = { 0.92, 0.3, 0.3 },
    purgeColor = { 0.75, 0.3, 1 },
    peak = 0, rangeMax = nil,   -- saved so the bar keeps its scale across fights and reloads
    point = { "CENTER", "UIParent", "CENTER", 0, -250 },
}

local POLL = 0.25               -- seconds between damage meter reads
local LAYERS = { "top", "peak", "live" }
local SMOOTH = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local SKULL = { 0.75, 1, 0.25, 0.5 }    -- skull in the raid target icon sheet

local THREAT_TEXT = {
    tank = { safe = "HOLD", warn = "SLIPPING", lost = "LOST" },
    dps = { warn = "PULLING", aggro = "AGGRO" },
}

CP.state = Fight.New()
CP.ctx = {}

local function Lighter(c) return c[1] + (1 - c[1]) * 0.35, c[2] + (1 - c[2]) * 0.35, c[3] + (1 - c[3]) * 0.35 end

local function SetBar(bar, v)
    if SMOOTH and pcall(bar.SetValue, bar, v, SMOOTH) then return end
    bar:SetValue(v)
end

----------------------------------------------------------------------------------------
-- Build
----------------------------------------------------------------------------------------
local function NewChip(parent, text)
    local c = CreateFrame("Frame", nil, parent)
    S.Backdrop(c, { inner = false })
    c.text = c:CreateFontString(nil, "OVERLAY")
    S.ApplyFont(c.text, 10)
    c.text:SetPoint("CENTER", 0, 0)
    c.text:SetText(text or "")
    c:Hide()
    return c
end

local function Build()
    local f = CreateFrame("Frame", "TempusCombatPulse", UIParent)
    f:SetFrameStrata("MEDIUM")
    f.strip = CreateFrame("Frame", nil, f)
    f.strip:SetAllPoints(f)
    S.Backdrop(f.strip)
    f.bars = {}
    for i, key in ipairs(LAYERS) do
        local b = S.StatusBar(f.strip)
        b:SetPoint("TOPLEFT", 1, -1)
        b:SetPoint("BOTTOMRIGHT", -1, 1)
        b:SetFrameLevel(f.strip:GetFrameLevel() + i)
        b:SetMinMaxValues(0, 1)
        b:SetValue(0)
        if key ~= "top" then b.bg:Hide() end
        f.bars[key] = b
    end
    local over = CreateFrame("Frame", nil, f.strip)
    over:SetAllPoints(f.strip)
    over:SetFrameLevel(f.strip:GetFrameLevel() + #LAYERS + 2)
    f.ticks = {}
    for _, key in ipairs(LAYERS) do
        local tick = over:CreateTexture(nil, "OVERLAY", nil, 2)
        tick:SetTexture(S.WHITE)
        local fill = f.bars[key]:GetStatusBarTexture()
        tick:SetPoint("TOP", fill, "TOPRIGHT", 0, 2)
        tick:SetPoint("BOTTOM", fill, "BOTTOMRIGHT", 0, -2)
        f.ticks[key] = tick
    end
    f.live = over:CreateFontString(nil, "OVERLAY")
    S.ApplyFont(f.live, 10)
    f.live:SetPoint("LEFT", f.strip, "LEFT", 4, 0)
    f.extra = over:CreateFontString(nil, "OVERLAY")     -- "Peak 1.1M  Top 1.4M", Full only
    S.ApplyFont(f.extra, 10)
    f.extra:SetPoint("RIGHT", f.strip, "RIGHT", -4, 0)
    f.extra:SetTextColor(0.78, 0.82, 0.9)

    -- Swing line along the bottom edge, drawn over the DPS fills.
    f.swing = S.StatusBar(f.strip)
    f.swing:SetPoint("BOTTOMLEFT", 1, 1)
    f.swing:SetPoint("BOTTOMRIGHT", -1, 1)
    f.swing:SetFrameLevel(over:GetFrameLevel() + 1)
    f.swing:SetMinMaxValues(0, 1)
    f.swing:SetValue(0)
    f.swing.bg:SetVertexColor(0, 0, 0, 0.45)

    -- Chips sit on the strip's top edge, left to right: threat, purge, kick, execute.
    f.chips = CreateFrame("Frame", nil, f)
    f.chips:SetAllPoints(f)
    f.chips:SetFrameLevel(over:GetFrameLevel() + 3)
    f.threat = NewChip(f.chips)
    f.purge = NewChip(f.chips, "PURGE")
    f.kick = CreateFrame("Frame", nil, f.chips)
    S.Backdrop(f.kick, { inner = false, shadow = false })
    f.kick.icon = f.kick:CreateTexture(nil, "ARTWORK")
    f.kick.icon:SetAllPoints()
    f.kick.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.kick.cd = CreateFrame("Cooldown", nil, f.kick, "CooldownFrameTemplate")
    f.kick.cd:SetAllPoints()
    f.kick.cd:SetDrawEdge(false)
    if f.kick.cd.SetHideCountdownNumbers then f.kick.cd:SetHideCountdownNumbers(true) end
    f.kick:Hide()
    -- The execute skull is a bare texture so its colour curve can drive the alpha directly.
    f.exec = f.chips:CreateTexture(nil, "OVERLAY")
    f.exec:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.exec:SetTexCoord(unpack(SKULL))
    f.exec:Hide()
    return f
end

----------------------------------------------------------------------------------------
-- Readings
----------------------------------------------------------------------------------------
local function TargetCast()
    -- Returns castActive, notInterruptible (true | false | secret value | nil when unknown).
    -- UnitCastingInfo has a castID before the flag, channels do not (same indexes as the plates).
    for _, q in ipairs({ { UnitCastingInfo, 9 }, { UnitChannelInfo, 8 } }) do
        if q[1] then
            local info = { pcall(q[1], "target") }
            local name = info[2]
            if info[1] and (T.issecret(name) or name ~= nil) then return true, info[q[2]] end
        end
    end
    return false
end

local function ThreatLevel()
    if not Bool(UnitAffectingCombat, "target") or Bool(UnitIsPlayer, "target") then return nil end
    local status = Plain(UnitThreatSituation, "player", "target")
    return NP.ThreatLevel(status, NP.IsTankRole()), NP.IsTankRole()
end

-- Everything the strip depends on, in the shape State.Plan wants.
function CP:Gather()
    local ctx = self.ctx
    if self.db.test then
        ctx.dpsReady, ctx.swingReady, ctx.swinging = true, true, true
        ctx.kickKnown, ctx.cast, ctx.hostile, ctx.purge = true, true, true, true
        ctx.executeOn, ctx.threat, ctx.tank, ctx.notInterruptible = true, "warn", false, false
        return ctx
    end
    ctx.dpsReady = Source.Available()
    ctx.swingReady = T.Swing and T.Swing.db and T.Swing.db.enabled and true or false
    ctx.swinging = T.Swing and T.Swing.Status() ~= nil or false
    ctx.kickKnown = NP.FindKick() ~= nil
    ctx.hostile = Bool(UnitExists, "target") and Bool(UnitCanAttack, "player", "target") and not Bool(UnitIsDead, "target")
    ctx.executeOn = (T.db.nameplates.execute or 0) > 0
    ctx.cast, ctx.notInterruptible, ctx.purge, ctx.threat, ctx.tank = false, nil, false, nil, false
    if ctx.hostile then
        ctx.cast, ctx.notInterruptible = TargetCast()
        if ctx.cast and not T.issecret(ctx.notInterruptible) and ctx.notInterruptible then ctx.cast = false end
        ctx.purge = NP.HasPurgeable("target")
        ctx.threat, ctx.tank = ThreatLevel()
    end
    return ctx
end

----------------------------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------------------------
-- The track's range: learned from readable readings and saved. nil while nothing is known; the
-- caller then scales against the group top instead.
function CP:DynamicMax(top)
    local db = self.db
    if not self.rangeMax and not db.test then
        self.rangeMax = Scale.Restore(db.rangeMax, self.lastTop, self.state.peak)
    end
    if top and top > 0 then self.rangeMax = Scale.Target(self.rangeMax, "DYNAMIC", top) end
    if not db.test then db.rangeMax = self.rangeMax end
    return self.rangeMax
end

function CP:SetLiveText(live)
    local abbr = AbbreviateLargeNumbers or AbbreviateNumbers or tostring
    local fs = self.frame.live
    if T.issecret(live) then
        if not pcall(function() fs:SetFormattedText("%s", abbr(live)) end) then fs:SetText("") end
    else
        fs:SetText(DT.Format(live))
    end
end

function CP:DrawDPS(live, top, secret)
    local f, s = self.frame, self.state
    local max
    if secret then
        -- With no known range, the group top (also hidden) fills the bar and live is drawn against it.
        max = self:DynamicMax() or top or 1
    else
        s = Fight.Update(s, live, top)
        -- A saved range hundreds of times the real DPS (left by old test samples) is wrong: relearn.
        if self.rangeMax and s.top > 0 and self.rangeMax > s.top * Scale.STALE then
            self.rangeMax = Scale.Target(nil, "DYNAMIC", s.top)
        end
        max = self:DynamicMax(s.top) or 1
        top, live = s.top, s.live
        if not self.db.test then
            self.db.peak = s.peak
            self.lastTop = s.groupTop > 0 and s.groupTop or self.lastTop
        end
    end
    if not T.issecret(max) then max = math.max(max, 1) end
    for _, key in ipairs(LAYERS) do f.bars[key]:SetMinMaxValues(0, max) end
    SetBar(f.bars.live, live)
    SetBar(f.bars.top, top or 0)
    SetBar(f.bars.peak, s.peak)
    f.ticks.peak:SetShown(s.peak > 0)
    f.ticks.top:SetShown(top ~= nil)
    self:SetLiveText(live)
    if self.plan and self.plan.peakLabels then
        f.extra:SetFormattedText("Peak %s  Top %s", DT.Format(s.peak),
            (secret or top == nil) and "-" or DT.Format(s.groupTop))
    end
end

function CP:Poll()
    local db = self.db
    local live, top, secret
    if db.test then
        live, top, secret = Source.Test(GetTime() - (self.testStart or 0))
    else
        live, top, secret = Source.Read()
    end
    if live == nil then return end
    self.secret = secret
    self:DrawDPS(live, top, secret)
end

-- Swing line: runs a frame update only while a swing is in progress.
local function SwingOnUpdate(bar)
    local status = bar.status
    local left = status.endT - GetTime()
    if left <= 0 and status.loop then status.endT, left = GetTime() + status.duration, status.duration end
    if left <= 0 then
        bar:SetScript("OnUpdate", nil)
        bar:SetValue(0)
        return
    end
    bar:SetValue(status.duration - left)
end

function CP:DrawSwing()
    local f, db = self.frame, self.db
    local bar = f.swing
    local status
    if db.test then
        local t = (GetTime() - (self.testStart or 0)) % 2.4
        status = { endT = GetTime() + 2.4 - t, duration = 2.4, outOfRange = false, loop = true }
    else
        status = T.Swing and T.Swing.Status()
    end
    local show = self.plan and self.plan.swing
    bar:SetShown(show and true or false)
    if not (show and status) then
        bar:SetScript("OnUpdate", nil)
        bar:SetValue(0)
        return
    end
    local c = status.outOfRange and { 0.85, 0.2, 0.2 } or T.accent
    bar:SetStatusBarColor(c[1], c[2], c[3], status.outOfRange and 0.6 or 1)
    bar:SetMinMaxValues(0, status.duration)
    bar.status = status
    bar:SetScript("OnUpdate", T:Wrap("combatpulse.swing", SwingOnUpdate))
    SwingOnUpdate(bar)
end

function CP:DrawKick()
    local f, ctx, k = self.frame, self.ctx, self.frame.kick
    local id = NP.FindKick()
    if not (self.plan.kick and id) then k:Hide() return end
    local tex = "Interface\\Icons\\Ability_Kick"
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, id)
        if ok and t then tex = t end
    end
    k.icon:SetTexture(tex)
    if C_Spell and C_Spell.GetSpellCooldownDuration and k.cd.SetCooldownFromDurationObject then
        local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, id)
        if ok and dur then pcall(k.cd.SetCooldownFromDurationObject, k.cd, dur) else k.cd:Clear() end
    end
    local ready
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, id)
        if ok and type(info) == "table" then ready = Rules.KickReady(info.startTime, info.duration, GetTime()) end
    end
    k.icon:SetDesaturated(ready == false)
    -- Without a cast (Full mode) the icon rests dim; an interruptible cast lights it up. The
    -- flag may be secret, so it drives the alpha through the client.
    local rest = self.db.mode == "FULL" and 0.35 or 0
    if not ctx.cast then
        k:SetAlpha(rest)
    elseif T.issecret(ctx.notInterruptible) then
        if k.SetAlphaFromBoolean then pcall(k.SetAlphaFromBoolean, k, ctx.notInterruptible, rest, 1) else k:SetAlpha(1) end
    else
        k:SetAlpha(1)   -- a plainly uninterruptible cast was already dropped in Gather
    end
    k:Show()
end

function CP:DrawThreat()
    local chip, ctx = self.frame.threat, self.ctx
    if not self.plan.threat then chip:Hide() return end
    local level = ctx.threat
    local text = THREAT_TEXT[ctx.tank and "tank" or "dps"][level]
    local c = T.db.nameplates.colors
    local col = (level == "safe" and c.threatSafe) or (level == "warn" and c.threatWarn) or c.threatAggro
    if not text then
        chip:SetAlpha(0.35)
        text, col = ctx.tank and "HOLD" or "SAFE", c.threatSafe
    else
        chip:SetAlpha(1)
    end
    chip.text:SetText(text)
    chip.text:SetTextColor(col[1], col[2], col[3])
    chip.tempusBackdrop:SetEdgeColor(col[1], col[2], col[3])
    chip:Show()
end

function CP:DrawPurge()
    local chip, c = self.frame.purge, self.db.purgeColor
    if not self.plan.purge then chip:Hide() return end
    chip.text:SetTextColor(Lighter(c))
    chip.tempusBackdrop:SetEdgeColor(c[1], c[2], c[3])
    chip:SetAlpha(self.ctx.purge and 1 or 0.3)
    chip:Show()
end

-- Execute: the nameplate colour curve turns the target's health into an alpha with no
-- comparison. Without the curve API, plain health values are used when readable.
function CP:DrawExecute()
    local tex, ctx = self.frame.exec, self.ctx
    if not self.plan.execute then tex:Hide() return end
    local c = T.db.nameplates.colors.execute
    tex:SetVertexColor(c[1], c[2], c[3], 0)
    tex:Show()
    if self.db.test then tex:SetVertexColor(c[1], c[2], c[3], 1) return end
    local key = ("%s:%s:%s:%s"):format(T.db.nameplates.execute, c[1], c[2], c[3])
    if self.curveKey ~= key then
        self.curveKey, self.curve = key, NP.MakeExecuteCurve(T.db.nameplates.execute, c)
    end
    local curve = self.curve
    if curve and UnitHealthPercent then
        local ok, color = pcall(UnitHealthPercent, "target", true, curve)
        if ok and color and pcall(function() tex:SetVertexColor(color:GetRGBA()) end) then return end
    end
    local hp, max = Plain(UnitHealth, "target"), Plain(UnitHealthMax, "target")
    if T.Num(hp) and T.Num(max) and max > 0 and hp / max * 100 <= T.db.nameplates.execute then
        tex:SetVertexColor(c[1], c[2], c[3], 1)
    end
end

function CP:Layout()
    local f, h = self.frame, self.db.height
    local size = math.max(14, h + 2)
    local x = 0
    local function Place(widget, w)
        widget:ClearAllPoints()
        widget:SetSize(w, size)
        widget:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x, 4)
        x = x + w + 4
    end
    for _, chip in ipairs({ f.threat, f.purge }) do
        if chip:IsShown() then
            S.ApplyFont(chip.text, math.max(8, math.min(size - 4, 11)))
            Place(chip, math.max(size, chip.text:GetStringWidth() + 10))
        end
    end
    if f.kick:IsShown() then Place(f.kick, size) end
    if f.exec:IsShown() then Place(f.exec, size) end
end

function CP:Apply()
    local f, db = self.frame, self.db
    if not (f and db) then return end
    local unlocked = not T.db.locked
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
    local visible = Rules.Visible(db, inCombat, unlocked)
    f:SetShown(visible)
    if not visible then self:StopPoll() return end
    local ctx = self:Gather()
    self.plan = Rules.Plan(db, ctx)
    local plan = self.plan
    -- While placing it, keep the strip visible even in Minimal so there is something to drag.
    f.strip:SetShown(plan.strip or (unlocked and true) or false)
    f.bars.top:SetShown(plan.dps)
    f.bars.peak:SetShown(plan.dps)
    f.bars.live:SetShown(plan.dps)
    f.live:SetShown(plan.dps)
    f.extra:SetShown(plan.peakLabels)
    if not plan.dps then for _, t in pairs(f.ticks) do t:Hide() end end
    self:DrawSwing()
    self:DrawThreat()
    self:DrawPurge()
    self:DrawKick()
    self:DrawExecute()
    self:Layout()
    if plan.dps and (inCombat or db.test) then self:StartPoll() else self:StopPoll() end
end

----------------------------------------------------------------------------------------
-- Meter polling: only while fighting (or testing), only when the DPS bar is on screen.
----------------------------------------------------------------------------------------
function CP:StartPoll()
    if self.ticker then return end
    local interval = self.db.test and 0.1 or POLL
    self.ticker = C_Timer.NewTicker(interval, T:Wrap("combatpulse.poll", function() CP:Poll() end))
    self:Poll()
end

function CP:StopPoll()
    if self.ticker then self.ticker:Cancel() self.ticker = nil end
end

function CP:Refresh()
    local f, db = self.frame, self.db
    if not (f and db) then return end
    f:SetScale(db.scale)
    f:SetSize(db.width, db.height)
    f:SetAlpha(db.opacity)
    local colors = { live = db.liveColor, peak = db.peakColor, top = db.topColor }
    local alphas = { live = 1, peak = 0.75, top = 0.6 }
    for _, key in ipairs(LAYERS) do
        local c = colors[key]
        f.bars[key]:SetStatusBarColor(c[1], c[2], c[3], alphas[key])
        f.ticks[key]:SetVertexColor(Lighter(c))
        f.ticks[key]:SetWidth(S.Pixel() * 2)
    end
    f.live:SetTextColor(Lighter(db.liveColor))
    S.ApplyFont(f.live, math.max(8, math.min(db.height - 2, 11)))
    S.ApplyFont(f.extra, math.max(8, math.min(db.height - 2, 11)))
    f.swing:SetHeight(math.max(2, math.floor(db.height * 0.25)))
    if db.test ~= self.testing then
        local leavingTest = self.testing == true and not db.test
        self.testing = db.test
        self.testStart = GetTime()
        self.state = Fight.New(not db.test and db.peak or 0)
        self.rangeMax, self.lastTop = nil, nil
        -- Test samples are never written to db.rangeMax, so preserve the last real learned
        -- range across reloads and when leaving test mode.
        if leavingTest then self.rangeMax = nil end
        self:StopPoll()
    end
    self:Apply()
end

function CP:ClearBars()
    local f = self.frame
    SetBar(f.bars.live, 0)
    SetBar(f.bars.top, 0)
    f.live:SetText("")
end

function CP:OnEvent(event)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if self.plan and self.plan.execute then self:DrawExecute() end
        return
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if self.plan and self.plan.kick then self:DrawKick() end
        return
    elseif event == "DAMAGE_METER_RESET" then
        self.db.peak, self.db.rangeMax, self.lastTop, self.rangeMax = 0, nil, nil, nil
        Fight.Reset(self.state)
        self:ClearBars()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "ENCOUNTER_START" then
        Fight.BeginFight(self.state)
        self.secret = false
        self:ClearBars()
    elseif event == "PLAYER_REGEN_ENABLED" and not self.db.test then
        -- Values unlock once combat ends; read the finished fight once more.
        C_Timer.After(0.5, function()
            if not UnitAffectingCombat("player") and self.plan and self.plan.dps then
                self:Poll()
            end
        end)
    elseif event == "SPELLS_CHANGED" then
        NP.ResetKick()
    end
    self:Apply()
end

local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD",
    "ENCOUNTER_START", "DAMAGE_METER_RESET", "SPELLS_CHANGED", "PLAYER_ROLES_ASSIGNED", "SPELL_UPDATE_COOLDOWN" }
local TARGET_EVENTS = { "UNIT_AURA", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_THREAT_LIST_UPDATE",
    "UNIT_THREAT_SITUATION_UPDATE", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }

T:NewModule("combatpulse", {
    label = "Combat Pulse",
    desc = "One compact combat strip: DPS, swing timing, interrupt, purge, threat and execute cues.",
    defaults = CP.defaults,
    OnEnable = function()
        CP.db = T.db.combatpulse
        CP.db.test = false      -- test mode never survives a reload
        CP.state = Fight.New(CP.db.peak)
        local f = Build()
        CP.frame = f
        T.Movers.ApplyPoint(f, CP.db)
        T.Movers:Register(f, {
            label = "Combat Pulse", page = "combatpulse",
            cfg = function() return CP.db end,
            corner = function() return CP.db.point[1] end,
            enabled = function() return CP.db.enabled end,
            onMoved = function() CP:Layout() end,
        })
        local ev = CreateFrame("Frame")
        for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
        for _, e in ipairs(TARGET_EVENTS) do pcall(ev.RegisterUnitEvent, ev, e, "target") end
        ev:SetScript("OnEvent", T:Wrap("combatpulse.events", function(_, event) CP:OnEvent(event) end))
        if T.Swing then T.Swing.listener = function() if CP.frame then CP:Apply() end end end
        CP:Refresh()
    end,
    OnSettings = function()
        CP.db = T.db.combatpulse
        if CP.frame then
            T.Movers.ApplyPoint(CP.frame, CP.db)
            CP:Refresh()
        end
    end,
})
