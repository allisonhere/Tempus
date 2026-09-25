-- Tempus: records which Blizzard frames, templates and APIs exist on this client, and
-- which values come back secret, into TempusDB.probe. Runs once after login and once in
-- /tempus probe.
local _, T = ...

local issecret = issecretvalue or function() return false end

local FRAMES = {
    -- action bars
    "MainMenuBar", "MainActionBar", "MainMenuBarArtFrame", "MainMenuBarArtFrameBackground", "MainMenuExpBar",
    "ReputationWatchBar", "StatusTrackingBarManager", "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
    "ActionButton1", "MultiBarBottomLeft", "MultiBarBottomLeftButton1", "MultiBarBottomRight",
    "MultiBarBottomRightButton1", "MultiBarRight", "MultiBarRightButton1", "MultiBarLeft", "MultiBarLeftButton1",
    "MultiBar5", "MultiBar5Button1", "StanceBar", "StanceBarFrame", "StanceButton1", "PetActionBar",
    "PetActionBarFrame", "PetActionButton1", "PossessBarFrame", "MicroButtonAndBagsBar", "MicroMenu",
    "CharacterMicroButton", "MainMenuBarBackpackButton", "CharacterBag0Slot", "ActionBarUpButton",
    "MainMenuBarPageNumber", "OverrideActionBar", "ExtraActionBarFrame", "EditModeManagerFrame",
    -- unit frames
    "PlayerFrame", "TargetFrame", "TargetFrameToT", "PetFrame", "FocusFrame", "PartyMemberFrame1",
    "PartyFrame", "CompactPartyFrame", "PlayerCastingBarFrame", "CastingBarFrame", "TargetFrameSpellBar",
    "ComboFrame", "RuneFrame", "TotemFrame",
    -- minimap
    "Minimap", "MinimapCluster", "MinimapBorder", "MinimapBorderTop", "MinimapBackdrop", "MinimapZoomIn",
    "MinimapZoomOut", "MinimapZoneText", "MinimapZoneTextButton", "GameTimeFrame", "TimeManagerClockButton",
    "MiniMapTracking", "MiniMapTrackingFrame", "MiniMapMailFrame", "MiniMapWorldMapButton",
    "MinimapToggleButton", "MiniMapBattlefieldFrame", "MiniMapLFGFrame", "LFGMinimapFrame",
    -- windows
    "CharacterFrame", "PaperDollFrame", "SpellBookFrame", "PlayerSpellsFrame", "TalentFrame",
    "PlayerTalentFrame", "ClassTalentFrame", "QuestLogFrame", "QuestFrame", "GossipFrame", "FriendsFrame",
    "MerchantFrame", "MailFrame", "BankFrame", "LootFrame", "GameMenuFrame", "AddonList", "WorldMapFrame",
    "SettingsPanel", "InterfaceOptionsFrame", "VideoOptionsFrame", "TradeFrame", "HonorFrame",
    "ContainerFrame1", "DressUpFrame", "TaxiFrame", "ClassTrainerFrame", "TradeSkillFrame", "CraftFrame",
    "AuctionFrame", "AuctionHouseFrame", "MacroFrame", "InspectFrame", "LFGParentFrame", "PVEFrame",
    "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ChatFrame1", "ChatFrame1Tab", "ChatFrame1EditBox",
    "GeneralDockManager", "UIErrorsFrame", "StaticPopup1", "DurabilityFrame", "BuffFrame", "DebuffFrame",
    "TemporaryEnchantFrame",
}

local TEMPLATES = {     -- template -> frame type it must be created as
    ActionBarButtonTemplate = "CheckButton", ActionButtonTemplate = "CheckButton",
    PetActionButtonTemplate = "CheckButton", StanceButtonTemplate = "CheckButton",
    SecureActionButtonTemplate = "Button", SecureUnitButtonTemplate = "Button",
    UIPanelButtonTemplate = "Button", SecureHandlerStateTemplate = "Frame",
    SecureHandlerEnterLeaveTemplate = "Frame", SecureGroupHeaderTemplate = "Frame",
    SecureAuraHeaderTemplate = "Frame", BackdropTemplate = "Frame", UIPanelScrollFrameTemplate = "ScrollFrame",
}

