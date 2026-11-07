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
local SPELLPOWER_URL = "https://www.curseforge.com/wow/addons/spellpower"
local SPELLPOWER_DESCRIPTION = "SpellPower adds live spell checking and lightweight grammar suggestions to your chat box. It recognizes WoW vocabulary and never sends messages for you."
local OPTIONAL_GREY = {0.45, 0.45, 0.45}
local function OptionalTooltip(owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("SpellPower (optional addon)", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(SPELLPOWER_DESCRIPTION, 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine("Install or enable SpellPower, then reload to use its settings.", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine(SPELLPOWER_URL, 0.4, 0.75, 1, true)
    GameTooltip:AddLine("Right-click for a copyable link.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end
function O:ShowSpellPowerLink()
    if GameTooltip then GameTooltip:Hide() end
    local dialog = self.spellPowerLink
    if not dialog then
        dialog = CreateFrame("Frame", "TempusSpellPowerLink", win)
        dialog:SetSize(500, 148); dialog:SetPoint("CENTER", win, "CENTER")
        dialog:SetFrameStrata("FULLSCREEN_DIALOG"); dialog:EnableMouse(true)
        local bg = Tex(dialog, "BACKGROUND", C.bg); bg:SetAllPoints(); Border(dialog)
        local title = Text(dialog, 13, C.text); title:SetPoint("TOPLEFT", 16, -12); title:SetText("SpellPower on CurseForge")
        dialog.url = UI.StyledEditBox(dialog, 468, 26); dialog.url:SetPoint("TOPLEFT", 16, -38)
        local hint = Text(dialog, 11, C.muted); hint:SetPoint("TOPLEFT", 16, -74)
        hint:SetText("Press Ctrl+C to copy, then open the link in your browser.")
        local close = FlatButton(dialog, "Close", 100, 26, function() dialog:Hide() end)
        close:SetPoint("BOTTOMRIGHT", -16, 14)
        dialog.url:SetScript("OnEscapePressed", function()
            dialog:Hide()
            win.escapePreviewConsumed = true
            win:SetPropagateKeyboardInput(false)
        end)
        dialog:SetScript("OnHide", function() dialog.url:ClearFocus() end)
        self.spellPowerLink = dialog
    end
    dialog:Show(); dialog.url:SetText(SPELLPOWER_URL); dialog.url:SetFocus(); dialog.url:HighlightText()
end

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
    p:Section("Layout", "Unlock to see a box for every movable element. Drag a labeled handle to move and snap to nearby edges or centers; hold Alt to bypass snapping. Shift-click frames or toggle them in the positioning panel to select a group. Drag or nudge them together, align edges/centers, or distribute equal gaps. Shift-click arrows moves 10 units. Right-click a box for settings.")
    p:Add(UI.W.Check("Lock frames", function() return T.db.locked end, function(v) T.db.locked = v end))
    p:Add(UI.W.Check("Minimap button", function() return not T.db.minimap.hide end, function(v) T.db.minimap.hide = not v end))
end })

-- SpellPower (chat spell checker) is a separate addon whose settings pages are built to
-- the same widget API, so they are listed in the sidebar and rendered in this window.
-- An older SpellPower without the page list gets a button that opens its own window.
local SP = _G.SpellPower
local spellPowerLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("SpellPower"))
    or (IsAddOnLoaded and IsAddOnLoaded("SpellPower")) or SP ~= nil
if SP and SP.Settings and SP.Settings.pages and SP.Settings.Mixin then
    local rank = {}
    for i, section in ipairs(SP.Settings.sections or {}) do rank[section.key] = i end
    for _, def in ipairs(SP.Settings.pages) do
        T:RegisterPage("spellpower", {
            key = "sp_" .. def.key, label = def.label,
            order = (rank[def.section] or 9) * 10 + (def.order or 0),
            build = function(p)
                SP.Settings:Mixin(p)
                def.build(p)
            end,
        })
    end
elseif spellPowerLoaded then
    T:RegisterPage("spellpower", { key = "spellpower", label = "SpellPower", order = 1, build = function(p)
        p:Section("SpellPower", "Live spell checking and grammar hints in the chat box. It has its own settings window.")
        p:Add(UI.W.Button("Open SpellPower settings", function()
            local handler = SlashCmdList and SlashCmdList["SPELLPOWER"]
            if handler then handler("") end
            if win then win:Hide() end
        end, nil, 200))
    end })
else
    -- Informational only: it appears in navigation/search but never builds a settings page.
    T:RegisterPage("spellpower", {key = "spellpower", label = "SpellPower", order = 1,
        unavailable = true, search = SPELLPOWER_DESCRIPTION .. " Optional addon CurseForge"})
end

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

function O:EnsurePage(def, indexing)
    if def.unavailable then return end
    local page = self.pages[def.key]
    if not page then
        page = UI.NewPage(scroll)
        page.frame:Hide()
        local ok, err = pcall(def.build, page)
        if not ok then page.buildError = tostring(err) end
        page:Finish()
        self.pages[def.key] = page
    end
    if page.buildError and not indexing and not page.errorReported then
        T:ReportError("settings page " .. def.key .. ": " .. page.buildError)
        page.errorReported = true
    end
    return page
end
function O:SetSearch(query)
    self.searchQuery = query or ""
    if not nav then return end
    if #T.SettingsSearch.Normalize(self.searchQuery) >= 2 and not InCombatLockdown() then
        for _, def in ipairs(T.pages) do
            local module = T.modules and T.modules[def.section]
            if not def.unavailable and not def.pinned and (not module or module.enabled) then self:EnsurePage(def, true) end
        end
    end
    self.searchResults, self.searchTotal = T.SettingsSearch.Results(T.pages, self.pages, T.pageSections, self.searchQuery)
    self.searchPicked = nil
    nav:SetVerticalScroll(0)
    self:LayoutNav()
end
function O:Select(key)
    local def = FindPage(key) or FindPage("modules")
    if not def then return end
    if def.unavailable then def = FindPage("modules") end
    if not def then return end
    key = def.key
    if self.highlight then self.highlight:Hide(); self.highlight = nil end
    for _, other in ipairs(T.pages) do
        local page = self.pages[other.key]
        if page then page.frame:SetShown(other.key == key) end
    end
    local page = self:EnsurePage(def)
    scroll:SetScrollChild(page.frame)
    page.frame:Show()
    page:Refresh()
    self.current = key
    if not def.pinned then expanded[def.section] = true end
    self:LayoutNav()
    scroll:SetVerticalScroll(0)
    UpdateScrollbar()
end
function O:OpenSearchResult(result)
    if result.unavailable then return end
    self.searchPicked = result
    self:Select(result.page)
    local page = self.pages[self.current]
    local range = math.max(0, page.frame:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0, math.min(range, -result.y - 12)))
    UpdateScrollbar()
    if result.widget then
        local widget = result.widget
        if not widget.searchHighlight then
            widget.searchHighlight = S.Accent(Tex(widget, "OVERLAY"), 0.16)
            widget.searchHighlight:SetAllPoints()
        end
        self.highlight = widget.searchHighlight
        self.highlight:Show()
        self.highlightId = (self.highlightId or 0) + 1
        local id = self.highlightId
        if C_Timer and C_Timer.After then C_Timer.After(1.5, function()
            if self.highlightId == id and self.highlight then self.highlight:Hide(); self.highlight = nil end
        end) end
    end
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

-- Escape dismisses the preview layer before the normal special-frame close binding.
-- Explicit close buttons still close settings immediately; they do not re-lock movers.
function O:DismissPreview(includeUnlocked)
    local active, apply = false, false
    if T.Layouts and T.Layouts.pending then T.Layouts:Cancel(); active = true end
    if T.Display and T.Display.testMode then T.Display:SetTestMode(false); active = true end
    if T.Swing and T.Swing.preview then T.Swing:SetPreview(false); active = true end
    if T.Ticker and T.Ticker.preview then T.Ticker:SetPreview(false); active = true end
    local GF = T.GroupFrames
    if GF and GF.showSamples then
        GF.showSamples = nil
        if GF.UpdateTestFrames then GF:UpdateTestFrames() end
        active = true
    end
    if T.db and T.db.combatpulse and T.db.combatpulse.test then
        T.db.combatpulse.test = false
        active, apply = true, true
    end
    if includeUnlocked and T.db and not T.db.locked then
        T.db.locked = true
        active, apply = true, true
    end
    if apply then T:ApplySettings() elseif active then self:Refresh() end
    return active
end

----------------------------------------------------------------------------------------
-- Sidebar: section headers that expand to their pages
----------------------------------------------------------------------------------------
local function SectionPages(section)
    local list = {}
    for _, def in ipairs(T.pages) do
        if def.section == section and not def.pinned then list[#list + 1] = def end
    end
    table.sort(list, function(a, b) return (a.order or 50) < (b.order or 50) end)
    return list
end

local function NavItem(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(26)
    b.bg = Tex(b, "BACKGROUND", { 1, 1, 1, 0 })
    b.bg:SetAllPoints()
    b.bar = S.Second(Tex(b, "ARTWORK", AC))
    b.bar:SetSize(3, 16)
    b.bar:SetPoint("LEFT", 0, 0)
    b.text = Text(b, 12, C.muted)
    b.text:SetPoint("LEFT", 22, 0)
    b.text:SetWidth(SIDE_W - 42)
    b.text:SetWordWrap(false)
    b.sub = Text(b, 9, C.muted)
    b.sub:SetPoint("BOTTOMLEFT", 22, 3)
    b.sub:SetWidth(SIDE_W - 42); b.sub:SetWordWrap(false); b.sub:Hide()
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self)
        if self.unavailable then OptionalTooltip(self)
        elseif not self.selected then self.bg:SetVertexColor(1, 1, 1, 0.03) end
    end)
    b:SetScript("OnLeave", function(self)
        if not self.selected then self.bg:SetVertexColor(1, 1, 1, 0) end
        if GameTooltip then GameTooltip:Hide() end
    end)
    function b:SetSelected(on)
        on = on and not self.unavailable
        self.selected = on
        self.bar:SetShown(on)
        self.bg:SetVertexColor(1, 1, 1, on and 0.06 or 0)
        local c = self.unavailable and OPTIONAL_GREY or (on and C.text or C.muted)
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
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self)
        if self.unavailable then OptionalTooltip(self) else self.text:SetTextColor(1, 1, 1) end
    end)
    b:SetScript("OnLeave", function(self)
        local color = self.unavailable and OPTIONAL_GREY or AC
        self.text:SetTextColor(color[1], color[2], color[3])
        if GameTooltip then GameTooltip:Hide() end
    end)
    return b
