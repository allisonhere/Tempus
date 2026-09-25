-- Tempus UI: nameplates. Each Blizzard plate gets a Tempus frame; the stock unit frame is
-- hidden. Health, names and threat can be secret on this client, so values flow straight
-- into bars, text and colour curves, and auras are drawn by the game's aura containers.
local _, T = ...
local S = T.Style
local issecret = T.issecret

local NP = { plates = {}, byUnit = {}, version = 0 }
T.Nameplates = NP

NP.defaults = {
    width = 140, height = 12, fontSize = 10, nameSize = 10,
    healthText = "PERCENT",     -- PERCENT | CURRENT | BOTH | NONE
    showLevel = true,
    levelStyle = "RELATIVE",    -- RELATIVE (+3 / -2) | ABSOLUTE (61)
    conStrip = true,            -- con-coloured strip at the left end of the health bar
    conMarker = "CHEVRONS",     -- CHEVRONS (elite/rare/boss) | DANGER (1-5 rating) | NONE
    trivialFade = true, trivialAlpha = 0.45,    -- grey (no XP) mobs: smaller and faded
    smooth = true,
    classColorEnemies = true, classColorFriends = true,
    friendlyNameOnly = true,
    targetScale = 1.15, nonTargetAlpha = 0.6, targetGlow = true, mouseoverGlow = true,
    threat = true, threatRole = "AUTO",     -- AUTO | TANK | DPS
    execute = 20,               -- percent; 0 turns it off
    castbar = true, castHeight = 10,
    castAlerts = true,          -- watched spells (Tempus > Nameplates > Casts & Auras list)
    kickHighlight = true,       -- bright edge on casts that can be interrupted
    alertSound = false,
    debuffs = "MINE",           -- MINE | ALL | NONE
    debuffSize = 22, debuffMax = 6,
    buffs = "PURGE",            -- PURGE | ALL | NONE
    buffSize = 20, buffMax = 4,
    cc = true, ccSize = 30,
    raidIcon = true, questIcon = true,
    manageCVars = true, stacking = true, maxDistance = 41,
    colors = {
        hostile = { 0.85, 0.2, 0.2 }, neutral = { 0.95, 0.8, 0.2 }, friendly = { 0.2, 0.75, 0.3 },
        tapped = { 0.55, 0.55, 0.55 }, execute = { 1, 0.45, 0.9 },
        threatSafe = { 0.25, 0.6, 1 }, threatWarn = { 1, 0.6, 0.1 }, threatAggro = { 1, 0.1, 0.1 },
        cast = { 0.25, 0.76, 1 }, castLocked = { 0.55, 0.55, 0.6 }, castAlert = { 1, 0.2, 0.75 },
    },
}

-- Addons that also replace nameplates; running two at once fights over the same frames.
local CONFLICTS = { "Plater", "Kui_Nameplates", "TidyPlates_ThreatPlates", "TidyPlates", "NeatPlates" }

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
local SMOOTH = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local INTERP = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
local DIR = Enum and Enum.StatusBarTimerDirection

local function SetBarValue(bar, v)
    if NP.db.smooth and SMOOTH and pcall(bar.SetValue, bar, v, SMOOTH) then return end
    bar:SetValue(v)
end

local function PlateFor(unit)
    return C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
end

----------------------------------------------------------------------------------------
-- Execute range: a step curve over the health fraction (0-1) whose alpha is 1 below the
-- threshold and 0 above it, applied to an overlay on the bar fill. No secret is compared.
----------------------------------------------------------------------------------------
local function BuildExecuteCurve()
    NP.executeCurve = nil
    local db = NP.db
    if db.execute <= 0 or not (C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType) then return end
    local ok, curve = pcall(function()
        local c = db.colors.execute
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, CreateColor(c[1], c[2], c[3], 1))
        curve:AddPoint(db.execute / 100, CreateColor(c[1], c[2], c[3], 0))
        return curve
    end)
    if ok then NP.executeCurve = curve end
end

----------------------------------------------------------------------------------------
-- Colours
----------------------------------------------------------------------------------------
local function IsHostile(unit)
    return not Bool(UnitIsFriend, "player", unit)
end

local function IsTankRole()
    local role = NP.db.threatRole
    if role == "TANK" then return true end
    if role == "DPS" then return false end
    return Plain(UnitGroupRolesAssigned, "player") == "TANK"
end

-- Threat status 0-3 mapped to a colour, or nil to fall back to reaction colours.
local function ThreatColor(unit)
    local db = NP.db
    if not db.threat or Bool(UnitIsPlayer, unit) or not Bool(UnitAffectingCombat, unit) then return nil end
    local status = Plain(UnitThreatSituation, "player", unit)
    if not T.Num(status) then return nil end
    local c = db.colors
    if IsTankRole() then
        if status == 3 then return c.threatSafe end
        if status >= 1 then return c.threatWarn end
        return c.threatAggro
    end
    if status >= 2 then return c.threatAggro end
    if status == 1 then return c.threatWarn end
    return nil
end

local function ReactionColor(unit)
    local c = NP.db.colors
    local reaction = Plain(UnitReaction, unit, "player")
    if type(reaction) == "number" then
        if reaction >= 5 then return c.friendly[1], c.friendly[2], c.friendly[3] end
        if reaction == 4 then return c.neutral[1], c.neutral[2], c.neutral[3] end
        return c.hostile[1], c.hostile[2], c.hostile[3]
    end
    if UnitSelectionColor then
        local ok, r, g, b = pcall(UnitSelectionColor, unit)
        if ok and T.Num(r) and T.Num(g) and T.Num(b) then return r, g, b end
    end
    return c.hostile[1], c.hostile[2], c.hostile[3]
end

local function HealthColor(f)
    local unit, db = f.unit, NP.db
    if Bool(UnitIsPlayer, unit) then
        local hostile = f.hostile
        if (hostile and db.classColorEnemies) or (not hostile and db.classColorFriends) then
            local _, class = Plain(UnitClass, unit)
            if type(class) == "string" then return S.ClassColor(class) end
        end
    end
    if Bool(UnitIsTapDenied, unit) then
        local c = db.colors.tapped
        return c[1], c[2], c[3]
    end
    local t = f.hostile and ThreatColor(unit)
    if t then return t[1], t[2], t[3] end
    return ReactionColor(unit)
end

----------------------------------------------------------------------------------------
-- Element updates
----------------------------------------------------------------------------------------
local function UpdateHealth(f)
    local unit, hp = f.unit, f.health
    local pct, havePct
    if UnitHealthPercent and CURVE100 then
        local ok, v = pcall(UnitHealthPercent, unit, true, CURVE100)
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

    local ex = f.executeTint
    if NP.executeCurve and f.hostile and UnitHealthPercent then
        local ok = pcall(function()
            ex:SetVertexColor(UnitHealthPercent(unit, true, NP.executeCurve):GetRGBA())
        end)
        ex:SetShown(ok)
    else
        ex:Hide()
    end

    local mode, txt = NP.db.healthText, f.healthText
    if mode == "NONE" or f.nameOnly then txt:SetText("") return end
    local ok = pcall(function()
        if not havePct or mode == "CURRENT" then
            txt:SetText(AbbreviateNumbers and AbbreviateNumbers(UnitHealth(unit)) or "")
        elseif mode == "BOTH" and AbbreviateNumbers then
            txt:SetFormattedText("%s - %.0f%%", AbbreviateNumbers(UnitHealth(unit)), pct)
        else
            txt:SetFormattedText("%.0f%%", pct)
        end
    end)
    if not ok then txt:SetText("") end
