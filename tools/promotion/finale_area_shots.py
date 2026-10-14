#!/usr/bin/env python3
"""Pick one real in-game still per 1-10 area (from the PV capture) for docs,
plus a contact sheet of all 49 cuts.

    python3 tools/promotion/finale_area_shots.py
"""
import glob
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PV = os.path.join(ROOT, "build", "promotion", "stage-1-10", "pv")
OUT = os.path.join(ROOT, "docs", "images", "stage-1-10")
AREAS = [("01-grassland", 7), ("02-thunder-bridge", 12), ("03-sand-ruins", 15), ("04-volcano", 18),
         ("05-iron-rail", 22), ("06-hive", 28), ("07-stone-giant", 32), ("08-bone-canyon", 37),
         ("09-title-run", 45)]

def main():
    os.makedirs(OUT, exist_ok=True)
    for name, shot in AREAS:
        src = os.path.join(PV, "shot_%02d.png" % shot)
        Image.open(src).convert("RGB").save(os.path.join(OUT, "area-%s.jpg" % name), quality=88, optimize=True)
    files = sorted(glob.glob(os.path.join(PV, "shot_??.png")))
    w, h, cols = 384, 216, 7
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows), (20, 20, 28))
    d = ImageDraw.Draw(sheet)
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
    except OSError:
        f = ImageFont.load_default()
    for i, p in enumerate(files):
        x, y = (i % cols) * w, (i // cols) * h
        sheet.paste(Image.open(p).convert("RGB").resize((w, h), Image.LANCZOS), (x, y))
        d.rectangle([x, y, x + 46, y + 26], fill=(0, 0, 0))
        d.text((x + 6, y + 2), os.path.basename(p)[5:7], fill=(255, 220, 60), font=f)
    sheet.save(os.path.join(OUT, "pv-49-cuts.jpg"), quality=84, optimize=True)
    print("wrote", len(AREAS), "area stills and the 49-cut sheet")

if __name__ == "__main__":
    main()
