-- Tempus UI: shopping list. Items you want with a target amount ("20 Linen Cloth"), shown in a
-- small panel with what this character has (bags and bank) and what your other characters
-- hold. Finishing an item says so. Add items by Shift-clicking one into the panel's box,
-- typing a name, or /tempus shop.
local _, T = ...
local S = T.Style
local SH = {}
T.Shopping = SH

SH.defaults = {
    enabled = true,
    items = {},                 -- { id = itemID, need = n, name = "Linen Cloth" } in list order
    showAlts = true,            -- add what other characters hold
    tooltip = true,             -- "Shopping list: 12/20" on item tooltips
    announce = true,            -- chat line and sound when an item is done
    hideDone = false,           -- drop finished items from the panel (they stay on the list)
    width = 230,
    point = { "TOPRIGHT", "UIParent", "TOPRIGHT", -24, -260 },
}

local ROW_H, PAD, MAX_ROWS = 18, 6, 20
local DONE = { 0.45, 0.85, 0.5 }

-- "[Linen Cloth] 20", "Linen Cloth x20", "20 Linen Cloth", or just the item: the item part
-- (link, id or name) and the amount (nil when none given).
function SH.ParseAdd(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return nil end
    local link = text:match("|H(item:[^|]+)|h")
    if link then
        local rest = text:gsub("|c%x+|H.-|h.-|h|r", ""):gsub("|H.-|h.-|h", "")
        return text:match("|c%x+|H.-|h.-|h|r") or text:match("|H.-|h.-|h"), tonumber(rest:match("(%d+)"))
    end
    local name, n = text:match("^(.-)%s*[xX]?%s*(%d+)$")
    if name and name ~= "" then return tonumber(name) or name, tonumber(n) end
    n, name = text:match("^(%d+)%s*[xX]?%s+(.+)$")
    if name then return tonumber(name) or name, tonumber(n) end
    return tonumber(text) or text, nil
end

-- Text and whether it is done for a have/need pair; alts adds "(+5 alts)".
function SH.ProgressText(have, need, alts)
    local done = have >= need
    local t = ("%d/%d"):format(math.min(have, need), need)
    if not done and alts and alts > 0 then t = t .. ("  |cff8c95a3+%d alts|r"):format(alts) end
    return t, done
end

local function ItemID(item)
    if type(item) == "number" then return item end
    if type(item) == "string" then
        local id = tonumber(item:match("item:(%d+)"))
        if id then return id end
    end
    local getInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
    local ok, _, link = pcall(getInfo, item)
    if ok and type(link) == "string" then return tonumber(link:match("item:(%d+)")) end
end

local function ItemName(id)
    local getInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
    local ok, name = pcall(getInfo, id)
    return ok and type(name) == "string" and name or nil
end

local function ItemIcon(id)
    local fn = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    local ok, icon = pcall(fn, id)
    return ok and icon or 134400
end

function SH:Have(id)
    local fn = GetItemCount or (C_Item and C_Item.GetItemCount)
    local ok, n = pcall(fn, id, true)
    return ok and T.Num(n) and n or 0
end

function SH:Alts(id)
    local Ch = T.Bags and T.Bags.Characters
    if not (self.db.showAlts and Ch and Ch.OthersCount) then return 0 end
    local ok, n = pcall(Ch.OthersCount, id, T:CharacterKey())
    return ok and n or 0
end

function SH:Find(id)
    for i, entry in ipairs(self.db.items) do
        if entry.id == id then return i, entry end
    end
end

-- Add (or change the target of) an item. Returns the entry, or nil and why.
function SH:Add(item, need)
    local id = ItemID(item)
    if not id then return nil, "unknown item (Shift-click the item, or see it once so the game knows its name)" end
    need = math.max(1, math.floor(tonumber(need) or 1))
    local _, entry = self:Find(id)
    if entry then entry.need = need
    else
        entry = { id = id, need = need, name = ItemName(id) or (type(item) == "string" and item:match("%[(.-)%]")) }
        table.insert(self.db.items, entry)
    end
    entry.done = self:Have(id) >= need
    self:Refresh()
    return entry
end

function SH:Remove(id)
    local i = self:Find(id)
    if i then table.remove(self.db.items, i) end
    self:Refresh()
end

function SH:Clear()
    wipe(self.db.items)
    self:Refresh()
end

-- Bags changed: refresh counts and announce anything that just got finished.
function SH:Recount()
    for _, entry in ipairs(self.db.items) do
        local done = self:Have(entry.id) >= entry.need
        if done and not entry.done and self.db.announce then
            T:Print("shopping list: |cff73d980%s done|r (%d).", entry.name or ("item " .. entry.id), entry.need)
            if PlaySound and SOUNDKIT and SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01 then
                pcall(PlaySound, SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01)
            elseif PlaySound and SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_OPEN then
                pcall(PlaySound, SOUNDKIT.IG_QUEST_LOG_OPEN)
            end
        end
        entry.done = done
        entry.name = entry.name or ItemName(entry.id)
    end
    self:Refresh()
end

-- One line per item: /tempus shop with no arguments.
function SH:PrintList()
    if #self.db.items == 0 then
        T:Print("shopping list is empty. Shift-click an item into the panel's box and add an amount, or |cff%s/tempus shop <item> <amount>|r.", T.accentHex)
        self:Open()
        return
    end
    for _, entry in ipairs(self.db.items) do
        local text = SH.ProgressText(self:Have(entry.id), entry.need, self:Alts(entry.id))
        T:Print("%s  %s", entry.name or ("item " .. entry.id), text)
    end
end

-- Show the panel with the add box focused, even while the list is empty.
function SH:Open()
    if not self.frame then return end
    self.forceShow = true
    self:UpdateShown()
    self.input:SetFocus()
end

-- /tempus shop [<item> [amount] | remove <item> | clear]
function SH:Command(rest)
    rest = (rest or ""):match("^%s*(.-)%s*$")
    if rest == "" then return self:PrintList() end
    local lower = rest:lower()
    if lower == "clear" then self:Clear(); T:Print("shopping list cleared.") return end
    local removeArg = rest:match("^[Rr][Ee][Mm][Oo][Vv][Ee]%s+(.+)$")
    if removeArg then
        local id = ItemID(SH.ParseAdd(removeArg))
        if id and self:Find(id) then self:Remove(id); T:Print("removed from the shopping list.")
        else T:Print("that item is not on the shopping list.") end
        return
    end
    local item, need = SH.ParseAdd(rest)
    local entry, why = self:Add(item, need)
    if entry then T:Print("shopping list: %s x%d.", entry.name or ("item " .. entry.id), entry.need)
    else T:Print("%s.", why) end
end

----------------------------------------------------------------------------------------
-- Panel
----------------------------------------------------------------------------------------
local function Row(self, i)
    local row = self.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, self.frame)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_H - 4, ROW_H - 4)
    row.icon:SetPoint("LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.count = S.Text(row, 11)
    row.count:SetPoint("RIGHT", 0, 0)
    row.name = S.Text(row, 11)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(r, delta)
        local _, entry = SH:Find(r.id)
        if not entry then return end
        local step = IsShiftKeyDown() and 5 or 1
        SH:Add(entry.id, math.max(1, entry.need + delta * step))
    end)
    row:SetScript("OnClick", function(r, mouse)
        if mouse == "RightButton" then SH:Remove(r.id) end
    end)
    row:SetScript("OnEnter", function(r)
        GameTooltip:SetOwner(r, "ANCHOR_LEFT")
        local ok = pcall(GameTooltip.SetItemByID, GameTooltip, r.id)
        if not ok then GameTooltip:SetText(r.name:GetText() or "") end
        GameTooltip:AddLine("Mouse wheel: change the amount (Shift: by 5). Right-click: remove.", 0.6, 0.65, 0.72, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.rows[i] = row
    return row
end

function SH:Refresh()
    local f, db = self.frame, self.db
    if not (f and db) then return end
    local y, shown = -(PAD + 16), 0
    for _, entry in ipairs(db.items) do
        local have = self:Have(entry.id)
        local text, done = SH.ProgressText(have, entry.need, self:Alts(entry.id))
        if shown < MAX_ROWS and not (done and db.hideDone) then
            shown = shown + 1
            local row = Row(self, shown)
            row.id = entry.id
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
            row:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
            row.icon:SetTexture(ItemIcon(entry.id))
            row.name:SetText(entry.name or ItemName(entry.id) or ("item " .. entry.id))
            row.count:SetText(text)
            local c = done and DONE or S.C.text
            row.name:SetTextColor(c[1], c[2], c[3])
            row.count:SetTextColor(done and DONE[1] or 1, done and DONE[2] or 1, done and DONE[3] or 1)
            row:Show()
            y = y - ROW_H
        end
    end
    for i = shown + 1, #self.rows do self.rows[i]:Hide() end
    self.empty:SetShown(shown == 0)
    if shown == 0 then
        self.empty:SetText(#db.items == 0 and "Shift-click an item below, or type a name and amount." or "Everything on the list is done.")
        y = y - ROW_H
    end
    self.input:ClearAllPoints()
    self.input:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, y - 4)
    self.input:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    f:SetSize(db.width, -y + 4 + 20 + PAD)
    self:UpdateShown()
end

function SH:UpdateShown()
    local f, db = self.frame, self.db
    if not (f and db) then return end
    local show = db.enabled and (#db.items > 0 or not T.db.locked or self.forceShow or self.input:HasFocus())
    f:SetShown(show and true or false)
end

-- Shift-clicking an item while the box has focus drops its link in, like the chat box.
local function HookLinks()
    if SH.linkHooked or not hooksecurefunc then return end
    SH.linkHooked = true
    local function Insert(link)
        local box = SH.input
        if box and box:HasFocus() and type(link) == "string" and link:find("|Hitem:") then
            box:SetText(link .. " ")
            box:SetCursorPosition(#box:GetText())
            return true
        end
    end
    if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", Insert) end
    if HandleModifiedItemClick then
        hooksecurefunc("HandleModifiedItemClick", function(link)
            if IsShiftKeyDown() then Insert(link) end
        end)
    end
end

local function HookTooltip()
    if SH.tipHooked or not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType) then return end
    SH.tipHooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not (SH.db and SH.db.enabled and SH.db.tooltip) then return end
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        local id = data and data.id
        if not T.Num(id) then return end
        local _, entry = SH:Find(id)
        if not entry then return end
        local text, done = SH.ProgressText(SH:Have(id), entry.need, SH:Alts(id))
        local c = done and DONE or { 1, 0.82, 0.3 }
        tooltip:AddDoubleLine("Shopping list", text, c[1], c[2], c[3], 1, 1, 1)
    end)
end

T:NewModule("shopping", {
    label = "Shopping list",
    desc = "Items you are collecting, with a target amount and what you and your alts already have.",
    defaults = SH.defaults,
    OnEnable = function()
        SH.db = T.db.shopping
        local f = CreateFrame("Frame", "TempusShoppingList", UIParent)
        f:SetFrameStrata("MEDIUM")
        S.Backdrop(f)
        SH.frame, SH.rows = f, {}
        local title = S.Text(f, 11, S.C.muted)
        title:SetPoint("TOPLEFT", PAD, -PAD)
        title:SetText("SHOPPING LIST")
        SH.empty = S.Text(f, 11, S.C.muted)
        SH.empty:SetPoint("TOPLEFT", PAD, -(PAD + 16))
        SH.empty:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
        SH.empty:SetJustifyH("LEFT")
        local input = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        input:SetAutoFocus(false)
        input:SetHeight(20)
        input:SetFontObject(GameFontHighlightSmall)
        if T.Skins and T.Skins.EditBox then pcall(T.Skins.EditBox, T.Skins, input) end
        local hint = S.Text(input, 10, S.C.muted)
        hint:SetPoint("LEFT", 2, 0)
        hint:SetText("Add: Shift-click item, amount, Enter")
        input:SetScript("OnTextChanged", function(box) hint:SetShown(box:GetText() == "") end)
        input:SetScript("OnEscapePressed", function(box) box:SetText(""); box:ClearFocus() end)
        input:SetScript("OnEnterPressed", function(box)
            local text = box:GetText()
            box:SetText("")
            box:ClearFocus()
            if text:match("%S") then SH:Command(text) end
        end)
        input:SetScript("OnEditFocusLost", function() SH.forceShow = nil; SH:UpdateShown() end)
        SH.input = input
        T.Movers.ApplyPoint(f, SH.db)
        T.Movers:Register(f, {
            label = "Shopping list", page = "shopping",
            cfg = function() return SH.db end,
            corner = function() return SH.db.point[1] end,
            enabled = function() return SH.db.enabled end,
        })
        HookLinks()
        HookTooltip()
        local ev = CreateFrame("Frame")
        for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "BANKFRAME_OPENED",
            "PLAYERBANKSLOTS_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do
            pcall(ev.RegisterEvent, ev, event)
        end
        ev:SetScript("OnEvent", T:Wrap("shopping.events", function(_, event)
            if event == "GET_ITEM_INFO_RECEIVED" then
                if SH.pendingNames then return end
                SH.pendingNames = true
                C_Timer.After(0.5, function() SH.pendingNames = nil; SH:Recount() end)
            else
                SH:Recount()
            end
        end))
        for _, entry in ipairs(SH.db.items) do entry.done = SH:Have(entry.id) >= entry.need end
        SH:Refresh()
    end,
    OnSettings = function()
        SH.db = T.db.shopping
        if SH.frame then
            T.Movers.ApplyPoint(SH.frame, SH.db)
            SH:Refresh()
        end
    end,
})
