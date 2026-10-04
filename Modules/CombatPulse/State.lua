-- Tempus UI: Combat Pulse, pure signal and history rules.
local _, T = ...
local CP = T.CombatPulse or {}
T.CombatPulse = CP

local State = {}
CP.State = State

State.MODES = { MINIMAL = true, STANDARD = true, FULL = true }
State.PRIORITY = { NORMAL = 0, IMPORTANT = 1, DANGEROUS = 2, MUST = 3 }

function State.Mode(mode)
    return State.MODES[mode] and mode or "STANDARD"
end

function State.CastPriority(priority)
    return State.PRIORITY[priority] and priority or "NORMAL"
end

function State.KickReady(start, duration, now)
    if not (T.Num(start) and T.Num(duration) and T.Num(now)) then return nil end
    if duration <= 1.6 then return true end
    return start + duration <= now
end

local URGENT = { warn = true, lost = true, aggro = true }
function State.ThreatUrgent(level)
    return URGENT[level] or false
end

function State.Role(role)
    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then return role end
    return "DAMAGER"
end

function State.SignalOrder(role)
    role = State.Role(role)
    if role == "TANK" then return { "threat", "kick", "purge" } end
    if role == "HEALER" then return { "purge", "kick", "threat" } end
    return { "kick", "purge", "threat" }
end

-- Readable relative performance. nil means the client did not expose comparable numbers.
function State.PercentOfTop(live, top)
    if not (T.Num(live) and T.Num(top)) or top <= 0 then return nil end
    return math.max(0, math.min(999, live / top * 100))
end

-- Newest fight first, bounded so SavedVariables never turn into a combat-meter database.
function State.PushHistory(history, entry, limit)
    history = type(history) == "table" and history or {}
    if type(entry) ~= "table" or not T.Num(entry.dps) or entry.dps <= 0 then return history end
    table.insert(history, 1, entry)
    limit = math.max(1, math.floor(tonumber(limit) or 5))
    while #history > limit do table.remove(history) end
    return history
end

-- What to draw. Role awareness changes emphasis, never invents information or hides a signal
-- the user explicitly enabled. Tank threat stays visible in Standard; other roles keep it
-- contextual. Signal order is handled separately by SignalOrder.
function State.Plan(db, ctx)
    local mode = State.Mode(db.mode)
    local plan = {}
    local full, minimal = mode == "FULL", mode == "MINIMAL"
    local role = State.Role(ctx.role)
    plan.dps = db.showDPS and ctx.dpsReady and not minimal or false
    plan.swing = db.showSwing and ctx.swingReady and not minimal and (full or ctx.swinging) or false
    plan.kick = db.showKick and ctx.kickKnown and (full or ctx.cast) or false
    plan.purge = db.showPurge and ctx.hostile and (full or ctx.purge) or false
    local tankHold = db.roleAware ~= false and role == "TANK" and ctx.hostile and not minimal
    plan.threat = db.showThreat and ctx.hostile and (full or tankHold or State.ThreatUrgent(ctx.threat)) or false
    plan.execute = db.showExecute and ctx.hostile and ctx.executeOn or false
    plan.priority = State.CastPriority(ctx.castPriority)
    plan.peakLabels = full and plan.dps
    plan.strip = plan.dps or plan.swing
    return plan
end

function State.Visible(db, inCombat, unlocked)
    if not db.enabled then return false end
    if db.test or unlocked or not db.hideOOC then return true end
    return inCombat and true or false
end
