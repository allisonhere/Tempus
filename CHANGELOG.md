# Changelog

## Unreleased

### Fixed
- Center the Need/Greed loot-roll stack above the hotbars and style its panels, fonts and countdown bars with the Tempus Windows skin. Native voting buttons and item tooltips are preserved.

## 2.11.5

### Changed
- **One chat log window**: reviewing and copying chat was split between a copy window and a separate select mode, each with its own icon by the tabs, its own setting and its own slash command. There is now one window that does both. Open it with the copy icon at the end of the tab row, by Alt+clicking a chat window, or with `/tempus copychat` (`/tempus selectchat` still works). Drag or Shift+arrows to select, Ctrl+A picks the lot, Ctrl+C copies, Esc closes. Colours start off, so what you paste outside the game is plain text; the **Colours** button shows the lines the way chat draws them. Lines that arrive while the window is open are counted and added by **Update**, so they cannot move the text under your selection. Typing in the window is put back, and the corner can be dragged to resize it. Chat settings now hold one checkbox, **Chat log button next to the tabs**, instead of two.

## 2.11.4

### Changed
- Settings pages use clearer labels and help text, and errors explain what to fix.
- Style Studio is now the single appearance page. Its live sample scene and controls make it easier to see how themes, fonts, bars, colours and icons will look together.

## 2.11.3

### Changed
- New Tempus icon: a neon hourglass. The addon list, installer and Automation bar use the square version; the minimap button (docked or not) uses a round version with its neon ring.

## 2.11.2

### Changed
- The settings window header has a new animated hourglass logo: the sand runs down, then the glass flips over, in 30 frames on a loop of about five seconds. It only animates while settings are open, and it stays still when the Animations setting is off. The minimap button keeps the clock icon.
- New settings window header: a silver TEMPUS UI wordmark, a diagonal band holding your profile and version, glowing edge lines, and outlined Preview and Unlock buttons. It follows your Appearance colours: the band and Unlock take the accent, the slash, base line and Preview take the second colour.

### Fixed
- Removed work-in-progress design files that were accidentally packaged in 2.11.1.

## 2.11.1

### Fixed
- Bags: the bank window could open with **0 / 0** slots on WoW Forever. Tempus hid Blizzard's bank frame completely, and the game only fills in the bank (its 48-slot main bank and bank bags) while that frame is on screen. Blizzard's bank now stays open but invisible behind the Tempus window, so the bank fills in every time; **Manage** still shows it.
- Bags: the bank's **Manage** button moved up into the window header next to Tag, instead of floating on the Personal row.

## 2.11.0

### New
- **Chat select mode**: Alt+click a chat window, or click the new I-beam button by the chat tabs, and the window turns into text you can select like a text editor: drag with the mouse, Shift+arrows, Ctrl+A, then Ctrl+C. Colours stay. Esc, Enter or switching tabs puts normal chat back, where links are clickable again. Lines that arrive while you are selecting are counted instead of jumping the text; click **update** to add them. Also `/tempus selectchat` (Chat > Select mode for chat history).
- **New chat look** (Skins > Chat frames): messages and the edit box share one panel. The active tab is bright with an accent underline and the others are dimmed; tabs light up on hover and show an unread count, which pulses pink for whispers. Chat uses your Tempus font with a little more line spacing, a **Back to newest** button appears when you scroll up (instead of the arrow column), and the edit box edge takes the colour of the channel you are typing in. Each part can be turned off; they apply after a reload.
- **Whisper alert** (Chat > Whisper alert): when someone whispers you, a pink banner shows who it is and the start of the message, a sound plays (pick it, or turn it off; it plays even with game sounds muted), and WoW's taskbar icon flashes when the game is in the background. Options for combat and Battle.net whispers, a Test button, and the banner can be moved with the UI unlocked. Press R to reply.
- **Cleaner chat text** (Chat > Text): short channel names (`[2. Trade - City]` becomes `[T]`), class-coloured player names, and grey timestamps.
- **Arrow keys move the cursor** in the chat box without holding Alt: Left, Right, Home and End move, Shift selects, Up and Down walk your sent messages. SpellPower's spell checking and shortcuts keep working (Chat > Typing).
- **Edit box position**: a slider moves the chat edit box left or right (Skins > Chat frames > Edit box left / right).

