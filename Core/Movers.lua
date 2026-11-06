-- Tempus UI: draggable boxes for every movable element, shown while the UI is unlocked.
-- Positions are stored as { corner, "UIParent", corner, x, y } in the element's config,
-- anchored at the corner the element grows away from so it never jumps when resized.
local _, T = ...
local S = T.Style

local M = { list = {} }
T.Movers = M

-- A single positioning panel also provides access to overlapping movers.
local panel, selected
local function Select(m)
    selected = m
    if panel then
        panel.name:SetText(m and m.opts.label or "No movable frames")
        local blocked = m and m.opts.secure and InCombatLockdown()
        panel.hint:SetText(blocked and "Protected frame: leave combat to move" or "Click: 1 unit  |  Shift-click: 10")
        for _, b in ipairs(panel.arrows) do b:SetEnabled(m ~= nil and not blocked) end
    end
    for _, item in ipairs(M.list) do
        item.selection:SetShown(item == m and item:IsShown())
    end
end
local function Panel()
    if panel then return panel end
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(300, 190)
    panel:SetPoint("TOP", UIParent, "TOP", 0, -80)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    local bg = S.Tex(panel, "BACKGROUND", {0.04, 0.05, 0.07, 0.97})
    bg:SetAllPoints()
    local border = S.CreateBorder(panel, "BORDER")
    border:SetThickness(1, panel)
    border:SetColor(T.accent[1], T.accent[2], T.accent[3], 1)
    panel.name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.name:SetPoint("TOP", 0, -12)
    panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.hint:SetPoint("BOTTOM", 0, 12)
    local chooser = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
    chooser:SetPoint("TOP", 0, -30)
    UIDropDownMenu_SetWidth(chooser, 240)
    UIDropDownMenu_SetText(chooser, "Select frame")
    UIDropDownMenu_Initialize(chooser, function()
        for _, item in ipairs(M.list) do
            if item:IsShown() then
                local target = item
                local info = UIDropDownMenu_CreateInfo()
                info.text, info.checked = target.opts.label, target == selected
                info.func = function() Select(target); UIDropDownMenu_SetText(chooser, target.opts.label) end
                UIDropDownMenu_AddButton(info)
            end
        end
    end)
    panel.arrows = {}
    local directions = {{"^", 0, 1, 0, -72}, {"<", -1, 0, -62, -106}, {"v", 0, -1, 0, -106}, {">", 1, 0, 62, -106}}
    for _, d in ipairs(directions) do
        local dx, dy = d[2], d[3]
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(58, 30)
        b:SetPoint("TOP", d[4], d[5])
        b:SetText(d[1])
        b:SetScript("OnClick", function()
            local m = selected
            if not m or not m:IsShown() or m.moving or (m.opts.secure and InCombatLockdown()) then return end
            local cfg = m.opts.cfg()
            local corner = m.opts.corner and m.opts.corner() or (cfg.point and cfg.point[1]) or "CENTER"
            M.SavePoint(m.target, cfg, corner)
            local step = IsShiftKeyDown() and 10 or 1
            cfg.point[4], cfg.point[5] = cfg.point[4] + dx * step, cfg.point[5] + dy * step
            M.ApplyPoint(m.target, cfg, corner)
            M.SavePoint(m.target, cfg, corner)
            if m.opts.onMoved then m.opts.onMoved() end
        end)
        panel.arrows[#panel.arrows + 1] = b
    end
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function() Select(selected) end)
    return panel