end

local function UpdateColor(f)
    local r, g, b = HealthColor(f)
    f.health:SetStatusBarColor(r, g, b)
    f.health.bg:SetVertexColor(r * 0.18, g * 0.18, b * 0.18, 0.9)
    if f.nameOnly then
        f.nameText:SetTextColor(r, g, b)
    else
        f.nameText:SetTextColor(1, 1, 1)
    end
end

----------------------------------------------------------------------------------------
-- Con: how tough a unit is next to you, readable without reading. A strip at the left
-- of the bar in the con colour, the level as a difference (+3 / -2), pips for elite /
-- rare / boss or a 1-5 danger rating, and grey (no XP) mobs shrunk and faded.
----------------------------------------------------------------------------------------
local CON_COLORS = {
    GRAY = { 0.55, 0.55, 0.55 }, GREEN = { 0.25, 0.78, 0.25 }, YELLOW = { 1, 0.85, 0 },
    ORANGE = { 1, 0.5, 0.15 }, RED = { 1, 0.12, 0.12 }, SKULL = { 0.85, 0.15, 0.85 },
}
local CON_ORDER = { "GRAY", "GREEN", "YELLOW", "ORANGE", "RED", "SKULL" }
local CLASS_MARKS = { elite = 1, rare = 1, rareelite = 2, worldboss = 3 }
local SKULL_TEX = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

-- Levels below yours that still give XP (green); anything lower is grey.
local function GreenRange(me)
    if GetQuestGreenRange then
        local ok, v = pcall(GetQuestGreenRange)
        if ok and T.Num(v) then return v end
    end
    if me <= 5 then return 5 end
    if me <= 39 then return math.floor(me / 10) + 5 end
    if me <= 59 then return math.floor(me / 5) + 1 end
    return 9
end

-- Pure: builds the con from plain numbers, so the settings preview can use it too.
-- hpRatio is the unit's max health over yours, or nil when unreadable.
local function ConInfo(level, class, me, hpRatio)
    local con = { level = level, class = class, marks = CLASS_MARKS[class] or 0 }
    if level < 0 or class == "worldboss" then
        con.key, con.diff = "SKULL", nil
    else
        local diff = level - me
        con.diff = diff
        if diff >= 5 then con.key = "RED"
        elseif diff >= 3 then con.key = "ORANGE"
        elseif diff >= -2 then con.key = "YELLOW"
        elseif -diff <= GreenRange(me) then con.key = "GREEN"
        else con.key = "GRAY" end
    end
    con.trivial = con.key == "GRAY"
    local c = CON_COLORS[con.key]
    con.r, con.g, con.b = c[1], c[2], c[3]
    -- Danger 0-5: the con, +1 for elites, and the unit's health against yours.
    local score = ({ GRAY = 0, GREEN = 1, YELLOW = 2, ORANGE = 3, RED = 4, SKULL = 5 })[con.key]
    if class == "elite" or class == "rareelite" then score = score + 1 end
    if hpRatio then
        if hpRatio >= 6 then score = score + 2
        elseif hpRatio >= 2.5 then score = score + 1
        elseif hpRatio < 0.4 then score = score - 1 end
    end
    con.danger = math.max(0, math.min(5, score))
    return con
end

local function UnitCon(unit)
    local level = Plain(UnitLevel, unit)
    if not T.Num(level) or level == 0 then return nil end
    local me = Plain(UnitLevel, "player")
    if not T.Num(me) then return nil end
    local mh, ph = Plain(UnitHealthMax, unit), Plain(UnitHealthMax, "player")
    local ratio = (T.Num(mh) and T.Num(ph) and ph > 0) and (mh / ph) or nil
    return ConInfo(level, Plain(UnitClassification, unit), me, ratio)
end

-- "+3 " style prefix for the name, coloured by con; "" when there is nothing to show.
local function LevelPrefix(con)
    local db = NP.db
    if not (db.showLevel and con) then return "" end
    local text
    if con.key == "SKULL" then
        text = "??"
    elseif db.levelStyle == "ABSOLUTE" then
        text = tostring(con.level)
    elseif con.diff ~= 0 then
        text = (con.diff > 0 and "+" or "") .. con.diff
    end
    if db.conMarker == "NONE" then
        -- No pips: keep elite / rare readable in the text instead.
        if con.class == "elite" or con.class == "rareelite" or con.class == "worldboss" then text = (text or "") .. "+" end
        if con.class == "rare" or con.class == "rareelite" then text = (text or "") .. " |cffc0c0ffR|r" end
    end
    if not text then return "" end
    return ("|cff%02x%02x%02x%s|r "):format(con.r * 255, con.g * 255, con.b * 255, text)
end

-- Strip, pips / skull and name offset for a con (nil hides them all).
local function ApplyCon(f, con)
    local db = NP.db
    local show = con and not f.nameOnly
    f.trivial = show and con.trivial and db.trivialFade or false
    f.conStrip:SetShown(show and db.conStrip or false)
    if show then f.conStrip:SetVertexColor(con.r, con.g, con.b, 1) end

    local count, color, skull = 0, nil, false
    if show and db.conMarker == "CHEVRONS" then
        count, color = con.marks, { con.r, con.g, con.b }
    elseif show and db.conMarker == "DANGER" then
        if con.danger >= 5 then skull = true
        else count, color = con.danger, CON_COLORS[CON_ORDER[con.danger + 1]] end
    end
    local size = f.pipSize
    for i, pip in ipairs(f.pips) do
        if i <= count then
            pip.fill:SetVertexColor(color[1], color[2], color[3], 1)
            pip:Show()
        else
            pip:Hide()
        end
    end
    f.skull:SetShown(skull)
    if not f.nameOnly then
        local offset = count > 0 and (count * (size + 2) + 2) or (skull and (size + 6) or 0)
        f.nameText:ClearAllPoints()
        f.nameText:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", offset, 3)
    end
end

local function UpdateName(f)
    local unit = f.unit
    local con = not f.nameOnly and f.hostile and UnitCon(unit) or nil
    ApplyCon(f, con)
    local prefix = f.nameOnly and "" or LevelPrefix(con)
    if not pcall(f.nameText.SetFormattedText, f.nameText, "%s%s", prefix, UnitName(unit)) then f.nameText:SetText("") end
end

local function UpdateRaidIcon(f)
    local idx = NP.db.raidIcon and Plain(GetRaidTargetIndex, f.unit)
    if idx then
        SetRaidTargetIconTexture(f.raidIcon, idx)
        f.raidIcon:Show()
    else
        f.raidIcon:Hide()
    end
end

