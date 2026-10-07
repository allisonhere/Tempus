-- Tempus UI: WoW container compatibility and exclusive bag-frame ownership.
local _, T = ...
local Bags = T.Bags or {}
T.Bags = Bags

local Client = {}
Client.__index = Client
Bags.Client = Client

Client.conflictFamilies = {
    { label = "Bagnon", addons = { "Bagnon", "Bagnon_Bank", "Bagnon_Config", "Bagnon_GuildBank", "BagBrother" } },
    { label = "Baganator", addons = { "Baganator" } },
    { label = "BetterBags", addons = { "BetterBags", "BetterBags_Config" } },
    { label = "AdiBags", addons = { "AdiBags" } },
    { label = "ArkInventory", addons = { "ArkInventory" } },
    { label = "Combuctor", addons = { "Combuctor" } },
    { label = "LiteBag", addons = { "LiteBag" } },
    { label = "OneBag3", addons = { "OneBag3" } },
}

function Client.New(env)
    return setmetatable({ env = env or _G, claimed = false }, Client)
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j, k, l, m end
end

-- Like Call, for functions with more return values than Call forwards.
local function CallAll(fn, ...)
    if type(fn) ~= "function" then return end
    local out = { pcall(fn, ...) }
    if table.remove(out, 1) then return unpack(out, 1, 20) end
end

function Client:NumBags()
    return self.env.NUM_TOTAL_EQUIPPED_BAG_SLOTS or self.env.NUM_BAG_SLOTS or 4
end

function Client:SlotCount(container)
    local C = self.env.C_Container
    local fn = C and C.GetContainerNumSlots or self.env.GetContainerNumSlots
    local count = Call(fn, container)
    return T.Num(count) and math.max(0, count) or 0
end

function Client:BagFamily(container)
    local C = self.env.C_Container
    local fn = C and C.GetContainerNumFreeSlots or self.env.GetContainerNumFreeSlots
    local _, family = Call(fn, container)
    return T.Num(family) and family or 0
end

-- Container ids moved from globals to Enum.BagIndex on newer clients.
function Client:Index(global, enumKey)
    local env = self.env
    if env[global] ~= nil then return env[global] end
    local index = env.Enum and env.Enum.BagIndex
    return index and index[enumKey] or nil
end

