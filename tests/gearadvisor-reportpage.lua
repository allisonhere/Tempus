-- The Gear Reporter page and its notice.
local page, confirmed, shown = nil, nil, nil
local T = { RegisterPage = function(_, cat, def) page = { cat = cat, def = def } end,
    Confirm = function(_, text, accept, label) confirmed = { text = text, accept = accept, label = label } end,
    ShowShare = function(_, mode) shown = mode end }
assert(loadfile("Modules/GearAdvisor/Pages.lua"))("Tempus", T)
assert(page.cat == "convenience" and page.def.key == "gearreport" and page.def.label == "Gear Reporter", "its own menu entry, not Auction values")
T:StartGearReport()
assert(confirmed and confirmed.text:find("no account") and confirmed.text:find("Nothing is sent") and confirmed.label == "I understand, continue")
assert(shown == nil, "the report opens only after the notice is accepted")
confirmed.accept()
assert(shown == "gearreport")
local buttons = {}
local p = { Section = function() end, Add = function(_, w) buttons[#buttons + 1] = w end }
T.UI = { W = { Button = function(label, fn) return { label = label, fn = fn } end } }
page.def.build(p)
assert(#buttons == 1 and buttons[1].label == "Share my gear data")
shown = nil; confirmed = nil
buttons[1].fn()
assert(confirmed and shown == nil, "the button shows the notice first")
print("PASS: Gear Reporter page shows a notice before the report")