local function UpdateQuest(f)
    local show = NP.db.questIcon and not f.nameOnly and C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest
        and Bool(C_QuestLog.UnitIsRelatedToActiveQuest, f.unit)
    f.questIcon:SetShown(show and true or false)
end

-- Target, focus and mouseover are found by plate identity, so no unit is compared.
local function UpdateHighlight(f)
    local db = NP.db
    local isTarget = NP.targetPlate == f.plate
    local isMouse = db.mouseoverGlow and NP.mousePlate == f.plate
    local scale = isTarget and db.targetScale or 1
    local alpha = (NP.hasTarget and not isTarget) and db.nonTargetAlpha or 1
    if f.trivial and not isTarget then
        scale, alpha = scale * 0.8, math.min(alpha, db.trivialAlpha)
    end
    f:SetScale(scale)
    f:SetAlpha(alpha)
    local a = T.accent
    if isTarget and db.targetGlow then
        f.bd:SetEdgeColor(a[1], a[2], a[3])
        f.bd.shadow:SetVertexColor(a[1], a[2], a[3], 0.55)
    else
        f.bd:SetEdgeColor(0, 0, 0)
        f.bd.shadow:SetVertexColor(0, 0, 0, 0.45)
    end
    f.hover:SetShown(isMouse and not isTarget)
end

----------------------------------------------------------------------------------------
-- Cast bar
----------------------------------------------------------------------------------------
-- Common dungeon casts worth stopping: heals, crowd control and big AoE. Added to the
-- watch list on request only; a pre-filled list would come back after every removal.
NP.commonCasts = { "Healing Wave", "Lesser Healing Wave", "Chain Heal", "Heal", "Greater Heal", "Flash Heal",
    "Holy Light", "Healing Touch", "Regrowth", "Fear", "Polymorph", "Hex", "Mind Control", "Sleep",
    "Chain Lightning", "Shadow Bolt Volley", "Frostbolt Volley", "Dominate Mind", "Banish" }

local lastAlertSound = 0
local function SetAlert(cb, on)
    cb.alert = on
    if on then
        local c = NP.db.colors.castAlert
        cb.glow.tex:SetVertexColor(c[1], c[2], c[3], 1)
        cb.glow:Show()
        cb.glow.anim:Play()
    else
        cb.glow.anim:Stop()
        cb.glow:Hide()
    end
end

-- Edge on interruptible casts. The flag may be secret, so it drives each edge's alpha.
local function SetKick(cb, notInterruptible)
    local show = NP.db.kickHighlight
    for _, t in ipairs({ cb.kick.top, cb.kick.bottom, cb.kick.left, cb.kick.right }) do
        if not show then
            t:SetAlpha(0)
        elseif issecret(notInterruptible) then
            if t.SetAlphaFromBoolean then pcall(t.SetAlphaFromBoolean, t, notInterruptible, 0, 1) else t:SetAlpha(0) end
        else
            t:SetAlpha(notInterruptible and 0 or 1)
        end
    end
end

local function CastStop(cb, failed)
    cb.casting, cb.dur, cb.endT = nil, nil, nil
    SetAlert(cb, false)
    if failed and cb:IsShown() then
        cb.bar:SetStatusBarColor(0.85, 0.2, 0.2)
        cb.text:SetText(failed)
        cb.shield:SetAlpha(0)
        cb.fadeAt = GetTime() + 0.4
    else
        cb.fadeAt = nil
        cb:Hide()
    end
end

local function CastStart(cb, unit, channel)
    local info = { pcall(channel and UnitChannelInfo or UnitCastingInfo, unit) }
    if not info[1] then CastStop(cb) return end
    local name, texture, startMS, endMS = info[2], info[4], info[5], info[6]
    -- UnitCastingInfo: ..., castID, notInterruptible, spellID; channels have no castID.
    local notInterruptible, spellID
    if channel then notInterruptible, spellID = info[8], info[9] else notInterruptible, spellID = info[9], info[10] end
    if not issecret(name) and name == nil then CastStop(cb) return end

    if not pcall(cb.text.SetText, cb.text, name) then cb.text:SetText("") end
    if not pcall(cb.icon.SetTexture, cb.icon, texture) then cb.icon:SetTexture(136243) end
    cb.fadeAt = nil
    cb.channel = channel
    local c = NP.db.colors.cast
    cb.bar:SetStatusBarColor(c[1], c[2], c[3])
    -- Uninterruptible casts get a grey cover; the flag may be secret, so it drives alpha.
    if issecret(notInterruptible) then
        if cb.shield.SetAlphaFromBoolean then pcall(cb.shield.SetAlphaFromBoolean, cb.shield, notInterruptible, 1, 0) end
    else
        cb.shield:SetAlpha(notInterruptible and 1 or 0)
    end
    SetKick(cb, notInterruptible)
    -- Watched spells are matched by ID or name, when the client lets addons read them.
    local db = NP.db
    local alert = db.castAlerts and T:ListHas("casts", (not issecret(name)) and name or nil,
        (not issecret(spellID)) and spellID or nil)
    if alert then
        local ac = db.colors.castAlert
        cb.bar:SetStatusBarColor(ac[1], ac[2], ac[3])
        if db.alertSound and GetTime() - lastAlertSound > 2 then
            lastAlertSound = GetTime()
            pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
        end
    end
    SetAlert(cb, alert and true or false)

    local durFn = channel and UnitChannelDuration or UnitCastingDuration
    local dur
    if durFn and cb.bar.SetTimerDuration and DIR then
        local ok, d = pcall(durFn, unit)
        if ok and d then dur = d end
    end
    if dur and pcall(cb.bar.SetTimerDuration, cb.bar, dur, INTERP, channel and DIR.RemainingTime or DIR.ElapsedTime) then
        cb.dur, cb.endT = dur, nil
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

local function RefreshCast(f)
    local cb = f.castbar
    if not NP.db.castbar or f.nameOnly then CastStop(cb) return end
    if not pcall(CastStart, cb, f.unit, false) or not cb.casting then
        pcall(CastStart, cb, f.unit, true)
    end
end

----------------------------------------------------------------------------------------
-- Auras: one aura container per group, drawn and updated by the client.
----------------------------------------------------------------------------------------
local auraRegions = setmetatable({}, { __mode = "k" })

