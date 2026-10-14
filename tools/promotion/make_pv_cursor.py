#!/usr/bin/env python3
"""Draw the guardian's YOU pointer for the 1-10 PV: a blue pointing hand with
a white rim and soft glow, plus a white copy of the Discord mark for the
incoming-call card (recoloured from the official mark in assets/promo).

    python3 tools/promotion/make_pv_cursor.py
"""
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROMO = os.path.join(ROOT, "assets", "promo")
K = 4  # supersampling


def hand_mask(size: int) -> Image.Image:
    """Index finger pointing up-left; the fingertip is the image's hot spot."""
    m = Image.new("L", (size * K, size * K), 0)
    d = ImageDraw.Draw(m)
    s = K * size / 100.0

    def rr(x0, y0, x1, y1, r):
        d.rounded_rectangle([x0 * s, y0 * s, x1 * s, y1 * s], radius=r * s, fill=255)
    rr(20, 4, 38, 62, 9)            # index finger
    rr(36, 36, 52, 66, 8)           # middle (curled)
    rr(50, 40, 65, 68, 7.5)         # ring
    rr(63, 45, 77, 70, 7)           # little
    rr(20, 50, 76, 92, 16)          # palm
    d.polygon([(6 * s, 56 * s), (22 * s, 48 * s), (30 * s, 74 * s), (16 * s, 78 * s)], fill=255)  # thumb
    d.ellipse([4 * s, 52 * s, 20 * s, 70 * s], fill=255)
    return m.rotate(28, resample=Image.BICUBIC, center=(29 * s, 8 * s)).resize((size, size), Image.LANCZOS)


def main() -> int:
    size = 120
    pad = 24
    hand = hand_mask(size)
    canvas = Image.new("L", (size + pad * 2, size + pad * 2), 0)
    canvas.paste(hand, (pad, pad))
    rim = canvas.filter(ImageFilter.MaxFilter(9))
    glow = rim.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(8))
    out = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    for color, mask in [((60, 150, 255, 150), glow), ((255, 255, 255, 255), rim), ((32, 120, 255, 255), canvas)]:
        layer = Image.new("RGBA", canvas.size, color)
        layer.putalpha(ImageChops.multiply(mask, Image.new("L", canvas.size, color[3])))
        out.alpha_composite(layer)
    # Knuckle lines and a highlight on the finger.
    d = ImageDraw.Draw(out)
    out.save(os.path.join(PROMO, "you_cursor.png"))
    mark = Image.open(os.path.join(PROMO, "discord_mark.png")).convert("RGBA")
    white = Image.new("RGBA", mark.size, (255, 255, 255, 255))
    white.putalpha(mark.getchannel("A"))
    white.save(os.path.join(PROMO, "discord_mark_white.png"))
    print("cursor", out.size, "hot spot ~", (pad + 23, pad + 8))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
