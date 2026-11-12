local combat, skin = false, true
UIParent = {}
function InCombatLockdown() return combat end
local events
function CreateFrame()
    events = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.event = fn end }
    return events
end
local hooks = 0
function hooksecurefunc(name, fn)
    hooks = hooks + 1
    local original = _G[name]
    _G[name] = function(...) original(...); fn(...) end
end
local panels = {}
local SK = {
    On = function() return skin end,
    Try = function(_, _, fn, ...) fn(...) end,
    Strip = function(_, frame) frame.stripped = true end,
    Panel = function(_, frame)
        panels[frame] = (panels[frame] or 0) + 1
        return { SetEdgeColor = function() end }
    end,
}
local T = { Skins = SK, accent = { 0.2, 0.8, 1 }, db = {}, Style = {
    C = { card = {} }, ApplyFont = function() end, BarTexture = function() return "tempus" end,
} }
local vote = function() end
local function Row()
    local row = { NeedButton = { OnClick = vote }, GreedButton = {}, PassButton = {}, Name = {},
        IconFrame = { Icon = { SetTexCoord = function() end }, Count = {} },
        Timer = { SetStatusBarTexture = function(self, texture) self.texture = texture end },
        shown = true, protected = false }
    function row:IsShown() return self.shown end
    function row:IsProtected() return self.protected end
    function row:ClearAllPoints() self.clears = (self.clears or 0) + 1 end
    function row:SetPoint(...) self.point = { ... } end
    function row:SetClampedToScreen(value) self.clamped = value end
    function row:HookScript(_, fn) self.onShow = fn end
    return row
end
GroupLootFrame1, GroupLootFrame2 = Row(), Row()
GroupLootContainer = { maxIndex = 4, reservedSize = 100, rollFrames = { [1] = GroupLootFrame1, [3] = GroupLootFrame2 } }
function GroupLootContainer_Update() end
assert(loadfile("Modules/Skins/LootRolls.lua"))("Tempus", T)
SK:InitLootRolls(); SK:InitLootRolls()
assert(hooks == 1, "layout hook must only be installed once")
assert(GroupLootFrame1.point[1] == "CENTER" and GroupLootFrame1.point[2] == UIParent)
assert(GroupLootFrame1.point[5] == 54 and GroupLootFrame2.point[5] == -54, "stack must be centered despite index gaps")
assert(panels[GroupLootFrame1] == 1 and GroupLootFrame1.Timer.texture == "tempus")
assert(GroupLootFrame1.NeedButton.OnClick == vote, "native voting script must survive skinning")
GroupLootFrame2.shown = false
GroupLootContainer_Update(GroupLootContainer)
assert(GroupLootFrame1.point[5] == 0, "single roll should return to screen center")
combat, GroupLootFrame1.protected = true, true
local before = GroupLootFrame1.clears
GroupLootContainer_Update(GroupLootContainer)
assert(GroupLootFrame1.clears == before, "protected frames cannot move during combat")
combat = false; events:event()
assert(GroupLootFrame1.clears > before, "deferred centering must resume after combat")
skin = false; before = GroupLootFrame1.clears
GroupLootContainer_Update(GroupLootContainer)
assert(GroupLootFrame1.clears == before, "stock skin must retain native layout")
skin = true
GroupLootFrame3 = Row()
GroupLootFrame3.LootButtonContainer = { NeedButton = { OnClick = vote }, GreedButton = {}, PassButton = {} }
function GroupLootFrame3:GetFrameLevel() return 5 end
function GroupLootFrame3.Timer:SetFrameLevel(level) self.level = level end
SK:InitLootRolls()
assert(GroupLootFrame3.tempusRollSkin and GroupLootFrame3.onShow, "late-loaded roll frames must be skinned")
assert(panels[GroupLootFrame3.LootButtonContainer.NeedButton] == 1, "Forever's nested roll buttons must be skinned")
GroupLootFrame3.Timer.level = 4
GroupLootFrame3:onShow()
assert(GroupLootFrame3.Timer.level == 6, "native OnShow must not leave the countdown behind the panel")
print("PASS: centered roll stacks, native votes, themed panels, combat deferral, stock skin and late loading")
