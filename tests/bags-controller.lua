local module
local T = {
    Bags = {},
    db = { bags = { collapsed = {}, customCategories = {}, mode = "CATEGORIES", showEmpty = true } },
    NewModule = function(_, _, def) module = def end,
    CharacterKey = function() return "Tester - Realm" end,
    RunOOC = function(_, fn) fn() end,
    Print = function() end,
}
function UnitName() return "Tester" end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end
StaticPopupDialogs = {}
local popupShown
function StaticPopup_Show(name) popupShown = name end
TempusDB = { bagOwners = {} }

assert(loadfile("Modules/Bags/Bags.lua"))("Tempus", T)
local B = T.Bags
B.db = T.db.bags
B.client = {
    EnabledConflicts = function() return { { label = "Bagnon", addons = { "Bagnon" } } } end,
    ToggleCarried = function() return true end,
}
B:Start()
assert(B.state == "PENDING" and popupShown == "TEMPUS_BAG_CONFLICT", "conflicts defer frame ownership")
B:ChooseExternal()
assert(B.state == "INACTIVE", "external choice leaves Tempus dormant")
assert(TempusDB.bagOwners["Tester - Realm"].choice == "EXTERNAL", "ownership choice is stored per character")

local resumed, reloads = 0, 0
TempusDB.bagOwners["Tester - Realm"] = { choice = "TEMPUS", families = { "Bagnon" } }
function ReloadUI() reloads = reloads + 1 end
B.state = "UNRESOLVED"
B.client = {
    EnabledConflicts = function() return { { label = "Bagnon", addons = { "Bagnon" } } } end,
    DisableConflicts = function() resumed = resumed + 1; return true end,
}
B:Start()
assert(B.state == "PENDING" and resumed == 1 and reloads == 1,
    "a saved Tempus choice resumes disabling without prompting again")

-- A client that refuses the disable must leave Tempus dormant and explain it, not reload or retry.
reloads, popupShown = 0, nil
B.state = "UNRESOLVED"
B.client = {
    EnabledConflicts = function() return { { label = "Bagnon", addons = { "Bagnon", "BagBrother" } } } end,
    DisableConflicts = function() return false, "Bagnon is still enabled for Tester" end,
}
B:Start()
assert(B.state == "INACTIVE" and reloads == 0 and popupShown == "TEMPUS_BAG_DISABLE_FAILED",
    "a refused disable shows the manual-steps popup instead of reloading")
assert(StaticPopupDialogs.TEMPUS_BAG_DISABLE_FAILED.text:find("Bagnon, BagBrother", 1, true),
    "the popup names every addon to disable by hand")
StaticPopupDialogs.TEMPUS_BAG_DISABLE_FAILED.OnCancel()
assert(TempusDB.bagOwners["Tester - Realm"].choice == "EXTERNAL", "keeping the other addon is remembered")

local claimed = 0
local function Window()
    local shown = false
    return {
        frame = {
            IsShown = function() return shown end,
            Show = function() shown = true end,
            Hide = function() shown = false end,
        },
        ApplyPoint = function() end,
        Render = function() end,
    }
end
B.state, B.carriedWindow, B.bankWindow, B.events = "UNRESOLVED", nil, nil, nil
B.Window = { New = Window }
B.Inventory = {
    Snapshot = function(storage) return { storage = storage, revision = 1, slots = {}, byKey = {}, used = 0, capacity = 0 } end,
    Project = function() return { sections = {}, emptyResult = true } end,
}
B.client = {
    EnabledConflicts = function() return {} end,
    Claim = function(_, sync) claimed = claimed + 1; sync(false); return true end,
    Locations = function() return {} end,
    Read = function() end,
}
B:Start()
assert(B.state == "CLAIMED" and claimed == 1 and B.carriedWindow and B.bankWindow,
    "conflict-free startup claims frames and creates both windows")

-- Sections fold per character; custom categories move an item between groups and persist in the db.
do
    local renders, originalRender = 0, B.Render
    B.Render = function() renders = renders + 1 end
    B:ToggleSection("EQUIPMENT")
    assert(B:Collapsed().EQUIPMENT == true and renders == 2, "folding a section is stored and redraws both windows")
    B:ToggleSection("EQUIPMENT")
    assert(B:Collapsed().EQUIPMENT == nil, "unfolding clears the entry")

    B:AssignCategory(500, "Fishing")
    assert(B:CustomItems()[500] == "Fishing", "assigned item maps to its category")
    B:AssignCategory(500, "Cooking")
    assert(B:CustomItems()[500] == "Cooking" and B.db.customCategories.Fishing == nil,
        "reassigning moves the item and drops the emptied category")
    B:AssignCategory(500, nil)
    assert(B:CustomItems()[500] == nil and next(B.db.customCategories) == nil, "removing clears custom membership")

    B.bagFilter = nil
    B:SetBagFilter(2)
    assert(B.bagFilter == 2, "bag filter selects a bag")
    B:SetBagFilter(2)
    assert(B.bagFilter == nil, "clicking the same bag again clears the filter")
    B:SetFilter("CARRIED", "GEAR")
    assert(B.filter.CARRIED == "GEAR" and B:ProjectOptions("CARRIED").filter == "GEAR", "filter chip state feeds the projection")
    B.Render = originalRender
end

print("PASS: bag ownership is exclusive and character-local")
