#!/usr/bin/env python3
"""Cut game sprites out of the three supplied concept mockups.

The mockups ARE the art direction for 走れメロス, so lifting the artwork out of
them is the closest match available -- every sprite ends up with the same paint,
the same light direction and the same palette as the concept.

Method: for each crop, every colour appearing on the crop's border is treated as
a background reference. Pixels near any reference are candidate background;
connected components of that candidate set which touch the border are the actual
background, so a brown enemy is never eaten just because brown appears in a
corner. The subject mask is then hole-filled, feathered by a pixel or so, and
de-spilled (the background colour is subtracted back out of semi-transparent
edge pixels) to kill the halo you otherwise get against a blue sky.

Usage:  python3 tools/extract_assets.py [--only NAME] [--sheet]
Output: assets/<category>/<name>.png plus assets/SOURCES.md
"""
from __future__ import annotations

import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

UPLOADS = os.environ.get(
    "SIDESKY_MOCKUPS",
    "/root/.claude/uploads/4fe2bbd1-052c-5324-9b7c-1ffa91f538c0",
)
MOCKUPS = {
    "m1": "1b00d892-image.png",   # solid holograms, runner mid-jump, scope reticle
    "m2": "1e8cf13d-image.png",   # dashed previews, walker clear on grass
    "m3": "e711c0ff-image.png",   # full-screen scope, everything ~1.5x larger
}
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")

# Paths now supplied as finished painted art (tools/import_assets.py). These
# scripts predate that art and would happily overwrite it with the older
# cut-outs of the same subject, so they leave them alone.
SUPPLIED = {
    "props/brick.png", "props/pipe.png", "props/qblock.png", "props/spikes.png",
    "characters/walker.png",
    "characters/runner_run.png", "characters/runner_jump.png",
    "terrain/dirt_tile.png", "terrain/grass_tile.png",
    "entities/laser_beam.png",
    "holograms/platform.png", "holograms/wall.png",
}


_cache: dict[str, np.ndarray] = {}


def load(key: str) -> np.ndarray:
    if key not in _cache:
        path = os.path.join(UPLOADS, MOCKUPS[key])
        _cache[key] = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    return _cache[key]


def _border_refs(rgb: np.ndarray, ring: int) -> np.ndarray:
    """Unique-ish colours from a `ring`-pixel frame around the crop."""
    top, bottom = rgb[:ring], rgb[-ring:]
    left, right = rgb[:, :ring], rgb[:, -ring:]
    refs = np.concatenate([p.reshape(-1, 3) for p in (top, bottom, left, right)])
    # Quantise to keep the distance matrix small; 8 levels per channel is plenty
    # to describe a sky gradient or a field of grass.
    quant = np.unique((refs / 8.0).astype(np.int16), axis=0).astype(np.float32) * 8.0
    return quant


def _min_dist_to_refs(rgb: np.ndarray, refs: np.ndarray) -> np.ndarray:
    h, w, _ = rgb.shape
    flat = rgb.reshape(-1, 1, 3)
    best = np.full(flat.shape[0], np.inf, dtype=np.float32)
    # Chunked so a large crop against a busy background does not blow up memory.
    for i in range(0, refs.shape[0], 256):
        chunk = refs[i:i + 256].reshape(1, -1, 3)
        d = np.sqrt(((flat - chunk) ** 2).sum(axis=2)).min(axis=1)
        best = np.minimum(best, d)
    return best.reshape(h, w)


