-- Cooldown tracker: only known spells are listed, in a stable order, trinkets after them.
local T = { Num = function(v) return type(v) == "number" end, Wrap = function(_, _, fn) return fn end,
    NewModule = function() end, Style = {},
    db = { lists = { cooldowns = { pummel = "Pummel", ["6552"] = "6552", unknown = "Zzz Fake", ["99999"] = "99999" } } } }
C_Spell = { GetSpellInfo = function(name) return ({ Pummel = { spellID = 6552 }, ["Zzz Fake"] = { spellID = 11 } })[name] end }
IsPlayerSpell = function(id) return id == 6552 or id == 99999 end
GetInventoryItemTexture = function(_, slot) return slot == 13 and 1 or nil end
assert(loadfile("Modules/Cooldowns/Cooldowns.lua"))("Tempus", T)
local CD = T.Cooldowns
CD.db = { trinkets = true }
local wanted = CD:Wanted()
-- "6552" and "Pummel" are the same spell and show once, the unknown spell is dropped, the other
-- known id is kept, and only the filled trinket slot shows.
local spells, slots = {}, {}
for _, e in ipairs(wanted) do if e.spell then spells[#spells + 1] = e.spell else slots[#slots + 1] = e.slot end end
assert(#spells == 2 and spells[1] == 6552 and spells[2] == 99999, table.concat(spells, ","))
assert(#slots == 1 and slots[1] == 13, "one trinket")
assert(wanted[#wanted].slot == 13, "trinkets come last")
CD.db.trinkets = false
for _, e in ipairs(CD:Wanted()) do assert(e.spell, "no trinkets when switched off") end
print("PASS: cooldown tracker lists known spells in order, then trinkets, and honours the trinket switch")

-- Timeline scale: equal steps between marks, clipped at the far end.
local m = CD.Marks(60)
assert(table.concat(m, ",") == "0,5,15,30,60", table.concat(m, ","))
assert(table.concat(CD.Marks(45), ",") == "0,5,15,30,45", "range between marks adds its own end")
local function near(a, b) return math.abs(a - b) < 1e-9 end
assert(CD.TimeFraction(0, m) == 0 and CD.TimeFraction(-3, m) == 0, "ready sits at the start")
assert(near(CD.TimeFraction(5, m), 0.25) and near(CD.TimeFraction(30, m), 0.75), "marks fall on equal steps")
assert(near(CD.TimeFraction(10, m), 0.375), "between marks is linear")
assert(CD.TimeFraction(60, m) == 1 and CD.TimeFraction(500, m) == 1, "past the end clips")
print("PASS: timeline scale maps remaining time to equal steps and clips at the far end")

-- Fade: solid across the far part of the scale, easing to 1 - strength at the ready line.
assert(CD.FadeAlpha(1, 0.8) == 1 and CD.FadeAlpha(0.35, 1) == 1, "far end is untouched")
assert(near(CD.FadeAlpha(0, 0.6), 0.4) and CD.FadeAlpha(0, 1) == 0 and CD.FadeAlpha(0, 0) == 1, "ready line takes the full fade")
assert(CD.FadeAlpha(0.1, 0.5) > CD.FadeAlpha(0, 0.5) and CD.FadeAlpha(0.1, 0.5) < 1, "in between is a ramp")
print("PASS: fade dims toward the ready line and leaves the far end alone")

-- Corner grip: width sets icon size and height sets length in the timeline; height sets size in the row.
local db = { mode = "timeline", showLabels = true, size = 36, length = 320 }
CD.ResizeFromBox(db, 28 + 14 + 2 * 40, 400 + 40)
assert(db.size == 40 and db.length == 400, db.size .. "," .. db.length)
CD.ResizeFromBox(db, 10, 10)
assert(db.size == 20 and db.length == 160, "clamped low")
CD.ResizeFromBox(db, 900, 2000)
assert(db.size == 64 and db.length == 600, "clamped high")
db.mode = "icons"; CD.ResizeFromBox(db, 500, 48)
assert(db.size == 48, "row sizes from height")
print("PASS: resize grip maps the dragged box to icon size and timeline length")
