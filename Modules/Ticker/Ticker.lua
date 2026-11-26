-- Tempus UI: resource ticker. One thin bar showing when your next energy or mana tick lands.
-- Energy and mana come in on a fixed 2-second server clock; the bar learns its phase from
-- the ticks it sees (a gain the size a regular tick should be). For mana it also shows the
-- five-second rule: after you spend mana, spirit regen stops for 5 seconds, and the bar
-- counts that down in its own colour before going back to tick timing.
local _, T = ...
local S = T.Style
local TK = {}
T.Ticker = TK

TK.defaults = {
    enabled = true,
    energy = true,              -- energy ticks (rogues, druids in cat form)
    mana = true,                -- mana ticks and the five-second rule
    showFsr = true,             -- the 5-second countdown after spending mana
    showText = true,            -- current power on the bar
    afford = true,              -- the strip under the bar: can you afford your spells now / at the next tick
    smart = true,               -- with no list of your own: pick the builder and finisher for the situation
    affordHeight = 12,
    stripPos = {},              -- where you dragged the strip / the dots (empty = follow the bar)
    dotsPos = {},
    dotNumbers = true,          -- seconds left inside each timer dot
    dots = true,                -- bleed / buff timers at the right end of the bar
    dotSize = 18,               -- big enough for the draining border to read
    dotStyle = "BORDER",        -- how a dot counts down: BORDER (draining border) | FILL (falling fill)
    slotGauge = true,           -- the countdown border on the strip's finisher slot
    rogueGauge = "NONE",        -- what a rogue's finisher slot counts down: NONE | Rupture | Slice and Dice
    gaugeThickness = 2,
    gaugePulse = 3,             -- seconds left when a countdown starts pulsing (0 = never)
    width = 220, height = 8,
    visibility = "AUTO",        -- AUTO (in combat or not full) | COMBAT | ALWAYS
    point = { "CENTER", "UIParent", "CENTER", 0, -238 },
}

TK.PERIOD = 2               -- seconds between server regen ticks
TK.FSR = 5                  -- the five-second rule
local ENERGY_COLOR = { 1, 0.86, 0.45 }   -- warm gold
local MANA_COLOR = { 0.45, 0.68, 1 }     -- clear blue
local FSR_COLOR = { 0.72, 0.62, 0.95 }   -- soft violet: mana regen is paused
TK.ENERGY_COLOR, TK.MANA_COLOR, TK.FSR_COLOR = ENERGY_COLOR, MANA_COLOR, FSR_COLOR

local POWER_MANA, POWER_ENERGY = 0, 3
if Enum and Enum.PowerType then
    POWER_MANA = Enum.PowerType.Mana or POWER_MANA
    POWER_ENERGY = Enum.PowerType.Energy or POWER_ENERGY
end

-- Does a gain of delta look like a regular tick? expected is what a tick should give (nil
-- when the client cannot say). A tick that runs into the cap gives less, so at the cap any
-- gain up to the expected amount counts.
function TK.IsTick(delta, expected, atMax)
    if not (T.Num(delta) and delta > 0) then return false end
    if not (T.Num(expected) and expected > 0) then return true end
    local tol = math.max(2, expected * 0.15)
    if math.abs(delta - expected) <= tol then return true end
    return atMax and delta <= expected + tol or false
end

-- Where the next tick lands, from the last tick seen: seconds left and the fraction done.
function TK.Phase(lastTick, now, period)
    period = period or TK.PERIOD
    if not lastTick then return nil end
    local since = (now - lastTick) % period
    return period - since, since / period
end

-- What the bar shows right now: "FSR" (5-second rule counting down), "TICK" or nil.
function TK.Mode(kind, lastTick, fsrEnd, now, showFsr)
    if kind == "mana" and showFsr and fsrEnd and now < fsrEnd then return "FSR" end
    if lastTick then return "TICK" end
end

-- Afford strip ---------------------------------------------------------------------------
-- A strip under the bar with one segment per tracked spell (the "builders" you press on a tick:
-- Claw and Shred for a cat, Sinister Strike for a rogue, or your own list). Each segment is
--   NOW   solid emerald with white text: you can afford the spell right now (faint green with
--         grey text when you have the energy but something else blocks the cast),
--   TICK  amber, fading up as the tick approaches: the coming tick gets you there,
--   LATER dim: even the next tick will not be enough.
local AFFORD = { NOW = { 0.13, 0.87, 0.52 }, TICK = { 1, 0.8, 0.3 }, LATER = { 0.5, 0.52, 0.58 } }
-- Brightness of a segment you cannot press: far below 1, so a ready one stands out.
local BLOCKED_ALPHA, LATER_ALPHA = 0.28, 0.16
TK.AFFORD_COLORS = AFFORD
TK.DEFAULT_SPELLS = { DRUID = { "Claw", "Shred" }, ROGUE = { "Sinister Strike", "Backstab" } }
TK.MAX_SEGMENTS = 4

-- State and brightness of one segment. done is how far through the tick we are (0-1).
function TK.AffordState(power, cost, expected, done)
    if not (T.Num(power) and T.Num(cost)) or cost <= 0 then return nil end
    if power >= cost then return "NOW", 1 end
    if T.Num(expected) and power + expected >= cost then
        return "TICK", 0.35 + 0.65 * math.max(0, math.min(1, T.Num(done) and done or 0))
    end
    return "LATER", LATER_ALPHA
end

local function SpellID(entry)
    local id = tonumber(entry)
    if id then return id end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, entry)
        if ok and type(info) == "table" and T.Num(info.spellID) then return info.spellID end
    elseif GetSpellInfo then
        local ok, _, _, _, _, _, _, id2 = pcall(GetSpellInfo, entry)
        if ok and T.Num(id2) then return id2 end
    end
