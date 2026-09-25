-- Tempus UI: settings pages for the unit frames module.
local _, T = ...
local UI = T.UI
local UF = T.UnitFrames
local W, Changed = UI.W, UI.Changed

local function UFDB() return T.db.unitframes end

T:RegisterPage("unitframes", { key = "uf_general", label = "General", order = 1, build = function(p)
    p:Section("Unit frames", "Player, target, target-of-target and pet frames. Health is shown as a percentage-fed bar because this client hides exact health values from addons. Unlock (top right) to drag frames and preview them without a target.")
    p:Dropdown(UFDB, "healthColor", "Health colour", {
        { "CLASS", "Class / reaction" }, { "REACTION", "Reaction only" },
        { "GRADIENT", "By health (green > red)" }, { "DARK", "Dark bars, coloured background" } })
    p:Slider(UFDB, "fontSize", "Text size", 8, 18, 1)
    p:Check(UFDB, "smooth", "Smooth bar animation")
    p:Check(UFDB, "classPower", "Combo points above the player frame", "Rogues, and druids in cat form.")
    p:Check(UFDB, "hideBlizzard", "Hide Blizzard unit frames", "Turning this off takes effect after /reload.")
    p:Newline()
    p:Section("Shared look", "Bar texture, font and outline come from General > Appearance.")
end })

local function UnitPage(unit, order)
    T:RegisterPage("unitframes", { key = "uf_" .. unit, label = UF.labels[unit], order = order, build = function(p)
        local cfg = function() return T.db.unitframes.units[unit] end
        p:Section(UF.labels[unit])
        p:Check(cfg, "enabled", "Enabled")
        p:Slider(cfg, "scale", "Scale", 0.5, 2, 0.05, UI.pct)
        p:Slider(cfg, "width", "Width", 60, 420, 1)
        p:Slider(cfg, "height", "Height", 14, 90, 1)
        p:Slider(cfg, "powerHeight", "Power bar height", 0, 24, 1, function(v) return v == 0 and "hidden" or tostring(v) end)
        p:Dropdown(cfg, "portrait", "Portrait", {
            { "NONE", "None" }, { "3D", "3D model" }, { "2D", "2D picture" }, { "OVERLAY", "3D, faded over health bar" } })

        p:Section("Text")
        p:Check(cfg, "showName", "Show name")
        p:Check(cfg, "showLevel", "Show level")
        p:Dropdown(cfg, "healthText", "Health text", {
            { "BOTH", "Value + percent" }, { "PERCENT", "Percent" }, { "CURRENT", "Value" }, { "NONE", "None" } })
        p:Dropdown(cfg, "powerText", "Power text", { { "CURRENT", "Value" }, { "PERCENT", "Percent" }, { "NONE", "None" } })

        if unit == "player" or unit == "target" then
            p:Section("Cast bar")
            p:Check(cfg, "castbar", "Show cast bar")
            p:Slider(cfg, "castbarHeight", "Cast bar height", 10, 36, 1)
        end
        if unit == "target" then
            p:Section("Auras", "Buffs and debuffs on your target, drawn by the game so they stay live in combat.")
            p:Check(cfg, "auras", "Show target auras")
            p:Slider(cfg, "auraSize", "Icon size", 14, 44, 1)
            p:Slider(cfg, "auraPerRow", "Icons per row", 4, 16, 1)
        end

        p:Section("Position")
        p:Add(W.Button("Reset position", function()
            T.db.unitframes.units[unit].point = T.CopyTable(UF.defaults.units[unit].point)
            Changed()
        end))
    end })
end

UnitPage("player", 2)
UnitPage("target", 3)
UnitPage("targettarget", 4)
UnitPage("pet", 5)
