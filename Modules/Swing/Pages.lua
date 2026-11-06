-- Tempus UI: settings page for the swing timer.
local _, T = ...

-- A labelled drawing of the swing bar for the settings page: each part of the bar with a
-- line to a short note on what it means. Frozen at a moment inside the cue window.
local DIAGRAM_W, DIAGRAM_H = 586, 172
local BAR_W, BAR_H = 420, 16
local FILL, CUE = 0.88, 0.84            -- how far the swing is, where the cue tick sits

local function SwingDiagram()
    local UI, S, SW = T.UI, T.Style, T.Swing
    local Tex, Text, C = UI.Tex, UI.Text, S.C
    local gold = SW and SW.CUE_COLOR or { 1, 0.82, 0.2 }
    local red = SW and SW.OUT_OF_RANGE or { 0.85, 0.2, 0.2 }
    local f = CreateFrame("Frame")
    f:SetSize(DIAGRAM_W, DIAGRAM_H)
    function f:Refresh() end

    local function Bar(y, h, fill, color, alpha)
        local back = Tex(f, "BACKGROUND", { 0, 0, 0, 0.6 })
        back:SetPoint("TOPLEFT", 0, y)
        back:SetSize(BAR_W, h)
        local fg = Tex(f, "ARTWORK", { color[1], color[2], color[3], alpha or 1 })
        fg:SetPoint("TOPLEFT", back, "TOPLEFT", 1, -1)
        fg:SetSize((BAR_W - 2) * fill, h - 2)
        return back
    end
    -- A note joined by a thin line to the point x on the bar edge at edgeY. The note sits
    -- at textY, above the bar when textY is higher, below it otherwise; align says whether
    -- the note starts at the line (LEFT) or ends at it (RIGHT).
    local function Callout(x, edgeY, textY, text, color, align)
        local line = Tex(f, "OVERLAY", { 1, 1, 1, 0.3 })
        line:SetWidth(1)
        line:SetPoint("TOPLEFT", x, math.max(edgeY, textY))
        line:SetHeight(math.abs(edgeY - textY))
        local t = Text(f, 11, color or C.text)
        t:SetText(text)
        local above = textY > edgeY
        local v = above and "BOTTOM" or "TOP"
        if align == "RIGHT" then
            t:SetJustifyH("RIGHT")
            t:SetPoint(v .. "RIGHT", f, "TOPLEFT", x + 4, textY + (above and 2 or -2))
        else
            t:SetPoint(v .. "LEFT", f, "TOPLEFT", x - 4, textY + (above and 2 or -2))
        end
    end

    local barY = -40
    local back = Bar(barY, BAR_H, FILL, gold)
    local label = Text(f, 10, C.text)
    label:SetPoint("LEFT", back, "LEFT", 5, 0)
    label:SetText("Main hand")
    local time = Text(f, 10, C.text)
    time:SetPoint("RIGHT", back, "RIGHT", -5, 0)
    time:SetText("0.3")
    local sx = 1 + (BAR_W - 2) * FILL
    local tx = 1 + (BAR_W - 2) * CUE
    local spark = f:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(16, BAR_H * 2.4)
    spark:SetPoint("CENTER", back, "LEFT", sx, 0)
    local tick = Tex(f, "OVERLAY", { gold[1], gold[2], gold[3], 0.95 })
    tick:SetSize(2, BAR_H + 6)
    tick:SetPoint("CENTER", back, "LEFT", tx, 0)

    local bottom = barY - BAR_H
    Callout(30, barY, -12, "Weapon: a bar each for main hand, off hand and ranged")
    Callout(BAR_W - 8, barY, -12, "Time left", C.muted, "RIGHT")
    Callout(sx, barY, -26, "Spark: where the swing is now", nil, "RIGHT")
    Callout(tx, bottom - 3, bottom - 16, "Cue tick: past it the bar turns gold.\nQueue Heroic Strike or Maul now.", gold, "RIGHT")

    local oorY = -122
    local oorBar = Bar(oorY, 12, 0.45, red, 0.45)
    local oor = Text(f, 11, red)
    oor:SetPoint("LEFT", oorBar, "RIGHT", 12, 0)
    oor:SetText("Out of range: the bar dims and turns red")
    local foot = Text(f, 10, C.muted)
    foot:SetPoint("TOPLEFT", 0, oorY - 22)
    foot:SetWidth(DIAGRAM_W)
    foot:SetText("When a swing lands the bar flashes white. After a fight, a line under the bar sums up your swinging time.")
    return f, DIAGRAM_H
end

T:RegisterPage("general", { key = "swing", label = "Swing timer", order = 6, build = function(p)
    local cfg = function() return T.db.swing end
    p:Section("Swing timer", "A bar per weapon that refills on every auto attack and turns red while your target is out of range. Unlock the UI to move it. Needs the Swing timer module (General > Modules). Blizzard's own swing timer (Edit Mode) is separate and can stay off.")
    p:Add(SwingDiagram(), DIAGRAM_H, true)
    p:Check(cfg, "enabled", "Show the swing timer")
    p:Add(T.UI.W.Button("Preview on / off", function()
        local SW = T.Swing
        if not SW then T:Print("the Swing timer module is off.") return end
        if InCombatLockdown() then T:Print("the swing preview is not available in combat.") return end
        SW:SetPreview(not SW.preview)
    end, "Loops fake swings on the bars so you can see size, colours, the cue and the flash. Ends in combat or when settings close."))
    p:Check(cfg, "offHand", "Off-hand bar when dual wielding")
    p:Check(cfg, "ranged", "Ranged bar when a ranged weapon is equipped")
    p:Check(cfg, "showTime", "Show time left")
    p:Check(cfg, "effects", "Spark swell and a flash when the swing is ready")
    p:Check(cfg, "cue", "Next-swing cue: a tick and a gold bar for the last moments, to time on-next-swing abilities (Heroic Strike, Maul)")
    p:Slider(cfg, "cueWindow", "Cue lead time", 0.1, 1.5, 0.05, function(v) return ("%.2fs"):format(v) end)
    p:Check(cfg, "cueLatency", "Add my latency to the cue")
    p:Check(cfg, "cueSound", "Play a sound when the cue starts")
    p:Check(cfg, "summary", "After a fight, show how much of it you spent swinging, out of range or idle (also /tempus swing)")
    p:Dropdown(cfg, "visibility", "Show", { { "COMBAT", "In combat" }, { "ALWAYS", "Always" } })
    p:Slider(cfg, "width", "Width", 80, 400, 1)
    p:Slider(cfg, "height", "Height", 4, 30, 1)
    p:Slider(cfg, "spacing", "Spacing", 0, 12, 1)
end })
