-- Cheapest gear upgrades from the Tempus auction scan. An upgrade is an item level above what you
-- wear in that slot (the same rule as the Bags arrow); results are ranked by item levels gained
-- per gold so a cheap +10 beats an expensive +12.
local _, T = ...
local M = T.Market
local S = T.Style

local PER_GROUP = 8               -- best deals kept per slot group
local LIMIT = 250                 -- display rows: items plus group headers
local VISIBLE = 14                -- rows visible at once; the rest scroll
local REQUESTS_PER_PASS = 150     -- uncached items asked for per refresh, so the client is not flooded
local SKIP_LOCS = { INVTYPE_BODY = true, INVTYPE_TABARD = true }
local RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local RANGED_SLOT = 18

-- Highest armor subclass each class wears (1 cloth, 2 leather, 3 mail, 4 plate), and the level at
-- which the heavier type unlocks for classes that start one type lower.
local ARMOR_TOP = { WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4, HUNTER = 3, SHAMAN = 3, ROGUE = 2, DRUID = 2,
    PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local ARMOR_UNLOCK = { WARRIOR = 40, PALADIN = 40, HUNTER = 40, SHAMAN = 40 }
local SHIELDS = { WARRIOR = true, PALADIN = true, SHAMAN = true }

local function Set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
-- Weapon subclasses by class: 0/1 axe, 2 bow, 3 gun, 4/5 mace, 6 polearm, 7/8 sword, 10 staff,
-- 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
local WEAPONS = {
    WARRIOR = Set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = Set(0, 1, 4, 5, 6, 7, 8),
    DEATHKNIGHT = Set(0, 1, 4, 5, 6, 7, 8),
    HUNTER = Set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18),
    ROGUE = Set(0, 2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST = Set(4, 10, 15, 19),
    SHAMAN = Set(0, 1, 4, 5, 10, 13, 15),
    MAGE = Set(7, 10, 15, 19),
    WARLOCK = Set(7, 10, 15, 19),
    DRUID = Set(4, 5, 6, 10, 13, 15),
}

local function Num(v) return T.Num(v) and v == v and not (T.issecret and T.issecret(v)) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
end

-- Can this class use the item? Unknown classes are not filtered. Rings, necks, trinkets, cloaks and
-- held-in-off-hand items are usable by everyone.
function M.CanUse(class, level, classID, subClassID, equipLoc, minLevel)
    if Num(minLevel) and Num(level) and minLevel > level then return false end
    if classID == 4 then
        if subClassID == 0 or equipLoc == "INVTYPE_CLOAK" then return true end
        if subClassID == 6 then return SHIELDS[class] == true end
        if subClassID >= 1 and subClassID <= 4 then
            local top = ARMOR_TOP[class]
            if not top then return true end
            if ARMOR_UNLOCK[class] and Num(level) and level < ARMOR_UNLOCK[class] then top = top - 1 end
            return subClassID == top
        end
        return false
    end
    if classID == 2 then
        local allowed = WEAPONS[class]
        return allowed == nil or allowed[subClassID] == true
    end
    return false
end

local function WornLevel(loc)
    if RANGED[loc] then
        local link = Call(GetInventoryItemLink, "player", RANGED_SLOT)
        if not link then return 0 end
        local lvl = Call(C_Item and C_Item.GetDetailedItemLevelInfo, link)
        return Num(lvl) and lvl or nil
    end
    return T.Bags.Client.WornLevel(_G, loc)
end

-- Gear metadata is read once per item and remembered on its price row (c = class, l = slot, s = subclass).
local function GearInfo(id, row, instant)
    if row.c == nil then
        local ok, _, _, _, loc, _, classID, subClassID = pcall(instant, id)
        if ok and Num(classID) then
            row.c, row.l, row.s = classID, type(loc) == "string" and loc or "", subClassID or 0
        else
            return nil
        end
    end
    local slots = T.Bags.Client.EQUIP_SLOTS
    if (row.c == 2 or row.c == 4) and slots[row.l] and not SKIP_LOCS[row.l] then return row end
    return nil
end

-- Slot groups, in the order the panel lists them. Variants of one slot share a group.
local GROUPS = {
    { "head", "Head", "INVTYPE_HEAD" }, { "neck", "Neck", "INVTYPE_NECK" },
    { "shoulder", "Shoulders", "INVTYPE_SHOULDER" }, { "back", "Back", "INVTYPE_CLOAK" },
    { "chest", "Chest", "INVTYPE_CHEST" }, { "wrist", "Wrists", "INVTYPE_WRIST" },
    { "hands", "Hands", "INVTYPE_HAND" }, { "waist", "Waist", "INVTYPE_WAIST" },
    { "legs", "Legs", "INVTYPE_LEGS" }, { "feet", "Feet", "INVTYPE_FEET" },
    { "finger", "Rings", "INVTYPE_FINGER" }, { "trinket", "Trinkets", "INVTYPE_TRINKET" },
    { "weapon", "One-hand weapons", "INVTYPE_WEAPON" }, { "mainhand", "Main hand", "INVTYPE_WEAPONMAINHAND" },
    { "twohand", "Two-hand weapons", "INVTYPE_2HWEAPON" }, { "offhand", "Off hand", "INVTYPE_WEAPONOFFHAND" },
    { "shield", "Shields", "INVTYPE_SHIELD" }, { "held", "Held in off hand", "INVTYPE_HOLDABLE" },
    { "ranged", "Ranged", "INVTYPE_RANGED" },
}
local GROUP_OF = { INVTYPE_ROBE = "chest", INVTYPE_RANGEDRIGHT = "ranged", INVTYPE_THROWN = "ranged" }
local GROUP_INDEX = {}
for i, g in ipairs(GROUPS) do GROUP_INDEX[g[1]] = i; GROUP_OF[g[3]] = GROUP_OF[g[3]] or g[1] end

function M.GroupKey(loc) return GROUP_OF[loc] end

-- Returns a ranked list, the number of items still waiting on item data, and how many were
-- requested this pass. Entry: { id, price, age, gain, level, worn, loc, score }.
function M:FindUpgrades()
    local store = self.Store()
    local db = T.db.market or {}
    local C = C_Item
    local instant = (C and C.GetItemInfoInstant) or GetItemInfoInstant
    local getInfo = (C and C.GetItemInfo) or GetItemInfo
    local detailed = C and C.GetDetailedItemLevelInfo
    local _, class = UnitClass("player")
    local level = UnitLevel("player")
    local money = db.upgradeAffordable and Call(GetMoney) or nil
    local minGain = Num(db.upgradeMinGain) and db.upgradeMinGain or 1
    local now = time()
    local worn, out, pending, requested = {}, {}, 0, 0
    if type(instant) ~= "function" or type(getInfo) ~= "function" then return out, 0, 0 end

    for id, row in pairs(store.items) do
        if GearInfo(id, row, instant) then
            local loc = row.l
            if worn[loc] == nil then worn[loc] = WornLevel(loc) or false end
            local base = worn[loc]
            if base ~= false and M.CanUse(class, level, row.c, row.s, loc, nil)
                and not (money and row.p > money) then
                local _, _, _, ilvl, minLevel = getInfo(id)
                local eff = Call(detailed, id)
                if Num(eff) and eff > 0 then ilvl = eff end
                if not Num(ilvl) then
                    pending = pending + 1
                    if requested < REQUESTS_PER_PASS and C and C.RequestLoadItemDataByID then
                        requested = requested + 1
                        Call(C.RequestLoadItemDataByID, id)
                    end
                elseif ilvl - base >= minGain and M.CanUse(class, level, row.c, row.s, loc, minLevel) then
                    local gain = ilvl - base
                    out[#out + 1] = { id = id, price = row.p, gain = gain, level = ilvl, worn = base, loc = loc,
                        age = Num(row.t) and math.max(0, math.floor((now - row.t) / 86400)) or nil,
                        score = gain / math.max(row.p / 10000, 0.01) }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.price ~= b.price then return a.price < b.price end
        return a.id < b.id
    end)
    -- Keep the best few per slot group so every slot is covered, not just the best-value one.
    local kept, counts = {}, {}
    for _, e in ipairs(out) do
        local key = GROUP_OF[e.loc]
        counts[key] = (counts[key] or 0) + 1
        if counts[key] <= PER_GROUP then kept[#kept + 1] = e end
    end
    return kept, pending, requested
end

-- What improves ------------------------------------------------------------------------------

local SHORT = { ITEM_MOD_STRENGTH_SHORT = "Str", ITEM_MOD_AGILITY_SHORT = "Agi", ITEM_MOD_STAMINA_SHORT = "Sta",
    ITEM_MOD_INTELLECT_SHORT = "Int", ITEM_MOD_SPIRIT_SHORT = "Spi", ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS", RESISTANCE0_NAME = "Armor" }

local function StatLabel(key)
    if SHORT[key] then return SHORT[key] end
    local text = _G[key]
    if type(text) ~= "string" then return nil end
    return (text:gsub(" Rating$", ""))
end

local function StatsOf(link)
    local fn = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not link then return {} end
    local ok, t = pcall(fn, link)
    return ok and type(t) == "table" and t or {}
end

-- The stats that go up when `newLink` replaces `oldLink` (nil = empty slot): up to `max` entries,
-- largest gain first, as { label, amount }.
function M.StatGains(newLink, oldLink, max, withLosses)
    local new, old, out, seen = StatsOf(newLink), StatsOf(oldLink), {}, {}
    local function add(key)
        if seen[key] then return end
        seen[key] = true
        local n, o = Num(new[key]) and new[key] or 0, Num(old[key]) and old[key] or 0
        local delta = n - o
        local label = (delta > 0 or (withLosses and delta < 0)) and StatLabel(key)
        if label then out[#out + 1] = { label = label, amount = delta, key = key, old = o, new = n } end
    end
    for key in pairs(new) do add(key) end
    if withLosses then for key in pairs(old) do add(key) end end
    table.sort(out, function(a, b)
        local x, y = math.abs(a.amount), math.abs(b.amount)
        if x ~= y then return x > y end
        return a.key < b.key
    end)
    while #out > (max or 3) do out[#out] = nil end
    return out
end

-- One colour per stat so the same stat reads the same down the whole list.
local BAR_COLORS = { Str = { 0.86, 0.36, 0.30 }, Agi = { 0.36, 0.78, 0.42 }, Sta = { 0.93, 0.60, 0.26 },
    Int = { 0.38, 0.62, 0.95 }, Spi = { 0.72, 0.62, 0.92 }, AP = { 0.95, 0.78, 0.30 }, DPS = { 0.95, 0.78, 0.30 },
    Armor = { 0.62, 0.68, 0.74 } }
local BAR_DEFAULT = { 0.45, 0.78, 0.78 }
local BAR_SEGS, BAR_W, BAR_H = 3, 92, 14

function M.BarColor(label) return BAR_COLORS[label] or BAR_DEFAULT end

-- Fill width for one stat: its share of the biggest gain of that stat in the list, never a bare
-- sliver, so small upgrades still show a bar.
function M.BarWidth(amount, max, width)
    if not (Num(amount) and Num(max)) or max <= 0 or amount <= 0 then return 0 end
    return math.max(3, math.floor(width * math.min(1, amount / max) + 0.5))
end

-- The biggest gain per stat across everything listed.
function M.GainMaxima(rowsGains)
    local max = {}
    for _, gains in ipairs(rowsGains) do
        for _, g in ipairs(gains) do
            local top = math.max(g.new or g.amount, g.old or 0)
            if top > (max[g.label] or 0) then max[g.label] = top end
        end
    end
    return max
end

local function AmountText(a) return a == math.floor(a) and ("%d"):format(a) or ("%.1f"):format(a) end

-- The worn item the candidate would replace: the lowest item level among its slots (empty = nil).
local function WornLink(loc)
    local slots = RANGED[loc] and { RANGED_SLOT } or T.Bags.Client.EQUIP_SLOTS[loc]
    local detailed = C_Item and C_Item.GetDetailedItemLevelInfo
    local best, bestLevel
    for _, slot in ipairs(slots or {}) do
        local link = Call(GetInventoryItemLink, "player", slot)
        local lvl = link and Call(detailed, link) or 0
        if not Num(lvl) then lvl = 0 end
        if bestLevel == nil or lvl < bestLevel then best, bestLevel = link, lvl end
    end
    return best
end

-- The list as the panel shows it: a header row per slot group (in GROUPS order) followed by that
-- group's items, best deal first.
function M.Layout(list)
    local by, out = {}, {}
    for _, e in ipairs(list) do
        local key = GROUP_OF[e.loc]
        by[key] = by[key] or {}
        by[key][#by[key] + 1] = e
    end
    for _, g in ipairs(GROUPS) do
        local items = by[g[1]]
        if items then
            out[#out + 1] = { header = g[2], count = #items }
            for _, e in ipairs(items) do out[#out + 1] = e end
        end
    end
    return out
end

-- Panel -----------------------------------------------------------------------------------------

local ROW_H, WIDTH = 22, 700
local DETAIL_W = 280    -- the detail pane to the right of the list

local function Money(copper)
    copper = math.floor(copper + 0.5)
    if copper >= 10000 then return ("%dg %ds"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100) end
    return ("%ds %dc"):format(math.floor(copper / 100), copper % 100)
end

local DETAIL_STATS = 7
local GROUP_LABEL = {}
for _, g in ipairs(GROUPS) do GROUP_LABEL[g[1]] = g[2] end

-- Everything the detail pane shows for one listed item.
function M.DetailInfo(e)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, link, _, _, _, _, _, _, _, icon = getInfo(e.id)
    local worn = WornLink(e.loc)
    return { name = name, link = link, icon = icon, slot = GROUP_LABEL[GROUP_OF[e.loc]] or "", level = e.level,
        worn = e.worn, wornLink = worn, gain = e.gain, price = e.price, age = e.age,
        perGold = e.score, stats = M.StatGains(link or ("item:" .. e.id), worn, DETAIL_STATS, true) }
end

function M.BuildDetail(p, scroll)
    local d = CreateFrame("Frame", nil, p)
    d:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
    d:SetSize(DETAIL_W - 18, VISIBLE * ROW_H)
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(36, 36)
    d.icon:SetPoint("TOPLEFT", 0, 0)
    d.name = S.Text(d, 13, S.C.text)
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 8, -2)
    d.name:SetWidth(DETAIL_W - 70)
    d.name:SetWordWrap(false)
    d.slot = S.Text(d, 11, S.C.muted)
    d.slot:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -3)
    d.line = {}
    for i = 1, 4 do
        d.line[i] = S.Text(d, 11, S.C.text)
        d.line[i]:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -10 - (i - 1) * 16)
        d.line[i]:SetWidth(DETAIL_W - 20)
        d.line[i]:SetWordWrap(false)
    end
    d.head = S.Text(d, 11, T.accent)
    d.head:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -82)
    d.stats = {}
    for i = 1, DETAIL_STATS do
        local s = {}
        s.label = S.Text(d, 11, S.C.text)
        s.label:SetPoint("TOPLEFT", d.head, "BOTTOMLEFT", 0, -8 - (i - 1) * 24)
        s.label:SetWidth(DETAIL_W - 20)
        s.label:SetWordWrap(false)
        s.track = d:CreateTexture(nil, "BACKGROUND")
        s.track:SetSize(DETAIL_W - 20, 6)
        s.track:SetPoint("TOPLEFT", s.label, "BOTTOMLEFT", 0, -2)
        s.track:SetColorTexture(1, 1, 1, 0.06)
        s.base = d:CreateTexture(nil, "ARTWORK")
        s.base:SetHeight(6)
        s.base:SetPoint("LEFT", s.track, "LEFT", 0, 0)
        s.fill = d:CreateTexture(nil, "ARTWORK", nil, 1)
        s.fill:SetHeight(6)
        s.fill:SetPoint("LEFT", s.base, "RIGHT", 0, 0)
        d.stats[i] = s
    end
    d.hint = S.Text(d, 11, S.C.muted)
    d.hint:SetPoint("TOPLEFT", 0, 0)
    d.hint:SetWidth(DETAIL_W - 24)
    d.hint:SetText("Hover an item to see exactly what changes.")
    return d
end

local function AgeText(age)
    if not age or age <= 0 then return "seen today" end
    return age == 1 and "seen 1 day ago" or ("seen %d days ago"):format(age)
end

function M:ShowDetail(e)
    local p, d = self.upgradePanel, self.upgradePanel and self.upgradePanel.detail
    if not d then return end
    self.detailEntry = e
    if not e then
        d.hint:Show(); d.icon:Hide(); d.name:SetText(""); d.slot:SetText(""); d.head:SetText("")
        for _, l in ipairs(d.line) do l:SetText("") end
        for _, s in ipairs(d.stats) do s.label:SetText(""); s.track:Hide(); s.base:Hide(); s.fill:Hide() end
        return
    end
    local i = M.DetailInfo(e)
    d.hint:Hide()
    d.icon:Show()
    d.icon:SetTexture(i.icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or 134400)
    d.name:SetText(i.link or i.name or ("item:" .. e.id))
    d.slot:SetText(i.slot)
    d.line[1]:SetText(("Item level |cffffffff%d|r  |cff66F27F+%d|r  (you wear %s)"):format(i.level or 0, i.gain or 0,
        i.worn and i.worn > 0 and tostring(i.worn) or "nothing"))
    d.line[2]:SetText("Replaces: " .. (i.wornLink or "empty slot"))
    d.line[3]:SetText("Price: |cffFFD140" .. Money(i.price) .. "|r  (" .. AgeText(i.age) .. ")")
    d.line[4]:SetText(i.perGold and ("Value: %.1f item levels per gold"):format(i.perGold) or "")
    d.head:SetText(#i.stats > 0 and "Stat changes (worn  >  new)" or "No stat changes known yet")
    local maxima = M.GainMaxima({ i.stats })
    for k, s in ipairs(d.stats) do
        local g = i.stats[k]
        if g then
            local c = M.BarColor(g.label)
            local lost = g.amount < 0
            local top = math.max(g.old, g.new)
            local w = DETAIL_W - 20
            s.label:SetText(("%s   %s  >  %s   %s"):format(g.label, AmountText(g.old), AmountText(g.new),
                lost and ("|cffFF6B6B-" .. AmountText(-g.amount) .. "|r") or ("|cff7CFF8A+" .. AmountText(g.amount) .. "|r")))
            s.track:Show()
            local keep = M.BarWidth(lost and g.new or g.old, top, w)
            s.base:SetWidth(math.max(1, keep))
            s.base:SetColorTexture(c[1], c[2], c[3], 0.35)
            s.base:SetShown(keep > 0)
            s.fill:SetWidth(M.BarWidth(math.abs(g.amount), top, w))
            if lost then s.fill:SetColorTexture(0.9, 0.28, 0.28, 0.9) else s.fill:SetColorTexture(c[1], c[2], c[3], 0.95) end
            s.fill:Show()
        else
            s.label:SetText(""); s.track:Hide(); s.base:Hide(); s.fill:Hide()
        end
    end
end

function M:BuildUpgradePanel()
    if self.upgradePanel then return self.upgradePanel end
    -- A free-standing window (not a child of the auction house) so it works anywhere: prices are saved.
    local p = CreateFrame("Frame", "TempusUpgradePanel", UIParent)
    p:SetSize(WIDTH + DETAIL_W, 60 + VISIBLE * ROW_H)
    p:SetFrameStrata("HIGH")
    p:SetClampedToScreen(true)
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", function(f) f:StartMoving() end)
    p:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, rel, x, y = f:GetPoint()
        if point and T.db.market then T.db.market.upgradePos = { point, rel, x, y } end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "TempusUpgradePanel") end
    if S and S.Backdrop then S.Backdrop(p, {}) end
    p.title = S.Text(p, 14, S.C.text)
    p.title:SetPoint("TOPLEFT", 12, -10)
    p.title:SetText("Cheapest upgrades")
    p.sub = S.Text(p, 11, S.C.muted)
    p.sub:SetPoint("TOPLEFT", p.title, "TOPRIGHT", 10, -2)
    p.sub:SetText("ilvl = item levels above what you wear; bars: dim = worn now, bright = gain, red = loss")
    p.close = CreateFrame("Button", nil, p)
    p.close:SetSize(20, 20)
    p.close:SetPoint("TOPRIGHT", -6, -6)
    p.close.x = S.Text(p.close, 14, S.C.muted)
    p.close.x:SetPoint("CENTER")
    p.close.x:SetText("x")
    p.close:SetScript("OnClick", function() p:Hide() end)
    p.status = S.Text(p, 11, S.C.muted)
    p.status:SetPoint("TOPRIGHT", p.close, "TOPLEFT", -6, -4)
    p.foot = S.Text(p, 11, S.C.muted)
    p.foot:SetPoint("BOTTOMLEFT", 12, 10)
    local scroll = CreateFrame("ScrollFrame", nil, p)
    scroll:SetPoint("TOPLEFT", 10, -34)
    scroll:SetSize(WIDTH - 20, VISIBLE * ROW_H)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 20, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        local max = math.max(0, content:GetHeight() - sf:GetHeight())
        sf:SetVerticalScroll(math.max(0, math.min(max, sf:GetVerticalScroll() - delta * ROW_H * 3)))
    end)
    p.scroll, p.content = scroll, content
    p.detail = M.BuildDetail(p, scroll)
    p.rows = {}
    for i = 1, LIMIT do
        local r = CreateFrame("Button", nil, content)
        r:SetSize(WIDTH - 20, ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", 2, 0)
        r.name = S.Text(r, 12, S.C.text)
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.name:SetWidth(200)
        r.name:SetJustifyH("LEFT")
        r.gain = S.Text(r, 12, { 0.4, 0.95, 0.5 })
        r.gain:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
        r.gain:SetWidth(56)
        r.gain:SetJustifyH("LEFT")
        r.price = S.Text(r, 12, { 1, 0.82, 0.25 })
        r.price:SetPoint("RIGHT", -4, 0)
        r.price:SetJustifyH("RIGHT")
        r.price:SetWidth(96)
        -- Stat bars: a dim track, a coloured fill sized by the gain, and the figure on top.
        r.segs = {}
        for k = 1, BAR_SEGS do
            local seg = {}
            seg.track = r:CreateTexture(nil, "BACKGROUND")
            seg.track:SetSize(BAR_W, BAR_H)
            seg.track:SetPoint("LEFT", r.gain, "RIGHT", 6 + (k - 1) * (BAR_W + 4), 0)
            seg.track:SetColorTexture(1, 1, 1, 0.06)
            seg.base = r:CreateTexture(nil, "ARTWORK")
            seg.base:SetHeight(BAR_H)
            seg.base:SetPoint("LEFT", seg.track, "LEFT", 0, 0)
            seg.fill = r:CreateTexture(nil, "ARTWORK", nil, 1)
            seg.fill:SetHeight(BAR_H)
            seg.fill:SetPoint("LEFT", seg.base, "RIGHT", 0, 0)
            seg.text = S.Text(r, 10, S.C.text, "OUTLINE")
            seg.text:SetPoint("LEFT", seg.track, "LEFT", 4, 0)
            seg.text:SetWidth(BAR_W - 6)
            seg.text:SetWordWrap(false)
            seg.track:Hide(); seg.base:Hide(); seg.fill:Hide(); seg.text:SetText("")
            r.segs[k] = seg
        end
        r:SetScript("OnEnter", function(b)
            if b.header or not b.entry then return end
            M:ShowDetail(b.entry)
        end)
        r:SetScript("OnClick", function(b)
            if b.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
                ChatEdit_InsertLink(b.link)
            end
        end)
        r:Hide()
        p.rows[i] = r
    end
    -- Item data arrives asynchronously; refresh the open panel as it lands.
    p:SetScript("OnShow", function(f)
        f:RegisterEvent("ITEM_DATA_LOAD_RESULT")
        f.scroll:SetVerticalScroll(0)
        M:RefreshUpgrades()
    end)
    p:SetScript("OnHide", function(f) f:UnregisterEvent("ITEM_DATA_LOAD_RESULT") end)
    p:SetScript("OnEvent", function() M:ScheduleUpgradeRefresh() end)
    p:Hide()
    self.upgradePanel = p
    return p
end

function M:ScheduleUpgradeRefresh()
    if self.upgradeTimer then return end
    self.upgradeTimer = true
    C_Timer.After(0.4, function()
        M.upgradeTimer = nil
        if M.upgradePanel and M.upgradePanel:IsShown() then M:RefreshUpgrades() end
    end)
end

function M:RefreshUpgrades()
    local p = self.upgradePanel
    if not (p and p:IsShown()) then return end
    local store = self.Store()
    local list, pending = {}, 0
    if Num(store.scanned) then
        local ok, l, n = pcall(self.FindUpgrades, self)
        if ok then list, pending = l, n end
    end
    local layout = M.Layout(list)
    local gainsOf, all = {}, {}
    for _, e in ipairs(layout) do
        if not e.header then
            local _, full = (C_Item and C_Item.GetItemInfo or GetItemInfo)(e.id)
            gainsOf[e] = M.StatGains(full or ("item:" .. e.id), WornLink(e.loc), BAR_SEGS, true)
            all[#all + 1] = gainsOf[e]
        end
    end
    local maxima = M.GainMaxima(all)
    for i, r in ipairs(p.rows) do
        local e = layout[i]
        if e and e.header then
            r.itemID, r.link, r.entry = nil, nil, nil
            r.icon:Hide(); r.gain:SetText(""); r.price:SetText("")
            for _, seg in ipairs(r.segs) do seg.track:Hide(); seg.base:Hide(); seg.fill:Hide(); seg.text:SetText("") end
            r.name:SetText(e.header)
            r.name:SetTextColor(T.accent[1], T.accent[2], T.accent[3])
            r.header = true
            r:Show()
        elseif e then
            r.header = nil
            r.icon:Show()
            r.name:SetTextColor(S.C.text[1], S.C.text[2], S.C.text[3])
            r.itemID, r.entry = e.id, e
            local name, link, _, _, _, _, _, _, _, icon = (C_Item and C_Item.GetItemInfo or GetItemInfo)(e.id)
            r.link = link
            r.icon:SetTexture(icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or 134400)
            r.name:SetText(link or name or ("item:" .. e.id))
            r.gain:SetText("+" .. e.gain .. " ilvl")
            local gains = gainsOf[e] or {}
            for k, seg in ipairs(r.segs) do
                local g = gains[k]
                if g then
                    local c = M.BarColor(g.label)
                    seg.track:Show()
                    -- Gain: worn value (dim) then the extra on top (bright). Loss: what you keep
                    -- (dim) then the part you give up in red.
                    local lost = g.amount < 0
                    local keep = lost and g.new or g.old
                    local baseW = M.BarWidth(keep, maxima[g.label], BAR_W)
                    seg.base:SetWidth(math.max(1, baseW))
                    seg.base:SetColorTexture(c[1], c[2], c[3], 0.35)
                    seg.base:SetShown(baseW > 0)
                    seg.fill:SetWidth(M.BarWidth(math.abs(g.amount), maxima[g.label], BAR_W))
                    if lost then seg.fill:SetColorTexture(0.9, 0.28, 0.28, 0.9)
                    else seg.fill:SetColorTexture(c[1], c[2], c[3], 0.95) end
                    seg.fill:Show()
                    seg.text:SetText(g.label .. " " .. AmountText(g.old) .. (lost
                        and (" |cffFF6B6B-" .. AmountText(-g.amount)) or (" |cff7CFF8A+" .. AmountText(g.amount))) .. "|r")
                else
                    seg.track:Hide(); seg.base:Hide(); seg.fill:Hide(); seg.text:SetText("")
                end
            end
            local stale = e.age and e.age >= (T.db.market.staleDays or 3)
            r.price:SetText(Money(e.price) .. (stale and " (old)" or ""))
            r:Show()
        else
            r.itemID, r.link, r.header, r.entry = nil, nil, nil, nil
            r:Hide()
        end
    end
    local sel
    if self.detailEntry then
        for _, e in ipairs(layout) do if e.id == self.detailEntry.id then sel = e break end end
    end
    self:ShowDetail(sel)
    p.content:SetHeight(math.max(1, #layout * ROW_H))
    local max = math.max(0, #layout * ROW_H - VISIBLE * ROW_H)
    if p.scroll:GetVerticalScroll() > max then p.scroll:SetVerticalScroll(max) end
    if not Num(store.scanned) then
        p.status:SetText("Scan the auction house first")
    elseif pending > 0 then
        p.status:SetText(("Loading item data (%d)..."):format(pending))
    elseif #list == 0 then
        p.status:SetText("No upgrades found")
    else
        p.status:SetText("")
    end
    local scanned = Num(store.scanned) and (time() - store.scanned) or nil
    p.foot:SetText(scanned and ("Scanned %s ago. Ranked by item levels gained per gold.")
        :format(scanned >= 86400 and (math.floor(scanned / 86400) .. " d") or scanned >= 3600
        and (math.floor(scanned / 3600) .. " h") or (math.floor(scanned / 60) .. " min")) or "")
end

function M:HideUpgrades()
    if self.upgradePanel then self.upgradePanel:Hide() end
end

-- Where the window opens: where you left it, else beside the auction house if it is open, else centred.
function M:PlaceUpgradePanel(p)
    p:ClearAllPoints()
    local pos = T.db.market and T.db.market.upgradePos
    if type(pos) == "table" and pos[1] then
        p:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    elseif AuctionHouseFrame and AuctionHouseFrame.IsShown and AuctionHouseFrame:IsShown() then
        p:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 6, 0)
    else
        p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function M:ToggleUpgrades()
    local p = self:BuildUpgradePanel()
    if p:IsShown() then p:Hide() return end
    self:PlaceUpgradePanel(p)
    p:Show()
end

function M:EnsureUpgradeButton(scanButton)
    if self.upgradeButton or not scanButton then return end
    local ok, b = pcall(CreateFrame, "Button", "TempusUpgradesButton", AuctionHouseFrame, "UIPanelButtonTemplate")
    if not (ok and b) then return end
    b:SetSize(90, 22)
    b:SetPoint("LEFT", scanButton, "RIGHT", 4, 0)
    if b.SetFrameLevel and scanButton.GetFrameLevel then b:SetFrameLevel(scanButton:GetFrameLevel()) end
    b:SetText("Upgrades")
    b:SetScript("OnClick", function() M:ToggleUpgrades() end)
    local SK = T.Skins
    if SK and SK.On and SK.Button and SK:On("windows") then pcall(SK.Button, SK, b) end
    self.upgradeButton = b
end