local function StyleAura(group, button)
    local r = auraRegions[button]
    if not r then
        r = {}
        r.bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
        r.bg:SetTexture(S.WHITE)
        r.bg:SetVertexColor(0, 0, 0, 1)
        r.dispel = button:CreateTexture(nil, "BACKGROUND", nil, -6)
        r.icon = button:CreateTexture(nil, "ARTWORK")
        button:SetIcon(r.icon)
        r.cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        r.cd:SetReverse(true)
        r.cd:SetDrawEdge(false)
        if r.cd.SetDrawBling then r.cd:SetDrawBling(false) end
        if r.cd.SetHideCountdownNumbers then r.cd:SetHideCountdownNumbers(true) end
        r.cd.noCooldownCount = true
        r.over = CreateFrame("Frame", nil, button)
        r.over:SetAllPoints(button)
        r.timer = r.over:CreateFontString(nil, "OVERLAY")
        r.count = r.over:CreateFontString(nil, "OVERLAY")
        if C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
            local ok, b = pcall(C_DurationUtil.CreateDurationTextBinding)
            if ok and b then
                pcall(b.SetFontString, b, r.timer)
                r.binding = b
            end
        end
        auraRegions[button] = r
    end
    local size = group.size
    button:SetSize(size, size)
    if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
    r.bg:SetAllPoints(button)
    r.dispel:SetAllPoints(button)
    r.icon:ClearAllPoints()
    r.icon:SetPoint("TOPLEFT", 1, -1)
    r.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.cd:ClearAllPoints()
    r.cd:SetAllPoints(r.icon)
    r.cd:SetSwipeColor(0, 0, 0, 0.6)
    pcall(button.SetDurationCooldown, button, r.cd)
    r.over:SetFrameLevel(button:GetFrameLevel() + 5)
    S.ApplyFont(r.timer, math.max(8, math.floor(size * 0.42)))
    S.ApplyFont(r.count, math.max(7, math.floor(size * 0.36)))
    r.timer:ClearAllPoints()
    r.timer:SetPoint("CENTER", r.icon, "CENTER", 1, 0)
    r.count:ClearAllPoints()
    r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, 0)
    pcall(button.ClearDurationText, button)
    if r.binding then
        if T.nativeFormatter then pcall(r.binding.SetFormatter, r.binding, T.nativeFormatter) end
        if T.nativeColorCurve and Enum.DurationTextBindingProperty then
            pcall(r.binding.SetTextColorCurve, r.binding, T.nativeColorCurve, Enum.DurationTextBindingProperty.RemainingDuration)
        end
        pcall(button.SetDurationText, button, r.timer, { binding = r.binding })
    else
        pcall(button.SetDurationText, button, r.timer, { textFormatter = T.nativeFormatter })
    end
    pcall(button.SetApplicationCount, button, r.count, {})
    -- The client colours this texture by dispel type; it shows as a 1px border.
    pcall(button.ClearDispelTypeTextures, button)
    pcall(button.AddDispelTypeTexture, button, r.dispel,
        { showWhenHarmful = group.filter:find("HARMFUL") ~= nil, showWhenHelpful = group.filter:find("HELPFUL") ~= nil })
end

-- Group definitions from the settings: filter strings, the fallback when this client does
-- not know a filter token, size, count and where the row sits on the plate.
local function AuraGroups()
    local db = NP.db
    local groups = {}
    if db.debuffs ~= "NONE" then
        local base = db.debuffs == "MINE" and "HARMFUL|PLAYER" or "HARMFUL"
        groups.debuffs = { filter = db.cc and (base .. "|!CROWD_CONTROL") or base, fallback = base,
            size = db.debuffSize, max = db.debuffMax, corner = "BOTTOMLEFT", growX = "RIGHT" }
    end
    if db.buffs ~= "NONE" then
        groups.buffs = { filter = db.buffs == "PURGE" and "HELPFUL|RAID_PLAYER_DISPELLABLE" or "HELPFUL", fallback = "HELPFUL",
            size = db.buffSize, max = db.buffMax, corner = "LEFT", growX = "RIGHT" }
    end
    if db.cc then
        groups.cc = { filter = "HARMFUL|CROWD_CONTROL", size = db.ccSize, max = 1, corner = "RIGHT", growX = "LEFT" }
    end
    return groups
end

local function AnchorGroup(f, key, c)
    local db = NP.db
    c:ClearAllPoints()
    if key == "debuffs" then
        c:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, db.nameSize + 6)
    elseif key == "buffs" then
        c:SetPoint("LEFT", f.health, "RIGHT", 4, 0)
    else
        c:SetPoint("RIGHT", f.health, "LEFT", -4, 0)
    end
end

local function ConfigureAuras(f)
    local groups = NP.groups
    local FD = AnchorUtil.FlowDirection
    local SM = rawget(_G, "AuraContainerSortMethod") or { Default = 1 }
    local SD = rawget(_G, "AuraContainerSortDirection") or { Normal = 1 }
    for key, c in pairs(f.auras) do
        if not groups[key] then
            c:SetEnabled(false)
            c:Hide()
        end
    end
    for key, g in pairs(groups) do
        local c = f.auras[key]
        if not c then
            c = CreateFrame("AuraContainer", nil, f, "CustomAuraContainerTemplate")
            c.buttons = setmetatable({}, { __mode = "k" })
            f.auras[key] = c
        end
        c.group = g
        c:SetEnabled(false)
        c:SetSize(g.size, g.size)
        AnchorGroup(f, key, c)
        c:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
        c:SetFlowLayoutAnchorPoint(g.corner)
        c:SetFlowLayoutGrowthDirection(g.growX == "LEFT" and FD.Left or FD.Right, FD.Up)
        c:SetFlowLayoutMaximumLineSize(g.max * g.size + (g.max - 1) * 2)
        local options = {
            maxFrameCount = g.max, sortMethod = SM.Default, sortDirection = SD.Normal,
            -- Reads c.group at call time, so frames made after a settings change use it.
            initializeFrame = function(button)
                c.buttons[button] = true
                StyleAura(c.group, button)
            end,
            layout = { elementWidth = g.size, elementHeight = g.size, elementSpacing = 2, lineSpacing = 2 },
        }
        if c:HasAuraGroup("g") then
            if not pcall(c.SetAuraGroupFilterString, c, "g", g.filter) and g.fallback then
                pcall(c.SetAuraGroupFilterString, c, "g", g.fallback)
            end
            pcall(c.SetAuraGroupMaxFrameCount, c, "g", g.max)
            pcall(c.SetAuraGroupLayout, c, "g", options.layout)
        elseif not pcall(c.AddAuraGroup, c, "g", g.filter, options) and g.fallback then
            pcall(c.AddAuraGroup, c, "g", g.fallback, options)
        end
        -- Aura buttons become forbidden to query after creation, so each container keeps
        -- its own list instead of asking buttons for their parent.
        for button in pairs(c.buttons) do pcall(StyleAura, g, button) end
    end
    f.auraVersion = NP.version
end

local function AttachAuras(f)
    if not NP.aurasOK then return end
    if f.auraVersion ~= NP.version then
        local ok, err = pcall(ConfigureAuras, f)
        if not ok then T:ReportError("nameplate auras: " .. tostring(err)) return end
    end
    local show = f.hostile and not f.nameOnly
    for key, c in pairs(f.auras) do
        if show and NP.groups[key] then
            -- Same token again would add a second copy of every aura; the container
            -- follows its token by itself.
            if c.tempusUnit ~= f.unit and pcall(c.SetUnit, c, f.unit) then c.tempusUnit = f.unit end
            c:Show()
            c:SetEnabled(true)
        else
            c:SetEnabled(false)
            c:Hide()
        end
    end
end

local function DetachAuras(f)
    for _, c in pairs(f.auras) do
        c:SetEnabled(false)
        c:Hide()
    end
end

