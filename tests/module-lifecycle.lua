-- Module startup failures disable only the failed module and reach diagnostics.
function GetAddOnMetadata() return "2.5.0" end
function GetTime() return 100 end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
function InCombatLockdown() return false end
function date() return "12:00:00" end
SlashCmdList = {}
TempusDB = { profiles = { Default = {} }, chars = {} }

local frames = {}
function CreateFrame()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript(event, callback) self[event] = callback end
    frames[#frames + 1] = frame
    return frame
end

local T = {}
assert(loadfile("Core/Core.lua"))("Tempus", T)
T.Options = { InitBlizzardPanel = function() end, Refresh = function() end }
T.InitMinimapButton = function() end

local settings = {}
T:NewModule("healthy", {
    OnEnable = function() end,
    OnSettings = function() settings[#settings + 1] = "healthy" end,
})
T:NewModule("broken", {
    OnEnable = function() error("startup failure") end,
    OnSettings = function() settings[#settings + 1] = "broken" end,
})

local loader = assert(frames[2], "core event frame")
loader.OnEvent(loader, "ADDON_LOADED", "Tempus")
assert(TempusDB.schemaVersion == 1 and TempusDB.profiles.Default.modules.bags == false,
    "existing profiles keep the new Bags module disabled during migration")
assert(type(TempusDB.bagOwners) == "table", "bag ownership decisions have character-local storage")
loader.OnEvent(loader, "PLAYER_LOGIN")
assert(T.modules.healthy.enabled, "healthy module remains enabled")
assert(not T.modules.broken.enabled, "failed module is disabled")
assert(TempusDB.debug.lastError.err:find("broken: ", 1, true), "startup failure reaches diagnostics")

T:ApplySettings()
assert(table.concat(settings, ",") == "healthy", "settings skip a module that failed to start")
print("PASS: module startup isolates failures and settings skip failed modules")
