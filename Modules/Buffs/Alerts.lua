-- Tempus: expiry warnings, on-screen alert toasts, and the minimap button.
local _, T = ...

T.sounds = {
    { 8959, "Raid Warning" },
    { 8960, "Ready Check" },
    { 12889, "Alarm Clock" },
    { 3081, "Whisper" },
    { 3175, "Map Ping" },
    { 850, "Quest Log Open" },
}

----------------------------------------------------------------------------------------
-- Toasts: icon + message, stacked, slide and fade.
----------------------------------------------------------------------------------------
local anchor, toasts = nil, {}

local function CreateToast()
    local f = CreateFrame("Frame", nil, anchor)
    f:SetSize(360, 34)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    T.Display.SetGradient(bg, "HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, 0.7)
    f.bg = bg
    local bg2 = f:CreateTexture(nil, "BACKGROUND")
    bg2:SetPoint("TOPLEFT", f, "TOP")
    bg2:SetPoint("BOTTOMRIGHT")
    bg2:SetTexture("Interface\\Buttons\\WHITE8X8")
    T.Display.SetGradient(bg2, "HORIZONTAL", 0, 0, 0, 0.7, 0, 0, 0, 0)
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT")
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOM")
    local line = f:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 40, 0)
    line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 0)
    line:SetHeight(1)
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.line = line
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(26, 26)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    f.text:SetShadowOffset(1, -1)
    f.text:SetPoint("CENTER", 15, 0)
    f.icon:SetPoint("RIGHT", f.text, "LEFT", -8, 0)
    f:Hide()
    f:SetScript("OnUpdate", function(self)
        local t = GetTime() - self.born
        local a
        if t < 0.25 then a = t / 0.25
        elseif t < 3.5 then a = 1
        elseif t < 4.3 then a = 1 - (t - 3.5) / 0.8
        else
            self:Hide()
            return
        end
        self:SetAlpha(a)
        local slide = t < 0.25 and (1 - t / 0.25) * 12 or 0
        self:SetPoint("TOP", anchor, "TOP", 0, -((self.slot - 1) * 38) + slide)
    end)
    return f
end

function T:Toast(icon, text, r, g, b)
    if not anchor then return end
    -- Reuse the oldest toast when all are busy.
    local toast
    for i = 1, 3 do toasts[i] = toasts[i] or CreateToast() end
    for i = 1, 3 do
        if not toasts[i]:IsShown() then toast = toasts[i]; break end
    end
    if not toast then
        toast = toasts[1]
        for i = 2, 3 do if toasts[i].born < toast.born then toast = toasts[i] end end
    end
    local used = {}
    for i = 1, 3 do if toasts[i] ~= toast and toasts[i]:IsShown() then used[toasts[i].slot] = true end end
    toast.slot = (not used[1] and 1) or (not used[2] and 2) or 3
    toast.born = GetTime()
    toast.icon:SetTexture(icon or 134400)
    toast.icon:SetShown(icon ~= nil)
    toast.text:SetText(text)
    toast.text:SetTextColor(r or 1, g or 1, b or 1)
    toast.line:SetVertexColor(r or 1, g or 1, b or 1, 0.8)
    toast:ClearAllPoints()
    toast:SetPoint("TOP", anchor, "TOP", 0, -((toast.slot - 1) * 38))
    toast:SetAlpha(0)
    toast:Show()
end

----------------------------------------------------------------------------------------
-- Expiry tracking (readable auras only; secret timings cannot be watched from Lua).
----------------------------------------------------------------------------------------
local tracked = {}      -- key -> { name, icon, duration, expiration, warned }

local function Key(e)
    if e.weapon then return "w" .. e.weapon end
    return e.auraInstanceID or (e.nameOK and e.name) or nil
end

local function Announce(e, msg, color)
    local a = T.db.alerts
    T:Toast(e.icon, msg, color[1], color[2], color[3])
    if a.sound and a.soundKit and a.soundKit > 0 then PlaySound(a.soundKit, "Master") end
    if a.chat then T:Print(msg) end
end

