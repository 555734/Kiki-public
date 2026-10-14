#!/usr/bin/env python3
"""Two soft cartoon clouds for 1-10's skies (replacing the mockup crops,
whose edges were cut straight). Puffs of white over a light-blue underside,
drawn at 4x and downsampled. Writes assets/stage_1_10/cloud_soft_a/b.png.

    python3 tools/promotion/make_soft_clouds.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "stage_1_10")
K = 4
W, H = 512, 256
PUFFS = {
    "a": [(-0.36, 0.0, 0.17), (-0.16, -0.12, 0.23), (0.08, -0.17, 0.27), (0.3, -0.06, 0.2), (0.42, 0.02, 0.13)],
    "b": [(-0.4, 0.02, 0.13), (-0.22, -0.08, 0.2), (0.0, -0.13, 0.22), (0.2, -0.1, 0.24), (0.4, 0.0, 0.15)],
}


def cloud(puffs):
    w, h = W * K, H * K
    base = (w * 0.5, h * 0.66)
    cw = w * 0.86

    def layer(dy, scale):
        m = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(m)
        for px, py, r in puffs:
            cx, cy, rr = base[0] + px * cw, base[1] + (py + dy) * cw, r * cw * scale
            d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=255)
        d.rectangle([base[0] - 0.36 * cw, base[1] + (dy - 0.04) * cw, base[0] + 0.42 * cw, base[1] + (dy + 0.05) * cw], fill=255)
        return m
    shade = layer(0.05, 1.0)
    white = layer(0.0, 0.93)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (w, h), (205, 225, 250, 255)), (0, 0), shade)
    out.paste(Image.new("RGBA", (w, h), (255, 255, 255, 255)), (0, 0), white)
    out = out.filter(ImageFilter.GaussianBlur(K * 0.8))
    return out.resize((W, H), Image.LANCZOS)


def main():
    for key, puffs in PUFFS.items():
        cloud(puffs).save(os.path.join(OUT, "cloud_soft_%s.png" % key))
    print("wrote 2 clouds")


if __name__ == "__main__":
    main()
