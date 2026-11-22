local _, T = ...
T:RegisterPage("convenience", {key = "market", label = "Auction values", order = 4.1, build = function(p)
    local cfg = function() return T.db.market end
    p:Section("Auction values", "Shows the lowest buyout from Tempus's own auction house scan on item tooltips, including stack estimates in Tempus bags. Prices are shared by all your characters on the realm. Listing prices are estimates, not completed sales.")
    p:Check(cfg, "tooltips", "Show auction estimates on item tooltips")
    p:Slider(cfg, "staleDays", "Mark prices stale after", 1, 14, 1, function(v) return v .. " days" end)
    p:Section("Scanning", "Open the auction house and click Tempus scan under its window, or the button below. A scan reads every listing in one request and keeps the lowest buyout per item. The game allows one full scan about every 15 minutes.")
    p:Check(cfg, "autoScan", "Scan automatically when I open the auction house")
    p:Add(T.UI.W.Button("Scan auction house", function() T.Market:StartScan() end, "Reads the whole auction house once. Does not buy, sell or post anything.", 200))
    p:Paragraph("Items with no scan data show 'No scanned price'; older prices are marked stale. Re-hover an item after a scan to see its updated estimate.")
end})
