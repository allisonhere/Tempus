## Tempus UI

Tempus is a full interface addon for **Warcraft Forever**. Unit frames, nameplates, party and raid frames, buffs, action bars, bags, chat, a square minimap, timelines for cooldowns and debuffs, a gear advisor for the auction house, and skins for Blizzard's windows all share one look. Every part is a module you can switch off, so use all of it or keep only what you like.

**Built for Forever's combat restrictions.** In combat, Forever hides health, auras, range and many other values from addons. Tempus is written around that: it draws what the game lets it draw, times your own casts where auras cannot be read, and says so where a feature has a limit, so your bars, timers and colours keep updating in the middle of a fight instead of breaking.

Type `/tempus` to open settings. A first-run setup helps you pick modules, a UI scale and a layout. Every settings page has a live preview, and a search box in the sidebar finds settings by their label or help text.

---

### Fighting

- **Unit, party and raid frames.**
  - Cast bars, portraits, combo points, incoming heals and absorbs, dispellable debuffs with a coloured tint, range fading, aggro borders, role and leader icons, and your own heals over time with timers.
  - Built-in click casting with starting bindings for Druid, Priest, Shaman and Paladin (Clique also works), and mouseover keybinds: hover a frame and press a key to cast on that player, in combat too.
  - A raid grid for up to 40, a corner grip to resize unlocked group frames, Compact, Standard and Large presets, and an option to list tanks and healers first.
  - Combo points rise in height and shade from red to green as you build them.
- **Nameplates.**
  - Threat colours for a tank or damage role, execute range, class and reaction colours.
  - A level strip at a glance: relative level, elite pips or a one-to-five danger rating, with grey mobs shrunk and faded.
  - Cast bars that show whether a cast can be interrupted, your own interrupt with its cooldown, and who stopped a cast.
  - Your debuffs, crowd control, alerts for spells on your watch list, and a purple edge on enemies carrying a buff you can dispel or steal.
  - They stay off while Plater or another nameplate addon is loaded.
- **Buffs and debuffs.** Icon or bar timers, a watch list for buffs you never want to forget, expiry warnings, and click to recast or cancel.
- **Combat Pulse.** One compact strip: a layered DPS bar from Blizzard's damage meter, a thin swing line, and small cues that appear only when they matter (an interruptible cast, a buff to purge, threat trouble, the execute range). Choose Minimal, Standard or Full, and switch off any signal.
- **Swing timer, resource ticker and danger alerts.**
  - Bars time your auto attacks and turn red when the target is out of range.
  - A thin bar times your next energy or mana tick, with the five-second rule for casters. A strip under it lights up when you can cast spells you press on a tick (Claw and Shred for a cat, or your own picks), and small dots time your own bleeds and buffs.
  - Warnings for elites, rares or much higher-level mobs, and for when too many mobs are on you.
- **Action bars** with fading, hotkeys and range colouring, paging for stances and forms, and a movable micro menu and bag buttons.

### Cooldown and debuff timelines

- **A vertical timeline for cooldowns.** Instead of a row of icons, each spell on cooldown falls down a time scale (5, 15, 30 seconds, one minute and on) toward a ready line, over a themed background that fades out near the end. Set the background style and opacity, how much it fades and where the fade starts, the length, the far end of the scale, the number of columns, the label side, and whether it falls down or rises. A live preview shows each change, and a corner grip on the unlocked frame resizes it.
- **Your debuffs on the target, falling down their own timeline.** Each icon starts at the top and lands as its own time ends, so a five-second debuff falls fast and a thirty-second one slowly. It can replace the target frame's own debuff icons.
  - Forever hides enemy auras from addons in combat, so Tempus times your casts instead, using lengths it has learned out of combat, lengths you list yourself (for example `Moonfire 12`), or lengths read from your spell text. Pick them from a list of your own spells.
  - Because of that, timers start at the cast and do not follow refreshes or early removal.

### Gear Advisor

Gear Advisor is a window of the best gear deals from your own auction house scan. It works anywhere, because scanned prices are saved.

