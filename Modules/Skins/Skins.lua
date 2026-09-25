-- Tempus UI: re-theme Blizzard windows in the Tempus look. A small toolkit strips the
-- stock art (by alpha, so nothing is destroyed) and lays Tempus panels underneath.
-- Every skin runs in pcall: a window that changed shape just stays stock.
local _, T = ...
local S = T.Style
local C = S.C

local SK = { skinned = {} }
T.Skins = SK

SK.defaults = {
    windows = true,
    tooltips = true, tooltipCursor = false, tooltipHealth = true,
    chat = true, chatAlpha = 0.55,
    bagnon = true, dbm = true,
    parchment = true,           -- keep parchment on reading surfaces (quests, gossip, books, mail)
    trackerPanel = true, trackerAlpha = 0.45,
}

----------------------------------------------------------------------------------------
-- Toolkit
----------------------------------------------------------------------------------------
local function IsTex(r) return r and r.GetObjectType and r:GetObjectType() == "Texture" end

-- Reading surfaces whose parchment is kept when the "parchment" option is on.
SK.readingWindows = { GossipFrame = true, QuestFrame = true, ItemTextFrame = true, OpenMailFrame = true,
    QuestLogDetailFrame = true, SendMailFrame = true }
local PARCHMENT = { "parchment", "questbg", "quest%-bg", "questdetail", "questbackground", "bookbg", "book%-bg",
    "ui%-book", "itemtext", "stationery", "paper", "letter", "questlog%-page", "questlog%-details" }

local function IsParchment(r)
    local name = r.GetAtlas and r:GetAtlas()
    if not name or name == "" then name = r.GetTexture and r:GetTexture() end
    if type(name) ~= "string" then return false end
    name = name:lower()
    for _, pat in ipairs(PARCHMENT) do
        if name:find(pat) then return true end
    end
    return false
end
SK.IsParchment = IsParchment

-- A kept parchment page gets a crisp dark edge so it sits in the Tempus frame like an inset.
local function EdgeParchment(r)
    if r.tempusEdge or not r.GetParent then return end
    local parent = r:GetParent()
    if not parent or not parent.CreateTexture then return end
    r.tempusEdge = S.CreateBorder(parent, "ARTWORK", 7)
    r.tempusEdge:SetThickness(1, r)
    r.tempusEdge:SetColor(0, 0, 0, 0.9)
end

-- Hide every texture region of a frame except Tempus's own and those listed in keep.
-- Inside reading windows, parchment survives when the option is on.
function SK:Strip(frame, keep)
    if not frame or not frame.GetRegions or (frame.IsForbidden and frame:IsForbidden()) then return end
    local keepParchment = SK.db and SK.db.parchment and SK.inReading
    for _, r in ipairs({ frame:GetRegions() }) do
        if IsTex(r) and not r.tempus and not (keep and keep[r]) then
            if keepParchment and IsParchment(r) then
                SK.foundParchment = true
                EdgeParchment(r)
            else
                r:SetAlpha(0)
                r.tempusStripped = true
                -- Reading windows assign their parchment when first shown; remember what
                -- was hidden so it can be re-checked then.
                if keepParchment then
                    SK.readingStripped = SK.readingStripped or {}
                    SK.readingStripped[r] = SK.inReadingName
                end
            end
        end
    end
end

local function HideKey(frame, key)
    local r = frame and frame[key]
    if type(r) == "table" and r.SetAlpha then r:SetAlpha(0) end
end

function SK:Panel(frame, fill)
    if frame.tempusSkinPanel then return frame.tempusSkinPanel end
    frame.tempusSkinPanel = S.Backdrop(frame, { fill = fill or C.bg })
    return frame.tempusSkinPanel
end

function SK:Button(b)
    if not b or b.tempusSkinned then return end
    b.tempusSkinned = true
    SK:Strip(b)
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftSeparator", "RightSeparator" }) do HideKey(b, key) end
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    local hl = b.GetHighlightTexture and b:GetHighlightTexture()
    if hl then
        hl:SetTexture(S.WHITE)
        hl:SetVertexColor(1, 1, 1, 0.08)
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", 1, -1)
        hl:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    local bd = S.Backdrop(b, { fill = C.card, shadow = false })
    b:HookScript("OnEnter", function() bd:SetEdgeColor(T.accent[1], T.accent[2], T.accent[3]) end)
    b:HookScript("OnLeave", function() bd:SetEdgeColor(0, 0, 0) end)
end

