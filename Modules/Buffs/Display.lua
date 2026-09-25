-- Tempus: aura buttons (icon and bar styles), group layout, movers, timers and cancelling.
local _, T = ...
local A = T.Auras

local D = { groups = {}, testMode = false, styleVersion = 0 }
T.Display = D
local proxy     -- secure button over the hovered icon: left-click recasts, right-click cancels

local WHITE = "Interface\\Buttons\\WHITE8X8"
local abs, sin, min, max = math.abs, math.sin, math.min, math.max

D.groupOrder = { "buffs", "debuffs", "weapons", "watch" }
D.groupLabels = { buffs = "Buffs", debuffs = "Debuffs", weapons = "Weapon Enchants", watch = "Missing Buffs" }

D.barTextures = T.Style.barTextures
local function BarTexture() return T.Style.BarTexture(T.db.barTexture) end

local DEBUFF_COLORS = {
    Magic   = { 0.2, 0.6, 1 },
    Curse   = { 0.6, 0, 1 },
    Disease = { 0.6, 0.4, 0 },
    Poison  = { 0, 0.6, 0 },
    none    = { 0.8, 0.1, 0.1 },
}
D.debuffColors = DEBUFF_COLORS

----------------------------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------------------------
local CreateBorder, SetGradient, ApplyFont = T.Style.CreateBorder, T.Style.SetGradient, T.Style.ApplyFont
D.CreateBorder, D.SetGradient = CreateBorder, SetGradient

local function ClearCooldown(cd)
    if cd.Clear then cd:Clear() else cd:SetCooldown(0, 0) end
end

----------------------------------------------------------------------------------------
-- Aura button
----------------------------------------------------------------------------------------
local function OnEnter(self) D:OnButtonEnter(self) end
local function OnLeave() GameTooltip:Hide() end

local function CreateButton(group)
    local b = CreateFrame("Button", nil, group.frame)
    b.group = group
    b:SetScript("OnEnter", OnEnter)
    b:SetScript("OnLeave", OnLeave)

    local art = CreateFrame("Frame", nil, b)
    b.art = art
    b.shadow = art:CreateTexture(nil, "BACKGROUND", nil, -8)
    b.shadow:SetTexture(WHITE)
    b.shadow:SetVertexColor(0, 0, 0, 0.55)
    b.iconBg = art:CreateTexture(nil, "BACKGROUND", nil, -6)
    b.iconBg:SetTexture(WHITE)
    b.iconBg:SetVertexColor(0, 0, 0, 1)
    b.icon = art:CreateTexture(nil, "ARTWORK")
    b.gloss = art:CreateTexture(nil, "ARTWORK", nil, 3)
    b.gloss:SetTexture(WHITE)
    b.gloss:SetBlendMode("ADD")
    b.shade = art:CreateTexture(nil, "ARTWORK", nil, 2)
    b.shade:SetTexture(WHITE)
    b.border = CreateBorder(art, "OVERLAY", 1)
    b.classic = art:CreateTexture(nil, "OVERLAY", nil, 1)
    b.classic:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    b.classic:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)

    b.glow = art:CreateTexture(nil, "OVERLAY", nil, 6)
    b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()
    local ag = b.glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.25)
    fade:SetToAlpha(1)
    fade:SetDuration(0.75)
    fade:SetSmoothing("IN_OUT")
    b.glowAnim = ag

    b.cd = CreateFrame("Cooldown", nil, art, "CooldownFrameTemplate")
    b.cd:SetReverse(true)
    b.cd:SetDrawEdge(false)
    if b.cd.SetDrawBling then b.cd:SetDrawBling(false) end
    if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
    b.cd.noCooldownCount = true   -- keep OmniCC and friends off our icons
    b.cd.noOCC = true

    -- Bars: one bar driven by Lua, one driven natively by a duration object.
    local barFrame = CreateFrame("Frame", nil, b)
    b.barFrame = barFrame
    b.barShadow = barFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    b.barShadow:SetTexture(WHITE)
    b.barShadow:SetVertexColor(0, 0, 0, 0.55)
    b.barBg = barFrame:CreateTexture(nil, "BACKGROUND", nil, -6)
    b.barBg:SetTexture(WHITE)
    b.bar = CreateFrame("StatusBar", nil, barFrame)
    b.bar:SetMinMaxValues(0, 1)
    b.nbar = CreateFrame("StatusBar", nil, barFrame)
    b.nbar:SetMinMaxValues(0, 1)
    b.barGloss = barFrame:CreateTexture(nil, "ARTWORK", nil, 3)
    b.barGloss:SetTexture(WHITE)
    b.barGloss:SetBlendMode("ADD")
    b.barBorder = CreateBorder(barFrame, "OVERLAY", 1)

    local over = CreateFrame("Frame", nil, b)
    over:SetAllPoints(b)
    b.over = over
    b.spark = over:CreateTexture(nil, "OVERLAY")
    b.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    b.spark:SetBlendMode("ADD")
    b.count = over:CreateFontString(nil, "OVERLAY")
    b.timer = over:CreateFontString(nil, "OVERLAY")
    b.nameText = over:CreateFontString(nil, "OVERLAY")
    b.nameText:SetWordWrap(false)
    return b
end

