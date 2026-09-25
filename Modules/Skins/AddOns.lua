-- Tempus UI: skins for other addons, through their own public skin APIs.
local _, T = ...
local S = T.Style
local SK = T.Skins

-- Bagnon (BagBrother) keeps a skin registry; "Tempus" appears in its skin list.
local function RegisterBagnon()
    local B = _G.Bagnon or _G.BagBrother
    local skins = B and B.Skins
    if not (skins and skins.Register) or SK.bagnonDone then return end
    SK.bagnonDone = true
    skins:Register({
        id = "Tempus",
        template = "BackdropTemplate",
        margin = 3, inset = 2,
        load = function(bg)
            if not bg.tempusBd then bg.tempusBd = S.Backdrop(bg, { fill = { 0.047, 0.054, 0.068, 0.95 } }) end
            bg.tempusBd:SetShown(true)
            local frame = bg:GetParent()
            if frame and type(frame.CloseButton) == "table" then pcall(SK.Close, SK, frame.CloseButton) end
        end,
        centerColor = function(bg, r, g, b, a)
            if bg.tempusBd then bg.tempusBd:SetFillColor(0.047, 0.054, 0.068, math.max(a or 0.95, 0.85)) end
        end,
        borderColor = function(bg, r, g, b)
            if bg.tempusBd then bg.tempusBd:SetEdgeColor(0, 0, 0) end
        end,
        reset = function(bg)
            if bg.tempusBd then bg.tempusBd:SetShown(false) end
        end,
    })
end

-- Bagnon item slots: square Tempus slots whose edge takes Bagnon's glow colour.
local function StyleBagnonItem(b)
    if b.tempusSkinned then return end
    b.tempusSkinned = true
    local icon = b.icon or (b:GetName() and _G[b:GetName() .. "IconTexture"])
    b.tempusIcon = icon
    if type(icon) == "table" then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    if b.IconGlow then b.IconGlow:SetAlpha(0) end
    if b.IconBorder then b.IconBorder:SetAlpha(0) end
    b.tempusBd = S.Backdrop(b, { fill = { 0.03, 0.035, 0.045, 1 } })
    local hl = b.GetHighlightTexture and b:GetHighlightTexture()
    if hl then
        hl:SetTexture(S.WHITE)
        hl:SetVertexColor(1, 1, 1, 0.14)
        hl:SetAllPoints(icon or b)
    end
    local pushed = b.GetPushedTexture and b:GetPushedTexture()
    if pushed then
        pushed:SetTexture(S.WHITE)
        pushed:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 0.3)
        pushed:SetAllPoints(icon or b)
    end
    local count = b.Count or (b:GetName() and _G[b:GetName() .. "Count"])
    if type(count) == "table" and count.SetFont then
        S.ApplyFont(count, 12)
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    end
end

local function BagnonBorder(b)
    if not b.tempusBd then return end
    local border = b.IconBorder
    if border and border:IsShown() then
        local r, g, bl = border:GetVertexColor()
        b.tempusBd:SetEdgeColor(r, g, bl)
    else
        b.tempusBd:SetEdgeColor(0, 0, 0)
    end
    if b.IconGlow then b.IconGlow:SetAlpha(0) end
end

local function HookBagnonItems()
    local B = _G.Bagnon
    local Item = B and B.Item
    if not Item or SK.bagnonItemsHooked or type(Item.Update) ~= "function" then return end
    SK.bagnonItemsHooked = true
    hooksecurefunc(Item, "Update", function(self)
        pcall(StyleBagnonItem, self)
        -- Empty slots: plain dark squares instead of the grey bag-slot art.
        if self.tempusIcon then self.tempusIcon:SetAlpha(self.hasItem and 1 or 0) end
        pcall(BagnonBorder, self)
    end)
    if type(Item.UpdateBorder) == "function" then
        hooksecurefunc(Item, "UpdateBorder", function(self) pcall(BagnonBorder, self) end)
    end
end

-- Switch Bagnon's frames to the Tempus skin once; later choices in Bagnon are respected.
local function ApplyBagnonSkin()
    local B = _G.Bagnon
    if not (B and type(B.sets) == "table") or TempusDB.bagnonApplied then return end
    local function Set(profile)
        if type(profile) ~= "table" then return end
        for _, fp in pairs(profile) do
            if type(fp) == "table" and fp.skin ~= nil then fp.skin = "Tempus" end
        end
    end
    Set(B.sets.global)
    for _, owners in pairs(B.sets.profiles or {}) do
        for _, profile in pairs(owners) do Set(profile) end
    end
    TempusDB.bagnonApplied = true
    if B.Frames and B.Frames.Update then pcall(B.Frames.Update, B.Frames) end
end

-- DBM timer bars: a "Tempus" preset in DBM's own skin list, using the shared bar texture
-- and font. DBM switches to it only when chosen (in DBM or via the Tempus Skins page).
local function RegisterDBM()
    local DBT = _G.DBT
    if not (DBT and DBT.RegisterSkin) or SK.dbmDone then return end
    SK.dbmDone = true
    local ok, skin = pcall(DBT.RegisterSkin, DBT, "Tempus")
    if not ok or type(skin) ~= "table" then return end
    skin.Defaults = {
        Texture = S.BarTexture(T.db.barTexture),
        Font = T.db.font or S.FONT,
        FontFlag = "OUTLINE",
        FontSize = 11,
        Height = 18,
        HugeHeight = 22,
    }
    skin.Options = skin.Defaults
    SK.dbmSkin = skin
end

function SK:ApplyDBM()
    RegisterDBM()
    if _G.DBT and SK.dbmSkin then
        local ok, err = pcall(_G.DBT.SetSkin, _G.DBT, "Tempus")
        if ok then T:Print("DBM timers now use the Tempus skin.") else T:Print("couldn't switch DBM skin: %s", tostring(err)) end
    else
        T:Print("DBM isn't loaded.")
    end
end

function SK:InitAddOns()
    if SK.db.bagnon then
        pcall(RegisterBagnon)
        pcall(HookBagnonItems)
        pcall(ApplyBagnonSkin)
    end
    if SK.db.dbm then pcall(RegisterDBM) end
end

function SK:OnAddonLoaded()
    SK:InitAddOns()
end
