# Frame positioning and layout presets

## Arrange frames

Use `/tempus unlock` or Unlock in the settings header. Drag a labeled handle or
its tinted frame box. Select small/overlapping frames from the positioning panel. Its frame list toggles
membership, so you can select several frames without reaching their handles.
Every selected frame is highlighted. Right-click a frame for its settings.

| Control | Result |
| --- | --- |
| Arrow click | Move selected frames 1 UIParent unit |
| Shift + arrow click | Move selected frames 10 UIParent units |
| Drag near edges/centers | Snap within 8 UIParent units, with alignment guides |
| Alt while dragging | Bypass snapping until Alt is released |
| Party/raid corner grip | Resize, independently of position snapping |
| Escape or `/tempus lock` | Lock frames and hide mover controls |

Screen edges and screen center also attract snapping. Edges align with edges;
centers align with centers. Arrow nudges never snap. UI scaling means a UI unit
may differ from a physical pixel. Group editing and movement are unavailable during combat, including groups with
unprotected frames.

While the Tempus settings window is open, the first Escape dismisses active
previews (layout ghosts, test auras, group samples and Combat Pulse test mode),
locks unlocked editing, and leaves the current settings page open. The next
Escape closes Tempus. With no active preview or unlocked editing, Escape closes
settings immediately. The close button always closes settings immediately.

## Edit several frames together

- **Shift-click** a frame or labeled handle to add/remove it from the selection.
  The dropdown toggles frames too and remains open for multiple picks.
  Ctrl-click also remains available. Shift-click on an arrow still nudges by 10
  units; it does not change the selection.
- Clicking an unselected frame normally starts a new selection. Clicking or
  dragging a frame already in the selection keeps the group. Use **Clear
  selection** to deselect everything. Right-click settings works independently.
- Drag any selected frame to move the whole group. Snapping uses the group's
  outer bounds against unselected frames and screen edges/center. Hold Alt to
  bypass snapping. Selected frames never snap to one another during group drag.
- Arrows nudge the whole group; Shift-click moves 10 units. Movement is measured
  in UIParent units, so differently scaled frames keep their relative spacing.
  The group stops together at screen boundaries instead of compressing.
- With two or more frames selected, **Left/Right/Top/Bottom edges** align that
  edge to the group's existing outer edge. **Centers X/Y** align frame centers
  horizontally/vertically to the center of the selection's bounding box.
- **Equal gaps X/Y** needs at least three frames. It orders them left-to-right
  or bottom-to-top and spaces their visible edges equally, accounting for
  different sizes. The outermost frames stay fixed on the chosen axis. If there
  is not enough room for nonnegative gaps, nothing moves and an explanation is
  printed; spread the endpoints apart and try again.
- **Center screen** translates the selection as a unit to the screen center,
  preserving its internal arrangement. This also works for a single frame.

Each completed group drag, nudge, alignment, distribution or centering is one
Undo/Redo action. Group controls are unavailable while another drag/resize or
interrupted drag save is in progress. Invalid arrangements never partially apply.
A group wider/taller than the screen cannot be moved as a unit until it fits.
Changing profiles, locking or reloading clears the temporary selection. Hiding
or disabling a frame removes it from the selection on the next mover refresh.
Selection membership is not stored in presets; presets save resulting positions.
Group editing changes positions only, not sizes or anchors between frames.

## Save, duplicate and rename

Open `/tempus` > General > Layout presets. Finish dragging, then choose
**Save current as...**, enter a name and Save. Names are trimmed, case-sensitive,
1-48 bytes, and cannot contain control characters or `|`. Names must be unique:
there is no silent overwrite. Save an adjusted layout under a new name.

Presets store positions only, not sizes, scales, enabled modules, colors or other
settings. They persist through reloads/logouts within the current Tempus profile.
Switching full profiles switches preset collections; resetting a profile removes
its presets as well.

Select a preset and use **Duplicate...** to copy its saved positions (not current
screen positions), or **Rename...** to change its name. Both require a unique name.
Neither operation moves any frames.

## Preview and apply

1. Select a saved layout and choose **Preview selected**.
2. Inspect the translucent labeled ghosts. Live frames and saved positions are
   unchanged. Ghosts use current frame sizes/scales; disabled frames have no ghost.
3. Choose **Apply preview** to replace current positions, or **Cancel preview**
   to dismiss ghosts without changing anything. Save current positions first if
   you want to keep them. Dragging/nudging afterward never modifies the preset.

Preview/apply are blocked during combat or frame dragging. Entering combat cancels
preview. Changing a setting/profile, locking frames or closing settings also
cancels it. Position changes are never queued to apply after combat. Disabled
modules' saved positions can be restored for later use; missing modules are skipped.
Automatic group-type switching is opt-in under General > Automatic layouts.
See [automatic layouts and settings search](automatic-layouts-and-search.md) for
assignments, safe switching and manual overrides. Specialization and combat role
are not automatic triggers.

## Restore defaults

Choose **Preview defaults**, review ghosts, then **Apply preview**. Only declared
module default positions are restored; saved presets and non-position settings
are preserved. Elements with no declared default position keep their current
position. This does not reset the full Tempus profile.

## Undo and redo

Use **Undo** and **Redo** in the unlocked positioning panel or under
**General > Layout presets > Layout history**. Buttons are disabled when no action
is available, during combat, or while dragging/resizing. No keyboard shortcuts are
assigned, so chat and text editing keep their normal behavior.

Each completed frame drag, each arrow click (including Shift-click), and each
applied preset, default-position restore, or group alignment/spacing operation
is one undo action. A multi-frame layout
apply is undone as a single step. Preview/cancel and saving/renaming/duplicating a
preset do not add actions. No-op position changes do not use history space.