function SK:Close(b)
    if not b or b.tempusSkinned then return end
    b.tempusSkinned = true
    SK:Strip(b)
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    local x = b:CreateFontString(nil, "OVERLAY")
    x:SetFont(S.FONT, 14, "OUTLINE")
    x:SetPoint("CENTER", 0, 1)
    x:SetText("x")
    x:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    b:HookScript("OnEnter", function() x:SetTextColor(1, 0.4, 0.4) end)
    b:HookScript("OnLeave", function() x:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
end

function SK:Tab(tab)
    if not tab or tab.tempusSkinned then return end
    tab.tempusSkinned = true
    -- Icon tabs (e.g. the paper-doll sidebar) keep their icon; text tabs lose everything.
    local icon = type(tab.Icon) == "table" and tab.Icon or nil
    SK:Strip(tab, icon and { [icon] = true })
    if icon then
        HideKey(tab, "Hider")
        HideKey(tab, "TabBg")
        HideKey(tab, "Highlight")
        icon:SetAlpha(1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:ClearAllPoints()
        local w, h = tab:GetSize()
        if w > 0 and h > 0 and math.abs(w - h) > 2 then
            -- Wide tab-system tabs (spellbook categories): keep the icon square and centred.
            local size = math.min(w, h) - 6
            icon:SetSize(size, size)
            icon:SetPoint("CENTER")
        else
            icon:SetPoint("TOPLEFT", 3, -3)
            icon:SetPoint("BOTTOMRIGHT", -3, 3)
        end
        local panel = CreateFrame("Frame", nil, tab)
        panel:SetAllPoints(icon)
        panel:SetFrameLevel(math.max(tab:GetFrameLevel() - 1, 0))
        local bd = S.Backdrop(panel, { fill = { 0.03, 0.035, 0.045, 1 }, shadow = false })
        -- Tab-system tabs mark the selected tab with SquareBackgroundActive; show it as an accent edge.
        local sel = tab.SquareBackgroundActive
        if type(sel) == "table" then
            local function State()
                local on = sel:IsShown()
                bd:SetEdgeColor(on and T.accent[1] or 0, on and T.accent[2] or 0, on and T.accent[3] or 0)
            end
            hooksecurefunc(sel, "Show", State)
            hooksecurefunc(sel, "Hide", State)
            hooksecurefunc(sel, "SetShown", State)
            State()
        end
        return
    end
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
        "LeftHighlight", "MiddleHighlight", "RightHighlight", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
        HideKey(tab, key)
    end
    local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
    if hl then hl:SetAlpha(0) end
    local panel = CreateFrame("Frame", nil, tab)
    panel:SetPoint("TOPLEFT", 6, -4)
    panel:SetPoint("BOTTOMRIGHT", -6, 4)
    panel:SetFrameLevel(math.max(tab:GetFrameLevel() - 1, 0))
    S.Backdrop(panel, { fill = C.card, shadow = false })
end

function SK:EditBox(e)
    if not e or e.tempusSkinned then return end
    e.tempusSkinned = true
    local name = e.GetName and e:GetName()
    for _, key in ipairs({ "Left", "Middle", "Mid", "Right" }) do
        HideKey(e, key)
        local g = name and _G[name .. key]
        if g and g.SetAlpha then g:SetAlpha(0) end
    end
    local panel = CreateFrame("Frame", nil, e)
    panel:SetPoint("TOPLEFT", -4, 0)
    panel:SetPoint("BOTTOMRIGHT", 0, 0)
    panel:SetFrameLevel(math.max(e:GetFrameLevel() - 1, 0))
    S.Backdrop(panel, { fill = { 0.03, 0.035, 0.045, 1 }, shadow = false })
end

function SK:Inset(f)
    if not f or f.tempusSkinned then return end
    f.tempusSkinned = true
    SK:Strip(f)
    HideKey(f, "NineSlice")
    HideKey(f, "Bg")
    S.Backdrop(f, { fill = { 0.035, 0.04, 0.052, 0.6 }, shadow = false })
end

-- Equipment and bag slots: square Tempus border that takes the item-quality colour.
function SK:ItemSlot(slot)
    if not slot or slot.tempusSkinned then return end
    slot.tempusSkinned = true
    local icon = slot.icon
    if type(icon) ~= "table" then icon = slot:GetName() and _G[slot:GetName() .. "IconTexture"] end
    SK:Strip(slot, icon and { [icon] = true })
    local nt = slot.GetNormalTexture and slot:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    if icon then
        icon:SetAlpha(1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:ClearAllPoints()
        icon:SetAllPoints(slot)
    end
    local bd = S.Backdrop(slot, { fill = { 0.03, 0.035, 0.045, 1 } })
    local border = slot.IconBorder
    if type(border) == "table" then
        border:SetAlpha(0)
        hooksecurefunc(border, "SetVertexColor", function(_, r, g, b) bd:SetEdgeColor(r, g, b) end)
        hooksecurefunc(border, "Hide", function() bd:SetEdgeColor(0, 0, 0) end)
    end
end

-- Modern scroll bars: a Track with a Thumb, and Back/Forward arrow buttons.
local function GreyArrow(b)
    if type(b) ~= "table" or not b.GetRegions then return end
    for _, r in ipairs({ b:GetRegions() }) do
        if IsTex(r) and not r.tempus then
            r:SetDesaturated(true)
            r:SetVertexColor(0.65, 0.68, 0.74)
        end
    end
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetDesaturated(true); t:SetVertexColor(0.65, 0.68, 0.74) end
    end
end

function SK:ScrollBar(bar)
    if not bar or bar.tempusSkinned then return end
    bar.tempusSkinned = true
    SK:Strip(bar)
    GreyArrow(bar.Back)
    GreyArrow(bar.Forward)
    local track = bar.Track
    if type(track) == "table" then
        SK:Strip(track)
        local panel = CreateFrame("Frame", nil, track)
        panel:SetPoint("TOPLEFT", 3, 0)
        panel:SetPoint("BOTTOMRIGHT", -3, 0)
        panel:SetFrameLevel(math.max(track:GetFrameLevel() - 1, 0))
        S.Backdrop(panel, { fill = { 0.03, 0.035, 0.045, 0.8 }, shadow = false, inner = false })
        local thumb = track.Thumb
        if type(thumb) == "table" then
            SK:Strip(thumb)
            for _, key in ipairs({ "Begin", "Middle", "End", "Main" }) do HideKey(thumb, key) end
            local fill = S.Tex(thumb, "ARTWORK", { 0.4, 0.44, 0.52, 0.9 })
            fill.tempus = true
            fill:SetPoint("TOPLEFT", 4, -1)
            fill:SetPoint("BOTTOMRIGHT", -4, 1)
            thumb:HookScript("OnEnter", function() fill:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1) end)
            thumb:HookScript("OnLeave", function() fill:SetVertexColor(0.4, 0.44, 0.52, 0.9) end)
        end
    end
end

-- Walk a window's children and skin the common widgets found in it.
function SK:Walk(frame, depth)
    depth = depth or 0
    if depth > 4 or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        -- Forbidden objects (secure trade, store...) must not be touched at all.
        if not (child.IsForbidden and child:IsForbidden()) and not child.tempusSkinned and not child.tempusSkinPanel
            and not child.tempusNoSkin then
            local kind = child.GetObjectType and child:GetObjectType()
            local name = child.GetName and child:GetName() or ""
            local function has(key) return type(child[key]) == "table" end
            if has("Track") and (has("Back") or has("Forward")) then
                SK:ScrollBar(child)
            -- Tabs before buttons: tab-system tabs also carry Left/Middle/Right and a font string.
            elseif (kind == "Button" or kind == "CheckButton") and (name:find("Tab%d+$") or has("LeftActive")) then
                SK:Tab(child)
            elseif kind == "Button" and has("Left") and has("Right") and (has("Middle") or has("Center")) and child.GetFontString then
                SK:Button(child)
            elseif kind == "EditBox" and (has("Left") or (name ~= "" and _G[name .. "Left"])) then
                SK:EditBox(child)
            elseif kind == "Button" and (name:find("CloseButton$") or frame.CloseButton == child) then
                SK:Close(child)
            elseif kind == "Frame" and has("NineSlice") and (name:find("Inset") or frame.Inset == child) then
                SK:Inset(child)
                SK:Walk(child, depth + 1)
            elseif kind == "Frame" or kind == "ScrollFrame" then
                SK:Walk(child, depth + 1)
            end
        end
    end
end

-- A whole window: strip its frame art, lay a Tempus panel under it, skin its widgets.
-- Reading windows (quests, gossip, books, mail) keep their parchment when the option is on;
-- SK.inReading is set only for the duration of that window's skinning pass.
function SK:Window(frame)
    if not frame or SK.skinned[frame] or (frame.IsForbidden and frame:IsForbidden()) then return end
    SK.skinned[frame] = true
    local name = frame.GetName and frame:GetName()
    local reading = name and SK.readingWindows[name] or nil
    SK.parchmentWindows = SK.parchmentWindows or {}
    local function Pass(fn)
        SK.inReading = reading
        SK.inReadingName = reading and name or nil
        SK.foundParchment = SK.parchmentWindows[name]
        local ok, err = pcall(fn)
        if reading then SK.parchmentWindows[name] = SK.foundParchment end
        SK.inReading, SK.inReadingName = nil, nil
        if not ok then error(err, 0) end
    end
    Pass(function()
        SK:Strip(frame)
        for _, key in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "portrait", "Background" }) do
            local r = frame[key]
            if not (reading and SK.db.parchment and type(r) == "table" and r.GetObjectType
                and r:GetObjectType() == "Texture" and IsParchment(r)) then
                HideKey(frame, key)
            end
        end
        if type(frame.Border) == "table" and frame.Border.GetObjectType then frame.Border:SetAlpha(0) end
        if type(frame.TitleContainer) == "table" then SK:Strip(frame.TitleContainer) end
        if type(frame.Header) == "table" then SK:Strip(frame.Header) end
        SK:Panel(frame)
        if type(frame.Inset) == "table" then SK:Inset(frame.Inset) end
        if type(frame.CloseButton) == "table" then SK:Close(frame.CloseButton) end
        SK:Walk(frame)
    end)
    -- Some widgets are created the first time the window opens.
    frame:HookScript("OnShow", function(self)
        SK.inReading, SK.inReadingName = reading, reading and name or nil
        SK.foundParchment = SK.parchmentWindows[name]
        pcall(SK.Walk, SK, self)
        if reading then SK.parchmentWindows[name] = SK.foundParchment end
        SK.inReading, SK.inReadingName = nil, nil
        if reading then
            SK:RestoreParchment(name)
            C_Timer.After(0, function() SK:RestoreParchment(name) end)
        end
    end)
end

