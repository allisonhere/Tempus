local _, T = ...
T:RegisterPage("minimap", { key = "waypoints", label = "Waypoints", order = 5, build = function(p)
    p:Section("Waypoints", "Type /way 52.3 41.8 Bank to mark coordinates in your current zone. /way #mapID 52.3 41.8 Bank uses a specific map ID. /way clear removes the destination. /tway always works if another addon uses /way. Needs the Waypoints module (General > Modules).")
    p:Section("Direction arrow", "The arrow points straight toward your destination, with distance in yards. It does not plan a path around obstacles. The minimap pin stays at the edge for distant destinations. Open the destination's zone on the world map to see its pin. Unlock the UI to move the arrow. The destination is kept after a reload; /way clear removes it.")
end })
