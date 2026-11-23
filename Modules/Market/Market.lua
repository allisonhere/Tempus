-- Tempus scans the auction house itself (C_AuctionHouse.ReplicateItems) and keeps the lowest
-- buyout per item for each realm, account-wide. No other addon is involved.
local _, T = ...
local M = { defaults = { tooltips = true, staleDays = 3, autoScan = false, upgradeMinGain = 3, upgradeSort = "VALUE", planGold = 0, reportTo = "", mailQueue = false, gearRole = "AUTO", gearRoleLast = false, upgradeAffordable = false, upgradeMaxGold = 0, upgradeUseAHFilters = true, upgradePos = false } }
T.Market = M

local SCAN_COOLDOWN = 15 * 60       -- the client only serves a full replicate about every 15 minutes
local BATCH = 500                   -- auctions read per frame
local TIMEOUT = 30                  -- seconds to wait for the server before giving up
local PRUNE_AFTER = 30 * 86400      -- forget prices older than this

local function Number(value)
    return T.Num(value) and value == value and value >= 0 and value < math.huge
end
local function Readable(value)
    return not (T.issecret and T.issecret(value))
end
local function Money(value)
    value = math.floor(value + 0.5)
    return ("%dg %ds %dc"):format(math.floor(value / 10000), math.floor(value / 100) % 100, value % 100)
end

-- Prices live in TempusDB.auctions[realm-faction], shared by every character and profile.
local function RealmKey()
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "Neutral"
    return (GetRealmName and GetRealmName() or "Realm") .. "-" .. tostring(faction)
end
local function Store()
    TempusDB = TempusDB or {}
    TempusDB.auctions = TempusDB.auctions or {}
    local key = RealmKey()
    TempusDB.auctions[key] = TempusDB.auctions[key] or { items = {} }
    return TempusDB.auctions[key]
end

local function ItemID(link, id)
    if Readable(link) and type(link) == "string" then
        local fromLink = tonumber(link:match("item:(%d+)"))
        if fromLink then return fromLink end
    end
    if Number(id) and id > 0 then return id end
end

M.Store = Store

function M:Quote(link, id)
    id = ItemID(link, id)
    if not id then return nil, "unknown" end
    local row = Store().items[id]
    if not (row and Number(row.p) and row.p > 0) then return nil, "unknown" end
    local age = Number(row.t) and math.max(0, math.floor((time() - row.t) / 86400)) or nil
    return { price = row.p, age = age }
end

function M:AddTooltip(tip, id)
    local db = T.db.market
    if not (db and db.tooltips and T:ModuleEnabled("market")) then return end
    local link
    if tip.GetItem then
        local ok, _, itemLink = pcall(tip.GetItem, tip)
        if ok and Readable(itemLink) then link = itemLink end
    end
    if not (type(link) == "string" or Number(id)) then return end
    local key = link or id
    if tip.tempusMarketKey == key then return end
    local quote = self:Quote(link, id)
    if not Number(Store().scanned) then return end     -- never scanned this realm: stay quiet
    tip.tempusMarketKey = key
    if not quote then
        tip:AddDoubleLine("Tempus AH estimate", "No scanned price", .65, .75, .85, .6, .6, .6)
        return
    end
    tip:AddDoubleLine("Tempus AH estimate / item", Money(quote.price), .65, .75, .85, 1, .82, .25)
    local owner = tip.GetOwner and tip:GetOwner()
    local record = owner and owner.tempusRecord
    if record and Number(record.count) and record.count > 1 then
        tip:AddDoubleLine("Stack (" .. record.count .. ")", Money(quote.price * record.count), .65, .75, .85, 1, .82, .25)
    end
    local age = quote.age
    local text = age and (age == 0 and "Seen today" or ("Seen %d day%s ago"):format(age, age == 1 and "" or "s")) or "Age unknown"
    if age and age >= (db.staleDays or 3) then text = text .. " · stale" end
    tip:AddDoubleLine("Tempus scan", text, .5, .55, .6, .75, .75, .75)
end

-- Modern item callbacks include comparison, embedded and addon-created tooltips.
-- Attach cleanup lazily so late-created tooltips are supported too.
local function PrepareTooltip(tip, legacy)
    if not (tip and tip.AddDoubleLine and tip.HookScript) then return false end
    if tip.HasScript and not tip:HasScript("OnTooltipCleared") then return false end
    if not tip.tempusMarketClearHook then
        tip:HookScript("OnTooltipCleared", function(t) t.tempusMarketKey = nil end)
        tip.tempusMarketClearHook = true
    end
    if legacy and not tip.tempusMarketItemHook then
        if tip.HasScript and not tip:HasScript("OnTooltipSetItem") then return false end
        tip:HookScript("OnTooltipSetItem", function(t) M:AddTooltip(t) end)
        tip.tempusMarketItemHook = true
    end
    return true
