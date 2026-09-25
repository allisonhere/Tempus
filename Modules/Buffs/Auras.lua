-- Tempus: reads player auras and weapon enchants into plain entry tables.
-- Every field is checked for secrecy; timing falls back to client duration objects.
local _, T = ...
local Readable, Num, Str = T.Readable, T.Num, T.Str

local A = { idByName = {} }     -- idByName: spell IDs learned out of combat, for native filters
T.Auras = A

local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local GetAuraDuration = C_UnitAuras and C_UnitAuras.GetAuraDuration
local GetDisplayCount = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount

local MINE = { player = true, pet = true, vehicle = true }

local function LegacyAura(index, filter)
    if not UnitAura then return nil end
    local name, icon, count, dispel, duration, expiration, source, _, _, spellId = UnitAura("player", index, filter)
    if name == nil then return nil end
    return {
        name = name, icon = icon, applications = count, dispelName = dispel,
        duration = duration, expirationTime = expiration, sourceUnit = source, spellId = spellId,
    }
end

local function ReadAura(index, filter)
    if GetAuraDataByIndex then
        local ok, aura = pcall(GetAuraDataByIndex, "player", index, filter)
        if ok then return aura end
        return nil
    end
    return LegacyAura(index, filter)
end

local function MakeEntry(aura, index, filter)
    local e = { index = index, filter = filter, harmful = filter == "HARMFUL" }
    e.name = aura.name
    e.nameOK = Str(aura.name)
    e.icon = aura.icon
    e.spellId = Num(aura.spellId) and aura.spellId or nil
    e.auraInstanceID = Num(aura.auraInstanceID) and aura.auraInstanceID or nil
    local instanceKey = aura.auraInstanceID     -- may be secret; still valid to pass back to the client
    e.dispel = Str(aura.dispelName) and aura.dispelName or nil
    if e.nameOK and e.spellId then A.idByName[e.name:lower()] = e.spellId end

    if Num(aura.applications) then
        e.count = aura.applications
    elseif instanceKey ~= nil and GetDisplayCount then
        local ok, text = pcall(GetDisplayCount, "player", instanceKey, 2, 999)
        if ok then e.countText = text end
    end

    local source = aura.sourceUnit
    if Str(source) then
        e.mine = MINE[source] or false
    elseif Readable(aura.isFromPlayerOrPlayerPet) and type(aura.isFromPlayerOrPlayerPet) == "boolean" then
        e.mine = aura.isFromPlayerOrPlayerPet
    end

    local duration, expiration = aura.duration, aura.expirationTime
    if Num(duration) and Num(expiration) then
        e.duration, e.expiration = duration, expiration
        e.permanent = duration <= 0 or expiration <= 0
    else
        e.secret = true
        if instanceKey ~= nil and GetAuraDuration then
            local ok, obj = pcall(GetAuraDuration, "player", instanceKey)
            if ok and obj then
                e.durObj = obj
                local okZero, zero = pcall(obj.IsZero, obj)
                if okZero and Readable(zero) and zero == true then e.durObj = nil end
            end
        end
        e.permanent = e.durObj == nil
    end
    return e
end

----------------------------------------------------------------------------------------
-- Scanning. The client may restrict one aura API in combat while another still works,
-- so each path is tried in turn and the outcome is recorded for /tempus debug.
----------------------------------------------------------------------------------------
local snapshot = {}     -- filter -> last successful out-of-combat entries

local function Record(filter, path, count, err)
    local log = TempusDB and TempusDB.debug
    if not log then return end
    local state = InCombatLockdown() and "combat" or "idle"
    log[state] = log[state] or {}
    local prev = log[state][filter]
    if prev and prev.path == path and prev.count == count and prev.err == err then return end
    log[state][filter] = { path = path, count = count, err = err, at = date("%H:%M:%S") }
end

