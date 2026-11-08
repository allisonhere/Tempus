-- Tempus UI: chat frames, tabs and edit boxes in Tempus panels.
-- Everything here is looks: textures, colours, fonts and small helper buttons. Blizzard's chat
-- handlers are never replaced, only hooked after they run, and the edit box keeps its font and
-- insets (spell checkers such as SpellPower measure text in it).
local _, T = ...
local S = T.Style
local SK = T.Skins

local FRAME_TEXTURES = { "Background", "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture",
    "TopTexture", "BottomTexture", "LeftTexture", "RightTexture" }

local MUTED = { 0.55, 0.6, 0.68 }
local WHISPER = { 1, 0.5, 1 }
local COMBAT_LOG = "ChatFrame2"

local panels = {}
local skinned = {}

local function Opt(key) return SK.db and SK.db[key] ~= false end

local function Mark(t) t.tempus = true; return t end

local function EditBoxOf(cf)
    return cf.editBox or _G[(cf:GetName() or "") .. "EditBox"]
end

----------------------------------------------------------------------------------------
-- Panel: one panel holding the messages and the edit box. It stops at the top of the
-- message area so the tabs sit on the open background, as they do on the combat log.
----------------------------------------------------------------------------------------
local function EditBoxBelow(cf, eb)
    if not (eb and eb:IsShown()) then return false end
    local top, bottom = eb:GetTop(), cf:GetBottom()
    return top and bottom and top <= bottom + 6 and true or false
end

-- Edit box placement: Blizzard's spot under the window, moved sideways by the
-- "chatInputX" setting. Only for the usual layout with the box under the window.
local EDIT_LEFT, EDIT_RIGHT = -5, 5

local function InputX() return T.Num(SK.db and SK.db.chatInputX) and SK.db.chatInputX or 0 end

local function PlaceEditBox(cf, eb)
    if not (eb and eb.tempusBelowY) then return end
    local x = InputX()
    eb.tempusMoving = true
    eb:ClearAllPoints()
    eb:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", EDIT_LEFT + x, eb.tempusBelowY)
    eb:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", EDIT_RIGHT + x, eb.tempusBelowY)
    eb.tempusMoving = nil
end

-- Remember where Blizzard put the box (only if it sits under this window), then place it.
local function TakeOverEditBox(cf, eb)
    if eb.tempusMoving then return end
    local point, rel, relPoint, _, y = eb:GetPoint(1)
    if rel ~= cf or not (relPoint and relPoint:find("^BOTTOM")) or not (point and point:find("^TOP")) then
        eb.tempusBelowY = nil
        return
    end
    eb.tempusBelowY = y or -2
    PlaceEditBox(cf, eb)
end
SK.ChatInputX = InputX

local function AnchorPanel(cf)
    local panel = cf.tempusPanel
    if not panel then return end
    panel:ClearAllPoints()
    if not Opt("chatUnified") then
        panel:SetPoint("TOPLEFT", cf, "TOPLEFT", -5, 5)
        panel:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 5, -6)
        return
    end
    local eb = EditBoxOf(cf)
    -- Widen the panel if the edit box was moved past its edge.
    local x = (eb and eb.tempusBelowY) and InputX() or 0
    panel:SetPoint("TOPLEFT", cf, "TOPLEFT", math.min(-8, EDIT_LEFT + x - 2), 5)
    panel:SetPoint("RIGHT", cf, "RIGHT", math.max(8, EDIT_RIGHT + x + 2), 0)
    if EditBoxBelow(cf, eb) then
        panel:SetPoint("BOTTOM", eb, "BOTTOM", 0, -2)
    else
        panel:SetPoint("BOTTOM", cf, "BOTTOM", 0, -8)
    end
end

