local T = {}
assert(loadfile("Config/Search.lua"))("Tempus", T)
local S = T.SettingsSearch
local sections = {{key = "general",label = "General"},{key = "unitframes",label = "Unit Frames"}}
local defs = {{key="layouts",label="Automatic layouts",section="general"},
 {key="player",label="Player",section="unitframes"}, {key="target",label="Target",section="unitframes"},
 {key="changelog",label="What's new",section="general",pinned=true}}
local widget = {}
local built = {layouts={searchEntries={{label="Solo layout",text="Solo layout preset selection",section="Routing",y=-100,widget=widget}}},
 player={searchEntries={{label="Cast bar",text="Show interrupt cooldown",section="Combat",y=-500,widget=widget}}},
 target={searchEntries={{label="Hide [boss]",text="Literal % value",y=-20}}},
 changelog={searchEntries={{label="Old cast bar change",text="Cast bar",y=-30}}}}
assert(S.Normalize("  |cff00ffffCaSt|r\t BAR  ") == "cast bar")
local results,total = S.Results(defs,built,sections,"CAST BAR")
assert(total == 1 and results[1].page == "player" and results[1].y == -500 and results[1].widget == widget)
assert(results[1].breadcrumb == "Unit Frames > Player > Combat")
results = S.Results(defs,built,sections,"player interrupt")
assert(#results == 1 and results[1].label == "Cast bar")
results = S.Results(defs,built,sections,"solo preset")
assert(#results == 1 and results[1].page == "layouts")
results = S.Results(defs,built,sections,"[boss]"); assert(#results == 1)
results = S.Results(defs,built,sections,"% value"); assert(#results == 1)
results = S.Results(defs,built,sections,"missing"); assert(#results == 0)
results,total = S.Results(defs,built,sections," "); assert(#results == 0 and total == 0)
results,total = S.Results(defs,built,sections,"c"); assert(#results == 0 and total == 0)
-- Unbuilt pages are discoverable by their own and their section's names.
results = S.Results(defs,{},sections,"unit frames target"); assert(#results == 1 and results[1].page == "target")
results,total = S.Results(defs,built,sections,"general",1); assert(#results == 1 and total > 1)
print("PASS: settings search, labels/help/breadcrumbs, literal matching, ordering and limits")