end

local function SpellKnown(id)
    local ok, known = pcall(IsPlayerSpell or IsSpellKnown, id)
    return ok and known == true
end

-- What a spell costs in the given power type (nil when it costs none or the client will not say).
function TK.SpellCost(id, ptype)
    local fn = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
    if type(fn) ~= "function" then return nil end
    local ok, costs = pcall(fn, id)
    if not ok or type(costs) ~= "table" then return nil end
    for _, c in ipairs(costs) do
        if type(c) == "table" and c.type == ptype and T.Num(c.cost) and c.cost > 0 then return c.cost end
    end
end

-- Can you cast it right now (enough energy, right form, not on cooldown)? The same answer the
-- action bar icons use, so it works even when the client hides your energy number. nil when the
-- client will not say.
function TK.IsUsable(id)
    local ok, usable, noPower
    if C_Spell and C_Spell.IsSpellUsable then ok, usable, noPower = pcall(C_Spell.IsSpellUsable, id)
    elseif IsUsableSpell then ok, usable, noPower = pcall(IsUsableSpell, id) end
    if not ok or usable == nil then return nil end
    if T.issecret and (T.issecret(usable) or T.issecret(noPower)) then return nil end
    -- Second answer: true when the only thing missing is power (so false = you have the energy
    -- but something else blocks it, such as Shred needing you behind the target).
    return usable == true, noPower == true
end

