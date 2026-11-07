-- Tempus UI: danger alert. A warning at the top of the screen when something risky shows up:
-- an elite, rare or skull-level mob, a mob several levels above you, or a hostile player
-- whose nameplate appears, and a second warning when more mobs are on you than you meant to
-- pull. Each mob warns once, then stays quiet for a while. Built for careful (hardcore) play.
local _, T = ...
local S = T.Style
local DG = { seen = {}, units = {} }
T.Danger = DG

DG.defaults = {
    enabled = true,
    elites = true,              -- elite, rare elite and world boss mobs
    rares = true,               -- rare mobs
    levelGap = 3,               -- warn for mobs this many levels above you (0 = off)
    players = true,             -- hostile players flagged for PvP
    pull = true,                -- warn when several mobs are on you
    pullCount = 3,              -- how many mobs on you count as too many
    sound = true,
    quietFor = 120,             -- seconds before the same mob can warn again
    point = { "TOP", "UIParent", "TOP", 0, -150 },
}

local SHOW_FOR, FADE = 3.5, 1   -- seconds an alert stays, then fades
local RED, ORANGE, PURPLE = { 1, 0.32, 0.28 }, { 1, 0.62, 0.25 }, { 0.78, 0.5, 1 }

-- Why a unit is dangerous, or nil. info: classification, level (-1 for ??), isPlayer,
-- hostile, dead, trivial. Returns a short label and a colour.
function DG.Reason(info, playerLevel, db)
    if not info or not info.hostile or info.dead then return nil end
    if info.isPlayer then
        if db.players then return "Hostile player", RED end
        return nil
    end
    if info.trivial then return nil end
    local c = info.classification
    if info.level == -1 or c == "worldboss" then return "Skull", PURPLE end
    if db.elites and (c == "elite" or c == "rareelite") then
        return c == "rareelite" and "Rare elite" or "Elite", ORANGE
    end
    local gap = T.Num(db.levelGap) and db.levelGap or 0
    if gap > 0 and T.Num(info.level) and T.Num(playerLevel) and info.level - playerLevel >= gap then
        return ("+%d levels"):format(info.level - playerLevel), RED
    end
    if db.rares and c == "rare" then return "Rare", PURPLE end
end

-- Should a pull warning go out? count of mobs on you now, the count at the last warning.
function DG.PullWarn(count, lastWarned, threshold)
    return T.Num(count) and count >= (threshold or 3) and count > (lastWarned or 0)
end

local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and not T.issecret(v) then return v end
end

local function Info(unit)
    local can = Safe(UnitCanAttack, "player", unit)
    return {
        hostile = can and true or false,
        dead = Safe(UnitIsDeadOrGhost, unit) and true or false,
        isPlayer = Safe(UnitIsPlayer, unit) and true or false,
        pvp = Safe(UnitIsPVP, unit),
        level = Safe(UnitLevel, unit),
        classification = Safe(UnitClassification, unit),
        trivial = Safe(UnitIsTrivial, unit) and true or false,
        name = Safe(UnitName, unit),
        guid = Safe(UnitGUID, unit),
    }
end

function DG:Show(text, color)
    local f = self.frame
    if not f then return end
    f.text:SetText(text)
    f.text:SetTextColor(color[1], color[2], color[3])
    f.shownAt = GetTime()
    f:SetAlpha(1)
    f:Show()
    if self.db.sound and PlaySound and SOUNDKIT then
        local kit = SOUNDKIT.RAID_WARNING or SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING
        if kit then pcall(PlaySound, kit) end
    end
end

function DG:Check(unit)
    if not (self.db and self.db.enabled) then return end
    local info = Info(unit)
    if info.isPlayer and not info.pvp then return end
    local label, color = DG.Reason(info, Safe(UnitLevel, "player"), self.db)
    if not label then return end
    local key = info.guid or info.name
    local now = GetTime()
    if key and self.seen[key] and now - self.seen[key] < (self.db.quietFor or 120) then return end
    if key then self.seen[key] = now end
    local level = info.level == -1 and "??" or tostring(info.level or "?")
    self:Show(("%s: %s (%s)"):format(label, info.name or "?", level), color)
