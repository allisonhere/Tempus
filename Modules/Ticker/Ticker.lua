-- Tempus UI: resource ticker. One thin bar showing when your next energy or mana tick lands.
-- Energy and mana come in on a fixed 2-second server clock; the bar learns its phase from
-- the ticks it sees (a gain the size a regular tick should be). For mana it also shows the
-- five-second rule: after you spend mana, spirit regen stops for 5 seconds, and the bar
-- counts that down in its own colour before going back to tick timing.
local _, T = ...
local S = T.Style
local TK = {}
T.Ticker = TK

TK.defaults = {
    enabled = true,
    energy = true,              -- energy ticks (rogues, druids in cat form)
    mana = true,                -- mana ticks and the five-second rule
    showFsr = true,             -- the 5-second countdown after spending mana
    showText = true,            -- current power on the bar
    width = 220, height = 8,
    visibility = "AUTO",        -- AUTO (in combat or not full) | COMBAT | ALWAYS
    point = { "CENTER", "UIParent", "CENTER", 0, -238 },
}

TK.PERIOD = 2               -- seconds between server regen ticks
TK.FSR = 5                  -- the five-second rule
local ENERGY_COLOR = { 1, 0.86, 0.45 }   -- warm gold
local MANA_COLOR = { 0.45, 0.68, 1 }     -- clear blue
local FSR_COLOR = { 0.72, 0.62, 0.95 }   -- soft violet: mana regen is paused
TK.ENERGY_COLOR, TK.MANA_COLOR, TK.FSR_COLOR = ENERGY_COLOR, MANA_COLOR, FSR_COLOR

local POWER_MANA, POWER_ENERGY = 0, 3
if Enum and Enum.PowerType then
    POWER_MANA = Enum.PowerType.Mana or POWER_MANA
    POWER_ENERGY = Enum.PowerType.Energy or POWER_ENERGY
end

-- Does a gain of delta look like a regular tick? expected is what a tick should give (nil
-- when the client cannot say). A tick that runs into the cap gives less, so at the cap any
-- gain up to the expected amount counts.
function TK.IsTick(delta, expected, atMax)
    if not (T.Num(delta) and delta > 0) then return false end
    if not (T.Num(expected) and expected > 0) then return true end
    local tol = math.max(2, expected * 0.15)
    if math.abs(delta - expected) <= tol then return true end
    return atMax and delta <= expected + tol or false
end

-- Where the next tick lands, from the last tick seen: seconds left and the fraction done.
function TK.Phase(lastTick, now, period)
    period = period or TK.PERIOD
    if not lastTick then return nil end
    local since = (now - lastTick) % period
    return period - since, since / period
end

-- What the bar shows right now: "FSR" (5-second rule counting down), "TICK" or nil.
function TK.Mode(kind, lastTick, fsrEnd, now, showFsr)
    if kind == "mana" and showFsr and fsrEnd and now < fsrEnd then return "FSR" end
    if lastTick then return "TICK" end
end

-- Regen per tick the client reports for the current power.
local function ExpectedTick(kind, inFsr)
    if kind == "energy" and GetPowerRegen then
        local ok, base = pcall(GetPowerRegen)
        if ok and T.Num(base) and base > 0 then return base * TK.PERIOD end
        return 20
    elseif kind == "mana" and GetManaRegen then
        local ok, base, casting = pcall(GetManaRegen)
        if ok then
            local r = inFsr and casting or base
            if T.Num(r) and r > 0 then return r * TK.PERIOD end
        end
    end
end

local function CurrentKind(db)
    if not UnitPowerType then return nil end
    local ok, ptype = pcall(UnitPowerType, "player")
    if not ok then return nil end
    if ptype == POWER_ENERGY and db.energy then return "energy", POWER_ENERGY end
    if ptype == POWER_MANA and db.mana then return "mana", POWER_MANA end
end

local function Power(ptype)
    local okA, cur = pcall(UnitPower, "player", ptype)
    local okB, max = pcall(UnitPowerMax, "player", ptype)
    if okA and okB and T.Num(cur) and T.Num(max) and not T.issecret(cur) then return cur, max end
end

-- Bar colour for what it shows: violet during the five-second rule, else by power type.
function TK.ColorFor(mode, kind)
    if mode == "FSR" then return FSR_COLOR end
    return kind == "energy" and ENERGY_COLOR or MANA_COLOR
end

-- A "view" is anything with bar, spark, text and label (the real ticker or a settings demo)
-- plus its state: kind, lastTick, fsrEnd, last (current power) and mode.
local function ColorView(v)
    local c = TK.ColorFor(v.mode, v.kind)
    v.bar:SetStatusBarColor(c[1], c[2], c[3])
    -- White with an outline, like the swing bars: readable over the fill and the empty part.
    v.text:SetTextColor(1, 1, 1)
    v.label:SetTextColor(1, 1, 1)
