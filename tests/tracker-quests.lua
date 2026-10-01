C_Timer = C_Timer or {After = function() end}
-- Run from the addon directory: luajit tests/tracker-quests.lua
local noop = function() end
local function Frame(parent)
    local f = {parent = parent, scripts = {}, shown = true, text = "", height = 40}
    for _, name in ipairs({"SetPoint", "SetFontObject", "SetAutoFocus", "SetTextColor", "SetWordWrap",
        "ClearFocus", "SetHighlightTexture", "SetVertexColor", "RegisterEvent"}) do f[name] = noop end
    function f:SetText(text) self.text = text; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
    function f:GetText() return self.text end
    function f:SetShown(shown) self.shown = not not shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetHeight() return self.height end
    function f:SetHeight(height) self.height = height end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:GetHighlightTexture() return self end
    function f:ClearAllPoints() self.reanchored = true end
    return f
end
function CreateFrame(_, _, parent) return Frame(parent) end
function UnitName() return "Allie" end
function GetRealmName() return "Realm" end
local combat, queued = false
function InCombatLockdown() return combat end
function hooksecurefunc(obj, key, fn)
    local original = obj[key]
    obj[key] = function(...) original(...); fn(...) end
end
TempusDB = {}
local panelUpdates = 0
local T = {
    Skins = { EditBox = noop, UpdateTrackerPanel = function() panelUpdates = panelUpdates + 1 end },
    Style = { C = {muted = {0.5, 0.5, 0.5}}, Text = Frame },
    RunOOC = function(_, fn) queued = fn end,
}
assert(loadfile("Modules/Skins/Quests.lua"))("Tempus", T)
local entries = {
    {title = "Westfall", isHeader = true},
    {title = "The Defias Brotherhood", questID = 101},
    {title = "Redridge Mountains", isHeader = true},
    {title = "Blackrock Menace", questID = 202},
    {title = "Untracked Quest", questID = 203},
}
T.QuestFilters.Entries = function() return entries end
assert(loadfile("Modules/Skins/TrackerQuests.lua"))("Tempus", T)
local F = T.TrackerQuestFilters
local module = Frame()
module.ContentsFrame = Frame(module)
module.headerHeight = 25
local a, b, unrelated = Frame(), Frame(), Frame()
a.id, b.id, unrelated.id = 101, 202, 900
a.used, b.used = true, true
module.usedBlocks = {QuestTemplate = {[101] = a, [202] = b, [900] = unrelated}}
function module:EndLayout() end
function module:UpdateHeight() self:SetHeight(self.contentsHeight) end
function module:MarkDirty() self.dirty = true end
local watched = {
    {title = "The Defias Brotherhood", GetID = function() return 101 end},
    {title = "Blackrock Menace", GetID = function() return 202 end},
}
function module:EnumQuestWatchData(callback)
    for _, quest in ipairs(watched) do if not callback(self, quest) then return end end
end
F:Attach(module)
F:Attach(module)
local view = module.tempusQuestZones
module:EndLayout()
assert(view.headers[1].text:GetText() == "- Westfall (1)")
assert(view.headers[2].text:GetText() == "- Redridge Mountains (1)")
assert(a.shown and b.shown and a.reanchored and b.reanchored)
assert(module.height == 205 and panelUpdates == 1)
view.headers[1].scripts.OnClick(view.headers[1])
assert(module.dirty and F:CollapsedZones().Westfall)
module:EndLayout()
assert(not a.shown and b.shown and module.height == 157)
assert(view.headers[1].text:GetText() == "+ Westfall (1)")
view.search:SetText("defas")
module:EndLayout()
assert(a.shown and not b.shown and module.height == 131)
assert(F:CollapsedZones().Westfall, "search must preserve saved collapse state")
view.search.scripts.OnEscapePressed()
module:EndLayout()
assert(not a.shown and b.shown and view.search:GetText() == "")
view.search:SetText("red mount")
local first
module:EnumQuestWatchData(function(_, quest) first = quest:GetID(); return false end)
assert(first == 202, "search must prioritize matches beyond the native height cutoff")
module:EndLayout()
assert(#F.Groups(entries, {[101] = a, [202] = b}, "red mount") == 1)
assert(b.shown and not a.shown)
view.search:SetText("untracked")
module:EndLayout()
assert(view.empty.shown and not a.shown and not b.shown and module.height == 81)
view.search:SetText("")
module.isCollapsed = true
module:EndLayout()
assert(not view.search.shown and not view.headers[1].shown)
module.isCollapsed = false
module:EndLayout()
assert(view.search.shown and view.headers[1].shown)
combat = true
local before = module.height
view.search:SetText("no results")
module:EndLayout()
assert(module.height == before and queued)
combat = false
queued()
module:EndLayout()
assert(view.empty.shown)
print("PASS: tracker zone headings, collapse persistence, fuzzy search, objectives retained, tracked-only results, panel height, global collapse, combat deferral")

ObjectiveTrackerFrame = {ForEachModule = function(_, callback) callback(module) end}
QuestObjectiveTracker = nil
QuestLogFrame = {tempusQuestFilters = nil}
T.Skins:InitTrackerQuestFilters()
assert(module.tempusQuestZones == view)
assert(QuestLogFrame.tempusQuestFilters == nil)
assert(F.events.scripts.OnEvent)
print("PASS: initialization finds the persistent HUD tracker without touching the L-key quest window")