local APIS = {
    "UnitHealthPercent", "UnitPowerPercent", "UnitHealthMissing", "UnitCastingDuration", "UnitChannelDuration",
    "UnitCastingInfo", "UnitChannelInfo", "UnitSelectionColor", "UnitInRange", "UnitGetTotalAbsorbs",
    "UnitGetDetailedHealPrediction", "CreateUnitHealPredictionCalculator", "AbbreviateNumbers",
    "RegisterUnitWatch", "RegisterStateDriver", "GetMinimapShape", "IsUsableAction", "GetActionCooldown",
    "IsActionInRange", "ActionHasRange", "GetActionTexture", "GetActionCount", "HasAction",
    "GetBonusBarOffset", "GetActionBarPage", "GetShapeshiftFormInfo", "GetNumShapeshiftForms",
    "GetPlayerMapPosition", "GetNetStats", "GetFramerate", "GetInventoryItemDurability",
    "C_Spell.GetSpellCooldownDuration", "C_Spell.GetSpellCooldown", "C_ActionBar.GetActionCooldown",
    "C_ActionBar.GetActionCooldownDuration", "C_ActionBar.IsUsableAction", "C_Secrets.ShouldAurasBeSecret",
    "C_Secrets.ShouldCooldownsBeSecret", "C_Secrets.ShouldUnitIdentityBeSecret",
    "C_Secrets.ShouldUnitHealthMaxBeSecret", "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition",
    "C_Container.GetContainerNumFreeSlots", "C_CurveUtil.CreateColorCurve", "C_DurationUtil.CreateDuration",
    "C_StringUtil.TruncateWhenZero", "C_StringUtil.WrapString", "C_EditMode.GetLayouts",
    "CurveConstants.ScaleTo100", "Enum.StatusBarInterpolation", "Enum.StatusBarTimerDirection",
}