end

function TK:ColorBar() ColorView(self) end

local function Paint(v, db, now)
    local mode = TK.Mode(v.kind, v.lastTick, v.fsrEnd, now, db.showFsr)
    if mode ~= v.mode then
        v.mode = mode
        ColorView(v)
        v.label:SetText(mode == "FSR" and "5s" or "")
    end
    if mode == "FSR" then
        v.bar:SetValue((v.fsrEnd - now) / TK.FSR)
    elseif mode == "TICK" then
        local _, done = TK.Phase(v.lastTick, now)
        v.bar:SetValue(done)
    else
        v.bar:SetValue(0)
    end
    v.spark:SetShown(mode ~= nil)
    if db.showText and v.last then
        if mode == "FSR" then v.text:SetFormattedText("%.1f", v.fsrEnd - now)
        else v.text:SetText(v.last) end
    else
        v.text:SetText("")
    end
end

-- Bar, spark and texts on frame f, stored on view v.
local function BuildView(v, f)
    v.bar = S.StatusBar(f)
    v.bar:SetPoint("TOPLEFT", 1, -1)
    v.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    v.bar:SetMinMaxValues(0, 1)
    v.spark = v.bar:CreateTexture(nil, "OVERLAY")
    v.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    v.spark:SetBlendMode("ADD")
    v.spark:SetPoint("CENTER", v.bar:GetStatusBarTexture(), "RIGHT")
    local over = CreateFrame("Frame", nil, f)
    over:SetAllPoints(f)
    over:SetFrameLevel(v.bar:GetFrameLevel() + 2)
    v.text = over:CreateFontString(nil, "OVERLAY")
    v.text:SetPoint("RIGHT", -4, 0)
    S.ApplyFont(v.text, 9, nil, "OUTLINE")
    v.label = over:CreateFontString(nil, "OVERLAY")
    v.label:SetPoint("LEFT", 4, 0)
    S.ApplyFont(v.label, 9, nil, "OUTLINE")
end

-- Power changed: learn the tick phase and, for mana, start the five-second rule on a spend.
function TK:OnPower()
    if self.preview then return end
    local kind, ptype = CurrentKind(self.db)
    if kind ~= self.kind then
        self.kind, self.ptype, self.lastTick, self.fsrEnd, self.last = kind, ptype, nil, nil, nil
        self:Refresh()
    end
    if not kind then return end
    local cur, max = Power(ptype)
    if not cur then return end
    local now, prev = GetTime(), self.last
    self.last, self.max = cur, max
    if prev then
        local delta = cur - prev
        if delta < 0 and kind == "mana" then
            self.fsrEnd = now + TK.FSR
        elseif delta > 0 then
            local inFsr = self.fsrEnd and now < self.fsrEnd
            if TK.IsTick(delta, ExpectedTick(kind, inFsr), cur >= max) then self.lastTick = now end
        end
    end
    self:UpdateShown()
end

local function OnUpdate()
    local self = TK
    local now = GetTime()
    if self.preview then
        -- Fake ticks every 2s; every third cycle a mana bar pretends a spell was cast.
        if not self.lastTick or now - self.lastTick >= TK.PERIOD then
            self.lastTick = now
            self.previewN = (self.previewN or 0) + 1
            if self.kind == "mana" and self.previewN % 4 == 1 then self.fsrEnd = now + TK.FSR end
        end
        self.last, self.max = 60 + 10 * ((self.previewN or 0) % 4), 100
    end
    Paint(self, self.db, now)
end

function TK:SetPreview(on)
    on = on and true or false
    if on and InCombatLockdown and InCombatLockdown() then return false end
    if self.preview == on then return on end
    self.preview = on
    self.lastTick, self.fsrEnd, self.last, self.previewN = nil, nil, nil, nil
    if on then
        self.kind = CurrentKind(self.db) or (self.db.mana and "mana") or "energy"
    else
        self.kind = nil
        self:OnPower()
    end
    self.mode = false
    self:Refresh()
    return on
end

function TK:UpdateShown()
    local f, db = self.frame, self.db
    if not (f and db) then return end
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
    local notFull = self.last and self.max and self.last < self.max
    local vis = db.visibility
    local show = db.enabled and self.kind and (self.preview or not T.db.locked or vis == "ALWAYS"
        or inCombat or (vis == "AUTO" and notFull))
    f:SetShown(show and true or false)
end

