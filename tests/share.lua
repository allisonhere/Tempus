-- Profile sharing: round trip, damaged strings and unsafe input. Run: lua5.1 tests/share.lua
local T = {}
assert(loadfile("Core/Share.lua"))("Tempus", T)
local S = T.Share

local profile = {
    width = 140, scale = 0.85, enabled = true, name = 'He said "hi"\n\\ok', neg = -3.5,
    point = { "TOPRIGHT", "UIParent", "TOPRIGHT", -205, -13 },
    lists = { hidden = { ["12345"] = "mount", ["#odd"] = true }, watch = {} },
    groups = { buffs = { size = 32, perRow = 10 }, [3] = "numeric key", [7] = { 1, 2, 3 } },
    colors = { soon = { 1, 0.82, 0.1 } },
}
local text = S.Export(profile)
assert(text:sub(1, 8) == "TEMPUS1:", "prefix")
local back, err = S.Import(text)
assert(back, err)
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
assert(same(profile, back), "round trip changed the profile")

-- Whitespace and line breaks added by chat or a text box are tolerated.
local wrapped = text:gsub("(" .. string.rep(".", 60) .. ")", "%1\n  ")
assert(S.Import(wrapped), "line breaks")

-- Damage is reported, never accepted.
assert(not S.Import(text:sub(1, #text - 10)), "truncated string")
assert(not S.Import("hello"), "wrong prefix")
local at = 40
local swapped = text:sub(at, at) == "Q" and "R" or "Q"
assert(not S.Import(text:sub(1, at - 1) .. swapped .. text:sub(at + 1)), "altered string")
assert(not S.Import(""), "empty")
assert(not S.Import(nil), "nil")

-- The reader never runs code and rejects junk and deep nesting.
assert(not S.Parse('{"a":print("x")}'))
assert(not S.Parse('{"a":1} trailing'))
assert(not S.Parse(string.rep("[", 50) .. string.rep("]", 50)), "deep nesting")
assert(S.Parse('{"a":[1,2,{"b":null}],"c":"\\u0041"}').c == "A")

-- Sanitize keeps known keys of the right type.
local clean = S.Sanitize({ width = 99, scale = "wide", bogus = 1, lists = {} }, { width = 1, scale = 1, lists = {}, other = true })
assert(clean.width == 99 and clean.scale == nil and clean.bogus == nil and clean.lists ~= nil)
print("PASS: profile strings round trip, reject damage and junk, and sanitize unknown settings")