-- Size, theme and anchors. Runs when settings change, not on every aura update.
function D:StyleButton(b, cfg, index)
    local db = T.db
    local bars = cfg.style == "BARS"
    local theme = db.theme
    local bs = db.borderSize
    local fontSize = db.timerFontSize

    b.styleVersion = D.styleVersion
    b:SetFrameLevel(b.group.frame:GetFrameLevel() + 2)
    b.over:SetFrameLevel(b:GetFrameLevel() + 12)
    b:EnableMouse(not db.clickThrough)

    local S, W, H
    if bars then
        H = cfg.barHeight
        W = cfg.barWidth
        S = cfg.barIcon ~= "NONE" and H or 0
    else
        S = cfg.size
        W = S
        H = S
        if cfg.timer == "BOTTOM" or cfg.timer == "TOP" then H = S + fontSize + 3 end
    end
    b:SetSize(W, H)

    -- Icon square
    local art = b.art
    art:ClearAllPoints()
    art:SetSize(max(S, 1), max(S, 1))
    art:SetShown(S > 0)
    if bars then
        art:SetPoint(cfg.barIcon == "RIGHT" and "RIGHT" or "LEFT", b)
    elseif cfg.timer == "TOP" then
        art:SetPoint("BOTTOM", b)
    else
        art:SetPoint("TOP", b)
    end
    b.cd:SetAllPoints(art)
    b.cd:SetSwipeColor(0, 0, 0, db.swipeAlpha)

    local zoom = theme == "CLASSIC" and 0 or db.iconZoom
    b.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
    b.icon:ClearAllPoints()
    b.iconBg:ClearAllPoints()
    b.iconBg:SetAllPoints(art)
    b.shadow:ClearAllPoints()
    b.shadow:SetPoint("TOPLEFT", art, -bs - 2, bs + 2)
    b.shadow:SetPoint("BOTTOMRIGHT", art, bs + 2, -bs - 2)
    b.icon:SetAllPoints(art)
    b.border:SetThickness(bs, art)

    local modern = theme == "MODERN" or theme == "GLOSS"
    b.shadow:SetShown(modern)
    b.border:SetShown(modern)
    b.iconBg:SetShown(modern)
    b.classic:ClearAllPoints()
    b.classic:SetPoint("TOPLEFT", art, -1, 1)
    b.classic:SetPoint("BOTTOMRIGHT", art, 1, -1)
    b.gloss:ClearAllPoints()
    b.gloss:SetPoint("TOPLEFT", art)
    b.gloss:SetPoint("TOPRIGHT", art)
    b.gloss:SetHeight(max(S, 1) * 0.5)
    SetGradient(b.gloss, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.22)
    b.gloss:SetShown(theme == "GLOSS")
    b.shade:ClearAllPoints()
    b.shade:SetPoint("BOTTOMLEFT", art)
    b.shade:SetPoint("BOTTOMRIGHT", art)
    b.shade:SetHeight(max(S, 1) * 0.45)
    SetGradient(b.shade, "VERTICAL", 0, 0, 0, 0.45, 0, 0, 0, 0)
    b.shade:SetShown(theme == "GLOSS")
    b.glow:ClearAllPoints()
    b.glow:SetPoint("CENTER", art)
    b.glow:SetSize(S * 1.8, S * 1.8)

    -- Text
    ApplyFont(b.timer, fontSize)
    ApplyFont(b.count, db.countFontSize)
    ApplyFont(b.nameText, db.nameFontSize)
    b.count:ClearAllPoints()
    b.count:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", 2, 1)
    b.count:SetTextColor(1, 1, 1)
    b.timer:ClearAllPoints()
    b.nameText:ClearAllPoints()

    local barFrame = b.barFrame
    barFrame:SetShown(bars)
    b.spark:SetShown(false)
    b.nameText:SetShown(bars and cfg.showName)
    if bars then
        barFrame:ClearAllPoints()
        local gap = S > 0 and (bs * 2 + 3) or 0
        if cfg.barIcon == "RIGHT" then
            barFrame:SetPoint("TOPLEFT", b)
            barFrame:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -(S + gap), 0)
        else
            barFrame:SetPoint("TOPLEFT", b, "TOPLEFT", S + gap, 0)
            barFrame:SetPoint("BOTTOMRIGHT", b)
        end
        b.barShadow:ClearAllPoints()
        b.barShadow:SetPoint("TOPLEFT", barFrame, -bs - 2, bs + 2)
        b.barShadow:SetPoint("BOTTOMRIGHT", barFrame, bs + 2, -bs - 2)
        b.barShadow:SetShown(theme ~= "FLAT")
        b.barBg:SetAllPoints(barFrame)
        local bg = db.colors.barBg
        b.barBg:SetVertexColor(bg[1], bg[2], bg[3], 0.85)
        local tex = BarTexture()
        for _, bar in ipairs({ b.bar, b.nbar }) do
            bar:ClearAllPoints()
            bar:SetAllPoints(barFrame)
            bar:SetStatusBarTexture(tex)
            bar:SetFrameLevel(barFrame:GetFrameLevel() + 1)
        end
        b.barBorder:SetThickness(bs, barFrame)
        b.barBorder:SetShown(theme ~= "FLAT" and theme ~= "CLASSIC")
        local c = db.colors.border
        b.barBorder:SetColor(c[1], c[2], c[3], 1)
        b.barGloss:ClearAllPoints()
        b.barGloss:SetPoint("TOPLEFT", barFrame)
        b.barGloss:SetPoint("TOPRIGHT", barFrame)
        b.barGloss:SetHeight(H * 0.5)
        SetGradient(b.barGloss, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.18)
        b.barGloss:SetShown(theme == "GLOSS")
        b.spark:SetSize(12, H * 2.2)

        b.timer:SetPoint("RIGHT", barFrame, "RIGHT", -5, 0)
        b.timer:SetJustifyH("RIGHT")
        b.nameText:SetPoint("LEFT", barFrame, "LEFT", 5, 0)
        b.nameText:SetPoint("RIGHT", b.timer, "LEFT", -4, 0)
        b.nameText:SetJustifyH("LEFT")
        b.timer:SetShown(cfg.timer ~= "NONE")
        if S == 0 then
            b.count:ClearAllPoints()
            b.count:SetPoint("LEFT", barFrame, "LEFT", 4, 0)
            b.nameText:SetPoint("LEFT", b.count, "RIGHT", 3, 0)
        end
    else
        b.timer:SetJustifyH("CENTER")
        b.timer:SetShown(cfg.timer ~= "NONE")
        if cfg.timer == "BOTTOM" then
            b.timer:SetPoint("TOP", art, "BOTTOM", 1, -(bs + 2))
        elseif cfg.timer == "TOP" then
            b.timer:SetPoint("BOTTOM", art, "TOP", 1, bs + 2)
        else
            b.timer:SetPoint("CENTER", art, "CENTER", 1, 0)
        end
    end

    -- Position in the group grid.
    local cellW, cellH, cols = D:CellSize(cfg)
    local i = index - 1
    local col, row
    if bars then col, row = 0, i else col, row = i % cols, math.floor(i / cols) end
    local corner = D:Corner(cfg)
    local sx = cfg.growX == "LEFT" and -1 or 1
    local sy = cfg.growY == "DOWN" and -1 or 1
    b:ClearAllPoints()
    b:SetPoint(corner, b.group.frame, corner, sx * col * (cellW + cfg.spacing), sy * row * (cellH + cfg.spacing))
