-- Tempus UI: settings page for the native Bags module.
local _, T = ...
local UI, W = T.UI, T.UI.W

T:RegisterPage("bags", { key = "bags", label = "Bags", order = 1, build = function(p)
    local cfg = function() return T.db.bags end
    p:Section("Bags", "Combines carried bags and personal bank storage. Search matches every typed word against item names, types and item IDs.")
    p:Dropdown(cfg, "mode", "Default view", { { "GRID", "Grid" }, { "CATEGORIES", "Automatic categories" } })
    p:Slider(cfg, "columns", "Columns", 6, 20, 1)
    p:Slider(cfg, "itemSize", "Item size", 28, 52, 1)
    p:Slider(cfg, "spacing", "Spacing", 1, 10, 1)
    p:Check(cfg, "showEmpty", "Show empty slots")
    p:Check(cfg, "showNew", "Mark newly acquired items")
    p:Section("Window", "Optional parts of the bag window.")
    p:Check(cfg, "showFilters", "Filter chips (gear, consumables, quest, junk)")
    p:Check(cfg, "showBagBar", "Bag bar (hover to highlight a bag, click to show only that bag)")
    p:Check(cfg, "showCurrencies", "Watched currencies in the footer")
    p:Section("Items", "Marks drawn on each item. Sections can be folded by clicking their headers.")
    p:Check(cfg, "sortItems", "Sort by quality, item level, then name")
    p:Check(cfg, "showItemLevel", "Item level and bind-on-equip tag on gear")
    p:Check(cfg, "showUpgrades", "Arrow on gear better than what you wear")
    p:Check(cfg, "showCooldowns", "Item cooldowns")
    p:Section("Custom categories", "Use Tag in the bag header, then click an item to put it in your own category.")
    p:Add(W.Button("Clear custom categories", function()
        T.db.bags.customCategories = {}
        UI.Changed()
    end))
    p:Section("Positions", "The windows can also be dragged by their title bars.")
    p:Add(W.Button("Reset bag positions", function()
        T.db.bags.point = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -24, 180 }
        T.db.bags.bankPoint = { "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 24, 180 }
        UI.Changed()
    end))
end })