end

function O:LayoutNav()
    if not nav then return end
    nav.message:Hide()
    if self.searchQuery and self.searchQuery:match("%S") then
        local results = self.searchResults or {}
        local y = -8
        for i, result in ipairs(results) do
            local b = nav.items[i] or NavItem(nav.child)
            nav.items[i] = b
            b:ClearAllPoints(); b:SetHeight(42)
            b:SetPoint("TOPLEFT", 8, y); b:SetPoint("RIGHT", nav.child, "RIGHT", -8, 0)
            b.text:ClearAllPoints(); b.text:SetPoint("TOPLEFT", 22, -3)
            b.text:SetText(result.label)
            b.sub:SetText(result.breadcrumb); b.sub:Show()
            b.unavailable = result.unavailable
            b:SetSelected(self.searchPicked == result)
            b:SetScript("OnClick", function(_, button)
                if result.unavailable then
                    if button == "RightButton" then self:ShowSpellPowerLink() end
                elseif button ~= "RightButton" then self:OpenSearchResult(result) end
            end)
            b:Show(); y = y - 44
        end
        for _, h in ipairs(nav.headers) do h:Hide() end
        for i = #results + 1, #nav.items do nav.items[i]:Hide() end
        if #results == 0 then
            nav.message:SetText(#T.SettingsSearch.Normalize(self.searchQuery) < 2 and "Type at least 2 characters." or
                (InCombatLockdown() and "No matches. Full indexing resumes after combat." or "No matching settings."))
            nav.message:Show(); y = -80
        end
        nav.child:SetHeight(-y + 8)
        return
    end
    local y = -8
    local hi, ii = 0, 0
    -- Pinned pages (What's new) sit above every section, always visible.
    for _, def in ipairs(T.pages) do
        if def.pinned then
            ii = ii + 1
            local b = nav.items[ii] or NavItem(nav.child)
            nav.items[ii] = b
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 8, y)
            b:SetPoint("RIGHT", nav.child, "RIGHT", -8, 0)
            b:SetHeight(26); b.sub:Hide()
            b.text:ClearAllPoints(); b.text:SetPoint("LEFT", 22, 0)
            b.text:SetText(def.label)
            b.unavailable = def.unavailable
            b:SetSelected(def.key == O.current)
            if not b.selected then b.text:SetTextColor(AC[1], AC[2], AC[3]) end
            b:SetScript("OnClick", function(_, button) if button ~= "RightButton" then O:Select(def.key) end end)
            b:Show()
            y = y - 31
        end
    end
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
            local unavailable = section.key == "spellpower" and not spellPowerLoaded
            h.unavailable = unavailable
            local color = unavailable and OPTIONAL_GREY or AC
            h.text:SetTextColor(color[1], color[2], color[3])
            local open = not unavailable and expanded[section.key]
            h.arrow:SetText(unavailable and "" or (open and "-" or "+"))
            h:SetScript("OnClick", function(_, button)
                if unavailable then
                    if button == "RightButton" then O:ShowSpellPowerLink() end
                elseif button ~= "RightButton" then
                    expanded[section.key] = not expanded[section.key]
                    O:LayoutNav()
                end
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
                    b:SetHeight(26); b.sub:Hide()
                    b.text:ClearAllPoints(); b.text:SetPoint("LEFT", 22, 0)
                    b.text:SetText(def.label)
                    b.unavailable = def.unavailable
                    b:SetSelected(def.key == O.current)
                    b:SetScript("OnClick", function(_, button) if button ~= "RightButton" then O:Select(def.key) end end)
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
    S.FadeIn(win, 0.18)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:EnableKeyboard(true)
    win:SetPropagateKeyboardInput(true)
    win:SetScript("OnKeyDown", function(self, key)
        local link = O.spellPowerLink
        local linkOpen = key == "ESCAPE" and link and link:IsShown()
        if linkOpen then link:Hide() end
        local consumed = key == "ESCAPE" and (self.escapePreviewConsumed or linkOpen or O:DismissPreview(true))
        if consumed then self.escapePreviewConsumed = true end
        self:SetPropagateKeyboardInput(not consumed)
    end)
    win:SetScript("OnKeyUp", function(self, key)
        local consumed = key == "ESCAPE" and self.escapePreviewConsumed
        if key == "ESCAPE" then self.escapePreviewConsumed = nil end
        self:SetPropagateKeyboardInput(not consumed)
    end)
    -- Previews also end when settings are closed by the close button or normal Escape.
    win:SetScript("OnHide", function()
        CloseMenu()
        if O.spellPowerLink then O.spellPowerLink:Hide() end
        O:DismissPreview(false)
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
    S.OnAccent(function()
        S.SetGradient(hbg, "HORIZONTAL", AC[1] * 0.28, AC[2] * 0.28, AC[3] * 0.28, 0.9, 0.05, 0.055, 0.07, 0.2)
    end)
    local hline = S.Accent(Tex(header, "ARTWORK"), 0.55)
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
    sub:SetText("INTERFACE SUITE  ·  v" .. T.version .. "  ·  by allie")
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
    UI.Tooltip(win.testBtn, "Preview", "Escape ends previews and keeps Tempus open. Press Escape again to close settings.")
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
    win.search = UI.StyledEditBox(side, SIDE_W - 46, 26)
    win.search:SetPoint("TOPLEFT", 10, -8)
    win.search:SetMaxLetters(80)
    local searchHint = Text(win.search, 10, C.muted)
    searchHint:SetPoint("LEFT", 8, 0); searchHint:SetText("Search settings...")
    win.search:SetScript("OnTextChanged", function(self)
        searchHint:SetShown(self:GetText() == "")
        O:SetSearch(self:GetText())
    end)
    win.search:SetScript("OnEnterPressed", function(self)
        if O.searchResults and O.searchResults[1] then O:OpenSearchResult(O.searchResults[1]) end
        self:ClearFocus()
    end)
    win.search:SetScript("OnEscapePressed", function(self)
        if not O:DismissPreview(true) then self:SetText("") end
        self:ClearFocus()
        -- The same physical Escape must not also reach the window close binding.
        win.escapePreviewConsumed = true
        win:SetPropagateKeyboardInput(false)
    end)
    local clearSearch = FlatButton(side, "x", 22, 26, function() win.search:SetText(""); win.search:ClearFocus() end)
    clearSearch:SetPoint("TOPRIGHT", -8, -8)
    nav = CreateFrame("ScrollFrame", nil, side)
    nav:SetPoint("TOPLEFT", 0, -42)
    nav:SetPoint("BOTTOMRIGHT", 0, 40)
    nav.child = CreateFrame("Frame", nil, nav)
    nav.child:SetSize(SIDE_W, 10)
    nav:SetScrollChild(nav.child)
    nav.headers, nav.items = {}, {}
    nav.message = Text(nav.child, 11, C.muted)
    nav.message:SetPoint("TOPLEFT", 12, -8); nav.message:SetWidth(SIDE_W - 24); nav.message:Hide()
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
    thumb = S.Accent(Tex(win, "OVERLAY"), 0.5)
    thumb:SetWidth(3)

    win:RegisterEvent("PLAYER_REGEN_ENABLED")
    win:SetScript("OnEvent", function()
        if win:IsShown() and O.searchQuery and O.searchQuery:match("%S") then O:SetSearch(O.searchQuery) end
    end)
    win:SetScript("OnShow", function(self)
        self.escapePreviewConsumed = nil
        self:SetPropagateKeyboardInput(true)
        O:Refresh()
    end)
    win:Hide()
end

function O:Open(key)
    if not win then CreateWindow() end
    win:Show()
    if key then win.search:SetText("") end
    O:Select(key or O.current or "modules")
    -- Opened plainly (slash command, minimap button): every sidebar section starts closed.
    -- Opened to a page (a mover's right-click), that page's section stays open.
    if not key then
        wipe(expanded)
        O:LayoutNav()
    end
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