local function Lookup(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return v
end

local function Read(ok, v)
    if not ok then return "ERR " .. tostring(v):sub(1, 80) end
    if issecret(v) then return "SECRET" end
    if v == nil then return "nil" end
    local t = type(v)
    if t == "number" or t == "boolean" or t == "string" then return v end
    return "<" .. t .. ">"
end

-- Every return value, not just the first, so multi-return APIs show which parts are secret.
local function Sample(fn, ...)
    if type(fn) ~= "function" then return "missing" end
    local res = { pcall(fn, ...) }
    if not res[1] then return Read(false, res[2]) end
    local out = {}
    for i = 2, math.max(#res, 2) do
        local r = Read(true, res[i])
        out[#out + 1] = tostring(r)
    end
    return table.concat(out, ", ")
end

local function FrameInfo(name)
    local f = _G[name]
    if f == nil then return nil end
    if type(f) ~= "table" or type(f.GetObjectType) ~= "function" then return "<non-frame>" end
    local ok, kind = pcall(f.GetObjectType, f)
    local parent = f.GetParent and f:GetParent()
    local pname = parent and parent.GetName and parent:GetName() or (parent and "<anon>" or "none")
    local shown = f.IsShown and f:IsShown()
    local protected = f.IsProtected and f:IsProtected()
    return ("%s parent=%s shown=%s protected=%s"):format(ok and kind or "?", tostring(pname), tostring(shown), tostring(protected))
end

-- Named globals worth knowing about, found by pattern rather than guessed.
local SCAN = { "^Minimap", "^MiniMap", "ActionBar", "^MultiBar", "MicroButton$", "^MainMenu", "Talent",
    "^QuestLog", "^SpellBook", "^Stance", "^PetAction", "^PlayerSpells", "^Character.*Frame$", "EditMode" }

local function ScanGlobals()
    local found = {}
    for name, v in pairs(_G) do
        if type(name) == "string" and type(v) == "table" and type(v.GetObjectType) == "function" and #name < 48 then
            for _, pat in ipairs(SCAN) do
                if name:find(pat) and not name:find("%d%d") then
                    found[#found + 1] = name
                    break
                end
            end
        end
    end
    table.sort(found)
    while #found > 500 do table.remove(found) end
    return found
end

function T:RunProbe(label)
    TempusDB.probe = TempusDB.probe or {}
    local p = TempusDB.probe
    if label == "idle" or not p.frames then
        p.client = select(4, GetBuildInfo())
        p.version = T.version
        p.frames, p.templates, p.apis = {}, {}, {}
        for _, name in ipairs(FRAMES) do p.frames[name] = FrameInfo(name) or "missing" end
        -- Look templates up instead of instantiating them: a parentless action button
        -- trips Blizzard's own OnLoad code.
        for tmpl in pairs(TEMPLATES) do
            local info = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(tmpl)
            p.templates[tmpl] = info and "ok" or "missing"
        end
        for _, api in ipairs(APIS) do
            local v = Lookup(api)
            p.apis[api] = v == nil and "missing" or type(v)
        end
        p.globals = ScanGlobals()
    end

    -- Secrecy samples, taken both out of and in combat.
    local s = {}
    local slot
    for i = 1, 120 do
        local ok, has = pcall(HasAction, i)
        if ok and has == true then slot = i break end
    end
    s.firstActionSlot = slot or "none"
    if slot then
        s.IsUsableAction = Sample(IsUsableAction, slot)
        s.GetActionCooldown = Sample(GetActionCooldown, slot)
        s.IsActionInRange = Sample(IsActionInRange, slot)
        s.GetActionTexture = Sample(GetActionTexture, slot)
        s.GetActionCount = Sample(GetActionCount, slot)
        if C_ActionBar then
            s.C_ActionBar_GetActionCooldown = Sample(C_ActionBar.GetActionCooldown, slot)
            s.C_ActionBar_GetActionCooldownDuration = Sample(C_ActionBar.GetActionCooldownDuration, slot)
        end
    end
    local curve = CurveConstants and CurveConstants.ScaleTo100
    s.UnitHealth = Sample(UnitHealth, "player")
    s.UnitHealthMax = Sample(UnitHealthMax, "player")
    s.UnitHealthPercent = Sample(UnitHealthPercent, "player", true, curve)
    s.UnitPower = Sample(UnitPower, "player")
    s.UnitPowerMax = Sample(UnitPowerMax, "player")
    s.UnitPowerPercent = Sample(UnitPowerPercent, "player", nil, false, curve)
    s.UnitName = Sample(UnitName, "player")
    s.UnitClass = Sample(UnitClass, "player")
    s.UnitLevel = Sample(UnitLevel, "player")
    s.UnitName_target = Sample(UnitName, "target")
    s.UnitReaction_target = Sample(UnitReaction, "player", "target")
    s.UnitSelectionColor_target = Sample(UnitSelectionColor, "target")
    s.UnitInRange_party1 = Sample(UnitInRange, "party1")
    s.UnitCastingInfo = Sample(UnitCastingInfo, "player")
    s.GetBonusBarOffset = Sample(GetBonusBarOffset)
    s.GetActionBarPage = Sample(GetActionBarPage)
    s.GetShapeshiftForm = Sample(GetShapeshiftForm)
    s.GetMoney = Sample(GetMoney)
    s.GetNetStats = Sample(GetNetStats)
    s.GetFramerate = Sample(GetFramerate)
    s.GetInventoryItemDurability = Sample(GetInventoryItemDurability, 5)
    s.UnitXP = Sample(UnitXP, "player")
    s.GetXPExhaustion = Sample(GetXPExhaustion)
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
        s.MapID = Read(ok, map)
        if ok and map and not issecret(map) and C_Map.GetPlayerMapPosition then
            local okp, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
            s.MapPosition = okp and pos and pos.GetXY and Sample(pos.GetXY, pos) or Read(okp, pos)
        end
    end
    if C_Secrets then
        for _, fn in ipairs({ "ShouldAurasBeSecret", "ShouldCooldownsBeSecret", "ShouldUnitIdentityBeSecret", "ShouldUnitHealthMaxBeSecret" }) do
            s["C_Secrets." .. fn] = Sample(C_Secrets[fn])
        end
    end
    if C_Spell and C_Spell.GetSpellCooldownDuration then
        s.GetSpellCooldownDuration_6603 = Sample(C_Spell.GetSpellCooldownDuration, 6603)
    end
    p[label] = s
    p[label].at = date("%H:%M:%S")
end

-- Runs only on demand now (/tempus probe); the first-run data is already collected.

----------------------------------------------------------------------------------------
-- Group probe (/tempus probe group): what party/raid frames can read on this client.
-- Samples the first group member out of combat now, and again a few seconds into the
-- next fight. Results land in TempusDB.probe.group.
----------------------------------------------------------------------------------------
local GROUP_TEMPLATES = { SecureGroupHeaderTemplate = true, SecureGroupPetHeaderTemplate = true,
    SecureRaidGroupHeaderTemplate = true, SecurePartyHeaderTemplate = true, SecureUnitButtonTemplate = true,
    PingableUnitFrameTemplate = true }
local GROUP_FRAMES = { "CompactRaidFrameManager", "CompactRaidFrameContainer", "CompactPartyFrame", "PartyFrame",
    "PartyMemberFrame1", "CompactRaidFrame1", "CompactPartyFrameMember1" }
local GROUP_APIS = { "UnitInRange", "CheckInteractDistance", "C_Spell.IsSpellInRange", "IsSpellInRange",
    "UnitGetIncomingHeals", "UnitGetTotalAbsorbs", "UnitGetTotalHealAbsorbs", "CreateUnitHealPredictionCalculator",
    "UnitGroupRolesAssigned", "UnitPhaseReason", "UnitHasIncomingResurrection", "GetReadyCheckStatus",
    "UnitIsGroupLeader", "UnitIsGroupAssistant", "C_ClickBindings", "ClickCastFrames", "C_UnitAuras.GetAuraDataByIndex",
    "AuraUtil.ForEachAura", "C_UnitAuras.GetUnitAuras", "UnitDistanceSquared", "C_PartyInfo.GetMinLevel" }

local function GroupSample(unit)
    local s = { unit = unit, at = date("%H:%M:%S"), combat = InCombatLockdown() }
    local curve = CurveConstants and CurveConstants.ScaleTo100
    s.UnitExists = Sample(UnitExists, unit)
    s.UnitName = Sample(UnitName, unit)
    s.UnitClass = Sample(UnitClass, unit)
    s.UnitHealth = Sample(UnitHealth, unit)
    s.UnitHealthMax = Sample(UnitHealthMax, unit)
    s.UnitHealthPercent = Sample(UnitHealthPercent, unit, true, curve)
    s.UnitPower = Sample(UnitPower, unit)
    s.UnitIsConnected = Sample(UnitIsConnected, unit)
    s.UnitIsDeadOrGhost = Sample(UnitIsDeadOrGhost, unit)
    s.UnitInRange = Sample(UnitInRange, unit)
    s.CheckInteractDistance = Sample(CheckInteractDistance, unit, 4)
    s.UnitDistanceSquared = Sample(UnitDistanceSquared, unit)
    s.UnitGroupRolesAssigned = Sample(UnitGroupRolesAssigned, unit)
    s.UnitGetIncomingHeals = Sample(UnitGetIncomingHeals, unit)
    s.UnitGetTotalAbsorbs = Sample(UnitGetTotalAbsorbs, unit)
    s.UnitThreatSituation = Sample(UnitThreatSituation, unit)
    s.UnitIsUnit_player = Sample(UnitIsUnit, unit, "player")
    s.UnitPhaseReason = Sample(UnitPhaseReason, unit)
    s.GetRaidTargetIndex = Sample(GetRaidTargetIndex, unit)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, "HARMFUL")
        s.debuff1 = not ok and ("ERR " .. tostring(a):sub(1, 80)) or (a == nil and "none")
            or (issecret(a) and "SECRET table") or ("spellId=" .. tostring(Read(true, a.spellId)) .. " dispel=" .. tostring(Read(true, a.dispelName)))
    end
    -- Range by a spell the player knows: the first helpful spell in the spellbook.
    if C_Spell and C_Spell.IsSpellInRange then
        for _, id in ipairs({ 2050, 2061, 774, 5185, 635, 19750, 331, 8004, 139, 17 }) do
            local okK, known = pcall(IsPlayerSpell or function() end, id)
            if okK and not issecret(known) and known == true then
                s.spellRange = id .. ": " .. tostring(Sample(C_Spell.IsSpellInRange, id, unit))
                break
            end
        end
    end
    if C_Secrets then
        for _, fn in ipairs({ "ShouldAurasBeSecret", "ShouldUnitIdentityBeSecret", "ShouldUnitHealthMaxBeSecret" }) do
            s["C_Secrets." .. fn] = Sample(C_Secrets[fn])
        end
    end
    return s
end

local function GroupUnit()
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do
            local u = "raid" .. i
            if UnitExists(u) and not UnitIsUnit(u, "player") then return u end
        end
    end
    if UnitExists("party1") then return "party1" end
end

function T:RunGroupProbe()
    TempusDB.probe = TempusDB.probe or {}
    local g = { client = select(4, GetBuildInfo()), templates = {}, frames = {}, apis = {} }
    for tmpl in pairs(GROUP_TEMPLATES) do
        local info = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(tmpl)
        g.templates[tmpl] = info and "ok" or "missing"
    end
    for _, name in ipairs(GROUP_FRAMES) do g.frames[name] = FrameInfo(name) or "missing" end
    for _, api in ipairs(GROUP_APIS) do
        local v = Lookup(api)
        g.apis[api] = v == nil and "missing" or type(v)
    end
    local unit = GroupUnit()
    g.idle = unit and GroupSample(unit) or "not in a group"
    TempusDB.probe.group = g
    if not unit then return false end
    -- One combat sample, a few seconds into the next fight.
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        C_Timer.After(3, function()
            local u = GroupUnit()
            g.combat = u and GroupSample(u) or "group left"
            T:Print("group probe: combat sample recorded. /reload to save it.")
        end)
    end)
    return true
end

----------------------------------------------------------------------------------------
-- Action bar paging and restricted-snippet facts. The "before" snapshot is taken as
-- this file loads, before Tempus moves any button.
----------------------------------------------------------------------------------------
local function ButtonFacts(b)
    if not b then return "missing" end
    local parent = b:GetParent()
    local t = {
        parent = parent and parent:GetName() or "<anon>",
        actionpage = tostring(b:GetAttribute("actionpage")),
        useparent = tostring(b:GetAttribute("useparent-actionpage")),
        type = tostring(b:GetAttribute("type")),
        actionAttr = tostring(b:GetAttribute("action")),
        field_action = tostring(b.action),
        buttonType = tostring(b.buttonType),
        bar = b.bar and b.bar.GetName and b.bar:GetName() or tostring(b.bar),
        id = b:GetID(),
    }
    if parent then
        t.parentActionpage = tostring(parent:GetAttribute("actionpage"))
        local gp = parent:GetParent()
        t.grandparent = gp and gp:GetName() or "<anon>"
        t.grandparentActionpage = gp and tostring(gp:GetAttribute("actionpage")) or "nil"
    end
    return t
end

local function PagingFacts()
    return {
        at = date("%H:%M:%S"),
        button1 = ButtonFacts(_G.ActionButton1),
        mainBarActionpage = MainActionBar and tostring(MainActionBar:GetAttribute("actionpage")) or "missing",
        GetActionBarPage = tostring(GetActionBarPage and GetActionBarPage()),
        GetBonusBarOffset = tostring(GetBonusBarOffset and GetBonusBarOffset()),
        GetShapeshiftForm = tostring(GetShapeshiftForm and GetShapeshiftForm()),
    }
end

local before = PagingFacts()

local SNIPPETS = {
    { "empty", "" },
    { "local", "local x = 1" },
    { "getattr", "local v = self:GetAttribute('x')" },
    { "setattr", "self:SetAttribute('tempus-test', 1)" },
    { "frameref", "local r = self:GetFrameRef('ref')" },
    { "childupdate", "control:ChildUpdate('tempus', 1)" },
    { "concat", "local s = 'a' .. 1" },
}

function T:RunSecureTests()
    local results = {}
    local f = CreateFrame("Frame", "TempusSecureTest", UIParent, "SecureHandlerBaseTemplate")
    f:SetFrameRef("ref", UIParent)
    for _, t in ipairs(SNIPPETS) do
        T.quietErrors = {}
        local ok, err = pcall(SecureHandlerExecute, f, t[2])
        local caught = T.quietErrors[1]
        T.quietErrors = nil
        results[t[1]] = (ok and not caught) and "ok" or ("FAIL " .. tostring(caught or err))
    end
    return results
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
watcher:SetScript("OnEvent", function(_, event)
    -- Developer data only: collected after /tempus probe turned it on, never by default.
    if not (TempusDB and TempusDB.probe and TempusDB.probe.enabled) then return end
    local p = TempusDB.probe
    TempusDB.probe = p
    if event == "PLAYER_LOGIN" then
        p.pagingBefore = before
        if not InCombatLockdown() then
            local ok, res = pcall(T.RunSecureTests, T)
            p.secureTests = ok and res or ("error " .. tostring(res))
        end
    else
        p.pagingBonus = p.pagingBonus or {}
        local facts = PagingFacts()
        p.pagingBonus[facts.GetBonusBarOffset] = facts
    end
end)

