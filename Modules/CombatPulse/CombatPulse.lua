-- Tempus UI: Combat Pulse. One compact, secret-safe combat strip that combines damage
-- pace, swing timing, interrupt priority/readiness, purge, threat and execute cues. It also
-- keeps a deliberately tiny readable post-fight history; it is not a combat meter.
local _, T = ...
local S = T.Style
local DT = T.DPSTrack
local NP = T.Nameplates
local CP = T.CombatPulse
local Fight, Rules = DT.State, CP.State
local Scale, Source = DT.Scale, DT.Source
local Bool, Plain = NP.Bool, NP.Plain

CP.defaults = {
    enabled = true,
    mode = "STANDARD",          -- MINIMAL | STANDARD | FULL
    width = 260, height = 12, scale = 1, opacity = 1,
    hideOOC = true,
    showDPS = true, showSwing = true, showCastPriority = true, showKick = true, showPurge = true, showThreat = true, showExecute = true,
    showPrevious = true, showSummary = true, summarySeconds = 5, historySize = 5,
    roleAware = true, historyOnClick = true,
    liveColor = { 0.62, 0.32, 1 },
    peakColor = { 1, 0.78, 0.18 },
    topColor = { 0.92, 0.3, 0.3 },
    purgeColor = { 0.75, 0.3, 1 },
    peak = 0, rangeMax = nil,
    point = { "CENTER", "UIParent", "CENTER", 0, -250 },
}

local POLL = 0.25
local LAYERS = { "top", "peak", "live" }
local SMOOTH = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local PRIORITY_COLOR = {
    NORMAL = { 0.65, 0.72, 0.82 },
    IMPORTANT = { 1, 0.78, 0.18 },
    DANGEROUS = { 1, 0.42, 0.12 },
    MUST = { 1, 0.15, 0.45 },
}
local THREAT_TEXT = {
    tank = { safe = "HOLD", warn = "SLIPPING", lost = "LOST" },
    dps = { warn = "PULLING", aggro = "AGGRO" },
}

CP.state = Fight.New()
CP.ctx = {}

local function Lighter(c)
    return c[1] + (1 - c[1]) * 0.35, c[2] + (1 - c[2]) * 0.35, c[3] + (1 - c[3]) * 0.35
end

local function SetBar(bar, v)
    if SMOOTH and pcall(bar.SetValue, bar, v, SMOOTH) then return end
    bar:SetValue(v)
end

local function ApplyCueColor(cue, color, alpha)
    if cue.tempusBackdrop then cue.tempusBackdrop:SetEdgeColor(color[1], color[2], color[3]) end
    if cue.text then cue.text:SetTextColor(Lighter(color)) end
    if cue.notch then cue.notch:SetVertexColor(color[1], color[2], color[3], alpha or 1) end
end

