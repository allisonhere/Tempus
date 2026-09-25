-- Tempus UI: party and raid frames. Blizzard's secure group headers own the buttons, so
-- the roster reorders even in combat; Tempus draws everything on a plain child frame of
-- each button. Health, range and incoming heals are secret on this client: they flow
-- straight into bars, text and SetAlphaFromBoolean, and auras come from aura containers.
local _, T = ...
local S = T.Style
local issecret = T.issecret

local GF = { buttons = {}, version = 0 }
T.GroupFrames = GF

GF.defaults = {
    hideBlizzard = true,
    healthColor = "CLASS",      -- CLASS | DARK | GRADIENT
    healthText = "NONE",        -- NONE | PERCENT
    fontSize = 11,
    smooth = true,
    rangeAlpha = 0.4,
    healPrediction = true, absorbs = true,
    aggro = true, targetHighlight = true,
    roleIcon = true, leaderIcon = true, raidIcon = true, readyCheck = true,
    powerHeight = 4, manaOnly = true,
    dispel = true, dispelTint = true,
    debuffs = true, debuffSize = 18, debuffMax = 3,
    buffs = true, buffSize = 14, buffMax = 3,
    -- Bindings are per class; a class's starting set is copied in once (see seeded).
    clickcast = { enabled = true, hints = true, bindings = {}, seeded = {} },
    party = { enabled = true, width = 130, height = 46, spacing = 4, growth = "DOWN", showPlayer = true, showSolo = false,
        point = { "TOPLEFT", "UIParent", "TOPLEFT", 30, -300 } },
    raid = { enabled = true, width = 84, height = 42, spacing = 3, groupBy = "GROUP", growth = "COLUMNS", sampleSize = 20,
        point = { "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 30, 260 } },
}

----------------------------------------------------------------------------------------
-- Safe reads
----------------------------------------------------------------------------------------
local function Bool(fn, ...)
    if not fn then return false end
    local ok, v = pcall(fn, ...)
    return ok and not issecret(v) and v and true or false
end

local function Plain(fn, ...)
    if not fn then return nil end
    local ok, v, v2 = pcall(fn, ...)
    if not ok or issecret(v) then return nil end
    return v, (not issecret(v2)) and v2 or nil
end

local CURVE100 = CurveConstants and CurveConstants.ScaleTo100
local SMOOTH = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

local function SetBarValue(bar, v)
    if GF.db.smooth and SMOOTH and pcall(bar.SetValue, bar, v, SMOOTH) then return end
    bar:SetValue(v)
end

-- Health fraction (0-1) -> red / yellow / green.
local gradientCurve
local function GradientCurve()
    if gradientCurve ~= nil then return gradientCurve end
    gradientCurve = false
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType then
        local ok, c = pcall(function()
            local c = C_CurveUtil.CreateColorCurve()
            c:SetType(Enum.LuaCurveType.Linear)
            c:AddPoint(0, CreateColor(0.9, 0.15, 0.15, 1))
            c:AddPoint(0.5, CreateColor(0.95, 0.8, 0.15, 1))
            c:AddPoint(1, CreateColor(0.2, 0.8, 0.3, 1))
            return c
        end)
        if ok then gradientCurve = c end
    end
    return gradientCurve
end

local ROLE_COORDS = {
    TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}
local READY_TEX = {
    ready = "Interface\\RaidFrame\\ReadyCheck-Ready",
    notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

----------------------------------------------------------------------------------------
-- Visuals. Everything lives on a plain frame over the secure button, so it can change in
-- combat (fading, colours, icons) without touching the protected button.
----------------------------------------------------------------------------------------
local function Overlay(parent, texture)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(texture)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

local function BuildContent(b)
    local c = CreateFrame("Frame", nil, b)
    c:SetAllPoints(b)
    b.content = c
    c.bd = S.Backdrop(c, { fill = { 0.03, 0.035, 0.045, 1 } })

    c.health = S.StatusBar(c)
    c.health:SetClipsChildren(true)
    -- Incoming heals and absorbs start where the health fill ends and are clipped by the bar.
    c.heal = Overlay(c.health, S.WHITE)
    c.heal:SetStatusBarColor(0.3, 0.95, 0.45, 0.45)
    c.absorb = Overlay(c.health, S.WHITE)
    c.absorb:SetStatusBarColor(0.85, 0.9, 1, 0.5)
    c.power = S.StatusBar(c)

    local over = CreateFrame("Frame", nil, c)
    over:SetAllPoints(c)
    over:SetFrameLevel(c:GetFrameLevel() + 6)
    c.over = over
    c.name = over:CreateFontString(nil, "OVERLAY")
    c.name:SetWordWrap(false)
    c.status = over:CreateFontString(nil, "OVERLAY")
    c.role = over:CreateTexture(nil, "OVERLAY")
    c.role:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    c.leader = over:CreateTexture(nil, "OVERLAY")
    c.raidIcon = over:CreateTexture(nil, "OVERLAY")
    c.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    c.ready = over:CreateTexture(nil, "OVERLAY")
    c.rez = over:CreateTexture(nil, "OVERLAY")
    c.rez:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
    for _, t in ipairs({ c.role, c.leader, c.raidIcon, c.ready, c.rez }) do t:Hide() end

    c.aggro = S.CreateBorder(over, "OVERLAY", 6)
    c.aggro:SetThickness(2, c)
    c.aggro:SetShown(false)
    c.target = S.CreateBorder(over, "OVERLAY", 7)
    c.target:SetThickness(1, c)
    c.target:SetColor(1, 1, 1, 0.9)
    c.target:SetShown(false)
    c.auras = {}
    return c
end

function GF:Layout(b, cfg)
    local c, db = b.content, GF.db
    local w, h = cfg.width, cfg.height
    local tex = S.BarTexture(T.db.barTexture)
    local ph = c.showPower and db.powerHeight or 0
    c.health:ClearAllPoints()
    c.health:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    c.health:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
    c.health:SetHeight(ph > 0 and (h - ph - 1) or h)
    c.health:SetStatusBarTexture(tex)
    c.health.bg:SetTexture(tex)
    for _, o in ipairs({ c.heal, c.absorb }) do
        o:ClearAllPoints()
        o:SetWidth(w)
        o:SetPoint("TOP")
        o:SetPoint("BOTTOM")
    end
    c.heal:SetPoint("LEFT", c.health:GetStatusBarTexture(), "RIGHT")
    c.absorb:SetPoint("LEFT", c.heal:GetStatusBarTexture(), "RIGHT")
    c.power:ClearAllPoints()
    c.power:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
    c.power:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
    c.power:SetHeight(math.max(ph, 1))
    c.power:SetShown(ph > 0)
    c.power:SetStatusBarTexture(tex)
    c.power.bg:SetTexture(tex)

    local fs = db.fontSize
    S.ApplyFont(c.name, fs)
    S.ApplyFont(c.status, math.max(fs - 1, 8))
    c.name:ClearAllPoints()
    c.name:SetPoint("CENTER", c.health, "CENTER", 0, db.healthText ~= "NONE" and (fs / 2 + 1) or 0)
    c.name:SetWidth(w - 8)
    c.status:ClearAllPoints()
    c.status:SetPoint("TOP", c.name, "BOTTOM", 0, -1)

    local icon = math.max(10, math.min(16, math.floor(h / 3)))
    c.role:SetSize(icon, icon)
    c.role:ClearAllPoints()
    c.role:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -2)
    c.leader:SetSize(icon, icon)
    c.leader:ClearAllPoints()
    c.leader:SetPoint("BOTTOMLEFT", c.role, "BOTTOMRIGHT", 1, 0)
    c.raidIcon:SetSize(icon + 2, icon + 2)
    c.raidIcon:ClearAllPoints()
    c.raidIcon:SetPoint("CENTER", c, "TOP", 0, -1)
    c.ready:SetSize(h * 0.55, h * 0.55)
    c.ready:ClearAllPoints()
    c.ready:SetPoint("CENTER", c.health, "CENTER")
    c.rez:SetSize(h * 0.55, h * 0.55)
    c.rez:ClearAllPoints()
    c.rez:SetPoint("CENTER", c.health, "CENTER")
    c.layoutVersion = GF.version
end

----------------------------------------------------------------------------------------
-- Element updates
----------------------------------------------------------------------------------------
local function UnitColor(unit)
    local _, class = Plain(UnitClass, unit)
    if type(class) == "string" then return S.ClassColor(class) end
    return 0.4, 0.75, 0.4
end

local function UpdateHealth(b)
    local c, unit, db = b.content, b.unit, GF.db
    local hp = c.health
    local pct, havePct
    if UnitHealthPercent and CURVE100 then
        local ok, v = pcall(UnitHealthPercent, unit, true, CURVE100)
        if ok and (issecret(v) or v ~= nil) then pct, havePct = v, true end
    end
    if havePct then
        hp:SetMinMaxValues(0, 100)
        SetBarValue(hp, pct)
    else
        local okM, maxV = pcall(UnitHealthMax, unit)
        local okC, cur = pcall(UnitHealth, unit)
        if okM and okC then
            hp:SetMinMaxValues(0, maxV)
            SetBarValue(hp, cur)
        end
    end

    local dead = Bool(UnitIsDeadOrGhost, unit)
    local offline = not Bool(UnitIsConnected, unit)
    local r, g, bl = UnitColor(unit)
    if dead or offline then
        hp:SetStatusBarColor(0.3, 0.3, 0.3)
        hp.bg:SetVertexColor(0.12, 0.12, 0.12, 0.9)
    elseif db.healthColor == "DARK" then
        hp:SetStatusBarColor(0.13, 0.14, 0.16)
        hp.bg:SetVertexColor(r * 0.55, g * 0.55, bl * 0.55, 0.95)
    elseif db.healthColor == "GRADIENT" and GradientCurve() and UnitHealthPercent then
        if not pcall(function() hp:SetStatusBarColor(UnitHealthPercent(unit, true, gradientCurve):GetRGB()) end) then
            hp:SetStatusBarColor(r, g, bl)
        end
        hp.bg:SetVertexColor(0.08, 0.09, 0.11, 0.9)
    else
        hp:SetStatusBarColor(r, g, bl)
        hp.bg:SetVertexColor(r * 0.18, g * 0.18, bl * 0.18, 0.9)
    end
    if db.healthColor == "DARK" then c.name:SetTextColor(r, g, bl) else c.name:SetTextColor(1, 1, 1) end

    if offline then
        c.status:SetText("Offline")
    elseif dead then
        c.status:SetText(Bool(UnitIsGhost, unit) and "Ghost" or "Dead")
    elseif db.healthText == "PERCENT" and havePct then
        if not pcall(c.status.SetFormattedText, c.status, "%.0f%%", pct) then c.status:SetText("") end
    else
        c.status:SetText("")
    end
    c.status:SetTextColor(0.8, 0.83, 0.9)
end

-- Incoming heals and absorbs share the health bar's scale (raw max health, which this
-- client leaves readable); the amounts themselves may be secret and go straight in.
local function UpdatePrediction(b)
    local c, unit, db = b.content, b.unit, GF.db
    local maxV = Plain(UnitHealthMax, unit)
    local okMax = T.Num(maxV) and maxV > 0
    local function Fill(bar, on, fn)
        if not (on and okMax and fn) then bar:Hide() return end
        local ok, v = pcall(fn, unit)
        if not ok or (not issecret(v) and v == nil) then bar:Hide() return end
        bar:SetMinMaxValues(0, maxV)
        bar:SetValue(v)
        bar:Show()
    end
    Fill(c.heal, db.healPrediction, UnitGetIncomingHeals)
    Fill(c.absorb, db.absorbs, UnitGetTotalAbsorbs)
end

local function UpdatePower(b)
    local c, unit, db = b.content, b.unit, GF.db
    local want = db.powerHeight > 0
    if want and db.manaOnly then
        local ptype = Plain(UnitPowerType, unit)
        want = ptype == ((Enum and Enum.PowerType and Enum.PowerType.Mana) or 0)
    end
    if want ~= c.showPower then
        c.showPower = want
        GF:Layout(b, b.cfg)
    end
    if not want then return end
    local okM, maxV = pcall(UnitPowerMax, unit)
    local okC, cur = pcall(UnitPower, unit)
    if okM and okC then
        c.power:SetMinMaxValues(0, maxV)
        SetBarValue(c.power, cur)
    end
    local _, token = Plain(UnitPowerType, unit)
    local pc = type(token) == "string" and PowerBarColor and PowerBarColor[token]
    local r, g, bl = pc and pc.r or 0.3, pc and pc.g or 0.5, pc and pc.b or 0.95
    c.power:SetStatusBarColor(r, g, bl)
    c.power.bg:SetVertexColor(r * 0.2, g * 0.2, bl * 0.2, 0.9)
end

local function UpdateName(b)
    if not pcall(b.content.name.SetText, b.content.name, UnitName(b.unit)) then b.content.name:SetText("") end
end

local function UpdateRange(b)
    local c = b.content
    if Bool(UnitIsUnit, b.unit, "player") or not UnitInRange then c:SetAlpha(1) return end
    local ok, inRange, checked = pcall(UnitInRange, b.unit)
    if not ok then c:SetAlpha(1) return end
    if issecret(inRange) then
        if c.SetAlphaFromBoolean then pcall(c.SetAlphaFromBoolean, c, inRange, 1, GF.db.rangeAlpha) end
    elseif checked == false then
        c:SetAlpha(1)       -- the client did not check (e.g. same unit as another token)
    else
        c:SetAlpha(inRange and 1 or GF.db.rangeAlpha)
    end
end

local function UpdateThreat(b)
    local c = b.content
    local status = GF.db.aggro and Plain(UnitThreatSituation, b.unit)
    if T.Num(status) and status >= 2 then
        c.aggro:SetColor(1, 0.15, 0.15, 1)
        c.aggro:SetShown(true)
    elseif T.Num(status) and status == 1 then
        c.aggro:SetColor(1, 0.65, 0.1, 1)
        c.aggro:SetShown(true)
    else
        c.aggro:SetShown(false)
    end
end

local function UpdateTarget(b)
    b.content.target:SetShown(GF.db.targetHighlight and Bool(UnitIsUnit, b.unit, "target"))
end

local function UpdateIcons(b)
    local c, unit, db = b.content, b.unit, GF.db
    local role = db.roleIcon and Plain(UnitGroupRolesAssigned, unit)
    local coords = role and ROLE_COORDS[role]
    if coords then
        c.role:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        c.role:Show()
    else
        c.role:Hide()
    end
    if db.leaderIcon and Bool(UnitIsGroupLeader, unit) then
        c.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        c.leader:Show()
    elseif db.leaderIcon and Bool(UnitIsGroupAssistant, unit) then
        c.leader:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
        c.leader:Show()
    else
        c.leader:Hide()
    end
    local idx = db.raidIcon and Plain(GetRaidTargetIndex, unit)
    if idx then
        SetRaidTargetIconTexture(c.raidIcon, idx)
        c.raidIcon:Show()
    else
        c.raidIcon:Hide()
    end
    c.rez:SetShown(Bool(UnitHasIncomingResurrection, unit))
end

local function UpdateReady(b, finished)
    local c = b.content
    local status = GF.db.readyCheck and Plain(GetReadyCheckStatus, b.unit)
    if status and READY_TEX[status] then
        c.ready:SetTexture(READY_TEX[status])
        c.ready:Show()
        c.readyHideAt = finished and (GetTime() + 6) or nil
    elseif not finished then
        c.ready:Hide()
    end
end

----------------------------------------------------------------------------------------
-- Auras: aura containers, drawn and updated by the client (auras are secret in combat).
--   dispel: debuffs you can remove, with a dispel-coloured border and optional frame tint
--   debuffs: other debuffs the game flags for group frames
--   buffs: your own buffs and HoTs, with timers
----------------------------------------------------------------------------------------
local auraRegions = setmetatable({}, { __mode = "k" })

local function StyleAura(b, g, button)
    local r = auraRegions[button]
    if not r then
        r = {}
        r.bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
        r.bg:SetTexture(S.WHITE)
        r.bg:SetVertexColor(0, 0, 0, 1)
        r.border = button:CreateTexture(nil, "BACKGROUND", nil, -6)
        r.icon = button:CreateTexture(nil, "ARTWORK")
        button:SetIcon(r.icon)
        r.cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        r.cd:SetReverse(true)
        r.cd:SetDrawEdge(false)
        if r.cd.SetDrawBling then r.cd:SetDrawBling(false) end
        if r.cd.SetHideCountdownNumbers then r.cd:SetHideCountdownNumbers(true) end
        r.cd.noCooldownCount = true
        r.over = CreateFrame("Frame", nil, button)
        r.over:SetAllPoints(button)
        r.timer = r.over:CreateFontString(nil, "OVERLAY")
        r.count = r.over:CreateFontString(nil, "OVERLAY")
        if C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
            local ok, bind = pcall(C_DurationUtil.CreateDurationTextBinding)
            if ok and bind then
                pcall(bind.SetFontString, bind, r.timer)
                r.binding = bind
            end
        end
        if g.key == "dispel" then
            -- A tint over the whole health bar in the dispel colour, drawn by the client.
            r.tint = button:CreateTexture(nil, "ARTWORK", nil, -1)
            r.tint:SetTexture(S.WHITE)
        end
        auraRegions[button] = r
    end
    local size = g.size
    button:SetSize(size, size)
    if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
    r.bg:SetAllPoints(button)
    r.border:ClearAllPoints()
    r.border:SetAllPoints(button)
    r.icon:ClearAllPoints()
    r.icon:SetPoint("TOPLEFT", 1, -1)
    r.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.cd:ClearAllPoints()
    r.cd:SetAllPoints(r.icon)
    r.cd:SetSwipeColor(0, 0, 0, 0.6)
    pcall(button.SetDurationCooldown, button, r.cd)
    r.over:SetFrameLevel(button:GetFrameLevel() + 5)
    S.ApplyFont(r.timer, math.max(7, math.floor(size * 0.5)))
    S.ApplyFont(r.count, math.max(7, math.floor(size * 0.45)))
    r.timer:ClearAllPoints()
    r.timer:SetPoint("CENTER", r.icon, "CENTER", 1, 0)
    r.timer:SetShown(g.key == "buffs" or size >= 16)
    r.count:ClearAllPoints()
    r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, 0)
    pcall(button.ClearDurationText, button)
    if r.binding then
        if T.nativeFormatter then pcall(r.binding.SetFormatter, r.binding, T.nativeFormatter) end
        pcall(button.SetDurationText, button, r.timer, { binding = r.binding })
    else
        pcall(button.SetDurationText, button, r.timer, { textFormatter = T.nativeFormatter })
    end
    pcall(button.SetApplicationCount, button, r.count, {})
    pcall(button.ClearDispelTypeTextures, button)
    local harmful = g.key ~= "buffs"
    pcall(button.AddDispelTypeTexture, button, r.border, { showWhenHarmful = harmful, showWhenHelpful = not harmful })
    if r.tint then
        r.tint:ClearAllPoints()
        r.tint:SetAllPoints(b.content.health)
        r.tint:SetAlpha(0.3)
        r.tint:SetShown(GF.db.dispelTint)
        if GF.db.dispelTint then
            pcall(button.AddDispelTypeTexture, button, r.tint, { showWhenHarmful = true, showWhenHelpful = false })
        end
    end
