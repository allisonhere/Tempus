-- Tempus UI: chat features on top of Blizzard's own chat frames: clickable links, a copy window,
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
    copyButton = true,      -- small "copy" button in the corner of each chat window
    history = true,         -- keep recent lines across /reload and relog
    historyLines = 150,     -- per chat window
    timestamps = "KEEP",    -- KEEP leaves the game setting alone | NONE | H24 | H12
    fadeChrome = false,     -- hide tabs and buttons until the mouse is over the chat window
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

function Chat.Linkify(msg)
    if not (msg:find("://", 1, true) or msg:find("www.", 1, true)) then return msg end
    local out, pos = {}, 1
    while pos <= #msg do
        local s, e = msg:find("|H.-|h.-|h", pos)
        out[#out + 1] = LinkPlain(msg:sub(pos, (s or #msg + 1) - 1))
        if not s then break end
        out[#out + 1] = msg:sub(s, e)
        pos = e + 1
    end
    return table.concat(out)
end

local function UrlFilter(_, _, msg, ...)
    if not (Chat.db and Chat.db.urls) or not Plain(msg) then return false end
    local ok, linked = pcall(Chat.Linkify, msg)
    if ok and linked ~= msg then return false, linked, ... end
    return false
end

----------------------------------------------------------------------------------------
-- Copy window
----------------------------------------------------------------------------------------
local win

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
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    tinsert(UISpecialFrames, "TempusChatCopyFrame")
    UI.Tex(win, "BACKGROUND", C.bg, -7):SetAllPoints()
    UI.Border(win, { 1, 1, 1, 0.12 })

    win.title = UI.Text(win, 16, AC)
    win.title:SetPoint("TOPLEFT", 16, -14)
    win.hint = UI.Text(win, 11, C.muted)
    win.hint:SetPoint("TOPLEFT", 16, -40)
    win.hint:SetText("Click in the text and press Ctrl+A, then Ctrl+C. Esc closes this window.")

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
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    win.edit, win.scroll = edit, scroll

    win.close = UI.FlatButton(win, "Close", 100, 26, function() win:Hide() end)
    win.close:SetPoint("BOTTOMRIGHT", -16, 16)
end

function Chat:ShowText(title, text)
    if not win then BuildWindow() end
    win.title:SetText(title)
    win.edit:SetText(text or "")
    win.scroll:SetVerticalScroll(0)
    win:Show()
    win.edit:SetFocus()
    win.edit:HighlightText()
end

-- Strip colours, textures and link wrappers so the pasted text reads as plain chat.
local function Clean(line)
    line = line:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    line = line:gsub("|H.-|h(.-)|h", "%1")
    line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return line
end

function Chat:Copy(cf)
    cf = cf or SELECTED_CHAT_FRAME or ChatFrame1
    local lines, hidden = {}, 0
    for i = 1, (cf:GetNumMessages() or 0) do
        local ok, msg = pcall(cf.GetMessageInfo, cf, i)
        if ok and msg then
            if Plain(msg) then
                lines[#lines + 1] = Clean(msg)
            else
                hidden = hidden + 1
            end
        end
    end
    local text = table.concat(lines, "\n")
    if hidden > 0 then
        text = text .. ("\n\n(%d line%s hidden by the game during a boss fight or Mythic+ run)"):format(hidden, hidden == 1 and "" or "s")
    end
    self:ShowText("Chat window " .. ((cf:GetName() or ""):gsub("ChatFrame", "")), text)
end

local function OnLink(link)
    local url = type(link) == "string" and not issecret(link) and link:match("^url:(.+)$")
    if url then Chat:ShowText("Link", url) end
end

----------------------------------------------------------------------------------------
-- Copy buttons and fading tabs
----------------------------------------------------------------------------------------
local buttons = {}

local function AddCopyButton(cf)
    if cf.tempusCopy then return end
    local b = CreateFrame("Button", nil, cf)
    b:SetSize(36, 14)
    b:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -2, -2)
    b:SetFrameLevel(cf:GetFrameLevel() + 5)
    local fs = b:CreateFontString(nil, "OVERLAY")
    S.ApplyFont(fs, 10)
    fs:SetPoint("RIGHT")
    fs:SetText("copy")
    fs:SetTextColor(0.75, 0.8, 0.9)
    b:SetAlpha(0.25)
    b:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
    b:SetScript("OnLeave", function(self) self:SetAlpha(0.25) end)
    b:SetScript("OnClick", function() Chat:Copy(cf) end)
    cf.tempusCopy = b
    buttons[#buttons + 1] = b
end

function Chat:ApplyButtons()
    local on = self.db.copyButton
    for _, cf in ipairs(Frames()) do
        if on then AddCopyButton(cf) end
        if cf.tempusCopy then cf.tempusCopy:SetShown(on) end
    end
end

-- Tabs, the button column and the dock hide until the mouse is over a chat window. Alpha only.
local fadeTicker
local function ChromeFrames(cf)
    local name = cf:GetName()
    return { _G[name .. "Tab"], _G[name .. "ButtonFrame"] or cf.buttonFrame }
end

local function Over(frame)
    return frame and frame.IsMouseOver and frame:IsMouseOver() or false
end

local function FadeTick()
    if not (Chat.db and Chat.db.fadeChrome) then
        if fadeTicker then fadeTicker:Cancel(); fadeTicker = nil end
        for _, cf in ipairs(Frames()) do
            for _, f in ipairs(ChromeFrames(cf)) do
                if f and f.SetAlpha then f:SetAlpha(1) end
            end
        end
        return
    end
    -- One answer for the whole chat area: tabs of windows that are not showing fade with the rest.
    local frames = Frames()
    local over = Over(_G.GeneralDockManager)
    for _, cf in ipairs(frames) do
        local name = cf:GetName()
        if (cf:IsShown() and Over(cf)) or Over(_G[name .. "Tab"]) then over = true end
        local edit = _G[name .. "EditBox"]
        if edit and edit:HasFocus() then over = true end
    end
    local alpha = over and 1 or 0
    for _, cf in ipairs(frames) do
        for _, f in ipairs(ChromeFrames(cf)) do
            if f and f.SetAlpha and f:GetAlpha() ~= alpha then f:SetAlpha(alpha) end
        end
    end
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
function Chat:ApplyTimestamps()
    local format = TIMESTAMP_FORMATS[self.db.timestamps]
    if not format then return end
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    local ok, err = pcall(set, "showTimestamps", format)
    if not ok then T:ReportError("chat timestamps: " .. tostring(err)) end
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
function Chat:Apply()
    self.db = T.db.chat
    self:ApplyButtons()
    self:ApplyFade()
    if self.db.history then self:HookHistory() end
end

T:NewModule("chat", {
    label = "Chat",
    desc = "Clickable links, a copy window, chat history across reloads, timestamps and fading tabs on top of Blizzard's chat.",
    defaults = Chat.defaults,
    OnEnable = function()
        Chat.db = T.db.chat
        for _, event in ipairs(URL_EVENTS) do
            pcall(ChatFrame_AddMessageEventFilter, event, UrlFilter)
        end
        hooksecurefunc("SetItemRef", function(link) pcall(OnLink, link) end)
        Chat:Apply()
        Chat:ApplyTimestamps()
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
    end,
})