local function AddEntry(out, aura, index, filter, unsureIndex, errs)
    local ok, e = pcall(MakeEntry, aura, index, filter)
    if ok then
        e.unsureIndex = unsureIndex
        out[#out + 1] = e
    else
        errs[#errs + 1] = "MakeEntry: " .. tostring(e)
    end
end

local function ByIndex(filter, out, errs)
    for index = 1, 64 do
        local aura = ReadAura(index, filter)
        if type(aura) ~= "table" then
            if index == 1 and GetAuraDataByIndex then
                local ok, err = pcall(GetAuraDataByIndex, "player", 1, filter)
                if not ok then errs[#errs + 1] = "ByIndex: " .. tostring(err) end
            end
            break
        end
        AddEntry(out, aura, index, filter, false, errs)
    end
end

local function ByUnitList(filter, out, errs)
    local fn = C_UnitAuras and C_UnitAuras.GetUnitAuras
    if not fn then return end
    local ok, list = pcall(fn, "player", filter)
    if not ok then errs[#errs + 1] = "GetUnitAuras: " .. tostring(list) return end
    if type(list) ~= "table" then return end
    for i, aura in ipairs(list) do
        if type(aura) == "table" then AddEntry(out, aura, i, filter, true, errs) end
    end
end

local function ByInstanceIDs(filter, out, errs)
    local ids = C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
    if not (ids and get) then return end
    local ok, list = pcall(ids, "player", filter)
    if not ok then errs[#errs + 1] = "GetUnitAuraInstanceIDs: " .. tostring(list) return end
    if type(list) ~= "table" then return end
    for i, id in ipairs(list) do
        local ok2, aura = pcall(get, "player", id)
        if ok2 and type(aura) == "table" then AddEntry(out, aura, i, filter, true, errs) end
    end
end

local function ByLegacy(filter, out, errs)
    if not UnitAura or not GetAuraDataByIndex then return end   -- already tried when it is the primary path
    for index = 1, 64 do
        local ok, aura = pcall(LegacyAura, index, filter)
        if not ok then errs[#errs + 1] = "UnitAura: " .. tostring(aura) break end
        if type(aura) ~= "table" then break end
        AddEntry(out, aura, index, filter, false, errs)
    end
end

local PATHS = { { "index", ByIndex }, { "unitList", ByUnitList }, { "instanceIDs", ByInstanceIDs }, { "legacy", ByLegacy } }

function A:ScanFilter(filter, out)
    local errs, list, used = {}, {}, "none"
    for _, p in ipairs(PATHS) do
        p[2](filter, list, errs)
        if #list > 0 then used = p[1] break end
    end
    local combat = InCombatLockdown()
    if not combat then
        snapshot[filter] = list
    elseif #list == 0 and snapshot[filter] and #snapshot[filter] > 0 then
        -- Every API came back empty in combat: keep showing what we knew before the
        -- pull, dropping anything whose readable timer has run out.
        local now = GetTime()
        for _, e in ipairs(snapshot[filter]) do
            if e.permanent or e.secret or (e.expiration or 0) > now then
                e.stale = true
                list[#list + 1] = e
            end
        end
        used = "snapshot"
    end
    Record(filter, used, #list, errs[1])
    -- Only a by-index or legacy scan is a complete, readable picture of the player's auras.
    A.lastScanReliable = A.lastScanReliable or {}
    A.lastScanReliable[filter] = (used == "index" or used == "legacy" or (used == "none" and not combat))
    for _, e in ipairs(list) do out[#out + 1] = e end
    return out
end

----------------------------------------------------------------------------------------
-- Weapon enchants
----------------------------------------------------------------------------------------
local weaponMax = {}        -- slot -> longest remaining seen, used as the total duration
local enchantNameCache = {}
local scanTip

local function EnchantNameFromLines(lines)
    for _, text in ipairs(lines) do
        if Str(text) then
            local name = text:match("^(.-) %(%d+ [^%)]+%)$")
            if name and name ~= "" then return name end
        end
    end
end

local function WeaponEnchantName(slot)
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            for _, line in ipairs(data.lines) do lines[#lines + 1] = line.leftText end
        end
    end
    if #lines == 0 then
        if not scanTip then
            scanTip = CreateFrame("GameTooltip", "TempusScanTooltip", nil, "GameTooltipTemplate")
        end
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
        scanTip:ClearLines()
        pcall(scanTip.SetInventoryItem, scanTip, "player", slot)
        for i = 1, scanTip:NumLines() do
            local fs = _G["TempusScanTooltipTextLeft" .. i]
            lines[#lines + 1] = fs and fs:GetText()
        end
        scanTip:Hide()
    end
    return EnchantNameFromLines(lines)
end

local function WeaponEntry(slot, has, msLeft, charges)
    if not has then
        weaponMax[slot] = nil
        return nil
    end
    local now = GetTime()
    local e = { weapon = slot, index = slot, filter = "WEAPON" }
    e.icon = GetInventoryItemTexture("player", slot)
    local itemName = GetItemInfo(GetInventoryItemLink("player", slot) or "")
    local key = slot .. ":" .. tostring(GetInventoryItemID("player", slot))
    if not enchantNameCache[key] then enchantNameCache[key] = WeaponEnchantName(slot) end
    e.name = enchantNameCache[key] or itemName or (slot == 16 and "Main Hand" or "Off Hand")
    e.nameOK = Str(e.name)
    e.count = Num(charges) and charges > 0 and charges or nil
    e.mine = true
    if Num(msLeft) and msLeft > 0 then
        local left = msLeft / 1000
        if not weaponMax[slot] or left > weaponMax[slot] + 1 then
            weaponMax[slot] = left
            enchantNameCache[key] = nil     -- new application: re-read the enchant name
        end
        e.duration = weaponMax[slot]
        e.expiration = now + left
    else
        e.permanent = true
        e.duration, e.expiration = 0, 0
    end
    return e
end

function A:ScanWeapons(out)
    if GetWeaponEnchantInfo then
        local ok, hasMain, mainMs, mainCharges, _, hasOff, offMs, offCharges = pcall(GetWeaponEnchantInfo)
        if ok and Readable(hasMain) and Readable(hasOff) then
            out[#out + 1] = WeaponEntry(16, hasMain, mainMs, mainCharges)
            out[#out + 1] = WeaponEntry(17, hasOff, offMs, offCharges)
            return out
        end
    end
    -- Forever's table-based API.
    if C_Item and C_Item.GetWeaponEnchantInfo and Enum and Enum.WeaponSlot then
        for slot, enum in pairs({ [16] = Enum.WeaponSlot.MainHand, [17] = Enum.WeaponSlot.OffHand }) do
            local ok, list = pcall(C_Item.GetWeaponEnchantInfo, enum)
            if ok and type(list) == "table" then
                for _, info in pairs(list) do
                    if type(info) == "table" and Readable(info.hasEnchant) and info.hasEnchant then
                        local ms = info.expiration or info.timeRemaining or info.remaining
                        if Num(info.expirationTime) and info.expirationTime > GetTime() then
                            ms = (info.expirationTime - GetTime()) * 1000
                        end
                        out[#out + 1] = WeaponEntry(slot, true, ms, info.charges)
                        break
                    end
                end
            end
        end
    end
    return out
end

----------------------------------------------------------------------------------------
-- Filtering and sorting
----------------------------------------------------------------------------------------
local function Visible(e, cfg)
    if T:ListHas("hidden", e.nameOK and e.name or nil, e.spellId) then return false end
    if cfg.onlyMine and e.mine == false then return false end
    if cfg.permanent == "HIDE" and e.permanent then return false end
    return true
end

local function SortEntries(list, cfg)
    local mode, reverse, permFirst = cfg.sort, cfg.reverse, cfg.permanent == "FIRST"
    table.sort(list, function(a, b)
        if a.permanent ~= b.permanent then
            if permFirst then return a.permanent == true end
            return b.permanent == true
        end
        -- Entries with secret timing cannot be compared; keep them in game order at the end.
        if a.secret ~= b.secret then return b.secret == true end
        local ka, kb
        if mode == "TIME" and not a.permanent and not a.secret then
            ka, kb = a.expiration, b.expiration
        elseif mode == "NAME" and a.nameOK and b.nameOK then
            ka, kb = a.name, b.name
        end
        if ka ~= nil and kb ~= nil and ka ~= kb then
            if reverse then return ka > kb end
            return ka < kb
        end
        if a.filter ~= b.filter then return a.filter < b.filter end
        return a.index < b.index
    end)
end

-- raw: an unfiltered list from ScanFilter/ScanWeapons. Returns the entries this group shows.
function A:Filter(raw, cfg)
    local list = {}
    for _, e in ipairs(raw) do
        if Visible(e, cfg) then
            e.important = T:ListHas("important", e.nameOK and e.name or nil, e.spellId)
            list[#list + 1] = e
        end
    end
    SortEntries(list, cfg)
    return list
end

-- Watch list: entries the player wants reminders for when missing.
function A:CollectMissing(buffs)
    local watch = T.db.lists.watch
    if not next(watch) then return {} end
    if T.db.watchHideInCombat and InCombatLockdown() then return {} end
    if T.db.watchOnlyResting and not IsResting() then return {} end
    if UnitIsDeadOrGhost("player") then return {} end
    local present, uncertain = {}, false
    for _, e in ipairs(buffs) do
        if e.nameOK then present[e.name:lower()] = true else uncertain = true end
        if e.spellId then present[tostring(e.spellId)] = true end
    end
    -- If any buff name is hidden from us we cannot prove something is missing.
    if uncertain then return {} end
    local out = {}
    for key, display in pairs(watch) do
        if not present[key] then
            local icon
            if C_Spell and C_Spell.GetSpellTexture then
                local ok, tex = pcall(C_Spell.GetSpellTexture, tonumber(key) or display)
                if ok then icon = tex end
            elseif GetSpellTexture then
                icon = GetSpellTexture(tonumber(key) or display)
            end
            out[#out + 1] = {
                name = display, nameOK = true, icon = icon or 134400, missing = true,
                permanent = true, index = #out + 1, filter = "WATCH",
            }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end
