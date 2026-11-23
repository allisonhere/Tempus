local module
time = function() return 2000000 end
GetRealmName = function() return 'Realm' end
UnitFactionGroup = function() return 'Horde' end
UnitClass = function() return 'Warrior', 'WARRIOR' end
local level, money = 60, 10 ^ 9
UnitLevel = function() return level end
GetMoney = function() return money end
TempusDB = {}
C_Timer = { After = function(_, fn) fn() end }
local T = { accent = { 0.2, 0.7, 1 }, db = { market = { staleDays = 3, upgradeMinGain = 1, upgradeAffordable = false } },
    Num = function(v) return type(v) == 'number' end, issecret = function() return false end,
    ModuleEnabled = function() return true end, Print = function() end,
    NewModule = function(_, _, def) module = def end }
T.UI = { StyledEditBox = function(parent) return CreateFrame('EditBox', nil, parent) end }
assert(loadfile('Modules/Bags/Client.lua'))('Tempus', T)
assert(loadfile('Modules/Market/Market.lua'))('Tempus', T)
assert(loadfile('Modules/GearAdvisor/EquipRules.lua'))('Tempus', T)
assert(loadfile('Modules/GearAdvisor/Weights.lua'))('Tempus', T)
assert(loadfile('Modules/GearAdvisor/Scoring.lua'))('Tempus', T)
assert(loadfile('Modules/GearAdvisor/Owned.lua'))('Tempus', T)
assert(loadfile('Modules/GearAdvisor/Verdicts.lua'))('Tempus', T)
assert(loadfile('Modules/GearAdvisor/Budget.lua'))('Tempus', T)
assert(loadfile('Modules/GearAdvisor/Confidence.lua'))('Tempus', T)
assert(loadfile('Modules/Market/Upgrades.lua'))('Tempus', T)
local M = T.Market
local G = 10000

