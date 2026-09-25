-- Tempus UI: settings widget kit. Self-contained, so every page looks the same.
local _, T = ...
local S = T.Style

local UI = {}
T.UI = UI

local WHITE, FONT = S.WHITE, S.FONT
local AC = T.accent
local C = S.C
UI.WIN_W, UI.WIN_H, UI.SIDE_W = 860, 600, 196
local CONTENT_W = UI.WIN_W - UI.SIDE_W - 14
local COL_W, COL_GAP, MARGIN = 280, 22, 22
UI.COL_W = COL_W

----------------------------------------------------------------------------------------
-- Primitives
----------------------------------------------------------------------------------------
local function Tex(parent, layer, color, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetTexture(WHITE)
    if color then t:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
    return t
end

local function Text(parent, size, color, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 12, flags or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    color = color or C.text
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH("LEFT")
    return fs
end

local function Border(frame, color)
    local b = S.CreateBorder(frame, "BORDER", 0)
    b:SetThickness(1, frame)
    color = color or C.line
    b:SetColor(color[1], color[2], color[3], color[4] or 1)
    return b
end

local function Tooltip(frame, title, body)
    if not body then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(body, C.muted[1] + 0.2, C.muted[2] + 0.2, C.muted[3] + 0.2, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Changed()
    T:ApplySettings()
end

local function FlatButton(parent, label, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 120, h or 24)
    b.bg = Tex(b, "BACKGROUND", C.card)
    b.bg:SetAllPoints()
    b.border = Border(b, { 1, 1, 1, 0.1 })
    b.text = Text(b, 11, C.text)
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.text:SetText(label)
    b:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(C.cardHi[1], C.cardHi[2], C.cardHi[3])
        self.border:SetColor(AC[1], AC[2], AC[3], 0.8)
    end)
    b:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(C.card[1], C.card[2], C.card[3])
        if not self.active then self.border:SetColor(1, 1, 1, 0.1) end
    end)
    b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)
    b:SetScript("OnClick", function(self, ...)
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        if onClick then onClick(self, ...) end
    end)
    function b:SetActive(on)
        self.active = on
        if on then
            self.border:SetColor(AC[1], AC[2], AC[3], 1)
            self.text:SetTextColor(AC[1], AC[2], AC[3])
        else
            self.border:SetColor(1, 1, 1, 0.1)
            self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end
    return b
end