function T:ProcessAlerts(buffs, weapons)
    local a = T.db.alerts
    local now = GetTime()
    local seen = {}
    -- In combat the scan can be partial or hidden; then only add or refresh buffs and
    -- never treat a missing one as gone (the countdown keeps running on what we know).
    local reliable = T.Auras.lastScanReliable and T.Auras.lastScanReliable.HELPFUL
    local function consider(e)
        if e.secret or e.permanent or not e.nameOK then return end
        if (e.duration or 0) < a.minDuration then return end
        if T:ListHas("hidden", e.name, e.spellId) then return end
        local key = Key(e)
        if not key then return end
        seen[key] = true
        local t = tracked[key]
        if not t or math.abs(t.expiration - e.expiration) > 2 then
            local rem = e.expiration - now
            -- First seen already inside the warning window (e.g. after a reload): warn now.
            tracked[key] = { name = e.name, icon = e.icon, duration = e.duration, expiration = e.expiration,
                warned = rem <= 0 }
        end
    end
    for _, e in ipairs(buffs) do consider(e) end
    for _, e in ipairs(weapons) do consider(e) end
    for key, t in pairs(tracked) do
        if not seen[key] and (reliable or (type(key) == "string" and key:sub(1, 1) == "w") or t.expiration < now) then
            if a.expired and t.expiration - now < 2 and not UnitIsDeadOrGhost("player") then
                Announce(t, t.name .. " has expired", T.db.colors.urgent)
            end
            tracked[key] = nil
        end
    end
end

local function CheckWarnings()
    if not T.db then return end
    local a = T.db.alerts
    if not a.warn then return end
    local now = GetTime()
    for _, t in pairs(tracked) do
        if not t.warned then
            local rem = t.expiration - now
            if rem <= a.warnAt and rem > 0 then
                t.warned = true
                Announce(t, ("%s expires in %d sec"):format(t.name, math.ceil(rem)), T.db.colors.soon)
            end
        end
    end
end

function T:InitAlerts()
    anchor = CreateFrame("Frame", "TempusAlertAnchor", UIParent)
    anchor:SetSize(360, 120)
    anchor:SetPoint("TOP", UIParent, "TOP", 0, -170)
    anchor:SetFrameStrata("HIGH")
    C_Timer.NewTicker(0.5, T:Wrap("buffs.alerts", CheckWarnings))
end

----------------------------------------------------------------------------------------
-- Minimap button
----------------------------------------------------------------------------------------
local mm

-- With the Tempus minimap, the button is a square docked in the map's lower right corner.
local function Docked()
    return T.Minimap and T.Minimap.holder and true or false
end

-- Same size, scale and inset as the day/night icon in the opposite corner (falls back to 28px at 0.8).
local function DielMetrics()
    local diel = (MinimapCluster and MinimapCluster.DielFrame) or _G.DielFrame
    local w, h = diel and diel:GetWidth() or 0, diel and diel:GetHeight() or 0
    if w < 8 or h < 8 then return 35, 35, 0.8 end
    return w, h, diel:GetScale() or 1
end

local RING = { 0.62, 0.47, 0.2 }
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- A round gold-ringed icon like the day/night one: outer ring, dark inner rim, masked logo.
local function BuildRing()
    if mm.ringOuter then return end
    mm.ringOuter = mm:CreateTexture(nil, "BACKGROUND", nil, 1)
    mm.ringOuter:SetTexture(T.Style.WHITE)
    mm.ringOuter:SetVertexColor(RING[1], RING[2], RING[3], 1)
    mm.ringOuter:SetAllPoints(mm)
    mm.ringInner = mm:CreateTexture(nil, "BACKGROUND", nil, 2)
    mm.ringInner:SetTexture(T.Style.WHITE)
    mm.ringInner:SetVertexColor(0.05, 0.045, 0.04, 1)
    mm.ringInner:SetPoint("TOPLEFT", 2, -2)
    mm.ringInner:SetPoint("BOTTOMRIGHT", -2, 2)
    mm.mask = mm:CreateMaskTexture()
    mm.mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mm.mask:SetAllPoints(mm)
    mm.ringOuter:AddMaskTexture(mm.mask)
    -- The inner disc needs its own mask, inset like the disc itself, or the full-size circle cuts its corners.
    mm.innerMask = mm:CreateMaskTexture()
    mm.innerMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mm.innerMask:SetPoint("TOPLEFT", 2, -2)
    mm.innerMask:SetPoint("BOTTOMRIGHT", -2, 2)
    mm.ringInner:AddMaskTexture(mm.innerMask)
    mm.iconMask = mm:CreateMaskTexture()
    mm.iconMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mm.iconMask:SetPoint("TOPLEFT", 3, -3)
    mm.iconMask:SetPoint("BOTTOMRIGHT", -3, 3)