-- Bring back hidden textures of a reading window that have since become parchment.
function SK:RestoreParchment(name)
    if not (SK.db.parchment and SK.readingStripped) then return end
    for r, owner in pairs(SK.readingStripped) do
        if owner == name and IsParchment(r) then
            r:SetAlpha(1)
            EdgeParchment(r)
            r.tempusStripped = nil
            SK.readingStripped[r] = nil
            SK.parchmentWindows[name] = true
        end
    end
end

----------------------------------------------------------------------------------------
-- Blizzard windows. Names from the Tempus probe of this client; load-on-demand windows
-- are picked up when their addon loads.
----------------------------------------------------------------------------------------
SK.windows = {
    "CharacterFrame", "WorldMapFrame", "FriendsFrame", "MerchantFrame", "MailFrame", "OpenMailFrame", "BankFrame", "LootFrame",
    "GameMenuFrame", "AddonList", "QuestFrame", "GossipFrame", "TradeFrame", "TaxiFrame", "DressUpFrame",
    "LFGParentFrame", "PVEFrame", "HelpFrame", "ItemTextFrame", "PetStableFrame", "TabardFrame", "GuildRegistrarFrame",
    "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
    -- load on demand
    "PlayerSpellsFrame", "SpellBookFrame", "PlayerTalentFrame", "TalentFrame", "ClassTalentFrame",
    "AuctionFrame", "AuctionHouseFrame", "TradeSkillFrame", "ProfessionsFrame", "CraftFrame", "MacroFrame",
    "InspectFrame", "ClassTrainerFrame", "CalendarFrame", "TimeManagerFrame", "CollectionsJournal",
    "CommunitiesFrame", "GuildFrame", "KeyBindingFrame", "EncounterJournal", "AchievementFrame",
}

local EQUIP_SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
    "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" }

-- Flat section header: hide the ornate background, add a fade and an accent underline.
local function FlatHeader(frame, bg)
    if frame.tempusHeader then return end
    frame.tempusHeader = true
    if bg then bg:SetAlpha(0) end
    local fade = S.Tex(frame, "BACKGROUND", { 1, 1, 1, 1 })
    fade.tempus = true
    fade:SetPoint("TOPLEFT", 2, -6)
    fade:SetPoint("BOTTOMRIGHT", -2, 6)
    S.SetGradient(fade, "HORIZONTAL", T.accent[1] * 0.25, T.accent[2] * 0.25, T.accent[3] * 0.25, 0.8, 0.05, 0.055, 0.07, 0.2)
    local line = S.Tex(frame, "ARTWORK", { T.accent[1], T.accent[2], T.accent[3], 0.7 })
    line.tempus = true
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", fade, "BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT", fade, "BOTTOMRIGHT")
end

-- Small square button: hide its stock face, keep and grey its icon, add a Tempus panel.
local function SquareButton(b, inset)
    if type(b) ~= "table" or b.tempusSkinned then return end
    b.tempusSkinned = true
    local hasIcon = type(b.Icon) == "table"
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t and t ~= b.Icon then
            if get == "GetNormalTexture" and not hasIcon then
                -- The face texture is the icon (e.g. an arrow): keep it, greyed.
                t:SetDesaturated(true)
                t:SetVertexColor(0.8, 0.83, 0.9)
            else
                t:SetAlpha(0)
            end
        end
    end
    if hasIcon then b.Icon:SetDesaturated(true); b.Icon:SetVertexColor(0.8, 0.83, 0.9) end
    local panel = CreateFrame("Frame", nil, b)
    panel:SetPoint("TOPLEFT", inset or 4, -(inset or 4))
    panel:SetPoint("BOTTOMRIGHT", -(inset or 4), inset or 4)
    panel:SetFrameLevel(math.max(b:GetFrameLevel() - 1, 0))
    local bd = S.Backdrop(panel, { fill = C.card, shadow = false })
    b:HookScript("OnEnter", function() bd:SetEdgeColor(T.accent[1], T.accent[2], T.accent[3]) end)
    b:HookScript("OnLeave", function() bd:SetEdgeColor(0, 0, 0) end)
end

-- Side tabs (character / reputation / skills ...): square icon tabs, accent edge when selected.
local function SideTab(tab)
    if type(tab) ~= "table" or tab.tempusSkinned then return end
    tab.tempusSkinned = true
    for _, key in ipairs({ "Background", "HighlightTexture" }) do HideKey(tab, key) end
    local icon = tab.Icon
    local size = 38
    local holder = CreateFrame("Frame", nil, tab)
    holder:SetSize(size, size)
    holder:SetPoint("CENTER", tab, "CENTER", -2, 0)
    holder:SetFrameLevel(math.max(tab:GetFrameLevel() - 1, 0))
    local bd = S.Backdrop(holder, { fill = { 0.03, 0.035, 0.045, 1 } })
    if type(icon) == "table" then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
        if not icon:GetTexture() or tostring(icon:GetTexture()):find("Portrait") then
            icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
        else
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end
    local sel = tab.SelectedTexture
    local function State()
        local on = type(sel) == "table" and sel:IsShown()
        bd:SetEdgeColor(on and T.accent[1] or 0, on and T.accent[2] or 0, on and T.accent[3] or 0)
    end
    if type(sel) == "table" then
        sel:SetAlpha(0)
        hooksecurefunc(sel, "Show", State)
        hooksecurefunc(sel, "Hide", State)
        hooksecurefunc(sel, "SetShown", State)
    end
    local hl = S.Tex(holder, "OVERLAY", { 1, 1, 1, 0 })
    hl.tempus = true
    hl:SetAllPoints()
    tab:HookScript("OnEnter", function() hl:SetVertexColor(1, 1, 1, 0.12) end)
    tab:HookScript("OnLeave", function() hl:SetVertexColor(1, 1, 1, 0) end)
    State()
end

-- The stats pane is a scroll box whose rows are recycled: restyle each row as it appears.
local function StyleStatRows(scrollBox)
    if not (scrollBox and scrollBox.ForEachFrame) then return end
    scrollBox:ForEachFrame(function(row)
        local bg = row.Background
        if type(bg) ~= "table" then return end
        local atlas = bg.GetAtlas and bg:GetAtlas() or ""
        if atlas:find("Title") then
            FlatHeader(row, bg)
        elseif atlas:find("Line") and not row.tempusStripe then
            row.tempusStripe = true
            bg:SetAlpha(0)
            local stripe = S.Tex(row, "BACKGROUND", { 1, 1, 1, 0.035 })
            stripe.tempus = true
            stripe:SetPoint("TOPLEFT", 4, -1)
            stripe:SetPoint("BOTTOMRIGHT", -4, 1)
        end
    end)
end

----------------------------------------------------------------------------------------
-- Live lists (reputation, skills, statistics, currency): rows are created and recycled
-- as they scroll, so a light sweep restyles whatever is new while the window is open.
----------------------------------------------------------------------------------------
local function SkinCheckBox(cb)
    if cb.tempusSkinned then return end
    cb.tempusSkinned = true
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = cb[get] and cb[get](cb)
        if t then t:SetAlpha(0) end
    end
    local panel = CreateFrame("Frame", nil, cb)
    panel:SetPoint("TOPLEFT", 4, -4)
    panel:SetPoint("BOTTOMRIGHT", -4, 4)
    panel:SetFrameLevel(math.max(cb:GetFrameLevel() - 1, 0))
    local bd = S.Backdrop(panel, { fill = { 0.03, 0.035, 0.045, 1 }, shadow = false })
    local ck = cb.GetCheckedTexture and cb:GetCheckedTexture()
    if ck then
        ck:SetTexture(S.WHITE)
        ck:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
        ck:ClearAllPoints()
        ck:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
        ck:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -3, 3)
    end
    local dck = cb.GetDisabledCheckedTexture and cb:GetDisabledCheckedTexture()
    if dck then
        dck:SetTexture(S.WHITE)
        dck:SetVertexColor(0.4, 0.42, 0.48, 1)
        dck:ClearAllPoints()
        dck:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
        dck:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -3, 3)
    end
    cb:HookScript("OnEnter", function() bd:SetEdgeColor(T.accent[1], T.accent[2], T.accent[3]) end)
    cb:HookScript("OnLeave", function() bd:SetEdgeColor(0, 0, 0) end)
