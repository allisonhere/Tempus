-- Tempus UI: square minimap in a Tempus panel, with zone text, clock, wheel zoom,
-- click shortcuts and fading addon buttons.
local _, T = ...
local S = T.Style

local MM = {}
T.Minimap = MM

MM.defaults = {
    size = 180,
    scale = 1,
    zoneText = "MOUSEOVER",     -- ALWAYS | MOUSEOVER | HIDE
    clock = true,
    clock24 = true,
    coords = false,
    fadeAddonButtons = true,
    point = { "TOPRIGHT", "UIParent", "TOPRIGHT", -8, -8 },
    hide = false, angle = 215,      -- the Tempus minimap button (shared table)
}

local hidden = T.Style.HiddenParent

local function Hide(frame)
    if type(frame) ~= "table" or not frame.SetParent then return end
    pcall(frame.SetParent, frame, hidden)
    -- Blizzard re-attaches some cluster pieces on layout; send them back each time.
    if not frame.tempusHideHooked and frame.GetObjectType and frame:GetObjectType() ~= "Texture" then
        frame.tempusHideHooked = true
        hooksecurefunc(frame, "SetParent", function(self, p)
            if p ~= hidden then C_Timer.After(0, function() pcall(self.SetParent, self, hidden) end) end
        end)
    end
end

-- Move a Blizzard minimap widget onto the square map at a fixed spot.
local function Rehome(frame, point, x, y, scale)
    if type(frame) ~= "table" or not frame.SetParent then return end
    frame:SetParent(MM.holder)
    frame:ClearAllPoints()
    frame:SetPoint(point, MM.holder, point, x, y)
    if scale then frame:SetScale(scale) end
    frame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
end

-- LibDBIcon and friends ask this to lay their buttons out around a square edge.
function GetMinimapShape() return "SQUARE" end

local ZONE_COLORS = {
    sanctuary = { 0.41, 0.8, 0.94 }, arena = { 1, 0.1, 0.1 }, friendly = { 0.1, 1, 0.1 },
    hostile = { 1, 0.1, 0.1 }, contested = { 1, 0.7, 0 }, combat = { 1, 0.1, 0.1 },
}

function MM:UpdateZone()
    local text = GetMinimapZoneText and GetMinimapZoneText() or ""
    local pvp = GetZonePVPInfo and GetZonePVPInfo()
    local c = ZONE_COLORS[pvp or ""] or { 1, 0.9, 0.7 }
    MM.zone:SetText(text)
    MM.zone:SetTextColor(c[1], c[2], c[3])
end

function MM:UpdateClock()
    local h, m = tonumber(date("%H")), tonumber(date("%M"))
    if MM.db.clock24 then
        MM.clock:SetFormattedText("%02d:%02d", h, m)
    else
        MM.clock:SetFormattedText("%d:%02d %s", (h % 12 == 0) and 12 or h % 12, m, h < 12 and "am" or "pm")
    end
end

function MM:UpdateCoords()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = map and not T.issecret(map) and C_Map.GetPlayerMapPosition(map, "player")
    local x, y
    if pos then x, y = pos:GetXY() end
    if T.Num(x) and T.Num(y) and (x > 0 or y > 0) then
        MM.coords:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
    else
        MM.coords:SetText("")
    end
end