----------------------------------------------------------------------------------------
-- Plate construction and layout
----------------------------------------------------------------------------------------
-- preview: a settings-window sample, not tied to a Blizzard plate.
local function Build(plate, preview)
    local f = CreateFrame("Frame", nil, plate)
    f.plate = not preview and plate or nil
    f.auras = {}
    f:SetPoint("CENTER", plate, "CENTER")
    f:EnableMouse(false)

    f.health = S.StatusBar(f)
    f.health:SetPoint("CENTER", f, "CENTER")
    f.bd = S.Backdrop(f.health, { inner = false })
    f.executeTint = f.health:CreateTexture(nil, "ARTWORK", nil, 2)
    f.executeTint:SetTexture(S.WHITE)
    f.executeTint:SetAllPoints(f.health:GetStatusBarTexture())
    f.executeTint:Hide()
    f.hover = f.health:CreateTexture(nil, "OVERLAY")
    f.hover:SetTexture(S.WHITE)
    f.hover:SetAllPoints(f.health)
    f.hover:SetVertexColor(1, 1, 1, 0.14)
    f.hover:Hide()

    local over = CreateFrame("Frame", nil, f)
    over:SetAllPoints(f)
    over:SetFrameLevel(f.health:GetFrameLevel() + 4)
    f.nameText = over:CreateFontString(nil, "OVERLAY")
    f.nameText:SetWordWrap(false)
    f.healthText = over:CreateFontString(nil, "OVERLAY")
    f.healthText:SetJustifyH("RIGHT")
    f.raidIcon = over:CreateTexture(nil, "OVERLAY")
    f.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.raidIcon:Hide()
    f.questIcon = over:CreateTexture(nil, "OVERLAY")
    f.questIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    f.questIcon:Hide()
    f.conStrip = f.health:CreateTexture(nil, "ARTWORK", nil, 4)
    f.conStrip:SetTexture(S.WHITE)
    f.conStrip:Hide()
    -- Square pips with a black rim, before the name: elite / rare / boss or danger.
    f.pips = {}
    for i = 1, 5 do
        local pip = CreateFrame("Frame", nil, over)
        pip.rim = pip:CreateTexture(nil, "ARTWORK")
        pip.rim:SetTexture(S.WHITE)
        pip.rim:SetVertexColor(0, 0, 0, 1)
        pip.rim:SetAllPoints()
        pip.fill = pip:CreateTexture(nil, "OVERLAY")
        pip.fill:SetTexture(S.WHITE)
        pip.fill:SetPoint("TOPLEFT", 1, -1)
        pip.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        pip:Hide()
        f.pips[i] = pip
    end
    f.skull = over:CreateTexture(nil, "OVERLAY")
    f.skull:SetTexture(SKULL_TEX)
    f.skull:Hide()

    local cb = CreateFrame("Frame", nil, f)
    S.Backdrop(cb, { inner = false })
    cb.bar = S.StatusBar(cb)
    cb.bar:SetAllPoints(cb)
    cb.shield = cb.bar:CreateTexture(nil, "ARTWORK", nil, 3)
    cb.shield:SetTexture(S.WHITE)
    cb.shield:SetAllPoints(cb.bar)
    cb.shield:SetAlpha(0)
    cb.iconFrame = CreateFrame("Frame", nil, cb)
    S.Backdrop(cb.iconFrame, { inner = false, shadow = false })
    cb.icon = cb.iconFrame:CreateTexture(nil, "ARTWORK")
    cb.icon:SetAllPoints(cb.iconFrame)
    cb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local cover = CreateFrame("Frame", nil, cb)
    cover:SetAllPoints(cb)
    cover:SetFrameLevel(cb.bar:GetFrameLevel() + 3)
    cb.text = cover:CreateFontString(nil, "OVERLAY")
    cb.text:SetJustifyH("LEFT")
    cb.text:SetWordWrap(false)
    cb.time = cover:CreateFontString(nil, "OVERLAY")
    cb.time:SetJustifyH("RIGHT")
    cb.kick = S.CreateBorder(cover, "OVERLAY", 7)
    cb.kick:SetThickness(1, cb)
    cb.kick:SetColor(1, 1, 1, 1)
    for _, t in ipairs({ cb.kick.top, cb.kick.bottom, cb.kick.left, cb.kick.right }) do t:SetAlpha(0) end
    -- Pulsing glow behind watched casts.
    cb.glow = CreateFrame("Frame", nil, cb)
    cb.glow:SetPoint("TOPLEFT", cb.iconFrame, "TOPLEFT", -4, 4)
    cb.glow:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", 4, -4)
    cb.glow:SetFrameLevel(math.max(cb:GetFrameLevel() - 1, 0))
    cb.glow.tex = cb.glow:CreateTexture(nil, "BACKGROUND")
    cb.glow.tex:SetTexture(S.WHITE)
    cb.glow.tex:SetAllPoints()
    cb.glow.anim = cb.glow:CreateAnimationGroup()
    cb.glow.anim:SetLooping("BOUNCE")
    local pulse = cb.glow.anim:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0.25)
    pulse:SetToAlpha(0.85)
    pulse:SetDuration(0.35)
    cb.glow:Hide()
    cb:SetScript("OnUpdate", T:Wrap("nameplates.cast", CastOnUpdate))
    cb:Hide()
    f.castbar = cb

    -- The clickable area follows the Tempus plate rather than the hidden Blizzard frame.
    f.hit = CreateFrame("Frame", nil, f)
    f.hit:EnableMouse(false)

    f:Hide()
    if not preview then NP.plates[plate] = f end
    return f
end

