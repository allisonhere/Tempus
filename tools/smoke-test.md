# In-game release check

Run this checklist on both interface versions listed in `Tempus.toc`. Start with Lua errors enabled.

## Installation and profiles

- Start once with no `TempusDB`. Finish the installer and reload.
- Start once with a saved profile from the previous release. Confirm its layout and module choices remain intact.
- Export the active profile, import it under a new name, switch profiles, and reload.
- Disable and re-enable each module from the Modules page. Confirm the reload notice appears.

## Style Studio

- Open General > Style Studio while standing in town without a target. Confirm all sample elements appear together and health, casts and aura timers animate.
- Confirm General has no separate Appearance page, and that second colour, combat colour, border thickness and animations are on Style Studio. Buff text sizes and colours are on Buffs & Debuffs > Look.
- Change theme, bar texture, font, outline, accent colour and icon crop. Confirm the scene updates immediately, and the saved appearance persists after `/reload`.
- Pause and resume; navigate away and back; close and reopen settings; switch profiles. Confirm samples stay correct and no live module preview modes are enabled.
- Repeat with unit frames, buffs and nameplates disabled. The independent sample scene should still work. Check `/tempus log` for errors.

## Auction values

- Open the auction house. Confirm **Tempus scan** and **Upgrades** sit in the top-left corner of the AH window, use the Tempus button skin (Stock skin and the Classic theme keep Blizzard's look), and are not covered by the AH art.
- Click **Tempus scan**. Confirm the button shows progress, a finished message reports items and auctions, nothing is bought or posted, and a second scan inside 15 minutes says how long to wait. Close the AH mid-scan and confirm the scan stops with a message. Turn on the automatic scan and confirm it starts when the AH opens.
- Hover scanned items and stacks in Tempus bags and item links. Check unit price, stack multiplication, scan age, stale labels and no duplicate lines on repeated hover. Before the first scan on a realm, tooltips show nothing. After a scan, an item nobody lists keeps its older price with an older age.
- Switch characters on the same realm and confirm the prices are still there. Disable the tooltip setting and the module, reload, and confirm no Lua errors (`/tempus log`).
- Click **Upgrades**. Confirm results are grouped under slot headers (Head, Back, Waist and so on, up to eight each), each row shows `+N ilvl` and the stats that rise compared with what you wear, only gear your class and level can equip appears, and prices past the stale setting say "(old)". Scroll with the mouse wheel past the first screenful.
- Hover a row and confirm the detail pane on the right of the panel updates: item, slot, item level versus worn, price and age, a side-by-side table of every stat (current item against the one you would buy, with the change) and a vertical chart of the stat changes (gains rise above the centre line, losses hang below it in red, the figure is the real amount). No tooltip should open. Shift-click a row to link it in chat.
- Type a price in the "Max price (gold)" box at the top of the list and confirm dearer items drop out; clear the box (or set the slider to 0) to remove the limit.
- Pick a category on the AH left list (for example Weapons > Two-Handed Swords), set the filter dropdown to one rarity (for example Uncommon only) and a level range, then open the Upgrades list: only matching items stay, the footer says "Using AH filters: ...", and clearing the AH filters (or turning off "Use the auction house filters" on the settings page) brings everything back.
- Close the AH and confirm the Upgrades window stays open. Open it away from the AH with `/tempus upgrades` and **Open upgrades list** on the settings page. Drag it, reload, reopen, and confirm it returns to its place; Escape and the x close it.
- Change the minimum gain slider and "Only show upgrades I can afford", and equip a better item, then confirm the list updates. First open after login should show "Loading item data" and then fill in.

## Combat safety

- Enter combat with party or raid frames, action bars, unit frames, nameplates, and Combat Pulse enabled.
- Change settings and lock or unlock movers during combat. Confirm protected changes wait until combat ends.
- Target, retarget, gain and lose auras, cast, interrupt, dispel, change threat, and cross the execute threshold.
- Confirm `/tempus log` has no new Lua errors, warnings, or blocked actions.

## Displays and integrations

- Open carried bags from the keybind, backpack button, and info bar. Check search, Grid/Categories, sorting, item use, dragging, splitting stacks, tooltips, empty slots, and new-item marks.
- Open the personal and reagent banks. Check both tabs, deposits/withdrawals, sorting, the Manage handoff, and that closing the banker closes the bank window.
- With Bagnon or another supported bag addon enabled, test both ownership choices on separate characters. Confirm only one addon draws bags and that choosing Tempus disables the competitor only for that character after reload.
- Check buffs, debuffs, weapon enchants, cooldowns, swing timers, XP, reputation, the minimap, and the info bar.
- Join a party and a raid. Check range fading, incoming heals, absorbs, dispels, HoTs, aggro, roles, and click-casting.
- Check hostile and friendly nameplates inside and outside an instance.
- Repeat the relevant checks with Plater, Clique, Bagnon, DBM, and SpellPower when installed.
- Run Combat Pulse in Minimal, Standard, Full, and test modes. Check Auto and Fixed maximum scales before, during, and after combat.

## Release result

- Run `tools/check.sh` from the addon directory.
- Record the client build and any failed item. Do not tag the release until every failure is fixed or explicitly deferred in `CHANGELOG.md`.
