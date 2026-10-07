-- Tempus UI: native carried-bag and personal-bank controller.
local _, T = ...
local B = T.Bags or {}
T.Bags = B

B.defaults = {
    mode = "GRID",
    columns = 12,
    itemSize = 36,
    spacing = 4,
    showEmpty = true,
    showNew = true,
    showItemLevel = true,
    showUpgrades = true,
    showCooldowns = true,
    showCurrencies = true,
    showBagBar = true,
    showFilters = true,
    sortItems = true,
    collapsed = {},          -- [characterKey][sectionKey] = true
    customCategories = {},   -- [name][itemID] = true
    point = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -24, 180 },
    bankPoint = { "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 24, 180 },
}
B.state = B.state or "UNRESOLVED"
B.query = B.query or { CARRIED = "", BANK = "" }
B.bankStorage = B.bankStorage or "BANK"
B.filter = B.filter or { CARRIED = "ALL", BANK = "ALL" }

local function FamilyLabels(conflicts)
    local labels = {}
    for _, family in ipairs(conflicts or {}) do labels[#labels + 1] = family.label end
    return labels
end

local function SameFamilies(saved, conflicts)
    if type(saved) ~= "table" or type(saved.families) ~= "table" then return false end
    local wanted = {}
    for _, name in ipairs(saved.families) do wanted[name] = true end
    if #saved.families ~= #conflicts then return false end
    for _, family in ipairs(conflicts) do if not wanted[family.label] then return false end end
    return true
end

function B:SaveOwnership(choice, conflicts)
    TempusDB.bagOwners = TempusDB.bagOwners or {}
    TempusDB.bagOwners[T:CharacterKey()] = { choice = choice, families = FamilyLabels(conflicts) }
end

function B:ChooseExternal()
    self:SaveOwnership("EXTERNAL", self.conflicts)
    self.state = "INACTIVE"
end

local function AddonNames(conflicts)
    local names = {}
    for _, family in ipairs(conflicts or {}) do
        for _, name in ipairs(family.addons) do names[#names + 1] = name end
    end
    return table.concat(names, ", ")
end

-- The client refused to change this character's addon list (seen on characters with no per-character
-- addon file). Say what to do by hand instead of failing quietly on every login.
function B:ShowDisableFailed(err)
    self.state = "INACTIVE"
    T:Print("could not disable the other bag addon: %s", err or "unknown error")
    local names = FamilyLabels(self.conflicts)
    StaticPopupDialogs.TEMPUS_BAG_DISABLE_FAILED = {
        text = "Tempus could not disable " .. table.concat(names, ", ") .. " for this character; the game would not allow it.\n\n"
            .. "Open AddOns at the character select screen and disable: " .. AddonNames(self.conflicts)
            .. ".\n\nThen log in again and Tempus Bags will take over.",
        button1 = "Okay",
        button2 = "Keep using " .. table.concat(names, ", "),
        OnCancel = function() B:ChooseExternal() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }
    StaticPopup_Show("TEMPUS_BAG_DISABLE_FAILED")
end

function B:ChooseTempus()
    local ok, err = self.client:DisableConflicts(self.conflicts)
    if not ok then
        self:ShowDisableFailed(err)
        return false
    end
    self:SaveOwnership("TEMPUS", self.conflicts)
    if ReloadUI then ReloadUI() end
    return true
end

function B:ShowConflictPrompt()
    local names = table.concat(FamilyLabels(self.conflicts), ", ")
    StaticPopupDialogs.TEMPUS_BAG_CONFLICT = {
        text = "Tempus Bags and " .. names .. " are both enabled. Which addon should own your bags on this character?",
        button1 = "Use Tempus",
        button2 = "Use " .. names,
        OnAccept = function() B:ChooseTempus() end,
        OnCancel = function() B:ChooseExternal() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }
    StaticPopup_Show("TEMPUS_BAG_CONFLICT")
end

function B:EnsureWindows()
    if self.carriedWindow then return end
    self.carriedWindow = self.Window.New(self, "CARRIED", "Bags", "point")
    self.bankWindow = self.Window.New(self, "BANK", "Bank", "bankPoint")
    self.carriedWindow:ApplyPoint()
    self.bankWindow:ApplyPoint()
end

function B:EnsureEvents()
    if self.events then return end
    self.events = CreateFrame("Frame")
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
        "PLAYERBANKSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED", "REAGENTBANK_PURCHASED",
        "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED" }) do
        pcall(self.events.RegisterEvent, self.events, event)
    end
    self.events:SetScript("OnEvent", function(_, event) self:OnEvent(event) end)
end