- **Scored for the build you play.** Every class has its builds (Arms, Fury, Holy, Shadow, Frost and so on, plus Forever's extra Shockadin, Battle Mage and Enhancement Tank). Pick yours under **Score gear as**, or leave it on Automatic: a Druid follows their shapeshift form, and a Warlock's build can come from where their talent points sit.
- **Why, not just a number.** The detail pane shows the item you wear and the item you would buy as the game's own tooltip text, then the math: the score, how much to trust it, and each stat with the score it adds. Scores are labelled as estimates, and a confidence level says why.
- **A clean list.** Column headings (Item, Score, Gain, Price) sort the list when you click them, and a second click flips the direction. Verdict tags mark the biggest upgrade, the best value and the best you can afford.
- **Smarter than item level.** It knows which hands a one-handed weapon competes for, warns when a two-hander takes off your shield, hides unique gear you already wear, and leaves out listings no better than something already in your bags. The old item-levels-per-gold ranking is still there as a choice.
- **A Find button** runs the auction house's own search for the selected item, so you buy with Blizzard's own Buy button. Tempus never buys anything for you.
- **A budget plan.** `/tempus gearplan 50` (or the button on the Gear Report page) lists the best set of gear to buy for 50 gold, not just the best single item.
- **Filters.** It follows your auction house filters (category, rarity, level range), a maximum price, a minimum gain, and an option to show only what you can afford.

The stat weights come from the community (GearQuest Forever, through Pawn Forever), not from the game, which is why Gear Advisor calls its scores estimates.

### Bags, bank and auction house

- **Combined bags and bank** with instant multi-word search, filters for gear, consumables, trades, quests and junk, a bag bar, item level and upgrade marks, cooldowns, a gold and currency footer, and grid or automatic category views with foldable sections and your own categories. The bank has its own row of tabs, including the ones you can still buy, with prices in the tooltips.
- **Your other characters.** Tempus remembers every character's bags and bank. Browse them from the Alts button, even offline, and item tooltips show what your other characters hold.
- **Auction values.** Tempus scans the auction house itself and shows the lowest buyout on item tooltips, plus stack estimates in your bags. One scan reads every listing in a single request, so the game's limit of about one full scan every 15 minutes applies. The **Tempus scan** button fills with your accent colour as the scan runs. Prices are kept per realm and shared by all your characters. These are listing estimates, not guaranteed sale prices, and older prices are marked stale.
- **Stat tooltips** that explain what an item's stats do for your character (attack power, crit, hit, haste, dodge, parry, block, health, mana, armor and regeneration), including the net change against the item you would replace.
- **Shopping list** for items you are collecting, with a target amount and what you and your alts already have.
- **Vendor and quest helpers** that sell grey items, repair, accept and hand in routine quests, loot everything at once and show an AFK screen.

### Look and feel

- **Chat** you can select and copy like a text editor, history that survives a reload, clickable web links, timestamps, whisper alerts and tabs that fade until mouseover, all on top of Blizzard's chat. If [SpellPower](https://www.curseforge.com/wow/addons/spellpower) is installed, its spellcheck and grammar options appear in Tempus's Chat settings.
- **A square minimap** with a configurable info bar, XP and reputation bars (with rested XP, XP per hour and time to level), and icons for ore and herb nodes you have gathered. Addon minimap buttons can stay on the edge, fade until mouseover, or collect in a tray.
- **Skins** for Blizzard windows, tooltips and chat, and for Bagnon and DBM, including centred loot-roll dialogs, a quest log search and a fully skinned quest tracker. A Stock skin keeps the search and leaves Blizzard's own look.
- **Style Studio** brings sample frames, nameplates, buffs, action buttons and cast bars together so you can change the theme (Modern, Gloss, Classic or Flat), texture, font, outline, accent colour and icon crop while a simulated scene runs. The accent colour recolours the settings window, move boxes and bags at once.
- **Movable everything.** Unlock the UI to drag any element, with a frame selector, arrow nudges, snapping, alignment guides, groups, and undo and redo. Save layouts as presets and optionally assign them to solo, party and raid play, switching automatically once combat ends.
- **Profiles.** Share your settings as a text string with Export and Import.

---

### Gear Report (optional)

On **Convenience > Gear Report**, a **Share my gear data** button can send the author a short report to help improve Gear Advisor. Nothing is sent unless you press it, and a notice first explains what the report holds: your race, class, level, faction and shapeshift form, your talent points, each equipped item's level and stats, and the stat names seen on your gear. It leaves out your character name and realm and holds no account, e-mail or password details. If you continue, Tempus whispers it, in plain chat you can see, to the author's character for your faction. If that character is offline it checks again every 30 minutes while you are logged in, for up to a day. Whoever receives a whisper sees who sent it.

### Handy commands

| Command | What it does |
|---|---|
| `/tempus` | Open settings |
| `/tempus unlock` / `lock` | Show or hide the boxes for dragging elements |
| `/tempus gear` | Open Gear Advisor |
| `/tempus gearplan [gold]` | List the best set of gear to buy for that much gold |
| `/tempus test` | Preview buff displays with sample auras |
| `/tempus install` | Run the first-run setup again |
| `/tempus safe` | Turn off everything except buffs and reload, as an escape hatch |
| `/tempus help` | List commands |

The settings window also has a **What's new** page with the changelog.

### Good to know

- Tempus keeps its settings per profile, and saved character inventories are shared by every profile.
- Some combat values are hidden by Forever, so a few things have honest limits: for example Combat Pulse's DPS comparison, whether a target's cast can be interrupted, and enemy auras in combat. The settings pages say where.
- For bug reports, `/tempus log` shows recent errors you can include.
