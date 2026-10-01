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
