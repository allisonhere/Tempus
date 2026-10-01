-- Tempus UI: the shared look. Every module draws its panels, borders, text and bars here.
local _, T = ...

local S = {}
T.Style = S

S.WHITE = "Interface\\Buttons\\WHITE8X8"
S.FONT = "Fonts\\FRIZQT__.TTF"
S.accent = T.accent

-- Palette of the settings window; modules reuse it so the whole UI reads as one piece.
S.C = {
    bg      = { 0.047, 0.054, 0.068, 0.97 },
    panel   = { 0.06, 0.068, 0.085, 0.92 },
    side    = { 0.065, 0.073, 0.092, 1 },
    card    = { 0.10, 0.11, 0.135, 1 },
    cardHi  = { 0.13, 0.145, 0.175, 1 },
    line    = { 1, 1, 1, 0.07 },
    edge    = { 0, 0, 0, 1 },
    text    = { 0.9, 0.92, 0.95 },
    muted   = { 0.55, 0.6, 0.68 },
}

S.barTextures = {
    { "SMOOTH", "Smooth", "Interface\\TargetingFrame\\UI-StatusBar" },
    { "FLAT", "Flat", S.WHITE },
    { "RAID", "Raid", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { "SKILL", "Skill", "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
}

function S.BarTexture(key)
    for _, t in ipairs(S.barTextures) do
        if t[1] == key then return t[3] end
    end
    return S.barTextures[1][3]
end

S.fonts = {
    { "Fonts\\FRIZQT__.TTF", "Friz Quadrata" }, { "Fonts\\ARIALN.TTF", "Arial Narrow" },
    { "Fonts\\MORPHEUS.TTF", "Morpheus" }, { "Fonts\\SKURRI.TTF", "Skurri" },
}

-- One physical screen pixel in UIParent units, for crisp 1px lines at any UI scale.
function S.Pixel()
    local _, h = GetPhysicalScreenSize()
    local scale = UIParent:GetEffectiveScale()
    if not h or h == 0 or not scale or scale == 0 then return 1 end
    return 768 / h / scale
end

----------------------------------------------------------------------------------------
-- Primitives
----------------------------------------------------------------------------------------
function S.CreateBorder(parent, layer, sublevel)
    local border = { parent = parent }
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        local t = parent:CreateTexture(nil, layer or "OVERLAY", nil, sublevel or 5)
        t:SetTexture(S.WHITE)
        t.tempus = true         -- skins never strip Tempus's own art
        border[side] = t
    end
    function border:SetThickness(n, target)
        target = target or self.parent
        local t, b, l, r = self.top, self.bottom, self.left, self.right
        for _, tex in ipairs({ t, b, l, r }) do tex:ClearAllPoints() end
        t:SetPoint("TOPLEFT", target, "TOPLEFT", -n, n); t:SetPoint("TOPRIGHT", target, "TOPRIGHT", n, n); t:SetHeight(n)
        b:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -n, -n); b:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", n, -n); b:SetHeight(n)
        l:SetPoint("TOPLEFT", target, "TOPLEFT", -n, 0); l:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -n, 0); l:SetWidth(n)
        r:SetPoint("TOPRIGHT", target, "TOPRIGHT", n, 0); r:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", n, 0); r:SetWidth(n)
    end
    -- A 1px line just inside the target instead of around it.
    function border:SetInside(target)
        target = target or self.parent
        local t, b, l, r = self.top, self.bottom, self.left, self.right
        for _, tex in ipairs({ t, b, l, r }) do tex:ClearAllPoints() end
        t:SetPoint("TOPLEFT", target, "TOPLEFT", 1, -1); t:SetPoint("TOPRIGHT", target, "TOPRIGHT", -1, -1); t:SetHeight(1)
        b:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", 1, 1); b:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -1, 1); b:SetHeight(1)
        l:SetPoint("TOPLEFT", target, "TOPLEFT", 1, -2); l:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", 1, 2); l:SetWidth(1)
        r:SetPoint("TOPRIGHT", target, "TOPRIGHT", -1, -2); r:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -1, 2); r:SetWidth(1)
    end
    function border:SetColor(r, g, b, a)
        for _, tex in ipairs({ self.top, self.bottom, self.left, self.right }) do tex:SetVertexColor(r, g, b, a or 1) end
    end
    function border:SetShown(shown)
        for _, tex in ipairs({ self.top, self.bottom, self.left, self.right }) do tex:SetShown(shown) end
    end
    return border
