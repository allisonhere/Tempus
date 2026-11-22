-- Explains what an item's stats do for your character, using the client's own conversion
-- functions (the ones the character panel uses), so numbers follow class, level and talents.
local _, T = ...
local S = { defaults = { compare = true } }
T.StatTips = S

local function Readable(v) return not (T.issecret and T.issecret(v)) end
local function Num(v) return type(v) == "number" and v == v and v > -math.huge and v < math.huge and Readable(v) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and Num(v) then return v end
end

local STR, AGI, STA, INT, SPI = 1, 2, 3, 4, 5
local BREAK, ARMOR_PER_AGI, MANA_PER_INT = 20, 2, 15

local SLOTS = {
    INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3}, INVTYPE_CHEST = {5}, INVTYPE_ROBE = {5},
    INVTYPE_WAIST = {6}, INVTYPE_LEGS = {7}, INVTYPE_FEET = {8}, INVTYPE_WRIST = {9}, INVTYPE_HAND = {10},
    INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14}, INVTYPE_CLOAK = {15},
    INVTYPE_WEAPON = {16, 17}, INVTYPE_2HWEAPON = {16}, INVTYPE_WEAPONMAINHAND = {16},
    INVTYPE_WEAPONOFFHAND = {17}, INVTYPE_SHIELD = {17}, INVTYPE_HOLDABLE = {17},
    INVTYPE_RANGED = {18}, INVTYPE_RANGEDRIGHT = {18}, INVTYPE_THROWN = {18}, INVTYPE_RELIC = {18},
}

-- item stat key -> output row and the combat rating it feeds
local RATINGS = {
    ITEM_MOD_HIT_RATING_SHORT = { "hit", "CR_HIT_MELEE" },
    ITEM_MOD_HIT_SPELL_RATING_SHORT = { "hit", "CR_HIT_SPELL" },
    ITEM_MOD_CRIT_RATING_SHORT = { "crit", "CR_CRIT_MELEE" },
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = { "spellCrit", "CR_CRIT_SPELL" },
    ITEM_MOD_HASTE_RATING_SHORT = { "haste", "CR_HASTE_MELEE" },
    ITEM_MOD_EXPERTISE_RATING_SHORT = { "expertise", "CR_EXPERTISE" },
    ITEM_MOD_DODGE_RATING_SHORT = { "dodge", "CR_DODGE" },
    ITEM_MOD_PARRY_RATING_SHORT = { "parry", "CR_PARRY" },
    ITEM_MOD_BLOCK_RATING_SHORT = { "block", "CR_BLOCK" },
}

-- "Equip:" text isn't part of the item stat table, so read the few percentage effects from it.
local EQUIP = {
    { "^improves your chance to hit by ([%d%.]+)%%", "hit" },
    { "^improves your chance to get a critical strike with spells by ([%d%.]+)%%", "spellCrit" },
    { "^improves your chance to get a critical strike by ([%d%.]+)%%", "crit" },
    { "chance to dodge an attack by ([%d%.]+)%%", "dodge" },
    { "chance to parry an attack by ([%d%.]+)%%", "parry" },
    { "chance to block attacks with a shield by ([%d%.]+)%%", "block" },
}

-- label, number format, lower is better
local ROWS = {
    { "ap", "Attack power", "%d" }, { "crit", "Crit chance", "%.2f%%" },
    { "spellCrit", "Spell crit chance", "%.2f%%" }, { "hit", "Hit chance", "%.2f%%" },
    { "haste", "Haste", "%.2f%%" }, { "expertise", "Expertise", "%.2f" },
    { "dodge", "Dodge chance", "%.2f%%" }, { "parry", "Parry chance", "%.2f%%" },
    { "block", "Block chance", "%.2f%%" }, { "armorCut", "Physical damage taken", "%.2f%%", true },
    { "health", "Health", "%d" }, { "mana", "Mana", "%d" },
    { "hp5", "Health regen per 5s (out of combat)", "%.1f", false, true },
    { "mp5", "Mana regen per 5s (not casting)", "%.1f", false, true },
}

local function Effective(stat)
    local _, v = UnitStat("player", stat)
    return Num(v) and v or 0
end