end

local function AuraGroups()
    local db = GF.db
    local groups = {}
    if db.dispel then
        groups.dispel = { key = "dispel", filter = "HARMFUL|RAID_PLAYER_DISPELLABLE", size = db.debuffSize + 2, max = 1,
            corner = "BOTTOMRIGHT", growX = "LEFT" }
    end
    if db.debuffs then
        groups.debuffs = { key = "debuffs", filter = db.dispel and "HARMFUL|RAID|!RAID_PLAYER_DISPELLABLE" or "HARMFUL|RAID",
            fallback = "HARMFUL", size = db.debuffSize, max = db.debuffMax, corner = "BOTTOMLEFT", growX = "RIGHT" }
    end
    if db.buffs then
        groups.buffs = { key = "buffs", filter = "HELPFUL|PLAYER", size = db.buffSize, max = db.buffMax,
            corner = "TOPRIGHT", growX = "LEFT" }
    end
    return groups
end

local function AnchorGroup(b, g, c)
    local content = b.content
    c:ClearAllPoints()
    if g.key == "dispel" then
        -- Bottom right: clear of the centred name, the debuffs (bottom left) and HoTs (top right).
        c:SetPoint("BOTTOMRIGHT", content.health, "BOTTOMRIGHT", -2, 2)
    elseif g.key == "debuffs" then
        c:SetPoint("BOTTOMLEFT", content.health, "BOTTOMLEFT", 2, 2)
    else
        c:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -2)
    end