end

local function SkinProgressBar(bar)
    if bar.tempusSkinned then return end
    bar.tempusSkinned = true
    local fill = bar:GetStatusBarTexture()
    for _, r in ipairs({ bar:GetRegions() }) do
        if IsTex(r) and r ~= fill and not r.tempus then r:SetAlpha(0) end
    end
    -- Borders often live on child frames of the bar - but a child StatusBar is the real
    -- fill of a nested bar (skill bars), so it is left for its own pass.
    for _, child in ipairs({ bar:GetChildren() }) do
        if child:GetObjectType() ~= "StatusBar" then
            for _, r in ipairs({ child:GetRegions() }) do
                if IsTex(r) and not r.tempus then r:SetAlpha(0) end
            end
        end
    end
    if fill then
        local r, g, b, a = bar:GetStatusBarColor()
        bar:SetStatusBarTexture(S.BarTexture(T.db.barTexture))
        if r then bar:SetStatusBarColor(r, g, b, a) end
    end
    S.Backdrop(bar, { fill = { 0.03, 0.035, 0.045, 1 }, shadow = false, inner = false })
end

local GREY = { 0.75, 0.78, 0.85 }

-- Square Tempus frame around an icon whose ornate slot art was hidden.
local function IconSlot(frame)
    local icon = type(frame.Icon) == "table" and frame.Icon
    if not icon or frame.tempusIconSlot then return end
    frame.tempusIconSlot = true
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    panel:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    panel:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    S.Backdrop(panel, { fill = { 0.03, 0.035, 0.045, 1 } })
end

-- Texture rules, by atlas name as reported by /tempus skinreport on this client.
local function SweepRegion(r, frame)
    if not IsTex(r) or r.tempus or r.tempusSeen then return end
    r.tempusSeen = true
    local atlas = (r.GetAtlas and r:GetAtlas() or ""):lower()
    if atlas == "" then return end
    local w = r:GetWidth() or 0
    if atlas:find("common%-button%-list%-collapseexpand") or (w >= 110 and (atlas:find("header") or atlas:find("category")))
        or (w >= 110 and atlas:find("ui%-character%-info%-title")) then
        FlatHeader(frame, r)
    elseif atlas:find("common%-button%-list%-minus") or atlas:find("common%-button%-list%-plus")
        or atlas:find("campaign_headericon") or (w <= 26 and (atlas:find("collapse") or atlas:find("expand"))) then
        r:SetDesaturated(true)
        r:SetVertexColor(GREY[1], GREY[2], GREY[3])
    elseif atlas:find("scrollline") or atlas:find("framedivider") or atlas:find("honor%-levelbg") then
        r:SetAlpha(0)
    elseif atlas:find("common%-stat%-bar%-bg") then
        r:SetDesaturated(true)
        r:SetVertexColor(0.45, 0.47, 0.52)
    elseif atlas:find("ui%-character%-info%-gearslot") then
        r:SetAlpha(0)
        IconSlot(frame)
    -- World map and quest log
    elseif atlas:find("gamepad%-mapquestlog") or atlas:find("questlog%-main%-background") then
        r:SetAlpha(0)
    elseif atlas:find("questlog%-frame") then
        r:SetAlpha(0)
        if not frame.tempusEdge then
            -- This border frame sits above the quest text: edge only, no fill.
            frame.tempusEdge = S.Backdrop(frame, { fill = { 0, 0, 0, 0 }, shadow = false })
        end
    elseif atlas:find("common%-search%-border") and frame:GetObjectType() ~= "EditBox" then
        r:SetAlpha(0)
        if not frame.tempusEdge then
            frame.tempusEdge = S.Backdrop(frame, { fill = { 0.03, 0.035, 0.045, 1 }, shadow = false })
        end
    elseif atlas:find("questlog%-icon%-ticksquare") then
        r:SetDesaturated(true)
        r:SetVertexColor(0.55, 0.58, 0.65)
    elseif atlas:find("questlog%-icon%-checkmark") then
        r:SetDesaturated(true)
        r:SetVertexColor(T.accent[1], T.accent[2], T.accent[3])
    end
end

-- RareScanner's world-map search box: slim Tempus field with a hint, dimmed until used.
local function IsRareScannerSearch(eb)
    return RSSearchBoxMixin and eb.Clean == RSSearchBoxMixin.Clean and eb.RefreshAll == RSSearchBoxMixin.RefreshAll
end

local function SkinRareScannerSearch(eb)
    eb.tempusSkinned = true
    SK:Strip(eb)
    local panel = CreateFrame("Frame", nil, eb)
    panel:SetPoint("TOPLEFT", -6, -6)
    panel:SetPoint("BOTTOMRIGHT", 2, 6)
    panel:SetFrameLevel(math.max(eb:GetFrameLevel() - 1, 0))
    local bd = S.Backdrop(panel, { fill = { 0.03, 0.035, 0.045, 0.92 } })
    local icon = panel:CreateTexture(nil, "OVERLAY")
    icon:SetAtlas("common-search-magnifyingglass")
    icon:SetSize(10, 10)
    icon:SetPoint("LEFT", panel, "LEFT", 6, 0)
    icon:SetVertexColor(0.6, 0.64, 0.72)
    eb:SetTextInsets(12, 4, 0, 0)
    local hint = panel:CreateFontString(nil, "OVERLAY")
    S.ApplyFont(hint, 11, nil, "NONE")
    hint:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    hint:SetTextColor(0.5, 0.54, 0.62)
    hint:SetText("Search rares, events, treasures...")
    local focused, hovered = false, false
    local function State()
        local text = eb:GetText()
        hint:SetShown(not focused and (text == nil or text == ""))
        eb:GetParent():SetAlpha((focused or hovered) and 1 or 0.6)
        if focused then bd:SetEdgeColor(T.accent[1], T.accent[2], T.accent[3]) else bd:SetEdgeColor(0, 0, 0) end
    end
    eb:HookScript("OnEditFocusGained", function() focused = true; State() end)
    eb:HookScript("OnEditFocusLost", function() focused = false; State() end)
    eb:HookScript("OnTextChanged", State)
    eb:HookScript("OnEnter", function() hovered = true; State() end)
    eb:HookScript("OnLeave", function() hovered = false; State() end)
    State()
end

-- Buttons drawn with a NineSlice (e.g. "Next Rewards at Rank 1"): flat Tempus button.
local function SkinSliceButton(b)
    if b.tempusSkinned then return end
    b.tempusSkinned = true
    b.NineSlice:SetAlpha(0)
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    local bd = S.Backdrop(b, { fill = C.card, shadow = false })
    b:HookScript("OnEnter", function() bd:SetEdgeColor(T.accent[1], T.accent[2], T.accent[3]) end)
    b:HookScript("OnLeave", function() bd:SetEdgeColor(0, 0, 0) end)
end

