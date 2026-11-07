-- Grey on cooldown: the decision from plain numbers, plain flags, or (secret) a duration curve.
-- Run: lua5.1 tests/cooldown-grey.lua
local function stub()
    return setmetatable({}, {__index = function(_, k) if k:match('^%u') then return function() end end end})
end
CreateFrame = function() return stub() end
UIParent = stub()
local SECRET = setmetatable({}, {})
local T = {accent = {0, 0.7, 1}, db = {theme = 'MODERN'}}
T.issecret = function(v) return v == SECRET end
function T.Num(v) return v ~= SECRET and type(v) == 'number' and v == v end
assert(loadfile('Core/Style.lua'))('Tempus', T)
local S = T.Style
local D = S.CooldownDown

-- Plain numbers.
assert(D(10, 8, nil, nil, 12) == true, 'an 8 second cooldown under way')
assert(D(10, 8, nil, nil, 19) == false, 'over')
assert(D(10, 1.5, nil, nil, 10.5) == false, 'the global cooldown never greys')
assert(D(0, 0, nil, nil, 50) == false, 'ready')
-- Secret numbers, plain flags.
assert(D(SECRET, SECRET, true, false, 5) == true, 'active and not the GCD')
assert(D(SECRET, SECRET, true, true, 5) == false, 'only the GCD')
assert(D(SECRET, SECRET, false, nil, 5) == false, 'not active')
-- Nothing plain to go on.
assert(D(SECRET, SECRET, true, nil, 5) == nil, 'active but GCD unknown')
assert(D(SECRET, SECRET, SECRET, SECRET, 5) == nil, 'all secret')
assert(D(SECRET, SECRET, nil, nil, 5) == nil)

-- Curve fallback: desaturation through a curve, then a tint, then give up.
Enum = {LuaCurveType = {Step = 1}}
CreateColor = function(r, g, b, a) return {GetRGB = function() return r, g, b end} end
local function curve() return {SetType = function() end, AddPoint = function(c, x, y) c[#c + 1] = {x, y} end} end
C_CurveUtil = {CreateCurve = curve, CreateColorCurve = curve}
local function eval(c, rem) local v = c[1][2]; for _, p in ipairs(c) do if rem >= p[1] then v = p[2] end end; return v end
local dur = {rem = 10, EvaluateRemainingDuration = function(d, c) return eval(c, d.rem) end}
local tex = {SetDesaturation = function(t, v) t.desat = v end, SetDesaturated = function(t, v) t.desat = v and 1 or 0 end,
    SetVertexColor = function(t, r) t.r = r end}
assert(S.GreyFromDuration(tex, dur, false) and tex.desat == 1, 'greyed while 10s remain')
dur.rem = 1
assert(S.GreyFromDuration(tex, dur, false) and tex.desat == 0, 'not grey in the last GCD-length stretch')
-- A client that won't take a secret desaturation: tint only where allowed.
local tex2 = {SetDesaturation = function() error('secret not allowed') end, SetVertexColor = function(t, r) t.r = r end,
    SetDesaturated = function() end}
dur.rem = 10
assert(not S.GreyFromDuration(tex2, dur, false), 'action buttons: no tint fallback')
assert(S.GreyFromDuration(tex2, dur, true) and tex2.r < 1 and tex2.tempusTinted, 'tracker icons tint instead')
S.SetGrey(tex2, false)
assert(tex2.r == 1 and not tex2.tempusTinted, 'a plain update undoes the tint')
assert(not S.GreyFromDuration(tex, nil, true), 'no duration object')
print('cooldown-grey ok')