end

function M:HookTooltips()
    if self.hooked then return end
    self.hooked = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
            if PrepareTooltip(tip) then M:AddTooltip(tip, data and data.id) end
        end)
    else
        for _, name in ipairs({"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
            "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "EmbeddedItemTooltip"}) do
            local tip = _G[name]
            PrepareTooltip(tip, true)
            if tip then PrepareTooltip(tip.ItemTooltip, true) end
        end
    end
end


-- Scanner ------------------------------------------------------------------------------------

local function Say(fmt, ...) T:Print(fmt, ...) end

local function AHOpen()
    return M.ahOpen or (AuctionHouseFrame and AuctionHouseFrame.IsShown and AuctionHouseFrame:IsShown())
end

-- Scan progress on the button: it fills with the accent colour as the scan goes, the number stays on top,
-- and the number's colour reverses where the fill is under it (like a bar with its label inside).
local INSET = 2

-- Pure: what to draw for a progress text and a 0..1 fraction on a button `inner` pixels wide, with the
-- accent colour `accent`. fillWidth is whole pixels; the reverse colour is dark on a light accent and
-- white on a dark one so the number reads on the fill.
function M.ProgressState(text, fraction, inner, accent)
    local f = (type(fraction) == "number" and fraction == fraction) and math.max(0, math.min(1, fraction)) or 0
    local c = type(accent) == "table" and accent or { 0.4, 0.7, 1 }
    local lum = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
    local rr, rg, rb = 1, 1, 1
    if lum > 0.55 then rr, rg, rb = 0.04, 0.05, 0.07 end
    return { text = text, fillWidth = math.floor(f * inner + 0.5), reverse = { rr, rg, rb }, accent = c }
end

local function BuildProgress(b)
    local S = T.Style
    if b.progress then return b.progress end
    if not (S and S.Text and S.Tex and CreateFrame) then return nil end
    local level = b.GetFrameLevel and b:GetFrameLevel() or 1
    local pr = {}
    pr.fillFrame = CreateFrame("Frame", nil, b)
    pr.fillFrame:SetPoint("TOPLEFT", b, "TOPLEFT", INSET, -INSET)
    pr.fillFrame:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -INSET, INSET)
    if pr.fillFrame.SetFrameLevel then pr.fillFrame:SetFrameLevel(level + 1) end
    pr.fill = S.Tex(pr.fillFrame, "ARTWORK")
    pr.fill:SetPoint("TOPLEFT", pr.fillFrame, "TOPLEFT", 0, 0)
    pr.fill:SetPoint("BOTTOMLEFT", pr.fillFrame, "BOTTOMLEFT", 0, 0)
    if S.Accent then S.Accent(pr.fill, 0.95) end
    pr.textFrame = CreateFrame("Frame", nil, b)
    pr.textFrame:SetAllPoints(b)
    if pr.textFrame.SetFrameLevel then pr.textFrame:SetFrameLevel(level + 2) end
    pr.base = S.Text(pr.textFrame, 11, S.C and S.C.text or { 1, 1, 1 })
    pr.base:SetPoint("CENTER", b, "CENTER", 0, 0)
    -- The same number again in the reverse colour, shown only over the filled part.
    pr.clip = CreateFrame("Frame", nil, b)
    pr.clip:SetPoint("TOPLEFT", b, "TOPLEFT", INSET, -INSET)
    pr.clip:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", INSET, INSET)
    if pr.clip.SetFrameLevel then pr.clip:SetFrameLevel(level + 3) end
    if pr.clip.SetClipsChildren then pr.clip:SetClipsChildren(true) end
    pr.inverse = S.Text(pr.clip, 11, { 1, 1, 1 })
    pr.inverse:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.progress = pr
    return pr
end

function M:SetProgress(text, fraction)
    local b = self.button
    if not b then return end
    local pr = text and BuildProgress(b) or b.progress
    if not text or not pr then
        if pr then pr.fillFrame:Hide(); pr.textFrame:Hide(); pr.clip:Hide() end
        b:SetText(text or "Tempus scan")
        return
    end
    local width = b.GetWidth and b:GetWidth()
    local state = M.ProgressState(text, fraction, (type(width) == "number" and width or 130) - 2 * INSET, T.accent)
    b:SetText("")
    pr.fillFrame:Show(); pr.textFrame:Show()
    pr.fill:SetWidth(math.max(state.fillWidth, 1))
    pr.fill:SetShown(state.fillWidth > 0)
    pr.clip:SetWidth(math.max(state.fillWidth, 1))
    pr.clip:SetShown(state.fillWidth > 0)
    pr.base:SetText(state.text)
    pr.inverse:SetText(state.text)
    pr.inverse:SetTextColor(state.reverse[1], state.reverse[2], state.reverse[3])
end

function M:Reset()
    self.scanning, self.processing, self.token = false, false, (self.token or 0) + 1
    if self.frame then self.frame:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE") end
    self:SetProgress()
end

function M:Fail(reason)
    self:Reset()
    Say("Auction scan stopped: %s", reason)
end

function M:NextScanIn()
    local last = Store().scanned
    if not Number(last) then return 0 end
    return math.max(0, SCAN_COOLDOWN - (time() - last))
end

function M:StartScan(auto)
    local api = C_AuctionHouse
    if not (api and api.ReplicateItems and api.GetNumReplicateItems and api.GetReplicateItemInfo) then
        if not auto then Say("This client has no auction house scan API.") end
        return false
    end
    if not AHOpen() then
        if not auto then Say("Open the auction house first, then scan.") end
        return false
    end
    if self.scanning then return false end
    local wait = self:NextScanIn()
    if wait > 0 then
        if not auto then Say("The auction house can be scanned again in %d min %d s.", math.floor(wait / 60), wait % 60) end
        return false
    end
    self:EnsureFrame()
    self.scanning, self.token = true, (self.token or 0) + 1
    local token = self.token
    self.frame:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    local ok = pcall(api.ReplicateItems)
    if not ok then return self:Fail("the client refused the request.") or false end
    Say("Scanning the auction house...")
    self:SetProgress("Requesting...", 0)
    if C_Timer and C_Timer.After then
        C_Timer.After(TIMEOUT, function()
            if M.scanning and not M.processing and M.token == token then M:Fail("no answer from the server. Try again shortly.") end
        end)
    end
    return true
end

function M:Process()
    local api = C_AuctionHouse
    local total = api.GetNumReplicateItems() or 0
    local best, auctions, token = {}, 0, self.token
    local index = 0
    local function step()
        if M.token ~= token or not M.scanning then return end
        local last = math.min(index + BATCH, total) - 1
        for i = index, last do
            local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = api.GetReplicateItemInfo(i)
            if Readable(count) and Readable(buyout) and Readable(itemID)
                and Number(count) and count > 0 and Number(buyout) and buyout > 0 and Number(itemID) and itemID > 0 then
                local unit = math.ceil(buyout / count)
                auctions = auctions + 1
                if not best[itemID] or unit < best[itemID] then best[itemID] = unit end
            end
        end
        index = last + 1
        if index < total then
            M:SetProgress(("%d%%"):format(math.floor(index / total * 100)), index / total)
            C_Timer.After(0, step)
        else
            M:Commit(best, auctions)
        end
    end
    step()
end

function M:Commit(best, auctions)
    local store, now, kept, count = Store(), time(), {}, 0
    for id, row in pairs(store.items) do
        if Number(row.t) and now - row.t < PRUNE_AFTER then kept[id] = row end
    end
    for id, price in pairs(best) do kept[id] = { p = price, t = now }; count = count + 1 end
    store.items, store.scanned = kept, now
    self:Reset()
    if self.RefreshUpgrades then self:RefreshUpgrades() end
    Say("Auction scan finished: %d items priced from %d auctions.", count, auctions)
end

function M:EnsureButton()
    if self.button or not (AuctionHouseFrame and CreateFrame) then return end
    local ok, b = pcall(CreateFrame, "Button", "TempusAuctionScanButton", AuctionHouseFrame, "UIPanelButtonTemplate")
    if not (ok and b) then return end
    b:SetSize(130, 22)
    b:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 4, -4)
    -- Sit above the auction house's own art in the corner.
    if b.SetFrameLevel and AuctionHouseFrame.GetFrameLevel then b:SetFrameLevel(AuctionHouseFrame:GetFrameLevel() + 20) end
    b:SetText("Tempus scan")
    b:SetScript("OnClick", function() M:StartScan() end)
    -- Match the Tempus window skin when it is on (stock skin and the Classic theme keep Blizzard's look).
    local SK = T.Skins
    if SK and SK.On and SK.Button and SK:On("windows") then pcall(SK.Button, SK, b) end
    self.button = b
    if self.EnsureUpgradeButton then self:EnsureUpgradeButton(b) end
end

function M:EnsureFrame()
    if self.frame then return end
    local f = CreateFrame("Frame")
    f:RegisterEvent("AUCTION_HOUSE_SHOW")
    f:RegisterEvent("AUCTION_HOUSE_CLOSED")
    f:RegisterEvent("MAIL_SHOW")
    f:RegisterEvent("MAIL_SEND_SUCCESS")
    f:SetScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_SHOW" then
            M.ahOpen = true
            if T:ModuleEnabled("market") then
                M:EnsureButton()
                if T.db.market and T.db.market.autoScan then M:StartScan(true) end
            end
        elseif event == "AUCTION_HOUSE_CLOSED" then
            M.ahOpen = false
            if M.scanning then M:Fail("the auction house was closed.") end
        elseif event == "MAIL_SHOW" then
            M:OfferQueuedMail()
        elseif event == "MAIL_SEND_SUCCESS" then
            M:MailSent()
        elseif event == "REPLICATE_ITEM_LIST_UPDATE" and M.scanning and not M.processing then
            M.processing = true
            M.frame:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
            M:Process()
        end
    end)
    self.frame = f
