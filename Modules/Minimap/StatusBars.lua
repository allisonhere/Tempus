-- Tempus UI: experience and reputation bars, replacing Blizzard's status tracking bars.
local _, T = ...
local S = T.Style

local XB = { bars = {} }
T.StatusBars = XB

XB.defaults = {
    hideBlizzard = true,
    xpColor = { 0.58, 0.36, 0.98 },
    restColor = { 0.25, 0.6, 1 },
    xp = { enabled = true, width = 476, height = 6, text = "HOVER", ticks = true,
        point = { "BOTTOM", "UIParent", "BOTTOM", 0, 34 } },
    rep = { enabled = true, width = 476, height = 7, text = "HOVER", ticks = false,
        point = { "BOTTOM", "UIParent", "BOTTOM", 0, 1 } },
}

local function Big(n)
    if not T.Num(n) then return "?" end
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end

----------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------
local session = { gained = 0, start = GetTime() }

local function MaxLevel()
    if IsPlayerAtEffectiveMaxLevel then
        local ok, v = pcall(IsPlayerAtEffectiveMaxLevel)
        if ok and not T.issecret(v) then return v end
    end
    local cap = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or MAX_PLAYER_LEVEL or 60
    local level = UnitLevel("player")
    return T.Num(level) and T.Num(cap) and level >= cap
end

local function XPData()
    local cur, max = UnitXP("player"), UnitXPMax("player")
    if not (T.Num(cur) and T.Num(max)) or max <= 0 then return nil end
    local rested = GetXPExhaustion()
    return { cur = cur, max = max, rested = T.Num(rested) and rested or 0, level = UnitLevel("player") }
end

local function RepData()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local ok, d = pcall(C_Reputation.GetWatchedFactionData)
        if ok and type(d) == "table" and T.Str(d.name) then
            local minV, maxV, value = d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding
            if T.Num(minV) and T.Num(maxV) and T.Num(value) then
                return { name = d.name, standing = d.reaction, min = minV, max = maxV, value = value }
            end
        end
    end
    if GetWatchedFactionInfo then
        local name, standing, minV, maxV, value = GetWatchedFactionInfo()
        if T.Str(name) and T.Num(minV) and T.Num(maxV) and T.Num(value) then
            return { name = name, standing = standing, min = minV, max = maxV, value = value }
        end
    end
end

----------------------------------------------------------------------------------------
-- Bars
----------------------------------------------------------------------------------------
local function CreateBar(key)
    local f = CreateFrame("Button", "TempusStatusBar_" .. key, UIParent)
    f:SetFrameStrata("LOW")
    f.bd = S.Backdrop(f, { fill = { 0.04, 0.045, 0.058, 0.9 } })
    f.rested = CreateFrame("StatusBar", nil, f)
    f.rested:SetAllPoints()
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetAllPoints()
    f.bar:SetFrameLevel(f.rested:GetFrameLevel() + 1)
    f.spark = f.bar:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    f.spark:SetBlendMode("ADD")
    f.spark:SetPoint("CENTER", f.bar:GetStatusBarTexture(), "RIGHT")
    local over = CreateFrame("Frame", nil, f)
    over:SetAllPoints()
    over:SetFrameLevel(f.bar:GetFrameLevel() + 2)
    f.ticks = {}
    for i = 1, 9 do
        local t = S.Tex(over, "ARTWORK", { 0, 0, 0, 0.45 })
        t:SetWidth(1)
        f.ticks[i] = t
    end
    f.text = over:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.key = key
    f:RegisterForClicks("AnyUp")
    f:SetScript("OnEnter", function(self)
        self.hover = true
        XB:UpdateText(self)
        XB:Tooltip(self)
    end)
    f:SetScript("OnLeave", function(self)
        self.hover = false
        XB:UpdateText(self)
        GameTooltip:Hide()
    end)
    f:SetScript("OnClick", function(self)
        if self.key == "rep" and ToggleCharacter then ToggleCharacter("ReputationFrame") end
    end)
    XB.bars[key] = f
    T.Movers:Register(f, {
        label = key == "xp" and "Experience Bar" or "Reputation Bar", page = "statusbars",
        cfg = function() return XB.db[key] end,
        corner = function() return XB.db[key].point[1] end,
        enabled = function() return XB.db[key].enabled end,
    })
    return f
end

