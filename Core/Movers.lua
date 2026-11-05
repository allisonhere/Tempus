-- Tempus UI: draggable boxes for every movable element, shown while the UI is unlocked.
-- Positions are stored as { corner, "UIParent", corner, x, y } in the element's config,
-- anchored at the corner the element grows away from so it never jumps when resized.
local _, T = ...
local S = T.Style

local M = { list = {}, selected = {} }
T.Movers = M

-- All snap calculations use UIParent coordinates, including scaled frames.
function M.FindSnap(box, targets, threshold)
    local dx, dy, gx, gy = 0, 0
    local bestX, bestY = threshold + 0.001, threshold + 0.001
    for _, target in ipairs(targets) do
        for _, pair in ipairs({{box[1], target[1]}, {box[1], target[2]},
            {box[2], target[1]}, {box[2], target[2]},
            {(box[1] + box[2]) / 2, (target[1] + target[2]) / 2}}) do
            local delta = pair[2] - pair[1]
            if math.abs(delta) < bestX then dx, gx, bestX = delta, pair[2], math.abs(delta) end
        end
        for _, pair in ipairs({{box[3], target[3]}, {box[3], target[4]},
            {box[4], target[3]}, {box[4], target[4]},
            {(box[3] + box[4]) / 2, (target[3] + target[4]) / 2}}) do
            local delta = pair[2] - pair[1]
            if math.abs(delta) < bestY then dy, gy, bestY = delta, pair[2], math.abs(delta) end
        end
    end
    return dx, dy, gx, gy
end
local function Bounds(frame)
    local l, r, b, t = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
    if not (l and r and b and t) then return end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return {l * scale, r * scale, b * scale, t * scale}
end
M.GetBounds = Bounds
local guides
local function HideGuides()
    if guides then guides:Hide() end
end
local function ShowGuides(x, y)
    if not x and not y then HideGuides(); return end
    if not guides then
        guides = CreateFrame("Frame", nil, UIParent)
        guides:SetAllPoints(UIParent)
        guides:SetFrameStrata("FULLSCREEN_DIALOG")
        guides:EnableMouse(false)
        guides.x = S.Accent(S.Tex(guides, "OVERLAY"), 0.85)
        guides.y = S.Accent(S.Tex(guides, "OVERLAY"), 0.85)
    end
    guides:Show()
    guides.x:SetShown(x ~= nil)
    guides.y:SetShown(y ~= nil)
    if x then
        guides.x:ClearAllPoints()
        guides.x:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)
        guides.x:SetSize(1, UIParent:GetHeight())
    end
    if y then
        guides.y:ClearAllPoints()
        guides.y:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y)
        guides.y:SetSize(UIParent:GetWidth(), 1)
    end
end

M.HideGuides, M.ShowGuides = HideGuides, ShowGuides

