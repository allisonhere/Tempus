-- Tempus UI: settings page for Combat Pulse.
local _, T = ...
local UI = T.UI
local W, Changed = UI.W, UI.Changed

T:RegisterPage("general", { key = "combatpulse", label = "Combat Pulse", order = 8, build = function(p)
    local cfg = function() return T.db.combatpulse end
    local two = function(v) return ("%.2f"):format(v) end
    p:Section("Combat Pulse", "One strip for the fight: the layered DPS bar, a thin swing line, and small cues that appear only when they matter: an interruptible cast, a buff you can purge, threat trouble and the execute range. Needs the Combat Pulse module (General > Modules). Swing timing needs the Swing timer module.")
    p:Check(cfg, "enabled", "Show Combat Pulse")
    p:Dropdown(cfg, "mode", "Presentation", {
        { "MINIMAL", "Minimal: urgent cues only" },
        { "STANDARD", "Standard: DPS, swing and cues" },
        { "FULL", "Full: everything available" },
    }, "Minimal shows only the cues that need you. Standard adds the DPS bar and swing line. Full also keeps the interrupt, purge and threat chips and your peak and group top numbers on screen.")
    p:Check(cfg, "hideOOC", "Hide out of combat")
    p:Check(function() return T.db end, "locked", "Lock position", "Untick to drag Combat Pulse (and every other Tempus element).")
    p:Check(cfg, "test", "Test mode", "Animated sample values and every cue, so you can place and style the strip out of combat.")

    p:Section("Signals", "Each cue only appears when Tempus can read it safely. Cast priority comes from Nameplates > Casts & Auras.")
    p:Check(cfg, "showDPS", "DPS bar (live, peak, group top)")
    p:Check(cfg, "showSwing", "Swing timing with moving edge")
    p:Check(cfg, "showCastPriority", "Important / Dangerous / Must cast warnings")
    p:Check(cfg, "showKick", "My interrupt readiness")
    p:Check(cfg, "showPurge", "Purge opportunity")
    p:Check(cfg, "showThreat", "Threat")
    p:Check(cfg, "showExecute", "Execute notch")
    p:Check(cfg, "roleAware", "Role-aware emphasis", "Tank keeps threat visible in Standard; cue order changes for tank, healer and damage roles.")
    p:Check(cfg, "showPrevious", "Previous-fight DPS marker", "A small marker on the bar shows the final DPS from your last recorded fight.")

    p:Section("Size")
    p:Slider(cfg, "width", "Width", 120, 600, 1)
    p:Slider(cfg, "height", "Height", 6, 30, 1)
    p:Slider(cfg, "scale", "Scale", 0.5, 2, 0.05, two)
    p:Slider(cfg, "opacity", "Opacity", 0.2, 1, 0.05, UI.pct)

    p:Section("After combat", "A tiny readable history, not a full damage meter. Hidden combat values are never reconstructed.")
    p:Check(cfg, "showSummary", "Show post-fight summary")
    p:Slider(cfg, "summarySeconds", "Summary duration", 2, 10, 1, function(v) return v .. "s" end)
    p:Slider(cfg, "historySize", "Fights to remember", 1, 5, 1)
    p:Check(cfg, "historyOnClick", "Click Combat Pulse out of combat for history")
    p:Add(W.Button("Show recent fights", function()
        if T.CombatPulse and T.CombatPulse.ToggleHistory then T.CombatPulse:ToggleHistory(true) end
    end))
    p:Add(W.Button("Clear fight history", function()
        T.db.combatpulse.history = {}
        if T.CombatPulse and T.CombatPulse.ToggleHistory then T.CombatPulse:ToggleHistory(false) end
        Changed()
    end))

    p:Section("Colours", "Threat and execute colours follow the Nameplates settings.")
    p:Color(cfg, "liveColor", "Live DPS")
    p:Color(cfg, "peakColor", "Your peak")
    p:Color(cfg, "topColor", "Group top")
    p:Color(cfg, "purgeColor", "Purge")

    p:Section("Position")
    p:Add(W.Button("Reset position", function()
        T.db.combatpulse.point = T.CopyTable(T.CombatPulse.defaults.point)
        Changed()
    end))
end })
