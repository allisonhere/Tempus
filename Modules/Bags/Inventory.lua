-- Tempus UI: normalized bag snapshots and the pure grid/category/search projection.
local _, T = ...
local Bags = T.Bags or {}
T.Bags = Bags

local I = {}
Bags.Inventory = I

local CATEGORY_ORDER = {
    "QUEST", "EQUIPMENT", "CONSUMABLE", "TRADE_GOODS", "RECIPE",
    "CONTAINER", "KEY", "JUNK", "MISCELLANEOUS", "EMPTY",
}
I.categories = {
    QUEST = "Quest", EQUIPMENT = "Equipment", CONSUMABLE = "Consumables",
    TRADE_GOODS = "Trade Goods", RECIPE = "Recipes", CONTAINER = "Containers",
    KEY = "Keys", JUNK = "Junk", MISCELLANEOUS = "Miscellaneous", EMPTY = "Empty",
}

function I.Key(location)
    return ("%s:%s:%s"):format(location.storage, location.container, location.slot)
end

local function Lower(value)
    return type(value) == "string" and value:lower() or ""
end

function I.Category(item)
    if not item or not item.itemID then return "EMPTY" end
    if item.quest or item.classID == 12 then return "QUEST" end
    if item.quality == 0 and not item.hasNoValue then return "JUNK" end
    local class = item.classID
    if class == 2 or class == 4 or class == 11 then return "EQUIPMENT" end
    if class == 0 then return "CONSUMABLE" end
    if class == 3 or class == 5 or class == 6 or class == 7 or class == 8 then return "TRADE_GOODS" end
    if class == 9 then return "RECIPE" end
    if class == 1 then return "CONTAINER" end
    if class == 13 then return "KEY" end
    return "MISCELLANEOUS"
end

local function SearchText(item)
    return table.concat({
        Lower(item.name), Lower(item.itemType), Lower(item.itemSubType), Lower(item.equipLoc),
        item.itemID and tostring(item.itemID) or "",
    }, " ")
end

