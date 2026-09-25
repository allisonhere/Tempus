-- Tempus UI: settings pages for the action bars module.
local _, T = ...
local UI = T.UI
local AB = T.ActionBars
local W, Changed = UI.W, UI.Changed

local function ABDB() return T.db.actionbars end
local FADE = { { "NONE", "Always visible" }, { "MOUSEOVER", "Show on mouseover" }, { "COMBAT", "Show in combat or on mouseover" } }

T:RegisterPage("actionbars", { key = "ab_general", label = "General", order = 1, build = function(p)
    p:Section("Action bars", "Blizzard's own buttons, restyled and placed in Tempus bars, so keybinds, cooldowns and range work exactly as before. Unlock (top right) to drag bars. Bars can only change outside combat.")
    p:Check(ABDB, "showHotkeys", "Show keybinds")
    p:Check(ABDB, "showMacroNames", "Show macro names")
    p:Check(ABDB, "showCounts", "Show item counts")
    p:Check(ABDB, "showEmpty", "Show empty slots", "Bars 2-8 hide empty slots and show them while you drag a spell or item. The main bar always shows all slots.")
    p:Slider(ABDB, "hotkeySize", "Text size", 8, 18, 1)
    p:Slider(ABDB, "swipeAlpha", "Cooldown darkness", 0.2, 1, 0.05, UI.pct)
end })

for i, def in ipairs(AB.defs) do
    T:RegisterPage("actionbars", { key = "ab_" .. def.key, label = def.label, order = i + 1, build = function(p)
        local cfg = function() return T.db.actionbars.bars[def.key] end
        p:Section(def.label, def.paging and "Pages automatically for stances, forms and stealth, like the default main bar." or nil)
        p:Check(cfg, "enabled", "Enabled")
        p:Check(cfg, "backdrop", "Panel behind the bar")
        p:Slider(cfg, "buttons", "Buttons", 1, def.count, 1)
        p:Slider(cfg, "perRow", "Buttons per row", 1, def.count, 1)
        p:Slider(cfg, "size", "Button size", 18, 64, 1)
        p:Slider(cfg, "spacing", "Spacing", 0, 16, 1)
        p:Slider(cfg, "scale", "Scale", 0.5, 2, 0.05, UI.pct)
        p:Section("Visibility")
        p:Dropdown(cfg, "fade", "Fading", FADE)
        p:Slider(cfg, "fadeAlpha", "Faded opacity", 0, 1, 0.05, UI.pct)
        p:Slider(cfg, "alpha", "Opacity when shown", 0.2, 1, 0.05, UI.pct)
        p:Section("Position")
        p:Add(W.Button("Reset position", function()
            T.db.actionbars.bars[def.key].point = T.CopyTable(AB.defaults.bars[def.key].point)
            Changed()
        end))
    end })
end

T:RegisterPage("actionbars", { key = "ab_menus", label = "Menu & Bags", order = 30, build = function(p)
    for _, key in ipairs({ "micro", "bags" }) do
        local cfg = function() return T.db.actionbars[key] end
        p:Section(key == "micro" and "Micro menu" or "Bag buttons")
        p:Check(cfg, "enabled", "Let Tempus place it", "Off leaves it where Blizzard's Edit Mode puts it.")
        p:Slider(cfg, "scale", "Scale", 0.5, 1.5, 0.05, UI.pct)
        p:Dropdown(cfg, "fade", "Fading", FADE)
        p:Slider(cfg, "fadeAlpha", "Faded opacity", 0, 1, 0.05, UI.pct)
    end
end })
