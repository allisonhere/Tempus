-- Tempus UI: Blizzard's built-in damage meter in a Tempus panel with a flat title bar, flat bars and
-- recoloured controls. Textures and fonts only: the meter keeps its own layout, data and secret-value handling. Bars are recycled by the
-- scroll list, so new rows are caught by a light timer while a meter window is open.
local _, T = ...
local S = T.Style
local SK = T.Skins

local MAX_WINDOWS = 5
local panels = {}

local function Hide(r)
    if type(r) == "table" and r.SetAlpha then r:SetAlpha(0) end
end

local function SkinEntry(e)
    if type(e) ~= "table" or e.tempusMeter then return end
    e.tempusMeter = true
    local bar = e.StatusBar
    if type(bar) ~= "table" then return end
    Hide(bar.Background)
    Hide(bar.BackgroundEdge)
    if bar.SetStatusBarTexture then pcall(bar.SetStatusBarTexture, bar, S.BarTexture(T.db.barTexture)) end
    local bg = S.Tex(bar, "BACKGROUND", { 0.03, 0.035, 0.045, 0.85 })
    bg.tempus = true
    bg:SetAllPoints()
    for _, key in ipairs({ "Name", "Value" }) do
        if type(bar[key]) == "table" and bar[key].SetFont then S.ApplyFont(bar[key], 11) end
    end
end

local function SkinEntries(win)
    local container = win.MinimizeContainer
    if type(container) ~= "table" then return end
    local box = container.ScrollBox
    if type(box) == "table" and box.ForEachFrame then pcall(box.ForEachFrame, box, SkinEntry) end
    SkinEntry(container.LocalPlayerEntry)
end

local MUTED = { 0.72, 0.77, 0.86 }

-- Grey icon that lights up in the accent colour under the mouse.
local function TintIcons(button, textures)
    local function Paint(r, g, b)
        for _, t in ipairs(textures) do
            if t.SetDesaturated then t:SetDesaturated(true) end
            t:SetVertexColor(r, g, b)
        end
    end
    Paint(MUTED[1], MUTED[2], MUTED[3])
    if button.HookScript then
        button:HookScript("OnEnter", function() Paint(T.accent[1], T.accent[2], T.accent[3]) end)
        button:HookScript("OnLeave", function() Paint(MUTED[1], MUTED[2], MUTED[3]) end)
    end
end

local function SkinControls(win)
    local minimize = win.MinimizeButton
    if type(minimize) == "table" and minimize.GetRegions then
        local regions = { minimize:GetRegions() }
        if regions[1] then TintIcons(minimize, { regions[1] }) end
        if regions[3] then regions[3]:SetAlpha(0) end       -- the red hover glow
    end
    local gear = win.SettingsDropdown
    if type(gear) == "table" and type(gear.Icon) == "table" then TintIcons(gear, { gear.Icon }) end

    local session = win.SessionDropdown
    if type(session) == "table" then
        Hide(session.Background)
        Hide(session.Arrow)
        local card = CreateFrame("Frame", nil, session)
        card:SetPoint("TOPLEFT", -1, 1)
        card:SetPoint("BOTTOMRIGHT", 1, -1)
        card:SetFrameLevel(math.max(session:GetFrameLevel() - 1, 0))
        S.Backdrop(card, { fill = { 0.07, 0.08, 0.1, 0.9 }, shadow = false, inner = false })
        for _, key in ipairs({ "SessionName", "Text" }) do
            if type(session[key]) == "table" and session[key].SetFont then S.ApplyFont(session[key], 12) end
        end
        local label = session.SessionName
        if type(label) == "table" and label.SetTextColor then label:SetTextColor(T.accent[1], T.accent[2], T.accent[3]) end
    end

    local kind = win.DamageMeterTypeDropdown
    if type(kind) == "table" then
        if type(kind.Arrow) == "table" then TintIcons(kind, { kind.Arrow }) end
        if type(kind.TypeName) == "table" and kind.TypeName.SetFont then
            S.ApplyFont(kind.TypeName, 12)
            kind.TypeName:SetTextColor(0.9, 0.93, 0.97)
        end
    end
end

local function SkinWindow(win)
    if win.tempusMeterWindow then return end
    win.tempusMeterWindow = true
    local container = win.MinimizeContainer
    if type(container) == "table" then
        Hide(container.Background)
        if type(container.ScrollBar) == "table" then pcall(SK.ScrollBar, SK, container.ScrollBar) end
        local source = container.SourceWindow
        if type(source) == "table" then
            Hide(source.Background)
            local sp = CreateFrame("Frame", nil, source)
            sp:SetAllPoints()
            sp:SetFrameLevel(math.max(source:GetFrameLevel() - 1, 0))
            S.Backdrop(sp, { fill = { 0.04, 0.045, 0.058, 0.95 } })
            if type(source.ScrollBar) == "table" then pcall(SK.ScrollBar, SK, source.ScrollBar) end
        end
    end
    local header = win.Header
    local headerHeight = (type(header) == "table" and header.GetHeight and header:GetHeight()) or 32
    Hide(header)
    local alpha = SK.db.meterAlpha
    local panel = CreateFrame("Frame", nil, win)
    panel:SetAllPoints()
    panel:SetFrameLevel(math.max(win:GetFrameLevel() - 1, 0))
    panel.bd = S.Backdrop(panel, { fill = { 0.04, 0.045, 0.058, alpha } })
    panel.header = S.Tex(panel, "BACKGROUND", { 0.02, 0.025, 0.035, math.min(1, alpha + 0.25) })
    panel.header.tempus = true
    panel.header:SetPoint("TOPLEFT")
    panel.header:SetPoint("TOPRIGHT")
    panel.header:SetHeight(headerHeight)
    panels[#panels + 1] = panel
    SK:Try("damage meter controls", SkinControls, win)
end

function SK:UpdateMeterAlpha()
    for _, p in ipairs(panels) do
        p.bd:SetFillColor(0.04, 0.045, 0.058, SK.db.meterAlpha)
        p.header:SetVertexColor(0.02, 0.025, 0.035, math.min(1, SK.db.meterAlpha + 0.25))
    end
end

local function Sweep()
    for i = 1, MAX_WINDOWS do
        local win = _G["DamageMeterSessionWindow" .. i]
        if win and win.GetObjectType then
            if not win.tempusMeterWindow then SK:Try("damage meter", SkinWindow, win) end
            if win:IsShown() then SK:Try("damage meter rows", SkinEntries, win) end
        end
    end
end

function SK:InitMeter()
    Sweep()
    C_Timer.NewTicker(1.5, T:Wrap("skins.meter", Sweep))
end
