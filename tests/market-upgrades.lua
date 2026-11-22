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
assert(loadfile('Modules/Bags/Client.lua'))('Tempus', T)
assert(loadfile('Modules/Market/Market.lua'))('Tempus', T)
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
-- scores (gain per gold): 4 -> 11, 11 -> 1.67 (+5 over ranged 25), 12 -> 14.5 (+58 for 4g), 13 -> 8, 2 -> 2, 6 -> 2.5, 1 -> 1
Same(Ids(list), { 12, 4, 13, 6, 2, 11, 1 })
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
Same(Ids((M:FindUpgrades())), { 6, 2, 11 })
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
assert(#gains == 3 and gains[1].label == 'Armor' and gains[1].amount == 200 and gains[2].label == 'Str' and gains[2].amount == 8
    and gains[3].label == 'Spi' and gains[3].amount == 4, 'gains only, biggest first')
local all = M.StatGains('new', nil, 8)
assert(#all == 5, 'empty slot: every stat is a gain')
local down = M.StatGains('old', 'new', 3)
assert(#down == 1 and down[1].label == 'Sta' and down[1].amount == 5, 'a downgrade in most stats lists only what rises')
assert(#M.StatGains('missing', 'old') == 0, 'uncached item has no stats yet')
local both = M.StatGains('old', 'new', 5, true)
local sawLoss
for _, g in ipairs(both) do if g.amount < 0 then sawLoss = true end end
assert(sawLoss, 'withLosses lists stats that drop, including ones the new item lacks')
-- bar sizing and colours
assert(M.BarWidth(10, 10, 80) == 80 and M.BarWidth(5, 10, 80) == 40 and M.BarWidth(1, 100, 80) == 3, 'bar width scales, never a sliver')
assert(M.BarWidth(0, 10, 80) == 0 and M.BarWidth(5, 0, 80) == 0 and M.BarWidth(nil, 10, 80) == 0, 'no gain, no bar')
assert(M.BarColor('Agi') ~= M.BarColor('Sta') and M.BarColor('Whatever')[1], 'known and unknown stats both coloured')
local mx = M.GainMaxima({ { { label = 'Agi', amount = 4 } }, { { label = 'Agi', amount = 9 }, { label = 'Sta', amount = 2 } } })
assert(mx.Agi == 9 and mx.Sta == 2, 'maxima per stat')
local withNew = M.GainMaxima({ { { label = 'Agi', amount = 4, old = 20, new = 24 } } })
assert(withNew.Agi == 24, 'scale uses the new total so worn + gain fits')
assert(gains[1].old and gains[1].new == gains[1].old + gains[1].amount, 'gains carry the worn and new values')
assert(all[1].label == 'Armor' and all[2].label == 'Sta' and all[3].label == 'Str' and all[4].label == 'Critical Strike'
    and all[5].label == 'Spi', 'ordered by size; Rating suffix trimmed')

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
local S = { C = { text = { 1, 1, 1 }, muted = { .5, .5, .5 } }, Text = function() return Frame() end, Backdrop = function() end }
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

-- tooltip goes beside the panel, level with the row, on whichever side has room
assert(M.TooltipSide(800, 300, 1920) == 'right' and M.TooltipSide(1700, 300, 1920) == 'left')
assert(M.TooltipSide(1580, 320, 1920) == 'right' and M.TooltipSide(1590, 320, 1920) == 'left', 'width and gap counted')
assert(M.TooltipSide(nil, 300, 1920) == 'right' and M.TooltipSide(1700, nil, 1920) == 'left', 'unknown width assumes 320')
local tipPoints, shown = {}, {}
GameTooltip = { SetOwner = function(_, owner, anchor) shown.owner, shown.anchor = owner, anchor end,
    SetHyperlink = function(_, l) shown.link = l end, Show = function() end, Hide = function() end,
    GetWidth = function() return 300 end, ClearAllPoints = function() tipPoints = {} end,
    SetPoint = function(_, ...) tipPoints[#tipPoints + 1] = { ... } end }
UIParent.GetWidth = function() return 1920 end
local row = { GetParent = function() return nil end }
M.upgradePanel = { GetRight = function() return 800 end }
M.PlaceTooltip(GameTooltip, row)
assert(tipPoints[1][1] == 'TOPLEFT' and tipPoints[1][2] == row and tipPoints[1][3] == 'TOPRIGHT' and tipPoints[1][4] == 14, 'right of the panel')
M.upgradePanel = { GetRight = function() return 1800 end }
M.PlaceTooltip(GameTooltip, row)
assert(tipPoints[1][1] == 'TOPRIGHT' and tipPoints[1][3] == 'TOPLEFT' and tipPoints[1][4] == -14, 'left of the panel when the right is full')
-- hovering a real row anchors with ANCHOR_NONE (not over the row) and shows the item
M.upgradePanel = nil; AuctionHouseFrame = nil
local pr = M:BuildUpgradePanel(); Seed({ [4] = 5 * G }); pr:Show()
local hovered = pr.rows[2]
rawset(hovered, 'header', false)   -- the stub returns a function for unset keys; real frames return nil
pr.GetRight = function() return 800 end
hovered.GetParent = function() return pr end
hovered.OnEnter(hovered)
assert(shown.anchor == 'ANCHOR_NONE' and shown.link == 'item:4' and tipPoints[1][1] == 'TOPLEFT', 'row hover uses the side anchor')
pr.rows[1].OnEnter(pr.rows[1]); assert(shown.link == 'item:4', 'header rows show no tooltip')
print('ok')
