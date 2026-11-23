# Gear Advisor: adding real game data

Gear Advisor's weights are community estimates until the game's own data fills the gaps. Two kinds of data
are collected in game and pasted into the repo. Everything else is generated.

## 1. Stat names: `/tempus gearstats`

1. Log in on a character that wears and carries the gear you want covered (caster, healer, tank, melee).
2. Type `/tempus gearstats`. Chat prints every stat name on that gear: how many items, the value range, an
   example item, and `NO WEIGHT` in front of any name no build gives a weight.
3. Copy the chat lines into a new file in `tools/gearadvisor/stats-samples/` (for example `druid-22.txt`).
4. Run `python3 tools/gen_gearadvisor.py stats`. It lists names seen, names with no weight, and the weights
   that are still only assumed.
5. Fix `tools/gearadvisor/statmap.json`: change a `key` to the real stat name, or set `"status": "seen"` once
   it is confirmed on a real item. Add a new entry when a stat has no weight yet (it also needs a rating
   divisor in `per` if the weight is per 1%).
6. Run `python3 tools/gen_gearadvisor.py weights` to regenerate `Modules/GearAdvisor/Weights.lua`, then
   `tools/check.sh`. Sync to the game and test.

## 2. Talent markers: `/tempus gearsig`

Talents unlock at level 10, so use characters at level 10 or higher.

1. On a character with a known build, type `/tempus gearsig`. It prints one line, for example
   `DRUID 22, 7 points: Feral Swiftness x2, Ferocity x5`.
2. Add it to `tools/gearadvisor/signatures.txt` with the build code in front:
   `ROLE=CAT | DRUID 22, 7 points: Feral Swiftness x2, Ferocity x5`. Role codes are in
   `Modules/GearAdvisor/Weights.lua` (`_order` of each class).
3. Add at least one sample for each build of the class, since a talent marks a build only when no other
   build's sample has points in it.
4. Run `python3 tools/gen_gearadvisor.py signals` to regenerate `Modules/GearAdvisor/TalentSignalsData.lua`,
   then `tools/check.sh`. With markers in place, Automatic scoring can use the talents (after the shapeshift
   form, before a guess).

## Confirmed in game

- `GetShapeshiftForm()`: Cat = 3 and Bear = 1 (level 22 Druid: attack power 177 and 130 match the classic cat and bear formulas).

## Other facts still to confirm in game

- Whether crit, hit and haste arrive on items as ratings (assumed) or percentages.
- The level at which talents unlock (10, as reported; not read from the client).
- GearQuest Forever's own licence terms (the weights reach us through Pawn Forever, MIT).

## Where things live

| What | File |
| --- | --- |
| Source weights (copy of Pawn Forever's table) | `tools/gearadvisor/pawn_forever_weights.lua` |
| Stat name map and rating divisors | `tools/gearadvisor/statmap.json` |
| Pasted talent signatures | `tools/gearadvisor/signatures.txt` |
| Pasted stat dumps | `tools/gearadvisor/stats-samples/*.txt` |
| Generator and report tool | `tools/gen_gearadvisor.py` |
| Generated weights / talent markers | `Modules/GearAdvisor/Weights.lua`, `TalentSignalsData.lua` |
