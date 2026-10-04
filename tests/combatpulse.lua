-- Combat Pulse: which signals show in each mode, the interrupt/threat/purge helpers it reuses
-- from the nameplates, and the swing status it reads from the swing timer.
-- Run: lua5.1 tests/combatpulse.lua
local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
local T = { Style = {}, issecret = function(v) return v == SECRET end, defaults = {} }
function T.Num(v) return type(v) == "number" and v == v and v > -math.huge and v < math.huge end
function T:NewModule(key, def) self.modules = self.modules or {}; self.modules[key] = def end
assert(loadfile("Modules/CombatPulse/State.lua"))("Tempus", T)
local Rules = T.CombatPulse.State

local function db(over)
    local d = { enabled = true, mode = "STANDARD", hideOOC = true,
        showDPS = true, showSwing = true, showKick = true, showPurge = true, showThreat = true, showExecute = true }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end
local function ctx(over)
    local c = { dpsReady = true, swingReady = true, swinging = false, kickKnown = true, cast = false,
        hostile = true, purge = false, threat = nil, executeOn = true }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

-- Modes.
assert(Rules.Mode("FULL") == "FULL" and Rules.Mode("bogus") == "STANDARD" and Rules.Mode(nil) == "STANDARD")

local p = Rules.Plan(db({ mode = "MINIMAL" }), ctx())
assert(not (p.dps or p.swing or p.kick or p.purge or p.threat or p.strip), "minimal is quiet with nothing happening")
assert(p.execute, "execute is always armed; its own alpha hides it")
p = Rules.Plan(db({ mode = "MINIMAL" }), ctx({ cast = true, purge = true, threat = "aggro" }))
assert(p.kick and p.purge and p.threat and not p.dps and not p.swing and not p.strip, "minimal shows only cues")
p = Rules.Plan(db({ mode = "MINIMAL" }), ctx({ threat = "safe" }))
assert(not p.threat, "holding threat is not urgent")

p = Rules.Plan(db(), ctx())
assert(p.dps and p.strip and not p.swing and not p.kick and not p.purge and not p.threat and not p.peakLabels,
    "standard: DPS bar, idle swing hidden, no cues")
p = Rules.Plan(db(), ctx({ swinging = true, cast = true, threat = "warn" }))
assert(p.swing and p.kick and p.threat, "standard: contextual signals appear")
p = Rules.Plan(db(), ctx({ threat = "lost" }))
assert(p.threat, "a tank that lost threat is urgent")

p = Rules.Plan(db({ mode = "FULL" }), ctx())
assert(p.dps and p.swing and p.kick and p.purge and p.threat and p.execute and p.peakLabels, "full shows everything")

-- Toggles and missing capabilities.
p = Rules.Plan(db({ mode = "FULL", showDPS = false, showSwing = false, showKick = false, showPurge = false,
    showThreat = false, showExecute = false }), ctx({ cast = true, purge = true, threat = "aggro" }))
assert(not (p.dps or p.swing or p.kick or p.purge or p.threat or p.execute or p.strip), "toggles switch signals off")
p = Rules.Plan(db({ mode = "FULL" }), ctx({ kickKnown = false, swingReady = false, dpsReady = false }))
assert(not (p.kick or p.swing or p.dps), "no interrupt, no swing module, no meter: those signals do not apply")
p = Rules.Plan(db({ mode = "FULL" }), ctx({ hostile = false, cast = true, purge = true, threat = "aggro" }))
assert(not (p.purge or p.threat or p.execute), "target cues need an attackable target")
p = Rules.Plan(db(), ctx({ executeOn = false }))
assert(not p.execute, "execute threshold 0 turns the cue off")

-- Out-of-combat visibility.
assert(not Rules.Visible(db({ enabled = false }), true, true), "disabled")
assert(Rules.Visible(db(), true, false) and not Rules.Visible(db(), false, false), "hide out of combat")
assert(Rules.Visible(db(), false, true), "unlocked shows it for placing")
assert(Rules.Visible(db({ test = true }), false, false), "test mode shows it")
assert(Rules.Visible(db({ hideOOC = false }), false, false), "hide out of combat off")

-- Interrupt readiness.
assert(Rules.KickReady(100, 15, 105) == false, "cooling down")
assert(Rules.KickReady(100, 15, 115) == true, "ready again")
assert(Rules.KickReady(0, 0, 105) == true, "no cooldown")
assert(Rules.KickReady(100, 1.5, 100.5) == true, "the global cooldown is not a cooldown")
assert(Rules.KickReady(SECRET, 15, 105) == nil and Rules.KickReady(nil, nil, 1) == nil, "unreadable stays unknown")

