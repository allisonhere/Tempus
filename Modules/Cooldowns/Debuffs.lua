-- Tempus UI: your debuffs on the target as a falling timeline. Each debuff you put on the target
-- falls down a scale toward the line where it runs out, over the same themed background the
-- cooldown timeline uses. In combat the client hides aura times from addons, so a debuff whose
-- time cannot be read is timed from your own cast, using the length it had the last time it
-- could be read.
local _, T = ...
local S = T.Style
local CD = T.Cooldowns
local DT = { icons = {}, timers = {}, learned = {} }
T.TargetDebuffs = DT

DT.defaults = {
    enabled = false,
    hideRow = true,             -- hide the target frame's own debuff icons while this is on
    mode = "timeline",
    size = 30, length = 260, range = 30,
    fall = "DOWN", labelSide = "LEFT", bgStyle = "GLASS",
    bgOpacity = 0.7, fadeBg = 0.8, fadeIcons = 0.3,
    showLabels = true, showTicks = true, accentRail = true,
    learned = {},               -- debuff name -> { dur, icon }, kept so a first cast in combat is timed
    point = { "CENTER", "UIParent", "CENTER", 470, -40 },
}

local function Plain(v) return v ~= nil and not (T.issecret and T.issecret(v)) end
local function PlainNum(v) return type(v) == "number" and Plain(v) end

local function TargetGUID()
    if not UnitGUID then return nil end
    local ok, g = pcall(UnitGUID, "target")
    if ok and type(g) == "string" and Plain(g) then return g end
end

-- Timers for `guid` that are still running, soonest first. Pure, for tests.
function DT.Live(timers, guid, now)
    local out = {}
    local mine = guid and timers[guid]
    if not mine then return out end
    for name, t in pairs(mine) do
        if t.exp > now then out[#out + 1] = { name = name, exp = t.exp, dur = t.dur, icon = t.icon }
        else mine[name] = nil end
    end
    table.sort(out, function(a, b) if a.exp ~= b.exp then return a.exp < b.exp end return a.name < b.name end)
    return out
end

function DT.Remember(timers, guid, name, exp, dur, icon)
    timers[guid] = timers[guid] or {}
    timers[guid][name] = { exp = exp, dur = dur, icon = icon }
end

-- Read the target's debuffs that are yours. Readable ones refresh the timers and teach the
-- lengths; the rest come from the cast timers.
function DT:Read(now)
    local guid = TargetGUID()
    if not guid then return {} end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "target", i, "HARMFUL|PLAYER")
            if not ok or type(a) ~= "table" then break end
            local name, dur, exp, icon = a.name, a.duration, a.expirationTime, a.icon
            if type(name) == "string" and Plain(name) and PlainNum(dur) and PlainNum(exp) and dur > 0 then
                if not Plain(icon) then icon = nil end
                DT.Remember(DT.timers, guid, name, exp, dur, icon)
                if icon then DT.db.learned[name] = { dur = dur, icon = icon } end
            end
        end
    end
    return DT.Live(DT.timers, guid, now)
end

-- Your cast landed: if it is a debuff we know the length of, start its timer on the target.
function DT:OnCast(spellID)
    local guid = TargetGUID()
    if not guid or not spellID then return end
    local name
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then name = info.name end
    end
    if type(name) ~= "string" or not Plain(name) then return end
    local known = DT.db.learned[name]
    if known and known.dur then
        DT.Remember(DT.timers, guid, name, GetTime() + known.dur, known.dur, known.icon)
    end
end

function DT:Refresh()
    local db, f = DT.db, DT.frame
    if not (db and f) then return end
    if not db.enabled then f:Hide(); return end
    local g = CD.Geometry(db)
    CD.LayoutTrack(f, db, g, CD.Marks(db.range))
    f:SetSize(g.w, g.h)
    DT:Update(true)
end

