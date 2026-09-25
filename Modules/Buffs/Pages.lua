-- Tempus UI: settings pages for the buffs module.
local _, T = ...
local UI = T.UI
local D = T.Display
local W, DB, Changed, pct, secs = UI.W, UI.DB, UI.Changed, UI.pct, UI.secs
local Text, StyledEditBox, FlatButton, COL_W = UI.Text, UI.StyledEditBox, UI.FlatButton, UI.COL_W

local PAGES = {}

PAGES[#PAGES + 1] = { key = "buffsgeneral", label = "Behaviour", build = function(p)
    p:Section("Behaviour", "Tempus replaces the default buff frames with fully configurable timers. Unlock to drag each group; right-click a group's box to jump to its settings.")
    p:Check(DB, "locked", "Lock frames", "When unlocked, every group shows a draggable box with preview auras.")
    p:Add(W.Check("Preview with test auras", function() return D.testMode end, function(v) D:SetTestMode(v) end,
        "Fills every group with sample buffs, debuffs, and enchants so you can style them."))
    p:Check(DB, "hideBlizzard", "Hide Blizzard buff frames", "Turning this off takes effect after /reload.")
    p:Check(DB, "tooltips", "Show tooltips")
    p:Check(DB, "rightClickCancel", "Right-click to cancel buffs", "Works out of combat; the game blocks cancelling buffs from addons during combat.")
    p:Check(DB, "clickToRecast", "Left-click to recast", "Casts a buff from your spellbook (highest rank), or uses the matching flask, elixir, poison or oil from your bags. Clicking a missing-buff reminder casts it. Out of combat only.")
    p:Check(DB, "clickThrough", "Click-through", "Auras ignore the mouse entirely (no tooltips or cancelling).")
    p:Check(DB, "mergeWeapons", "Show weapon enchants with buffs", "Adds oils, poisons and sharpening stones to the buff group instead of their own group.")
    p:Add(W.Check("Minimap button", function() return not T.db.minimap.hide end, function(v) T.db.minimap.hide = not v end))

    p:Section("Quick layouts", "One-click starting points. They change the style of all groups; fine-tune afterwards.")
    p:Add(W.Button("Classic icons", function()
        for _, g in pairs(T.db.groups) do g.style = "ICONS"; g.timer = "BOTTOM" end
        T.db.theme = "MODERN"; Changed()
    end, "Icon grid with timers below."))
    p:Add(W.Button("Timer bars", function()
        for k, g in pairs(T.db.groups) do if k ~= "watch" then g.style = "BARS"; g.barIcon = "LEFT" end end
        Changed()
    end, "Every buff as a named, draining bar."))
    p:Add(W.Button("Compact", function()
        for _, g in pairs(T.db.groups) do g.style = "ICONS"; g.timer = "CENTER"; g.size = 28; g.spacing = 3 end
        Changed()
    end, "Small icons with the timer inside."))
    p:Add(W.Button("Big & glossy", function()
        for k, g in pairs(T.db.groups) do g.style = "ICONS"; g.timer = "BOTTOM"; g.size = k == "debuffs" and 48 or 40 end
        T.db.theme = "GLOSS"; Changed()
    end, "Large glossy icons."))
end }

