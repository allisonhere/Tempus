-- Search operates on registered pages and widget metadata, without running callbacks.
local _, T = ...
local Search = {}
T.SettingsSearch = Search
function Search.Normalize(text)
    return tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", " "):match("^%s*(.-)%s*$"):lower()
end
function Search.Matches(text, query)
    text = Search.Normalize(text)
    for word in Search.Normalize(query):gmatch("%S+") do
        if not text:find(word, 1, true) then return false end
    end
    return true
end
function Search.Results(definitions, built, sections, query, limit)
    query = Search.Normalize(query)
    if #query < 2 then return {}, 0 end
    local labels, results = {}, {}
    for _, section in ipairs(sections) do labels[section.key] = section.label end
    for _, def in ipairs(definitions) do
        local path = (labels[def.section] or def.section or "Settings") .. " > " .. def.label
        local function Add(label, text, entry, order)
            local breadcrumb = path .. (entry and entry.section and (" > " .. entry.section) or "")
            if not Search.Matches(breadcrumb .. " " .. label .. " " .. text, query) then return end
            local normalized = Search.Normalize(label)
            local score = normalized == query and 0 or (Search.Matches(label, query) and 1 or 2)
            results[#results + 1] = {page = def.key, label = label, breadcrumb = breadcrumb,
                y = entry and entry.y or -18, widget = entry and entry.widget, score = score, order = order, unavailable = def.unavailable}
        end
        Add(def.label, def.search or "", nil, 0)
        local page = built[def.key]
        for i, entry in ipairs(not def.pinned and page and page.searchEntries or {}) do Add(entry.label, entry.text or entry.label, entry, i) end
    end
    table.sort(results, function(a,b)
        if a.score ~= b.score then return a.score < b.score end
        if a.breadcrumb ~= b.breadcrumb then return a.breadcrumb < b.breadcrumb end
        if a.label ~= b.label then return a.label < b.label end
        if a.page ~= b.page then return a.page < b.page end
        return a.order < b.order
    end)
    local total = #results
    for i = #results, (limit or 100) + 1, -1 do results[i] = nil end
    return results, total
end
