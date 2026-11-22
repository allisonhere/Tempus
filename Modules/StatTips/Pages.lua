local _, T = ...
T:RegisterPage("convenience", {key = "stattips", label = "Stat tooltips", order = 4.2, build = function(p)
    local cfg = function() return T.db.stattips end
    p:Section("Stat tooltips", "Adds lines to item tooltips showing what the item's stats do for your character, such as attack power, crit chance, health, mana and armor. Values come from the game's own conversion rules, so they follow your class, level and talents.")
    p:Check(cfg, "compare", "Show the change when swapping in an unequipped item")
    p:Paragraph("Equipped items and the comparison tooltips show what the item gives you. Other items show the net change against what they would replace. Regen and dodge values are per-point averages, marked with ~.")
end})