end

function D:CellSize(cfg)
    if cfg.style == "BARS" then
        return cfg.barWidth, cfg.barHeight, 1
    end
    local h = cfg.size
    if cfg.timer == "BOTTOM" or cfg.timer == "TOP" then h = h + T.db.timerFontSize + 3 end
    return cfg.size, h, cfg.perRow
end

function D:MaxButtons(cfg)
    return cfg.perRow * cfg.rows
end

function D:Corner(cfg)
    return (cfg.growY == "DOWN" and "TOP" or "BOTTOM") .. (cfg.growX == "LEFT" and "RIGHT" or "LEFT")
end

----------------------------------------------------------------------------------------
-- Binding an entry to a button
----------------------------------------------------------------------------------------
local function StaticBarColor(e, cfg)
    local c = T.db.colors
    local mode = cfg.barColor
    if e.missing then return c.urgent end
    if mode == "CLASS" then
        local _, class = UnitClass("player")
        local cc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        if cc then return { cc.r, cc.g, cc.b } end
    elseif mode == "TYPE" and e.harmful then
        return DEBUFF_COLORS[e.dispel or "none"] or DEBUFF_COLORS.none
    end
    if e.weapon then return c.weaponBar end
    if e.harmful then return c.debuffBar end
    return c.buffBar
end

local function EnsureBinding(b)
    if b.binding ~= nil then return b.binding end
    b.binding = false
    if T.nativeFormatter and C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
        local ok, binding = pcall(C_DurationUtil.CreateDurationTextBinding)
        if ok and binding then
            pcall(binding.SetFontString, binding, b.timer)
            b.binding = binding
        end
    end
    return b.binding
end

local function DisableBinding(b)
    if b.binding then pcall(b.binding.SetEnabled, b.binding, false) end
end

