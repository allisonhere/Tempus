-- Drive the real mover handlers and panel buttons with a small frame API double.
local combat, shift, cursorX, cursorY = false, false, 0, 0
local control, alt = false, true
local Methods = {}
function Methods:SetScript(event, fn) self.scripts[event] = fn end
function Methods:GetScript(event) return self.scripts[event] end
function Methods:Hide()
    local was = self.shown; self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Methods:Show() self.shown = true end
function Methods:SetShown(on) if on then self:Show() else self:Hide() end end
function Methods:IsShown() return self.shown end
function Methods:SetEnabled(on) self.enabled = on end
function Methods:SetSize(w,h) self.width, self.height = w,h end
function Methods:SetAllPoints(other) self.relative = other end
function Methods:GetWidth() return self.width or (self.relative and self.relative:GetWidth()) or 1 end
function Methods:GetHeight() return self.height or (self.relative and self.relative:GetHeight()) or 1 end
function Methods:GetEffectiveScale() return self.scale or 1 end
function Methods:SetScale(value) self.scale = value end
function Methods:SetText(value) self.text = value end
function Methods:GetLeft() return self.left or 0 end
function Methods:GetBottom() return self.bottom or 0 end
function Methods:GetRight() return self:GetLeft() + self:GetWidth() end
function Methods:GetTop() return self:GetBottom() + self:GetHeight() end
function Methods:SetPoint(corner, relative, relativeCorner, x, y)
    if not self.target then return end
    assert(not combat, "protected frame cannot move in combat")
    local factor = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local W,H = UIParent:GetWidth() / factor, UIParent:GetHeight() / factor
    local function Offset(anchor,w,h)
        local ox = anchor:find("LEFT") and 0 or (anchor:find("RIGHT") and w or w/2)
        local oy = anchor:find("BOTTOM") and 0 or (anchor:find("TOP") and h or h/2)
        return ox,oy
    end
    local ax,ay = Offset(relativeCorner,W,H)
    local bx,by = Offset(corner,self:GetWidth(),self:GetHeight())
    self.left, self.bottom = ax + x - bx, ay + y - by