local function StyledEditBox(parent, w, h)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(w, h or 24)
    e:SetAutoFocus(false)
    e:SetFont(FONT, 12, "")
    e:SetTextColor(C.text[1], C.text[2], C.text[3])
    e:SetTextInsets(8, 8, 0, 0)
    local bg = Tex(e, "BACKGROUND", { 0.03, 0.035, 0.045, 1 })
    bg:SetAllPoints()
    local border = Border(e, { 1, 1, 1, 0.12 })
    e:SetScript("OnEditFocusGained", function() border:SetColor(AC[1], AC[2], AC[3], 0.9) end)
    e:SetScript("OnEditFocusLost", function() border:SetColor(1, 1, 1, 0.12) end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

----------------------------------------------------------------------------------------
-- Dropdown menu (shared popup)
----------------------------------------------------------------------------------------
local menu, catcher

local function CloseMenu()
    if menu then menu:Hide() end
    if catcher then catcher:Hide() end
end

local function OpenMenu(owner, items, onPick, current)
    if not menu then
        catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("FULLSCREEN")
        catcher:SetScript("OnClick", CloseMenu)
        menu = CreateFrame("Frame", nil, UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu.bg = Tex(menu, "BACKGROUND", { 0.07, 0.08, 0.1, 0.98 })
        menu.bg:SetAllPoints()
        Border(menu, { AC[1], AC[2], AC[3], 0.6 })
        menu.rows = {}
    end
    local rowH = 22
    for i, item in ipairs(items) do
        local row = menu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(rowH)
            row.hl = Tex(row, "BACKGROUND", { AC[1], AC[2], AC[3], 0.18 })
            row.hl:SetAllPoints()
            row.hl:Hide()
            row.text = Text(row, 11)
            row.text:SetPoint("LEFT", 10, 0)
            row.mark = Tex(row, "ARTWORK", AC)
            row.mark:SetSize(3, rowH - 8)
            row.mark:SetPoint("LEFT", 2, 0)
            row:SetScript("OnEnter", function(self) self.hl:Show() end)
            row:SetScript("OnLeave", function(self) self.hl:Hide() end)
            menu.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1 - (i - 1) * rowH)
        row:SetPoint("RIGHT", menu, "RIGHT", -1, 0)
        row.text:SetText(item[2])
        row.mark:SetShown(item[1] == current)
        row:SetScript("OnClick", function()
            CloseMenu()
            onPick(item[1])
        end)
        row:Show()
    end
    for i = #items + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(math.max(owner:GetWidth(), 140), #items * rowH + 2)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    catcher:Show()
    menu:Show()
end

----------------------------------------------------------------------------------------
-- Widgets. Each has :Refresh() that re-reads its value.
----------------------------------------------------------------------------------------
local W = {}

function W.Check(label, get, set, tip)
    local f = CreateFrame("Button", nil, nil)
    f:SetSize(COL_W, 24)
    local box = CreateFrame("Frame", nil, f)
    box:SetSize(18, 18)
    box:SetPoint("LEFT")
    local bg = Tex(box, "BACKGROUND", { 0.03, 0.035, 0.045, 1 })
    bg:SetAllPoints()
    local border = Border(box, { 1, 1, 1, 0.18 })
    local fill = Tex(box, "ARTWORK", AC)
    fill:SetPoint("TOPLEFT", 4, -4)
    fill:SetPoint("BOTTOMRIGHT", -4, 4)
    local text = Text(f, 12)
    text:SetPoint("LEFT", box, "RIGHT", 9, 0)
    text:SetPoint("RIGHT", f, "RIGHT")
    text:SetText(label)
    f:SetScript("OnEnter", function() border:SetColor(AC[1], AC[2], AC[3], 0.9) end)
    f:SetScript("OnLeave", function() border:SetColor(1, 1, 1, 0.18) end)
    f:SetScript("OnClick", function()
        set(not get())
        PlaySound(get() and 856 or 857)
        Changed()
    end)
    function f:Refresh() fill:SetShown(get() and true or false) end
    Tooltip(f, label, tip)
    return f, 24
end

function W.Slider(label, minV, maxV, step, get, set, fmt, tip)
    local f = CreateFrame("Frame", nil, nil)
    f:SetSize(COL_W, 42)
    local text = Text(f, 12)
    text:SetPoint("TOPLEFT")
    text:SetText(label)
    local value = StyledEditBox(f, 58, 18)
    value:SetPoint("TOPRIGHT", 0, 2)
    value:SetJustifyH("RIGHT")
    value:SetFont(FONT, 11, "")
    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("TOPLEFT", 0, -26)
    s:SetPoint("TOPRIGHT", 0, -26)
    s:SetHeight(14)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local track = Tex(s, "BACKGROUND", { 0.03, 0.035, 0.045, 1 })
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    local fillT = Tex(s, "BORDER", AC)
    fillT:SetPoint("LEFT", track, "LEFT")
    fillT:SetHeight(4)
    s:SetThumbTexture(WHITE)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(10, 14)
    thumb:SetVertexColor(0.92, 0.95, 1)
    fillT:SetPoint("RIGHT", thumb, "CENTER")
    local function Show(v)
        if fmt then value:SetText(fmt(v)) else value:SetText(tostring(v)) end
    end
    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        v = tonumber(("%.3f"):format(v))
        Show(v)
        if self.updating then return end
        if v ~= get() then
            set(v)
            Changed()
        end
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(math.min(maxV, math.max(minV, self:GetValue() + delta * step)))
    end)
    value:SetScript("OnEnterPressed", function(self)
        local v = tonumber((self:GetText():gsub("[^%d%.%-]", "")))
        if v then s:SetValue(math.min(maxV, math.max(minV, v))) end
        self:ClearFocus()
    end)
    function f:Refresh()
        s.updating = true
        s:SetValue(get())
        s.updating = false
        Show(get())
    end
    Tooltip(f, label, tip)
    return f, 44
end

function W.Dropdown(label, items, get, set, tip)
    local f = CreateFrame("Frame", nil, nil)
    f:SetSize(COL_W, 48)
    local text = Text(f, 12)
    text:SetPoint("TOPLEFT")
    text:SetText(label)
    local btn = CreateFrame("Button", nil, f)
    btn:SetPoint("TOPLEFT", 0, -18)
    btn:SetPoint("TOPRIGHT", 0, -18)
    btn:SetHeight(26)
    local bg = Tex(btn, "BACKGROUND", C.card)
    bg:SetAllPoints()
    local border = Border(btn, { 1, 1, 1, 0.12 })
    local cur = Text(btn, 12)
    cur:SetPoint("LEFT", 10, 0)
    local arrow = btn:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(20, 20)
    arrow:SetPoint("RIGHT", -3, 0)
    btn:SetScript("OnEnter", function() border:SetColor(AC[1], AC[2], AC[3], 0.8) end)
    btn:SetScript("OnLeave", function() border:SetColor(1, 1, 1, 0.12) end)
    local function List() return type(items) == "function" and items() or items end
    btn:SetScript("OnClick", function(self)
        OpenMenu(self, List(), function(v) set(v); Changed() end, get())
    end)
    function f:Refresh()
        local v = get()
        if v == nil then v = "" end     -- unset matches a "" (None) item, never shows "nil"
        cur:SetText(tostring(v))
        for _, item in ipairs(List()) do
            if item[1] == v then cur:SetText(item[2]) end
        end
    end
    Tooltip(btn, label, tip)
    return f, 48
