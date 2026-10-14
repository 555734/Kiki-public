#!/usr/bin/env python3
"""Render the MELOS GAME title used by the 1-10 PV (39-49 s).

Two stacked words in the project's Baloo 2 Bold (assets/fonts, OFL): a
yellow-to-orange gradient face, a light blue inner rim, a thick navy outline
and a dark extrusion underneath, as in the storyboard. Output is a
transparent PNG the PV director draws centred behind the gameplay.

    python3 tools/promotion/make_pv_title.py
"""
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = os.path.join(ROOT, "assets", "fonts", "Baloo2-Bold.ttf")
OUT = os.path.join(ROOT, "assets", "promo", "title_melos_game.png")

W, H = 1400, 820
SIZE = 330
LINES = [("MELOS", 20), ("GAME", 340)]


def mask_for(stroke: int) -> Image.Image:
    font = ImageFont.truetype(FONT, SIZE)
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for text, y in LINES:
        w = d.textlength(text, font=font)
        d.text(((W - w) / 2, y), text, font=font, fill=255, stroke_width=stroke, stroke_fill=255)
    return m


def shift(mask: Image.Image, dy: int) -> Image.Image:
    """Move down without wrapping (ImageChops.offset wraps around)."""
    out = Image.new("L", mask.size, 0)
    out.paste(mask, (0, dy))
    return out


def line_spans() -> list:
    font = ImageFont.truetype(FONT, SIZE)
    spans = []
    for text, y in LINES:
        box = font.getbbox(text)
        spans.append((y + box[1], y + box[3]))
    return spans


def solid(color, mask: Image.Image) -> Image.Image:
    layer = Image.new("RGBA", (W, H), color)
    layer.putalpha(mask)
    return layer


def main() -> int:
    face = mask_for(0)
    rim = mask_for(9)
    outline = mask_for(26)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # Soft drop shadow, then a solid extrusion straight down.
    shadow = outline.filter(ImageFilter.GaussianBlur(14))
    out.alpha_composite(solid((0, 10, 40, 150), shift(shadow, 30)))
    for dy in range(22, 0, -2):
        out.alpha_composite(solid((14, 30, 92, 255), shift(outline, dy)))
    out.alpha_composite(solid((16, 38, 112, 255), outline))
    out.alpha_composite(solid((58, 150, 255, 255), rim))
    # Vertical gradient per line: bright yellow on top to deep orange below.
    grad = Image.new("RGBA", (W, H))
    gd = ImageDraw.Draw(grad)
    spans = line_spans()
    for y in range(H):
        top, bottom = min(spans, key=lambda sp: 0 if sp[0] <= y <= sp[1] else min(abs(y - sp[0]), abs(y - sp[1])))
        local = min(1.0, max(0.0, (y - top) / max(1.0, bottom - top)))
        r, g, b = 255, int(238 - 128 * local), int(80 - 70 * local)
        gd.line([(0, y), (W, y)], fill=(r, g, max(b, 0), 255))
    grad.putalpha(face)
    out.alpha_composite(grad)
    # A glossy highlight across the top third of each letter.
    gloss = Image.new("L", (W, H), 0)
    gl = ImageDraw.Draw(gloss)
    for top, bottom in line_spans():
        gl.rectangle([0, top, W, top + (bottom - top) * 0.3], fill=80)
    gloss = ImageChops.multiply(gloss, face.filter(ImageFilter.MinFilter(9)))
    out.alpha_composite(solid((255, 255, 255, 255), gloss))
    out = out.crop(out.getbbox())
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print(OUT, out.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
