-- One coordinate destination, with a bearing arrow and pins on both maps.
local _, T = ...
local W = {}
T.Waypoints = W
local secret = issecretvalue or function() return false end
local function Number(n) return not secret(n) and T.Num(n) end

function W.Parse(text, currentMap)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text:lower() == "clear" then return false end
    local map, rest = text:match("^#(%d+)%s+(.+)$")
    map, text = tonumber(map) or currentMap, rest or text
    local x, y, label = text:match("^(%d+%.?%d*)[%s,]+(%d+%.?%d*)%s*(.*)$")
    x, y = tonumber(x), tonumber(y)
    if not map or not x or not y or x > 100 or y > 100 then return nil end
    return { map = map, x = x / 100, y = y / 100, label = label ~= "" and label or "Waypoint" }
end

-- dx east, dy north, facing counterclockwise from north. Texture rotates counterclockwise.
function W.Bearing(dx, dy, facing)
    return math.atan2(-dx, dy) - facing, math.sqrt(dx * dx + dy * dy)
end

function W.Project(dx, dy, radius, half, facing)
    if facing then
        local s, c = math.sin(facing), math.cos(facing)
        dx, dy = dx * c + dy * s, -dx * s + dy * c
    end
    local x, y = dx * half / radius, dy * half / radius
    local scale = math.max(1, math.sqrt(x * x + y * y) / half)
    return x / scale, y / scale
end

-- Compass tape spans 180 degrees; destinations behind you clamp to its edge.
-- `linear` spaces degrees evenly (flat styles); otherwise they bunch toward the edges like a drum.
function W.CompassOffset(angle, linear)
    angle = (angle + math.pi) % (2 * math.pi) - math.pi
    angle = math.max(-math.pi / 2, math.min(math.pi / 2, angle))
    if linear then return angle / (math.pi / 2) * 85 end
    return math.sin(angle) * 85
end

-- Compass looks. drum: curved brushed-metal drum; tape: flat dark strip; panel: a backdrop at all.
W.STYLES = {
    DRUM = { label = "Drum", curve = true, drum = true,
        tape = { 1, 1, 1, 1 }, tick = { 0.04, 0.04, 0.04 }, text = { 0.02, 0.02, 0.02 }, red = true },
    FLAT = { label = "Flat tape",
        tape = { 0.1, 0.12, 0.15, 1 }, tick = { 0.82, 0.85, 0.9 }, text = { 0.92, 0.94, 0.97 } },
    MINIMAL = { label = "Minimal", tick = { 1, 1, 1 }, text = { 1, 1, 1 } },
    -- No compass at all: a real arrow that aims at the destination, with small text under it.
    ARROW = { label = "Small arrow", compact = true, tick = { 1, 1, 1 }, text = { 1, 1, 1 } },
}
W.STYLE_ORDER = { "DRUM", "FLAT", "MINIMAL", "ARROW" }

function W:Style()
    return W.STYLES[self.db and self.db.style] or W.STYLES.DRUM
end

function W:UpdateCompass(facing)
    if not self.arrow.ticks then return end
    for i = 0, 71 do
        local tick = self.arrow.ticks[i]
        local angle = (i * math.pi / 36 + (facing or 0) + math.pi) % (2 * math.pi) - math.pi
        tick:SetShown(facing ~= nil and math.abs(angle) <= math.pi / 2 and not self:Style().compact)
        local curve = math.max(0, math.cos(angle))
        local drum = self:Style().curve
        tick:SetAlpha(0.25 + 0.75 * curve)
        local scale = drum and math.max(0.65, curve) or 1
        tick:SetScale(scale)
        tick:ClearAllPoints()
        tick:SetPoint("TOP", self.arrow, "TOP", W.CompassOffset(angle, not drum) / scale,
            (-7 - (drum and 3 * (1 - curve) or 0)) / scale)
    end
end

