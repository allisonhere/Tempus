-- Auctionator owns scanning and its realm database; Tempus consumes its public API.
local _, T = ...
local M = { defaults = { tooltips = true, staleDays = 3 } }
T.Market = M
local function API()
    local a = _G.Auctionator
    return a and a.API and a.API.v1
end
local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
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

function M:Quote(link, id)
    local api = API()
    if not api then return nil, "unavailable" end
    local price, age
    -- Preserve enchant/suffix/item-level variants whenever a link is available.
    if Readable(link) and type(link) == "string" and link:find("item:", 1, true) then
        price = Call(api.GetAuctionPriceByItemLink, "Tempus", link)
        age = Call(api.GetAuctionAgeByItemLink, "Tempus", link)
    elseif Number(id) and id > 0 then
        price = Call(api.GetAuctionPriceByItemID, "Tempus", id)
        age = Call(api.GetAuctionAgeByItemID, "Tempus", id)
    end
    if not Number(price) or price <= 0 then return nil, "unknown" end
    return {price = price, age = Number(age) and math.floor(age) or nil}
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
    local quote, reason = self:Quote(link, id)
    if reason == "unavailable" then return end
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
    tip:AddDoubleLine("Auctionator · last scan", text, .5, .55, .6, .75, .75, .75)
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

function M:ScanBags()
    local api = API()
    local search = api and (api.MultiSearchExact or api.MultiSearch)
    if type(search) ~= "function" then T:Print("Enable Auctionator to scan auction prices."); return false end
    local open = (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown())
    if not open then T:Print("Visit an auctioneer and open the auction house first."); return false end
    local C = C_Container
    local slots = C and C.GetContainerNumSlots or GetContainerNumSlots
    local info = C and C.GetContainerItemInfo
    local itemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    local terms, seen, skipped = {}, {}, 0
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        local count = Call(slots, bag)
        for slot = 1, (Number(count) and count or 0) do
            local item = Call(info, bag, slot)
            local link
            if type(item) == "table" then
                if Readable(item.isBound) and not item.isBound and Readable(item.hyperlink) then link = item.hyperlink end
            elseif not info and GetContainerItemLink then
                link = Call(GetContainerItemLink, bag, slot)
            end
            if Readable(link) and type(link) == "string" then
                local name = Call(itemInfo, link)
                if Readable(name) and type(name) == "string" and name ~= "" then
                    -- The public API accepts plain names; MultiSearchExact adds its own quoting.
                    if not name:find('[";^]') and not seen[name] then
                        seen[name] = true
                        terms[#terms + 1] = name
                    end
                else skipped = skipped + 1 end
            end
        end
    end
    if #terms == 0 then T:Print("No searchable bag items yet. Let item details load, then try again."); return false end
    table.sort(terms)
    local ok = pcall(search, "Tempus", terms)
    if not ok then T:Print("Auctionator could not start the scan. Finish its current scan and try again."); return false end
    T:Print("Scanning %d bag item names with Auctionator. Re-hover items when it finishes to see updated prices.", #terms)
    if skipped > 0 then T:Print("%d uncached items were skipped; scan again after their details load.", skipped) end
    return true
end

T:NewModule("market", {
    label = "Auction values",
    desc = "Scanned auction estimates on item tooltips, using Auctionator's realm prices.",
    defaults = M.defaults,
    OnEnable = function() M:HookTooltips() end,
})
