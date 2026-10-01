-- Tempus UI: settings page for the vendor module.
local _, T = ...

T:RegisterPage("general", { key = "vendor", label = "Vendor", order = 4, build = function(p)
    local cfg = function() return T.db.vendor end
    p:Section("Vendor", "Runs when you open a merchant window. Needs the Vendor module to be on (General > Modules).")
    p:Check(cfg, "sellGrey", "Sell grey items", "Poor-quality items with a vendor price. Nothing else is ever sold.")
    p:Check(cfg, "autoRepair", "Repair gear")
    p:Check(cfg, "guildRepair", "Use guild bank funds first", "Only when your guild allows it; otherwise you pay.")
    p:Check(cfg, "summary", "Print a summary in chat")
end })
