-- Tempus UI: whisper alert. When someone whispers you: a banner at the top of the screen
-- with who it is and what they said, a sound you can pick (played on the Master channel so it
-- is heard with game sounds off), and a flashing taskbar icon when the game is in the background.
-- Nothing is sent or replied for you: press R (Blizzard's reply key) to answer.
local _, T = ...
local S = T.Style
local Chat = T.Chat
local issecret = issecretvalue or function() return false end

local WA = {}
Chat.Whisper = WA

-- Merged into the chat module's defaults so they live in T.db.chat.
local DEFAULTS = {
    whisperAlert = true,        -- master switch
    whisperBanner = true,       -- banner at the top of the screen
    whisperSound = "TELL",      -- NONE | TELL | RAID_WARNING | READY_CHECK | ALARM
    whisperFlash = true,        -- flash the taskbar icon when the game is in the background
    whisperCombat = true,       -- also alert in combat
    whisperBattleNet = true,    -- Battle.net whispers too
    whisperPoint = { "TOP", "UIParent", "TOP", 0, -100 },
}
for k, v in pairs(DEFAULTS) do Chat.defaults[k] = v end

WA.SOUNDS = {
    { "NONE", "No sound" },
    { "TELL", "Whisper (the game's own)" },
    { "RAID_WARNING", "Raid warning" },
    { "READY_CHECK", "Ready check" },
    { "ALARM", "Alarm clock" },
}
local SOUND_KITS = {
    TELL = { "TELL_MESSAGE" },
    RAID_WARNING = { "RAID_WARNING" },
    READY_CHECK = { "READY_CHECK" },
    ALARM = { "ALARM_CLOCK_WARNING_3", "ALARM_CLOCK_WARNING_2" },
}
local FALLBACK_IDS = { TELL = 3081, RAID_WARNING = 8959, READY_CHECK = 8960, ALARM = 12867 }

local PINK = { 1, 0.5, 1 }
local SHOW_FOR, FADE = 8, 1.5
local SOUND_GAP = 4             -- seconds between sounds from the same person
local MAX_PREVIEW = 90

local function Plain(v) return type(v) == "string" and not issecret(v) end

function WA.SoundKit(choice)
    if choice == "NONE" or not choice then return nil end
    local names = SOUND_KITS[choice]
    if names and SOUNDKIT then
        for _, n in ipairs(names) do
            if SOUNDKIT[n] then return SOUNDKIT[n] end
        end
    end
    return FALLBACK_IDS[choice]
end

-- Strip colours and links so the preview reads as plain text, and keep it short.
function WA.Preview(msg)
    if not Plain(msg) then return nil end
    msg = msg:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1")
    msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if #msg > MAX_PREVIEW then msg = msg:sub(1, MAX_PREVIEW - 3) .. "..." end
    return msg
end

-- Should this whisper alert? event, the sender, now, the last sound per sender.
function WA.ShouldAlert(db, event, inCombat)
    if not (db and db.whisperAlert) then return false end
    if event == "CHAT_MSG_BN_WHISPER" and not db.whisperBattleNet then return false end
    if inCombat and not db.whisperCombat then return false end
    return true
end

local lastSound = {}

function WA.SoundDue(sender, now)
    local key = Plain(sender) and sender or "?"
    if lastSound[key] and now - lastSound[key] < SOUND_GAP then return false end
    lastSound[key] = now
    return true
end

----------------------------------------------------------------------------------------
-- Banner
----------------------------------------------------------------------------------------
-- The movers read and write cfg.point; this keeps it in T.db.chat.whisperPoint.
local placement = setmetatable({}, {
    __index = function(_, k) if k == "point" then return Chat.db.whisperPoint end end,
    __newindex = function(_, k, v) if k == "point" then Chat.db.whisperPoint = v end end,
})

local function OnUpdate(f)
    local age = GetTime() - (f.shownAt or 0)
    if age > SHOW_FOR + FADE then
        f:Hide()
    elseif age > SHOW_FOR then
        f:SetAlpha(1 - (age - SHOW_FOR) / FADE)
    end
end

local function Build()
    local f = CreateFrame("Button", "TempusWhisperAlert", UIParent)
    f:SetFrameStrata("HIGH")
    f:SetSize(380, 50)
    f:Hide()
    S.Backdrop(f, { fill = { 0.05, 0.04, 0.07, 0.92 } }):SetEdgeColor(PINK[1], PINK[2], PINK[3], 0.9)
    local bar = f:CreateTexture(nil, "ARTWORK")
    bar:SetTexture(S.WHITE)
    bar:SetVertexColor(PINK[1], PINK[2], PINK[3], 1)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMLEFT", 1, 1)
    bar:SetWidth(3)
    f.title = S.Text(f, 15, PINK, "OUTLINE")
    f.title:SetPoint("TOPLEFT", 14, -8)
    f.title:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.body = S.Text(f, 12, { 0.92, 0.92, 0.95 })
    f.body:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.body:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.body:SetWordWrap(false)
    f.hint = S.Text(f, 9, { 0.55, 0.6, 0.68 })
    f.hint:SetPoint("BOTTOMRIGHT", -8, 5)
    f.hint:SetText("R to reply - click to dismiss")
    local pulse = f:CreateAnimationGroup()
    local grow = pulse:CreateAnimation("Alpha")
    grow:SetFromAlpha(0.4)
    grow:SetToAlpha(1)
    grow:SetDuration(0.25)
    f.pulse = pulse
    f:SetScript("OnClick", function(self) self:Hide() end)
    f:SetScript("OnUpdate", T:Wrap("chat.whisper", OnUpdate))
    WA.frame = f
    T.Movers.ApplyPoint(f, placement)
    T.Movers:Register(f, {
        label = "Whisper alert", page = "chat",
        cfg = function() return placement end,
        corner = function() return Chat.db.whisperPoint[1] end,
        enabled = function() return Chat.db.whisperAlert and Chat.db.whisperBanner end,
    })
end

function WA:ShowBanner(sender, msg)
    if not self.frame then Build() end
    local f = self.frame
    f.title:SetText(Plain(sender) and ("Whisper from " .. sender) or "New whisper")
    f.body:SetText(WA.Preview(msg) or "")
    f:SetHeight((f.body:GetText() or "") ~= "" and 50 or 36)
    f.shownAt = GetTime()
    f:SetAlpha(1)
    f:Show()
    f.pulse:Stop()
    f.pulse:Play()
end

function WA:Alert(event, msg, sender)
    local db = Chat.db
    if not WA.ShouldAlert(db, event, InCombatLockdown and InCombatLockdown()) then return end
    if db.whisperBanner then self:ShowBanner(sender, msg) end
    local kit = WA.SoundKit(db.whisperSound)
    if kit and PlaySound and WA.SoundDue(sender, GetTime()) then pcall(PlaySound, kit, "Master") end
    if db.whisperFlash and FlashClientIcon then pcall(FlashClientIcon) end
end

function WA:Test()
    local db = Chat.db
    if db.whisperBanner then self:ShowBanner("Someone", "Hey, are you around? Want to run Deadmines?") end
    local kit = WA.SoundKit(db.whisperSound)
    if kit and PlaySound then pcall(PlaySound, kit, "Master") end
end

function WA:Init()
    if self.ready then return end
    self.ready = true
    -- Move the banner with the UI unlocked even before the first whisper.
    pcall(Build)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("CHAT_MSG_WHISPER")
    pcall(ev.RegisterEvent, ev, "CHAT_MSG_BN_WHISPER")
    ev:SetScript("OnEvent", T:Wrap("chat.whisper.event", function(_, event, msg, sender)
        WA:Alert(event, msg, sender)
    end))
end

function WA:Apply()
    if self.frame then T.Movers.ApplyPoint(self.frame, placement) end
    if self.frame and not (Chat.db.whisperAlert and Chat.db.whisperBanner) then self.frame:Hide() end
end
