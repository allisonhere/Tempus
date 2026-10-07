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

    p:Section("Signals", "Each cue only appears when Tempus can read it safely; classes without an interrupt or purge never see those cues.")
    p:Check(cfg, "showDPS", "DPS bar (live, peak, group top)")
    p:Check(cfg, "showSwing", "Swing timing")
    p:Check(cfg, "showKick", "Interrupt (your kick, when the target casts something interruptible)")
    p:Check(cfg, "showPurge", "Purge (a buff you can dispel or steal)")
    p:Check(cfg, "showThreat", "Threat (uses the nameplate tank / damage role)")
    p:Check(cfg, "showExecute", "Execute range (uses the nameplate execute threshold)")

    p:Dropdown(cfg, "scaleMode", "Bar scale", {
        { "AUTO", "Auto" }, { "FIXED", "Fixed maximum" },
    }, "In combat the game hides DPS, so Auto can only size the bar from earlier readable fights, and early-fight bursts can fill it. Fixed maximum puts the end of the bar at a DPS you choose.")
    p:Slider(cfg, "fixedMax", "Fixed maximum", 1, 5000000, 1, T.DPSTrack.Format, "DPS at the end of the bar in Fixed maximum mode. Set it a little above your best burst, such as 1.5 to 2 times your usual DPS.")

    p:Section("Size")
    p:Slider(cfg, "width", "Width", 120, 600, 1)
    p:Slider(cfg, "height", "Height", 6, 30, 1)
    p:Slider(cfg, "scale", "Scale", 0.5, 2, 0.05, two)
    p:Slider(cfg, "opacity", "Opacity", 0.2, 1, 0.05, UI.pct)

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
