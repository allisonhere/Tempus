-- Tempus UI: first-run setup. Four steps: welcome, modules, UI scale, layout preset.
-- Reopen any time with /tempus install.
local _, T = ...
local UI = T.UI
local S = T.Style
local C, AC = S.C, T.accent
local Tex, Text, FlatButton = UI.Tex, UI.Text, UI.FlatButton

local I = {}
T.Installer = I

local W_, H_ = 560, 420
local win, steps, stepIndex, body = nil, {}, 1, nil
-- Default keeps what you have; the presets are opt-in.
local choice = { scale = "KEEP", preset = "NONE" }

----------------------------------------------------------------------------------------
-- UI scale. The CVar cannot go below 0.64, so pixel-perfect scale is applied to
-- UIParent directly and re-applied at every login.
----------------------------------------------------------------------------------------
local function PixelPerfectScale()
    local _, h = GetPhysicalScreenSize()
    if not T.Num(h) or h <= 0 then return nil end
    return math.max(0.4, math.min(1.15, 768 / h))
end

function T:ApplyUIScale()
    local v = T.db and T.db.uiScale
    if not v then return end
    T:RunOOC(function() UIParent:SetScale(v) end, "uiscale")
end

----------------------------------------------------------------------------------------
-- Layout presets
----------------------------------------------------------------------------------------
I.presets = {
    { key = "BALANCED", label = "Balanced", desc = "Class-coloured frames with 3D portraits, two action bars, icon buffs, standard nameplates and party frames. A clean all-rounder.",
        apply = function(db)
            db.theme = "MODERN"
            db.unitframes.healthColor = "CLASS"
            db.unitframes.units.player.portrait = "3D"
            db.unitframes.units.target.portrait = "3D"
            for _, bar in pairs(db.actionbars.bars) do bar.fade = "NONE" end
            db.databar.count = 5
            local np, gf = db.nameplates, db.groupframes
            np.width, np.height, np.healthText, np.conMarker = 140, 12, "PERCENT", "CHEVRONS"
            gf.healthColor, gf.healthText, gf.powerHeight = "CLASS", "NONE", 4
            gf.party.width, gf.party.height, gf.raid.width, gf.raid.height = 130, 46, 84, 42
        end },
    { key = "MINIMAL", label = "Minimal", desc = "Dark frames without portraits, side bars on mouseover, compact buffs, slim nameplates and small group frames. Maximum screen space.",
        apply = function(db)
            db.theme = "FLAT"
            db.unitframes.healthColor = "DARK"
            for _, u in pairs(db.unitframes.units) do u.portrait = "NONE" end
            for key, bar in pairs(db.actionbars.bars) do
                if key ~= "bar1" and key ~= "stance" then bar.fade = "MOUSEOVER" end
            end
            for _, g in pairs(db.groups) do g.size = 28; g.spacing = 3; g.timer = "CENTER" end
            db.databar.count = 4
            db.minimap.zoneText = "MOUSEOVER"
            local np, gf = db.nameplates, db.groupframes
            np.width, np.height, np.nameSize, np.healthText = 120, 8, 9, "NONE"
            np.nonTargetAlpha, np.debuffSize, np.buffs = 0.5, 18, "NONE"
            gf.healthColor, gf.healthText, gf.powerHeight = "DARK", "NONE", 0
            gf.party.width, gf.party.height, gf.raid.width, gf.raid.height = 110, 38, 72, 34
        end },
    { key = "DETAILED", label = "Detailed", desc = "Gloss theme, health-gradient frames, three action bars, buff timer bars, a full info bar, nameplates with danger ratings and large healer frames.",
        apply = function(db)
            db.theme = "GLOSS"
            db.unitframes.healthColor = "GRADIENT"
            db.actionbars.bars.bar3.enabled = true
            db.groups.buffs.style = "BARS"
            db.databar.count = 8
            db.databar.width = 900
            db.databar.slots = { "system", "durability", "bags", "gold", "coords", "xp", "friends", "time" }
            db.minimap.coords = true
            local np, gf = db.nameplates, db.groupframes
            np.width, np.height, np.healthText, np.conMarker = 150, 14, "BOTH", "DANGER"
            gf.healthColor, gf.healthText, gf.powerHeight = "GRADIENT", "PERCENT", 5
            gf.party.width, gf.party.height, gf.raid.width, gf.raid.height = 150, 52, 90, 46
        end },
}