end

local function ConfigureAuras(b)
    local FD = AnchorUtil.FlowDirection
    local SM = rawget(_G, "AuraContainerSortMethod") or { Default = 1 }
    local SD = rawget(_G, "AuraContainerSortDirection") or { Normal = 1 }
    local content = b.content
    for key, c in pairs(content.auras) do
        if not GF.groups[key] then c:SetEnabled(false); c:Hide() end
    end
    for key, g in pairs(GF.groups) do
        local c = content.auras[key]
        if not c then
            c = CreateFrame("AuraContainer", nil, content.over, "CustomAuraContainerTemplate")
            c.buttons = setmetatable({}, { __mode = "k" })
            content.auras[key] = c
        end
        c.group = g
        c:SetEnabled(false)
        c:SetSize(g.size, g.size)
        AnchorGroup(b, g, c)
        local corner = g.corner
        c:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
        c:SetFlowLayoutAnchorPoint(corner)
        c:SetFlowLayoutGrowthDirection(g.growX == "LEFT" and FD.Left or FD.Right, FD.Up)
        c:SetFlowLayoutMaximumLineSize(g.max * g.size + (g.max - 1) * 1)
        local options = {
            maxFrameCount = g.max, sortMethod = SM.Default, sortDirection = SD.Normal,
            initializeFrame = function(button)
                c.buttons[button] = true
                StyleAura(b, c.group, button)
            end,
            layout = { elementWidth = g.size, elementHeight = g.size, elementSpacing = 1, lineSpacing = 1 },
        }
        if c:HasAuraGroup("g") then
            if not pcall(c.SetAuraGroupFilterString, c, "g", g.filter) and g.fallback then
                pcall(c.SetAuraGroupFilterString, c, "g", g.fallback)
            end
            pcall(c.SetAuraGroupMaxFrameCount, c, "g", g.max)
            pcall(c.SetAuraGroupLayout, c, "g", options.layout)
        elseif not pcall(c.AddAuraGroup, c, "g", g.filter, options) and g.fallback then
            pcall(c.AddAuraGroup, c, "g", g.fallback, options)
        end
        -- Aura buttons can't be asked for their parent; each container keeps its own list.
        for button in pairs(c.buttons) do pcall(StyleAura, b, g, button) end
    end
    content.auraVersion = GF.version