end

local function StyleMinimapButton()
    local docked = Docked()
    mm.round:SetShown(not docked)
    mm.roundBg:SetShown(not docked)
    if mm.tempusBackdrop then mm.tempusBackdrop.hidden = true; mm.tempusBackdrop:Refresh() end
    if docked then
        BuildRing()
        local w, h, scale = DielMetrics()
        -- The day/night frame has clear padding around its disc; shrink ours to the disc's size.
        mm:SetSize(w * 0.86, h * 0.86)
        mm:SetScale(scale)
        mm.ringOuter:Show()
        mm.ringInner:Show()
        mm.icon:ClearAllPoints()
        mm.icon:SetPoint("TOPLEFT", 3, -3)
        mm.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        mm.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        mm.icon:SetTexture("Interface\\AddOns\\Tempus\\media\\icon-minimap")   -- the logo without its tick marks
        if not mm.iconMasked then mm.icon:AddMaskTexture(mm.iconMask); mm.iconMasked = true end
        mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    else
        if mm.ringOuter then mm.ringOuter:Hide(); mm.ringInner:Hide() end
        if mm.iconMasked then mm.icon:RemoveMaskTexture(mm.iconMask); mm.iconMasked = false end
        mm.icon:SetTexture(T.LOGO)
        mm:SetScale(1)
        mm:SetSize(31, 31)
        mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        mm.icon:ClearAllPoints()
        mm.icon:SetPoint("TOPLEFT", 6, -5)
        mm.icon:SetSize(20, 20)
        mm.icon:SetTexCoord(0, 1, 0, 1)
    end
end

local function PositionMinimapButton()
    StyleMinimapButton()
    if Docked() then
        mm:ClearAllPoints()
        mm:SetPoint("BOTTOMRIGHT", T.Minimap.holder, "BOTTOMRIGHT", -6, 6)   -- same margin as the day/night disc at BOTTOMLEFT
        mm:SetFrameLevel(T.Minimap.holder:GetFrameLevel() + 9)
        return
    end
    local angle = math.rad(T.db.minimap.angle or 215)
    local r = (Minimap:GetWidth() / 2) + 5
    local x, y = math.cos(angle), math.sin(angle)
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        -- Project onto the square's edge instead of a circle.
        local m = math.max(math.abs(x), math.abs(y))
        x, y = x / m, y / m
    end
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

function T:InitMinimapButton()
    mm = CreateFrame("Button", "TempusMinimapButton", Minimap)
    mm:SetSize(31, 31)
    mm:SetFrameStrata("MEDIUM")
    mm:SetFrameLevel(8)
    mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mm:RegisterForDrag("LeftButton")
    mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local overlay = mm:CreateTexture(nil, "OVERLAY")
    mm.round = overlay
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")
    local bg = mm:CreateTexture(nil, "BACKGROUND")
    mm.roundBg = bg
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = mm:CreateTexture(nil, "ARTWORK")
    mm.icon = icon
    icon:SetSize(20, 20)
    icon:SetTexture(T.LOGO)
    icon:SetPoint("TOPLEFT", 6, -5)
    mm:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if T.Minimap and T.Minimap.ButtonMode and Docked() and T.Minimap:ButtonMode() == "TRAY" then
                T.Minimap:ToggleTray()
            else
                T.db.locked = not T.db.locked
                T:ApplySettings()
            end
        else
            T.Options:Toggle()
        end
    end)
    mm:SetScript("OnDragStart", function(self)
        if Docked() then return end
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            T.db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
            PositionMinimapButton()
        end)
    end)
    mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mm:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cff" .. T.accentHex .. "Tempus|r UI")
        GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
        if Docked() and T.Minimap:ButtonMode() == "TRAY" then
            GameTooltip:AddLine("Right-click: addon button tray", 1, 1, 1)
        else
            GameTooltip:AddLine("Right-click: " .. (T.db.locked and "unlock" or "lock") .. " frames", 1, 1, 1)
        end
        if not Docked() then GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7) end
        GameTooltip:Show()
    end)
    mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
    T:UpdateMinimapButton()
end

function T:UpdateMinimapButton()
    if not mm then return end
    mm:SetShown(not T.db.minimap.hide)
    PositionMinimapButton()
end
