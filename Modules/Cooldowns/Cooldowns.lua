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
    point = { "CENTER", "UIParent", "CENTER", 0, -170 },
}

local TRINKET_SLOTS = { 13, 14 }

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
    return b
end

local function SetCooldown(b, entry)
    local cd = b.cd
    local desat = false
    if entry.spell then
        if C_Spell and C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
            local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, entry.spell)
            if ok and dur then pcall(cd.SetCooldownFromDurationObject, cd, dur) else cd:Clear() end
        end
        if C_Spell and C_Spell.GetSpellCooldown then
            local ok, info = pcall(C_Spell.GetSpellCooldown, entry.spell)
            if ok and type(info) == "table" and T.Num(info.startTime) and T.Num(info.duration) then
                if not (C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject) then
                    if info.duration > 0 then cd:SetCooldown(info.startTime, info.duration) else cd:Clear() end
                end
                desat = info.duration > 1.6 and info.startTime + info.duration > GetTime()
            end
        end
    else
        local ok, start, duration = pcall(GetInventoryItemCooldown, "player", entry.slot)
        if ok then
            pcall(function()
                if T.Num(start) and T.Num(duration) then
                    if duration > 0 then cd:SetCooldown(start, duration) else cd:Clear() end
                    desat = duration > 1.6 and start + duration > GetTime()
                else
                    cd:SetCooldown(start, duration)
                end
            end)
        end
    end
    b.icon:SetDesaturated(desat)
end

function CD:Refresh()
    local db, f = CD.db, CD.frame
    if not (db and f) then return end
    if not db.enabled then f:Hide() return end
    local wanted = CD:Wanted()
    local size, gap = db.size, db.spacing
    local left = db.growX == "LEFT"
    for i, entry in ipairs(wanted) do
        local b = CD.icons[i]
        if not b then b = NewIcon(f); CD.icons[i] = b end
        b:SetSize(size, size)
        b:ClearAllPoints()
        local offset = (i - 1) * (size + gap)
        if left then b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -offset, 0) else b:SetPoint("TOPLEFT", f, "TOPLEFT", offset, 0) end
        b.entry = entry
        b.icon:SetTexture(entry.spell and SpellTexture(entry.spell) or GetInventoryItemTexture("player", entry.slot))
        SetCooldown(b, entry)
        b:Show()
    end
    for i = #wanted + 1, #CD.icons do CD.icons[i]:Hide() end
    local n = math.max(#wanted, 1)
    f:SetSize(n * size + (n - 1) * gap, size)
    f:SetShown(#wanted > 0 or not T.db.locked)
end

function CD:Update()
    for _, b in ipairs(CD.icons) do
        if b:IsShown() and b.entry then SetCooldown(b, b.entry) end
    end
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