end

local function OpenColorPicker(color, onChange)
    local r, g, b = color[1], color[2], color[3]
    local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        color[1], color[2], color[3] = nr, ng, nb
        onChange()
    end
    local function cancel()
        color[1], color[2], color[3] = r, g, b
        onChange()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = apply, cancelFunc = cancel })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func = apply
        ColorPickerFrame.cancelFunc = cancel
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

function W.Color(label, get, tip)
    local f = CreateFrame("Button", nil, nil)
    f:SetSize(COL_W, 24)
    local sw = CreateFrame("Frame", nil, f)
    sw:SetSize(30, 18)
    sw:SetPoint("LEFT")
    local fill = Tex(sw, "ARTWORK")
    fill:SetAllPoints()
    local border = Border(sw, { 1, 1, 1, 0.25 })
    local text = Text(f, 12)
    text:SetPoint("LEFT", sw, "RIGHT", 9, 0)
    text:SetText(label)
    f:SetScript("OnEnter", function() border:SetColor(AC[1], AC[2], AC[3], 1) end)
    f:SetScript("OnLeave", function() border:SetColor(1, 1, 1, 0.25) end)
    f:SetScript("OnClick", function() OpenColorPicker(get(), Changed) end)
    function f:Refresh()
        local c = get()
        fill:SetVertexColor(c[1], c[2], c[3])
    end
    Tooltip(f, label, tip)
    return f, 24
end

function W.Button(label, onClick, tip, width)
    local f = CreateFrame("Frame", nil, nil)
    f:SetSize(COL_W, 28)
    local b = FlatButton(f, label, width or 150, 26, onClick)
    b:SetPoint("LEFT")
    function f:Refresh() end
    Tooltip(b, label, tip)
    f.button = b
    return f, 28
end