History holds the latest 50 position-changing actions per profile in memory until
`/reload` or logout. Switching to another profile gives that profile its own history;
switching back returns to the original history during the same session. Resetting
or replacing a profile starts a new history. Frame positions and saved presets
remain saved normally, even though the undo stacks are not persisted.

After Undo, Redo restores the action. Making a new position change after Undo
clears the redo branch; a no-op leaves it available. Undo/Redo only change position
anchors affected by that action: they preserve unrelated frame positions, sizes,
scales, colors and saved preset definitions. Resizing and settings-page changes
are not undoable. A missing module is skipped instead of recreated. Undo/Redo
cancel an active ghost preview, and blocked history actions are never queued.

## Implementation

`Core/Layouts.lua` implements capture, validation, storage, staging and apply.
`Config/LayoutPresets.lua` supplies the General page and name dialog; both files
are registered in the TOC. `Core/Movers.lua` supplies handles, selection, controls and snapping.
`Core/MoverGroups.lua` plans alignment/spacing and performs group movement. Its
pure `GroupPlan(boxes, action, dx, dy, width, height)` accepts rectangles in
UIParent coordinates and returns ordered left/bottom positions or `nil, error`.
Supported actions: `move`, `centerScreen`, `left`, `right`, `top`, `bottom`,
`centerX`, `centerY`, `spaceX`, `spaceY`. `T.Movers:GroupAction(...)` validates the
current selection and commits one history action. Dragging uses the same planner,
freezes selection geometry at drag start, and saves positions only on completion.
All anchors are stored before module callbacks. Group saves preserve fractional
anchor offsets to prevent rounding drift across differently scaled frames.
Interrupted drag saves retain their captured profile and final cursor positions;
pending saves block other layout actions until completed.

Storage: `TempusDB.profiles[profileName].layoutPresets[name]` is an array of entries
with `path` (configuration keys) and `point` (the five-value anchor). Capture walks
position-bearing config tables, excluding the preset store. Copies are detached,
including staged snapshots. Apply checks the original profile table and skips
configuration paths no longer present. The store is created lazily; no migration
is required. APIs: `T.Layouts:Save`, `Duplicate`, `Rename`, `Names`, `Stage`, `Apply`,
and `Cancel`; `Stage(nil, true)` stages defaults. Save/Duplicate/Rename return a
name or `nil, error`; Stage/Apply return success or `nil, error`.

History is held outside SavedVariables in a weak-key table indexed by the profile
table. `BeginEdit()` captures a profile-bound position snapshot; `EndEdit(token)`
records only changed anchors and discards edits that crossed profiles. Call these
around completed position edits; replayed edits are suppressed. `Undo()`/`Redo()`
replay detached before/after patches via the normal settings application path and
return success or `nil, error`. `CanUndo()`/`CanRedo()` expose current availability;
`CanEdit()` checks combat/drag guards. UI availability refreshes after edits,
replays, profile application and combat transitions. Mover drags record once on
completion, including out-of-combat saving after a combat interruption.

## Verification

Run repository `tools/check.sh`: Lua 5.1 syntax, generated changelog consistency,
tool regressions and addon tests. `tests/layouts.lua` covers copies, names,
preview/cancel, position-only apply, defaults, profile isolation and guards.
`tests/movers-snap.lua` covers alignment, capture thresholds and scaled coordinates.
`tests/layout-history.lua` covers action order, redo branches, defaults, profile
isolation, detached patches, missing modules, guards and the 50-action limit.
`tests/movers-history.lua` drives actual drag/nudge and panel handlers, including
combat interruption and hiding during a drag. `tests/layouts-page.lua` checks
settings widget dimensions and history button actions.
`tests/mover-groups.lua` covers geometry, equal visible gaps, boundary handling,
minimum selection counts, invalid operations and fractional coordinates. The
mover integration tests also cover Shift-click/dropdown selection, group snapping,
mixed-scale movement, alignment, atomic history, pending saves and selection cleanup.

In-game acceptance checks:

1. Unlock and drag: check edge/center guides, Alt bypass and unsnapped nudges.
2. Save Solo; move a frame; save Raid. Preview Solo and verify live frames stay
   put. Cancel, preview again, then Apply. `/reload` and check persistence.
3. Duplicate Solo and rename the copy. Try duplicate/blank names: expect rejection.
4. Change a size/color, then preview/apply defaults: check sizes/colors and preset
   names survive while declared default positions return.
5. Preview, then close settings, switch profiles or enter combat: ghosts disappear.
   Verify preview/apply cannot move frames during combat or dragging.
6. Verify right-click settings, Escape locking and party/raid resize grips.

7. Drag a frame, click Undo, then Redo: verify both positions. Repeat with an arrow
   nudge and Shift-click. One Undo should reverse an entire drag, not each update.
8. Apply a saved preset or defaults and Undo/Redo: verify every affected position
   returns together while colors, sizes and saved presets are preserved.
9. Undo, make a new nudge, and verify Redo becomes disabled. Switch profiles and
   back to check history isolation; `/reload` and verify both stacks start empty.
10. Verify history buttons disable in combat and while dragging/resizing, then
    become available again afterward. End resizing by locking frames and confirm
    history does not remain disabled.

11. Shift-click two frames (including one at a different scale), drag either, then
    nudge/Shift-nudge. Verify relative spacing, group boundary clamping, Alt bypass
    and Undo/Redo of the entire group in one step.
12. Select three unequal-size frames from the dropdown. Try each edge/center
    alignment, equal gaps on both axes and Center screen. Check fixed endpoints,
    unchanged sizes, and no partial movement when there is insufficient room.
13. Disable a selected module, switch profiles, lock, or Clear selection: verify
    selection highlights/counts update and disabled group buttons cannot act.
