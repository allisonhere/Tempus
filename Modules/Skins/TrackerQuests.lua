local _, T = ...
local SK, S, Q = T.Skins, T.Style, T.QuestFilters
local F = {}
T.TrackerQuestFilters = F

function F:CollapsedZones()
    TempusDB.trackerCollapsedZones = TempusDB.trackerCollapsedZones or {}
    local key = UnitName("player") .. " - " .. GetRealmName()
    TempusDB.trackerCollapsedZones[key] = TempusDB.trackerCollapsedZones[key] or {}
    return TempusDB.trackerCollapsedZones[key]
end

function F.Groups(entries, blocks, query)
    local groups, byZone, zone, seen = {}, {}, "Quests", {}
    for _, entry in ipairs(entries) do
        if entry.isHeader then
            zone = entry.title
        else
            local block = blocks[entry.questID]
            if block then
                seen[block] = true
                if Q.Matches(entry.title .. " " .. zone, query) then
                    local group = byZone[zone]
                    if not group then
                        group = {title = zone, blocks = {}}
                        byZone[zone] = group
                        groups[#groups + 1] = group
                    end
                    group.blocks[#group.blocks + 1] = block
                end
            end
        end
    end
    -- Turn-in animations can briefly outlive the quest's log entry.
    local extra = {title = "Quests", blocks = {}}
    for _, block in pairs(blocks) do
        if not seen[block] and Q.Matches(block.HeaderText and block.HeaderText:GetText() or "", query) then
            extra.blocks[#extra.blocks + 1] = block
        end
    end
    table.sort(extra.blocks, function(a, b) return a.id < b.id end)
    if #extra.blocks > 0 then groups[#groups + 1] = extra end
    return groups
end

function F:Layout(module)
    local view = module.tempusQuestZones
    if not view or self.layingOut then return end
    if InCombatLockdown() then
        T:RunOOC(function() F:Refresh() end, "skins.trackerquests")
        return
    end
    self.layingOut = true
    -- An error mid-layout must not leave the flag stuck, or the tracker never lays out again.
    local ok, err = pcall(self.LayoutBody, self, module, view)
    self.layingOut = false
    if not ok then
        for _, header in ipairs(view.headers) do header:Hide() end
        if T.ReportError then T:ReportError(err) end
    end
end

function F:LayoutBody(module, view)
    local collapsed = module.isCollapsed or (module.parentContainer and module.parentContainer.isCollapsed)
    for _, header in ipairs(view.headers) do header:Hide() end
    view.search:SetShown(not collapsed)
    view.empty:Hide()
    if collapsed then return end
    local blocks = {}
    for _, pool in pairs(module.usedBlocks) do
        for id, block in pairs(pool) do
            if block.used then blocks[id] = block end
        end
    end
    local query = view.search:GetText()
    local groups = self.Groups(Q:Entries(), blocks, query)
    local saved = self:CollapsedZones()
    local searching = query:find("%S") ~= nil
    local y = 32
    for _, block in pairs(blocks) do block:Hide() end
    for i, group in ipairs(groups) do
        local header = view.headers[i]
        if not header then
            header = CreateFrame("Button", nil, module.ContentsFrame)
            header:SetHeight(22)
            header.text = S.Text(header, 12, S.C.muted)
            header.text:SetPoint("LEFT", 2, 0)
            header.text:SetPoint("RIGHT", -2, 0)
            header.text:SetWordWrap(false)
            header:SetHighlightTexture(S.WHITE)
            header:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
            header:SetScript("OnClick", function(button)
                local zones = F:CollapsedZones()
                zones[button.zone] = not zones[button.zone] or nil
                F:Refresh()
            end)
            view.headers[i] = header
        end
        local folded = saved[group.title] and not searching
        header.zone = group.title
        header.text:SetText((folded and "+ " or "- ") .. group.title .. " (" .. #group.blocks .. ")")
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", module.ContentsFrame, "TOPLEFT", 0, -y)
        header:SetPoint("RIGHT", module.ContentsFrame, "RIGHT", 0, 0)
        header:Show()
        y = y + 26
        if not folded then
            for _, block in ipairs(group.blocks) do
                block:ClearAllPoints()
                block:SetPoint("TOP", module.ContentsFrame, "TOP", 0, -y)
                block:SetPoint("LEFT", block.offsetX or module.blockOffsetX or 20, 0)
                if not block.fixedWidth then block:SetPoint("RIGHT") end
                block:Show()
                y = y + block:GetHeight() + 8
            end
        end
    end
    if #groups == 0 then
        view.empty:Show()
        y = y + 24
    end
    module.contentsHeight = (module.headerHeight or 25) + y
    module:UpdateHeight()
    self.layingOut = false
    SK:UpdateTrackerPanel()
    -- Frame rectangles settle a frame later; fit the panel again once they have.
    C_Timer.After(0, function() SK:UpdateTrackerPanel() end)
end

function F:Refresh()
    for module in pairs(self.modules or {}) do module:MarkDirty() end
end

function F:Attach(module)
    if module.tempusQuestZones then return end
    local view = {headers = {}}
    module.tempusQuestZones = view
    self.modules = self.modules or {}
    self.modules[module] = true
    local search = CreateFrame("EditBox", nil, module.ContentsFrame, "InputBoxTemplate")
    view.search = search
    search:SetAutoFocus(false)
    search:SetFontObject(GameFontHighlightSmall)
    search:SetHeight(24)
    search:SetPoint("TOPLEFT", module.ContentsFrame, "TOPLEFT", 6, -2)
    search:SetPoint("RIGHT", module.ContentsFrame, "RIGHT", -6, 0)
    SK:EditBox(search)
    local hint = S.Text(search, 11, S.C.muted)
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText("Search tracked quests or zones...")
    search:SetScript("OnTextChanged", function()
        hint:SetShown(search:GetText() == "")
        F:Refresh()
    end)
    search:SetScript("OnEscapePressed", function() search:SetText(""); search:ClearFocus() end)
    search:SetScript("OnEnterPressed", function() search:ClearFocus() end)
    view.empty = S.Text(module.ContentsFrame, 12, S.C.muted)
    view.empty:SetPoint("TOPLEFT", 6, -34)
    view.empty:SetText("No matching tracked quests.")
    view.empty:Hide()
    -- Search matches must be built before the native tracker's height limit is reached.
    if module.EnumQuestWatchData then
        local enumerate = module.EnumQuestWatchData
        module.EnumQuestWatchData = function(owner, callback)
            local query = view.search:GetText()
            if not query:find("%S") then return enumerate(owner, callback) end
            local zones, zone = {}, "Quests"
            for _, entry in ipairs(Q:Entries()) do
                if entry.isHeader then zone = entry.title
                elseif entry.questID then zones[entry.questID] = zone end
            end
            local matches, others = {}, {}
            enumerate(owner, function(_, quest)
                local list = Q.Matches(quest.title .. " " .. (zones[quest:GetID()] or "Quests"), query)
                    and matches or others
                list[#list + 1] = quest
                return true
            end)
            for _, list in ipairs({matches, others}) do
                for _, quest in ipairs(list) do
                    if not callback(owner, quest) then return end
                end
            end
        end
    end
    hooksecurefunc(module, "EndLayout", function() F:Layout(module) end)
    module:MarkDirty()
end

function SK:InitTrackerQuestFilters()
    local function Attach(module)
        if module and module.ContentsFrame and module.EndLayout and module.EnumQuestWatchData then F:Attach(module) end
    end
    Attach(_G.QuestObjectiveTracker)
    Attach(_G.CampaignQuestObjectiveTracker)
    local tracker = _G.ObjectiveTrackerFrame
    if tracker and tracker.ForEachModule then tracker:ForEachModule(Attach) end
    if not F.events then
        F.events = CreateFrame("Frame")
        F.events:RegisterEvent("PLAYER_ENTERING_WORLD")
        F.events:SetScript("OnEvent", function()
            C_Timer.After(0, function() SK:Try("tracker quest filters", SK.InitTrackerQuestFilters, SK) end)
        end)
    end
end
