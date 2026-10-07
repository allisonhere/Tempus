local T = {
    Bags = {},
    Num = function(v) return type(v) == "number" and v == v end,
    Str = function(v) return type(v) == "string" and v ~= "" end,
    Readable = function(v) return v ~= nil end,
}
assert(loadfile("Modules/Bags/Client.lua"))("Tempus", T)
local Client = T.Bags.Client

local item = { itemID = 42, hyperlink = "item:42", iconFileID = 7, stackCount = 3,
    quality = 2, isLocked = false, hasNoValue = false }
local function itemInfo()
    return "Copper Sword", "item:42", 2, 10, 1, "Weapon", "Sword", 1,
        "INVTYPE_WEAPON", 7, 12, 2, 7
end

local modernEnv = {
    NUM_BAG_SLOTS = 2, NUM_BANKBAGSLOTS = 1, BANK_CONTAINER = -1, REAGENTBANK_CONTAINER = -3,
    C_Container = {
        GetContainerNumSlots = function(bag) return ({ [0] = 2, [1] = 1, [2] = 1, [-1] = 2, [3] = 1, [-3] = 2 })[bag] or 0 end,
        GetContainerNumFreeSlots = function() return 0, 0 end,
        GetContainerItemInfo = function(bag, slot) if bag == 0 and slot == 1 then return item end end,
        GetContainerItemQuestInfo = function() return { isQuestItem = false } end,
    },
    C_NewItems = { IsNewItem = function(bag, slot) return bag == 0 and slot == 1 end },
    GetItemInfo = itemInfo,
}
local legacyEnv = {
    NUM_BAG_SLOTS = 2, NUM_BANKBAGSLOTS = 1, BANK_CONTAINER = -1, REAGENTBANK_CONTAINER = -3,
    GetContainerNumSlots = modernEnv.C_Container.GetContainerNumSlots,
    GetContainerNumFreeSlots = function() return 0, 0 end,
    GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return 7, 3, false, 2, false, false, "item:42", false, false, 42 end
    end,
    GetItemInfo = itemInfo,
}

