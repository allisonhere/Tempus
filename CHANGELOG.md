# Changelog

## Unreleased

### New
- **Layered DPS track**: one bar from Blizzard's damage meter. Purple runs to your live DPS, gold on to your peak this fight, and red on to the group's top DPS, with a small marker at each edge. Scale modes, colours, size and a test mode with animated values are under General > DPS track. Unlock the UI to move it.

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
