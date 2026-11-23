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
    mode = "icons",             -- icons (a row) | timeline (icons fall along a time scale)
    length = 320,               -- timeline: height of the scale
    range = 60,                 -- timeline: seconds at the far end (30 | 60 | 120 | 300)
    showReady = false,          -- timeline: keep spells that are ready parked at the ready line
    fall = "DOWN",              -- DOWN: ready line at the bottom | UP: ready line at the top
    labelSide = "LEFT",         -- which side the time labels and the rail sit on
    bgStyle = "GLASS",          -- GLASS | SOLID | MINIMAL (rail and marks only)
    bgOpacity = 0.7,            -- how strong the scale's background is
    fadeBg = 0.8,               -- how far the background fades out toward the ready line
    fadeIcons = 0.5,            -- how far icons fade as they near ready
    showLabels = true, showTicks = true, accentRail = true,
    point = { "CENTER", "UIParent", "CENTER", 0, -170 },
}

local TRINKET_SLOTS = { 13, 14 }

-- Timeline scale: equal-width steps between these marks, so the near seconds get the room.
local MARKS = { 0, 5, 15, 30, 60, 120, 300 }
local FADE_ZONE = 0.35      -- the last share of the scale (by position) that fades toward ready
local LABEL_W, EDGE = 28, 4

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

-- Opacity multiplier at `pos` (0 ready, 1 far end): full outside the fade zone, easing down to
-- 1 - strength at the ready line.
function CD.FadeAlpha(pos, strength)
    local t = math.min(math.max(pos, 0) / FADE_ZONE, 1)
    return 1 - strength * (1 - t)
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

----------------------------------------------------------------------------------------
-- Timeline. s is the distance from the ready line along the scale (0 .. length); the ready
-- line sits at the bottom (fall DOWN) or the top (fall UP) with half an icon of room beyond.
----------------------------------------------------------------------------------------
local STYLES = {                      -- fill colour, fill strength
    GLASS   = { { 0.05, 0.07, 0.11 }, 0.85 },
    SOLID   = { { 0.02, 0.02, 0.03 }, 1 },
    MINIMAL = { { 0, 0, 0 }, 0 },
}

local function Geometry(db)
    local size, len = db.size, db.length
    local labelW = db.showLabels and LABEL_W or 0
    local panelW = size * 2 + 14
    local left = db.labelSide ~= "RIGHT"
    local x0 = left and labelW or 0
    local g = { size = size, len = len, panelW = panelW, x0 = x0, labelW = labelW, left = left, down = db.fall ~= "UP" }
    g.w, g.h = labelW + panelW, len + size
    g.c1 = left and (x0 + 6 + size / 2) or (x0 + panelW - 6 - size / 2)
    g.c2 = left and (g.c1 + size + 2) or (g.c1 - size - 2)
    g.rail = left and x0 or (x0 + panelW - 2)
    return g
end

-- Paint a vertical strip spanning s0..s1 on tex; `dist` s is measured from the ready line.
local function PlaceStrip(f, tex, g, x, w, s0, s1)
    tex:ClearAllPoints()
    if g.down then tex:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, g.size / 2 + s0)
    else tex:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(g.size / 2 + s0)) end
    tex:SetSize(w, s1 - s0)
end

-- A strip that is solid over the far part of the scale and ramps from `aNear` at the ready
-- line up to `aFar` across the fade zone. Two textures, one flat and one gradient.
local function Strip(f, tr, name, g, x, w, rgb, aFar, aNear)
    local st = tr[name]
    if not st then st = { far = f:CreateTexture(nil, "BACKGROUND"), near = f:CreateTexture(nil, "BACKGROUND") }; tr[name] = st end
    local nz = g.len * FADE_ZONE
    for _, t in pairs(st) do t:SetTexture(S.WHITE) end
    PlaceStrip(f, st.far, g, x, w, nz, g.len + EDGE)
    st.far:SetVertexColor(rgb[1], rgb[2], rgb[3], aFar)
    PlaceStrip(f, st.near, g, x, w, -EDGE, nz)
    local nearA = EDGE / (nz + EDGE) * (aFar - aNear) + aNear      -- alpha where the strip starts
    if g.down then S.SetGradient(st.near, "VERTICAL", rgb[1], rgb[2], rgb[3], nearA, rgb[1], rgb[2], rgb[3], aFar)
    else S.SetGradient(st.near, "VERTICAL", rgb[1], rgb[2], rgb[3], aFar, rgb[1], rgb[2], rgb[3], nearA) end
    st.far:Show(); st.near:Show()