function I.Snapshot(storage, locations, read)
    local snapshot = { storage = storage, revision = 1, slots = {}, byKey = {}, byItemID = {}, used = 0, capacity = 0 }
    for _, location in ipairs(locations) do
        local key = I.Key(location)
        local source = read(location) or {}
        local record = {
            key = key, location = location, itemID = source.itemID, link = source.link,
            name = source.name, icon = source.icon, count = source.count or 0,
            quality = source.quality, classID = source.classID, subClassID = source.subClassID,
            itemType = source.itemType, itemSubType = source.itemSubType, equipLoc = source.equipLoc,
            locked = source.locked and true or false, readable = source.readable ~= false,
            quest = source.quest and true or false, isNew = source.isNew and true or false,
            hasNoValue = source.hasNoValue and true or false, bagFamily = source.bagFamily or 0,
            itemLevel = source.itemLevel, bindType = source.bindType, bound = source.bound and true or false,
            durability = source.durability, maxDurability = source.maxDurability,
            empty = not source.itemID,
        }
        record.category = I.Category(record)
        record.searchText = SearchText(record)
        snapshot.capacity = snapshot.capacity + 1
        if not record.empty then
            snapshot.used = snapshot.used + 1
            snapshot.byItemID[record.itemID] = snapshot.byItemID[record.itemID] or {}
            snapshot.byItemID[record.itemID][key] = true
        end
        snapshot.slots[#snapshot.slots + 1] = record
        snapshot.byKey[key] = record
    end
    return snapshot
end

local function Matches(item, query)
    if query == "" then return true end
    if item.empty then return false end
    for token in query:gmatch("%S+") do
        if not item.searchText:find(token, 1, true) then return false end
    end
    return true
end

-- Filter chips: each maps to the built-in categories it keeps. Custom categories count as their own
-- item's built-in category, so a "Fishing" potion still shows under the Consumables chip.
I.filters = {
    { key = "ALL", label = "All" },
    { key = "GEAR", label = "Gear", categories = { EQUIPMENT = true } },
    { key = "CONSUMABLE", label = "Consumables", categories = { CONSUMABLE = true } },
    { key = "QUEST", label = "Quest", categories = { QUEST = true } },
    { key = "JUNK", label = "Junk", categories = { JUNK = true } },
}
local filterByKey = {}
for _, filter in ipairs(I.filters) do filterByKey[filter.key] = filter end

local function PassesFilter(item, filter)
    local def = filterByKey[filter or "ALL"]
    if not def or not def.categories then return true end
    return def.categories[item.category] == true
end

-- Quality, then item level, then name, then slot key: the key makes the order total and stable.
local function Before(a, b)
    local qa, qb = a.quality or -1, b.quality or -1
    if qa ~= qb then return qa > qb end
    local la, lb = a.itemLevel or 0, b.itemLevel or 0
    if la ~= lb then return la > lb end
    local na, nb = Lower(a.name), Lower(b.name)
    if na ~= nb then return na < nb end
    return a.key < b.key
end
I.Before = Before

-- Custom categories: customItems maps itemID -> category name. They sort between Quest and the
-- built-in categories, alphabetically, and only claim items the built-ins would not call quest or empty.
local function CategoryFor(item, customItems)
    local custom = customItems and item.itemID and customItems[item.itemID]
    if custom and item.category ~= "QUEST" then return "CUSTOM:" .. custom, custom end
    return item.category, I.categories[item.category]
end

-- opts: filter (chip key), container (limit to one bag), sort (bool), customItems (itemID -> name),
-- collapsed (section key -> true). A collapsed section keeps its count but projects no keys.
function I.Project(snapshot, mode, query, showEmpty, opts)
    opts = opts or {}
    query = Lower(query):match("^%s*(.-)%s*$") or ""
    local projection = { revision = snapshot.revision, storage = snapshot.storage, mode = mode,
        query = query, sections = {}, visibleCount = 0, totalCount = #snapshot.slots, emptyResult = false }
    local groups, labels, customKeys = {}, {}, {}
    local items = {}
    for _, item in ipairs(snapshot.slots) do
        local visible = Matches(item, query) and (showEmpty or not item.empty)
            and PassesFilter(item, opts.filter)
            and (opts.container == nil or item.location.container == opts.container)
        if visible then items[#items + 1] = item end
    end
    if opts.sort then
        local occupied, empty = {}, {}
        for _, item in ipairs(items) do
            if item.empty then empty[#empty + 1] = item else occupied[#occupied + 1] = item end
        end
        table.sort(occupied, Before)
        items = occupied
        for _, item in ipairs(empty) do items[#items + 1] = item end
    end
    for _, item in ipairs(items) do
        local key, label = "GRID", nil
        if mode == "CATEGORIES" then
            key, label = CategoryFor(item, opts.customItems)
            if key:find("^CUSTOM:") and not labels[key] then
                labels[key] = label
                customKeys[#customKeys + 1] = key
            end
        end
        groups[key] = groups[key] or {}
        groups[key][#groups[key] + 1] = item.key
        projection.visibleCount = projection.visibleCount + 1
    end
    if mode == "CATEGORIES" then
        table.sort(customKeys)
        local order = {}
        for _, key in ipairs(CATEGORY_ORDER) do
            order[#order + 1] = key
            if key == "QUEST" then for _, custom in ipairs(customKeys) do order[#order + 1] = custom end end
        end
        for _, key in ipairs(order) do
            local keys = groups[key]
            if keys and #keys > 0 then
                local collapsed = opts.collapsed and opts.collapsed[key] and true or false
                projection.sections[#projection.sections + 1] = {
                    key = key, label = labels[key] or I.categories[key], count = #keys,
                    collapsed = collapsed, keys = collapsed and {} or keys,
                }
            end
        end
    else
        projection.sections[1] = { key = "GRID", count = #(groups.GRID or {}), keys = groups.GRID or {} }
    end
    projection.emptyResult = projection.visibleCount == 0
    return projection
end
