-- The gear data report notice, and the Gear Report page that carries its button.
local confirmed, shown = nil, nil
local T = { Confirm = function(_, text, accept, label) confirmed = { text = text, accept = accept, label = label } end,
    ShowShare = function(_, mode) shown = mode end }
assert(loadfile("Modules/GearAdvisor/Pages.lua"))("Tempus", T)
T:StartGearReport()
assert(confirmed and confirmed.text:find("no account") and confirmed.text:find("Nothing is sent") and confirmed.label == "I understand, continue")
assert(shown == nil, "the report opens only after the notice is accepted")
confirmed.accept()
assert(shown == "gearreport")

-- The page: renamed Gear Report, with the button at the very top.
local page
local P = { module = nil }
local order = {}
local pageT = { RegisterPage = function(_, cat, def) page = { cat = cat, def = def } end, StartGearReport = function() confirmed = "noticed" end,
    db = { market = {} }, UI = { W = { Button = function(label, fn) return { kind = "button", label = label, fn = fn } end } },
    Num = function(v) return type(v) == "number" end, GearAdvisor = {} }
local p = setmetatable({}, { __index = function() return function() end end })
p.Section = function(_, title) order[#order + 1] = "section:" .. title end
p.Add = function(_, w) order[#order + 1] = "add:" .. (w.label or "?"); if w.label == "Share my gear data" then p.button = w end end
UnitClass = function() return "Warlock", "WARLOCK" end
Enum = {}
local ok, err = pcall(function() assert(loadfile("Modules/Market/Pages.lua"))("Tempus", pageT) end)
assert(ok, err)
assert(page.cat == "convenience" and page.def.key == "market" and page.def.label == "Gear Report", "the Auction values page is now Gear Report")
page.def.build(p)
assert(order[1] == "section:Gear Report" and order[2] == "add:Share my gear data", "the button is first on the page: " .. table.concat(order, ", "))
confirmed = nil
p.button.fn()
assert(confirmed == "noticed", "the button shows the notice first")
print("PASS: the Gear Report page leads with the share button, behind a notice")
