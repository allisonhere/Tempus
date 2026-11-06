-- Tempus UI: swing timer. A bar per weapon (main hand, off hand, ranged) refilled on every
-- PLAYER_SWING, dimmed and tinted red while C_SwingTimer reports the target out of auto
-- attack range. The range check is new in WoW Forever; without it the bars still time swings.
local _, T = ...
local S = T.Style
local SW = { rows = {} }
T.Swing = SW

SW.defaults = {
    enabled = true,
    width = 220, height = 12, spacing = 3,
    offHand = true, ranged = true,
    showTime = true,
    effects = true,             -- spark swell and a flash when the swing is ready
    cue = true,                 -- a tick and a gold bar for the last moments: press on-next-swing moves now
    cueWindow = 0.4,            -- seconds before the swing lands that the cue starts
    cueLatency = true,          -- widen the cue by your home latency so the press lands in time
    cueSound = false,           -- a short sound when the cue starts
    visibility = "COMBAT",      -- COMBAT | ALWAYS
    point = { "CENTER", "UIParent", "CENTER", 0, -215 },
}

local OUT_OF_RANGE = { 0.85, 0.2, 0.2 }
local DIM = 0.45
local FLASH = 0.3           -- seconds the ready flash takes to fade
local CUE_COLOR = { 1, 0.82, 0.2 }
local SWELL = 0.25          -- the spark grows during the last quarter second

-- Swing types in display order. Enum.PlayerSwingType: MainHand 0, OffHand 1, Ranged 2.
local TYPES = {
    { key = "main", label = "Main hand", enum = "MainHand", fallback = 0 },
    { key = "off", label = "Off hand", enum = "OffHand", fallback = 1 },
    { key = "ranged", label = "Ranged", enum = "Ranged", fallback = 2 },
}
for _, t in ipairs(TYPES) do
    t.id = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType[t.enum] or t.fallback
end

-- Which rows to show for the given attack speeds (nil or 0 = no such weapon).
function SW.Wanted(db, mainSpeed, offSpeed, rangedSpeed)
    local out = { main = true }
    if db.offHand and (T.Num(offSpeed) and offSpeed > 0) then out.off = true end
    if db.ranged and (T.Num(rangedSpeed) and rangedSpeed > 0) then out.ranged = true end
    return out
end

-- Out of range only when the client actually made the check and the target failed it;
-- C_SwingTimer documents that nil ("no check made") must not be treated as out of range.
function SW.OutOfRange(isInRange, checksRange)
    if checksRange == false then return false end
    return isInRange == false
end

-- Seconds before a swing lands that the cue opens. An on-next-swing ability has to reach
-- the server before the swing does, so the window is the chosen lead plus (optionally)
-- the round-trip delay, and never longer than most of the swing itself.
function SW.CueWindow(db, latencyMs, duration)
    local w = (T.Num(db.cueWindow) and db.cueWindow or 0.4)
    if db.cueLatency and T.Num(latencyMs) and latencyMs > 0 then w = w + latencyMs / 1000 end
    if T.Num(duration) and duration > 0 then w = math.min(w, duration * 0.6) end
    return math.max(w, 0)
end

-- The swing to show on a single strip: the first running one, main hand first. Returns nil
-- while nothing is swinging, otherwise a table with endT, duration and outOfRange.
function SW.Status()
    if not (SW.db and SW.db.enabled) then return nil end
    for _, kind in ipairs(TYPES) do
        local row = SW.rows[kind.key]
        if row and row.wanted and row.endT then
            return { endT = row.endT, duration = row.duration, outOfRange = row.outOfRange and true or false }
        end
    end
end

-- Other modules (Combat Pulse) set listener to hear when a swing starts, ends or changes range.
local function Notify()
    if SW.listener then SW.listener() end
end

local function AttackSpeeds()
    if not UnitAttackSpeed then return end
    local ok, main, off, ranged = pcall(UnitAttackSpeed, "player")
    if ok then return main, off, ranged end
end

local function RangeAPI()
    return C_SwingTimer and C_SwingTimer.EnableRangeCheck and C_SwingTimer.IsTargetWithinSwingRange and C_SwingTimer
end

local function ColorRow(row)
    local c = row.outOfRange and OUT_OF_RANGE or (row.cueing and CUE_COLOR) or (row.type.key == "main" and T.accent)
        or (row.type.key == "off" and { T.accent[1] * 0.7, T.accent[2] * 0.7, T.accent[3] * 0.7 })
        or { 0.4, 0.8, 0.45 }
    row.bar:SetStatusBarColor(c[1], c[2], c[3])
    row:SetAlpha(row.outOfRange and DIM or 1)
    local t = row.outOfRange and OUT_OF_RANGE or { 1, 1, 1 }
    row.label:SetTextColor(t[1], t[2], t[3])
    row.time:SetTextColor(t[1], t[2], t[3])
