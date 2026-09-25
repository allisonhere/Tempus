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

----------------------------------------------------------------------------------------
-- Healium: visual restyle only. Click-casting, secure attributes and Healium's own logic
-- are untouched; its frames are found by shape and restyled as they appear.
----------------------------------------------------------------------------------------
local function ReplaceBorder(f, target, thickness)
    if type(f) ~= "table" or f.tempusBorder then return end
    if f.SetBackdrop then pcall(f.SetBackdrop, f, nil) end
    local b = S.CreateBorder(f, "OVERLAY", 7)
    b:SetThickness(thickness, target)
    b:SetColor(1, 0.2, 0.2, 1)
    f.tempusBorder = b
    -- Healium colours these by debuff type / threat; keep following its colours.
    if f.SetBackdropBorderColor then
        hooksecurefunc(f, "SetBackdropBorderColor", function(_, r, g, bl) b:SetColor(r or 1, g or 1, bl or 1, 1) end)
    end
end

local function StyleBar(bar)
    if type(bar) ~= "table" or not bar.SetStatusBarTexture then return end
    local r, g, b, a = bar:GetStatusBarColor()
    bar:SetStatusBarTexture(S.BarTexture(T.db.barTexture))
    if r then bar:SetStatusBarColor(r, g, b, a) end
end

local function StyleHealiumGroup(uf)
    local cb = uf.CaptionBar
    if type(cb) ~= "table" or cb.tempusSkinned then return end
    cb.tempusSkinned = true
    if cb.SetBackdrop then pcall(cb.SetBackdrop, cb, nil) end
    S.Backdrop(cb, { fill = { 0.047, 0.054, 0.068, 0.95 } })
    if type(cb.Caption) == "table" then S.ApplyFont(cb.Caption, 12) end
    if type(cb.CloseButton) == "table" then pcall(SK.Close, SK, cb.CloseButton) end
end

local function StyleHealiumUnit(b)
    if b.tempusSkinned then return end
    b.tempusSkinned = true
    StyleBar(b.HealthBar)
    StyleBar(b.ManaBar)
    StyleBar(b.PredictBar)
    S.Backdrop(b.HealthBar, { fill = { 0.06, 0.065, 0.08, 0.95 }, shadow = false, inner = false })
    for _, r in ipairs({ b.ManaBar:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" and r:GetDrawLayer() == "BACKGROUND" and not r.tempus then
            r:SetColorTexture(0.06, 0.065, 0.08, 1)
        end
    end
    local bgs = b.HealthbarOpaqueBackgrounds
    if type(bgs) == "table" then
        if bgs[1] then bgs[1]:SetVertexColor(0.05, 0.055, 0.07, 1) end
        if bgs[2] then
            bgs[2]:SetTexture(S.WHITE)
            bgs[2]:SetHorizTile(false)
            bgs[2]:SetVertTile(false)
            bgs[2]:SetVertexColor(0.08, 0.09, 0.11, 1)
        end
    end
    local hb = b.HealthBar
    if type(hb.name) == "table" then S.ApplyFont(hb.name, 11) end
    if type(hb.HPText) == "table" then S.ApplyFont(hb.HPText, 10) end
    ReplaceBorder(b.CurseBar, b, 2)
    ReplaceBorder(b.AggroBar, b, 2)
end

local function StyleHealiumButton(hb)
    if hb.tempusSkinned then return end
    hb.tempusSkinned = true
    local icon = hb.icon
    if type(icon) == "table" then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    S.Backdrop(hb, { fill = { 0.03, 0.035, 0.045, 1 }, shadow = false })
    for _, r in ipairs({ hb:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" and r:GetDrawLayer() == "HIGHLIGHT" and not r.tempus then
            r:SetTexture(S.WHITE)
            r:SetVertexColor(1, 1, 1, 0.15)
            r:SetBlendMode("ADD")
        end
    end
    local pushed = hb.GetPushedTexture and hb:GetPushedTexture()
    if pushed then
        pushed:SetTexture(S.WHITE)
        pushed:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 0.3)
    end
    ReplaceBorder(hb.CurseBar, hb, 2)
end

-- Healium frames are recognised by their parts, not names (group headers name them).
local function SweepHealium()
    local f = EnumerateFrames()
    while f do
        if not f.tempusSkinned and not (f.IsForbidden and f:IsForbidden()) then
            if type(f.HealthBar) == "table" and type(f.ManaBar) == "table" and type(f.CurseBar) == "table" then
                pcall(StyleHealiumUnit, f)
            elseif type(f.CaptionBar) == "table" and type(f.CaptionBar.Caption) == "table" then
                pcall(StyleHealiumGroup, f)
            elseif type(f.CurseBar) == "table" and type(f.icon) == "table" and type(f.cooldown) == "table" then
                pcall(StyleHealiumButton, f)
            end
        end
        f = EnumerateFrames(f)
    end
end

local function InitHealium()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded)("Healium")
    if not loaded or SK.healiumDone then return end
    SK.healiumDone = true
    local sweep = T:Wrap("skins.healium", SweepHealium)
    local function Soon() C_Timer.After(0.3, function() pcall(sweep) end) end
    Soon()
    local ev = CreateFrame("Frame")
    -- A full frame walk is costly: only when the group or the player's own pet changes.
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
    pcall(ev.RegisterUnitEvent, ev, "UNIT_PET", "player")
    ev:SetScript("OnEvent", Soon)
    if HealiumUnitFrames_ShowHideFrame then hooksecurefunc("HealiumUnitFrames_ShowHideFrame", Soon) end
    if Healium_UpdateOpaqueHealthbarBackgrounds then
        hooksecurefunc("Healium_UpdateOpaqueHealthbarBackgrounds", function()
            -- Healium re-applies its tile texture here; restyle those backgrounds again.
            local f = EnumerateFrames()
            while f do
                if f.tempusSkinned and type(f.HealthbarOpaqueBackgrounds) == "table" and f.HealthbarOpaqueBackgrounds[2] then
                    f.HealthbarOpaqueBackgrounds[2]:SetTexture(S.WHITE)
                    f.HealthbarOpaqueBackgrounds[2]:SetVertexColor(0.08, 0.09, 0.11, 1)
                end
                f = EnumerateFrames(f)
            end
        end)
    end
end

function SK:InitAddOns()
    if SK.db.healium ~= false then pcall(InitHealium) end
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
