-- Tempus UI: player, target, target-of-target, pet and focus frames.
-- Health and power are secret on this client, so values flow straight from the API into
-- status bars and formatted text; Lua never compares or computes with them.
local _, T = ...
local S = T.Style
local issecret = T.issecret

local UF = { frames = {} }
T.UnitFrames = UF

-- Focus only exists on clients that have the focus event.
local function HasFocus()
    if C_EventUtils and C_EventUtils.IsEventValid then
        local ok, valid = pcall(C_EventUtils.IsEventValid, "PLAYER_FOCUS_CHANGED")
        if ok then return valid and true or false end
    end
    return FocusFrame ~= nil
end

local UNITS = { "player", "target", "targettarget", "pet" }
if HasFocus() then UNITS[#UNITS + 1] = "focus" end
UF.units = UNITS
UF.labels = { player = "Player", target = "Target", targettarget = "Target of Target", pet = "Pet", focus = "Focus" }

local function Unit(point, x, y, overrides)
    local u = {
        enabled = true, width = 230, height = 44, powerHeight = 9, scale = 1,
        portrait = "NONE",          -- NONE | 2D | 3D | OVERLAY
        showName = true, showLevel = true,
        healthText = "BOTH",        -- PERCENT | CURRENT | BOTH | NONE
        powerText = "CURRENT",      -- PERCENT | CURRENT | NONE
        castbar = false, castbarHeight = 18,
        auras = false, auraSize = 24, auraPerRow = 8,
        point = { point, "UIParent", point, x, y },
    }
    for k, v in pairs(overrides or {}) do u[k] = v end
    return u
end

UF.defaults = {
    healthColor = "CLASS",          -- CLASS | REACTION | GRADIENT | DARK
    hideBlizzard = true,
    fontSize = 12,
    smooth = true,
    lagBar = true,              -- recent damage drains away behind the health bar
    lowHealth = true,           -- the player frame glows and pulses red at low health
    lowHealthAt = 35,           -- percent
    classPower = true,
    units = {
        player = Unit("CENTER", -300, -180, { portrait = "3D", castbar = true }),
        target = Unit("CENTER", 300, -180, { portrait = "3D", castbar = true, auras = true, powerText = "PERCENT" }),
        targettarget = Unit("CENTER", 300, -250, { width = 130, height = 26, powerHeight = 0, healthText = "PERCENT", showLevel = false }),
        pet = Unit("CENTER", -300, -250, { width = 130, height = 26, powerHeight = 5, healthText = "PERCENT", showLevel = false }),
        focus = Unit("CENTER", 300, -330, { width = 160, height = 30, powerHeight = 4, castbar = true, healthText = "PERCENT" }),
    },
}

----------------------------------------------------------------------------------------
-- Safe reads
----------------------------------------------------------------------------------------
local function Bool(fn, ...)
    if not fn then return false end
    local ok, v = pcall(fn, ...)
    return ok and not issecret(v) and v and true or false
end

local function Plain(fn, ...)
    if not fn then return nil end
    local ok, v, v2 = pcall(fn, ...)
    if not ok or issecret(v) then return nil end
    return v, (not issecret(v2)) and v2 or nil
end

local CURVE100 = CurveConstants and CurveConstants.ScaleTo100
local function SetBarValue(bar, v)
    S.SetBar(bar, v, UF.db.smooth, UF.db.lagBar)
end

----------------------------------------------------------------------------------------
-- Colours
----------------------------------------------------------------------------------------
local gradientCurve
local function GradientCurve()
    if gradientCurve ~= nil then return gradientCurve end
    gradientCurve = false
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType then
        local ok, c = pcall(function()
            local c = C_CurveUtil.CreateColorCurve()
            c:SetType(Enum.LuaCurveType.Linear)
            c:AddPoint(0, CreateColor(0.9, 0.15, 0.15, 1))
            c:AddPoint(0.5, CreateColor(0.95, 0.8, 0.15, 1))
            c:AddPoint(1, CreateColor(0.2, 0.8, 0.3, 1))
            return c
        end)
        if ok then gradientCurve = c end
    end
    return gradientCurve
end

local function UnitColor(unit)
    if Bool(UnitIsPlayer, unit) then
        local _, class = Plain(UnitClass, unit)
        if type(class) == "string" then return S.ClassColor(class) end
    end
    if Bool(UnitIsTapDenied, unit) then return 0.55, 0.55, 0.55 end
    if UnitSelectionColor then
        local ok, r, g, b = pcall(UnitSelectionColor, unit)
        if ok and T.Num(r) and T.Num(g) and T.Num(b) then return r, g, b end
    end
    local reaction = Plain(UnitReaction, unit, "player")
    if type(reaction) == "number" then
        if reaction >= 5 then return 0.2, 0.75, 0.3 end
        if reaction == 4 then return 0.95, 0.85, 0.2 end
        return 0.85, 0.2, 0.2
    end
    return 0.3, 0.6, 1
end

local function PowerColor(unit)
    local ptype, token = Plain(UnitPowerType, unit)
    local c = type(token) == "string" and PowerBarColor and PowerBarColor[token]
    if c then return c.r, c.g, c.b end
    return 0.3, 0.5, 0.95
end

----------------------------------------------------------------------------------------
-- Element updates
----------------------------------------------------------------------------------------
-- Low health on the player frame: a red glow whose colour comes from a step curve, so the
-- secret health value decides whether it is visible and Lua never compares it. Above the
-- threshold the curve gives black, and the glow blends additively, so it vanishes even where
-- the client ignores a secret colour's alpha.
local LOW_COLOR, LOW_OFF = { 1, 0.12, 0.08 }, { 0, 0, 0, 0 }
local lowCurve, lowCurveAt
local function UpdateLowHealth(f, dead)
    local db = UF.db
    if lowCurveAt ~= db.lowHealthAt then
        lowCurveAt, lowCurve = db.lowHealthAt, S.ThresholdCurve(db.lowHealthAt, LOW_COLOR, LOW_OFF)
    end
    local glow, on = f.lowGlow, false
    if db.lowHealth and lowCurve and not dead and UnitHealthPercent then
        on = pcall(function()
            glow:SetVertexColor(UnitHealthPercent(f.unit, true, lowCurve):GetRGBA())
        end)
    end
    glow:SetShown(on)
    f.lowPulse:SetActive(on)
end

local function UpdateHealth(f)
    local unit = f.unit
    local hp = f.health
    local dead = Bool(UnitIsDeadOrGhost, unit)
    local offline = Bool(UnitIsPlayer, unit) and not Bool(UnitIsConnected, unit)
    local mode = UF.db.healthColor

    local pct, havePct
    if UnitHealthPercent and CURVE100 then
        local ok, v = pcall(UnitHealthPercent, unit, true, CURVE100)
        -- Test for nil only when the value is not secret; secrets must not be compared.
        if ok and (issecret(v) or v ~= nil) then pct, havePct = v, true end
    end
    if havePct then
        hp:SetMinMaxValues(0, 100)
        SetBarValue(hp, pct)
    else
        local okM, maxV = pcall(UnitHealthMax, unit)
        local okC, cur = pcall(UnitHealth, unit)
        if okM and okC then
            hp:SetMinMaxValues(0, maxV)
            SetBarValue(hp, cur)
        end
    end

    if f.lowGlow then UpdateLowHealth(f, dead) end

    -- Colour
    if dead or offline then
        hp:SetStatusBarColor(0.35, 0.35, 0.35)
        hp.bg:SetVertexColor(0.1, 0.1, 0.1, 0.9)
    elseif mode == "DARK" then
        local r, g, b = UnitColor(unit)
        hp:SetStatusBarColor(0.13, 0.14, 0.16)
        hp.bg:SetVertexColor(r * 0.55, g * 0.55, b * 0.55, 0.95)
    elseif mode == "GRADIENT" and GradientCurve() and UnitHealthPercent then
        local ok = pcall(function()
            local c = UnitHealthPercent(unit, true, gradientCurve)
            hp:SetStatusBarColor(c:GetRGB())
        end)
        if not ok then hp:SetStatusBarColor(UnitColor(unit)) end
        hp.bg:SetVertexColor(0.08, 0.09, 0.11, 0.9)
    else
        local r, g, b
        if mode == "REACTION" and Bool(UnitIsPlayer, unit) then
            -- Reaction mode ignores class: friendly players green, hostile red.
            if Bool(UnitIsFriend, "player", unit) then r, g, b = 0.2, 0.75, 0.3 else r, g, b = 0.85, 0.2, 0.2 end
        else
            r, g, b = UnitColor(unit)
        end
        hp:SetStatusBarColor(r, g, b)
        hp.bg:SetVertexColor(r * 0.18, g * 0.18, b * 0.18, 0.9)
    end

    -- Text
    local cfg, txt = f.cfg, f.healthText
    if cfg.healthText == "NONE" then
        txt:SetText("")
    elseif dead then
        txt:SetText(Bool(UnitIsGhost, unit) and "Ghost" or "Dead")
    elseif offline then
        txt:SetText("Offline")
    else
        local ok = pcall(function()
            if not havePct then
                txt:SetText(AbbreviateNumbers and AbbreviateNumbers(UnitHealth(unit)) or "")
            elseif cfg.healthText == "PERCENT" or not AbbreviateNumbers then
                txt:SetFormattedText("%.0f%%", pct)
            elseif cfg.healthText == "CURRENT" then
                txt:SetText(AbbreviateNumbers(UnitHealth(unit)))
            else
                txt:SetFormattedText("%s  |cffb0b8c8%.0f%%|r", AbbreviateNumbers(UnitHealth(unit)), pct)
            end
        end)
        if not ok then txt:SetText("") end
    end
end

local function UpdatePower(f)
    local pw = f.power
    if not pw:IsShown() then return end
    local unit = f.unit
    local okM, maxV = pcall(UnitPowerMax, unit)
    local okC, cur = pcall(UnitPower, unit)
    if okM and okC then
        pw:SetMinMaxValues(0, maxV)
        SetBarValue(pw, cur)
    end
    local r, g, b = PowerColor(unit)
    pw:SetStatusBarColor(r, g, b)
    pw.bg:SetVertexColor(r * 0.2, g * 0.2, b * 0.2, 0.9)
    local mode, txt = f.cfg.powerText, f.powerText
    if mode == "NONE" or f.cfg.powerHeight < 8 then txt:SetText("") return end
    local ok = pcall(function()
        if mode == "PERCENT" and UnitPowerPercent and CURVE100 then
            txt:SetFormattedText("%.0f%%", UnitPowerPercent(unit, nil, false, CURVE100))
        else
            txt:SetFormattedText("%d", UnitPower(unit))
        end
    end)
    if not ok then txt:SetText("") end
end

local function UpdateName(f)
    local unit, cfg = f.unit, f.cfg
    if not cfg.showName then f.nameText:SetText("") return end
    local level = cfg.showLevel and Plain(UnitLevel, unit)
    local ok = pcall(function()
        if level and level ~= 0 then
            local lvl = level < 0 and "??" or tostring(level)
            local class = Plain(UnitClassification, unit)
            if class == "elite" or class == "worldboss" or class == "rareelite" then lvl = lvl .. "+" end
            local c = GetQuestDifficultyColor and level > 0 and GetQuestDifficultyColor(level) or { r = 1, g = 0.3, b = 0.3 }
            f.nameText:SetFormattedText("|cff%02x%02x%02x%s|r  %s", c.r * 255, c.g * 255, c.b * 255, lvl, UnitName(unit))
        else
            f.nameText:SetText(UnitName(unit))
        end
    end)
    if not ok then f.nameText:SetText("") end
end

local function UpdatePortrait(f)
    local mode = f.cfg.portrait
    if mode == "2D" then
        pcall(SetPortraitTexture, f.portrait2D, f.unit)
    elseif mode == "3D" or mode == "OVERLAY" then
        local m = f.model
        m:ClearModel()
        if Bool(UnitIsVisible, f.unit) then
            pcall(m.SetUnit, m, f.unit)
            if m.SetPortraitZoom then m:SetPortraitZoom(1) end
            if m.SetCamDistanceScale then m:SetCamDistanceScale(mode == "OVERLAY" and 1.4 or 1) end
        else
            pcall(m.SetModel, m, "Interface\\Buttons\\TalkToMeQuestionMark.m2")
        end
    end
end

local function UpdateIndicators(f)
    local unit = f.unit
    local idx = Plain(GetRaidTargetIndex, unit)
    if idx then
        SetRaidTargetIconTexture(f.raidIcon, idx)
        f.raidIcon:Show()
    else
        f.raidIcon:Hide()
    end
    if unit == "player" then
        if Bool(UnitAffectingCombat, "player") then
            f.stateIcon:SetTexCoord(0.5, 1, 0, 0.49)
            f.stateIcon:Show()
        elseif Bool(IsResting) then
            f.stateIcon:SetTexCoord(0, 0.5, 0, 0.421875)
            f.stateIcon:Show()
        else
            f.stateIcon:Hide()
        end
    end
end

-- Combo points as five bars, each filled when points >= i: the secret count goes straight
-- into SetValue, so no comparison happens in Lua.
local function UpdateClassPower(f)
    local cp = f.classPower
    if not cp then return end
    local show = UF.db.classPower
    local _, class = Plain(UnitClass, "player")
    -- Only rogues and druids use combo points; for everyone else the bar stayed empty above the frame.
    if class ~= "ROGUE" and class ~= "DRUID" then show = false end
    if class == "DRUID" then
        local ptype = Plain(UnitPowerType, "player")
        show = show and Enum and Enum.PowerType and ptype == Enum.PowerType.Energy
    end
    show = show and Bool(UnitExists, "target")
    cp:SetShown(show and true or false)
    if not show then return end
    local points, have
    if Enum and Enum.PowerType and Enum.PowerType.ComboPoints then
        local ok, v = pcall(UnitPower, "player", Enum.PowerType.ComboPoints)
        if ok and (issecret(v) or v ~= nil) then points, have = v, true end
    end
    if not have and GetComboPoints then
        local ok, v = pcall(GetComboPoints, "player", "target")
        if ok and (issecret(v) or v ~= nil) then points, have = v, true end
    end
    if not have then cp:Hide() return end
    for i, pip in ipairs(cp.pips) do SetBarValue(pip, points) end
end

----------------------------------------------------------------------------------------
-- Cast bar
----------------------------------------------------------------------------------------
local INTERP = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
local DIR = Enum and Enum.StatusBarTimerDirection

-- Your interrupt, for colouring target and focus cast bars. Every rank is listed because
-- Classic knows each rank by its own id; ranks share one cooldown.
local INTERRUPTS = {
    1766, 1767, 1768, 1769, 38768,                  -- Kick
    6552, 6554,                                     -- Pummel
    72, 1671, 1672, 29704,                          -- Shield Bash
    2139,                                           -- Counterspell
    8042, 8044, 8045, 8046, 10412, 10413, 10414,    -- Earth Shock
    19244, 19647,                                   -- Spell Lock (felhunter)
}
local KICK_CD = { 0.85, 0.6, 0.2 }
local kickSpell

function UF.FindInterrupt()
    kickSpell = nil
    for _, id in ipairs(INTERRUPTS) do
        local known = false
        if IsPlayerSpell then
            local ok, v = pcall(IsPlayerSpell, id)
            known = ok and v == true
        end
        if not known and IsSpellKnown then
            local ok, v = pcall(IsSpellKnown, id, true)     -- pet spells
            known = ok and v == true
        end
        if known then kickSpell = id end
    end
    return kickSpell
end

-- true when your interrupt is ready, false when it is cooling down, nil when you have none
-- or the client will not say (secret cooldowns).
function UF.KickReady()
    if not kickSpell then return nil end
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, kickSpell)
        if ok and type(info) == "table" then start, duration = info.startTime, info.duration end
    elseif GetSpellCooldown then
        local ok, a, b = pcall(GetSpellCooldown, kickSpell)
        if ok then start, duration = a, b end
    end
    if not (T.Num(start) and T.Num(duration)) or issecret(start) or issecret(duration) then return nil end
    -- The global cooldown is not a reason to wait.
    return not (duration > 1.6 and start + duration > GetTime())
