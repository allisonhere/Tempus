-- Tempus scans the auction house itself (C_AuctionHouse.ReplicateItems) and keeps the lowest
-- buyout per item for each realm, account-wide. No other addon is involved.
local _, T = ...
local M = { defaults = { tooltips = true, staleDays = 3, autoScan = false, upgradeMinGain = 1, upgradeAffordable = false, upgradePos = false } }
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

function M:SetProgress(text)
    if self.button then self.button:SetText(text or "Tempus scan") end
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
    self:SetProgress("Requesting...")
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
            M:SetProgress(("%d%%"):format(math.floor(index / total * 100)))
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
