-- Tempus UI: chat frames, tabs and edit boxes in Tempus panels. Only textures change;
-- sizes, positions and fonts are left to the game and to Prat.
local _, T = ...
local S = T.Style
local SK = T.Skins

local FRAME_TEXTURES = { "Background", "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture",
    "TopTexture", "BottomTexture", "LeftTexture", "RightTexture" }

local panels = {}

local function SkinChatFrame(cf)
    if not cf or cf.tempusSkinned then return end
    cf.tempusSkinned = true
    local name = cf:GetName()
    for _, suffix in ipairs(FRAME_TEXTURES) do
        local t = _G[name .. suffix]
        if t and t.SetAlpha then t:SetAlpha(0) end
    end
    if type(cf.Background) == "table" then cf.Background:SetAlpha(0) end

    local panel = CreateFrame("Frame", nil, cf)
    panel:SetPoint("TOPLEFT", cf, "TOPLEFT", -5, 5)
    panel:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 5, -6)
    panel:SetFrameLevel(math.max(cf:GetFrameLevel() - 1, 0))
    panel.bd = S.Backdrop(panel, { fill = { 0.04, 0.045, 0.058, SK.db.chatAlpha } })
    panels[#panels + 1] = panel

    local tab = _G[name .. "Tab"]
    if tab then
        SK:Strip(tab)
        for _, key in ipairs({ "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
            "HighlightLeft", "HighlightMiddle", "HighlightRight" }) do
            local t = (type(tab[key]) == "table" and tab[key]) or _G[name .. "Tab" .. key]
            if t and t.SetAlpha then t:SetAlpha(0) end
        end
        local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
        if hl then hl:SetAlpha(0) end
        local fs = tab.Text or (tab.GetFontString and tab:GetFontString())
        if fs then S.ApplyFont(fs, 12, nil, "NONE") end
    end

    local eb = _G[name .. "EditBox"]
    if eb then
        SK:Strip(eb)
        for _, key in ipairs({ "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }) do
            local t = (type(eb[key]) == "table" and eb[key]) or _G[name .. "EditBox" .. key]
            if t and t.SetAlpha then t:SetAlpha(0) end
        end
        local ebPanel = CreateFrame("Frame", nil, eb)
        ebPanel:SetPoint("TOPLEFT", 2, -2)
        ebPanel:SetPoint("BOTTOMRIGHT", -2, 2)
        ebPanel:SetFrameLevel(math.max(eb:GetFrameLevel() - 1, 0))
        S.Backdrop(ebPanel, { fill = { 0.03, 0.035, 0.045, 0.95 } })
    end

    local bf = _G[name .. "ButtonFrame"] or cf.buttonFrame
    if bf then SK:Strip(bf) end
    if type(cf.ScrollBar) == "table" then pcall(SK.ScrollBar, SK, cf.ScrollBar) end
    local search = _G[name .. "ChatSearchEditBox"]
    if search then pcall(SK.EditBox, SK, search) end
    if type(cf.ScrollToBottomButton) == "table" then
        for _, r in ipairs({ cf.ScrollToBottomButton:GetRegions() }) do
            if r.SetDesaturated then r:SetDesaturated(true); r:SetVertexColor(0.7, 0.73, 0.8) end
        end
    end
end

function SK:UpdateChatAlpha()
    for _, p in ipairs(panels) do p.bd:SetFillColor(0.04, 0.045, 0.058, SK.db.chatAlpha) end
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
    for i = 1, (NUM_CHAT_WINDOWS or 10) do pcall(SkinChatFrame, _G["ChatFrame" .. i]) end
    if FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            for _, name in ipairs(CHAT_FRAMES or {}) do pcall(SkinChatFrame, _G[name]) end
        end)
    end
end
