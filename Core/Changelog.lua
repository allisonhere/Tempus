-- Generated from CHANGELOG.md by tools/gen_changelog.py. Do not edit by hand.
local _, T = ...
T.changelog = {
    { version = "Unreleased", sections = {
        { title = "Added", items = {
            { 0, "|cffffffffShare my gear data.|r A button on Convenience > Auction values opens a text with your class, level, talent points and the stat names on your gear. Copy it, or type a character name and press Whisper to send it to them in chat. Nothing is sent unless you press Whisper. |cffffffffMail it later|r queues the report as a few short mails instead: the next time you open a mailbox Tempus asks whether to send it, then fills in the Send Mail tab (recipient, subject and text) and moves on to the next part after each send. You press Send yourself every time. It is for helping improve Gear Advisor." },
            { 0, "|cffffffffA Find button on the Buying section of the Gear Advisor detail pane.|r It opens a search for the selected item in the auction house window (the same search the auction house's own search bar runs), so you see the real listings and buy with Blizzard's own Buy button. It sits on the |cffffffffBuying|r heading, with the listing's price, age and item level listed under it, and the same for the item you wear (its item level and what else would come off). It needs the auction house open, spends nothing and buys nothing." },
        } },
    } },
    { version = "2.18.0", sections = {
        { title = "Changed", items = {
            { 0, "|cffffffffGear Advisor window, redesigned and flat.|r The gradients are gone from the list (the hover wash, the gain badge and the value meter are plain colours now) and the hover tooltip is gone: everything is in the window. The list has column headings (|cffffffffItem, Score, Gain, Price|r) that you can click to sort by: click once to sort by that column, click again to flip the direction, and the active heading shows |cff9fd6ffv|r (high to low) or |cff9fd6ff^|r (low to high). Name sorts A to Z without case, and |cffffffffRank upgrades by|r gained |cffffffffMost item levels|r and |cffffffffName|r. The list shows each listing's |cffffffffScore|r for your build next to its item levels gained and its price. The detail pane is now a clean set of rows: Score (and which build it was scored as), Item level, Price and age, what it Replaces (and what else comes off), Trust (the confidence and its reasons) and Why (each stat with the score it adds, and any stat that moved with no weight). The stat table gained a |cffffffffScore|r column, so you can see what each stat adds, and the vertical chart is gone. The detail pane is now one scrolling column, top to bottom: the tooltip of the item you |cffffffffwear|r, the tooltip of the item you would |cffffffffbuy|r, then |cffffffffthe math|r. Each tooltip is squeezed into a few lines (the name line and empty lines dropped, a line's right-hand text joined to it, plain \"+12 Agility\" lines on one line) in the game's own colours, so you get what the item and compare tooltips showed without a tooltip opening. Scroll the pane with the mouse wheel when it is longer than the window." },
            { 0, "|cffffffffThe Tempus scan button is a progress bar.|r While the auction house scan runs, the button fills from the left with your accent colour as it goes. The percentage stays on top, and its colour reverses where the fill is under it (white on a dark accent, dark on a light one) so it reads on both sides." },
        } },
    } },
    { version = "2.17.0", sections = {
        { title = "Added", items = {
        } },
        { title = "Changed", items = {
            { 0, "|cffffffffGear Advisor scores split stats.|r Crit, hit and haste weights now cover the melee, ranged and spell versions of the stat, mana regeneration covers both of its keys, and healing done and damage done are scored with their own weights, so a stat the game splits into variants is not left unscored." },
            { 0, "|cffffffffGear Advisor shows its detail on hover.|r Hovering a listing now opens a tooltip beside the window with the item, the verdict tags, why it scored what it did, what else would come off and how far to trust it. The long \"why\" line in the side pane was wider than the pane and got cut off; the tooltip is not." },
        } },
    } },
    { version = "2.16.0", sections = {
        { title = "Added", items = {
            { 0, "|cffffffffGear Advisor ranks by your stats.|r The list weighs how much the stats your class cares about improve against the price (item levels when the game gives no stats), drops gear with worse stats for your class, and has a |cffffffffRank upgrades by|r setting: best value, biggest upgrade or cheapest. The window has a new gold look with value meters." },
            { 0, "|cffffffffGear Advisor scores gear for the build you play, for every class.|r A Cat scores agility, attack power and weapon damage; a Bear scores stamina, armor and dodge; every class has its own builds (Arms, Fury, Protection, Holy, Shadow, Frost and so on, plus Forever's extra Shockadin, Battle Mage and Enhancement Tank). Choose the build under Convenience > Auction values > |cffffffffScore gear as|r. Druids can leave it on Automatic to follow their shapeshift form; for other classes Automatic is a guess, so pick yours. A ranged weapon's damage counts at the ranged weight. The detail pane says why an item scored what it did, for example \"+12.4 as Cat (from your form): +12 Agility, -4 Stamina (estimate)\". The weights are community estimates from GearQuest Forever, via Pawn Forever (MIT), and are labelled as estimates." },
            { 0, "|cffffffffGear Advisor leaves out listings you already beat.|r If something in your bags that you can wear is as good as an auction listing for the same slot, the listing is hidden, and the footer says how many were left out. When the game gives stats for both, your build's score decides, so a higher item level with worse stats for you does not hide a better listing; otherwise item level decides. It never suggests buying what you already carry." },
            { 0, "|cffffffffGear Advisor verdict tags.|r The detail pane marks the Biggest upgrade, the Best value, the Best you can afford (when it differs from the biggest) and a Small upgrade (the cheapest listing that is still a real gain). The footer also says how many listings were left out for worse stats for your build." },
            { 0, "|cffffffff|cff9fd6ff/tempus gearplan [gold]|r|r lists the best set of gear to buy for that much gold (no amount means all the gold you carry), picked from your last auction scan. It looks for the best whole set, not just the best single item: two cheaper pieces can beat one dear one. The same plan is on Convenience > Auction values: a |cffffffffBudget plan gold|r slider (0 means all the gold you carry) and a |cffffffffShow budget plan|r button. It keeps to one item per slot (two for rings and trinkets), never mixes a two-hander with a second weapon or a shield, and never buys anything. Gains are added item by item, so items that share stats can overlap, and the second ring or trinket is a rough guess." },
            { 0, "|cffffffffGear Advisor can read your talents (switched on class by class).|r When \"Score gear as\" is on Automatic, the build can come from the talents you have points in, after your shapeshift form and before a guess. It needs a list of which talents mark which build, and none is shipped yet: no talent names are guessed, so nothing changes until a class has been probed. Talents unlock at level 10, so below that the build comes from your form, your choice or a labelled guess." },
            { 0, "|cffffffffGear Advisor confidence and the old ranking.|r The detail pane shows a confidence next to the price: |cffffffffMedium|r at best, because the stat weights are community estimates, and |cffffffffLow|r when the build is assumed, some stats changed but have no weight, or the price is stale. When the game gives no stats, or you pick the old method, it says |cffffffffItem level only|r. |cffffffffRank upgrades by|r has a new |cffffffffItem levels per gold (old method)|r choice that brings back the original ranking, with no stat check, and says so instead of passing itself off as a stat score." },
        } },
        { title = "Fixed", items = {
            { 0, "|cffffffffGear Advisor and one-hand weapons.|r A class that cannot dual wield (a Druid, say) is now compared with its main hand, not the empty off hand that made every one-hander look like a huge upgrade. Characters that dual wield still see the off hand." },
            { 0, "|cffffffffTwo-handers and shields.|r A two-hand weapon now says when it also takes off your shield or off hand, and a shield or off-hand item says when it takes off your two-hander." },
            { 0, "|cffffffffUnique-equipped gear|r you already wear is no longer offered again." },
        } },
        { title = "Changed", items = {
            { 0, "|cffffffffCheapest upgrades is now Gear Advisor.|r The window, the auction house button and the settings button carry the new name, and |cff9fd6ff/tempus gear|r opens it. |cff9fd6ff/tempus upgrades|r still works." },
        } },
    } },
    { version = "2.15.0", sections = {
        { title = "Added", items = {
            { 0, "|cffffffffTarget debuff timeline.|r Your debuffs on the target fall down a timeline toward the moment they run out, with each icon starting at the top and landing as its own time ends (a 5 second debuff falls fast, a 30 second one slowly; a Columns setting spaces icons that start together, and one shared time scale is still available), the same glass background, fades, preview and resize grip as the cooldown timeline. Turn it on under Combat > Target debuffs (Target debuff timeline module); it can replace the target frame's own debuff icons. In combat the game hides debuff times, so Tempus learns each length when it can read it and times your casts after that. Pick your debuffs from a list of your own spells (the length is read from the spell's text) or type them (Moonfire 12), and casting one starts its timer." },
            { 0, "|cffffffffCooldown timeline.|r Cooldowns > Style can now be a vertical timeline instead of a row of icons. Each spell on cooldown falls down a scale (5, 15, 30 seconds, 1 minute and on) toward a ready line, over a themed glass background with a rail, time labels and lines at each mark. The background and the icons fade out as they near the ready line, and you can set how much, the background opacity and style, the length, the far end of the scale, which side the labels sit on, and whether it falls down or rises up. The settings page has a live preview, and unlocking the UI gives the timeline a corner grip: drag it wider for bigger icons and taller for a longer scale. The row of icons is still the default." },
        } },
        { title = "Changed", items = {
            { 0, "|cffffffffSettings.|r Dropdown lists no longer scroll with the mouse wheel (long lists lay out in columns instead), sliders no longer change with the wheel so it scrolls the page, and the timeline preview stays at the top while the controls scroll. The timelines also have a None background that shows only the icons." },
        } },
    } },
    { version = "2.14.0", sections = {
        { title = "Added", items = {
            { 0, "|cffffffffResource ticker afford strip.|r A strip under the tick bar with one segment per spell you press on a tick (Claw and Shred for a cat, Sinister Strike and Backstab for a rogue, or your own list on the Resource ticker page). Green means the game says you can cast it now, the same check your action bar icons use, so it works even though the client hides your energy number. Softer green means you have the energy but something else blocks it (Shred from the front, no target). Amber fades up as the next tick approaches when your energy is readable." },
            { 0, "|cffffffffTimer dots|r at the right end of the tick bar for your bleeds and buffs (Rake, Rip and Savage Roar for a cat; Slice and Dice and Rupture for a rogue). Each drains and shifts green to yellow to red as time runs out, and dims when it is not up. In combat the game hides auras from addons, so the dots then time themselves from your own casts. Seconds inside the dots can be turned off." },
            { 0, "|cffffffffMove the strip and dots.|r With the frames unlocked each has its own drag handle; a reset button on the Resource ticker page puts them back." },
            { 0, "|cffffffffPositioning panel.|r Themed buttons, a Lock frames button, and a Position box that shows the selected frame as |cff9fd6ffCORNER x y|r to copy, or to type a position into and press Enter." },
            { 0, "|cff9fd6ff/tempus tickdebug|r explains what the strip and dots are doing." },
        } },
        { title = "Fixed", items = {
            { 0, "The tick bar and strip kept working after shifting bear form then cat form." },
        } },
    } },
    { version = "2.13.0", sections = {
        { title = "Added", items = {
            { 0, "|cffffffffUpgrades list detail pane.|r Hovering a row fills a pane inside the window (no tooltip any more): item level against what you wear, price and age, every stat side by side (current against the one you would buy, with the change) and a vertical chart where gains rise above a centre line and losses hang below it in red. Stat names are written out in full. The list is narrower, the window taller." },
            { 0, "|cffffffffUpgrades list follows the auction house filters.|r The category you pick on the left (for example Two-Handed Swords), the rarity boxes and the level range apply to the list as well, and it refreshes when you change them. The footer says when they are active. A switch on General > Auction values turns this off." },
            { 0, "|cffffffffMaximum price for the upgrades list|r, a box in the window and a slider on General > Auction values." },
            { 0, "|cffffffffBank bag slots.|r The bank window now has a row for your bank tabs and bags: hover to dim everything else, click to show only that tab, drag bags on and off. Tabs you have not bought show as locked, the next one can be bought (through the game's own confirmation), and a line shows how many tabs you own, the free slots and how many are left to buy. Tooltips give each tab's price: the next tab live, later ones as last seen. Turn it off with |cffffffffBank bag slots|r in Bags > Window." },
            { 0, "|cffffffffStat tooltips|r (Convenience > Stat tooltips): item tooltips explain what the stats do for your character, such as attack power, crit chance, health, mana and armor, using the game's own conversion rules. Unequipped items can show the change against what they would replace." },
            { 0, "|cffffffffTrades filter|r in the bags: trade goods and recipes together." },
            { 0, "|cffffffffCombo points|r are now a little taller with each point and shade from red through yellow to green." },
        } },
        { title = "Fixed", items = {
            { 0, "A weapon enchant or poison on a weapon could throw \"attempt to call a nil value\" in Buffs on clients without the old |cff9fd6ffGetItemInfo|r function." },
        } },
    } },
    { version = "2.12.0", sections = {
        { title = "Added", items = {
            { 0, "|cffffffffCheapest gear upgrades|r from your auction scan. The |cffffffffUpgrades|r button in the top-left corner of the auction house window, |cff9fd6ff/tempus upgrades|r and |cffffffffOpen upgrades list|r on General > Auction values open a window that lists gear better than what you wear, that your class and level can equip. It is grouped by slot (head, back, waist and so on, the best eight per slot), ranked by item levels gained per gold, and shows each item's |cff9fd6ff+ilvl|r and the stats that go up compared with your worn item. It works anywhere, not only at the auction house, because scanned prices are saved. Drag it to move it; item tooltips open beside it, not over the list. Settings: a minimum item level gain and an option to show only what you can afford." },
        } },
        { title = "Changed", items = {
            { 0, "|cffffffffTempus now scans the auction house itself.|r Auction values no longer reads Auctionator. The |cffffffffTempus scan|r button (top-left corner of the auction house window), |cffffffffScan auction house|r on the settings page, or the new optional automatic scan read every listing in one request and keep the lowest buyout per item. Prices are saved per realm for all your characters and dropped after 30 days. The game allows about one full scan every 15 minutes. |cffffffffScan bag items|r is gone, since it only drove Auctionator's searches. Prices from Auctionator are not imported, so scan once to fill the data." },
        } },
        { title = "Fixed", items = {
            { 0, "\"Tempus: loaded. Type /tempus to configure.\" could show twice at login. Saved chat history replayed last session's copy next to the new one. The line is no longer saved, and copies already saved are skipped." },
        } },
    } },
    { version = "2.11.6", sections = {
        { title = "Fixed", items = {
            { 0, "The flight path map (opened from a flight master) showed solid black under the Tempus skin. It no longer gets stripped like other Blizzard windows, so the route map stays visible." },
        } },
    } },
    { version = "2.11.5", sections = {
        { title = "Added", items = {
            { 0, "|cffffffffPlugins|r section under General > Modules lists optional addons (currently SpellPower) that add their own pages to this settings window. Switch one off to hide its pages from the sidebar and search right away, no reload needed. Plugins are on by default, so nothing disappears after upgrading." },
        } },
        { title = "Changed", items = {
            { 0, "|cffffffffOne chat log window|r: reviewing and copying chat was split between a copy window and a separate select mode, each with its own icon by the tabs, its own setting and its own slash command. There is now one window that does both. Open it with the copy icon at the end of the tab row, by Alt+clicking a chat window, or with |cff9fd6ff/tempus copychat|r (|cff9fd6ff/tempus selectchat|r still works). Drag or Shift+arrows to select, Ctrl+A picks the lot, Ctrl+C copies, Esc closes. Colours start off, so what you paste outside the game is plain text; the |cffffffffColours|r button shows the lines the way chat draws them. Lines that arrive while the window is open are counted and added by |cffffffffUpdate|r, so they cannot move the text under your selection. Typing in the window is put back, and the corner can be dragged to resize it. Chat settings now hold one checkbox, |cffffffffChat log button next to the tabs|r, instead of two." },
        } },
        { title = "Fixed", items = {
            { 0, "Center the Need/Greed loot-roll stack above the hotbars and style its panels, fonts and countdown bars with the Tempus Windows skin. Native voting buttons and item tooltips are preserved." },
            { 0, "The first-run setup window's welcome text could spill down over the Back/Next/Skip buttons. It no longer draws on top of them." },
            { 0, "Using an item from the bag window (a potion, say) while in combat could fail and show WoW's \"action blocked because of an AddOn\" message. The bag window no longer redraws itself mid-combat, so item use works normally there." },
        } },
    } },
    { version = "2.11.4", sections = {
        { title = "Changed", items = {
            { 0, "Settings pages use clearer labels and help text, and errors explain what to fix." },
            { 0, "Style Studio is now the single appearance page. Its live sample scene and controls make it easier to see how themes, fonts, bars, colours and icons will look together." },
        } },
    } },
    { version = "2.11.3", sections = {
        { title = "Changed", items = {
            { 0, "New Tempus icon: a neon hourglass. The addon list, installer and Automation bar use the square version; the minimap button (docked or not) uses a round version with its neon ring." },
        } },
    } },
    { version = "2.11.2", sections = {
        { title = "Changed", items = {
            { 0, "The settings window header has a new animated hourglass logo: the sand runs down, then the glass flips over, in 30 frames on a loop of about five seconds. It only animates while settings are open, and it stays still when the Animations setting is off. The minimap button keeps the clock icon." },
            { 0, "New settings window header: a silver TEMPUS UI wordmark, a diagonal band holding your profile and version, glowing edge lines, and outlined Preview and Unlock buttons. It follows your Appearance colours: the band and Unlock take the accent, the slash, base line and Preview take the second colour." },
        } },
        { title = "Fixed", items = {
            { 0, "Removed work-in-progress design files that were accidentally packaged in 2.11.1." },
        } },
    } },
    { version = "2.11.1", sections = {
        { title = "Fixed", items = {
            { 0, "Bags: the bank window could open with |cffffffff0 / 0|r slots on WoW Forever. Tempus hid Blizzard's bank frame completely, and the game only fills in the bank (its 48-slot main bank and bank bags) while that frame is on screen. Blizzard's bank now stays open but invisible behind the Tempus window, so the bank fills in every time; |cffffffffManage|r still shows it." },
            { 0, "Bags: the bank's |cffffffffManage|r button moved up into the window header next to Tag, instead of floating on the Personal row." },
        } },
    } },
    { version = "2.11.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffChat select mode|r: Alt+click a chat window, or click the new I-beam button by the chat tabs, and the window turns into text you can select like a text editor: drag with the mouse, Shift+arrows, Ctrl+A, then Ctrl+C. Colours stay. Esc, Enter or switching tabs puts normal chat back, where links are clickable again. Lines that arrive while you are selecting are counted instead of jumping the text; click |cffffffffupdate|r to add them. Also |cff9fd6ff/tempus selectchat|r (Chat > Select mode for chat history)." },
            { 0, "|cffffffffNew chat look|r (Skins > Chat frames): messages and the edit box share one panel. The active tab is bright with an accent underline and the others are dimmed; tabs light up on hover and show an unread count, which pulses pink for whispers. Chat uses your Tempus font with a little more line spacing, a |cffffffffBack to newest|r button appears when you scroll up (instead of the arrow column), and the edit box edge takes the colour of the channel you are typing in. Each part can be turned off; they apply after a reload." },
            { 0, "|cffffffffWhisper alert|r (Chat > Whisper alert): when someone whispers you, a pink banner shows who it is and the start of the message, a sound plays (pick it, or turn it off; it plays even with game sounds muted), and WoW's taskbar icon flashes when the game is in the background. Options for combat and Battle.net whispers, a Test button, and the banner can be moved with the UI unlocked. Press R to reply." },
            { 0, "|cffffffffCleaner chat text|r (Chat > Text): short channel names (|cff9fd6ff[2. Trade - City]|r becomes |cff9fd6ff[T]|r), class-coloured player names, and grey timestamps." },
            { 0, "|cffffffffArrow keys move the cursor|r in the chat box without holding Alt: Left, Right, Home and End move, Shift selects, Up and Down walk your sent messages. SpellPower's spell checking and shortcuts keep working (Chat > Typing)." },
            { 0, "|cffffffffEdit box position|r: a slider moves the chat edit box left or right (Skins > Chat frames > Edit box left / right)." },
        } },
        { title = "Fixed", items = {
            { 0, "The chat copy window came up empty when the window held Battle.net whispers. Friends' names now show as their BattleTag name." },
            { 0, "Changing the chat font size from a chat tab's menu works while the Tempus chat font is on." },
        } },
    } },
    { version = "2.10.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffStyle Studio|r (General > Style Studio): sample player and target frames, enemy nameplates, buffs, debuffs, action buttons and cast bars in one live scene. Change the theme, bar texture, font, outline, accent colour or icon crop and watch every sample update at once; pause the scene to compare details. Changes save immediately, and the scene uses simulated data without turning on any module's test mode." },
            { 0, "|cffffffffAuction values|r (General > Auction values): with Auctionator enabled, item tooltips show its last scanned price and how old the data is, and Tempus bags show stack estimates. At the auction house, |cffffffffScan bag items|r searches your carried items through Auctionator (it never buys or posts). Unknown prices stay unknown and old prices are marked stale." },
        } },
        { title = "Fixed", items = {
            { 0, "Bags: the bank window showed no slots on clients that use character bank tabs. It now reads your purchased bank tabs as well as the older bank and bank bags, so the bank (and the Alts viewer's saved bank) fills in again." },
        } },
    } },
    { version = "2.9.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffResource ticker|r: a thin bar under the swing timer that fills toward your next energy or mana tick (they come every 2 seconds), so you can wait for the tick before an expensive move or a cast. After you spend mana it turns violet and counts down the five-second rule first. It learns the tick timing from ticks it sees, ignoring refunds and potions. Preview, size and when to show it are on General > Resource ticker." },
            { 0, "|cffffffffShopping list|r: a small panel of items you are collecting with a target amount (\"Linen Cloth 20\"), showing what this character has in bags and bank plus what your alts hold. Shift-click an item into its box (or type a name) and press Enter; mouse wheel changes the amount, right-click removes. Item tooltips show your progress, and finishing an item says so. Also |cff9fd6ff/tempus shop <item> <amount>|r, |cff9fd6ff/tempus shop remove <item>|r, |cff9fd6ff/tempus shop clear|r (Bags > Shopping list)." },
            { 0, "|cffffffffDanger alert|r: a warning at the top of the screen when a risky mob's nameplate appears (elite, rare, ?? level or several levels above you) or a hostile PvP player, and when more mobs are on you than you meant to pull. No warnings while you are on a flight path. Each mob warns once, then stays quiet for a while; sound, level gap and pull size are adjustable (General > Danger alert)." },
            { 0, "|cffffffffLive bar demos in settings|r: every animated bar now plays on its own page. Nameplates and Party & Raid samples take hits (the red \"recent damage\" chunk drains away) and nameplates cast, with every other cast interrupted. Unit Frames > General has a live player frame with health, power, the low-health glow and a cast bar. The Swing timer page has live bars under its diagram, and the Resource ticker page has energy and mana bars. They follow your current settings and only run while the page is open." },
            { 0, "|cffffffffSkip empty loot|r: looting a corpse with nothing on it no longer opens an empty loot window (General > Automation)." },
            { 0, "|cffffffffGrey out on cooldown|r for action bar buttons: a button's icon turns grey while its spell or item is on cooldown, on top of Blizzard's dark sweep (the global cooldown doesn't count). On by default; Action Bars > General." },
        } },
        { title = "Changed", items = {
            { 0, "Swing timer and resource ticker text is now always white with a black outline, so it stays readable over both the filled and the empty part of the bar (it used to turn black on light bars and vanish over the dark empty part)." },
        } },
        { title = "Fixed", items = {
            { 0, "Cooldowns: icons stayed in colour during a cooldown in combat, because the game hides cooldown times from addons there. They now grey out in combat too." },
        } },
    } },
    { version = "2.8.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffNext-swing cue|r: each swing bar gets a tick near its end, and the bar turns soft teal for the last moments before the swing lands, so you can time on-next-swing abilities (Heroic Strike, Maul). The window is a lead time you choose plus, optionally, your latency; an optional sound plays when it starts (Swing timer settings)." },
            { 0, "|cffffffffFight summary|r: when combat ends, a line under the swing timer shows how much of the fight you spent swinging, out of range or idle (|cff9fd6ff/tempus swing|r repeats it; Swing timer settings turn it off)." },
            { 0, "Escape locks the UI again after unlocking it, and the Profiles page can save your current settings under a new name." },
            { 0, "Swing timer: the spark swells and the bar flashes when a swing is ready (optional)." },
            { 0, "|cff9fd6ff/tempus probe swing|r records swing and range events for comparison with Blizzard's swing timer." },
            { 0, "|cffffffffDiscoverable SpellPower integration|r: when the optional addon is missing or disabled, keep its sidebar entry visible in grey. Hover for a description of its chat spelling/grammar help and its CurseForge link; right-click for a copyable URL. The missing entry is searchable without opening settings. Installed and older standalone integrations keep their existing behavior." },
            { 0, "|cffffffffAutomatic layouts|r: opt in under General > Automatic layouts and assign position presets to Solo, Party and Raid. Switching waits for combat to end, locked frames, and editing/previews to finish, then uses the latest group/profile. Manual position changes and Undo/Redo take precedence for the current group type; Pause keeps manual control across group changes. Rules persist per profile; renamed presets keep their assignments. Each automatic switch is one undo action." },
            { 0, "|cffffffffSettings search|r: type in the sidebar to find page names, control labels and help text across eligible settings pages. Click a match to open the page, scroll to its control and highlight it. Enter opens the first match; Escape or x clears the query. Search uses literal, case-insensitive word matching and never activates controls. Full indexing waits until out of combat." },
            { 0, "|cffffffffGroup frame editing|r: Shift-click frames or toggle them in the positioning panel's selector to move them together. Align edges/centers, distribute equal visible gaps across three or more frames, or center a group on screen. Group dragging snaps its outer bounds; Alt bypasses snapping and arrows remain unsnapped. Mixed-scale frames preserve spacing, screen edges clamp the whole group, and each group change is one Undo/Redo step. Group editing is blocked during combat, resizing and pending drag saves. Selection is temporary and clears on lock/profile change/reload." },
            { 0, "|cffffffffPosition Undo/Redo|r in the unlocked positioning panel and Layout presets page: reverse drags, arrow nudges, applied presets and default-position restores. Each completed edit is one step, with up to 50 steps per profile until reload/logout. A new edit clears redo; no-ops preserve it. Combat and active dragging/resizing disable history controls. Sizes, colors and saved preset definitions stay unchanged." },
            { 0, "|cffffffffLayout presets|r under General: save position-only layouts in the current profile, duplicate and rename them, preview ghost frames before applying, cancel safely, and preview/restore module default positions without resetting other settings. Combat and active dragging block layout switching. Names never silently overwrite existing presets." },
            { 0, "|cffffffffFrame snapping and alignment guides|r: drag near frame or screen edges and centers to snap within 8 UI units; hold Alt to move freely. Arrow nudges remain unsnapped." },
            { 0, "Complete positioning, preset, storage and testing documentation in |cff9fd6ffdocs/layouts.md|r." },
            { 0, "|cffffffffSwing timer diagram|r: the Swing timer settings page shows a labelled drawing of the bar, explaining the spark, cue tick, time left and the out-of-range look." },
            { 0, "|cffffffffEmpty a bag|r: right-click a bag on the bag bar to move everything in it into your other bags (quivers and other special bags only get items they hold), then take the empty bag off into a free slot." },
            { 0, "|cffffffffDrag bags on and off the bag bar|r: drag a bag from the bar to an inventory slot to take it off, or drop a bag on a bar slot to equip or swap it. Hovering a bag shows its slot count, used and free." },
            { 0, "|cffffffffQuest progress on nameplates|r: quest mobs show how many you still need (\"4/10\") beside the quest marker, read from the tooltip or your quest log (Nameplates > General)." },
            { 0, "|cffffffffSecond colour|r: an optional second colour for the settings window, used for the selected-page marker, ticked checkboxes, slider fills and the lines beside section titles (Appearance)." },
        } },
        { title = "Changed", items = {
            { 0, "|cffffffffPreview-first Escape|r: while Tempus settings is open, Escape ends layout ghosts, test auras, group samples, Combat Pulse test mode and unlocked editing without closing settings. Press Escape again to close Tempus. Holding the key does not skip this step, and focused search gives active previews priority. The close button still closes immediately." },
            { 0, "Bags grid view always shows your real bag slots, so dragging one item onto another visibly swaps them. Display sorting now applies to Sections view only." },
            { 0, "Swing bar text switches between black and white to stay readable on any bar colour; the cue tick is warm white." },
        } },
    } },
    { version = "2.7.2", sections = {
        { title = "New", items = {
            { 0, "Shared positioning panel: select an unlocked frame from the list and use four arrows to nudge it by 1 UI unit, or Shift-click for 10. Protected frames cannot be nudged during combat." },
        } },
        { title = "Changed", items = {
            { 0, "Larger labeled drag handles make small frames easier to grab. The selected frame is highlighted; Escape locks the layout and hides positioning controls." },
        } },
    } },
    { version = "2.7.1", sections = {
        { title = "Changed", items = {
            { 0, "The beta bug-report banner at the top of the settings window is gone." },
        } },
    } },
    { version = "2.7.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffChat module|r: extras on top of Blizzard's chat windows, on their own Chat settings page. Web addresses become clickable links that open a box to copy from; a copy icon at the right end of the tab row (or |cff9fd6ff/tempus copychat|r) opens the selected window's text for copying; recent lines are saved and shown again after a reload or relog; timestamps can be set to 24-hour, 12-hour or off; and tabs and buttons can hide until the mouse is over the window. Lines the game hides during boss fights and Mythic+ runs are passed through untouched, because addons cannot read, search or save them. If Prat is loaded, switch off its matching modules so lines are not linked or stamped twice." },
            { 0, "|cffffffffDamage meter skin|r: Blizzard's built-in damage meter gets a Tempus panel, a flat title bar with recoloured buttons and dropdowns, flat bars with the class colours kept, and Tempus fonts and scrollbars (Skins > Damage meter, with an opacity slider). Applies after a reload." },
            { 0, "|cffffffffGathering node icons|r: ore and herb spots on the minimap get a small icon of what they are (Minimap > Gathering nodes). The game does not tell addons what its own tracking blips are, so Tempus learns a node when you mine or pick it (the icon is the first item looted). A node you gathered recently is shown dim until it has probably respawned (the game cannot say whether a node is up). The list starts empty and fills as you gather." },
            { 0, "|cffffffffTempus theme|r: a new look and the default for new profiles. Panels get an edge and a soft glow in your accent colour, a faint light along the top, and Tempus's own bar texture and the Inter font. Pick it under Appearance > Theme; the bar texture and font are separate choices there too." },
            { 0, "|cffffffffCombat colour|r: the accent switches to its own colour while you are in combat, so the whole interface shows when a fight starts (Appearance, on by default). There is also a new |cffffffffClass colour|r accent." },
            { 0, "|cffffffffRecent damage|r: on unit frames, nameplates and party and raid frames, a hit shows as a red chunk that drains away behind the health bar (\"Show recent damage\" on each page)." },
            { 0, "|cffffffffAnimations|r: the settings window, bags and the target frame fade in; your player frame glows and pulses red below a health threshold (Unit frames > General); cooldown icons flash when they are ready again; and dispellable debuffs make a group frame's tint breathe. Appearance > Animations turns them all off." },
            { 0, "|cffffffffFocus frame|r: a Tempus unit frame for your focus, with its own cast bar (Unit frames > Focus). Shown on clients that have a focus." },
            { 0, "|cffffffffInterrupt-aware cast bars|r: target and focus cast bars turn amber while your interrupt (Kick, Pummel, Shield Bash, Counterspell, Earth Shock, Spell Lock) is cooling down, and a mark at the bar's end shows you can interrupt now. Uninterruptible casts get a grey shield and edge, and an interrupted cast flashes." },
            { 0, "|cffffffffAutomation module|r (General > Automation): accepts quests and hands in finished ones (it never chooses between rewards or pays gold, and Shift skips it), hides repeated red errors such as \"Ability is not ready yet\", loots everything at once when auto-loot is on, and an optional AFK screen fades the interface and turns the camera while you are away." },
            { 0, "|cffffffffTidier minimap buttons|r: the tray and hide-until-mouseover now also catch addon buttons that do not use LibDBIcon (Healium, TalentsForeverBook, the ForeverUtilities class helpers and others), and addon buttons lose Blizzard's round gold ring for a flat square Tempus edge (Minimap > Square addon buttons). Two new Addon buttons choices, |cffffffffRow under the map|r and |cffffffffColumn on the left|r, line every addon button up 1px apart along the map, always visible." },
            { 0, "|cffffffffMinimap footer|r: the clock and coordinates move into a slim bar under the map, and addon buttons line up in a row beneath it (or a column on the map's left), 1px apart; click the footer to fold the row away. Blizzard's zone text (where Questie writes its own coordinates) no longer shows next to Tempus's." },
            { 0, "|cff9fd6ff/tempus probe chat|r records whether chat arrives as secret values on your client, in the open world, in groups and in instances." },
        } },
        { title = "Changed", items = {
            { 0, "|cffffffffThe beta is ending|r: a banner at the top of the settings window asks you to report bugs, with the issues address ready to copy." },
            { 0, "\"What's new\" is pinned at the top of the settings sidebar, and every sidebar section starts closed when you open the settings." },
            { 0, "New profiles use your class colour as the accent." },
            { 0, "The new Chat, Gathering nodes and Automation modules start switched on in existing profiles too; turn any of them off under General > Modules." },
        } },
    } },
    { version = "2.6.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffNative Bags module|r: combined carried bags and personal/reagent bank windows with instant multi-word search, native item interactions and sorting, plus grid and automatic category views. Filter chips (gear, consumables, quest, junk), a bag bar that highlights or isolates one bag, item level and bind-on-equip tags, upgrade arrows, cooldowns, durability tint, and a footer with slots, currencies and gold. Category sections fold when you click their headers, items sort by quality and item level, and Tag lets you build your own categories. New installs enable it; upgraded profiles keep it off until enabled. When another bag addon is active, Tempus asks which one should own the bags for that character." },
            { 0, "|cffffffffOther characters in Bags|r: Tempus saves what each character carries and keeps in the bank and reagent bank. Alts in the bag header opens a menu of every saved character and storage, shown in the same window (read-only, with search, filters, grid and category views). Your own bank is listed there too, so you can browse it away from the banker. Item tooltips gain a line per character, such as |cff9fd6ffBags 4  Bank 12|r. The bank saves while it is open; characters appear after you log into them once. Turn it off, or forget the other characters, on the Bags page." },
            { 0, "|cffffffffMouseover keybinds for healers|r: hover a party or raid frame and press a key to cast on that player, in combat too. Up to 8 per class, with Shift, Ctrl or Alt (Party & raid frames > Click-casting)." },
            { 0, "|cffffffffResize group frames by dragging|r: unlock the UI and drag the grip in the corner of the party or raid box; the frame width and height follow the settings sliders." },
            { 0, "|cffffffffGroup frame size presets|r: Compact, Standard and Large set frame sizes, spacing, text and aura sizes for party and raid in one click (Party & raid frames > General)." },
            { 0, "|cffffffffMinimap button tray|r: \"Addon buttons\" on the Minimap page can now collect every addon minimap button into a tray. Right-click the Tempus button, now a square in the map's lower right corner, to open the grid of buttons; left-click still opens settings. The tray closes when you move away. Around the edge and Hide until mouseover still work as before." },
            { 0, "|cffffffffHide names on group frames|r: \"Show player names\" on the Party and Raid pages turns names off for a compact grid of bars and health text." },
            { 0, "|cffffffffParty frames by role|r: the party can list tank, healer, then damage (Party > Arrange by); party order is still available." },
            { 0, "|cffffffffCombat Pulse bar scale|r: choose Auto or a Fixed maximum DPS for the end of the bar (General > Combat Pulse). In combat the game hides DPS, so Auto can only size the bar from earlier readable fights and early-fight bursts can fill it; a fixed maximum avoids the guesswork." },
        } },
        { title = "Changed", items = {
            { 0, "New profiles show health percent on group frames by default." },
            { 0, "Changing the accent colour recolours the settings window, move boxes and bags straight away; some Blizzard skins still need a reload." },
            { 0, "The bag bar and micro menu lose Blizzard's bronze frame, and their buttons are one size." },
            { 0, "Dropdown menus widen to fit their longest label, open toward the side of the screen with room, and scroll when the list is long." },
        } },
        { title = "Fixed", items = {
            { 0, "Vendor: the \"sold grey items for\" total was always 0 on clients without the old |cff9fd6ffGetItemInfo|r. It now reads prices from |cff9fd6ffC_Item.GetItemInfo|r and falls back to the gold you actually received." },
            { 0, "Bags: moving a window by its body now saves its position, and stacks of 1000 or more show as |cff9fd6ff1k|r." },
        } },
    } },
    { version = "2.5.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffCombat Pulse|r: one compact combat strip. It combines a layered DPS bar from Blizzard's damage meter (purple to your live DPS, gold to your peak, red to the group's top), a thin swing line, and small cues for an interruptible target cast, a buff you can purge, threat trouble and the execute range. Choose Minimal (urgent cues only), Standard or Full; every signal can be switched off, and threat and execute follow your Nameplates settings. Settings, a test mode and reset position are under General > Combat Pulse. Unlock the UI to move it." },
        } },
    } },
    { version = "2.4.1", sections = {
        { title = "Changed", items = {
            { 0, "Releases are now published on CurseForge. No other changes from 2.4.0." },
        } },
    } },
    { version = "2.4.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffSwing timer module|r: bars for your main hand, off hand and ranged weapon that refill on every auto attack and turn red while your target is out of range, using WoW Forever's new range check. Unlock the UI to move it; settings are under General > Swing timer." },
            { 0, "|cffffffffQuest tracker skin|r: quest titles and objectives use the Tempus font and outline, and quest item buttons get square Tempus icons." },
        } },
        { title = "Changed", items = {
            { 0, "The quest tracker's zone folding and search box are gone. They rearranged Blizzard's tracker, and that caused \"Auras cannot be accessed when secret while tainted by 'Tempus'\" errors. Quest log search is unchanged." },
        } },
        { title = "Fixed", items = {
            { 0, "No more Lua error from the quest tracker when you level up in combat." },
        } },
    } },
    { version = "2.3.1", sections = {
        { title = "Fixed", items = {
            { 0, "The Modules step of the first-run setup lays its checkboxes out in two columns, so the list no longer runs off the bottom of the window." },
        } },
    } },
    { version = "2.3.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffShare profiles|r: Export turns the active profile into a text string; Import creates a new profile from one (General > Profiles). Damaged or edited strings are refused, and nothing in them is ever run." },
            { 0, "|cffffffffCooldowns module|r: a movable row of icons with cooldown swipes for spells you list and your trinkets. \"Add my interrupt\" adds your class's interrupt." },
            { 0, "|cffffffffVendor module|r: sells grey items and repairs gear when you open a merchant (optionally from guild funds), with a short chat summary." },
            { 0, "|cffffffffDispellable buff alert|r on nameplates: a purple edge on enemies carrying a buff you can dispel or steal. It works in combat." },
        } },
    } },
    { version = "2.2.1", sections = {
        { title = "Fixed", items = {
            { 0, "The five combo point boxes above the player frame now show only for rogues and druids in cat form, not for every class." },
        } },
    } },
    { version = "2.2.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffYour interrupt on nameplates|r: your own interrupt, with its cooldown swipe, shows beside casts you can stop (Nameplates > Casts & Auras). Hidden for classes without one." },
            { 0, "|cffffffffWho interrupted|r: a stopped cast reads \"Interrupted: Name\" when the game reports who did it." },
        } },
    } },
    { version = "2.1.3", sections = {
        { title = "New", items = {
            { 0, "|cffffffffSpellPower settings in the Tempus window|r: with SpellPower 0.3.0 or newer installed, its pages are listed in the sidebar and shown in the Tempus window, in the same look." },
        } },
    } },
    { version = "2.1.2", sections = {
        { title = "New", items = {
            { 0, "|cffffffffSpellPower|r gets a section in the settings sidebar (when the addon is installed) with a button that opens its settings." },
        } },
        { title = "Fixed", items = {
            { 0, "The quest tracker no longer stops refreshing if a layout pass hits an error." },
        } },
    } },
    { version = "2.1.1", sections = {
        { title = "Fixed", items = {
            { 0, "|cffffffffTaint error on level-up|r: hiding Blizzard's buff and debuff frames no longer reparents them, which caused \"Auras cannot be accessed when secret while tainted\" when Edit Mode refreshed." },
        } },
    } },
    { version = "2.1.0", sections = {
        { title = "New", items = {
            { 0, "|cffffffffThemes apply everywhere|r: Modern, Gloss, Classic and Flat now restyle every Tempus panel and status bar (unit, party and raid frames, nameplates, action bars, minimap, info bar, skinned windows) live, not just buffs. Class, dispel and target highlight edges stay visible in every theme." },
            { 0, "|cffffffffWhat's new page|r in the settings window (General), showing this changelog." },
            { 0, "|cffffffffQuest log search|r: a search box over the quest list that tolerates typos and matches zone names, a Zones button to hide whole zones, and Reset." },
            { 0, "|cffffffffQuest tracker zones and search|r: tracked quests are grouped under zone headers that fold (remembered per character), plus a fuzzy search box at the top of the tracker." },
            { 0, "|cffffffffStock skin|r (Skins page): Blizzard's own look for windows, tooltips, chat and the tracker, with all Tempus features kept." },
            { 0, "|cffffffffNameplates|r" },
            { 1, "A replacement for Blizzard's plates: threat colours by role, execute-range tint and a target glow." },
            { 1, "Cast bars that show when a cast can be interrupted, and alerts for spells on your watch list." },
            { 1, "Your debuffs, purgeable buffs and crowd control." },
            { 0, "|cffffffffCon on nameplates|r: a con-coloured strip, relative level, elite/rare/boss pips or an optional 1-5 danger rating, and grey mobs shrunk and faded." },
            { 0, "|cffffffffParty & Raid frames|r" },
            { 1, "Secure group headers, range fading, incoming heals and absorbs." },
            { 1, "Dispellable debuffs with a coloured tint, your HoTs with timers, and role, leader, ready-check and aggro indicators." },
            { 0, "|cffffffffClick-casting|r on party and raid frames, with starting bindings for Druid, Priest, Shaman and Paladin, and a preview that explains each click." },
            { 0, "|cffffffffPreviews|r: sample nameplates and group frames on their settings pages, plus on-screen sample party/raid frames for arranging them solo." },
            { 0, "|cffffffffAccent colour|r: six to choose from (Appearance)." },
            { 0, "The installer presets now cover nameplates and group frames." },
        } },
        { title = "Fixed", items = {
            { 0, "The panel behind the quest tracker now stays the height of its content when sections change, zones fold or the tracker collapses." },
            { 0, "Target frame auras duplicated on every retarget." },
            { 0, "Spellbook category tabs lost their icons." },
            { 0, "Quest and book text is dark brown on parchment instead of light grey." },
            { 0, "The unit frames' \"by health\" colour never reached green." },
            { 0, "Settings pages could stop scrolling partway down." },
        } },
        { title = "Changed", items = {
            { 0, "New Tempus logo (a clock whose hands form a T) in the AddOns list, settings, installer and minimap button, replacing the pocket-watch icon." },
            { 0, "Developer probing is off by default (|cff9fd6ff/tempus probe|r to turn it on, |cff9fd6ff/tempus probe off|r to clear it)." },
            { 0, "Tempus UI is now published under an All Rights Reserved license (see LICENSE): free to download and play with; redistribution or reuse needs permission." },
        } },
    } },
}
