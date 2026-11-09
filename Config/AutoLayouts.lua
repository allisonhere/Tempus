local _, T = ...
local UI, A = T.UI, T.AutoLayouts
T:RegisterPage("layout", {key = "auto_layouts", label = "Automatic layouts", order = 3.1, build = function(p)
    p:Section("Automatic layouts", "Opt in to a saved position preset for solo, party or raid play. Switching waits for combat to end, frames to be locked, and dragging/previews to finish. An unassigned group type keeps current positions.")
    p:Add(UI.W.Check("Enable automatic layout switching", function() return A:Config().enabled end, function(v) A:Config().enabled = v; A:Reapply() end))
    p:Add(UI.W.Check("Pause automatic switching (manual override)", function() return A:Config().paused end, function(v) A:Config().paused = v; A:Reapply() end))
    local function Choices()
        local items = {{"", "Keep current positions"}}
        for _, name in ipairs(T.Layouts:Names()) do items[#items + 1] = {name, name} end
        return items
    end
    for _, entry in ipairs({{"solo", "Solo layout"}, {"party", "Party layout"}, {"raid", "Raid layout"}}) do
        local context = entry[1]
        p:Add(UI.W.Dropdown(entry[2], Choices, function() return A:Config()[context] or "" end,
            function(name) A:Config()[context] = name; A:Schedule() end))
    end
    p:Newline()
    p:Add(UI.W.Button("Reapply current group layout", function() A:Reapply() end,
        "Reapply the assigned preset after manual changes. Enable automatic switching and unpause it first.", 240))
    p:Newline()
    local status = CreateFrame("Frame")
    status:SetSize(UI.COL_W * 2 + 22, 54)
    local text = UI.Text(status, 11)
    text:SetAllPoints(); text:SetJustifyV("TOP")
    status.searchLabel = "Automatic layout status"
    status.searchText = "Current group preset status combat pending manual override"
    function status:Refresh() text:SetText(A:Status()) end
    p:Add(status, 54, true)
    p:Section("Manual changes", "Dragging, nudging, alignment, Undo/Redo or applying a preset keeps your manual layout for this group type. Automatic switching resumes when the group type changes. Reapply current group layout retries now; Pause keeps manual control across group changes. Each automatic switch is one Undo action. Rules and Pause are saved per profile.")
end})