-- { name, cost, id } for each entry you know that costs the current power, in the order given;
-- at most MAX_SEGMENTS.
function TK.ResolveSpells(ptype, entries)
    local out = {}
    for _, entry in ipairs(entries) do
        local id = SpellID(entry)
        if id and SpellKnown(id) then
            local cost = TK.SpellCost(id, ptype)
            if cost then
                local name = tonumber(entry) and ((C_Spell and C_Spell.GetSpellInfo and (C_Spell.GetSpellInfo(id) or {}).name)
                    or (GetSpellInfo and GetSpellInfo(id))) or entry
                out[#out + 1] = { name = tostring(name), cost = cost, id = id }
                if #out >= TK.MAX_SEGMENTS then break end
            end
        end
    end
    return out
end

-- The spells to watch: your own list if you made one, else the class defaults.
function TK.TrackedSpells(ptype, listed, class)
    local entries = {}
    for _, v in pairs(listed or {}) do entries[#entries + 1] = v end
    table.sort(entries, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    if #entries == 0 then entries = TK.DEFAULT_SPELLS[class] or {} end
    return TK.ResolveSpells(ptype, entries)
end

-- Smart slots ----------------------------------------------------------------------------
-- With no list of your own, cats and rogues get a builder and a finisher picked for the moment.
TK.SMART = { DRUID = true, ROGUE = true }
TK.FRONT_HOLD = 4           -- seconds to trust the game's "you must be behind your target"

-- A unit answer that may be missing or hidden: true, false, or nil when the client will not say.
local function Answer(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or (T.issecret and T.issecret(v)) then return nil end
    return v and true or false
end

-- Can you attack from behind? Addons cannot see facing, so: a mob attacking you faces you,
-- a mob attacking someone else can be got behind. When the client will not say who it is
-- attacking, assume behind only in a group where you are not the tank.
function TK.CanBeBehind(now)
    if TK.frontUntil and now < TK.frontUntil then return false end
    if Answer(UnitExists, "target") == false then return false end
    local has = Answer(UnitExists, "targettarget")
    if has == false then return false end
    local onMe = has and Answer(UnitIsUnit, "targettarget", "player")
    if onMe ~= nil then return not onMe end
    if not Answer(IsInGroup) then return false end
    local ok, role = pcall(UnitGroupRolesAssigned or function() end, "player")
    return not (ok and role == "TANK")
end

-- The game's red "You must be behind your target": you are in front, whatever we guessed.
function TK:OnError(message, now)
    if type(message) ~= "string" or (T.issecret and T.issecret(message)) then return end
    if SPELL_FAILED_NOT_BEHIND and message == SPELL_FAILED_NOT_BEHIND then
        self.frontUntil = now + TK.FRONT_HOLD
    end
end

local function HasDagger()
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not (fn and GetInventoryItemID) then return false end
    local okI, item = pcall(GetInventoryItemID, "player", 16)
    if not okI or not item then return false end
    local ok, _, _, _, _, _, classID, subClassID = pcall(fn, item)
    return ok and classID == 2 and subClassID == 15
end

-- Seconds left and total duration of your bleed on the current target (or your buff), from the
-- aura or your cast.
function TK.RunningLeft(name, harmful, now)
    local left, total = TK.AuraLeft(harmful and "target" or "player", name, harmful, now)
    if left then
        -- A readable aura is the truth: keep the cast timer and learned length in step.
        TK.learned[name] = total
        TK.dotTimers[name] = { exp = now + left, dur = total, guid = harmful and TK.TargetGUID() or nil }
        return left, total
    end
    return TK.TimerLeft(name, harmful, now)
end

local function Usable(ptype, name) return TK.ResolveSpells(ptype, { name })[1] end

-- The builder and finisher for right now, skipping any you have not learned.
function TK.SmartSpells(ptype, class, now)
    local behind = TK.CanBeBehind(now)
    local builder, finisher
    if class == "DRUID" then
        builder = (behind and Usable(ptype, "Shred")) or Usable(ptype, "Claw")
        local rip = Usable(ptype, "Rip")
        -- Ferocious Bite takes the slot while your Rip is still ticking.
        local bite = (not rip or TK.RunningLeft("Rip", true, now)) and Usable(ptype, "Ferocious Bite")
        finisher = bite or rip
        -- The slot's border counts Rip down, whichever of the two is showing.
        if finisher then finisher.gauge = "Rip" end
    elseif class == "ROGUE" then
        builder = (behind and HasDagger() and Usable(ptype, "Backstab")) or Usable(ptype, "Sinister Strike")
        finisher = Usable(ptype, "Eviscerate")
        local track = TK.db and TK.db.rogueGauge
        if finisher and track and track ~= "NONE" then finisher.gauge = track end
    end
    local out = {}
    if builder then out[#out + 1] = builder end
    if finisher then
        if finisher.name == "Rip" then finisher.dot = true end
        out[#out + 1] = finisher
    end
    return out
end

-- Why the strip is or is not showing, one line each (for /tempus tickdebug).
function TK.Debug()
    local out = {}
    local function Add(fmt, ...) out[#out + 1] = fmt:format(...) end
    local db = TK.db
    local class = UnitClass and select(2, UnitClass("player")) or "?"
    Add("ticker: module %s, bar %s, kind=%s, power type=%s, power=%s/%s, tick seen=%s",
        db and "on" or "OFF", TK.frame and TK.frame:IsShown() and "shown" or "hidden", tostring(TK.kind), tostring(TK.ptype),
        tostring(TK.last), tostring(TK.max), TK.lastTick and "yes" or "NO (wait for one energy tick)")
    do
        local okP, cur = pcall(UnitPower, "player", TK.ptype or 3)
        local okM, max = pcall(UnitPowerMax, "player", TK.ptype or 3)
        local function Desc(ok, v)
            if not ok then return "error: " .. tostring(v) end
            return ("%s%s"):format(type(v), T.issecret and T.issecret(v) and " SECRET" or "")
        end
        Add("raw power read: UnitPower -> %s, UnitPowerMax -> %s, in combat=%s", Desc(okP, cur), Desc(okM, max),
            tostring(UnitAffectingCombat and UnitAffectingCombat("player")))
    end
    Add("afford strip: setting %s, class %s, segments %d, API: C_Spell.GetSpellPowerCost=%s GetSpellPowerCost=%s IsPlayerSpell=%s",
        db and db.afford and "on" or "OFF", tostring(class), TK.spells and #TK.spells or 0,
        tostring(C_Spell and type(C_Spell.GetSpellPowerCost)), tostring(type(GetSpellPowerCost)), tostring(type(IsPlayerSpell)))
    local entries = {}
    for _, v in pairs(T.db.lists and T.db.lists.tickspells or {}) do entries[#entries + 1] = v end
    if #entries == 0 then
        entries = TK.DEFAULT_SPELLS[class] or {}
        if db and db.smart and TK.SMART[class] then
            entries = {}
            for _, s in ipairs(TK.spells or {}) do entries[#entries + 1] = s.name end
            local function Read(fn, ...)
                local ok, v = pcall(fn or function() end, ...)
                if not ok then return "error" end
                return T.issecret and T.issecret(v) and "SECRET" or tostring(v)
            end
            Add("smart slots: behind guess=%s, target=%s, target's target=%s, is you=%s, front hold=%s",
                tostring(TK.CanBeBehind(GetTime())), Read(UnitExists, "target"), Read(UnitExists, "targettarget"),
                Read(UnitIsUnit, "targettarget", "player"), tostring(TK.frontUntil and GetTime() < TK.frontUntil or false))
        end
    end
    if #entries == 0 then Add("no spells to track for %s: add some on the Strip & countdowns page", tostring(class)) end
    for _, entry in ipairs(entries) do
        local id = SpellID(entry)
        local known = id and SpellKnown(id)
        local raw
        if id then
            local fn = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
            local ok, costs = pcall(fn or function() end, id)
            local parts = {}
            if ok and type(costs) == "table" then
                for _, c in ipairs(costs) do parts[#parts + 1] = ("type %s cost %s"):format(tostring(c.type), tostring(c.cost)) end
            end
            raw = ok and (#parts > 0 and table.concat(parts, "; ") or "no cost entries") or "call failed"
        end
        Add("  %s: spell id %s, known=%s, cost=%s, usable now=%s", tostring(entry), tostring(id), tostring(known), tostring(raw),
            tostring(id and select(1, TK.IsUsable(id))) .. " / only-power-missing " .. tostring(id and select(2, TK.IsUsable(id))))
    end
    Add("timer dots: setting %s, %d listed, target exists=%s", db and db.dots and "on" or "OFF",
        TK.dotList and #TK.dotList or 0, tostring(UnitExists and UnitExists("target")))
    for _, d in ipairs(TK.dotList or {}) do
        local ok, left, total = pcall(TK.AuraLeft, d.debuff and "target" or "player", d.name, d.debuff, GetTime())
        Add("  %s (%s): left=%s of %s", d.name, d.debuff and "on target" or "on you", ok and tostring(left) or "error " .. tostring(left), tostring(total))
    end
    for _, unit in ipairs({ "player", "target" }) do
        for i = 1, 40 do
            local ok, a
            if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, unit == "target" and "HARMFUL" or "HELPFUL")
                if not ok or type(a) ~= "table" then break end
                if i <= 12 then
                    Add("  %s aura %d: name=%s source=%s duration=%s expires=%s", unit, i, tostring(a.name), tostring(a.sourceUnit),
                        tostring(a.duration), tostring(a.expirationTime))
                end
            else
                break
            end
        end
    end
    return out
end

function TK:RebuildSpells()
    local class = UnitClass and select(2, UnitClass("player"))
    local dl = {}
    for _, d in ipairs(TK.DEFAULT_DOTS[class] or {}) do
        local id = SpellID(d.name)
        if (not id or SpellKnown(id)) and #dl < TK.MAX_DOTS then dl[#dl + 1] = d end
    end
    self.dotList = dl
    self:PickSpells(GetTime and GetTime() or 0)
end

-- The strip's spells: the smart slots when they apply, else your list or the class defaults.
function TK:PickSpells(now)
    local class = UnitClass and select(2, UnitClass("player"))
    local listed = T.db.lists and T.db.lists.tickspells
    self.smartOn = self.db and self.db.smart and TK.SMART[class] and not (listed and next(listed)) and true or false
    if not self.ptype then self.spells = {}
    elseif self.smartOn then self.spells = TK.SmartSpells(self.ptype, class, now)
    else self.spells = TK.TrackedSpells(self.ptype, listed, class) end
end

-- Regen per tick the client reports for the current power.
local function ExpectedTick(kind, inFsr)
    if kind == "energy" and GetPowerRegen then
        local ok, base = pcall(GetPowerRegen)
        if ok and T.Num(base) and base > 0 then return base * TK.PERIOD end
        return 20
    elseif kind == "mana" and GetManaRegen then
        local ok, base, casting = pcall(GetManaRegen)
        if ok then
            local r = inFsr and casting or base
            if T.Num(r) and r > 0 then return r * TK.PERIOD end
        end
    end
end

local function CurrentKind(db)
    if not UnitPowerType then return nil end
    local ok, ptype = pcall(UnitPowerType, "player")
    if not ok then return nil end
    if ptype == POWER_ENERGY and db.energy then return "energy", POWER_ENERGY end
    if ptype == POWER_MANA and db.mana then return "mana", POWER_MANA end
end

local function Power(ptype)
    local okA, cur = pcall(UnitPower, "player", ptype)
    local okB, max = pcall(UnitPowerMax, "player", ptype)
    if okA and okB and T.Num(cur) and T.Num(max) and not T.issecret(cur) then return cur, max end
end

-- Bar colour for what it shows: violet during the five-second rule, else by power type.
function TK.ColorFor(mode, kind)
    if mode == "FSR" then return FSR_COLOR end
    return kind == "energy" and ENERGY_COLOR or MANA_COLOR
end

-- A "view" is anything with bar, spark, text and label (the real ticker or a settings demo)
-- plus its state: kind, lastTick, fsrEnd, last (current power) and mode.
local function ColorView(v)
    local c = TK.ColorFor(v.mode, v.kind)
    v.bar:SetStatusBarColor(c[1], c[2], c[3])
    -- White with an outline, like the swing bars: readable over the fill and the empty part.
    v.text:SetTextColor(1, 1, 1)
    v.label:SetTextColor(1, 1, 1)
end

function TK:ColorBar() ColorView(self) end

local function Paint(v, db, now)
    local mode = TK.Mode(v.kind, v.lastTick, v.fsrEnd, now, db.showFsr)
    if mode ~= v.mode then
        v.mode = mode
        ColorView(v)
        v.label:SetText(mode == "FSR" and "5s" or "")
    end
    if mode == "FSR" then
        v.bar:SetValue((v.fsrEnd - now) / TK.FSR)
    elseif mode == "TICK" then
        local _, done = TK.Phase(v.lastTick, now)
        v.bar:SetValue(done)
    else
        v.bar:SetValue(0)
    end
    v.spark:SetShown(mode ~= nil)
    if db.showText and v.last then
        if mode == "FSR" then v.text:SetFormattedText("%.1f", v.fsrEnd - now)
        else v.text:SetText(v.last) end
    else
        v.text:SetText("")
    end
end

-- Bar, spark and texts on frame f, stored on view v.
local function BuildView(v, f)
    v.bar = S.StatusBar(f)
    v.bar:SetPoint("TOPLEFT", 1, -1)
    v.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    v.bar:SetMinMaxValues(0, 1)
    v.spark = v.bar:CreateTexture(nil, "OVERLAY")
    v.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    v.spark:SetBlendMode("ADD")
    v.spark:SetPoint("CENTER", v.bar:GetStatusBarTexture(), "RIGHT")
    local over = CreateFrame("Frame", nil, f)
    over:SetAllPoints(f)
    over:SetFrameLevel(v.bar:GetFrameLevel() + 2)
    v.text = over:CreateFontString(nil, "OVERLAY")
    v.text:SetPoint("RIGHT", -4, 0)
    S.ApplyFont(v.text, 9, nil, "OUTLINE")
    v.label = over:CreateFontString(nil, "OVERLAY")
    v.label:SetPoint("LEFT", 4, 0)
    S.ApplyFont(v.label, 9, nil, "OUTLINE")
end

local function BuildStrip(f)
    local strip = CreateFrame("Frame", nil, f)
    strip.segs = {}
    for i = 1, TK.MAX_SEGMENTS do
        local seg = CreateFrame("Frame", nil, strip)
        S.Backdrop(seg)
        seg.fill = seg:CreateTexture(nil, "ARTWORK")
        seg.fill:SetPoint("TOPLEFT", 1, -1)
        seg.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        seg.fill:SetTexture(S.BarTexture(T.db and T.db.barTexture))
        seg.text = seg:CreateFontString(nil, "OVERLAY")
        seg.text:SetPoint("CENTER")
        S.ApplyFont(seg.text, 9, nil, "OUTLINE")
        seg:Hide()
        strip.segs[i] = seg
    end
    return strip
end

-- Timer dots -------------------------------------------------------------------------------
-- A small square at the right end of the bar for each of your bleeds and buffs. Its border drains
-- as the time runs out and goes green -> yellow -> red; dim when it is not up.
TK.DEFAULT_DOTS = {
    DRUID = { { name = "Rake", debuff = true }, { name = "Rip", debuff = true }, { name = "Savage Roar" } },
    ROGUE = { { name = "Slice and Dice" }, { name = "Rupture", debuff = true } },
}
TK.MAX_DOTS = 4
-- In combat the client hides auras from addons (yours and your target's), so the dots also time
-- themselves from your own casts. Used when the real aura cannot be read; durations are the
-- usual ones, replaced by what the client reported the last time it let us read the aura.
TK.DOT_DURATION = { ["Rake"] = 9, ["Rip"] = 12, ["Savage Roar"] = 18, ["Slice and Dice"] = 21, ["Rupture"] = 16 }
TK.dotTimers = {}
TK.learned = {}

local function TargetGUID()
    if not UnitGUID then return nil end
    local ok, g = pcall(UnitGUID, "target")
    if ok and type(g) == "string" and not (T.issecret and T.issecret(g)) then return g end
end
TK.TargetGUID = TargetGUID

-- Your cast of a tracked spell succeeded: start its timer (on the target, for a debuff).
function TK:OnCast(name)
    for _, d in ipairs(self.dotList or {}) do
        if d.name == name then
            local dur = TK.learned[name] or TK.DOT_DURATION[name]
            if dur then
                self.dotTimers[name] = { exp = GetTime() + dur, dur = dur, guid = d.debuff and TargetGUID() or nil }
            end
        end
    end
end

-- Seconds left from the cast timer, if it still applies to the current target.
function TK.TimerLeft(name, harmful, now)
    local t = TK.dotTimers[name]
    if not t or t.exp <= now then return nil end
    if harmful and t.guid then
        local g = TargetGUID()
        if g and g ~= t.guid then return nil end
    end
    return t.exp - now, t.dur
end

-- Colour for the fraction of time left (1 = full).
function TK.DotColor(frac)
    frac = math.max(0, math.min(1, T.Num(frac) and frac or 0))
    if frac >= 0.5 then
        local t = (frac - 0.5) / 0.5            -- yellow -> green
        return 1 - 0.65 * t, 0.8 + 0.1 * t, 0.3 + 0.15 * t
    end
    local t = frac / 0.5                        -- red -> yellow
    return 0.95 + 0.05 * t, 0.25 + 0.55 * t, 0.25 + 0.05 * t
end

-- Seconds left and total duration of your own aura called name on unit, or nil when it is not up
-- (or the client hides it).
function TK.AuraLeft(unit, name, harmful, now)
    local filter = harmful and "HARMFUL|PLAYER" or "HELPFUL"
    for i = 1, 40 do
        local aname, dur, exp, src
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
            if not ok or type(a) ~= "table" then return nil end
            aname, dur, exp, src = a.name, a.duration, a.expirationTime, a.sourceUnit
        elseif UnitAura then
            local ok, n, _, _, _, d, e, s = pcall(UnitAura, unit, i, filter)
            if not ok or not n then return nil end
            aname, dur, exp, src = n, d, e, s
        else
            return nil
        end
        if aname == name and (harmful or src == nil or src == "player") then
            if T.Num(exp) and T.Num(dur) and dur > 0 and not (T.issecret and (T.issecret(exp) or T.issecret(dur))) then
                return math.max(0, exp - now), dur
            end
            return nil
        end
    end
end

-- Border gauge ------------------------------------------------------------------------------
-- A frame's border as a countdown: it unwinds clockwise from the top-left over a dim outline.
-- How much of each side (top, right, bottom, left) is still lit with frac of the time left, on a
-- w by h frame with edges t thick. The sides fit between the top and bottom edges.
function TK.GaugeLengths(frac, w, h, t)
    frac = math.max(0, math.min(1, T.Num(frac) and frac or 0))
    local side = math.max(0, h - 2 * t)
    local sides = { w, side, w, side }
    local gone = (1 - frac) * 2 * (w + side)
    local out = {}
    for i, len in ipairs(sides) do
        out[i] = math.max(0, math.min(len, len - gone))
        gone = math.max(0, gone - len)
    end
    return out
end

-- Brightness of the lit part: steady, then pulsing twice a second in the last pulse seconds.
function TK.GaugeAlpha(left, now, pulse)
    if left > (pulse or TK.defaults.gaugePulse) then return 1 end
    return 0.35 + 0.65 * math.abs(math.cos(now * math.pi * 2))
end

-- Each lit edge is anchored at its clockwise end, so it shrinks toward the next corner.
local function BuildGauge(f)
    local g = { track = {}, lit = {} }
    for i = 1, 4 do
        g.track[i] = f:CreateTexture(nil, "OVERLAY", nil, 1)
        g.lit[i] = f:CreateTexture(nil, "OVERLAY", nil, 2)
        g.track[i]:SetTexture(S.WHITE)
        g.lit[i]:SetTexture(S.WHITE)
        g.track[i]:Hide()
        g.lit[i]:Hide()
    end
    return g
end

local function HideGauge(g)
    if not g then return end
    for i = 1, 4 do g.track[i]:Hide() g.lit[i]:Hide() end
end

local function PaintGauge(g, f, w, h, left, total, now)
    -- Never thicker than half the frame, or the edges would cross.
    local t = math.max(1, math.min(TK.db.gaugeThickness, math.floor(math.min(w, h) / 2)))
    local frac = left / total
    local r, gr, b = TK.DotColor(frac)
    local alpha = TK.GaugeAlpha(left, now, TK.db.gaugePulse)
    local side = math.max(0, h - 2 * t)
    local lengths = TK.GaugeLengths(frac, w, h, t)
    local function Edge(tex, i, len)
        if len <= 0 then tex:Hide() return end
        tex:ClearAllPoints()
        if i == 1 then tex:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0) tex:SetSize(len, t)
        elseif i == 2 then tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, t) tex:SetSize(t, len)
        elseif i == 3 then tex:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0) tex:SetSize(len, t)
        else tex:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -t) tex:SetSize(t, len) end
        tex:Show()
    end
    for i = 1, 4 do
        g.track[i]:SetVertexColor(r, gr, b, 0.2)
        Edge(g.track[i], i, (i % 2 == 1) and w or side)
        g.lit[i]:SetVertexColor(r, gr, b, alpha)
        Edge(g.lit[i], i, lengths[i])
    end
end

-- A looping 12-second countdown for the settings preview and the unlocked frames.
local function SampleTime(now) return 12 - now % 12, 12 end

function TK:PaintDots(now)
    local dots = self.dots
    if not dots then return end
    local list = self.dotList
    if T.db and not T.db.locked and not (list and #list > 0) then
        list = { { name = "Rake", debuff = true }, { name = "Rip", debuff = true }, { name = "Savage Roar" } }
    end
    if not (self.db.dots and list and #list > 0 and (self.kind or (T.db and not T.db.locked))) then dots:Hide() return end
    local size = self.db.dotSize
    local n = math.min(#list, TK.MAX_DOTS)
    dots:SetSize(n * size + (n - 1) * 3, size)
    dots:Show()
    for i, d in ipairs(dots.items) do
        local sp = list[i]
        if not sp then
            d:Hide()
        else
            local left, total = TK.RunningLeft(sp.name, sp.debuff, now)
            if not left and i == 1 and (self.preview or (T.db and not T.db.locked)) then left, total = SampleTime(now) end
            d:SetSize(size, size)
            d:ClearAllPoints()
            d:SetPoint("TOPLEFT", dots, "TOPLEFT", (i - 1) * (size + 3), 0)
            local numbers = self.db.dotNumbers ~= false
            local border = self.db.dotStyle ~= "FILL"
            if left and border then
                PaintGauge(d.gauge, d, size, size, left, total, now)
                d.fill:Hide()
            else
                HideGauge(d.gauge)
                d.fill:ClearAllPoints()
                d.fill:SetPoint("BOTTOMLEFT", 1, 1)
                d.fill:SetPoint("BOTTOMRIGHT", -1, 1)
                if left then
                    local frac = left / total
                    local r, g, b = TK.DotColor(frac)
                    d.fill:SetVertexColor(r, g, b, TK.GaugeAlpha(left, now, self.db.gaugePulse))
                    d.fill:SetHeight(math.max(1, (size - 2) * frac))
                else
                    d.fill:SetVertexColor(0.5, 0.52, 0.58, 0.25)
                    d.fill:SetHeight(size - 2)
                end
                d.fill:Show()
            end
            if left and numbers then d.text:SetFormattedText("%d", math.ceil(left)) else d.text:SetText("") end
            d.label:SetText(sp.name:sub(1, 1))
            -- The letter stands in whenever there is no number to show.
            d.label:SetShown(not (left and numbers))
            d:Show()
        end
    end
end

local function BuildDots(f)
    local dots = CreateFrame("Frame", nil, f)
    dots.items = {}
    for i = 1, TK.MAX_DOTS do
        local d = CreateFrame("Frame", nil, dots)
        S.Backdrop(d)
        d.fill = d:CreateTexture(nil, "ARTWORK")
        d.fill:SetTexture(S.BarTexture(T.db and T.db.barTexture))
        d.gauge = BuildGauge(d)
        d.text = d:CreateFontString(nil, "OVERLAY")
        d.text:SetPoint("CENTER")
        S.ApplyFont(d.text, 9, nil, "OUTLINE")
        d.label = d:CreateFontString(nil, "OVERLAY")
        d.label:SetPoint("CENTER")
        S.ApplyFont(d.label, 9, nil, "OUTLINE")
        d:Hide()
        dots.items[i] = d
    end
    return dots
end

-- Lay the strip under the bar and paint it: one equal segment per spell.
-- Put the strip and the dots where the player dragged them, else beside the bar.
function TK:PlaceExtras()
    local db, frame = self.db, self.frame
    if not (db and frame) then return end
    local function Place(f, cfg, point, rel, relPoint, x, y)
        if not f then return end
        f:ClearAllPoints()
        if cfg and cfg.point then T.Movers.ApplyPoint(f, cfg) else f:SetPoint(point, rel, relPoint, x, y) end
    end
    Place(self.strip, db.stripPos, "TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    Place(self.dots, db.dotsPos, "LEFT", frame, "RIGHT", 3, 0)
end

function TK:PaintStrip(now)
    local strip, db = self.strip, self.db
    if not strip then return end
    local unlocked = T.db and not T.db.locked
    local sample = self.preview or unlocked
    local spells = sample and { { name = "Claw", cost = 45 }, { name = "Rip", cost = 30, gauge = "Rip" } } or self.spells
    if not (db.afford and spells and #spells > 0 and (self.kind or unlocked)) then
        strip:Hide()
        return
    end
    local width, gap = self.frame:GetWidth(), 2
    local h = db.affordHeight
    local n = #spells
    local w = (width - gap * (n - 1)) / n
    local _, done = TK.Phase(self.lastTick, now)
    local expected = ExpectedTick(self.kind, self.fsrEnd and now < self.fsrEnd)
    strip:SetSize(width, h)
    strip:Show()
    for i, seg in ipairs(strip.segs) do
        local sp = spells[i]
        if sp then
            -- The game's own "can I cast it" decides NOW; your energy number (when readable) adds
            -- the "next tick gets you there" step. Without a readable number it is lit or dim.
            local usable, noPower
            if sp.id then usable, noPower = TK.IsUsable(sp.id) end
            local state, alpha
            if usable == true then
                state, alpha = "NOW", 1
            elseif usable == false and noPower == false then
                -- Enough energy, but blocked by something else (position, target, form): light it
                -- softer so you still see the energy is there.
                state, alpha = "NOW", BLOCKED_ALPHA
            else
                state, alpha = TK.AffordState(self.last, sp.cost, expected, done)
                if usable == false and state == "NOW" then state, alpha = "LATER", LATER_ALPHA end
            end
            seg:SetSize(w, h)
            seg:ClearAllPoints()
            seg:SetPoint("TOPLEFT", strip, "TOPLEFT", (i - 1) * (w + gap), 0)
            local c = AFFORD[state or "LATER"]
            seg.fill:SetVertexColor(c[1], c[2], c[3], alpha or LATER_ALPHA)
            -- The label dims with its segment; amber stays white as the tick is about to land.
            local lit = state == "TICK" or (state == "NOW" and alpha == 1)
            local shade = lit and 1 or 0.55
            seg.text:SetTextColor(shade, shade, shade)
            seg.text:SetShown(h >= 9)
            local left, total
            if sp.gauge then
                if sample then left, total = SampleTime(now)
                else left, total = TK.RunningLeft(sp.gauge, sp.gauge ~= "Slice and Dice", now) end
            end
            if left and db.slotGauge then
                seg.gauge = seg.gauge or BuildGauge(seg)
                PaintGauge(seg.gauge, seg, w, h, left, total, now)
            else
                HideGauge(seg.gauge)
            end
            local running = sp.dot and left
            if running then seg.text:SetFormattedText("%s %ds", sp.name, math.ceil(running))
            else seg.text:SetText(sp.name .. " " .. sp.cost) end
            seg:Show()
        else
            seg:Hide()
        end
    end
end

-- Power changed: learn the tick phase and, for mana, start the five-second rule on a spend.
function TK:OnPower()
    if self.preview then return end
    local kind, ptype = CurrentKind(self.db)
    if kind ~= self.kind then
        self.kind, self.ptype, self.lastTick, self.fsrEnd, self.last = kind, ptype, nil, nil, nil
        self:Refresh()
    end
    if not kind then return end
    local cur, max = Power(ptype)
    if not cur then return end
    local now, prev = GetTime(), self.last
    self.last, self.max = cur, max
    if prev then
        local delta = cur - prev
        if delta < 0 and kind == "mana" then
            self.fsrEnd = now + TK.FSR
        elseif delta > 0 then
            local inFsr = self.fsrEnd and now < self.fsrEnd
            if TK.IsTick(delta, ExpectedTick(kind, inFsr), cur >= max) then self.lastTick = now end
        end
    end
    self:UpdateShown()
end

local function OnUpdate()
    local self = TK
    local now = GetTime()
    if self.preview then
        -- Fake ticks every 2s; every third cycle a mana bar pretends a spell was cast.
        if not self.lastTick or now - self.lastTick >= TK.PERIOD then
            self.lastTick = now
            self.previewN = (self.previewN or 0) + 1
            if self.kind == "mana" and self.previewN % 4 == 1 then self.fsrEnd = now + TK.FSR end
        end
        self.last, self.max = 60 + 10 * ((self.previewN or 0) % 4), 100
    end
    -- Self-heal: a form change can fire its event before the power type has switched, which
    -- would leave the bar on the old kind and the strip with no spells.
    if not self.preview and now - (self.healAt or 0) >= 0.5 then
        self.healAt = now
        local kind = CurrentKind(self.db)
        if kind ~= self.kind or (kind and #(self.spells or {}) == 0) then
            self:Refresh()
            self:OnPower()
        end
    end
    -- The smart slots follow your target, so look again several times a second.
    if self.smartOn and not self.preview and now - (self.pickAt or 0) >= 0.2 then
        self.pickAt = now
        self:PickSpells(now)
    end
    Paint(self, self.db, now)
    self:PaintStrip(now)
    if not self.dotAt or now - self.dotAt >= 0.1 then
        self.dotAt = now
        self:PaintDots(now)
    end
end

function TK:SetPreview(on)
    on = on and true or false
    if on and InCombatLockdown and InCombatLockdown() then return false end
    if self.preview == on then return on end
    self.preview = on
    self.lastTick, self.fsrEnd, self.last, self.previewN = nil, nil, nil, nil
    if on then
        self.kind = CurrentKind(self.db) or (self.db.mana and "mana") or "energy"
    else
        self.kind = nil
        self:OnPower()
    end
    self.mode = false
    self:Refresh()
    return on
end

function TK:UpdateShown()
    local f, db = self.frame, self.db
    if not (f and db) then return end
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
    local notFull = self.last and self.max and self.last < self.max
    local vis = db.visibility
    local show = db.enabled and self.kind and (self.preview or not T.db.locked or vis == "ALWAYS"
        or inCombat or (vis == "AUTO" and notFull))
    f:SetShown(show and true or false)
end

function TK:Refresh()
    local db, f = self.db, self.frame
    if not (db and f) then return end
    f:SetSize(db.width, db.height)
    local size = math.max(7, math.min(db.height - 1, 11))
    S.ApplyFont(self.text, size, nil, "OUTLINE")
    S.ApplyFont(self.label, size, nil, "OUTLINE")
    self.text:SetShown(db.showText and db.height >= 7)
    self.label:SetShown(db.height >= 7)
    self.spark:SetSize(8, db.height * 2)
    self.mode = false        -- repaint on the next frame
    if not self.preview then
        local kind, ptype = CurrentKind(db)
        if kind ~= self.kind then self.kind, self.ptype, self.lastTick, self.fsrEnd, self.last = kind, ptype, nil, nil, nil end
        if self.ptype then self.last, self.max = Power(self.ptype) end
    end
    self:RebuildSpells()
    self:PlaceExtras()
    self:UpdateShown()
end

-- Settings demo: an energy bar and a mana bar ticking on their own, painted by the same code
-- as the real ticker. Energy is spent now and then and ticks back up; the mana bar casts
-- every few ticks, which starts the violet five-second rule.
function TK.CreateDemo(width)
    local box = CreateFrame("Frame")
    local views = {}
    for i, kind in ipairs({ "energy", "mana" }) do
        local f = CreateFrame("Frame", nil, box)
        S.Backdrop(f)
        local v = { kind = kind, frame = f, n = 0, last = kind == "energy" and 100 or 70 }
        BuildView(v, f)
        views[i] = v
    end
    local height = 0
    function box:Refresh()
        local db = T.db.ticker
        local y = 0
        for _, v in ipairs(views) do
            local w = math.min(db.width, width)
            v.frame:SetSize(w, db.height)
            v.frame:ClearAllPoints()
            v.frame:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
            y = y + db.height + 4
            local size = math.max(7, math.min(db.height - 1, 11))
            S.ApplyFont(v.text, size, nil, "OUTLINE")
            S.ApplyFont(v.label, size, nil, "OUTLINE")
            v.text:SetShown(db.showText and db.height >= 7)
            v.label:SetShown(db.height >= 7)
            v.spark:SetSize(8, db.height * 2)
            v.mode = false
        end
        height = y
        box:SetSize(width, math.max(y, 1))
    end
    box:Refresh()
    T.UI.Loop(box, 0.03, function(_, now)
        local db = T.db.ticker
        for _, v in ipairs(views) do
            if not v.lastTick or now - v.lastTick >= TK.PERIOD then
                v.lastTick = now
                v.n = v.n + 1
                if v.kind == "energy" then
                    -- Spend 40 every third tick, otherwise gain 20 up to the cap.
                    if v.n % 3 == 0 then v.last = math.max(0, v.last - 40) else v.last = math.min(100, v.last + 20) end
                else
                    if v.n % 4 == 1 then v.fsrEnd = now + TK.FSR; v.last = math.max(10, v.last - 25)
                    elseif not (v.fsrEnd and now < v.fsrEnd) then v.last = math.min(100, v.last + 6) end
                end
            end
            Paint(v, db, now)
        end
    end)
    return box
end

T:NewModule("ticker", {
    label = "Resource ticker",
    desc = "A thin bar timing your next energy or mana tick, with the five-second rule for casters.",
    defaults = TK.defaults,
    OnEnable = function()
        TK.db = T.db.ticker
        local f = CreateFrame("Frame", "TempusResourceTicker", UIParent)
        f:SetFrameStrata("MEDIUM")
        S.Backdrop(f)
        TK.frame = f
        BuildView(TK, f)
        TK.strip = BuildStrip(f)
        TK.dots = BuildDots(f)
        local function Extra(frame, label, key)
            T.Movers:Register(frame, {
                label = label, page = "tickerstrip",
                cfg = function() return TK.db[key] end,
                corner = function() return "TOPLEFT" end,
                enabled = function() return TK.db.enabled and TK.db[key == "stripPos" and "afford" or "dots"] end,
                onMoved = function() TK:PlaceExtras() end,
            })
        end
        Extra(TK.strip, "Afford strip", "stripPos")
        Extra(TK.dots, "Timer dots", "dotsPos")
        f:SetScript("OnUpdate", T:Wrap("ticker.update", OnUpdate))
        T.Movers.ApplyPoint(f, TK.db)
        T.Movers:Register(f, {
            label = "Resource ticker", page = "ticker",
            cfg = function() return TK.db end,
            corner = function() return TK.db.point[1] end,
            enabled = function() return TK.db.enabled end,
        })
        local ev = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_DISABLED",
            "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE" }) do
            pcall(ev.RegisterEvent, ev, event)
        end
        for _, event in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
            pcall(ev.RegisterUnitEvent, ev, event, "player")
        end
        pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
        pcall(ev.RegisterEvent, ev, "UI_ERROR_MESSAGE")
        ev:SetScript("OnEvent", T:Wrap("ticker.events", function(_, event, _, message, spellID)
            if event == "UI_ERROR_MESSAGE" then
                TK:OnError(message, GetTime())
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                local name
                if C_Spell and C_Spell.GetSpellName then
                    local ok, n = pcall(C_Spell.GetSpellName, spellID)
                    if ok then name = n end
                elseif GetSpellInfo then
                    local ok, n = pcall(GetSpellInfo, spellID)
                    if ok then name = n end
                end
                if type(name) == "string" and not (T.issecret and T.issecret(name)) then TK:OnCast(name) end
            elseif event == "PLAYER_REGEN_DISABLED" then
                if TK.preview then TK:SetPreview(false) end
                TK:UpdateShown()
            elseif event == "PLAYER_REGEN_ENABLED" then
                TK:UpdateShown()
            elseif event == "UNIT_POWER_FREQUENT" then
                TK:OnPower()
            elseif event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
                TK:RebuildSpells()
            else
                TK:Refresh()
                TK:OnPower()
                -- The power type and spell book can lag the form event; look again shortly.
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.3, function() TK:Refresh() TK:OnPower() end)
                end
            end
        end))
        TK:Refresh()
    end,
    OnSettings = function()
        TK.db = T.db.ticker
        if TK.frame then
            T.Movers.ApplyPoint(TK.frame, TK.db)
            TK:Refresh()
        end
    end,
})
