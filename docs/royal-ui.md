# Tempus Royal UI — complete shared visual-system pass (in-game review pending)

This branch replaces the **Swing Timer settings presentation** with the illustrated Royal UI composition. The existing swing-timer combat implementation, SavedVariables keys, and callbacks are retained.

## Currently implemented

- Full Swing Timer page composition with a hero header, a gold/violet clock dial, four dedicated cards, and a bottom preview strip.
- Native WoW TGA textures in `media/royal/`: `panel`, `frame`, `hero`, `header-astral`, `emblem`, `dial`, `toggle-on`, `toggle-off`, `slider-jewel`, and `nav-icons`.
- Enhanced masthead uses the astral header tapestry, ornate hourglass, gilded title, gold separator, and faint chronometer.
- Sidebar navigation uses a custom 16-glyph golden icon atlas, engraved active marker, and ornamental section dividers.
- **All existing module settings pages** inherit engraved section cards, gilded section headings, gold-accented dropdowns, edit boxes and buttons, enamel toggles, and jeweled sliders. Individual module page layouts remain as authored, other than Swing Timer.
- Shared settings toggle and slider graphics plus Royal window framing and branding.
- Original Swing module keys remain: `enabled`, `offHand`, `ranged`, `showTime`, `visibility`, `width`, `height`, and `spacing`.
- Page search and widget refresh still use `Config/Widgets.lua` and `UI.NewPage`.

## Important visual limitations

These first-pass TGA files are **programmatically drawn**, not extracted final-quality illustrated assets. They are not equivalent to the original concept illustration's intricate metallic sculpting, texture richness, character imagery, or typography. The current implementation should not be represented as a pixel-perfect reproduction.

The clock readout and swing timeline in the settings window are **decorative previews**, not live combat values. The real swing bar module behavior remains unchanged.

## Required in-game review

1. Install this branch in WoW; open `/tempus` then select **Swing timer**.
2. Confirm the TGA textures load rather than displaying green squares, including under the current client graphics API.
3. Inspect the 860 × 600 settings window at 100% UI scale and at other scales. Verify header, nav, card borders, hero clock, all controls, and scrollbar don't overlap or clip.
4. Confirm the four switches, three sliders, visibility dropdown, saved settings, nav search, profile switching, and reload retain their previous behavior.
5. Compare the result side by side with the original illustrated prototype and revise the artwork itself, not only colors.
6. Run `tools/check.sh`; do not merge PR until in-game appearance and functionality are approved.

The `artwork/source/` SVGs are editable sources, **not** directly loadable WoW textures.

## Scope note

This pass applies a coherent Royal style across the **entire existing config UI**, including every current module options page. Only Swing Timer has a bespoke four-card editorial composition. Fully hand-composing every other module to the illustrated Swing Timer layout requires separate page-specific design and in-game review. Do not interpret automated test success as proof of pixel-perfect visual fidelity.

The reference illustration includes decorative art that is not presently reproduced exactly. Current textures are original procedural designs and the interface is meant to remain a working native WoW UI.