local function Sweep(frame, depth)
    if depth > 12 or (frame.IsForbidden and frame:IsForbidden()) or not frame:IsVisible() then return end
    for _, r in ipairs({ frame:GetRegions() }) do SweepRegion(r, frame) end
    for _, child in ipairs({ frame:GetChildren() }) do
        local kind = child.GetObjectType and child:GetObjectType()
        if kind == "StatusBar" then
            pcall(SkinProgressBar, child)
        elseif kind == "Button" and type(child.NineSlice) == "table" and child.GetFontString and child:GetFontString()
            and (child:GetWidth() or 0) > 60 and not child.tempusSkinned then
            pcall(SkinSliceButton, child)
        elseif kind == "CheckButton" and (child:GetWidth() or 99) <= 32 and not child.tempusSkinned then
            pcall(SkinCheckBox, child)
        elseif kind == "EditBox" and not child.tempusSkinned then
            if IsRareScannerSearch(child) then
                pcall(SkinRareScannerSearch, child)
            else
                -- Input boxes, including ones whose border pieces have no keys or names.
                pcall(SK.EditBox, SK, child)
                SK:Strip(child)
            end
        end
        if not child.tempusSkinPanel and not child.tempusNoSkin then Sweep(child, depth + 1) end
    end
end

-- Sweeps a window twice a second while it is open.
function SK:LiveSweep(frame)
    if not frame or frame.tempusSweeping then return end
    frame.tempusSweeping = true
    local t = 0
    local driver = CreateFrame("Frame", nil, frame)
    driver:SetScript("OnUpdate", T:Wrap("skins.livesweep", function(_, elapsed)
        t = t + elapsed
        if t < 0.5 then return end
        t = 0
        pcall(Sweep, frame, 0)
    end))
end

----------------------------------------------------------------------------------------
-- World map & quest log. The map canvas and its pins are never walked or restyled.
----------------------------------------------------------------------------------------
local function SkinWorldMap()
    local wm = WorldMapFrame
    if not wm then return end
    -- Keep every sweep and walk out of the map canvas.
    for _, key in ipairs({ "ScrollContainer", "BlackoutFrame" }) do
        if type(wm[key]) == "table" then wm[key].tempusNoSkin = true end
    end
    SK:Panel(wm)
    local bf = wm.BorderFrame
    if type(bf) == "table" then
        SK:Strip(bf)
        for _, key in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "portrait", "InsetBorderTop" }) do HideKey(bf, key) end
        if type(bf.TitleContainer) == "table" then SK:Strip(bf.TitleContainer) end
        if type(bf.CloseButton) == "table" then SK:Close(bf.CloseButton) end
        local mm = bf.MaximizeMinimizeFrame
        if type(mm) == "table" then
            SK:Strip(mm)
            for _, key in ipairs({ "MaximizeButton", "MinimizeButton" }) do
                local b = mm[key]
                if type(b) == "table" then
                    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
                        local t = b[get] and b[get](b)
                        if t then t:SetDesaturated(true); t:SetVertexColor(0.8, 0.83, 0.9) end
                    end
                end
            end
        end
    end
    -- Breadcrumb bar (World > Zone): flat strip, flat crumb buttons.
    local nav = wm.NavBar
    if type(nav) == "table" then
        SK:Strip(nav)
        for _, key in ipairs({ "overlay", "InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight" }) do HideKey(nav, key) end
        if type(nav.overlay) == "table" then SK:Strip(nav.overlay) end
        S.Backdrop(nav, { fill = { 0.035, 0.04, 0.052, 1 }, shadow = false })
    end
    -- Quest log panel.
    local q = QuestMapFrame
    if q then
        for _, key in ipairs({ "Background", "VerticalSeparator" }) do HideKey(q, key) end
        SK:Strip(q)
        -- Search box, buttons, scroll bars and tabs of the quest log side only.
        SK:Walk(q)
    end
end

-- Crumb buttons are created per zone; restyle any new ones.
local function SkinNavButtons()
    local nav = WorldMapFrame and WorldMapFrame.NavBar
    if type(nav) ~= "table" then return end
    local list = { nav.home or nav.homeButton }
    for _, b in ipairs(nav.navList or {}) do list[#list + 1] = b end
    for _, b in ipairs(list) do
        if type(b) == "table" and not b.tempusSkinned then
            b.tempusSkinned = true
            SK:Strip(b)
            for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
                local t = b[get] and b[get](b)
                if t then t:SetAlpha(0) end
            end
            local arrow = b.MenuArrowButton
            if type(arrow) == "table" then
                for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
                    local t = arrow[get] and arrow[get](arrow)
                    if t then t:SetDesaturated(true); t:SetVertexColor(0.8, 0.83, 0.9) end
                end
            end
            local bd = S.Backdrop(b, { fill = C.card, shadow = false })
            b:HookScript("OnEnter", function() bd:SetEdgeColor(T.accent[1], T.accent[2], T.accent[3]) end)
            b:HookScript("OnLeave", function() bd:SetEdgeColor(0, 0, 0) end)
        end
    end
end

local function SkinCharacterFrame()
    local cf = CharacterFrame
    for _, slot in ipairs(EQUIP_SLOTS) do
        local b = _G["Character" .. slot .. "Slot"]
        if b then
            if type(b.BorderFrame) == "table" then
                if type(b.BorderFrame.IconBorder) == "table" and not b.IconBorder then b.IconBorder = b.BorderFrame.IconBorder end
                SK:Strip(b.BorderFrame)
            end
            SK:ItemSlot(b)
        end
    end
    -- Pane art behind the model and the stats.
    for _, key in ipairs({ "LeftPaneHost", "RightPaneHost" }) do
        local host = cf[key]
        if type(host) == "table" then
            SK:Strip(host)
            HideKey(host, "StoneBg")
            for _, child in ipairs({ host:GetChildren() }) do
                if not child.GetChildren or #{ child:GetChildren() } == 0 then SK:Strip(child) end
            end
        end
    end
    local pane = _G.CharacterStatsPaneScrollBox
    if pane then
        HideKey(pane, "Border")
        HideKey(pane, "ClassBackground")
        SK:Strip(pane)
        if type(pane.ScrollBar) == "table" then SK:ScrollBar(pane.ScrollBar) end
        local box = pane.ScrollBox
        if type(box) == "table" then
            StyleStatRows(box)
            if box.Update and not box.tempusHooked then
                box.tempusHooked = true
                hooksecurefunc(box, "Update", function(self) pcall(StyleStatRows, self) end)
            end
        end
    end
    if type(cf.RightPaneToggleButton) == "table" then SquareButton(cf.RightPaneToggleButton, 4) end
    if type(cf.ModeTabs) == "table" then
        for _, tab in ipairs({ cf.ModeTabs:GetChildren() }) do pcall(SideTab, tab) end
    end
    local pd = PaperDollFrame
    if pd then
        local info = pd.PaperDollLevelInfo
        if type(info) == "table" then HideKey(info, "CharacterLevelTextBackground") end
        local scene = pd.CharacterModelScene or _G.CharacterModelScene
        if type(scene) == "table" then
            HideKey(scene, "BackgroundOverlay")
            for _, key in ipairs({ "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight" }) do
                local t = scene[key]
                if type(t) == "table" then t:SetDesaturated(true); t:SetVertexColor(0.32, 0.34, 0.4) end
            end
            local cfr = scene.ControlFrame
            if type(cfr) == "table" then
                for _, b in ipairs({ cfr:GetChildren() }) do pcall(SquareButton, b, 6) end
            end
        end
    end
end

local EXTRA = {
    WorldMapFrame = function()
        SkinWorldMap()
        SK:LiveSweep(WorldMapFrame)
        WorldMapFrame:HookScript("OnShow", function() pcall(SkinNavButtons) end)
        if WorldMapFrame.NavBar and WorldMapFrame.NavBar.Refresh then
            hooksecurefunc(WorldMapFrame.NavBar, "Refresh", function() pcall(SkinNavButtons) end)
        end
        pcall(SkinNavButtons)
    end,
    CharacterFrame = function()
        SkinCharacterFrame()
        SK:LiveSweep(CharacterFrame)
        -- Pieces created on first open are caught when the window shows.
        CharacterFrame:HookScript("OnShow", function() pcall(SkinCharacterFrame) end)
    end,
    InspectFrame = function()
        for _, slot in ipairs(EQUIP_SLOTS) do SK:ItemSlot(_G["Inspect" .. slot .. "Slot"]) end
    end,
}

function SK:SkinWindows()
    if not SK.db.windows then return end
    for _, name in ipairs(SK.windows) do
        local f = _G[name]
        if f and not SK.skinned[f] and f.GetObjectType then
            local ok, err = true, nil
            if name == "WorldMapFrame" then
                SK.skinned[f] = true
            else
                ok, err = pcall(SK.Window, SK, f)
            end
            if ok and EXTRA[name] then ok, err = pcall(EXTRA[name]) end
            if not ok and TempusDB and TempusDB.debug then
                TempusDB.debug.skinErrors = TempusDB.debug.skinErrors or {}
                TempusDB.debug.skinErrors[name] = tostring(err)
            end
        end
    end
end

----------------------------------------------------------------------------------------
-- Bag buttons and micro menu
----------------------------------------------------------------------------------------
local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
    "CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton" }

