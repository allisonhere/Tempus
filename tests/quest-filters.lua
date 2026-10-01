-- Run from the addon directory: luajit tests/quest-filters.lua
local noop = function() end
local frames = {}
local function Frame(parent)
    local f = { parent = parent, scripts = {}, shown = true, text = "" }
    for _, method in ipairs({"SetSize", "SetPoint", "SetHeight", "SetWidth", "SetFrameLevel", "SetAllPoints",
        "EnableMouse", "EnableMouseWheel", "SetAutoFocus", "SetFontObject", "SetWordWrap",
        "SetTextColor", "SetHighlightTexture", "SetVertexColor", "RegisterForClicks", "RegisterEvent", "ClearFocus"}) do
        f[method] = noop
    end
    function f:SetText(text) self.text = text; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
    function f:GetText() return self.text end
    function f:GetHeight() return 104 end
    function f:GetWidth() return 300 end
    function f:GetFrameLevel() return 1 end
    function f:SetShown(shown) self.shown = not not shown end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:HookScript(event, fn) self.scripts[event] = fn end
    function f:GetHighlightTexture() return self end
    frames[#frames + 1] = f
    return f
end
function CreateFrame(_, _, parent) return Frame(parent) end
function UnitName() return "Allie" end
function GetRealmName() return "Realm" end
TempusDB = {}
local entries = {
    {"Westfall", 0, nil, true},
    {"The Defias Brotherhood", 18, nil, false, false, nil, nil, 101},
    {"Redridge Mountains", 0, nil, true},
    {"Blackrock Menace", 20, nil, false, false, nil, nil, 202},
    {"Blackrock Bounty", 21, nil, false, false, nil, nil, 203},
}
function GetNumQuestLogEntries() return #entries end
function GetQuestLogTitle(index) return unpack(entries[index], 1, 16) end
local selected
function QuestLog_SetSelection(index) selected = index end
function QuestLog_Update() end
local T = {Skins = {Button = noop, EditBox = noop}, Style = {
    C = {bg = {0, 0, 0}, text = {1, 1, 1}, muted = {0.5, 0.5, 0.5}},
    Text = function(parent) return Frame(parent) end, Backdrop = noop,
}}
assert(loadfile("Modules/Skins/Quests.lua"))("Tempus", T)
local Q = T.QuestFilters
assert(Q.Matches("The Defias Brotherhood", "dfbr"))
assert(Q.Matches("The Defias Brotherhood", "defas"))
assert(Q.Matches("Redridge Mountains", "red mount"))
assert(Q.Matches("A 100% Problem", "100%"))
assert(not Q.Matches("The Defias Brotherhood", "blackrock"))
assert(not Q.Matches("Blackrock Menace", "blackrock defias"))
local filtered = Q.Filter(Q:Entries(), {}, "red mount")
assert(#filtered == 3 and filtered[2].questID == 202 and filtered[3].index == 5)
filtered = Q.Filter(Q:Entries(), {Westfall = true}, "defias")
assert(#filtered == 0)
print("PASS: fuzzy matching, typos, literal punctuation, multiword zone matches, hidden zones")

local parent, list = Frame(), Frame()
list.shown = false -- Classic hides this frame when no scrollbar is needed.
Q:Attach(parent, list, false)
Q:Attach(parent, list, false)
assert(#Q.views == 1)
local view = Q.views[1]
assert(view.overlay.parent == parent and not view.overlay.shown)
view.search:SetText("blackrock")
assert(view.overlay.shown and view.rows[2].entry.index == 4)
view.rows[2].scripts.OnClick(view.rows[2], "LeftButton")
assert(selected == 4)
view.rows[1].scripts.OnClick(view.rows[1], "RightButton")
assert(Q:HiddenZones()["Redridge Mountains"] and #view.list == 0 and view.empty.shown)
view.search.scripts.OnEscapePressed()
assert(view.search:GetText() == "" and #view.list == 2)
view.zones = true
Q:Render(view)
assert(#view.list == 2)
view.rows[1].scripts.OnClick(view.rows[1], "LeftButton")
assert(not Q:HiddenZones()["Redridge Mountains"])
view.zones = false
Q:Render(view)
assert(not view.overlay.shown)
print("PASS: real quest indices, zone hide/restore, empty results, Escape, Classic list visibility, repeated setup")

-- Newer clients can retain legacy wrappers whose underlying API is gone.
local legacyCount, legacyTitle = GetNumQuestLogEntries, GetQuestLogTitle
GetNumQuestLogEntries = function() error("attempt to call a nil value") end
GetQuestLogTitle = function() error("legacy title API must not be called") end
C_QuestLog = {
    GetNumQuestLogEntries = function() return #entries, 3 end,
    GetInfo = function(index)
        local e = entries[index]
        return {title = e[1], level = e[2], isHeader = e[4], questID = e[8], isHidden = e[16]}
    end,
}
local modern = Q:Entries()
assert(#modern == 5 and modern[1].title == "Westfall" and modern[1].isHeader)
assert(modern[4].index == 4 and modern[4].questID == 202)
view.search:SetText("blackrock")
assert(#view.list == 3 and view.rows[2].entry.questID == 202)
view.rows[1].scripts.OnClick(view.rows[1], "RightButton")
assert(#view.list == 0)
Q:HiddenZones()["Redridge Mountains"] = nil
C_QuestLog.GetInfo = function(index)
    if index == 4 then return nil end
    local e = entries[index]
    return {title = e[1], level = e[2], isHeader = e[4], questID = e[8]}
end
modern = Q:Entries()
assert(#modern == 4 and modern[4].index == 5 and modern[4].questID == 203)
C_QuestLog = {}
GetNumQuestLogEntries, GetQuestLogTitle = legacyCount, legacyTitle
assert(#Q:Entries() == 5)
print("PASS: modern APIs bypass broken legacy wrappers, preserve quest indices, handle absent entries, retain Classic support")
