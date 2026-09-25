-- Tempus UI: the settings window. Pages come from modules via T:RegisterPage and are
-- grouped into collapsible sidebar sections.
local _, T = ...
local UI = T.UI
local S = T.Style
local C, AC = S.C, T.accent
local Tex, Text, Border, FlatButton, CloseMenu = UI.Tex, UI.Text, UI.Border, UI.FlatButton, UI.CloseMenu
local WIN_W, WIN_H, SIDE_W = UI.WIN_W, UI.WIN_H, UI.SIDE_W

local O = { pages = {} }
T.Options = O

local win, scroll, thumb, nav
local expanded = {}          -- section key -> open in the sidebar

----------------------------------------------------------------------------------------
-- Suite-level pages
----------------------------------------------------------------------------------------
T:RegisterPage("general", { key = "modules", label = "Modules", order = 1, build = function(p)
    p:Section("Modules", "Turn whole parts of the UI on or off. Changes apply after a reload.")
    for _, key in ipairs(T.moduleOrder) do
        local m = T.modules[key]
        p:Add(UI.W.Check(m.label or key, function() return T:ModuleEnabled(key) end, function(v)
            T.db.modules[key] = v and true or false
            O.needsReload = true
        end, m.desc))
    end
    p:Newline()
    p:Add(UI.W.Button("Reload UI", function() ReloadUI() end, "Applies module changes."))
    p:Section("Layout", "Unlock to see a box for every movable element. Drag to move; right-click a box to open its settings.")
    p:Add(UI.W.Check("Lock frames", function() return T.db.locked end, function(v) T.db.locked = v end))
    p:Add(UI.W.Check("Minimap button", function() return not T.db.minimap.hide end, function(v) T.db.minimap.hide = not v end))
end })

----------------------------------------------------------------------------------------
-- Page selection
----------------------------------------------------------------------------------------
local function UpdateScrollbar()
    local child = scroll:GetScrollChild()
    local range = math.max(0, child:GetHeight() - scroll:GetHeight())
    if range <= 0 then thumb:Hide() return end
    thumb:Show()
    local h = scroll:GetHeight()
    local th = math.max(30, h * h / child:GetHeight())
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 8, -(h - th) * (scroll:GetVerticalScroll() / range))
end

local function FindPage(key)
    for _, def in ipairs(T.pages) do
        if def.key == key then return def end
    end
end

function O:Select(key)
    local def = FindPage(key) or FindPage("modules")
    key = def.key
    for _, other in ipairs(T.pages) do
        local page = O.pages[other.key]
        if page then page.frame:SetShown(other.key == key) end
    end
    local page = O.pages[key]
    if not page then
        page = UI.NewPage(scroll)
        local ok, err = pcall(def.build, page)
        if not ok then T:ReportError("settings page " .. key .. ": " .. tostring(err)) end
        page:Finish()
        O.pages[key] = page
    end
    scroll:SetScrollChild(page.frame)
    page.frame:Show()
    page:Refresh()
    O.current = key
    expanded[def.section] = true
    O:LayoutNav()
    scroll:SetVerticalScroll(0)
    UpdateScrollbar()
end

function O:Refresh()
    if not win or not win:IsShown() then return end
    local page = O.pages[O.current]
    if page then page:Refresh() end
    win.lockBtn:SetActive(not T.db.locked)
    win.lockBtn.text:SetText(T.db.locked and "Unlock" or "Lock")
    if T.Display then win.testBtn:SetActive(T.Display.testMode) end
    win.profile:SetText("Profile: |cffffffff" .. T:ProfileName() .. "|r")
    win.reload:SetShown(O.needsReload and true or false)
end

