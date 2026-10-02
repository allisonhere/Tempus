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
    visibility = "COMBAT",      -- COMBAT | ALWAYS
    point = { "CENTER", "UIParent", "CENTER", 0, -215 },
}

local OUT_OF_RANGE = { 0.85, 0.2, 0.2 }
local DIM = 0.45

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

local function AttackSpeeds()
    if not UnitAttackSpeed then return end
    local ok, main, off, ranged = pcall(UnitAttackSpeed, "player")
    if ok then return main, off, ranged end
end

local function RangeAPI()
    return C_SwingTimer and C_SwingTimer.EnableRangeCheck and C_SwingTimer.IsTargetWithinSwingRange and C_SwingTimer
end

local function ColorRow(row)
    local c = row.outOfRange and OUT_OF_RANGE or (row.type.key == "main" and T.accent)
        or (row.type.key == "off" and { T.accent[1] * 0.7, T.accent[2] * 0.7, T.accent[3] * 0.7 })
        or { 0.4, 0.8, 0.45 }
    row.bar:SetStatusBarColor(c[1], c[2], c[3])
    row:SetAlpha(row.outOfRange and DIM or 1)
    local t = row.outOfRange and OUT_OF_RANGE or { 1, 1, 1 }
    row.label:SetTextColor(t[1], t[2], t[3])
    row.time:SetTextColor(t[1], t[2], t[3])
end

local function RowOnUpdate(row)
    if not row.endT then return end
    local left = row.endT - GetTime()
    if left <= 0 then
        row.endT = nil
        row.bar:SetValue(0)
        row.time:SetText("")
        row.spark:Hide()
        SW:UpdateShown()
        return
    end
    row.bar:SetValue(row.duration - left)
    if SW.db.showTime then row.time:SetFormattedText("%.1f", left) end
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
            row.spark:Show()
            self:UpdateShown()
            return
        end
    end
end

function SW:SetRange(swingType, outOfRange)
    for _, row in pairs(self.rows) do
        if row.type.id == swingType and row.outOfRange ~= outOfRange then
            row.outOfRange = outOfRange
            ColorRow(row)
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
            row.spark:SetSize(10, db.height * 2)
            ColorRow(row)
        else
            row.endT = nil
        end
    end
    f:SetSize(db.width, math.max(n * db.height + (n - 1) * db.spacing, db.height))
    self:UpdateRangeChecks()
    self:PollRange()
    self:UpdateShown()
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
