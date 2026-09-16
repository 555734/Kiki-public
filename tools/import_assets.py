#!/usr/bin/env python3
"""Bring the supplied painted PNGs into assets/ at usable sizes.

These arrived as ~1250px renders with a lot of empty margin around each subject.
Shipping them untouched would put ~14MB of mostly-transparent pixels in the APK
and make every sprite arrive at the GPU an order of magnitude larger than it is
ever drawn, so each one is cropped to the pixels that actually carry alpha and
then resized to roughly twice its on-screen size.

Two details that matter and are easy to get wrong:

* The crop keeps a little of the glow. Cropping hard against alpha > 8 clips the
  outer halo of the holograms and the optic, which is most of what makes them
  read as light rather than as plastic.
* The resize is done on PREMULTIPLIED pixels. Resampling straight alpha mixes
  the colour of fully transparent pixels into the edge, and since transparent
  pixels here are black, that puts a dark fringe around every sprite.

Usage:  python3 tools/import_assets.py --from DIR [--only NAME]
"""
from __future__ import annotations

import argparse
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")

# name -> (source stem, destination, target width in px, halo padding in px)
#
# Target widths are about twice the largest size the sprite is drawn at, which
# keeps it crisp when the camera is close without paying for a 1250px texture.
PLAN = {
    "brick":         ("2176c470", "props/brick.png",              128, 6),
    "ground_block":  ("89400dc8", "terrain/ground_block.png",     384, 4),
    "parallax":      ("85f19b95", "bg/parallax.png",             1280, 0),
    "laser_beam":    ("15da6fb4", "entities/laser_beam.png",      512, 10),
    "crosshair":     ("fd70a417", "scope/crosshair.png",          256, 14),
    "scope_ring":    ("870f0bb3", "scope/ring.png",               512, 14),
    "hit_burst":     ("fafbbf7a", "entities/hit_burst.png",       256, 14),
    "platform":      ("2a737003", "holograms/platform.png",       384, 12),
    "signpost":      ("bbc094cd", "props/signpost.png",           168, 4),
    "qblock":        ("35e28323", "props/qblock.png",             128, 4),
    "coin":          ("7e0dbf28", "props/coin.png",               112, 4),
    "wall":          ("a0a6f736", "holograms/wall.png",            96, 12),
    "warp_gate":     ("7a41f5ee", "holograms/warp_gate.png",      232, 12),
    "pipe":          ("72c74b70", "props/pipe.png",               160, 4),
    "spring":        ("85a99aa9", "entities/spring.png",          152, 4),
    "spikes":        ("170795d6", "props/spikes.png",             384, 4),
    "walker":        ("d7a8d6c9", "characters/walker.png",         128, 4),
    "tree":          ("3b760b60", "props/tree.png",                256, 4),
}

# The runner's pose set. These go through a DIFFERENT path from everything
# above, because they are frames of one character rather than eight separate
# objects: scaled individually they would each fill their own file and the
# runner would change size every time they crouched or raised a fist.
#
# So all eight are scaled by ONE factor, then pasted onto ONE canvas, aligned by
# the FEET -- bottom edge to bottom edge, and the horizontal centre of the
# figure's lowest rows to the middle of the canvas. That is the point the game
# positions the sprite by, so aligning it here is what stops the character
# sliding sideways between frames.
POSES = {
    "runner_idle":  "d5827cc4",
    "runner_run":   "a404c112",
    "runner_jump":  "618567c9",
    "runner_fall":  "4cde9b49",
    "runner_land":  "4037aaf3",
    "runner_dash":  "5022285b",
    "runner_reach": "c4ea3cea",
    "runner_cheer": "a072f7bd",
}
## The pose every other pose is measured against, and how tall it ends up.
POSE_REFERENCE = "runner_idle"
POSE_REFERENCE_PX = 128
## Breathing room so a raised fist or a trailing scarf is not clipped.
POSE_MARGIN = 6


def crop_to_content(im: Image.Image, pad: int) -> Image.Image:
    """Trim the empty margin, keeping `pad` pixels of halo on every side."""
    a = np.array(im)
    alpha = a[..., 3]
    ys, xs = np.where(alpha > 4)
    if len(xs) == 0:
        return im
    x0 = max(0, int(xs.min()) - pad)
    y0 = max(0, int(ys.min()) - pad)
    x1 = min(im.width, int(xs.max()) + 1 + pad)
    y1 = min(im.height, int(ys.max()) + 1 + pad)
    return im.crop((x0, y0, x1, y1))


