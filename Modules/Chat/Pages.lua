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
    p:Check(cfg, "selectMode", "Select mode for chat history", "Alt+click a chat window, or the I-beam button by the tabs, to show it as text you can select with the mouse or keyboard (Shift+arrows, Ctrl+A) and copy with Ctrl+C. Esc returns to normal chat, where links are clickable again. Also /tempus selectchat.")
    p:Section("Typing")
    p:Check(cfg, "editorKeys", "Arrow keys move the cursor", "Left, Right, Home and End move the cursor in the chat box and Shift selects, without holding Alt. Up and Down walk your sent messages. Ctrl+A, C, V and X work as usual, and SpellPower keeps working.")
    p:Section("Whisper alert", "Gets your attention when someone whispers you: a banner with who it is and what they said, a sound, and a flashing taskbar icon when the game is in the background. Press R to reply. Unlock the UI to move the banner.")
    p:Check(cfg, "whisperAlert", "Alert me when someone whispers")
    p:Add(W.Button("Test", function()
        if T.Chat.Whisper and T.Chat.Whisper.ready then T.Chat.Whisper:Test() else T:Print("the Chat module is off.") end
    end, "Shows a sample banner and plays the sound."))
    p:Check(cfg, "whisperBanner", "Banner on screen", "Shows who whispered and the start of the message for a few seconds. Click it to dismiss.")
    p:Dropdown(cfg, "whisperSound", "Sound", T.Chat.Whisper and T.Chat.Whisper.SOUNDS or { { "TELL", "Whisper" } })
    p:Check(cfg, "whisperFlash", "Flash the taskbar icon", "Flashes WoW in your taskbar when the game is in the background.")
    p:Check(cfg, "whisperCombat", "Also alert in combat")
    p:Check(cfg, "whisperBattleNet", "Battle.net whispers too")
    p:Section("Text")
    p:Check(cfg, "shortChannels", "Short channel names", "[2. Trade - City] becomes [T], [1. General] becomes [G]; other channels show their number. Party, guild and raid tags keep the game's wording. Off when Prat is loaded.")
    p:Check(cfg, "classNames", "Class-coloured names", "Turns on the game's own class colours for player names in chat. Turning this off leaves the game setting as it is.")
    p:Check(cfg, "mutedTimestamps", "Grey timestamps", "Timestamps are drawn in grey so the message stands out. Works with the game's timestamp setting or the one below.")
    p:Section("History", "Recent lines are saved and shown again after a reload or relog. Lines the game hides during boss fights and Mythic+ cannot be saved.")
    p:Check(cfg, "history", "Keep chat history", "Applies after a reload.")
    p:Slider(cfg, "historyLines", "Lines kept per window", 25, 500, 25, nil, "How many recent lines each chat window saves for after a reload.")
    p:Add(W.Button("Clear saved history", function() T.Chat:ClearHistory() end))
    p:Section("Look")
    p:Dropdown(cfg, "timestamps", "Timestamps", { { "KEEP", "Leave the game setting" }, { "NONE", "Off" },
        { "H24", "24-hour (14:05:31)" }, { "H12", "12-hour (2:05:31 PM)" } })
    p:Check(cfg, "fadeChrome", "Hide tabs and buttons until mouseover", "Tabs and the scroll buttons appear when the mouse is over the chat window.")
end })