function Client:ContainerIDs(storage)
    local env, ids, numBags = self.env, {}, self:NumBags()
    if storage == "CARRIED" then
        for id = env.BACKPACK_CONTAINER or 0, numBags do ids[#ids + 1] = id end
        if env.KEYRING_CONTAINER and type(env.HasKey) == "function" and Call(env.HasKey) then
            ids[#ids + 1] = env.KEYRING_CONTAINER
        end
    elseif storage == "BANK" then
        local bank = self:Index("BANK_CONTAINER", "Bank")
        if bank ~= nil then ids[#ids + 1] = bank end
        local bankBags = env.NUM_BANKBAGSLOTS
            or (env.Constants and env.Constants.InventoryConstants and env.Constants.InventoryConstants.NumCharacterBankSlots)
            or 0
        for id = numBags + 1, numBags + bankBags do ids[#ids + 1] = id end
    elseif storage == "REAGENT" then
        local reagent = self:Index("REAGENTBANK_CONTAINER", "Reagentbank")
        if reagent ~= nil then ids[1] = reagent end
    end
    return ids
end

function Client:Locations(storage)
    local out = {}
    for _, container in ipairs(self:ContainerIDs(storage)) do
        for slot = 1, self:SlotCount(container) do
            out[#out + 1] = { storage = storage, container = container, slot = slot }
        end
    end
    return out
end

function Client:Read(location)
    local env, C = self.env, self.env.C_Container
    local info
    if C and C.GetContainerItemInfo then
        info = Call(C.GetContainerItemInfo, location.container, location.slot)
    elseif env.GetContainerItemInfo then
        local icon, count, locked, quality, readable, _, link, _, noValue, itemID, bound =
            Call(env.GetContainerItemInfo, location.container, location.slot)
        if itemID or link then
            info = { iconFileID = icon, stackCount = count, isLocked = locked, quality = quality,
                isReadable = readable, hyperlink = link, hasNoValue = noValue, itemID = itemID, isBound = bound }
        end
    end
    if type(info) ~= "table" then return { bagFamily = self:BagFamily(location.container) } end

    local itemID, link = info.itemID, info.hyperlink
    local name, itemLink, quality, baseLevel, _, itemType, itemSubType, _, equipLoc, icon,
        _, classID, subClassID, bindType = CallAll(env.GetItemInfo, itemID or link)
    local quest
    local questFn = C and C.GetContainerItemQuestInfo or env.GetContainerItemQuestInfo
    local questInfo, legacyQuest = Call(questFn, location.container, location.slot)
    if type(questInfo) == "table" then quest = questInfo.isQuestItem
    elseif questInfo ~= nil then quest = legacyQuest end
    local newFn = env.C_NewItems and env.C_NewItems.IsNewItem
    local durability, maxDurability = Call(C and C.GetContainerItemDurability, location.container, location.slot)
    local detailed = env.C_Item and env.C_Item.GetDetailedItemLevelInfo
    local itemLevel = Call(detailed, link or itemID)
    return {
        itemLevel = T.Num(itemLevel) and itemLevel > 0 and itemLevel or (T.Num(baseLevel) and baseLevel > 0 and baseLevel or nil),
        bindType = T.Num(bindType) and bindType or nil,
        bound = info.isBound and true or false,
        durability = T.Num(durability) and durability or nil,
        maxDurability = T.Num(maxDurability) and maxDurability or nil,
        itemID = T.Num(itemID) and itemID or nil,
        link = T.Str(link) and link or (T.Str(itemLink) and itemLink or nil),
        name = T.Str(name) and name or nil,
        icon = info.iconFileID or icon,
        count = T.Num(info.stackCount) and info.stackCount or 1,
        quality = T.Num(info.quality) and info.quality or (T.Num(quality) and quality or nil),
        classID = T.Num(classID) and classID or nil,
        subClassID = T.Num(subClassID) and subClassID or nil,
        itemType = T.Str(itemType) and itemType or nil,
        itemSubType = T.Str(itemSubType) and itemSubType or nil,
        equipLoc = T.Str(equipLoc) and equipLoc or nil,
        locked = info.isLocked and true or false,
        readable = info.isReadable ~= false,
        quest = quest and true or false,
        isNew = newFn and Call(newFn, location.container, location.slot) and true or false,
        hasNoValue = info.hasNoValue and true or false,
        bagFamily = self:BagFamily(location.container),
    }
end

function Client:IsReagentAvailable()
    local env = self.env
    local reagent = self:Index("REAGENTBANK_CONTAINER", "Reagentbank")
    if reagent == nil then return false end
    if type(env.IsReagentBankUnlocked) == "function" and not Call(env.IsReagentBankUnlocked) then return false end
    return self:SlotCount(reagent) > 0
end

function Client:Sort(storage)
    local env, C = self.env, self.env.C_Container
    local fn
    if storage == "CARRIED" then fn = C and C.SortBags or env.SortBags
    elseif storage == "BANK" then fn = C and (C.SortBankBags or C.SortBank) or env.SortBankBags
    elseif storage == "REAGENT" then fn = C and C.SortReagentBankBags or env.SortReagentBankBags end
    if type(fn) ~= "function" then return false, "sorting is not available on this client" end
    local ok, err = pcall(fn)
    return ok, ok and nil or tostring(err)
end

-- Addon state is always read and written for the current character (no character argument).
-- Naming one explicitly breaks on clients that do not recognise our identifier: they treat it as an
-- unknown character and report every addon as enabled, which looked like a conflict that was not there.
local function AddOnEnabled(env, name)
    local modern = env.C_AddOns and env.C_AddOns.GetAddOnEnableState
    local state = Call(modern, name)
    if state == nil then state = Call(env.GetAddOnEnableState, nil, name) end
    return T.Num(state) and state > 0
end

function Client:EnabledConflicts()
    local conflicts = {}
    for _, family in ipairs(self.conflictFamilies) do
        local enabled = {}
        for _, name in ipairs(family.addons) do
            if AddOnEnabled(self.env, name) then enabled[#enabled + 1] = name end
        end
        if #enabled > 0 then conflicts[#conflicts + 1] = { label = family.label, addons = enabled } end
    end
    return conflicts
end

function Client:DisableConflicts(conflicts)
    local env = self.env
    local fn = env.C_AddOns and env.C_AddOns.DisableAddOn or env.DisableAddOn
    if type(fn) ~= "function" then return false, "this client cannot disable addons" end
    for _, family in ipairs(conflicts) do
        for _, name in ipairs(family.addons) do
            local ok, err = pcall(fn, name)
            if not ok then return false, tostring(err) end
        end
    end
    local remaining = self:EnabledConflicts()
    if #remaining > 0 then return false, remaining[1].label .. " is still enabled" end
    return true
end

-- Slots Blizzard compares an equippable against, by equip location.
local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_RANGED = { 16 },
    INVTYPE_RANGEDRIGHT = { 16 },
}

-- Item level of what you wear in the slot(s) an item would replace: the lowest of them, nil if a
-- slot is empty or unreadable (an empty slot counts as 0, so anything is an upgrade).
function Client:EquippedLevel(equipLoc)
    local slots, env = EQUIP_SLOTS[equipLoc], self.env
    if not slots then return nil end
    local detailed = env.C_Item and env.C_Item.GetDetailedItemLevelInfo
    local lowest
    for _, slot in ipairs(slots) do
        local link = Call(env.GetInventoryItemLink, "player", slot)
        local level = link and Call(detailed, link) or 0
        if not T.Num(level) then return nil end
        if lowest == nil or level < lowest then lowest = level end
    end
    return lowest
end

function Client:Cooldown(location)
    local env, C = self.env, self.env.C_Container
    local start, duration, enabled = Call(C and C.GetContainerItemCooldown or env.GetContainerItemCooldown,
        location.container, location.slot)
    if type(start) == "table" then start, duration, enabled = start.startTime, start.duration, start.isEnabled end
    if not (T.Num(start) and T.Num(duration)) or duration <= 0 or enabled == false or enabled == 0 then return nil end
    return start, duration
end

function Client:Money()
    local money = Call(self.env.GetMoney)
    return T.Num(money) and money or 0
end

-- Up to three watched currencies as { name, quantity, icon }; empty when the client has no such API.
function Client:Currencies()
    local api, out = self.env.C_CurrencyInfo, {}
    local fn = api and api.GetBackpackCurrencyInfo
    if type(fn) ~= "function" then return out end
    for index = 1, 3 do
        local info = Call(fn, index)
        if type(info) ~= "table" then break end
        if T.Num(info.quantity) then
            out[#out + 1] = { name = T.Str(info.name) and info.name or "", quantity = info.quantity, icon = info.iconFileID }
        end
    end
    return out
end

function Client:BagIcon(container)
    local env, C = self.env, self.env.C_Container
    if container == (env.BACKPACK_CONTAINER or 0) then return "Interface\\Buttons\\Button-Backpack-Up" end
    local invSlot = Call(C and C.ContainerIDToInventoryID or env.ContainerIDToInventoryID, container)
    local texture = invSlot and Call(env.GetInventoryItemTexture, "player", invSlot)
    return texture
end

function Client:BagName(container)
    if container == (self.env.BACKPACK_CONTAINER or 0) then return "Backpack" end
    local name = Call(self.env.C_Container and self.env.C_Container.GetBagName or self.env.GetBagName, container)
    return T.Str(name) and name or ("Bag " .. tostring(container))
end

function Client:CreateProxy(parent, container)
    local proxy = self.env.CreateFrame("Frame", nil, parent)
    proxy:SetID(container)
    return proxy
end

function Client:CreateItemButton(parent)
    return self.env.CreateFrame("ItemButton", nil, parent, "ContainerFrameItemButtonTemplate")
end

-- Only the slot id is set, and the bag id comes from the proxy parent's id. Do not write fields such
-- as button.bagID or call the template's Update/SetBagID: Blizzard's click handler reads those, and
-- anything an addon wrote there taints it and blocks the protected UseContainerItem (right-click use).
function Client:BindItemButton(button, record)
    if button:GetID() ~= record.location.slot then button:SetID(record.location.slot) end
end

function Client:ShowTooltip(button, record)
    local tip = self.env.GameTooltip
    if not tip or not record.link then return end
    tip:SetOwner(button, "ANCHOR_RIGHT")
    tip:SetHyperlink(record.link)
    tip:Show()
end

function Client:OwnedContainer(container)
    for _, storage in ipairs({ "CARRIED", "BANK", "REAGENT" }) do
        for _, id in ipairs(self:ContainerIDs(storage)) do
            if id == container then return true end
        end
    end
    return false
end

-- Every stock frame that can show our containers: the combined-bags frame and the per-bag frames.
function Client:StockFrames()
    local env, frames = self.env, {}
    if env.ContainerFrameCombinedBags then frames[1] = env.ContainerFrameCombinedBags end
    for i = 1, env.NUM_CONTAINER_FRAMES or 13 do
        if env["ContainerFrame" .. i] then frames[#frames + 1] = env["ContainerFrame" .. i] end
    end
    return frames
end

function Client:StockBagsShown()
    for _, frame in ipairs(self:StockFrames()) do
        if frame.IsShown and frame:IsShown() and frame.GetID and self:OwnedContainer(frame:GetID()) then
            return true
        end
    end
    return false
end

function Client:SuppressStockBags()
    for _, frame in ipairs(self:StockFrames()) do
        if frame.GetID and self:OwnedContainer(frame:GetID()) then
            if self.hidden then frame:SetParent(self.hidden) end
            frame:Hide()
        end
    end
    if self.env.BackpackTokenFrame then self.env.BackpackTokenFrame:Hide() end
end

-- Stock code asked for our window to change. shown == true/false is an explicit open/close request;
-- nil only re-checks the stock frames and can open our window but never close it (they stay hidden
-- while ours is up, so "nothing shown" proves nothing).
function Client:QueueStockSync(shown)
    if shown ~= nil then self.syncDesired = shown end
    if self.syncQueued then return end
    self.syncQueued = true
    local function Run()
        self.syncQueued = nil
        local desired = self.syncDesired
        self.syncDesired = nil
        if desired == nil and self:StockBagsShown() then desired = true end
        if desired then self:SuppressStockBags() end
        if desired ~= nil and self.onStockSync then self.onStockSync(desired) end
    end
    local timer = self.env.C_Timer and self.env.C_Timer.After
    if timer then timer(0, Run) else Run() end
end

function Client:Claim(onStockSync, isShown)
    if self.claimed then return true end
    local env = self.env
    if type(env.CreateFrame) ~= "function" or type(env.hooksecurefunc) ~= "function" then
        return false, "the client has no safe bag-frame hook support"
    end
    self.hidden = env.CreateFrame("Frame", nil, env.UIParent)
    self.hidden:Hide()
    self.onStockSync = onStockSync
    self.isShown = isShown

    for _, frame in ipairs(self:StockFrames()) do
        if type(frame.SetID) == "function" then
            if frame.GetID and self:OwnedContainer(frame:GetID()) then frame:SetParent(self.hidden) end
            env.hooksecurefunc(frame, "SetID", function(stock, container)
                if self:OwnedContainer(container) then stock:SetParent(self.hidden) end
            end)
            env.hooksecurefunc(frame, "Show", function(stock)
                if stock.GetID and self:OwnedContainer(stock:GetID()) then
                    self:QueueStockSync(true)
                    stock:SetParent(self.hidden)
                    stock:Hide()
                end
            end)
        end
    end
    -- Toggling: with the stock frames hidden, Blizzard believes the bags are closed and "opens" them.
    -- If our window is already up, that open request really meant close.
    for _, name in ipairs({ "ToggleAllBags", "ToggleBackpack" }) do
        if type(env[name]) == "function" then
            env.hooksecurefunc(name, function()
                if self.syncDesired == true and self.isShown and self.isShown() then self.syncDesired = false end
                self:QueueStockSync()
            end)
        end
    end
    for _, name in ipairs({ "CloseAllBags", "CloseBackpack" }) do
        if type(env[name]) == "function" then
            env.hooksecurefunc(name, function() self:QueueStockSync(false) end)
        end
    end
    for _, name in ipairs({ "ToggleBag", "OpenAllBags", "OpenBackpack", "OpenBag" }) do
        if type(env[name]) == "function" then
            env.hooksecurefunc(name, function() self:QueueStockSync() end)
        end
    end
    if type(env.ShowUIPanel) == "function" then
        env.hooksecurefunc("ShowUIPanel", function(panel)
            if panel and panel == env.BankFrame and not self.managingBank then panel:SetParent(self.hidden) end
        end)
    end
    if type(env.ContainerFrame_GenerateFrame) == "function" then
        env.hooksecurefunc("ContainerFrame_GenerateFrame", function()
            self:QueueStockSync()
        end)
    end
    self.claimed = true
    return true
end

function Client:SuppressBank()
    local bank = self.env.BankFrame
    if bank and self.hidden and not self.managingBank then bank:SetParent(self.hidden) end
end

function Client:ShowBankManagement(show)
    local env, bank = self.env, self.env.BankFrame
    if not bank then return false end
    self.managingBank = show and true or false
    bank:SetParent(show and env.UIParent or self.hidden)
    if show then
        if env.ShowUIPanel then env.ShowUIPanel(bank) else bank:Show() end
    end
    return true
end

function Client:ToggleCarried()
    local toggle = self.env.ToggleAllBags
    if type(toggle) == "function" then toggle(); return true end
    return false
end

function Client:CloseCarried()
    local close = self.env.CloseAllBags
    if type(close) == "function" then close(); return true end
    return false
end

function Client:CloseBank()
    local env = self.env
    if env.C_Bank and env.C_Bank.CloseBankFrame then env.C_Bank.CloseBankFrame(); return true end
    if env.HideUIPanel and env.BankFrame then env.HideUIPanel(env.BankFrame); return true end
    return false
end
