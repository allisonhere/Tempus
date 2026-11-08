local _, T = ...
T:RegisterPage("general", {key = "market", label = "Auction values", order = 4.1, build = function(p)
    local cfg = function() return T.db.market end
    p:Section("Auction values", "Shows Auctionator's last scanned prices on item links and tooltips: chat, loot, bags, bank, crafting and comparisons. Enable Auctionator and the Auction values module to show estimates on item tooltips. Listing prices are estimates, not completed sales.")
    p:Check(cfg, "tooltips", "Show auction estimates on item tooltips")
    p:Slider(cfg, "staleDays", "Mark prices stale after", 1, 14, 1, function(v) return v .. " days" end)
    p:Section("Refresh prices", "Visit an auctioneer, open the auction house, then scan your carried items below. Auctionator runs the searches and stores the results; re-hover an item after scanning to see its updated estimate.")
    p:Add(T.UI.W.Button("Scan bag items", function() T.Market:ScanBags() end, "Searches each distinct item name in your carried bags. Does not buy, sell or post items.", 200))
    p:Paragraph("For prices beyond your bags, use Auctionator's Full Scan at the auction house. Prices remain available away from the auctioneer. Items with no scan data show 'No scanned price'; older data is marked stale.")
    p:Paragraph("If Auctionator already adds auction prices to tooltips, you can turn those off in its settings or disable Tempus's estimate above.")
end})