-- Editable name list with add box, optional "pick from active buffs", and remove buttons.
function W.List(listKey, placeholder)
    local f = CreateFrame("Frame", nil, nil)
    local width = COL_W * 2 + COL_GAP
    f:SetSize(width, 236)
    local input = StyledEditBox(f, width - 250, 26)
    input:SetPoint("TOPLEFT")
    local hint = Text(input, 11, C.muted)
    hint:SetPoint("LEFT", 9, 0)
    hint:SetText(placeholder or "Buff name or spell ID...")
    input:SetScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
    local function Add()
        T:ListAdd(listKey, input:GetText())
        input:SetText("")
        input:ClearFocus()
    end
    input:SetScript("OnEnterPressed", Add)
    local add = FlatButton(f, "Add", 70, 26, Add)
    add:SetPoint("LEFT", input, "RIGHT", 8, 0)
    local pick = FlatButton(f, "Pick active buff", 160, 26, function(self)
        local items, seen = {}, {}
        for _, e in ipairs(T.Auras:ScanFilter("HELPFUL", {})) do
            if e.nameOK and not seen[e.name] then
                seen[e.name] = true
                items[#items + 1] = { e.name, e.name }
            end
        end
        for _, e in ipairs(T.Auras:ScanFilter("HARMFUL", {})) do
            if e.nameOK and not seen[e.name] then
                seen[e.name] = true
                items[#items + 1] = { e.name, e.name .. " |cffff6060(debuff)|r" }
            end
        end
        if #items == 0 then items = { { "", "|cff888888No readable auras right now|r" } } end
        OpenMenu(self, items, function(v) if v ~= "" then T:ListAdd(listKey, v) end end)
    end)
    pick:SetPoint("LEFT", add, "RIGHT", 8, 0)

    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", 0, -34)
    box:SetPoint("BOTTOMRIGHT")
    local bg = Tex(box, "BACKGROUND", { 0.03, 0.035, 0.045, 1 })
    bg:SetAllPoints()
    Border(box, { 1, 1, 1, 0.08 })
    local empty = Text(box, 12, C.muted)
    empty:SetPoint("CENTER")
    empty:SetText("Nothing here yet.")
    local rows, offset, ROWS, ROW_H = {}, 0, 8, 24
    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, box)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", -1, 0)
        if i % 2 == 0 then Tex(row, "BACKGROUND", { 1, 1, 1, 0.025 }):SetAllPoints() end
        row.text = Text(row, 12)
        row.text:SetPoint("LEFT", 10, 0)
        row.remove = FlatButton(row, "Remove", 70, 18, function(self) T:ListRemove(listKey, self.key) end)
        row.remove:SetPoint("RIGHT", -6, 0)
        rows[i] = row
    end
    local keys = {}
    local function Render()
        local list = T.db.lists[listKey]
        wipe(keys)
        for k in pairs(list) do keys[#keys + 1] = k end
        table.sort(keys)
        offset = math.max(0, math.min(offset, #keys - ROWS))
        for i = 1, ROWS do
            local k = keys[i + offset]
            local row = rows[i]
            if k then
                row.text:SetText(list[k] .. (tonumber(k) and " |cff888888(spell ID)|r" or ""))
                row.remove.key = k
                row:Show()
            else
                row:Hide()
            end
        end
        empty:SetShown(#keys == 0)
    end
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta
        Render()
    end)
    f.Refresh = Render
    return f, 236
end

----------------------------------------------------------------------------------------
-- Page layout: a two-column flow with full-width sections.
----------------------------------------------------------------------------------------
local Page = {}
Page.__index = Page

local function NewPage(parent)
    local p = setmetatable({ widgets = {}, y = -18, col = 0, rowH = 0 }, Page)
    p.frame = CreateFrame("Frame", nil, parent)
    p.frame:SetSize(CONTENT_W - 20, 10)
    return p
end

function Page:Newline()
    if self.col > 0 then
        self.y = self.y - self.rowH - 12
        self.col, self.rowH = 0, 0
    end
end

function Page:Add(widget, height, full)
    widget:SetParent(self.frame)
    widget:ClearAllPoints()
    if full then
        self:Newline()
        widget:SetPoint("TOPLEFT", self.frame, "TOPLEFT", MARGIN, self.y)
        self.y = self.y - height - 12
    else
        widget:SetPoint("TOPLEFT", self.frame, "TOPLEFT", MARGIN + self.col * (COL_W + COL_GAP), self.y)
        self.rowH = math.max(self.rowH, height)
        self.col = self.col + 1
        if self.col == 2 then self:Newline() end
    end
    self.widgets[#self.widgets + 1] = widget
    return widget
end

function Page:Section(title, desc)
    self:Newline()
    if self.y < -20 then self.y = self.y - 10 end
    local t = Text(self.frame, 14, AC)
    t:SetPoint("TOPLEFT", MARGIN, self.y)
    t:SetText(title)
    local line = Tex(self.frame, "ARTWORK", C.line)
    line:SetHeight(1)
    line:SetPoint("LEFT", t, "RIGHT", 10, 0)
    line:SetPoint("RIGHT", self.frame, "RIGHT", -MARGIN, 0)
    self.y = self.y - 22
    if desc then
        local d = Text(self.frame, 11, C.muted)
        d:SetPoint("TOPLEFT", MARGIN, self.y)
        d:SetWidth(COL_W * 2 + COL_GAP)
        d:SetText(desc)
        d:SetSpacing(2)
        self.y = self.y - d:GetStringHeight() - 10
    end
    self.y = self.y - 4
end

function Page:Finish()
    self:Newline()
    self.frame:SetHeight(-self.y + 20)
end

function Page:Refresh()
    for _, w in ipairs(self.widgets) do
        w:Refresh()
        if w.enabledIf then
            local on = w.enabledIf()
            w:SetAlpha(on and 1 or 0.35)
        end
    end
end

-- Shorthands binding widgets to db paths.
local function DB() return T.db end
local function Getter(tbl, key) return function() return tbl()[key] end end
local function Setter(tbl, key) return function(v) tbl()[key] = v end end

function Page:Check(tbl, key, label, tip)
    return self:Add(W.Check(label, Getter(tbl, key), Setter(tbl, key), tip))
end
function Page:Slider(tbl, key, label, a, b, step, fmt, tip)
    return self:Add(W.Slider(label, a, b, step, Getter(tbl, key), Setter(tbl, key), fmt, tip))
end
function Page:Dropdown(tbl, key, label, items, tip)
    return self:Add(W.Dropdown(label, items, Getter(tbl, key), Setter(tbl, key), tip))
end
function Page:Color(tbl, key, label, tip)
    return self:Add(W.Color(label, function() return tbl()[key] end, tip))
end

local pct = function(v) return ("%d%%"):format(v * 100 + 0.5) end
local secs = function(v) return v == 0 and "off" or ("%ds"):format(v) end


UI.Tex, UI.Text, UI.Border, UI.Tooltip, UI.Changed = Tex, Text, Border, Tooltip, Changed
UI.FlatButton, UI.StyledEditBox, UI.OpenMenu, UI.CloseMenu = FlatButton, StyledEditBox, OpenMenu, CloseMenu
UI.W, UI.NewPage, UI.Page = W, NewPage, Page
UI.DB, UI.Getter, UI.Setter, UI.pct, UI.secs = DB, Getter, Setter, pct, secs