function SK:BagButton(b)
    if not b or b.tempusSkinned then return end
    local icon = b.icon
    if type(icon) ~= "table" then icon = b:GetName() and _G[b:GetName() .. "IconTexture"] end
    if icon and icon.RemoveMaskTexture then
        for _, key in ipairs({ "CircleMask", "IconMask" }) do
            if type(b[key]) == "table" then pcall(icon.RemoveMaskTexture, icon, b[key]) end
        end
    end
    SK:ItemSlot(b)
    local hl = b.SlotHighlightTexture or (b.GetHighlightTexture and b:GetHighlightTexture())
    if hl then
        hl:SetTexture(S.WHITE)
        hl:SetVertexColor(1, 1, 1, 0.12)
        hl:SetAllPoints(b)
    end
    local count = b.Count or (b:GetName() and _G[b:GetName() .. "Count"])
    if type(count) == "table" and count.SetFont then
        S.ApplyFont(count, 11)
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 2)
    end
end

-- Clean square icons for the micro buttons; unknown buttons keep Blizzard's art.
local MICRO_ICONS = {
    SpellbookMicroButton = "Interface\\Icons\\INV_Misc_Book_09",
    PlayerSpellsMicroButton = "Interface\\Icons\\INV_Misc_Book_09",
    ProfessionMicroButton = "Interface\\Icons\\Trade_BlackSmithing",
    TalentMicroButton = "Interface\\Icons\\Ability_Marksmanship",
    AchievementMicroButton = "Interface\\Icons\\INV_Misc_Ribbon_01",
    QuestLogMicroButton = "Interface\\Icons\\INV_Misc_Note_01",
    SocialsMicroButton = "Interface\\Icons\\INV_Letter_15",
    FriendsMicroButton = "Interface\\Icons\\INV_Letter_15",
    GuildMicroButton = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
    LFDMicroButton = "Interface\\Icons\\Spell_Holy_MindVision",
    LFGMicroButton = "Interface\\Icons\\Spell_Holy_MindVision",
    CollectionsMicroButton = "Interface\\Icons\\Ability_Mount_RidingHorse",
    EJMicroButton = "Interface\\Icons\\INV_Misc_Book_11",
    WorldMapMicroButton = "Interface\\Icons\\INV_Misc_Map_01",
    HelpMicroButton = "Interface\\Icons\\INV_Misc_QuestionMark",
    MainMenuMicroButton = "Interface\\Icons\\INV_Misc_Gear_01",
    StoreMicroButton = "Interface\\Icons\\INV_Misc_Coin_02",
    HousingMicroButton = "Interface\\Icons\\INV_Misc_Key_03",
    PVPMicroButton = "Interface\\Icons\\INV_BannerPVP_02",
}

local function MicroButtons()
    local list = {}
    if MicroMenu and MicroMenu.GetChildren then
        for _, c in ipairs({ MicroMenu:GetChildren() }) do
            local name = c.GetName and c:GetName()
            if name and name:find("MicroButton$") then list[#list + 1] = c end
        end
    end
    if #list == 0 and MICRO_BUTTONS then
        for _, name in ipairs(MICRO_BUTTONS) do if _G[name] then list[#list + 1] = _G[name] end end
    end
    return list
end

function SK:MicroButton(b)
    local name = b:GetName()
    local isChar = name == "CharacterMicroButton"
    if b.tempusSkinned or not (isChar or MICRO_ICONS[name]) then return end
    b.tempusSkinned = true
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    for _, key in ipairs({ "Background", "PushedBackground", "Portrait", "PortraitMask", "Shadow", "FlashBorder" }) do HideKey(b, key) end
    local bd = S.Backdrop(b, { fill = { 0.03, 0.035, 0.045, 1 } })
    local icon = b:CreateTexture(nil, "ARTWORK", nil, 7)
    icon.tempus = true
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.tempusIcon = icon
    if isChar then
        icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
        local function Portrait() pcall(SetPortraitTexture, icon, "player") end
        Portrait()
        local ev = CreateFrame("Frame")
        ev:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        ev:SetScript("OnEvent", Portrait)
    else
        icon:SetTexture(MICRO_ICONS[name])
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl.tempus = true
    hl:SetTexture(S.WHITE)
    hl:SetVertexColor(1, 1, 1, 0.14)
    hl:SetAllPoints(icon)
    local function State()
        local on = b:IsEnabled()
        icon:SetDesaturated(not on)
        icon:SetAlpha(on and 1 or 0.45)
    end
    hooksecurefunc(b, "Enable", State)
    hooksecurefunc(b, "Disable", State)
    b:HookScript("OnMouseDown", function() if b:IsEnabled() then bd:SetEdgeColor(T.accent[1], T.accent[2], T.accent[3]) end end)
    b:HookScript("OnMouseUp", function() bd:SetEdgeColor(0, 0, 0) end)
    State()
end

-- Quest/objective tracker: no background panel, flat headers with an accent underline.
local function SkinTrackerHeader(h)
    if type(h) ~= "table" or h.tempusSkinned then return end
    h.tempusSkinned = true
    if type(h.Background) == "table" then h.Background:SetAlpha(0) end
    local line = S.Tex(h, "ARTWORK", { T.accent[1], T.accent[2], T.accent[3], 0.7 })
    line.tempus = true
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 2)
    line:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -20, 2)
    local fade = S.Tex(h, "BACKGROUND", { 1, 1, 1, 1 })
    fade.tempus = true
    fade:SetPoint("TOPLEFT", 0, -4)
    fade:SetPoint("BOTTOMRIGHT", -20, 2)
    S.SetGradient(fade, "HORIZONTAL", 0.05, 0.055, 0.07, 0.75, 0.05, 0.055, 0.07, 0)
    local text = h.Text
    if type(text) == "table" and text.SetFont then S.ApplyFont(text, 13) end
    local mb = h.MinimizeButton
    if type(mb) == "table" then
        for _, r in ipairs({ mb:GetRegions() }) do
            if r.SetDesaturated then r:SetDesaturated(true); r:SetVertexColor(0.75, 0.78, 0.85) end
        end
    end
end

-- Lowest visible point of the tracker's content, so the panel ends with the last quest.
local function ContentBottom(tr)
    local lowest
    local function Scan(f, depth)
        if depth > 3 then return end
        for _, child in ipairs({ f:GetChildren() }) do
            if child:IsVisible() and child ~= tr.tempusPanel then
                local b = child:GetBottom()
                local h = child:GetHeight() or 0
                if b and h > 1 and (not lowest or b < lowest) then lowest = b end
                Scan(child, depth + 1)
            end
        end
    end
    Scan(tr, 0)
    return lowest
