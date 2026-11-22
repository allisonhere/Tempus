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
local T = { db = { market = { staleDays = 3, upgradeMinGain = 1, upgradeAffordable = false } },
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
assert(all[1].label == 'Armor' and all[2].label == 'Sta' and all[3].label == 'Str' and all[4].label == 'Critical Strike'
    and all[5].label == 'Spi', 'ordered by size; Rating suffix trimmed')

-- list is capped
local many = {}
for i = 100, 260 do info[i] = { 4, 4, 'INVTYPE_HEAD', 70, 40 }; many[i] = i * 100 end
Seed(many)
assert(#M:FindUpgrades() == 100, 'results are capped at 100')

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
AuctionHouseFrame = Frame()
-- Style is captured at load, so reload the module with a stub style
local S = { C = { text = { 1, 1, 1 }, muted = { .5, .5, .5 } }, Text = function() return Frame() end, Backdrop = function() end }
T.Style = S
assert(loadfile('Modules/Market/Upgrades.lua'))('Tempus', T)
Seed({ [4] = 5 * G, [9] = 1 * G })
M:ToggleUpgrades()
local p = M.upgradePanel
assert(p and p:IsShown(), 'panel opens')
assert(p.rows[1].shown and p.rows[1].itemID == 4 and not p.rows[2].shown)
assert(p.status.text:find('Loading item data %(1%)'), p.status.text)
assert(p.content.height == 22, 'scroll content sized to the results')
p:Hide()
-- many results: content grows past the viewport, scroll position is clamped when the list shrinks
local big = {}
for i = 300, 340 do info[i] = { 4, 4, 'INVTYPE_HEAD', 70, 40 }; big[i] = i * 100 end
Seed(big)
p:Show()
assert(p.content.height == 41 * 22 and p.rows[41].shown and not p.rows[42].shown)
p.scroll:SetVerticalScroll(500)
Seed({ [4] = 5 * G })
M:RefreshUpgrades()
assert(p.scroll:GetVerticalScroll() == 0, 'scroll clamped back when the list is short')
M:HideUpgrades(); assert(not p:IsShown())
print('ok')