function B:Claim()
    local claimed, claimError
    T:RunOOC(function()
        claimed, claimError = self.client:Claim(function(shown) self:SetCarriedShown(shown) end, function()
            return self.carriedWindow and self.carriedWindow.frame:IsShown()
        end)
        self.trace[#self.trace + 1] = "claim=" .. tostring(claimed) .. " err=" .. tostring(claimError)
        if not claimed then
            self.state = "INACTIVE"
            T:Print("Bags could not take over Blizzard's bag frames: %s", claimError or "unknown error")
            return
        end
        self.state = "CLAIMED"
        self:EnsureWindows()
        self:EnsureEvents()
        self:Refresh("CARRIED")
    end, "bags.claim")
end

function B:Start()
    self.client = self.client or self.Client.New(_G)
    self.conflicts = self.client:EnabledConflicts()
    self.trace = { "character=" .. tostring(UnitName("player")), "key=" .. tostring(T:CharacterKey()),
        "conflicts=" .. #self.conflicts }
    if #self.conflicts > 0 then
        local saved = TempusDB.bagOwners and TempusDB.bagOwners[T:CharacterKey()]
        self.trace[#self.trace + 1] = "saved=" .. tostring(saved and saved.choice)
        if saved and saved.choice == "EXTERNAL" and SameFamilies(saved, self.conflicts) then
            self.state = "INACTIVE"
            return
        end
        if saved and saved.choice == "TEMPUS" and SameFamilies(saved, self.conflicts) then
            self.state = "PENDING"
            local ok, err = self.client:DisableConflicts(self.conflicts)
            self.trace[#self.trace + 1] = "disable ok=" .. tostring(ok) .. " err=" .. tostring(err)
            if ok then
                if ReloadUI then ReloadUI() end
            else
                self:ShowDisableFailed(err)
            end
            return
        end
        self.state = "PENDING"
        self:ShowConflictPrompt()
        return
    end
    self:Claim()
end

function B:Snapshot(storage)
    local snapshot = self.Inventory.Snapshot(storage, self.client:Locations(storage), function(location)
        return self.client:Read(location)
    end)
    local previous = self.snapshots and self.snapshots[storage]
    snapshot.revision = previous and previous.revision + 1 or 1
    self.snapshots = self.snapshots or {}
    self.snapshots[storage] = snapshot
    return snapshot
end

function B:Render(storage)
    local actual = storage == "BANK" and self.bankStorage or storage
    local snapshot = self.snapshots and self.snapshots[actual] or self:Snapshot(actual)
    local queryKey = storage == "BANK" and "BANK" or storage
    local projection = self.Inventory.Project(snapshot, self.db.mode, self.query[queryKey] or "", self.db.showEmpty,
        self:ProjectOptions(storage))
    local window = storage == "BANK" and self.bankWindow or self.carriedWindow
    if window and window.frame:IsShown() then window:Render(snapshot, projection) end
end

function B:Refresh(storage)
    self:Snapshot(storage)
    self:Render(storage == "CARRIED" and "CARRIED" or "BANK")
end

function B:SetCarriedShown(shown)
    if self.state ~= "CLAIMED" then return end
    self:EnsureWindows()
    if shown then
        self.carriedWindow.frame:Show()
        self:Refresh("CARRIED")
    else
        self.carriedWindow.frame:Hide()
    end
end

function B:Toggle(scope)
    if scope == "BANK" then
        if self.bankWindow then self.bankWindow.frame:SetShown(not self.bankWindow.frame:IsShown()) end
        return
    end
    if self.state == "CLAIMED" then
        local shown = not self.carriedWindow.frame:IsShown()
        self.client:CloseCarried()
        self:SetCarriedShown(shown)
        return
    end
    self.client:ToggleCarried()
end

function B:Close(storage)
    if storage == "CARRIED" then
        if not self.client:CloseCarried() and self.carriedWindow then self.carriedWindow.frame:Hide() end
    elseif self.bankWindow then
        self.bankWindow.frame:Hide()
        self.client:CloseBank()
    end
end

function B:SetQuery(storage, text)
    self.query[storage] = text or ""
    self:Render(storage)
end

-- Per-character set of folded section keys.
function B:Collapsed()
    local all, key = self.db.collapsed, T:CharacterKey()
    all[key] = all[key] or {}
    return all[key]
end

-- itemID -> custom category name, rebuilt only after an assignment or settings change.
function B:CustomItems()
    if not self.customLookup then
        local lookup = {}
        for name, items in pairs(self.db.customCategories) do
            for itemID in pairs(items) do lookup[itemID] = name end
        end
        self.customLookup = lookup
    end
    return self.customLookup
end

function B:ProjectOptions(storage)
    return {
        filter = self.filter[storage],
        container = storage == "CARRIED" and self.bagFilter or nil,
        sort = self.db.sortItems,
        customItems = self:CustomItems(),
        collapsed = self:Collapsed(),
    }
end

function B:RenderAll()
    self:Render("CARRIED")
    self:Render("BANK")
end

function B:SetFilter(storage, key)
    self.filter[storage] = key
    self:Render(storage)
end

function B:SetBagFilter(container)
    self.bagFilter = self.bagFilter ~= container and container or nil
    self:Render("CARRIED")
end

function B:SetHoverBag(container)
    self.hoverBag = container
    if self.carriedWindow then self.carriedWindow:ApplyHighlight() end
end

function B:ToggleSection(key)
    local collapsed = self:Collapsed()
    collapsed[key] = not collapsed[key] or nil
    self:RenderAll()
end

function B:ToggleTagMode()
    self.tagMode = not self.tagMode
    if self.tagMode then T:Print("Bags tag mode: click an item to put it in a custom category. Click Tag again to finish.") end
    self:RenderAll()
end

-- itemID joins the named category (removed from any other); nil name removes it from custom categories.
function B:AssignCategory(itemID, name)
    for category, items in pairs(self.db.customCategories) do
        items[itemID] = nil
        if next(items) == nil then self.db.customCategories[category] = nil end
    end
    if name and name ~= "" then
        self.db.customCategories[name] = self.db.customCategories[name] or {}
        self.db.customCategories[name][itemID] = true
    end
    self.customLookup = nil
    self:RenderAll()
end

function B:ShowCategoryMenu(anchor, record)
    local itemID = record.itemID
    if not itemID then return end
    local names = {}
    for name in pairs(self.db.customCategories) do names[#names + 1] = name end
    table.sort(names)
    local items = { { "__new", "New category..." } }
    for _, name in ipairs(names) do items[#items + 1] = { name, name } end
    local current = self:CustomItems()[itemID]
    if current then items[#items + 1] = { "__none", "Remove from custom category" } end
    T.UI.OpenMenu(anchor, items, function(value)
        if value == "__new" then
            StaticPopupDialogs.TEMPUS_BAG_CATEGORY = {
                text = "Name the new category for " .. (record.name or "this item") .. ":",
                button1 = ACCEPT or "Accept",
                button2 = CANCEL or "Cancel",
                hasEditBox = 1,
                maxLetters = 24,
                OnAccept = function(dialog, id)
                    local box = (dialog.GetEditBox and dialog:GetEditBox()) or dialog.editBox or dialog.EditBox
                    B:AssignCategory(id, box and box:GetText():match("^%s*(.-)%s*$"))
                end,
                EditBoxOnEnterPressed = function(box)
                    local parent = box:GetParent()
                    B:AssignCategory(parent.data, box:GetText():match("^%s*(.-)%s*$"))
                    parent:Hide()
                end,
                EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("TEMPUS_BAG_CATEGORY", nil, nil, itemID)
        elseif value == "__none" then
            self:AssignCategory(itemID, nil)
        else
            self:AssignCategory(itemID, value)
        end
    end, current)
end

function B:ToggleView()
    self.db.mode = self.db.mode == "GRID" and "CATEGORIES" or "GRID"
    self:Render("CARRIED")
    self:Render("BANK")
end

function B:SetBankStorage(storage)
    if storage == "REAGENT" and not self.client:IsReagentAvailable() then return end
    self.bankStorage = storage
    self:Refresh(storage)
end

function B:Sort(storage)
    local actual = storage == "BANK" and self.bankStorage or storage
    local ok, err = self.client:Sort(actual)
    if not ok then T:Print("Bags: %s", err) end
end

function B:ShowBankManagement()
    if self.bankWindow then self.bankWindow.frame:Hide() end
    self.client:ShowBankManagement(true)
end

function B:OnEvent(event)
    if event == "BANKFRAME_OPENED" then
        self.client:SuppressBank()
        if self.bankStorage == "REAGENT" and not self.client:IsReagentAvailable() then self.bankStorage = "BANK" end
        self.openedCarriedForBank = not self.carriedWindow.frame:IsShown()
        self:SetCarriedShown(true)
        self.bankWindow.frame:Show()
        self:Refresh(self.bankStorage)
    elseif event == "BANKFRAME_CLOSED" then
        self.bankWindow.frame:Hide()
        self.client:ShowBankManagement(false)
        if self.openedCarriedForBank then self:SetCarriedShown(false) end
        self.openedCarriedForBank = nil
        self.snapshots.BANK, self.snapshots.REAGENT = nil, nil
    elseif event == "BAG_UPDATE_DELAYED" then
        self:Refresh("CARRIED")
        if self.bankWindow.frame:IsShown() then self:Refresh(self.bankStorage) end
    elseif event == "PLAYER_MONEY" or event == "CURRENCY_DISPLAY_UPDATE" then
        if self.carriedWindow then self.carriedWindow:UpdateFooter() end
        if self.bankWindow and self.bankWindow.frame:IsShown() then self.bankWindow:UpdateFooter() end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        if self.carriedWindow then self.carriedWindow:UpdateCooldowns() end
    elseif event == "ITEM_LOCK_CHANGED" then
        if self.carriedWindow and self.carriedWindow.frame:IsShown() then self:Refresh("CARRIED") end
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if self.bankWindow.frame:IsShown() then self:Refresh("BANK") end
    elseif event == "PLAYERREAGENTBANKSLOTS_CHANGED" or event == "REAGENTBANK_PURCHASED" then
        if self.bankWindow.frame:IsShown() then self:Refresh("REAGENT") end
    end
end

-- Temporary: /tempus bagdump writes TempusDB.bagdump so the stock bag frame layout can be read after /reload.
function B:Dump()
    local out = {
        state = self.state, moduleEnabled = T:ModuleEnabled("bags"), claimed = self.client and self.client.claimed,
        conflicts = FamilyLabels(self.conflicts), trace = self.trace, rawStates = {}, windows = self.carriedWindow ~= nil,
        lastError = TempusDB.debug and TempusDB.debug.lastError, frames = {}, globals = {},
    }
    for _, family in ipairs(self.Client.conflictFamilies) do
        for _, addon in ipairs(family.addons) do
            local modern = C_AddOns and C_AddOns.GetAddOnEnableState
            local legacy = GetAddOnEnableState
            out.rawStates[addon] = {
                modern = modern and select(2, pcall(modern, addon)) or "n/a",
                legacy = legacy and select(2, pcall(legacy, nil, addon)) or "n/a",
            }
        end
    end
    for _, name in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBag", "OpenAllBags", "CloseAllBags",
        "OpenBackpack", "CloseBackpack", "ContainerFrame_GenerateFrame", "ContainerFrame_OnShow", "ShowUIPanel",
        "C_Container", "GetContainerNumSlots", "NUM_CONTAINER_FRAMES", "NUM_BAG_SLOTS", "NUM_TOTAL_EQUIPPED_BAG_SLOTS",
        "NUM_BANKBAGSLOTS", "BACKPACK_CONTAINER", "BANK_CONTAINER", "REAGENTBANK_CONTAINER", "KEYRING_CONTAINER",
        "BankFrame", "ContainerFrameCombinedBags", "ContainerFrameContainer", "BackpackTokenFrame", "C_Bank" }) do
        local v = _G[name]
        out.globals[name] = type(v) == "table" and "table" or type(v) == "function" and "function" or v == nil and "nil" or tostring(v)
    end
    local names = { "ContainerFrameCombinedBags", "ContainerFrameContainer", "BankFrame" }
    for i = 1, 13 do names[#names + 1] = "ContainerFrame" .. i end
    for _, name in ipairs(names) do
        local f = _G[name]
        if f then
            local entry = { type = f.GetObjectType and f:GetObjectType(), shown = f.IsShown and f:IsShown() or false }
            if f.GetID then entry.id = f:GetID() end
            if f.GetBagID then local ok, v = pcall(f.GetBagID, f); entry.bagID = ok and v or "err" end
            if f.GetParent and f:GetParent() then entry.parent = f:GetParent():GetName() or "unnamed" end
            if f.IsProtected then entry.protected = f:IsProtected() and true or false end
            out.frames[name] = entry
        end
    end
    out.bagIndex, out.inventoryConstants = {}, {}
    for k, v in pairs(Enum and Enum.BagIndex or {}) do out.bagIndex[k] = v end
    for k, v in pairs(Constants and Constants.InventoryConstants or {}) do out.inventoryConstants[k] = v end
    out.bankIds = { BANK = self.client:ContainerIDs("BANK"), REAGENT = self.client:ContainerIDs("REAGENT"),
        CARRIED = self.client:ContainerIDs("CARRIED") }
    TempusDB.bagdump = out
    T:Print("bag state dumped; /reload, then read TempusDB.bagdump in SavedVariables.")
end

function B:OnEnable()
    self.db = T.db.bags
    self.snapshots = {}
    self:Start()
end

function B:OnSettings()
    self.db = T.db.bags
    self.customLookup = nil
    if self.carriedWindow then
        self.carriedWindow:ApplyPoint()
        self.bankWindow:ApplyPoint()
        self:Render("CARRIED")
        self:Render("BANK")
    end
end

T:NewModule("bags", {
    label = "Bags",
    desc = "A searchable combined bag and personal-bank window with grid and automatic category views.",
    defaults = B.defaults,
    OnEnable = function() B:OnEnable() end,
    OnSettings = function() B:OnSettings() end,
})