end

local function HideTrack(f)
    local tr = f.track
    if not tr then return end
    for key, v in pairs(tr) do
        if key == "marks" then
            for _, mk in ipairs(v) do mk.tick:Hide(); mk.text:Hide() end
        elseif key == "line" then v:Hide()
        else v.far:Hide(); v.near:Hide() end
    end
end

local function LayoutTrack(f, db, g, marks)
    local tr = f.track
    if not tr then tr = { marks = {} }; f.track = tr end
    local bg = db.bgOpacity
    local style = STYLES[db.bgStyle] or STYLES.GLASS
    local fade = db.fadeBg
    local accent = db.accentRail and T.accent or { 0.62, 0.66, 0.74 }
    -- Panel fill, a faint edge opposite the rail, and the rail itself.
    local fillA = bg * style[2]
    if fillA > 0 then
        Strip(f, tr, "fill", g, g.x0, g.panelW, style[1], fillA, fillA * (1 - fade))
        local ex = g.left and (g.x0 + g.panelW - 1) or g.x0
        Strip(f, tr, "edge", g, ex, 1, { 1, 1, 1 }, bg * 0.12, bg * 0.12 * (1 - fade))
    elseif tr.fill then tr.fill.far:Hide(); tr.fill.near:Hide(); tr.edge.far:Hide(); tr.edge.near:Hide() end
    Strip(f, tr, "rail", g, g.rail, 2, accent, bg * 0.95, bg * 0.95 * (1 - fade))
    -- The ready line across the panel.
    if not tr.line then tr.line = f:CreateTexture(nil, "ARTWORK") end
    tr.line:SetTexture(S.WHITE)
    tr.line:SetVertexColor(accent[1], accent[2], accent[3], bg * (1 - fade))
    tr.line:ClearAllPoints()
    if g.down then tr.line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", g.x0, g.size / 2 - 1)
    else tr.line:SetPoint("TOPLEFT", f, "TOPLEFT", g.x0, -(g.size / 2 - 1)) end
    tr.line:SetSize(g.panelW, 2)
    tr.line:Show()
    -- Marks: a hairline across the panel and a time label beside it.
    for i, m in ipairs(marks) do
        local mk = tr.marks[i]
        if not mk then
            mk = { tick = f:CreateTexture(nil, "ARTWORK"), text = S.Text(f, 10, S.C.muted) }
            tr.marks[i] = mk
        end
        local pos = CD.TimeFraction(m, marks)
        local s = g.len * pos
        local fa = CD.FadeAlpha(pos, fade)
        mk.tick:SetTexture(S.WHITE)
        mk.tick:SetVertexColor(1, 1, 1, bg * 0.22 * fa)
        mk.tick:ClearAllPoints()
        if g.down then mk.tick:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", g.x0, g.size / 2 + s)
        else mk.tick:SetPoint("TOPLEFT", f, "TOPLEFT", g.x0, -(g.size / 2 + s) + 1) end
        mk.tick:SetSize(g.panelW, 1)
        mk.tick:SetShown(db.showTicks and m > 0)
        mk.text:SetJustifyH(g.left and "RIGHT" or "LEFT")
        mk.text:ClearAllPoints()
        local anchor = g.left and "RIGHT" or "LEFT"
        local ty = g.down and (g.size / 2 + s) or -(g.size / 2 + s)
        local tx = g.left and (g.x0 - 5) or (g.x0 + g.panelW + 5)
        mk.text:SetPoint(anchor, f, g.down and "BOTTOMLEFT" or "TOPLEFT", tx, ty)
        mk.text:SetText(MarkLabel(m))
        mk.text:SetAlpha(math.min(1, bg + 0.25) * fa)
        mk.text:SetShown(db.showLabels and m > 0)
    end
    for i = #marks + 1, #tr.marks do tr.marks[i].tick:Hide(); tr.marks[i].text:Hide() end
