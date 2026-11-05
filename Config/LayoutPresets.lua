-- Preset actions deliberately separate preview from apply; names never overwrite silently.
local _, T = ...
local UI, L = T.UI, T.Layouts
local selected, dialog
local function Report(ok, err)
    if not ok then T:Print(err) end
    return ok
end
local function Prompt(title, action)
    if dialog then dialog:Hide() end
    local profile = T.db
    dialog = CreateFrame("Frame", nil, UIParent)
    dialog:SetSize(360, 130); dialog:SetPoint("CENTER"); dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:EnableMouse(true)
    local bg = UI.Tex(dialog, "BACKGROUND", {0.04, 0.05, 0.07, 1}); bg:SetAllPoints(); UI.Border(dialog)
    local heading = UI.Text(dialog, 13); heading:SetPoint("TOPLEFT", 16, -12); heading:SetText(title)
    local input = UI.StyledEditBox(dialog, 328, 26); input:SetPoint("TOPLEFT", 16, -36); input:SetMaxLetters(48)
    local function Submit()
        if profile ~= T.db then T:Print("Profile changed; try again."); dialog:Hide(); return end
        local name, err = action(input:GetText())
        if Report(name, err) then selected = name; dialog:Hide(); if T.Options then T.Options:Refresh() end end
    end
    local save = UI.FlatButton(dialog, "Save", 100, 26, Submit); save:SetPoint("BOTTOMLEFT", 16, 16)
    local cancel = UI.FlatButton(dialog, "Cancel", 100, 26, function() dialog:Hide() end); cancel:SetPoint("BOTTOMRIGHT", -16, 16)
    input:SetScript("OnEnterPressed", Submit)
    input:SetScript("OnEscapePressed", function() dialog:Hide() end)
    input:SetFocus()
end
T:RegisterPage("general", {key = "layouts", label = "Layout presets", order = 3, build = function(p)
    p:Section("Layout presets", "Save frame positions in this profile. Preview shows ghost frames; Apply commits the preview. Sizes and other settings stay unchanged. Layout switching is unavailable in combat.")
    p:Add(UI.W.Dropdown("Saved layout", function()
        local items = {}; for _, name in ipairs(L:Names()) do items[#items + 1] = {name, name} end
        return items
    end, function() return selected end, function(value) L:Cancel(); selected = value end))
    p:Newline()
    p:Add(UI.W.Button("Save current as...", function() Prompt("Save current frame positions", function(name) return L:Save(name) end) end))
    p:Add(UI.W.Button("Duplicate...", function() local source = selected; Prompt("Duplicate selected layout", function(name) return L:Duplicate(source, name) end) end))
    p:Newline()
    p:Add(UI.W.Button("Rename...", function() local source = selected; Prompt("Rename selected layout", function(name) return L:Rename(source, name) end) end))
    p:Add(UI.W.Button("Preview selected", function() if Report(L:Stage(selected)) then T:Print("Preview only. Use Apply preview to move frames, or Cancel preview.") end end))
    p:Newline()
    p:Add(UI.W.Button("Preview defaults", function() if Report(L:Stage(nil, true)) then T:Print("Default positions previewed. Saved presets are preserved.") end end))
    p:Add(UI.W.Button("Apply preview", function() Report(L:Apply()) end))
    p:Newline()
    p:Add(UI.W.Button("Cancel preview", function() L:Cancel() end))
    p:Section("Layout history", "Undo and redo frame drags, arrow nudges, applied presets and default-position restores. History holds the last 50 position changes per profile until reload/logout. Sizes and other settings are not included.")
    for _, action in ipairs({"Undo", "Redo"}) do
        local method = action
        local widget, height = UI.W.Button(action, function() Report(L[method](L)) end)
        function widget:Refresh() self.button:SetEnabled(L["Can" .. method](L)) end
        p:Add(widget, height)
    end
    p:Section("Arrange frames", "Use /tempus unlock for labeled drag handles and the frame selector. Shift-click adds or removes frames from a group; the selector also toggles frames. Drag or nudge selected frames together, align their edges/centers, or use Equal gaps with at least three frames. Arrows nudge 1 UI unit; Shift-click nudges 10. Drag near edges or centers to snap within 8 units. Hold Alt to bypass snapping. Escape locks frames. Use Save current as to capture an adjusted layout under a new name.")
end})
