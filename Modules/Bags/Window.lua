-- Tempus UI: carried-bag and personal-bank windows driven by inventory projections.
-- Everything drawn on an item button lives in tempus* regions. Never write fields Blizzard's click
-- handlers read (count, bagID, ...) or call the template's Update: that taints right-click use.
local _, T = ...
local Bags = T.Bags
local S, UI = T.Style, T.UI

local Window = {}
Window.__index = Window
Bags.Window = Window

local PAD, HEADER_H, GAP, FOOTER_H = 8, 24, 6, 30
local SLOT_BAR_W = 110
local BORDER_DEFAULT = { 0.12, 0.13, 0.16, 1 }
local BORDER_COMMON = { 0.38, 0.41, 0.48, 1 }
local GEAR_CLASSES = { [2] = true, [4] = true }

local function Label(parent, text, size, color)
    local fs = S.Text(parent, size or 11, color)
    fs:SetText(text)
    return fs
end

local function SmallButton(parent, text, width, click)
    return UI.FlatButton(parent, text, width, 22, click)
end

local function IconRegion(button)
    return button.icon or button.Icon or button.IconTexture
end

function Window.FormatMoney(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then
        local text = BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or tostring(gold)
        parts[#parts + 1] = ("|cffffd24d%s|rg"):format(text)
    end
    if gold > 0 or silver > 0 then parts[#parts + 1] = ("|cffc8ccd4%d|rs"):format(silver) end
    parts[#parts + 1] = ("|cffc87f4a%d|rc"):format(rest)
    return table.concat(parts, " ")
end

function Window.New(owner, storage, title, pointKey)
    local self = setmetatable({ owner = owner, storage = storage, pointKey = pointKey,
        buttons = {}, proxies = {}, headers = {}, chips = {} }, Window)
    local frame = CreateFrame("Frame", "Tempus" .. title:gsub("%s", "") .. "Frame", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetSize(480, 360)
    S.Backdrop(frame)
    self.frame = frame

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", PAD, -7)
    header:SetPoint("TOPRIGHT", -PAD, -7)
    header:SetHeight(HEADER_H)
    self.title = Label(header, title, 14, T.accent)
    self.title:SetPoint("LEFT", 2, 0)

    self.close = SmallButton(header, "x", 24, function() owner:Close(storage) end)
    self.close:SetPoint("RIGHT")
    self.mode = SmallButton(header, "Grid", 72, function() owner:ToggleView() end)
    self.mode:SetPoint("RIGHT", self.close, "LEFT", -4, 0)
    self.sort = SmallButton(header, "Sort", 46, function() owner:Sort(storage) end)
    self.sort:SetPoint("RIGHT", self.mode, "LEFT", -4, 0)
    self.tag = SmallButton(header, "Tag", 40, function() owner:ToggleTagMode() end)
    self.tag:SetPoint("RIGHT", self.sort, "LEFT", -4, 0)

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local cfg = { point = owner.db[pointKey] }
        T.Movers.SavePoint(frame, cfg, pointKey == "point" and "BOTTOMRIGHT" or "BOTTOMLEFT")
        owner.db[pointKey] = cfg.point
    end)

    self.search = UI.StyledEditBox(frame, 220, 24)
    self.search:SetScript("OnTextChanged", function(box)
        self.searchHint:SetShown(box:GetText() == "")
        owner:SetQuery(storage, box:GetText())
    end)
    self.search:SetScript("OnEscapePressed", function(box)
        if box:GetText() ~= "" then box:SetText("") else box:ClearFocus(); owner:Close(storage) end
    end)
    self.searchHint = Label(self.search, "Search items, types or IDs", 11, S.C.muted)
    self.searchHint:SetPoint("LEFT", 9, 0)

    -- Filter chips.
    self.chipRow = CreateFrame("Frame", nil, frame)
    self.chipRow:SetHeight(20)
    local x = 0
    for _, filter in ipairs(Bags.Inventory.filters) do
        local chip = UI.FlatButton(self.chipRow, filter.label, 62, 20, function() owner:SetFilter(storage, filter.key) end)
        chip:SetPoint("LEFT", self.chipRow, "LEFT", x, 0)
        chip.key = filter.key
        self.chips[#self.chips + 1] = chip
        x = x + 66
    end

    if storage == "BANK" then
        self.bankRow = CreateFrame("Frame", nil, frame)
        self.bankRow:SetHeight(22)
        self.personalTab = SmallButton(self.bankRow, "Personal", 72, function() owner:SetBankStorage("BANK") end)
        self.personalTab:SetPoint("RIGHT")
        self.reagentTab = SmallButton(self.bankRow, "Reagents", 72, function() owner:SetBankStorage("REAGENT") end)
        self.reagentTab:SetPoint("RIGHT", self.personalTab, "LEFT", -4, 0)
        self.manage = SmallButton(self.bankRow, "Manage", 64, function() owner:ShowBankManagement() end)
        self.manage:SetPoint("RIGHT", self.reagentTab, "LEFT", -4, 0)
    else
        self.bagBar = Bags.BagBar.New(self)
    end

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(s, delta)
        local max = math.max(0, content:GetHeight() - s:GetHeight())
        s:SetVerticalScroll(math.max(0, math.min(max, s:GetVerticalScroll() - delta * 45)))
    end)
    self.scroll, self.content = scroll, content
    self.empty = Label(content, "No matching items", 13, S.C.muted)
    self.empty:SetPoint("TOP", 0, -30)
    self.empty:Hide()

    -- Footer: slot meter on the left, currencies and money on the right.
    self.slotBg = S.Tex(frame, "ARTWORK", { 1, 1, 1, 0.08 })
    self.slotBg:SetSize(SLOT_BAR_W, 5)
    self.slotBg:SetPoint("BOTTOMLEFT", 10, 14)
    self.slotFill = S.Tex(frame, "OVERLAY", T.accent)
    self.slotFill:SetHeight(5)
    self.slotFill:SetPoint("LEFT", self.slotBg, "LEFT")
    self.footer = Label(frame, "", 11, S.C.muted)
    self.footer:SetPoint("LEFT", self.slotBg, "RIGHT", 8, 0)
    self.wealth = Label(frame, "", 11)
    self.wealth:SetJustifyH("RIGHT")
    self.wealth:SetPoint("BOTTOMRIGHT", -10, 9)

    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame:Hide()
    return self
end

function Window:Proxy(container)
    if not self.proxies[container] then
        local proxy = self.owner.client:CreateProxy(self.content, container)
        proxy:SetAllPoints(self.content)
        self.proxies[container] = proxy
    end
    return self.proxies[container]
end

-- Blizzard decorations on the template that we replace with our own border and marks.
local STOCK_DECOR = { "IconBorder", "IconOverlay", "IconOverlay2", "NewItemTexture", "BattlepayItemTexture",
    "JunkIcon", "UpgradeIcon", "flash", "ExtendedSlot" }

function Window:Button(record)
    local button = self.buttons[record.key]
    if button then return button end
    local owner = self.owner
    button = owner.client:CreateItemButton(self:Proxy(record.location.container))
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
    for _, key in ipairs(STOCK_DECOR) do
        local decor = button[key]
        if decor and decor.Hide then decor:Hide() end
    end

    button.tempusBg = S.Tex(button, "BACKGROUND", S.C.card, -8)
    button.tempusBg:SetAllPoints()
    button.tempusBorder = S.CreateBorder(button, "OVERLAY", 3)
    button.tempusBorder:SetThickness(1, button)
    button.tempusNew = S.Tex(button, "OVERLAY", { T.accent[1], T.accent[2], T.accent[3], 1 }, 4)
    button.tempusNew:SetHeight(2)
    button.tempusNew:SetPoint("BOTTOMLEFT", 1, 1)
    button.tempusNew:SetPoint("BOTTOMRIGHT", -1, 1)
    button.tempusMark = Label(button, "", 10)
    button.tempusMark:SetPoint("TOPRIGHT", -2, -2)
    button.tempusUp = button:CreateTexture(nil, "OVERLAY", nil, 5)
    button.tempusUp:SetSize(10, 10)
    button.tempusUp:SetPoint("TOPRIGHT", -1, -1)
    local atlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("bags-greenarrow")
    if atlas then button.tempusUp:SetAtlas("bags-greenarrow") else button.tempusUp:SetColorTexture(0.3, 0.9, 0.4, 1) end
    button.tempusLevel = Label(button, "", 10)
    button.tempusLevel:SetPoint("BOTTOMLEFT", 2, 2)
    button.tempusBoE = Label(button, "", 8, { 0.35, 0.9, 0.5 })
    button.tempusBoE:SetPoint("TOPLEFT", 2, -2)

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    button.tempusCooldown = cooldown

    -- Category tagging overlay: ours, so the secure item click never runs while tagging.
    local tag = CreateFrame("Button", nil, button)
    tag:SetAllPoints()
    tag:SetFrameLevel(button:GetFrameLevel() + 10)
    tag:Hide()
    tag:SetScript("OnEnter", function(t)
        if t.record then owner.client:ShowTooltip(t, t.record) end
    end)
    tag:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tag:SetScript("OnClick", function(t) if t.record then owner:ShowCategoryMenu(t, t.record) end end)
    button.tempusTag = tag

    button:HookScript("OnEnter", function(b)
        local accent = T.accent
        b.tempusBorder:SetColor(accent[1], accent[2], accent[3], 1)
    end)
    button:HookScript("OnLeave", function(b)
        local c = b.tempusBorderColor or BORDER_DEFAULT
        b.tempusBorder:SetColor(c[1], c[2], c[3], c[4] or 1)
    end)

    self.buttons[record.key] = button
    return button
end

local function SectionHeader(self, index)
    local header = self.headers[index]
    if header then return header end
    header = CreateFrame("Button", nil, self.content)
    header:SetHeight(20)
    header.chevron = Label(header, "-", 12, T.accent)
    header.chevron:SetPoint("LEFT", 2, 0)
    header.label = Label(header, "", 11)
    header.label:SetPoint("LEFT", 16, 0)
    header.line = S.Tex(header, "ARTWORK", { 1, 1, 1, 0.08 })
    header.line:SetHeight(1)
    header.line:SetPoint("LEFT", header.label, "RIGHT", 8, 0)
    header.line:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    header:SetScript("OnClick", function(h) self.owner:ToggleSection(h.sectionKey) end)
    header:SetScript("OnEnter", function(h) h.label:SetTextColor(T.accent[1], T.accent[2], T.accent[3]) end)
    header:SetScript("OnLeave", function(h) h.label:SetTextColor(S.C.text[1], S.C.text[2], S.C.text[3]) end)
    self.headers[index] = header
    return header
end

function Window:IsUpgrade(record)
    if not (record.itemLevel and GEAR_CLASSES[record.classID or 0]) then return false end
    local loc = record.equipLoc
    if not loc or loc == "" then return false end
    local cache = self.equipped
    if cache[loc] == nil then
        -- false means "no comparison available"; a plain `x and false or y` would turn that back into nil.
        cache[loc] = self.owner.client:EquippedLevel(loc) or false
    end
    local worn = cache[loc]
    return worn ~= false and record.itemLevel > worn
end

function Window:UpdateCooldown(button, record)
    local cooldown = button.tempusCooldown
    local start, duration
    if self.owner.db.showCooldowns and not record.empty then
        start, duration = self.owner.client:Cooldown(record.location)
    end
    if start then
        if not pcall(cooldown.SetCooldown, cooldown, start, duration) then cooldown:Clear() end
    else
        cooldown:Clear()
    end
end

function Window:UpdateCooldowns()
    if not self.frame:IsShown() then return end
    for _, button in pairs(self.buttons) do
        if button:IsShown() and button.tempusRecord then self:UpdateCooldown(button, button.tempusRecord) end
    end
end

-- Dim every item outside the hovered bag.
function Window:ApplyHighlight()
    local hover = self.owner.hoverBag
    for _, button in pairs(self.buttons) do
        local base = button.tempusAlpha or 1
        if hover ~= nil and self.storage == "CARRIED" and button.tempusContainer ~= hover then base = base * 0.25 end
        button:SetAlpha(base)
    end
end

function Window:StyleButton(button, record, size)
    local owner, db = self.owner, self.owner.db
    button:SetSize(size, size)
    owner.client:BindItemButton(button, record)
    button.tempusRecord, button.tempusContainer = record, record.location.container
    button.tempusTag.record = record

    local icon = IconRegion(button)
    if icon then
        icon:SetTexture(record.icon)
        local r, g, b = 1, 1, 1
        if record.maxDurability and record.maxDurability > 0 and record.durability then
            if record.durability <= 0 then r, g, b = 1, 0.25, 0.25
            elseif record.durability / record.maxDurability < 0.25 then r, g, b = 1, 0.75, 0.3 end
        end
        icon:SetVertexColor(r, g, b)
    end

    -- Stack count: our own text. SetItemButtonCount would write button.count, which Blizzard reads.
    local countText = button.Count or button.count_text
    if countText and countText.SetText then
        local count = record.count or 0
        countText:SetText(count > 1 and (count >= 1000 and "*" or count) or "")
        countText:SetShown(count > 1)
    end

    local color = BORDER_DEFAULT
    if record.itemID and record.quality then
        local quality = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[record.quality]
        if record.quality >= 2 and quality then color = { quality.r, quality.g, quality.b, 1 }
        elseif record.quality == 1 then color = BORDER_COMMON end
    end
    button.tempusBorderColor = color
    button.tempusBorder:SetColor(color[1], color[2], color[3], color[4])
    button.tempusBg:SetVertexColor(S.C.card[1], S.C.card[2], S.C.card[3], record.empty and 0.55 or 1)

    local gear = GEAR_CLASSES[record.classID or 0] and record.equipLoc and record.equipLoc ~= ""
    local upgrade = db.showUpgrades and gear and self:IsUpgrade(record)
    button.tempusNew:SetShown(db.showNew and record.isNew)
    button.tempusUp:SetShown(upgrade and true or false)
    local mark = record.quest and "!" or (record.quality == 0 and not record.hasNoValue and "$" or "")
    button.tempusMark:SetText(upgrade and "" or mark)

    local levelText = ""
    if db.showItemLevel and gear and record.itemLevel then levelText = tostring(record.itemLevel) end
    button.tempusLevel:SetText(levelText)
    if upgrade then button.tempusLevel:SetTextColor(0.4, 0.95, 0.5)
    else button.tempusLevel:SetTextColor(color[1] > 0.5 and color[1] or 0.9, color[2] > 0.5 and color[2] or 0.92,
        color[3] > 0.5 and color[3] or 0.95) end
    local boe = db.showItemLevel and gear and record.bindType == 2 and not record.bound
    button.tempusBoE:SetText(boe and "BoE" or "")

    self:UpdateCooldown(button, record)
    button.tempusAlpha = record.locked and 0.45 or 1
    button.tempusTag:SetShown(owner.tagMode and not record.empty)
    button:Show()
end

function Window:Layout()
    local db = self.owner.db
    local y = PAD + HEADER_H + GAP
    self.search:ClearAllPoints()
    self.search:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -y)
    self.search:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PAD, -y)
    y = y + 24 + GAP
    local function Place(frame, height, shown)
        frame:SetShown(shown)
        if not shown then return end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -y)
        y = y + height + GAP
    end
    Place(self.chipRow, 20, db.showFilters)
    if self.bankRow then Place(self.bankRow, 22, true) end
    if self.bagBar then
        Place(self.bagBar.frame, 24, db.showBagBar)
        if db.showBagBar then self.bagBar:Refresh() end
    end
    self.scroll:ClearAllPoints()
    self.scroll:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD, -y)
    self.scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -PAD, FOOTER_H)
    self.chrome = y + FOOTER_H
