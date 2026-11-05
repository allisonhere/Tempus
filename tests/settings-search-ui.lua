-- Exercise the real widget metadata, settings window, search navigation and indexing guards.
local combat, setters, errors = false, 0, {}
local methods, frames = {}, {}
function methods:SetScript(event,fn) self.scripts[event] = fn end
function methods:EnableKeyboard(value) self.keyboard = value end
function methods:SetPropagateKeyboardInput(value) self.propagate = value end
function methods:ClearFocus() self.focused = false end
function methods:SetFocus() self.focused = true end
function methods:SetTextColor(r,g,b) self.color = {r,g,b} end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event,fn)
    local previous = self.scripts[event]
    self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
end
function methods:SetSize(w,h) self.width,self.height = w,h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width or 500 end
function methods:GetHeight() return self.height or 400 end
function methods:GetStringHeight() return 14 end
function methods:GetText() return self.text or "" end
function methods:SetText(text)
    self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:IsShown() return self.shown end
function methods:Show()
    local old = self.shown; self.shown = true
    if not old and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    local old = self.shown; self.shown = false
    if old and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(on) if on then self:Show() else self:Hide() end end
function methods:SetScrollChild(child) self.child = child end
function methods:GetScrollChild() return self.child end
function methods:SetVerticalScroll(value) self.offset = value end
function methods:GetVerticalScroll() return self.offset or 0 end
function methods:SetParent(parent) self.parent = parent end
function methods:GetRegions() return unpack(self.regions) end
local function Frame(_,name,parent)
    local frame = setmetatable({name=name,parent=parent,scripts={},regions={},shown=true}, {__index=function(_,key)
        return methods[key] or (key:match("^%u") and function() end)
    end})
    frames[#frames+1] = frame; return frame
end
function methods:CreateFontString() local value=Frame(); self.regions[#self.regions+1]=value; return value end
function methods:CreateTexture() return Frame() end
CreateFrame = Frame
UIParent = Frame(); UISpecialFrames = {}; tinsert = table.insert
wipe = function(t) for key in pairs(t) do t[key]=nil end end
function InCombatLockdown() return combat end
function PlaySound() end
local color = {.1,.2,.3,1}
local S = {WHITE="white",FONT="font",C=setmetatable({}, {__index=function() return color end}),
 CreateBorder=Frame, Accent=function(value) return value end, OnAccent=function(fn) fn() end,
 FadeIn=function() end, SetGradient=function() end}
local T = {Style=S,accent=color,moduleOrder={},modules={unitframes={enabled=true},disabled={enabled=false}},
 db={locked=true,minimap={},modules={}},version="test",pages={},
 pageSections={{key="general",label="General"},{key="unitframes",label="Unit Frames"},{key="disabled",label="Disabled module"},{key="spellpower",label="SpellPower"}},
 Layouts={Cancel=function() end}}
function T:RegisterPage(section,def) def.section=section; self.pages[#self.pages+1]=def end
function T:ProfileName() return "Default" end
function T:ModuleEnabled() return true end
function T:ReportError(err) errors[#errors+1]=err end
assert(loadfile("Config/Widgets.lua"))("Tempus",T)
assert(loadfile("Config/Search.lua"))("Tempus",T)
local built = 0
T:RegisterPage("unitframes",{key="player",label="Player",build=function(p)
    built=built+1; p:Section("Combat", "Interrupt cooldown warnings")
    for i=1,20 do p:Add(T.UI.W.Check("Filler "..i,function() return false end,function() setters=setters+1 end)) end
    p:Add(T.UI.W.Check("Enable cast bar",function() return true end,function() setters=setters+1 end,"Show interrupt cooldown"))
    p:Paragraph("Casts can also show their spell icon.")
end})
T:RegisterPage("disabled",{key="disabled",label="Disabled options",build=function() error("disabled page should not be indexed") end})
T:RegisterPage("general",{key="broken",label="Broken page",build=function() error("broken test page") end})
T:RegisterPage("general",{key="changelog",label="What's new",pinned=true,build=function() error("pinned log must not be indexed") end})
assert(loadfile("Config/Window.lua"))("Tempus",T)
local O=T.Options
O:Open()
local win
for _,f in ipairs(frames) do if f.name=="TempusOptionsFrame" then win=f end end
assert(win and win.search and not O.pages.player and setters==0)
-- Optional SpellPower remains visible and grey, with no live settings when absent.
GameTooltip={lines={},SetOwner=function() end,SetText=function(self,s) self.title=s;self.lines={} end,
    AddLine=function(self,s) self.lines[#self.lines+1]=s end,
    Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end}
local optional
for _,f in ipairs(frames) do if f.unavailable and f.arrow then optional=f end end
assert(optional and optional:IsShown() and optional.text:GetText()=="SPELLPOWER")
assert(optional.text.color[1]==.45 and optional.arrow:GetText()=="")
local current=O.current
optional.scripts.OnClick(optional,"LeftButton")
assert(O.current==current and not O.pages.spellpower)
optional.scripts.OnEnter(optional)
assert(GameTooltip.shown and optional.text.color[1]==.45)
local tooltip=table.concat(GameTooltip.lines," ")
assert(tooltip:find("spell checking",1,true) and tooltip:find("grammar",1,true))
local url="https://www.curseforge.com/wow/addons/spellpower"
assert(tooltip:find(url,1,true))
optional.scripts.OnLeave(optional); assert(not GameTooltip.shown)
optional.scripts.OnClick(optional,"RightButton")
assert(O.spellPowerLink:IsShown() and O.spellPowerLink.url:GetText()==url and O.spellPowerLink.url.focused)
O.spellPowerLink.url.scripts.OnEscapePressed(O.spellPowerLink.url)
win.scripts.OnKeyUp(win,"ESCAPE")
assert(not O.spellPowerLink:IsShown() and win:IsShown())
-- Search keeps the optional entry informational rather than building/activating it.
win.search:SetText("SpellPower")
assert(#O.searchResults==1 and O.searchResults[1].unavailable and not O.pages.spellpower)
local optionalResult
for _,f in ipairs(frames) do if f.unavailable and f.sub and f:IsShown() then optionalResult=f end end
assert(optionalResult)
optionalResult.scripts.OnClick(optionalResult,"LeftButton"); assert(O.current==current)
optionalResult.scripts.OnClick(optionalResult,"RightButton"); assert(O.spellPowerLink:IsShown())
win.scripts.OnKeyDown(win,"ESCAPE"); win.scripts.OnKeyUp(win,"ESCAPE")
assert(win:IsShown() and not O.spellPowerLink:IsShown())
O:Open("spellpower"); assert(O.current=="modules" and not O.pages.spellpower)

win.search:SetText("cast bar")
assert(built==1 and setters==0 and #errors==0,"indexing must not invoke setters or report hidden page errors")
local result
for _,r in ipairs(O.searchResults) do if r.label=="Enable cast bar" then result=r end end
assert(result and result.widget and result.y < -200)
O:OpenSearchResult(result)
assert(O.current=="player" and O.highlight:IsShown() and setters==0)
local scroll
for _,f in ipairs(frames) do if f.child==O.pages.player.frame then scroll=f end end
assert(scroll and scroll:GetVerticalScroll()>0,"search should scroll to its result")
win.search:SetText("player interrupt")
assert(#O.searchResults>0 and built==1,"repeated search reuses built pages")
win.search.scripts.OnEnterPressed(win.search); assert(O.current=="player")
win.search.scripts.OnEscapePressed(win.search)
assert(win.search:GetText()=="" and win:IsShown(),"Escape clears search without closing settings")
win.search:SetText("never matches anything"); assert(#O.searchResults==0)
O:Open("player"); assert(win.search:GetText()=="")
-- Custom frame labels join the index even when they do not use a stock widget factory.
local p=T.UI.NewPage(Frame()); p:Section("Custom")
local custom=Frame(); local label=custom:CreateFontString(); label:SetText("Custom binding")
function custom:Refresh() end
p:Add(custom,28)
assert(p.searchEntries[#p.searchEntries].label=="Custom binding")
-- In combat, only already-built content and page names are searched.
T:RegisterPage("general",{key="fresh",label="Fresh settings",build=function(page)
    built=built+1; page:Add(T.UI.W.Button("Unique new option",function() setters=setters+1 end))
end})
combat=true; win.search:SetText("unique new option")
assert(not O.pages.fresh and #O.searchResults==0)
combat=false; win.scripts.OnEvent(win,"PLAYER_REGEN_ENABLED")
assert(O.pages.fresh and #O.searchResults==1 and setters==0)
-- Explicitly opening a broken page reports its cached error once, not while searching.
O:Open("broken"); O:Open("broken"); assert(#errors==1)
print("PASS: real search UI, widget labels, scroll/highlight, caching, Escape and combat guards")

-- Escape first dismisses previews; only the next physical press closes settings.
local displayStops, sampleStops, applies = 0,0,0
T.Layouts.Cancel = function(self) self.pending = nil end
T.Display = {testMode = false, SetTestMode = function(self,on) self.testMode=on; if not on then displayStops=displayStops+1 end end}
T.GroupFrames = {UpdateTestFrames = function() sampleStops=sampleStops+1 end}
function T:ApplySettings() applies=applies+1; self.Layouts:Cancel(); O:Refresh() end
local function KeyDown(key)
    win.scripts.OnKeyDown(win,key)
    -- Model the native close binding only when the window propagates Escape.
    if key=="ESCAPE" and win.propagate then win:Hide() end
end
local function Escape()
    KeyDown("ESCAPE")
    win.scripts.OnKeyUp(win,"ESCAPE")
end
local function Open()
    win:Hide(); O:Open("modules")
    assert(win.keyboard and win.propagate and win:IsShown())
end
Open()
win.testBtn.scripts.OnClick(win.testBtn)
assert(T.Display.testMode)
KeyDown("W"); assert(win.propagate and T.Display.testMode,"ordinary keys must propagate")
Escape(); assert(not T.Display.testMode and win:IsShown() and displayStops==1)
Escape(); assert(not win:IsShown())
Open(); T.Layouts.pending={profile=T.db}
Escape(); assert(not T.Layouts.pending and win:IsShown())
Escape(); assert(not win:IsShown())
Open(); T.GroupFrames.showSamples=true
Escape(); assert(not T.GroupFrames.showSamples and sampleStops==1 and win:IsShown())
Escape(); assert(not win:IsShown())
Open(); T.db.combatpulse={test=true}
Escape(); assert(not T.db.combatpulse.test and applies==1 and win:IsShown())
Escape(); assert(not win:IsShown())
-- Unlocked sample frames are dismissed by locking, without closing the settings.
Open(); T.db.locked=false
Escape(); assert(T.db.locked and applies==2 and win:IsShown())
Escape(); assert(not win:IsShown())
-- Holding Escape cannot consume the preview and close settings through key-repeat.
Open(); T.Display.testMode=true
KeyDown("ESCAPE"); KeyDown("ESCAPE")
assert(win:IsShown() and not T.Display.testMode)
win.scripts.OnKeyUp(win,"ESCAPE")
Escape(); assert(not win:IsShown())
-- With no preview, Escape retains normal one-press closing behavior.
Open(); Escape(); assert(not win:IsShown())
-- A focused search input gives previews priority and releases focus for the next Escape.
Open(); win.search:SetText("cast bar"); win.search.focused=true; T.Display.testMode=true
win.search.scripts.OnEscapePressed(win.search)
assert(not T.Display.testMode and not win.search.focused and win.search:GetText()=="cast bar")
KeyDown("ESCAPE"); assert(win:IsShown(),"the same key must not also close the window")
win.scripts.OnKeyUp(win,"ESCAPE")
Escape(); assert(not win:IsShown())
-- Explicit close is immediate and still cleans previews; it does not re-lock editing.
Open(); T.Display.testMode=true; T.Layouts.pending={}; T.db.locked=false
win:Hide(); assert(not win:IsShown() and not T.Display.testMode and not T.Layouts.pending and not T.db.locked)
print("PASS: preview-first Escape, key-repeat, search focus, unlocked samples and explicit close")
