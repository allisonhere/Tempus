-- Tempus UI: Combat Pulse, signal rules. Pure functions that decide which parts of the strip
-- are on screen for a presentation mode and what is currently happening. No frames, no
-- WoW calls: the display feeds readings in and draws whatever Plan returns.
local _, T = ...
local CP = T.CombatPulse or {}
T.CombatPulse = CP

local State = {}
CP.State = State

State.MODES = { MINIMAL = true, STANDARD = true, FULL = true }

function State.Mode(mode)
    return State.MODES[mode] and mode or "STANDARD"
end

-- Is your interrupt ready? true / false, or nil when the cooldown cannot be read (secret or
-- missing); the display then shows it neither ready nor cooling. Anything under the global
-- cooldown counts as ready.
function State.KickReady(start, duration, now)
    if not (T.Num(start) and T.Num(duration) and T.Num(now)) then return nil end
    if duration <= 1.6 then return true end
    return start + duration <= now
end

-- Threat levels that need attention. A tank holding it ("safe") and no threat are quiet.
local URGENT = { warn = true, lost = true, aggro = true }
function State.ThreatUrgent(level)
    return URGENT[level] or false
end

-- What to draw. db: the module settings. ctx: what is going on right now:
--   dpsReady    a damage meter reading exists
--   swingReady  the swing timer module is running
--   swinging    a swing is in progress
--   kickKnown   your class has an interrupt that Tempus knows
--   cast        the target is casting something it may be possible to interrupt
--   hostile     the target is an attackable enemy
--   executeOn   the nameplate execute threshold is above 0
--   purge       the target has a buff you can dispel or steal
--   threat      "safe" | "warn" | "lost" | "aggro" | nil
-- Returns booleans: dps, swing, kick, purge, threat, execute, peakLabels, strip (the backing
-- bar). Out of combat nothing contextual can apply.
function State.Plan(db, ctx)
    local mode = State.Mode(db.mode)
    local plan = {}
    local full, minimal = mode == "FULL", mode == "MINIMAL"
    plan.dps = db.showDPS and ctx.dpsReady and not minimal or false
    plan.swing = db.showSwing and ctx.swingReady and not minimal and (full or ctx.swinging) or false
    plan.kick = db.showKick and ctx.kickKnown and (full or ctx.cast) or false
    plan.purge = db.showPurge and ctx.hostile and (full or ctx.purge) or false
    plan.threat = db.showThreat and ctx.hostile and (full or State.ThreatUrgent(ctx.threat)) or false
    plan.execute = db.showExecute and ctx.hostile and ctx.executeOn or false
    plan.peakLabels = full and plan.dps
    -- Minimal has no bar of its own: it is just the chips, and nothing when none apply.
    plan.strip = plan.dps or plan.swing
    return plan
end

-- Whether the whole frame is drawn: always while placing it or testing, otherwise only in
-- combat when "hide out of combat" is on.
function State.Visible(db, inCombat, unlocked)
    if not db.enabled then return false end
    if db.test or unlocked or not db.hideOOC then return true end
    return inCombat and true or false
end
