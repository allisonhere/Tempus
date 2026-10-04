-- Combat Pulse display: drives the real module against stub frames and checks what it shows
-- through a fight, a secret DPS reading, test mode and a disabled signal source.
-- Run: lua5.1 tests/combatpulse-display.lua
local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
local function stub()
    local o = { shown = true, calls = {} }
    return setmetatable(o, { __index = function(t, k)
        if k:match("^%u") then
            return function(self, ...)
                t.calls[k] = { ... }
                if k == "SetShown" then t.shown = (...) and true or false
                elseif k == "Show" then t.shown = true elseif k == "Hide" then t.shown = false
                elseif k == "IsShown" then return t.shown
                elseif k == "SetValue" then t.value = (...)
                elseif k == "SetAlpha" then t.alpha = (...)
                elseif k == "SetScript" then t[(...)] = select(2, ...)
                elseif k == "GetStringWidth" then return 40
                elseif k == "GetFrameLevel" then return 1
                elseif k == "SetFont" then return true
                elseif k:match("^Create") then return stub() end
                return t
            end
        end
    end })
end
CreateFrame = function() return stub() end
UIParent = stub()
GetTime = function() return 100 end
unpack = unpack or table.unpack
Enum = { DamageMeterType = { DamageDone = 0, Dps = 1 }, DamageMeterSessionType = { Current = 1 } }
C_Timer = { NewTicker = function(_, fn) return { Cancel = function() end, fn = fn } end, After = function() end }

local T = { issecret = function(v) return v == SECRET end, accent = { 0, 0.7, 1 }, defaults = {}, modules = {},
    perf = {}, Movers = { ApplyPoint = function() end, Register = function() end } }
function T.Num(v) return type(v) == "number" and v == v and v > -math.huge and v < math.huge end
function T:Wrap(_, fn) return fn end
function T:NewModule(key, def) self.modules[key] = def end
function T.CopyTable(t) return t end
function T:ListHas(list, name, spellID)
    local l = self.db.lists[list] or {}
    return (spellID and l[tostring(spellID)] ~= nil)
        or (type(name) == "string" and l[name:lower()] ~= nil)
end
T.db = { locked = true, lists = { casts = {}, castsDanger = {}, castsMust = {} }, nameplates = { execute = 20, threatRole = "AUTO", colors = {
    threatSafe = { 0.25, 0.6, 1 }, threatWarn = { 1, 0.6, 0.1 }, threatAggro = { 1, 0.1, 0.1 }, execute = { 1, 0.45, 0.9 } } } }
T.Style = { WHITE = "w", Backdrop = function(f) f.tempusBackdrop = stub() return f.tempusBackdrop end,
    StatusBar = function() local b = stub() b.bg = stub() return b end, ApplyFont = function() end,
    Pixel = function() return 1 end }
local function load(file) assert(loadfile(file))("Tempus", T) end
for _, f in ipairs({ "State", "Scale", "Source" }) do load("Modules/DPSTrack/" .. f .. ".lua") end
load("Modules/Nameplates/Nameplates.lua")
load("Modules/Swing/Swing.lua")
load("Modules/CombatPulse/State.lua")
load("Modules/CombatPulse/CombatPulse.lua")
local CP, NP = T.CombatPulse, T.Nameplates

-- A world with a hostile, casting, purgeable target and a damage meter.
local world = { combat = true, secret = false, cast = true, notInt = false }
UnitAffectingCombat = function(unit) return world.combat end
UnitExists = function() return true end
UnitCanAttack = function() return true end
UnitIsDead = function() return false end
UnitIsPlayer = function() return false end
UnitThreatSituation = function() return 2 end
UnitGroupRolesAssigned = function() return "DAMAGER" end
UnitGUID = function() return "me" end
UnitClass = function() return "Warrior", "WARRIOR" end
IsPlayerSpell = function() return true end
UnitCastingInfo = function()
    if world.cast then return "Heal", "", 1, 0, 1, false, "id", world.notInt, 5 end
end
UnitChannelInfo = function() end
C_UnitAuras = { GetUnitAuraInstanceIDs = function() return { 1 } end }
C_DamageMeter = { GetCombatSessionFromType = function()
    local aps = world.secret and SECRET or 500
    return { combatSources = { { amountPerSecond = aps, isLocalPlayer = true }, { amountPerSecond = world.secret and SECRET or 900 } } }
end }
C_Spell = { GetSpellTexture = function() return 1 end,
    GetSpellCooldown = function() return { startTime = 50, duration = 15 } end }

T.db.combatpulse = {}
for k, v in pairs(CP.defaults) do T.db.combatpulse[k] = v end
local db = T.db.combatpulse
T.modules.combatpulse.OnEnable()
local f = CP.frame
assert(f and f.shown, "built and shown in combat")
local function plan() return CP.plan end

-- Standard, in combat: DPS bar, kick on the interruptible cast, purge, threat.
CP:Apply()
assert(plan().dps and plan().kick and plan().purge and plan().threat and not plan().swing, "standard cues")
assert(CP.ticker, "the meter is polled while fighting")
CP:Poll()
assert(f.bars.live.value == 500 and f.bars.top.value == 900 and db.peak == 500, "readable DPS drawn and the peak saved")

-- Secret values are drawn, never compared.
world.secret = true
CP:Poll()
assert(CP.secret and f.bars.live.value == SECRET and db.peak == 500, "secret DPS goes straight into the bar")
world.secret = false

-- A plainly uninterruptible cast drops the kick cue.
world.notInt = true
CP:Apply()
assert(not plan().kick and not f.kick.shown, "uninterruptible: no kick cue")
-- A secret flag keeps the icon and lets the client decide its alpha.
world.notInt = SECRET
f.kick.SetAlphaFromBoolean = nil
CP:Apply()
assert(plan().kick and f.kick.shown, "secret flag: kick chip stays, alpha handed to the client")
world.notInt = false

