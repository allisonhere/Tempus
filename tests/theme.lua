local function stub()
    local o = {shown = true}
    function o:SetShown(v) self.shown = v and true or false end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:CreateTexture() return stub() end
    function o:SetVertexColor(r, g, b, a) self.color = {r, g, b, a} end
    return setmetatable(o, {__index = function(_, k) if k:match('^%u') then return function() end end end})
end
CreateFrame = function() return stub() end
UIParent = stub()
local T = {accent = {0, 0.7, 1}, db = {theme = 'MODERN'}}
assert(loadfile('Core/Style.lua'))('Tempus', T)
local S = T.Style
local plain, glowing = stub(), stub()
local a = S.Backdrop(plain)
local b = S.Backdrop(glowing)
b:SetEdgeColor(0, 0.7, 1)
assert(a.edge.top.shown and a.shadow.shown and not a.gloss.shown and a.thickness == 1)
T.db.theme = 'FLAT'; S.ApplyTheme()
assert(not a.edge.top.shown and not a.shadow.shown and not a.inner.top.shown, 'flat hides decoration')
assert(b.edge.top.shown, 'a coloured highlight edge survives flat')
T.db.theme = 'GLOSS'; S.ApplyTheme()
assert(a.gloss.shown and a.shadow.shown and a.edge.top.shown)
T.db.theme = 'CLASSIC'; S.ApplyTheme()
assert(a.thickness == 2 and not a.shadow.shown and not a.inner.top.shown and a.edge.top.shown and not a.gloss.shown)
T.db.theme = 'bogus'; S.ApplyTheme()
assert(S.Theme() == 'MODERN' and a.thickness == 1 and a.shadow.shown)
a:SetShown(false)
assert(not a.fill.shown and not a.edge.top.shown)
local bar = S.StatusBar(stub())
T.db.theme = 'GLOSS'; S.ApplyTheme()
assert(bar.tempusGloss.shown)
T.db.theme = 'FLAT'; S.ApplyTheme()
assert(not bar.tempusGloss.shown)
-- Tempus theme: accent-tinted edge and glow on neutral panels; a functional edge keeps its colour.
T.Num = function(v) return type(v) == 'number' end
local edgeColor = function(h) return h.edge.top.color end
T.db.theme = 'TEMPUS'; S.ApplyTheme()
assert(S.Theme() == 'TEMPUS' and S.Modern())
assert(a.shadow.shown == false, 'hidden panel stays hidden')
a:SetShown(true)
assert(a.shadow.shown and a.inner.top.shown and a.sheen.shown and a.glow.shown and not a.gloss.shown)
assert(math.abs(edgeColor(a)[2] - 0.7 * 0.8) < 1e-6 and edgeColor(a)[4] == 0.35, 'neutral edge takes the accent tint')
assert(a.glow.color[2] == 0.7, 'glow follows the accent')
assert(edgeColor(b)[2] == 0.7 and edgeColor(b)[4] == 1, 'functional edge keeps its colour')
T.accent[1], T.accent[2], T.accent[3] = 1, 0.2, 0.2
S.RefreshAccent()
assert(a.glow.color[2] == 0.2 and math.abs(edgeColor(a)[1] - 0.8) < 1e-6, 'an accent change repaints the Tempus edge and glow')
assert(bar.tempusShade.shown and not bar.tempusGloss.shown, 'Tempus bars get the leading-edge shade')
T.db.theme = 'MODERN'; S.ApplyTheme()
assert(not a.glow.shown and not a.sheen.shown and edgeColor(a)[4] == 1)

-- Motion helpers do nothing harmful on a client without bar interpolation.
assert(S.SMOOTH == nil and S.LagBar(bar) == nil, 'no interpolation: no lag bar')
local set
bar.SetValue = function(_, v, mode) set = { v, mode } end
S.SetBar(bar, 40, true, true)
assert(set[1] == 40 and set[2] == nil, 'plain SetValue without interpolation')

print('PASS: themes restyle backdrops and status bars live; coloured highlight edges survive')