end

function Window:UpdateFooter(snapshot)
    snapshot = snapshot or self.lastSnapshot
    if not snapshot then return end
    local capacity = math.max(1, snapshot.capacity)
    local ratio = math.min(1, snapshot.used / capacity)
    self.slotFill:SetWidth(math.max(1, SLOT_BAR_W * ratio))
    if ratio >= 0.9 then self.slotFill:SetVertexColor(0.95, 0.35, 0.3)
    else self.slotFill:SetVertexColor(T.accent[1], T.accent[2], T.accent[3]) end
    self.footer:SetText(("%d / %d  (%d free)"):format(snapshot.used, snapshot.capacity, snapshot.capacity - snapshot.used))

    local parts = {}
    if self.owner.db.showCurrencies and self.storage == "CARRIED" then
        for _, currency in ipairs(self.owner.client:Currencies()) do
            local icon = currency.icon and ("|T%s:12:12:0:0|t "):format(tostring(currency.icon)) or ""
            parts[#parts + 1] = icon .. currency.quantity
        end
    end
    parts[#parts + 1] = Window.FormatMoney(self.owner.client:Money())
    self.wealth:SetText(table.concat(parts, "   "))
end

function Window:Render(snapshot, projection)
    local owner, db, content = self.owner, self.owner.db, self.content
    self.lastSnapshot, self.equipped = snapshot, {}
    self:Layout()
    local size, gap, columns = db.itemSize, db.spacing, db.columns
    local width = math.max(360, columns * (size + gap) - gap + PAD * 2)
    local inner = width - PAD * 2
    self.chipRow:SetWidth(inner)
    if self.bankRow then self.bankRow:SetWidth(inner) end
    for _, button in pairs(self.buttons) do button:Hide(); button:ClearAllPoints() end
    for _, header in ipairs(self.headers) do header:Hide(); header:ClearAllPoints() end

    local y, headerIndex = 0, 0
    for _, section in ipairs(projection.sections) do
        if section.label then
            headerIndex = headerIndex + 1
            local header = SectionHeader(self, headerIndex)
            header.sectionKey = section.key
            header.label:SetText(("%s |cff8c97ad(%d)|r"):format(section.label, section.count or #section.keys))
            header.chevron:SetText(section.collapsed and "+" or "-")
            header:SetWidth(inner)
            header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            header:Show()
            y = y + 22
        end
        for index, key in ipairs(section.keys) do
            local record = snapshot.byKey[key]
            local button = self:Button(record)
            local col, row = (index - 1) % columns, math.floor((index - 1) / columns)
            button:SetPoint("TOPLEFT", content, "TOPLEFT", col * (size + gap), -(y + row * (size + gap)))
            self:StyleButton(button, record, size)
        end
        y = y + math.ceil(#section.keys / columns) * (size + gap)
        if section.label then y = y + 6 end
    end
    y = math.max(y, 70)
    content:SetSize(inner, y)
    local screenHeight = UIParent:GetHeight() or 768
    self.frame:SetSize(width, math.min(y + self.chrome, screenHeight - 70))

    self.mode.text:SetText(db.mode == "GRID" and "Grid" or "Sections")
    self.tag:SetActive(owner.tagMode and true or false)
    self.empty:SetShown(projection.emptyResult)
    local active = owner.filter[self.storage] or "ALL"
    for _, chip in ipairs(self.chips) do chip:SetActive(chip.key == active) end
    self:UpdateFooter(snapshot)
    self:ApplyHighlight()
    if self.personalTab then
        self.personalTab:SetActive(owner.bankStorage == "BANK")
        self.reagentTab:SetActive(owner.bankStorage == "REAGENT")
        self.reagentTab:SetShown(owner.client:IsReagentAvailable())
    end
end

function Window:ApplyPoint()
    local point = self.owner.db[self.pointKey]
    if point then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(point[1], UIParent, point[3], point[4], point[5])
    end
end