end

-- Colour a target or focus cast by whether you can interrupt it right now.
local function PaintKick(cb)
    if not cb.kickable then return end
    local ready = UF.KickReady()
    if ready == cb.kickState then return end
    cb.kickState = ready
    if ready == false then
        cb.bar:SetStatusBarColor(KICK_CD[1], KICK_CD[2], KICK_CD[3])
    else
        local c = cb.baseColor
        cb.bar:SetStatusBarColor(c[1], c[2], c[3])
    end
    cb.kick:SetShown(ready == true)
end

-- Alpha from a value that may be secret: the client decides; plain values are decided here.
local function BoolAlpha(tex, v)
    if issecret(v) then
        if tex.SetAlphaFromBoolean then pcall(tex.SetAlphaFromBoolean, tex, v, 1, 0) end
    else
        tex:SetAlpha(v and 1 or 0)
    end
end

local function CastStop(cb, failed)
    cb.casting, cb.dur = nil, nil
    if failed and cb:IsShown() then
        cb.bar:SetStatusBarColor(0.85, 0.2, 0.2)
        cb.text:SetText(failed)
        cb.kick:Hide()
        if failed == "Interrupted" and cb.kickable then cb.flash() end
        cb.fadeAt = GetTime() + 0.5
    else
        cb:Hide()
    end