end

local function RowOnUpdate(row)
    local now = GetTime()
    if row.flashT then
        local a = 1 - (now - row.flashT) / FLASH
        if a <= 0 then
            row.flashT = nil
            row.flash:Hide()
        else
            row.flash:SetAlpha(a * 0.55)
        end
    end
    if not row.endT then return end
    local left = row.endT - now
    if left <= 0 then
        row.endT = nil
        row.bar:SetValue(0)
        row.time:SetText("")
        row.spark:Hide()
        row.cueing, row.cueAt = false, nil
        row.tick:Hide()
        ColorRow(row)
        if SW.db.effects and not row.outOfRange then
            row.flashT = now
            row.flash:SetAlpha(0.55)
            row.flash:Show()
        end
        SW:UpdateShown()
        Notify()
        return
    end
    row.bar:SetValue(row.duration - left)
    if row.cueAt then
        local cueing = left <= row.cueAt
        if cueing ~= row.cueing then
            row.cueing = cueing
            ColorRow(row)
            if cueing and SW.db.cueSound and not row.outOfRange and PlaySound and SOUNDKIT and SOUNDKIT.UI_BNET_TOAST then
                pcall(PlaySound, SOUNDKIT.UI_BNET_TOAST)
            end
        end
    end
    if SW.db.showTime then row.time:SetFormattedText("%.1f", left) end
    if SW.db.effects then
        local k = left < SWELL and (1 - left / SWELL) or 0
        row.spark:SetSize(10 + 14 * k, row.sparkH * (1 + 0.6 * k))
    end
end

local function NewRow(parent, kind)
    local row = CreateFrame("Frame", nil, parent)
    row.type = kind
    S.Backdrop(row)
    row.bar = S.StatusBar(row)
    row.bar:SetPoint("TOPLEFT", 1, -1)
    row.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)
    row.spark = row.bar:CreateTexture(nil, "OVERLAY")
    row.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    row.spark:SetBlendMode("ADD")
    row.spark:SetPoint("CENTER", row.bar:GetStatusBarTexture(), "RIGHT")
    row.spark:Hide()
    local over = CreateFrame("Frame", nil, row)
    over:SetAllPoints(row)
    over:SetFrameLevel(row.bar:GetFrameLevel() + 2)
    row.tick = over:CreateTexture(nil, "ARTWORK")
    row.tick:SetColorTexture(CUE_COLOR[1], CUE_COLOR[2], CUE_COLOR[3], 0.9)
    row.tick:SetWidth(2)
    row.tick:Hide()
    row.flash = over:CreateTexture(nil, "ARTWORK")
    row.flash:SetColorTexture(1, 1, 1, 1)
    row.flash:SetPoint("TOPLEFT", 1, -1)
    row.flash:SetPoint("BOTTOMRIGHT", -1, 1)
    row.flash:Hide()
    row.label = over:CreateFontString(nil, "OVERLAY")
    row.label:SetPoint("LEFT", 5, 0)
    S.ApplyFont(row.label, 10)   -- a FontString needs a font before SetText; Refresh resizes it
    row.label:SetText(kind.label)
    row.time = over:CreateFontString(nil, "OVERLAY")
    row.time:SetPoint("RIGHT", -5, 0)
    S.ApplyFont(row.time, 10)
    row:SetScript("OnUpdate", T:Wrap("swing.update", RowOnUpdate))
    ColorRow(row)
    return row
end

function SW:Start(swingType, duration)
    if not T.Num(duration) or duration <= 0 then return end
    for _, row in pairs(self.rows) do
        if row.type.id == swingType and row.wanted then
            row.duration, row.endT = duration, GetTime() + duration
            row.bar:SetMinMaxValues(0, duration)
            row.bar:SetValue(0)
            row.spark:SetSize(10, row.sparkH or 24)
            row.spark:Show()
            row.cueing, row.cueAt = false, nil
            row.tick:Hide()
            if self.db.cue then
                local _, _, _, home = GetNetStats()
                local w = SW.CueWindow(self.db, home, duration)
                if w > 0 then
                    row.cueAt = w
                    local barW = row.bar:GetWidth()
                    if not T.Num(barW) or barW <= 0 then barW = self.db.width - 2 end
                    row.tick:ClearAllPoints()
                    row.tick:SetPoint("TOP", row.bar, "TOPLEFT", barW * (1 - w / duration), 0)
                    row.tick:SetPoint("BOTTOM", row.bar, "BOTTOMLEFT", barW * (1 - w / duration), 0)
                    row.tick:Show()
                end
            end
            ColorRow(row)
            row.flashT = nil
            row.flash:Hide()
            self:UpdateShown()
            Notify()
            return
        end
    end
