-- Tempus UI: icons for gathering nodes on the minimap. The game draws its own tracking blips and
-- tells addons neither where they are nor what they are, so Tempus keeps its own list of nodes,
-- learned when you gather (position from the cast, icon from the first thing looted), and draws
-- each as a small icon.
local _, T = ...
local issecret = issecretvalue or function() return false end

local Nodes = {}
T.Nodes = Nodes

Nodes.defaults = {
    learn = true,           -- remember nodes as you gather them
    size = 14,              -- icon size in pixels
    ore = true, herb = true,
    dim = true,             -- dim a node's pin for a while after you gathered it
    respawn = 10,           -- minutes a gathered node is assumed to stay gone
}

local GATHER_SPELLS = {     -- cast spell id -> kind. Ranks and expansions each have their own id.
    [2575] = "ore", [2576] = "ore", [3564] = "ore", [10248] = "ore", [29354] = "ore", [50310] = "ore",
    [74517] = "ore", [102161] = "ore", [158754] = "ore",
    [2366] = "herb", [2368] = "herb", [3570] = "herb", [11993] = "herb", [28695] = "herb", [50300] = "herb",
    [74519] = "herb", [110413] = "herb", [158745] = "herb",
}
local GENERIC = {
    ore = "Interface\\Icons\\Trade_Mining", herb = "Interface\\Icons\\Trade_Herbalism",
}
-- Minimap diameter in yards at zoom 0..5.
local OUTDOOR = { [0] = 466.67, 400, 333.33, 266.67, 200, 133.33 }
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }

local MERGE_YARDS = 12      -- a second node of the same kind this close is the same node
local MAX_PER_MAP = 600
local LOOT_WINDOW = 8       -- seconds after a gather cast in which the loot window still belongs to it

----------------------------------------------------------------------------------------
-- Pure helpers (also used by tests)
----------------------------------------------------------------------------------------
-- Pin offset in minimap pixels for a node dx/dy yards east/north of the player, or nil when it lies
-- outside the visible square. `facing` (radians, counter-clockwise from north, as GetPlayerFacing
-- reports it) is only given when the minimap rotates.
function Nodes.Project(dx, dy, diameter, half, facing)
    if facing then
        local s, c = math.sin(facing), math.cos(facing)
        dx, dy = dx * c + dy * s, -dx * s + dy * c
    end
    local scale = (half * 2) / diameter
    local x, y = dx * scale, dy * scale
    if math.abs(x) > half or math.abs(y) > half then return nil end
    return x, y
end