end

local function CastStart(cb, unit, channel)
    local info = { pcall(channel and UnitChannelInfo or UnitCastingInfo, unit) }
    if not info[1] then CastStop(cb) return end
    local name, text, texture, startMS, endMS = info[2], info[3], info[4], info[5], info[6]
    -- UnitCastingInfo: ..., isTradeSkill, castID, notInterruptible; UnitChannelInfo has no castID.
    local notInterruptible
    if channel then notInterruptible = info[8] else notInterruptible = info[9] end
    if not issecret(name) and name == nil then CastStop(cb) return end

    if not pcall(cb.text.SetText, cb.text, name) then cb.text:SetText("") end
    if not pcall(cb.icon.SetTexture, cb.icon, texture) then cb.icon:SetTexture(136243) end
    cb.fadeAt = nil
    cb.channel = channel
    local ac = channel and { 0.35, 0.75, 0.35 } or { T.accent[1], T.accent[2], T.accent[3] }
    cb.bar:SetStatusBarColor(ac[1], ac[2], ac[3])
    cb.baseColor = ac
    BoolAlpha(cb.shield, notInterruptible)
    for _, t in ipairs(cb.lock) do BoolAlpha(t, notInterruptible) end
    cb.kickState = "unset"
    cb.kick:Hide()
    PaintKick(cb)

    local durFn = channel and UnitChannelDuration or UnitCastingDuration
    local dur
    if durFn and cb.bar.SetTimerDuration and DIR then
        local ok, d = pcall(durFn, unit)
        if ok and d then dur = d end
    end
    if dur and pcall(cb.bar.SetTimerDuration, cb.bar, dur, INTERP, channel and DIR.RemainingTime or DIR.ElapsedTime) then
        cb.dur = dur
        cb.casting = true
    elseif T.Num(startMS) and T.Num(endMS) then
        cb.dur = nil
        cb.startT, cb.endT = startMS / 1000, endMS / 1000
        cb.bar:SetMinMaxValues(0, cb.endT - cb.startT)
        cb.casting = true
    else
        CastStop(cb)
        return
    end
    cb:Show()