function TK:Refresh()
    local db, f = self.db, self.frame
    if not (db and f) then return end
    f:SetSize(db.width, db.height)
    local size = math.max(7, math.min(db.height - 1, 11))
    S.ApplyFont(self.text, size, nil, "OUTLINE")
    S.ApplyFont(self.label, size, nil, "OUTLINE")
    self.text:SetShown(db.showText and db.height >= 7)
    self.label:SetShown(db.height >= 7)
    self.spark:SetSize(8, db.height * 2)
    self.mode = false        -- repaint on the next frame
    if not self.preview then
        local kind, ptype = CurrentKind(db)
        if kind ~= self.kind then self.kind, self.ptype, self.lastTick, self.fsrEnd, self.last = kind, ptype, nil, nil, nil end
        if self.ptype then self.last, self.max = Power(self.ptype) end
    end
    self:UpdateShown()
end

-- Settings demo: an energy bar and a mana bar ticking on their own, painted by the same code
-- as the real ticker. Energy is spent now and then and ticks back up; the mana bar casts
-- every few ticks, which starts the violet five-second rule.
function TK.CreateDemo(width)
    local box = CreateFrame("Frame")
    local views = {}
    for i, kind in ipairs({ "energy", "mana" }) do
        local f = CreateFrame("Frame", nil, box)
        S.Backdrop(f)
        local v = { kind = kind, frame = f, n = 0, last = kind == "energy" and 100 or 70 }
        BuildView(v, f)
        views[i] = v
    end
    local height = 0
    function box:Refresh()
        local db = T.db.ticker
        local y = 0
        for _, v in ipairs(views) do
            local w = math.min(db.width, width)
            v.frame:SetSize(w, db.height)
            v.frame:ClearAllPoints()
            v.frame:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
            y = y + db.height + 4
            local size = math.max(7, math.min(db.height - 1, 11))
            S.ApplyFont(v.text, size, nil, "OUTLINE")
            S.ApplyFont(v.label, size, nil, "OUTLINE")
            v.text:SetShown(db.showText and db.height >= 7)
            v.label:SetShown(db.height >= 7)
            v.spark:SetSize(8, db.height * 2)
            v.mode = false
        end
        height = y
        box:SetSize(width, math.max(y, 1))
    end
    box:Refresh()
    T.UI.Loop(box, 0.03, function(_, now)
        local db = T.db.ticker
        for _, v in ipairs(views) do
            if not v.lastTick or now - v.lastTick >= TK.PERIOD then
                v.lastTick = now
                v.n = v.n + 1
                if v.kind == "energy" then
                    -- Spend 40 every third tick, otherwise gain 20 up to the cap.
                    if v.n % 3 == 0 then v.last = math.max(0, v.last - 40) else v.last = math.min(100, v.last + 20) end
                else
                    if v.n % 4 == 1 then v.fsrEnd = now + TK.FSR; v.last = math.max(10, v.last - 25)
                    elseif not (v.fsrEnd and now < v.fsrEnd) then v.last = math.min(100, v.last + 6) end
                end
            end
            Paint(v, db, now)
        end
    end)
    return box
end

T:NewModule("ticker", {
    label = "Resource ticker",
    desc = "A thin bar timing your next energy or mana tick, with the five-second rule for casters.",
    defaults = TK.defaults,
    OnEnable = function()
        TK.db = T.db.ticker
        local f = CreateFrame("Frame", "TempusResourceTicker", UIParent)
        f:SetFrameStrata("MEDIUM")
        S.Backdrop(f)
        TK.frame = f
        BuildView(TK, f)
        f:SetScript("OnUpdate", T:Wrap("ticker.update", OnUpdate))
        T.Movers.ApplyPoint(f, TK.db)
        T.Movers:Register(f, {
            label = "Resource ticker", page = "ticker",
            cfg = function() return TK.db end,
            corner = function() return TK.db.point[1] end,
            enabled = function() return TK.db.enabled end,
        })
        local ev = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_DISABLED",
            "PLAYER_REGEN_ENABLED" }) do
            pcall(ev.RegisterEvent, ev, event)
        end
        for _, event in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
            pcall(ev.RegisterUnitEvent, ev, event, "player")
        end
        ev:SetScript("OnEvent", T:Wrap("ticker.events", function(_, event)
            if event == "PLAYER_REGEN_DISABLED" then
                if TK.preview then TK:SetPreview(false) end
                TK:UpdateShown()
            elseif event == "PLAYER_REGEN_ENABLED" then
                TK:UpdateShown()
            elseif event == "UNIT_POWER_FREQUENT" then
                TK:OnPower()
            else
                TK:Refresh()
                TK:OnPower()
            end
        end))
        TK:Refresh()
    end,
    OnSettings = function()
        TK.db = T.db.ticker
        if TK.frame then
            T.Movers.ApplyPoint(TK.frame, TK.db)
            TK:Refresh()
        end
    end,
})
