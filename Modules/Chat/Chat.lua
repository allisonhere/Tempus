-- Tempus UI: chat features on top of Blizzard's own chat frames: a chat log window you can select
-- and copy from, arrow keys that move the cursor in the chat box, clickable links,
-- chat history that survives a reload, timestamps, and tabs that fade until the mouse is near.
-- Blizzard still formats and delivers every line. Text is only touched when it is a plain string:
-- during a boss fight or Mythic+ run the client hands chat over as secret values, which cannot be
-- searched, changed or stored, so those lines are passed through untouched.
local _, T = ...
local S = T.Style
local issecret = issecretvalue or function() return false end

local Chat = {}
T.Chat = Chat

Chat.defaults = {
    urls = true,            -- web addresses become clickable links that open a copy box
    copyButton = true,      -- the chat log icon at the end of the tab row, and Alt+click
    history = true,         -- keep recent lines across /reload and relog
    historyLines = 150,     -- per chat window
    timestamps = "KEEP",    -- KEEP leaves the game setting alone | NONE | H24 | H12
    fadeChrome = false,     -- hide tabs and buttons until the mouse is over the chat window
    editorKeys = true,      -- plain arrow keys move the cursor in the chat box; Up/Down walk history
    shortChannels = true,   -- [2. Trade - City] becomes [T]
    classNames = true,      -- player names in their class colour (the game's own setting)
    mutedTimestamps = true, -- timestamps in grey so they do not compete with the message
}

local TIMESTAMP_FORMATS = { NONE = "none", H24 = "%H:%M:%S ", H12 = "%I:%M:%S %p " }
local HISTORY_MAX_AGE = 24 * 3600
local SKIP_FRAME = "ChatFrame2"     -- the combat log would flood the saved history

local URL_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL" }

local function Frames()
    local list = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then list[#list + 1] = cf end
    end
    return list
end

local function Plain(v) return type(v) == "string" and not issecret(v) end

----------------------------------------------------------------------------------------
-- Links
----------------------------------------------------------------------------------------
local BARE_TLDS = { com = true, net = true, org = true, io = true, gg = true, tv = true, co = true, edu = true,
    gov = true, info = true, me = true, dev = true, app = true, xyz = true, uk = true, de = true, fr = true,
    ca = true, eu = true, ru = true, nl = true, se = true, us = true }

-- Wrap web addresses in a |Hurl:| link. Existing hyperlinks are left alone.
local function LinkPlain(text)
    text = text:gsub("(https?://[^%s|]+)", function(url)
        local trail = url:match("[%.,;:!%?%)%]]+$") or ""
        local core = url:sub(1, #url - #trail)
        return ("|cff5fb0ff|Hurl:%s|h[%s]|h|r%s"):format(core, core, trail)
    end)
    text = text:gsub("(%f[%w]www%.[%w%-]+%.[^%s|]+)", function(url)
        local trail = url:match("[%.,;:!%?%)%]]+$") or ""
        local core = url:sub(1, #url - #trail)
        return ("|cff5fb0ff|Hurl:%s|h[%s]|h|r%s"):format(core, core, trail)
    end)
    return text
end

local function LinkMail(text)
    text = text:gsub("(%f[%w][%w%._%-%+]+@[%w%-]+%.[%w%.%-]*%w)", function(mail)
        return ("|cff5fb0ff|Hurl:%s|h[%s]|h|r"):format(mail, mail)
    end)
    return text
end

-- Bare domains (example.com/path). Only well-known endings, so "e.g." and "3.5" stay text.
local function LinkBare(text)
    text = text:gsub("(%f[%w][%w%-%.]*[%w]%.%a%a%a?%a?%f[^%w][^%s|]*)", function(word)
        local host = word:match("^([%w%-%.]+)")
        local tld = host:match("%.(%a+)$")
        if not tld or not BARE_TLDS[tld:lower()] then return word end
        local trail = word:match("[%.,;:!%?%)%]]+$") or ""
        local core = word:sub(1, #word - #trail)
        return ("|cff5fb0ff|Hurl:%s|h[%s]|h|r%s"):format(core, core, trail)
    end)
    return text
end

local function Segments(msg, fn)
    local out, pos = {}, 1
    while pos <= #msg do
        local s, e = msg:find("|H.-|h.-|h", pos)
        out[#out + 1] = fn(msg:sub(pos, (s or #msg + 1) - 1))
        if not s then break end
        out[#out + 1] = msg:sub(s, e)
        pos = e + 1
    end
    return table.concat(out)
end

function Chat.Linkify(msg)
    if not (msg:find(".", 1, true) or msg:find("@", 1, true)) then return msg end
    return Segments(Segments(Segments(msg, LinkPlain), LinkMail), LinkBare)
end

----------------------------------------------------------------------------------------
-- Short channel names. Only the channel label argument is changed, and only when it is a
-- plain string; Blizzard still builds the line. Party, guild and raid tags come from the
-- game's own format strings, which are left alone so chat stays clean during encounters.
----------------------------------------------------------------------------------------
local CHANNEL_SHORT = { General = "G", Trade = "T", LocalDefense = "LD", WorldDefense = "WD",
    LookingForGroup = "LFG", GuildRecruitment = "GR", Services = "S", Hardcore = "HC", Newcomers = "N" }

function Chat.ShortChannel(label)
    if not Plain(label) then return label end
    local num, name = label:match("^(%d+)%.%s*(.+)$")
    if not num then return label end
    local base = name:match("^([%w]+)")
    return (base and CHANNEL_SHORT[base]) or num
end

local function ChannelFilter(_, _, msg, a2, a3, a4, ...)
    if not (Chat.db and Chat.db.shortChannels) or not Plain(a4) then return false end
    local short = Chat.ShortChannel(a4)
    if short == a4 then return false end
    return false, msg, a2, a3, short, ...
end

local function UrlFilter(_, _, msg, ...)
    if not (Chat.db and Chat.db.urls) or not Plain(msg) then return false end
    local ok, linked = pcall(Chat.Linkify, msg)
    if ok and linked ~= msg then return false, linked, ... end
    return false
end

----------------------------------------------------------------------------------------
-- Chat log window
--
-- One window for reading and copying chat, opened from the icon at the end of the tab row,
-- by Alt+clicking a chat window, or with /tempus copychat. The lines sit in a multi-line
-- EditBox, so you can drag or Shift+arrow a selection and Ctrl+C it, or Ctrl+A for the lot.
-- Colours are off by default, so what you paste outside the game is plain text; the Colours
-- button shows the same lines the way chat draws them. Lines that arrive while the window is
-- open are counted instead of added, so they cannot move the text under a selection.
--
-- The box is deliberately left unnamed: spell checkers that hook chat input by name
-- (SpellPower) cannot reach a box that has no name at all.
----------------------------------------------------------------------------------------
local win
local Render

-- Read-only: anything the user types or pastes is put back. Selecting and Ctrl+C never
-- change the text, so they work as normal.
function Chat.GuardText(box, user)
    if user and box.tempusText and box:GetText() ~= box.tempusText then
        box:SetText(box.tempusText)
    end
end

-- Keep the cursor in sight while it moves with the keyboard.
local function FollowCursor(scroll, y, h)
    local top = -y
    local cur = scroll:GetVerticalScroll()
    local height = scroll:GetHeight()
    if top < cur then
        scroll:SetVerticalScroll(top)
    elseif top + h > cur + height then
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScrollRange(), top + h - height))
    end
end

local LOG_HINT = "Drag or Shift+arrows to select, Ctrl+A then Ctrl+C copies the lot. Esc closes."
local TEXT_HINT = "Click in the text and press Ctrl+A, then Ctrl+C. Esc closes this window."
local MIN_W, MIN_H = 420, 240

local function FitEdit()
    if win then win.edit:SetWidth(math.max(120, (win:GetWidth() or MIN_W) - 44)) end
end

local function BuildWindow()
    local UI = T.UI
    local C, AC = S.C, T.accent
    win = CreateFrame("Frame", "TempusChatCopyFrame", UIParent)
    win:SetSize(620, 400)
    win:SetPoint("CENTER")
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetResizable(true)
    if win.SetResizeBounds then pcall(win.SetResizeBounds, win, MIN_W, MIN_H)
    elseif win.SetMinResize then pcall(win.SetMinResize, win, MIN_W, MIN_H) end
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); FitEdit() end)
    win:SetScript("OnSizeChanged", FitEdit)
    tinsert(UISpecialFrames, "TempusChatCopyFrame")
    UI.Tex(win, "BACKGROUND", C.bg, -7):SetAllPoints()
    UI.Border(win, { 1, 1, 1, 0.12 })

    win.title = UI.Text(win, 16, AC)
    win.title:SetPoint("TOPLEFT", 16, -14)

    win.colorBtn = UI.FlatButton(win, "Colours", 78, 22, function(self)
        win.colors = not win.colors
        self:SetActive(win.colors and true or false)
        Render()
    end)
    win.colorBtn:SetPoint("TOPRIGHT", -16, -12)
    UI.Tooltip(win.colorBtn, "Colours", "Shows the lines the way chat draws them. Off means plain text, so what you paste outside the game has no colour codes in it.")

    win.update = UI.FlatButton(win, "Update", 78, 22, function() Render() end)
    win.update:SetPoint("RIGHT", win.colorBtn, "LEFT", -6, 0)
    win.update:Hide()
    UI.Tooltip(win.update, "Update", "New lines have arrived since this window opened. Adding them clears any selection you have made.")

    win.hint = UI.Text(win, 11, C.muted)
    win.hint:SetPoint("TOPLEFT", 16, -40)
    win.hint:SetPoint("RIGHT", win, "RIGHT", -16, 0)
    win.hint:SetJustifyH("LEFT")
    win.hint:SetText(LOG_HINT)

    local box = CreateFrame("Frame", nil, win)
    box:SetPoint("TOPLEFT", 16, -64)
    box:SetPoint("BOTTOMRIGHT", -16, 58)
    UI.Tex(box, "BACKGROUND", C.field or { 0.03, 0.035, 0.045, 1 }):SetAllPoints()
    UI.Border(box, { 1, 1, 1, 0.1 })
    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    edit:SetWidth(580)
    edit:SetMaxLetters(0)
    scroll:SetScrollChild(edit)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = math.max(0, edit:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
    end)
    edit:SetScript("OnTextChanged", function(self, user) Chat.GuardText(self, user) end)
    edit:SetScript("OnCursorChanged", function(_, _, y, _, h) FollowCursor(scroll, y, h) end)
    edit:SetScript("OnEscapePressed", function() win:Hide() end)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    win.edit, win.scroll = edit, scroll

    win.close = UI.FlatButton(win, "Close", 100, 26, function() win:Hide() end)
    win.close:SetPoint("BOTTOMRIGHT", -22, 20)

    -- Three stepped bars in the corner: drag to resize, since this window stands in for a
    -- view that used to match the chat window's own size.
    local grip = CreateFrame("Button", nil, win)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    local bars = {}
    for i = 1, 3 do
        local t = grip:CreateTexture(nil, "OVERLAY")
        t:SetTexture(S.WHITE)
        t:SetSize(i * 4, 1)
        t:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", 0, (i - 1) * 4)
        t:SetVertexColor(0.5, 0.55, 0.62, 1)
        bars[#bars + 1] = t
    end
    grip:SetScript("OnEnter", function()
        local ac = T.accent
        for _, t in ipairs(bars) do t:SetVertexColor(ac[1], ac[2], ac[3], 1) end
    end)
    grip:SetScript("OnLeave", function()
        for _, t in ipairs(bars) do t:SetVertexColor(0.5, 0.55, 0.62, 1) end
    end)
    grip:SetScript("OnMouseDown", function() win:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() win:StopMovingOrSizing(); FitEdit() end)
end

-- A plain block of text in the same window: used for a clicked web link, which is not a
-- chat log, so the log's own buttons stay out of the way.
function Chat:ShowText(title, text)
    if not win then BuildWindow() end
    win.cf, win.pending = nil, 0
    win.title:SetText(title)
    win.hint:SetText(TEXT_HINT)
    win.colorBtn:Hide()
    win.update:Hide()
    win.edit.tempusText = text or ""
    win.edit:SetText(text or "")
    win.scroll:SetVerticalScroll(0)
    win:Show()
    FitEdit()
    win.edit:SetFocus()
    win.edit:HighlightText()
end

-- Battle.net names arrive as protected |K...|k codes, and the game refuses to put any text
-- holding one into an edit box: the whole text comes out empty. Swap each for the friend's
-- BattleTag name (looked up from the account id in the player link), or "friend".
local function BattleTagName(id)
    id = tonumber(id)
    if not (id and C_BattleNet and C_BattleNet.GetAccountInfoByID) then return nil end
    local ok, info = pcall(C_BattleNet.GetAccountInfoByID, id)
    local tag = ok and type(info) == "table" and info.battleTag
    if Plain(tag) and tag ~= "" then return (tag:gsub("#%d+$", "")) end
end

function Chat.StripProtected(line, lookup)
    lookup = lookup or BattleTagName
    line = line:gsub("(|HBNplayer:(.-)|h)(.-)(|h)", function(open, data, text, close)
        local name = lookup(data:match("^[^:]*:(%d+)")) or "friend"
        return open .. text:gsub("|K.-|k", function() return name end) .. close
    end)
    return (line:gsub("|K.-|k", "friend"))
end

-- Strip colours, textures and link wrappers so the pasted text reads as plain chat.
local function Clean(line)
    line = Chat.StripProtected(line)
    line = line:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    line = line:gsub("|H.-|h(.-)|h", "%1")
    line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return line
end

-- Same, but colours stay: the window is an EditBox, which draws |c...|r itself. Link
-- wrappers go (an EditBox cannot click them) and the link text stays, coloured.
function Chat.CleanKeepColor(line)
    line = Chat.StripProtected(line)
    line = line:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    line = line:gsub("|H.-|h(.-)|h", "%1")
    return line
end

-- The readable lines of a chat window, plus how many the game kept secret.
function Chat.Lines(cf, clean)
    clean = clean or Clean
    local lines, hidden = {}, 0
    for i = 1, (cf:GetNumMessages() or 0) do
        local ok, msg = pcall(cf.GetMessageInfo, cf, i)
        if ok and msg then
            if Plain(msg) then
                lines[#lines + 1] = clean(msg)
            else
                hidden = hidden + 1
            end
        end
    end
    return lines, hidden
end

local function HiddenNote(hidden)
    if hidden <= 0 then return "" end
    return ("\n\n(%d line%s hidden by the game during a boss fight or Mythic+ run)"):format(hidden, hidden == 1 and "" or "s")
end

-- Fill the window from the chat frame it was opened on. Called again by Colours and Update.
function Render()
    if not (win and win.cf) then return end
    local lines, hidden = Chat.Lines(win.cf, win.colors and Chat.CleanKeepColor or Clean)
    local text = table.concat(lines, "\n") .. HiddenNote(hidden)
    if text == "" then text = "(No lines in this window that can be shown.)" end
    win.count, win.pending = #lines, 0
    win.update:Hide()
    win.hint:SetText(LOG_HINT)
    win.edit.tempusText = text
    win.edit:SetText(text)
    win.edit:SetFocus()
    win.edit:HighlightText()
    -- The box only knows its full height after layout; then jump to the newest line.
    local function Bottom()
        if win:IsShown() then win.scroll:SetVerticalScroll(win.scroll:GetVerticalScrollRange()) end
    end
    C_Timer.After(0, Bottom)
    C_Timer.After(0.1, Bottom)
end

function Chat:ShowLog(cf)
    cf = cf or SELECTED_CHAT_FRAME or ChatFrame1
    if not cf then return end
    if not win then BuildWindow() end
    win.cf = cf
    win.colors = win.colors or false
    win.title:SetText("Chat window " .. ((cf:GetName() or ""):gsub("ChatFrame", "")))
    win.colorBtn:Show()
    win.colorBtn:SetActive(win.colors)
    win:Show()
    FitEdit()
    Render()
end

function Chat:ToggleLog(cf)
    if win and win:IsShown() then win:Hide() else self:ShowLog(cf) end
end

function Chat:LogShown() return win and win:IsShown() or false end

-- Older names, kept so /tempus copychat, /tempus selectchat and anything else holding on
-- to them still open the one window.
Chat.Copy = Chat.ShowLog
Chat.ToggleSelect = Chat.ToggleLog

local function OnLink(link)
    local url = type(link) == "string" and not issecret(link) and link:match("^url:(.+)$")
    if url then Chat:ShowText("Link", url) end
end

-- New lines while the window is open are counted, not added: adding would drop the
-- selection you are making. Update reloads the window with them.
local function NoteNewLine(cf, text)
    if not (win and win:IsShown() and win.cf == cf) or not Plain(text) then return end
    win.pending = (win.pending or 0) + 1
    win.hint:SetText(("%d new line%s since this window opened - Update adds them."):format(win.pending, win.pending == 1 and "" or "s"))
    win.update:Show()
end

function Chat:HookChatLog()
    for _, cf in ipairs(Frames()) do
        if not cf.tempusChatLog then
            cf.tempusChatLog = true
            cf:HookScript("OnMouseDown", function(self, button)
                if button == "LeftButton" and Chat.db and Chat.db.copyButton and IsAltKeyDown and IsAltKeyDown() then
                    pcall(Chat.ShowLog, Chat, self)
                end
            end)
            hooksecurefunc(cf, "AddMessage", function(self, text) pcall(NoteNewLine, self, text) end)
        end
    end
end

----------------------------------------------------------------------------------------
-- Typing: arrow keys move the cursor without Alt. Only the game's own switch is flipped;
-- the chat box keeps Blizzard's handlers, so sending and SpellPower's hooks are untouched.
----------------------------------------------------------------------------------------
local function EditBoxes()
    local list = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then list[#list + 1] = eb end
    end
    return list
end

local function SetArrows(eb)
    if not (eb and eb.SetAltArrowKeyMode) then return end
    local want = not (Chat.db and Chat.db.editorKeys)
    pcall(eb.SetAltArrowKeyMode, eb, want)
end

function Chat:ApplyInput()
    for _, eb in ipairs(EditBoxes()) do
        if not eb.tempusInput and eb.HookScript then
            eb.tempusInput = true
            -- The game sets this again when the box opens, so set it after it does.
            eb:HookScript("OnShow", function(self) pcall(SetArrows, self) end)
            eb:HookScript("OnEditFocusGained", function(self) pcall(SetArrows, self) end)
        end
        SetArrows(eb)
    end
    if not self.inputActivateHook then
        self.inputActivateHook = true
        if ChatEdit_ActivateChat then pcall(hooksecurefunc, "ChatEdit_ActivateChat", SetArrows) end
        if ChatFrameUtil and ChatFrameUtil.ActivateChat then pcall(hooksecurefunc, ChatFrameUtil, "ActivateChat", SetArrows) end
    end
end

----------------------------------------------------------------------------------------
-- Copy buttons and fading tabs
----------------------------------------------------------------------------------------
-- One icon button at the right end of the tab row; it opens the chat log for whichever
-- chat window is selected.
local function Outline(parent, x, y, size, list)
    local function line(point, rel, w, h, ox, oy)
        local t = parent:CreateTexture(nil, "OVERLAY")
        t:SetTexture(S.WHITE)
        t:SetSize(w, h)
        t:SetPoint(point, parent, rel, x + ox, y + oy)
        list[#list + 1] = t
    end
    line("TOPLEFT", "TOPLEFT", size, 1, 0, 0)
    line("BOTTOMLEFT", "TOPLEFT", size, 1, 0, -size)
    line("TOPLEFT", "TOPLEFT", 1, size, 0, 0)
    line("TOPLEFT", "TOPLEFT", 1, size, size - 1, 0)
end

local function BuildCopyButton()
    local dock = _G.GeneralDockManager
    if Chat.copyButton or not dock then return end
    local b = CreateFrame("Button", nil, dock)
    b:SetSize(20, 20)
    b:SetPoint("RIGHT", dock, "RIGHT", -2, 0)
    b:SetFrameLevel(dock:GetFrameLevel() + 5)
    local lines = {}
    Outline(b, 5, -3, 9, lines)     -- the sheet behind
    Outline(b, 8, -7, 9, lines)     -- the sheet in front
    local fill = b:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(S.WHITE)
    fill:SetPoint("TOPLEFT", b, "TOPLEFT", 9, -8)
    fill:SetSize(7, 7)
    fill:SetVertexColor(0.04, 0.045, 0.058, 1)
    local function Tint(r, g, bl) for _, t in ipairs(lines) do t:SetVertexColor(r, g, bl, 1) end end
    Tint(0.75, 0.8, 0.9)
    b:SetScript("OnEnter", function(self)
        local ac = T.accent
        Tint(ac[1], ac[2], ac[3])
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Chat log")
        GameTooltip:AddLine("Opens this window's lines as text you can select and copy. Alt+click a chat window does the same.", 0.8, 0.85, 0.9, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() Tint(0.75, 0.8, 0.9); GameTooltip:Hide() end)
    b:SetScript("OnClick", function() Chat:ToggleLog(SELECTED_CHAT_FRAME or ChatFrame1) end)
    Chat.copyButton = b
end

function Chat:ApplyButtons()
    BuildCopyButton()
    if self.copyButton then self.copyButton:SetShown(self.db.copyButton and true or false) end
end

-- Tabs, the button column and the dock hide until the mouse is over a chat window. Alpha only.
local fadeTicker
local function ChromeFrames(cf)
    local name = cf:GetName()
    return { _G[name .. "Tab"], _G[name .. "ButtonFrame"] or cf.buttonFrame }
end

-- Buttons shared by all windows (chat menu, channels, quick join) fade with the rest.
local SHARED_CHROME = { "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton" }
local function EachChrome(fn)
    for _, cf in ipairs(Frames()) do
        for _, f in ipairs(ChromeFrames(cf)) do fn(f) end
    end
    for _, name in ipairs(SHARED_CHROME) do fn(_G[name]) end
end

local function Over(frame)
    return frame and frame.IsMouseOver and frame:IsMouseOver() or false
end

local function FadeTick()
    if not (Chat.db and Chat.db.fadeChrome) then
        if fadeTicker then fadeTicker:Cancel(); fadeTicker = nil end
        if Chat.copyButton then Chat.copyButton:SetAlpha(1) end
        EachChrome(function(f) if f and f.SetAlpha then f:SetAlpha(1) end end)
        return
    end
    -- One answer for the whole chat area: tabs of windows that are not showing fade with the rest.
    local frames = Frames()
    local over = Over(_G.GeneralDockManager)
    for _, name in ipairs(SHARED_CHROME) do
        if Over(_G[name]) then over = true end
    end
    for _, cf in ipairs(frames) do
        local name = cf:GetName()
        if (cf:IsShown() and Over(cf)) or Over(_G[name .. "Tab"]) then over = true end
        local edit = _G[name .. "EditBox"]
        if edit and edit:HasFocus() then over = true end
    end
    local alpha = over and 1 or 0
    if Chat.copyButton and Chat.copyButton:GetAlpha() ~= alpha then Chat.copyButton:SetAlpha(alpha) end
    EachChrome(function(f)
        if f and f.SetAlpha and f:GetAlpha() ~= alpha then f:SetAlpha(alpha) end
    end)
end

function Chat:ApplyFade()
    if self.db.fadeChrome and not fadeTicker then
        fadeTicker = C_Timer.NewTicker(0.15, T:Wrap("chat.fade", FadeTick))
    elseif not self.db.fadeChrome and fadeTicker then
        FadeTick()
    end
end

----------------------------------------------------------------------------------------
-- Timestamps: the game's own setting, so every line is stamped by Blizzard, not rewritten here.
----------------------------------------------------------------------------------------
local STAMP_COLOR = "|cff6f7787"

-- The game's timestamp format, with or without the grey wrapper. Trailing space stays outside.
function Chat.StampFormat(format, muted)
    if not Plain(format) or format == "" or format == "none" then return format end
    local plain = format:gsub("^|c%x%x%x%x%x%x%x%x", ""):gsub("|r(%s*)$", "%1")
    if not muted then return plain end
    local body, space = plain:match("^(.-)(%s*)$")
    return STAMP_COLOR .. body .. "|r" .. space
end

function Chat:ApplyTimestamps()
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    local format = TIMESTAMP_FORMATS[self.db.timestamps]
    if not format and get then
        local ok, current = pcall(get, "showTimestamps")
        format = ok and current or nil
    end
    if not format then return end
    format = Chat.StampFormat(format, self.db.mutedTimestamps)
    local ok, current = pcall(get, "showTimestamps")
    if ok and current == format then return end
    local done, err = pcall(set, "showTimestamps", format)
    if not done then T:ReportError("chat timestamps: " .. tostring(err)) end
end

-- Class-coloured names through the game's own setting (the same switch as in its chat options).
local CLASS_GROUPS = { "SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "WHISPER", "PARTY", "PARTY_LEADER", "RAID",
    "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "BATTLEGROUND", "BATTLEGROUND_LEADER",
    "GUILD_ACHIEVEMENT", "ACHIEVEMENT" }

function Chat:ApplyClassNames()
    if not self.db.classNames or self.classNamesDone then return end
    self.classNamesDone = true
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    local ok, override = pcall(get, "chatClassColorOverride")
    if ok and override ~= nil and override ~= "0" then pcall(set, "chatClassColorOverride", "0") end
    if SetChatColorNameByClass then
        for _, group in ipairs(CLASS_GROUPS) do pcall(SetChatColorNameByClass, group, true) end
        for i = 1, 20 do pcall(SetChatColorNameByClass, "CHANNEL" .. i, true) end
    end
end

----------------------------------------------------------------------------------------
-- History
----------------------------------------------------------------------------------------
local function Store()
    TempusDB.chatHistory = TempusDB.chatHistory or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    TempusDB.chatHistory[key] = TempusDB.chatHistory[key] or {}
    return TempusDB.chatHistory[key]
end

local function Record(cf, text, r, g, b)
    if Chat.replaying or not (Chat.db and Chat.db.history) then return end
    if not Plain(text) then return end
    local name = cf:GetName()
    if not name or name == SKIP_FRAME then return end
    local list = Store()
    list[name] = list[name] or {}
    local lines = list[name]
    lines[#lines + 1] = { t = text, r = T.Num(r) and r or nil, g = T.Num(g) and g or nil,
        b = T.Num(b) and b or nil, at = time() }
    local limit = Chat.db.historyLines
    if #lines > limit + 40 then
        local kept = {}
        for i = #lines - limit + 1, #lines do kept[#kept + 1] = lines[i] end
        list[name] = kept
    end
end

function Chat:HookHistory()
    for _, cf in ipairs(Frames()) do
        if not cf.tempusHistory then
            cf.tempusHistory = true
            hooksecurefunc(cf, "AddMessage", function(self, text, r, g, b)
                pcall(Record, self, text, r, g, b)
            end)
        end
    end
end

function Chat:Replay()
    if self.replayed or not self.db.history then return end
    self.replayed = true
    local saved = TempusDB.chatHistory and TempusDB.chatHistory[(UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")]
    if not saved then return end
    local cutoff = time() - HISTORY_MAX_AGE
    self.replaying = true
    for _, cf in ipairs(Frames()) do
        local lines = saved[cf:GetName()]
        if lines and #lines > 0 then
            local shown = 0
            for _, line in ipairs(lines) do
                if line.at >= cutoff and Plain(line.t) then
                    pcall(cf.AddMessage, cf, line.t, line.r, line.g, line.b)
                    shown = shown + 1
                end
            end
            if shown > 0 then
                pcall(cf.AddMessage, cf, "|cff7a8190— earlier chat —|r")
            end
        end
    end
    self.replaying = false
end

function Chat:ClearHistory()
    if TempusDB.chatHistory then TempusDB.chatHistory[(UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")] = nil end
    T:Print("saved chat history cleared for this character.")
end

function Chat.PratLoaded()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return loaded and loaded("Prat-3.0") and true or false
end

----------------------------------------------------------------------------------------
-- Module
----------------------------------------------------------------------------------------
-- Select mode and the copy window used to be two settings. They are one window now, so a
-- profile that had only select mode on keeps the feature instead of losing it quietly.
function Chat.MergeSelectMode(db)
    if type(db) ~= "table" or db.selectMode == nil then return false end
    local moved = db.selectMode and not db.copyButton
    if moved then db.copyButton = true end
    db.selectMode = nil
    return moved
end

function Chat:Apply()
    self.db = T.db.chat
    self:ApplyButtons()
    self:ApplyFade()
    self:ApplyInput()
    self:HookChatLog()
    if self.db.history then self:HookHistory() end
end

T:NewModule("chat", {
    label = "Chat",
    desc = "A chat log window you can select and copy from, editor-style cursor keys, clickable links, chat history across reloads, timestamps and fading tabs on top of Blizzard's chat.",
    defaults = Chat.defaults,
    OnEnable = function()
        Chat.db = T.db.chat
        Chat.MergeSelectMode(Chat.db)
        for _, event in ipairs(URL_EVENTS) do
            pcall(ChatFrame_AddMessageEventFilter, event, UrlFilter)
        end
        if not Chat.PratLoaded() then pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_CHANNEL", ChannelFilter) end
        hooksecurefunc("SetItemRef", function(link) pcall(OnLink, link) end)
        Chat:Apply()
        Chat:ApplyTimestamps()
        Chat:ApplyClassNames()
        if Chat.Whisper then pcall(Chat.Whisper.Init, Chat.Whisper) end
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            C_Timer.After(1, function()
                Chat:Apply()
                Chat:Replay()
            end)
        end)
    end,
    OnSettings = function()
        Chat:Apply()
        Chat:ApplyTimestamps()
        Chat:ApplyClassNames()
        if Chat.Whisper then Chat.Whisper:Apply() end
    end,
})
