-- Plugins: registered addons can be switched off, hiding their pages, without a reload.
function GetAddOnMetadata() return "2.5.0" end
function GetTime() return 100 end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
function InCombatLockdown() return false end
function date() return "12:00:00" end
SlashCmdList = {}
TempusDB = { profiles = { Default = {} }, chars = {} }
function CreateFrame()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript() end
    return frame
end

local T = {}
assert(loadfile("Core/Core.lua"))("Tempus", T)

-- before the database exists everything counts as enabled
assert(T:PluginEnabled("catchy") == true)
assert(T:PluginEnabled(nil) == true, "pages without a plugin are always shown")

T.db = {}
local def = T:RegisterPlugin("catchy", { label = "Catchy" })
assert(def.key == "catchy" and T.pluginOrder[1] == "catchy")
assert(T:RegisterPlugin("catchy") == def, "registering twice keeps one entry")
assert(#T.pluginOrder == 1)
assert(T:PluginEnabled("catchy") == true, "plugins are on by default")

T:SetPluginEnabled("catchy", false)
assert(T:PluginEnabled("catchy") == false and T.db.plugins.catchy == false)
T:SetPluginEnabled("catchy", true)
assert(T:PluginEnabled("catchy") == true)
print("plugins ok")