end

function SK:UpdateTrackerPanel()
    local tr = _G.ObjectiveTrackerFrame
    local panel = tr and tr.tempusPanel
    if not panel then return end
    local show = SK.db.trackerPanel and tr:IsVisible()
    local top, bottom = tr:GetTop(), show and ContentBottom(tr)
    if not (show and top and bottom) or top - bottom < 20 then panel:Hide() return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", tr, "TOPLEFT", -8, 6)
    panel:SetPoint("TOPRIGHT", tr, "TOPRIGHT", 6, 6)
    panel:SetHeight(top - bottom + 14)
    panel.bd:SetFillColor(0.035, 0.04, 0.052, SK.db.trackerAlpha)
    panel.bd:SetEdgeColor(0, 0, 0, math.min(1, SK.db.trackerAlpha + 0.35))
    panel:Show()
end

function SK:SkinTracker()
    local tr = _G.ObjectiveTrackerFrame
    if not tr then return end
    if type(tr.NineSlice) == "table" then tr.NineSlice:SetAlpha(0) end
    if not tr.tempusPanel then
        local panel = CreateFrame("Frame", nil, tr)
        panel:SetFrameLevel(math.max(tr:GetFrameLevel() - 1, 0))
        panel.bd = S.Backdrop(panel, { fill = { 0.035, 0.04, 0.052, 0.45 } })
        panel:Hide()
        tr.tempusPanel = panel
    end
    SkinTrackerHeader(tr.Header)
    for _, child in ipairs({ tr:GetChildren() }) do
        if type(child.Header) == "table" then pcall(SkinTrackerHeader, child.Header) end
    end
    SK:UpdateTrackerPanel()
end

function SK:InitTracker()
    local tr = _G.ObjectiveTrackerFrame
    if not tr then return end
    SK:SkinTracker()
    -- Sections are created as quests and achievements get tracked.
    if type(tr.Update) == "function" then hooksecurefunc(tr, "Update", function() pcall(SK.SkinTracker, SK) end) end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_WATCH_LIST_CHANGED", "TRACKED_ACHIEVEMENT_LIST_CHANGED", "PLAYER_ENTERING_WORLD" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function() C_Timer.After(0.1, function() pcall(SK.SkinTracker, SK) end) end)
    -- Progress bars and late headers: swept when the tracker updates, not continuously.
    local sweepTracker = T:Wrap("skins.trackersweep", function() pcall(Sweep, tr, 0) end)
    if type(tr.Update) == "function" then hooksecurefunc(tr, "Update", sweepTracker) end
    C_Timer.After(1, sweepTracker)
    local t = 0
    local sizer = CreateFrame("Frame", nil, tr)
    sizer:SetScript("OnUpdate", T:Wrap("skins.trackerpanel", function(_, elapsed)
        t = t + elapsed
        if t < 1 then return end
        t = 0
        pcall(SK.UpdateTrackerPanel, SK)
    end))
    hooksecurefunc(tr, "Hide", function() if tr.tempusPanel then tr.tempusPanel:Hide() end end)
end

function SK:SkinBarButtons()
    for _, name in ipairs(BAG_BUTTONS) do
        local b = _G[name]
        if b then pcall(SK.BagButton, SK, b) end
    end
    for _, b in ipairs(MicroButtons()) do pcall(SK.MicroButton, SK, b) end
end

----------------------------------------------------------------------------------------
-- Readable text. Quest, gossip and book text is dark brown, made for parchment; on a
-- Tempus panel it disappears. Any dark text in these windows is lifted to light grey.
----------------------------------------------------------------------------------------
local TEXT_WINDOWS = { "GossipFrame", "QuestFrame", "ItemTextFrame", "QuestLogFrame", "QuestLogDetailFrame" }

local brightFonts, brightCount = {}, 0
local function Dark(r, g, b) return T.Num(r) and T.Num(g) and T.Num(b) and (0.299 * r + 0.587 * g + 0.114 * b) < 0.45 end

-- A light copy of a dark font object; buttons re-apply their font object on every state
-- change, so recolouring the text alone does not stick.
local function BrightClone(fo)
    if not fo or not fo.GetTextColor then return fo end
    if brightFonts[fo] then return brightFonts[fo] end
    if not Dark(fo:GetTextColor()) then brightFonts[fo] = fo return fo end
    brightCount = brightCount + 1
    local clone = CreateFont("TempusReadableFont" .. brightCount)
    clone:CopyFontObject(fo)
    clone:SetTextColor(0.9, 0.9, 0.9)
    clone:SetShadowColor(0, 0, 0, 1)
    clone:SetShadowOffset(1, -1)
    brightFonts[fo] = clone
    brightFonts[clone] = clone
    return clone
end

local function BrightenButton(b)
    for _, pair in ipairs({ { "GetNormalFontObject", "SetNormalFontObject" }, { "GetHighlightFontObject", "SetHighlightFontObject" } }) do
        local get, set = b[pair[1]], b[pair[2]]
        if get and set then
            local fo = get(b)
            local clone = BrightClone(fo)
            if clone and clone ~= fo then set(b, clone) end
        end
    end
end

local function BrightenRegions(frame, depth)
    if depth > 9 or (frame.IsForbidden and frame:IsForbidden()) then return end
    if frame.GetObjectType and frame:GetObjectType() == "Button" then pcall(BrightenButton, frame) end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then
            local red, green, blue = r:GetTextColor()
            if T.Num(red) and T.Num(green) and T.Num(blue) and (0.299 * red + 0.587 * green + 0.114 * blue) < 0.45 then
                r:SetTextColor(0.9, 0.9, 0.9)
                r:SetShadowColor(0, 0, 0, 1)
                r:SetShadowOffset(1, -1)
            end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do BrightenRegions(child, depth + 1) end
end

-- On parchment the reverse: light grey or white text becomes dark brown. That covers
-- text lightened before the parchment was found, and text the client draws light itself.
-- Coloured text (item quality, headers) is left alone.
local INK = { 0.24, 0.14, 0.06 }
local function Light(r, g, b)
    if not (T.Num(r) and T.Num(g) and T.Num(b)) then return false end
    return (0.299 * r + 0.587 * g + 0.114 * b) > 0.55 and (math.max(r, g, b) - math.min(r, g, b)) < 0.15
end

local inkFonts, inkCount = {}, 0
local function InkClone(fo)
    if not fo or not fo.GetTextColor then return fo end
    -- A font Tempus lightened goes back to Blizzard's original, which is made for parchment.
    for orig, clone in pairs(brightFonts) do
        if clone == fo and orig ~= fo then fo = orig break end
    end
    if inkFonts[fo] then return inkFonts[fo] end
    if not Light(fo:GetTextColor()) then inkFonts[fo] = fo return fo end
    inkCount = inkCount + 1
    local clone = CreateFont("TempusInkFont" .. inkCount)
    clone:CopyFontObject(fo)
    clone:SetTextColor(INK[1], INK[2], INK[3])
    clone:SetShadowColor(0, 0, 0, 0)
    inkFonts[fo] = clone
    inkFonts[clone] = clone
    return clone
end

local function InkButton(b)
    for _, pair in ipairs({ { "GetNormalFontObject", "SetNormalFontObject" }, { "GetHighlightFontObject", "SetHighlightFontObject" } }) do
        local get, set = b[pair[1]], b[pair[2]]
        if get and set then
            local fo = get(b)
            local ink = InkClone(fo)
            if ink and ink ~= fo then set(b, ink) end
        end
    end
end

local function InkRegions(frame, depth)
    if depth > 9 or (frame.IsForbidden and frame:IsForbidden()) then return end
    if frame.GetObjectType and frame:GetObjectType() == "Button" then pcall(InkButton, frame) end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" and Light(r:GetTextColor()) then
            r:SetTextColor(INK[1], INK[2], INK[3])
            r:SetShadowColor(0, 0, 0, 0)
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do InkRegions(child, depth + 1) end
end

