local module, post
local function Tip()
    local t = { lines = {}, scripts = {}, link = 'item:1' }
    function t:GetItem() return 'Item', self.link end
    function t:AddLine(l) self.lines[#self.lines + 1] = { l } end
    function t:AddDoubleLine(l, r) self.lines[#self.lines + 1] = { l, r } end
    function t:HookScript(e, f) self.scripts[e] = f end
    return t
end
GameTooltip = Tip()
Enum = { TooltipDataType = { Item = 1 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) post = fn end }
strtrim = function(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
local T = { db = { stattips = { compare = true } }, ModuleEnabled = function() return true end,
    NewModule = function(_, _, def) module = def end }
assert(loadfile('Modules/StatTips/StatTips.lua'))('Tempus', T)

local stats = { ['item:1'] = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 5 } }
local equipped = {}
UnitClass = function() return 'Warrior', 'WARRIOR' end
UnitStat = function(_, i) return 100, 100 end
GetAttackPowerForStat = function(_, x) return x * 2 end
GetCritChanceFromStat = function() return 0 end
UnitHPPerStamina = function() return 10 end
GetItemStats = function(link) return stats[link] end
GetItemInfoInstant = function() return 1, 'x', 'y', 'INVTYPE_CHEST' end
GetInventoryItemLink = function(_, slot) return equipped[slot] end
UnitArmor = function() return 0, 0 end

module.OnEnable()
post(GameTooltip)
local joined = {}
for _, l in ipairs(GameTooltip.lines) do joined[#joined + 1] = (l[1] or '') .. '|' .. (l[2] or '') end
local text = table.concat(joined, '\n')
assert(text:find('replaces an empty slot'), text)
assert(text:find('Attack power|+20', 1, true), text)
assert(text:find('Health|+50', 1, true), 'first 20 stamina... base 100 is past the break: 5*10=50')
local n = #GameTooltip.lines
post(GameTooltip); assert(#GameTooltip.lines == n, 'no duplicate lines')
GameTooltip.scripts.OnTooltipCleared(GameTooltip)

-- swapping against an equipped piece subtracts it; equipped item shows its own gain
equipped[5] = 'item:2'; stats['item:2'] = { ITEM_MOD_STRENGTH_SHORT = 4 }
GameTooltip.lines = {}; post(GameTooltip)
assert(GameTooltip.lines[3][1] == '  Attack power' and GameTooltip.lines[3][2] == '+12', 'delta vs equipped')
GameTooltip.scripts.OnTooltipCleared(GameTooltip)
equipped[5] = 'item:1'; GameTooltip.lines = {}; post(GameTooltip)
assert(GameTooltip.lines[2][1]:find('gives you'), 'equipped header')

-- disabled / compare off
GameTooltip.scripts.OnTooltipCleared(GameTooltip); equipped[5] = nil
T.db.stattips.compare = false; GameTooltip.lines = {}; post(GameTooltip)
assert(#GameTooltip.lines == 0, 'compare off hides swap lines')
-- errors never escape
GetItemStats = function() error('boom') end
GameTooltip.scripts.OnTooltipCleared(GameTooltip); post(GameTooltip)
print('ok')
