-- Tempus UI: the info bar, a panel of live data texts (ElvUI's datatexts).
local _, T = ...
local S = T.Style

local DB = { slots = {} }
T.DataBar = DB

DB.defaults = {
    enabled = true,
    width = 560, height = 22, fontSize = 11,
    slots = { "system", "durability", "bags", "gold", "time", "NONE", "NONE", "NONE" },
    count = 5,
    time24 = true,
    point = { "BOTTOM", "UIParent", "BOTTOM", 0, 10 },
}

local ACC = T.accentHex
local function Hex(r, g, b) return ("%02x%02x%02x"):format(r * 255, g * 255, b * 255) end
local function Grade(p)     -- 0..1, green when high
    if p > 0.5 then return Hex(1 - (p - 0.5) * 2 * 0.8, 0.9, 0.3) end
    return Hex(1, 0.2 + p * 1.4, 0.2)
end

----------------------------------------------------------------------------------------
-- Session state
----------------------------------------------------------------------------------------
local sessionStartMoney
local function Money() local m = GetMoney(); return T.Num(m) and m or 0 end

local function FormatMoney(copper, icons)
    copper = math.floor(math.abs(copper))
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if icons and GetCoinTextureString then return GetCoinTextureString(copper) end
    if g > 0 then return ("|cffffd700%s|rg |cffc7c7cf%d|rs"):format(BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g, s) end
    if s > 0 then return ("|cffc7c7cf%d|rs |cffeda55f%d|rc"):format(s, c) end
    return ("|cffeda55f%d|rc"):format(c)
end

local function SaveGold()
    TempusDB.gold = TempusDB.gold or {}
    local realm = GetRealmName() or "?"
    TempusDB.gold[realm] = TempusDB.gold[realm] or {}
    local _, class = UnitClass("player")
    TempusDB.gold[realm][UnitName("player") or "?"] = { money = Money(), class = class }
end

local function BagSlots()
    local free, total = 0, 0
    local numFree = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
    local numSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local f, fam = numFree(bag)
        local n = numSlots(bag)
        if T.Num(f) and T.Num(n) and (fam == 0 or fam == nil) then
            free, total = free + f, total + n
        end
    end
    return free, total
end

local DURABILITY_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }
local function Durability()
    local lowest, items = 1, {}
    for _, slot in ipairs(DURABILITY_SLOTS) do
        local cur, max = GetInventoryItemDurability(slot)
        if T.Num(cur) and T.Num(max) and max > 0 then
            local p = cur / max
            lowest = math.min(lowest, p)
            items[#items + 1] = { slot = slot, p = p }
        end
    end
    return lowest, items
end

----------------------------------------------------------------------------------------
-- Data texts: text() -> string, tooltip(tt), click(button), interval (seconds, optional)
----------------------------------------------------------------------------------------
DB.texts = {}
local function Add(key, label, def) def.label = label; DB.texts[key] = def end

Add("time", "Time", {
    interval = 1,
    text = function()
        local h, m = tonumber(date("%H")), tonumber(date("%M"))
        if DB.db.time24 then return ("%02d:%02d"):format(h, m) end
        return ("%d:%02d |cff%s%s|r"):format((h % 12 == 0) and 12 or h % 12, m, ACC, h < 12 and "am" or "pm")
    end,
    tooltip = function(tt)
        tt:AddLine("Time", 1, 1, 1)
        tt:AddDoubleLine("Local", date("%H:%M"), 0.7, 0.75, 0.8, 1, 1, 1)
        if GetGameTime then
            local h, m = GetGameTime()
            if T.Num(h) and T.Num(m) then tt:AddDoubleLine("Realm", ("%02d:%02d"):format(h, m), 0.7, 0.75, 0.8, 1, 1, 1) end
        end
        tt:AddDoubleLine("Played this session", SecondsToTime and SecondsToTime(GetTime() - DB.loginTime) or "", 0.7, 0.75, 0.8, 1, 1, 1)
        tt:AddLine(" ")
        tt:AddLine("Click: calendar / clock", 0.5, 0.8, 1)
    end,
    click = function()
        if ToggleCalendar then pcall(ToggleCalendar) elseif TimeManager_Toggle then pcall(TimeManager_Toggle) end
    end,
})

Add("system", "FPS & Latency", {
    interval = 1,
    text = function()
        local fps = math.floor(GetFramerate() + 0.5)
        local _, _, home, world = GetNetStats()
        local ms = math.max(T.Num(home) and home or 0, T.Num(world) and world or 0)
        local fc = Grade(math.min(fps / 60, 1))
        local mc = Grade(1 - math.min(ms / 300, 1))
        return ("|cff%s%d|r fps  |cff%s%d|r ms"):format(fc, fps, mc, ms)
    end,
    tooltip = function(tt)
        tt:AddLine("System", 1, 1, 1)
        local _, _, home, world = GetNetStats()
        tt:AddDoubleLine("Home latency", ("%d ms"):format(T.Num(home) and home or 0), 0.7, 0.75, 0.8, 1, 1, 1)
        tt:AddDoubleLine("World latency", ("%d ms"):format(T.Num(world) and world or 0), 0.7, 0.75, 0.8, 1, 1, 1)
        if not InCombatLockdown() and UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
            UpdateAddOnMemoryUsage()
            local list, total = {}, 0
            local num = (C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns)()
            for i = 1, num do
                local mem = GetAddOnMemoryUsage(i)
                if T.Num(mem) and mem > 0 then
                    total = total + mem
                    local name = (C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo)(i)
                    list[#list + 1] = { name, mem }
                end
            end
            table.sort(list, function(a, b) return a[2] > b[2] end)
            tt:AddLine(" ")
            tt:AddDoubleLine("Addon memory", ("%.1f MB"):format(total / 1024), 1, 1, 1, 1, 1, 1)
            for i = 1, math.min(8, #list) do
                local m = list[i][2]
                tt:AddDoubleLine(list[i][1], m > 1024 and ("%.1f MB"):format(m / 1024) or ("%d KB"):format(m), 0.7, 0.75, 0.8, 1, 1, 1)
            end
            tt:AddLine(" ")
            tt:AddLine("Click: free unused memory", 0.5, 0.8, 1)
        end
    end,
    click = function()
        if InCombatLockdown() then return end
        local before = collectgarbage("count")
        collectgarbage("collect")
        T:Print("freed %.1f MB.", (before - collectgarbage("count")) / 1024)
    end,
})

Add("durability", "Durability", {
    events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" },
    text = function()
        local p = Durability()
        return ("Armor |cff%s%d%%|r"):format(Grade(p), math.floor(p * 100 + 0.5))
    end,
    tooltip = function(tt)
        tt:AddLine("Durability", 1, 1, 1)
        local _, items = Durability()
        table.sort(items, function(a, b) return a.p < b.p end)
        for _, it in ipairs(items) do
            local link = GetInventoryItemLink("player", it.slot)
            local name = link and GetItemInfo(link) or ("Slot " .. it.slot)
            tt:AddDoubleLine(name, ("|cff%s%d%%|r"):format(Grade(it.p), math.floor(it.p * 100 + 0.5)), 0.8, 0.8, 0.8)
        end
        tt:AddLine(" ")
        tt:AddLine("Click: character sheet", 0.5, 0.8, 1)
    end,
    click = function() if ToggleCharacter then ToggleCharacter("PaperDollFrame") end end,
})

Add("bags", "Bag Space", {
    events = { "BAG_UPDATE_DELAYED", "BAG_UPDATE" },
    text = function()
        local free, total = BagSlots()
        return ("Bags |cff%s%d|r/%d"):format(Grade(total > 0 and free / total or 1), free, total)
    end,
    tooltip = function(tt)
        local free, total = BagSlots()
        tt:AddLine("Bags", 1, 1, 1)
        tt:AddDoubleLine("Free", free, 0.7, 0.75, 0.8, 1, 1, 1)
        tt:AddDoubleLine("Used", total - free, 0.7, 0.75, 0.8, 1, 1, 1)
        tt:AddLine(" ")
        tt:AddLine("Click: open bags", 0.5, 0.8, 1)
    end,
    click = function() if ToggleAllBags then ToggleAllBags() end end,
})

Add("gold", "Gold", {
    events = { "PLAYER_MONEY" },
    text = function()
        SaveGold()
        return FormatMoney(Money())
    end,
    tooltip = function(tt)
        tt:AddLine("Gold", 1, 1, 1)
        local diff = Money() - (sessionStartMoney or Money())
        tt:AddDoubleLine("This session", (diff < 0 and "|cffff6060-|r" or "|cff60ff60+|r") .. FormatMoney(diff), 0.7, 0.75, 0.8)
        local realm = GetRealmName() or "?"
        local total = 0
        tt:AddLine(" ")
        tt:AddLine("Characters on " .. realm, 1, 1, 1)
        for name, info in pairs((TempusDB.gold or {})[realm] or {}) do
            local r, g, b = S.ClassColor(info.class)
            tt:AddDoubleLine(name, FormatMoney(info.money), r, g, b)
            total = total + info.money
        end
        tt:AddDoubleLine("Total", FormatMoney(total), 1, 1, 1)
        tt:AddLine(" ")
        tt:AddLine("Click: open bags", 0.5, 0.8, 1)
    end,
    click = function() if ToggleAllBags then ToggleAllBags() end end,
})

Add("coords", "Coordinates", {
    interval = 0.2,
    text = function()
        local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local pos = T.Num(map) and C_Map.GetPlayerMapPosition(map, "player")
        local x, y
        if pos then x, y = pos:GetXY() end
        if T.Num(x) and T.Num(y) and (x > 0 or y > 0) then return ("%.1f, %.1f"):format(x * 100, y * 100) end
        return "--, --"
    end,
    click = function() if ToggleWorldMap then ToggleWorldMap() end end,
})

Add("xp", "Experience", {
    events = { "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP" },
    text = function()
        local cur, max = UnitXP("player"), UnitXPMax("player")
        if not (T.Num(cur) and T.Num(max)) or max == 0 then return "XP --" end
        local rest = GetXPExhaustion()
        local r = T.Num(rest) and rest > 0 and (" |cff4fa3ff+%d%%|r"):format(math.floor(rest / max * 100)) or ""
        return ("XP |cff%s%.1f%%|r%s"):format(ACC, cur / max * 100, r)
    end,
    tooltip = function(tt)
        local cur, max = UnitXP("player"), UnitXPMax("player")
        tt:AddLine("Experience", 1, 1, 1)
        if T.Num(cur) and T.Num(max) and max > 0 then
            tt:AddDoubleLine("Current", ("%s / %s"):format(BreakUpLargeNumbers and BreakUpLargeNumbers(cur) or cur, BreakUpLargeNumbers and BreakUpLargeNumbers(max) or max), 0.7, 0.75, 0.8, 1, 1, 1)
            tt:AddDoubleLine("To level", max - cur, 0.7, 0.75, 0.8, 1, 1, 1)
            local rest = GetXPExhaustion()
            if T.Num(rest) and rest > 0 then tt:AddDoubleLine("Rested", rest, 0.7, 0.75, 0.8, 0.3, 0.65, 1) end
        end
    end,
})

Add("friends", "Friends", {
    events = { "FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE" },
    text = function()
        local n = C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends() or 0
        local bn = BNGetNumFriends and select(2, BNGetNumFriends()) or 0
        return ("Friends |cff%s%d|r"):format(ACC, (T.Num(n) and n or 0) + (T.Num(bn) and bn or 0))
    end,
    click = function() if ToggleFriendsFrame then ToggleFriendsFrame(1) end end,
})

Add("guild", "Guild", {
    events = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" },
    text = function()
        if not IsInGuild() then return "No guild" end
        local _, online = GetNumGuildMembers()
        return ("Guild |cff%s%d|r"):format(ACC, T.Num(online) and online or 0)
    end,
    click = function() if ToggleGuildFrame then ToggleGuildFrame() elseif ToggleFriendsFrame then ToggleFriendsFrame(3) end end,
})

Add("zone", "Zone", {
    events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" },
    text = function()
        local sub = GetSubZoneText and GetSubZoneText() or ""
        return sub ~= "" and sub or (GetZoneText and GetZoneText() or "")
    end,
    click = function() if ToggleWorldMap then ToggleWorldMap() end end,
})

function DB:TextList()
    local list = { { "NONE", "Empty" } }
    for key, def in pairs(DB.texts) do list[#list + 1] = { key, def.label } end
    table.sort(list, function(a, b) return a[1] == "NONE" or (b[1] ~= "NONE" and a[2] < b[2]) end)
    return list
end

----------------------------------------------------------------------------------------
-- Bar
----------------------------------------------------------------------------------------
local function UpdateSlot(slot)
    local def = DB.texts[slot.key]
    if not def then slot.text:SetText("") return end
    local ok, text = pcall(def.text)
    slot.text:SetText(ok and text or "")
end

local function SlotEnter(slot)
    local def = DB.texts[slot.key]
    if not def or not def.tooltip then return end
    GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
    GameTooltip:ClearLines()
    pcall(def.tooltip, GameTooltip)
    GameTooltip:Show()
end

local function CreateSlot(i)
    local slot = CreateFrame("Button", nil, DB.bar)
    slot:RegisterForClicks("AnyUp")
    slot.text = slot:CreateFontString(nil, "OVERLAY")
    slot.text:SetPoint("CENTER")
    slot.text:SetWordWrap(false)
    slot.sep = S.Tex(slot, "ARTWORK", { 1, 1, 1, 0.08 })
    slot.sep:SetWidth(1)
    slot.sep:SetPoint("TOPLEFT", 0, -4)
    slot.sep:SetPoint("BOTTOMLEFT", 0, 4)
    slot.hl = S.Tex(slot, "HIGHLIGHT", { 1, 1, 1, 0.05 })
    slot.hl:SetAllPoints()
    slot:SetScript("OnEnter", SlotEnter)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slot:SetScript("OnClick", function(self, button)
        local def = DB.texts[self.key]
        if def and def.click then pcall(def.click, button) end
        UpdateSlot(self)
    end)
    slot.elapsed = 0
    slot:SetScript("OnUpdate", T:Wrap("infobar.slots", function(self, elapsed)
        local def = DB.texts[self.key]
        if not def or not def.interval then return end
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= def.interval then
            self.elapsed = 0
            UpdateSlot(self)
        end
    end))
    DB.slots[i] = slot
    return slot
end

function DB:Refresh()
    local db = DB.db
    local bar = DB.bar
    bar:SetShown(db.enabled)
    if not db.enabled then return end
    bar:SetSize(db.width, db.height)
    T.Movers.ApplyPoint(bar, db)
    local n = math.max(1, math.min(db.count, 8))
    local w = db.width / n
    for i = 1, 8 do
        local slot = DB.slots[i] or CreateSlot(i)
        if i <= n then
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", bar, "TOPLEFT", (i - 1) * w, 0)
            slot:SetSize(w, db.height)
            slot.key = db.slots[i] or "NONE"
            slot.sep:SetShown(i > 1)
            S.ApplyFont(slot.text, db.fontSize, nil, "NONE")
            slot.text:SetWidth(w - 6)
            slot:Show()
            UpdateSlot(slot)
        else
            slot:Hide()
        end
    end
    -- Event-driven texts refresh on their events.
    DB.events:UnregisterAllEvents()
    for i = 1, n do
        local def = DB.texts[DB.slots[i].key]
        for _, e in ipairs(def and def.events or {}) do pcall(DB.events.RegisterEvent, DB.events, e) end
    end
    DB.events:RegisterEvent("PLAYER_ENTERING_WORLD")
end

T:NewModule("databar", {
    label = "Info Bar",
    desc = "A panel of live info: time, FPS and latency, durability, bag space, gold across characters, coordinates, XP, friends and guild.",
    defaults = DB.defaults,
    OnEnable = function()
        DB.db = T.db.databar
        DB.loginTime = GetTime()
        sessionStartMoney = Money()
        local bar = CreateFrame("Frame", "TempusInfoBar", UIParent)
        bar:SetFrameStrata("LOW")
        S.Backdrop(bar)
        DB.bar = bar
        DB.events = CreateFrame("Frame")
        DB.events:SetScript("OnEvent", function()
            for i = 1, math.min(DB.db.count, 8) do if DB.slots[i] then UpdateSlot(DB.slots[i]) end end
        end)
        T.Movers:Register(bar, {
            label = "Info Bar", page = "databar",
            cfg = function() return DB.db end,
            corner = function() return DB.db.point[1] end,
            enabled = function() return DB.db.enabled end,
        })
        DB:Refresh()
    end,
    OnSettings = function()
        DB.db = T.db.databar
        DB:Refresh()
    end,
})