function SK:BrightenText()
    if not SK.db.windows then return end
    for _, name in ipairs(TEXT_WINDOWS) do
        local f = _G[name]
        if SK.db.parchment then SK:RestoreParchment(name) end
        local onParchment = SK.db.parchment and SK.parchmentWindows and SK.parchmentWindows[name]
        if f and f:IsShown() then
            if onParchment then pcall(InkRegions, f, 0) else pcall(BrightenRegions, f, 0) end
        end
    end
end

-- Content arrives through events and scroll-box layouts; recolour right after each.
function SK:InitReadableText()
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
        "QUEST_FINISHED", "ITEM_TEXT_READY", "ITEM_TEXT_BEGIN", "QUEST_LOG_UPDATE" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    local function Soon()
        C_Timer.After(0, function() SK:BrightenText() end)
        C_Timer.After(0.15, function() SK:BrightenText() end)
    end
    ev:SetScript("OnEvent", Soon)
    for _, name in ipairs(TEXT_WINDOWS) do
        local f = _G[name]
        if f then f:HookScript("OnShow", Soon) end
    end
end

----------------------------------------------------------------------------------------
-- Skin report: records stock art still visible in open windows, so leftovers can be
-- targeted precisely. /tempus skinreport, then /reload to write it to disk.
----------------------------------------------------------------------------------------
local function KeyOf(obj)
    local key = obj.GetParentKey and obj:GetParentKey()
    if key then return key end
    local name = obj.GetName and obj:GetName()
    if name then return name end
    return obj.GetObjectType and ("<" .. obj:GetObjectType() .. ">") or "?"
end

local function PathOf(obj, root)
    local parts, cur, guard = {}, obj, 0
    while cur and cur ~= root and guard < 8 do
        table.insert(parts, 1, KeyOf(cur))
        cur = cur.GetParent and cur:GetParent()
        guard = guard + 1
    end
    return table.concat(parts, ".")
end

local function Describe(tex)
    local atlas = tex.GetAtlas and tex:GetAtlas()
    if atlas and atlas ~= "" then return "atlas:" .. atlas end
    local file = tex.GetTexture and tex:GetTexture()
    if file == nil then return nil end
    return "file:" .. tostring(file)
end

local function Capture(root, out, depth, count)
    if depth > 7 or count[1] > 250 then return end
    for _, r in ipairs({ root:GetRegions() }) do
        local alpha = r.GetEffectiveAlpha and r:GetEffectiveAlpha() or r:GetAlpha()
        local stripped = IsTex(r) and r.tempusStripped and r:IsShown() and (r:GetWidth() or 0) >= 64
        if stripped then
            local what = Describe(r)
            if what then
                local w, h = r:GetSize()
                count[1] = count[1] + 1
                out[#out + 1] = ("[stripped] %s  %s  %dx%d"):format(PathOf(r, out.root), what, math.floor((w or 0) + 0.5), math.floor((h or 0) + 0.5))
            end
        elseif IsTex(r) and not r.tempus and r:IsVisible() and alpha > 0.05 then
            local what = Describe(r)
            if what and what ~= "file:" .. S.WHITE then
                local w, h = r:GetSize()
                count[1] = count[1] + 1
                out[#out + 1] = ("%s  %s  %dx%d"):format(PathOf(r, out.root), what, math.floor((w or 0) + 0.5), math.floor((h or 0) + 0.5))
            end
        end
    end
    for _, child in ipairs({ root:GetChildren() }) do
        if not (child.IsForbidden and child:IsForbidden()) and child:IsVisible() and not child.tempusSkinPanel then
            Capture(child, out, depth + 1, count)
        end
    end
end

local function Topmost(f)
    -- Climb to the last ancestor below UIParent: that is the window the mouse is over.
    local guard = 0
    while f and f.GetParent and guard < 30 do
        local p = f:GetParent()
        if not p or p == UIParent or p == WorldFrame then return f end
        f = p
        guard = guard + 1
    end
    return f
end

function SK:Report()
    -- Runs accumulate for the session, so several tabs can be captured before a reload.
    if not SK.reportSession then
        SK.reportSession = true
        TempusDB.skinReport = {}
    end
    SK.reportRun = (SK.reportRun or 0) + 1
    local targets, seen = {}, {}
    local function Add(f, label)
        if not f or seen[f] or (f.IsForbidden and f:IsForbidden()) or not f:IsVisible() then return end
        seen[f] = true
        targets[#targets + 1] = { f, label or (f.GetName and f:GetName()) or ("<" .. f:GetObjectType() .. ">") }
    end
    -- 1. The window under the mouse.
    local focus = GetMouseFoci and GetMouseFoci()[1] or (GetMouseFocus and GetMouseFocus())
    if focus and focus ~= WorldFrame then Add(Topmost(focus), nil) end
    -- 2. Every known window that is open, wherever it is parented.
    for _, name in ipairs(SK.windows) do
        if _G[name] then Add(_G[name], name) end
    end
    -- 3. Large named frames directly on UIParent.
    for _, f in ipairs({ UIParent:GetChildren() }) do
        if not (f.IsForbidden and f:IsForbidden()) then
            local name = f.GetName and f:GetName()
            local w, h = f:GetSize()
            if name and not name:find("^Tempus") and (w or 0) > 150 and (h or 0) > 150 and name ~= "WorldFrame" then Add(f, name) end
        end
    end
    for _, t in ipairs(targets) do
        local f, label = t[1], t[2]
        local out = { root = f }
        Capture(f, out, 0, { 0 })
        out.root = nil
        out.skinned = SK.skinned[f] and true or false
        local parent = f:GetParent()
        out.parent = parent and (parent:GetName() or "<anon>") or "none"
        local tc = type(f.TitleContainer) == "table" and f.TitleContainer
        local tt = tc and type(tc.TitleText) == "table" and tc.TitleText
        local title = tt and tt.GetText and tt:GetText()
        if title and T.issecret(title) then title = nil end
        out.title = title
        TempusDB.skinReport[("%d %s%s"):format(SK.reportRun, label, title and (" [" .. title .. "]") or "")] = out
    end
    T:Print("skin report #%d captured for %d window(s)%s. Repeat for other tabs, then /reload.", SK.reportRun, #targets,
        focus and focus ~= WorldFrame and " (including the one under your mouse)" or "")
end

T:NewModule("skins", {
    label = "Skins",
    desc = "Re-themes Blizzard windows, tooltips and chat, plus Bagnon and DBM, in the Tempus look.",
    defaults = SK.defaults,
    OnEnable = function()
        SK.db = T.db.skins
        SK:SkinWindows()
        if SK.db.windows then
            pcall(SK.InitReadableText, SK)
            pcall(SK.SkinBarButtons, SK)
            pcall(SK.InitTracker, SK)
        end
        if SK.InitTooltips and SK.db.tooltips then pcall(SK.InitTooltips, SK) end
        if SK.InitChat and SK.db.chat then pcall(SK.InitChat, SK) end
        if SK.InitAddOns then pcall(SK.InitAddOns, SK) end
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("ADDON_LOADED")
        ev:SetScript("OnEvent", function(_, _, addon)
            SK:SkinWindows()
            if SK.OnAddonLoaded then pcall(SK.OnAddonLoaded, SK, addon) end
        end)
    end,
    OnSettings = function()
        SK.db = T.db.skins
        if SK.UpdateChatAlpha then pcall(SK.UpdateChatAlpha, SK) end
        pcall(SK.UpdateTrackerPanel, SK)
    end,
})
