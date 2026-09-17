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
        python3 tools/import_assets.py --from DIR --poses
        python3 tools/import_assets.py --from DIR --stage-art
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



# ---------------------------------------------------------------------------
# The 1-B / 1-S hand-over: thirteen paintings for THE KEEPER and nine for THE
# OPEN SKY, delivered as 1000-2200px boards.
#
# These go through a different table from PLAN above because the two stages
# need three things the first hand-over did not:
#
#   * TILES with no alpha at all (the island cross-section, the flagstones).
#     crop_to_content() reads the alpha channel, so running it on these throws
#     away nothing on a good day and everything on a bad one -- and a plain
#     LANCZOS resize breaks a seamless tile, because the filter cannot see past
#     the edge and pulls the outermost pixels inward. Both are handled by the
#     "tile" mode, which resizes a 3x3 wrap of the image and cuts the middle
#     out: every output pixel then has real neighbours on all four sides and
#     the tile still meets itself.
#   * BOXES. Most of this set is drawn with Art.draw_stretched into a rect the
#     physics already owns -- the barricade's 70x128 collider, the shockwave's
#     110x48 hazard, the gate's 56x420 slot. The painting has to FILL that box,
#     because the box is the thing that hurts you or holds you up, and a picture
#     that stops short of it is a lie about where the edge is. So the box mode
#     resamples to twice the drawn rect and bakes the distortion in at import,
#     where it is one good LANCZOS pass, instead of leaving it to a stretch at
#     draw time.
#   * The FOUR BOSS POSES, which have the runner's problem (see POSES) in a
#     worse form: they were painted at four different heights on the board.
#
# name -> (source file, destination, mode, target, pad)
#
#   fit   target is a width; the aspect is kept (Art.draw_sprite scales by height)
#   box   target is (w, h); cropped to the subject, then resampled to exactly that
#   tile  target is (w, h); seamless, wrap-resized, never cropped
#   cap   target is (w, h); cropped vertically to the band, wrap-resized across
#   bg    target is (w, h); an opaque backdrop, no alpha and no subject to trim
STAGE_PLAN = {
    # --- 1-B "THE KEEPER" --------------------------------------------------
    "keeper_core":       ("keeper/05_core.png", "keeper/core.png",
                          "box", (128, 128), 14),
    "keeper_barricade":  ("keeper/06_barricade.png", "keeper/barricade.png",
                          "box", (140, 256), 4),
    "keeper_rubble_b":   ("keeper/07_barricade_rubble.png",
                          "keeper/barricade_rubble.png", "box", (168, 77), 6),
    "keeper_shockwave":  ("keeper/08_shockwave.png", "keeper/shockwave.png",
                          "box", (220, 96), 12),
    "keeper_portcullis": ("keeper/09_portcullis.png", "keeper/portcullis.png",
                          "box", (112, 840), 2),
    "keeper_panorama":   ("keeper/10_panorama.jpg", "keeper/panorama.jpg",
                          "bg", (1280, 720), 0),
    "keeper_flagstone":  ("keeper/11_flagstone.png", "keeper/flagstone.png",
                          "tile", (132, 132), 0),
    "keeper_brazier":    ("keeper/12_brazier.png", "keeper/brazier.png",
                          "fit", 130, 6),
    "keeper_rubble":     ("keeper/13_rubble.png", "keeper/rubble.png",
                          "fit", 460, 6),

    # --- 1-S "THE OPEN SKY" ------------------------------------------------
    "sky_panorama":    ("sky/01_panorama.jpg", "sky/panorama.jpg",
                        "bg", (1280, 720), 0),
    "sky_island_tile": ("sky/02_island_tile.png", "sky/island_tile.png",
                        "tile", (132, 132), 0),
    "sky_island_cap":  ("sky/03_island_cap.png", "sky/island_cap.png",
                        "cap", (0, 92), 4),
    "sky_keel":        ("sky/04_keel.png", "sky/keel.png",
                        "box", (480, 298), 6),
    # A soft column of light, drawn at most 240x720, and the only file in this
    # set stored at 1:1 rather than 2x: there is no edge in it for the extra
    # pixels to sharpen, and at 2x it was the largest file in the game.
    "sky_updraft":     ("sky/05_updraft.png", "sky/updraft.png",
                        "box", (240, 720), 6),
    "sky_streamer":    ("sky/06_streamer.png", "sky/streamer.png",
                        "fit", 200, 6),
    "sky_arch":        ("sky/07_arch.png", "sky/arch.png",
                        "box", (440, 520), 6),
    "sky_beacon":      ("sky/08_beacon.png", "sky/beacon.png",
                        "fit", 120, 6),
    "sky_flyer":       ("sky/09_flyer.png", "sky/flyer.png",
                        "fit", 128, 6),
}

