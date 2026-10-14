#!/usr/bin/env python3
"""Annotate the rendered 1-10 world map with areas, checkpoints and PV cuts.

Inputs are produced by the game itself:
  build/stage-maps/stage-1-10.png + maps.json   (tools/export_stage_maps.tscn)
  build/promotion/stage-1-10/pv/shots_report.json (tools/promotion/capture_finale_pv.tscn)
Output: docs/images/stage-1-10/stage-1-10-map.jpg (and a smaller overview).
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAPS = os.path.join(ROOT, "build", "stage-maps")
REPORT = os.path.join(ROOT, "build", "promotion", "stage-1-10", "pv", "shots_report.json")
OUT = os.path.join(ROOT, "docs", "images", "stage-1-10")
COLOURS = [(46, 160, 67), (70, 110, 200), (214, 150, 60), (220, 80, 40), (90, 100, 120),
           (230, 160, 20), (150, 110, 80), (200, 190, 160), (60, 170, 220)]


def font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main():
    meta = json.load(open(os.path.join(MAPS, "maps.json")))
    record = [m for m in meta["maps"] if m["stage"] == "1-10"][0]
    report = json.load(open(REPORT))
    img = Image.open(os.path.join(MAPS, record["png"])).convert("RGB")
    ox, oy = record["world_origin"]
    sc = record["scale"]

    def px(x, y):
        return ((x - ox) * sc, (y - oy) * sc)

    pad_top = 120
    canvas = Image.new("RGB", (img.width, img.height + pad_top + 40), (24, 28, 40))
    canvas.paste(img, (0, pad_top))
    d = ImageDraw.Draw(canvas)
    f_big, f_mid, f_small = font(34), font(22), font(17)
    d.text((16, 10), "STAGE 1-10  THE LAST RUN  -  whole course rendered from the game (LevelBuilder), scale %.2f" % sc,
           fill=(255, 255, 255), font=f_big)
    d.text((16, 56), "Coloured bands: areas.  White flags: checkpoints.  Numbered dots: storyboard cuts at the runner's "
           "position when the cut's action happened (capture_finale_pv).", fill=(200, 210, 230), font=f_mid)
    for i, z in enumerate(report["zones"]):
        x0 = max(0, px(z["from"], 0)[0])
        x1 = min(img.width, px(z["to"], 0)[0])
        c = COLOURS[i % len(COLOURS)]
        d.rectangle([x0, pad_top - 26, x1, pad_top - 4], fill=c)
        d.text((x0 + 6, pad_top - 26), "%s (%ss)" % (z["name"], z["seconds"]), fill=(255, 255, 255), font=f_small)
        d.line([x0, pad_top, x0, pad_top + img.height], fill=c, width=2)
    for i, (x, y) in enumerate(report["checkpoints"]):
        X, Y = px(x, y)
        Y += pad_top
        d.line([X, Y - 26, X, Y + 12], fill=(255, 255, 255), width=3)
        d.polygon([(X, Y - 26), (X + 18, Y - 20), (X, Y - 14)], fill=(255, 255, 255))
        d.text((X + 4, Y + 10), "CP%d" % (i + 1), fill=(255, 255, 255), font=f_small)
    for label, (x, y), c in (("START", report["start"], (60, 220, 90)), ("GOAL", report["goal"], (255, 80, 80))):
        X, Y = px(x, y)
        Y += pad_top
        d.ellipse([X - 10, Y - 10, X + 10, Y + 10], fill=c)
        d.text((X + 12, Y - 30), label, fill=c, font=f_mid)
    for row in report["shots"]:
        if "runner_world" not in row:
            continue
        X, Y = px(*row["runner_world"])
        Y += pad_top
        ok = row["success"]
        d.ellipse([X - 13, Y - 13, X + 13, Y + 13], fill=(255, 220, 40) if ok else (230, 60, 60), outline=(20, 20, 20), width=2)
        d.text((X - 9 if row["shot"] < 10 else X - 12, Y - 10), str(row["shot"]), fill=(20, 20, 20), font=f_small)
    os.makedirs(OUT, exist_ok=True)
    full = os.path.join(OUT, "stage-1-10-map.jpg")
    canvas.save(full, quality=86, optimize=True)
    small = canvas.resize((canvas.width // 2, canvas.height // 2), Image.LANCZOS)
    small.save(os.path.join(OUT, "stage-1-10-map-small.jpg"), quality=86, optimize=True)
    print("wrote", full, canvas.size)


if __name__ == "__main__":
    sys.exit(main())
