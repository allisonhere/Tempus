# Tempus — animated bitmap hourglass (WoW Forever)

This is a **real addon texture animation**, not a GIF shown in-game. The 512×512 RGBA TGA contains sixteen 128×128 frames. WoW displays one frame at a time using `Texture:SetTexCoord`, advanced by a lightweight, throttled `OnUpdate` while the settings header is visible. The rest of the Tempus UI stays unchanged.

## Install on your local copy

1. Extract this ZIP somewhere outside your addon directory.
2. With WoW closed, run from a terminal:
   ```bash
   python3 install.py "/path/to/World of Warcraft/_forever_/Interface/AddOns/Tempus"
   ```
3. Start the game, type `/tempus`, and watch the icon animate. If you have an existing character session, `/reload` after copying files also reloads addon Lua.

The installer backs up `Config/Window.lua` as `Config/Window.lua.hourglass-backup` and patches only the existing `logo:SetTexture(T.LOGO)` line. It **does not overwrite other Tempus files**, touch the default minimap icon, alter `Tempus.toc`, or change any unrelated UI. It refuses to patch if the header differs from the specific main-branch version inspected on 2026-11-08.

## Animation

- 16 frames, a full drain/flip/refill cycle in ~3 seconds.
- Real RGBA uncompressed TGA atlas, 512×512, power-of-two.
- Each frame has 128×128 pixels, displayed by Tempus at 34×34 UI units.
- Animation runs only while the settings window is visible. If Tempus `animate=false`, a static frame is shown.
- No game-state/combat values read, no protected actions, no external libraries or GIF decoder, and no addon API workarounds.

## Verify in game

Check for visible art and correct cropped animation. If the texture is blank, verify `media/hourglass-animated.tga` exists and has not been renamed. There is no way to confirm a successful render without testing inside your Forever game client. This package has been statically validated, not in-game tested.

## Undo

Restore `Config/Window.lua.hourglass-backup` to `Config/Window.lua`, and optionally delete `media/hourglass-animated.tga`. Then `/reload`.
