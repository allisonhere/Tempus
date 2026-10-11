-- Tempus UI: Blizzard's built-in damage meter in a Tempus panel with flat bars. Textures and fonts
-- only: the meter keeps its own layout, data and secret-value handling. Bars are recycled by the
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

local function SkinWindow(win)
    if win.tempusMeterWindow then return end
    win.tempusMeterWindow = true
    Hide(win.Header)
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
    local alpha = SK.db.meterAlpha
    local panel = CreateFrame("Frame", nil, win)
    panel:SetAllPoints()
    panel:SetFrameLevel(math.max(win:GetFrameLevel() - 1, 0))
    panel.bd = S.Backdrop(panel, { fill = { 0.04, 0.045, 0.058, alpha } })
    panel.header = S.Tex(panel, "BACKGROUND", { 0.02, 0.025, 0.035, math.min(1, alpha + 0.25) })
    panel.header.tempus = true
    panel.header:SetPoint("TOPLEFT")
    panel.header:SetPoint("TOPRIGHT")
    panel.header:SetHeight(28)
    panels[#panels + 1] = panel
    for _, key in ipairs({ "DamageMeterTypeDropdown", "SessionDropdown" }) do
        local d = win[key]
        if type(d) == "table" then
            for _, fsKey in ipairs({ "TypeName", "SessionName", "Text" }) do
                if type(d[fsKey]) == "table" and d[fsKey].SetFont then S.ApplyFont(d[fsKey], 12) end
            end
        end
    end
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
