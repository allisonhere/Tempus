-- Tempus UI: small automations. Accepts and turns in quests, filters repeated red error
-- messages, loots everything at once with auto-loot, and shows an AFK screen. Holding Shift
-- skips the quest and loot automations.
local _, T = ...
local S = T.Style
local issecret = T.issecret or function() return false end

local A = {}
T.Automation = A

A.defaults = {
    quests = true,          -- accept quests from NPCs
    turnIn = true,          -- hand in finished quests (never picks between rewards)
    errors = true,          -- hide "not ready yet" / "not enough energy" spam
    fastLoot = true,        -- take every item at once when auto-loot is on
    afk = false,            -- AFK screen with a slowly turning camera
}

local function Skip()
    return IsShiftKeyDown and IsShiftKeyDown()
end

local function Plain(v) return v ~= nil and not issecret(v) end

----------------------------------------------------------------------------------------
-- Quests
----------------------------------------------------------------------------------------
-- Chooses one quest on a gossip or greeting window: a finished one to hand in first, then a
-- new one to take. Grey (trivial) quests are left alone. Returns true when it picked one.
function A.PickGossipQuest()
    local db = A.db
    local G = C_GossipInfo
    if G and G.GetActiveQuests then
        if db.turnIn then
            for _, q in ipairs(G.GetActiveQuests() or {}) do
                if q.isComplete and q.questID then G.SelectActiveQuest(q.questID) return true end
            end
        end
        if db.quests then
            for _, q in ipairs(G.GetAvailableQuests() or {}) do
                if not q.isTrivial and q.questID then G.SelectAvailableQuest(q.questID) return true end
            end
        end
        return false
    end
    -- Quest greeting windows (and older clients) list quests by index.
    if db.turnIn and GetNumActiveQuests then
        for i = 1, GetNumActiveQuests() do
            local _, complete = GetActiveTitle(i)
            if complete then SelectActiveQuest(i) return true end
        end
    end
    if db.quests and GetNumAvailableQuests then
        for i = 1, GetNumAvailableQuests() do
            local trivial = GetAvailableQuestInfo and select(1, GetAvailableQuestInfo(i))
            if not trivial then SelectAvailableQuest(i) return true end
        end
    end
    return false
end

function A.OnQuestEvent(event)
    local db = A.db
    if not db or Skip() then return end
    if event == "QUEST_DETAIL" then
        if db.quests then AcceptQuest() end
    elseif event == "QUEST_PROGRESS" then
        if db.turnIn and IsQuestCompletable() then
            -- Quests that take gold are the player's call.
            if GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then return end
            CompleteQuest()
        end
    elseif event == "QUEST_COMPLETE" then
        if not db.turnIn then return end
        local choices = GetNumQuestChoices() or 0
        if choices > 1 then return end          -- a real choice: leave it to the player
        GetQuestReward(choices == 1 and 1 or 0)
    elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        A.PickGossipQuest()
    end
end

----------------------------------------------------------------------------------------
-- Error filter
----------------------------------------------------------------------------------------
local SPAM_KEYS = {
    "ERR_ABILITY_COOLDOWN", "ERR_SPELL_COOLDOWN", "ERR_ITEM_COOLDOWN", "SPELL_FAILED_NOT_READY",
    "ERR_OUT_OF_ENERGY", "ERR_OUT_OF_RAGE", "ERR_OUT_OF_MANA", "ERR_OUT_OF_FOCUS",
    "ERR_NO_ATTACK_TARGET", "ERR_GENERIC_NO_TARGET", "SPELL_FAILED_NO_COMBO_POINTS",
    "SPELL_FAILED_TARGETS_DEAD", "SPELL_FAILED_SPELL_IN_PROGRESS",
}
local spam

function A.IsSpam(msg)
    if not Plain(msg) or type(msg) ~= "string" then return false end
    if not spam then
        spam = {}
        for _, key in ipairs(SPAM_KEYS) do
            local text = _G[key]
            if type(text) == "string" then spam[text] = true end
        end
    end
    return spam[msg] == true
end

local errorsOwned, blizzErrorHandler

local function OnError(event, ...)
    local _, msg = ...
    if A.IsSpam(msg) then return end
    -- Anything else goes through Blizzard's own handler, sound and all.
    if blizzErrorHandler then
        blizzErrorHandler(UIErrorsFrame, event, ...)
    elseif UIErrorsFrame and Plain(msg) then
        UIErrorsFrame:AddMessage(msg, 1, 0.1, 0.1, 1)
    end
end

function A.ApplyErrors()
    local f = UIErrorsFrame
    if not f then return end
    local want = A.db and A.db.errors
    if want and not errorsOwned then
        blizzErrorHandler = f:GetScript("OnEvent")
        pcall(f.UnregisterEvent, f, "UI_ERROR_MESSAGE")
        A.events:RegisterEvent("UI_ERROR_MESSAGE")
        errorsOwned = true
    elseif not want and errorsOwned then
        A.events:UnregisterEvent("UI_ERROR_MESSAGE")
        pcall(f.RegisterEvent, f, "UI_ERROR_MESSAGE")
        errorsOwned = false
    end
end

