# Tempus Royal UI — redesign branch

This is an **in-progress visual redesign** of the existing addon configuration screen, not a replacement for the addon. Main remains unchanged.

## Implemented
- A self-contained Royal rendering layer for the settings window, framing, header, sidebar, and selected nav item.
- Uses native WoW texture regions and existing frame structure; no new dependencies or changed SavedVariables.
- The existing page builders, options, and combat logic are preserved.

## Artwork
The `artwork/source/` directory contains vector source artwork and design notes. SVG is **source only**, not a directly loadable WoW texture. Export it to lossless RGBA TGA or BLP before referencing in Lua. The ornate reference mockup is a *visual target*, not an exact in-game rendering yet.

## Next iteration
1. Export original individual artwork (not a crop of the complete UI screenshot) into `media/royal/`.
2. Replace procedural ornamentation with texture-backed nine-slice panels; test scaling at the 860×600 configuration window size.
3. Reskin shared Config/Widgets.lua controls without changing get/set/Refresh callbacks.
4. Review in WoW and run `tools/check.sh` before opening a final PR.

Do not change swing timer math, module registrations, default profile values, navigation semantics, slash commands, or combat restrictions.
