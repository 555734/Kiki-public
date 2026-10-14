#!/usr/bin/env python3
"""One real in-game still per 1-10 area, plus a sheet of all 49 cuts, taken
from the finished PV (frame 30 of each cut's 60).

    python3 tools/promotion/finale_area_shots.py
"""
import os
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PV = os.path.join(ROOT, "build", "promotion", "stage-1-10", "pv")
OUT = os.path.join(ROOT, "docs", "images", "stage-1-10")
FONT = os.path.join(ROOT, "assets", "fonts", "Nunito-ExtraBold.ttf")
AREAS = [("01-grassland", 7), ("02-thunder-bridge", 12), ("03-sand-ruins", 15), ("04-volcano", 18),
         ("05-iron-rail", 22), ("06-hive", 28), ("07-stone-giant", 33), ("08-bone-canyon", 37),
         ("09-title-run", 45)]


def frames():
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(PV, "finale_pv_49cuts.mp4"),
                          "-vf", "select='eq(mod(n\\,60)\\,30)'", "-vsync", "0", "-f", "rawvideo",
                          "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, 720, 1280, 3)


def main():
    os.makedirs(OUT, exist_ok=True)
    shots = frames()
    for name, shot in AREAS:
        Image.fromarray(shots[shot - 1]).save(os.path.join(OUT, "area-%s.jpg" % name), quality=88, optimize=True)
    w, h, cols = 384, 216, 7
    rows = (len(shots) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows), (20, 20, 28))
    d = ImageDraw.Draw(sheet)
    f = ImageFont.truetype(FONT, 20)
    for i, img in enumerate(shots):
        x, y = (i % cols) * w, (i // cols) * h
        sheet.paste(Image.fromarray(img).resize((w, h), Image.LANCZOS), (x, y))
        d.rectangle([x, y, x + 86, y + 26], fill=(0, 0, 0))
        d.text((x + 6, y + 1), "%02d  %ds" % (i + 1, i), fill=(255, 220, 60), font=f)
    sheet.save(os.path.join(OUT, "pv-49-cuts.jpg"), quality=84, optimize=True)
    print("wrote", len(AREAS), "area stills and the 49-cut sheet")


if __name__ == "__main__":
    main()