end

function SW:SetRange(swingType, outOfRange)
    for _, row in pairs(self.rows) do
        if row.type.id == swingType and row.outOfRange ~= outOfRange then
            row.outOfRange = outOfRange
            ColorRow(row)
            Notify()
        end
    end
end

-- Ask C_SwingTimer for the current target, e.g. after a target change.
function SW:PollRange()
    local api = RangeAPI()
    for _, row in pairs(self.rows) do
        local out = false
        if api and row.wanted then
            local ok, inRange = pcall(api.IsTargetWithinSwingRange, row.type.id)
            out = ok and not T.issecret(inRange) and SW.OutOfRange(inRange) or false
        end
        if row.outOfRange ~= out then
            row.outOfRange = out
            ColorRow(row)
            Notify()
        end
    end
end

-- Range events only fire for swing types someone enabled. Blizzard's own swing timer turns
-- the same switch, so it is only turned off again when neither timer needs it.
function SW:UpdateRangeChecks()
    local api = RangeAPI()
    if not api then return end
    local blizzard = GetCVarBool and GetCVarBool("showSwingTimer")
    for _, row in pairs(self.rows) do
        local want = row.wanted and self.db.enabled
        if want ~= row.rangeOn and (want or not blizzard) then
            if pcall(api.EnableRangeCheck, row.type.id, want and true or false) then row.rangeOn = want end
        end
    end
end

function SW:UpdateShown()
    local f, db = self.frame, self.db
    if not (f and db) then return end
    local swinging = false
    for _, row in pairs(self.rows) do
        if row.endT then swinging = true end
    end
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
    local show = db.enabled and (db.visibility == "ALWAYS" or inCombat or swinging or not T.db.locked)
    f:SetShown(show and true or false)
end

function SW:Refresh()
    local db, f = self.db, self.frame
    if not (db and f) then return end
    local wanted = SW.Wanted(db, AttackSpeeds())
    local y, n = 0, 0
    for _, kind in ipairs(TYPES) do
        local row = self.rows[kind.key]
        if not row then row = NewRow(f, kind); self.rows[kind.key] = row end
        row.wanted = wanted[kind.key] or false
        row:SetShown(row.wanted)
        if row.wanted then
            row:SetSize(db.width, db.height)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
            y = y + db.height + db.spacing
            n = n + 1
            local size = math.max(8, math.min(db.height - 2, 12))
            S.ApplyFont(row.label, size)
            S.ApplyFont(row.time, size)
            row.label:SetShown(db.height >= 10)
            row.time:SetShown(db.showTime)
            row.sparkH = db.height * 2
            row.spark:SetSize(10, row.sparkH)
            ColorRow(row)
        else
            row.endT = nil
            row.cueing, row.cueAt = false, nil
            row.tick:Hide()
        end
    end
    f:SetSize(db.width, math.max(n * db.height + (n - 1) * db.spacing, db.height))
    self:UpdateRangeChecks()
    self:PollRange()
    self:UpdateShown()
    Notify()
end

T:NewModule("swing", {
    label = "Swing timer",
    desc = "Bars that time your auto attacks and turn red when the target is out of range.",
    defaults = SW.defaults,
    OnEnable = function()
        SW.db = T.db.swing
        local f = CreateFrame("Frame", "TempusSwingTimer", UIParent)
        f:SetFrameStrata("MEDIUM")
        SW.frame = f
        T.Movers.ApplyPoint(f, SW.db)
        T.Movers:Register(f, {
            label = "Swing timer", page = "swing",
            cfg = function() return SW.db end,
            corner = function() return SW.db.point[1] end,
            enabled = function() return SW.db.enabled end,
        })
        local ev = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "PLAYER_TARGET_CHANGED",
            "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "WEAPON_SLOT_CHANGED",
            "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
            pcall(ev.RegisterEvent, ev, event)   -- some events only exist on newer clients
        end
        pcall(ev.RegisterUnitEvent, ev, "UNIT_ATTACK_SPEED", "player")
        ev:SetScript("OnEvent", T:Wrap("swing.events", function(_, event, a, b, c)
            if event == "PLAYER_SWING" then
                SW:Start(b, a)
            elseif event == "PLAYER_SWING_RANGE_UPDATE" then
                if not (T.issecret(b) or T.issecret(c)) then SW:SetRange(a, SW.OutOfRange(b, c)) end
            elseif event == "PLAYER_TARGET_CHANGED" then
                SW:PollRange()
            elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
                SW:UpdateShown()
            else
                SW:Refresh()
            end
        end))
        SW:Refresh()
    end,
    OnSettings = function()
        SW.db = T.db.swing
        if SW.frame then
            T.Movers.ApplyPoint(SW.frame, SW.db)
            SW:Refresh()
        end
    end,
})
