local module, messages, post, prices, age = nil, {}, nil, 12345, 4
local secret={}
local function Tip()
    local t={lines={},scripts={},link='item:123:0:0:0:0:0:7',owner={tempusRecord={count=5}}}
    function t:GetItem() return 'Test item',self.link end
    function t:GetOwner() return self.owner end
    function t:AddDoubleLine(left,right) self.lines[#self.lines+1]={left,right} end
    function t:HookScript(event,fn) self.scripts[event]=fn end
    return t
end
GameTooltip=Tip(); ItemRefTooltip=Tip()
Enum={TooltipDataType={Item=1}}
TooltipDataProcessor={AddTooltipPostCall=function(_,fn) post=fn end}
local T={db={market={tooltips=true,staleDays=3}},
    Num=function(v) return type(v)=='number' end, issecret=function(v) return v==secret end,
    ModuleEnabled=function() return true end,
    Print=function(_,fmt,...) messages[#messages+1]=fmt:format(...) end,
    NewModule=function(_,_,def) module=def end}
assert(loadfile('Modules/Market/Market.lua'))('Tempus',T)
local M=T.Market
local q,why=M:Quote('item:123',123)
assert(not q and why=='unavailable')
local linkCalls,idCalls=0,0
Auctionator={API={v1={
    GetAuctionPriceByItemLink=function(caller,link) assert(caller=='Tempus' and link:find('item:')); linkCalls=linkCalls+1; return prices end,
    GetAuctionAgeByItemLink=function() return age end,
    GetAuctionPriceByItemID=function() idCalls=idCalls+1; return prices end,
    GetAuctionAgeByItemID=function() return age end,
}}}
local api=Auctionator.API.v1
module.OnEnable(); module.OnEnable()
post(GameTooltip,{id=123})
assert(#GameTooltip.lines==3 and GameTooltip.lines[1][2]=='1g 23s 45c')
assert(GameTooltip.lines[2][2]=='6g 17s 25c' and GameTooltip.lines[3][2]:find('stale'))
assert(linkCalls==1 and idCalls==0,'prefer variant link to bare item ID')
post(GameTooltip,{id=123}); assert(#GameTooltip.lines==3,'no duplicate callback lines')
GameTooltip.scripts.OnTooltipCleared(GameTooltip); GameTooltip.lines={}
prices=23456; age=0
post(GameTooltip,{id=123})
assert(GameTooltip.lines[1][2]=='2g 34s 56c' and GameTooltip.lines[3][2]=='Seen today','do not cache old scan results')
prices=nil
q,why=M:Quote('item:123',123); assert(not q and why=='unknown')
prices=-1; assert(not M:Quote(nil,123))
prices=0/0; assert(not M:Quote(nil,123))
prices=math.huge; assert(not M:Quote(nil,123))
prices=secret; assert(not M:Quote(nil,123))
prices=100; age=nil
q=M:Quote(nil,123); assert(q.price==100 and q.age==nil)
api.GetAuctionPriceByItemLink=function() error('provider unavailable') end
local before=idCalls
assert(not M:Quote('item:123',123) and idCalls==before,'never silently substitute another variant')
assert(not M:Quote(secret,secret))
T.db.market.tooltips=false
local lines=#GameTooltip.lines
M:AddTooltip(GameTooltip,999); assert(#GameTooltip.lines==lines)
T.db.market.tooltips=true
local scans,terms=0
api.MultiSearchExact=function(caller,list)
    assert(caller=='Tempus')
    for _,term in ipairs(list) do assert(not term:find('"'), 'API rejects caller-quoted names') end
    scans=scans+1; terms=list
end
assert(not M:ScanBags() and scans==0,'scan requires open AH')
AuctionFrame={IsShown=function() return true end}
NUM_BAG_SLOTS=0
local items={
    {hyperlink='item:1'}, {hyperlink='item:1'}, {hyperlink='item:2'},
    {hyperlink='item:3',isBound=true}, {hyperlink='item:4'}, {hyperlink=secret},
}
C_Container={GetContainerNumSlots=function() return #items end, GetContainerItemInfo=function(_,slot) return items[slot] end}
C_Item={GetItemInfo=function(link) return ({['item:1']='Silk Cloth',['item:2']='Linen Cloth',['item:3']='Bound Sword'})[link] end}
assert(M:ScanBags() and scans==1 and #terms==2)
assert(terms[1]=='Linen Cloth' and terms[2]=='Silk Cloth','unique exact names, excluding bound and uncached items')
assert(messages[#messages]:find('uncached'))
api.MultiSearchExact=nil
api.MultiSearch=function() scans=scans+1 end
assert(M:ScanBags(), 'older API uses basic name searches')
api.MultiSearch=function() error('busy') end
assert(not M:ScanBags() and messages[#messages]:find('could not start'))
-- Every modern item surface participates, including tooltips created after startup.
api.GetAuctionPriceByItemLink=function() return 100 end
local comparison=Tip()
post(comparison,{id=123})
assert(#comparison.lines==3 and comparison.scripts.OnTooltipCleared)
post(comparison,{id=123}); assert(#comparison.lines==3)
comparison.scripts.OnTooltipCleared(comparison); comparison.lines={}
post(comparison,{id=123}); assert(#comparison.lines==3,'reused comparison tip must show price again')
local embedded=Tip(); embedded.GetItem=false; embedded.owner=nil
post(embedded,{id=123})
assert(#embedded.lines==2,'embedded items can use callback ID when no item link is available')
post({}, {id=123}) -- a non-tooltip surface is ignored safely
-- Legacy tooltip path also hooks and renders, without the modern data processor.
TooltipDataProcessor=nil; M.hooked=nil
GameTooltip=Tip(); ItemRefTooltip=Tip()
ShoppingTooltip1=Tip(); ItemRefShoppingTooltip1=Tip()
EmbeddedItemTooltip={ItemTooltip=Tip()}
api.GetAuctionPriceByItemLink=function() return 100 end
M:HookTooltips()
GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
assert(GameTooltip.lines[1][2]=='0g 1s 0c')
GameTooltip.scripts.OnTooltipCleared(GameTooltip)
assert(GameTooltip.tempusMarketKey==nil)
for _,tip in ipairs({ShoppingTooltip1,ItemRefShoppingTooltip1,EmbeddedItemTooltip.ItemTooltip}) do
    tip.scripts.OnTooltipSetItem(tip)
    assert(tip.lines[1][2]=='0g 1s 0c','legacy comparison/embedded tooltips include prices')
end
print('PASS: auction estimates, variants, age, stack totals, missing/invalid data, tooltip lifecycle, and explicit AH scans')
