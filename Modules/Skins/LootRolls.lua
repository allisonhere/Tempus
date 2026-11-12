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