function NP:Layout(f)
    local db = NP.db
    local w, h = db.width, db.height
    local tex = S.BarTexture(T.db.barTexture)
    f:SetSize(w, h)
    f.health:SetSize(w, h)
    f.health:SetStatusBarTexture(tex)
    f.health.bg:SetTexture(tex)
    f.executeTint:SetAllPoints(f.health:GetStatusBarTexture())
    S.ApplyFont(f.nameText, db.nameSize)
    S.ApplyFont(f.healthText, db.fontSize)

    f.nameText:ClearAllPoints()
    f.healthText:ClearAllPoints()
    if f.nameOnly then
        f.health:Hide()
        f.nameText:SetJustifyH("CENTER")
        f.nameText:SetPoint("CENTER", f, "CENTER", 0, 0)
        f.nameText:SetWidth(w + 40)
    else
        f.health:Show()
        f.nameText:SetJustifyH("LEFT")
        f.nameText:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, 3)
        f.nameText:SetWidth(w - 12)
        f.healthText:SetPoint("RIGHT", f.health, "RIGHT", -3, 0)
    end
    f.raidIcon:SetSize(h + 8, h + 8)
    f.raidIcon:ClearAllPoints()
    f.raidIcon:SetPoint("RIGHT", f.health, "LEFT", -4 - (db.cc and db.ccSize + 4 or 0), 0)
    f.questIcon:SetSize(h + 6, h + 6)
    f.questIcon:ClearAllPoints()
    f.questIcon:SetPoint("BOTTOMRIGHT", f.health, "TOPRIGHT", 2, 1)
    f.conStrip:ClearAllPoints()
    f.conStrip:SetPoint("TOPLEFT", f.health, "TOPLEFT")
    f.conStrip:SetPoint("BOTTOMLEFT", f.health, "BOTTOMLEFT")
    f.conStrip:SetWidth(math.max(2, math.floor(h / 4)))
    local size = math.max(5, math.floor(db.nameSize * 0.6))
    f.pipSize = size
    local lift = 3 + math.max(0, (db.nameSize - size) / 2)
    for i, pip in ipairs(f.pips) do
        pip:SetSize(size, size)
        pip:ClearAllPoints()
        pip:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", (i - 1) * (size + 2), lift)
    end
    f.skull:SetSize(size + 4, size + 4)
    f.skull:ClearAllPoints()
    f.skull:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, lift - 2)

    local cb, ch = f.castbar, db.castHeight
    cb:ClearAllPoints()
    cb:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", ch + 3, -3)
    cb:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -3)
    cb:SetHeight(ch)
    cb.bar:SetStatusBarTexture(tex)
    cb.bar.bg:SetTexture(tex)
    local lc = db.colors.castLocked
    cb.shield:SetVertexColor(lc[1], lc[2], lc[3], 1)
    cb.iconFrame:ClearAllPoints()
    cb.iconFrame:SetPoint("RIGHT", cb, "LEFT", -3, 0)
    cb.iconFrame:SetSize(ch, ch)
    local cfs = math.max(8, math.min(ch, db.fontSize))
    S.ApplyFont(cb.text, cfs)
    S.ApplyFont(cb.time, cfs)
    cb.time:ClearAllPoints()
    cb.time:SetPoint("RIGHT", cb, "RIGHT", -3, 0)
    cb.text:ClearAllPoints()
    cb.text:SetPoint("LEFT", cb, "LEFT", 3, 0)
    cb.text:SetPoint("RIGHT", cb.time, "LEFT", -3, 0)

    f.hit:ClearAllPoints()
    f.hit:SetPoint("TOPLEFT", f.health, "TOPLEFT", -6, db.nameSize + 6)
    f.hit:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", 6, -(ch + 6))
    f.layoutVersion = NP.version
end

----------------------------------------------------------------------------------------
-- Blizzard's plate: hidden while a Tempus plate is shown, and kept hidden when the
-- driver shows it again for a new unit.
----------------------------------------------------------------------------------------
local function HideBlizzardPlate(uf)
    if not NP.active or not uf or (uf.IsForbidden and uf:IsForbidden()) then return end
    if uf:IsProtected() then
        pcall(uf.ClearAllPoints, uf)
        pcall(uf.SetAlpha, uf, 0)
        return
    end
    uf:Hide()
    pcall(uf.UnregisterAllEvents, uf)
    if CompactUnitFrame_UnregisterEvents then pcall(CompactUnitFrame_UnregisterEvents, uf) end
    local hb = uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar
    if hb then pcall(hb.UnregisterAllEvents, hb) end
    if uf.castBar then pcall(uf.castBar.UnregisterAllEvents, uf.castBar) end
end

local function HookBlizzardPlate(plate)
    local uf = plate.UnitFrame
    if not uf or NP.hooked[uf] then return end
    NP.hooked[uf] = true
    hooksecurefunc(uf, "Show", HideBlizzardPlate)
    if uf.SetShown then
        hooksecurefunc(uf, "SetShown", function(self, shown) if shown then HideBlizzardPlate(self) end end)
    end
end

local function ApplyHitArea(plate, f)
    if plate.CanChangeHitTestPoints and plate.SetAllHitTestPoints then
        pcall(function()
            if plate:CanChangeHitTestPoints() then
                plate:ClearAllHitTestPoints()
                plate:SetAllHitTestPoints(f.hit)
            end
        end)
    end
end

----------------------------------------------------------------------------------------
-- Unit lifecycle
----------------------------------------------------------------------------------------
local function UpdateAll(f)
    UpdateName(f)
    UpdateHealth(f)
    UpdateColor(f)
    UpdateRaidIcon(f)
    UpdateQuest(f)
    UpdateHighlight(f)
    RefreshCast(f)
end

local function Attach(unit)
    local plate = PlateFor(unit)
    if not plate then return end               -- forbidden plate: Blizzard keeps it
    if Bool(UnitIsUnit, unit, "player") then return end     -- personal resource display
    local f = NP.plates[plate] or Build(plate)
    if f.unit and NP.byUnit[f.unit] == f then NP.byUnit[f.unit] = nil end
    f.unit = unit
    NP.byUnit[unit] = f
    f.hostile = IsHostile(unit)
    f.nameOnly = not f.hostile and NP.db.friendlyNameOnly
    NP:Layout(f)
    if C_NamePlateManager and C_NamePlateManager.SetNamePlateSimplified then
        pcall(C_NamePlateManager.SetNamePlateSimplified, unit, false)
    end
    HookBlizzardPlate(plate)
    HideBlizzardPlate(plate.UnitFrame)
    ApplyHitArea(plate, f)
    f:Show()
    UpdateAll(f)
    AttachAuras(f)
end

local function Detach(unit)
    local f = NP.byUnit[unit]
    if not f then return end
    NP.byUnit[unit] = nil
    f.unit = nil
    CastStop(f.castbar)
    DetachAuras(f)
    f:Hide()
end

local function RefreshTargets()
    NP.hasTarget = Bool(UnitExists, "target")
    NP.targetPlate = NP.hasTarget and PlateFor("target") or nil
    for _, f in pairs(NP.byUnit) do UpdateHighlight(f) end
end

----------------------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------------------
local CAST_START = { UNIT_SPELLCAST_START = false, UNIT_SPELLCAST_DELAYED = false,
    UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true }
local CAST_STOP = { UNIT_SPELLCAST_STOP = false, UNIT_SPELLCAST_CHANNEL_STOP = false,
    UNIT_SPELLCAST_FAILED = "Failed", UNIT_SPELLCAST_INTERRUPTED = "Interrupted" }
local CAST_FLAGS = { UNIT_SPELLCAST_INTERRUPTIBLE = true, UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true }