end

local function CastOnUpdate(cb)
    if cb.fadeAt then
        if GetTime() >= cb.fadeAt then cb.fadeAt = nil; cb:Hide() end
        return
    end
    if not cb.casting then return end
    if cb.kickable then
        local now = GetTime()
        if now >= (cb.kickAt or 0) then cb.kickAt = now + 0.1; PaintKick(cb) end
    end
    if cb.dur then
        pcall(function() cb.time:SetFormattedText("%.1f", cb.dur:GetRemainingDuration()) end)
    elseif cb.endT then
        local now = GetTime()
        local left = cb.endT - now
        if left <= 0 then CastStop(cb) return end
        cb.bar:SetValue(cb.channel and left or (now - cb.startT))
        cb.time:SetFormattedText("%.1f", left)
    end
end

local function CreateCastbar(f)
    local cb = CreateFrame("Frame", nil, f)
    S.Backdrop(cb)
    cb.icon = cb:CreateTexture(nil, "ARTWORK")
    cb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cb.iconFrame = CreateFrame("Frame", nil, cb)
    S.Backdrop(cb.iconFrame)
    cb.icon:SetParent(cb.iconFrame)
    cb.icon:SetAllPoints(cb.iconFrame)
    cb.bar = S.StatusBar(cb)
    cb.bar:SetAllPoints(cb)
    cb.spark = cb.bar:CreateTexture(nil, "OVERLAY")
    cb.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    cb.spark:SetBlendMode("ADD")
    cb.spark:SetPoint("CENTER", cb.bar:GetStatusBarTexture(), "RIGHT")
    cb.shield = cb.bar:CreateTexture(nil, "OVERLAY")
    cb.shield:SetAllPoints(cb.bar)
    cb.shield:SetTexture(S.WHITE)
    cb.shield:SetVertexColor(0.6, 0.6, 0.6, 0.45)
    cb.shield:SetAlpha(0)
    -- Uninterruptible casts also get a grey edge, so "locked" reads at a glance.
    local lock = S.CreateBorder(cb, "OVERLAY", 6)
    lock:SetThickness(1, cb)
    lock:SetColor(0.75, 0.75, 0.75, 1)
    cb.lock = { lock.top, lock.bottom, lock.left, lock.right }
    for _, t in ipairs(cb.lock) do t:SetAlpha(0) end
    -- Ready-to-interrupt mark at the bar's right end.
    cb.kick = cb.bar:CreateTexture(nil, "OVERLAY", nil, 7)
    cb.kick:SetTexture(S.WHITE)
    cb.kick:SetPoint("TOPRIGHT", cb.bar)
    cb.kick:SetPoint("BOTTOMRIGHT", cb.bar)
    cb.kick:SetWidth(3)
    S.Accent(cb.kick)
    cb.kick:Hide()
    -- A flash over the bar when a cast is interrupted.
    local flash = cb.bar:CreateTexture(nil, "OVERLAY", nil, 7)
    flash:SetTexture(S.WHITE)
    flash:SetAllPoints(cb.bar)
    flash:SetBlendMode("ADD")
    flash:SetVertexColor(1, 0.3, 0.2, 0.8)
    cb.flash = S.Flash(flash)
    local over = CreateFrame("Frame", nil, cb)
    over:SetAllPoints(cb)
    over:SetFrameLevel(cb.bar:GetFrameLevel() + 3)
    cb.text = over:CreateFontString(nil, "OVERLAY")
    cb.text:SetPoint("LEFT", 6, 0)
    cb.text:SetJustifyH("LEFT")
    cb.time = over:CreateFontString(nil, "OVERLAY")
    cb.time:SetPoint("RIGHT", -6, 0)
    cb.text:SetPoint("RIGHT", cb.time, "LEFT", -4, 0)
    cb.text:SetWordWrap(false)
    cb:SetScript("OnUpdate", T:Wrap("unitframes.castbar", CastOnUpdate))
    cb:Hide()
    return cb