local function BuildPanel(cf)
    local panel = CreateFrame("Frame", nil, cf)
    -- Bottom of the bottom layer: the panel reaches up behind the tab row, and tabs, the
    -- dock buttons and the chat menu live on other frames that must all draw above it.
    panel:SetFrameStrata("BACKGROUND")
    panel:SetFrameLevel(0)
    panel.bd = S.Backdrop(panel, { fill = { 0.04, 0.045, 0.058, SK.db.chatAlpha } })
    cf.tempusPanel = panel
    panels[#panels + 1] = panel
    AnchorPanel(cf)
end

function SK:UpdateChatAlpha()
    for _, p in ipairs(panels) do p.bd:SetFillColor(0.04, 0.045, 0.058, SK.db.chatAlpha) end
end

----------------------------------------------------------------------------------------
-- Tabs: active tab bright with an accent underline, the rest dimmed, a hover highlight,
-- and an unread count that pulses for whispers.
----------------------------------------------------------------------------------------
local function TabOf(cf) return _G[(cf:GetName() or "") .. "Tab"] end

local function TabText(tab) return tab.Text or (tab.GetFontString and tab:GetFontString()) end

local function IsWhisperWindow(cf)
    return cf.chatType == "WHISPER" or cf.chatType == "BN_WHISPER"
end

local function PaintTab(cf)
    local tab = TabOf(cf)
    if not (tab and tab.tempusLine) then return end
    local active = cf:IsShown()
    local a = T.accent
    tab.tempusLine:SetShown(active)
    tab.tempusLine:SetVertexColor(a[1], a[2], a[3], 1)
    local fs = TabText(tab)
    if fs then
        if active then fs:SetTextColor(1, 1, 1)
        elseif IsWhisperWindow(cf) then fs:SetTextColor(WHISPER[1], WHISPER[2], WHISPER[3])
        else fs:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end
    end
    local unread = cf.tempusUnread or 0
    if active or unread <= 0 then
        cf.tempusUnread = 0
        tab.tempusBadge:Hide()
        tab.tempusPulse:Stop()
        cf.tempusAlert = nil
    else
        tab.tempusBadge.text:SetText(unread > 99 and "99+" or tostring(unread))
        local c = (cf.tempusAlert or IsWhisperWindow(cf)) and WHISPER or a
        tab.tempusBadge.dot:SetVertexColor(c[1], c[2], c[3], 1)
        tab.tempusBadge:SetWidth(math.max(14, tab.tempusBadge.text:GetStringWidth() + 8))
        tab.tempusBadge:Show()
        if cf.tempusAlert or IsWhisperWindow(cf) then
            if not tab.tempusPulse:IsPlaying() then tab.tempusPulse:Play() end
        else
            tab.tempusPulse:Stop()
            tab.tempusBadge:SetAlpha(1)
        end
    end
end

local function PaintTabs()
    for cf in pairs(skinned) do pcall(PaintTab, cf) end
end
SK.PaintChatTabs = PaintTabs

local function CountUnread(cf)
    if cf:IsShown() or cf:GetName() == COMBAT_LOG then return end
    if T.Chat and T.Chat.replaying then return end
    if not cf.isDocked and not IsWhisperWindow(cf) then return end
    cf.tempusUnread = (cf.tempusUnread or 0) + 1
    PaintTab(cf)
end

local function DecorateTab(cf, tab)
    local hover = Mark(tab:CreateTexture(nil, "BACKGROUND", nil, 1))
    hover:SetTexture(S.WHITE)
    hover:SetPoint("TOPLEFT", tab, "TOPLEFT", 4, -4)
    hover:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 3)
    hover:SetVertexColor(1, 1, 1, 0.07)
    hover:Hide()
    tab:HookScript("OnEnter", function() hover:Show() end)
    tab:HookScript("OnLeave", function() hover:Hide() end)

    local line = Mark(tab:CreateTexture(nil, "OVERLAY"))
    line:SetTexture(S.WHITE)
    line:SetHeight(2)
    line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 8, 3)
    line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, 3)
    tab.tempusLine = line

    local badge = CreateFrame("Frame", nil, tab)
    badge:SetSize(14, 12)
    badge:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 2, -1)
    badge:SetFrameLevel(tab:GetFrameLevel() + 3)
    badge.dot = Mark(badge:CreateTexture(nil, "ARTWORK"))
    badge.dot:SetTexture(S.WHITE)
    badge.dot:SetAllPoints()
    badge.text = badge:CreateFontString(nil, "OVERLAY")
    badge.text:SetFont(S.FONT, 9, "")
    badge.text:SetTextColor(0.05, 0.05, 0.07)
    badge.text:SetPoint("CENTER", 0, 0)
    badge:Hide()
    tab.tempusBadge = badge

    local pulse = badge:CreateAnimationGroup()
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.7)
    pulse:SetLooping("BOUNCE")
    tab.tempusPulse = pulse

    cf:HookScript("OnShow", function() pcall(PaintTabs) end)
    cf:HookScript("OnHide", function() pcall(PaintTabs) end)
    hooksecurefunc(cf, "AddMessage", function(self) pcall(CountUnread, self) end)
end

----------------------------------------------------------------------------------------
-- Font and spacing for the message area (not the edit box).
----------------------------------------------------------------------------------------
-- The size the player picked in the chat window's menu (saved by the game per window).
local function SavedSize(cf)
    local id = cf.GetID and cf:GetID()
    if not (id and id > 0 and GetChatWindowInfo) then return nil end
    local ok, _, size = pcall(GetChatWindowInfo, id)
    if ok and T.Num(size) and size > 0 then return size end
