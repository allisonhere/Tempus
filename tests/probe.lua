-- API dump: names only, sorted, C_ namespaces and Enums split out. Run: lua5.1 tests/probe.lua
date = os.date
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
local T = {}
assert(loadfile("Core/Probe.lua"))("Tempus", T)

local env = {
    UnitHealth = function() end, AbbreviateNumbers = function() end, SomeFrame = {}, count = 3,
    C_Spell = { GetSpellInfo = function() end, Data = {}, IsSpellInRange = function() end },
    C_Locked = setmetatable({}, { __index = function() error("locked") end }),
    NotC = { Fn = function() end },
    Enum = { PowerType = { Mana = 0, Rage = 1 }, Bad = 5 },
}
local api = T.CollectAPI(env)
assert(table.concat(api.globals, ",") == "AbbreviateNumbers,UnitHealth", table.concat(api.globals, ","))
assert(table.concat(api.namespaces.C_Spell, ",") == "GetSpellInfo,IsSpellInRange")
assert(api.namespaces.C_Locked and #api.namespaces.C_Locked == 0)
assert(api.namespaces.NotC == nil and api.namespaces.Enum == nil)
assert(table.concat(api.enums.PowerType, ",") == "Mana,Rage")
assert(api.enums.Bad == nil)

TempusDB = {}
UnitAffectingCombat = function() return true end
T.DPSTrack = { Source = {
    Available = function() return false end,
    Read = function() return nil end,
} }
local dps = T:RunDPSProbe()
assert(not dps.available and dps.live == "nil" and dps.meterAvailable == "missing",
    "DPS probe identifies missing meter API")
T.DPSTrack.Source.Available = function() return true end
T.DPSTrack.Source.Read = function() return 400, 800, false end
dps = T:RunDPSProbe()
assert(dps.available and dps.live == 400 and dps.top == 800 and dps.combat == "true",
    "DPS probe records actual meter readings")
T.DPSTrack.Source.Read = function() error("meter refused") end
dps = T:RunDPSProbe()
assert(dps.live:find("meter refused", 1, true), "DPS probe preserves failed read reason")
assert(TempusDB.probe.dps == dps, "DPS probe is saved for inspection after reload")
T.DPSTrack.db = { scaleMode = "DYNAMIC", fixedMax = 1000000, test = false }
T.DPSTrack.frame = {
    IsShown = function() return true end,
    bars = { live = {
        GetValue = function() return 800 end,
        GetMinMaxValues = function() return 0, 800 end,
    } },
}
T.perf = { ["dpstrack.update"] = { calls = 20 } }
dps = T:RunDPSProbe()
assert(dps.scaleMode == "DYNAMIC" and dps.drawnLive == "800" and dps.drawnRange == "0, 800",
    "DPS probe exposes self-normalized full bar")
assert(dps.shown and dps.updateCalls == 20 and not dps.test,
    "DPS probe records visibility, update activity and test mode")
local meterEnums = { DamageMeterSessionType = { Current = 1, Overall = 0 },
    DamageMeterType = { Dps = 1, DamageDone = 0 } }
local census = T.CollectDPSMeter({ GetCombatSessionFromType = function(sessionType, meterType)
    if sessionType == 1 and meterType == 1 then return { combatSources = {}, maxAmount = 0 } end
    return { combatSources = { { amountPerSecond = 400, isLocalPlayer = true } }, maxAmount = 90000 }
end }, meterEnums)
assert(#census.sessions["Current.Dps"].combatSources == 0,
    "census preserves empty DPS session")
assert(census.sessions["Current.DamageDone"].combatSources[1].amountPerSecond == 400,
    "census captures source fields from damage session")
assert(census.enums.DamageMeterSessionType.Current == 1, "census captures actual enum values")
print("probe ok")