end

local function AttachAuras(b)
    if not GF.aurasOK then return end
    local content = b.content
    if content.auraVersion ~= GF.version then
        local ok, err = pcall(ConfigureAuras, b)
        if not ok then T:ReportError("group auras: " .. tostring(err)) return end
    end
    for key, c in pairs(content.auras) do
        if b.unit and GF.groups[key] then
            -- Same token again would add a second copy of every aura; the container
            -- follows its token by itself.
            if c.tempusUnit ~= b.unit and pcall(c.SetUnit, c, b.unit) then c.tempusUnit = b.unit end
            c:Show()
            c:SetEnabled(true)
        else
            c:SetEnabled(false)
            c:Hide()
        end
    end
end

----------------------------------------------------------------------------------------
-- Per-button events: a plain frame per button listens for its own unit, re-registered
-- whenever the header gives the button a different unit.
----------------------------------------------------------------------------------------
local UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_NAME_UPDATE",
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_HEAL_PREDICTION",
    "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_IN_RANGE_UPDATE",
    "INCOMING_RESURRECT_CHANGED", "UNIT_PHASE",
}

local function UpdateAll(b)
    if not b.unit or not Bool(UnitExists, b.unit) then return end
    if b.content.layoutVersion ~= GF.version then GF:Layout(b, b.cfg) end
    UpdateName(b)
    UpdatePower(b)
    UpdateHealth(b)
    UpdatePrediction(b)
    UpdateRange(b)
    UpdateThreat(b)
    UpdateTarget(b)
    UpdateIcons(b)
    UpdateReady(b)
end

local function OnUnitEvent(ev, event)
    local b = ev.button
    if not b.unit then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
        UpdateHealth(b)
        UpdatePrediction(b)
    elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        UpdatePrediction(b)
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        UpdatePower(b)
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
        UpdateThreat(b)
    elseif event == "UNIT_IN_RANGE_UPDATE" or event == "UNIT_PHASE" then
        UpdateRange(b)
    elseif event == "INCOMING_RESURRECT_CHANGED" then
        UpdateIcons(b)
    else
        UpdateAll(b)
    end
end

local function SetUnit(b, unit)
    if unit == b.unit then return end
    b.unit = unit
    local ev = b.ev
    ev:UnregisterAllEvents()
    if unit then
        for _, e in ipairs(UNIT_EVENTS) do pcall(ev.RegisterUnitEvent, ev, e, unit) end
        UpdateAll(b)
    end
    AttachAuras(b)
end

----------------------------------------------------------------------------------------
-- Click-casting: mouse button + modifier -> spell, set as secure click attributes on each
-- button (out of combat only). Off while Clique is loaded, which does the same job.
----------------------------------------------------------------------------------------
GF.clickButtons = { { "1", "Left" }, { "2", "Right" }, { "3", "Middle" }, { "4", "Button 4" }, { "5", "Button 5" } }
GF.clickMods = { { "", "" }, { "shift-", "Shift" }, { "ctrl-", "Ctrl" }, { "alt-", "Alt" } }

-- Starting bindings for classes that heal or cleanse. "A|B" casts the first one you know,
-- so low-level characters get the lower-rank spell.
GF.clickDefaults = {
    DRUID = { ["shift-1"] = "Rejuvenation", ["ctrl-1"] = "Healing Touch", ["alt-1"] = "Regrowth",
        ["3"] = "Remove Curse", ["shift-2"] = "Abolish Poison|Cure Poison" },
    PRIEST = { ["shift-1"] = "Renew", ["ctrl-1"] = "Greater Heal|Heal|Lesser Heal", ["alt-1"] = "Flash Heal",
        ["3"] = "Dispel Magic", ["shift-2"] = "Power Word: Shield", ["ctrl-2"] = "Abolish Disease|Cure Disease" },
    SHAMAN = { ["shift-1"] = "Lesser Healing Wave", ["ctrl-1"] = "Healing Wave", ["alt-1"] = "Chain Heal",
        ["3"] = "Cure Poison", ["shift-2"] = "Cure Disease" },
    PALADIN = { ["shift-1"] = "Flash of Light", ["ctrl-1"] = "Holy Light", ["alt-1"] = "Holy Shock",
        ["3"] = "Cleanse|Purify", ["shift-2"] = "Blessing of Protection", ["ctrl-2"] = "Lay on Hands" },
}
local CLICK_BASE = { ["1"] = "target", ["2"] = "menu" }

-- This class's bindings, seeding the starting set the first time only, so anything the
-- player removes stays removed.
function GF:ClickBindings()
    local cc = (GF.db or T.db.groupframes).clickcast
    local _, class = UnitClass("player")
    class = class or "UNKNOWN"
    cc.bindings[class] = cc.bindings[class] or {}
    local binds = cc.bindings[class]
    if not cc.seeded[class] then
        for k, v in pairs(CLICK_BASE) do binds[k] = v end
        for k, v in pairs(GF.clickDefaults[class] or {}) do binds[k] = v end
        cc.seeded[class] = true
    end
    return binds
end

function GF:ResetClickBindings()
    local cc = T.db.groupframes.clickcast
    local _, class = UnitClass("player")
    cc.bindings[class] = nil
    cc.seeded[class] = nil
end

local function SpellKnown(name)
    local id
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        id = ok and type(info) == "table" and info.spellID or nil
    elseif GetSpellInfo then
        local ok, _, _, _, _, _, _, sid = pcall(GetSpellInfo, name)
        id = ok and sid or nil
    end
    if not T.Num(id) then return false end
    local ok, known = pcall(IsPlayerSpell or IsSpellKnown, id)
    return ok and known == true
end