local function NewCue(parent, text)
    local c = CreateFrame("Frame", nil, parent)
    S.Backdrop(c, { inner = false, shadow = false })
    c.text = c:CreateFontString(nil, "OVERLAY")
    S.ApplyFont(c.text, 10)
    c.text:SetPoint("CENTER", 0, 0)
    c.text:SetText(text or "")
    c.notch = c:CreateTexture(nil, "OVERLAY")
    c.notch:SetTexture(S.WHITE)
    c.notch:SetSize(5, 5)
    c.notch:SetPoint("BOTTOM", c, "BOTTOM", 0, -2)
    if c.notch.SetRotation then c.notch:SetRotation(math.rad(45)) end
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

    -- Invisible status bar used only to position the previous-fight marker. Letting the game
    -- position its fill also works when the active scale is a secret value.
    f.previous = S.StatusBar(f.strip)
    f.previous:SetPoint("TOPLEFT", 1, -1)
    f.previous:SetPoint("BOTTOMRIGHT", -1, 1)
    f.previous:SetFrameLevel(f.strip:GetFrameLevel() + #LAYERS + 1)
    f.previous:SetStatusBarColor(1, 1, 1, 0)
    f.previous.bg:Hide()
    f.previous:SetMinMaxValues(0, 1)
    f.previous:SetValue(0)

    local over = CreateFrame("Frame", nil, f.strip)
    over:SetAllPoints(f.strip)
    over:SetFrameLevel(f.strip:GetFrameLevel() + #LAYERS + 3)
    f.over = over

    f.ticks = {}
    for _, key in ipairs(LAYERS) do
        local tick = over:CreateTexture(nil, "OVERLAY", nil, 2)
        tick:SetTexture(S.WHITE)
        local fill = f.bars[key]:GetStatusBarTexture()
        tick:SetPoint("TOP", fill, "TOPRIGHT", 0, 2)
        tick:SetPoint("BOTTOM", fill, "BOTTOMRIGHT", 0, -2)
        f.ticks[key] = tick
    end

    f.previousTick = over:CreateTexture(nil, "OVERLAY", nil, 3)
    f.previousTick:SetTexture(S.WHITE)
    f.previousTick:SetVertexColor(0.85, 0.88, 0.95, 0.9)
    local prevFill = f.previous:GetStatusBarTexture()
    f.previousTick:SetPoint("TOP", prevFill, "TOPRIGHT", 0, 3)
    f.previousTick:SetPoint("BOTTOM", prevFill, "BOTTOMRIGHT", 0, -3)
    f.previousTick:Hide()

    f.live = over:CreateFontString(nil, "OVERLAY")
    S.ApplyFont(f.live, 10)
    f.live:SetPoint("LEFT", f.strip, "LEFT", 4, 0)
    f.extra = over:CreateFontString(nil, "OVERLAY")
    S.ApplyFont(f.extra, 10)
    f.extra:SetPoint("RIGHT", f.strip, "RIGHT", -4, 0)
    f.extra:SetTextColor(0.78, 0.82, 0.9)

    -- Swing is a thin line with a bright moving edge, not a second full-size bar.
    f.swing = S.StatusBar(f.strip)
    f.swing:SetPoint("BOTTOMLEFT", 1, 1)
    f.swing:SetPoint("BOTTOMRIGHT", -1, 1)
    f.swing:SetFrameLevel(over:GetFrameLevel() + 1)
    f.swing:SetMinMaxValues(0, 1)
    f.swing:SetValue(0)
    f.swing.bg:SetVertexColor(0, 0, 0, 0.45)
    f.swingTick = over:CreateTexture(nil, "OVERLAY", nil, 4)
    f.swingTick:SetTexture(S.WHITE)
    local swingFill = f.swing:GetStatusBarTexture()
    f.swingTick:SetPoint("TOP", swingFill, "TOPRIGHT", 0, 1)
    f.swingTick:SetPoint("BOTTOM", swingFill, "BOTTOMRIGHT", 0, -1)
    f.swingTick:Hide()

    -- Execute is a Tempus notch on the strip itself, not WoW's raid-target skull.
    f.exec = f:CreateTexture(nil, "OVERLAY", nil, 5)
    f.exec:SetTexture(S.WHITE)
    f.exec:SetSize(8, 8)
    f.exec:SetPoint("RIGHT", f, "RIGHT", -2, 0)
    if f.exec.SetRotation then f.exec:SetRotation(math.rad(45)) end
    f.exec:Hide()

    -- Functional border only: no panel fill over the DPS layers.
    f.castEdge = S.CreateBorder(f.strip, "OVERLAY", 6)
    f.castEdge:SetInside(f.strip)
    f.castEdge:SetShown(false)

    -- All contextual cues share the same chip + notch language.
    f.cues = CreateFrame("Frame", nil, f)
    f.cues:SetAllPoints(f)
    f.cues:SetFrameLevel(over:GetFrameLevel() + 4)
    f.cast = NewCue(f.cues, "CAST")
    f.threat = NewCue(f.cues)
    f.purge = NewCue(f.cues, "PURGE")

    f.kick = NewCue(f.cues, "KICK")
    f.kick.icon = f.kick:CreateTexture(nil, "ARTWORK")
    f.kick.icon:SetSize(12, 12)
    f.kick.icon:SetPoint("LEFT", f.kick, "LEFT", 3, 0)
    f.kick.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.kick.text:ClearAllPoints()
    f.kick.text:SetPoint("LEFT", f.kick.icon, "RIGHT", 3, 0)
    f.kick.cd = CreateFrame("Cooldown", nil, f.kick, "CooldownFrameTemplate")
    f.kick.cd:SetAllPoints(f.kick.icon)
    f.kick.cd:SetDrawEdge(false)
    if f.kick.cd.SetHideCountdownNumbers then f.kick.cd:SetHideCountdownNumbers(true) end
    f.kick.flash = f.kick:CreateTexture(nil, "BACKGROUND")
    f.kick.flash:SetTexture(S.WHITE)
    f.kick.flash:SetPoint("TOPLEFT", -2, 2)
    f.kick.flash:SetPoint("BOTTOMRIGHT", 2, -2)
    f.kick.flash:SetAlpha(0)
    if f.kick.flash.CreateAnimationGroup then
        local ag = f.kick.flash:CreateAnimationGroup()
        local a1 = ag:CreateAnimation("Alpha")
        a1:SetFromAlpha(0.65); a1:SetToAlpha(0); a1:SetDuration(0.35); a1:SetOrder(1)
        f.kick.flashAnim = ag
    end

    -- Post-fight summary stays visible even when the main strip hides out of combat.
    f.summary = CreateFrame("Frame", nil, UIParent)
    f.summary:SetFrameStrata("DIALOG")
    f.summary:SetSize(260, 54)
    f.summary:SetPoint("TOP", f, "BOTTOM", 0, -8)
    S.Backdrop(f.summary)
    f.summary.title = f.summary:CreateFontString(nil, "OVERLAY")
    S.ApplyFont(f.summary.title, 10)
    f.summary.title:SetPoint("TOPLEFT", 8, -7)
    f.summary.title:SetText("COMBAT PULSE  •  click for history")
    if f.summary.EnableMouse then f.summary:EnableMouse(true) end
    if f.summary.SetScript then
        f.summary:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and CP.db and CP.db.historyOnClick then CP:ToggleHistory(true) end
        end)
    end
    f.summary.main = f.summary:CreateFontString(nil, "OVERLAY")
    S.ApplyFont(f.summary.main, 12)
    f.summary.main:SetPoint("TOPLEFT", 8, -22)
    f.summary.sub = f.summary:CreateFontString(nil, "OVERLAY")
    S.ApplyFont(f.summary.sub, 10)
    f.summary.sub:SetPoint("TOPLEFT", 8, -38)
    f.summary.sub:SetTextColor(0.75, 0.8, 0.9)
    f.summary:Hide()

    -- Tiny five-fight history; no spells, breakdowns or scrolling combat-meter data.
    f.history = CreateFrame("Frame", nil, UIParent)
    f.history:SetFrameStrata("DIALOG")
    f.history:SetSize(260, 126)
    f.history:SetPoint("TOP", f, "BOTTOM", 0, -8)
    S.Backdrop(f.history)
    f.history.title = f.history:CreateFontString(nil, "OVERLAY")
    S.ApplyFont(f.history.title, 11)
    f.history.title:SetPoint("TOPLEFT", 8, -8)
    f.history.title:SetText("Recent fights")
    f.history.rows = {}
    for i = 1, 5 do
        local row = f.history:CreateFontString(nil, "OVERLAY")
        S.ApplyFont(row, 10)
        row:SetPoint("TOPLEFT", 8, -27 - (i - 1) * 18)
        row:SetPoint("RIGHT", -8, 0)
        row:SetJustifyH("LEFT")
        f.history.rows[i] = row
    end
    f.history:Hide()
    return f
end

local function TargetCast()
    for _, q in ipairs({ { UnitCastingInfo, 9, 10 }, { UnitChannelInfo, 8, 9 } }) do
        if q[1] then
            local info = { pcall(q[1], "target") }
            local name = info[2]
            if info[1] and (T.issecret(name) or name ~= nil) then
                return true, info[q[2]], name, info[q[3]]
            end
        end
    end
    return false
end

local function ThreatLevel()
    if not Bool(UnitAffectingCombat, "target") or Bool(UnitIsPlayer, "target") then return nil end
    local status = Plain(UnitThreatSituation, "player", "target")
    return NP.ThreatLevel(status, NP.IsTankRole()), NP.IsTankRole()
end

function CP:Gather()
    local ctx = self.ctx
    if self.db.test then
        ctx.dpsReady, ctx.swingReady, ctx.swinging = true, true, true
        ctx.kickKnown, ctx.cast, ctx.castActive, ctx.hostile, ctx.purge = true, true, true, true, true
        ctx.executeOn, ctx.threat, ctx.tank, ctx.notInterruptible = true, "warn", false, false
        ctx.role, ctx.castPriority, ctx.castName = "DAMAGER", "MUST", "Test Cast"
        return ctx
    end
    ctx.dpsReady = Source.Available()
    ctx.swingReady = T.Swing and T.Swing.db and T.Swing.db.enabled and true or false
    ctx.swinging = T.Swing and T.Swing.Status() ~= nil or false
    ctx.kickKnown = NP.FindKick() ~= nil
    ctx.hostile = Bool(UnitExists, "target") and Bool(UnitCanAttack, "player", "target") and not Bool(UnitIsDead, "target")
    ctx.executeOn = (T.db.nameplates.execute or 0) > 0
    ctx.role = Plain(UnitGroupRolesAssigned, "player") or "DAMAGER"
    ctx.cast, ctx.castActive, ctx.notInterruptible, ctx.purge, ctx.threat, ctx.tank = false, false, nil, false, nil, false
    ctx.castName, ctx.castPriority = nil, "NORMAL"
    if ctx.hostile then
        local name, spellID
        ctx.castActive, ctx.notInterruptible, name, spellID = TargetCast()
        ctx.cast = ctx.castActive
        if ctx.cast and not T.issecret(ctx.notInterruptible) and ctx.notInterruptible then ctx.cast = false end
        local plainName = name and not T.issecret(name) and name or nil
        local plainID = spellID and not T.issecret(spellID) and spellID or nil
        ctx.castName = plainName
        ctx.castPriority = T.db.nameplates.castAlerts ~= false and NP.CastPriority(plainName, plainID) or "NORMAL"
        ctx.purge = NP.HasPurgeable("target")
        ctx.threat, ctx.tank = ThreatLevel()
    end
    return ctx
end

function CP:History()
    TempusDB.combatPulseHistory = TempusDB.combatPulseHistory or {}
    local key = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
    local history = TempusDB.combatPulseHistory[key]
    if type(history) ~= "table" then
        history = {}
        TempusDB.combatPulseHistory[key] = history
    end
    return history, key
end

function CP:SetHistory(history)
    local _, key = self:History()
    TempusDB.combatPulseHistory[key] = history
end

function CP:ClearHistory()
    self:SetHistory({})
    if self.frame then
        self.frame.history:Hide()
        self.frame.previous:Hide()
        self.frame.previousTick:Hide()
    end
end

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

function CP:DrawPrevious(max)
    local f, db = self.frame, self.db
    local history = self:History()
    local previous = history[1]
    local dps = previous and previous.dps
    local show = self.plan and self.plan.dps and db.showPrevious and T.Num(dps) and dps > 0 and not db.test
    f.previous:SetShown(show and true or false)
    f.previousTick:SetShown(show and true or false)
    if not show then return end
    f.previous:SetMinMaxValues(0, max)
    f.previous:SetValue(dps)
    f.previousTick:SetWidth(S.Pixel() * 2)
end

function CP:DrawDPS(live, top, secret)
    local f, s = self.frame, self.state
    local max
    if secret then
        max = self:DynamicMax() or top or 1
    else
        s = Fight.Update(s, live, top)
        if self.fightActive and T.Num(live) then self.fightPeak = math.max(self.fightPeak or 0, live) end
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
    self:DrawPrevious(max)
    if self.plan and self.plan.peakLabels then
        f.extra:SetFormattedText("Peak %s  Top %s", DT.Format(s.peak),
            (secret or top == nil) and "-" or DT.Format(s.groupTop))
    end
end

function CP:Poll()
    local live, top, secret
    if self.db.test then
        live, top, secret = Source.Test(GetTime() - (self.testStart or 0))
    else
        live, top, secret = Source.Read()
    end
    if live == nil then return end
    self.secret = secret
    self:DrawDPS(live, top, secret)
end

local function SwingOnUpdate(bar)
    local status = bar.status
    local left = status.endT - GetTime()
    if left <= 0 and status.loop then status.endT, left = GetTime() + status.duration, status.duration end
    if left <= 0 then
        bar:SetScript("OnUpdate", nil)
        bar:SetValue(0)
        if bar.tempusTick then bar.tempusTick:Hide() end
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
    f.swingTick:SetShown(show and status and true or false)
    if not (show and status) then
        bar:SetScript("OnUpdate", nil)
        bar:SetValue(0)
        return
    end
    local color = status.outOfRange and { 0.85, 0.2, 0.2 } or T.accent
    bar:SetStatusBarColor(color[1], color[2], color[3], status.outOfRange and 0.6 or 1)
    f.swingTick:SetVertexColor(color[1], color[2], color[3], 1)
    f.swingTick:SetWidth(S.Pixel() * 2)
    bar:SetMinMaxValues(0, status.duration)
    bar.status, bar.tempusTick = status, f.swingTick
    bar:SetScript("OnUpdate", T:Wrap("combatpulse.swing", SwingOnUpdate))
    SwingOnUpdate(bar)
end

function CP:KickReady(id)
    if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
    local ok, info = pcall(C_Spell.GetSpellCooldown, id)
    if not (ok and type(info) == "table") then return nil end
    return Rules.KickReady(info.startTime, info.duration, GetTime())
end

function CP:DrawKick()
    local ctx, k = self.ctx, self.frame.kick
    local id = NP.FindKick()
    if not (self.plan.kick and id) then
        k:Hide()
        self.kickToken = nil
        return
    end

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

    local ready = self:KickReady(id)
    k.icon:SetDesaturated(ready == false)
    local priority = Rules.CastPriority(ctx.castPriority)
    local color = PRIORITY_COLOR[priority] or PRIORITY_COLOR.NORMAL
    k.text:SetText(priority == "MUST" and "KICK!" or "KICK")
    ApplyCueColor(k, color, 1)
    k.flash:SetVertexColor(color[1], color[2], color[3], 1)

    local rest = self.db.mode == "FULL" and 0.3 or 0
    if not ctx.cast then
        k:SetAlpha(rest)
    elseif T.issecret(ctx.notInterruptible) then
        if k.SetAlphaFromBoolean then pcall(k.SetAlphaFromBoolean, k, ctx.notInterruptible, rest, 1) else k:SetAlpha(1) end
    else
        k:SetAlpha(ready == false and 0.55 or 1)
    end
    k:Show()

    -- One arrival pulse only when a cast becomes actionable. No continuous flashing.
    local token = ctx.cast and ready == true and ((ctx.castName or "?") .. ":" .. priority) or nil
    if token and token ~= self.kickToken and k.flashAnim then
        k.flashAnim:Stop()
        k.flashAnim:Play()
    end
    self.kickToken = token
end

function CP:DrawCastPriority()
    local cue, plan = self.frame.cast, self.plan
    local edge = self.frame.castEdge
    if not (plan and plan.castAlert) then
        cue:Hide()
        edge:SetShown(false)
        return
    end
    local priority = plan.priority
    local color = PRIORITY_COLOR[priority] or PRIORITY_COLOR.NORMAL
    cue.text:SetText(priority == "MUST" and "MUST" or priority == "DANGEROUS" and "DANGER" or "IMPORTANT")
    ApplyCueColor(cue, color, 1)
    cue:SetAlpha(1)
    cue:Show()
    if self.frame.strip:IsShown() then
        local alpha = priority == "IMPORTANT" and 0.55 or priority == "DANGEROUS" and 0.8 or 1
        edge:SetColor(color[1], color[2], color[3], alpha)
        edge:SetShown(true)
    else
        edge:SetShown(false)
    end
end

function CP:DrawThreat()
    local chip, ctx = self.frame.threat, self.ctx
    if not self.plan.threat then chip:Hide() return end
    local level = ctx.threat
    local text = THREAT_TEXT[ctx.tank and "tank" or "dps"][level]
    local colors = T.db.nameplates.colors
    local col = (level == "safe" and colors.threatSafe) or (level == "warn" and colors.threatWarn) or colors.threatAggro
    if not text then
        chip:SetAlpha(0.3)
        text, col = ctx.tank and "HOLD" or "SAFE", colors.threatSafe
    else
        chip:SetAlpha(1)
    end
    chip.text:SetText(text)
    ApplyCueColor(chip, col, 1)
    chip:Show()
end

function CP:DrawPurge()
    local chip, color = self.frame.purge, self.db.purgeColor
    if not self.plan.purge then chip:Hide() return end
    ApplyCueColor(chip, color, 1)
    chip:SetAlpha(self.ctx.purge and 1 or 0.3)
    chip:Show()
end

function CP:DrawExecute()
    local tex = self.frame.exec
    if not self.plan.execute then tex:Hide() return end
    local color = T.db.nameplates.colors.execute
    tex:SetVertexColor(color[1], color[2], color[3], 0)
    tex:Show()
    if self.db.test then tex:SetVertexColor(color[1], color[2], color[3], 1) return end
    local key = ("%s:%s:%s:%s"):format(T.db.nameplates.execute, color[1], color[2], color[3])
    if self.curveKey ~= key then
        self.curveKey, self.curve = key, NP.MakeExecuteCurve(T.db.nameplates.execute, color)
    end
    if self.curve and UnitHealthPercent then
        local ok, curveColor = pcall(UnitHealthPercent, "target", true, self.curve)
        if ok and curveColor and pcall(function() tex:SetVertexColor(curveColor:GetRGBA()) end) then return end
    end
    local hp, max = Plain(UnitHealth, "target"), Plain(UnitHealthMax, "target")
    if T.Num(hp) and T.Num(max) and max > 0 and hp / max * 100 <= T.db.nameplates.execute then
        tex:SetVertexColor(color[1], color[2], color[3], 1)
    end
end

function CP:Layout()
    local f, h = self.frame, self.db.height
    local size = math.max(14, h + 2)
    local x = 0
    local widgets = { cast = f.cast, threat = f.threat, purge = f.purge, kick = f.kick }
    local function Place(widget, width)
        widget:ClearAllPoints()
        widget:SetSize(width, size)
        widget:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x, 4)
        x = x + width + 4
    end
    local role = self.db.roleAware ~= false and self.ctx.role or "DAMAGER"
    for _, key in ipairs(Rules.SignalOrder(role)) do
        local cue = widgets[key]
        if cue and cue:IsShown() then
            S.ApplyFont(cue.text, math.max(8, math.min(size - 4, 11)))
            local width = key == "kick" and math.max(48, cue.text:GetStringWidth() + 25)
                or math.max(size, cue.text:GetStringWidth() + 10)
            Place(cue, width)
        end
    end