end
SK.ChatSavedSize = SavedSize

local function ApplyChatFont(cf, size)
    if not (cf and cf.GetFont) then return end
    size = (T.Num(size) and size > 0 and size) or SavedSize(cf) or select(2, cf:GetFont())
    if not size then return end
    local font = (T.db and T.db.font) or S.FONT
    cf.tempusFontBusy = true
    local ok, set = pcall(cf.SetFont, cf, font, size, "")
    if not (ok and set ~= false) then pcall(cf.SetFont, cf, S.FONT, size, "") end
    cf:SetShadowColor(0, 0, 0, 0.9)
    cf:SetShadowOffset(1, -1)
    if cf.SetSpacing then cf:SetSpacing(2) end
    cf.tempusFontBusy = nil
end

-- Size from a font object (or its global name).
local function ObjectSize(obj)
    if type(obj) == "string" then obj = _G[obj] end
    if type(obj) == "table" and obj.GetFont then
        local _, size = obj:GetFont()
        return size
    end
end

-- Whatever way the game changes a window's font (the chat menu, chat settings, a font
-- object), keep its size and put the Tempus font face back on.
local function FollowGameFont(cf)
    if cf.tempusFontHooked then return end
    cf.tempusFontHooked = true
    local function Follow(size)
        if cf.tempusFontBusy or not (T.Num(size) and size > 0) then return end
        ApplyChatFont(cf, size)
    end
    hooksecurefunc(cf, "SetFont", function(_, _, size) pcall(Follow, size) end)
    if cf.SetFontObject then
        hooksecurefunc(cf, "SetFontObject", function(_, obj) pcall(Follow, ObjectSize(obj)) end)
    end
    local obj = cf.GetFontObject and cf:GetFontObject()
    if type(obj) == "table" and obj.SetFont and not obj.tempusFontHooked then
        obj.tempusFontHooked = true
        hooksecurefunc(obj, "SetFont", function(_, _, size) pcall(Follow, size) end)
    end
end

----------------------------------------------------------------------------------------
-- "Back to newest": a small button while scrolled up, instead of Blizzard's arrow column.
----------------------------------------------------------------------------------------
local pills = {}

local function HideForGood(b)
    if type(b) ~= "table" or not b.Hide or b.tempusGone then return end
    b.tempusGone = true
    b:Hide()
    hooksecurefunc(b, "Show", b.Hide)
end

local function BuildPill(cf)
    local name = cf:GetName()
    for _, suffix in ipairs({ "ButtonFrameUpButton", "ButtonFrameDownButton", "ButtonFrameBottomButton" }) do
        HideForGood(_G[name .. suffix])
    end
    HideForGood(cf.ScrollToBottomButton)

    local pill = CreateFrame("Button", nil, cf)
    pill:SetSize(116, 18)
    pill:SetPoint("BOTTOM", cf, "BOTTOM", 0, 4)
    pill:SetFrameLevel(cf:GetFrameLevel() + 10)
    S.Backdrop(pill, { fill = { 0.07, 0.08, 0.1, 0.95 }, shadow = false })
    pill.text = S.Text(pill, 10, T.accent)
    pill.text:SetPoint("CENTER")
    pill.text:SetText("Back to newest")
    pill:SetScript("OnClick", function() cf:ScrollToBottom() end)
    pill:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    pill:SetScript("OnLeave", function(self) local a = T.accent; self.text:SetTextColor(a[1], a[2], a[3]) end)
    pill:Hide()
    pills[cf] = pill
end

local function PillTick()
    for cf, pill in pairs(pills) do
        local up = cf:IsShown() and cf.AtBottom and not cf:AtBottom()
        if up ~= pill:IsShown() then pill:SetShown(up and true or false) end
    end
end

----------------------------------------------------------------------------------------
-- Edit box: tinted with the colour of the channel you are typing in, brighter while focused.
----------------------------------------------------------------------------------------
local function ChannelColor(eb)
    local ct = eb.GetAttribute and eb:GetAttribute("chatType") or "SAY"
    local key = ct
    if ct == "CHANNEL" then
        local target = eb:GetAttribute("channelTarget")
        if target then key = "CHANNEL" .. tostring(target) end
    end
    local info = ChatTypeInfo and (ChatTypeInfo[key] or ChatTypeInfo[ct])
    if info and info.r then return info.r, info.g, info.b end
    return 1, 1, 1