-- Addon buttons (LibDBIcon etc.) are children of the Minimap; fade them unless hovered.
local function AddonButtons()
    local list = {}
    for _, child in ipairs({ Minimap:GetChildren() }) do
        local name = child.GetName and child:GetName()
        if name and (name:find("^LibDBIcon") or name == "TempusMinimapButton") then list[#list + 1] = child end
    end
    return list
end

-- How addon buttons behave: EDGE (around the square), FADE (edge, hidden until mouseover) or
-- TRAY (collected behind one button). Older profiles only have the fadeAddonButtons checkbox.
function MM:ButtonMode()
    local db = MM.db
    return db.addonButtons or (db.fadeAddonButtons and "FADE" or "EDGE")
end

----------------------------------------------------------------------------------------
-- Button tray: every LibDBIcon button is moved into a grid that opens from one small button.
----------------------------------------------------------------------------------------
local TRAY_COLS, TRAY_PAD, TRAY_GAP = 5, 6, 4

local function DBIcon()
    return LibStub and LibStub("LibDBIcon-1.0", true)
end

local function TrayCandidates()
    local list = {}
    for _, parent in ipairs({ Minimap, MM.tray }) do
        if parent then
            for _, child in ipairs({ parent:GetChildren() }) do
                local name = child.GetName and child:GetName()
                if name and name:find("^LibDBIcon10_") then list[#list + 1] = child end
            end
        end
    end
    table.sort(list, function(a, b) return a:GetName() < b:GetName() end)
    return list
end

local function Collect(b)
    b.tempusTray = true
    b:SetParent(MM.tray)
    b:SetFrameLevel(MM.tray:GetFrameLevel() + 2)
    b:SetAlpha(1)
    b:RegisterForDrag()                       -- no dragging around the minimap edge while in the tray
    if not b.tempusTrayHook then
        b.tempusTrayHook = true
        -- LibDBIcon puts a button back on the edge whenever it refreshes; send it back to its tray cell.
        hooksecurefunc(b, "SetPoint", function(self)
            if self.tempusTray and not self.tempusPlacing and MM.trayOn then
                C_Timer.After(0, function() MM:LayoutTray() end)
            end
        end)
    end
end

function MM:LayoutTray()
    if not (MM.tray and MM.trayOn) then return end
    local n, size = 0, 31
    for _, b in ipairs(TrayCandidates()) do
        if not b.tempusTray then Collect(b) end
        if not (b.db and b.db.hide) then
            size = b:GetWidth() > 0 and b:GetWidth() or size
            local col, row = n % TRAY_COLS, math.floor(n / TRAY_COLS)
            b.tempusPlacing = true
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", MM.tray, "TOPLEFT", TRAY_PAD + col * (size + TRAY_GAP), -TRAY_PAD - row * (size + TRAY_GAP))
            b.tempusPlacing = false
            b:Show()
            n = n + 1
        end
    end
    local cols, rows = math.max(1, math.min(n, TRAY_COLS)), math.max(1, math.ceil(n / TRAY_COLS))
    MM.tray:SetSize(TRAY_PAD * 2 + cols * size + (cols - 1) * TRAY_GAP, TRAY_PAD * 2 + rows * size + (rows - 1) * TRAY_GAP)
    MM.trayEmpty:SetShown(n == 0)
end

-- Back to the minimap edge: re-parent each button and let LibDBIcon place it from its saved angle.
function MM:ReleaseTray()
    local lib = DBIcon()
    for _, b in ipairs(TrayCandidates()) do
        if b.tempusTray then
            b.tempusTray = false
            b:SetParent(Minimap)
            b:RegisterForDrag("LeftButton")
            local name = b:GetName():match("^LibDBIcon10_(.+)")
            if lib and lib.Refresh and name then pcall(lib.Refresh, lib, name, b.db) end
        end
    end
end

-- Right-click on the Tempus minimap button.
function MM:ToggleTray()
    local tray = MM.tray
    if not tray or not MM.trayOn then return end
    if tray:IsShown() then tray:Hide() return end
    MM:LayoutTray()
    tray:ClearAllPoints()
    local bottom = MM.holder:GetBottom() or 0
    if bottom < (UIParent:GetHeight() or 768) / 2 then
        tray:SetPoint("BOTTOMRIGHT", MM.holder, "TOPRIGHT", 0, 4)
    else
        tray:SetPoint("TOPRIGHT", MM.holder, "BOTTOMRIGHT", 0, -4)
    end
    tray:Show()
end

function MM:BuildTray()
    local tray = CreateFrame("Frame", "TempusMinimapTray", UIParent)
    tray:SetFrameStrata("HIGH")
    tray:SetClampedToScreen(true)
    tray:EnableMouse(true)
    S.Backdrop(tray)
    tray:Hide()
    MM.tray = tray
    MM.trayEmpty = tray:CreateFontString(nil, "OVERLAY")
    MM.trayEmpty:SetFont(S.FONT, 11, "")
    MM.trayEmpty:SetTextColor(0.55, 0.6, 0.68)
    MM.trayEmpty:SetText("No addon buttons")
    MM.trayEmpty:SetPoint("CENTER")
    tray:SetSize(120, 40)

    -- Closes itself shortly after the mouse leaves.
    tray:SetScript("OnUpdate", function(self, elapsed)
        local opener = _G.TempusMinimapButton
        if self:IsMouseOver(8, -8, -8, 8) or (opener and opener:IsMouseOver()) then
            self.idle = 0
        else
            self.idle = (self.idle or 0) + elapsed
            if self.idle > 1.2 then self:Hide() end
        end
    end)
end

function MM:ApplyButtonMode()
    local mode = MM:ButtonMode()
    if mode == "TRAY" then
        MM.trayOn = true
        for _, b in ipairs(AddonButtons()) do b:SetAlpha(1) end   -- Tempus's own button stays on the edge
        MM:LayoutTray()
    else
        if MM.trayOn then
            MM.trayOn = false
            MM:ReleaseTray()
        end
        MM.tray:Hide()
        for _, b in ipairs(AddonButtons()) do b:SetAlpha(mode == "FADE" and 0 or 1) end
    end
end

local function Hovered()
    return MM.holder:IsMouseOver(8, -8, -8, 8)
end

function MM:UpdateHover()
    local over = Hovered()
    if over == MM.lastOver then return end
    MM.lastOver = over
    if MM.db.zoneText == "MOUSEOVER" then MM.zone:SetShown(over) end
    if MM:ButtonMode() == "FADE" then
        for _, b in ipairs(AddonButtons()) do b:SetAlpha(over and 1 or 0) end
    end
end

----------------------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------------------
local function OpenTracking()
    local t = MinimapCluster and MinimapCluster.Tracking
    local btn = t and (t.Button or t)
    if btn and btn.OpenMenu and pcall(btn.OpenMenu, btn) then return end
    if btn and btn.Click and pcall(btn.Click, btn) then return end
    if MiniMapTrackingDropDown and ToggleDropDownMenu then
        pcall(ToggleDropDownMenu, 1, nil, MiniMapTrackingDropDown, "cursor")
    end
end

local function Build()
    local holder = CreateFrame("Frame", "TempusMinimap", UIParent)
    holder:SetFrameStrata("LOW")
    MM.holder = holder
    S.Backdrop(holder)

    Minimap:SetParent(holder)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    Minimap:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    Minimap:SetMaskTexture(S.WHITE)
    Minimap:SetFrameLevel(holder:GetFrameLevel() + 2)
    if Minimap.SetArchBlobRingScalar then Minimap:SetArchBlobRingScalar(0) end
    if Minimap.SetQuestBlobRingScalar then Minimap:SetQuestBlobRingScalar(0) end

    -- Blizzard decoration around the round map.
    -- By name: a table of globals would stop at the first one this client lacks.
    for _, name in ipairs({ "MinimapCompassTexture", "MinimapBackdrop", "MinimapBorder", "MinimapBorderTop", "GameTimeFrame",
        "TimeManagerClockButton", "MinimapZoomIn", "MinimapZoomOut", "MiniMapWorldMapButton", "MinimapToggleButton" }) do
        local f = _G[name]
        if type(f) == "table" and f.Hide then
            if f.GetObjectType and f:GetObjectType() == "Texture" then f:SetTexture(nil) else Hide(f) end
        end
    end
    if Minimap.ZoomIn then Hide(Minimap.ZoomIn) end
    if Minimap.ZoomOut then Hide(Minimap.ZoomOut) end
    if Minimap.ZoomHitArea then Hide(Minimap.ZoomHitArea) end
    local cluster = MinimapCluster
    if cluster then
        for _, key in ipairs({ "BorderTop", "ZoneTextButton", "Tracking" }) do Hide(cluster[key]) end
        -- Keep useful indicators, re-homed onto the square map.
        if type(cluster.IndicatorFrame) == "table" then
            cluster.IndicatorFrame:SetParent(holder)
            cluster.IndicatorFrame:ClearAllPoints()
            cluster.IndicatorFrame:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -4, -4)
            cluster.IndicatorFrame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        end
        if type(cluster.InstanceDifficulty) == "table" then
            cluster.InstanceDifficulty:SetParent(holder)
            cluster.InstanceDifficulty:ClearAllPoints()
            cluster.InstanceDifficulty:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -2)
        end
        pcall(cluster.EnableMouse, cluster, false)
        -- Forever's day/night cycle indicator: keep it, in the bottom-left corner.
        pcall(Rehome, cluster.DielFrame or _G.DielFrame, "BOTTOMLEFT", 2, 2, 0.8)
    end
    pcall(Rehome, _G.AddonCompartmentFrame, "TOPRIGHT", -4, -24, 0.9)
    if MiniMapMailIcon and not (cluster and type(cluster.IndicatorFrame) == "table") then
        local mail = MiniMapMailIcon:GetParent() or MiniMapMailIcon
        mail:SetParent(holder)
        mail:ClearAllPoints()
        mail:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -4, -4)
    end
    if QueueStatusButton then
        QueueStatusButton:SetParent(holder)
        QueueStatusButton:ClearAllPoints()
        QueueStatusButton:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 2, 2)
        QueueStatusButton:SetScale(0.7)
    end

    -- Text overlays
    local over = CreateFrame("Frame", nil, holder)
    over:SetAllPoints(holder)
    over:SetFrameLevel(Minimap:GetFrameLevel() + 6)
    MM.zone = over:CreateFontString(nil, "OVERLAY")
    MM.zone:SetPoint("TOP", holder, "TOP", 0, -5)
    MM.zone:SetPoint("LEFT", holder, "LEFT", 6, 0)
    MM.zone:SetPoint("RIGHT", holder, "RIGHT", -6, 0)
    MM.zone:SetWordWrap(false)
    MM.clock = over:CreateFontString(nil, "OVERLAY")
    MM.clock:SetPoint("BOTTOM", holder, "BOTTOM", 0, 5)
    MM.coords = over:CreateFontString(nil, "OVERLAY")
    MM.coords:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -30, 5)   -- clear of the Tempus button in the corner

    -- Interaction: wheel zoom, right-click tracking, middle-click calendar.
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        local zoom = self:GetZoom()
        if delta > 0 and zoom < self:GetZoomLevels() - 1 then self:SetZoom(zoom + 1)
        elseif delta < 0 and zoom > 0 then self:SetZoom(zoom - 1) end
    end)
    Minimap:HookScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            OpenTracking()
        elseif button == "MiddleButton" then
            if ToggleCalendar then pcall(ToggleCalendar) elseif TimeManager_Toggle then pcall(TimeManager_Toggle) end
        end
    end)

    T.Movers:Register(holder, {
        label = "Minimap", page = "minimap",
        cfg = function() return MM.db end,
        corner = function() return MM.db.point[1] end,
    })

    MM:BuildTray()

    local t, tc, tt = 0, 0, 0
    holder:SetScript("OnUpdate", T:Wrap("minimap.tick", function(_, elapsed)
        t, tc, tt = t + elapsed, tc + elapsed, tt + elapsed
        -- Addons that create their button late still end up in the tray.
        if tt >= 3 then
            tt = 0
            if MM.trayOn then MM:LayoutTray() end
        end
        if t >= 0.1 then
            t = 0
            MM:UpdateHover()
            if MM.db.coords then MM:UpdateCoords() end
        end
        if tc >= 1 then
            tc = 0
            if MM.db.clock then MM:UpdateClock() end
        end
    end))
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do ev:RegisterEvent(e) end
    ev:SetScript("OnEvent", function() MM:UpdateZone() end)