end

----------------------------------------------------------------------------------------
-- Frame construction
----------------------------------------------------------------------------------------
local function OnEnter(self)
    if self.unitWatchOff and not Bool(UnitExists, self.unit) then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    if GameTooltip:SetUnit(self.unit) ~= false then GameTooltip:Show() end
end

local function CreateUnitFrame(unit)
    local f = CreateFrame("Button", "TempusUF_" .. unit, UIParent, "SecureUnitButtonTemplate")
    f.unit = unit
    f:SetAttribute("unit", unit)
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    f:SetFrameStrata("LOW")
    f:SetScript("OnEnter", OnEnter)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.bd = S.Backdrop(f)
    if unit ~= "player" then S.FadeIn(f, 0.12) end

    f.health = S.StatusBar(f)
    S.LagBar(f.health)
    if unit == "player" then
        f.lowGlow = S.Glow(f, 14, "BACKGROUND", -7)
        if f.lowGlow then f.lowGlow:SetBlendMode("ADD") end
        if f.lowGlow then f.lowPulse = S.Pulse(f.lowGlow, 1, 0.3, 1.1) end
    end
    f.power = S.StatusBar(f)
    f.powerSep = S.Tex(f, "ARTWORK", { 0, 0, 0, 1 })
    f.powerSep:SetHeight(1)

    f.portraitFrame = CreateFrame("Frame", nil, f)
    S.Backdrop(f.portraitFrame, { shadow = false })
    f.portrait2D = f.portraitFrame:CreateTexture(nil, "ARTWORK")
    f.portrait2D:SetAllPoints()
    f.portrait2D:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    f.model = CreateFrame("PlayerModel", nil, f.portraitFrame)
    f.model:SetAllPoints()

    local over = CreateFrame("Frame", nil, f)
    over:SetAllPoints(f)
    over:SetFrameLevel(f:GetFrameLevel() + 8)
    f.over = over
    f.nameText = over:CreateFontString(nil, "OVERLAY")
    f.nameText:SetJustifyH("LEFT")
    f.nameText:SetWordWrap(false)
    f.healthText = over:CreateFontString(nil, "OVERLAY")
    f.healthText:SetJustifyH("RIGHT")
    f.powerText = over:CreateFontString(nil, "OVERLAY")
    f.powerText:SetJustifyH("RIGHT")
    f.raidIcon = over:CreateTexture(nil, "OVERLAY")
    f.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.raidIcon:SetSize(18, 18)
    f.raidIcon:SetPoint("CENTER", f, "TOP", 0, 0)
    f.raidIcon:Hide()
    if unit == "player" then
        f.stateIcon = over:CreateTexture(nil, "OVERLAY")
        f.stateIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
        f.stateIcon:SetSize(20, 20)
        f.stateIcon:SetPoint("CENTER", f, "TOPLEFT", 2, -2)
        f.stateIcon:Hide()

        local cp = CreateFrame("Frame", nil, f)
        cp.pips = {}
        for i = 1, 5 do
            local pip = S.StatusBar(cp)
            pip:SetMinMaxValues(i - 1, i)
            pip:SetStatusBarColor(1, 0.8, 0.2)
            S.Backdrop(pip, { shadow = false, inner = false })
            cp.pips[i] = pip
        end
        cp:Hide()
        f.classPower = cp
    end
    if unit == "player" or unit == "target" or unit == "focus" then
        f.castbar = CreateCastbar(f)
        f.castbar.kickable = unit ~= "player"
    end
    if unit == "target" and T.Display and T.Display.NativeAvailable then
        -- Aura containers stay live in combat, when auras are secret to addons.
        f.auraBuffs = { id = "UF_target_buffs", key = "buffs", unit = "target", filter = "HELPFUL", frame = CreateFrame("Frame", nil, f) }
        f.auraDebuffs = { id = "UF_target_debuffs", key = "debuffs", unit = "target", filter = "HARMFUL", frame = CreateFrame("Frame", nil, f) }
    end
    return f
