-- Tempus UI: saved bag, bank and reagent contents for every character, for the alt viewer and tooltip counts.
-- Pure data code: the controller feeds it snapshots and it hands snapshots back, so it needs no frames.
local _, T = ...
local Bags = T.Bags or {}
T.Bags = Bags

local Ch = { storages = { "CARRIED", "BANK", "REAGENT" } }
Bags.Characters = Ch

Ch.labels = { CARRIED = "Bags", BANK = "Bank", REAGENT = "Reagents" }

local function Store()
    TempusDB = TempusDB or {}
    TempusDB.inventories = TempusDB.inventories or {}
    return TempusDB.inventories
end

-- Copy a live snapshot into saved variables. info: name, realm, class, money, time.
function Ch.Capture(key, info, storage, snapshot)
    local chars = Store()
    local rec = chars[key] or {}
    chars[key] = rec
    rec.name, rec.realm, rec.class = info.name, info.realm, info.class
    rec.money, rec.updated = info.money, info.time
    rec.storages = rec.storages or {}
    local items = {}
    for _, slot in ipairs(snapshot.slots) do
        if not slot.empty then
            items[#items + 1] = {
                container = slot.location.container, slot = slot.location.slot,
                itemID = slot.itemID, count = slot.count, link = slot.link, name = slot.name, icon = slot.icon,
                quality = slot.quality, itemLevel = slot.itemLevel, bound = slot.bound or nil,
                hasNoValue = slot.hasNoValue or nil, quest = slot.quest or nil,
            }
        end
    end
    rec.storages[storage] = { items = items, used = snapshot.used, capacity = snapshot.capacity, updated = info.time }
    Ch.dirty = true
end

-- Static item data (type, equip slot, icon) that is always available without a server round trip.
local function Instant(itemID)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return end
    local ok, id, itemType, itemSubType, equipLoc, icon, classID, subClassID = pcall(fn, itemID)
    if ok and id then return itemType, itemSubType, equipLoc, icon, classID, subClassID end
end

local function NameFromLink(link)
    return type(link) == "string" and link:match("|h%[(.-)%]|h") or nil
end

-- A snapshot of one saved storage in the shape Inventory.Project expects, or nil if never saved.
-- Records are marked readonly: no live slot stands behind them.
function Ch.Snapshot(key, storage)
    local rec = Store()[key]
    local saved = rec and rec.storages and rec.storages[storage]
    if not saved then return nil end
    local byKey, locations = {}, {}
    for _, row in ipairs(saved.items) do
        local location = { storage = storage, container = row.container, slot = row.slot }
        locations[#locations + 1] = location
        byKey[Bags.Inventory.Key(location)] = row
    end
    local snapshot = Bags.Inventory.Snapshot(storage, locations, function(location)
        local row = byKey[Bags.Inventory.Key(location)]
        local itemType, itemSubType, equipLoc, icon, classID, subClassID = Instant(row.itemID)
        return {
            itemID = row.itemID, count = row.count, link = row.link, quality = row.quality,
            itemLevel = row.itemLevel, bound = row.bound, hasNoValue = row.hasNoValue, quest = row.quest,
            name = row.name or NameFromLink(row.link), icon = row.icon or icon,
            itemType = itemType, itemSubType = itemSubType, equipLoc = equipLoc,
            classID = classID, subClassID = subClassID, readonly = true,
        }
    end)
    -- Empty slots are not saved; keep the real capacity for the footer.
    snapshot.used, snapshot.capacity = saved.used or snapshot.used, saved.capacity or snapshot.capacity
    snapshot.saved, snapshot.updated = true, saved.updated
    return snapshot
end

-- Saved characters, most recently seen first. Each entry: key, name, realm, class, money, updated, storages.
function Ch.List()
    local out = {}
    for key, rec in pairs(Store()) do
        local storages = {}
        for _, storage in ipairs(Ch.storages) do
            local saved = rec.storages and rec.storages[storage]
            if saved and #saved.items > 0 then storages[#storages + 1] = storage end
        end
        out[#out + 1] = { key = key, name = rec.name or key, realm = rec.realm, class = rec.class,
            money = rec.money or 0, updated = rec.updated or 0, storages = storages, rec = rec }
    end
    table.sort(out, function(a, b)
        if a.updated ~= b.updated then return a.updated > b.updated end
        return a.key < b.key
    end)
    return out
end

function Ch.Record(key)
    return Store()[key]
end

function Ch.SetMoney(key, money)
    local rec = Store()[key]
    if rec then rec.money = money end
end

function Ch.Forget(key)
    Store()[key] = nil
    Ch.dirty = true
end

function Ch.ForgetAllExcept(keep)
    for key in pairs(Store()) do
        if key ~= keep then Store()[key] = nil end
    end
    Ch.dirty = true
end

-- itemID -> character key -> storage -> count, rebuilt only after the saved data changed.
local function Index()
    if Ch.index and not Ch.dirty then return Ch.index end
    local index = {}
    for key, rec in pairs(Store()) do
        for storage, saved in pairs(rec.storages or {}) do
            for _, row in ipairs(saved.items) do
                if row.itemID then
                    local perChar = index[row.itemID] or {}
                    index[row.itemID] = perChar
                    local perStorage = perChar[key] or {}
                    perChar[key] = perStorage
                    perStorage[storage] = (perStorage[storage] or 0) + (row.count or 1)
                end
            end
        end
    end
    Ch.index, Ch.dirty = index, false
    return index
end

function Ch.ClassHex(class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return ("%02x%02x%02x"):format(color.r * 255 + 0.5, color.g * 255 + 0.5, color.b * 255 + 0.5) end
    return "c8ccd4"
end

-- Tooltip lines for an item: one per character that has some, skipped when everything is in the
-- current character's bags (nothing to add). Returns { text } rows, at most `limit` characters.
function Ch.CountLines(itemID, currentKey, limit)
    local perChar = Index()[itemID]
    if not perChar then return {} end
    local rows, outside = {}, false
    for key, counts in pairs(perChar) do
        local parts, total = {}, 0
        for _, storage in ipairs(Ch.storages) do
            local n = counts[storage]
            if n and n > 0 then
                parts[#parts + 1] = ("%s %d"):format(Ch.labels[storage], n)
                total = total + n
                if key ~= currentKey or storage ~= "CARRIED" then outside = true end
            end
        end
        if total > 0 then
            local rec = Store()[key]
            rows[#rows + 1] = { key = key, total = total, class = rec and rec.class, name = rec and rec.name or key,
                text = table.concat(parts, "  ") }
        end
    end
    if not outside then return {} end
    table.sort(rows, function(a, b)
        if (a.key == currentKey) ~= (b.key == currentKey) then return a.key == currentKey end
        if a.total ~= b.total then return a.total > b.total end
        return a.key < b.key
    end)
    local lines = {}
    for i, row in ipairs(rows) do
        if limit and i > limit then break end
        lines[#lines + 1] = { left = ("|cff%s%s|r"):format(Ch.ClassHex(row.class), row.name), right = row.text }
    end
    return lines
end

function Ch.Age(seconds)
    seconds = math.max(0, seconds or 0)
    if seconds < 90 then return "just now" end
    if seconds < 5400 then return ("%d min ago"):format(math.floor(seconds / 60 + 0.5)) end
    if seconds < 129600 then return ("%d hr ago"):format(math.floor(seconds / 3600 + 0.5)) end
    return ("%d days ago"):format(math.floor(seconds / 86400 + 0.5))
end
