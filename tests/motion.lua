-- Recent-damage bar, combat accent and class accent.
-- Run: lua5.1 tests/motion.lua
Enum = { StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 } }
local function stub()
    local o = { shown = true, level = 5 }
    function o:SetShown(v) self.shown = v and true or false end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:IsShown() return self.shown end
    function o:CreateTexture() return stub() end
    function o:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    function o:GetFrameLevel() return self.level end
    function o:SetFrameLevel(n) self.level = n end
    function o:SetMinMaxValues(a, b) self.min, self.max = a, b end
    function o:GetMinMaxValues() return self.min, self.max end
    function o:SetValue(v, mode) self.value, self.mode = v, mode end
    function o:SetStatusBarColor(r, g, b, a) self.color = { r, g, b, a } end
    return setmetatable(o, { __index = function(_, k) if k:match('^%u') then return function() end end end })
end
CreateFrame = function() return stub() end
UIParent = stub()
local T = { accent = { 0.25, 0.76, 1 }, db = { theme = 'MODERN' } }
assert(loadfile('Core/Style.lua'))('Tempus', T)
local S = T.Style
local IMM, EASE = 0, 1

local bar = S.StatusBar(stub())
bar:SetMinMaxValues(0, 100)
local lag = assert(S.LagBar(bar), 'lag bar made when the client interpolates')
assert(S.LagBar(bar) == lag, 'one lag bar per bar')
assert(not lag.shown, 'lag bar starts hidden')

S.SetBar(bar, 80, true, true)
assert(lag.shown and bar.mode == IMM and lag.value == 80 and lag.mode == IMM, 'first value: both jump')
assert(lag.max == 100 and lag.level == bar.level - 1, 'lag bar follows range and sits under the bar')
S.SetBar(bar, 50, true, true)
assert(bar.value == 50 and bar.mode == IMM and lag.value == 50 and lag.mode == EASE, 'a hit: bar jumps, lag eases')
S.SnapLag(bar)
S.SetBar(bar, 90, true, true)
assert(lag.mode == IMM, 'new unit: lag snaps')
S.SetBar(bar, 70, true, true)
assert(lag.mode == EASE, 'snap is one-off')
S.SetBar(bar, 60, true, false)
assert(not lag.shown and bar.mode == EASE, 'lag off: hidden, smooth bar')
S.SetBar(bar, 55, false, false)
assert(bar.value == 55 and bar.mode == nil, 'neither: plain value')

-- Pulses stay still when animations are off.
local played = 0
local region = stub()
region.CreateAnimationGroup = function()
    local ag = stub()
    ag.playing = false
    ag.Play = function(self) self.playing = true; played = played + 1 end
    ag.Stop = function(self) self.playing = false end
    ag.IsPlaying = function(self) return self.playing end
    ag.CreateAnimation = function() return stub() end
    return ag
end
local pulse = S.Pulse(region)
pulse:SetActive(true)
assert(played == 1)
pulse:SetActive(false)
T.db.animate = false
pulse:SetActive(true)
assert(played == 1 and not pulse.ag.playing, 'animations off: no pulse')
T.db.animate = true

print('PASS: recent-damage bar, pulses')

-- Combat accent and class accent through Core.
function GetAddOnMetadata() return "2.6.0" end
function GetTime() return 100 end
function UnitName() return "Tester" end
function UnitClass() return "Mage", "MAGE" end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
function GetRealmName() return "Realm" end
function InCombatLockdown() return false end
function date() return "12:00:00" end
SlashCmdList = {}
local C = {}
assert(loadfile("Core/Core.lua"))("Tempus", C)
local repainted = 0
C.Style = { RefreshAccent = function() repainted = repainted + 1 end }
C.db = { accent = "GOLD", combatAccent = true, combatColor = { 1, 0.45, 0.22 } }
C:ApplyAccent()
assert(C.accent[1] == 1 and C.accent[2] == 0.78, 'gold')
C:SetCombatAccent(true)
assert(C.accent[2] == 0.45 and repainted == 1, 'combat colour in combat')
C:SetCombatAccent(false)
assert(C.accent[2] == 0.78 and repainted == 2, 'accent restored after combat')
C.db.combatAccent = false
C:SetCombatAccent(true)
assert(C.accent[2] == 0.78 and repainted == 2, 'switched off: nothing changes')
C.db.accent = "CLASS"
C:ApplyAccent()
assert(C.accent[1] == 0.25 and C.accent[3] == 0.92 and C.accentHex == "40c7eb", 'class accent')
print('PASS: combat accent and class accent')