end

local function AuraCfg(cfg, rows)
    return { style = "ICONS", size = cfg.auraSize, timer = "CENTER", perRow = cfg.auraPerRow, rows = rows,
        spacing = 3, growX = "RIGHT", growY = "UP", sort = "INDEX", reverse = false, onlyMine = false }
end

function UF:Layout(f)
    local cfg, db = f.cfg, UF.db
    f:SetScale(cfg.scale)
    f:SetSize(cfg.width, cfg.height)
    local ph = cfg.powerHeight
    local portraitW = (cfg.portrait == "2D" or cfg.portrait == "3D") and cfg.height or 0
    local left = portraitW > 0 and (portraitW + 1) or 0
    local fs = db.fontSize
    local smallFs = math.max(fs - 2, 8)

    f.portraitFrame:ClearAllPoints()
    if portraitW > 0 then
        f.portraitFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.portraitFrame:SetSize(portraitW, cfg.height)
        f.portraitFrame:Show()
        f.portrait2D:SetShown(cfg.portrait == "2D")
        f.model:SetShown(cfg.portrait == "3D")
        f.model:SetAlpha(1)
    elseif cfg.portrait == "OVERLAY" then
        f.portraitFrame:SetAllPoints(f.health)
        f.portraitFrame:Show()
        f.portraitFrame.tempusBackdrop:SetShown(false)
        f.portrait2D:Hide()
        f.model:Show()
        f.model:SetAlpha(0.35)
        f.portraitFrame:SetFrameLevel(f.health:GetFrameLevel() + 1)
    else
        f.portraitFrame:Hide()
    end
    if portraitW > 0 then f.portraitFrame.tempusBackdrop:SetShown(true) end

    local tex = S.BarTexture(T.db.barTexture)
    f.health:SetStatusBarTexture(tex)
    f.health.bg:SetTexture(tex)
    if f.health.tempusLag then f.health.tempusLag:SetStatusBarTexture(tex) end
    f.power:SetStatusBarTexture(tex)
    f.power.bg:SetTexture(tex)
    f.health:ClearAllPoints()
    f.health:SetPoint("TOPLEFT", f, "TOPLEFT", left, 0)
    f.health:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.health:SetHeight(ph > 0 and (cfg.height - ph - 1) or cfg.height)
    f.power:ClearAllPoints()
    f.power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, 0)
    f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.power:SetHeight(math.max(ph, 1))
    f.power:SetShown(ph > 0)
    f.powerSep:ClearAllPoints()
    f.powerSep:SetPoint("BOTTOMLEFT", f.health, "BOTTOMLEFT", 0, -1)
    f.powerSep:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", 0, -1)
    f.powerSep:SetShown(ph > 0)

    S.ApplyFont(f.nameText, cfg.height < 30 and smallFs or fs)
    S.ApplyFont(f.healthText, cfg.height < 30 and smallFs or fs)
    S.ApplyFont(f.powerText, smallFs)
    f.healthText:ClearAllPoints()
    f.healthText:SetPoint("RIGHT", f.health, "RIGHT", -5, 0)
    f.nameText:ClearAllPoints()
    f.nameText:SetPoint("LEFT", f.health, "LEFT", 5, 0)
    f.nameText:SetPoint("RIGHT", f.healthText, "LEFT", -6, 0)
    f.powerText:ClearAllPoints()
    f.powerText:SetPoint("RIGHT", f.power, "RIGHT", -5, 0)

    if f.classPower then
        local cp = f.classPower
        cp:ClearAllPoints()
        cp:SetPoint("BOTTOMLEFT", f, "TOPLEFT", left, 4)
        cp:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 4)
        cp:SetHeight(6)
        local w = (cfg.width - left - 4 * 3) / 5
        for i, pip in ipairs(cp.pips) do
            pip:ClearAllPoints()
            pip:SetSize(w, 6)
            pip:SetPoint("LEFT", cp, "LEFT", (i - 1) * (w + 3), 0)
            pip:SetStatusBarTexture(tex)
            pip.bg:SetTexture(tex)
        end
    end

    local cb = f.castbar
    if cb then
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", f, "BOTTOMLEFT", cfg.castbarHeight + 4, -6)
        cb:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -6)
        cb:SetHeight(cfg.castbarHeight)
        cb.iconFrame:ClearAllPoints()
        cb.iconFrame:SetPoint("RIGHT", cb, "LEFT", -4, 0)
        cb.iconFrame:SetSize(cfg.castbarHeight, cfg.castbarHeight)
        cb.bar:SetStatusBarTexture(tex)
        cb.bar.bg:SetTexture(tex)
        cb.spark:SetSize(12, cfg.castbarHeight * 2.2)
        S.ApplyFont(cb.text, smallFs)
        S.ApplyFont(cb.time, smallFs)
        if not cfg.castbar then cb:Hide() end
    end

    for _, a in ipairs({ f.auraDebuffs, f.auraBuffs }) do
        if a then
            a.cfg = AuraCfg(cfg, a == f.auraDebuffs and 1 or 2)
            a.frame:ClearAllPoints()
            a.frame:SetSize(cfg.width, cfg.auraSize)
        end
    end
    if f.auraDebuffs then
        f.auraDebuffs.frame:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 6)
        f.auraBuffs.frame:SetPoint("BOTTOMLEFT", f.auraDebuffs.frame, "TOPLEFT", 0, 3)
        local D = T.Display
        for _, a in ipairs({ f.auraDebuffs, f.auraBuffs }) do
            a.frame:SetShown(cfg.auras)
            if cfg.auras and D:NativeAvailable() then
                local ok, err = pcall(D.ConfigureNative, D, a)
                if ok then
                    a.native:Show()
                    a.native:SetEnabled(true)
                else
                    T:ReportError("target auras: " .. tostring(err))
                end
            elseif a.native then
                a.native:SetEnabled(false)
                a.native:Hide()
            end
        end
    end
