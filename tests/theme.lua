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
print('PASS: themes restyle backdrops and status bars live; coloured highlight edges survive')
