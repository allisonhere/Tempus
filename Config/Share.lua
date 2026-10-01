-- Tempus UI: the export / import window for profile strings.
local _, T = ...
local UI = T.UI
local S = T.Style
local C, AC = S.C, T.accent
local Tex, Text, Border, FlatButton, StyledEditBox = UI.Tex, UI.Text, UI.Border, UI.FlatButton, UI.StyledEditBox

local win

local function Create()
    win = CreateFrame("Frame", "TempusShareFrame", UIParent)
    win:SetSize(560, 380)
    win:SetPoint("CENTER")
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    tinsert(UISpecialFrames, "TempusShareFrame")
    Tex(win, "BACKGROUND", C.bg, -7):SetAllPoints()
    Border(win, { 1, 1, 1, 0.12 })

    win.title = Text(win, 16, AC)
    win.title:SetPoint("TOPLEFT", 16, -14)
    win.hint = Text(win, 11, C.muted)
    win.hint:SetPoint("TOPLEFT", 16, -40)
    win.hint:SetPoint("RIGHT", win, "RIGHT", -16, 0)
    win.hint:SetWordWrap(true)

    local box = CreateFrame("Frame", nil, win)
    box:SetPoint("TOPLEFT", 16, -78)
    box:SetPoint("BOTTOMRIGHT", -16, 90)
    Tex(box, "BACKGROUND", C.field or { 0.03, 0.035, 0.045, 1 }):SetAllPoints()
    Border(box, { 1, 1, 1, 0.1 })
    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    edit:SetWidth(520)
    edit:SetMaxLetters(0)
    scroll:SetScrollChild(edit)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = math.max(0, edit:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
    end)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    win.edit = edit

    win.status = Text(win, 11, C.muted)
    win.status:SetPoint("BOTTOMLEFT", 16, 62)
    win.status:SetPoint("RIGHT", win, "RIGHT", -16, 0)

    win.nameLabel = Text(win, 12)
    win.nameLabel:SetPoint("BOTTOMLEFT", 16, 22)
    win.nameLabel:SetText("New profile name")
    win.name = StyledEditBox(win, 200, 26)
    win.name:SetPoint("LEFT", win.nameLabel, "RIGHT", 10, 0)

    win.action = FlatButton(win, "Import", 100, 26, function() win:DoImport() end)
    win.action:SetPoint("BOTTOMRIGHT", -126, 16)
    win.action:SetActive(true)
    win.close = FlatButton(win, "Close", 100, 26, function() win:Hide() end)
    win.close:SetPoint("BOTTOMRIGHT", -16, 16)

    function win:DoImport()
        local ok, err = T:ImportProfile(win.name:GetText(), win.edit:GetText())
        if ok then
            win:Hide()
            T:Print("profile imported and selected. Reload to apply it everywhere.")
        else
            win.status:SetText("|cffff6060Could not import:|r " .. err)
        end
    end
end

function T:ShowShare(mode)
    if not win then Create() end
    win.mode = mode
    win.status:SetText("")
    if mode == "export" then
        win.title:SetText("Export profile")
        win.hint:SetText("Copy this text (Ctrl+C) and share it. Anyone can paste it into Import to get your settings.")
        win.edit:SetText(T:ExportProfile())
        win.nameLabel:Hide(); win.name:Hide(); win.action:Hide()
        win:Show()
        win.edit:SetFocus()
        win.edit:HighlightText()
    else
        win.title:SetText("Import profile")
        win.hint:SetText("Paste a profile string below, name the new profile, and click Import. Your current profile is not changed.")
        win.edit:SetText("")
        win.name:SetText("Imported")
        win.nameLabel:Show(); win.name:Show(); win.action:Show()
        win:Show()
        win.edit:SetFocus()
    end
end
