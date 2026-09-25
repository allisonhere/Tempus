# Changelog

## 2.1.0

### New
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
- Target frame auras duplicated on every retarget.
- Spellbook category tabs lost their icons.
- Quest and book text is dark brown on parchment instead of light grey.
- The unit frames' "by health" colour never reached green.
- Settings pages could stop scrolling partway down.

### Changed
- Developer probing is off by default (`/tempus probe` to turn it on, `/tempus probe off` to clear it).