end

function UF:UpdateAll(f)
    if not f.cfg.enabled then return end
    if not Bool(UnitExists, f.unit) then
        if f.preview then UF:Preview(f) end
        return
    end
    UpdateHealth(f)
    UpdatePower(f)
    UpdateName(f)
    UpdatePortrait(f)
    UpdateIndicators(f)
    UpdateClassPower(f)
    if f.castbar and f.cfg.castbar then
        if not pcall(CastStart, f.castbar, f.unit, false) or not f.castbar.casting then
            pcall(CastStart, f.castbar, f.unit, true)
        end
    end
end

-- Placeholder content while unlocked, so frames can be positioned without a target.
function UF:Preview(f)
    f.health:SetMinMaxValues(0, 100)
    f.health:SetValue(72)
    if f.health.tempusLag then f.health.tempusLag:Hide() end
    if f.lowGlow then f.lowGlow:Hide(); f.lowPulse:SetActive(false) end
    local r, g, b = S.ClassColor(select(2, UnitClass("player")))
    f.health:SetStatusBarColor(r, g, b)
    f.power:SetMinMaxValues(0, 100)
    f.power:SetValue(55)
    f.power:SetStatusBarColor(0.3, 0.5, 0.95)
    f.nameText:SetText(UF.labels[f.unit])
    f.healthText:SetText("72%")
    f.powerText:SetText("")
end

----------------------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------------------
local UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_PORTRAIT_UPDATE",
    "UNIT_MODEL_CHANGED", "UNIT_FLAGS",
}
local CAST_START = { UNIT_SPELLCAST_START = false, UNIT_SPELLCAST_DELAYED = false,
    UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true }
local CAST_STOP = { UNIT_SPELLCAST_STOP = false, UNIT_SPELLCAST_CHANNEL_STOP = false,
    UNIT_SPELLCAST_FAILED = "Failed", UNIT_SPELLCAST_INTERRUPTED = "Interrupted" }

local function OnEvent(f, event, unit, arg2)
    if not f.cfg.enabled then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
        UpdateHealth(f)
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        UpdatePower(f)
        if f.classPower then UpdateClassPower(f) end
    elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL" then
        UpdateName(f)
    elseif event == "UNIT_FACTION" then
        UpdateHealth(f)
    elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
        UpdatePortrait(f)
    elseif CAST_START[event] ~= nil then
        if f.castbar and f.cfg.castbar then pcall(CastStart, f.castbar, f.unit, CAST_START[event]) end
    elseif CAST_STOP[event] ~= nil then
        if f.castbar and f.castbar.casting then CastStop(f.castbar, CAST_STOP[event] or nil) end
    else
        -- A new unit behind the frame: its health bar jumps rather than draining.
        if event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD"
            or (event == "PLAYER_TARGET_CHANGED" and f.unit ~= "player")
            or event == "PLAYER_FOCUS_CHANGED" then
            S.SnapLag(f.health)
        end
        UF:UpdateAll(f)
    end
