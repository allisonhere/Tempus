-- Tempus UI: settings pages for the party and raid frames module.
local _, T = ...
local UI = T.UI
local W, Changed = UI.W, UI.Changed

local function GFDB() return T.db.groupframes end

local PREVIEW_H = 170
local function Preview(p, kind)
    local box = T.GroupFrames:CreatePreview(kind, UI.COL_W * 2 + 22, PREVIEW_H)
    p:Add(box, PREVIEW_H, true)
    box:Refresh()
end

-- Puts sample party and raid frames on screen at their real positions (session only).
local function SampleToggle(p)
    -- W.Button returns the widget and its height; Page:Add needs both.
    local b, h = W.Button("Show sample frames on screen", function()
        local GF = T.GroupFrames
        GF.showSamples = not GF.showSamples
        GF:UpdateTestFrames()
        T:Print(GF.showSamples and "sample party and raid frames shown. Click the button again to hide them."
            or "sample frames hidden.")
    end, "Shows sample party and raid frames where the real ones will be, at your sizes. Click again to hide.", 230)
    p:Add(b, h)
end

T:RegisterPage("groupframes", { key = "gf_general", label = "General", order = 1, build = function(p)
    Preview(p, "party")
    SampleToggle(p)
    p:Newline()
    p:Section("Party & raid frames", "Shared look for both. Health, range and incoming heals are hidden from addons on this client, so they're drawn by the game straight into the bars. Unlock (top right) to move the frames; sample party and raid frames fill the boxes so you can arrange them without a group. Works with click-cast addons such as Clique.")
    p:Dropdown(GFDB, "healthColor", "Health colour", {
        { "CLASS", "Class" }, { "DARK", "Dark bars, class-coloured names" }, { "GRADIENT", "By health (green > red)" } })
    p:Dropdown(GFDB, "healthText", "Health text", { { "NONE", "None" }, { "PERCENT", "Percent" } })
    p:Slider(GFDB, "fontSize", "Text size", 8, 16, 1)
    p:Slider(GFDB, "rangeAlpha", "Out-of-range opacity", 0.1, 1, 0.05, UI.pct)
    p:Slider(GFDB, "powerHeight", "Power bar height", 0, 10, 1, function(v) return v == 0 and "hidden" or tostring(v) end)
    p:Check(GFDB, "manaOnly", "Power bar for mana users only", "Healers and casters; hides rage and energy bars.")
    p:Check(GFDB, "smooth", "Smooth health animation")
    p:Check(GFDB, "hideBlizzard", "Hide Blizzard party and raid frames", "Turning this off takes effect after /reload.")

    p:Section("Healing")
    p:Check(GFDB, "healPrediction", "Show incoming heals")
    p:Check(GFDB, "absorbs", "Show absorb shields")
    p:Check(GFDB, "dispel", "Debuffs you can dispel", "One large icon in the middle, bordered in the debuff type's colour.")
    p:Check(GFDB, "dispelTint", "Tint the frame in the dispel colour")
    p:Check(GFDB, "debuffs", "Other important debuffs", "Bottom left; the ones the game flags for group frames.")
    p:Slider(GFDB, "debuffSize", "Debuff size", 10, 30, 1)
    p:Slider(GFDB, "debuffMax", "Max debuffs", 1, 6, 1)
    p:Check(GFDB, "buffs", "Your buffs and HoTs", "Top right, with timers.")
    p:Slider(GFDB, "buffSize", "Buff size", 8, 24, 1)
    p:Slider(GFDB, "buffMax", "Max buffs", 1, 6, 1)

    p:Section("Indicators")
    p:Check(GFDB, "aggro", "Aggro border", "Orange when close to pulling threat, red when a mob is on them.")
    p:Check(GFDB, "targetHighlight", "White border on your target")
    p:Check(GFDB, "roleIcon", "Role icons")
    p:Check(GFDB, "leaderIcon", "Leader and assistant icons")
    p:Check(GFDB, "raidIcon", "Raid target marks")
    p:Check(GFDB, "readyCheck", "Ready check")
end })