-- Recolour and show or hide the pieces for the chosen look.
function W:ApplyStyle()
    local f, st = self.arrow, self:Style()
    if not (f and f.ticks) then return end
    local backdrop = f.tempusBackdrop
    if type(backdrop) == "table" then
        backdrop:SetShown(st.panel and true or false)
        if st.fill then backdrop:SetFillColor(st.fill[1], st.fill[2], st.fill[3], st.fill[4]) end
    end
    f.tape:SetShown(st.tape ~= nil)
    for _, tex in ipairs({ f.pointer, f.needle }) do tex:SetShown(not st.compact) end
    f.tex:ClearAllPoints()
    f.label:ClearAllPoints()
    f.distance:ClearAllPoints()
    f.close:ClearAllPoints()
    if st.compact then
        f:SetSize(130, 74)
        f.tex:SetSize(46, 46)
        f.tex:SetPoint("TOP", 0, -2)
        f.label:SetPoint("BOTTOM", 0, 14)
        f.label:SetWidth(124)
        f.label:SetJustifyH("CENTER")
        f.distance:SetPoint("BOTTOM", 0, 2)
        f.distance:SetJustifyH("CENTER")
        f.close:SetPoint("TOPRIGHT", 0, 0)
    else
        f:SetSize(230, 56)
        f.label:SetJustifyH("LEFT")
        f.distance:SetJustifyH("LEFT")
        f.tex:SetSize(14, 14)
        f.tex:SetPoint("BOTTOMLEFT", 8, 5)
        f.label:SetPoint("BOTTOMLEFT", 26, 5)
        f.label:SetWidth(104)
        f.distance:SetPoint("BOTTOMRIGHT", -23, 5)
        f.close:SetPoint("BOTTOMRIGHT", -1, 0)
    end
    if st.tape then f.tape:SetColorTexture(st.tape[1], st.tape[2], st.tape[3], st.tape[4]) end
    for _, tex in ipairs(f.drumParts) do tex:SetShown(st.drum and true or false) end
    for i = 0, 71 do
        f.tickLines[i]:SetColorTexture(st.tick[1], st.tick[2], st.tick[3], 1)
        if f.tickLabels[i] then f.tickLabels[i]:SetTextColor(st.text[1], st.text[2], st.text[3]) end
    end
    local a = T.accent or { 1, 1, 1 }
    local r, g, b = 0.9, 0.08, 0.05
    if not st.red then r, g, b = a[1], a[2], a[3] end
    f.pointer:SetVertexColor(r, g, b, 1)
    f.needle:SetColorTexture(r, g, b, 0.85)
    self:UpdateCompass(0)
end

-- Ctrl+click on the world map places the game's own map pin. Follow it: it becomes the destination.
local function ReadPin()
    local pin = C_Map and C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    if type(pin) ~= "table" or not pin.uiMapID or not pin.position then return end
    local position = pin.position
    local x, y
    if type(position.GetXY) == "function" then x, y = position:GetXY() else x, y = position.x, position.y end
    if secret(pin.uiMapID) or not Number(x) or not Number(y) then return end
    return pin.uiMapID, x, y
end

-- The game can fire its event before the pin is fully readable. Keep read failure separate from
-- a real "no pin" result so a transient error does not retire and then rediscover the same pin.
local function MapPin()
    local ok, map, x, y = pcall(ReadPin)
    return ok, map, x, y
end

-- A new map pin replaces whatever destination was set before. Called on the game's event and from the
-- refresh tick, so a missed event cannot leave the compass on the old destination.
function W:FromMapPin()
    local readable, map, x, y = MapPin()
    if not readable then return end
    local sig = map and (map .. ":" .. x .. ":" .. y)
    if sig == self.lastPin then return end
    self.lastPin = sig
    if not map or not self.db or self.db.mapClick == false then return end
    self.db.target = { map = map, x = x, y = y, label = "Map waypoint" }
    T:Print("Waypoint: Map waypoint (%.1f, %.1f).", x * 100, y * 100)
    self:Update()
end