def resize_premultiplied(im: Image.Image, width: int) -> Image.Image:
    """Resize without dragging the colour of transparent pixels into the edge."""
    if im.width <= width:
        return im
    height = max(1, round(im.height * width / im.width))
    a = np.array(im).astype(np.float32) / 255.0
    alpha = a[..., 3:4]
    a[..., :3] *= alpha                       # premultiply
    small = np.array(Image.fromarray(
        (a * 255.0 + 0.5).astype(np.uint8), "RGBA"
    ).resize((width, height), Image.LANCZOS)).astype(np.float32) / 255.0
    out_alpha = np.clip(small[..., 3:4], 0.0, 1.0)
    rgb = np.where(out_alpha > 1e-4, small[..., :3] / np.maximum(out_alpha, 1e-4), 0.0)
    out = np.concatenate([np.clip(rgb, 0.0, 1.0), out_alpha], axis=2)
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA")


def bbox(im: Image.Image) -> tuple[int, int, int, int]:
    a = np.array(im)[..., 3]
    ys, xs = np.where(a > 4)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def feet_centre(im: Image.Image, box: tuple[int, int, int, int]) -> float:
    """Horizontal centre of the lowest tenth of the figure, in source pixels.

    Not the bounding box's centre: an outstretched arm or a raised fist drags
    that sideways, and the result is a character who shifts a few pixels left
    and right as the pose changes. The feet are the part that stays put.
    """
    x0, y0, x1, y1 = box
    a = np.array(im)[..., 3]
    band = max(1, (y1 - y0) // 10)
    ys, xs = np.where(a[y1 - band:y1, x0:x1] > 4)
    if len(xs) == 0:
        return (x0 + x1) / 2.0
    return x0 + float(xs.mean())


def import_poses(src: str) -> int:
    loaded = {}
    for name, stem in POSES.items():
        path = os.path.join(src, stem + "-image.png")
        if not os.path.exists(path):
            print(f"  MISSING  {name}: {path}")
            return 1
        im = Image.open(path).convert("RGBA")
        box = bbox(im)
        loaded[name] = (im, box, feet_centre(im, box))

    ref_box = loaded[POSE_REFERENCE][1]
    scale = POSE_REFERENCE_PX / (ref_box[3] - ref_box[1])

    height = POSE_MARGIN + max(
        round((b[3] - b[1]) * scale) for _, b, _ in loaded.values())
    half = max(
        max(feet - b[0], b[2] - feet) for _, b, feet in loaded.values())
    width = POSE_MARGIN * 2 + 2 * round(half * scale)

    for name, (im, box, feet) in loaded.items():
        cut = im.crop(box)
        w = max(1, round(cut.width * scale))
        h = max(1, round(cut.height * scale))
        cut = resize_premultiplied(cut, w) if w < cut.width else cut.resize((w, h), Image.LANCZOS)
        canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        # Feet to the middle, soles to the floor.
        x = round(width / 2 - (feet - box[0]) * scale)
        canvas.alpha_composite(cut, (x, height - cut.height))
        out = os.path.join(ASSETS, "characters", name + ".png")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        canvas.save(out, optimize=True)
        print(f"  {name:14s} -> {width}x{height}  {os.path.getsize(out) // 1024}KB")

    figure = round((ref_box[3] - ref_box[1]) * scale)
    print(f"\n  canvas {width}x{height}, reference figure {figure}px tall")
    print(f"  Balance.RUNNER_POSE_HEADROOM = {height / figure:.4f}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", required=True, help="directory of <stem>-image.png")
    ap.add_argument("--only", default="")
    ap.add_argument("--poses", action="store_true", help="import the runner pose set")
    args = ap.parse_args()

    if args.poses:
        return import_poses(args.src)

    rows = []
    for name, (stem, dest, width, pad) in PLAN.items():
        if args.only and args.only != name:
            continue
        source = os.path.join(args.src, stem + "-image.png")
        if not os.path.exists(source):
            print(f"  MISSING  {name}: {source}")
            return 1
        im = Image.open(source)
        original = im.size
        if im.mode == "RGB":
            # The panorama is a full-bleed background; it has no subject to trim
            # and no alpha to premultiply.
            im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
        else:
            im = crop_to_content(im.convert("RGBA"), pad)
            im = resize_premultiplied(im, width)
        out = os.path.join(ASSETS, dest)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        im.save(out, optimize=True)
        kb = os.path.getsize(out) // 1024
        print(f"  {name:14s} {original[0]}x{original[1]} -> {im.size[0]}x{im.size[1]}  {kb}KB  {dest}")
        rows.append((name, dest, original, im.size, stem))

    print(f"\n{len(rows)} imported")
    return 0


if __name__ == "__main__":
    sys.exit(main())
