-- Minimap: which buttons count as addon buttons. Run: lua5.1 tests/minimap-buttons.lua
local T = { Style = { HiddenParent = {} }, NewModule = function() end }
CreateFrame = function() return {} end
assert(loadfile("Modules/Minimap/Minimap.lua"))("Tempus", T)
local MM = T.Minimap
local function B(name, kind) return { GetName = function() return name end, GetObjectType = function() return kind or "Button" end } end
for name, want in pairs({ LibDBIcon10_Questie = true, HealiumMiniMap = true, TalentsForeverBookMinimap = true,
    ForeverClassmateShamanMinimap = true, MiniMapMailFrame = false, MinimapZoomIn = false, TempusMinimapButton = false,
    QuestieFrame12 = false }) do
    assert(MM.IsAddonButton(B(name)) == want, name)
end
assert(MM.IsAddonButton(B("SomethingMinimap", "Frame")) == false, "frames are not buttons")
print("PASS: minimap finds LibDBIcon and named addon buttons, leaves Blizzard buttons and map pins alone")