----------------------------------------------------------------------------------------
-- Steps
----------------------------------------------------------------------------------------
local function Option(parent, y, label, desc, selected, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", 24, y)
    b:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
    b:SetHeight(desc and 52 or 32)
    b.bg = Tex(b, "BACKGROUND", C.card)
    b.bg:SetAllPoints()
    b.edge = UI.Border(b, selected and { AC[1], AC[2], AC[3], 1 } or { 1, 1, 1, 0.1 })
    local t = Text(b, 13, selected and AC or C.text)
    t:SetPoint("TOPLEFT", 12, desc and -9 or -9)
    t:SetText(label)
    if desc then
        local d = Text(b, 11, C.muted)
        d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
        d:SetPoint("RIGHT", b, "RIGHT", -12, 0)
        d:SetText(desc)
    end
    b:SetScript("OnEnter", function(self) self.bg:SetVertexColor(C.cardHi[1], C.cardHi[2], C.cardHi[3]) end)
    b:SetScript("OnLeave", function(self) self.bg:SetVertexColor(C.card[1], C.card[2], C.card[3]) end)
    b:SetScript("OnClick", function() onClick(); I:Show(stepIndex) end)
    return b
end

steps[1] = { title = "Welcome to Tempus UI", build = function(f)
    local t = Text(f, 13, C.text)
    t:SetPoint("TOPLEFT", 24, -10)
    t:SetPoint("RIGHT", f, "RIGHT", -24, 0)
    t:SetSpacing(4)
    t:SetText("A complete interface in one clean look: buff timers, unit frames, nameplates, party and raid frames, "
        .. "action bars, a square minimap, an info bar and skins for Blizzard's windows, tooltips, chat, Bagnon and DBM.\n\n"
        .. "This short setup picks which parts to use, your UI scale and a starting layout. "
        .. "Everything can be changed later with |cff" .. T.accentHex .. "/tempus|r, and you can run this again with "
        .. "|cff" .. T.accentHex .. "/tempus install|r.\n\n"
        .. "Tip: |cff" .. T.accentHex .. "/tempus unlock|r shows a box for every element so you can drag things where you like.")
end }

steps[2] = { title = "Modules", build = function(f)
    local y = -6
    local intro = Text(f, 12, C.muted)
    intro:SetPoint("TOPLEFT", 24, y)
    intro:SetText("Turn off anything another addon already does for you.")
    y = y - 26
    for _, key in ipairs(T.moduleOrder) do
        local m = T.modules[key]
        local cb = UI.W.Check(m.label or key, function() return T:ModuleEnabled(key) end, function(v)
            T.db.modules[key] = v and true or false
        end)
        cb:SetParent(f)
        cb:SetPoint("TOPLEFT", 24, y)
        cb:SetWidth(W_ - 48)
        cb:SetScript("OnClick", function(self)
            T.db.modules[key] = not T:ModuleEnabled(key)
            self:Refresh()
        end)
        cb:Refresh()
        y = y - 28
    end
end }

steps[3] = { title = "UI scale", build = function(f)
    local pp = PixelPerfectScale()
    local _, h = GetPhysicalScreenSize()
    local y = -6
    local cur = UIParent:GetScale()
    local opts = {
        { "PIXEL", ("Pixel perfect  (%.2f)"):format(pp or 1), "Every 1px border lands exactly on a screen pixel. Crispest look; everything is smaller on high-resolution screens." },
        { "LARGE", "Large  (0.71)", "Bigger interface, still sharp." },
        { "KEEP", ("Keep current  (%.2f)"):format(cur), "Leave the game's own UI scale setting alone." },
    }
    for _, o in ipairs(opts) do
        Option(f, y, o[2], o[3], choice.scale == o[1], function() choice.scale = o[1] end)
        y = y - 60
    end
    local note = Text(f, 11, C.muted)
    note:SetPoint("TOPLEFT", 24, y - 4)
    note:SetText(("Screen height: %s px"):format(T.Num(h) and h or "?"))
end }

steps[4] = { title = "Starting layout", build = function(f)
    local y = -6
    for _, p in ipairs(I.presets) do
        Option(f, y, p.label, p.desc, choice.preset == p.key, function() choice.preset = p.key end)
        y = y - 60
    end
    Option(f, y, "Keep my current settings", "Only apply modules and scale.", choice.preset == "NONE", function() choice.preset = "NONE" end)
end }

----------------------------------------------------------------------------------------
-- Window
----------------------------------------------------------------------------------------
local function Finish()
    local db = T.db
    if choice.scale == "PIXEL" then db.uiScale = PixelPerfectScale()
    elseif choice.scale == "LARGE" then db.uiScale = 0.71
    else db.uiScale = nil end
    for _, p in ipairs(I.presets) do
        if p.key == choice.preset then pcall(p.apply, db) end
    end
    TempusDB.installed = T.version
    ReloadUI()
end

function I:Show(index)
    stepIndex = index
    if body then body:Hide() end
    body = CreateFrame("Frame", nil, win)
    body:SetPoint("TOPLEFT", 0, -100)
    body:SetPoint("BOTTOMRIGHT", 0, 56)
    local step = steps[index]
    win.stepTitle:SetText(step.title)
    win.stepCount:SetText(("STEP %d OF %d"):format(index, #steps))
    for i, dot in ipairs(win.dots) do
        dot:SetVertexColor(i <= index and AC[1] or 0.25, i <= index and AC[2] or 0.27, i <= index and AC[3] or 0.32, 1)
    end
    step.build(body)
    win.back:SetShown(index > 1)
    win.next.text:SetText(index == #steps and "Finish & reload" or "Next")
end

local function Create()
    win = CreateFrame("Frame", "TempusInstaller", UIParent)
    win:SetSize(W_, H_)
    win:SetPoint("CENTER")
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    local bd = S.Backdrop(win, { fill = C.bg })
    bd:SetEdgeColor(AC[1] * 0.5, AC[2] * 0.5, AC[3] * 0.5)
    local head = Tex(win, "BACKGROUND", { 1, 1, 1, 1 }, -5)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(64)
    S.SetGradient(head, "HORIZONTAL", AC[1] * 0.3, AC[2] * 0.3, AC[3] * 0.3, 0.95, 0.05, 0.055, 0.07, 0.3)
    local logo = win:CreateTexture(nil, "ARTWORK")
    logo:SetSize(40, 40)
    logo:SetPoint("TOPLEFT", 18, -12)
    logo:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
    logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local title = Text(win, 22, AC)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -1)
    title:SetText("Tempus UI")
    win.stepCount = Text(win, 10, C.muted)
    win.stepCount:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 12, 2)
    win.dots = {}
    for i = 1, #steps do
        local d = Tex(win, "ARTWORK", C.line)
        d:SetSize(34, 3)
        d:SetPoint("TOPRIGHT", win, "TOPRIGHT", -18 - (#steps - i) * 40, -30)
        win.dots[i] = d
    end
    win.stepTitle = Text(win, 16, C.text)
    win.stepTitle:SetPoint("TOPLEFT", 24, -76)

    win.next = FlatButton(win, "Next", 130, 30, function()
        if stepIndex < #steps then I:Show(stepIndex + 1) else Finish() end
    end)
    win.next:SetPoint("BOTTOMRIGHT", -18, 16)
    win.next:SetActive(true)
    win.back = FlatButton(win, "Back", 90, 30, function() I:Show(stepIndex - 1) end)
    win.back:SetPoint("RIGHT", win.next, "LEFT", -8, 0)
    local skip = FlatButton(win, "Skip setup", 110, 30, function()
        TempusDB.installed = T.version
        win:Hide()
    end)
    skip:SetPoint("BOTTOMLEFT", 18, 16)

    local close = CreateFrame("Button", nil, win)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -8, -8)
    local x = Text(close, 16, C.muted)
    x:SetPoint("CENTER")
    x:SetJustifyH("CENTER")
    x:SetText("x")
    close:SetScript("OnEnter", function() x:SetTextColor(1, 0.4, 0.4) end)
    close:SetScript("OnLeave", function() x:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    close:SetScript("OnClick", function() win:Hide() end)
    -- Escape closes it like any game window.
    tinsert(UISpecialFrames, "TempusInstaller")
end

function I:Open()
    if InCombatLockdown() then T:Print("setup opens after combat.") return end
    if not win then Create() end
    win:Show()
    I:Show(1)
end

-- First run: open shortly after login unless setup was done or skipped.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    T:ApplyUIScale()
    if not TempusDB.installed then
        -- Shown once, ever: the flag is saved as soon as it opens, however it is closed.
        TempusDB.installed = "shown " .. T.version
        C_Timer.After(2, function() if not InCombatLockdown() then I:Open() end end)
    end
end)
