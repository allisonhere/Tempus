#!/usr/bin/env python3
"""Draw media/node-pin.tga: the minimap gathering-node pin (gold ring + tail as one shape).
128x128, the icon shows through a transparent hole centred at (64, 46) with a 32 px radius."""
import math
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

SS = 4                     # supersampling
N = 128 * SS
CX, CY, R = 64 * SS, 46 * SS, 42 * SS
HOLE = 32 * SS
TIP = (64 * SS, 124 * SS)

def mask_from(draw_fn):
    img = Image.new("L", (N, N), 0)
    draw_fn(ImageDraw.Draw(img))
    return img

# Tangent points of the lines from the tip to the circle.
L = TIP[1] - CY
a = math.acos(R / L)
tangents = [(CX + s * R * math.sin(a), CY + R * math.cos(a)) for s in (-1, 1)]

shape = mask_from(lambda d: (d.ellipse([CX - R, CY - R, CX + R, CY + R], fill=255),
                             d.polygon([tangents[0], tangents[1], TIP], fill=255)))
hole = mask_from(lambda d: d.ellipse([CX - HOLE, CY - HOLE, CX + HOLE, CY + HOLE], fill=255))

def erode(m, px):
    return m.filter(ImageFilter.MinFilter(px * 2 + 1)) if px else m

outline = ImageChops.subtract(shape, erode(shape, 3 * SS // 2))
body = ImageChops.subtract(shape, hole)
inner_dark = ImageChops.subtract(hole.filter(ImageFilter.MaxFilter(3 * SS + 1)), hole)   # line around the hole

def shade(x, y, lit):
    """Gold with light from the upper left; `lit` flips it for the inside of the ring."""
    t = ((x - CX) * -0.55 + (y - CY) * -0.85) / R
    t = max(-1, min(1, t)) * (1 if lit else -1)
    lo, hi = (112, 78, 18), (255, 226, 120)
    f = (t + 1) / 2
    base = [lo[i] + (hi[i] - lo[i]) * f for i in range(3)]
    # darken toward the tip so the tail reads as part of the same solid
    if y > CY + R * 0.7:
        d = min(1, (y - (CY + R * 0.7)) / (TIP[1] - CY - R * 0.7)) * 0.35
        base = [c * (1 - d) for c in base]
    return tuple(int(c) for c in base)

img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
px = img.load()
bpx, opx, ipx, hpx = body.load(), outline.load(), inner_dark.load(), hole.load()
bevel_w = 3 * SS
for y in range(N):
    for x in range(N):
        if opx[x, y] > 0 and bpx[x, y] > 0:
            px[x, y] = (22, 15, 4, int(opx[x, y] * 0.95))
        elif bpx[x, y] > 0:
            # a lit band on the outer rim, shadow band on the inner rim, gold between
            r = math.hypot(x - CX, y - CY)
            inner = HOLE + bevel_w
            col = shade(x, y, r > inner)
            px[x, y] = col + (255,)
        elif ipx[x, y] > 0:
            px[x, y] = (22, 15, 4, 230)
# The hole stays transparent so the icon shows through.
img = img.resize((128, 128), Image.LANCZOS)

out = Path(__file__).resolve().parent.parent / "media" / "node-pin.tga"
w, h = img.size
header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])
data = bytearray()
for r, g, b, al in img.getdata():
    data += bytes((b, g, r, al))
out.write_bytes(header + bytes(data))
print("wrote", out)
