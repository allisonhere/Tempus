-- Tempus UI: settings page for the resource ticker.
local _, T = ...

-- Live energy and mana bars at the top of the page, ticking on their own while it is open.
local DEMO_W, DEMO_H = 420, 68
local function TickerDemo()
    local UI, S = T.UI, T.Style
    local f = CreateFrame("Frame")
    f:SetSize(DEMO_W, DEMO_H)
    local title = UI.Text(f, 11, S.C.muted)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("Live demo: energy, then mana (violet = five-second rule)")
    local box = T.Ticker.CreateDemo(DEMO_W)
    box:SetParent(f)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -18)
    function f:Refresh() box:Refresh() end
    return f
end

-- The preview drives the bar, the strip and the dots, so both pages carry the button.
local function PreviewButton()
    return T.UI.W.Button("Preview on / off", function()
        local TK = T.Ticker
        if not TK or not TK.frame then T:Print("the Resource ticker module is off.") return end
        if InCombatLockdown() then T:Print("the ticker preview is not available in combat.") return end
        TK:SetPreview(not TK.preview)
    end, "Loops fake ticks and countdowns (and, for mana, a five-second rule) so you can judge size and colours. Ends in combat or when settings close.")
end

T:RegisterPage("combat", { key = "ticker", label = "Resource ticker", order = 6.5, build = function(p)
    local cfg = function() return T.db.ticker end
    p:Section("Resource ticker", "Energy and mana come in on a fixed 2-second clock. This bar fills toward your next tick, so you can wait for it before an expensive move or a cast. After you spend mana, spirit regen stops for five seconds: the bar turns violet and counts that down first. The bar learns the tick timing from the ticks it sees, so it starts once your power has ticked up once. Unlock the UI to move it. Needs the Resource ticker module (General > Modules).")
    p:Add(TickerDemo(), DEMO_H, true)
    p:Check(cfg, "enabled", "Show the resource ticker")
    p:Add(PreviewButton())
    p:Check(cfg, "energy", "Energy ticks (rogues, druids in cat form)")
    p:Check(cfg, "mana", "Mana ticks")
    p:Check(cfg, "showFsr", "Five-second rule countdown after spending mana")
    p:Check(cfg, "showText", "Show current power (or seconds left of the five-second rule)")
    p:Dropdown(cfg, "visibility", "Show", { { "AUTO", "In combat or not full" }, { "COMBAT", "In combat" }, { "ALWAYS", "Always" } })
    p:Section("Bar size")
    p:Slider(cfg, "width", "Width", 60, 400, 1)
    p:Slider(cfg, "height", "Height", 3, 20, 1)
end })

T:RegisterPage("combat", { key = "tickerstrip", label = "Strip & countdowns", order = 6.6, build = function(p)
    local cfg = function() return T.db.ticker end
    p:Section("Afford strip", "A strip under the bar with one segment per spell you press on a tick, such as Claw and Shred for a cat or Sinister Strike for a rogue. Green means the game says you can cast it right now (the same check your action bar icons use), so you can watch the ticks without looking down. When your energy number is readable, amber also fades up as the next tick approaches if that tick will get you there. Grey means not yet. With the list below empty, cats and rogues get two slots picked for the moment: a builder (Shred or Backstab when the mob is attacking someone else, else Claw or Sinister Strike) and a finisher (Rip, then Ferocious Bite while Rip is running; Eviscerate for rogues). Anything you add to the list replaces that; spells you do not know are skipped. Needs the Resource ticker module (General > Modules).")
    p:Add(PreviewButton())
    p:Check(cfg, "afford", "Show the afford strip")
    p:Check(cfg, "smart", "Pick the builder and finisher automatically (when the list is empty)")
    p:Slider(cfg, "affordHeight", "Strip height", 4, 24, 1)
    p:Add(T.UI.W.List("tickspells", "Spell name or ID, e.g. Claw", true), 236, true)
    p:Section("Timer dots and countdowns", "Dots time your bleeds, buffs and damage-over-time spells, going green, yellow, then red as they run out. The finisher slot on the afford strip can count one down on its border too: Rip for a cat, even while the slot shows Ferocious Bite, or your choice below for a rogue. The slot countdown needs the automatic builder and finisher.")
    p:Check(cfg, "dots", "Show timer dots at the right end of the bar (Rake, Rip, Savage Roar; Slice and Dice, Rupture; Corruption, Curse of Agony, Immolate, Unstable Affliction)")
    p:Dropdown(cfg, "dotStyle", "Dot countdown", { { "BORDER", "Draining border" }, { "FILL", "Falling fill" } })
    p:Check(cfg, "dotNumbers", "Show the seconds counting down inside each timer dot")
    p:Slider(cfg, "dotSize", "Timer dot size", 12, 32, 1)
    p:Check(cfg, "slotGauge", "Countdown border on the finisher slot")
    p:Dropdown(cfg, "rogueGauge", "Rogue finisher slot counts down", { { "NONE", "Nothing" }, { "Rupture", "Rupture" }, { "Slice and Dice", "Slice and Dice" } })
    p:Slider(cfg, "gaugeThickness", "Border thickness", 1, 5, 1)
    p:Slider(cfg, "gaugePulse", "Pulse in the last seconds (0 = never)", 0, 8, 1)
    p:Add(T.UI.W.Button("Reset strip and dot positions", function()
        local TK = T.Ticker
        if not TK or not TK.db then return end
        TK.db.stripPos, TK.db.dotsPos = {}, {}
        TK:PlaceExtras()
    end, "Put the strip back under the bar and the dots back at its right end. To move them, unlock the frames (/tempus unlock) and drag them."))
end })
