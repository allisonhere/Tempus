-- A self-contained sample scene. No unit events, secure buttons, or live aura state.
local _, T = ...
local UI, S = T.UI, T.Style
local Studio = {}
T.StyleStudio = Studio
local ICONS = {
    "Interface\\Icons\\Spell_Frost_FrostBolt02",
    "Interface\\Icons\\Spell_Holy_MagicalSentry",
    "Interface\\Icons\\Spell_Nature_Rejuvenation",
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    "Interface\\Icons\\Spell_Fire_Fireball02",
    "Interface\\Icons\\INV_Potion_54",
}

function Studio:CreateScene()
    local scene = CreateFrame("Frame")
    scene:SetSize(UI.COL_W * 2 + 22, 266)
    scene.searchLabel = "Style Studio sample combat scene"
    scene.searchText = "Preview unit frames buffs debuffs nameplates action bars cast bars textures fonts colours"
    S.Backdrop(scene, {fill = {0.025, 0.03, 0.04, 1}, shadow = false})
    scene.bars, scene.labels, scene.icons = {}, {}, {}
    scene.elapsed, scene.paused = 0, false

    local function Label(parent, text, size, x, y, colour)
        local fs = UI.Text(parent, size, colour)
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetText(text)
        scene.labels[#scene.labels + 1] = {text = fs, size = size}
        return fs
    end
    local function Bar(x, y, width, height, colour, text)
        local bar = S.StatusBar(scene)
        bar:SetSize(width, height)
        bar:SetPoint("TOPLEFT", x, y)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(75)
        bar.sampleColour = colour
        S.Backdrop(bar, {shadow = false})
        if text then
            bar.label = Label(bar, text, 11, 5, -3)
            bar.label:SetWidth(width - 10)
        end
        scene.bars[#scene.bars + 1] = bar
        return bar
    end
    local function Icon(x, y, size, index, caption, harmful)
        local icon = CreateFrame("Frame", nil, scene)
        icon:SetSize(size, size)
        icon:SetPoint("TOPLEFT", x, y)
        icon.art = icon:CreateTexture(nil, "ARTWORK")
        icon.art:SetAllPoints()
        icon.art:SetTexture(ICONS[index])
        icon.edge = S.CreateBorder(icon, "OVERLAY", 1)
        icon.gloss = icon:CreateTexture(nil, "OVERLAY")
        icon.gloss:SetTexture(S.WHITE)
        icon.gloss:SetPoint("TOPLEFT")
        icon.gloss:SetPoint("TOPRIGHT")
        icon.gloss:SetHeight(size / 2)
        S.SetGradient(icon.gloss, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.22)
        icon.caption = Label(icon, caption, 10, 1, -size - 2)
        icon.harmful = harmful
        scene.icons[#scene.icons + 1] = icon
        return icon
    end

    Label(scene, "SAMPLE COMBAT", 10, 12, -10, S.C.muted)
    local pause = UI.FlatButton(scene, "Pause", 72, 20, function(button)
        scene.paused = not scene.paused
        button.text:SetText(scene.paused and "Resume" or "Pause")
    end)
    pause:SetPoint("TOPRIGHT", -10, -7)
    scene.pauseButton = pause

    Label(scene, "Player & target", 10, 12, -36, S.C.muted)
    local player = Bar(12, -54, 126, 26, {0.25, 0.78, 0.42}, "Player   84%")
    local mana = Bar(12, -82, 126, 6, {0.2, 0.45, 1})
    local target = Bar(150, -54, 126, 26, {0.85, 0.22, 0.2}, "Target   62%")
    local targetPower = Bar(150, -82, 126, 6, {0.8, 0.3, 0.16})
    targetPower:SetValue(65)
    local cast = Bar(12, -97, 264, 18, "accent", "Frostbolt")

    Label(scene, "Enemy nameplate · high threat", 10, 306, -36, S.C.muted)
    Label(scene, "Training foe", 11, 320, -53)
    local plate = Bar(320, -70, 236, 16, {0.9, 0.25, 0.18})
    local enemyCast = Bar(320, -91, 236, 16, {1, 0.65, 0.15}, "Fireball · interruptible")
    Icon(320, -115, 22, 4, "8s", true)
    Icon(350, -115, 22, 3, "12s", false)

    Label(scene, "Buffs & debuffs", 10, 12, -132, S.C.muted)
    local buff = Icon(12, -150, 30, 2, "24s")
    local hot = Icon(54, -150, 30, 3, "12s")
    local debuff = Icon(96, -150, 30, 4, "8s", true)
    local aura = Bar(144, -153, 132, 18, "buffBar", "Arcane Intellect")
    local dot = Bar(144, -179, 132, 18, "debuffBar", "Shadow Word: Pain")
    scene.buff, scene.cast, scene.player = buff, cast, player

    Label(scene, "Action bar", 10, 306, -162, S.C.muted)
    for i = 1, 6 do Icon(306 + (i - 1) * 42, -181, 32, i, tostring(i)) end
    Label(scene, "Simulated data · shared appearance at sample sizes", 10, 12, -246, S.C.muted)

    function scene:Animate()
        local t = self.elapsed
        local hp = math.floor(78 + 14 * math.cos(t * 0.55))
        player:SetValue(hp)
        player.label:SetFormattedText("Player   %d%%", hp)
        mana:SetValue(60 + 25 * math.cos(t * 0.35))
        target:SetValue(62 - (t * 3) % 45)
        target.label:SetFormattedText("Target   %d%%", 62 - (t * 3) % 45)
        plate:SetValue(62 - (t * 3) % 45)
        cast:SetValue((t % 3) / 3 * 100)
        cast.label:SetFormattedText("Frostbolt   %.1fs", 3 - t % 3)
        enemyCast:SetValue((t % 4) / 4 * 100)
        local remaining = 24 - math.floor(t % 24)
        buff.caption:SetFormattedText("%ds", remaining)
        hot.caption:SetFormattedText("%ds", 12 - math.floor(t % 12))
        debuff.caption:SetFormattedText("%ds", 8 - math.floor(t % 8))
        self.icons[1].caption:SetText(debuff.caption:GetText())
        self.icons[2].caption:SetText(hot.caption:GetText())
        aura:SetValue(remaining / 24 * 100)
        dot:SetValue((8 - t % 8) / 8 * 100)
    end
    function scene:Refresh()
        local db = T.db
        for _, item in ipairs(self.labels) do S.ApplyFont(item.text, item.size) end
        for _, bar in ipairs(self.bars) do
            local texture = S.BarTexture(db.barTexture)
            bar:SetStatusBarTexture(texture)
            bar.bg:SetTexture(texture)
            local c = bar.sampleColour
            if type(c) == "string" then c = c == "accent" and T.accent or db.colors[c] end
            bar:SetStatusBarColor(c[1], c[2], c[3])
            bar:RefreshTheme()
            bar.tempusBackdrop:Refresh()
        end
        for _, icon in ipairs(self.icons) do
            local zoom = db.theme == "CLASSIC" and 0 or (db.iconZoom or 0.08)
            icon.art:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
            local colour = db.colors[icon.harmful and "debuffBar" or "border"]
            icon.edge:SetThickness(db.theme == "CLASSIC" and 2 or (db.borderSize or 1), icon)
            icon.edge:SetColor(colour[1], colour[2], colour[3], 1)
            icon.edge:SetShown(db.theme ~= "FLAT")
            icon.gloss:SetShown(db.theme == "GLOSS")
        end
        self:Animate()
    end
    -- Only visible scenes advance. Keep the clock local; opening/searching never
    -- enables module test modes or writes fake values into live frames or the DB.
    scene:SetScript("OnUpdate", function(self, delta)
        if self.paused or not self:IsShown() then return end
        self.elapsed = self.elapsed + delta
        self.tick = (self.tick or 0) + delta
        if self.tick < 0.05 then return end
        self.tick = 0
        self:Animate()
    end)
    return scene
end

-- The one page for the suite's shared look: a live sample scene, then every shared appearance control.
-- Buff-only text sizes and colours live under Buffs & Debuffs > Look.
T:RegisterPage("general", {key = "style_studio", label = "Style Studio", order = 2, build = function(p)
    local W, DB = UI.W, UI.DB
    p:Section("Style Studio", "Your shared look on a sample combat scene. Changes save immediately and show in the scene at once.")
    p:Add(Studio:CreateScene(), 266, true)

    p:Section("Style")
    p:Add(W.Dropdown("Accent colour", function()
        local t = {}
        for _, a in ipairs(T.accents) do
            local c = T:AccentColor(a[1])
            t[#t + 1] = { a[1], ("|cff%02x%02x%02x%s|r"):format(c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5, a[2]) }
        end
        return t
    end, function() return DB().accent end, function(v)
        DB().accent = v   -- the dropdown itself calls Changed()
    end, "Highlights, selected tabs, target glows and headers. The settings window, bags and move boxes recolour at once; some Blizzard skins need a reload.", "accent"))
    p:Add(W.Button("Reload UI", function() ReloadUI() end, "Recolours everything, including the parts that do not change live."))
    p:Check(DB, "useSecond", "Second colour", "A second colour for the settings window, next to the accent: the selected-page marker, ticked checkboxes, slider fills and the lines beside section titles.")
    p:Color(DB, "secondColor", "Pick second colour")
    p:Check(DB, "combatAccent", "Combat colour", "The accent switches to its own colour while you are in combat, so the whole interface shows when a fight starts.")
    p:Color(DB, "combatColor", "Combat accent")
    p:Dropdown(DB, "theme", "Theme", {
        { "TEMPUS", "Tempus - accent edge & soft glow" }, { "MODERN", "Modern - crisp border & shadow" }, { "GLOSS", "Gloss - glassy highlight" },
        { "CLASSIC", "Classic - Blizzard look" }, { "FLAT", "Flat - borderless" } })
    p:Dropdown(DB, "barTexture", "Bar texture", S.barTextures)
    p:Slider(DB, "borderSize", "Border thickness", 0, 4, 1, nil, "Thickness of the edge around icons and bars. 0 hides it.")
    p:Slider(DB, "iconZoom", "Icon crop", 0, 0.2, 0.01, UI.pct, "Trims the edges of spell and item icons. Higher values hide more of Blizzard's icon border.")
    p:Check(DB, "animate", "Animations", "Windows fade in; low health, ready cooldowns and dispellable debuffs pulse.")

    p:Section("Text")
    p:Dropdown(DB, "font", "Font", S.fonts)
    p:Dropdown(DB, "fontOutline", "Outline", { { "NONE", "None (shadow)" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" } })
end})
