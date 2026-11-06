local combat, party, raid = false, false, false
function InCombatLockdown() return combat end
function IsInGroup() return party end
function IsInRaid() return raid end
local events, timers = {}, {}
function CreateFrame()
    local f = {events = {}}
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(_, callback) self.callback = callback end
    events[#events + 1] = f; return f
end
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
local function Point(x) return {"CENTER","UIParent","CENTER",x,0} end
local T = {defaults = {}, db = {locked = true, unit = {point = Point(0), size = 77}}, Movers = {list = {}}}
assert(loadfile("Core/Layouts.lua"))("Tempus", T)
assert(loadfile("Core/AutoLayouts.lua"))("Tempus", T)
local L, A = T.Layouts, T.AutoLayouts
function T:ApplySettings() L:Cancel(); A:Schedule() end
local function Tick() local fn = table.remove(timers,1); assert(fn,"missing timer"); fn() end
local function Flush()
    local count = 0
    while #timers > 0 do count = count + 1; assert(count < 20,"scheduler did not settle"); Tick() end
end
for _, pair in ipairs({{"Solo",10},{"Party",20},{"Raid",30}}) do T.db.unit.point = Point(pair[2]); assert(L:Save(pair[1])) end
T.db.unit.point = Point(5)
local cfg = A:Config(); cfg.solo, cfg.party, cfg.raid = "Solo","Party","Raid"
A:Evaluate(); assert(T.db.unit.point[4] == 5 and not L:CanUndo(),"default must be opt-in")
cfg.enabled = true; A:Evaluate(); Flush()
assert(T.db.unit.point[4] == 10 and T.db.unit.size == 77)
assert(L:Undo() and T.db.unit.point[4] == 5); Flush()
assert(A:Status():find("Manual layout",1,true))
A:Evaluate(); assert(T.db.unit.point[4] == 5,"undo must not fight automatic switching")
party = true; A:Evaluate(); Flush(); assert(T.db.unit.point[4] == 20)
-- Repeated roster notifications cannot overwrite manual positions in the same group type.
T.db.unit.point[4] = 25; A:Evaluate(); assert(T.db.unit.point[4] == 25)
A:Reapply(); Flush(); assert(T.db.unit.point[4] == 20)
-- A manual edit suppresses pending automatic work for this group type only.
local edit = L:BeginEdit(); T.db.unit.point[4] = 24; L:EndEdit(edit)
A:Evaluate(); assert(T.db.unit.point[4] == 24)
raid = true; A:Evaluate(); Flush(); assert(T.db.unit.point[4] == 30,"raid must take precedence")
cfg.paused = true; A:Evaluate(); party,raid = false,false
A:Evaluate(); assert(T.db.unit.point[4] == 30)
cfg.paused = false; A:Reapply(); Flush(); assert(T.db.unit.point[4] == 10)
cfg.solo = ""; A:Evaluate(); assert(T.db.unit.point[4] == 10 and A:Status():find("No preset",1,true))
-- Coalesced notifications always use the latest group and the latest assigned preset.
combat,party = true,true
A:Schedule(); A:Schedule(); assert(#timers == 1); Tick()
assert(T.db.unit.point[4] == 10 and #timers == 0)
raid = true; A:Schedule(); Tick(); assert(T.db.unit.point[4] == 10)
combat = false; A:Schedule(); Flush(); assert(T.db.unit.point[4] == 30)
-- Returning to the already active context clears a stale waiting status.
combat,raid = true,false; A:Evaluate()
raid = true; A:Evaluate(); assert(not A:Status():find("Waiting",1,true)); combat = false
-- Unlock and preview deferrals retry without moving live frames; latest state wins.
party,raid = true,false; T.db.locked = false; A:Evaluate()
assert(T.db.unit.point[4] == 30 and #timers == 1)
T.db.locked = true; L.pending = {profile = T.db}; Tick()
assert(T.db.unit.point[4] == 30 and #timers == 1)
L:Cancel(); Tick(); Flush(); assert(T.db.unit.point[4] == 20)
-- Pending drag saves block routing, even though combat itself has ended.
raid = true; T.Movers.list = {{pendingMove = true}}; A:Evaluate()
assert(T.db.unit.point[4] == 20); T.Movers.list = {}; Tick(); Flush(); assert(T.db.unit.point[4] == 30)
assert(L:Rename("Raid","Raid renamed")); Flush()
assert(cfg.raid == "Raid renamed" and A:Status():find("Raid renamed",1,true))
L:Delete("Party"); Flush(); assert(cfg.party == "")
-- Missing preset names are harmless and visible in status.
raid = false; cfg.party = "missing"; A:Evaluate()
assert(T.db.unit.point[4] == 30 and A:Status():find("Preset missing",1,true))
-- Old pending jobs cannot apply a previous profile's assignments.
local old = T.db
cfg.party = "Solo"; combat = true; A:Evaluate()
T.db = {locked = true, unit = {point = Point(900)}}
combat = false; A:Schedule(); Flush()
assert(T.db.unit.point[4] == 900 and not L:CanUndo())
T.db = old; cfg.enabled = false; A:Evaluate(); Flush()
assert(A:Status():find("disabled",1,true))
local registered = events[#events].events
assert(registered.GROUP_ROSTER_UPDATE and registered.PLAYER_ENTERING_WORLD and registered.PLAYER_REGEN_ENABLED)
print("PASS: automatic layouts, combat/edit deferral, manual override, profiles and assignment maintenance")
