-- Royal settings-window artwork. Presentation only: no settings, module or combat state changes.
local _, T = ...
local S, UI = T.Style, T.UI
local Royal = {}
UI.Royal = Royal

local GOLD = { 0.76, 0.58, 0.30 }
local PALE = { 0.96, 0.85, 0.65 }
local VIOLET = { 0.48, 0.26, 0.72 }
local WHITE = S.WHITE

local function Block(parent, layer, color, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub or 0)
    t:SetTexture(WHITE)
    t:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    return t
end

local function Rule(parent, anchor, x, y, width, color)
    local t = Block(parent, "ARTWORK", color or GOLD)
    t:SetSize(width, 1)
    t:SetPoint(anchor, x, y)
    return t
end

local function Jewel(parent, point, x, y, size)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(size, size)
    holder:SetPoint(point, parent, point, x, y)
    local diamond = Block(holder, "ARTWORK", GOLD)
    diamond:SetSize(size * 0.64, size * 0.64)
    diamond:SetPoint("CENTER")
    diamond:SetRotation(math.pi / 4)
    local inner = Block(holder, "OVERLAY", VIOLET)
    inner:SetSize(size * 0.36, size * 0.36)
    inner:SetPoint("CENTER")
    inner:SetRotation(math.pi / 4)
    return holder
end

local function Corner(parent, point, dx, dy, sx, sy)
    local h = Block(parent, "OVERLAY", GOLD)
    h:SetSize(31, 2)
    h:SetPoint(point, parent, point, dx, dy)
    local v = Block(parent, "OVERLAY", GOLD)
    v:SetSize(2, 31)
    v:SetPoint(point, parent, point, dx, dy)
    -- Offsets continue inward from the anchored corner rather than outlining
    -- a second rectangular frame.
    local glint = Block(parent, "OVERLAY", PALE)
    glint:SetSize(5, 5)
    glint:SetPoint(point, parent, point, dx + sx * 3, dy + sy * 3)
end

function Royal.Apply(window, header, sidebar, content)
    if window.royalApplied then return end
    window.royalApplied = true
    -- Deep ink overlay and warm metal edging; content remains clickable.
    local fill = Block(window, "BACKGROUND", { 0.035, 0.029, 0.052, 0.91 }, -5)
    fill:SetAllPoints(window)
    local edgeTop = Block(window, "BORDER", GOLD)
    edgeTop:SetHeight(2)
    edgeTop:SetPoint("TOPLEFT", 4, -3)
    edgeTop:SetPoint("TOPRIGHT", -4, -3)
    local edgeBottom = Block(window, "BORDER", GOLD)
    edgeBottom:SetHeight(2)
    edgeBottom:SetPoint("BOTTOMLEFT", 4, 3)
    edgeBottom:SetPoint("BOTTOMRIGHT", -4, 3)
    Corner(window, "TOPLEFT", 4, -4, 1, -1)
    Corner(window, "TOPRIGHT", -4, -4, -1, -1)
    Corner(window, "BOTTOMLEFT", 4, 4, 1, 1)
    Corner(window, "BOTTOMRIGHT", -4, 4, -1, 1)
    Jewel(window, "TOP", 0, -3, 11)
    Jewel(window, "BOTTOM", 0, 3, 11)

    local top = header:CreateTexture(nil, "BACKGROUND", nil, -4)
    top:SetTexture("Interface\\AddOns\\Tempus\\media\\royal\\header-astral.tga")
    top:SetAllPoints()
    top:SetVertexColor(1, 1, 1, 1)
    local headerShade = Block(header, "BACKGROUND", { 0.12, 0.065, 0.16, 0.32 }, -3)
    headerShade:SetAllPoints()
    local underline = Block(header, "BORDER", GOLD)
    underline:SetHeight(1)
    underline:SetPoint("BOTTOMLEFT", 14, 2)
    underline:SetPoint("BOTTOMRIGHT", -14, 2)
    Rule(header, "TOPLEFT", 64, -5, 130, { 0.8, 0.57, 0.30, 0.7 })
    Rule(header, "TOPRIGHT", -64, -5, 130, { 0.8, 0.57, 0.30, 0.7 })
    -- An engraved astral chronometer sits behind the center of the masthead.
    -- The clock is deliberately subdued so text and toolbar actions stay readable.
    local dial = header:CreateTexture(nil, "BACKGROUND", nil, -2)
    dial:SetTexture("Interface\\AddOns\\Tempus\\media\\royal\\dial.tga")
    dial:SetSize(112, 112)
    dial:SetPoint("CENTER", header, "CENTER", 112, -11)
    dial:SetAlpha(0.26)
    local lineTop = Block(header, "BORDER", {0.95,0.77,0.43,0.68})
    lineTop:SetHeight(1)
    lineTop:SetPoint("TOPLEFT",6,-5)
    lineTop:SetPoint("TOPRIGHT",-6,-5)
    local crest = Block(header,"OVERLAY",{0.88,0.65,0.33,0.8})
    crest:SetSize(7,7)
    crest:SetPoint("BOTTOM",header,"BOTTOM",0,2)
    crest:SetRotation(math.pi/4)
    local leftFlourish=Block(header,"ARTWORK",{0.82,0.61,0.36,0.54})
    leftFlourish:SetSize(140,1)
    leftFlourish:SetPoint("RIGHT",crest,"LEFT",-12,0)
    local rightFlourish=Block(header,"ARTWORK",{0.82,0.61,0.36,0.54})
    rightFlourish:SetSize(140,1)
    rightFlourish:SetPoint("LEFT",crest,"RIGHT",12,0)

    local sidefill = Block(sidebar, "BACKGROUND", { 0.065, 0.044, 0.082, 0.62 }, -4)
    sidefill:SetAllPoints()
    local separator = Block(sidebar, "BORDER", { 0.68, 0.48, 0.24, 0.72 })
    separator:SetWidth(1)
    separator:SetPoint("TOPRIGHT", -1, -8)
    separator:SetPoint("BOTTOMRIGHT", -1, 8)
    local inset = Block(sidebar, "BACKGROUND", { 0.15, 0.09, 0.18, 0.37 }, -3)
    inset:SetPoint("TOPLEFT", 8, -48)
    inset:SetPoint("BOTTOMRIGHT", -8, 45)
    local accent = Block(sidebar, "ARTWORK", VIOLET)
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", 14, -42)
    accent:SetPoint("TOPRIGHT", -14, -42)

    -- Subtle page header ornament; deliberately behind settings controls.
    local rule = Block(content, "BACKGROUND", { 0.73, 0.52, 0.28, 0.22 })
    rule:SetSize(210, 1)
    rule:SetPoint("TOPRIGHT", -20, -6)
end

function Royal.NavItem(button)
    if button.royalDecor then return end
    button.royalDecor = true
    local inset = Block(button, "BORDER", { 0.38, 0.19, 0.51, 0.4 })
    inset:SetPoint("TOPLEFT", 7, -1)
    inset:SetPoint("BOTTOMRIGHT", -4, 1)
    inset:Hide()
    local edge = Block(button, "ARTWORK", GOLD)
    edge:SetWidth(2)
    edge:SetPoint("TOPLEFT", 8, -3)
    edge:SetPoint("BOTTOMLEFT", 8, 3)
    edge:Hide()
    button.royalInset, button.royalEdge = inset, edge
end

function Royal.NavSelected(button, on)
    if not button.royalDecor then return end
    button.royalInset:SetShown(on)
    button.royalEdge:SetShown(on)
    if on then
        button.text:SetTextColor(PALE[1], PALE[2], PALE[3])
    end
end