end

function CP:RenderHistory()
    local panel, history = self.frame.history, self:History()
    local limit = math.min(5, self.db.historySize or 5)
    for i, row in ipairs(panel.rows) do
        local e = i <= limit and history[i]
        if e then
            local pct = e.pct and ("  " .. math.floor(e.pct + 0.5) .. "% of top") or ""
            local peak = e.peak and ("  peak " .. DT.Format(e.peak)) or ""
            row:SetText(("%d.  %s DPS%s%s"):format(i, DT.Format(e.dps), pct, peak))
            row:Show()
        else
            row:SetText(i == 1 and "No completed fights recorded yet." or "")
            row:SetShown(i == 1)
        end
    end
end

function CP:ToggleHistory(force)
    if not self.frame or (UnitAffectingCombat and UnitAffectingCombat("player")) then return end
    local panel = self.frame.history
    local show = force
    if show == nil then show = not panel:IsShown() end
    if show then
        self.frame.summary:Hide()
        self:RenderHistory()
        panel:Show()
    else
        panel:Hide()
    end
end

function CP:ShowSummary(entry)
    if not (self.db.showSummary and entry and self.frame) then return end
    local s = self.frame.summary
    self.frame.history:Hide()
    s:SetWidth(math.max(220, self.db.width))
    local relative = entry.pct and ("   " .. math.floor(entry.pct + 0.5) .. "% of leader") or ""
    s.main:SetText(DT.Format(entry.dps) .. " DPS" .. relative)
    s.sub:SetText(entry.peak and ("Peak " .. DT.Format(entry.peak)) or "Peak unavailable while combat values were hidden")
    s:Show()
    self.summaryToken = (self.summaryToken or 0) + 1
    local token = self.summaryToken
    C_Timer.After(tonumber(self.db.summarySeconds) or 5, function()
        if CP.summaryToken == token and CP.frame then CP.frame.summary:Hide() end
    end)