end
local frames = {}
local function Frame()
    local frame = setmetatable({scripts = {}, shown = true}, {__index = function(_, key)
        return Methods[key] or (key:match("^%u") and function() end)
    end})
    frames[#frames + 1] = frame
    return frame
end
function Methods:CreateTexture() return Frame() end
function Methods:CreateFontString() return Frame() end
CreateFrame = Frame
UIParent = Frame(); UIParent:SetSize(1000,800)
UISpecialFrames, tinsert = {}, table.insert
function InCombatLockdown() return combat end
function GetCursorPosition() return cursorX, cursorY end
function IsShiftKeyDown() return shift end
function IsAltKeyDown() return alt end
function IsControlKeyDown() return control end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetText() end
function UIDropDownMenu_Initialize(frame,fn) frame.menu = fn end
local menuItems
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info) menuItems[#menuItems+1] = info end
local S = {Tex = Frame, CreateBorder = Frame, Accent = function(v) return v end, OnAccent = function(fn) fn() end}
local T = {Style = S, accent = {1,0,1}, db = {locked = false, unit = {point = {"BOTTOMLEFT","UIParent","BOTTOMLEFT",10,50}}}}
function T:Print() end
assert(loadfile("Core/Movers.lua"))("Tempus", T)
assert(loadfile("Core/MoverGroups.lua"))("Tempus", T)
assert(loadfile("Core/Layouts.lua"))("Tempus", T)
local M, L = T.Movers, T.Layouts
local target = Frame(); target.target = true; target:SetSize(100,20)
local callbacks, queued = 0, {}
local m = M:Register(target, {label = "Player", cfg = function() return T.db.unit end, secure = true,
    onMoved = function() callbacks = callbacks + 1 end})
function T:ApplySettings()
    L:Cancel()
    for _, mover in ipairs(M.list) do M.ApplyPoint(mover.target, mover.opts.cfg()) end
    M:Refresh()
end
function T:RunOOC(fn) if combat then queued[#queued + 1] = fn else fn() end end
T:ApplySettings()
-- Locate the actual panel, through the button callbacks captured at creation.
local panel
for _, frame in ipairs(frames) do
    if frame.undo and frame.redo then panel = frame; break end
end
assert(panel and not panel.undo.enabled and not panel.redo.enabled)
-- The entire mouse drag is one history action, not one entry per update.
m.scripts.OnDragStart(m)
assert(not panel.undo.enabled)
cursorX, cursorY = 30,20; m.scripts.OnUpdate(m)
cursorX, cursorY = 50,40; m.scripts.OnUpdate(m)
m.scripts.OnDragStop(m)
assert(T.db.unit.point[4] == 60 and T.db.unit.point[5] == 90 and callbacks == 1)
assert(panel.undo.enabled)
panel.undo.scripts.OnClick(panel.undo)
assert(T.db.unit.point[4] == 10 and T.db.unit.point[5] == 50 and not panel.undo.enabled and panel.redo.enabled)
panel.redo.scripts.OnClick(panel.redo)
assert(T.db.unit.point[4] == 60 and T.db.unit.point[5] == 90)
-- One arrow click is one edit; Shift multiplies it by ten.
panel.arrows[4].scripts.OnClick(panel.arrows[4])
assert(T.db.unit.point[4] == 61)
assert(L:Undo() and T.db.unit.point[4] == 60)
shift = true; panel.arrows[1].scripts.OnClick(panel.arrows[1]); shift = false
assert(T.db.unit.point[5] == 100 and not L:CanRedo())
assert(L:Undo() and T.db.unit.point[5] == 90)
-- Entering combat ends a drag without writing protected anchors or losing history.
m.scripts.OnDragStart(m)
cursorX = 70; m.scripts.OnUpdate(m)
combat = true; m.scripts.OnUpdate(m)
assert(not m.moving and #queued == 1 and not L:CanUndo())
combat = false; queued[1]()
assert(T.db.unit.point[4] == 80)
assert(L:Undo() and T.db.unit.point[4] == 60)
-- Closing/locking during a drag commits exactly once and does not leak moving state.
m.scripts.OnDragStart(m); cursorX = 90; m.scripts.OnUpdate(m)
T.db.locked = true; T:ApplySettings()
assert(not m.moving and L:Undo() and T.db.unit.point[4] == 60)
print("PASS: mover drag/nudge history, panel actions, combat and hide cleanup")

-- Group edits drive the same live handlers, including frames with different scales.
local function Point(x,y) return {"BOTTOMLEFT","UIParent","BOTTOMLEFT",x,y} end
T.db = {locked = false, unit = {point = Point(10,50)}, two = {point = Point(200,25)}, three = {point = Point(750,50)}}
local second = Frame(); second.target = true; second:SetSize(40,10); second:SetScale(2)
local third = Frame(); third.target = true; third:SetSize(120,20)
local n = M:Register(second, {label = "Target", cfg = function() return T.db.two end, secure = true,
    enabled = function() return T.db.two.enabled ~= false end})
local o = M:Register(third, {label = "Combat bar", cfg = function() return T.db.three end})
T:ApplySettings()
assert(#M:Selection() == 1 and M.selected[m])
shift = true; n.scripts.OnMouseDown(n,"LeftButton"); shift = false
assert(#M:Selection() == 2 and m.selection.shown and n.selection.shown)
assert(panel.name.text == "2 frames selected")
-- Shift toggles membership in both directions; Ctrl-click remains compatible.
shift = true; n.scripts.OnMouseDown(n,"LeftButton"); shift = false
assert(#M:Selection() == 1 and not M.selected[n])
shift = true; n.scripts.OnMouseDown(n,"LeftButton"); shift = false
assert(#M:Selection() == 2 and M.selected[n])
control = true; n.scripts.OnMouseDown(n,"LeftButton"); control = false
assert(#M:Selection() == 1)
control = true; n.scripts.OnMouseDown(n,"LeftButton"); control = false
assert(#M:Selection() == 2)
-- Shift on the arrow changes step size without toggling any selected member.
shift = true; panel.arrows[4].scripts.OnClick(panel.arrows[4]); shift = false
assert(#M:Selection() == 2 and T.db.unit.point[4] == 20 and T.db.two.point[4] == 205)
assert(L:Undo() and T.db.unit.point[4] == 10 and T.db.two.point[4] == 200)

assert(panel.groupButtons[1].enabled and not panel.groupButtons[7].enabled)
-- One nudge moves both by one UIParent unit despite their different scales.
panel.arrows[4].scripts.OnClick(panel.arrows[4])
assert(T.db.unit.point[4] == 11 and T.db.two.point[4] == 200.5)
assert(L:Undo() and T.db.unit.point[4] == 10 and T.db.two.point[4] == 200 and not L:CanUndo())
assert(L:Redo() and T.db.unit.point[4] == 11 and T.db.two.point[4] == 200.5)
assert(L:Undo())
-- Dragging an already selected member keeps the selection; the UNION snaps to outsiders.
cursorX,cursorY,alt = 0,0,false
m.scripts.OnMouseDown(m,"LeftButton"); m.scripts.OnDragStart(m)
cursorX = 267; m.scripts.OnUpdate(m); m.scripts.OnDragStop(m)
assert(T.db.unit.point[4] == 280 and T.db.two.point[4] == 335)
assert(#M:Selection() == 2 and L:Undo() and T.db.unit.point[4] == 10 and T.db.two.point[4] == 200)
-- Alt bypass applies to the group and preserves its spacing.
cursorX,cursorY,alt = 0,0,true
m.scripts.OnDragStart(m); cursorX = 267; m.scripts.OnUpdate(m); m.scripts.OnDragStop(m)
assert(T.db.unit.point[4] == 277 and T.db.two.point[4] == 333.5)
assert(L:Undo())
assert(M:GroupAction("move",10000,0))
assert(T.db.unit.point[4] == 530 and T.db.two.point[4] == 460)
assert(L:Undo())
-- Alignment uses the group's bounds and affects both frames in one history step.
panel.groupButtons[3].scripts.OnClick(panel.groupButtons[3])
assert(M.GetBounds(target)[2] == 480 and M.GetBounds(second)[2] == 480)
assert(L:Undo() and T.db.unit.point[4] == 10 and T.db.two.point[4] == 200)
shift = true; o.scripts.OnMouseDown(o,"LeftButton"); shift = false
assert(#M:Selection() == 3 and panel.groupButtons[7].enabled)
assert(M:GroupAction("spaceX"))
assert(T.db.unit.point[4] == 10 and T.db.two.point[4] == 195 and T.db.three.point[4] == 750)
assert(L:Undo() and T.db.two.point[4] == 200)
-- Impossible spacing fails without any movement or changes to the redo branch.
assert(not M:GroupAction("spaceY") and L:CanRedo())
assert(T.db.unit.point[5] == 50 and T.db.two.point[5] == 25)
assert(M:GroupAction("centerScreen"))
local union = M.GroupBounds({M.GetBounds(target),M.GetBounds(second),M.GetBounds(third)})
assert((union[1]+union[2])/2 == 500 and (union[3]+union[4])/2 == 400)
assert(L:Undo())
-- Combat rejects the entire group, including its unprotected member.
combat = true
assert(not M:GroupAction("move",5,0) and T.db.three.point[4] == 750)
combat = false
-- Interrupted group drag saves once after combat; no action can interleave before save.
cursorX,cursorY = 0,0
m.scripts.OnDragStart(m); cursorX = 20; m.scripts.OnUpdate(m)
combat = true; m.scripts.OnUpdate(m)
assert(m.pendingMove and n.pendingMove and o.pendingMove)
combat = false; assert(not L:CanUndo() and not M:GroupAction("move",1,0))
queued[#queued]()
assert(not m.pendingMove and not n.pendingMove and not o.pendingMove)
assert(T.db.unit.point[4] == 30 and T.db.two.point[4] == 210 and T.db.three.point[4] == 770)
assert(L:Undo() and T.db.unit.point[4] == 10 and T.db.two.point[4] == 200 and T.db.three.point[4] == 750)
-- Dropdown toggles selection without requiring a reachable frame hitbox.
local chooser
for _, frame in ipairs(frames) do if frame.menu then chooser = frame; break end end
menuItems = {}; chooser.menu()
assert(#menuItems == 3 and menuItems[2].checked and menuItems[2].keepShownOnClick)
menuItems[2].func(); assert(#M:Selection() == 2 and not M.selected[n])
menuItems[2].func(); assert(#M:Selection() == 3)
-- Hidden frames leave the selection; Clear and lock discard transient grouping.
T.db.two.enabled = false; M:Refresh()
assert(#M:Selection() == 2 and not M.selected[n])
M:ClearSelection(); assert(#M:Selection() == 0 and not panel.arrows[1].enabled)
M:Select(m); M:Select(o,true)
T.db.locked = true; M:Refresh(); assert(#M:Selection() == 0)
T.db.locked = false; M:Refresh(); assert(#M:Selection() == 1)
print("PASS: group selection, mixed-scale nudges, drag snapping, alignment, spacing and atomic history")

-- Resizing blocks the whole group, and a queued old-profile save cannot touch a new one.
T.db.two.enabled = true; M:Refresh(); M:Select(n,true)
m.sizing = true
local before = T.db.unit.point[4]
assert(not M:GroupAction("left") and T.db.unit.point[4] == before)
m.sizing = nil
cursorX,cursorY = 0,0
m.scripts.OnDragStart(m); cursorX = 10; m.scripts.OnUpdate(m)
combat = true; m.scripts.OnUpdate(m); combat = false
assert(m.pendingMove and n.pendingMove)
T.db = {locked = false, unit = {point = Point(100,100)}, two = {point = Point(300,100)}, three = {point = Point(750,100)}}
T:ApplySettings(); queued[#queued]()
assert(T.db.unit.point[4] == 100 and T.db.two.point[4] == 300)
assert(not m.pendingMove and not n.pendingMove and not L:CanUndo())
assert(#M:Selection() == 1)
print("PASS: group resize guard and interrupted save profile isolation")
