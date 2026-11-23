-- Tempus UI: cooldown tracker. A row of icons for the spells you list (and your trinkets), each
-- with the game's own cooldown swipe, so it keeps working while cooldown numbers are hidden.
local _, T = ...
local S = T.Style
local CD = { icons = {} }
T.Cooldowns = CD

CD.defaults = {
    enabled = true,
    size = 36, spacing = 4,
    trinkets = true,            -- show equipped trinket cooldowns (slots 13 and 14)
    growX = "RIGHT",            -- RIGHT | LEFT
    mode = "icons",             -- icons (a row) | timeline (icons slide along a time scale)
    barWidth = 360,             -- timeline: length of the scale
    range = 60,                 -- timeline: seconds at the far end (30 | 60 | 120 | 300)
    showReady = false,          -- timeline: keep spells that are ready parked at the start
    point = { "CENTER", "UIParent", "CENTER", 0, -170 },
}

local TRINKET_SLOTS = { 13, 14 }

-- Timeline scale: equal-width steps between these marks, so the near seconds get the room.
local MARKS = { 0, 5, 15, 30, 60, 120, 300 }
local TRACK_H, LABEL_H = 6, 12

function CD.Marks(range)
    local out = {}
    for _, m in ipairs(MARKS) do if m <= range then out[#out + 1] = m end end
    if out[#out] ~= range then out[#out + 1] = range end
    return out
end

-- Where `t` seconds from now sits along the scale, 0 (ready) to 1 (the far end).
function CD.TimeFraction(t, marks)
    if t <= 0 then return 0 end
    local n = #marks - 1
    for i = 1, n do
        if t < marks[i + 1] then return (i - 1 + (t - marks[i]) / (marks[i + 1] - marks[i])) / n end
    end
    return 1
end

local function MarkLabel(m) return m >= 60 and (m / 60) .. "m" or tostring(m) end

local function SpellFor(entry)
    local id = tonumber(entry)
    if id then return id end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, entry)
        if ok and type(info) == "table" and T.Num(info.spellID) then return info.spellID end
    elseif GetSpellInfo then
        local ok, _, _, _, _, _, _, id2 = pcall(GetSpellInfo, entry)
        if ok and T.Num(id2) then return id2 end
    end
end

local function SpellTexture(id)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, id)
        if ok then return tex end
    end
    if GetSpellTexture then return GetSpellTexture(id) end
end

local function Known(id)
    local ok, known = pcall(IsPlayerSpell or IsSpellKnown, id)
    return ok and known == true
end