-- Add a node to a map's list unless a node of that kind is already within MERGE_YARDS.
function Nodes.Add(list, node, w, h)
    for _, n in ipairs(list) do
        if n.kind == node.kind then
            local dx, dy = (n.x - node.x) * w, (n.y - node.y) * h
            if dx * dx + dy * dy <= MERGE_YARDS * MERGE_YARDS then
                if node.icon then n.icon = node.icon end
                n.seen = node.seen or n.seen
                return false
            end
        end
    end
    if #list >= MAX_PER_MAP then table.remove(list, 1) end
    list[#list + 1] = node
    return true
end

----------------------------------------------------------------------------------------
-- Positions
----------------------------------------------------------------------------------------
local function PlayerPos()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local map = C_Map.GetBestMapForUnit("player")
    if not map or issecret(map) then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos or not pos.GetXY then return end
    local x, y = pos:GetXY()
    if not T.Num(x) or not T.Num(y) or issecret(x) or issecret(y) or (x == 0 and y == 0) then return end
    return map, x, y
end

local sizeCache = {}
local function MapSize(map)
    local s = sizeCache[map]
    if s then return s[1], s[2] end
    local w, h = 1000, 1000
    if C_Map and C_Map.GetMapWorldSize then
        local ok, mw, mh = pcall(C_Map.GetMapWorldSize, map)
        if ok and T.Num(mw) and T.Num(mh) and mw > 0 and mh > 0 then w, h = mw, mh end
    end
    sizeCache[map] = { w, h }
    return w, h
end

----------------------------------------------------------------------------------------
-- Learning
----------------------------------------------------------------------------------------
local pending

local function Store()
    TempusDB.nodes = TempusDB.nodes or {}
    return TempusDB.nodes
end

local function Commit(icon)
    local p = pending
    pending = nil
    if not p then return end
    local list = Store()[p.map] or {}
    Store()[p.map] = list
    local w, h = MapSize(p.map)
    Nodes.Add(list, { x = p.x, y = p.y, kind = p.kind, icon = icon, seen = time() }, w, h)
    Nodes.dirty = true
end

local function OnCast(_, unit, _, castGUID, spellID)
    if unit ~= "player" or not (Nodes.db and Nodes.db.learn) then return end
    if issecret(spellID) then return end
    local kind = GATHER_SPELLS[spellID]
    if not kind then return end
    local map, x, y = PlayerPos()
    if not map then return end
    pending = { map = map, x = x, y = y, kind = kind, at = GetTime(), guid = castGUID }
    -- The cast has to finish before the node counts. Whatever is looted first tells us what the
    -- node was; if nothing opens, keep the generic icon.
    C_Timer.After(LOOT_WINDOW, function()
        if pending and pending.ok and GetTime() - pending.at >= LOOT_WINDOW - 0.5 then Commit(nil) end
    end)
end

local function OnCastEnd(event, unit, castGUID)
    if unit ~= "player" or not pending then return end
    if not issecret(castGUID) and pending.guid and castGUID ~= pending.guid then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        pending.ok = true
        if pending.looted then Commit(pending.icon) end
    else
        pending = nil           -- interrupted, failed or cancelled: nothing was gathered
    end
end

local function FirstLootIcon()
    local get = (C_Loot and C_Loot.GetLootSlotInfo) or GetLootSlotInfo
    local count = (C_Loot and C_Loot.GetNumLootItems) or GetNumLootItems
    if not (get and count) then return end
    for i = 1, count() do
        local tex = get(i)
        if type(tex) == "table" then tex = tex.item or tex.texture or tex.icon end
        if tex and not issecret(tex) then return tex end
    end
end

local function OnLoot(event)
    if not pending or pending.looted then return end
    local icon = FirstLootIcon()
    if not icon and event == "LOOT_READY" then return end      -- try again on LOOT_OPENED
    -- Loot that opens before the cast reports success is held until it does.
    if pending.ok then Commit(icon) else pending.looted, pending.icon = true, icon end
end

function Nodes:Clear()
    TempusDB.nodes = nil
    Nodes.dirty = true
    T:Print("learned gathering nodes cleared.")
end

----------------------------------------------------------------------------------------
-- Node list for the current map
----------------------------------------------------------------------------------------
local current = { map = nil, list = {} }

local function Rebuild(map)
    local list = {}
    for _, n in ipairs(Store()[map] or {}) do
        list[#list + 1] = { x = n.x, y = n.y, kind = n.kind, icon = n.icon or GENERIC[n.kind], seen = n.seen }
    end
    current.map, current.list, Nodes.dirty = map, list, false
end

----------------------------------------------------------------------------------------
-- Pins
----------------------------------------------------------------------------------------
local pins, shown = {}, 0

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local DIM_ALPHA = 0.35
local PIN_ART = "Interface\\AddOns\\Tempus\\media\\node-pin"
-- media/node-pin.tga (made by tools/gen_node_pin.py) is a 128 px gold drop: ring and tail in one shape.
-- Its transparent hole is 64 px across with its centre 18 px above the image centre, and the tip is
-- 78 px below the hole's centre. Everything here scales from those numbers.
local ART_HOLE, ART_DROP, ART_TIP = 64, 18, 78

-- A round icon showing through the hole of the gold drop; the drop's point sits on the node's spot.
local function Pin(i)
    local pin = pins[i]
    if pin then return pin end
    pin = CreateFrame("Frame", nil, Minimap)
    pin:SetFrameLevel(Minimap:GetFrameLevel() + 4)
    pin.tex = pin:CreateTexture(nil, "ARTWORK")
    pin.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pin.tex:SetPoint("CENTER", pin, "CENTER")
    local mask = pin:CreateMaskTexture()
    mask:SetTexture(MASK)
    mask:SetAllPoints(pin.tex)
    pcall(pin.tex.AddMaskTexture, pin.tex, mask)
    pin.art = pin:CreateTexture(nil, "OVERLAY")
    pin.art:SetTexture(PIN_ART)
    pins[i] = pin
    return pin
end

-- Sizes the pin (size = the icon's width); returns how far the icon's centre sits above the tip.
local function Layout(pin, size)
    local k = size / ART_HOLE
    pin:SetSize(size, size)
    pin.tex:SetSize(size * 1.06, size * 1.06)     -- tucks under the drop's inner edge
    pin.art:SetSize(128 * k, 128 * k)
    pin.art:ClearAllPoints()
    pin.art:SetPoint("CENTER", pin, "CENTER", 0, -ART_DROP * k)
    return ART_TIP * k
end

local function Update()
    local db = Nodes.db
    if not db or not Minimap:IsVisible() then
        for i = 1, shown do pins[i]:Hide() end
        shown = 0
        return
    end
    local map, px, py = PlayerPos()
    local used = 0
    if map then
        if current.map ~= map or Nodes.dirty then Rebuild(map) end
        local w, h = MapSize(map)
        local zoom = Minimap:GetZoom() or 0
        local indoors = IsIndoors and IsIndoors()
        local diameter = (indoors and INDOOR or OUTDOOR)[zoom] or 400
        if C_Minimap and C_Minimap.GetViewRadius then
            local ok, r = pcall(C_Minimap.GetViewRadius)
            if ok and T.Num(r) and r > 0 and not issecret(r) then diameter = r * 2 end
        end
        local half = Minimap:GetWidth() / 2
        local facing
        if GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing then
            facing = GetPlayerFacing()
            if issecret(facing) then facing = nil end
        end
        local size = db.size
        local now, gone = time(), (db.respawn or 10) * 60
        for _, n in ipairs(current.list) do
            if db[n.kind] then
                local x, y = Nodes.Project((n.x - px) * w, (py - n.y) * h, diameter, half, facing)
                if x then
                    used = used + 1
                    local pin = Pin(used)
                    local stem = Layout(pin, size)
                    pin.tex:SetTexture(n.icon)
                    pin:ClearAllPoints()
                    pin:SetPoint("CENTER", Minimap, "CENTER", x, y + stem)
                    -- Nothing tells an addon whether a node is up, so a node you gathered recently is
                    -- shown dim until it has probably respawned.
                    local down = db.dim and n.seen and now - n.seen < gone
                    pin:SetAlpha(down and DIM_ALPHA or 1)
                    pin.tex:SetDesaturated(down and true or false)
                    local shade = down and 0.6 or 1
                    pin.tex:SetVertexColor(shade, shade, shade)
                    pin.art:SetVertexColor(shade, shade, shade)
                    pin:Show()
                end
            end
        end
    end
    for i = used + 1, shown do pins[i]:Hide() end
    shown = used
end

----------------------------------------------------------------------------------------
-- Module
----------------------------------------------------------------------------------------
function Nodes:Apply()
    Nodes.db = T.db.nodes
    Nodes.dirty = true
end

T:NewModule("nodes", {
    label = "Gathering nodes",
    desc = "Icons on the minimap for ore and herb nodes, learned as you gather them.",
    defaults = Nodes.defaults,
    OnEnable = function()
        Nodes:Apply()
        local f = CreateFrame("Frame")
        f:RegisterEvent("UNIT_SPELLCAST_SENT")
        f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        f:RegisterEvent("UNIT_SPELLCAST_FAILED")
        f:RegisterEvent("LOOT_READY")       -- before fast loot empties the window
        f:RegisterEvent("LOOT_OPENED")
        f:SetScript("OnEvent", T:Wrap("nodes.events", function(_, event, ...)
            if event == "LOOT_READY" or event == "LOOT_OPENED" then OnLoot(event)
            elseif event == "UNIT_SPELLCAST_SENT" then OnCast(event, ...)
            else OnCastEnd(event, ...) end
        end))
        local elapsed = 0
        f:SetScript("OnUpdate", T:Wrap("nodes.update", function(_, dt)
            elapsed = elapsed + dt
            if elapsed < 0.1 then return end
            elapsed = 0
            Update()
        end))
    end,
    OnSettings = function() Nodes:Apply() end,
})