-- A single positioning panel also provides access to overlapping movers.
local panel, selected
function M:Selection()
    local list = {}
    for _, m in ipairs(self.list) do if self.selected[m] and m:IsShown() then list[#list + 1] = m end end
    return list
end
function M:RefreshHistory()
    if not panel or not panel.undo then return end
    panel.undo:SetEnabled(T.Layouts and T.Layouts:CanUndo() or false)
    panel.redo:SetEnabled(T.Layouts and T.Layouts:CanRedo() or false)
    local ready = self.CanGroup and self:CanGroup(1)
    for _, b in ipairs(panel.arrows) do b:SetEnabled(ready and true or false) end
    for _, b in ipairs(panel.groupButtons or {}) do b:SetEnabled(self:CanGroup(b.required) and true or false) end
end
function M:RefreshSelection()
    local members = self:Selection()
    if not self.selected[selected] then selected = members[1] end
    if panel then
        panel.name:SetText(#members > 1 and (#members .. " frames selected") or (selected and selected.opts.label or "No frames selected"))
        panel.hint:SetText(InCombatLockdown() and "Leave combat to move frames" or "Shift-click: add/remove frames\nArrows: 1 unit  |  Shift: 10  |  Alt: no snap")
    end
    for _, item in ipairs(self.list) do item.selection:SetShown(self.selected[item] and item:IsShown() or false) end
    self:RefreshHistory()
end
function M:Select(m, toggle)
    if self.activeDrag then return end
    if toggle then self.selected[m] = not self.selected[m]
    elseif not self.selected[m] then self.selected = {[m] = true} end
    if self.selected[m] then selected = m end
    self:RefreshSelection()
end
function M:ClearSelection()
    if self.activeDrag then return end
    self.selected, selected = {}, nil
    self:RefreshSelection()
end
local function Panel()
    if panel then return panel end
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(360, 366)
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
    UIDropDownMenu_SetText(chooser, "Select frames (toggle)")
    UIDropDownMenu_Initialize(chooser, function()
        for _, item in ipairs(M.list) do
            if item:IsShown() then
                local target = item
                local info = UIDropDownMenu_CreateInfo()
                info.text, info.checked = target.opts.label, M.selected[target] and true or false
                info.keepShownOnClick = true
                info.func = function() M:Select(target, true) end
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
            local step = IsShiftKeyDown() and 10 or 1
            local ok, err = M:GroupAction("move", dx * step, dy * step)
            if not ok then T:Print(err) end
        end)
        panel.arrows[#panel.arrows + 1] = b
    end
    for _, definition in ipairs({{"undo", "Undo", -48}, {"redo", "Redo", 48}}) do
        local action = definition[1]
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(88, 26)
        button:SetPoint("TOP", definition[3], -151)
        button:SetText(definition[2])
        button:SetScript("OnClick", function()
            if not T.Layouts then return end
            local ok, err
            if action == "undo" then ok, err = T.Layouts:Undo() else ok, err = T.Layouts:Redo() end
            if not ok then T:Print(err) end
            M:RefreshHistory()
        end)
        panel[action] = button
    end
    local alignment = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    alignment:SetPoint("TOP", 0, -185)
    alignment:SetText("Align to selection bounds")
    panel.groupButtons = {}
    local actions = {
        {"Left edges", "left", 2}, {"Centers X", "centerX", 2}, {"Right edges", "right", 2},
        {"Top edges", "top", 2}, {"Centers Y", "centerY", 2}, {"Bottom edges", "bottom", 2},
        {"Equal gaps X", "spaceX", 3}, {"Equal gaps Y", "spaceY", 3}, {"Center screen", "centerScreen", 1},
    }
    for i, definition in ipairs(actions) do
        local action = definition[2]
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(108, 26)
        button:SetPoint("TOP", ((i - 1) % 3 - 1) * 116, -205 - math.floor((i - 1) / 3) * 30)
        button:SetText(definition[1]); button.required = definition[3]
        button:SetScript("OnClick", function()
            local ok, err = M:GroupAction(action)
            if not ok then T:Print(err) end
        end)
        panel.groupButtons[#panel.groupButtons + 1] = button
    end
    local clear = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clear:SetSize(140, 26); clear:SetPoint("TOP", 0, -300); clear:SetText("Clear selection")
    clear:SetScript("OnClick", function() M:ClearSelection() end)
    M:RefreshHistory()
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function() M:RefreshSelection() end)
    return panel
end

-- Save frame's current position into cfg.point, anchored at `corner`.
function M.SavePoint(frame, cfg, corner, precise)
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
    cfg.point = { corner, "UIParent", corner, precise and x or math.floor(x + 0.5), precise and y or math.floor(y + 0.5) }
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
    hint:SetText(opts.page and "drag to snap  |  Alt: free move  |  right-click for settings" or "drag to snap  |  Alt: free move")
    hint:SetTextColor(0.8, 0.85, 0.9, 0.8)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    m:SetScript("OnDragStart", function()
        if not M.selected[m] then M:Select(m) end
        M:StartGroupDrag(m)
    end)
    m:SetScript("OnDragStop", function() M:FinishGroupDrag() end)
    m:SetScript("OnHide", function()
        if M.activeDrag and M.selected[m] then M:FinishGroupDrag() end
    end)
    m:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then M:Select(m, IsShiftKeyDown() or IsControlKeyDown()) end
    end)
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
            m.sizing = true
            M:RefreshHistory()
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
            if not g.sizing then return end
            g.sizing = nil
            m.sizing = nil
            M:RefreshHistory()
            hint:SetText(opts.page and "drag to snap  |  Alt: free move  |  right-click for settings" or "drag to snap  |  Alt: free move")
            if opts.onMoved then opts.onMoved() end
        end)
        grip:SetScript("OnHide", grip:GetScript("OnDragStop"))
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
    local changed = self.selectionProfile ~= T.db
    self.selectionProfile = T.db
    if not unlocked or changed then self.selected, selected = {}, nil end
    for _, m in ipairs(self.list) do if not m:IsShown() then self.selected[m] = nil end end
    if unlocked and (not self.wasUnlocked or changed) then
        for _, m in ipairs(self.list) do if m:IsShown() then self:Select(m); break end end
    end
    self.wasUnlocked = unlocked
    if not unlocked then HideGuides() end
    self:RefreshSelection()
end
