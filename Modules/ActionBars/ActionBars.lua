-- Tempus UI: action bars. Blizzard's own buttons are moved into Tempus bars and restyled.
-- Their event code stays Blizzard's, so cooldowns, range and usability keep working in
-- combat even though those values are secret to addon code on this client.
local _, T = ...
local S = T.Style

local AB = { bars = {} }
T.ActionBars = AB

-- key, label, Blizzard bar frame, button prefix, button count, page constant name
AB.defs = {
    { key = "bar1", label = "Main Bar", blizz = "MainActionBar", prefix = "ActionButton", count = 12, paging = true },
    { key = "bar2", label = "Bar 2", blizz = "MultiBarBottomLeft", prefix = "MultiBarBottomLeftButton", count = 12 },
    { key = "bar3", label = "Bar 3", blizz = "MultiBarBottomRight", prefix = "MultiBarBottomRightButton", count = 12 },
    { key = "bar4", label = "Bar 4 (right)", blizz = "MultiBarRight", prefix = "MultiBarRightButton", count = 12 },
    { key = "bar5", label = "Bar 5 (right 2)", blizz = "MultiBarLeft", prefix = "MultiBarLeftButton", count = 12 },
    { key = "bar6", label = "Bar 6", blizz = "MultiBar5", prefix = "MultiBar5Button", count = 12 },
    { key = "bar7", label = "Bar 7", blizz = "MultiBar6", prefix = "MultiBar6Button", count = 12 },
    { key = "bar8", label = "Bar 8", blizz = "MultiBar7", prefix = "MultiBar7Button", count = 12 },
    { key = "stance", label = "Stance / Forms", blizz = "StanceBar", prefix = "StanceButton", count = 10, stance = true },
    { key = "pet", label = "Pet Bar", blizz = "PetActionBar", prefix = "PetActionButton", count = 10, pet = true },
}

local function Bar(point, x, y, overrides)
    local b = {
        enabled = true, buttons = 12, perRow = 12, size = 36, spacing = 4, scale = 1, alpha = 1,
        fade = "NONE",          -- NONE | MOUSEOVER | COMBAT
        fadeAlpha = 0,
        backdrop = false,
        point = { point, "UIParent", point, x, y },
    }
    for k, v in pairs(overrides or {}) do b[k] = v end
    return b
end

AB.defaults = {
    showHotkeys = true,
    showMacroNames = false,
    showCounts = true,
    hotkeySize = 12,
    swipeAlpha = 0.75,
    rangeColor = true,
    showEmpty = false,          -- empty slots on bars 2-8 (they always show while dragging)
    bars = {
        bar1 = Bar("BOTTOM", 0, 42),
        bar2 = Bar("BOTTOM", 0, 84),
        bar3 = Bar("BOTTOM", 0, 126, { enabled = false }),
        bar4 = Bar("RIGHT", -6, 0, { perRow = 1, size = 32 }),
        bar5 = Bar("RIGHT", -44, 0, { perRow = 1, size = 32, enabled = false }),
        bar6 = Bar("BOTTOM", 0, 168, { enabled = false }),
        bar7 = Bar("BOTTOM", 0, 210, { enabled = false }),
        bar8 = Bar("BOTTOM", 0, 252, { enabled = false }),
        stance = Bar("BOTTOMLEFT", 380, 172, { buttons = 10, perRow = 10, size = 28 }),
        pet = Bar("BOTTOMRIGHT", -380, 172, { buttons = 10, perRow = 10, size = 28 }),
    },
    micro = { enabled = true, scale = 0.85, fade = "MOUSEOVER", fadeAlpha = 0.25, point = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -6, 4 } },
    bags = { enabled = true, scale = 0.85, fade = "MOUSEOVER", fadeAlpha = 0.25, point = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -6, 48 } },
}

-- Classic paging: bar switching plus stance/form bonus bars (page 6 + bonus index).
local PAGING = "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "
    .. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; [bonusbar:5] 11; 1"

local hidden = S.HiddenParent

----------------------------------------------------------------------------------------
-- Button styling
----------------------------------------------------------------------------------------
local function Region(b, key, suffix)
    local r = b[key]
    if type(r) ~= "table" then r = b:GetName() and _G[b:GetName() .. suffix] end
    return type(r) == "table" and r or nil
end

local function HideArt(b)
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    for _, key in ipairs({ "SlotArt", "SlotBackground", "FloatingBG", "RightDivider", "BottomDivider", "BorderShadow", "NormalTexture" }) do
        local r = b[key]
        if type(r) == "table" and r.SetAlpha then r:SetAlpha(0) end
    end
    local fbg = b:GetName() and _G[b:GetName() .. "FloatingBG"]
    if fbg then fbg:SetAlpha(0) end