local modern, legacy = Client.New(modernEnv), Client.New(legacyEnv)
local carried = modern:Locations("CARRIED")
assert(#carried == 4 and carried[1].container == 0 and carried[4].container == 2, "carried containers")
local bank = modern:Locations("BANK")
assert(#bank == 3 and bank[1].container == -1 and bank[3].container == 3, "personal bank containers")
assert(#modern:Locations("REAGENT") == 2, "feature-detected reagent bank")

local a, b = modern:Read(carried[1]), legacy:Read(carried[1])
for _, key in ipairs({ "itemID", "link", "name", "icon", "count", "quality", "classID", "subClassID", "equipLoc" }) do
    assert(a[key] == b[key], "modern and legacy normalize " .. key)
end
assert(a.isNew and not b.isNew, "new-item state is capability driven")
assert(modern:Read(carried[2]).itemID == nil, "empty slot")

local disabled = {}
local enabled = { Bagnon = true, BagBrother = true }
local conflictClient = Client.New({
    C_AddOns = {
        GetAddOnEnableState = function(name, character)
            assert(character == nil, "state is read for the current character")
            return enabled[name] and 2 or 0 end,
        DisableAddOn = function(name, character)
            assert(character == nil, "disable targets the current character without naming one")
            enabled[name] = nil
            disabled[#disabled + 1] = name
        end,
    },
})
local conflicts = conflictClient:EnabledConflicts()
assert(#conflicts == 1 and conflicts[1].label == "Bagnon" and #conflicts[1].addons == 2,
    "enabled addons collapse into one conflict family")
assert(conflictClient:DisableConflicts(conflicts), "conflicts can be disabled")
assert(disabled[1] == "Bagnon" and disabled[2] == "BagBrother",
    "only enabled family members are disabled for this character")

-- Item level, durability, cooldowns, comparison, money and currencies.
do
    local worn = { [16] = "item:worn1", [17] = "item:worn2" }
    local levels = { ["item:42"] = 55, ["item:worn1"] = 40, ["item:worn2"] = 30 }
    local env = {
        C_Container = {
            GetContainerNumSlots = function() return 1 end,
            GetContainerNumFreeSlots = function() return 0, 0 end,
            GetContainerItemInfo = function() return item end,
            GetContainerItemDurability = function() return 20, 100 end,
            GetContainerItemCooldown = function() return 100, 30, 1 end,
        },
        C_Item = { GetDetailedItemLevelInfo = function(link) return levels[link] end },
        GetItemInfo = function() return "Copper Sword", "item:42", 2, 10, 1, "Weapon", "Sword", 1,
            "INVTYPE_WEAPON", 7, 12, 2, 7, 1 end,
        GetInventoryItemLink = function(_, slot) return worn[slot] end,
        GetMoney = function() return 12345 end,
        C_CurrencyInfo = { GetBackpackCurrencyInfo = function(i)
            if i <= 2 then return { name = "Badge " .. i, quantity = i * 10, iconFileID = i } end
        end },
    }
    local client = Client.New(env)
    local record = client:Read({ storage = "CARRIED", container = 0, slot = 1 })
    assert(record.itemLevel == 55 and record.bindType == 1, "detailed item level and bind type")
    assert(record.durability == 20 and record.maxDurability == 100, "durability")
    local start, duration = client:Cooldown({ container = 0, slot = 1 })
    assert(start == 100 and duration == 30, "cooldown")
    env.C_Container.GetContainerItemCooldown = function() return 0, 0, 1 end
    assert(client:Cooldown({ container = 0, slot = 1 }) == nil, "no cooldown when duration is zero")
    assert(client:EquippedLevel("INVTYPE_WEAPON") == 30, "two-slot items compare against the lower slot")
    assert(client:EquippedLevel("INVTYPE_HEAD") == 0, "an empty slot counts as level 0")
    assert(client:EquippedLevel("INVTYPE_BAG") == nil, "non-equippable has no comparison")
    assert(client:Money() == 12345, "money")
    local currencies = client:Currencies()
    assert(#currencies == 2 and currencies[2].quantity == 20, "backpack currencies")
    assert(#Client.New({}):Currencies() == 0, "currencies degrade to empty without the API")
end

-- Stock-frame takeover: combined frame is claimed, and the bag key closes our window.
do
    local env = { NUM_CONTAINER_FRAMES = 1, NUM_BAG_SLOTS = 4, UIParent = {} }
    local function Frame(id)
        local f = { id = id, shown = false }
        function f:SetID(v) self.id = v end
        function f:GetID() return self.id end
        function f:SetParent(p) self.parent = p end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        function f:IsShown() return self.shown end
        return f
    end
    function env.CreateFrame() return Frame(0) end
    env.ContainerFrameCombinedBags, env.ContainerFrame1 = Frame(0), Frame(1)
    function env.hooksecurefunc(target, name, fn)
        if type(target) == "string" then target, name, fn = env, target, name end
        local original = target[name]
        target[name] = function(...) local r = original(...); fn(...); return r end
    end
    function env.ToggleAllBags()
        if env.ContainerFrameCombinedBags:IsShown() then env.CloseAllBags() else env.ContainerFrameCombinedBags:Show() end
    end
    function env.CloseAllBags() env.ContainerFrameCombinedBags:Hide() end
    env.ToggleBag = function() end
    local queue = {}
    env.C_Timer = { After = function(_, fn) queue[#queue + 1] = fn end }
    local function Flush() local run = queue; queue = {}; for _, fn in ipairs(run) do fn() end end

    local ours, client = false, Client.New(env)
    assert(client:Claim(function(shown) ours = shown end, function() return ours end), "claim succeeds")

    env.ToggleAllBags(); Flush()
    assert(ours and not env.ContainerFrameCombinedBags:IsShown() and env.ContainerFrameCombinedBags.parent == client.hidden,
        "opening shows ours and hides the combined stock frame")
    env.ToggleBag(); Flush()
    assert(ours, "an unrelated bag call does not close our window")
    env.ToggleAllBags(); Flush()
    assert(not ours, "the bag key closes our window even though stock thinks bags are closed")
    env.ToggleAllBags(); Flush()
    assert(ours, "and opens it again")
    env.CloseAllBags(); Flush()
    assert(not ours, "CloseAllBags closes our window")
end

print("PASS: bag APIs normalize storage and isolate conflicting bag addons")