-- Change in fn(x) when x moves from base to base + d.
local function Shift(fn, base, d, scale)
    local a, b = Call(fn, base + d), Call(fn, base)
    return a and b and (a - b) * (scale or 1) or 0
end

local function WithBreak(x, perPoint)
    x = math.max(x, 0)
    return math.min(BREAK, x) + math.max(x - BREAK, 0) * perPoint
end

function S.Effects(delta, removing)
    local out, approx = {}, {}
    local _, class = UnitClass("player")
    local mana = class ~= "WARRIOR" and class ~= "ROGUE"
    local function add(key, v) if Num(v) and v ~= 0 then out[key] = (out[key] or 0) + v end end
    local function base(stat, d) local cur = Effective(stat); return removing and cur - d or cur end

    local str, agi, sta, int, spi = delta.ITEM_MOD_STRENGTH_SHORT, delta.ITEM_MOD_AGILITY_SHORT,
        delta.ITEM_MOD_STAMINA_SHORT, delta.ITEM_MOD_INTELLECT_SHORT, delta.ITEM_MOD_SPIRIT_SHORT
    if str then
        local b = base(STR, str)
        add("ap", Shift(function(x) return GetAttackPowerForStat(STR, x) end, b, str))
        add("crit", Shift(function(x) return GetCritChanceFromStat(STR, x) end, b, str, 100))
    end
    if agi then
        local b = base(AGI, agi)
        add("ap", Shift(function(x) return GetAttackPowerForStat(AGI, x) end, b, agi))
        add("crit", Shift(function(x) return GetCritChanceFromStat(AGI, x) end, b, agi, 100))
        local cur = Effective(AGI)
        local dodge = Call(GetDodgeChanceFromAttribute)
        if dodge and cur > 0 then add("dodge", dodge * 100 / cur * agi); approx.dodge = true end
    end
    if sta then
        local per = Call(UnitHPPerStamina, "player") or 10
        add("health", Shift(function(x) return WithBreak(x, per) end, base(STA, sta), sta))
    end
    if int then
        local b = base(INT, int)
        if mana then add("mana", Shift(function(x) return WithBreak(x, MANA_PER_INTELLECT or MANA_PER_INT) end, b, int)) end
        add("spellCrit", Shift(function(x) return GetSpellCritChanceFromStat(INT, x) end, b, int, 100))
    end
    if spi then
        local cur = Effective(SPI)
        if cur > 0 then
            local hp, mp = Call(GetHealthRegenFromSpirit), Call(GetManaRegenFromSpirit)
            if hp then add("hp5", hp * 5 / cur * spi); approx.hp5 = true end
            if mp and mana then add("mp5", mp * 5 / cur * spi); approx.mp5 = true end
        end
    end
    for statKey, info in pairs(RATINGS) do
        local amount, index = delta[statKey], _G[info[2]]
        if amount and index then
            add(info[1], Call(GetCombatRatingBonusForCombatRatingValue, index, amount))
        end
    end
    for _, key in ipairs({ "hit", "crit", "spellCrit", "dodge", "parry", "block" }) do add(key, delta["EQUIP_" .. key]) end
    add("ap", delta.EQUIP_ap)

    local armor = (agi and agi * ARMOR_PER_AGI or 0) + (delta.RESISTANCE0_NAME or 0)
    if armor ~= 0 and C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectiveness then
        local _, cur = UnitArmor("player")
        local level = UnitEffectiveLevel and UnitEffectiveLevel("player") or UnitLevel("player")
        if Num(cur) and Num(level) then
            local b = removing and cur - armor or cur
            local cut = Shift(function(x) return C_PaperDollInfo.GetArmorEffectiveness(math.max(x, 0), level) end, b, armor, 100)
            add("armorCut", -cut)
        end
    end
    return out, approx
end