end

local function PaintEditBox(eb)
    local h = eb and eb.tempusPanel
    if not h then return end
    local r, g, b = ChannelColor(eb)
    local focus = eb:HasFocus()
    h:SetEdgeColor(r, g, b, focus and 0.9 or 0.35)
    if eb.tempusBar then eb.tempusBar:SetVertexColor(r, g, b, focus and 1 or 0.45) end
end

local function SkinEditBox(cf, eb)
    local name = cf:GetName()
    SK:Strip(eb)
    for _, key in ipairs({ "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }) do
        local t = (type(eb[key]) == "table" and eb[key]) or _G[name .. "EditBox" .. key]
        if t and t.SetAlpha then t:SetAlpha(0) end
    end
    local ebPanel = CreateFrame("Frame", nil, eb)
    ebPanel:SetPoint("TOPLEFT", 2, -2)
    ebPanel:SetPoint("BOTTOMRIGHT", -2, 2)
    ebPanel:SetFrameLevel(math.max(eb:GetFrameLevel() - 1, 0))
    local h = S.Backdrop(ebPanel, { fill = { 0.03, 0.035, 0.045, 0.95 }, shadow = not Opt("chatUnified") })
    if Opt("chatEditColor") then
        eb.tempusPanel = h
        local bar = Mark(ebPanel:CreateTexture(nil, "ARTWORK"))
        bar:SetTexture(S.WHITE)
        bar:SetWidth(2)
        bar:SetPoint("TOPLEFT", ebPanel, "TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMLEFT", ebPanel, "BOTTOMLEFT", 1, 1)
        eb.tempusBar = bar
        -- Wrapped: an error in a hook would stop hooks other addons (SpellPower) put on the box.
        local function Paint(self) pcall(PaintEditBox, self) end
        eb:HookScript("OnEditFocusGained", Paint)
        eb:HookScript("OnEditFocusLost", Paint)
        eb:HookScript("OnShow", Paint)
        if eb.UpdateHeader then hooksecurefunc(eb, "UpdateHeader", PaintEditBox) end
        PaintEditBox(eb)
    end
    if InputX() ~= 0 then
        -- Blizzard re-anchors the box when windows dock or the chat style changes;
        -- take its new spot and move it again a frame later.
        hooksecurefunc(eb, "SetPoint", function(self)
            if self.tempusMoving or self.tempusPending then return end
            self.tempusPending = true
            C_Timer.After(0, function()
                self.tempusPending = nil
                pcall(TakeOverEditBox, cf, self)
                pcall(AnchorPanel, cf)
            end)
        end)
        TakeOverEditBox(cf, eb)
    end
    if Opt("chatUnified") then
        eb:HookScript("OnShow", function() pcall(AnchorPanel, cf) end)
        eb:HookScript("OnHide", function() pcall(AnchorPanel, cf) end)
    end
end

----------------------------------------------------------------------------------------
-- One chat window
----------------------------------------------------------------------------------------
local function SkinChatFrame(cf)
    if not cf or cf.tempusSkinned then return end
    cf.tempusSkinned = true
    skinned[cf] = true
    local name = cf:GetName()
    for _, suffix in ipairs(FRAME_TEXTURES) do
        local t = _G[name .. suffix]
        if t and t.SetAlpha then t:SetAlpha(0) end
    end
    if type(cf.Background) == "table" then cf.Background:SetAlpha(0) end

    BuildPanel(cf)

    local tab = TabOf(cf)
    if tab then
        SK:Strip(tab)
        for _, key in ipairs({ "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
            "HighlightLeft", "HighlightMiddle", "HighlightRight" }) do
            local t = (type(tab[key]) == "table" and tab[key]) or _G[name .. "Tab" .. key]
            if t and t.SetAlpha then t:SetAlpha(0) end
        end
        local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
        if hl then hl:SetAlpha(0) end
        local fs = TabText(tab)
        if fs then S.ApplyFont(fs, 12, nil, "NONE") end
        if Opt("chatTabs") then pcall(DecorateTab, cf, tab) end
    end

    local eb = EditBoxOf(cf)
    if eb then pcall(SkinEditBox, cf, eb) end

    local bf = _G[name .. "ButtonFrame"] or cf.buttonFrame
    if bf then SK:Strip(bf) end
    if type(cf.ScrollBar) == "table" then pcall(SK.ScrollBar, SK, cf.ScrollBar) end
    local search = _G[name .. "ChatSearchEditBox"]
    if search then pcall(SK.EditBox, SK, search) end
    if Opt("chatNewButton") then
        pcall(BuildPill, cf)
    elseif type(cf.ScrollToBottomButton) == "table" then
        for _, r in ipairs({ cf.ScrollToBottomButton:GetRegions() }) do
            if r.SetDesaturated then r:SetDesaturated(true); r:SetVertexColor(0.7, 0.73, 0.8) end
        end
    end
    if Opt("chatFont") then
        pcall(ApplyChatFont, cf)
        pcall(FollowGameFont, cf)
    end
    pcall(PaintTab, cf)
end

-- Small square Tempus buttons for the chat menu and voice/channel buttons.
local function SkinChatButton(b)
    if type(b) ~= "table" or b.tempusSkinned then return end
    b.tempusSkinned = true
    for _, r in ipairs({ b:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" and r ~= b.Icon and not r.tempus then
            local atlas = r.GetAtlas and r:GetAtlas()
            if atlas and atlas:find("chatframe%-button") then r:SetAlpha(0) end
        end
    end
    local panel = CreateFrame("Frame", nil, b)
    panel:SetPoint("TOPLEFT", 3, -3)
    panel:SetPoint("BOTTOMRIGHT", -3, 3)
    panel:SetFrameLevel(math.max(b:GetFrameLevel() - 1, 0))
    S.Backdrop(panel, { fill = { 0.04, 0.045, 0.058, 0.9 }, shadow = false })
end

local function SkinAll()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do pcall(SkinChatFrame, _G["ChatFrame" .. i]) end
    for _, name in ipairs(CHAT_FRAMES or {}) do pcall(SkinChatFrame, _G[name]) end
end

function SK:InitChat()
    for _, name in ipairs({ "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }) do
        pcall(SkinChatButton, _G[name])
    end
    -- The search box is created late; catch it the first time chat is shown or used.
    local tries, ticker = 0, nil
    ticker = C_Timer.NewTicker(2, function()
        tries = tries + 1
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local search = _G["ChatFrame" .. i .. "ChatSearchEditBox"]
            if search then pcall(SK.EditBox, SK, search) end
        end
        if tries >= 15 and ticker and ticker.Cancel then ticker:Cancel() end
    end)
    SkinAll()
    if FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function() SkinAll(); PaintTabs() end)
    end
    if Opt("chatTabs") then
        -- Blizzard recolours tab text when the selection changes; paint ours over it.
        if FCFTab_UpdateColors then hooksecurefunc("FCFTab_UpdateColors", function() PaintTabs() end) end
        if FCF_StartAlertFlash then
            hooksecurefunc("FCF_StartAlertFlash", function(cf)
                if cf then cf.tempusAlert = true; pcall(PaintTab, cf) end
            end)
        end
        if FCFDock_SelectWindow then hooksecurefunc("FCFDock_SelectWindow", function() PaintTabs() end) end
        S.OnAccent(PaintTabs)
    end
    if Opt("chatEditColor") and ChatEdit_UpdateHeader then
        hooksecurefunc("ChatEdit_UpdateHeader", function(eb) pcall(PaintEditBox, eb) end)
    end
    if Opt("chatFont") then
        -- The chat menu's font size: catch it where the game saves it and where the menu
        -- applies it, then again a frame later in case the game re-applies its own font.
        local function Resize(cf, size)
            if not (cf and skinned[cf]) then return end
            pcall(ApplyChatFont, cf, size)
            C_Timer.After(0, function() pcall(ApplyChatFont, cf, size) end)
        end
        if SetChatWindowSize then
            hooksecurefunc("SetChatWindowSize", function(id, size) Resize(_G["ChatFrame" .. tostring(id)], size) end)
        end
        if FCF_SetChatWindowFontSize then
            hooksecurefunc("FCF_SetChatWindowFontSize", function(menu, cf, size)
                cf = cf or (FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame())
                Resize(cf, size or (type(menu) == "table" and menu.value))
            end)
        end
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("UPDATE_CHAT_WINDOWS")
        ev:SetScript("OnEvent", function()
            for cf in pairs(skinned) do pcall(ApplyChatFont, cf, select(2, cf:GetFont())) end
        end)
    end
    if Opt("chatNewButton") then C_Timer.NewTicker(0.25, function() pcall(PillTick) end) end
    if Opt("chatUnified") then
        -- Edit boxes can move when windows are docked or resized.
        C_Timer.After(1, function() for cf in pairs(skinned) do pcall(AnchorPanel, cf) end end)
        if FCF_DockFrame then hooksecurefunc("FCF_DockFrame", function() for cf in pairs(skinned) do pcall(AnchorPanel, cf) end end) end
    end
end