-- The wanted entries, in a stable order: your listed spells first (A-Z), then trinkets.
function CD:Wanted()
    local out = {}
    local keys = {}
    for key in pairs(T.db.lists.cooldowns or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    local seen = {}
    for _, key in ipairs(keys) do
        local id = SpellFor(T.db.lists.cooldowns[key])
        if id and not seen[id] and Known(id) then
            seen[id] = true
            out[#out + 1] = { spell = id }
        end
    end
    if CD.db.trinkets then
        for _, slot in ipairs(TRINKET_SLOTS) do
            if GetInventoryItemTexture and GetInventoryItemTexture("player", slot) then out[#out + 1] = { slot = slot } end
        end
    end
    return out
end

local SetCooldown

local function NewIcon(parent)
    local b = CreateFrame("Frame", nil, parent)
    S.Backdrop(b, { inner = false, shadow = false })
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.icon)
    b.cd:SetDrawEdge(false)
    -- An accent flash when a real cooldown (not the global one) comes back.
    b.ready = b:CreateTexture(nil, "OVERLAY")
    b.ready:SetTexture(S.WHITE)
    b.ready:SetAllPoints(b.icon)
    b.ready:SetBlendMode("ADD")
    S.Accent(b.ready, 0.55)
    b.flash = S.Flash(b.ready)
    b.cd:HookScript("OnCooldownDone", function()
        if b:IsShown() and b.entry then SetCooldown(b, b.entry) end
    end)
    return b
end

function SetCooldown(b, entry)
    local cd = b.cd
    local now = GetTime()
    local down, dur     -- down: true / false / nil (secret, can't tell); dur: duration object
    b.cdStart, b.cdDur = nil, nil
    if entry.spell then
        local native = C_Spell and C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject
        if native then
            local ok, d = pcall(C_Spell.GetSpellCooldownDuration, entry.spell)
            if ok and d then dur = d; pcall(cd.SetCooldownFromDurationObject, cd, d) else cd:Clear() end
        end
        if C_Spell and C_Spell.GetSpellCooldown then
            local ok, info = pcall(C_Spell.GetSpellCooldown, entry.spell)
            if ok and type(info) == "table" then
                if not native and T.Num(info.startTime) and T.Num(info.duration) then
                    if info.duration > 0 then cd:SetCooldown(info.startTime, info.duration) else cd:Clear() end
                end
                down = S.CooldownDown(info.startTime, info.duration, info.isActive, info.isOnGCD, now)
                if T.Num(info.startTime) and T.Num(info.duration) then b.cdStart, b.cdDur = info.startTime, info.duration end
            end
        end
    else
        local ok, start, duration = pcall(GetInventoryItemCooldown, "player", entry.slot)
        if ok then
            pcall(function()
                if T.Num(start) and T.Num(duration) then
                    if duration > 0 then cd:SetCooldown(start, duration) else cd:Clear() end
                else
                    cd:SetCooldown(start, duration)
                end
            end)
            down = S.CooldownDown(start, duration, nil, nil, now)
            if T.Num(start) and T.Num(duration) then b.cdStart, b.cdDur = start, duration end
            if down == nil and C_DurationUtil and C_DurationUtil.CreateDuration then
                pcall(function()
                    local d = C_DurationUtil.CreateDuration()
                    d:SetTimeFromStart(start, duration)
                    dur = d
                end)
            end
        end
    end
    -- Secret numbers: grey through the duration object; the ticker re-evaluates it.
    if down == nil and S.GreyFromDuration(b.icon, dur, true) then
        b.secretDur = dur
        b.down = nil
        return
    end
    b.secretDur = nil
    down = down == true
    if b.down and not down then b.flash() end
    b.down = down
    S.SetGrey(b.icon, down)
end

-- The scale behind the timeline icons: a track, a "ready" line and labelled marks.
local function BuildTrack(f)
    local tr = { marks = {} }
    tr.track = S.Tex(f, "BACKGROUND", { 0, 0, 0, 0.55 })
    tr.edge = S.Tex(f, "BORDER", { 1, 1, 1, 0.12 })
    tr.now = f:CreateTexture(nil, "ARTWORK")
    tr.now:SetTexture(S.WHITE)
    S.Accent(tr.now, 0.9)
    f.track = tr
    return tr
end

local function LayoutTrack(f, db, size, marks)
    local tr = f.track or BuildTrack(f)
    local w = db.barWidth
    local pad = size / 2
    tr.track:ClearAllPoints()
    tr.track:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", pad, LABEL_H)
    tr.track:SetSize(w, TRACK_H)
    tr.edge:ClearAllPoints()
    tr.edge:SetPoint("TOPLEFT", tr.track, "BOTTOMLEFT", 0, 0)
    tr.edge:SetSize(w, 1)
    tr.now:ClearAllPoints()
    tr.now:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", pad - 1, LABEL_H - 2)
    tr.now:SetSize(2, TRACK_H + 4)
    for i, m in ipairs(marks) do
        local mk = tr.marks[i]
        if not mk then
            mk = { tick = S.Tex(f, "ARTWORK", { 1, 1, 1, 0.3 }), text = S.Text(f, 10, S.C.muted) }
            mk.text:SetJustifyH("CENTER")
            tr.marks[i] = mk
        end
        local x = pad + w * CD.TimeFraction(m, marks)
        mk.tick:ClearAllPoints()
        mk.tick:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, LABEL_H)
        mk.tick:SetSize(1, TRACK_H)
        mk.text:ClearAllPoints()
        mk.text:SetPoint("TOP", f, "BOTTOMLEFT", x, LABEL_H - 1)
        mk.text:SetText(MarkLabel(m))
        mk.tick:Show(); mk.text:Show()
    end
    for i = #marks + 1, #tr.marks do tr.marks[i].tick:Hide(); tr.marks[i].text:Hide() end
    tr.track:Show(); tr.edge:Show(); tr.now:Show()
end

local function HideTrack(f)
    local tr = f.track
    if not tr then return end
    tr.track:Hide(); tr.edge:Hide(); tr.now:Hide()
    for _, mk in ipairs(tr.marks) do mk.tick:Hide(); mk.text:Hide() end
end

-- Timeline mode: slide each icon to where its remaining time falls. Icons that would sit on
-- top of each other take the next lane up.
function CD:Place()
    local db, f = CD.db, CD.frame
    if not (db and f) or db.mode ~= "timeline" then return end
    local size, w, pad = db.size, db.barWidth, db.size / 2
    local marks = CD.Marks(db.range)
    local now = GetTime()
    local order = {}
    for _, b in ipairs(CD.icons) do
        if b.entry and b:IsShown() or b.parked then
            local frac
            if b.cdStart and b.cdDur and b.down then
                frac = CD.TimeFraction(b.cdStart + b.cdDur - now, marks)
            elseif b.secretDur then
                frac = 1                              -- on cooldown but the time is hidden: far end
            elseif db.showReady then
                frac = 0
            end
            if frac then
                b:Show(); b.parked = nil
                b.frac = frac
                order[#order + 1] = b
            else
                b:Hide(); b.parked = true
            end
        end
    end
    table.sort(order, function(a, c) return a.frac < c.frac end)
    local laneEnd = { -1e9, -1e9 }
    for _, b in ipairs(order) do
        local x = pad + w * b.frac
        local lane = 1
        if x - size / 2 < laneEnd[1] then lane = 2 end
        if lane == 2 and x - size / 2 < laneEnd[2] then lane = (laneEnd[1] <= laneEnd[2]) and 1 or 2 end
        laneEnd[lane] = x + size / 2
        b:ClearAllPoints()
        b:SetPoint("BOTTOM", f, "BOTTOMLEFT", x, LABEL_H + TRACK_H + 1 + (lane - 1) * (size + 2))
    end
end

function CD:Refresh()
    local db, f = CD.db, CD.frame
    if not (db and f) then return end
    if not db.enabled then f:Hide() return end
    local wanted = CD:Wanted()
    local size, gap = db.size, db.spacing
    local left = db.growX == "LEFT"
    local timeline = db.mode == "timeline"
    for i, entry in ipairs(wanted) do
        local b = CD.icons[i]
        if not b then b = NewIcon(f); CD.icons[i] = b end
        b:SetSize(size, size)
        b.parked = nil
        if not timeline then
            b:ClearAllPoints()
            local offset = (i - 1) * (size + gap)
            if left then b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -offset, 0) else b:SetPoint("TOPLEFT", f, "TOPLEFT", offset, 0) end
        end
        local old = b.entry
        if not (old and old.spell == entry.spell and old.slot == entry.slot) then b.down = nil end  -- new spell: no flash
        b.entry = entry
        b.icon:SetTexture(entry.spell and SpellTexture(entry.spell) or GetInventoryItemTexture("player", entry.slot))
        SetCooldown(b, entry)
        b:Show()
    end
    for i = #wanted + 1, #CD.icons do CD.icons[i]:Hide(); CD.icons[i].entry = nil; CD.icons[i].parked = nil end
    if timeline then
        local marks = CD.Marks(db.range)
        LayoutTrack(f, db, size, marks)
        f:SetSize(db.barWidth + size, LABEL_H + TRACK_H + 1 + size * 2 + 2)
        CD:Place()
        f:SetShown(#wanted > 0 or not T.db.locked)
    else
        HideTrack(f)
        local n = math.max(#wanted, 1)
        f:SetSize(n * size + (n - 1) * gap, size)
        f:SetShown(#wanted > 0 or not T.db.locked)
    end
end

function CD:Update()
    for _, b in ipairs(CD.icons) do
        if (b:IsShown() or b.parked) and b.entry then SetCooldown(b, b.entry) end
    end
    CD:Place()
end

T:NewModule("cooldowns", {
    label = "Cooldowns",
    desc = "A row of icons with cooldown swipes for spells you choose and your trinkets.",
    defaults = CD.defaults,
    OnEnable = function()
        CD.db = T.db.cooldowns
        local f = CreateFrame("Frame", "TempusCooldowns", UIParent)
        f:SetFrameStrata("MEDIUM")
        CD.frame = f
        T.Movers.ApplyPoint(f, CD.db)
        T.Movers:Register(f, {
            label = "Cooldowns", page = "cooldowns",
            cfg = function() return CD.db end,
            corner = function() return CD.db.point[1] end,
            enabled = function() return CD.db.enabled end,
        })
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
        ev:RegisterEvent("SPELLS_CHANGED")
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        ev:SetScript("OnEvent", T:Wrap("cooldowns.events", function(_, event)
            if event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then CD:Update() else CD:Refresh() end
        end))
        -- Icons greyed from a secret duration are snapshots: refresh them a few times a second.
        local acc = 0
        local slide = 0
        f:SetScript("OnUpdate", T:Wrap("cooldowns.grey", function(_, elapsed)
            if CD.db.mode == "timeline" then
                slide = slide + elapsed
                if slide >= 0.03 then slide = 0; CD:Place() end
            end
            acc = acc + elapsed
            if acc < 0.2 then return end
            acc = 0
            for _, b in ipairs(CD.icons) do
                if b.secretDur and b:IsShown() and not S.GreyFromDuration(b.icon, b.secretDur, true) then
                    b.secretDur = nil
                end
            end
        end))
        CD:Refresh()
    end,
    OnSettings = function()
        CD.db = T.db.cooldowns
        if CD.frame then
            T.Movers.ApplyPoint(CD.frame, CD.db)
            CD:Refresh()
        end
    end,
})