end

function AB:StyleButton(b)
    local db = AB.db
    if not b.tempusStyled then
        b.tempusStyled = true
        local icon = Region(b, "icon", "Icon")
        b.tempusIcon = icon
        if icon then
            if b.IconMask and icon.RemoveMaskTexture then pcall(icon.RemoveMaskTexture, icon, b.IconMask) end
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            icon:SetDrawLayer("ARTWORK")
            icon:ClearAllPoints()
            icon:SetAllPoints(b)
        end
        HideArt(b)
        if b.UpdateButtonArt then hooksecurefunc(b, "UpdateButtonArt", HideArt) end
        b.tempusBd = S.Backdrop(b, { fill = { 0.03, 0.035, 0.045, 1 } })

        local hl = b:GetHighlightTexture()
        if hl then
            hl:SetTexture(S.WHITE)
            hl:SetVertexColor(1, 1, 1, 0.15)
            hl:SetAllPoints(b)
            hl:SetBlendMode("ADD")
        end
        local pushed = b:GetPushedTexture()
        if pushed then
            pushed:SetTexture(S.WHITE)
            pushed:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 0.35)
            pushed:SetAllPoints(b)
        end
        if b.GetCheckedTexture and b:GetCheckedTexture() then
            local ck = b:GetCheckedTexture()
            ck:SetTexture(S.WHITE)
            ck:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 0.3)
            ck:SetAllPoints(b)
            ck:SetBlendMode("ADD")
        end
        local border = Region(b, "Border", "Border")     -- equipped-item frame
        if border then border:SetAlpha(0) end
        local flash = Region(b, "Flash", "Flash")
        if flash then
            flash:SetTexture(S.WHITE)
            flash:SetVertexColor(1, 0.2, 0.2, 0.35)
            flash:SetAllPoints(b)
        end
        local cd = Region(b, "cooldown", "Cooldown")
        if cd then
            cd:ClearAllPoints()
            cd:SetAllPoints(b)
        end
    end

    local cd = Region(b, "cooldown", "Cooldown")
    if cd and cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, db.swipeAlpha) end
    local hk = Region(b, "HotKey", "HotKey")
    if hk then
        S.ApplyFont(hk, db.hotkeySize)
        hk:ClearAllPoints()
        hk:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -2)
        hk:SetJustifyH("RIGHT")
        hk:SetAlpha(db.showHotkeys and 1 or 0)
    end
    local count = Region(b, "Count", "Count")
    if count then
        S.ApplyFont(count, db.hotkeySize + 1)
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 2)
        count:SetAlpha(db.showCounts and 1 or 0)
    end
    local name = Region(b, "Name", "Name")
    if name then
        S.ApplyFont(name, math.max(db.hotkeySize - 2, 8))
        name:ClearAllPoints()
        name:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
        name:SetAlpha(db.showMacroNames and 1 or 0)
    end
    HideArt(b)
end

----------------------------------------------------------------------------------------
-- Bars
----------------------------------------------------------------------------------------
-- Blizzard button code sometimes reaches up to its bar (fields, or methods called from
-- secure snippets). Our bar answers with the original bar's values so nothing is nil.
local function InheritFromBlizzardBar(bar, blizz)
    if not blizz then return end
    for k, v in pairs(blizz) do
        if bar[k] == nil and type(k) == "string" then
            local t = type(v)
            if t == "string" or t == "number" or t == "boolean" then
                bar[k] = v
            elseif t == "function" then
                bar[k] = function(_, ...) return v(blizz, ...) end
            end
        end
    end
end

local function CreateBar(def)
    -- Plain frames: restricted snippets fail on this client (TempusDB.probe.secureTests),
    -- and visibility/attribute drivers do not need a secure handler template.
    local bar = CreateFrame("Frame", "TempusBar_" .. def.key, UIParent)
    InheritFromBlizzardBar(bar, _G[def.blizz])
    bar.def = def
    bar.buttons = {}
    bar:SetFrameStrata("LOW")
    bar.bd = S.Backdrop(bar)
    bar.bd:SetShown(false)
    for i = 1, def.count do
        local b = _G[def.prefix .. i]
        if b then
            bar.buttons[i] = b
            -- Pin each multibar button to its current page before it leaves its Blizzard parent.
            if not def.stance and not def.pet and not def.paging then
                local page = b:GetAttribute("actionpage")
                if not page and T.Num(b.action) and b.action > 0 then page = math.ceil(b.action / 12) end
                if page then b:SetAttribute("actionpage", page) end
            end
        end
    end
    if def.paging then
        -- Blizzard's main buttons carry useparent-actionpage, so they read the page from
        -- whatever frame holds them. An attribute driver sets it on this bar directly -
        -- the secure state manager does the work, in combat too, with no snippet.
        for _, b in pairs(bar.buttons) do
            b:SetAttribute("actionpage", nil)
            b:SetAttribute("useparent-actionpage", true)
        end
        RegisterAttributeDriver(bar, "actionpage", PAGING)
    end
    return bar