----------------------------------------------------------------------------------------
-- Fast loot
----------------------------------------------------------------------------------------
function A.AutoLootOn(arg)
    if type(arg) == "boolean" then return arg end
    local cvar = GetCVarBool and GetCVarBool("autoLootDefault") or false
    local toggled = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") or false
    return cvar ~= toggled
end

function A.FastLoot()
    for i = (GetNumLootItems() or 0), 1, -1 do LootSlot(i) end
end

local function OnLootReady(autoLoot)
    if not (A.db and A.db.fastLoot) or not A.AutoLootOn(autoLoot) then return end
    -- One frame later, so modules that read the loot window (gathering nodes) see it first.
    C_Timer.After(0, A.FastLoot)
end

----------------------------------------------------------------------------------------
-- AFK screen
----------------------------------------------------------------------------------------
local afkFrame, afkSince

local function Clock(sec)
    sec = math.floor(sec)
    return ("%02d:%02d"):format(math.floor(sec / 60), sec % 60)
end

local function BuildAfk()
    local f = CreateFrame("Frame", "TempusAFKFrame", nil)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetAllPoints(WorldFrame)
    f:SetScale(UIParent:GetEffectiveScale())
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    bar:SetHeight(110)
    S.Backdrop(bar, { fill = { 0.03, 0.035, 0.045, 0.9 } })
    local logo = bar:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(T.LOGO)
    logo:SetSize(72, 72)
    logo:SetPoint("LEFT", 28, 0)
    f.name = S.Text(bar, 22, T.accent)
    f.name:SetPoint("TOPLEFT", logo, "TOPRIGHT", 18, -8)
    f.info = S.Text(bar, 13, S.C.muted)
    f.info:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -6)
    f.timer = S.Text(bar, 28)
    f.timer:SetPoint("RIGHT", -32, 8)
    f.clock = S.Text(bar, 13, S.C.muted)
    f.clock:SetPoint("TOPRIGHT", f.timer, "BOTTOMRIGHT", 0, -4)
    local hint = S.Text(bar, 11, S.C.muted)
    hint:SetPoint("BOTTOM", 0, 10)
    hint:SetText("Away. Move or press a key to come back.")
    local t = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        t = t + elapsed
        if t < 0.5 then return end
        t = 0
        f.timer:SetText("AFK " .. Clock(GetTime() - (afkSince or GetTime())))
        f.clock:SetText(date("%H:%M"))
    end)
    f:EnableKeyboard(true)
    if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
    f:SetScript("OnKeyDown", function() A.LeaveAfk() end)
    f:Hide()
    return f
end

function A.EnterAfk()
    if afkFrame and afkFrame:IsShown() then return end
    if InCombatLockdown() then return end
    afkFrame = afkFrame or BuildAfk()
    local level = UnitLevel("player")
    local className = UnitClass("player")
    afkFrame.name:SetText(UnitName("player") or "")
    afkFrame.info:SetText(("Level %s %s  ·  %s"):format(tostring(level or ""), className or "", GetRealmName() or ""))
    afkSince = GetTime()
    -- Alpha, not Hide: showing UIParent again is blocked in combat, its alpha never is.
    UIParent:SetAlpha(0)
    afkFrame:Show()
    if MoveViewLeftStart then MoveViewLeftStart(0.035) end
end

function A.LeaveAfk()
    if not (afkFrame and afkFrame:IsShown()) then return end
    afkFrame:Hide()
    UIParent:SetAlpha(1)
    if MoveViewLeftStop then MoveViewLeftStop() end
end

local function OnFlags(unit)
    if unit and unit ~= "player" then return end
    local ok, afk = pcall(UnitIsAFK, "player")
    if not ok or issecret(afk) then return end
    if afk and A.db.afk then A.EnterAfk() else A.LeaveAfk() end
end

----------------------------------------------------------------------------------------
-- Module
----------------------------------------------------------------------------------------
local QUEST_EVENTS = { QUEST_DETAIL = true, QUEST_PROGRESS = true, QUEST_COMPLETE = true,
    GOSSIP_SHOW = true, QUEST_GREETING = true }

local function OnEvent(_, event, ...)
    if QUEST_EVENTS[event] then A.OnQuestEvent(event)
    elseif event == "UI_ERROR_MESSAGE" then OnError(event, ...)
    elseif event == "LOOT_READY" then OnLootReady(...)
    elseif event == "PLAYER_FLAGS_CHANGED" then OnFlags(...)
    elseif event == "PLAYER_REGEN_DISABLED" then A.LeaveAfk()
    end
end

T:NewModule("automation", {
    label = "Automation",
    desc = "Accepts and hands in quests, hides error spam, loots everything at once and shows an AFK screen.",
    defaults = A.defaults,
    OnEnable = function()
        A.db = T.db.automation
        A.events = CreateFrame("Frame")
        for e in pairs(QUEST_EVENTS) do pcall(A.events.RegisterEvent, A.events, e) end
        A.events:RegisterEvent("LOOT_READY")
        A.events:RegisterEvent("PLAYER_FLAGS_CHANGED")
        A.events:RegisterEvent("PLAYER_REGEN_DISABLED")
        A.events:SetScript("OnEvent", T:Wrap("automation.events", OnEvent))
        A.ApplyErrors()
    end,
    OnSettings = function()
        A.db = T.db.automation
        if A.events then A.ApplyErrors() end
        if not A.db.afk then A.LeaveAfk() end
    end,
})