PAGES[#PAGES + 1] = { key = "appearance", label = "Appearance", suite = true, build = function(p)
    p:Section("Style")
    p:Dropdown(DB, "accent", "Accent colour", function()
        local t = {}
        for _, a in ipairs(T.accents) do
            local c = a[3]
            t[#t + 1] = { a[1], ("|cff%02x%02x%02x%s|r"):format(c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5, a[2]) }
        end
        return t
    end, "Highlights, selected tabs, target glows and headers across the whole UI. /reload to recolour everything already on screen.")
    p:Add(W.Button("Reload UI", function() ReloadUI() end, "Applies the accent colour everywhere."))
    p:Dropdown(DB, "theme", "Theme", {
        { "MODERN", "Modern - crisp border & shadow" }, { "GLOSS", "Gloss - glassy highlight" },
        { "CLASSIC", "Classic - Blizzard look" }, { "FLAT", "Flat - borderless" } })
    p:Dropdown(DB, "barTexture", "Bar texture", function()
        local t = {}
        for _, bt in ipairs(D.barTextures) do t[#t + 1] = { bt[1], bt[2] } end
        return t
    end)
    p:Slider(DB, "borderSize", "Border thickness", 0, 4, 1)
    p:Slider(DB, "iconZoom", "Icon crop", 0, 0.2, 0.01, pct, "Trims the icon's built-in edge.")

    p:Section("Text")
    p:Dropdown(DB, "font", "Font", {
        { "Fonts\\FRIZQT__.TTF", "Friz Quadrata" }, { "Fonts\\ARIALN.TTF", "Arial Narrow" },
        { "Fonts\\MORPHEUS.TTF", "Morpheus" }, { "Fonts\\SKURRI.TTF", "Skurri" } })
    p:Dropdown(DB, "fontOutline", "Outline", { { "NONE", "None (shadow)" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" } })
    p:Slider(DB, "timerFontSize", "Timer size", 7, 24, 1)
    p:Slider(DB, "countFontSize", "Stack count size", 7, 24, 1)
    p:Slider(DB, "nameFontSize", "Bar name size", 7, 24, 1)

    local colors = function() return T.db.colors end
    p:Section("Colours")
    p:Color(colors, "border", "Buff border")
    p:Color(colors, "important", "Important aura glow")
    p:Color(colors, "buffBar", "Buff bar")
    p:Color(colors, "debuffBar", "Debuff bar")
    p:Color(colors, "weaponBar", "Weapon enchant")
    p:Color(colors, "barBg", "Bar background")
end }

PAGES[#PAGES + 1] = { key = "timers", label = "Timers", build = function(p)
    p:Section("Countdown text")
    p:Dropdown(DB, "timerFormat", "Format", {
        { "SMART", "Smart  -  1h  12m  1:05  45" }, { "CLOCK", "Clock  -  1:02:03  12:05  0:45" },
        { "LONG", "Long  -  1h 02m  12m 05s  45s" } })
    p:Slider(DB, "decimals", "Tenths of a second below", 0, 10, 1, secs, "Shows 4.3 instead of 5 in the final seconds.")
    p:Check(DB, "colorTimers", "Colour by time left")
    p:Newline()
    p:Slider(DB, "soonAt", "\"Soon\" colour below", 5, 600, 5, secs)
    p:Slider(DB, "urgentAt", "\"Urgent\" colour below", 1, 60, 1, secs)
    local colors = function() return T.db.colors end
    p:Color(colors, "normal", "Normal")
    p:Color(colors, "soon", "Soon")
    p:Color(colors, "urgent", "Urgent / missing")

    p:Section("Animation")
    p:Check(DB, "pulse", "Pulse when about to expire")
    p:Slider(DB, "pulseAt", "Pulse below", 1, 60, 1, secs)
    p:Check(DB, "swipe", "Cooldown swipe on icons")
    p:Slider(DB, "swipeAlpha", "Swipe darkness", 0.1, 1, 0.05, pct)
end }

local function GroupPage(key, label)
    return { key = key, label = label, build = function(p)
        local cfg = function() return T.db.groups[key] end
        local isBars = function() return T.db.groups[key].style == "BARS" end
        local isIcons = function() return not isBars() end
        local desc = {
            buffs = "Your helpful auras.",
            debuffs = "Harmful effects on you. Borders are coloured by dispel type.",
            weapons = "Temporary weapon enchants: oils, stones, poisons and shaman imbues.",
            watch = "Buffs from your watch list that you do NOT have. Tempus only reports missing when every buff name is readable.",
        }
        p:Section(label, desc[key])
        p:Check(cfg, "enabled", "Enabled")
        p:Dropdown(cfg, "style", "Style", { { "ICONS", "Icons" }, { "BARS", "Timer bars" } })
        p:Slider(cfg, "scale", "Scale", 0.5, 2, 0.05, pct)
        p:Slider(cfg, "alpha", "Opacity", 0.2, 1, 0.05, pct)

        p:Section("Layout")
        p:Slider(cfg, "size", "Icon size", 16, 72, 1).enabledIf = isIcons
        p:Slider(cfg, "spacing", "Spacing", 0, 24, 1)
        p:Slider(cfg, "perRow", "Per row (icons) / bars per column", 1, 40, 1)
        p:Slider(cfg, "rows", "Rows", 1, 10, 1)
        p:Dropdown(cfg, "growX", "Grow horizontally", { { "LEFT", "To the left" }, { "RIGHT", "To the right" } }).enabledIf = isIcons
        p:Dropdown(cfg, "growY", "Grow vertically", { { "DOWN", "Downwards" }, { "UP", "Upwards" } })
        p:Dropdown(cfg, "timer", "Timer position", { { "BOTTOM", "Below icon" }, { "TOP", "Above icon" }, { "CENTER", "On icon" }, { "NONE", "Hidden" } })

        p:Section("Bars")
        p:Slider(cfg, "barWidth", "Bar width", 80, 420, 5).enabledIf = isBars
        p:Slider(cfg, "barHeight", "Bar height", 10, 40, 1).enabledIf = isBars
        p:Dropdown(cfg, "barIcon", "Icon", { { "LEFT", "Left" }, { "RIGHT", "Right" }, { "NONE", "No icon" } }).enabledIf = isBars
        p:Dropdown(cfg, "barColor", "Bar colour", {
            { "TIME", "By time left (green > red)" }, { "CUSTOM", "Custom colour" },
            { "CLASS", "Class colour" }, { "TYPE", "Debuff type" } }).enabledIf = isBars
        p:Check(cfg, "showName", "Show aura name").enabledIf = isBars

        if key ~= "watch" then
            p:Section("Sorting & filtering")
            p:Dropdown(cfg, "sort", "Sort by", { { "TIME", "Time left" }, { "NAME", "Name" }, { "INDEX", "Order applied" } })
            p:Dropdown(cfg, "permanent", "Auras without a duration", { { "LAST", "Show last" }, { "FIRST", "Show first" }, { "HIDE", "Hide" } })
            p:Check(cfg, "reverse", "Reverse order")
            if key ~= "weapons" then p:Check(cfg, "onlyMine", "Only auras cast by me") end
        else
            p:Section("Watch list", "Add buffs you never want to forget - food, flasks, class buffs. A glowing reminder appears while they are missing.")
            p:Check(DB, "watchHideInCombat", "Hide reminders in combat")
            p:Check(DB, "watchOnlyResting", "Only remind in rested areas")
            p:Add(W.List("watch", "Buff to watch for, e.g. Well Fed"), 236, true)
        end

        p:Section("Position")
        p:Add(W.Button("Reset position", function()
            T.db.groups[key].point = T.CopyTable(T.defaults.groups[key].point)
            Changed()
        end))
        p:Add(W.Button(T.db.locked and "Unlock to move" or "Lock frames", function()
            T.db.locked = not T.db.locked
            Changed()
        end))
    end }
end
PAGES[#PAGES + 1] = GroupPage("buffs", "Buffs")
PAGES[#PAGES + 1] = GroupPage("debuffs", "Debuffs")
PAGES[#PAGES + 1] = GroupPage("weapons", "Weapon Enchants")
PAGES[#PAGES + 1] = GroupPage("watch", "Missing Buffs")

PAGES[#PAGES + 1] = { key = "alerts", label = "Alerts", build = function(p)
    local a = function() return T.db.alerts end
    p:Section("Expiry alerts", "An on-screen toast (and optional sound) when a long buff is about to run out or has faded. Only buffs whose timing the game shares with addons can be watched.")
    p:Check(a, "warn", "Warn before a buff expires")
    p:Slider(a, "warnAt", "Warn this long before", 5, 300, 5, secs)
    p:Check(a, "expired", "Announce when a buff expires")
    p:Slider(a, "minDuration", "Only buffs lasting at least", 0, 1800, 30, secs, "Skips short procs and cooldowns.")
    p:Check(a, "sound", "Play a sound")
    local soundItems = {}
    for _, s in ipairs(T.sounds) do soundItems[#soundItems + 1] = { s[1], s[2] } end
    p:Dropdown(a, "soundKit", "Sound", soundItems)
    p:Check(a, "chat", "Also print in chat")
    p:Newline()
    p:Add(W.Button("Preview alert", function()
        T:Toast("Interface\\Icons\\Spell_Holy_MagicalSentry", "Arcane Intellect expires in 30 sec", unpack(T.db.colors.soon))
        if T.db.alerts.sound then PlaySound(T.db.alerts.soundKit, "Master") end
    end))
end }

PAGES[#PAGES + 1] = { key = "filters", label = "Filters", build = function(p)
    p:Section("Hidden auras", "These never appear in any group. Use it for clutter such as mounts, rested XP or zone auras.")
    p:Add(W.List("hidden", "Aura name or spell ID to hide..."), 236, true)
    p:Section("Important auras", "These get a glowing, pulsing border so you notice them instantly.")
    p:Add(W.List("important", "Aura name or spell ID to highlight..."), 236, true)
end }

PAGES[#PAGES + 1] = { key = "profiles", label = "Profiles", suite = true, build = function(p)
    p:Section("Profiles", "Settings are stored in profiles. Each character picks one; share a profile between characters to keep them identical.")
    local profiles = function()
        local t = {}
        for _, name in ipairs(T:ProfileList()) do t[#t + 1] = { name, name } end
        return t
    end
    p:Add(W.Dropdown("Active profile", profiles, function() return T:ProfileName() end, function(v) T:SetProfile(v) end))
    local newBox = CreateFrame("Frame")
    newBox:SetSize(COL_W, 48)
    local label = Text(newBox, 12)
    label:SetPoint("TOPLEFT")
    label:SetText("New profile")
    local edit = StyledEditBox(newBox, COL_W - 90, 26)
    edit:SetPoint("TOPLEFT", 0, -18)
    local create = FlatButton(newBox, "Create", 80, 26, function()
        local name = strtrim(edit:GetText() or "")
        if name ~= "" then
            T:SetProfile(name)
            edit:SetText("")
            edit:ClearFocus()
        end
    end)
    create:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    edit:SetScript("OnEnterPressed", function() create:Click() end)
    function newBox:Refresh() end
    p:Add(newBox, 48)
    p:Add(W.Dropdown("Copy settings from", profiles, function() return "" end, function(v) T:CopyProfile(v) end,
        "Overwrites the active profile with a copy of the chosen one."))
    p:Add(W.Dropdown("Delete a profile", profiles, function() return "" end, function(v) T:DeleteProfile(v) end,
        "The active profile and Default cannot be deleted."))
    p:Newline()
    p:Add(W.Button("Reset active profile", function() T:ResetProfile() end, "Restores every setting in this profile to its default."))
end }

-- Appearance and profiles apply to the whole suite; the rest belong to the buffs section.
for _, def in ipairs(PAGES) do
    T:RegisterPage(def.suite and "general" or "buffs", def)
end
