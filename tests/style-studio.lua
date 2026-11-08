-- Exercise the real scene, style helpers, and settings page without a game client.
local frames, methods = {}, {}
local function Frame(_, _, parent)
    local f = setmetatable({parent=parent, shown=true, scripts={}, points={}}, {__index=function(_, key)
        return methods[key] or (key:match('^%u') and function() end)
    end})
    frames[#frames+1]=f
    return f
end
function methods:CreateTexture() return Frame(nil,nil,self) end
function methods:CreateFontString() return Frame(nil,nil,self) end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width or 1000 end
function methods:GetHeight() return self.height or 800 end
function methods:GetStringHeight() return 14 end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:SetScript(event, fn) self.scripts[event]=fn end
function methods:HookScript(event, fn)
    local old=self.scripts[event]
    self.scripts[event]=function(...) if old then old(...) end; fn(...) end
end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetShown(value) self.shown=value end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:SetParent(parent) self.parent=parent end
function methods:SetText(text) self.text=text end
function methods:GetText() return self.text end
function methods:SetFormattedText(fmt, ...) self.text=fmt:format(...) end
function methods:SetFont(path,size,outline) self.font={path,size,outline}; return true end
function methods:SetTexture(path) self.texture=path end
function methods:SetTexCoord(...) self.coords={...} end
function methods:SetStatusBarTexture(path) self.texture=path end
function methods:SetStatusBarColor(...) self.colour={...} end
function methods:SetVertexColor(...) self.colour={...} end
function methods:SetThumbTexture() self.thumb=Frame(nil,nil,self) end
function methods:GetThumbTexture() return self.thumb end
function methods:SetValue(value) self.value=value end
PlaySound=function() end
CreateFrame=Frame
UIParent=Frame()
local T={accent={0.2,0.7,1},accents={{'BLUE','Blue'}},pages={},
    db={theme='MODERN',barTexture='FLAT',font='test.ttf',fontOutline='NONE',iconZoom=.08,borderSize=1,
        accent='BLUE',colors={buffBar={.2,.6,1},debuffBar={.8,.1,.1},border={0,0,0}}}}
function T:RegisterPage(section, def) def.section=section; self.pages[#self.pages+1]=def end
function T:AccentColor() return self.accent end
function T:ApplySettings() error('scene must not apply settings') end
-- These are forbidden: opening the studio must not inspect or modify live units.
UnitHealth=function() error('must use sample health') end
UnitName=function() error('must use sample names') end
InCombatLockdown=function() return true end
assert(loadfile('Core/Style.lua'))('Tempus',T)
assert(loadfile('Config/Widgets.lua'))('Tempus',T)
assert(loadfile('Config/StyleStudio.lua'))('Tempus',T)
assert(T.pages[1].key=='style_studio' and T.pages[1].section=='general')
local page=T.UI.NewPage(UIParent)
T.pages[1].build(page)
page:Finish()
page:Refresh()
local scene=page.widgets[1]
assert(#scene.bars==9 and #scene.icons==11)
assert(scene.player.texture==T.Style.WHITE and scene.cast.colour[2]==.7)
assert(scene.labels[1].text.font[1]=='test.ttf')
local before=T.db
local count=#frames
scene.scripts.OnUpdate(scene,1)
assert(scene.elapsed==1 and scene.cast.value>30 and scene.cast.value<34)
assert(scene.buff.caption:GetText()=='23s')
assert(T.db==before and T.db.theme=='MODERN' and not T.db.testMode)
assert(#frames==count,'animation must reuse existing frames')
scene.pauseButton.scripts.OnClick(scene.pauseButton)
scene.scripts.OnUpdate(scene,1)
assert(scene.elapsed==1 and scene.pauseButton.text:GetText()=='Resume')
scene.pauseButton.scripts.OnClick(scene.pauseButton)
page.frame:Hide()
scene.scripts.OnUpdate(scene,1)
assert(scene.elapsed==1,'hidden pages do no animation work')
page.frame:Show()
scene.scripts.OnUpdate(scene,1)
assert(scene.elapsed==2)
-- Refresh must pick up a replaced profile, not capture the old table.
T.db={theme='GLOSS',barTexture='RAID',font='new.ttf',fontOutline='THICKOUTLINE',iconZoom=.15,borderSize=3,
    accent='BLUE',colors=before.colors}
scene:Refresh()
assert(scene.elapsed==2 and scene.player.texture==T.Style.BarTexture('RAID'))
assert(scene.labels[1].text.font[1]=='new.ttf' and scene.labels[1].text.font[3]=='THICKOUTLINE')
assert(scene.icons[1].gloss:IsShown() and scene.icons[1].coords==nil)
assert(scene.icons[1].art.coords[1]==.15)
assert(scene.player.tempusGloss:IsShown())
T.db.theme='FLAT'; scene:Refresh()
assert(not scene.icons[1].edge.top:IsShown() and not scene.player.tempusGloss:IsShown())
T.db.theme='CLASSIC'; scene:Refresh()
assert(scene.icons[1].art.coords[1]==0 and scene.icons[1].edge.top:IsShown())
for _,bar in ipairs(scene.bars) do assert(bar.value>=0 and bar.value<=100) end
print('PASS: Style Studio samples, appearance refresh, profile switch, pause, hidden lifecycle, and no live state writes')
