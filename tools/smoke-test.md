# In-game release check

Run this checklist on both interface versions listed in `Tempus.toc`. Start with Lua errors enabled.

## Installation and profiles

- Start once with no `TempusDB`. Finish the installer and reload.
- Start once with a saved profile from the previous release. Confirm its layout and module choices remain intact.
- Export the active profile, import it under a new name, switch profiles, and reload.
- Disable and re-enable each module from the Modules page. Confirm the reload notice appears.

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
