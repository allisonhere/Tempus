-- Style Blizzard's roll frames without replacing their voting or timer handlers.
local _, T = ...
local SK, S = T.Skins, T.Style

function SK:SkinLootRoll(frame)
    if not frame or not self:On("windows") then return end
    if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
    -- Forever lowers the timer on each item setup; keep it above our panel.
    if frame.Timer and frame.GetFrameLevel and frame.Timer.SetFrameLevel then
        frame.Timer:SetFrameLevel(frame:GetFrameLevel() + 1)
    end
    if frame.tempusRollSkin then return end
    self:Strip(frame)
    local panel = self:Panel(frame)
    panel:SetEdgeColor(T.accent[1], T.accent[2], T.accent[3], 0.7)
    if frame.Name then S.ApplyFont(frame.Name, 12) end
    if frame.IconFrame then
        local icon = frame.IconFrame
        if icon.Icon then icon.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
        if icon.Count then S.ApplyFont(icon.Count, 11) end
    end
    local buttons = frame.LootButtonContainer or frame
    for _, key in ipairs({ "NeedButton", "GreedButton", "PassButton", "DisenchantButton", "TransmogButton" }) do
        local button = buttons[key]
        -- These normal textures are the recognizable dice/coin/pass icons.
        if button then self:Panel(button, S.C.card) end
    end
    if frame.Timer then
        frame.Timer:SetStatusBarTexture(S.BarTexture(T.db.barTexture))
        self:Panel(frame.Timer, S.C.card)
    end
    frame.tempusRollSkin = true
end

function SK:CenterLootRolls(container)
    if not self:On("windows") or not container or not container.rollFrames then return end
    local rows = {}
    for i = 1, container.maxIndex or 4 do
        local row = container.rollFrames[i]
        if row and row:IsShown() then rows[#rows + 1] = row end
    end
    local spacing = (container.reservedSize or 76) + 8
    for i, row in ipairs(rows) do
        if not (InCombatLockdown() and row.IsProtected and row:IsProtected()) then
            row:ClearAllPoints()
            row:SetPoint("CENTER", UIParent, "CENTER", 0, ((#rows + 1) / 2 - i) * spacing)
            row:SetClampedToScreen(true)
            self:Try("loot roll", self.SkinLootRoll, self, row)
        end
    end
end

function SK:InitLootRolls()
    if not self:On("windows") then return end
    if not self.lootRollUpdateHook and type(GroupLootContainer_Update) == "function" then
        self.lootRollUpdateHook = true
        hooksecurefunc("GroupLootContainer_Update", function(container)
            SK:Try("loot roll layout", SK.CenterLootRolls, SK, container)
        end)
    end
    for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
        local row = _G["GroupLootFrame" .. i]
        if row and not row.tempusRollHook then
            row.tempusRollHook = true
            row:HookScript("OnShow", function(frame)
                SK:Try("loot roll", SK.SkinLootRoll, SK, frame)
                SK:Try("loot roll layout", SK.CenterLootRolls, SK, GroupLootContainer)
            end)
            self:Try("loot roll", self.SkinLootRoll, self, row)
        end
    end
    if not self.lootRollEvents then
        self.lootRollEvents = CreateFrame("Frame")
        self.lootRollEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
        self.lootRollEvents:SetScript("OnEvent", function()
            SK:Try("loot roll layout", SK.CenterLootRolls, SK, GroupLootContainer)
        end)
    end
    self:CenterLootRolls(GroupLootContainer)
end

function SK:PreviewLootRoll()
    if not self:On("windows") then
        T:Print("Enable Windows under Skins and turn off Stock skin to preview the loot-roll skin.")
        return
    end
    if not self.lootRollPreview then
        local row = CreateFrame("Frame", nil, UIParent)
        row:SetSize(277, 67)
        row:SetFrameStrata("FULLSCREEN_DIALOG")
        row:SetClampedToScreen(true)
        row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.Name:SetPoint("TOPLEFT", 60, -15)
        row.Name:SetSize(125, 30)
        row.Name:SetJustifyH("LEFT")
        row.Name:SetText("Loot roll preview")
        row.Name:SetTextColor(0.64, 0.21, 0.93)
        row.IconFrame = CreateFrame("Frame", nil, row)
        row.IconFrame:SetSize(34, 34)
        row.IconFrame:SetPoint("TOPLEFT", 10, -13)
        row.IconFrame.Icon = row.IconFrame:CreateTexture(nil, "ARTWORK")
        row.IconFrame.Icon:SetAllPoints()
        row.IconFrame.Icon:SetTexture("Interface\\Icons\\INV_Misc_Gift_01")
        local choices = {
            { "NeedButton", "need", -44, -6, "Need" },
            { "PassButton", "pass", -6, -4, "Pass" },
            { "GreedButton", "greed", -44, -33, "Greed" },
        }
        for _, choice in ipairs(choices) do
            local b = CreateFrame("Button", nil, row)
            b:SetSize(32, 32)
            b:SetPoint("TOPRIGHT", choice[3], choice[4])
            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            icon:SetAtlas("lootroll-toast-icon-" .. choice[2] .. "-up")
            b:SetScript("OnClick", function() row:Hide(); GameTooltip:Hide() end)
            local label = choice[5]
            b:SetScript("OnEnter", function(button)
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetText(label .. " — preview only; click to close")
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row[choice[1]] = b
        end
        row.Timer = CreateFrame("StatusBar", nil, row)
        row.Timer:SetPoint("BOTTOMLEFT", 3, 2)
        row.Timer:SetSize(190, 8)
        row.Timer:SetMinMaxValues(0, 100)
        row.Timer:SetValue(70)
        row.Timer:SetStatusBarColor(1, 0.82, 0)
        self:SkinLootRoll(row)
        row:SetScript("OnHide", function() GameTooltip:Hide() end)
        self.lootRollPreview = row
    end
    self.lootRollPreview:ClearAllPoints()
    self.lootRollPreview:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.lootRollPreview:Show()
end