function XB:UpdateText(f)
    local cfg = XB.db[f.key]
    local show = cfg.text == "ALWAYS" or (cfg.text == "HOVER" and f.hover)
    f.text:SetShown(show)
    if not show then return end
    if f.key == "xp" then
        local d = XPData()
        if not d then f.text:SetText("") return end
        local rest = d.rested > 0 and ("  |cff66b3ffrested %d%%|r"):format(math.floor(d.rested / d.max * 100)) or ""
        f.text:SetFormattedText("%s / %s  |cff%s%.1f%%|r%s", Big(d.cur), Big(d.max), T.accentHex, d.cur / d.max * 100, rest)
    else
        local r = RepData()
        if not r then f.text:SetText("") return end
        local label = _G["FACTION_STANDING_LABEL" .. tostring(r.standing)] or ""
        local span = math.max(r.max - r.min, 1)
        f.text:SetFormattedText("%s  |cffb0b8c8%s|r  %s / %s", r.name, label, Big(r.value - r.min), Big(span))
    end
end

function XB:Tooltip(f)
    GameTooltip:SetOwner(f, "ANCHOR_TOP", 0, 6)
    GameTooltip:ClearLines()
    if f.key == "xp" then
        local d = XPData()
        if not d then return end
        GameTooltip:AddLine(("Experience  -  level %s"):format(tostring(d.level)), 1, 1, 1)
        GameTooltip:AddDoubleLine("Current", ("%s / %s (%.1f%%)"):format(Big(d.cur), Big(d.max), d.cur / d.max * 100), 0.7, 0.75, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine("To next level", Big(d.max - d.cur), 0.7, 0.75, 0.8, 1, 1, 1)
        if d.rested > 0 then
            GameTooltip:AddDoubleLine("Rested", ("%s (%d%%)"):format(Big(d.rested), math.floor(d.rested / d.max * 100)), 0.7, 0.75, 0.8, 0.4, 0.7, 1)
        end
        local elapsed = GetTime() - session.start
        if session.gained > 0 and elapsed > 60 then
            local perHour = session.gained / elapsed * 3600
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Gained this session", Big(math.floor(session.gained)), 0.7, 0.75, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine("Per hour", Big(math.floor(perHour)), 0.7, 0.75, 0.8, 1, 1, 1)
            if perHour > 0 and SecondsToTime then
                GameTooltip:AddDoubleLine("Time to level", SecondsToTime((d.max - d.cur) / perHour * 3600), 0.7, 0.75, 0.8, 1, 1, 1)
            end
        end
    else
        local r = RepData()
        if not r then return end
        local label = _G["FACTION_STANDING_LABEL" .. tostring(r.standing)] or ""
        GameTooltip:AddLine(r.name, 1, 1, 1)
        GameTooltip:AddDoubleLine("Standing", label, 0.7, 0.75, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine("Progress", ("%s / %s"):format(Big(r.value - r.min), Big(math.max(r.max - r.min, 1))), 0.7, 0.75, 0.8, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click: reputation", 0.5, 0.8, 1)
    end
    GameTooltip:Show()
end

local lastXP, lastMax
function XB:Update()
    local db = XB.db
    local xp = XB.bars.xp
    local d = XPData()
    local showXP = db.xp.enabled and d and not MaxLevel()
    xp:SetShown(showXP and true or false)
    if showXP then
        if lastXP then
            if d.cur >= lastXP then session.gained = session.gained + (d.cur - lastXP)
            elseif lastMax then session.gained = session.gained + (lastMax - lastXP) + d.cur end
        end
        lastXP, lastMax = d.cur, d.max
        xp.bar:SetMinMaxValues(0, d.max)
        xp.bar:SetValue(d.cur)
        xp.rested:SetMinMaxValues(0, d.max)
        xp.rested:SetValue(math.min(d.max, d.cur + d.rested))
        xp.rested:SetShown(d.rested > 0)
        xp.spark:SetShown(d.cur > 0 and d.cur < d.max)
        XB:UpdateText(xp)
    end

    local rep = XB.bars.rep
    local r = RepData()
    local showRep = db.rep.enabled and r ~= nil
    rep:SetShown(showRep and true or false)
    if showRep then
        local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[r.standing] or { r = 0.3, g = 0.7, b = 0.3 }
        rep.bar:SetMinMaxValues(r.min, math.max(r.max, r.min + 1))
        rep.bar:SetValue(r.value)
        rep.bar:SetStatusBarColor(c.r, c.g, c.b)
        rep.rested:Hide()
        rep.spark:SetShown(r.value > r.min and r.value < r.max)
        XB:UpdateText(rep)
    end
end

function XB:Layout()
    local db = XB.db
    local tex = S.BarTexture(T.db.barTexture)
    for key, f in pairs(XB.bars) do
        local cfg = db[key]
        f:SetSize(cfg.width, cfg.height)
        T.Movers.ApplyPoint(f, cfg)
        f.bar:SetStatusBarTexture(tex)
        f.rested:SetStatusBarTexture(tex)
        f.spark:SetSize(10, cfg.height * 2.4)
        S.ApplyFont(f.text, math.max(9, math.min(cfg.height + 4, 12)))
        for i, t in ipairs(f.ticks) do
            t:ClearAllPoints()
            t:SetPoint("TOP", f, "TOPLEFT", cfg.width * i / 10, 0)
            t:SetPoint("BOTTOM", f, "BOTTOMLEFT", cfg.width * i / 10, 0)
            t:SetShown(cfg.ticks)
        end
    end
    local c, rc = db.xpColor, db.restColor
    XB.bars.xp.bar:SetStatusBarColor(c[1], c[2], c[3])
    XB.bars.xp.rested:SetStatusBarColor(rc[1], rc[2], rc[3], 0.45)
    XB:Update()
end

-- Blizzard's bars stay in their Edit Mode container (it calls layout methods on their
-- parent); they are made invisible and mouse-transparent instead of being moved.
local function MouseOff(f, depth)
    if depth > 4 or (f.IsForbidden and f:IsForbidden()) then return end
    if f.EnableMouse and not (f.IsProtected and f:IsProtected()) then pcall(f.EnableMouse, f, false) end
    for _, child in ipairs({ f:GetChildren() }) do MouseOff(child, depth + 1) end
end

local function SoftHide(f)
    if f.tempusSoftHidden then return end
    f.tempusSoftHidden = true
    f:SetAlpha(0)
    hooksecurefunc(f, "SetAlpha", function(self, a) if a and a > 0 then self:SetAlpha(0) end end)
    MouseOff(f, 0)
    -- Bars created or re-enabled later get their mouse turned off again.
    hooksecurefunc(f, "Show", function(self) MouseOff(self, 0) end)
end

function XB:HideBlizzard()
    if not XB.db.hideBlizzard or XB.blizzHidden then return end
    XB.blizzHidden = true
    for _, name in ipairs({ "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "MainMenuExpBar", "ReputationWatchBar" }) do
        local f = _G[name]
        if f and not (f.IsProtected and f:IsProtected()) then pcall(SoftHide, f) end
    end
end

T:NewModule("statusbars", {
    label = "XP & Reputation Bars",
    desc = "Tempus experience bar (with rested XP, XP per hour and time to level) and reputation bar for your watched faction.",
    defaults = XB.defaults,
    OnEnable = function()
        XB.db = T.db.statusbars
        CreateBar("xp")
        CreateBar("rep")
        local ev = CreateFrame("Frame")
        for _, e in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
            "UPDATE_FACTION", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN" }) do
            pcall(ev.RegisterEvent, ev, e)
        end
        ev:SetScript("OnEvent", function() XB:Update() end)
        XB:HideBlizzard()
        XB:Layout()
    end,
    OnSettings = function()
        XB.db = T.db.statusbars
        XB:HideBlizzard()
        XB:Layout()
    end,
})

T:RegisterPage("minimap", { key = "statusbars", label = "XP & Reputation", order = 3, build = function(p)
    local UI = T.UI
    local db = function() return T.db.statusbars end
    p:Section("Experience & reputation bars", "Hover a bar for details: XP per hour and time to level, or your watched faction's standing. Click the reputation bar to open reputations. Watch a faction from the reputation window to show its bar.")
    p:Check(db, "hideBlizzard", "Hide Blizzard's XP/reputation bars", "Turning this off takes effect after /reload.")
    p:Color(db, "xpColor", "Experience colour")
    p:Color(db, "restColor", "Rested colour")
    for _, key in ipairs({ "xp", "rep" }) do
        local cfg = function() return T.db.statusbars[key] end
        p:Section(key == "xp" and "Experience bar" or "Reputation bar")
        p:Check(cfg, "enabled", "Enabled")
        p:Check(cfg, "ticks", "Tick marks every 10%")
        p:Slider(cfg, "width", "Width", 100, 1600, 2)
        p:Slider(cfg, "height", "Height", 3, 24, 1)
        p:Dropdown(cfg, "text", "Text", { { "HOVER", "On mouseover" }, { "ALWAYS", "Always" }, { "NONE", "Hidden" } })
        p:Newline()
        p:Add(UI.W.Button("Reset position", function()
            T.db.statusbars[key].point = T.CopyTable(XB.defaults[key].point)
            UI.Changed()
        end))
    end
end })
