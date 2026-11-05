-- Build the real page and exercise each rule setter to catch loop/callback mistakes.
local T = {defaults={},db={locked=true},Movers={list={}},UI={COL_W=280,W={}}}
function InCombatLockdown() return false end
function CreateFrame()
    return {RegisterEvent=function() end,SetScript=function() end,SetSize=function() end}
end
T.UI.Text=function() return {SetAllPoints=function() end,SetJustifyV=function() end,SetText=function(self,s) self.text=s end} end
local function Widget(label,get,set)
    local w={label=label,get=get,set=set}
    function w:Refresh() if get then self.value=get() end end
    return w
end
T.UI.W.Check=function(label,get,set) return Widget(label,get,set),24 end
T.UI.W.Dropdown=function(label,items,get,set) local w=Widget(label,get,set);w.items=items;return w,48 end
T.UI.W.Button=function(label,click) local w=Widget(label);w.click=click;return w,28 end
local build
function T:RegisterPage(_,def) assert(def.key=="auto_layouts");build=def.build end
assert(loadfile("Core/Layouts.lua"))("Tempus",T)
assert(loadfile("Core/AutoLayouts.lua"))("Tempus",T)
assert(loadfile("Config/AutoLayouts.lua"))("Tempus",T)
local widgets={}
local p={Section=function() end,Newline=function() end}
function p:Add(w,height) assert(height and height>0);widgets[w.label or "status"]=w;w:Refresh() end
build(p)
widgets["Enable automatic layout switching"].set(true)
assert(T.AutoLayouts:Config().enabled)
widgets["Pause automatic switching (manual override)"].set(true)
assert(T.AutoLayouts:Config().paused)
for _,pair in ipairs({{"Solo layout","solo"},{"Party layout","party"},{"Raid layout","raid"}}) do
    local w=widgets[pair[1]];assert(w.items()[1][1]=="")
    w.set(pair[2].." preset"); assert(w.get()==pair[2].." preset")
end
local cfg=T.AutoLayouts:Config()
assert(cfg.solo=="solo preset" and cfg.party=="party preset" and cfg.raid=="raid preset")
widgets["Reapply current group layout"].click()
print("PASS: automatic layout settings and independent solo/party/raid assignments")