-- Nameplate helpers shared with the strip. Loading the plate file needs no frames.
local function load(file, t) assert(loadfile(file))("Tempus", t) end
local NT = { Style = {}, issecret = T.issecret, Num = T.Num, defaults = {}, db = { nameplates = { threatRole = "AUTO" } } }
function NT:NewModule() end
load("Modules/Nameplates/Nameplates.lua", NT)
local NP = NT.Nameplates
assert(NP.ThreatLevel(3, true) == "safe" and NP.ThreatLevel(2, true) == "warn" and NP.ThreatLevel(1, true) == "warn"
    and NP.ThreatLevel(0, true) == "lost", "tank: holding, slipping, lost")
assert(NP.ThreatLevel(3, false) == "aggro" and NP.ThreatLevel(2, false) == "aggro"
    and NP.ThreatLevel(1, false) == "warn" and NP.ThreatLevel(0, false) == nil, "damage dealer: pulling aggro")
assert(NP.ThreatLevel(nil, true) == nil and NP.ThreatLevel(SECRET, false) == nil, "unreadable status is no signal")

UnitGroupRolesAssigned = function() return "TANK" end
assert(NP.IsTankRole() == true, "assigned tank role works before the plates module is enabled")
NT.db.nameplates.threatRole = "DPS"
assert(NP.IsTankRole() == false, "manual role override wins")

C_UnitAuras = { GetUnitAuraInstanceIDs = function(unit, filter)
    assert(filter == "HELPFUL|RAID_PLAYER_DISPELLABLE")
    if unit == "boom" then error("api") end
    return unit == "has" and { 1, 2 } or {}
end }
assert(NP.HasPurgeable("has") == true and NP.HasPurgeable("none") == false, "purgeable buffs are counted")
assert(NP.HasPurgeable("boom") == false, "an API error means no purge cue")
C_UnitAuras = nil
assert(NP.HasPurgeable("has") == false, "no aura API means no purge cue")

C_CurveUtil = nil
assert(NP.MakeExecuteCurve(20, { 1, 0, 0 }) == nil, "no curve API: no curve")
assert(NP.MakeExecuteCurve(0, { 1, 0, 0 }) == nil, "threshold 0 turns it off")
local points = {}
C_CurveUtil = { CreateColorCurve = function()
    return { SetType = function() end, AddPoint = function(_, x, color) points[#points + 1] = { x, color.a } end } end }
Enum = { LuaCurveType = { Step = 1 } }
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
assert(NP.MakeExecuteCurve(20, { 1, 0, 0 }) and points[1][1] == 0 and points[1][2] == 1
    and points[2][1] == 0.2 and points[2][2] == 0, "alpha 1 below the threshold, 0 above")

-- Swing status for the strip.
local ST = { Style = {}, issecret = T.issecret, Num = T.Num, defaults = {} }
function ST:NewModule() end
load("Modules/Swing/Swing.lua", ST)
local SW = ST.Swing
assert(SW.Status() == nil, "no swing before the module runs")
SW.db = { enabled = true }
SW.rows = { main = { wanted = true }, off = { wanted = true, endT = 12, duration = 1.4, outOfRange = true },
    ranged = { wanted = true, endT = 13, duration = 2.9 } }
local st = SW.Status()
assert(st.endT == 12 and st.duration == 1.4 and st.outOfRange == true, "first running swing, main hand first")
SW.rows.main.endT, SW.rows.main.duration = 11, 2.6
assert(SW.Status().endT == 11 and SW.Status().outOfRange == false)
SW.rows.main.endT, SW.rows.off.endT, SW.rows.ranged.endT = nil, nil, nil
assert(SW.Status() == nil, "idle")
SW.rows.ranged.endT, SW.rows.ranged.wanted = 13, false
assert(SW.Status() == nil, "unwanted rows are ignored")
SW.db.enabled = false
SW.rows.ranged.wanted = true
assert(SW.Status() == nil, "disabled module")

-- The strip hears about swings through SW.listener.
local noop = setmetatable({}, { __index = function() return function() end end })
GetTime = function() return 100 end
local heard = 0
SW.listener = function() heard = heard + 1 end
SW.db.enabled = true
local row = setmetatable({ wanted = true, type = { id = 0, key = "main" }, bar = noop, spark = noop,
    label = noop, time = noop }, { __index = function(_, k) if k:match("^%u") then return function() end end end })
SW.rows = { main = row }
ST.accent = { 0, 0.7, 1 }
SW:Start(0, 2.6)
assert(heard == 1 and SW.rows.main.endT == 102.6, "starting a swing notifies the listener")
SW:SetRange(0, true)
SW:SetRange(0, true)
assert(heard == 2 and SW.Status().outOfRange == true, "only a range change notifies")
print("combatpulse ok")