end

function CP:FinishFight()
    if not self.fightActive then return end
    self.fightActive = false
    local live, top, secret = Source.Read()
    if secret or not (T.Num(live) and live > 0) then return end
    local entry = {
        dps = live,
        top = T.Num(top) and top or nil,
        pct = Rules.PercentOfTop(live, top),
        peak = T.Num(self.fightPeak) and self.fightPeak > 0 and self.fightPeak or nil,
        at = time and time() or nil,
    }
    local history = self:History()
    self:SetHistory(Rules.PushHistory(history, entry, self.db.historySize))
    self:ShowSummary(entry)
end

function CP:Apply()
    local f, db = self.frame, self.db
    if not (f and db) then return end
    local unlocked = not T.db.locked
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
    local visible = Rules.Visible(db, inCombat, unlocked)
    f:SetShown(visible)
    if f.EnableMouse then f:EnableMouse(unlocked or (not inCombat and db.historyOnClick)) end
    if not visible then self:StopPoll() return end
    local ctx = self:Gather()
    self.plan = Rules.Plan(db, ctx)
    local plan = self.plan
    f.strip:SetShown(plan.strip or (unlocked and true) or false)
    f.bars.top:SetShown(plan.dps)
    f.bars.peak:SetShown(plan.dps)
    f.bars.live:SetShown(plan.dps)
    f.live:SetShown(plan.dps)
    f.extra:SetShown(plan.peakLabels)
    if not plan.dps then
        for _, tick in pairs(f.ticks) do tick:Hide() end
        f.previous:Hide(); f.previousTick:Hide()
    end
    self:DrawSwing()
    self:DrawCastPriority()
    self:DrawThreat()
    self:DrawPurge()
    self:DrawKick()
    self:DrawExecute()
    self:Layout()
    if plan.dps and (inCombat or db.test) then self:StartPoll() else self:StopPoll() end