### Fixed
- The chat copy window came up empty when the window held Battle.net whispers. Friends' names now show as their BattleTag name.
- Changing the chat font size from a chat tab's menu works while the Tempus chat font is on.

## 2.10.0

### New
- **Style Studio** (General > Style Studio): sample player and target frames, enemy nameplates, buffs, debuffs, action buttons and cast bars in one live scene. Change the theme, bar texture, font, outline, accent colour or icon crop and watch every sample update at once; pause the scene to compare details. Changes save immediately, and the scene uses simulated data without turning on any module's test mode.
- **Auction values** (General > Auction values): with Auctionator enabled, item tooltips show its last scanned price and how old the data is, and Tempus bags show stack estimates. At the auction house, **Scan bag items** searches your carried items through Auctionator (it never buys or posts). Unknown prices stay unknown and old prices are marked stale.

### Fixed
- Bags: the bank window showed no slots on clients that use character bank tabs. It now reads your purchased bank tabs as well as the older bank and bank bags, so the bank (and the Alts viewer's saved bank) fills in again.


## 2.9.0

### New
- **Resource ticker**: a thin bar under the swing timer that fills toward your next energy or mana tick (they come every 2 seconds), so you can wait for the tick before an expensive move or a cast. After you spend mana it turns violet and counts down the five-second rule first. It learns the tick timing from ticks it sees, ignoring refunds and potions. Preview, size and when to show it are on General > Resource ticker.
- **Shopping list**: a small panel of items you are collecting with a target amount ("Linen Cloth 20"), showing what this character has in bags and bank plus what your alts hold. Shift-click an item into its box (or type a name) and press Enter; mouse wheel changes the amount, right-click removes. Item tooltips show your progress, and finishing an item says so. Also `/tempus shop <item> <amount>`, `/tempus shop remove <item>`, `/tempus shop clear` (Bags > Shopping list).
- **Danger alert**: a warning at the top of the screen when a risky mob's nameplate appears (elite, rare, ?? level or several levels above you) or a hostile PvP player, and when more mobs are on you than you meant to pull. No warnings while you are on a flight path. Each mob warns once, then stays quiet for a while; sound, level gap and pull size are adjustable (General > Danger alert).
- **Live bar demos in settings**: every animated bar now plays on its own page. Nameplates and Party & Raid samples take hits (the red "recent damage" chunk drains away) and nameplates cast, with every other cast interrupted. Unit Frames > General has a live player frame with health, power, the low-health glow and a cast bar. The Swing timer page has live bars under its diagram, and the Resource ticker page has energy and mana bars. They follow your current settings and only run while the page is open.

- **Skip empty loot**: looting a corpse with nothing on it no longer opens an empty loot window (General > Automation).
- **Grey out on cooldown** for action bar buttons: a button's icon turns grey while its spell or item is on cooldown, on top of Blizzard's dark sweep (the global cooldown doesn't count). On by default; Action Bars > General.

### Changed
- Swing timer and resource ticker text is now always white with a black outline, so it stays readable over both the filled and the empty part of the bar (it used to turn black on light bars and vanish over the dark empty part).

### Fixed
- Cooldowns: icons stayed in colour during a cooldown in combat, because the game hides cooldown times from addons there. They now grey out in combat too.


## 2.8.0

### New
- **Next-swing cue**: each swing bar gets a tick near its end, and the bar turns soft teal for the last moments before the swing lands, so you can time on-next-swing abilities (Heroic Strike, Maul). The window is a lead time you choose plus, optionally, your latency; an optional sound plays when it starts (Swing timer settings).
- **Fight summary**: when combat ends, a line under the swing timer shows how much of the fight you spent swinging, out of range or idle (`/tempus swing` repeats it; Swing timer settings turn it off).
- Escape locks the UI again after unlocking it, and the Profiles page can save your current settings under a new name.
- Swing timer: the spark swells and the bar flashes when a swing is ready (optional).
- `/tempus probe swing` records swing and range events for comparison with Blizzard's swing timer.
- **Discoverable SpellPower integration**: when the optional addon is missing or disabled, keep its sidebar entry visible in grey. Hover for a description of its chat spelling/grammar help and its CurseForge link; right-click for a copyable URL. The missing entry is searchable without opening settings. Installed and older standalone integrations keep their existing behavior.
- **Automatic layouts**: opt in under General > Automatic layouts and assign position presets to Solo, Party and Raid. Switching waits for combat to end, locked frames, and editing/previews to finish, then uses the latest group/profile. Manual position changes and Undo/Redo take precedence for the current group type; Pause keeps manual control across group changes. Rules persist per profile; renamed presets keep their assignments. Each automatic switch is one undo action.
- **Settings search**: type in the sidebar to find page names, control labels and help text across eligible settings pages. Click a match to open the page, scroll to its control and highlight it. Enter opens the first match; Escape or x clears the query. Search uses literal, case-insensitive word matching and never activates controls. Full indexing waits until out of combat.
- **Group frame editing**: Shift-click frames or toggle them in the positioning panel's selector to move them together. Align edges/centers, distribute equal visible gaps across three or more frames, or center a group on screen. Group dragging snaps its outer bounds; Alt bypasses snapping and arrows remain unsnapped. Mixed-scale frames preserve spacing, screen edges clamp the whole group, and each group change is one Undo/Redo step. Group editing is blocked during combat, resizing and pending drag saves. Selection is temporary and clears on lock/profile change/reload.
- **Position Undo/Redo** in the unlocked positioning panel and Layout presets page: reverse drags, arrow nudges, applied presets and default-position restores. Each completed edit is one step, with up to 50 steps per profile until reload/logout. A new edit clears redo; no-ops preserve it. Combat and active dragging/resizing disable history controls. Sizes, colors and saved preset definitions stay unchanged.
- **Layout presets** under General: save position-only layouts in the current profile, duplicate and rename them, preview ghost frames before applying, cancel safely, and preview/restore module default positions without resetting other settings. Combat and active dragging block layout switching. Names never silently overwrite existing presets.
- **Frame snapping and alignment guides**: drag near frame or screen edges and centers to snap within 8 UI units; hold Alt to move freely. Arrow nudges remain unsnapped.
- Complete positioning, preset, storage and testing documentation in `docs/layouts.md`.
- **Swing timer diagram**: the Swing timer settings page shows a labelled drawing of the bar, explaining the spark, cue tick, time left and the out-of-range look.
- **Empty a bag**: right-click a bag on the bag bar to move everything in it into your other bags (quivers and other special bags only get items they hold), then take the empty bag off into a free slot.
- **Drag bags on and off the bag bar**: drag a bag from the bar to an inventory slot to take it off, or drop a bag on a bar slot to equip or swap it. Hovering a bag shows its slot count, used and free.
- **Quest progress on nameplates**: quest mobs show how many you still need ("4/10") beside the quest marker, read from the tooltip or your quest log (Nameplates > General).
- **Second colour**: an optional second colour for the settings window, used for the selected-page marker, ticked checkboxes, slider fills and the lines beside section titles (Appearance).

### Changed
- **Preview-first Escape**: while Tempus settings is open, Escape ends layout ghosts, test auras, group samples, Combat Pulse test mode and unlocked editing without closing settings. Press Escape again to close Tempus. Holding the key does not skip this step, and focused search gives active previews priority. The close button still closes immediately.
- Bags grid view always shows your real bag slots, so dragging one item onto another visibly swaps them. Display sorting now applies to Sections view only.
- Swing bar text switches between black and white to stay readable on any bar colour; the cue tick is warm white.

## 2.7.2

### New
- Shared positioning panel: select an unlocked frame from the list and use four arrows to nudge it by 1 UI unit, or Shift-click for 10. Protected frames cannot be nudged during combat.

### Changed
- Larger labeled drag handles make small frames easier to grab. The selected frame is highlighted; Escape locks the layout and hides positioning controls.

## 2.7.1

### Changed
- The beta bug-report banner at the top of the settings window is gone.

## 2.7.0

### New
- **Chat module**: extras on top of Blizzard's chat windows, on their own Chat settings page. Web addresses become clickable links that open a box to copy from; a copy icon at the right end of the tab row (or `/tempus copychat`) opens the selected window's text for copying; recent lines are saved and shown again after a reload or relog; timestamps can be set to 24-hour, 12-hour or off; and tabs and buttons can hide until the mouse is over the window. Lines the game hides during boss fights and Mythic+ runs are passed through untouched, because addons cannot read, search or save them. If Prat is loaded, switch off its matching modules so lines are not linked or stamped twice.
- **Damage meter skin**: Blizzard's built-in damage meter gets a Tempus panel, a flat title bar with recoloured buttons and dropdowns, flat bars with the class colours kept, and Tempus fonts and scrollbars (Skins > Damage meter, with an opacity slider). Applies after a reload.
- **Gathering node icons**: ore and herb spots on the minimap get a small icon of what they are (Minimap > Gathering nodes). The game does not tell addons what its own tracking blips are, so Tempus learns a node when you mine or pick it (the icon is the first item looted). A node you gathered recently is shown dim until it has probably respawned (the game cannot say whether a node is up). The list starts empty and fills as you gather.
- **Tempus theme**: a new look and the default for new profiles. Panels get an edge and a soft glow in your accent colour, a faint light along the top, and Tempus's own bar texture and the Inter font. Pick it under Appearance > Theme; the bar texture and font are separate choices there too.
- **Combat colour**: the accent switches to its own colour while you are in combat, so the whole interface shows when a fight starts (Appearance, on by default). There is also a new **Class colour** accent.
- **Recent damage**: on unit frames, nameplates and party and raid frames, a hit shows as a red chunk that drains away behind the health bar ("Show recent damage" on each page).
- **Animations**: the settings window, bags and the target frame fade in; your player frame glows and pulses red below a health threshold (Unit frames > General); cooldown icons flash when they are ready again; and dispellable debuffs make a group frame's tint breathe. Appearance > Animations turns them all off.
- **Focus frame**: a Tempus unit frame for your focus, with its own cast bar (Unit frames > Focus). Shown on clients that have a focus.
- **Interrupt-aware cast bars**: target and focus cast bars turn amber while your interrupt (Kick, Pummel, Shield Bash, Counterspell, Earth Shock, Spell Lock) is cooling down, and a mark at the bar's end shows you can interrupt now. Uninterruptible casts get a grey shield and edge, and an interrupted cast flashes.
- **Automation module** (General > Automation): accepts quests and hands in finished ones (it never chooses between rewards or pays gold, and Shift skips it), hides repeated red errors such as "Ability is not ready yet", loots everything at once when auto-loot is on, and an optional AFK screen fades the interface and turns the camera while you are away.
- **Tidier minimap buttons**: the tray and hide-until-mouseover now also catch addon buttons that do not use LibDBIcon (Healium, TalentsForeverBook, the ForeverUtilities class helpers and others), and addon buttons lose Blizzard's round gold ring for a flat square Tempus edge (Minimap > Square addon buttons). Two new Addon buttons choices, **Row under the map** and **Column on the left**, line every addon button up 1px apart along the map, always visible.
- **Minimap footer**: the clock and coordinates move into a slim bar under the map, and addon buttons line up in a row beneath it (or a column on the map's left), 1px apart; click the footer to fold the row away. Blizzard's zone text (where Questie writes its own coordinates) no longer shows next to Tempus's.
- `/tempus probe chat` records whether chat arrives as secret values on your client, in the open world, in groups and in instances.

### Changed
- **The beta is ending**: a banner at the top of the settings window asks you to report bugs, with the issues address ready to copy.
- "What's new" is pinned at the top of the settings sidebar, and every sidebar section starts closed when you open the settings.
- New profiles use your class colour as the accent.
- The new Chat, Gathering nodes and Automation modules start switched on in existing profiles too; turn any of them off under General > Modules.

## 2.6.0

### New
- **Native Bags module**: combined carried bags and personal/reagent bank windows with instant multi-word search, native item interactions and sorting, plus grid and automatic category views. Filter chips (gear, consumables, quest, junk), a bag bar that highlights or isolates one bag, item level and bind-on-equip tags, upgrade arrows, cooldowns, durability tint, and a footer with slots, currencies and gold. Category sections fold when you click their headers, items sort by quality and item level, and Tag lets you build your own categories. New installs enable it; upgraded profiles keep it off until enabled. When another bag addon is active, Tempus asks which one should own the bags for that character.
- **Other characters in Bags**: Tempus saves what each character carries and keeps in the bank and reagent bank. Alts in the bag header opens a menu of every saved character and storage, shown in the same window (read-only, with search, filters, grid and category views). Your own bank is listed there too, so you can browse it away from the banker. Item tooltips gain a line per character, such as `Bags 4  Bank 12`. The bank saves while it is open; characters appear after you log into them once. Turn it off, or forget the other characters, on the Bags page.
- **Mouseover keybinds for healers**: hover a party or raid frame and press a key to cast on that player, in combat too. Up to 8 per class, with Shift, Ctrl or Alt (Party & raid frames > Click-casting).
- **Resize group frames by dragging**: unlock the UI and drag the grip in the corner of the party or raid box; the frame width and height follow the settings sliders.
- **Group frame size presets**: Compact, Standard and Large set frame sizes, spacing, text and aura sizes for party and raid in one click (Party & raid frames > General).
- **Minimap button tray**: "Addon buttons" on the Minimap page can now collect every addon minimap button into a tray. Right-click the Tempus button, now a square in the map's lower right corner, to open the grid of buttons; left-click still opens settings. The tray closes when you move away. Around the edge and Hide until mouseover still work as before.
- **Hide names on group frames**: "Show player names" on the Party and Raid pages turns names off for a compact grid of bars and health text.
- **Party frames by role**: the party can list tank, healer, then damage (Party > Arrange by); party order is still available.
- **Combat Pulse bar scale**: choose Auto or a Fixed maximum DPS for the end of the bar (General > Combat Pulse). In combat the game hides DPS, so Auto can only size the bar from earlier readable fights and early-fight bursts can fill it; a fixed maximum avoids the guesswork.

### Changed
- New profiles show health percent on group frames by default.
- Changing the accent colour recolours the settings window, move boxes and bags straight away; some Blizzard skins still need a reload.
- The bag bar and micro menu lose Blizzard's bronze frame, and their buttons are one size.
- Dropdown menus widen to fit their longest label, open toward the side of the screen with room, and scroll when the list is long.

### Fixed
- Vendor: the "sold grey items for" total was always 0 on clients without the old `GetItemInfo`. It now reads prices from `C_Item.GetItemInfo` and falls back to the gold you actually received.
- Bags: moving a window by its body now saves its position, and stacks of 1000 or more show as `1k`.

## 2.5.0

### New
- **Combat Pulse**: one compact combat strip. It combines a layered DPS bar from Blizzard's damage meter (purple to your live DPS, gold to your peak, red to the group's top), a thin swing line, and small cues for an interruptible target cast, a buff you can purge, threat trouble and the execute range. Choose Minimal (urgent cues only), Standard or Full; every signal can be switched off, and threat and execute follow your Nameplates settings. Settings, a test mode and reset position are under General > Combat Pulse. Unlock the UI to move it.

## 2.4.1

### Changed
- Releases are now published on CurseForge. No other changes from 2.4.0.

## 2.4.0

### New
- **Swing timer module**: bars for your main hand, off hand and ranged weapon that refill on every auto attack and turn red while your target is out of range, using WoW Forever's new range check. Unlock the UI to move it; settings are under General > Swing timer.
- **Quest tracker skin**: quest titles and objectives use the Tempus font and outline, and quest item buttons get square Tempus icons.

### Changed
- The quest tracker's zone folding and search box are gone. They rearranged Blizzard's tracker, and that caused "Auras cannot be accessed when secret while tainted by 'Tempus'" errors. Quest log search is unchanged.

### Fixed
- No more Lua error from the quest tracker when you level up in combat.

## 2.3.1

### Fixed
- The Modules step of the first-run setup lays its checkboxes out in two columns, so the list no longer runs off the bottom of the window.

## 2.3.0

### New
- **Share profiles**: Export turns the active profile into a text string; Import creates a new profile from one (General > Profiles). Damaged or edited strings are refused, and nothing in them is ever run.
- **Cooldowns module**: a movable row of icons with cooldown swipes for spells you list and your trinkets. "Add my interrupt" adds your class's interrupt.
- **Vendor module**: sells grey items and repairs gear when you open a merchant (optionally from guild funds), with a short chat summary.
- **Dispellable buff alert** on nameplates: a purple edge on enemies carrying a buff you can dispel or steal. It works in combat.

## 2.2.1

### Fixed
- The five combo point boxes above the player frame now show only for rogues and druids in cat form, not for every class.

## 2.2.0

### New
- **Your interrupt on nameplates**: your own interrupt, with its cooldown swipe, shows beside casts you can stop (Nameplates > Casts & Auras). Hidden for classes without one.
- **Who interrupted**: a stopped cast reads "Interrupted: Name" when the game reports who did it.

## 2.1.3

### New
- **SpellPower settings in the Tempus window**: with SpellPower 0.3.0 or newer installed, its pages are listed in the sidebar and shown in the Tempus window, in the same look.

## 2.1.2

### New
- **SpellPower** gets a section in the settings sidebar (when the addon is installed) with a button that opens its settings.

### Fixed
- The quest tracker no longer stops refreshing if a layout pass hits an error.

## 2.1.1

### Fixed
- **Taint error on level-up**: hiding Blizzard's buff and debuff frames no longer reparents them, which caused "Auras cannot be accessed when secret while tainted" when Edit Mode refreshed.

## 2.1.0

### New
- **Themes apply everywhere**: Modern, Gloss, Classic and Flat now restyle every Tempus panel and status bar (unit, party and raid frames, nameplates, action bars, minimap, info bar, skinned windows) live, not just buffs. Class, dispel and target highlight edges stay visible in every theme.
- **What's new page** in the settings window (General), showing this changelog.
- **Quest log search**: a search box over the quest list that tolerates typos and matches zone names, a Zones button to hide whole zones, and Reset.
- **Quest tracker zones and search**: tracked quests are grouped under zone headers that fold (remembered per character), plus a fuzzy search box at the top of the tracker.
- **Stock skin** (Skins page): Blizzard's own look for windows, tooltips, chat and the tracker, with all Tempus features kept.
- **Nameplates**
  - A replacement for Blizzard's plates: threat colours by role, execute-range tint and a target glow.
  - Cast bars that show when a cast can be interrupted, and alerts for spells on your watch list.
  - Your debuffs, purgeable buffs and crowd control.
- **Con on nameplates**: a con-coloured strip, relative level, elite/rare/boss pips or an optional 1-5 danger rating, and grey mobs shrunk and faded.
- **Party & Raid frames**
  - Secure group headers, range fading, incoming heals and absorbs.
  - Dispellable debuffs with a coloured tint, your HoTs with timers, and role, leader, ready-check and aggro indicators.
- **Click-casting** on party and raid frames, with starting bindings for Druid, Priest, Shaman and Paladin, and a preview that explains each click.
- **Previews**: sample nameplates and group frames on their settings pages, plus on-screen sample party/raid frames for arranging them solo.
- **Accent colour**: six to choose from (Appearance).
- The installer presets now cover nameplates and group frames.

### Fixed
- The panel behind the quest tracker now stays the height of its content when sections change, zones fold or the tracker collapses.
- Target frame auras duplicated on every retarget.
- Spellbook category tabs lost their icons.
- Quest and book text is dark brown on parchment instead of light grey.
- The unit frames' "by health" colour never reached green.
- Settings pages could stop scrolling partway down.

### Changed
- New Tempus logo (a clock whose hands form a T) in the AddOns list, settings, installer and minimap button, replacing the pocket-watch icon.
- Developer probing is off by default (`/tempus probe` to turn it on, `/tempus probe off` to clear it).
- Tempus UI is now published under an All Rights Reserved license (see LICENSE): free to download and play with; redistribution or reuse needs permission.
