-- Tempus UI: settings page for the shopping list.
local _, T = ...

T:RegisterPage("bags", { key = "shopping", label = "Shopping list", order = 5, build = function(p)
    local cfg = function() return T.db.shopping end
    p:Section("Shopping list", "Items you are collecting with a target amount, in a small panel: what this character has in bags and bank, and what your alts hold. To add one, click the panel's box, Shift-click the item (or type its name), add the amount and press Enter, e.g. \"Linen Cloth 20\". Mouse wheel over an item changes the amount; right-click removes it. Also /tempus shop <item> <amount>, /tempus shop remove <item>, /tempus shop clear. Needs the Shopping list module (General > Modules).")
    p:Check(cfg, "enabled", "Show the shopping list")
    p:Add(T.UI.W.Button("Open the list", function()
        local SH = T.Shopping
        if not SH or not SH.frame then T:Print("the Shopping list module is off.") return end
        SH:Open()
    end, "Shows the panel with the add box ready, even while the list is empty."))
    p:Check(cfg, "showAlts", "Count what my other characters hold (from the Alts viewer)")
    p:Check(cfg, "tooltip", "Show progress on item tooltips")
    p:Check(cfg, "announce", "Chat line and a sound when an item is done")
    p:Check(cfg, "hideDone", "Hide finished items from the panel")
    p:Slider(cfg, "width", "Width", 160, 360, 1)
    p:Add(T.UI.W.Button("Clear the list", function()
        if T.Shopping and T.Shopping.db then T.Shopping:Clear(); T:Print("shopping list cleared.") end
    end, "Removes every item."))
end })
