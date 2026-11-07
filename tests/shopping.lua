-- Shopping list: parsing what was typed, progress text, adding/removing and "done" announcements.
-- Run: lua5.1 tests/shopping.lua
local T = { Style = {}, issecret = function() return false end, accentHex = "ffffff" }
function T.Num(v) return type(v) == "number" and v == v end
function T:NewModule(key, def) self.module = def end
local printed = {}
function T:Print(msg, ...) printed[#printed + 1] = msg:format(...) end
function T:CharacterKey() return "Me - Realm" end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
assert(loadfile("Modules/Shopping/Shopping.lua"))("Tempus", T)
local SH = T.Shopping

local link = "|cffffffff|Hitem:2589::::::::20:::::::|h[Linen Cloth]|h|r"
local item, n = SH.ParseAdd(link .. " 20")
assert(item == link and n == 20, "link then amount")
item, n = SH.ParseAdd(link)
assert(item == link and n == nil, "link alone")
item, n = SH.ParseAdd("Linen Cloth 20")
assert(item == "Linen Cloth" and n == 20, "name then amount")
item, n = SH.ParseAdd("Linen Cloth x20")
assert(item == "Linen Cloth" and n == 20, "name x amount")
item, n = SH.ParseAdd("20 Linen Cloth")
assert(item == "Linen Cloth" and n == 20, "amount then name")
item, n = SH.ParseAdd("2589 5")
assert(item == 2589 and n == 5, "item id")
assert(SH.ParseAdd("   ") == nil)

local t, done = SH.ProgressText(12, 20, 5)
assert(t:find("12/20") and t:find("+5 alts") and not done)
t, done = SH.ProgressText(25, 20, 5)
assert(t == "20/20" and done, "done hides alts and caps the count")

-- Fake client.
local counts = { [2589] = 4 }
GetItemCount = function(id) return counts[id] or 0 end
GetItemInfo = function(x)
    if x == 2589 or x == "Linen Cloth" then return "Linen Cloth", "|Hitem:2589|h[Linen Cloth]|h" end
end
T.Bags = { Characters = { OthersCount = function(id, me) assert(me == "Me - Realm") return id == 2589 and 7 or 0 end } }
SH.db = { items = {}, showAlts = true, announce = true }
SH:Command("Linen Cloth 20")
assert(#SH.db.items == 1 and SH.db.items[1].id == 2589 and SH.db.items[1].need == 20, "added by name")
assert(SH:Alts(2589) == 7)
SH:Command(link .. " 10")
assert(#SH.db.items == 1 and SH.db.items[1].need == 10, "adding again changes the target")
SH:Command("Mystery Thing 3")
assert(#SH.db.items == 1 and printed[#printed]:find("unknown item"), "unknown names are refused")
counts[2589] = 10
SH:Recount()
assert(printed[#printed]:find("Linen Cloth done"), "announces when done")
local before = #printed
SH:Recount()
assert(#printed == before, "announces only once")
SH:Command("remove Linen Cloth")
assert(#SH.db.items == 0, "removed")
print("shopping ok")
