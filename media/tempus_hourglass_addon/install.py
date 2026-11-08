#!/usr/bin/env python3
"""Install the Tempus animated-hourglass sprite texture and settings-header patch."""
from pathlib import Path
import argparse, shutil, sys

MATCH = "    logo:SetTexture(T.LOGO)"
REPLACEMENT = '    -- Single 512x512 TGA atlas: sixteen 128x128 frames. No GIF/video dependencies.\n    -- This replaces only the settings-window header logo, not the addon\'s minimap icon.\n    logo:SetTexture("Interface\\\\AddOns\\\\Tempus\\\\media\\\\hourglass-animated")\n    logo.tempus = true  -- prevent Tempus\'s skinning code from altering its art\n    local function HourglassFrame(index)\n        local col = (index - 1) % 4\n        local row = math.floor((index - 1) / 4)\n        logo:SetTexCoord(col / 4, (col + 1) / 4, row / 4, (row + 1) / 4)\n    end\n    HourglassFrame(1)\n    do\n        -- Fluid sand-drain sequence, a quick 3-frame flip, then sand refilling.\n        local frameTimes = {\n            0.190, 0.190, 0.190, 0.190,\n            0.190, 0.190, 0.190, 0.190,\n            0.260, 0.095, 0.095, 0.095,\n            0.160, 0.170, 0.170, 0.380,\n        }\n        local index, accumulated = 1, 0\n        -- A driver frame automatically stops updating while options are hidden.\n        local driver = CreateFrame("Frame", nil, header)\n        driver:SetAllPoints(logo)\n        driver:SetScript("OnShow", function()\n            index, accumulated = 1, 0\n            HourglassFrame(index)\n        end)\n        driver:SetScript("OnUpdate", function(_, elapsed)\n            if T.db and T.db.animate == false then\n                if index ~= 1 then\n                    index, accumulated = 1, 0\n                    HourglassFrame(1)\n                end\n                return\n            end\n            accumulated = accumulated + elapsed\n            -- Bound catch-up work after stalls or alt-tab.\n            local changes = 0\n            while accumulated >= frameTimes[index] and changes < 4 do\n                accumulated = accumulated - frameTimes[index]\n                index = index % 16 + 1\n                HourglassFrame(index)\n                changes = changes + 1\n            end\n            if changes == 4 then accumulated = 0 end\n        end)\n    end'

def main():
    ap=argparse.ArgumentParser(description='Add a native, animated TGA hourglass to Tempus settings')
    ap.add_argument('addon_dir',help='Path to Interface/AddOns/Tempus (or current working directory)')
    ns=ap.parse_args()
    folder=Path(ns.addon_dir).expanduser().resolve()
    dest=folder/'Config'/'Window.lua'
    image=folder/'media'/'hourglass-animated.tga'
    source=Path(__file__).resolve().parent/'media'/'hourglass-animated.tga'
    if not dest.is_file():
        sys.exit(f'Cannot find {dest}. Point this script to your Tempus addon directory.')
    if not (folder/'Tempus.toc').is_file():
        sys.exit('Tempus.toc missing; this does not look like the Tempus addon folder.')
    old=dest.read_text(encoding='utf-8')
    if 'HourglassFrame(index)' in old:
        print('Already patched; refreshing texture only.')
    else:
        if old.count(MATCH) != 1:
            sys.exit('Refusing to patch: header logo code differs from the inspected Tempus main branch. No files changed.')
        backup=dest.with_suffix('.lua.hourglass-backup')
        if not backup.exists():
            shutil.copy2(dest,backup)
            print('Backup:',backup)
        patched=old.replace(MATCH, REPLACEMENT,1)
        dest.write_text(patched,encoding='utf-8')
        print('Patched:',dest)
    image.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,image)
    print('Texture:',image)
    print('Restart WoW (or /reload) and open /tempus to view it.')

if __name__ == '__main__':
    main()