end

-- Mobs that are on you: in combat and targeting you or tanked by you.
function DG:OnYou()
    local n = 0
    for unit in pairs(self.units) do
        if Safe(UnitCanAttack, "player", unit) and Safe(UnitAffectingCombat, unit) and not Safe(UnitIsPlayer, unit) then
            local status = Safe(UnitThreatSituation, "player", unit)
            local targeting = Safe(UnitIsUnit, unit .. "target", "player")
            if targeting or (T.Num(status) and status >= 2) then n = n + 1 end
        end
    end
    return n
end

local function OnUpdate(f)
    if f.shownAt then
        local age = GetTime() - f.shownAt
        if age > SHOW_FOR + FADE then f.shownAt = nil; f:Hide()
        elseif age > SHOW_FOR then f:SetAlpha(1 - (age - SHOW_FOR) / FADE) end
    end
end

local function PollPull()
    local self = DG
    if not (self.db and self.db.enabled and self.db.pull) then return end
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
    if not inCombat then self.pullWarned = 0 return end
    local n = self:OnYou()
    if DG.PullWarn(n, self.pullWarned, self.db.pullCount) then
        self.pullWarned = n
        self:Show(("%d mobs on you!"):format(n), RED)
    elseif n < (self.pullWarned or 0) then
        self.pullWarned = n    -- one died or ran: a new one joining warns again
    end
end

function DG:Test()
    self:Show("Elite: Defias Overseer (18)", ORANGE)
end

T:NewModule("danger", {
    label = "Danger alert",
    desc = "Warns when an elite, rare or much higher-level mob shows up, or when too many mobs are on you.",
    defaults = DG.defaults,
    OnEnable = function()
        DG.db = T.db.danger
        local f = CreateFrame("Frame", "TempusDangerAlert", UIParent)
        f:SetFrameStrata("HIGH")
        f:SetSize(420, 30)
        f.text = S.Text(f, 18, nil, "OUTLINE")
        f.text:SetPoint("CENTER")
    f.text:SetJustifyH("CENTER")
        f:Hide()
        f:SetScript("OnUpdate", T:Wrap("danger.fade", OnUpdate))
        DG.frame = f
        T.Movers.ApplyPoint(f, DG.db)
        T.Movers:Register(f, {
            label = "Danger alert", page = "danger",
            cfg = function() return DG.db end,
            corner = function() return DG.db.point[1] end,
            enabled = function() return DG.db.enabled end,
        })
        local ev = CreateFrame("Frame")
        for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_REGEN_ENABLED" }) do
            pcall(ev.RegisterEvent, ev, event)
        end
        ev:SetScript("OnEvent", T:Wrap("danger.events", function(_, event, unit)
            if event == "NAME_PLATE_UNIT_ADDED" then
                DG.units[unit] = true
                DG:Check(unit)
            elseif event == "NAME_PLATE_UNIT_REMOVED" then
                DG.units[unit] = nil
            else
                DG.pullWarned = 0
                -- Forget old sightings now and then so the table does not grow all session.
                local now = GetTime()
                for key, t in pairs(DG.seen) do
                    if now - t > (DG.db.quietFor or 120) then DG.seen[key] = nil end
                end
            end
        end))
        local poll = CreateFrame("Frame")
        local acc = 0
        poll:SetScript("OnUpdate", T:Wrap("danger.pull", function(_, elapsed)
            acc = acc + elapsed
            if acc < 0.4 then return end
            acc = 0
            PollPull()
        end))
    end,
    OnSettings = function()
        DG.db = T.db.danger
        if DG.frame then T.Movers.ApplyPoint(DG.frame, DG.db) end
    end,
})