-- "target" / "menu" / ("spell", name) for a binding value, or nil when nothing applies.
function GF.ResolveAction(v)
    if type(v) ~= "string" or v == "" then return nil end
    if v == "target" or v == "menu" then return v end
    for name in v:gmatch("[^|]+") do
        name = strtrim(name)
        if SpellKnown(name) then return "spell", name end
    end
    return nil
end

function GF.ComboLabel(combo)
    local mod, btn = combo:match("^(.-)(%d)$")
    local label
    for _, m in ipairs(GF.clickMods) do if m[1] == mod then label = m[2] end end
    for _, bt in ipairs(GF.clickButtons) do
        if bt[1] == btn then return (label ~= "" and (label .. " + ") or "") .. bt[2] end
    end
    return combo
end

local function ApplyClicks(b)
    for attr in pairs(b.ccAttrs or {}) do b:SetAttribute(attr, nil) end
    b.ccAttrs = {}
    local cc = GF.db.clickcast
    if not cc.enabled or GF.cliqueLoaded then return end
    local function Set(attr, v)
        b:SetAttribute(attr, v)
        b.ccAttrs[attr] = true
    end
    for combo, v in pairs(GF:ClickBindings()) do
        local mod, btn = combo:match("^(.-)(%d)$")
        local kind, spell = GF.ResolveAction(v)
        if mod and kind == "spell" then
            Set(mod .. "type" .. btn, "spell")
            Set(mod .. "spell" .. btn, spell)
        elseif mod and kind == "target" then
            Set(mod .. "type" .. btn, "target")
        elseif mod and kind == "menu" then
            Set(mod .. "type" .. btn, "togglemenu")
        end
    end
end

