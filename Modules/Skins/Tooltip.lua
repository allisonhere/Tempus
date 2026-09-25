-- Tempus UI: tooltips in Tempus panels, with class/reaction and item-quality edges and a
-- styled health bar. Unit and item info is checked for secrecy before it is used.
local _, T = ...
local S = T.Style
local SK = T.Skins
local issecret = T.issecret

local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "FriendsTooltip", "WorldMapTooltip", "SmallTextTooltip" }

local function Edge(tt, r, g, b)
    if tt.tempusSkinPanel then tt.tempusSkinPanel:SetEdgeColor(r, g, b) end
end

local function HideStock(tt)
    if tt.NineSlice then tt.NineSlice:SetAlpha(0) end
    if tt.SetBackdrop and tt.GetBackdrop and not tt.NineSlice then pcall(tt.SetBackdrop, tt, nil) end
end

local function StyleTip(tt)
    if not tt or tt.tempusSkinPanel then return end
    SK:Panel(tt, { 0.055, 0.062, 0.078, 0.94 })
    HideStock(tt)
    tt:HookScript("OnShow", HideStock)
    tt:HookScript("OnTooltipCleared", function(self) Edge(self, 0, 0, 0) end)
end

local function Readable(v) return v ~= nil and not issecret(v) end

local function OnUnit(tt)
    if tt ~= GameTooltip or not tt.GetUnit then return end
    local ok, _, unit = pcall(tt.GetUnit, tt)
    if not ok or not Readable(unit) then return end
    local r, g, b
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if okP and Readable(isPlayer) and isPlayer then
        local _, class = UnitClass(unit)
        if Readable(class) then r, g, b = S.ClassColor(class) end
    end
    if not r and UnitSelectionColor then
        local okS, rr, gg, bb = pcall(UnitSelectionColor, unit)
        if okS and T.Num(rr) and T.Num(gg) and T.Num(bb) then r, g, b = rr, gg, bb end
    end
    if r then
        Edge(tt, r, g, b)
        local line = GameTooltipTextLeft1
        if line then line:SetTextColor(r, g, b) end
        if GameTooltipStatusBar then GameTooltipStatusBar:SetStatusBarColor(r, g, b) end
    end
end

local function OnItem(tt)
    if not tt.GetItem then return end
    local ok, _, link = pcall(tt.GetItem, tt)
    if not ok or not Readable(link) then return end
    local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(link)
    if not T.Num(quality) then quality = select(3, GetItemInfo(link)) end
    if T.Num(quality) and quality > 1 then
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if c then Edge(tt, c.r, c.g, c.b) end
    end
end

local function StyleHealthBar()
    local bar = GameTooltipStatusBar
    if not bar or bar.tempusSkinned then return end
    bar.tempusSkinned = true
    bar:SetStatusBarTexture(S.BarTexture(T.db.barTexture))
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 1, -3)
    bar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -1, -3)
    bar:SetHeight(6)
    S.Backdrop(bar, { fill = { 0.08, 0.09, 0.11, 0.9 }, inner = false })
    for _, r in ipairs({ bar:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" and not r.tempus and r ~= bar:GetStatusBarTexture() then r:SetAlpha(0) end
    end
end

function SK:InitTooltips()
    for _, name in ipairs(TIPS) do
        local tt = _G[name]
        if tt then pcall(StyleTip, tt) end
    end
    if SharedTooltip_SetBackdropStyle then
        hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tt) if tt and tt.tempusSkinPanel then HideStock(tt) end end)
    end
    if SK.db.tooltipHealth then pcall(StyleHealthBar) elseif GameTooltipStatusBar then GameTooltipStatusBar:SetAlpha(0) end

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt) pcall(OnUnit, tt) end)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt) pcall(OnItem, tt) end)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", function(tt) pcall(OnUnit, tt) end)
        for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
            if _G[name] then _G[name]:HookScript("OnTooltipSetItem", function(tt) pcall(OnItem, tt) end) end
        end
    end

    if GameTooltip_SetDefaultAnchor then
        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tt, parent)
            if SK.db.tooltipCursor and parent and not InCombatLockdown() then
                tt:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", 18, 12)
            end
        end)
    end
end
