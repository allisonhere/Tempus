-- Tempus UI: settings pages for the nameplates module.
local _, T = ...
local UI = T.UI
local W, Changed = UI.W, UI.Changed

local function NPDB() return T.db.nameplates end
local function Colors() return T.db.nameplates.colors end

-- Sample plates at the top of every nameplate page, redrawn on each settings change.
local PREVIEW_H = 150
local function Preview(p)
    local box = T.Nameplates:CreatePreview(UI.COL_W * 2 + 22, PREVIEW_H)
    p:Add(box, PREVIEW_H, true)
    box:Refresh()
end

T:RegisterPage("nameplates", { key = "np_general", label = "General", order = 1, build = function(p)
    Preview(p)
    p:Section("Nameplates", "Replaces Blizzard's nameplates for enemies and friends. Plates the game locks to addons (e.g. friendly plates inside instances) stay Blizzard's. Turned off automatically while Plater or another nameplate addon is enabled.")
    p:Slider(NPDB, "width", "Width", 60, 260, 1)
    p:Slider(NPDB, "height", "Health bar height", 4, 30, 1)
    p:Slider(NPDB, "nameSize", "Name text size", 7, 18, 1)
    p:Slider(NPDB, "fontSize", "Health text size", 7, 18, 1)
    p:Dropdown(NPDB, "healthText", "Health text", {
        { "PERCENT", "Percent" }, { "CURRENT", "Value" }, { "BOTH", "Value + percent" }, { "NONE", "None" } })
    p:Check(NPDB, "friendlyNameOnly", "Friendly units: name only", "Friendly players and NPCs show just a coloured name.")
    p:Check(NPDB, "smooth", "Smooth health animation")
    p:Check(NPDB, "raidIcon", "Raid target marks")
    p:Check(NPDB, "questIcon", "Quest mob marker")

    p:Section("Level & con", "How tough an enemy is at a glance: grey (no XP), green, yellow (about your level), orange, red, and a purple skull for bosses and ?? levels.")
    p:Check(NPDB, "showLevel", "Show level")
    p:Dropdown(NPDB, "levelStyle", "Level as", { { "RELATIVE", "Difference (+3, -2)" }, { "ABSOLUTE", "Level (61)" } },
        "Difference hides the number for mobs your own level.")
    p:Check(NPDB, "conStrip", "Con-coloured strip on the bar")
    p:Dropdown(NPDB, "conMarker", "Markers before the name", {
        { "CHEVRONS", "Elite / rare / boss pips" }, { "DANGER", "Danger rating (1-5, skull)" }, { "NONE", "None" } },
        "Danger combines the con, elite status and the enemy's health against yours: a +2 elite with triple your health rates higher than a +2 normal mob.")
    p:Check(NPDB, "trivialFade", "Shrink and fade grey mobs", "Mobs that give no XP, so the ones worth fighting stand out. Your target is never faded.")
    p:Slider(NPDB, "trivialAlpha", "Grey mob opacity", 0.15, 1, 0.05, UI.pct)

    p:Section("Target")
    p:Slider(NPDB, "targetScale", "Target scale", 1, 1.6, 0.05, UI.pct)
    p:Slider(NPDB, "nonTargetAlpha", "Other plates' opacity", 0.2, 1, 0.05, UI.pct, "Applies while you have a target.")
    p:Check(NPDB, "targetGlow", "Glow around your target")
    p:Check(NPDB, "mouseoverGlow", "Highlight plate under the mouse")

    p:Section("Game settings", "Applied out of combat. These are the game's own nameplate options, so they also change what Blizzard's plates would do.")
    p:Check(NPDB, "manageCVars", "Let Tempus manage these")
    p:Check(NPDB, "stacking", "Stack plates instead of overlapping")
    p:Slider(NPDB, "maxDistance", "View distance (yards)", 20, 60, 1, nil, "The client may cap this lower.")
end })