-- A faint note along the bottom of the world map, so the Ctrl+click is discoverable.
function W:UpdateMapHint()
    local map = WorldMapFrame
    local on = self.db and self.db.mapClick ~= false and map and map.IsShown and map:IsShown()
    if not on then
        if self.hint then self.hint:Hide() end
        return
    end
    if not self.hint then
        -- Its own frame above the map canvas: a label on the map frame itself draws underneath it.
        local parent = map.ScrollContainer or map
        local box = CreateFrame("Frame", nil, map)
        box.tempus = true
        box:SetFrameStrata("DIALOG")
        box:SetFrameLevel(parent:GetFrameLevel() + 50)
        box:SetPoint("BOTTOM", parent, "BOTTOM", 0, 10)
        local back = box:CreateTexture(nil, "BACKGROUND")
        back.tempus = true
        back:SetAllPoints(box)
        back:SetColorTexture(0, 0, 0, 0.6)
        local text = T.Style.Text(box, 12, { 1, 1, 1 }, "OUTLINE")
        text:SetPoint("CENTER")
        text:SetText("Ctrl+click the map to set a Tempus waypoint")
        box:SetSize(text:GetStringWidth() + 20, 22)
        self.hint = box
    end
    self.hint:Show()
end

function W:Command(text)
    local map = C_Map and C_Map.GetBestMapForUnit("player")
    local point = W.Parse(text, map)
    if point == nil then
        T:Print("/way x y [label] uses your current zone. /way #mapID x y [label] selects a map. /way clear removes it. /tway also works.")
        return
    end
    if point and not (C_Map and C_Map.GetMapInfo(point.map)) then
        T:Print("Unknown map ID.") return
    end
    self.db.target = point or nil
    -- Any new or cleared destination retires the game's map pin, so the two never disagree.
    if self.db.mapClick ~= false and C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
    self.lastPin = nil
    T:Print(point and ("Waypoint: %s (%.1f, %.1f)."):format(point.label, point.x * 100, point.y * 100) or "Waypoint cleared.")
    self:Update()
end