function D:SetEntry(b, e)
    local cfg = b.group.cfg
    local db = T.db
    local bars = cfg.style == "BARS"
    local changed = b.entry == nil or b.entry.index ~= e.index or b.entry.filter ~= e.filter
        or b.entry.auraInstanceID ~= e.auraInstanceID
    b.entry = e

    if not pcall(b.icon.SetTexture, b.icon, e.icon or 134400) then b.icon:SetTexture(134400) end
    b.icon:SetDesaturated(e.missing and true or false)
    b.icon:SetAlpha(e.missing and 0.75 or 1)

    if e.count and e.count > 1 then
        b.count:SetText(e.count)
    elseif e.countText ~= nil then
        pcall(b.count.SetText, b.count, e.countText)
    else
        b.count:SetText("")
    end

    if bars and cfg.showName then
        if not pcall(b.nameText.SetText, b.nameText, e.name) then b.nameText:SetText("") end
    end

    -- Border colour and emphasis
    local c
    if e.missing then
        c = db.colors.urgent
    elseif e.harmful then
        c = DEBUFF_COLORS[e.dispel or "none"] or DEBUFF_COLORS.none
    elseif e.important then
        c = db.colors.important
    elseif e.weapon then
        c = db.colors.weaponBar
    else
        c = db.colors.border
    end
    b.border:SetColor(c[1], c[2], c[3], 1)
    b.classic:SetVertexColor(c[1], c[2], c[3])
    b.classic:SetShown(db.theme == "CLASSIC" and (e.harmful or e.important or e.missing or e.weapon) and true or false)
    if e.important or e.missing then
        local g = e.missing and db.colors.urgent or db.colors.important
        b.glow:SetVertexColor(g[1], g[2], g[3])
        b.glow:Show()
        if not b.glowAnim:IsPlaying() then b.glowAnim:Play() end
    else
        b.glow:Hide()
        b.glowAnim:Stop()
    end

    local bc = StaticBarColor(e, cfg)
    b.bar:SetStatusBarColor(bc[1], bc[2], bc[3])
    b.nbar:SetStatusBarColor(bc[1], bc[2], bc[3])

    -- Timing
    b.lastText = nil
    b.art:SetAlpha(1)
    b.barFrame:SetAlpha(1)
    if e.missing then
        DisableBinding(b)
        ClearCooldown(b.cd)
        b.timer:SetText(bars and "MISSING" or "!")
        local u = db.colors.urgent
        b.timer:SetTextColor(u[1], u[2], u[3])
        b.bar:Show(); b.nbar:Hide()
        b.bar:SetValue(1)
        b.spark:Hide()
    elseif e.permanent then
        DisableBinding(b)
        ClearCooldown(b.cd)
        b.timer:SetText("")
        b.bar:Show(); b.nbar:Hide()
        b.bar:SetValue(1)
        b.spark:Hide()
        b.cdStart, b.cdDur = nil, nil
    elseif e.secret then
        b.cdStart, b.cdDur = nil, nil
        if db.swipe and b.cd.SetCooldownFromDurationObject then
            pcall(b.cd.SetCooldownFromDurationObject, b.cd, e.durObj)
        else
            ClearCooldown(b.cd)
        end
        if bars then
            b.bar:Hide(); b.nbar:Show()
            local ok = b.nbar.SetTimerDuration and Enum.StatusBarInterpolation and pcall(b.nbar.SetTimerDuration, b.nbar, e.durObj,
                Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
            if not ok then b.nbar:SetValue(1) end
            b.spark:ClearAllPoints()
            b.spark:SetPoint("CENTER", b.nbar:GetStatusBarTexture(), "RIGHT", 0, 0)
            b.spark:Show()
        end
        local binding = EnsureBinding(b)
        if binding then
            pcall(binding.SetFormatter, binding, T.nativeFormatter)
            if T.nativeColorCurve and Enum.DurationTextBindingProperty then
                pcall(binding.SetTextColorCurve, binding, T.nativeColorCurve, Enum.DurationTextBindingProperty.RemainingDuration)
            end
            pcall(binding.SetDuration, binding, e.durObj)
            pcall(binding.SetEnabled, binding, true)
        else
            b.timer:SetTextColor(1, 1, 1)
        end
    else
        DisableBinding(b)
        b.bar:Show(); b.nbar:Hide()
        local start = e.expiration - e.duration
        if db.swipe then
            if changed or not b.cdStart or abs(b.cdStart - start) > 0.5 or abs((b.cdDur or 0) - e.duration) > 0.5 then
                b.cd:SetCooldown(start, e.duration)
                b.cdStart, b.cdDur = start, e.duration
            end
        else
            ClearCooldown(b.cd)
            b.cdStart, b.cdDur = nil, nil
        end
        if bars then
            b.spark:ClearAllPoints()
            b.spark:SetPoint("CENTER", b.bar:GetStatusBarTexture(), "RIGHT", 0, 0)
            b.spark:Show()
        end
        D:TickButton(b, GetTime())
    end
end

-- Per-frame refresh for Lua-timed entries (native entries update themselves).
function D:TickButton(b, now)
    local e = b.entry
    if not e or e.permanent or e.missing then return end
    local db = T.db
    local bars = b.group.cfg.style == "BARS"
    if e.secret then
        if bars and b.group.cfg.barColor == "TIME" and T.nativeBarCurve and e.durObj and not b.noCurve then
            local ok = pcall(function()
                local color = e.durObj:EvaluateRemainingPercent(T.nativeBarCurve)
                b.nbar:SetStatusBarColor(color:GetRGB())
            end)
            if not ok then b.noCurve = true end
        end
        if not b.binding and e.durObj then
            pcall(function() b.timer:SetFormattedText("%.0f", e.durObj:GetRemainingDuration()) end)
        end
        return
    end
    local rem = e.expiration - now
    if rem <= 0 then
        if D.testMode and e.test then
            e.expiration = now + e.duration
            rem = e.duration
        else
            rem = 0
        end
    end
    local text = T.FormatTime(rem)
    if text ~= b.lastText then
        b.timer:SetText(text)
        b.lastText = text
    end
    local c = T.TimeColor(rem)
    b.timer:SetTextColor(c[1], c[2], c[3])
    if bars then
        local p = e.duration > 0 and rem / e.duration or 0
        b.bar:SetValue(p)
        if b.group.cfg.barColor == "TIME" then b.bar:SetStatusBarColor(T.GradientColor(p)) end
        b.spark:SetShown(p > 0.005 and p < 0.995)
    end
    if db.pulse and rem > 0 and rem <= db.pulseAt then
        local a = 0.4 + 0.6 * abs(sin(now * 3.5))
        b.art:SetAlpha(a)
        if bars then b.barFrame:SetAlpha(0.55 + 0.45 * abs(sin(now * 3.5))) end
        b.pulsing = true
    elseif b.pulsing then
        b.art:SetAlpha(1)
        b.barFrame:SetAlpha(1)
        b.pulsing = nil
    end
end

----------------------------------------------------------------------------------------
-- Groups
----------------------------------------------------------------------------------------
local function CreateGroup(key)
    local g = { key = key, buttons = {} }
    local f = CreateFrame("Frame", "TempusGroup_" .. key, UIParent)
    f:SetFrameStrata("LOW")
    g.frame = f

    g.mover = T.Movers:Register(f, {
        label = D.groupLabels[key],
        page = key,
        cfg = function() return g.cfg end,
        corner = function() return D:Corner(g.cfg) end,
        enabled = function() return g.cfg and g.cfg.enabled end,
    })
    return g
end

function D:SavePosition(g)
    T.Movers.SavePoint(g.frame, g.cfg, D:Corner(g.cfg))
end

function D:LayoutGroup(g)
    local cfg = g.cfg
    local f = g.frame
    f:SetScale(cfg.scale)
    f:SetAlpha(cfg.alpha)
    local cellW, cellH, cols = D:CellSize(cfg)
    local rows = cfg.style == "BARS" and cfg.perRow * cfg.rows or cfg.rows
    local w = cols * cellW + (cols - 1) * cfg.spacing
    local h = rows * cellH + (rows - 1) * cfg.spacing
    f:SetSize(max(w, 10), max(h, 10))
    T.Movers.ApplyPoint(f, cfg, D:Corner(cfg))   -- re-anchors if growth changed, keeping the box in place
    f:SetShown(cfg.enabled)
    for i, b in ipairs(g.buttons) do D:StyleButton(b, cfg, i) end
end

function D:Populate(g, list)
    local cfg = g.cfg
    local limit = D:MaxButtons(cfg)
    local shown = 0
    for i = 1, min(#list, limit) do
        local b = g.buttons[i]
        if not b then
            b = CreateButton(g)
            g.buttons[i] = b
        end
        if b.styleVersion ~= D.styleVersion then D:StyleButton(b, cfg, i) end
        D:SetEntry(b, list[i])
        b:Show()
        shown = i
    end
    for i = shown + 1, #g.buttons do
        local b = g.buttons[i]
        if b:IsShown() then
            b:Hide()
            b.entry = nil
            DisableBinding(b)
            b.glowAnim:Stop()
        end
    end
    g.count = shown
end

----------------------------------------------------------------------------------------
-- Test auras
----------------------------------------------------------------------------------------
local TEST = {
    buffs = {
        { "Power Word: Fortitude", "Interface\\Icons\\Spell_Holy_WordFortitude", 1800, 1210 },
        { "Arcane Intellect", "Interface\\Icons\\Spell_Holy_MagicalSentry", 1800, 95 },
        { "Mark of the Wild", "Interface\\Icons\\Spell_Nature_Regeneration", 1800, 3200, nil, true },
        { "Blessing of Kings", "Interface\\Icons\\Spell_Magic_MageArmor", 300, 42 },
        { "Thorns", "Interface\\Icons\\Spell_Nature_Thorns", 600, 12 },
        { "Power Word: Shield", "Interface\\Icons\\Spell_Holy_PowerWordShield", 30, 7 },
        { "Battle Shout", "Interface\\Icons\\Ability_Warrior_BattleShout", 120, 4 },
        { "Well Fed", "Interface\\Icons\\Spell_Misc_Food", 900, 600 },
        { "Frost Armor", "Interface\\Icons\\Spell_Frost_FrostArmor02", 0, 0 },
        { "Lightning Shield", "Interface\\Icons\\Spell_Nature_LightningShield", 600, 330, 3 },
    },
    debuffs = {
        { "Curse of Agony", "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", 24, 14, nil, nil, "Curse" },
        { "Deadly Poison", "Interface\\Icons\\Ability_Rogue_DualWeild", 12, 9, 4, nil, "Poison" },
        { "Shadow Word: Pain", "Interface\\Icons\\Spell_Shadow_ShadowWordPain", 18, 5, nil, nil, "Magic" },
        { "Weakened Soul", "Interface\\Icons\\Spell_Holy_AshesToAshes", 15, 11 },
    },
    weapons = {
        { "Brilliant Wizard Oil", "Interface\\Icons\\INV_Potion_105", 1800, 1440, nil, nil, nil, 16 },
        { "Instant Poison", "Interface\\Icons\\Ability_Poisons", 1800, 50, 42, nil, nil, 17 },
    },
    watch = {
        { "Arcane Intellect", "Interface\\Icons\\Spell_Holy_MagicalSentry" },
    },
}

function D:TestEntries(key)
    local now = GetTime()
    local out = {}
    for i, t in ipairs(TEST[key] or {}) do
        local e = {
            test = true, index = i, filter = key, name = t[1], nameOK = true, icon = t[2],
            duration = t[3] or 0, expiration = (t[3] or 0) > 0 and (now + t[4]) or 0,
            count = t[5], important = t[6], dispel = t[7], weapon = t[8],
            harmful = key == "debuffs", missing = key == "watch",
        }
        e.permanent = e.missing or e.duration == 0
        out[#out + 1] = e
    end
    return out
end

function D:SetTestMode(on)
    D.testMode = on and true or false
    D.testStart = GetTime()
    D.testCache = nil
    D:RequestUpdate()
end

----------------------------------------------------------------------------------------
-- Update cycle
----------------------------------------------------------------------------------------
function D:RequestUpdate()
    D.dirty = true
end


----------------------------------------------------------------------------------------
-- Combat mode. While auras are secret the client refuses to list them to addons, so the
-- buff and debuff groups hand over to a client-driven AuraContainer, styled to match.
----------------------------------------------------------------------------------------
local NATIVE_FILTER = { buffs = "HELPFUL", debuffs = "HARMFUL" }

function D:NativeAvailable()
    if D.nativeOK ~= nil then return D.nativeOK end
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    D.nativeOK = (C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate")
        and AnchorUtil and AnchorUtil.FlowDirection) and true or false
    return D.nativeOK
end

function D:AurasSecret()
    if not (C_Secrets and C_Secrets.ShouldAurasBeSecret) then return false end
    local ok, v = pcall(C_Secrets.ShouldAurasBeSecret)
    return ok and v == true
end

local function StyleNativeButton(g, button)
    local db, cfg = T.db, g.cfg
    local r = g.nativeRegions[button]
    if not r then
        r = {}
        r.shadow = button:CreateTexture(nil, "BACKGROUND", nil, -8)
        r.shadow:SetTexture(WHITE)
        r.shadow:SetVertexColor(0, 0, 0, 0.55)
        r.dispel = button:CreateTexture(nil, "BACKGROUND", nil, -7)
        r.icon = button:CreateTexture(nil, "ARTWORK")
        button:SetIcon(r.icon)
        r.border = CreateBorder(button, "OVERLAY", 1)
        r.gloss = button:CreateTexture(nil, "ARTWORK", nil, 3)
        r.gloss:SetTexture(WHITE)
        r.gloss:SetBlendMode("ADD")
        r.cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        r.cd:SetReverse(true)
        r.cd:SetDrawEdge(false)
        if r.cd.SetDrawBling then r.cd:SetDrawBling(false) end
        r.cd.noCooldownCount = true
        r.over = CreateFrame("Frame", nil, button)
        r.over:SetAllPoints(button)
        r.timer = r.over:CreateFontString(nil, "OVERLAY")
        r.count = r.over:CreateFontString(nil, "OVERLAY")
        if C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
            local ok, b = pcall(C_DurationUtil.CreateDurationTextBinding)
            if ok and b then
                pcall(b.SetFontString, b, r.timer)
                r.binding = b
            end
        end
        g.nativeRegions[button] = r
    end
    local S, bs = g.nativeSize, db.borderSize
    local timerBelow = cfg.timer == "BOTTOM" or cfg.timer == "TOP"
    button:SetSize(S, g.nativeCellH)
    if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(db.tooltips and not db.clickThrough) end

    local iconTop = cfg.timer == "TOP" and -(g.nativeCellH - S) or 0
    r.icon:ClearAllPoints()
    r.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, iconTop)
    r.icon:SetSize(S, S)
    local zoom = db.theme == "CLASSIC" and 0 or db.iconZoom
    r.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
    local modern = db.theme == "MODERN" or db.theme == "GLOSS"
    r.shadow:ClearAllPoints()
    r.shadow:SetPoint("TOPLEFT", r.icon, -bs - 2, bs + 2)
    r.shadow:SetPoint("BOTTOMRIGHT", r.icon, bs + 2, -bs - 2)
    r.shadow:SetShown(modern)
    r.border:SetThickness(bs, r.icon)
    local c = db.colors.border
    r.border:SetColor(c[1], c[2], c[3], 1)
    local harmful = (g.filter or NATIVE_FILTER[g.key]) == "HARMFUL"
    r.border:SetShown(modern and not harmful)
    r.gloss:ClearAllPoints()
    r.gloss:SetPoint("TOPLEFT", r.icon)
    r.gloss:SetPoint("TOPRIGHT", r.icon)
    r.gloss:SetHeight(S * 0.5)
    SetGradient(r.gloss, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.22)
    r.gloss:SetShown(db.theme == "GLOSS")

    r.cd:ClearAllPoints()
    r.cd:SetAllPoints(r.icon)
    r.cd:SetSwipeColor(0, 0, 0, db.swipeAlpha)
    if r.cd.SetHideCountdownNumbers then r.cd:SetHideCountdownNumbers(true) end
    if db.swipe then
        r.cd:Show()
        pcall(button.SetDurationCooldown, button, r.cd)
    else
        r.cd:Hide()
    end

    r.over:SetFrameLevel(button:GetFrameLevel() + 5)
    ApplyFont(r.timer, db.timerFontSize)
    ApplyFont(r.count, db.countFontSize)
    r.timer:ClearAllPoints()
    if cfg.timer == "BOTTOM" then
        r.timer:SetPoint("TOP", r.icon, "BOTTOM", 1, -(bs + 2))
    elseif cfg.timer == "TOP" then
        r.timer:SetPoint("BOTTOM", r.icon, "TOP", 1, bs + 2)
    else
        r.timer:SetPoint("CENTER", r.icon, "CENTER", 1, 0)
    end
    r.timer:SetShown(cfg.timer ~= "NONE")
    if r.binding then
        if T.nativeFormatter then pcall(r.binding.SetFormatter, r.binding, T.nativeFormatter) end
        if T.nativeColorCurve and Enum.DurationTextBindingProperty then
            pcall(r.binding.SetTextColorCurve, r.binding, T.nativeColorCurve, Enum.DurationTextBindingProperty.RemainingDuration)
        end
        pcall(button.ClearDurationText, button)
        pcall(button.SetDurationText, button, r.timer, { binding = r.binding })
    end
    r.count:ClearAllPoints()
    r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, 1)
    pcall(button.SetApplicationCount, button, r.count, {})

    -- Debuffs: the client colours this plate by dispel type; it shows as the border.
    pcall(button.ClearDispelTypeTextures, button)
    if harmful then
        r.dispel:ClearAllPoints()
        r.dispel:SetPoint("TOPLEFT", r.icon, -bs - 1, bs + 1)
        r.dispel:SetPoint("BOTTOMRIGHT", r.icon, bs + 1, -bs - 1)
        r.dispel:Show()
        pcall(button.AddDispelTypeTexture, button, r.dispel, { showWhenHarmful = true, showWhenHelpful = false })
    else
        r.dispel:Hide()
    end
end

local function HiddenSpellIDs()
    local ids = {}
    for key in pairs(T.db.lists.hidden) do
        local id = tonumber(key) or A.idByName[key]
        if id then ids[id] = true end
    end
    return ids
end

function D:ConfigureNative(g)
    local cfg = g.cfg
    if not g.native then
        g.native = CreateFrame("AuraContainer", nil, g.frame, "CustomAuraContainerTemplate")
        g.nativeRegions = setmetatable({}, { __mode = "k" })
        g.nativeKey = "Tempus_" .. (g.id or g.key)
    end
    local c = g.native
    -- Icon layout even when the group uses bars: the client draws icon buttons only.
    local S = cfg.style == "BARS" and math.max(cfg.barHeight + 4, 24) or cfg.size
    local cellH = S
    if cfg.timer == "BOTTOM" or cfg.timer == "TOP" then cellH = S + T.db.timerFontSize + 3 end
    g.nativeSize, g.nativeCellH = S, cellH
    local perRow = cfg.style == "BARS" and 10 or cfg.perRow
    local corner = D:Corner(cfg)
    local FD = AnchorUtil.FlowDirection
    c:SetEnabled(false)
    c:Hide()
    c:ClearAllPoints()
    c:SetSize(S, cellH)
    c:SetPoint(corner, g.frame, corner, 0, 0)
    -- Only when the unit token changes: the container follows the token itself (target
    -- changes included), and setting the same token again adds a second copy of each aura.
    local unit = g.unit or "player"
    if g.nativeUnit ~= unit then
        c:SetUnit(unit)
        g.nativeUnit = unit
    end
    c:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    c:SetFlowLayoutAnchorPoint(corner)
    c:SetFlowLayoutGrowthDirection(cfg.growX == "LEFT" and FD.Left or FD.Right, cfg.growY == "UP" and FD.Up or FD.Down)
    c:SetFlowLayoutMaximumLineSize(perRow * S + (perRow - 1) * cfg.spacing)
    local SM = rawget(_G, "AuraContainerSortMethod") or { Default = 1, ExpirationOnly = 2 }
    local SD = rawget(_G, "AuraContainerSortDirection") or { Normal = 1, Reverse = 2 }
    local candidate = { excludeSpellIDs = HiddenSpellIDs() }
    if cfg.onlyMine then candidate.isFromPlayerOrPlayerPet = true end
    local options = {
        maxFrameCount = perRow * cfg.rows,
        sortMethod = cfg.sort == "TIME" and SM.ExpirationOnly or SM.Default,
        sortDirection = cfg.reverse and SD.Reverse or SD.Normal,
        initializeFrame = function(button) StyleNativeButton(g, button) end,
        candidateFilters = candidate,
        layout = { elementWidth = S, elementHeight = cellH, elementSpacing = cfg.spacing, lineSpacing = cfg.spacing },
    }
    if c:HasAuraGroup(g.nativeKey) then
        c:SetAuraGroupMaxFrameCount(g.nativeKey, options.maxFrameCount)
        c:SetAuraGroupCandidateFilters(g.nativeKey, options.candidateFilters)
        c:SetAuraGroupLayout(g.nativeKey, options.layout)
        c:SetAuraGroupSortMethod(g.nativeKey, options.sortMethod, options.sortDirection)
    else
        c:AddAuraGroup(g.nativeKey, g.filter or NATIVE_FILTER[g.key], options)
    end
    if not D:AurasSecret() then
        for button in pairs(g.nativeRegions) do StyleNativeButton(g, button) end
    end
    g.nativeVersion = D.styleVersion
end

-- Returns true when the group is being drawn by the client this update.
function D:UpdateNative(g, wanted)
    if wanted and not D.nativeFailed and NATIVE_FILTER[g.key] and D:NativeAvailable() then
        if g.nativeVersion ~= D.styleVersion then
            local ok, err = pcall(D.ConfigureNative, D, g)
            if not ok then
                D.nativeFailed = true
                if TempusDB and TempusDB.debug then TempusDB.debug.nativeError = tostring(err) end
                return false
            end
        end
        if not g.nativeActive then
            g.native:Show()
            g.native:SetEnabled(true)
            g.nativeActive = true
        end
        return true
    end
    if g.nativeActive then
        g.native:SetEnabled(false)
        g.native:Hide()
        g.nativeActive = false
    end
    return false
end

local function ReportError(err)
    if TempusDB then
        TempusDB.debug = TempusDB.debug or {}
        TempusDB.debug.lastError = { err = tostring(err), combat = InCombatLockdown(), at = date("%H:%M:%S") }
    end
    if not D.errorShown then
        D.errorShown = true
        T:Print("|cffff5050error:|r %s", tostring(err))
    end
end

function D:Update()
    D.dirty = false
    local ok, err = xpcall(D.UpdateInner, debugstack and function(e) return tostring(e) .. "\n" .. debugstack(2, 6, 0) end or tostring, D)
    if not ok then ReportError(err) end
end

function D:UpdateInner()
    if not T.db then return end
    local testing = D.testMode or not T.db.locked
    local secret = D:AurasSecret()
    local rawBuffs, rawDebuffs, rawWeapons
    if testing then
        -- Alerts always watch the real buffs, even while the groups show preview auras.
        if T.ProcessAlerts then
            pcall(function() T:ProcessAlerts(A:ScanFilter("HELPFUL", {}), A:ScanWeapons({})) end)
        end
        if not D.testCache then
            D.testStart = D.testStart or GetTime()
            D.testCache = {}
            for _, key in ipairs(D.groupOrder) do
                D.testCache[key] = D:TestEntries(key)
            end
        end
    else
        D.testCache = nil
        rawBuffs = A:ScanFilter("HELPFUL", {})
        rawDebuffs = A:ScanFilter("HARMFUL", {})
        rawWeapons = A:ScanWeapons({})
        if T.ProcessAlerts then T:ProcessAlerts(rawBuffs, rawWeapons) end
    end
    for _, key in ipairs(D.groupOrder) do
        local g = D.groups[key]
        local cfg = g.cfg
        if cfg.enabled then
            local list
            if testing then
                list = {}
                for _, e in ipairs(D.testCache[key]) do list[#list + 1] = e end
                if key == "buffs" and T.db.mergeWeapons then
                    for _, e in ipairs(D.testCache.weapons) do list[#list + 1] = e end
                elseif key == "weapons" and T.db.mergeWeapons then
                    list = {}
                end
            elseif key == "buffs" then
                local raw = rawBuffs
                if T.db.mergeWeapons then
                    raw = {}
                    for _, e in ipairs(rawBuffs) do raw[#raw + 1] = e end
                    for _, e in ipairs(rawWeapons) do raw[#raw + 1] = e end
                end
                list = A:Filter(raw, cfg)
            elseif key == "debuffs" then
                list = A:Filter(rawDebuffs, cfg)
            elseif key == "weapons" then
                list = T.db.mergeWeapons and {} or A:Filter(rawWeapons, cfg)
            else
                list = A:CollectMissing(rawBuffs)
            end
            if D:UpdateNative(g, secret and not testing) then list = {} end
            D:Populate(g, list)
        else
            D:UpdateNative(g, false)
            D:Populate(g, {})
        end
    end
    D:SyncProxy()
end

function D:Rebuild()
    D.styleVersion = D.styleVersion + 1
    for _, key in ipairs(D.groupOrder) do
        local g = D.groups[key]
        g.cfg = T.db.groups[key]
        D:LayoutGroup(g)
    end
    D.testCache = nil
    D:HideBlizzard()
    D:Update()
end

----------------------------------------------------------------------------------------
-- Tooltips, secure right-click cancelling and left-click recasting
----------------------------------------------------------------------------------------
local function CanCancel(e)
    return T.db.rightClickCancel and e and not e.test and not e.missing and not e.harmful
        and not e.unsureIndex and not e.stale
end

local function Known(id)
    if not T.Num(id) then return false end
    local ok, known = pcall(IsPlayerSpell or IsSpellKnown or function() return false end, id)
    if ok and T.Readable(known) and known then return true end
    if IsSpellKnown and IsSpellKnown ~= IsPlayerSpell then
        ok, known = pcall(IsSpellKnown, id)
        return ok and T.Readable(known) and known and true or false
    end
    return false
end

local function SpellIdFromName(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        return ok and type(info) == "table" and info.spellID or nil
    elseif GetSpellInfo then
        local ok, _, _, _, _, _, _, id = pcall(GetSpellInfo, name)
        return ok and id or nil
    end
end

local function ItemCount(name)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not fn then return 0 end
    local ok, n = pcall(fn, name)
    return ok and T.Num(n) and n or 0
end

-- What a left-click would do: ("spell", name) for a spell you know, ("item", name) for a
-- matching consumable in your bags, or nil. Casting by name picks the highest rank.
function D:RecastAction(e)
    if not T.db.clickToRecast or not e or e.test or e.harmful then return nil end
    if not e.weapon and (Known(e.spellId) or (e.nameOK and Known(SpellIdFromName(e.name)))) then
        if e.nameOK then return "spell", e.name end
        return "spell", e.spellId
    end
    if e.nameOK and ItemCount(e.name) > 0 then return "item", e.name end
    return nil
end

local function CanAct(e)
    return CanCancel(e) or D:RecastAction(e) ~= nil
end

function D:ShowTooltip(b, anchor)
    local e = b.entry
    if not e or not T.db.tooltips then return end
    GameTooltip:SetOwner(anchor or b, "ANCHOR_BOTTOMLEFT")
    if e.test then
        GameTooltip:SetText(e.name, 1, 1, 1)
        GameTooltip:AddLine("Tempus preview aura", T.accent[1], T.accent[2], T.accent[3])
    elseif e.missing then
        GameTooltip:SetText(e.name, 1, 0.35, 0.3)
        GameTooltip:AddLine("Missing - this buff from your watch list is not active.", 0.9, 0.9, 0.9, true)
    elseif e.weapon then
        GameTooltip:SetInventoryItem("player", e.weapon)
    else
        GameTooltip:SetUnitAura("player", e.index, e.filter)
    end
    if not e.secret and not e.permanent and not e.missing and e.expiration then
        local rem = e.expiration - GetTime()
        if rem > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Remaining", T.FormatTime(rem) .. (T.db.timerFormat == "SMART" and rem < 60 and "s" or ""), 0.7, 0.75, 0.8, 1, 1, 1)
        end
    end
    if not InCombatLockdown() and not e.test then
        local kind, what = D:RecastAction(e)
        if kind == "spell" then
            GameTooltip:AddLine((e.missing and "Left-click to cast " or "Left-click to recast ") .. tostring(what), 0.5, 1, 0.6)
        elseif kind == "item" then
            GameTooltip:AddLine("Left-click to use " .. what .. (e.weapon and " on this weapon" or ""), 0.5, 1, 0.6)
        end
        if CanCancel(e) then GameTooltip:AddLine("Right-click to cancel", 0.5, 0.8, 1) end
    end
    GameTooltip:Show()
end

local function CreateProxy()
    proxy = CreateFrame("Button", "TempusCancelButton", UIParent, "SecureActionButtonTemplate")
    proxy:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    proxy:SetAttribute("useOnKeyDown", false)
    proxy:SetAttribute("unit", "player")
    proxy:SetAttribute("type2", "cancelaura")
    proxy:Hide()
    proxy:SetScript("OnEnter", function(self)
        if self.owner then D:ShowTooltip(self.owner, self) end
    end)
    proxy:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if not InCombatLockdown() then
            self:Hide()
            self.owner = nil
        end
    end)
    proxy:HookScript("PostClick", function(self)
        if not InCombatLockdown() then
            self:Hide()
            self.owner = nil
        end
        D.reenter = true
        D:RequestUpdate()
    end)
end

local function SetProxyTarget(e)
    -- Left button. Button-suffixed names keep "spell" from reaching cancelaura on the right button.
    local kind, what = D:RecastAction(e)
    proxy:SetAttribute("type1", kind)
    proxy:SetAttribute("spell1", kind == "spell" and what or nil)
    proxy:SetAttribute("item1", kind == "item" and what or nil)
    -- Right button
    proxy:SetAttribute("type2", CanCancel(e) and "cancelaura" or nil)
    if e.weapon then
        proxy:SetAttribute("target-slot", e.weapon)
        proxy:SetAttribute("index", nil)
        proxy:SetAttribute("filter", nil)
    else
        proxy:SetAttribute("target-slot", nil)
        proxy:SetAttribute("index", not e.missing and e.index or nil)
        proxy:SetAttribute("filter", e.filter)
    end
end

-- After any aura change the hovered icon may show a different aura: retarget or drop the proxy.
function D:SyncProxy()
    if not proxy or InCombatLockdown() then return end
    local owner = proxy.owner
    if proxy:IsShown() then
        if owner and owner:IsShown() and owner:IsMouseOver() and CanAct(owner.entry) then
            SetProxyTarget(owner.entry)
            return
        end
        proxy:Hide()
        proxy.owner = nil
        GameTooltip:Hide()
    end
    if D.reenter then
        D.reenter = nil
        for _, key in ipairs(D.groupOrder) do
            for i = 1, D.groups[key].count or 0 do
                local b = D.groups[key].buttons[i]
                if b:IsMouseOver() then D:OnButtonEnter(b) return end
            end
        end
    end
end

function D:OnButtonEnter(b)
    local e = b.entry
    if proxy and not InCombatLockdown() and CanAct(e) then
        -- Place the secure button over the icon using absolute coordinates, so no
        -- insecure frame becomes an anchor dependency of a protected one.
        local left, bottom, w, h = b:GetRect()
        if left then
            local ratio = b:GetEffectiveScale() / proxy:GetEffectiveScale()
            proxy:ClearAllPoints()
            proxy:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
            proxy:SetSize(w * ratio, h * ratio)
            proxy:SetFrameStrata(b:GetFrameStrata())
            proxy:SetFrameLevel(b:GetFrameLevel() + 20)
            SetProxyTarget(e)
            proxy.owner = b
            proxy:Show()
            return
        end
    end
    D:ShowTooltip(b)
end

----------------------------------------------------------------------------------------
-- Blizzard frames
----------------------------------------------------------------------------------------
function D:HideBlizzard()
    if not T.db.hideBlizzard or D.blizzHidden then return end
    D.blizzHidden = true
    local hider = T.Style.HiddenParent
    for _, name in ipairs({ "BuffFrame", "TemporaryEnchantFrame", "DebuffFrame" }) do
        local f = _G[name]
        if f then
            pcall(f.UnregisterAllEvents, f)
            pcall(f.SetParent, f, hider)
        end
    end
end

----------------------------------------------------------------------------------------
-- Init and driver
----------------------------------------------------------------------------------------
function D:Init()
    for _, key in ipairs(D.groupOrder) do
        D.groups[key] = CreateGroup(key)
    end
    CreateProxy()

    local ev = CreateFrame("Frame")
    ev:RegisterUnitEvent("UNIT_AURA", "player")
    ev:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_UPDATE_RESTING")
    ev:RegisterEvent("PLAYER_DEAD")
    ev:RegisterEvent("PLAYER_ALIVE")
    ev:RegisterEvent("PLAYER_UNGHOST")
    ev:SetScript("OnEvent", T:Wrap("buffs.events", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" and proxy:IsShown() then
            proxy:Hide()
            proxy.owner = nil
        end
        D:RequestUpdate()
    end))

    local tick, poll = 0, 0
    ev:SetScript("OnUpdate", T:Wrap("buffs.tick+scan", function(_, elapsed)
        if D.dirty then D:Update() end
        poll = poll + elapsed
        if poll >= 1 then          -- weapon enchants have no expiry event
            poll = 0
            D:RequestUpdate()
        end
        tick = tick + elapsed
        if tick < 0.05 then return end
        tick = 0
        local now = GetTime()
        for _, key in ipairs(D.groupOrder) do
            local g = D.groups[key]
            if g.cfg and g.cfg.enabled then
                for i = 1, g.count or 0 do D:TickButton(g.buttons[i], now) end
            end
        end
    end))

    D:Rebuild()
end
