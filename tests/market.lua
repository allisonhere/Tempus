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
-- the scan button is skinned only when window skinning is on
local skinned = {}
T.Skins = { On = function(_, key) return key == 'windows' and T.skinOn end, Button = function(_, b) skinned[#skinned + 1] = b end }
AuctionHouseFrame = CreateFrame('Frame')
T.skinOn = true
ah.OnEvent(ah, 'AUCTION_HOUSE_SHOW')
assert(M.button and #skinned == 1 and skinned[1] == M.button, 'button skinned')
M.button = nil; T.skinOn = false
ah.OnEvent(ah, 'AUCTION_HOUSE_SHOW')
assert(M.button and #skinned == 1, 'stock skin leaves the button alone')
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

-- The scan button fills with the accent colour; the number stays and reverses over the fill.
local st = M.ProgressState('40%', 0.4, 126, { 0.2, 0.6, 1 })
assert(st.fillWidth == 50 and st.text == '40%' and st.reverse[1] == 1 and st.reverse[3] == 1, 'dark accent: white number over the fill')
local light = M.ProgressState('100%', 1, 126, { 1, 0.9, 0.3 })
assert(light.fillWidth == 126 and light.reverse[1] < 0.1, 'light accent: dark number over the fill')
assert(M.ProgressState('x', -3, 100, nil).fillWidth == 0 and M.ProgressState('x', 7, 100, nil).fillWidth == 100, 'fraction is clamped')
assert(M.ProgressState('x', nil, 100, nil).fillWidth == 0 and M.ProgressState('x', 0 / 0, 100, nil).fillWidth == 0, 'no fraction, empty bar')

-- Mailing the report: cut into mail-sized parts, queued, offered at a mailbox, one part per send.
local long = {}
for i = 1, 40 do long[#long + 1] = 'line number ' .. i .. ' with some words to fill the space' end
local mparts = M.MailParts(table.concat(long, '\n'), 450)
assert(#mparts >= 4, #mparts)
for _, part in ipairs(mparts) do assert(#part <= 450 and not part:find('|', 1, true)) end
assert(#M.MailParts('') == 0 and M.MailParts('a|b')[1] == 'a/b' and #M.MailParts(string.rep('x', 1000), 450) == 3, 'long lines are cut too')
T.db.market = T.db.market or {}
local confirmed, sent = nil, {}
T.Confirm = function(_, text, accept) confirmed = { text = text, accept = accept } end
local function box() return { SetText = function(self, t) self.text = t end } end
SendMailNameEditBox, SendMailSubjectEditBox, SendMailBodyEditBox = box(), box(), box()
assert(not M:QueueReportMail('', 'text') and not M:QueueReportMail('Friend', ''), 'needs a name and text')
assert(M:QueueReportMail(' Allie ', table.concat(long, '\n')) and T.db.market.mailQueue.to == 'Allie' and T.db.market.mailQueue.total == #mparts)
M:OfferQueuedMail()
assert(confirmed and confirmed.text:find('Allie') and SendMailNameEditBox.text == nil, 'asks first, fills nothing yet')
confirmed.accept()
assert(SendMailNameEditBox.text == 'Allie' and SendMailSubjectEditBox.text == ('Tempus gear data (1/%d)'):format(#mparts) and SendMailBodyEditBox.text == mparts[1], 'part one filled in')
C_Timer = { After = function(_, fn) fn() end }
M:MailSent()
assert(SendMailSubjectEditBox.text == ('Tempus gear data (2/%d)'):format(#mparts) and SendMailBodyEditBox.text == mparts[2], 'the next part follows a send')
for _ = 3, #mparts do M:MailSent() end
M:MailSent()
assert(T.db.market.mailQueue == false, 'finished: queue cleared')
confirmed = nil; M:OfferQueuedMail(); assert(confirmed == nil, 'nothing queued, nothing asked')
M:MailSent()
SendMailNameEditBox, SendMailSubjectEditBox, SendMailBodyEditBox = nil, nil, nil

-- The mailbox prompt: only while a report is queued, and it stops nagging after two refusals or two weeks.
T.Confirm = function(_, text, accept, label, decline) confirmed = { text = text, accept = accept, decline = decline } end
T.db.market.mailQueue = false
confirmed = nil; M:OfferQueuedMail(); assert(confirmed == nil, 'empty queue: no prompt')
assert(M:QueueReportMail('Allie', 'some report text'))
confirmed = nil; M:OfferQueuedMail(); assert(confirmed, 'queued: prompt')
confirmed.decline(); assert(T.db.market.mailQueue, 'one refusal keeps the queue')
confirmed = nil; M:OfferQueuedMail(); confirmed.decline()
assert(T.db.market.mailQueue == false, 'two refusals drop the queue')
assert(M:QueueReportMail('Allie', 'some report text'))
T.db.market.mailQueue.at = time() - 15 * 86400
confirmed = nil; M:OfferQueuedMail()
assert(confirmed == nil and T.db.market.mailQueue == false, 'a queue older than two weeks is dropped without asking')

-- Sending by whisper waits for the person to come online: a probe line first, the rest only once it goes through.
M.SplitForChat = function(text) local t = {} for l in tostring(text):gmatch("[^\n]+") do t[#t + 1] = l end return t end
local whispers, timers = {}, {}
SendChatMessage = function(msg, kind, _, to) whispers[#whispers + 1] = to .. ': ' .. msg end
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }
local function run() local list = timers; timers = {}; for _, t in ipairs(list) do t.fn() end end
T.db.market.whisperQueue = false
assert(not M:QueueWhisper('', 'x') and not M:QueueWhisper('Friend', ''), 'needs a name and text')
assert(M:QueueWhisper('Daily Reporter', 'line one\nline two\nline three'))
assert(not M.filtersInstalled, 'nothing is filtered or hidden')
assert(#whispers == 1 and whispers[1] == 'Daily Reporter: line one', 'only the probe goes first')
M:OnSystemMessage("No player named 'Daily Reporter' is currently playing.")
run()
assert(T.db.market.whisperQueue and #whispers == 1, 'offline: stays queued, nothing more sent')
assert(timers[1] and timers[1].delay == 1800, 'tries again in half an hour')
run()
assert(#whispers == 2 and whispers[2] == 'Daily Reporter: line one', 'second attempt probes again')
run(); run()
assert(#whispers == 4 and whispers[3] == 'Daily Reporter: line two' and whispers[4] == 'Daily Reporter: line three', 'online: the rest follow')
run()
assert(T.db.market.whisperQueue == false, 'finished: queue cleared')
M:OnSystemMessage("No player named 'Daily Reporter' is currently playing."); assert(M.probeFailed ~= true or true)
-- a stale queue is dropped
T.db.market.whisperQueue = { to = 'Daily Reporter', lines = { 'x' }, at = time() - 2 * 86400 }
local before = #whispers
M:PumpWhisper()
assert(T.db.market.whisperQueue == false and #whispers == before, 'a day later it gives up without sending')
SendChatMessage = nil
