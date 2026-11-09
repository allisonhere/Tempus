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

T:RegisterPage("combat", { key = "ticker", label = "Resource ticker", order = 6.5, build = function(p)
    local cfg = function() return T.db.ticker end
    p:Section("Resource ticker", "Energy and mana come in on a fixed 2-second clock. This bar fills toward your next tick, so you can wait for it before an expensive move or a cast. After you spend mana, spirit regen stops for five seconds: the bar turns violet and counts that down first. The bar learns the tick timing from the ticks it sees, so it starts once your power has ticked up once. Unlock the UI to move it. Needs the Resource ticker module (General > Modules).")
    p:Add(TickerDemo(), DEMO_H, true)
    p:Check(cfg, "enabled", "Show the resource ticker")
    p:Add(T.UI.W.Button("Preview on / off", function()
        local TK = T.Ticker
        if not TK or not TK.frame then T:Print("the Resource ticker module is off.") return end
        if InCombatLockdown() then T:Print("the ticker preview is not available in combat.") return end
        TK:SetPreview(not TK.preview)
    end, "Loops fake ticks (and, for mana, a five-second rule) so you can judge size and colours. Ends in combat or when settings close."))
    p:Check(cfg, "energy", "Energy ticks (rogues, druids in cat form)")
    p:Check(cfg, "mana", "Mana ticks")
    p:Check(cfg, "showFsr", "Five-second rule countdown after spending mana")
    p:Check(cfg, "showText", "Show current power (or seconds left of the five-second rule)")
    p:Dropdown(cfg, "visibility", "Show", { { "AUTO", "In combat or not full" }, { "COMBAT", "In combat" }, { "ALWAYS", "Always" } })
    p:Slider(cfg, "width", "Width", 60, 400, 1)
    p:Slider(cfg, "height", "Height", 3, 20, 1)
end })