end

T:NewModule("market", {
    label = "Auction values",
    desc = "Tempus scans the auction house itself and shows the lowest buyout on item tooltips.",
    defaults = M.defaults,
    OnEnable = function() M:EnsureFrame(); M:HookTooltips() end,
})

-- Mailing the gear data report ---------------------------------------------------------------------
-- The report is queued, and the next time you open a mailbox Tempus asks whether to send it. It only fills
-- in the Send Mail tab (recipient, subject, text); you press Send yourself, once per part.

-- Text cut into mail-sized parts at line breaks (a mail holds about 500 characters).
function M.MailParts(text, max)
    max = max or 450
    local parts, cur = {}, ""
    for line in tostring(text or ""):gmatch("[^\n]+") do
        line = line:gsub("|", "/")
        while #line > max do
            if cur ~= "" then parts[#parts + 1] = cur; cur = "" end
            parts[#parts + 1] = line:sub(1, max)
            line = line:sub(max + 1)
        end
        if #cur + #line + 1 > max and cur ~= "" then parts[#parts + 1] = cur; cur = "" end
        cur = cur == "" and line or (cur .. "\n" .. line)
    end
    if cur ~= "" then parts[#parts + 1] = cur end
    return parts
end

function M:QueueReportMail(to, text)
    to = tostring(to or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local parts = M.MailParts(text)
    if to == "" or #parts == 0 or not T.db.market then return false end
    T.db.market.mailQueue = { to = to, parts = parts, total = #parts }
    T:Print("queued %d mail%s to %s. Tempus will ask when you open a mailbox.", #parts, #parts == 1 and "" or "s", to)
    return true
end

function M:FillMail()
    local q = T.db.market and T.db.market.mailQueue
    if not (q and q.parts and q.parts[1]) then return false end
    if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, 2) end
    if not (SendMailNameEditBox and SendMailSubjectEditBox and SendMailBodyEditBox) then
        T:Print("the Send Mail tab is not available.")
        return false
    end
    SendMailNameEditBox:SetText(q.to)
    SendMailSubjectEditBox:SetText(("Tempus gear data (%d/%d)"):format(q.total - #q.parts + 1, q.total))
    SendMailBodyEditBox:SetText(q.parts[1])
    q.filled = true
    T:Print("gear data filled in for %s. Press Send.", q.to)
    return true
end

function M:OfferQueuedMail()
    local q = T.db and T.db.market and T.db.market.mailQueue
    if not (q and q.parts and q.parts[1]) then return end
    T:Confirm(("Mail your gear data to %s? It is %d short mail%s; you press Send for each."):format(q.to, #q.parts, #q.parts == 1 and "" or "s"),
        function() M:FillMail() end, "Fill in the mail")
end

-- After a send, move to the next part, or finish.
function M:MailSent()
    local q = T.db and T.db.market and T.db.market.mailQueue
    if not (q and q.parts and q.filled) then return end
    table.remove(q.parts, 1)
    q.filled = nil
    if #q.parts == 0 then
        T.db.market.mailQueue = false
        T:Print("gear data mailed to %s. Thank you!", q.to)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0.6, function() M:FillMail() end)
    end
end