end

local function RegisterEvents(f)
    local unit = f.unit
    if unit ~= "targettarget" then
        for _, e in ipairs(UNIT_EVENTS) do f:RegisterUnitEvent(e, unit) end
        if f.castbar then
            for e in pairs(CAST_START) do f:RegisterUnitEvent(e, unit) end
            for e in pairs(CAST_STOP) do f:RegisterUnitEvent(e, unit) end
        end
    end
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("RAID_TARGET_UPDATE")
    if unit == "target" or unit == "targettarget" then f:RegisterEvent("PLAYER_TARGET_CHANGED") end
    if unit == "pet" then f:RegisterUnitEvent("UNIT_PET", "player") end
    if unit == "focus" then f:RegisterEvent("PLAYER_FOCUS_CHANGED") end
    if unit == "player" then
        f:RegisterEvent("PLAYER_REGEN_DISABLED")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:RegisterEvent("PLAYER_UPDATE_RESTING")
        f:RegisterEvent("PLAYER_TARGET_CHANGED")
        f:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    end
    f:SetScript("OnEvent", T:Wrap("unitframes.events", OnEvent))
    if unit == "targettarget" then
        -- No events fire when the target's target changes.
        local t = 0
        f:SetScript("OnUpdate", T:Wrap("unitframes.tot", function(self, elapsed)
            t = t + elapsed
            if t > 0.2 then t = 0; UF:UpdateAll(self) end
        end))
    end
end

----------------------------------------------------------------------------------------
-- Visibility, preview and Blizzard frames
----------------------------------------------------------------------------------------
function UF:ApplyVisibility(f)
    T:RunOOC(function()
        local cfg = f.cfg
        local preview = cfg.enabled and not T.db.locked
        f.preview = preview
        if not cfg.enabled then
            UnregisterUnitWatch(f)
            f:Hide()
        elseif preview and f.unit ~= "player" then
            UnregisterUnitWatch(f)
            f:Show()
        elseif f.unit == "player" then
            UnregisterUnitWatch(f)
            f:Show()
        else
            RegisterUnitWatch(f)
        end
        UF:UpdateAll(f)
    end, "ufvis_" .. f.unit)
end

local hider
local function HideBlizzard(frame)
    if not frame then return end
    hider = S.HiddenParent
    pcall(frame.UnregisterAllEvents, frame)
    pcall(frame.SetParent, frame, hider)
end

function UF:HideBlizzard()
    if not UF.db.hideBlizzard or UF.blizzHidden then return end
    T:RunOOC(function()
        UF.blizzHidden = true
        local u = UF.db.units
        if u.player.enabled then HideBlizzard(PlayerFrame) end
        if u.target.enabled then HideBlizzard(TargetFrame); HideBlizzard(ComboFrame) end
        if u.pet.enabled and PetFrame then HideBlizzard(PetFrame) end
        if UF.frames.focus and u.focus.enabled and FocusFrame then HideBlizzard(FocusFrame) end
        if u.player.enabled and u.player.castbar and PlayerCastingBarFrame then
            pcall(PlayerCastingBarFrame.SetUnit, PlayerCastingBarFrame, nil)
            HideBlizzard(PlayerCastingBarFrame)
        end
    end, "ufblizz")
end

----------------------------------------------------------------------------------------
-- Module
----------------------------------------------------------------------------------------
function UF:Refresh()
    for _, unit in ipairs(UNITS) do
        local f = UF.frames[unit]
        f.cfg = UF.db.units[unit]
        T:RunOOC(function()
            UF:Layout(f)
            T.Movers.ApplyPoint(f, f.cfg, "CENTER")
        end, "uflayout_" .. unit)
        UF:ApplyVisibility(f)
    end
    UF:HideBlizzard()
end

T:NewModule("unitframes", {
    label = "Unit Frames",
    desc = "Player, target, target-of-target and pet frames with cast bars, portraits and combo points.",
    defaults = UF.defaults,
    OnEnable = function()
        UF.db = T.db.unitframes
        UF.FindInterrupt()
        local spells = CreateFrame("Frame")
        spells:RegisterEvent("SPELLS_CHANGED")
        spells:RegisterEvent("UNIT_PET")
        spells:SetScript("OnEvent", function() UF.FindInterrupt() end)
        for _, unit in ipairs(UNITS) do
            local f = CreateUnitFrame(unit)
            f.cfg = UF.db.units[unit]
            UF.frames[unit] = f
            RegisterEvents(f)
            T.Movers:Register(f, {
                label = UF.labels[unit], page = "uf_" .. unit, secure = true,
                cfg = function() return UF.db.units[unit] end,
                corner = function() return "CENTER" end,
                enabled = function() return UF.db.units[unit].enabled end,
            })
        end
        UF:Refresh()
    end,
    OnSettings = function()
        UF.db = T.db.unitframes
        UF:Refresh()
    end,
})
