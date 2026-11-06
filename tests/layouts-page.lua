-- Settings pages must preserve widget height and expose working history actions.
local db = {unit = {point = {"CENTER","UIParent","CENTER",0,0}}}
function InCombatLockdown() return false end
function CreateFrame() return {RegisterEvent = function() end, SetScript = function() end} end
local T = {db = db, Movers = {list = {}}, UI = {W = {}}, Print = function() end}
function T:ApplySettings() self.Layouts:Cancel() end
local build
function T:RegisterPage(_, definition) build = definition.build end
local function Button(label, onClick)
    local widget = {label = label, click = onClick, button = {SetEnabled = function(self,on) self.enabled = on end}}
    function widget:Refresh() end
    return widget, 28
end
T.UI.W.Button = Button
T.UI.W.Dropdown = function() return {Refresh = function() end}, 48 end
assert(loadfile("Core/Layouts.lua"))("Tempus", T)
assert(loadfile("Config/LayoutPresets.lua"))("Tempus", T)
local widgets, buttons = {}, {}
local page = {Section = function() end, Newline = function() end}
function page:Add(widget, height)
    assert(type(height) == "number" and height > 0, "page widgets need explicit heights")
    widgets[#widgets + 1] = widget
    if widget.label then buttons[widget.label] = widget end
    widget:Refresh()
end
build(page)
assert(not buttons.Undo.button.enabled and not buttons.Redo.button.enabled)
local edit = T.Layouts:BeginEdit(); db.unit.point[4] = 3; T.Layouts:EndEdit(edit)
buttons.Undo:Refresh(); assert(buttons.Undo.button.enabled)
buttons.Undo.click(); assert(db.unit.point[4] == 0)
buttons.Redo:Refresh(); assert(buttons.Redo.button.enabled)
buttons.Redo.click(); assert(db.unit.point[4] == 3)
assert(buttons["Preview selected"] and buttons["Preview defaults"] and buttons["Apply preview"])
print("PASS: preset page widget sizing and undo/redo actions")
