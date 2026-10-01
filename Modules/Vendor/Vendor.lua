-- Tempus UI: vendor helper. Sells grey items and repairs gear when a merchant opens.
local _, T = ...
local V = {}
T.Vendor = V

V.defaults = {
    sellGrey = true,
    autoRepair = true,
    guildRepair = false,        -- pay from the guild bank first when allowed
    summary = true,             -- print what was sold and repaired
}

local function Money(copper)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        local ok, text = pcall(C_CurrencyInfo.GetCoinTextureString, copper)
        if ok and text then return text end
    end
    return GetCoinTextureString and GetCoinTextureString(copper) or (copper .. "c")
end

local function GetItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" then return info.quality, info.hasNoValue, info.stackCount, info.itemID end
        return
    end
    if GetContainerItemInfo then
        local _, count, _, quality, _, _, _, _, noValue, itemID = GetContainerItemInfo(bag, slot)
        return quality, noValue, count, itemID
    end
end

local function SellPrice(itemID, count)
    if not itemID or not GetItemInfo then return 0 end
    local price = select(11, GetItemInfo(itemID))
    return T.Num(price) and price * (count or 1) or 0
end

local function UseItem(bag, slot)
    local use = (C_Container and C_Container.UseContainerItem) or UseContainerItem
    if use then pcall(use, bag, slot) end
end

function V:SellGrey()
    local sold, total = 0, 0
    local last = NUM_BAG_SLOTS or 4
    local getSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    if not getSlots then return 0, 0 end
    for bag = 0, last do
        for slot = 1, (getSlots(bag) or 0) do
            local quality, noValue, count, itemID = GetItem(bag, slot)
            -- Quality 0 is grey ("poor"); items with no vendor price stay in the bag.
            if quality == 0 and not noValue then
                total = total + SellPrice(itemID, count)
                sold = sold + 1
                UseItem(bag, slot)
            end
        end
    end
    return sold, total
end

function V:Repair()
    if not (CanMerchantRepair and CanMerchantRepair()) then return 0 end
    local cost = GetRepairAllCost and GetRepairAllCost()
    if not T.Num(cost) or cost <= 0 then return 0 end
    local useGuild = V.db.guildRepair and CanGuildBankRepair and CanGuildBankRepair()
    if not useGuild and GetMoney() < cost then
        T:Print("not enough gold to repair (%s).", Money(cost))
        return 0
    end
    RepairAllItems(useGuild and true or nil)
    return cost, useGuild
end

function V:OnMerchant()
    local db = V.db
    local soldCount, soldCopper, repairCost, guild = 0, 0, 0, false
    if db.sellGrey then soldCount, soldCopper = V:SellGrey() end
    if db.autoRepair then repairCost, guild = V:Repair() end
    if not db.summary then return end
    if soldCount > 0 then
        T:Print("sold %d grey item%s for %s.", soldCount, soldCount == 1 and "" or "s", Money(soldCopper))
    end
    if repairCost > 0 then
        T:Print("repaired for %s%s.", Money(repairCost), guild and " (guild bank)" or "")
    end
end

T:NewModule("vendor", {
    label = "Vendor",
    desc = "Sells grey items and repairs your gear when you open a merchant.",
    defaults = V.defaults,
    OnEnable = function()
        V.db = T.db.vendor
        V.events = CreateFrame("Frame")
        V.events:RegisterEvent("MERCHANT_SHOW")
        V.events:SetScript("OnEvent", T:Wrap("vendor.merchant", function() V:OnMerchant() end))
    end,
    OnSettings = function() V.db = T.db.vendor end,
})