end

function MM:Refresh()
    local db = MM.db
    local h = MM.holder
    h:SetScale(db.scale)
    h:SetSize(db.size, db.size)
    T.Movers.ApplyPoint(h, db)
    -- The map texture only redraws at the new size after a size change on the Minimap itself.
    Minimap:SetSize(db.size - 2, db.size - 2)
    S.ApplyFont(MM.zone, 12)
    S.ApplyFont(MM.clock, 12)
    S.ApplyFont(MM.coords, 10)
    MM.zone:SetShown(db.zoneText == "ALWAYS" or (db.zoneText == "MOUSEOVER" and MM.lastOver))
    MM.clock:SetShown(db.clock)
    MM.coords:SetShown(db.coords)
    MM.lastOver = nil
    MM:ApplyButtonMode()
    MM:UpdateZone()
    MM:UpdateClock()
    if T.UpdateMinimapButton then T:UpdateMinimapButton() end
end

T:NewModule("minimap", {
    label = "Minimap",
    desc = "Square minimap in a Tempus panel with zone text, clock, coordinates, wheel zoom and tidy addon buttons.",
    defaults = MM.defaults,
    OnEnable = function()
        MM.db = T.db.minimap
        Build()
        MM:Refresh()
    end,
    OnSettings = function()
        MM.db = T.db.minimap
        MM:Refresh()
    end,
})