-- Priority changes the kick treatment without a second cast database.
T.db.lists.castsMust["5"] = "5"
world.cast, world.notInt = true, false
CP:Apply()
assert(plan().priority == "MUST" and f.kick.shown, "must-interrupt priority reaches Combat Pulse")
T.db.lists.castsMust["5"] = nil

-- Minimal: no DPS, no strip until a cue needs you.
db.mode = "MINIMAL"
CP:Apply()
assert(not plan().dps and plan().kick and not CP.ticker, "minimal draws cues only and stops polling")
world.cast = false
CP:Apply()
assert(not plan().kick and not f.strip.shown, "minimal with nothing to say shows no strip")

-- Full keeps the persistent chips, and out of combat the frame hides.
db.mode = "FULL"
CP:Apply()
assert(plan().dps and plan().kick and plan().purge and plan().threat and plan().peakLabels, "full")
world.combat = false
CP:Apply()
assert(not f.shown and not CP.ticker, "hidden out of combat, polling stopped")
T.db.locked = false
CP:Apply()
assert(f.shown, "unlocked: shown for placing")
T.db.locked = true

-- Test mode shows every cue out of combat, then switches cleanly off.
db.mode, db.test = "STANDARD", true
CP:Refresh()
assert(f.shown and plan().dps and plan().swing and plan().kick and plan().purge and plan().threat and plan().execute,
    "test mode shows everything")
db.test = false
CP:Refresh()
assert(not f.shown and not CP.ticker, "test off: back to hidden out of combat")

-- Events: a target-health event only redraws the execute cue; a meter reset clears the peak.
world.combat = true
CP:Apply()
CP:OnEvent("UNIT_HEALTH")
CP:OnEvent("DAMAGE_METER_RESET")
assert(db.peak == 0 and CP.state.peak == 0, "meter reset clears the saved peak")

-- Missing APIs degrade: no meter, no unit APIs.
C_DamageMeter, UnitThreatSituation, UnitCastingInfo, C_UnitAuras, UnitHealthPercent = nil, nil, nil, nil, nil
db.mode = "FULL"
CP:Apply()
assert(not plan().dps, "no damage meter, no DPS bar")
print("combatpulse display ok")

-- Regression: with no learned range, a hidden reading must not be drawn against a huge default.
C_DamageMeter = { GetCombatSessionFromType = function()
    return { combatSources = { { amountPerSecond = SECRET, isLocalPlayer = true }, { amountPerSecond = SECRET } } }
end }
db.peak, db.rangeMax, db.mode = 0, nil, "STANDARD"
CP.rangeMax, CP.lastTop = nil, nil
world.combat = true
CP:Apply()
CP:Poll()
assert(f.bars.top.calls.SetMinMaxValues[2] == SECRET, "unknown range: scale against the group top")
db.rangeMax, CP.rangeMax = 8000, nil
CP:Poll()
assert(f.bars.top.calls.SetMinMaxValues[2] == 8000, "a saved range is reused before any reading")
print("combatpulse regression ok")

-- Regression: test-mode samples must not leave a huge saved range behind, and a stale one heals.
local saved = db.rangeMax
db.test = true
CP:Refresh()
CP:Poll()
assert(CP.lastTop == nil and db.rangeMax == saved, "test samples are never remembered")
db.test = false
CP:Refresh()
C_DamageMeter = { GetCombatSessionFromType = function()
    return { combatSources = { { amountPerSecond = 16, isLocalPlayer = true }, { amountPerSecond = 18 } } }
end }
db.rangeMax, CP.rangeMax = 2284067, 2284067
CP:Poll()
assert(db.rangeMax < 100, "a range far above the real DPS is relearned from a readable reading")
print("combatpulse stale-range ok")

-- Busy target events only redraw when what the strip shows changes.
C_DamageMeter = { GetCombatSessionFromType = function()
    return { combatSources = { { amountPerSecond = 500, isLocalPlayer = true }, { amountPerSecond = 900 } } }
end }
UnitCastingInfo = function() end
UnitThreatSituation = function() return 2 end
C_UnitAuras = { GetUnitAuraInstanceIDs = function() return { 1 } end }
UnitAffectingCombat = function() return true end
world.combat = true
CP:Apply()
local applies = 0
local realApply = CP.Apply
CP.Apply = function(self) applies = applies + 1 return realApply(self) end
CP:OnEvent("UNIT_AURA")
CP:OnEvent("UNIT_THREAT_LIST_UPDATE")
assert(applies == 0, "unchanged purge and threat do not redraw")
C_UnitAuras = { GetUnitAuraInstanceIDs = function() return {} end }
CP:OnEvent("UNIT_AURA")
assert(applies == 1 and not CP.ctx.purge, "a purge change redraws")
UnitThreatSituation = function() return 0 end
CP:OnEvent("UNIT_THREAT_LIST_UPDATE")
assert(applies == 2, "a threat change redraws")
CP.Apply = realApply
print("combatpulse busy-event ok")

-- A readable finished fight is saved, bounded, and can feed the previous-fight marker/summary.
CP.fightActive, CP.fightPeak = true, 650
db.history, db.historySize, db.showSummary = {}, 5, true
C_DamageMeter = { GetCombatSessionFromType = function()
    return { combatSources = { { amountPerSecond = 600, isLocalPlayer = true }, { amountPerSecond = 750 } } }
end }
CP:FinishFight()
assert(#db.history == 1 and db.history[1].dps == 600 and math.floor(db.history[1].pct + 0.5) == 80,
    "finished fight is stored with relative performance")
assert(f.summary.shown, "post-fight summary is shown")

