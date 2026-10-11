-- Tempus UI: settings page for the chat module.
local _, T = ...
local UI = T.UI
local W = UI.W

T:RegisterPage("chat", { key = "chat", label = "Chat", order = 1, build = function(p)
    local cfg = function() return T.db.chat end
    p:Section("Chat", "Extras on top of Blizzard's chat windows. The look of the windows themselves (panels, tabs, edit box) is under Skins > Chat frames. Needs the Chat module to be on (General > Modules).")
    if T.Chat.PratLoaded() then
        p:Section("Prat is loaded", "Prat has its own timestamps, link copying, copy chat and history. Turn those Prat modules off, or switch Prat off, so lines are not stamped or linked twice.")
    end
    p:Section("Links and copying")
    p:Check(cfg, "urls", "Clickable web links", "Web addresses in chat become blue links. Click one to get a box to copy it from.")
    p:Check(cfg, "copyButton", "Copy button next to the tabs", "A small copy icon at the right end of the tab row opens the selected window's text for copying. Also /tempus copychat.")
    p:Section("History", "Recent lines are saved and shown again after a reload or relog. Lines the game hides during boss fights and Mythic+ cannot be saved.")
    p:Check(cfg, "history", "Keep chat history", "Applies after a reload.")
    p:Slider(cfg, "historyLines", "Lines kept per window", 25, 500, 25)
    p:Add(W.Button("Clear saved history", function() T.Chat:ClearHistory() end))
    p:Section("Look")
    p:Dropdown(cfg, "timestamps", "Timestamps", { { "KEEP", "Leave the game setting" }, { "NONE", "Off" },
        { "H24", "24-hour (14:05:31)" }, { "H12", "12-hour (2:05:31 PM)" } })
    p:Check(cfg, "fadeChrome", "Hide tabs and buttons until mouseover", "Tabs and the scroll buttons appear when the mouse is over the chat window.")
end })
