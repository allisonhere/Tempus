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

function BagBar.New(window)
    local self = setmetatable({ window = window, owner = window.owner, buttons = {} }, BagBar)
    self.frame = CreateFrame("Frame", nil, window.frame)
    self.frame:SetHeight(SIZE)
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
    button.border = S.CreateBorder(button, "OVERLAY", 2)
    button.border:SetThickness(1, button)
    button:SetScript("OnEnter", function(b)
        self.owner:SetHoverBag(b.container)
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        local client = self.owner.client
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
        GameTooltip:AddLine("Right-click to empty it into your other bags, then take it off", 0.6, 0.65, 0.72)
        if b.container ~= 0 then
            GameTooltip:AddLine("Drag it to your inventory to take it off; drop a bag here to swap", 0.6, 0.65, 0.72)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        self.owner:SetHoverBag(nil)
        GameTooltip:Hide()
    end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    -- Drag a bag off to an inventory slot, or drop a bag (or any item) on a slot here.
    button:SetScript("OnDragStart", function(b)
        self.owner.client:PickupBag(b.container)
    end)
    button:SetScript("OnReceiveDrag", function(b)
        self.owner.client:DropOnBag(b.container)
    end)
    button:SetScript("OnClick", function(b, mouse)
        if CursorHasItem() then              -- click-to-drop, like the stock bag slots
            self.owner.client:DropOnBag(b.container)
        elseif mouse == "RightButton" then self.owner:EmptyBag(b.container)
        else self.owner:SetBagFilter(b.container) end
    end)
    self.buttons[index] = button
    return button
end

-- Rebuild icons for the containers that exist right now (bags can be swapped at any time).
function BagBar:Refresh()
    local owner, ids = self.owner, {}
    for _, id in ipairs(owner.client:ContainerIDs("CARRIED")) do
        if id >= (owner.client.env.BACKPACK_CONTAINER or 0) then ids[#ids + 1] = id end
    end
    local accent = T.accent
    local x = 0
    for index, id in ipairs(ids) do
        local button = Button(self, index)
        button.container = id
        button:ClearAllPoints()
        button:SetPoint("LEFT", self.frame, "LEFT", x, 0)
        local texture = owner.client:BagIcon(id)
        button.icon:SetTexture(texture)
        button.icon:SetShown(texture ~= nil)
        if owner.bagFilter == id then button.border:SetColor(accent[1], accent[2], accent[3], 1)
        else button.border:SetColor(1, 1, 1, 0.12) end
        button:Show()
        x = x + SIZE + GAP
    end
    for index = #ids + 1, #self.buttons do self.buttons[index]:Hide() end
    self.frame:SetWidth(math.max(1, x - GAP))
end