local function Pin(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(28, 28)
    p.tempus = true
    p:SetFrameStrata(parent:GetFrameStrata())
    p:SetFrameLevel(parent:GetFrameLevel() + 100)
    local tex = p:CreateTexture(nil, "OVERLAY")
    tex.tempus = true
    tex:SetAllPoints(p)
    tex:SetTexture("Interface\\AddOns\\Tempus\\media\\node-pin")
    local dot = p:CreateTexture(nil, "OVERLAY", nil, 1)
    dot.tempus = true
    dot:SetColorTexture(1, 0.75, 0.1, 1)
    dot:SetSize(7, 7)
    dot:SetPoint("CENTER", p, "CENTER", 0, 4)
    p:EnableMouse(true)
    p:SetScript("OnEnter", function()
        local target = W.db.target
        if not target then return end
        GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
        GameTooltip:AddLine(target.label)
        GameTooltip:AddLine(("%.1f, %.1f — /way clear to remove"):format(target.x * 100, target.y * 100))
        GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p:Hide()
    return p
end

local function Delta(target)
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local map = C_Map.GetBestMapForUnit("player")
    if not map or secret(map) then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local px, py = pos:GetXY()
    if not Number(px) or not Number(py) or (px == 0 and py == 0) then return end
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local a, player = C_Map.GetWorldPosFromMapPos(map, pos)
        local b, destination = C_Map.GetWorldPosFromMapPos(target.map, CreateVector2D(target.x, target.y))
        if a and b and not secret(a) and not secret(b) and a == b and player and destination then
            -- World X increases north; world Y increases west.
            local nx, wy = player:GetXY()
            local tx, ty = destination:GetXY()
            if Number(nx) and Number(wy) and Number(tx) and Number(ty) then return wy - ty, tx - nx end
        end
    end
    if map ~= target.map then return end
    if not C_Map.GetMapWorldSize then return end
    local width, height = C_Map.GetMapWorldSize(map)
    if Number(width) and Number(height) and width > 0 and height > 0 then
        return (target.x - px) * width, (py - target.y) * height
    end
end

function W:Update()
    local target = self.db.target
    -- The world map sits above the compass's usual layer, so lift the compass while the map is open.
    if self.arrow and self.arrow.SetFrameStrata then
        local open = WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()
        local strata = open and "FULLSCREEN_DIALOG" or "HIGH"
        if self.strata ~= strata then self.strata = strata self.arrow:SetFrameStrata(strata) end
    end
    if self.mini then self.mini:Hide() end
    if self.world then self.world:Hide() end
    if not target then
        self.arrow:SetShown(not T.db.locked)
        if not T.db.locked then
            self.arrow.tex:Show()
            self.arrow.tex:SetRotation(0)
            self.arrow.label:SetText("Waypoint compass")
            self.arrow.distance:SetText("Preview")
            self.arrow:Show()
        end
        return
    end
    local mapFrame = WorldMapFrame
    if mapFrame and mapFrame:IsShown() and mapFrame.GetCanvas and mapFrame.GetMapID then
        local map = mapFrame:GetMapID()
        local x, y = target.x, target.y
        if map ~= target.map then
            x, y = nil, nil
            if C_Map.GetMapRectOnMap then
                local left, right, top, bottom = C_Map.GetMapRectOnMap(target.map, map)
                if Number(left) and Number(right) and Number(top) and Number(bottom) then
                    x, y = left + target.x * (right - left), top + target.y * (bottom - top)
                end
            end
        end
        if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            local canvas = mapFrame:GetCanvas()
            self.world = self.world or Pin(canvas)
            self.world:ClearAllPoints()
            self.world:SetPoint("CENTER", canvas, "TOPLEFT", x * canvas:GetWidth(), -y * canvas:GetHeight())
            self.world:Show()
        end
    end
    local ok, dx, dy = pcall(Delta, target)
    if not ok then dx, dy = nil, nil end
    self.arrow:Show()
    self.arrow.label:SetText(target.label)
    local facing = GetPlayerFacing and GetPlayerFacing()
    self:UpdateCompass(Number(facing) and facing or nil)
    if dx then
        local angle, distance = W.Bearing(dx, dy, Number(facing) and facing or 0)
        self.arrow.tex:SetRotation(angle)
        self.arrow.marker:SetShown(Number(facing) and not self:Style().compact)
        self.arrow.marker:ClearAllPoints()
        self.arrow.marker:SetPoint("TOP", self.arrow, "TOP", W.CompassOffset(-angle, not self:Style().curve), -27)
        self.arrow.tex:SetShown(Number(facing) and distance > 10)
        self.arrow.distance:SetText(distance <= 10 and "Arrived" or ("%d yd"):format(distance + 0.5))
        if Minimap and Minimap:IsVisible() then
            self.mini = self.mini or Pin(Minimap)
            local radius = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
            if not Number(radius) or radius <= 0 then
                local diameters = IsIndoors and IsIndoors() and {300,240,180,120,80,50} or {466.67,400,333.33,266.67,200,133.33}
                radius = (diameters[(Minimap:GetZoom() or 0) + 1] or 400) / 2
            end
            local rotation = GetCVar and GetCVar("rotateMinimap") == "1" and Number(facing) and facing or nil
            local x, y = W.Project(dx, dy, radius, math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2 - 12, rotation)
            self.mini:ClearAllPoints()
            self.mini:SetPoint("CENTER", Minimap, "CENTER", x, y)
            self.mini:Show()
        end
    else
        self.arrow.tex:Hide()
        self.arrow.marker:Hide()
        self.arrow.distance:SetText("-- yd")
    end

end

T:NewModule("waypoints", {
    label = "Waypoints", desc = "/way x y [label]: a direction arrow, distance and pins on both maps. /way clear removes the destination.",
    defaults = { point = { "TOP", "UIParent", "TOP", 0, -18 }, style = "DRUM", mapClick = true },
    OnEnable = function()
        W.db = T.db.waypoints
        local f = CreateFrame("Frame", "TempusWaypointArrow", UIParent)
        W.arrow = f
        -- Migrate the old floating arrow once; subsequent compass positions remain movable.
        if not W.db.compassLayout then
            W.db.point = { "TOP", "UIParent", "TOP", 0, -18 }
            W.db.compassLayout = true
        end
        f:SetSize(230, 56)
        f:SetFrameStrata("HIGH")
        T.Style.Backdrop(f, { fill = { 0.035, 0.045, 0.055, 0.96 } })
        f.drumParts = {}
        local function Part(tex) f.drumParts[#f.drumParts + 1] = tex return tex end
        local tape = f:CreateTexture(nil, "ARTWORK", nil, -2)
        f.tape = tape
        tape:SetColorTexture(1, 1, 1, 1)
        tape:SetSize(184, 31)
        tape:SetPoint("TOP", 0, -3)
        -- Broad shading leaves a bright centre and darkens the curved drum's sides.
        for _, side in ipairs({ "LEFT", "RIGHT" }) do
            local shade = Part(f:CreateTexture(nil, "ARTWORK", nil, -1))
            shade:SetTexture("Interface\\Buttons\\WHITE8X8")
            shade:SetSize(80, 31)
            shade:SetPoint("TOP" .. side, side == "LEFT" and 23 or -23, -3)
            if side == "LEFT" then
                T.Style.SetGradient(shade, "HORIZONTAL", 0, 0, 0, 0.85, 0, 0, 0, 0)
            else
                T.Style.SetGradient(shade, "HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, 0.85)
            end
        end
        -- Brushed metal bezel, dark lower lip, and a narrow reflection on the glass.
        for _, edge in ipairs({ "TOP", "BOTTOM" }) do
            local rim = Part(f:CreateTexture(nil, "OVERLAY", nil, 2))
            rim:SetTexture("Interface\\Buttons\\WHITE8X8")
            rim:SetSize(190, 3)
            rim:SetPoint("TOP", 0, edge == "TOP" and -1 or -34)
            T.Style.SetGradient(rim, "VERTICAL", 0.12, 0.14, 0.16, 1, 0.68, 0.71, 0.74, 1)
        end
        for _, side in ipairs({ -1, 1 }) do
            local cap = Part(f:CreateTexture(nil, "OVERLAY", nil, 2))
            cap:SetTexture("Interface\\Buttons\\WHITE8X8")
            cap:SetSize(3, 32)
            cap:SetPoint("TOP", side * 94, -3)
            T.Style.SetGradient(cap, "HORIZONTAL", 0.18, 0.2, 0.23, 1, 0.5, 0.53, 0.56, 1)
        end
        local glass = Part(f:CreateTexture(nil, "OVERLAY", nil, 3))
        glass:SetTexture("Interface\\Buttons\\WHITE8X8")
        glass:SetSize(178, 9)
        glass:SetPoint("TOP", 0, -4)
        T.Style.SetGradient(glass, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.3)
        f.ticks, f.tickLines, f.tickLabels = {}, {}, {}
        local names = { [0] = "N", [18] = "E", [36] = "S", [54] = "W" }
        for i = 0, 71 do
            local tick = CreateFrame("Frame", nil, f)
            tick:SetSize(24, 25)
            local line = tick:CreateTexture(nil, "OVERLAY")
            line:SetColorTexture(0.04, 0.04, 0.04, 1)
            line:SetSize(i % 6 == 0 and 2 or 1, i % 6 == 0 and 7 or i % 2 == 0 and 5 or 3)
            line:SetPoint("TOP", 0, 0)
            f.tickLines[i] = line
            if i % 6 == 0 then
                local label = T.Style.Text(tick, names[i] and 10 or 8, { 0.02, 0.02, 0.02 }, "")
                label:SetPoint("TOP", 0, -9)
                label:SetText(names[i] or tostring(i * 5))
                f.tickLabels[i] = label
            end
            f.ticks[i] = tick
        end
        -- Fixed red lubber line, with a triangular pointer above the moving dial.
        local center = f:CreateTexture(nil, "OVERLAY", nil, 5)
        center:SetTexture("Interface\\Minimap\\MinimapArrow")
        center:SetVertexColor(0.9, 0.08, 0.05, 1)
        center:SetSize(13, 13)
        center:SetRotation(math.pi)
        center:SetPoint("TOP", 0, 2)
        f.pointer = center
        local needle = f:CreateTexture(nil, "OVERLAY", nil, 4)
        needle:SetColorTexture(0.85, 0.06, 0.04, 0.85)
        needle:SetSize(1, 21)
        needle:SetPoint("TOP", 0, -9)
        f.needle = needle
        f.marker = f:CreateTexture(nil, "OVERLAY", nil, 5)
        f.marker:SetColorTexture(1, 0.66, 0.05, 1)
        f.marker:SetSize(6, 6)
        f.marker:SetRotation(math.pi / 4)
        f.marker:Hide()
        f.tex = f:CreateTexture(nil, "ARTWORK")
        f.tex:SetTexture("Interface\\Minimap\\MinimapArrow")
        f.tex:SetSize(14, 14)
        f.tex:SetPoint("BOTTOMLEFT", 8, 5)
        f.label = T.Style.Text(f, 10, T.Style.C.text, "OUTLINE")
        f.label:SetPoint("BOTTOMLEFT", 26, 5)
        f.label:SetWidth(104)
        f.label:SetWordWrap(false)
        f.distance = T.Style.Text(f, 10, T.Style.C.text, "OUTLINE")
        f.distance:SetPoint("BOTTOMRIGHT", -23, 5)
        local close = CreateFrame("Button", nil, f)
        close:SetSize(18, 18)
        close:SetPoint("BOTTOMRIGHT", -1, 0)
        close:SetFrameLevel(f:GetFrameLevel() + 5)
        close:EnableMouse(true)
        close:RegisterForClicks("LeftButtonUp")
        close.text = T.Style.Text(close, 12, T.Style.C.text, "OUTLINE")
        close.text:SetPoint("CENTER")
        close.text:SetText("x")
        close:SetScript("OnClick", function()
            GameTooltip:Hide()
            W:Command("clear")
        end)
        f.close = close
        -- Right-click anywhere on the compass clears the waypoint, in every style.
        f:EnableMouse(true)
        f:HookScript("OnMouseUp", function(_, button)
            if button == "RightButton" then
                GameTooltip:Hide()
                W:Command("clear")
            end
        end)
        close:SetScript("OnEnter", function()
            GameTooltip:SetOwner(close, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Clear waypoint")
            GameTooltip:Show()
        end)
        close:SetScript("OnLeave", function() GameTooltip:Hide() end)
        T.Movers.ApplyPoint(f, W.db)
        T.Movers:Register(f, { label = "Waypoint compass", cfg = function() return W.db end,
            enabled = function() return true end, corner = function() return W.db.point[1] end })
        f:Hide()
        W:ApplyStyle()
        SlashCmdList.TEMPUSWAY = function(text) W:Command(text) end
        SLASH_TEMPUSWAY1 = "/tway"
        local occupied = false
        for key, value in pairs(_G) do
            if type(key) == "string" and key:match("^SLASH_") and type(value) == "string" and value:lower() == "/way" then occupied = true break end
        end
        if not occupied then SLASH_TEMPUSWAY2 = "/way"
        else T:Print("/way belongs to another addon; use /tway for Tempus waypoints.") end
        do
            local readable, map, x, y = MapPin()
            W.lastPin = readable and map and (map .. ":" .. x .. ":" .. y)
        end
        local pins = CreateFrame("Frame")
        pins:RegisterEvent("USER_WAYPOINT_UPDATED")
        pins:SetScript("OnEvent", T:Wrap("waypoints.mappin", function() W:FromMapPin() end))
        local driver = CreateFrame("Frame")
        local accumulated = 0
        driver:SetScript("OnUpdate", T:Wrap("waypoints.update", function(_, elapsed)
            accumulated = accumulated + elapsed
            if accumulated < 0.1 then return end
            accumulated = 0
            W:Update()
            W:UpdateMapHint()
            -- Guarded so a failure here can never repeat ten times a second.
            pcall(W.FromMapPin, W)
        end))
    end,
    OnSettings = function()
        W.db = T.db.waypoints
        if W.arrow then T.Movers.ApplyPoint(W.arrow, W.db) W:ApplyStyle() end
    end,
})