def cutout(
    key: str,
    box: tuple[int, int, int, int],
    tol: float = 34.0,
    ring: int = 3,
    feather: float = 1.1,
    despill: bool = True,
    fill_holes: bool = True,
    keep_largest: bool = True,
    pad: int = 2,
) -> Image.Image:
    x0, y0, x1, y1 = box
    rgb = load(key)[y0:y1, x0:x1].copy()
    h, w, _ = rgb.shape

    refs = _border_refs(rgb, ring)
    dist = _min_dist_to_refs(rgb, refs)
    candidate_bg = dist < tol

    # Only the background regions that actually reach the frame edge count.
    labels, n = ndimage.label(candidate_bg)
    border_labels = set(labels[0].tolist()) | set(labels[-1].tolist())
    border_labels |= set(labels[:, 0].tolist()) | set(labels[:, -1].tolist())
    border_labels.discard(0)
    background = np.isin(labels, list(border_labels)) if border_labels else np.zeros_like(candidate_bg)

    subject = ~background
    if fill_holes:
        subject = ndimage.binary_fill_holes(subject)
    if keep_largest:
        lab, count = ndimage.label(subject)
        if count > 1:
            sizes = ndimage.sum(subject, lab, range(1, count + 1))
            subject = lab == (int(np.argmax(sizes)) + 1)
            subject = ndimage.binary_fill_holes(subject)

    alpha = ndimage.gaussian_filter(subject.astype(np.float32), feather) if feather > 0 \
        else subject.astype(np.float32)
    alpha = np.clip((alpha - 0.35) / 0.4, 0.0, 1.0)
    alpha[subject] = np.maximum(alpha[subject], 1.0)

    out = rgb.copy()
    if despill:
        # Un-mix the background out of partially transparent edge pixels, using
        # the nearest border reference as the local background estimate.
        edge = (alpha > 0.02) & (alpha < 0.98)
        if edge.any():
            idx = np.argwhere(edge)
            px = rgb[edge]
            d = np.sqrt(((px[:, None, :] - refs[None, :, :]) ** 2).sum(axis=2))
            bg = refs[np.argmin(d, axis=1)]
            a = alpha[edge][:, None]
            out[idx[:, 0], idx[:, 1]] = np.clip((px - (1.0 - a) * bg) / np.maximum(a, 0.05), 0, 255)

    rgba = np.dstack([out, alpha * 255.0]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")

    bbox = img.getbbox()
    if bbox:
        l, t, r, b = bbox
        img = img.crop((max(0, l - pad), max(0, t - pad),
                        min(img.width, r + pad), min(img.height, b + pad)))
    return img


# Channel expressions for subjects whose colour sits too close to the
# background for the distance matte above -- a white cloud on pale blue sky, a
# cream castle on the same sky, a red heart on dark navy. Each returns a scalar
# field that is high on the subject and low on the background.
KEYS = {
    "not_sky":  lambda r, g, b: r - b,            # anything less blue than sky
    "green":    lambda r, g, b: g - np.maximum(r, b),
    "warm":     lambda r, g, b: r - g,            # wood/tan against grass
    "red":      lambda r, g, b: r - np.maximum(g, b),
    "bright":   lambda r, g, b: 0.299 * r + 0.587 * g + 0.114 * b,
    "cyan":     lambda r, g, b: np.minimum(g, b) - r,
}


def keyed(
    key: str,
    box: tuple[int, int, int, int],
    channel: str,
    lo: float,
    hi: float,
    feather: float = 0.8,
    fill_holes: bool = True,
    keep_largest: bool = False,
    min_area: int = 0,
    pad: int = 2,
) -> Image.Image:
    x0, y0, x1, y1 = box
    rgb = load(key)[y0:y1, x0:x1].copy()
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    v = KEYS[channel](r, g, b)
    alpha = np.clip((v - lo) / max(hi - lo, 1e-6), 0.0, 1.0)

    solid = alpha > 0.5
    if fill_holes:
        solid = ndimage.binary_fill_holes(solid)
    if min_area > 0:
        lab, n = ndimage.label(solid)
        if n:
            sizes = ndimage.sum(solid, lab, range(1, n + 1))
            drop = {i + 1 for i, sz in enumerate(sizes) if sz < min_area}
            solid = solid & ~np.isin(lab, list(drop)) if drop else solid
    if keep_largest:
        lab, n = ndimage.label(solid)
        if n > 1:
            sizes = ndimage.sum(solid, lab, range(1, n + 1))
            solid = lab == (int(np.argmax(sizes)) + 1)
    alpha = np.maximum(alpha, solid.astype(np.float32))
    alpha = alpha * ndimage.binary_dilation(solid, iterations=2).astype(np.float32)
    if feather > 0:
        alpha = ndimage.gaussian_filter(alpha, feather)
        alpha = np.clip(alpha * 1.15, 0.0, 1.0)

    rgba = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    bbox = img.getbbox()
    if bbox:
        l, t, rr, bb = bbox
        img = img.crop((max(0, l - pad), max(0, t - pad),
                        min(img.width, rr + pad), min(img.height, bb + pad)))
    return img


def rect(key: str, box: tuple[int, int, int, int]) -> Image.Image:
    """Straight crop, no matting -- for tiles and already-rectangular UI plates."""
    x0, y0, x1, y1 = box
    return Image.fromarray(load(key)[y0:y1, x0:x1].astype(np.uint8), "RGB").convert("RGBA")


# Derived assets: built from other cut-outs rather than lifted directly.
# The wall in the mockup is drawn in perspective, so it cannot be used as a
# straight texture; rotating the (flat, face-on) platform slab gives a wall that
# matches the platform exactly, which is what the fiction wants anyway.
DERIVED = {
    "wall": lambda: (
        Image.open(os.path.join(OUT, "holograms", "platform.png"))
        .transpose(Image.ROTATE_90)
    ),
}

# name -> (category, source, box, kind, kwargs, note)
ASSETS: list[tuple] = [
    # ---- characters -------------------------------------------------------
    ("runner_run",     "characters", "m2", (656, 424, 750, 526), "cut", dict(tol=40), "running, clear sky"),
    ("runner_jump",    "characters", "m1", (776, 300, 906, 446), "cut", dict(tol=40), "mid-jump, clear sky"),
    ("walker",         "characters", "m2", (1356, 460, 1444, 552), "cut", dict(tol=30), "on grass, unobstructed"),
    # ---- holograms --------------------------------------------------------
    ("platform",       "holograms",  "m1", (662, 424, 968, 502), "cut", dict(tol=26), "solid slab, face-on"),
    ("wall",           "holograms",  "m1", (0, 0, 0, 0), "derive", {}, "platform rotated 90deg"),
    # ---- props ------------------------------------------------------------
    ("pipe",           "props",      "m3", (470, 430, 604, 524), "cut", dict(tol=32), "zoomed, highest res"),
    ("qblock",         "props",      "m3", (332, 332, 448, 402), "cut", dict(tol=32), "zoomed"),
    ("brick",          "props",      "m1", (192, 318, 290, 420), "cut", dict(tol=32), "single brick block, sky margin"),
    ("spikes",         "props",      "m3", (606, 626, 916, 694), "cut", dict(tol=40, keep_largest=False), "zoomed spike row"),
    ("fence",          "props",      "m1", (218, 484, 316, 550), "key", dict(channel="warm", lo=2, hi=34, min_area=40), "wooden rail on grass"),
    ("flowers",        "props",      "m1", (134, 474, 216, 536), "cut", dict(tol=26, keep_largest=False), "daisies"),
    # ---- terrain (rect samples, tiled by the renderer) --------------------
    ("grass_cap",      "terrain",    "m2", (1186, 526, 1360, 606), "rect", {}, "grass band, prop-free plateau"),
    ("dirt_body",      "terrain",    "m1", (60, 616, 520, 756), "rect", {}, "dirt strata, measured"),
    ("dirt_body_alt",  "terrain",    "m1", (60, 606, 460, 700), "rect", {}, "second strata variation"),
    # ---- background (chroma-keyed: too close to sky for the distance matte)
    ("cloud_a",        "bg",         "m1", (440, 18, 668, 122), "key", dict(channel="not_sky", lo=-72, hi=-26), ""),
    ("cloud_b",        "bg",         "m1", (1080, 146, 1312, 244), "key", dict(channel="not_sky", lo=-72, hi=-26), ""),
    ("cloud_c",        "bg",         "m1", (176, 206, 352, 294), "key", dict(channel="not_sky", lo=-72, hi=-26), ""),
    ("castle",         "bg",         "m2", (1410, 120, 1624, 306), "key", dict(channel="not_sky", lo=-76, hi=-22, min_area=120), "distant skyline"),
    # ---- ui ---------------------------------------------------------------
    ("panel_p1",       "ui",         "m3", (0, 4, 316, 96), "rect", {}, "P1 plate with hearts"),
    ("panel_p2",       "ui",         "m3", (4, 104, 330, 196), "rect", {}, "P2 plate"),
    ("portrait_lira",  "ui",         "m3", (10, 10, 104, 92), "rect", {}, ""),
    ("portrait_orion", "ui",         "m3", (14, 110, 108, 192), "rect", {}, ""),
    ("stage_plate",    "ui",         "m1", (1336, 8, 1672, 100), "rect", {}, "stage name + objective"),
    ("ability_bar",    "ui",         "m1", (586, 738, 1084, 924), "rect", {}, "unselected state"),
    ("icon_platform",  "ui",         "m3", (676, 800, 762, 880), "key", dict(channel="bright", lo=52, hi=112), "lit frame"),
    ("icon_wall",      "ui",         "m3", (794, 800, 880, 880), "key", dict(channel="bright", lo=52, hi=112), ""),
    ("icon_snipe",     "ui",         "m3", (912, 800, 998, 880), "key", dict(channel="bright", lo=52, hi=112), "selected state"),
    ("heart",          "ui",         "m3", (123, 46, 164, 83), "key", dict(channel="bright", lo=44, hi=82, keep_largest=True), "single filled heart"),
    # ---- scope furniture --------------------------------------------------
    ("zoom_slider",    "scope",      "m3", (1490, 272, 1560, 552), "rect", {}, ""),
    ("cartridge",      "scope",      "m3", (1404, 640, 1604, 796), "key", dict(channel="bright", lo=88, hi=150, keep_largest=True), "bullet glyph for the fire button"),
    ("btn_reticle",    "scope",      "m3", (1556, 808, 1648, 894), "cut", dict(tol=40), ""),
]


def contact_sheet(paths: list[str], out_path: str, cell: int = 190) -> None:
    """Checkerboard contact sheet so transparency is visible at a glance."""
    cols = 7
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * (cell + 18)), (30, 34, 40))
    check = Image.new("RGB", (cell, cell), (70, 74, 82))
    for cy in range(0, cell, 12):
        for cx in range(0, cell, 12):
            if (cx // 12 + cy // 12) % 2 == 0:
                check.paste((96, 100, 110), (cx, cy, min(cx + 12, cell), min(cy + 12, cell)))
    from PIL import ImageDraw
    draw = ImageDraw.Draw(sheet)
    for i, p in enumerate(paths):
        im = Image.open(p).convert("RGBA")
        im.thumbnail((cell - 8, cell - 8))
        cx, cy = (i % cols) * cell, (i // cols) * (cell + 18)
        sheet.paste(check, (cx, cy))
        sheet.paste(im, (cx + (cell - im.width) // 2, cy + (cell - im.height) // 2), im)
        name = os.path.splitext(os.path.basename(p))[0]
        draw.text((cx + 4, cy + cell + 3), f"{name} {im.width}x{im.height}", fill=(220, 226, 234))
    sheet.save(out_path)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None, help="comma-separated asset names")
    ap.add_argument("--sheet", default=None, help="write a contact sheet here")
    args = ap.parse_args()
    wanted = set(args.only.split(",")) if args.only else None

    written, rows = [], []
    for name, cat, src, box, kind, kwargs, note in ASSETS:
        if wanted and name not in wanted:
            continue
        if kind == "rect":
            img = rect(src, box)
        elif kind == "key":
            img = keyed(src, box, **kwargs)
        elif kind == "derive":
            img = DERIVED[name]()
        else:
            img = cutout(src, box, **kwargs)
        if f"{cat}/{name}.png" in SUPPLIED:
            print(f"  {cat}/{name}.png  SKIPPED (supplied painted art)")
            continue
        d = os.path.join(OUT, cat)
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, name + ".png")
        img.save(path)
        written.append(path)
        rows.append((f"{cat}/{name}.png", src, str(box), kind, f"{img.width}x{img.height}", note))
        print(f"  {cat}/{name}.png  {img.width}x{img.height}  from {src}{box}")

    if not wanted:
        with open(os.path.join(OUT, "SOURCES.md"), "w") as fh:
            fh.write("# Asset provenance\n\n")
            fh.write("Every sprite here was cut from one of the three concept mockups supplied\n"
                     "with the brief, by `tools/extract_assets.py`. Re-run that script to\n"
                     "regenerate; the crop boxes live in its `ASSETS` table.\n\n")
            fh.write("| file | mockup | crop (x0,y0,x1,y1) | method | size | note |\n")
            fh.write("|---|---|---|---|---|---|\n")
            for r in rows:
                fh.write("| `%s` | %s | `%s` | %s | %s | %s |\n" % r)
            fh.write("\nMockups: `m1` solid holograms + mid-jump runner, `m2` dashed previews +\n"
                     "clear walker, `m3` full-screen scope (~1.5x scale, best for detail).\n")

    if args.sheet:
        contact_sheet(written, args.sheet)
        print("sheet ->", args.sheet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
