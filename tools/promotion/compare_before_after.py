#!/usr/bin/env python3
"""Second-by-second comparison of two 49 s PV renders.

    python3 tools/promotion/compare_before_after.py BEFORE.mp4 AFTER.mp4 OUT_DIR

For every second 0-48 takes the frame at t + 0.5 s from both videos and lays
them side by side (before left, after right), seven seconds per page:
OUT_DIR/before_after_0.jpg ... before_after_6.jpg.
"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                    "assets", "fonts", "Nunito-ExtraBold.ttf")
W, H = 640, 360


def frames(mp4):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", mp4, "-vf", "select='eq(mod(n\\,60)\\,30)',scale=%d:%d" % (W, H),
                          "-vsync", "0", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3)


def main():
    before, after, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    a, b = frames(before), frames(after)
    try:
        font = ImageFont.truetype(FONT, 26)
    except OSError:
        font = ImageFont.load_default()
    for page in range(7):
        sheet = Image.new("RGB", (W * 2 + 12, H * 7 + 6 * 6 + 40), (16, 18, 24))
        d = ImageDraw.Draw(sheet)
        d.text((10, 6), "BEFORE (6280.mp4)", font=font, fill=(255, 140, 120))
        d.text((W + 22, 6), "AFTER", font=font, fill=(140, 255, 160))
        for row in range(7):
            sec = page * 7 + row
            y = 40 + row * (H + 6)
            for col, src in enumerate((a, b)):
                if sec < len(src):
                    sheet.paste(Image.fromarray(src[sec]), (col * (W + 12), y))
                d.rectangle([col * (W + 12), y, col * (W + 12) + 74, y + 32], fill=(0, 0, 0))
                d.text((col * (W + 12) + 6, y + 2), "%02ds" % sec, font=font, fill=(255, 220, 0))
        sheet.save(os.path.join(out, "before_after_%d.jpg" % page), quality=86)
    print("wrote 7 pages to", out)


if __name__ == "__main__":
    main()