## The Keeper's four states. Same treatment as the runner's eight poses and for
## the same reason, except that the failure is louder: a boss whose height
## changes when it braces is a boss whose reach the player cannot learn.
##
## They are aligned by the FEET rather than by the board, because the four
## paintings put the floor in four different places (45, 96, 149 and 62 pixels
## up from the bottom edge). Aligning by the board would leave the charge pose
## hovering a fifth of a body height above the flagstones.
KEEPER_POSES = {
    "keeper_stand":  "keeper/01_keeper_stand.png",
    "keeper_brace":  "keeper/02_keeper_brace.png",
    "keeper_charge": "keeper/03_keeper_charge.png",
    "keeper_reel":   "keeper/04_keeper_reel.png",
}
## The pose the other three are measured against, and the width of the canvas
## they all end up on. 336 is twice Balance.KEEPER_SIZE.x, which is the rect
## keeper_visual.gd stretches every one of them into.
KEEPER_POSE_REFERENCE = "keeper_stand"
KEEPER_CANVAS_W = 336


def resize_wrapped(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Resize a seamless tile without breaking the seam.

    LANCZOS at the edge of an image has nothing on the far side to sample, so
    it leans inward and the outermost column stops matching the one it is
    supposed to meet. Tiling the image 3x3 first gives every edge pixel the
    neighbours it will actually have on screen; the middle third is then cut
    back out at the target size.
    """
    w, h = size
    wide = Image.new(im.mode, (im.width * 3, im.height * 3))
    for ty in range(3):
        for tx in range(3):
            wide.paste(im, (im.width * tx, im.height * ty))
    wide = wide.resize((w * 3, h * 3), Image.LANCZOS)
    return wide.crop((w, h, w * 2, h * 2))


def seam_ratio(im: Image.Image) -> tuple[float, float]:
    """How badly the tile fails to meet itself, as a multiple of its own grain.

    1.0 means the wrap-around edge is as continuous as any other pair of
    neighbouring rows or columns. A backdrop that was never meant to tile reads
    around 25-45 here, which is what makes this worth printing rather than
    assuming.
    """
    a = np.array(im.convert("RGB")).astype(np.float32)
    hx = np.abs(a[:, -1] - a[:, 0]).mean() / max(1e-6, np.abs(np.diff(a, axis=1)).mean())
    hy = np.abs(a[-1] - a[0]).mean() / max(1e-6, np.abs(np.diff(a, axis=0)).mean())
    return hx, hy


def import_keeper_poses(src: str) -> list:
    loaded = {}
    for name, rel in KEEPER_POSES.items():
        path = os.path.join(src, rel)
        if not os.path.exists(path):
            print(f"  MISSING  {name}: {path}")
            return []
        im = Image.open(path).convert("RGBA")
        box = bbox(im)
        loaded[name] = (im, box, feet_centre(im, box))

    # One scale for all four, so the boss is the same boss in every state.
    widest = max(b[2] - b[0] for _, b, _ in loaded.values())
    scale = KEEPER_CANVAS_W / widest
    height = max(round((b[3] - b[1]) * scale) for _, b, _ in loaded.values())

    rows = []
    for name, (im, box, feet) in loaded.items():
        cut = im.crop(box)
        w = max(1, round(cut.width * scale))
        cut = resize_premultiplied(cut, w)
        canvas = Image.new("RGBA", (KEEPER_CANVAS_W, height), (0, 0, 0, 0))
        # Feet to the middle of the canvas, soles to its bottom edge -- the
        # bottom edge is where keeper_visual.gd puts the hitbox's feet.
        x = round(KEEPER_CANVAS_W / 2 - (feet - box[0]) * scale)
        canvas.alpha_composite(cut, (x, height - cut.height))
        out = os.path.join(ASSETS, "keeper", name + ".png")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        canvas.save(out, optimize=True)
        kb = os.path.getsize(out) // 1024
        print(f"  {name:18s} {im.width}x{im.height} -> {KEEPER_CANVAS_W}x{height}"
              f"  (figure {cut.width}x{cut.height})  {kb}KB")
        rows.append((name, out))
    print(f"  canvas {KEEPER_CANVAS_W}x{height} (aspect {KEEPER_CANVAS_W / height:.3f}); "
          f"drawn into 168x134 (aspect 1.254)")
    return rows


def import_stage(src: str) -> int:
    rows = import_keeper_poses(src)
    if not rows:
        return 1
    for name, (rel, dest, mode, target, pad) in STAGE_PLAN.items():
        source = os.path.join(src, rel)
        if not os.path.exists(source):
            print(f"  MISSING  {name}: {source}")
            return 1
        im = Image.open(source)
        original = im.size
        note = ""
        if mode == "bg":
            im = im.convert("RGB").resize(target, Image.LANCZOS)
        elif mode == "tile":
            before = seam_ratio(im)
            im = resize_wrapped(im.convert("RGB"), target)
            after = seam_ratio(im)
            note = (f"  seam {before[0]:.1f}/{before[1]:.1f} -> "
                    f"{after[0]:.1f}/{after[1]:.1f}")
        elif mode == "cap":
            rgba = im.convert("RGBA")
            x0, y0, x1, y1 = bbox(rgba)
            y0 = max(0, y0 - pad)
            y1 = min(rgba.height, y1 + pad)
            band = rgba.crop((0, y0, rgba.width, y1))
            height = target[1]
            width = target[0] or max(1, round(band.width * height / band.height))
            im = resize_wrapped(band, (width, height))
            note = f"  band {band.width}x{band.height}"
        elif mode == "box":
            cut = crop_to_content(im.convert("RGBA"), pad)
            note = f"  subject {cut.width}x{cut.height}"
            # Down first on the long axis with the premultiplied path, which is
            # what keeps the halo from going grey, then the exact box.
            if cut.width > target[0]:
                cut = resize_premultiplied(cut, target[0])
            im = cut.resize(target, Image.LANCZOS)
        else:
            cut = crop_to_content(im.convert("RGBA"), pad)
            im = resize_premultiplied(cut, target)
        out = os.path.join(ASSETS, dest)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        if dest.endswith(".jpg"):
            im.save(out, quality=88, optimize=True, progressive=True)
        else:
            im.save(out, optimize=True)
        kb = os.path.getsize(out) // 1024
        print(f"  {name:18s} {original[0]}x{original[1]} -> "
              f"{im.size[0]}x{im.size[1]}  {kb}KB  {dest}{note}")
        rows.append((name, out))
    print(f"\n{len(rows)} imported")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", required=True, help="directory of <stem>-image.png")
    ap.add_argument("--only", default="")
    ap.add_argument("--poses", action="store_true", help="import the runner pose set")
    ap.add_argument("--stage-art", action="store_true",
                    help="import the 1-B/1-S hand-over (--from holds keeper/ and sky/)")
    args = ap.parse_args()

    if args.poses:
        return import_poses(args.src)
    if args.stage_art:
        return import_stage(args.src)

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