----------------------------------------------------------------------------------------
-- Sidebar: section headers that expand to their pages
----------------------------------------------------------------------------------------
local function SectionPages(section)
    local list = {}
    for _, def in ipairs(T.pages) do
        if def.section == section then list[#list + 1] = def end
    end
    table.sort(list, function(a, b) return (a.order or 50) < (b.order or 50) end)
    return list
end

local function NavItem(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(26)
    b.bg = Tex(b, "BACKGROUND", { 1, 1, 1, 0 })
    b.bg:SetAllPoints()
    b.bar = Tex(b, "ARTWORK", AC)
    b.bar:SetSize(3, 16)
    b.bar:SetPoint("LEFT", 0, 0)
    b.text = Text(b, 12, C.muted)
    b.text:SetPoint("LEFT", 22, 0)
    b:SetScript("OnEnter", function(self) if not self.selected then self.bg:SetVertexColor(1, 1, 1, 0.03) end end)
    b:SetScript("OnLeave", function(self) if not self.selected then self.bg:SetVertexColor(1, 1, 1, 0) end end)
    function b:SetSelected(on)
        self.selected = on
        self.bar:SetShown(on)
        self.bg:SetVertexColor(1, 1, 1, on and 0.06 or 0)
        local c = on and C.text or C.muted
        self.text:SetTextColor(c[1], c[2], c[3])
    end
    return b
end

local function NavHeader(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(28)
    b.text = Text(b, 11, AC)
    b.text:SetPoint("LEFT", 12, 0)
    b.arrow = Text(b, 11, C.muted)
    b.arrow:SetPoint("RIGHT", -10, 0)
    b.line = Tex(b, "ARTWORK", C.line)
    b.line:SetHeight(1)
    b.line:SetPoint("BOTTOMLEFT", 8, 0)
    b.line:SetPoint("BOTTOMRIGHT", -8, 0)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(AC[1], AC[2], AC[3]) end)
    return b
end

function O:LayoutNav()
    local y = -8
    local hi, ii = 0, 0
    for _, section in ipairs(T.pageSections) do
        local pages = SectionPages(section.key)
        if #pages > 0 then
            hi = hi + 1
            local h = nav.headers[hi] or NavHeader(nav.child)
            nav.headers[hi] = h
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 8, y)
            h:SetPoint("RIGHT", nav.child, "RIGHT", -8, 0)
            h.text:SetText(section.label:upper())
            local open = expanded[section.key]
            h.arrow:SetText(open and "-" or "+")
            h:SetScript("OnClick", function()
                expanded[section.key] = not expanded[section.key]
                O:LayoutNav()
            end)
            h:Show()
            y = y - 30
            if open then
                for _, def in ipairs(pages) do
                    ii = ii + 1
                    local b = nav.items[ii] or NavItem(nav.child)
                    nav.items[ii] = b
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", 8, y)
                    b:SetPoint("RIGHT", nav.child, "RIGHT", -8, 0)
                    b.text:SetText(def.label)
                    b:SetSelected(def.key == O.current)
                    b:SetScript("OnClick", function() O:Select(def.key) end)
                    b:Show()
                    y = y - 27
                end
                y = y - 4
            end
        end
    end
    for i = hi + 1, #nav.headers do nav.headers[i]:Hide() end
    for i = ii + 1, #nav.items do nav.items[i]:Hide() end
    nav.child:SetHeight(-y + 8)
    local range = math.max(0, nav.child:GetHeight() - nav:GetHeight())
    if nav:GetVerticalScroll() > range then nav:SetVerticalScroll(range) end
end

----------------------------------------------------------------------------------------
-- Window
----------------------------------------------------------------------------------------
local function CreateWindow()
    win = CreateFrame("Frame", "TempusOptionsFrame", UIParent)
    win:SetSize(WIN_W, WIN_H)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    -- Previews started from the settings end when the settings close.
    win:SetScript("OnHide", function()
        CloseMenu()
        if T.Display and T.Display.testMode then T.Display:SetTestMode(false) end
        local GF = T.GroupFrames
        if GF and GF.showSamples then
            GF.showSamples = nil
            if GF.UpdateTestFrames then GF:UpdateTestFrames() end
        end
    end)
    tinsert(UISpecialFrames, "TempusOptionsFrame")

    local shadow = Tex(win, "BACKGROUND", { 0, 0, 0, 0.45 }, -8)
    shadow:SetPoint("TOPLEFT", -6, 6)
    shadow:SetPoint("BOTTOMRIGHT", 6, -6)
    local bg = Tex(win, "BACKGROUND", C.bg, -7)
    bg:SetAllPoints()
    Border(win, { 1, 1, 1, 0.1 })

    -- Header
    local header = CreateFrame("Frame", nil, win)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(56)
    local hbg = Tex(header, "BACKGROUND", { 1, 1, 1, 1 }, -6)
    hbg:SetAllPoints()
    S.SetGradient(hbg, "HORIZONTAL", AC[1] * 0.28, AC[2] * 0.28, AC[3] * 0.28, 0.9, 0.05, 0.055, 0.07, 0.2)
    local hline = Tex(header, "ARTWORK", { AC[1], AC[2], AC[3], 0.55 })
    hline:SetHeight(1)
    hline:SetPoint("BOTTOMLEFT")
    hline:SetPoint("BOTTOMRIGHT")
    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(34, 34)
    logo:SetPoint("LEFT", 14, 0)
    logo:SetTexture(T.LOGO)
    local title = Text(header, 20, AC, "")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, 0)
    title:SetText("Tempus UI")
    local sub = Text(header, 10, C.muted)
    sub:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 12, 1)
    sub:SetText("INTERFACE SUITE  ·  v" .. T.version)
    win.profile = Text(header, 11, C.muted)
    win.profile:SetPoint("LEFT", title, "RIGHT", 18, -1)

    local close = CreateFrame("Button", nil, header)
    close:SetSize(28, 28)
    close:SetPoint("RIGHT", -12, 0)
    local x = Text(close, 16, C.muted)
    x:SetPoint("CENTER")
    x:SetJustifyH("CENTER")
    x:SetText("x")
    close:SetScript("OnEnter", function() x:SetTextColor(1, 0.4, 0.4) end)
    close:SetScript("OnLeave", function() x:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    close:SetScript("OnClick", function() win:Hide() end)

    win.lockBtn = FlatButton(header, "Unlock", 84, 26, function()
        T.db.locked = not T.db.locked
        UI.Changed()
    end)
    win.lockBtn:SetPoint("RIGHT", close, "LEFT", -10, 0)
    win.testBtn = FlatButton(header, "Preview", 84, 26, function()
        if T.Display then T.Display:SetTestMode(not T.Display.testMode) end
        O:Refresh()
    end)
    win.testBtn:SetPoint("RIGHT", win.lockBtn, "LEFT", -8, 0)
    win.reload = FlatButton(header, "Reload to apply", 120, 26, function() ReloadUI() end)
    win.reload:SetPoint("RIGHT", win.testBtn, "LEFT", -8, 0)
    win.reload:SetActive(true)
    win.reload:Hide()

    -- Sidebar
    local side = CreateFrame("Frame", nil, win)
    side:SetPoint("TOPLEFT", 0, -56)
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(SIDE_W)
    Tex(side, "BACKGROUND", C.side, -6):SetAllPoints()
    local sline = Tex(side, "ARTWORK", C.line)
    sline:SetWidth(1)
    sline:SetPoint("TOPRIGHT")
    sline:SetPoint("BOTTOMRIGHT")
    nav = CreateFrame("ScrollFrame", nil, side)
    nav:SetPoint("TOPLEFT", 0, -2)
    nav:SetPoint("BOTTOMRIGHT", 0, 40)
    nav.child = CreateFrame("Frame", nil, nav)
    nav.child:SetSize(SIDE_W, 10)
    nav:SetScrollChild(nav.child)
    nav.headers, nav.items = {}, {}
    nav:EnableMouseWheel(true)
    nav:SetScript("OnMouseWheel", function(self, delta)
        local range = math.max(0, nav.child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
    end)
    local foot = Text(side, 10, C.muted)
    foot:SetPoint("BOTTOMLEFT", 14, 12)
    foot:SetWidth(SIDE_W - 24)
    foot:SetText("/tempus  ·  /tempus unlock")

    -- Content
    scroll = CreateFrame("ScrollFrame", nil, win)
    scroll:SetPoint("TOPLEFT", SIDE_W + 2, -60)
    scroll:SetPoint("BOTTOMRIGHT", -14, 6)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local child = self:GetScrollChild()
        local range = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 48)))
        UpdateScrollbar()
    end)
    scroll:SetScrollChild(CreateFrame("Frame"))
    thumb = Tex(win, "OVERLAY", { AC[1], AC[2], AC[3], 0.5 })
    thumb:SetWidth(3)

    win:SetScript("OnShow", function() O:Refresh() end)
    win:Hide()
end

function O:Open(key)
    if not win then CreateWindow() end
    win:Show()
    O:Select(key or O.current or "modules")
    O:Refresh()
end

function O:Toggle()
    if win and win:IsShown() then win:Hide() else O:Open() end
end

-- Entry in the game's AddOns settings list.
function O:InitBlizzardPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Tempus UI"
    local title = Text(panel, 20, AC)
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Tempus UI")
    local desc = Text(panel, 12, C.text)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetText("All settings live in Tempus UI's own window.")
    local b = FlatButton(panel, "Open Tempus UI settings", 220, 30, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        O:Open()
    end)
    b:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, "Tempus UI")
        Settings.RegisterAddOnCategory(cat)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end
