local module, messages, post = nil, {}, nil
local secret = {}
local now = 1000000
function time() return now end
GetRealmName = function() return 'Realm' end
UnitFactionGroup = function() return 'Horde' end
TempusDB = {}
local timeouts = {}
C_Timer = { After = function(d, fn) if d == 0 then fn() else timeouts[#timeouts + 1] = fn end end }
local frames = {}
function CreateFrame(kind)
    local f = { events = {}, texts = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(n, fn) self[n] = fn end
    function f:SetSize() end function f:SetPoint() end
    function f:SetText(t) self.text = t end
    function f:IsShown() return true end
    frames[#frames + 1] = f
    return f
end
local function Tip()
    local t = { lines = {}, scripts = {}, link = 'item:123:0:0:0:0:0:7', owner = { tempusRecord = { count = 5 } } }
    function t:GetItem() return 'Test item', self.link end
    function t:GetOwner() return self.owner end
    function t:AddDoubleLine(l, r) self.lines[#self.lines + 1] = { l, r } end
    function t:HookScript(e, fn) self.scripts[e] = fn end
    return t
end
GameTooltip = Tip()
Enum = { TooltipDataType = { Item = 1 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) post = fn end }
local T = { db = { market = { tooltips = true, staleDays = 3, autoScan = false } },
    Num = function(v) return type(v) == 'number' end, issecret = function(v) return v == secret end,
    ModuleEnabled = function() return true end,
    Print = function(_, fmt, ...) messages[#messages + 1] = fmt:format(...) end,
    NewModule = function(_, _, def) module = def end }
assert(loadfile('Modules/Market/Market.lua'))('Tempus', T)
local M = T.Market

-- before any scan: nothing stored, tooltip stays quiet
assert(not M:Quote('item:123', 123))
module.OnEnable(); module.OnEnable()
post(GameTooltip, { id = 123 }); assert(#GameTooltip.lines == 0, 'quiet before first scan')

-- scanning needs the API and an open house
assert(not M:StartScan()); assert(messages[#messages]:find('no auction house scan API'))
local auctions = {
    -- name, tex, count, q, usable, lvl, lvlType, minBid, minInc, buyout, bid, highBidder, bidderName, owner, ownerName, sale, itemID
    { 'a', 1, 5, 1, 1, 1, 1, 0, 0, 61725, 0, 0, 0, 0, 0, 0, 123 },    -- 12345 per item
    { 'a', 1, 1, 1, 1, 1, 1, 0, 0, 20000, 0, 0, 0, 0, 0, 0, 123 },
    { 'b', 1, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 777 },        -- no buyout: ignored
    { 'c', 1, 3, 1, 1, 1, 1, 0, 0, 1001, 0, 0, 0, 0, 0, 0, 555 },     -- ceil(333.67) = 334
}
local replicated = 0
C_AuctionHouse = {
    ReplicateItems = function() replicated = replicated + 1 end,
    GetNumReplicateItems = function() return #auctions end,
    GetReplicateItemInfo = function(i) return unpack(auctions[i + 1]) end,
}
assert(not M:StartScan()); assert(messages[#messages]:find('Open the auction house'))
local ah = M.frame
ah.OnEvent(ah, 'AUCTION_HOUSE_SHOW')
assert(M:StartScan() and replicated == 1 and M.scanning)
assert(not M:StartScan() and replicated == 1, 'no second scan while one runs')
ah.OnEvent(ah, 'REPLICATE_ITEM_LIST_UPDATE')
assert(not M.scanning and messages[#messages]:find('2 items priced from 3 auctions'), messages[#messages])
local q = M:Quote('item:123:0:0', nil)
assert(q and q.price == 12345 and q.age == 0, 'keeps the lowest unit buyout')
assert(M:Quote(nil, 555).price == 334 and not M:Quote(nil, 777))

-- tooltip shows our scan, and stack total
post(GameTooltip, { id = 123 })
assert(GameTooltip.lines[1][2] == '1g 23s 45c' and GameTooltip.lines[2][2] == '6g 17s 25c', GameTooltip.lines[1][2])
assert(GameTooltip.lines[3][2] == 'Seen today')
GameTooltip.scripts.OnTooltipCleared(GameTooltip); GameTooltip.lines = {}
post(GameTooltip, { id = 123 }); local n = #GameTooltip.lines
post(GameTooltip, { id = 123 }); assert(#GameTooltip.lines == n, 'no duplicate lines')

-- cooldown, aging, stale
assert(not M:StartScan()); assert(messages[#messages]:find('scanned again in 15 min'))
now = now + 4 * 86400 + 16 * 60
q = M:Quote(nil, 123); assert(q.age == 4)
GameTooltip.scripts.OnTooltipCleared(GameTooltip); GameTooltip.lines = {}
post(GameTooltip, { id = 123 }); assert(GameTooltip.lines[3][2]:find('stale'))

-- second scan merges: unlisted items keep their old price, relisted ones update
auctions = { { 'a', 1, 1, 1, 1, 1, 1, 0, 0, 5000, 0, 0, 0, 0, 0, 0, 123 } }
assert(M:StartScan()); ah.OnEvent(ah, 'REPLICATE_ITEM_LIST_UPDATE')
assert(M:Quote(nil, 123).price == 5000 and M:Quote(nil, 555).price == 334 and M:Quote(nil, 555).age == 4, 'unlisted item keeps its old timestamp')

-- a server that never answers times out
now = now + 20 * 60
timeouts = {}
assert(M:StartScan()); assert(#timeouts == 1); timeouts[1]()
assert(not M.scanning and messages[#messages]:find('no answer'), messages[#messages])
now = now + 20 * 60
-- closing mid-scan fails cleanly; auto scan; secret values skipped; old rows pruned
now = now + 20 * 60
assert(M:StartScan()); ah.OnEvent(ah, 'AUCTION_HOUSE_CLOSED')
assert(not M.scanning and messages[#messages]:find('stopped'))
ah.OnEvent(ah, 'AUCTION_HOUSE_SHOW')
T.db.market.autoScan = true
auctions = { { 'a', 1, secret, 1, 1, 1, 1, 0, 0, 100, 0, 0, 0, 0, 0, 0, 900 }, { 'a', 1, 1, 1, 1, 1, 1, 0, 0, 100, 0, 0, 0, 0, 0, 0, 901 } }
ah.OnEvent(ah, 'AUCTION_HOUSE_SHOW')
assert(M.scanning, 'auto scan starts when the house opens'); ah.OnEvent(ah, 'REPLICATE_ITEM_LIST_UPDATE')
assert(not M:Quote(nil, 900) and M:Quote(nil, 901).price == 100)
now = now + 31 * 86400 + 1000
auctions = { { 'a', 1, 1, 1, 1, 1, 1, 0, 0, 100, 0, 0, 0, 0, 0, 0, 901 } }
assert(M:StartScan()); ah.OnEvent(ah, 'REPLICATE_ITEM_LIST_UPDATE')
assert(not M:Quote(nil, 123) and M:Quote(nil, 901), 'prices older than 30 days are dropped')
print('ok')
