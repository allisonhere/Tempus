-- Tempus UI: row of equipped-bag icons. Hover highlights a bag's items, click limits the grid to it,
-- right-click empties it into the other bags, drag moves bags on and off.
local _, T = ...
local Bags = T.Bags or {}
T.Bags = Bags
local S = T.Style

local BagBar = {}
BagBar.__index = BagBar
Bags.BagBar = BagBar

local SIZE, GAP = 24, 4

local function Money(copper)
    copper = math.floor((copper or 0) + 0.5)
    local g, sv, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return sv > 0 and ("%dg %ds"):format(g, sv) or ("%dg"):format(g) end
    if sv > 0 then return c > 0 and ("%ds %dc"):format(sv, c) or ("%ds"):format(sv) end
    return ("%dc"):format(c)
end
BagBar.Money = Money

function BagBar.New(window, storage)
    local self = setmetatable({ window = window, owner = window.owner, storage = storage or "CARRIED", buttons = {} }, BagBar)
    self.frame = CreateFrame("Frame", nil, window.frame)
    -- The bank bar has a line under the buttons: how many tabs are open, how many slots are free.
    self.height = self.storage == "BANK" and SIZE + 16 or SIZE
    self.frame:SetHeight(self.height)
    if self.storage == "BANK" then
        self.summary = S.Text(self.frame, 11, S.C.muted)
        self.summary:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 0)
    end
    return self
end

local function Button(self, index)
    local button = self.buttons[index]
    if button then return button end
    button = CreateFrame("Button", nil, self.frame)
    button:SetSize(SIZE, SIZE)
    button.bg = S.Tex(button, "BACKGROUND", S.C.card)
    button.bg:SetAllPoints()
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.lock = S.Text(button, 14, S.C.muted)
    button.lock:SetPoint("CENTER", 0, 1)
    button.lock:SetText("")
    button.border = S.CreateBorder(button, "OVERLAY", 2)
    button.border:SetThickness(1, button)
    button:SetScript("OnEnter", function(b)
        self.owner:SetHoverBag(b.container, self.storage)
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        local client = self.owner.client
        if b.tab then
            local info = self.tabInfo
            if not b.tab.bought then
                GameTooltip:SetText(b.tab.name .. " (not bought)", 1, 1, 1)
                local costs = self.owner.db and self.owner.db.tabCosts or {}
                if b.buyable then
                    GameTooltip:AddLine("Price: " .. (info and info.nextCost and Money(info.nextCost) or "unknown"), 1, 0.82, 0.25)
                    GameTooltip:AddLine("Click to buy this tab", 0.4, 0.95, 0.5)
                    if info and info.canAfford == false then GameTooltip:AddLine("You cannot afford it yet", 0.95, 0.4, 0.35) end
                else
                    local seen = costs[tostring(b.index)]
                    if seen then
                        GameTooltip:AddLine("Price: " .. Money(seen) .. " (as last seen)", 1, 0.82, 0.25)
                    else
                        GameTooltip:AddLine("Price: shown once it is the next tab to buy", 0.6, 0.65, 0.72)
                    end
                    GameTooltip:AddLine("Buy the tabs before it first", 0.6, 0.65, 0.72)
                end
                GameTooltip:Show()
                return
            end
            GameTooltip:SetText(b.tab.name, 1, 1, 1)
            GameTooltip:AddLine(("%d slots  ·  %d used, %d free"):format(b.tab.slots, b.tab.slots - b.tab.free, b.tab.free), 0.85, 0.88, 0.92)
            GameTooltip:AddLine("Click to show only this tab", 0.6, 0.65, 0.72)
            GameTooltip:Show()
            return
        end
        local total = client:SlotCount(b.container)
        if total == 0 then
            GameTooltip:SetText("Empty bag slot", 1, 1, 1)
            GameTooltip:AddLine("Drag a bag here to equip it", 0.6, 0.65, 0.72)
            GameTooltip:Show()
            return
        end
        GameTooltip:SetText(client:BagName(b.container), 1, 1, 1)
        local free = math.min(client:FreeSlots(b.container), total)
        GameTooltip:AddLine(("%d slots  ·  %d used, %d free"):format(total, total - free, free), 0.85, 0.88, 0.92)
        GameTooltip:AddLine("Click to show only this bag", 0.6, 0.65, 0.72)
        if self.storage ~= "CARRIED" then
            GameTooltip:AddLine("Drag it to your inventory to take it off; drop a bag here to swap", 0.6, 0.65, 0.72)
            GameTooltip:Show()
            return
        end
        GameTooltip:AddLine("Right-click to empty it into your other bags, then take it off", 0.6, 0.65, 0.72)
        if b.container ~= 0 then
            GameTooltip:AddLine("Drag it to your inventory to take it off; drop a bag here to swap", 0.6, 0.65, 0.72)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        self.owner:SetHoverBag(nil, self.storage)
        GameTooltip:Hide()
    end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    -- Drag a bag off to an inventory slot, or drop a bag (or any item) on a slot here.
    button:SetScript("OnDragStart", function(b)
        if b.tab then return end
        self.owner.client:PickupBag(b.container)
    end)
    button:SetScript("OnReceiveDrag", function(b)
        if b.tab then return end
        self.owner.client:DropOnBag(b.container)
    end)
    button:SetScript("OnClick", function(b, mouse)
        if b.tab and not b.tab.bought then
            if b.buyable then self.owner.client:BuyBankTab() end
            return
        end
        if CursorHasItem() then              -- click-to-drop, like the stock bag slots
            self.owner.client:DropOnBag(b.container)
        elseif mouse == "RightButton" and self.storage == "CARRIED" then self.owner:EmptyBag(b.container)
        else self.owner:SetBagFilter(b.container, self.storage) end
    end)
    self.buttons[index] = button
    return button
end

-- Rebuild icons for the containers that exist right now (bags can be swapped at any time).
-- The bank on clients that sell tabs: every tab is drawn, bought ones normally, the rest locked,
-- with the next one clickable to buy.
function BagBar:RefreshTabs(info)
    local owner = self.owner
    local accent = T.accent
    self.tabInfo = info
    -- The game only tells us the price of the NEXT tab; remember each one when it is, so the
    -- later ones can show their last seen price.
    local db = owner.db
    if db and info.nextCost and info.bought < info.total then
        db.tabCosts = db.tabCosts or {}
        db.tabCosts[tostring(info.bought + 1)] = info.nextCost
    end
    local x = 0
    local nextBuy = true
    for n, tab in ipairs(info.tabs) do
        local button = Button(self, n)
        button.container, button.tab, button.index = tab.container, tab, n
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, 0)
        if tab.bought then
            button.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
            button.icon:SetShown(true)
            button.icon:SetAlpha(1)
            button.lock:SetText("")
            button.buyable = false
            if owner.bankBagFilter == tab.container then button.border:SetColor(accent[1], accent[2], accent[3], 1)
            else button.border:SetColor(1, 1, 1, 0.12) end
        else
            button.icon:SetShown(false)
            button.buyable = nextBuy and info.canBuy and true or false
            nextBuy = false
            button.lock:SetText(button.buyable and "+" or "")
            button.lock:SetTextColor(accent[1], accent[2], accent[3])
            if button.buyable then button.border:SetColor(accent[1], accent[2], accent[3], 0.8)
            else button.border:SetColor(1, 1, 1, 0.06) end
        end
        button:SetAlpha(tab.bought and 1 or (button.buyable and 0.9 or 0.45))
        button:Show()
        x = x + SIZE + GAP
    end
    for index = #info.tabs + 1, #self.buttons do self.buttons[index]:Hide() end
    self.frame:SetWidth(math.max(1, x - GAP))
    local toBuy = info.total - info.bought
    self.summary:SetText(("%d of %d tabs  ·  %d free slots%s"):format(info.bought, info.total, info.free,
        toBuy > 0 and ("  ·  " .. toBuy .. " to buy") or ""))
