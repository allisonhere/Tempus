-- Tempus UI: draggable boxes for every movable element, shown while the UI is unlocked.
-- Positions are stored as { corner, "UIParent", corner, x, y } in the element's config,
-- anchored at the corner the element grows away from so it never jumps when resized.
local _, T = ...
local S = T.Style

local M = { list = {} }
T.Movers = M

-- Save frame's current position into cfg.point, anchored at `corner`.
function M.SavePoint(frame, cfg, corner)
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not (left and right and top and bottom) then return end
    local s = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local W, H = UIParent:GetWidth() / s, UIParent:GetHeight() / s
    corner = corner or "CENTER"
    local x, y
    if corner == "CENTER" then
        x, y = (left + right) / 2 - W / 2, (top + bottom) / 2 - H / 2
    else
        x = corner:find("LEFT") and left or (corner:find("RIGHT") and (right - W)) or ((left + right) / 2 - W / 2)
        y = corner:find("TOP") and (top - H) or (corner:find("BOTTOM") and bottom) or ((top + bottom) / 2 - H / 2)
    end
    cfg.point = { corner, "UIParent", corner, math.floor(x + 0.5), math.floor(y + 0.5) }
    frame:ClearAllPoints()
    frame:SetPoint(corner, UIParent, corner, cfg.point[4], cfg.point[5])
end

-- Place frame from cfg.point; re-anchor to `corner` if the growth corner changed.
function M.ApplyPoint(frame, cfg, corner)
    local p = cfg.point
    if not p then return end
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    if corner and p[1] ~= corner then M.SavePoint(frame, cfg, corner) end
end

-- opts: label, page (settings page key), cfg() -> config with .point, corner() -> string,
-- enabled() -> bool, secure (frame is protected: moves only out of combat), onMoved().
function M:Register(frame, opts)
    local m = CreateFrame("Frame", nil, UIParent)
    m:SetFrameStrata("DIALOG")
    m:SetAllPoints(frame)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    local ac = T.accent
    local bg = S.Tex(m, "BACKGROUND", { ac[1], ac[2], ac[3], 0.16 })
    bg:SetAllPoints()
    local border = S.CreateBorder(m, "BORDER")
    border:SetThickness(1, m)
    border:SetColor(ac[1], ac[2], ac[3], 0.9)
    local label = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOM", m, "TOP", 0, 4)
    label:SetTextColor(ac[1], ac[2], ac[3])
    label:SetText(opts.label)
    local hint = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", m, "BOTTOM", 0, -3)
    hint:SetText(opts.page and "drag to move  |  right-click for settings" or "drag to move")
    hint:SetTextColor(0.8, 0.85, 0.9, 0.8)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local function Save()
        local cfg = opts.cfg()
        M.SavePoint(frame, cfg, opts.corner and opts.corner() or (cfg.point and cfg.point[1]) or "CENTER")
        if opts.onMoved then opts.onMoved() end
    end
    m:SetScript("OnDragStart", function()
        if opts.secure and InCombatLockdown() then return end
        frame:StartMoving()
        m.moving = true
    end)
    m:SetScript("OnDragStop", function()
        if not m.moving then return end
        m.moving = nil
        frame:StopMovingOrSizing()
        if opts.secure then T:RunOOC(Save) else Save() end
    end)
    m:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and opts.page then T.Options:Open(opts.page) end
    end)
    m:Hide()
    m.opts = opts
    self.list[#self.list + 1] = m
    return m
end

function M:Refresh()
    local unlocked = T.db and not T.db.locked
    for _, m in ipairs(self.list) do
        local on = unlocked and (not m.opts.enabled or m.opts.enabled())
        m:SetShown(on and true or false)
    end
end