-- Tooltip lines for the active spell bindings, in button then modifier order.
local function BuildHints()
    local hints = {}
    if GF.db.clickcast.enabled and not GF.cliqueLoaded then
        local binds = GF:ClickBindings()
        for _, bt in ipairs(GF.clickButtons) do
            for _, m in ipairs(GF.clickMods) do
                local combo = m[1] .. bt[1]
                local kind, spell = GF.ResolveAction(binds[combo])
                if kind == "spell" then hints[#hints + 1] = { GF.ComboLabel(combo), spell } end
            end
        end
    end
    GF.hints = hints
end

-- Names of the castable (not passive) spells in your spellbook, helpful ones only when
-- the client can tell, for the binding dropdowns. Handles both spellbook APIs.
function GF:SpellbookSpells()
    local names, seen = {}, {}
    local function Add(name, id)
        if type(name) ~= "string" or name == "" or seen[name] then return end
        local helpful
        if id and C_Spell and C_Spell.IsSpellHelpful then
            local ok, h = pcall(C_Spell.IsSpellHelpful, id)
            if ok and not issecret(h) then helpful = h end
        elseif IsHelpfulSpell then
            local ok, h = pcall(IsHelpfulSpell, name)
            if ok and not issecret(h) then helpful = h end
        end
        if helpful == false then return end
        seen[name] = true
        names[#names + 1] = name
    end
    pcall(function()
        if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
            local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
            local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
            for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
                local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
                if line and not line.offSpecID then
                    for j = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                        local info = C_SpellBook.GetSpellBookItemInfo(j, bank)
                        if info and (spellType == nil or info.itemType == spellType) and not info.isPassive then
                            Add(info.name, info.spellID)
                        end
                    end
                end
            end
        elseif GetNumSpellTabs and GetSpellTabInfo then
            for t = 1, GetNumSpellTabs() do
                local _, _, offset, count = GetSpellTabInfo(t)
                for i = offset + 1, offset + count do
                    local name = GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell")
                    local kind, id = GetSpellBookItemInfo(i, BOOKTYPE_SPELL or "spell")
                    local passive = IsPassiveSpell and IsPassiveSpell(i, BOOKTYPE_SPELL or "spell")
                    if kind == "SPELL" and not passive then Add(name, id) end
                end
            end
        end
    end)
    table.sort(names)
    return names
end

function GF:ApplyClickCasting()
    T:RunOOC(function()
        for b in pairs(GF.buttons) do ApplyClicks(b) end
        BuildHints()
    end, "gfclicks")
end

local function OnEnter(self)
    if not self.unit then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    if GameTooltip:SetUnit(self.unit) == false then return end
    if GF.db.clickcast.hints and GF.hints and #GF.hints > 0 then
        GameTooltip:AddLine(" ")
        for _, h in ipairs(GF.hints) do
            GameTooltip:AddDoubleLine(h[1], h[2], 0.55, 0.6, 0.68, 0.5, 1, 0.6)
        end
    end
    GameTooltip:Show()
end

-- Runs once per button, out of combat (buttons are pre-created before any fight).
local function StyleButton(header, b)
    if GF.buttons[b] then return end
    GF.buttons[b] = true
    b.cfg = header.cfg
    b.header = header
    BuildContent(b)
    b:RegisterForClicks("AnyUp")
    b:HookScript("OnEnter", OnEnter)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    -- Click-cast addons (Clique and others) pick frames up from this table.
    ClickCastFrames = ClickCastFrames or {}
    ClickCastFrames[b] = true
    b.ev = CreateFrame("Frame")
    b.ev.button = b
    b.ev:SetScript("OnEvent", T:Wrap("groupframes.unit", OnUnitEvent))
    b:HookScript("OnAttributeChanged", function(self, name, value)
        if name == "unit" then SetUnit(self, value) end
    end)
    b:HookScript("OnShow", function(self) UpdateAll(self) end)
    GF:Layout(b, header.cfg)
    SetUnit(b, b:GetAttribute("unit"))
end

----------------------------------------------------------------------------------------
-- Secure headers
----------------------------------------------------------------------------------------
local INIT = [[
    local header = self:GetParent()
    self:SetWidth(header:GetAttribute("tempus-width"))
    self:SetHeight(header:GetAttribute("tempus-height"))
    self:SetAttribute("*type1", "target")
    self:SetAttribute("*type2", "togglemenu")
]]

local CLASS_ORDER = "WARRIOR,DEATHKNIGHT,PALADIN,PRIEST,SHAMAN,DRUID,ROGUE,MAGE,WARLOCK,HUNTER,MONK,DEMONHUNTER,EVOKER"

local function ForEachChild(header, fn)
    for i = 1, 40 do
        local child = header:GetAttribute("child" .. i) or header[i]
        if not child then break end
        fn(child)
    end
end

-- Header attributes from the settings. Any config attribute change makes the header
-- re-lay itself out.
local function ConfigureHeader(header)
    local cfg, kind = header.cfg, header.kind
    header:SetAttribute("tempus-width", cfg.width)
    header:SetAttribute("tempus-height", cfg.height)
    header:SetAttribute("template", "SecureUnitButtonTemplate")
    header:SetAttribute("initialConfigFunction", INIT)
    header:SetAttribute("sortMethod", "INDEX")
    local sp = cfg.spacing
    if kind == "party" then
        header:SetAttribute("showParty", true)
        header:SetAttribute("showPlayer", cfg.showPlayer)
        header:SetAttribute("showRaid", false)
        header:SetAttribute("showSolo", cfg.showSolo and cfg.showPlayer)
        if cfg.growth == "RIGHT" then
            header:SetAttribute("point", "LEFT"); header:SetAttribute("xOffset", sp); header:SetAttribute("yOffset", 0)
        else
            header:SetAttribute("point", "TOP"); header:SetAttribute("xOffset", 0); header:SetAttribute("yOffset", -sp)
        end
    else
        header:SetAttribute("showRaid", true)
        header:SetAttribute("showParty", false)
        header:SetAttribute("showPlayer", true)
        header:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
        if cfg.groupBy == "ROLE" then
            header:SetAttribute("groupBy", "ASSIGNEDROLE")
            header:SetAttribute("groupingOrder", "TANK,HEALER,DAMAGER,NONE")
        elseif cfg.groupBy == "CLASS" then
            header:SetAttribute("groupBy", "CLASS")
            header:SetAttribute("groupingOrder", CLASS_ORDER)
        else
            header:SetAttribute("groupBy", "GROUP")
            header:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
        end
        header:SetAttribute("maxColumns", 8)
        header:SetAttribute("unitsPerColumn", 5)
        header:SetAttribute("columnSpacing", sp)
        if cfg.growth == "ROWS" then
            -- Each group is a row, groups stack downwards.
            header:SetAttribute("point", "LEFT"); header:SetAttribute("xOffset", sp); header:SetAttribute("yOffset", 0)
            header:SetAttribute("columnAnchorPoint", "TOP")
        else
            header:SetAttribute("point", "TOP"); header:SetAttribute("xOffset", 0); header:SetAttribute("yOffset", -sp)
            header:SetAttribute("columnAnchorPoint", "LEFT")
        end
    end
end

-- Footprint of a full header, for the mover box.
local function HolderSize(kind, cfg)
    local w, h, sp = cfg.width, cfg.height, cfg.spacing
    if kind == "party" then
        local n = cfg.showPlayer and 5 or 4
        if cfg.growth == "RIGHT" then return n * w + (n - 1) * sp, h end
        return w, n * h + (n - 1) * sp
    end
    if cfg.growth == "ROWS" then return 5 * w + 4 * sp, 8 * h + 7 * sp end
    return 8 * w + 7 * sp, 5 * h + 4 * sp
end

local function Visibility(kind)
    if kind == "party" then
        local cfg = GF.db.party
        return (cfg.showSolo and cfg.showPlayer) and "[group:raid] hide; show" or "[group:raid] hide; [group:party] show; hide"
    end
    return "[group:raid] show; hide"
end

local function CreateHeader(kind)
    local cfg = GF.db[kind]
    local holder = CreateFrame("Frame", "TempusGroup_" .. kind .. "Holder", UIParent)
    holder:SetFrameStrata("LOW")
    local header = CreateFrame("Frame", "TempusGroup_" .. kind, holder, "SecureGroupHeaderTemplate")
    header:SetPoint("TOPLEFT", holder, "TOPLEFT")
    header.kind, header.cfg, header.holder = kind, cfg, holder
    ConfigureHeader(header)
    header:HookScript("OnAttributeChanged", function(self, name, value)
        if type(name) == "string" and name:find("^child%d+$") and type(value) == "table" and not InCombatLockdown() then
            StyleButton(self, value)
        end
    end)
    -- Create every button now, out of combat: the header would otherwise make new ones
    -- mid-fight, when Tempus could no longer set them up.
    header:SetAttribute("startingIndex", kind == "party" and -4 or -39)
    header:Show()
    header:SetAttribute("startingIndex", 1)
    ForEachChild(header, function(child) StyleButton(header, child) end)
    header:Hide()
    RegisterAttributeDriver(header, "state-visibility", cfg.enabled and Visibility(kind) or "hide")
    GF[kind] = header
    T.Movers:Register(holder, {
        label = kind == "party" and "Party frames" or "Raid frames", page = "gf_" .. kind, secure = true,
        cfg = function() return GF.db[kind] end,
        corner = function() return GF.db[kind].point[1] end,
        enabled = function() return GF.db[kind].enabled end,
    })
    return header
end

local function ApplyHeader(kind)
    local header = GF[kind]
    if not header then return end
    T:RunOOC(function()
        local cfg = GF.db[kind]
        header.cfg = cfg
        header.holder:SetSize(HolderSize(kind, cfg))
        T.Movers.ApplyPoint(header.holder, cfg, cfg.point[1])
        ForEachChild(header, function(child)
            child.cfg = cfg
            child:SetSize(cfg.width, cfg.height)
        end)
        ConfigureHeader(header)
        RegisterAttributeDriver(header, "state-visibility", cfg.enabled and Visibility(kind) or "hide")
    end, "gfheader_" .. kind)
end

----------------------------------------------------------------------------------------
-- Blizzard frames
----------------------------------------------------------------------------------------
function GF:HideBlizzard()
    if not GF.db.hideBlizzard or GF.blizzHidden then return end
    T:RunOOC(function()
        GF.blizzHidden = true
        for _, name in ipairs({ "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer" }) do
            local f = _G[name]
            if f then
                pcall(f.UnregisterAllEvents, f)
                pcall(f.SetParent, f, S.HiddenParent)
            end
        end
        for i = 1, 4 do
            local f = _G["PartyMemberFrame" .. i]
            if f then
                pcall(f.UnregisterAllEvents, f)
                pcall(f.SetParent, f, S.HiddenParent)
            end
        end
    end, "gfblizz")
end

----------------------------------------------------------------------------------------
-- Group-wide events
----------------------------------------------------------------------------------------
local function EachActive(fn)
    for b in pairs(GF.buttons) do
        if b.unit and b:IsVisible() then fn(b) end
    end
end

local function OnEvent(_, event)
    if event == "PLAYER_TARGET_CHANGED" then
        EachActive(UpdateTarget)
    elseif event == "RAID_TARGET_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "PLAYER_ROLES_ASSIGNED" then
        EachActive(UpdateIcons)
    elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" then
        EachActive(function(b) UpdateReady(b) end)
    elseif event == "READY_CHECK_FINISHED" then
        EachActive(function(b) UpdateReady(b, true) end)
    elseif event == "GROUP_ROSTER_UPDATE" then
        EachActive(UpdateAll)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Buttons the header made during combat get their Tempus look now.
        for _, kind in ipairs({ "party", "raid" }) do
            local header = GF[kind]
            if header then ForEachChild(header, function(child) StyleButton(header, child) end) end
        end
        if GF.clicksPending then GF.clicksPending = nil; GF:ApplyClickCasting() end
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        -- Learning a spell (or a new rank) can switch a binding on; fires in bursts.
        if not GF.clickTimer then
            GF.clickTimer = true
            C_Timer.After(0.5, function()
                GF.clickTimer = nil
                if InCombatLockdown() then GF.clicksPending = true else GF:ApplyClickCasting() end
            end)
        end
    end
end

-- Range has no reliable event on every client, and ready-check marks fade after a while.
local function Tick(self, elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t < 0.25 then return end
    self.t = 0
    local now = GetTime()
    EachActive(function(b)
        UpdateRange(b)
        local c = b.content
        if c.readyHideAt and now >= c.readyHideAt then
            c.readyHideAt = nil
            c.ready:Hide()
        end
    end)
end

----------------------------------------------------------------------------------------
-- Settings preview: plain (non-secure) frames with the same visuals and fixed values.
----------------------------------------------------------------------------------------
local SAMPLE = {
    { "Thrall", "SHAMAN", "HEALER", 0.92, 0.18, 0, nil },
    { "Varian", "WARRIOR", "TANK", 0.55, 0, 0.25, "aggro" },
    { "Jaina", "MAGE", "DAMAGER", 0.34, 0.3, 0, "dispel" },
    { "Sylvanas", "HUNTER", "DAMAGER", 1, 0, 0, "range" },
    { "Anduin", "PRIEST", "HEALER", 0, 0, 0, "dead" },
}
local DISPEL_COLOR = { 0.2, 0.6, 1 }

local function FillSample(b, cfg, data)
    local name, class, role, pct, heal, absorb, state = unpack(data)
    local c, db = b.content, GF.db
    c.showPower = db.powerHeight > 0 and (not db.manaOnly or role == "HEALER")
    GF:Layout(b, cfg)
    local r, g, bl = S.ClassColor(class)
    local hp = c.health
    hp:SetMinMaxValues(0, 1)
    hp:SetValue(pct)
    if state == "dead" then
        hp:SetStatusBarColor(0.3, 0.3, 0.3)
        hp.bg:SetVertexColor(0.12, 0.12, 0.12, 0.9)
    elseif db.healthColor == "DARK" then
        hp:SetStatusBarColor(0.13, 0.14, 0.16)
        hp.bg:SetVertexColor(r * 0.55, g * 0.55, bl * 0.55, 0.95)
    elseif db.healthColor == "GRADIENT" then
        local gr = pct < 0.5 and pct * 2 or 1
        hp:SetStatusBarColor(pct < 0.5 and 0.9 or 0.95 - (pct - 0.5) * 1.5, 0.15 + gr * 0.65, 0.15)
        hp.bg:SetVertexColor(0.08, 0.09, 0.11, 0.9)
    else
        hp:SetStatusBarColor(r, g, bl)
        hp.bg:SetVertexColor(r * 0.18, g * 0.18, bl * 0.18, 0.9)
    end
    c.name:SetText(name)
    if db.healthColor == "DARK" then c.name:SetTextColor(r, g, bl) else c.name:SetTextColor(1, 1, 1) end
    if state == "dead" then c.status:SetText("Dead")
    elseif db.healthText == "PERCENT" then c.status:SetFormattedText("%d%%", pct * 100)
    else c.status:SetText("") end
    c.heal:SetMinMaxValues(0, 1); c.heal:SetValue(heal); c.heal:SetShown(db.healPrediction and heal > 0)
    c.absorb:SetMinMaxValues(0, 1); c.absorb:SetValue(absorb); c.absorb:SetShown(db.absorbs and absorb > 0)
    c.power:SetMinMaxValues(0, 1); c.power:SetValue(0.7)
    c.power:SetStatusBarColor(0.3, 0.5, 0.95)
    c.power.bg:SetVertexColor(0.06, 0.1, 0.19, 0.9)
    c:SetAlpha(state == "range" and db.rangeAlpha or 1)
    local coords = db.roleIcon and ROLE_COORDS[role]
    if coords then c.role:SetTexCoord(unpack(coords)); c.role:Show() else c.role:Hide() end
    c.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    c.leader:SetShown(db.leaderIcon and name == "Varian")
    if db.raidIcon and name == "Varian" then SetRaidTargetIconTexture(c.raidIcon, 8); c.raidIcon:Show() else c.raidIcon:Hide() end
    c.ready:Hide()
    c.rez:SetShown(state == "dead")
    c.aggro:SetColor(1, 0.15, 0.15, 1)
    c.aggro:SetShown(db.aggro and state == "aggro")
    c.target:SetShown(db.targetHighlight and name == "Jaina")

    -- Stand-in aura icons where the containers would draw.
    c.sample = c.sample or {}
    local function Icon(key, i, tex, color)
        local g = GF.groups[key]
        local list = c.sample[key] or {}
        c.sample[key] = list
        local ic = list[i]
        if not ic then
            ic = CreateFrame("Frame", nil, c.over)
            ic.border = ic:CreateTexture(nil, "BACKGROUND")
            ic.border:SetTexture(S.WHITE)
            ic.border:SetAllPoints()
            ic.icon = ic:CreateTexture(nil, "ARTWORK")
            ic.icon:SetPoint("TOPLEFT", 1, -1)
            ic.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            ic.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            list[i] = ic
        end
        if not g then ic:Hide() return end
        ic:SetSize(g.size, g.size)
        ic:ClearAllPoints()
        local step = (i - 1) * (g.size + 1)
        if key == "dispel" then ic:SetPoint("BOTTOMRIGHT", c.health, "BOTTOMRIGHT", -2, 2)
        elseif key == "debuffs" then ic:SetPoint("BOTTOMLEFT", c.health, "BOTTOMLEFT", 2 + step, 2)
        else ic:SetPoint("TOPRIGHT", c, "TOPRIGHT", -2 - step, -2) end
        ic.icon:SetTexture(tex)
        ic.border:SetVertexColor(color[1], color[2], color[3])
        ic:Show()
    end
    for _, list in pairs(c.sample) do for _, ic in ipairs(list) do ic:Hide() end end
    c.sampleTint = c.sampleTint or c.health:CreateTexture(nil, "ARTWORK", nil, 3)
    c.sampleTint:SetTexture(S.WHITE)
    c.sampleTint:SetAllPoints(c.health)
    c.sampleTint:SetVertexColor(DISPEL_COLOR[1], DISPEL_COLOR[2], DISPEL_COLOR[3], 0.3)
    c.sampleTint:SetShown(state == "dispel" and db.dispel and db.dispelTint)
    if state == "dispel" then Icon("dispel", 1, "Interface\\Icons\\Spell_Frost_FrostNova", DISPEL_COLOR) end
    if state == "aggro" then Icon("debuffs", 1, "Interface\\Icons\\Ability_Warrior_Sunder", { 0, 0, 0 }) end
    if role ~= "HEALER" and state ~= "dead" then
        Icon("buffs", 1, "Interface\\Icons\\Spell_Nature_Rejuvenation", { 0, 0, 0 })
        if name == "Varian" then Icon("buffs", 2, "Interface\\Icons\\Spell_Holy_Renew", { 0, 0, 0 }) end
    end
end

-- Sample frames can't cast (no unit, not secure); a click shows what it would do instead.
local MOUSE = { LeftButton = "1", RightButton = "2", MiddleButton = "3", Button4 = "4", Button5 = "5" }

local function DescribeClick(button)
    local btn = MOUSE[button]
    if not btn then return nil end
    local mod = (IsAltKeyDown() and "alt-" or "") .. (IsControlKeyDown() and "ctrl-" or "") .. (IsShiftKeyDown() and "shift-" or "")
    local combo = mod .. btn
    local label = GF.ComboLabel(combo)
    local cc = GF.db.clickcast
    if GF.cliqueLoaded then return label .. ": handled by Clique", 0.8, 0.8, 0.8 end
    if not cc.enabled then return "Click-casting is off", 0.8, 0.8, 0.8 end
    local v = GF:ClickBindings()[combo]
    local kind, spell = GF.ResolveAction(v)
    if kind == "spell" then return label .. "  >  " .. spell, 0.5, 1, 0.6 end
    if kind == "target" or (not v and btn == "1") then return label .. "  >  Target", 1, 1, 1 end
    if kind == "menu" or (not v and btn == "2") then return label .. "  >  Menu", 1, 1, 1 end
    if type(v) == "string" and v ~= "" then
        return label .. "  >  " .. v:gsub("|", " or ") .. " (not learned yet)", 1, 0.6, 0.3
    end
    return label .. ": not bound", 0.7, 0.7, 0.7
end

local function SampleClicks(b)
    local c = b.content
    c.clickText = c.over:CreateFontString(nil, "OVERLAY")
    c.clickText:SetPoint("CENTER", c, "CENTER")
    c.clickText:SetWordWrap(false)
    c.clickText:Hide()
    b:EnableMouse(true)
    b:SetScript("OnMouseUp", function(self, button)
        local text, r, g, bl = DescribeClick(button)
        if not text then return end
        S.ApplyFont(c.clickText, math.max(9, GF.db.fontSize))
        c.clickText:SetText(text)
        c.clickText:SetTextColor(r, g, bl)
        c.clickText:Show()
        c.clickHideAt = GetTime() + 2
        self:SetScript("OnUpdate", function(f)
            if GetTime() >= (c.clickHideAt or 0) then
                c.clickText:Hide()
                f:SetScript("OnUpdate", nil)
            end
        end)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Sample frame")
        GameTooltip:AddLine("Click with any button and modifier to see what it would do.", 0.8, 0.8, 0.8, true)
        BuildHints()
        if GF.hints and #GF.hints > 0 then
            GameTooltip:AddLine(" ")
            for _, h in ipairs(GF.hints) do GameTooltip:AddDoubleLine(h[1], h[2], 0.55, 0.6, 0.68, 0.5, 1, 0.6) end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Returns a full-width settings widget: a sample party, or a sample raid of 10.
function GF:CreatePreview(kind, width, height)
    local box = CreateFrame("Frame")
    box:SetSize(width, height)
    S.Backdrop(box, { fill = { 0.03, 0.035, 0.045, 1 }, shadow = false })
    local holder = CreateFrame("Frame", nil, box)
    holder:SetPoint("TOPLEFT", 8, -8)
    holder:SetPoint("BOTTOMRIGHT", -8, 8)
    holder:SetClipsChildren(true)
    local inner = CreateFrame("Frame", nil, holder)
    local count = kind == "party" and 5 or 10
    local frames = {}
    for i = 1, count do
        local b = CreateFrame("Frame", nil, inner)
        BuildContent(b)
        SampleClicks(b)
        frames[i] = b
    end
    function box:Refresh()
        GF.db = T.db.groupframes
        GF.groups = AuraGroups()
        local cfg = GF.db[kind]
        local w, h, sp = cfg.width, cfg.height, cfg.spacing
        local cols, rows
        for i, b in ipairs(frames) do
            b:SetSize(w, h)
            b:ClearAllPoints()
            local idx = i - 1
            local col, row
            if kind == "party" then
                if cfg.growth == "RIGHT" then col, row = idx, 0 else col, row = 0, idx end
            elseif cfg.growth == "ROWS" then
                col, row = idx % 5, math.floor(idx / 5)
            else
                col, row = math.floor(idx / 5), idx % 5
            end
            b:SetPoint("TOPLEFT", inner, "TOPLEFT", col * (w + sp), -row * (h + sp))
            cols, rows = math.max(cols or 0, col + 1), math.max(rows or 0, row + 1)
            FillSample(b, cfg, SAMPLE[(i - 1) % #SAMPLE + 1])
        end
        local iw, ih = cols * w + (cols - 1) * sp, rows * h + (rows - 1) * sp
        inner:SetSize(iw, ih)
        local s = math.min(1, (width - 20) / iw, (height - 20) / ih)
        inner:SetScale(s)
        inner:ClearAllPoints()
        inner:SetPoint("CENTER", holder, "CENTER", 0, 0)
    end
    return box
end

-- While the UI is unlocked, or GF.showSamples is on (a settings button, not saved),
-- sample frames fill each mover box at the real size and layout, so both can be
-- arranged without a group. They are plain frames over the holder.
function GF:UpdateTestFrames()
    local on = T.db and (not T.db.locked or GF.showSamples)
    for _, kind in ipairs({ "party", "raid" }) do
        local header = GF[kind]
        if header then
            local cfg = GF.db[kind]
            local holder = header.holder
            holder.test = holder.test or {}
            local show = on and cfg.enabled
            local n = kind == "party" and (cfg.showPlayer and 5 or 4) or (cfg.sampleSize or 20)
            for i = 1, math.max(n, #holder.test) do
                local b = holder.test[i]
                if show and i <= n then
                    if not b then
                        b = CreateFrame("Frame", nil, holder)
                        b:SetFrameLevel(holder:GetFrameLevel() + 20)
                        BuildContent(b)
                        SampleClicks(b)
                        holder.test[i] = b
                    end
                    local idx = i - 1
                    local col, row
                    if kind == "party" then
                        if cfg.growth == "RIGHT" then col, row = idx, 0 else col, row = 0, idx end
                    elseif cfg.growth == "ROWS" then
                        col, row = idx % 5, math.floor(idx / 5)
                    else
                        col, row = math.floor(idx / 5), idx % 5
                    end
                    b:SetSize(cfg.width, cfg.height)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", holder, "TOPLEFT", col * (cfg.width + cfg.spacing), -row * (cfg.height + cfg.spacing))
                    FillSample(b, cfg, SAMPLE[idx % #SAMPLE + 1])
                    b:Show()
                elseif b then
                    b:Hide()
                end
            end
        end
    end
end

----------------------------------------------------------------------------------------
-- Module
----------------------------------------------------------------------------------------
function GF:Refresh()
    GF.version = GF.version + 1
    GF.groups = AuraGroups()
    ApplyHeader("party")
    ApplyHeader("raid")
    for b in pairs(GF.buttons) do
        b.content.layoutVersion = nil
        if b.unit then
            UpdateAll(b)
            AttachAuras(b)
        end
    end
    GF:HideBlizzard()
    GF:UpdateTestFrames()
    GF:ApplyClickCasting()
end

T:NewModule("groupframes", {
    label = "Party & Raid",
    desc = "Party and raid frames: range fading, incoming heals, dispellable debuffs, your HoTs, roles and aggro.",
    defaults = GF.defaults,
    OnEnable = function()
        GF.db = T.db.groupframes
        GF.groups = AuraGroups()
        GF.aurasOK = T.Display and T.Display.NativeAvailable and T.Display:NativeAvailable() or false
        if InCombatLockdown() then
            -- Headers must be built out of combat; a /reload in a fight defers it.
            T:RunOOC(function() GF:Build() end, "gfbuild")
        else
            GF:Build()
        end
    end,
    OnSettings = function()
        GF.db = T.db.groupframes
        if GF.built then GF:Refresh() end
    end,
})

function GF:Build()
    if GF.built then return end
    GF.built = true
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    GF.cliqueLoaded = loaded and loaded("Clique") and true or false
    CreateHeader("party")
    CreateHeader("raid")
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED",
        "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED",
        "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", T:Wrap("groupframes.events", OnEvent))
    ev:SetScript("OnUpdate", T:Wrap("groupframes.tick", Tick))
    GF:Refresh()
end
