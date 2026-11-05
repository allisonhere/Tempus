# Automatic layouts and settings search

## Set up automatic layouts

First save the desired positions as named presets under **General > Layout
presets**. Open **General > Automatic layouts** and assign a **Solo layout**,
**Party layout**, and **Raid layout**, then enable **Automatic layout switching**.
The feature is off by default, and assignments belong to the current Tempus
profile. **Keep current positions** leaves that group type unassigned; it never
resets frames or guesses a preset name.

The group type is based on the game's group state. Raid takes precedence over
party. A change in member count inside the same party/raid does not reset your
layout. Login/reload and entering the world evaluate the current group too.
Specialization, combat role and party size are not additional routing conditions.

Only frame positions change. Sizes, colors, module enablement and saved preset
contents are preserved. Every actual automatic switch is one Undo action.

## Combat, editing and manual override

- Switching waits for combat to end. If the group changes several times during
  combat, the latest group and current profile assignments are used afterward.
  An old queued target is never applied blindly.
- Frames must be locked. Switching also waits for a drag, resize, pending drag
  save, or ghost preview to finish. Status text explains what is pending.
- Dragging, nudging, alignment, applying a preset/defaults, or Undo/Redo takes
  manual control for the current group type. Automatic routing resumes when the
  group type changes, rather than immediately undoing your adjustment.
- **Reapply current group layout** explicitly retries the current assignment
  after manual adjustments. Enable switching and unpause it first.
- **Pause automatic switching (manual override)** keeps manual control across
  group changes. Pause is saved per profile. Clear it to resume routing to the
  current assignment.

Manual changes can overwrite current positions, so save an arrangement you want
to keep as a preset first. Undo history lasts for the current session; presets and
rules persist through reloads/logouts. Previewing or canceling a preview alone
is not a manual override: a waiting automatic switch may proceed after preview
ends. Changing an assignment for the current group type deliberately requests
that new preset when switching is safe.

Renaming a preset updates its assignments. Deleting one clears matching rules.
If an imported rule names a preset that is missing, no frames move and status
asks you to choose another preset. Switching profiles evaluates that profile's
rules; an old pending job cannot apply another profile's layout.

## Search settings

Open `/tempus` and type in **Search settings...** at the top of the sidebar.
Use at least two characters. Search matches page/section names, setting labels,
help text, and explanatory paragraphs. Matching is case-insensitive for English
text; every space-separated word must appear somewhere in the combined label,
help or page path. Punctuation is literal, not a pattern or regular expression.
For example, try `cast bar`, `party width`, `solo layout`, or `interrupt cooldown`.

Results show the setting name and its section/page path. Click a result to open
that page, scroll to the control, and briefly highlight it. Press Enter to open
the first result. Search itself never toggles settings or activates a button.
With no active preview, Escape in the search box or the **x** next to it clears
the query and restores the normal sidebar. If a preview is active, the first
Escape dismisses that preview and releases search focus while keeping settings
open; the next Escape closes Tempus. Opening a specific page from a mover also clears the query. Search text
is session-only, up to 80 characters; at most 100 matches are shown, so refine
broad queries to narrow the results.

On the first search, eligible settings pages are constructed hidden and reused
thereafter. During combat, search uses already-built pages and page names; full
indexing resumes after combat. Disabled or failed modules are searchable by page
name, but their controls are indexed only when the module has started. Enabling a
module normally requires a reload. The What's new page can be found by title;
its historical release notes are excluded from settings results.

## Optional SpellPower entry

If SpellPower is absent or disabled, its sidebar section remains visible in grey.
Hovering explains its live chat spelling checks, grammar suggestions and WoW
vocabulary, and displays `https://www.curseforge.com/wow/addons/spellpower`.
The entry has no expandable settings and left-click does nothing. Right-click
opens a copy box with the URL selected; press Ctrl+C, then paste it into your
browser. Escape closes the copy box first, keeping Tempus open.

The missing-addon entry is also discoverable in search, with the same grey style,
tooltip and right-click copy action. Search never tries to construct its settings.
Install or enable SpellPower, then reload to activate integration. Current versions
keep their embedded Tempus pages; older loaded versions keep the standalone
settings button. SpellPower is optional and no installation is triggered by the
menu. `tests/spellpower-menu.lua` covers the registration variants; the settings
UI regression tests cover disabled navigation, hover/copy behavior and Escape.

## Implementation

`Core/AutoLayouts.lua` owns defaults, group detection, status and debounced
routing. Saved data is `profile.autoLayouts = {enabled, paused, solo, party,
raid}`; names reference the current profile's `layoutPresets`. Runtime state is
separate per profile and held outside SavedVariables. Events are
`PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `GROUP_ROSTER_UPDATE` and
`PLAYER_REGEN_ENABLED`. Group notifications coalesce for 0.1 seconds; safe-edit
waits retry every 0.5 seconds, and combat waits resume from the combat-end event.
Each evaluation reads the latest group, assignments and profile. Manual edits
mark the current context handled; automatic applies bypass that marker.

`Config/AutoLayouts.lua` provides the settings page. `Core/Layouts.lua` exposes
`ApplySaved(name)` and `ApplySnapshot(snapshot)` through the same position/history
path as manual preset application. Core settings application schedules routing;
preset rename/delete and position history notify it through guarded hooks.

`Config/Search.lua` contains pure normalization, literal matching, ranking and
result limiting. `Config/Widgets.lua` adds label/help metadata and records page
entry offsets. Custom widgets can set `searchLabel` and `searchText`; direct text
regions are used as a fallback. `Config/Window.lua` owns the search input, hidden
page cache, results, navigation and highlights. Cached pages still refresh their
live values normally when opened. Search does not invoke control callbacks.

## Verification

Run `tools/check.sh` for Lua 5.1 syntax, changelog synchronization and all tests.
New regressions cover automatic routing/deferral/manual override/profile safety,
the three rule setters, literal settings search/ranking, and the actual settings
window's indexing, navigation, highlight, Escape behavior and combat guards.

In-game acceptance checks:

1. Save Solo/Party/Raid presets with visibly different positions. Assign them,
   enable switching, and join/leave or convert a group. Check position-only changes.
2. Change group type in combat; verify nothing moves until combat ends and only
   the latest assignment applies. Repeat while unlocked or viewing a ghost preview.
3. Undo a switch or nudge a frame. Check that roster updates in the same group
   type keep manual positions. Use Reapply; then try persistent Pause.
4. Rename an assigned preset and switch profiles while an automatic change is
   waiting. Check assignments and profile isolation.
5. Search an unvisited page for `cast bar`, `raid width` and `solo layout`. Click
   a control result, check scrolling/highlight, and verify its value did not change.
6. Check Enter, Escape, clear, no-result queries, and searching during/after combat.
7. Enable Preview or stage layout ghosts. Press Escape once: verify the preview
   ends while settings stays open. Press again: settings closes. Repeat with
   sample frames, Combat Pulse test mode, unlocked editing and focused search.
   Holding Escape should not skip the preview layer through key-repeat.