end

function S.SetGradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    if CreateColor and pcall(tex.SetGradient, tex, orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)) then
        return
    end
    if tex.SetGradientAlpha then tex:SetGradientAlpha(orientation, r1, g1, b1, a1, r2, g2, b2, a2) end
end

function S.Tex(parent, layer, color, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetTexture(S.WHITE)
    if color then t:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
    return t
end

function S.Text(parent, size, color, flags, font)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or S.FONT, size or 12, flags or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    color = color or S.C.text
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetJustifyH("LEFT")
    return fs
end

-- Font from the active profile, with outline handling and a safe fallback.
function S.ApplyFont(fs, size, font, outline)
    local db = T.db or {}
    outline = outline or db.fontOutline or "OUTLINE"
    if outline == "NONE" then outline = "" end
    if not fs:SetFont(font or db.font or S.FONT, size, outline) then
        fs:SetFont(S.FONT, size, outline)
    end
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
end

----------------------------------------------------------------------------------------
-- Themes. T.db.theme (MODERN | GLOSS | CLASSIC | FLAT) restyles every Backdrop and
-- StatusBar through one registry, live, with no reload:
--   MODERN  crisp 1px edge, soft shadow, faint inner line
--   GLOSS   Modern plus a glassy highlight over the top half
--   CLASSIC thicker warm Blizzard-style border, no shadow or inner line
--   FLAT    no shadow, inner line or decorative edge
-- An edge a module has coloured on purpose (class, dispel, target highlight) always stays
-- visible, so a functional highlight never disappears with the theme.
----------------------------------------------------------------------------------------
function S.Theme()
    local theme = T.db and T.db.theme
    if theme == "GLOSS" or theme == "CLASSIC" or theme == "FLAT" then return theme end
    return "MODERN"
end

S.backdrops = setmetatable({}, { __mode = "k" })
S.statusBars = setmetatable({}, { __mode = "k" })

local CLASSIC_EDGE = { 0.62, 0.52, 0.32 }

local function IsNeutral(c)
    return c[1] <= 0.05 and c[2] <= 0.05 and c[3] <= 0.05
end

function S.ApplyTheme()
    for frame in pairs(S.backdrops) do
        if frame.tempusBackdrop then frame.tempusBackdrop:Refresh() end
    end
    for bar in pairs(S.statusBars) do
        if bar.tempusGloss then bar:RefreshTheme() end
    end
end

-- The signature panel: dark fill, 1px black edge, soft outer shadow, optional inner line.
-- Returns a handle so callers can recolour the edge (e.g. class or dispel colours).
function S.Backdrop(frame, opts)
    opts = opts or {}
    if frame.tempusBackdrop then return frame.tempusBackdrop end
    local h = { frame = frame, edgeColor = { 0, 0, 0, 1 }, hidden = false,
        wantShadow = opts.shadow ~= false, wantInner = opts.inner ~= false }
    local fill = opts.fill or S.C.panel
    h.shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    h.shadow:SetTexture(S.WHITE)
    h.shadow.tempus = true
    h.shadow:SetPoint("TOPLEFT", -3, 3)
    h.shadow:SetPoint("BOTTOMRIGHT", 3, -3)
    h.shadow:SetVertexColor(0, 0, 0, 0.45)
    h.fill = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    h.fill:SetTexture(S.WHITE)
    h.fill.tempus = true
    h.fill:SetAllPoints(frame)
    h.fill:SetVertexColor(fill[1], fill[2], fill[3], fill[4] or 1)
    h.edge = S.CreateBorder(frame, "BACKGROUND", -6)
    h.edge:SetThickness(1, frame)
    h.thickness = 1
    h.edge:SetColor(0, 0, 0, 1)
    if h.wantInner then
        h.inner = S.CreateBorder(frame, "BORDER", -8)
        h.inner:SetInside(frame)
        h.inner:SetColor(1, 1, 1, 0.06)
    end
    h.gloss = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    h.gloss:SetTexture(S.WHITE)
    h.gloss.tempus = true
    h.gloss:SetPoint("TOPLEFT", frame)
    h.gloss:SetPoint("TOPRIGHT", frame)
    h.gloss:SetPoint("BOTTOM", frame, "CENTER")
    S.SetGradient(h.gloss, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.12)
    h.gloss:Hide()

    function h:Refresh()
        local theme = S.Theme()
        local c = self.edgeColor
        local functional = not IsNeutral(c)
        local shown = not self.hidden
        self.fill:SetShown(shown)
        self.shadow:SetShown(shown and self.wantShadow and (theme == "MODERN" or theme == "GLOSS"))
        if self.inner then self.inner:SetShown(shown and (theme == "MODERN" or theme == "GLOSS")) end
        self.gloss:SetShown(shown and theme == "GLOSS")
        local edgeShown = shown and (theme ~= "FLAT" or functional)
        self.edge:SetShown(edgeShown)
        local thickness = theme == "CLASSIC" and 2 or 1
        if self.thickness ~= thickness then
            self.thickness = thickness
            self.edge:SetThickness(thickness, self.frame)
        end
        if theme == "CLASSIC" then
            if functional then
                self.edge:SetColor(c[1], c[2], c[3], c[4])
            else
                self.edge:SetColor(CLASSIC_EDGE[1], CLASSIC_EDGE[2], CLASSIC_EDGE[3], 1)
            end
        else
            self.edge:SetColor(c[1], c[2], c[3], c[4])
        end
    end
    function h:SetEdgeColor(r, g, b, a)
        self.edgeColor[1], self.edgeColor[2], self.edgeColor[3], self.edgeColor[4] = r, g, b, a or 1
        self:Refresh()
    end
    function h:SetFillColor(r, g, b, a) self.fill:SetVertexColor(r, g, b, a or 1) end
    function h:SetShown(shown)
        self.hidden = not shown
        self:Refresh()
    end
    frame.tempusBackdrop = h
    S.backdrops[frame] = true
    h:Refresh()
    return h
end

-- A styled status bar with background, used by unit frames, cast bars and the info bar.
function S.StatusBar(parent, texture)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(S.BarTexture(texture or (T.db and T.db.barTexture)))
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetTexture(S.BarTexture(texture or (T.db and T.db.barTexture)))
    bar.bg:SetVertexColor(0.08, 0.09, 0.11, 0.9)
    -- Glassy highlight for the Gloss theme, over the top half of the bar.
    bar.tempusGloss = bar:CreateTexture(nil, "OVERLAY", nil, 6)
    bar.tempusGloss:SetTexture(S.WHITE)
    bar.tempusGloss.tempus = true
    bar.tempusGloss:SetPoint("TOPLEFT", bar)
    bar.tempusGloss:SetPoint("TOPRIGHT", bar)
    bar.tempusGloss:SetPoint("BOTTOM", bar, "CENTER")
    S.SetGradient(bar.tempusGloss, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.16)
    function bar:RefreshTheme() self.tempusGloss:SetShown(S.Theme() == "GLOSS") end
    S.statusBars[bar] = true
    bar:RefreshTheme()
    return bar
end

function S.ClassColor(class)
    local cc = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
    if cc then return cc.r, cc.g, cc.b end
    return 0.6, 0.6, 0.6
end

----------------------------------------------------------------------------------------
-- The one hidden parent for Blizzard frames Tempus replaces. Edit Mode and managed
-- containers call layout methods on a frame's parent (Layout, MarkDirty,
-- CheckForLayoutChange...); a plain hidden frame lacks them and errors. Unknown
-- method-style names (Capitalised) answer with a no-op; fields stay nil.
----------------------------------------------------------------------------------------
do
    local hp = CreateFrame("Frame", "TempusHiddenParent", UIParent)
    hp:Hide()
    local mt = getmetatable(hp)
    local methods = mt and mt.__index
    local nop = function() end
    if type(methods) == "table" then
        pcall(setmetatable, hp, {
            __index = function(_, k)
                local v = methods[k]
                if v ~= nil then return v end
                if type(k) == "string" and k:find("^%u") then return nop end
            end,
        })
    end
    S.HiddenParent = hp
end