end

-- Out of combat, re-assert the paging setup (Blizzard code can set a button's own page).
function AB:SyncPage()
    local bar = AB.bars.bar1
    if not bar or InCombatLockdown() then return end
    for _, b in pairs(bar.buttons) do
        if b:GetAttribute("actionpage") ~= nil then b:SetAttribute("actionpage", nil) end
        if not b:GetAttribute("useparent-actionpage") then b:SetAttribute("useparent-actionpage", true) end
    end
end

function AB:LayoutBar(bar)
    local def, cfg = bar.def, AB.db.bars[bar.def.key]
    bar.cfg = cfg
    if not cfg.enabled then
        UnregisterStateDriver(bar, "visibility")
        bar:Hide()
        for _, b in pairs(bar.buttons) do b:SetParent(hidden) end
        return
    end
    local n = math.min(cfg.buttons, def.count)
    local perRow = math.max(1, math.min(cfg.perRow, n))
    local rows = math.ceil(n / perRow)
    local size, sp = cfg.size, cfg.spacing
    bar:SetScale(cfg.scale)
    bar:SetSize(perRow * size + (perRow - 1) * sp, rows * size + (rows - 1) * sp)
    bar.bd:SetShown(cfg.backdrop)
    for i, b in pairs(bar.buttons) do
        if i <= n then
            b:SetParent(bar)
            b:ClearAllPoints()
            b:SetSize(size, size)
            local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
            b:SetPoint("TOPLEFT", bar, "TOPLEFT", col * (size + sp), -row * (size + sp))
            AB:StyleButton(b)
            -- Visibility of each slot is decided by AB:UpdateEmpty.
        else
            b:SetParent(hidden)
        end
    end
    T.Movers.ApplyPoint(bar, cfg)
    if def.pet then
        RegisterStateDriver(bar, "visibility", "[pet] show; hide")
    elseif def.stance then
        local forms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
        RegisterStateDriver(bar, "visibility", (T.Num(forms) and forms > 0) and "show" or "hide")
    else
        RegisterStateDriver(bar, "visibility", "show")
    end
end

----------------------------------------------------------------------------------------
-- Micro menu and bag buttons: Blizzard frames we only move, scale and fade.
----------------------------------------------------------------------------------------
local placing = {}
local function PlaceBlizz(key, frame)
    local cfg = AB.db[key]
    if not frame or not cfg.enabled then return end
    placing[frame] = true
    frame:SetScale(cfg.scale)
    frame:ClearAllPoints()
    local p = cfg.point
    frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    placing[frame] = nil
end

local function MicroFrame() return MicroMenuContainer or MicroMenu end
local function BagsFrame() return BagsBar or MicroButtonAndBagsBar end

function AB:PlaceMenus()
    PlaceBlizz("micro", MicroFrame())
    PlaceBlizz("bags", BagsFrame())
end

local function HookPlacement(key, frame)
    if not frame or frame.tempusHooked then return end
    frame.tempusHooked = true
    -- Edit Mode re-positions these; put them back whenever it does.
    hooksecurefunc(frame, "SetPoint", function(self)
        if placing[self] or not AB.db[key].enabled or InCombatLockdown() then return end
        C_Timer.After(0, function() if not InCombatLockdown() then PlaceBlizz(key, self) end end)
    end)
end

----------------------------------------------------------------------------------------
-- Fading
----------------------------------------------------------------------------------------
local function FadeTarget(frame, cfg, inCombat)
    if cfg.fade == "NONE" or not cfg.fade then return cfg.alpha or 1 end
    if frame:IsMouseOver(4, -4, -4, 4) then return cfg.alpha or 1 end
    if cfg.fade == "COMBAT" and inCombat then return cfg.alpha or 1 end
    return cfg.fadeAlpha
end

local function FadeTick()
    local inCombat = InCombatLockdown()
    for _, bar in pairs(AB.bars) do
        if bar.cfg and bar.cfg.enabled and bar:IsShown() then
            local a = FadeTarget(bar, bar.cfg, inCombat)
            if math.abs(bar:GetAlpha() - a) > 0.01 then bar:SetAlpha(bar:GetAlpha() + (a - bar:GetAlpha()) * 0.35) end
        end
    end
    for key, fn in pairs({ micro = MicroFrame, bags = BagsFrame }) do
        local f, cfg = fn(), AB.db[key]
        if f and cfg.enabled then
            local a = FadeTarget(f, cfg, inCombat)
            if math.abs(f:GetAlpha() - a) > 0.01 then f:SetAlpha(f:GetAlpha() + (a - f:GetAlpha()) * 0.35) end
        end
    end
end

----------------------------------------------------------------------------------------
-- Module
----------------------------------------------------------------------------------------
function AB:HideBlizzard()
    for _, def in ipairs(AB.defs) do
        -- Tempus owns every bar's buttons now, so the Blizzard containers are only art.
        local f = _G[def.blizz]
        if f then pcall(f.SetParent, f, hidden) end
    end
    -- The art/end caps live on the main bar in older layouts.
    for _, name in ipairs({ "MainMenuBarArtFrame", "MainMenuBarArtFrameBackground" }) do
        local f = _G[name]
        if f then pcall(f.SetParent, f, hidden) end
    end
end

-- Bars 2-8 hide empty slots (unless showEmpty, or while a spell or item is being dragged).
-- The main bar always shows all its slots: its actions change as it pages, in combat too.
function AB:UpdateEmpty()
    T:RunOOC(function()
        for _, bar in pairs(AB.bars) do
            local def, cfg = bar.def, bar.cfg
            if cfg and cfg.enabled and not def.pet and not def.stance then
                local n = math.min(cfg.buttons, def.count)
                for i, b in pairs(bar.buttons) do
                    if i <= n then
                        local show = def.paging or AB.db.showEmpty or AB.dragging
                        if not show then
                            local slot = b.action
                            if not T.Num(slot) and b.CalculateAction then
                                local ok, v = pcall(b.CalculateAction, b)
                                if ok then slot = v end
                            end
                            local ok, has = pcall(HasAction, slot)
                            show = ok and has == true
                        end
                        b:SetShown(show and true or false)
                    end
                end
            end
        end
    end, "abempty")
end

function AB:Refresh()
    T:RunOOC(function()
        for _, bar in pairs(AB.bars) do AB:LayoutBar(bar) end
        AB:PlaceMenus()
        AB:SyncPage()
    end, "ablayout")
    AB:UpdateEmpty()
end

T:NewModule("actionbars", {
    label = "Action Bars",
    desc = "Ten restyled, movable action bars with paging for stances and forms, mouseover fading, and a movable micro menu and bags.",
    defaults = AB.defaults,
    OnEnable = function()
        AB.db = T.db.actionbars
        T:RunOOC(function()
            for _, def in ipairs(AB.defs) do
                if _G[def.prefix .. "1"] then
                    local bar = CreateBar(def)
                    AB.bars[def.key] = bar
                    T.Movers:Register(bar, {
                        label = def.label, page = "ab_" .. def.key, secure = true,
                        cfg = function() return AB.db.bars[def.key] end,
                        enabled = function() return AB.db.bars[def.key].enabled end,
                    })
                end
            end
            AB:HideBlizzard()
            for key, fn in pairs({ micro = MicroFrame, bags = BagsFrame }) do
                local f = fn()
                if f then
                    HookPlacement(key, f)
                    T.Movers:Register(f, {
                        label = key == "micro" and "Micro Menu" or "Bags", page = "ab_menus",
                        cfg = function() return AB.db[key] end,
                        enabled = function() return AB.db[key].enabled end,
                    })
                end
            end
            AB:Refresh()
        end, "abinit")

        local ev = CreateFrame("Frame")
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        ev:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        ev:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
        ev:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
        ev:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        ev:RegisterEvent("ACTIONBAR_SHOWGRID")
        ev:RegisterEvent("ACTIONBAR_HIDEGRID")
        if C_EditMode then ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED") end
        ev:SetScript("OnEvent", T:Wrap("actionbars.events", function(_, event)
            if event == "ACTIONBAR_SHOWGRID" or event == "ACTIONBAR_HIDEGRID" then
                AB.dragging = event == "ACTIONBAR_SHOWGRID"
                AB:UpdateEmpty()
            elseif event == "ACTIONBAR_SLOT_CHANGED" then
                AB:UpdateEmpty()
            elseif event == "UPDATE_BONUS_ACTIONBAR" or event == "ACTIONBAR_PAGE_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
                AB:SyncPage()
            else
                AB:Refresh()
            end
        end))
        local t = 0
        ev:SetScript("OnUpdate", T:Wrap("actionbars.fade", function(_, elapsed)
            t = t + elapsed
            if t < 0.05 then return end
            t = 0
            FadeTick()
        end))
    end,
    OnSettings = function()
        AB.db = T.db.actionbars
        AB:Refresh()
    end,
})
