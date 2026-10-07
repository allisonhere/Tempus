-- Smoke test: build the bag window and bag bar against a permissive fake frame API and render real
-- projections through them. Catches nil-index and typo errors that would only appear in game.
local widgets = {}
local verbs = { "Set", "Get", "Is", "Show", "Hide", "Clear", "Register", "Enable", "Create", "Hook", "Start",
    "Stop", "Add", "Disable", "Lower", "Raise", "Has", "Update", "Fire", "Play", "Break" }
local numeric = { GetWidth = 100, GetHeight = 100, GetFrameLevel = 1, GetID = 0, GetVerticalScroll = 0,
    GetEffectiveScale = 1, GetLeft = 0, GetBottom = 0 }

local function Widget(kind)
    local obj = { kind = kind, shown = true, text = "", scripts = {}, points = {} }
    widgets[#widgets + 1] = obj
    local methods = {}
    function methods.SetText(self, text) self.text = tostring(text) end
    function methods.GetText(self) return self.text end
    function methods.SetShown(self, on) self.shown = on and true or false end
    function methods.Show(self) self.shown = true end
    function methods.Hide(self) self.shown = false end
    function methods.IsShown(self) return self.shown end
    function methods.SetScript(self, name, fn) self.scripts[name] = fn end
    function methods.HookScript(self, name, fn) self.scripts["hook" .. name] = fn end
    function methods.SetID(self, id) self.id = id end
    function methods.GetID(self) return self.id or 0 end
    function methods.GetNormalTexture() return nil end
    function methods.CreateTexture() return Widget("Texture") end
    function methods.CreateFontString() return Widget("FontString") end
    function methods.GetParent(self) return self.parent end
    return setmetatable(obj, { __index = function(t, key)
        if methods[key] then return methods[key] end
        if numeric[key] then return function() return numeric[key] end end
        for _, verb in ipairs(verbs) do
            if key == verb or (key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("%u")) then
                return function(self) return self end
            end
        end
    end })
end

function CreateFrame(kind, _, parent)
    local frame = Widget(kind)
    frame.parent = parent
    return frame
end
UIParent = Widget("Frame")
GameTooltip = Widget("Frame")
ITEM_QUALITY_COLORS = { [0] = { r = 0.6, g = 0.6, b = 0.6 }, [1] = { r = 1, g = 1, b = 1 },
    [2] = { r = 0.1, g = 1, b = 0.1 }, [3] = { r = 0, g = 0.4, b = 1 } }

local T = { Bags = {}, accent = { 0.2, 0.7, 1 } }
T.Style = {
    C = { card = { 0.1, 0.1, 0.1, 1 }, muted = { 0.5, 0.5, 0.5 }, text = { 0.9, 0.9, 0.9 } },
    Backdrop = function() end,
    Text = function() return Widget("FontString") end,
    Tex = function() return Widget("Texture") end,
    CreateBorder = function() return Widget("Border") end,
}
T.UI = {
    FlatButton = function(parent, label) local b = Widget("Button"); b.text = Widget("FontString"); b.label = label; return b end,
    StyledEditBox = function() return Widget("EditBox") end,
}
T.Movers = { SavePoint = function() end }
for _, file in ipairs({ "Inventory", "BagBar", "Window" }) do
    assert(loadfile("Modules/Bags/" .. file .. ".lua"))("Tempus", T)
end
local Bags, I = T.Bags, T.Bags.Inventory

local client = {
    env = { BACKPACK_CONTAINER = 0 },
    CreateItemButton = function(_, parent) local b = Widget("Button"); b.parent = parent; return b end,
    CreateProxy = function(_, parent, id) local p = Widget("Frame"); p.parent = parent; p.id = id; return p end,
    BindItemButton = function(_, button, record) button:SetID(record.location.slot) end,
    Cooldown = function(_, location) if location.slot == 1 then return 100, 20 end end,
    EquippedLevel = function(_, loc) return loc == "INVTYPE_WEAPON" and 40 or nil end,
    Money = function() return 123456 end,
    Currencies = function() return { { name = "Badge", quantity = 12, icon = 1 } } end,
    ContainerIDs = function() return { 0, 1, 2 } end,
    BagName = function(_, id) return "Bag " .. id end,
    BagIcon = function(_, id) return id == 0 and "backpack" or nil end,
    IsReagentAvailable = function() return false end,
    ShowTooltip = function() end,
}
local owner = {
    client = client, filter = { CARRIED = "ALL", BANK = "ALL" }, bankStorage = "BANK",
    db = { mode = "CATEGORIES", columns = 6, itemSize = 36, spacing = 4, showEmpty = true, showNew = true,
        showItemLevel = true, showUpgrades = true, showCooldowns = true, showCurrencies = true,
        showBagBar = true, showFilters = true, sortItems = true, collapsed = {}, customCategories = {},
        point = { "CENTER", "UIParent", "CENTER", 0, 0 } },
}
local calls = {}
for _, name in ipairs({ "Close", "ToggleView", "Sort", "ToggleTagMode", "SetQuery", "SetFilter",
    "SetBagFilter", "SetHoverBag", "ToggleSection", "ShowCategoryMenu", "SetBankStorage", "ShowBankManagement" }) do
    owner[name] = function(_, ...) calls[name] = { ... } end
end
Bags.Window = Bags.Window

local locations, data = {}, {
    ["CARRIED:0:1"] = { itemID = 1, name = "Better Sword", classID = 2, equipLoc = "INVTYPE_WEAPON", quality = 3,
        itemLevel = 60, bindType = 2, count = 1, icon = 1 },
    ["CARRIED:0:2"] = { itemID = 2, name = "Potion", classID = 0, quality = 1, count = 5, icon = 2, isNew = true },
    ["CARRIED:0:3"] = { itemID = 3, name = "Broken Helm", classID = 4, equipLoc = "INVTYPE_HEAD", quality = 2,
        itemLevel = 20, durability = 0, maxDurability = 50, icon = 3 },
}
for slot = 1, 4 do locations[#locations + 1] = { storage = "CARRIED", container = 0, slot = slot } end
local snapshot = I.Snapshot("CARRIED", locations, function(l) return data[I.Key(l)] end)

local window = Bags.Window.New(owner, "CARRIED", "Bags", "point")
local bank = Bags.Window.New(owner, "BANK", "Bank", "bankPoint")
assert(window.bagBar and not bank.bagBar and bank.bankRow, "bag bar is carried-only, bank tabs are bank-only")
assert(#window.chips == #I.filters, "one chip per filter")

local function RenderMode(mode, opts)
    owner.db.mode = mode
    local projection = I.Project(snapshot, mode, "", true, opts)
    window:Render(snapshot, projection)
    return projection
end

RenderMode("GRID", { sort = true })
RenderMode("CATEGORIES", { sort = true })
assert(window.headers[1] and window.headers[1].label.text:find("%(%d+%)"), "section header shows its count")
assert(window.footer.text:find("3 / 4"), "footer shows used and total slots")
assert(window.wealth.text:find("12"), "currency count is in the footer")
assert(window.wealth.text:find("|cffffd24d12|rg"), "money is formatted as gold/silver/copper")

local sword = window.buttons["CARRIED:0:1"]
assert(sword.tempusUp.shown, "better weapon than the equipped one gets an upgrade mark")
assert(sword.tempusLevel.text == "60" and sword.tempusBoE.text == "BoE", "item level and BoE tag")
assert(not window.buttons["CARRIED:0:3"].tempusUp.shown, "no equipped comparison means no arrow")
assert(window.buttons["CARRIED:0:2"].tempusNew.shown, "new items are marked")

-- Section fold from the header, tag overlay, bag highlight and chips.
window.headers[1].scripts.OnClick(window.headers[1])
assert(calls.ToggleSection and calls.ToggleSection[1] == window.headers[1].sectionKey, "header click folds its section")
window.chips[2].scripts.OnClick = nil
owner.tagMode = true
RenderMode("GRID")
assert(window.buttons["CARRIED:0:1"].tempusTag.shown, "tag overlays appear in tag mode")
assert(not window.buttons["CARRIED:0:4"].tempusTag.shown, "empty slots cannot be tagged")
window.buttons["CARRIED:0:1"].tempusTag.scripts.OnClick(window.buttons["CARRIED:0:1"].tempusTag)
assert(calls.ShowCategoryMenu, "clicking a tagged item opens the category menu")
owner.tagMode = false

owner.hoverBag = 2
window:ApplyHighlight()
owner.hoverBag = nil
window:ApplyHighlight()

owner.db.showFilters, owner.db.showBagBar = false, false
RenderMode("GRID")
assert(not window.chipRow.shown and not window.bagBar.frame.shown, "chips and bag bar can be switched off")

bank:Render(snapshot, I.Project(snapshot, "GRID", "", true))
assert(Bags.Window.FormatMoney(0) == "|cffc87f4a0|rc" and Bags.Window.FormatMoney(10101):find("1|rg"), "money formatting")

print("PASS: bag window renders marks, sections, footer and bag bar without errors")
