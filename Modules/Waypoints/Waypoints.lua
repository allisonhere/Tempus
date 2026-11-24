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
    T:Print(point and ("Waypoint: %s (%.1f, %.1f)."):format(point.label, point.x * 100, point.y * 100) or "Waypoint cleared.")
    self:Update()
end

local function Pin(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(22, 22)
    p:SetFrameLevel(parent:GetFrameLevel() + 10)
    local tex = p:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\AddOns\\Tempus\\media\\node-pin")
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
    local width, height = C_Map.GetMapWorldSize(map)
    if Number(width) and Number(height) and width > 0 and height > 0 then
        return (target.x - px) * width, (py - target.y) * height
    end
end

function W:Update()
    local target = self.db.target
    self.arrow:Hide()
    if self.mini then self.mini:Hide() end
    if self.world then self.world:Hide() end
    if not target then
        if not T.db.locked then
            self.arrow.tex:Show()
            self.arrow.tex:SetRotation(0)
            self.arrow.label:SetText("Waypoint arrow")
            self.arrow.distance:SetText("/way x y [label]")
            self.arrow:Show()
        end
        return
    end
    local dx, dy = Delta(target)
    self.arrow:Show()
    self.arrow.label:SetText(target.label)
    local facing = GetPlayerFacing and GetPlayerFacing()
    if dx and Number(facing) then
        local angle, distance = W.Bearing(dx, dy, facing)
        self.arrow.tex:SetRotation(angle)
        self.arrow.tex:SetShown(distance > 10)
        self.arrow.distance:SetText(distance <= 10 and "Arrived" or ("%d yd"):format(distance + 0.5))
        if Minimap and Minimap:IsVisible() then
            self.mini = self.mini or Pin(Minimap)
            local radius = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
            if not Number(radius) or radius <= 0 then
                local diameters = IsIndoors and IsIndoors() and {300,240,180,120,80,50} or {466.67,400,333.33,266.67,200,133.33}
                radius = (diameters[(Minimap:GetZoom() or 0) + 1] or 400) / 2
            end
            local rotation = GetCVar and GetCVar("rotateMinimap") == "1" and facing or nil
            local x, y = W.Project(dx, dy, radius, math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2 - 12, rotation)
            self.mini:ClearAllPoints()
            self.mini:SetPoint("CENTER", Minimap, "CENTER", x, y)
            self.mini:Show()
        end
    else
        self.arrow.tex:Hide()
        self.arrow.distance:SetText("Direction unavailable here")
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
end

T:NewModule("waypoints", {
    label = "Waypoints", desc = "/way x y [label]: a direction arrow, distance and pins on both maps. /way clear removes the destination.",
    defaults = { point = { "TOP", "UIParent", "TOP", 0, -240 } },
    OnEnable = function()
        W.db = T.db.waypoints
        local f = CreateFrame("Frame", "TempusWaypointArrow", UIParent)
        W.arrow = f
        f:SetSize(220, 86)
        f.tex = f:CreateTexture(nil, "ARTWORK")
        f.tex:SetTexture("Interface\\Minimap\\MinimapArrow")
        f.tex:SetSize(38, 38)
        f.tex:SetPoint("TOP", 0, 0)
        f.label = T.Style.Text(f, 12, T.Style.C.text, "OUTLINE")
        f.label:SetPoint("TOP", 0, -40)
        f.label:SetWidth(220)
        f.label:SetWordWrap(false)
        f.distance = T.Style.Text(f, 11, T.Style.C.text, "OUTLINE")
        f.distance:SetPoint("TOP", 0, -57)
        local close = CreateFrame("Button", nil, f)
        close:SetSize(18, 18)
        close:SetPoint("LEFT", f.tex, "RIGHT", 3, 0)
        close.text = T.Style.Text(close, 12, T.Style.C.text, "OUTLINE")
        close.text:SetPoint("CENTER")
        close.text:SetText("x")
        close:SetScript("OnClick", function() W:Command("clear") end)
        close:SetScript("OnEnter", function()
            GameTooltip:SetOwner(close, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Clear waypoint")
            GameTooltip:Show()
        end)
        close:SetScript("OnLeave", function() GameTooltip:Hide() end)
        T.Movers.ApplyPoint(f, W.db)
        T.Movers:Register(f, { label = "Waypoint arrow", cfg = function() return W.db end,
            enabled = function() return true end, corner = function() return W.db.point[1] end })
        f:Hide()
        SlashCmdList.TEMPUSWAY = function(text) W:Command(text) end
        SLASH_TEMPUSWAY1 = "/tway"
        local occupied = false
        for key, value in pairs(_G) do
            if type(key) == "string" and key:match("^SLASH_") and type(value) == "string" and value:lower() == "/way" then occupied = true break end
        end
        if not occupied then SLASH_TEMPUSWAY2 = "/way"
        else T:Print("/way belongs to another addon; use /tway for Tempus waypoints.") end
        local driver = CreateFrame("Frame")
        local accumulated = 0
        driver:SetScript("OnUpdate", T:Wrap("waypoints.update", function(_, elapsed)
            accumulated = accumulated + elapsed
            if accumulated < 0.1 then return end
            accumulated = 0
            W:Update()
        end))
    end,
    OnSettings = function()
        W.db = T.db.waypoints
        if W.arrow then T.Movers.ApplyPoint(W.arrow, W.db) end
    end,
})