local function StripColors(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

function S.Stats(link)
    local stats = {}
    if type(link) ~= "string" then return stats end
    local getStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    local ok, t = pcall(getStats, link)
    if ok and type(t) == "table" then for k, v in pairs(t) do stats[k] = v end end
    local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and select(2, pcall(C_TooltipInfo.GetHyperlink, link))
    if type(data) == "table" and data.lines then
        local prefix = (ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:"):lower()
        for _, line in ipairs(data.lines) do
            local text = type(line.leftText) == "string" and Readable(line.leftText) and StripColors(line.leftText):lower()
            if text and text:sub(1, #prefix) == prefix then
                text = strtrim(text:sub(#prefix + 1))
                for _, e in ipairs(EQUIP) do
                    local n = tonumber(text:match(e[1]))
                    if n then stats["EQUIP_" .. e[2]] = (stats["EQUIP_" .. e[2]] or 0) + n; break end
                end
                local ap = tonumber(text:match("^%+(%d+) attack power"))
                if ap and not stats.ITEM_MOD_ATTACK_POWER_SHORT then stats.EQUIP_ap = (stats.EQUIP_ap or 0) + ap end
            end
        end
    end
    return stats
end

local function IsEquipped(link)
    for slot = 1, 19 do if GetInventoryItemLink("player", slot) == link then return true end end
    return false
end

-- What the item would replace: its slot's stats, plus the off hand for a two-hander.
local function Replaced(link)
    local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local _, _, _, loc = info(link)
    local slots = loc and SLOTS[loc]
    if not slots then return nil end
    local slot = slots[1]
    for _, s in ipairs(slots) do if not GetInventoryItemLink("player", s) then slot = s; break end end
    local oldLink = GetInventoryItemLink("player", slot)
    local stats = S.Stats(oldLink)
    local name = oldLink or "an empty slot"
    if loc == "INVTYPE_2HWEAPON" then
        local off = GetInventoryItemLink("player", 17)
        if off then
            for k, v in pairs(S.Stats(off)) do stats[k] = (stats[k] or 0) + v end
            name = name .. " + " .. off
        end
    end
    return stats, name
end

function S:Build(link, tip)
    local item = self.Stats(link)
    local removing = tip == ShoppingTooltip1 or tip == ShoppingTooltip2 or IsEquipped(link)
    local delta, header = item, "This item gives you:"
    if not removing then
        local old, name = Replaced(link)
        if not old then return nil end
        for k, v in pairs(old) do item[k] = (item[k] or 0) - v end
        header = "Swapping in (replaces " .. name .. "):"
    end
    local effects, approx = self.Effects(delta, removing)
    local rows = {}
    for _, r in ipairs(ROWS) do
        local v = effects[r[1]]
        if v and math.abs(v) >= 0.005 then
            local good = (v > 0) ~= (r[4] == true)
            rows[#rows + 1] = { r[2], ((approx[r[1]] or r[5]) and "~" or "") .. (v > 0 and "+" or "") .. r[3]:format(v), good }
        end
    end
    if #rows == 0 then return nil end
    return header, rows
end

function S:AddTooltip(tip)
    local db = T.db.stattips
    if not (db and T:ModuleEnabled("stattips") and tip.AddDoubleLine and tip.GetItem) then return end
    local ok, _, link = pcall(tip.GetItem, tip)
    if not (ok and Readable(link) and type(link) == "string") or tip.tempusStatTipsKey == link then return end
    tip.tempusStatTipsKey = link
    local built, header, rows = pcall(self.Build, self, link, tip)
    if not (built and header) then return end
    if not db.compare and header:find("^Swapping") then return end
    tip:AddLine(" ")
    tip:AddLine(header, 1, .82, 0, true)
    for _, r in ipairs(rows) do
        local c = r[3] and { .25, 1, .25 } or { 1, .3, .3 }
        tip:AddDoubleLine("  " .. r[1], r[2], .8, .8, .8, c[1], c[2], c[3])
    end
end

local function Prepare(tip)
    if not (tip and tip.AddDoubleLine and tip.HookScript) then return false end
    if tip.HasScript and not tip:HasScript("OnTooltipCleared") then return false end
    if not tip.tempusStatTipsClear then
        tip:HookScript("OnTooltipCleared", function(t) t.tempusStatTipsKey = nil end)
        tip.tempusStatTipsClear = true
    end
    return true
end

function S:HookTooltips()
    if self.hooked then return end
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then return end
    self.hooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip)
        if Prepare(tip) then S:AddTooltip(tip) end
    end)
end

T:NewModule("stattips", {
    label = "Stat tooltips",
    desc = "Item tooltips explain what stats do for your character: attack power, crit, health, armor and more.",
    defaults = S.defaults,
    OnEnable = function() S:HookTooltips() end,
})
