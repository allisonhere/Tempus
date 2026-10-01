local _, T = ...
local SK, S = T.Skins, T.Style
local Q = {}
T.QuestFilters = Q

local function Normalize(text)
    return (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
end

local function NearWord(a, b)
    if math.abs(#a - #b) > 1 then return false end
    local previous = {}
    for j = 0, #b do previous[j] = j end
    for i = 1, #a do
        local current = { [0] = i }
        for j = 1, #b do
            current[j] = math.min(current[j - 1] + 1, previous[j] + 1,
                previous[j - 1] + (a:sub(i, i) == b:sub(j, j) and 0 or 1))
        end
        previous = current
    end
    return previous[#b] <= 1
end

function Q.Matches(text, query)
    text, query = Normalize(text), Normalize(query)
    for token in query:gmatch("%S+") do
        local matched = text:find(token, 1, true) ~= nil
        if not matched then
            local position = 1
            for i = 1, #token do
                local found = text:find(token:sub(i, i), position, true)
                if not found then position = nil; break end
                position = found + 1
            end
            matched = position ~= nil
        end
        if not matched and #token >= 4 then
            for word in text:gmatch("%S+") do
                if NearWord(token, word) then matched = true; break end
            end
        end
        if not matched then return false end
    end
    return true
end

function Q.Filter(entries, hidden, query)
    local result, header, added = {}, nil, false
    for _, entry in ipairs(entries) do
        if entry.isHeader then
            header, added = entry, false
        elseif not entry.isHidden and not hidden[header and header.title or ""]
            and Q.Matches(entry.title .. " " .. (header and header.title or ""), query) then
            if header and not added then result[#result + 1] = header; added = true end
            result[#result + 1] = entry
        end
    end
    return result
end

function Q:HiddenZones()
    TempusDB.questHiddenZones = TempusDB.questHiddenZones or {}
    local key = UnitName("player") .. " - " .. GetRealmName()
    TempusDB.questHiddenZones[key] = TempusDB.questHiddenZones[key] or {}
    return TempusDB.questHiddenZones[key]
end

function Q:Entries()
    local entries = {}
    local modern = C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo
    local count = modern and C_QuestLog.GetNumQuestLogEntries() or GetNumQuestLogEntries()
    for index = 1, count do
        local entry
        if modern then
            local info = C_QuestLog.GetInfo(index)
            if info then
                entry = { title = info.title, level = info.level, isHeader = info.isHeader,
                    isHidden = info.isHidden, questID = info.questID, index = index }
            end
        else
            local title, level, _, isHeader, _, _, _, questID, _, _, _, _, _, _, _, isHidden = GetQuestLogTitle(index)
            entry = { title = title, level = level, isHeader = isHeader,
                isHidden = isHidden, questID = questID, index = index }
        end
        if entry and entry.title then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

local function Button(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(text)
    SK:Button(button)
    return button
end

function Q:Render(view)
    local hidden, entries = self:HiddenZones(), self:Entries()
    local query = view.search:GetText()
    local active = query:find("%S") or next(hidden)
    view.overlay:SetShown(active ~= nil or view.zones)
    if not active and not view.zones then return end
    local list = {}
    if view.zones then
        local seen = {}
        for _, entry in ipairs(entries) do
            if entry.isHeader and not seen[entry.title] then
                seen[entry.title] = true
                list[#list + 1] = entry
            end
        end
        for title in pairs(hidden) do
            if not seen[title] then list[#list + 1] = {title = title, isHeader = true} end
        end
        table.sort(list, function(a, b) return a.title < b.title end)
    else
        list = self.Filter(entries, hidden, query)
    end
    view.list = list
    local count = math.max(1, math.floor((view.overlay:GetHeight() - 8) / 24))
    view.offset = math.max(0, math.min(view.offset, #list - count))
    view.empty:SetText(view.zones and "No zones in the quest log." or "No matching quests.")
    view.empty:SetShown(#list == 0)
    for i = 1, math.max(count, #view.rows) do
        local row = view.rows[i]
        if not row and i <= count then
            row = CreateFrame("Button", nil, view.overlay)
            row:SetHeight(24)
            row:SetPoint("TOPLEFT", 8, -4 - (i - 1) * 24)
            row:SetPoint("RIGHT", -8, 0)
            row.text = S.Text(row, 12)
            row.text:SetPoint("LEFT")
            row.text:SetPoint("RIGHT")
            row.text:SetWordWrap(false)
            row:SetHighlightTexture(S.WHITE)
            row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row:SetScript("OnClick", function(button, mouseButton)
                local entry = button.entry
                if view.zones or (entry.isHeader and mouseButton == "RightButton") then
                    local zones = Q:HiddenZones()
                    zones[entry.title] = not zones[entry.title] or nil
                    Q:Refresh()
                elseif not entry.isHeader then
                    if view.map then QuestMapFrame_ShowQuestDetails(entry.questID)
                    else QuestLog_SetSelection(entry.index); QuestLog_Update() end
                end
            end)
            view.rows[i] = row
        end
        if row then
            local entry = i <= count and list[view.offset + i]
            row.entry = entry
            row:SetShown(entry ~= nil)
            if entry then
                local prefix = view.zones and (hidden[entry.title] and "[ ] " or "[x] ")
                    or (entry.isHeader and "" or "    ")
                row.text:SetText(prefix .. entry.title)
                local color = entry.isHeader and S.C.muted or S.C.text
                row.text:SetTextColor(color[1], color[2], color[3])
            end
        end
    end
end

function Q:Refresh()
    for _, view in ipairs(self.views or {}) do self:Render(view) end
end

function Q:Attach(parent, list, map)
    if parent.tempusQuestFilters then return end
    parent.tempusQuestFilters = true
    local view = { rows = {}, offset = 0, map = map }
    self.views = self.views or {}
    self.views[#self.views + 1] = view
    local host = map and list or parent
    local toolbar = CreateFrame("Frame", nil, host)
    toolbar:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", map and 0 or 19, 4)
    toolbar:SetWidth(list:GetWidth())
    toolbar:SetHeight(28)
    toolbar:SetFrameLevel(list:GetFrameLevel() + 20)
    S.Backdrop(toolbar, { fill = S.C.bg, shadow = false })
    local search = CreateFrame("EditBox", nil, toolbar, "InputBoxTemplate")
    search:SetAutoFocus(false)
    search:SetFontObject(GameFontHighlightSmall)
    search:SetHeight(24)
    search:SetPoint("LEFT", 8, 0)
    search:SetPoint("RIGHT", -132, 0)
    SK:EditBox(search)
    view.search = search
    local hint = S.Text(search, 11, S.C.muted)
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText("Search quests or zones...")
    search:SetScript("OnTextChanged", function()
        hint:SetShown(search:GetText() == "")
        view.offset = 0
        Q:Render(view)
    end)
    search:SetScript("OnEscapePressed", function() search:SetText(""); search:ClearFocus() end)
    search:SetScript("OnEnterPressed", function() search:ClearFocus() end)
    local zones = Button(toolbar, "Zones", 60)
    zones:SetPoint("RIGHT", -66, 0)
    zones:SetScript("OnClick", function()
        view.zones = not view.zones
        zones:SetText(view.zones and "Done" or "Zones")
        view.offset = 0
        Q:Render(view)
    end)
    local reset = Button(toolbar, "Reset", 60)
    reset:SetPoint("RIGHT", -4, 0)
    reset:SetScript("OnClick", function()
        local hidden = Q:HiddenZones()
        for title in pairs(hidden) do hidden[title] = nil end
        search:SetText("")
        Q:Refresh()
    end)
    local overlay = CreateFrame("Frame", nil, host)
    overlay:SetAllPoints(list)
    overlay:SetFrameLevel(list:GetFrameLevel() + 10)
    overlay:EnableMouse(true)
    overlay:EnableMouseWheel(true)
    S.Backdrop(overlay, { fill = { S.C.bg[1], S.C.bg[2], S.C.bg[3], 1 }, shadow = false })
    view.overlay = overlay
    view.empty = S.Text(overlay, 12, S.C.muted)
    view.empty:SetPoint("TOPLEFT", 8, -10)
    overlay:SetScript("OnMouseWheel", function(_, delta)
        view.offset = view.offset - delta * 3
        Q:Render(view)
    end)
    overlay:SetScript("OnSizeChanged", function() Q:Render(view) end)
    list:HookScript("OnShow", function() Q:Render(view) end)
    list:HookScript("OnSizeChanged", function() toolbar:SetWidth(list:GetWidth()); Q:Render(view) end)
    parent:HookScript("OnShow", function() Q:Render(view) end)
    Q:Render(view)
end

function SK:InitQuestFilters()
    if QuestLogFrame and QuestLogListScrollFrame then Q:Attach(QuestLogFrame, QuestLogListScrollFrame, false) end
    if QuestMapFrame and QuestMapFrame.QuestsFrame then Q:Attach(QuestMapFrame, QuestMapFrame.QuestsFrame, true) end
    if Q.events then return end
    Q.events = CreateFrame("Frame")
    Q.events:RegisterEvent("QUEST_LOG_UPDATE")
    Q.events:SetScript("OnEvent", function() Q:Refresh() end)
    for _, name in ipairs({ "QuestLog_Update", "QuestLogQuests_Update" }) do
        if type(_G[name]) == "function" then hooksecurefunc(name, function() Q:Refresh() end) end
    end
end
