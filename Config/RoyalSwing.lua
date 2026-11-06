-- Royal Swing Timer settings composition. All controls reuse the original widget
-- bindings and ApplySettings path; artwork never changes combat state.
local _, T = ...
local UI, S = T.UI, T.Style
local R = {}
UI.RoyalSwing = R
local ROOT = "Interface\\AddOns\\Tempus\\media\\royal\\"
local GOLD = {0.78, 0.59, 0.34, 1}
local PALE = {0.94, 0.82, 0.63}
local MUTED = {0.67, 0.65, 0.73}
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Tex(parent, layer, c)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(WHITE)
    if c then t:SetVertexColor(c[1], c[2], c[3], c[4] or 1) end
    return t
end
local function Label(parent, content, size, color, font)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont(font or S.FONT, size or 12, "")
    f:SetTextColor(unpack(color or PALE))
    f:SetShadowOffset(1,-1)
    f:SetShadowColor(0,0,0,0.9)
    f:SetText(content)
    f:SetJustifyH("LEFT")
    return f
end
local function Art(parent, file, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(ROOT .. file)
    return t
end
local function Card(parent, x, y, w, h, title, symbol)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w,h)
    f:SetPoint("TOPLEFT",x,y)
    local bg = Art(f, "panel", "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetVertexColor(0.96,0.92,1,0.94)
    local rim = Art(f, "frame", "BORDER")
    rim:SetAllPoints(f)
    if rim.SetTextureSliceMargins then
        pcall(rim.SetTextureSliceMargins, rim, 30,30,30,30)
        if rim.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
            pcall(rim.SetTextureSliceMode, rim, Enum.UITextureSliceMode.Stretched)
        end
    end
    local titleBg = Tex(f,"ARTWORK",{0.19,0.12,0.23,0.9})
    titleBg:SetPoint("TOPLEFT",5,-5)
    titleBg:SetPoint("TOPRIGHT",-5,-5)
    titleBg:SetHeight(29)
    local divider = Tex(f,"ARTWORK",GOLD)
    divider:SetPoint("TOPLEFT",9,-33)
    divider:SetPoint("TOPRIGHT",-9,-33)
    divider:SetHeight(1)
    local label = Label(f, title, 13, PALE, "Fonts\\FRIZQT__.TTF")
    label:SetPoint("TOPLEFT",42,-12)
    local icon = Label(f, symbol or "", 12, GOLD, "Fonts\\FRIZQT__.TTF")
    icon:SetPoint("TOPLEFT",19,-12)
    local iconRule = Tex(f, "ARTWORK", {0.92, 0.73, 0.44, 0.52})
    iconRule:SetSize(14,1)
    iconRule:SetPoint("TOPLEFT",17,-27)
    -- Light catches the inner bezel; content retains room to breathe.
    local sheen = Tex(f,"BORDER",{0.98,0.79,0.49,0.11})
    sheen:SetPoint("TOPLEFT",10,-37)
    sheen:SetPoint("TOPRIGHT",-10,-37)
    sheen:SetHeight(1)
    return f
end
local function Place(page, widget, x, y, width)
    -- Preserve UI.NewPage's widget registry for Refresh and settings search.
    page:Add(widget, widget:GetHeight())
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", page.frame, "TOPLEFT", x,y)
    if width then widget:SetWidth(width) end
    local e = page.searchEntries[#page.searchEntries]
    if e and e.widget == widget then e.y = y end
    return widget
end
local function DecorativeBar(parent,x,y,w,progress)
    -- Engraved, multi-layer timeline with the cue rendered as a gold needle.
    local surround=Tex(parent,"ARTWORK",{0.65,0.47,0.28,0.90})
    surround:SetSize(w,12)
    surround:SetPoint("TOPLEFT",x,y)
    local bg=Tex(parent,"ARTWORK",{0.046,0.029,0.063,1})
    bg:SetPoint("TOPLEFT",surround,"TOPLEFT",2,-2)
    bg:SetPoint("BOTTOMRIGHT",surround,"BOTTOMRIGHT",-2,2)
    local fill=Tex(parent,"OVERLAY",{0.58,0.28,0.83,1})
    fill:SetSize((w-6)*progress,6)
    fill:SetPoint("LEFT",bg,"LEFT",2,0)
    local sheen=Tex(parent,"OVERLAY",{0.98,0.74,1,0.34})
    sheen:SetHeight(1)
    sheen:SetPoint("TOPLEFT",fill,"TOPLEFT",0,0)
    sheen:SetPoint("TOPRIGHT",fill,"TOPRIGHT",0,0)
    for i=1,9 do
        local tick=Tex(parent,"OVERLAY",{0.84,0.66,0.42,0.40})
        tick:SetSize(1,i==5 and 7 or 4)
        tick:SetPoint("TOPLEFT",surround,"BOTTOMLEFT",i*w/10,1)
    end
    local glow=Tex(parent,"OVERLAY",{1,0.64,0.19,0.12})
    glow:SetSize(12,24)
    glow:SetPoint("CENTER",surround,"LEFT",w*progress,0)
    local mark=Tex(parent,"OVERLAY",{1,0.83,0.43,1})
    mark:SetSize(2,20)
    mark:SetPoint("CENTER",surround,"LEFT",w*progress,0)
    return surround
end
function R.Build(page)
    local root=page.frame
    root:SetWidth(630)
    page.searchSection="Swing timer"
    page.searchEntries[#page.searchEntries+1]={label="Swing timer",text="Auto attack timing and weapon swing display",y=-8}
    local hero = CreateFrame("Frame",nil,root)
    hero:SetSize(610,98)
    hero:SetPoint("TOPLEFT",10,-7)
    local banner=Art(hero,"hero","BACKGROUND")
    banner:SetAllPoints()
    local emblem=Art(hero,"emblem","OVERLAY")
    emblem:SetSize(67,67);emblem:SetPoint("LEFT",8,-2)
    local headline=Label(hero,"Swing Timer",27,{0.98,0.89,0.80}, "Fonts\\FRIZQT__.TTF")
    headline:SetPoint("TOPLEFT",77,-10)
    local tagline=Label(hero,"PRECISION  /  AUTO ATTACK TRACKING",9,GOLD)
    tagline:SetPoint("TOPLEFT",79,-44)
    local info=Label(hero,"Track weapon swings and time your next attack.\nConfigure each bar below; unlock to position it.",11,MUTED)
    info:SetPoint("TOPLEFT",79,-60)
    info:SetWidth(345)
    local dial=Art(hero,"dial","ARTWORK")
    dial:SetSize(130,130)
    dial:SetPoint("RIGHT",hero,"RIGHT",-8,0)
    local dialNumber=Label(hero,"0.40s",19,{1.0,0.90,0.77},"Fonts\\FRIZQT__.TTF")
    dialNumber:SetPoint("CENTER",dial,"CENTER",0,-2)
    local dialCaption=Label(hero,"SWING CYCLE",8,GOLD)
    dialCaption:SetPoint("TOP",dialNumber,"BOTTOM",0,-4)
    local left = Card(root,10,-111,296,156,"DISPLAY","I")
    local right= Card(root,316,-111,296,156,"WEAPON OPTIONS","II")
    local timing=Card(root,10,-276,296,169,"TIMING","III")
    local layout=Card(root,316,-276,296,184,"LAYOUT","IV")
    local cfg=function() return T.db.swing end
    local function check(key,label,x,y)
        local w=UI.W.Check(label,function() return cfg()[key] end,function(v)cfg()[key]=v end)
        return Place(page,w,x,y,255)
    end
    check("enabled","Show swing timer",25,-154)
    check("showTime","Show time remaining",25,-188)
    check("ranged","Ranged weapon bar",25,-222)
    check("offHand","Off-hand bar (dual wield)",331,-154)
    local hint=Label(right,"Select when the swing display is visible.",10,MUTED)
    hint:SetPoint("TOPLEFT",15,-83)
    local dd=UI.W.Dropdown("Visibility",{{"COMBAT","In combat"},{"ALWAYS","Always"}},function()return cfg().visibility end,function(v)cfg().visibility=v end)
    Place(page,dd,331,-208,252)
    -- Timing art is a visual preview only. It never claims to represent a live countdown.
    local chartTitle=Label(timing,"EXAMPLE SWING CYCLE",9,GOLD)
    chartTitle:SetPoint("TOPLEFT",16,-48)
    DecorativeBar(timing,17,-73,259,0.69)
    local indicator=Label(timing,"0.4s",20,{0.98,0.90,0.78})
    indicator:SetPoint("TOPLEFT",18,-108)
    local micro=Label(timing,"Ready cue  •  next auto attack",10,MUTED)
    micro:SetPoint("TOPLEFT",79,-113)
    local note=Label(timing,"Actual timing is calculated by the Swing module.",9,MUTED)
    note:SetPoint("TOPLEFT",18,-143)
    local function slider(key,title,low,high,step,x,y)
        local w=UI.W.Slider(title,low,high,step,function()return cfg()[key] end,function(v)cfg()[key]=v end)
        return Place(page,w,x,y,260)
    end
    slider("width","Width",80,400,1,331,-318)
    slider("height","Height",4,30,1,331,-366)
    slider("spacing","Spacing",0,12,1,331,-414)
    local preview=CreateFrame("Frame",nil,root)
    preview:SetSize(602,60);preview:SetPoint("TOPLEFT",14,-469)
    local bg=Art(preview,"panel","BACKGROUND");bg:SetAllPoints()
    local edge=Art(preview,"frame","BORDER");edge:SetAllPoints()
    if edge.SetTextureSliceMargins then pcall(edge.SetTextureSliceMargins, edge, 30,30,30,30) end
    local t=Label(preview,"S W I N G   T I M E L I N E    •    P R E V I E W",10,GOLD)
    t:SetPoint("TOP",0,-9)
    DecorativeBar(preview,23,-31,375,0.72)
    -- Use native color swatches instead of font-dependent square glyphs.
    -- Explicit vertical placement prevents line collisions at small UI scales.
    local legendA=Tex(preview,"OVERLAY",{0.67,0.35,0.94,1})
    legendA:SetSize(9,9)
    legendA:SetPoint("TOPLEFT",414,-29)
    local legendTextA=Label(preview,"Progress",10,PALE)
    legendTextA:SetPoint("LEFT",legendA,"RIGHT",7,0)
    local legendB=Tex(preview,"OVERLAY",{0.96,0.73,0.34,1})
    legendB:SetSize(9,9)
    legendB:SetPoint("TOPLEFT",502,-29)
    local legendTextB=Label(preview,"Cue",10,PALE)
    legendTextB:SetPoint("LEFT",legendB,"RIGHT",7,0)
    local legendC=Tex(preview,"OVERLAY",{0.70,0.18,0.21,1})
    legendC:SetSize(9,9)
    legendC:SetPoint("TOPLEFT",414,-43)
    local legendTextC=Label(preview,"Out of range",10,PALE)
    legendTextC:SetPoint("LEFT",legendC,"RIGHT",7,0)
    page.y=-548
    page.col=0
    page.rowH=0
end
