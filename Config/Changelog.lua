-- Tempus UI: "What's new" page. The text comes from Core/Changelog.lua, which is generated
-- from CHANGELOG.md (python3 tools/gen_changelog.py), because an addon cannot read files.
local _, T = ...
local UI = T.UI

T:RegisterPage("general", { key = "changelog", label = "What's new", order = 2, build = function(p)
    local log = T.changelog or {}
    local version = T.version or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Tempus", "Version"))
        or (GetAddOnMetadata and GetAddOnMetadata("Tempus", "Version")) or "?"
    p:Section("What's new", "You are running Tempus " .. tostring(version) .. ".")
    if #log == 0 then
        p:Paragraph("No changelog is bundled with this version.", 0, T.Style.C.muted)
        return
    end
    for i, release in ipairs(log) do
        if i > 1 then p:Section("Version " .. release.version) end
        if i == 1 then p:Paragraph("Version " .. release.version, 0, T.Style.accent, 13, 8) end
        for _, section in ipairs(release.sections) do
            p:Paragraph(section.title, 0, T.Style.C.muted, 11, 4)
            for _, item in ipairs(section.items) do
                local top = item[1] == 0
                p:Paragraph((top and "- " or "   - ") .. item[2], top and 6 or 20, T.Style.C.text, 12, top and 5 or 3)
            end
            p:Paragraph(" ", 0, nil, 6, 2)
        end
    end
end })