end

function CP:StartPoll()
    if self.ticker then return end
    local interval = self.db.test and 0.1 or POLL
    self.ticker = C_Timer.NewTicker(interval, T:Wrap("combatpulse.poll", function() CP:Poll() end))
    self:Poll()
end

function CP:StopPoll()
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
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
        local color = colors[key]
        f.bars[key]:SetStatusBarColor(color[1], color[2], color[3], alphas[key])
        f.ticks[key]:SetVertexColor(Lighter(color))
        f.ticks[key]:SetWidth(S.Pixel() * 2)
    end
    f.live:SetTextColor(Lighter(db.liveColor))
    S.ApplyFont(f.live, math.max(8, math.min(db.height - 2, 11)))
    S.ApplyFont(f.extra, math.max(8, math.min(db.height - 2, 11)))
    f.swing:SetHeight(math.max(2, math.floor(db.height * 0.25)))
    f.summary:SetWidth(math.max(220, db.width))
    f.history:SetWidth(math.max(220, db.width))
    if db.test ~= self.testing then
        self.testing = db.test
        self.testStart = GetTime()
        self.state = Fight.New(not db.test and db.peak or 0)
        self.rangeMax, self.lastTop = nil, nil
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
    local shown = self.plan and self.frame:IsShown() and not self.db.test
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if shown and self.plan.execute then self:DrawExecute() end
        return
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        local now = GetTime()
        if shown and self.plan.kick and now - (self.kickAt or 0) > 0.1 then
            self.kickAt = now
            self:DrawKick()
        end
        return
    elseif event == "UNIT_AURA" then
        if shown and self.ctx.hostile and NP.HasPurgeable("target") ~= self.ctx.purge then self:Apply() end
        return
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
        if shown and self.ctx.hostile and (ThreatLevel()) ~= self.ctx.threat then self:Apply() end
        return
    elseif event == "DAMAGE_METER_RESET" then
        self.db.peak, self.db.rangeMax, self.lastTop, self.rangeMax = 0, nil, nil, nil
        Fight.Reset(self.state)
        self:ClearBars()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "ENCOUNTER_START" then
        self.fightActive, self.fightPeak = true, 0
        self.frame.summary:Hide()
        self.frame.history:Hide()
        Fight.BeginFight(self.state)
        self.secret = false
        self:ClearBars()
    elseif event == "PLAYER_REGEN_ENABLED" and not self.db.test then
        C_Timer.After(0.5, function()
            if not UnitAffectingCombat("player") then
                CP:FinishFight()
                if CP.plan and CP.plan.dps then CP:Poll() end
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
    desc = "One compact combat strip: damage pace, swing, interrupt priority, purge, threat and execute.",
    defaults = CP.defaults,
    OnEnable = function()
        CP.db = T.db.combatpulse
        CP.db.test = false
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
        if f.HookScript then
            f:HookScript("OnMouseUp", function(_, button)
                if button == "LeftButton" and CP.db.historyOnClick and T.db.locked then CP:ToggleHistory() end
            end)
        end
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
