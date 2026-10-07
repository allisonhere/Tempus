-- Tempus UI: row of equipped-bag icons. Hover highlights a bag's items, click limits the grid to it.
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
        GameTooltip:SetText(self.owner.client:BagName(b.container), 1, 1, 1)
        GameTooltip:AddLine("Click to show only this bag", 0.6, 0.65, 0.72)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        self.owner:SetHoverBag(nil)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(b) self.owner:SetBagFilter(b.container) end)
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