local function SizePage(kind, label, order)
    T:RegisterPage("groupframes", { key = "gf_" .. kind, label = label, order = order, build = function(p)
        local cfg = function() return T.db.groupframes[kind] end
        Preview(p, kind)
        p:Section(label, kind == "party" and "Shown in a 5-player group; hidden in a raid."
            or "Shown in a raid. Groups are columns (or rows) of five.")
        p:Check(cfg, "enabled", "Enabled")
        p:Slider(cfg, "width", "Width", 40, 240, 1)
        p:Slider(cfg, "height", "Height", 20, 90, 1)
        p:Slider(cfg, "spacing", "Spacing", 0, 20, 1)
        if kind == "party" then
            p:Dropdown(cfg, "growth", "Direction", { { "DOWN", "Downwards" }, { "RIGHT", "Sideways" } })
            p:Check(cfg, "showPlayer", "Include yourself")
            p:Check(cfg, "showSolo", "Show when not in a group", "Your own frame while solo: handy for testing auras, HoTs and dispels on yourself.")
        else
            p:Dropdown(cfg, "growth", "Layout", { { "COLUMNS", "Groups as columns" }, { "ROWS", "Groups as rows" } })
            p:Dropdown(cfg, "groupBy", "Arrange by", { { "GROUP", "Raid group" }, { "ROLE", "Role" }, { "CLASS", "Class" } })
            p:Dropdown(cfg, "sampleSize", "Sample raid size", { { 10, "10 players" }, { 20, "20 players" }, { 40, "40 players" } },
                "How many sample frames show on screen, to see how a full raid fits.")
        end
        p:Section("Position")
        SampleToggle(p)
        p:Add(W.Button("Reset position", function()
            T.db.groupframes[kind].point = T.CopyTable(T.GroupFrames.defaults[kind].point)
            Changed()
        end))
    end })
end

SizePage("party", "Party", 2)
SizePage("raid", "Raid", 3)

-- Click-casting: one dropdown per mouse button + modifier, for your current class.
T:RegisterPage("groupframes", { key = "gf_clicks", label = "Click-casting", order = 4, build = function(p)
    local GF = T.GroupFrames
    local cc = function() return T.db.groupframes.clickcast end
    local binds = function() return GF:ClickBindings() end
    local _, className = UnitClass("player")
    p:Section("Click-casting", "Click a party or raid frame to cast on that player: no targeting needed, and it works in combat. Bindings are saved per class ("
        .. (className or "?") .. " here). Unbound clicks still target (left) or open the menu (right). Changes apply out of combat."
        .. (GF.cliqueLoaded and "\n|cffffd200Clique is loaded, so Tempus bindings are off; Clique handles clicks.|r" or ""))
    p:Check(cc, "enabled", "Enable click-casting")
    p:Check(cc, "hints", "List bindings in frame tooltips")

    -- Choices: none, target, menu, your spells, plus any saved value not in the list
    -- (e.g. a starting binding like "Abolish Poison|Cure Poison").
    local items = { { "", "None" }, { "target", "Target" }, { "menu", "Menu" } }
    local listed = { [""] = true, target = true, menu = true }
    for _, name in ipairs(GF:SpellbookSpells()) do
        items[#items + 1] = { name, name }
        listed[name] = true
    end
    for _, v in pairs(binds()) do
        if type(v) == "string" and not listed[v] then
            items[#items + 1] = { v, (v:gsub("|", " or ")) }
            listed[v] = true
        end
    end

    for _, bt in ipairs(GF.clickButtons) do
        p:Section(bt[2] .. " button")
        for _, m in ipairs(GF.clickMods) do
            local combo = m[1] .. bt[1]
            p:Dropdown(binds, combo, GF.ComboLabel(combo), items)
        end
    end

    p:Section("Reset")
    p:Add(W.Button("Restore starting bindings", function()
        GF:ResetClickBindings()
        GF:ClickBindings()
        Changed()
        if T.Options and T.Options.Open then T.Options:Open("gf_clicks") end
    end, "Druid, Priest, Shaman and Paladin get a healing set; other classes get Left = Target, Right = Menu."))
end })