end

function BagBar:Refresh()
    local owner, ids = self.owner, {}
    local client = owner.client
    if self.storage == "BANK" and client.BankTabs then
        local info = client:BankTabs()
        if info then return self:RefreshTabs(info) end
    end
    for _, id in ipairs(client:ContainerIDs(self.storage)) do
        if self.storage == "CARRIED" then
            if id >= (client.env.BACKPACK_CONTAINER or 0) then ids[#ids + 1] = id end
        elseif client:SlotCount(id) > 0 or client:IsBagSlot(id) then
            -- bank: tabs / bags that hold slots, plus empty bag slots you can still equip a bag in
            ids[#ids + 1] = id
        end
    end
    local filter = self.storage == "CARRIED" and owner.bagFilter or owner.bankBagFilter
    local accent = T.accent
    local x = 0
    for index, id in ipairs(ids) do
        local button = Button(self, index)
        button.container = id
        button.tab, button.buyable = nil, false
        button.lock:SetText("")
        button:SetAlpha(1)
        button:ClearAllPoints()
        button:SetPoint("LEFT", self.frame, "LEFT", x, 0)
        local texture = client:BagIcon(id)
        -- Bank tabs have no bag item to show an icon for: a plain bag picture stands in.
        if not texture and self.storage ~= "CARRIED" then texture = "Interface\\Buttons\\Button-Backpack-Up" end
        button.icon:SetTexture(texture)
        button.icon:SetShown(texture ~= nil)
        if filter == id then button.border:SetColor(accent[1], accent[2], accent[3], 1)
        else button.border:SetColor(1, 1, 1, 0.12) end
        button:Show()
        x = x + SIZE + GAP
    end
    for index = #ids + 1, #self.buttons do self.buttons[index]:Hide() end
    self.frame:SetWidth(math.max(1, x - GAP))
    if self.summary then self.summary:SetText("") end
end
