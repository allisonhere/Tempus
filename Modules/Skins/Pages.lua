-- Tempus UI: settings page for the skins module.
local _, T = ...
local UI = T.UI
local W = UI.W

T:RegisterPage("skins", { key = "skins", label = "Skins", order = 1, build = function(p)
    local cfg = function() return T.db.skins end
    p:Section("Blizzard", "Re-themes the game's windows in the Tempus look. Most changes apply after a reload.")
    p:Check(cfg, "windows", "Windows", "Character sheet, spellbook, talents, merchant, mail, bank, loot, menus, friends and more.")
    p:Check(cfg, "parchment", "Parchment reading panels", "Quest dialogs, quest details, gossip, books and mail keep their parchment inside a Tempus frame. Off makes them fully dark with brightened text. Applies after a reload.")
    p:Check(cfg, "tooltips", "Tooltips", "Tempus panels with class, reaction and item-quality borders.")
    p:Check(cfg, "tooltipHealth", "Tooltip health bar")
    p:Check(cfg, "tooltipCursor", "Tooltips follow the cursor")
    p:Check(cfg, "chat", "Chat frames", "Panels behind chat, flat tabs and edit box. Works alongside Prat.")
    p:Slider(cfg, "chatAlpha", "Chat panel opacity", 0, 1, 0.05, UI.pct)
    p:Section("Quest tracker")
    p:Check(cfg, "trackerPanel", "Panel behind the quest tracker", "A translucent Tempus panel sized to your tracked quests.")
    p:Slider(cfg, "trackerAlpha", "Panel opacity", 0.1, 1, 0.05, UI.pct)
    p:Section("Other addons")
    p:Check(cfg, "bagnon", "Bagnon", "Tempus skin for Bagnon's frames and square item slots with quality borders.")
    p:Check(cfg, "dbm", "DBM timers", "Adds a 'Tempus' skin to DBM's bar skins.")
    p:Newline()
    p:Add(W.Button("Use Tempus skin in DBM", function() T.Skins:ApplyDBM() end, "Switches DBM's timer bars to the Tempus skin now."))
    p:Add(W.Button("Reload UI", function() ReloadUI() end))
end })