-- class, sub, loc, ilvl, minLevel (nil ilvl = item data not cached)
local info = {
    [1] = { 4, 4, 'INVTYPE_HEAD', 60, 50 },      -- plate helm +10 over 50, 10g
    [2] = { 4, 4, 'INVTYPE_HEAD', 52, 40 },      -- +2, 1g
    [3] = { 4, 1, 'INVTYPE_CHEST', 70, 40 },     -- cloth: warrior cannot use
    [4] = { 4, 4, 'INVTYPE_CHEST', 55, 40 },     -- empty slot: +55, 5g
    [5] = { 4, 4, 'INVTYPE_HEAD', 50, 40 },      -- +0: not an upgrade
    [6] = { 2, 8, 'INVTYPE_2HWEAPON', 45, 40 },  -- 2h sword +5 over 40, 2g
    [7] = { 2, 19, 'INVTYPE_RANGEDRIGHT', 90, 40 }, -- wand: not a warrior weapon
    [8] = { 4, 4, 'INVTYPE_HEAD', 99, 61 },      -- needs level 61
    [9] = { 4, 4, 'INVTYPE_LEGS', nil, 40 },     -- not cached yet
    [10] = { 0, 0, '', 5, 1 },                   -- not gear
    [11] = { 2, 2, 'INVTYPE_RANGED', 30, 40 },   -- bow, compared with the ranged slot, 3g
    [12] = { 4, 0, 'INVTYPE_FINGER', 58, 40 },   -- ring: lower of two slots (rings 50 and empty -> 0)
    [13] = { 4, 6, 'INVTYPE_SHIELD', 48, 40 },   -- shield: warriors can
}
local worn = { [1] = 50, [16] = 40, [18] = 25, [11] = 50 }   -- slot -> ilvl; 12 (second ring) empty
local requests = {}
C_Item = {
    GetItemInfoInstant = function(id) local i = info[id]; if i then return id, 'x', 'y', i[3], 'icon', i[1], i[2] end end,
    GetItemInfo = function(id) local i = info[id]; if i and i[4] then return 'n' .. id, 'link' .. id, 1, i[4], i[5] end end,
    GetDetailedItemLevelInfo = function(a)
        if type(a) == 'string' then return tonumber(a:match('worn:(%d+)')) and worn[tonumber(a:match('worn:(%d+)'))] end
    end,
    RequestLoadItemDataByID = function(id) requests[#requests + 1] = id end,
}
GetInventoryItemLink = function(_, slot) return worn[slot] and ('worn:' .. slot) or nil end

local function Seed(prices)
    TempusDB.auctions = { ['Realm-Horde'] = { scanned = 2000000, items = {} } }
    for id, p in pairs(prices) do TempusDB.auctions['Realm-Horde'].items[id] = { p = p, t = 2000000 } end
end
local function Ids(list) local t = {} for _, e in ipairs(list) do t[#t + 1] = e.id end return t end
local function Same(a, b) assert(table.concat(a, ',') == table.concat(b, ','), table.concat(a, ',') .. ' ~= ' .. table.concat(b, ',')) end

Seed({ [1] = 10 * G, [2] = 1 * G, [3] = 1 * G, [4] = 5 * G, [5] = 1 * G, [6] = 2 * G, [7] = 1 * G, [8] = 1 * G,
    [9] = 1 * G, [10] = 1 * G, [11] = 3 * G, [12] = 4 * G, [13] = 6 * G })
local list, pending, requested = M:FindUpgrades()
-- ranked by gain per square root of the price, so a big gain beats a tiny one for pennies
Same(Ids(list), { 12, 4, 13, 6, 1, 11, 2 })
assert(pending == 1 and requested == 1 and requests[1] == 9, 'uncached item counted and requested once')
local byId = {} for _, e in ipairs(list) do byId[e.id] = e end
assert(byId[4].gain == 55 and byId[4].worn == 0, 'empty slot counts as level 0')
assert(byId[12].gain == 58 and byId[12].worn == 0, 'two-slot items compare with the lower slot')
assert(byId[11].gain == 5 and byId[11].worn == 25, 'ranged items compare with the ranged slot')
assert(byId[6].gain == 5 and byId[6].worn == 40)
assert(not byId[3] and not byId[5] and not byId[7] and not byId[8] and not byId[10], 'unusable and non-upgrades dropped')

-- metadata is remembered on the price row so item info is read once
local row = TempusDB.auctions['Realm-Horde'].items[1]
assert(row.c == 4 and row.l == 'INVTYPE_HEAD' and row.s == 4)

-- minimum gain and affordability
T.db.market.upgradeMinGain = 6
Same(Ids((M:FindUpgrades())), { 12, 4, 13, 1 })
T.db.market.upgradeMinGain = 1
T.db.market.upgradeAffordable = true; money = 3 * G
Same(Ids((M:FindUpgrades())), { 6, 11, 2 })
T.db.market.upgradeAffordable = false; money = 10 ^ 9

-- classes: a mage cannot use plate or swords-by-warrior sets; armor unlocks by level
assert(M.CanUse('MAGE', 60, 4, 1, 'INVTYPE_HEAD', 40) and not M.CanUse('MAGE', 60, 4, 4, 'INVTYPE_HEAD', 40))
assert(M.CanUse('MAGE', 60, 2, 19, 'INVTYPE_RANGEDRIGHT') and not M.CanUse('MAGE', 60, 2, 1, 'INVTYPE_2HWEAPON'))
assert(M.CanUse('PALADIN', 39, 4, 3, 'INVTYPE_CHEST') and not M.CanUse('PALADIN', 39, 4, 4, 'INVTYPE_CHEST'))
assert(M.CanUse('PALADIN', 40, 4, 4, 'INVTYPE_CHEST') and not M.CanUse('PALADIN', 40, 4, 3, 'INVTYPE_CHEST'))
assert(M.CanUse('PRIEST', 60, 4, 0, 'INVTYPE_TRINKET') and M.CanUse('PRIEST', 60, 4, 1, 'INVTYPE_CLOAK'))
assert(not M.CanUse('ROGUE', 60, 4, 6, 'INVTYPE_SHIELD') and M.CanUse('SHAMAN', 60, 4, 6, 'INVTYPE_SHIELD'))
assert(M.CanUse('UNKNOWN', 60, 4, 4, 'INVTYPE_HEAD') and M.CanUse('UNKNOWN', 60, 2, 7, 'INVTYPE_WEAPON'), 'unknown classes are not filtered')
assert(not M.CanUse('WARRIOR', 10, 4, 4, 'INVTYPE_HEAD', 20), 'level requirement')

-- stats that improve: only gains, biggest first, capped, empty slot = everything
local stats = {
    new = { ITEM_MOD_STRENGTH_SHORT = 20, ITEM_MOD_STAMINA_SHORT = 30, ITEM_MOD_CRIT_RATING_SHORT = 8, RESISTANCE0_NAME = 500, ITEM_MOD_SPIRIT_SHORT = 4 },
    old = { ITEM_MOD_STRENGTH_SHORT = 12, ITEM_MOD_STAMINA_SHORT = 35, ITEM_MOD_CRIT_RATING_SHORT = 8, RESISTANCE0_NAME = 300 },
}
C_Item.GetItemStats = function(link) return stats[link] end
ITEM_MOD_CRIT_RATING_SHORT = 'Critical Strike Rating'
local gains = M.StatGains('new', 'old', 3)
assert(#gains == 3 and gains[1].label == 'Armor' and gains[1].amount == 200 and gains[2].label == 'Strength' and gains[2].amount == 8
    and gains[3].label == 'Spirit' and gains[3].amount == 4, 'gains only, biggest first')
local all = M.StatGains('new', nil, 8)
assert(#all == 5, 'empty slot: every stat is a gain')
local down = M.StatGains('old', 'new', 3)
assert(#down == 1 and down[1].label == 'Stamina' and down[1].amount == 5, 'a downgrade in most stats lists only what rises')
assert(#M.StatGains('missing', 'old') == 0, 'uncached item has no stats yet')
local both = M.StatGains('old', 'new', 5, true)
local sawLoss
for _, g in ipairs(both) do if g.amount < 0 then sawLoss = true end end
assert(sawLoss, 'withLosses lists stats that drop, including ones the new item lacks')
-- bar sizing and colours
assert(M.BarColor('Agility', 'ITEM_MOD_AGILITY_SHORT') ~= M.BarColor('Stamina', 'ITEM_MOD_STAMINA_SHORT') and M.BarColor('Agi') ~= M.BarColor('Sta') and M.BarColor('Whatever')[1], 'known and unknown stats both coloured')
assert(gains[1].old and gains[1].new == gains[1].old + gains[1].amount, 'gains carry the worn and new values')
assert(all[1].label == 'Armor' and all[2].label == 'Stamina' and all[3].label == 'Strength' and all[4].label == 'Critical Strike Rating'
    and all[5].label == 'Spirit', 'ordered by size, full names')

-- grouping: headers in slot order, items best-first inside each group, robes join chest, ranged variants join
local layout = M.Layout({
    { id = 1, loc = 'INVTYPE_LEGS', score = 9 }, { id = 2, loc = 'INVTYPE_HEAD', score = 8 },
    { id = 3, loc = 'INVTYPE_ROBE', score = 7 }, { id = 4, loc = 'INVTYPE_HEAD', score = 5 },
    { id = 5, loc = 'INVTYPE_CLOAK', score = 4 }, { id = 6, loc = 'INVTYPE_CHEST', score = 3 },
    { id = 7, loc = 'INVTYPE_RANGEDRIGHT', score = 2 }, { id = 8, loc = 'INVTYPE_THROWN', score = 1 },
})
local seq = {}
for _, row in ipairs(layout) do seq[#seq + 1] = row.header and ('#' .. row.header) or row.id end
assert(table.concat(seq, ','):gsub('#', '') == 'Head,2,4,Back,5,Chest,3,6,Legs,1,Ranged,7,8', table.concat(seq, ','))
assert(layout[1].count == 2 and M.GroupKey('INVTYPE_ROBE') == 'chest' and M.GroupKey('INVTYPE_THROWN') == 'ranged')
assert(#M.Layout({}) == 0)

-- per-group cap keeps every slot represented
local mixed, price = {}, 100
for i = 400, 420 do info[i] = { 4, 4, 'INVTYPE_HEAD', 70, 40 }; mixed[i] = price + i end
info[430] = { 4, 4, 'INVTYPE_WAIST', 70, 40 }; mixed[430] = 9999999
info[431] = { 4, 4, 'INVTYPE_CLOAK', 70, 40 }; mixed[431] = 9999999
Seed(mixed)
local capped = M:FindUpgrades()
local perGroup = {}
for _, e in ipairs(capped) do perGroup[M.GroupKey(e.loc)] = (perGroup[M.GroupKey(e.loc)] or 0) + 1 end
assert(perGroup.head == 8 and perGroup.waist == 1 and perGroup.back == 1, 'pricey slots still appear next to a crowded one')

-- list is capped
local many = {}
for i = 100, 160 do info[i] = { 4, 4, 'INVTYPE_HEAD', 70, 40 }; many[i] = i * 100 end
Seed(many)
assert(#M:FindUpgrades() == 8, 'only the best 8 per slot group are kept')

-- never scanned: nothing, no errors
TempusDB.auctions = {}
assert(#M:FindUpgrades() == 0)

-- panel builds, shows rows, shows loading, hides with the AH
local function Frame()
    local f = { shown = false, kids = {} }
    local mt = {}
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true; if self.OnShow then self.OnShow(self) end end
    function f:Hide() self.shown = false; if self.OnHide then self.OnHide(self) end end
    function f:SetScript(n, fn) self[n] = fn end
    function f:RegisterEvent() end function f:UnregisterEvent() end
    function f:CreateTexture() return Frame() end
    function f:SetText(t) self.text = t end
    function f:GetVerticalScroll() return self.vs or 0 end
    function f:SetVerticalScroll(v) self.vs = v end
    function f:SetHeight(h) self.height = h end
    function f:GetHeight() return self.height or 0 end
    return setmetatable(f, { __index = function() return function() end end })
end
CreateFrame = function() return Frame() end
UIParent = Frame()
UISpecialFrames = {}
AuctionHouseFrame = Frame()
-- Style is captured at load, so reload the module with a stub style
local S = { C = { text = { 1, 1, 1 }, muted = { .5, .5, .5 } }, Text = function() return Frame() end, Backdrop = function() end,
    Tex = function() return Frame() end, Accent = function(o) return o end, SetGradient = function() end,
    OnAccent = function(fn) fn() end }
T.Style = S
assert(loadfile('Modules/Market/Upgrades.lua'))('Tempus', T)
Seed({ [4] = 5 * G, [9] = 1 * G })
M:ToggleUpgrades()
local p = M.upgradePanel
assert(p and p:IsShown(), 'panel opens')
assert(p.rows[1].shown and p.rows[1].header and p.rows[1].name.text == 'Chest', 'group header row')
assert(p.rows[2].shown and p.rows[2].itemID == 4 and not p.rows[3].shown)
assert(p.status.text:find('Loading item data %(1%)'), p.status.text)
assert(p.content.height == 2 * 22, 'scroll content counts header rows')
p:Hide()
-- many results across slots: content grows past the viewport, scroll position clamped when the list shrinks
local big, slotsList = {}, { 'INVTYPE_HEAD', 'INVTYPE_NECK', 'INVTYPE_SHOULDER', 'INVTYPE_CLOAK' }
local n = 300
for _, loc in ipairs(slotsList) do
    for k = 1, 8 do n = n + 1; info[n] = { 4, 4, loc, 70, 40 }; big[n] = n * 100 end
end
worn = {}
Seed(big)
p:Show()
assert(p.content.height == 36 * 22 and p.rows[36].shown and not p.rows[37].shown, p.content.height)
p.scroll:SetVerticalScroll(500)
Seed({ [4] = 5 * G })
M:RefreshUpgrades()
assert(p.scroll:GetVerticalScroll() == 0, 'scroll clamped back when the list is short')
M:HideUpgrades(); assert(not p:IsShown())

-- works without the auction house: no AH frame, panel is parented to UIParent, closes with Escape
AuctionHouseFrame = nil
M.upgradePanel = nil
Seed({ [4] = 5 * G })
local points = {}
local origFrame = Frame
Frame = function()
    local f = origFrame()
    function f:ClearAllPoints() points = {} end
    function f:SetPoint(...) points[#points + 1] = { ... } end
    function f:GetPoint() return 'TOPLEFT', UIParent, 'BOTTOMLEFT', 120, 340 end
    function f:StartMoving() self.moving = true end
    function f:StopMovingOrSizing() self.moving = false end
    return f
end
M:ToggleUpgrades()
local q = M.upgradePanel
assert(q:IsShown() and points[1][1] == 'CENTER', 'opens centred with no auction house and no saved position')
assert(UISpecialFrames[#UISpecialFrames] == 'TempusUpgradePanel', 'Escape closes it')
assert(q.rows[2].itemID == 4, 'lists saved prices without the auction house')
q.OnDragStop(q)
local saved = T.db.market.upgradePos
assert(saved and saved[1] == 'TOPLEFT' and saved[3] == 120 and saved[4] == 340, 'dragged position is saved')
q.close.OnClick(); assert(not q:IsShown(), 'close button hides it')
M:ToggleUpgrades()
assert(points[1][1] == 'TOPLEFT' and points[1][4] == 120, 'reopens where it was left')
-- closing the auction house does not close it
M:EnsureFrame(); local ah = M.frame
ah.OnEvent(ah, 'AUCTION_HOUSE_CLOSED')
assert(q:IsShown(), 'stays open after the auction house closes')
-- beside the auction house when it is open and nothing was saved
q:Hide(); T.db.market.upgradePos = false
AuctionHouseFrame = Frame(); AuctionHouseFrame.shown = true
M:ToggleUpgrades()
assert(points[1][1] == 'TOPLEFT' and points[1][2] == AuctionHouseFrame and points[1][3] == 'TOPRIGHT', 'docks beside the AH when open')

-- hovering a row fills the detail pane (no tooltip), a header does not, refresh keeps it in sync
M.upgradePanel = nil; AuctionHouseFrame = nil
local pr = M:BuildUpgradePanel(); Seed({ [4] = 5 * G }); pr:Show()
local hovered = pr.rows[2]
rawset(hovered, 'header', false)   -- the stub returns a function for unset keys; real frames return nil
assert(hovered.entry and hovered.entry.id == 4, 'row remembers its entry')
hovered.OnEnter(hovered)
assert(M.detailEntry.id == 4, 'hover selects the item')
local info = M.DetailInfo(hovered.entry)
assert(info.slot ~= '' and info.price == hovered.entry.price and info.gain == hovered.entry.gain, 'detail info carries slot, price, gain')
local before = M.detailEntry
pr.rows[1].OnEnter(pr.rows[1]); assert(M.detailEntry == before, 'header rows leave the detail alone')
M:RefreshUpgrades(); assert(M.detailEntry and M.detailEntry.id == 4, 'selection survives a refresh')
Seed({}); M:RefreshUpgrades(); assert(M.detailEntry == nil, 'cleared when the item leaves the list')
-- auction house filters: read from g_auctionHouseFilters, applied before the cap
Enum = Enum or {}
Enum.AuctionHouseFilter = { PoorQuality = 6, CommonQuality = 7, UncommonQuality = 8, RareQuality = 9, EpicQuality = 10,
    LegendaryQuality = 11, ArtifactQuality = 12, UsableOnly = 2 }
local function AHF(min, max, off)
    local f = { [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [2] = false }
    for _, id in ipairs(off or {}) do f[id] = false end
    return { minLevel = min, maxLevel = max, filters = f }
end
g_auctionHouseFilters = nil
assert(M.ReadAHFilters() == nil, 'AH never opened: no filters')
g_auctionHouseFilters = AHF(0, 0)
assert(M.ReadAHFilters() == nil, 'default filters mean nothing is filtered')
g_auctionHouseFilters = AHF(20, 30, { 6, 7 })
local rf = M.ReadAHFilters()
assert(rf.minLevel == 20 and rf.maxLevel == 30 and rf.quality[0] == false and rf.quality[1] == false and rf.quality[2] == nil, 'level range and hidden rarities read')
g_auctionHouseFilters = { minLevel = 'x', maxLevel = {}, filters = 5 }
assert(M.ReadAHFilters() == nil, 'garbage is ignored')
assert(M.PassesFilters(nil, 1, 5), 'no filters passes')
assert(not M.PassesFilters(rf, 1, 25) and M.PassesFilters(rf, 2, 25), 'hidden rarity drops')
assert(not M.PassesFilters(rf, 2, 19) and not M.PassesFilters(rf, 2, 31) and M.PassesFilters(rf, 2, 20) and M.PassesFilters(rf, 2, 30), 'level range inclusive')
assert(M.PassesFilters(rf, nil, nil), 'unknown values pass')
assert(M.PassesFilters({ minLevel = 0, maxLevel = 0, quality = {} }, 3, 99), '0 means unbounded')
assert(M.FilterSummary(rf) == 'Uncommon+, level 20-30', M.FilterSummary(rf))
assert(M.FilterSummary(M.ReadAHFilters and { minLevel = 0, maxLevel = 40, quality = { [0] = false, [1] = false, [2] = false } }) == 'Rare+, up to level 40')
assert(M.FilterSummary({ minLevel = 0, maxLevel = 0, quality = { [1] = false } }) == 'Poor/Uncommon/Rare/Epic/Legendary/Artifact', 'non-contiguous lists names')

-- all test items are common (quality 1), required level 40 except one at 61
Seed({ [1] = 10 * G, [4] = 5 * G, [6] = 2 * G })
T.db.market.upgradeMinGain = 1
g_auctionHouseFilters = AHF(0, 0, { 7 })
local fl, _, _, hid = M:FindUpgrades()
assert(#fl == 0 and hid == 3, 'common hidden: everything filtered, counted')
T.db.market.upgradeUseAHFilters = false
assert(#(M:FindUpgrades()) == 3, 'setting off ignores AH filters')
T.db.market.upgradeUseAHFilters = nil
g_auctionHouseFilters = AHF(51, 0)
assert(#(M:FindUpgrades()) == 0, 'level floor above the items')
g_auctionHouseFilters = AHF(40, 40)
assert(#(M:FindUpgrades()) == 2, 'level range 40-40 keeps the two level-40 items, drops the level-50 helm')
-- the panel says why it is empty
g_auctionHouseFilters = AHF(0, 0, { 7 })
local pf = M:BuildUpgradePanel(); pf:Show(); M:RefreshUpgrades()
assert(pf.status.text == 'No gear matches the AH filters', tostring(pf.status.text))
g_auctionHouseFilters = nil
-- the open list notices an AH filter change on its own
g_auctionHouseFilters = AHF(0, 0)
assert(M.FilterSignature() == '', 'default filters have an empty signature')
local pu = M.upgradePanel; pu:Show()
Seed({ [4] = 5 * G, [6] = 2 * G }); M:RefreshUpgrades()
assert(#M.Layout((M:FindUpgrades())) > 0)
g_auctionHouseFilters = AHF(0, 0, { 7 })
assert(M.FilterSignature() ~= '', 'a changed filter changes the signature')
pu.OnUpdate(pu, 0.1); assert(pu.status.text ~= 'No gear matches the AH filters', 'waits for the half second')
pu.OnUpdate(pu, 0.5)
assert(pu.status.text == 'No gear matches the AH filters', 'refreshed after the filter changed: ' .. tostring(pu.status.text))
g_auctionHouseFilters = nil
-- the category picked in the AH list (for example two-handed weapons) applies too
local function Cat(filters, name)
    return { CategoriesList = { GetCategoryFilterData = function() return filters end, GetCategoryData = function() return { name = name } end } }
end
AuctionHouseFrame = nil; g_auctionHouseFilters = AHF(0, 0)
assert(M.ReadAHCategory() == nil, 'no AH frame, no category')
AuctionHouseFrame = Cat(nil, 'x'); assert(M.ReadAHCategory() == nil, 'nothing selected')
AuctionHouseFrame = Cat({ { classID = 2, subClassID = 8 } }, 'Two-Handed Swords')
local cf = M.ReadAHFilters()
assert(cf and cf.categoryName == 'Two-Handed Swords' and #cf.categories == 1, 'category is read even with default filters')
assert(M.PassesFilters(cf, 1, 1, 2, 8, 'INVTYPE_2HWEAPON') and not M.PassesFilters(cf, 1, 1, 2, 7, 'INVTYPE_WEAPON')
    and not M.PassesFilters(cf, 1, 1, 4, 4, 'INVTYPE_HEAD'), 'class and subclass must match')
assert(M.FilterSummary(cf) == 'Two-Handed Swords', M.FilterSummary(cf))
AuctionHouseFrame = Cat({ { classID = 4, subClassID = 4, inventoryType = 1 } }, 'Plate Head')
local hf = M.ReadAHFilters()
assert(M.PassesFilters(hf, 1, 1, 4, 4, 'INVTYPE_HEAD') and not M.PassesFilters(hf, 1, 1, 4, 4, 'INVTYPE_LEGS'), 'inventory type must match')
assert(M.FilterSignature() ~= '', 'category is part of the signature')
-- through FindUpgrades: item 6 is a 2h sword (class 2, sub 8), the rest are armor
Seed({ [1] = 10 * G, [4] = 5 * G, [6] = 2 * G })
AuctionHouseFrame = Cat({ { classID = 2, subClassID = 8 } }, 'Two-Handed Swords')
Same(Ids((M:FindUpgrades())), { 6 })
T.db.market.upgradeUseAHFilters = false; assert(#(M:FindUpgrades()) == 3); T.db.market.upgradeUseAHFilters = nil
AuctionHouseFrame = nil; g_auctionHouseFilters = nil
-- side-by-side table lists unchanged stats too, with both values
local cmp = M.StatGains('new', 'old', 8, true, true)
local anyEqual, anyBoth
for _, g in ipairs(cmp) do
    if g.amount == 0 then anyEqual = true end
    if g.old and g.new then anyBoth = true end
end
assert(anyBoth, 'every row carries current and new values')
assert(#cmp >= #M.StatGains('new', 'old', 8, true), 'unchanged stats are added, never removed')
Seed({ [4] = 5 * G }); AuctionHouseFrame = nil; g_auctionHouseFilters = nil
local info2 = M.DetailInfo((M:FindUpgrades())[1])
assert(type(info2.all) == 'table' and info2.confidenceLabel and info2.confidenceReasons ~= nil, 'detail info has the comparison table rows and the confidence')
-- max price: setting and the box in the window
Seed({ [1] = 10 * G, [2] = 1 * G, [4] = 5 * G, [6] = 2 * G })
T.db.market.upgradeMaxGold = 3
local cheap = M:FindUpgrades()
for _, e in ipairs(cheap) do assert(e.price <= 3 * G, 'nothing above the cap') end
assert(#cheap > 0 and #cheap < #(function() T.db.market.upgradeMaxGold = 0 return (M:FindUpgrades()) end)(), 'the cap hides the dearer items, 0 = no limit')
local pp = M.upgradePanel; pp:Show()
pp.price.GetText = function() return '1,0' end
pp.price.OnTextChanged(pp.price, true)
assert(T.db.market.upgradeMaxGold == 10, 'typing a price saves it (commas ignored)')
pp.price.GetText = function() return 'abc' end
pp.price.OnTextChanged(pp.price, true)
assert(T.db.market.upgradeMaxGold == 0, 'junk means no limit')
T.db.market.upgradeMaxGold = 0.5; M:RefreshUpgrades()
assert(pp.status.text == 'No gear under 0.5 gold', tostring(pp.status.text))
T.db.market.upgradeMaxGold = 0
-- Stat-aware ranking: warriors value strength and stamina, not spirit.
do
    local stats = {
        ['item:1'] = { ITEM_MOD_STRENGTH_SHORT = 10 }, ['worn:1'] = { ITEM_MOD_STRENGTH_SHORT = 4 },
        ['item:2'] = { ITEM_MOD_SPIRIT_SHORT = 20 },                       -- wrong stats for a warrior
        ['item:4'] = { ITEM_MOD_STAMINA_SHORT = 8 },
        ['item:12'] = { ITEM_MOD_STRENGTH_SHORT = 3 },
    }
    C_Item.GetItemStats = function(link) return stats[link] end
    T.db.market.upgradeMinGain = 1
    worn[1] = 50
    assert(M.UsefulScore('item:1', 'worn:1', 'WARRIOR') == 6, 'strength gain counts in full')
    assert(M.UsefulScore('item:2', nil, 'WARRIOR') == 0, 'spirit is worth nothing to a warrior')
    assert(M.UsefulScore('item:2', nil, 'PRIEST') > 0, 'but something to a priest')
    assert(M.UsefulScore('item:1', 'worn:1', 'NOCLASS') == nil, 'unknown class: no stat score')
    C_Item.GetItemStats = function() return {} end
    assert(M.UsefulScore('item:1', 'worn:1', 'WARRIOR') == nil, 'no stats from the client: fall back to item level')
    C_Item.GetItemStats = function(link) return stats[link] end

    local ranked = M:FindUpgrades()
    local ids = Ids(ranked)
    for _, id in ipairs(ids) do assert(id ~= 2, 'wrong-stat item dropped') end
    local e1
    for _, e in ipairs(ranked) do if e.id == 1 then e1 = e end end
    assert(e1 and e1.useful == 6 and e1.worth == 6, 'useful score kept on the entry')

    T.db.market.upgradeSort = 'CHEAPEST'
    local cheap = M:FindUpgrades()
    local lastPrice = {}
    for _, e in ipairs(cheap) do
        local g = M.GroupKey(e.loc)
        assert(not lastPrice[g] or lastPrice[g] <= e.price, 'cheapest first within a slot group')
        lastPrice[g] = e.price
    end
    T.db.market.upgradeSort = 'BIGGEST'
    local big = M:FindUpgrades()
    local first = {}
    for _, e in ipairs(big) do
        local g = M.GroupKey(e.loc)
        if first[g] and first[g].worth < e.worth then error('biggest first within a slot group') end
        first[g] = first[g] or e
    end
    T.db.market.upgradeSort = 'VALUE'
    C_Item.GetItemStats = nil
    worn[1] = nil
end

print('ok')

-- Gear Advisor equip rules inside the search: dual wield, displaced gear, unique-equipped.
local gear = {
    [14] = { 2, 4, 'INVTYPE_WEAPON', 45, 40 },         -- one-hand mace +5 over the main hand
    [15] = { 4, 0, 'INVTYPE_FINGER', 70, 40 },         -- unique ring we already wear
    [6] = { 2, 8, 'INVTYPE_2HWEAPON', 45, 40 },
    [777] = { 4, 6, 'INVTYPE_SHIELD', 30, 1 },
}
local realInstant, realGetInfo = C_Item.GetItemInfoInstant, C_Item.GetItemInfo
C_Item.GetItemInfoInstant = function(id) local i = gear[id]; if i then return id, 'x', 'y', i[3], 'icon', i[1], i[2] end end
C_Item.GetItemInfo = function(id) local i = gear[id]; if i then return 'n' .. id, 'link' .. id, 1, i[4], i[5] end end
local realClass, realWorn = UnitClass, worn
worn = { [16] = 40, [11] = 50, [12] = 50 }
GetInventoryItemID = function(_, slot) if slot == 17 then return 777 elseif slot == 11 then return 15 end end
C_Item.GetItemUniquenessByID = function(id) return id == 15 end
Seed({ [14] = 1 * G, [6] = 2 * G, [15] = 1 * G })
UnitClass = function() return 'Druid', 'DRUID' end
local druid = {} for _, e in ipairs((M:FindUpgrades())) do druid[e.id] = e end
assert(druid[14] and druid[14].worn == 40 and druid[14].gain == 5, 'a druid compares a one-hander with the main hand, not the empty off hand')
assert(not druid[15], 'a unique-equipped ring you already wear is not offered')
UnitClass = function() return 'Warrior', 'WARRIOR' end
local war = {} for _, e in ipairs((M:FindUpgrades())) do war[e.id] = e end
assert(war[14] and war[14].worn == 0, 'a warrior who dual wields can use the empty off hand')
assert(war[6] and war[6].note == 'Also takes off your shield', 'a two-hander warns that the shield comes off')
UnitClass, worn, GetInventoryItemID = realClass, realWorn, nil
C_Item.GetItemInfoInstant, C_Item.GetItemInfo, C_Item.GetItemUniquenessByID = realInstant, realGetInfo, nil

-- The "why" line names the role and the stats that moved the score.
GetShapeshiftForm = function() return 3 end
C_Item.GetItemStats = function(l) return ({ nw = { ITEM_MOD_AGILITY_SHORT = 12, ITEM_MOD_STAMINA_SHORT = 2 }, od = { ITEM_MOD_STAMINA_SHORT = 6 } })[l] end
local why = M.WhyText('nw', 'od', 'DRUID')
assert(why and why:find('Cat') and why:find('from your form') and why:find('%+12 Agility') and why:find('%-4 Stamina') and why:find('estimate'), tostring(why))
T.db.market.gearRole = 'BEAR'
assert(M.WhyText('nw', 'od', 'DRUID'):find('Bear') and M.WhyText('nw', 'od', 'DRUID'):find('your choice'))
T.db.market.gearRole = 'AUTO'
assert(M.WhyText('nw', 'od', 'WARRIOR'):find('Arms') and M.WhyText('nw', 'od', 'WARRIOR'):find('assumed'), 'other classes say the role is a guess')
assert(M.WhyText('nw', 'od', 'NOPE') == nil, 'a class with no weights has nothing to say')
GetShapeshiftForm, C_Item.GetItemStats = nil, nil

-- Carried gear that already beats a listing hides the listing.
local bagLevel = 62
local prevInstant, prevInfo, prevDetailed = C_Item.GetItemInfoInstant, C_Item.GetItemInfo, C_Item.GetDetailedItemLevelInfo
C_Item.GetItemInfoInstant = function(id)
    if id == 'bag:head' then return 1, 'x', 'y', 'INVTYPE_HEAD', 'icon', 4, 4 end
    return prevInstant(id)
end
C_Item.GetItemInfo = function(id)
    if id == 'bag:head' then return 'Carried helm', id, 1, bagLevel, 40 end
    return prevInfo(id)
end
C_Item.GetDetailedItemLevelInfo = function(a)
    if a == 'bag:head' then return bagLevel end
    return prevDetailed(a)
end
NUM_BAG_SLOTS = 0
C_Container = { GetContainerNumSlots = function() return 1 end, GetContainerItemLink = function() return 'bag:head' end }
UnitClass = function() return 'Warrior', 'WARRIOR' end
Seed({ [1] = 10 * G })
local beatenList, _, _, _, _, beatenCount = M:FindUpgrades()
assert(#beatenList == 0 and beatenCount == 1, 'a carried helm of 62 hides a listing of 60 (' .. #beatenList .. ',' .. tostring(beatenCount) .. ')')
bagLevel = 55
local keptList, _, _, _, _, keptCount = M:FindUpgrades()
assert(#keptList == 1 and keptCount == 0, 'a weaker carried helm does not hide it')
C_Container, NUM_BAG_SLOTS = nil, nil
C_Item.GetItemInfoInstant, C_Item.GetItemInfo, C_Item.GetDetailedItemLevelInfo = prevInstant, prevInfo, prevDetailed

-- /tempus gearplan: the plan prints, stays within the gold, and says nothing is bought.
local printed = {}
T.Print = function(_, fmt, ...) printed[#printed + 1] = fmt:format(...) end
UnitClass = function() return 'Warrior', 'WARRIOR' end
worn = { [1] = 50, [16] = 40, [18] = 25, [11] = 50 }
GetInventoryItemID = nil
Seed({ [1] = 10 * G, [2] = 1 * G, [4] = 5 * G, [6] = 2 * G, [11] = 3 * G })
local plan = M:BuildPlan(8 * G)
assert(#plan.picks >= 1 and plan.cost <= 8 * G, 'plan within the budget')
M:PrintPlan(8)
local text = table.concat(printed, '\n')
assert(text:find('Gear Advisor plan') and text:find('nothing is bought') and text:find('Total'), text)
printed = {}
Seed({})
M:PrintPlan(8)
assert(table.concat(printed, '\n'):find('nothing in the last scan'), 'no listings: say so')

-- Legacy ranking: item levels per gold, no stat check, and the confidence line says so.
Seed({ [1] = 10 * G, [2] = 1 * G, [4] = 5 * G, [6] = 2 * G, [11] = 3 * G })
T.db.market.upgradeSort = 'LEGACY'
local legacy = M:FindUpgrades()
assert(#legacy >= 2, 'legacy lists items')
for i = 2, #legacy do assert(legacy[i - 1].score >= legacy[i].score, 'ordered by item levels per gold') end
GetShapeshiftForm = function() return 3 end
C_Item.GetItemStats = function(l) return ({ nw = { ITEM_MOD_AGILITY_SHORT = 12 }, od = { ITEM_MOD_STAMINA_SHORT = 6 } })[l] end
assert(M.ConfidenceText('nw', 'od', 'DRUID', false, 1):find('Item level only'), 'legacy is never called a stat score')
T.db.market.upgradeSort = 'VALUE'
assert(M.ConfidenceText('nw', 'od', 'DRUID', false, 1):find('Medium'), 'a scored upgrade for a known build is Medium')
assert(M.ConfidenceText('nw', 'od', 'DRUID', false, 9):find('Low') and M.ConfidenceText('nw', 'od', 'DRUID', false, 9):find('9 days old'), 'a stale price lowers it')
GetShapeshiftForm, C_Item.GetItemStats = nil, nil

-- The plan uses the Budget plan setting when no amount is given.
T.db.market.planGold = 4
printed = {}
Seed({ [1] = 10 * G, [2] = 1 * G, [4] = 5 * G, [6] = 2 * G, [11] = 3 * G })
M:PrintPlan()
assert(table.concat(printed, '\n'):find('plan for 4'), table.concat(printed, '\n'))
T.db.market.planGold = 0


-- The detail pane's facts: parts text names each stat with its score share, unscored stats are listed.
local parts = { { key = 'ITEM_MOD_AGILITY_SHORT', change = 12, value = 12.0 }, { key = 'ITEM_MOD_STAMINA_SHORT', change = -4, value = -1.4 } }
local text = M.PartsText(parts, { 'ITEM_MOD_WEIRD' })
assert(text:find('Agility %\+12 %(%\+12.0%)') and text:find('Stamina %-4 %(%-1.4%)') and text:find('Not scored: ITEM_MOD_WEIRD'), text)
assert(M.PartsText({}, {}) == 'No scored stat changes.')

-- The Item text tab: tooltip lines are read with their colours, empty ones skipped, and long ones are cut with a count.
local function fs(text, r, g, b) return { GetText = function() return text end, GetTextColor = function() return r, g, b end } end
local fake = { TipTextLeft1 = fs('Helm of Testing', 1, 1, 1), TipTextRight1 = fs(nil), TipTextLeft2 = fs('Binds when equipped', 1, 1, 1),
    TipTextRight2 = fs(nil), TipTextLeft3 = fs(''), TipTextRight3 = fs(''), TipTextLeft4 = fs('Head', 1, 1, 1), TipTextRight4 = fs('Plate', 0.8, 0.8, 0.8),
    TipTextLeft5 = fs('Equip: Restores 5 mana per 5 sec.', 0, 1, 0), TipTextRight5 = fs(nil) }
local tl = M.ReadTip('Tip', 5, function(k) return fake[k] end)
assert(#tl == 4 and tl[1][1] == 'Helm of Testing' and tl[3][1] == 'Head' and tl[3][2] == 'Plate' and tl[4][4] == 1 and tl[4][3] == 0, 'empty lines skipped, text and colour kept')
local compact = M.CompactTip({
    { 'Helm of Testing', '', 1, 1, 1 }, { 'Binds when equipped', '', 1, 1, 1 }, { 'Head', 'Plate', 1, 1, 1 },
    { '+12 Agility', '', 1, 1, 1 }, { '+8 Stamina', '', 1, 1, 1 }, { '45 Armor', '', 1, 1, 1 },
    { 'Equip: Restores 5 mana per 5 sec.', '', 0, 1, 0 } })
assert(compact == '|cffffffffBinds when equipped|r\n|cffffffffHead   Plate|r\n|cffffffff+12 Agility  ·  +8 Stamina|r\n|cffffffff45 Armor|r\n|cff00ff00Equip: Restores 5 mana per 5 sec.|r', compact)
assert(M.CompactTip({ { 'Only a name', '', 1, 1, 1 } }) == '' and M.CompactTip({}) == '', 'a name alone leaves nothing')
assert(#M.TipLines(nil) == 0 and #M.TipLines(42) == 0, 'no link, no lines')

-- Sorting: each setting orders as described, _REV flips the main column, and the headings drive it.
local rows = {
    { id = 1, name = 'Zed', rank = 5, worth = 9, gain = 4, price = 30, score = 1 },
    { id = 2, name = 'alpha', rank = 9, worth = 3, gain = 12, price = 10, score = 3 },
    { id = 3, name = 'Mid', rank = 7, worth = 6, gain = 8, price = 20, score = 2 },
}
local function order(sort) local c = {} for i, e in ipairs(rows) do c[i] = e end table.sort(c, M.Comparator(sort)) local t = {} for _, e in ipairs(c) do t[#t + 1] = e.id end return table.concat(t, ',') end
assert(order('VALUE') == '2,3,1' and order('BIGGEST') == '1,3,2' and order('GAIN') == '2,3,1' and order('CHEAPEST') == '2,3,1' and order('NAME') == '2,3,1', 'names sort without case: alpha, Mid, Zed')
assert(order('LEGACY') == '2,3,1')
assert(order('BIGGEST_REV') == '2,3,1' and order('CHEAPEST_REV') == '1,3,2' and order('NAME_REV') == '1,3,2' and order('GAIN_REV') == '1,3,2', 'the main column flips')
assert(order('NOPE') == order('VALUE') and order(nil) == order('VALUE'), 'an unknown setting is the default')
local b1, r1 = M.SortBase('GAIN_REV'); local b2, r2 = M.SortBase('NAME')
assert(b1 == 'GAIN' and r1 == true and b2 == 'NAME' and r2 == false)
local tied = { { id = 9, name = 'x', rank = 1, price = 5, worth = 1 }, { id = 4, name = 'x', rank = 1, price = 5, worth = 1 } }
table.sort(tied, M.Comparator('VALUE')); assert(tied[1].id == 4, 'ties fall back to the id')
-- headings: click to sort, click again to flip, another heading resets
local hp = M.upgradePanel
Seed({ [1] = 10 * G, [2] = 1 * G, [4] = 5 * G })
M:ToggleUpgrades(); hp = M.upgradePanel
local function click(key) for _, h in ipairs(hp.heads) do if h.key == key then h.OnClick(h) end end end
T.db.market.upgradeSort = 'VALUE'
click('BIGGEST'); assert(T.db.market.upgradeSort == 'BIGGEST')
click('BIGGEST'); assert(T.db.market.upgradeSort == 'BIGGEST_REV')
click('BIGGEST'); assert(T.db.market.upgradeSort == 'BIGGEST', 'a third click flips back')
click('CHEAPEST'); assert(T.db.market.upgradeSort == 'CHEAPEST')
click('NAME'); assert(T.db.market.upgradeSort == 'NAME')
click('GAIN'); assert(T.db.market.upgradeSort == 'GAIN')
T.db.market.upgradeSort = 'VALUE'