-- Re-read the target's debuffs now (events, a few times a second), then place the icons.
function DT:Update(reread)
    local db, f = DT.db, DT.frame
    if not (db and f and db.enabled) then return end
    local now = GetTime()
    local exists = UnitExists and UnitExists("target")
    f:SetShown(exists or not T.db.locked)
    if reread or not DT.list then DT.list = exists and DT:Read(now) or {} end
    local list = DT.list
    if list[1] and list[#list].exp <= now then list = DT.Live(DT.timers, TargetGUID(), now); DT.list = list end
    local g = CD.Geometry(db)
    local marks = CD.Marks(db.range)
    local order = {}
    for i, e in ipairs(list) do
        local b = DT.icons[i]
        if not b then b = CD.NewIcon(f); b.ready:Hide(); DT.icons[i] = b end
        b:SetSize(db.size, db.size)
        if b.key ~= e.name or b.exp ~= e.exp then
            b.key, b.exp = e.name, e.exp
            b.icon:SetTexture(e.icon or 134400)
            b.cd:SetCooldown(e.exp - e.dur, e.dur)
        end
        b.pos = CD.TimeFraction(e.exp - now, marks)
        b:Show()
        order[#order + 1] = b
    end
    for i = #list + 1, #DT.icons do DT.icons[i]:Hide(); DT.icons[i].key = nil end
    CD.PlaceIcons(f, db, g, order)
end

-- True when this timeline stands in for the target frame's own debuff icons.
function T.DebuffTimelineOn()
    local db = T.db and T.db.targetdebuffs
    return db and db.enabled and db.hideRow and T:ModuleEnabled("targetdebuffs") or false
end

local function RefreshTargetFrame()
    if T.UnitFrames and T.UnitFrames.Refresh and T.UnitFrames.frames and T.UnitFrames.frames.target then
        pcall(T.UnitFrames.Refresh, T.UnitFrames)
    end
end

function DT.Debug()
    local out = {}
    local db, f = DT.db, DT.frame
    if not (db and f) then return { "target debuffs: module is not running." } end
    local function Add(fmt, ...) out[#out + 1] = fmt:format(...) end
    local now = GetTime()
    Add("target debuffs: enabled=%s, frame %s, target guid=%s, hides frame row=%s",
        tostring(db.enabled), f:IsShown() and "shown" or "HIDDEN", tostring(TargetGUID() ~= nil), tostring(T.DebuffTimelineOn()))
    for _, e in ipairs(DT.Live(DT.timers, TargetGUID(), now)) do
        Add("  %s: %.1fs of %ds", e.name, e.exp - now, e.dur)
    end
    local n = 0
    for name, v in pairs(db.learned) do n = n + 1; Add("  learned %s: %ds", name, v.dur) end
    if n == 0 then Add("  nothing learned yet: apply each debuff once out of combat so its length can be read.") end
    return out
end

T:NewModule("targetdebuffs", {
    label = "Target debuff timeline",
    desc = "Your debuffs on the target falling down a timeline, instead of the target frame's icon row.",
    defaults = DT.defaults,
    OnEnable = function()
        DT.db = T.db.targetdebuffs
        local f = CreateFrame("Frame", "TempusTargetDebuffs", UIParent)
        f:SetFrameStrata("MEDIUM")
        DT.frame = f
        T.Movers.ApplyPoint(f, DT.db)
        T.Movers:Register(f, {
            label = "Target debuffs", page = "targetdebuffs",
            cfg = function() return DT.db end,
            corner = function() return DT.db.point[1] end,
            enabled = function() return DT.db.enabled end,
            onResize = function(w, h)
                local size, length = DT.db.size, DT.db.length
                CD.ResizeFromBox(DT.db, w, h)
                if size ~= DT.db.size or length ~= DT.db.length then DT:Refresh() end
            end,
            onMoved = function() if T.Options and T.Options.Refresh then T.Options:Refresh() end end,
        })
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("PLAYER_TARGET_CHANGED")
        ev:RegisterEvent("UNIT_AURA")
        ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        ev:SetScript("OnEvent", T:Wrap("targetdebuffs.events", function(_, event, unit, _, spellID)
            if event == "UNIT_SPELLCAST_SUCCEEDED" then DT:OnCast(spellID)
            elseif event == "UNIT_AURA" and unit ~= "target" then return end
            DT:Update(true)
        end))
        local acc, readAcc = 0, 0
        f:SetScript("OnUpdate", T:Wrap("targetdebuffs.fall", function(_, elapsed)
            acc, readAcc = acc + elapsed, readAcc + elapsed
            if acc < 0.03 then return end
            acc = 0
            local reread = readAcc >= 0.3
            if reread then readAcc = 0 end
            DT:Update(reread)
        end))
        DT:Refresh()
        RefreshTargetFrame()
    end,
    OnSettings = function()
        DT.db = T.db.targetdebuffs
        if DT.frame then
            T.Movers.ApplyPoint(DT.frame, DT.db)
            DT:Refresh()
        end
        RefreshTargetFrame()
    end,
})