end

-- Lay icons (each with a .pos, 0 ready .. 1 far end) down the scale of frame f.
local function PlaceIcons(f, db, g, order)
    table.sort(order, function(a, c) return a.pos < c.pos end)
    local gap = g.size + 2
    local last = { -1e9, -1e9 }
    for _, b in ipairs(order) do
        local s = g.len * b.pos
        local lane = 1
        if s - last[1] < gap then
            if s - last[2] >= gap then lane = 2 else lane = last[1] <= last[2] and 1 or 2 end
        end
        last[lane] = s
        b:ClearAllPoints()
        local x = lane == 1 and g.c1 or g.c2
        if g.down then b:SetPoint("CENTER", f, "BOTTOMLEFT", x, g.size / 2 + s)
        else b:SetPoint("CENTER", f, "TOPLEFT", x, -(g.size / 2 + s)) end
        b:SetAlpha(CD.FadeAlpha(b.pos, db.fadeIcons))
    end
end

-- Timeline mode: move each icon to where its remaining time falls, and fade it as it nears
-- ready. Icons that would sit on top of each other take the second lane.
function CD:Place()
    local db, f = CD.db, CD.frame
    if not (db and f) or db.mode ~= "timeline" then return end
    local g = Geometry(db)
    local marks = CD.Marks(db.range)
    local now = GetTime()
    local order = {}
    for _, b in ipairs(CD.icons) do
        if b.entry and (b:IsShown() or b.parked) then
            local pos
            if b.cdStart and b.cdDur and b.down then
                pos = CD.TimeFraction(b.cdStart + b.cdDur - now, marks)
            elseif b.secretDur then
                pos = 1                               -- on cooldown but the time is hidden: far end
            elseif db.showReady then
                pos = 0
            end
            if pos then
                b:Show(); b.parked = nil
                b.pos = pos
                order[#order + 1] = b
            else
                b:Hide(); b.parked = true
            end
        end
    end
    PlaceIcons(f, db, g, order)
end

-- Corner grip: the box the cursor asks for sets the icon size (from width in the timeline,
-- from height in the row) and, in the timeline, the length of the scale.
function CD.ResizeFromBox(db, w, h)
    local clamp = function(v, lo, hi) return math.max(lo, math.min(hi, math.floor(v + 0.5))) end
    if db.mode == "timeline" then
        local labelW = db.showLabels and LABEL_W or 0
        db.size = clamp((w - labelW - 14) / 2, 20, 64)
        db.length = clamp(h - db.size, 160, 600)
    else
        db.size = clamp(h, 20, 64)
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
        if not timeline then b:SetAlpha(1) end
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
        local g = Geometry(db)
        LayoutTrack(f, db, g, CD.Marks(db.range))
        f:SetSize(g.w, g.h)
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

-- One line each on why the timeline shows what it shows (for /tempus cddebug).
function CD.Debug()
    local out = {}
    local function Add(fmt, ...) out[#out + 1] = fmt:format(...) end
    local db, f = CD.db, CD.frame
    if not (db and f) then return { "cooldowns: module is not running (General > Modules)." } end
    local x, y = f:GetCenter()
    local w, h = f:GetSize()
    Add("cooldowns: mode=%s, enabled=%s, frame %s %.0fx%.0f at %s,%s, locked=%s, bg=%s opacity=%.2f, showReady=%s",
        tostring(db.mode), tostring(db.enabled), f:IsShown() and "shown" or "HIDDEN", w, h,
        x and ("%.0f"):format(x) or "?", y and ("%.0f"):format(y) or "?", tostring(T.db.locked), tostring(db.bgStyle), db.bgOpacity or 0, tostring(db.showReady))
    local wanted = CD:Wanted()
    Add("tracked: %d entries (%d spells in your list, trinkets %s)", #wanted, (function() local n = 0 for _ in pairs(T.db.lists.cooldowns or {}) do n = n + 1 end return n end)(), db.trinkets and "on" or "off")
    local now = GetTime()
    for i, b in ipairs(CD.icons) do
        if b.entry then
            local left = b.cdStart and b.cdDur and (b.cdStart + b.cdDur - now)
            Add("  #%d %s: %s, down=%s, remaining=%s, pos=%s, secret=%s, %s",
                i, b.entry.spell and ("spell " .. b.entry.spell) or ("slot " .. b.entry.slot), b:IsShown() and "shown" or "hidden",
                tostring(b.down), left and ("%.1fs"):format(left) or "unknown", b.pos and ("%.2f"):format(b.pos) or "-",
                tostring(b.secretDur ~= nil), b.parked and "parked (ready, hidden)" or "placed")
        end
    end
    return out
end

-- Settings preview: fake spells falling down the real timeline layout, on their own clock.
local DEMO_ICONS = { 136243, 135808, 132333, 136048, 135846 }
function CD.CreateDemo(width, height)
    local box = CreateFrame("Frame")
    box:SetSize(width, height)
    local view = CreateFrame("Frame", nil, box)
    view:SetPoint("TOP", box, "TOP", 0, 0)
    local items = {}
    for i, tex in ipairs(DEMO_ICONS) do
        local b = NewIcon(view)
        b.icon:SetTexture(tex)
        b.cd:Hide(); b.ready:Hide()
        items[i] = { b = b, period = 9 + i * 3.1, phase = (i * 0.37) % 1 }
    end
    function box:Refresh()
        local db = CD.db or T.db.cooldowns
        if db.mode ~= "timeline" then
            view:Hide()
            if not box.note then
                box.note = S.Text(box, 11, S.C.muted)
                box.note:SetPoint("TOPLEFT", 0, 0)
                box.note:SetText("Set Style to Timeline to see the preview.")
            end
            box.note:Show()
            return
        end
        if box.note then box.note:Hide() end
        local g = Geometry(db)
        local scale = math.min(1, (height - 4) / g.h)
        view:SetScale(scale)
        view:SetSize(g.w, g.h)
        view:Show()
        LayoutTrack(view, db, g, CD.Marks(db.range))
        box.g = g
    end
    box:Refresh()
    T.UI.Loop(box, 0.03, function(_, now)
        local db = CD.db or T.db.cooldowns
        if db.mode ~= "timeline" or not box.g then return end
        local order = {}
        for _, it in ipairs(items) do
            local life = ((now / it.period) + it.phase) % 1
            local remaining = db.range * (1 - life)
            it.b:SetSize(db.size, db.size)
            it.b.pos = CD.TimeFraction(remaining, CD.Marks(db.range))
            it.b:Show()
            order[#order + 1] = it.b
        end
        PlaceIcons(view, db, box.g, order)
    end)
    return box
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
            onResize = function(w, h)
                local size, length = CD.db.size, CD.db.length
                CD.ResizeFromBox(CD.db, w, h)
                if size ~= CD.db.size or length ~= CD.db.length then CD:Refresh() end
            end,
            onMoved = function() if T.Options and T.Options.Refresh then T.Options:Refresh() end end,
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
        S.OnAccent(function()
            if CD.db and CD.db.mode == "timeline" and CD.db.enabled then CD:Refresh() end
        end)
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
