local _, T = ...
T:RegisterPage("minimap", { key = "waypoints", label = "Waypoints", order = 5, build = function(p)
    p:Section("Waypoints", "Type /way 52.3 41.8 Bank to mark coordinates in your current zone. /way #mapID 52.3 41.8 Bank uses a specific map ID. /way clear removes the destination. /tway always works if another addon uses /way. Needs the Waypoints module (General > Modules).")
    local cfg = function() return T.db.waypoints end
    local styles = {}
    for _, key in ipairs(T.Waypoints and T.Waypoints.STYLE_ORDER or { "DRUM" }) do
        styles[#styles + 1] = { key, T.Waypoints and T.Waypoints.STYLES[key].label or "Drum" }
    end
    p:Dropdown(cfg, "style", "Compass style", styles)
    p:Section("Compass bar", "A compact compass bar at the top of the screen shows heading marks, your destination and distance in yards. The small arrow points straight toward the destination. It does not plan a path around obstacles. The minimap pin stays at the edge for distant destinations. Open the destination's zone on the world map to see its pin. Unlock the UI to move the compass bar. The destination is kept after a reload; click the x at the top right of the bar or use /way clear to remove it.")
end })