T:RegisterPage("nameplates", { key = "np_combat", label = "Casts & Auras", order = 2, build = function(p)
    Preview(p)
    p:Section("Cast bar", "A grey cover means the cast can't be interrupted.")
    p:Check(NPDB, "castbar", "Show cast bars")
    p:Slider(NPDB, "castHeight", "Cast bar height", 6, 24, 1)
    p:Check(NPDB, "kickHighlight", "White edge on interruptible casts", "Works in combat too: the game drives it directly.")
    p:Check(NPDB, "kickIcon", "Show my interrupt", "Your interrupt, with its cooldown swipe, beside casts you can stop. Hidden for classes with no interrupt.")
    p:Check(NPDB, "interruptedBy", "Show who interrupted", "A stopped cast reads \"Interrupted: Name\" when the game tells addons who did it.")

    p:Section("Cast priorities", "Normal casts use the regular cast bar. Important, Dangerous and Must Interrupt share these lists with Combat Pulse. Spells are matched by name or spell ID; if the client hides both in combat, priority falls back to Normal.")
    p:Check(NPDB, "castAlerts", "Use cast priorities")
    p:Check(NPDB, "alertSound", "Sound for Dangerous / Must Interrupt", "At most once every two seconds.")
    p:Color(Colors, "castAlert", "Priority alert colour")
    p:Add(W.List("casts", "Important: spell name or ID"), 154, true)
    p:Add(W.List("castsDanger", "Dangerous: spell name or ID"), 154, true)
    p:Add(W.List("castsMust", "Must Interrupt: spell name or ID"), 154, true)
    p:Add(W.Button("Add common dungeon casts as Important", function()
        for _, name in ipairs(T.Nameplates.commonCasts) do T.db.lists.casts[name:lower()] = name end
        Changed()
    end, "Heals, fears, polymorphs and big AoE casts from common dungeon mobs."))

    p:Section("Auras", "Drawn by the game, so they keep updating in combat when auras are hidden from addons.")
    p:Dropdown(NPDB, "debuffs", "Debuffs on enemies", { { "MINE", "Only mine" }, { "ALL", "All" }, { "NONE", "None" } })
    p:Slider(NPDB, "debuffSize", "Debuff size", 12, 40, 1)
    p:Slider(NPDB, "debuffMax", "Max debuffs", 1, 12, 1)
    p:Dropdown(NPDB, "buffs", "Buffs on enemies", { { "PURGE", "Only purgeable" }, { "ALL", "All" }, { "NONE", "None" } })
    p:Slider(NPDB, "buffSize", "Buff size", 12, 40, 1)
    p:Slider(NPDB, "buffMax", "Max buffs", 1, 8, 1)
    p:Check(NPDB, "buffAlert", "Purple edge on enemies with a dispellable buff", "Shows when an enemy has a buff you can dispel or steal. Works in combat: only the count of such buffs is read.")
    p:Check(NPDB, "cc", "Crowd control as a large icon", "Stuns, fears, polymorphs and the like, shown left of the bar.")
    p:Slider(NPDB, "ccSize", "Crowd control size", 16, 48, 1)
end })

T:RegisterPage("nameplates", { key = "np_colors", label = "Colours & Threat", order = 3, build = function(p)
    Preview(p)
    p:Section("Health colours")
    p:Check(NPDB, "classColorEnemies", "Class colours for enemy players")
    p:Check(NPDB, "classColorFriends", "Class colours for friendly players")
    p:Color(Colors, "hostile", "Hostile")
    p:Color(Colors, "neutral", "Neutral")
    p:Color(Colors, "friendly", "Friendly")
    p:Color(Colors, "tapped", "Tapped by others")

    p:Section("Threat", "Colours enemy NPCs in combat by your threat. Tanks: blue = you hold it, orange = slipping, red = lost. Others: orange = close to pulling, red = it's on you.")
    p:Check(NPDB, "threat", "Threat colours")
    p:Dropdown(NPDB, "threatRole", "Role", { { "AUTO", "From group role" }, { "TANK", "Tank" }, { "DPS", "Damage / healer" } })
    p:Color(Colors, "threatSafe", "Tank: holding threat")
    p:Color(Colors, "threatWarn", "Threat warning")
    p:Color(Colors, "threatAggro", "Aggro lost / on you")

    p:Section("Execute range")
    p:Slider(NPDB, "execute", "Tint enemies below", 0, 50, 1, function(v) return v == 0 and "off" or (v .. "%") end)
    p:Color(Colors, "execute", "Execute colour")

    p:Section("Cast bar")
    p:Color(Colors, "cast", "Interruptible")
    p:Color(Colors, "castLocked", "Can't interrupt")
end })