end

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
    local bg = S.Accent(S.Tex(m, "BACKGROUND"), 0.16)
    bg:SetAllPoints()
    local border = S.CreateBorder(m, "BORDER")
    border:SetThickness(1, m)
    local label = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOM", m, "TOP", 0, 4)
    S.OnAccent(function()
        border:SetColor(ac[1], ac[2], ac[3], 0.9)
        label:SetTextColor(ac[1], ac[2], ac[3])
    end)
    label:SetText(opts.label)
    local handle = CreateFrame("Frame", nil, m)
    handle:SetSize(math.max(96, frame:GetWidth()), 22)
    handle:SetPoint("BOTTOM", m, "TOP", 0, 0)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    local handleBg = S.Accent(S.Tex(handle, "BACKGROUND"), 0.35)
    handleBg:SetAllPoints()
    label:SetParent(handle)
    label:ClearAllPoints()
    label:SetPoint("CENTER", handle)
    m.selection = S.Tex(m, "OVERLAY", {1, 1, 1, 0.18})
    m.selection:SetAllPoints()
    m.selection:Hide()
    m.target = frame
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
        Select(m)
        frame:StartMoving()
        m.moving = true
    end)
    m:SetScript("OnDragStop", function()
        if not m.moving then return end
        m.moving = nil
        frame:StopMovingOrSizing()
        if opts.secure then T:RunOOC(Save) else Save() end
    end)
    m:SetScript("OnMouseDown", function() Select(m) end)
    m:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and opts.page then T.Options:Open(opts.page) end
    end)

    for _, event in ipairs({"OnDragStart", "OnDragStop", "OnMouseDown", "OnMouseUp"}) do
        handle:SetScript(event, m:GetScript(event))
    end

    -- Optional corner grip: opts.onResize(totalWidth, totalHeight) gets the box size the cursor
    -- asks for, in the frame's own units. The box is pinned at its top-left while sizing.
    if opts.onResize then
        local grip = CreateFrame("Frame", nil, m)
        grip:SetSize(14, 14)
        grip:SetPoint("BOTTOMRIGHT")
        grip:EnableMouse(true)
        grip:RegisterForDrag("LeftButton")
        local mark = S.Tex(grip, "OVERLAY", ac)
        mark:SetPoint("BOTTOMRIGHT")
        mark:SetSize(8, 8)
        grip:SetScript("OnDragStart", function(g)
            if opts.secure and InCombatLockdown() then return end
            local cfg = opts.cfg()
            M.SavePoint(frame, cfg, "TOPLEFT")
            g.sizing, g.last = true, nil
            hint:SetText("release to apply")
        end)
        grip:SetScript("OnUpdate", function(g)
            if not g.sizing then return end
            if InCombatLockdown() then return end
            local scale = frame:GetEffectiveScale()
            local x, y = GetCursorPosition()
            local left, top = frame:GetLeft(), frame:GetTop()
            if not (left and top) then return end
            local w, h = x / scale - left, top - y / scale
            local key = math.floor(w) .. "x" .. math.floor(h)
            if key == g.last then return end
            g.last = key
            opts.onResize(w, h)
        end)
        grip:SetScript("OnDragStop", function(g)
            g.sizing = nil
            hint:SetText(opts.page and "drag to move  |  right-click for settings" or "drag to move")
            if opts.onMoved then opts.onMoved() end
        end)
    end
    m:Hide()
    m.opts = opts
    self.list[#self.list + 1] = m
    return m
end

-- Hidden frame registered as a special frame: Escape hides it, which re-locks the UI.
local escProxy
local function EscProxy()
    if escProxy then return escProxy end
    escProxy = CreateFrame("Frame", "TempusUnlockProxy", UIParent)
    escProxy:SetSize(1, 1)
    escProxy:Hide()
    escProxy:SetScript("OnHide", function()
        if T.db and not T.db.locked then
            T.db.locked = true
            T:ApplySettings()
            T:Print("frames locked.")
        end
    end)
    tinsert(UISpecialFrames, "TempusUnlockProxy")
    return escProxy
end

function M:Refresh()
    local unlocked = T.db and not T.db.locked
    EscProxy():SetShown(unlocked and true or false)
    for _, m in ipairs(self.list) do
        local on = unlocked and (not m.opts.enabled or m.opts.enabled())
        m:SetShown(on and true or false)
    end
    local controls = Panel()
    controls:SetShown(unlocked and true or false)
    if not unlocked then Select(nil)
    elseif not selected or not selected:IsShown() then
        local first
        for _, m in ipairs(self.list) do if m:IsShown() then first = m; break end end
        Select(first)
    else Select(selected) end
end
