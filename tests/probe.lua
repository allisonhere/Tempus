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
print("probe ok")
