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
    win.box = box
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

    win.whisper = FlatButton(win, "Whisper", 100, 26, function() win:DoWhisper() end)
    win.whisper:SetPoint("BOTTOMRIGHT", -126, 16)
    win.whisper:Hide()
    function win:DoWhisper()
        local target = (win.name:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if target == "" then win.status:SetText("Type the name to whisper it to.") return end
        local lines = T.Market and T.Market.SplitForChat and T.Market.SplitForChat(win.edit:GetText()) or {}
        if #lines == 0 then win.status:SetText("Nothing to send.") return end
        if T.db.market then T.db.market.reportTo = (target ~= (T.Market.DefaultReportTo and T.Market.DefaultReportTo())) and target or "" end
        for i, line in ipairs(lines) do
            C_Timer.After((i - 1) * 0.5, function() pcall(SendChatMessage, line, "WHISPER", nil, target) end)
        end
        win.status:SetText(("Whispering %d lines to %s..."):format(#lines, target))
    end

    win.mail = FlatButton(win, "Mail it later", 100, 26, function() win:DoMail() end)
    win.mail:SetPoint("BOTTOMRIGHT", -236, 16)
    win.mail:Hide()
    function win:DoMail()
        local target = (win.name:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if target == "" then win.status:SetText("Type the name to mail it to.") return end
        local text = T.Market and T.Market.CompactReport and T.Market.CompactReport(T.Market.BuildFrom(win.edit:GetText())) or win.edit:GetText()
        if T.Market and T.Market.QueueReportMail and T.Market:QueueReportMail(target, text) then
            T.db.market.reportTo = (target ~= (T.Market.DefaultReportTo and T.Market.DefaultReportTo())) and target or ""
            win.status:SetText("Queued. Tempus will ask the next time you open a mailbox.")
        end
    end

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

-- The report window has three buttons on the bottom row, so its name box moves up onto its own row.
local function Layout(report)
    win:SetHeight(report and 424 or 380)
    win.box:ClearAllPoints()
    win.box:SetPoint("TOPLEFT", 16, -78)
    win.box:SetPoint("BOTTOMRIGHT", -16, report and 134 or 90)
    win.nameLabel:ClearAllPoints()
    win.nameLabel:SetPoint("BOTTOMLEFT", 16, report and 62 or 22)
    win.status:ClearAllPoints()
    win.status:SetPoint("BOTTOMLEFT", 16, report and 102 or 62)
    win.status:SetPoint("RIGHT", win, "RIGHT", -16, 0)
end

function T:ShowShare(mode)
    if not win then Create() end
    Layout(mode == "gearreport")
    win.mode = mode
    win.status:SetText("")
    win.whisper:Hide(); win.mail:Hide()
    if mode == "gearreport" then
        win.title:SetText("Gear data report")
        win.hint:SetText("Type your build on the second line, then copy this text (Ctrl+C), whisper it to someone, or queue it as mail that Tempus offers to send when you next open a mailbox (a short version, two or three mails). It holds your class, level, talent points and the stat names on your gear.")
        win.edit:SetText(T.Market and T.Market.Report and T.Market.Report() or "")
        win.nameLabel:SetText("Whisper to"); win.nameLabel:Show()
        local saved = T.db.market and T.Market and T.Market.FixReportTo and T.Market.FixReportTo(T.db.market.reportTo) or (T.db.market and T.db.market.reportTo)
        win.name:SetText((saved and saved ~= "" and saved) or (T.Market and T.Market.DefaultReportTo and T.Market.DefaultReportTo()) or ""); win.name:Show()
        win.action:Hide(); win.whisper:Show(); win.mail:Show()
        win:Show()
        win.edit:SetFocus()
        win.edit:HighlightText()
        return
    end
    win.nameLabel:SetText("New profile name")
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
