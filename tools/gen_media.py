#!/usr/bin/env python3
"""Draw the Tempus theme textures into media/:
  bar-tempus.tga  256x32 bar fill: bright 1px top line, soft sheen, darker toward the bottom.
                  Greyscale, so the bar's colour comes from SetStatusBarColor.
  glow.tga        64x64 soft glow for the Tempus theme, sliced 16 px on every side; the middle
                  is transparent so the panel's own fill shows through unchanged."""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

MEDIA = Path(__file__).resolve().parent.parent / "media"


def write_tga(img, name):
    w, h = img.size
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])
    data = bytearray()
    for r, g, b, a in img.convert("RGBA").getdata():
        data += bytes((b, g, r, a))
    (MEDIA / name).write_bytes(header + bytes(data))
    print("wrote", MEDIA / name)


def bar():
    w, h = 256, 32
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        v = 250 - 70 * t                  # light at the top, deeper at the bottom
        if t < 0.45:                      # sheen over the upper part
            v += 12 * (1 - t / 0.45)
        if y == 0:
            v = 255
        if y == h - 1:
            v *= 0.75                     # a darker bottom line gives the bar an edge
        v = int(max(0, min(255, v)))
        for x in range(w):
            px[x, y] = (v, v, v, 255)
    write_tga(img, "bar-tempus.tga")


def glow():
    n, m = 64, 16                         # size, slice margin
    ss = 4
    big = Image.new("L", (n * ss, n * ss), 0)
    ImageDraw.Draw(big).rectangle([m * ss, m * ss, (n - m) * ss - 1, (n - m) * ss - 1], fill=255)
    soft = big.filter(ImageFilter.GaussianBlur(5 * ss))
    inner = Image.new("L", big.size, 0)
    ImageDraw.Draw(inner).rectangle([m * ss, m * ss, (n - m) * ss - 1, (n - m) * ss - 1], fill=255)
    alpha = ImageChops.subtract(soft, inner).resize((n, n), Image.LANCZOS)
    # stretch the fade so the edge next to the panel is strongest
    alpha = alpha.point(lambda a: min(255, int(a * 2.2)))
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    img.putalpha(alpha)
    write_tga(img, "glow.tga")


bar()
glow()