local function OnEvent(self, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Attach(unit)
        if NP.hasTarget and not NP.targetPlate then RefreshTargets() end
        return
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Detach(unit)
        return
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        RefreshTargets()
        return
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        NP.mousePlate = PlateFor("mouseover")
        for _, f in pairs(NP.byUnit) do UpdateHighlight(f) end
        return
    elseif event == "RAID_TARGET_UPDATE" then
        for _, f in pairs(NP.byUnit) do UpdateRaidIcon(f) end
        return
    elseif event == "QUEST_LOG_UPDATE" then
        for _, f in pairs(NP.byUnit) do UpdateQuest(f) end
        return
    elseif event == "PLAYER_LEVEL_UP" then
        -- Every con shifts when you level; UnitLevel may lag the event by a frame.
        C_Timer.After(0.2, function()
            for _, f in pairs(NP.byUnit) do UpdateName(f); UpdateHighlight(f) end
        end)
        return
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_ROLES_ASSIGNED" then
        for _, f in pairs(NP.byUnit) do UpdateColor(f) end
        return
    end

    local f = unit and NP.byUnit[unit]
    if not f then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        UpdateHealth(f)
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
        UpdateColor(f)
    elseif CAST_START[event] ~= nil then
        if NP.db.castbar and not f.nameOnly then pcall(CastStart, f.castbar, unit, CAST_START[event]) end
    elseif CAST_STOP[event] ~= nil then
        if f.castbar.casting then CastStop(f.castbar, CAST_STOP[event] or nil) end
    elseif CAST_FLAGS[event] then
        RefreshCast(f)
    elseif event == "UNIT_FACTION" or event == "UNIT_FLAGS" then
        -- Reaction can flip (e.g. a mob turning hostile), which changes the whole plate.
        if IsHostile(unit) ~= f.hostile then Attach(unit) else UpdateColor(f) end
    else
        UpdateName(f)
        UpdateColor(f)
        UpdateHighlight(f)
    end
end

local EVENTS = {
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
    "UPDATE_MOUSEOVER_UNIT", "RAID_TARGET_UPDATE", "QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "PLAYER_ROLES_ASSIGNED", "PLAYER_LEVEL_UP",
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_FLAGS",
    "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
}

-- UPDATE_MOUSEOVER_UNIT has no "left" counterpart; poll only while a plate is highlighted.
local function MouseoverPoll(self, elapsed)
    if not NP.mousePlate then return end
    self.t = (self.t or 0) + elapsed
    if self.t < 0.1 then return end
    self.t = 0
    if PlateFor("mouseover") ~= NP.mousePlate then
        NP.mousePlate = nil
        for _, f in pairs(NP.byUnit) do UpdateHighlight(f) end
    end
end

----------------------------------------------------------------------------------------
-- Settings preview: sample plates built with the real layout code and fed fixed values.
-- Auras are stand-in icons, since aura containers need a live unit.
----------------------------------------------------------------------------------------
local SAMPLE_ICONS = {
    debuffs = { "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Ability_Warrior_Sunder",
        "Interface\\Icons\\Spell_Nature_Slow", "Interface\\Icons\\Spell_Shadow_CurseOfSargeras" },
    buffs = { "Interface\\Icons\\Spell_Holy_PowerWordShield", "Interface\\Icons\\Spell_Nature_Rejuvenation" },
    cc = { "Interface\\Icons\\Spell_Nature_Polymorph" },
}

local function SampleIcon(parent)
    local b = CreateFrame("Frame", nil, parent)
    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetTexture(S.WHITE)
    b.border:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.timer = b:CreateFontString(nil, "OVERLAY")
    b.timer:SetPoint("CENTER", 1, 0)
    return b
end

-- Lays out stand-in icons for one aura group where the real container would sit.
local function SampleAuras(f, key, count, shown)
    f.sample = f.sample or {}
    local icons = f.sample[key] or {}
    f.sample[key] = icons
    local g = NP.groups[key]
    local n = (shown and g) and math.min(count, g.max) or 0
    for i = 1, math.max(n, #icons) do
        local b = icons[i]
        if i <= n then
            if not b then b = SampleIcon(f); icons[i] = b end
            b:SetSize(g.size, g.size)
            b:ClearAllPoints()
            local step = (i - 1) * (g.size + 2)
            if key == "debuffs" then
                b:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", step, NP.db.nameSize + 6)
            elseif key == "buffs" then
                b:SetPoint("LEFT", f.health, "RIGHT", 4 + step, 0)
            else
                b:SetPoint("RIGHT", f.health, "LEFT", -4 - step, 0)
            end
            local list = SAMPLE_ICONS[key]
            b.icon:SetTexture(list[(i - 1) % #list + 1])
            if key == "buffs" then
                b.border:SetVertexColor(0.2, 0.6, 1)        -- magic, as the client colours purgeable buffs
            elseif key == "cc" then
                b.border:SetVertexColor(0.8, 0.2, 0.9)
            else
                b.border:SetVertexColor(0, 0, 0)
            end
            S.ApplyFont(b.timer, math.max(8, math.floor(g.size * 0.42)))
            b.timer:SetText(key == "cc" and "6" or tostring(4 + i * 5))
            b:Show()
        elseif b then
            b:Hide()
        end
    end
end

-- Width and height a plate takes with its auras and cast bar, to scale it into its cell.
local function Footprint(f)
    local db, groups = NP.db, NP.groups
    local left = groups.cc and (groups.cc.size + 4) or 0
    local right = groups.buffs and (4 + groups.buffs.max * (groups.buffs.size + 2)) or 0
    local debuffW = groups.debuffs and groups.debuffs.max * (groups.debuffs.size + 2) or 0
    local w = left + math.max(db.width, debuffW) + right
    local top = db.nameSize + 6 + (groups.debuffs and groups.debuffs.size or 0)
    local h = top + db.height + 3 + db.castHeight
    return w, h, left, right, top
end

local function FillSample(f, kind)
    local db, c = NP.db, NP.db.colors
    f.nameOnly = kind == "friend"
    f.hostile = kind ~= "friend"
    NP:Layout(f)
    f:SetScale(1)
    f:SetAlpha(1)

    local pct = 65
    if kind == "other" then pct = db.execute > 0 and math.max(db.execute - 6, 4) or 40 end
    f.health:SetMinMaxValues(0, 100)
    f.health:SetValue(pct)
    local col = kind == "friend" and c.friendly or (kind == "other" and db.threat and c.threatWarn) or c.hostile
    f.health:SetStatusBarColor(col[1], col[2], col[3])
    f.health.bg:SetVertexColor(col[1] * 0.18, col[2] * 0.18, col[3] * 0.18, 0.9)
    local ex = db.colors.execute
    f.executeTint:SetVertexColor(ex[1], ex[2], ex[3], 1)
    f.executeTint:SetShown(kind == "other" and db.execute > 0)

    -- Target: an elite two levels up with triple your health; other: a normal mob four up.
    local me = UnitLevel("player") or 60
    local con
    if kind == "target" then con = ConInfo(me + 2, "elite", me, 3)
    elseif kind == "other" then con = ConInfo(me + 4, "normal", me, 1) end
    ApplyCon(f, con)
    f.trivial = false
    f.nameText:SetText((kind ~= "friend" and LevelPrefix(con) or "")
        .. (kind == "target" and "Defias Pillager" or kind == "other" and "Riverpaw Mystic" or "Friendly Player"))
    if kind == "friend" then
        local r, g, b = S.ClassColor(select(2, UnitClass("player")))
        f.nameText:SetTextColor(r, g, b)
    else
        f.nameText:SetTextColor(1, 1, 1)
    end
    local ht = db.healthText
    if ht == "NONE" or f.nameOnly then f.healthText:SetText("")
    elseif ht == "CURRENT" then f.healthText:SetText(pct == 65 and "2.1K" or "310")
    elseif ht == "BOTH" then f.healthText:SetFormattedText("%s - %d%%", pct == 65 and "2.1K" or "310", pct)
    else f.healthText:SetFormattedText("%d%%", pct) end

    local a = T.accent
    local isTarget = kind == "target"
    if isTarget and db.targetGlow then
        f.bd:SetEdgeColor(a[1], a[2], a[3])
        f.bd.shadow:SetVertexColor(a[1], a[2], a[3], 0.55)
    else
        f.bd:SetEdgeColor(0, 0, 0)
        f.bd.shadow:SetVertexColor(0, 0, 0, 0.45)
    end
    f.hover:Hide()
    if db.raidIcon and isTarget then
        SetRaidTargetIconTexture(f.raidIcon, 8)
        f.raidIcon:Show()
    else
        f.raidIcon:Hide()
    end
    f.questIcon:SetShown(db.questIcon and kind == "other")

    local cb = f.castbar
    cb.casting, cb.dur, cb.endT, cb.fadeAt = nil, nil, nil, nil
    if isTarget and db.castbar then
        cb.bar:SetMinMaxValues(0, 1)
        cb.bar:SetValue(0.6)
        -- A watched, interruptible cast: alert colour, glow and kick edge.
        local col = db.castAlerts and c.castAlert or c.cast
        cb.bar:SetStatusBarColor(col[1], col[2], col[3])
        cb.shield:SetAlpha(0)
        cb.icon:SetTexture("Interface\\Icons\\Spell_Shadow_Possession")
        cb.text:SetText("Fear")
        cb.time:SetText("1.2")
        SetKick(cb, false)
        SetAlert(cb, db.castAlerts)
        cb:Show()
    elseif kind == "other" and db.castbar then
        cb.bar:SetMinMaxValues(0, 1)
        cb.bar:SetValue(0.3)
        cb.shield:SetAlpha(1)
        SetKick(cb, true)
        SetAlert(cb, false)
        cb.icon:SetTexture("Interface\\Icons\\Spell_Nature_HealingTouch")
        cb.text:SetText("Healing Wave")
        cb.time:SetText("2.4")
        cb:Show()
    else
        cb:Hide()
    end

    local hostile = kind ~= "friend"
    SampleAuras(f, "debuffs", kind == "target" and 3 or 1, hostile)
    SampleAuras(f, "buffs", 1, hostile and kind == "target")
    SampleAuras(f, "cc", 1, hostile and kind == "other")
    f:Show()
end

-- A full-width settings widget: target on the left, a faded second enemy and a friendly
-- name on the right. Refresh() redraws it from the current settings.
function NP:CreatePreview(width, height)
    local box = CreateFrame("Frame")
    box:SetSize(width, height)
    S.Backdrop(box, { fill = { 0.03, 0.035, 0.045, 1 }, shadow = false })
    local cellW = (width - 30) / 2
    local cells = {}
    local function Cell(kind, x, y, h, label)
        local holder = CreateFrame("Frame", nil, box)
        holder:SetSize(cellW, h)
        holder:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
        holder:SetClipsChildren(true)
        local f = Build(holder, true)
        f:ClearAllPoints()
        local t = box:CreateFontString(nil, "OVERLAY")
        S.ApplyFont(t, 10)
        t:SetTextColor(0.55, 0.6, 0.68)
        t:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 2, 2)
        t:SetText(label)
        cells[#cells + 1] = { kind = kind, holder = holder, f = f, h = h }
    end
    Cell("target", 10, -8, height - 16, "Target")
    Cell("other", 20 + cellW, -8, (height - 16) * 0.62, "Other enemy (faded, in execute range)")
    Cell("friend", 20 + cellW, -8 - (height - 16) * 0.62, (height - 16) * 0.38, "Friendly")

    function box:Refresh()
        NP.db = T.db.nameplates
        NP.groups = AuraGroups()
        for _, cell in ipairs(cells) do
            local f = cell.f
            FillSample(f, cell.kind)
            -- Shrink to fit the cell; labels take the bottom 14px.
            local fw, fh, left, right, top = Footprint(f)
            local bottom = fh - top - NP.db.height
            if cell.kind == "friend" then fw, fh, left, right, top, bottom = NP.db.width, NP.db.nameSize + 4, 0, 0, 0, 0 end
            local s = math.min(1, (cellW - 8) / fw, (cell.h - 18) / fh)
            f:SetScale(s)
            f:ClearAllPoints()
            -- Centre the whole footprint (auras, name, cast bar), not just the health bar;
            -- offsets are in the plate's scaled units, and 7px leaves room for the label.
            f:SetPoint("CENTER", cell.holder, "CENTER", (left - right) / 2, (bottom - top) / 2 + 7 / s)
            if cell.kind == "other" and T.db.nameplates.nonTargetAlpha < 1 then
                f:SetAlpha(T.db.nameplates.nonTargetAlpha)
            end
        end
    end
    return box
end

----------------------------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------------------------
function NP:ApplyCVars()
    local db = NP.db
    if not db.manageCVars then return end
    T:RunOOC(function()
        pcall(SetCVar, "nameplateMotion", db.stacking and 1 or 0)
        pcall(SetCVar, "nameplateMaxDistance", db.maxDistance)
        -- Older clients size the stacking/click box from these rather than hit-test points.
        if C_NamePlate and C_NamePlate.SetNamePlateEnemySize then
            pcall(C_NamePlate.SetNamePlateEnemySize, db.width + 12, db.height + db.nameSize + db.castHeight + 12)
        end
    end, "npcvars")
end

function NP:Refresh()
    NP.version = NP.version + 1
    BuildExecuteCurve()
    NP.groups = AuraGroups()
    for unit in pairs(NP.byUnit) do Attach(unit) end
    NP:ApplyCVars()
end

local function ConflictingAddon()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    for _, name in ipairs(CONFLICTS) do
        if loaded and loaded(name) then return name end
    end
end

T:NewModule("nameplates", {
    label = "Nameplates",
    desc = "Tempus nameplates: threat and execute colours, cast bars, your debuffs, purgeable buffs and crowd control.",
    defaults = NP.defaults,
    OnEnable = function()
        NP.db = T.db.nameplates
        local other = ConflictingAddon()
        if other then
            T:Print("nameplates are off while |cffffd200%s|r is enabled. Disable it and /reload to use Tempus nameplates.", other)
            return
        end
        NP.active = true
        NP.hooked = setmetatable({}, { __mode = "k" })
        NP.aurasOK = T.Display and T.Display.NativeAvailable and T.Display:NativeAvailable() or false
        NP.groups = AuraGroups()
        BuildExecuteCurve()

        local ev = CreateFrame("Frame")
        for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
        for e in pairs(CAST_START) do pcall(ev.RegisterEvent, ev, e) end
        for e in pairs(CAST_STOP) do pcall(ev.RegisterEvent, ev, e) end
        for e in pairs(CAST_FLAGS) do pcall(ev.RegisterEvent, ev, e) end
        ev:SetScript("OnEvent", T:Wrap("nameplates.events", OnEvent))
        ev:SetScript("OnUpdate", MouseoverPoll)
        NP.eventFrame = ev

        -- After a /reload, plates already on screen get no NAME_PLATE_UNIT_ADDED.
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
                local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if unit then Attach(unit) end
            end
        end
        RefreshTargets()
        NP:ApplyCVars()
    end,
    OnSettings = function()
        NP.db = T.db.nameplates
        if NP.active then NP:Refresh() end
    end,
})
