#!/usr/bin/env python3
"""Paint the opening gorge of 1-10 (the rescue) as production PNGs.

    python3 tools/promotion/make_gorge_art.py

Writes assets/stage_1_10/gorge_left.png, gorge_right.png and gorge_far.png
with the soft, outlined, lit-solid painter of make_creature_art.py (shapes as
signed distance fields, lit from the upper left, a dark outline, grain).

* gorge_left  -- the near cliff: grass run-up, an undercut lip, a buttress
  at mid height with a shelf and a tree, strata bands and angular rocks,
  falling away into the dark.
  Drawn 1:1 with its top-left at world (860, 1100); the walkable top is
  world y 1160 (image y 60), the lip at world x 1540 (image x 680).
* gorge_right -- the far bank: a heavy grass-topped overhang (top world y
  1040, front edge world x 2300) with teeth of rock and roots under it,
  receding to a wall at world x 2860 with a shelf and a twisted tree. Top-left at world (2280, 1000).
* gorge_wall  -- the canyon beyond the gap: three ranges of mesas stepping
  into haze under open sky, waterfalls from the middle range into mist, the
  dark below. Top-left at world (1300, 520).
* gorge_far   -- the gorge's inner wall seen across the gap: blue, hazy rock
  ledges of the gorge's inner wall, lit at the rim just under the lips and
  sinking into black within ~300px, a thin waterfall dropping into it; the waterfall under the near cliff, left of the runner's path.
  Top-left at world (1480, 1180).

The collision shapes stay the level's rectangles (level_finale_data.gd);
these paintings replace how they look.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_creature_art as P  # noqa: E402

ROCK = "#c07a44"
ROCK_DARK = "#8a5230"
GRASS = "#62c23c"
GRASS_DARK = "#3c8a2a"
INK = "#3b2416"


def wavy(xs, base, amp, f, ph):
    return base + amp * np.sin(xs * f + ph)


def depth_fade(c, y0, y1, to=(0.06, 0.07, 0.13), k=0.92):
    """Darken toward the bottom: the drop goes into shadow."""
    t = np.clip((c.y - y0) / (y1 - y0), 0, 1) ** 1.2 * k
    c.rgb = c.rgb * (1 - t[..., None]) + np.array(to, np.float32) * t[..., None]


def grass_cap(c, pts, seed, lip_vines=()):
    """A grass band along the walkable top `pts`, with tufts and vines."""
    d = np.full(c.x.shape, 1e9, np.float32)
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        d = np.minimum(d, c.capsule(ax, ay + 12, bx, by + 12, 17))
    rng = np.random.default_rng(seed)
    tufts = np.full(c.x.shape, 1e9, np.float32)
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        n = int(abs(bx - ax) / 26)
        for k in range(n):
            x = ax + (bx - ax) * (k + rng.uniform(0.1, 0.9)) / max(n, 1)
            y = ay + (by - ay) * (x - ax) / max(bx - ax, 1)
            h = rng.uniform(10, 22)
            tufts = np.minimum(tufts, c.poly([(x - 7, y + 4), (x + rng.uniform(-4, 4), y - h), (x + 7, y + 4)]))
    for (vx, vy, length) in lip_vines:
        pts_v = [(vx, vy)]
        for k in range(1, 7):
            pts_v.append((vx + 7 * np.sin(k * 1.3), vy + length * k / 6))
        for (ax, ay), (bx, by) in zip(pts_v[:-1], pts_v[1:]):
            d = np.minimum(d, c.capsule(ax, ay, bx, by, 6 - 0.5 * (ay - vy) / max(length, 1) * 4, 4))
        d = np.minimum(d, c.circle(pts_v[-1][0], pts_v[-1][1], 7))
    c.paint(np.minimum(d, tufts), GRASS, bevel=10, outline=4, ink="#24461a", seed=seed, grain=0.05, shade=0.45)


def flowers(c, spots, seed):
    rng = np.random.default_rng(seed)
    for (x, y) in spots:
        col = ["#ffffff", "#ffd84a", "#ff8fb0"][int(rng.integers(0, 3))]
        d = np.full(c.x.shape, 1e9, np.float32)
        for k in range(5):
            a = k * 2 * np.pi / 5
            d = np.minimum(d, c.circle(x + 6 * np.cos(a), y - 14 + 6 * np.sin(a), 4.5))
        c.paint(c.capsule(x, y, x, y - 12, 2), GRASS_DARK, bevel=2, outline=1.5, ink="#24461a", seed=seed + 1)
        c.paint(d, col, bevel=3, outline=2, ink="#6a4a3a", seed=seed + 2, grain=0.02)
        c.paint(c.circle(x, y - 14, 3), "#f2b03a", bevel=2, outline=1, ink="#6a4a3a", seed=seed + 3)


def strata(c, mask_d, rows, seed, x0, x1):
    """Darker cracks between rock layers, only inside the rock."""
    rng = np.random.default_rng(seed)
    cracks = []
    for y in rows:
        xs = np.linspace(x0, x1, 12)
        pts = [(float(x), float(y + rng.uniform(-10, 10) + 8 * np.sin(x * 0.02 + y))) for x in xs]
        cracks.append((pts, 1.7))
    return cracks


BANDS = ["#cf8e54", "#b9733f", "#dba468", "#a8653a", "#c4824b"]


def bands(c, body_d, y0, y1, seed, x0, x1, tilt=0.0):
    """Rock strata: wavy horizontal layers of alternating colour inside the
    body, each lit as its own slab."""
    rng = np.random.default_rng(seed)
    y = y0
    k = 0
    while y < y1:
        h = rng.uniform(60, 130)
        xs = np.linspace(x0, x1, 24)
        top = y + 10 * np.sin(xs * 0.013 + k) + 6 * np.sin(xs * 0.051 + 2 * k) + tilt * (xs - x0)
        bot = y + h + 10 * np.sin(xs * 0.011 + k + 1) + 5 * np.sin(xs * 0.047 + k) + tilt * (xs - x0)
        poly = [(float(x), float(t)) for x, t in zip(xs, top)] + [(float(x), float(b)) for x, b in zip(xs[::-1], bot[::-1])]
        d = np.maximum(c.poly(poly), body_d + 2.0)
        c.paint(d, BANDS[k % len(BANDS)], bevel=18, outline=2.5, ink="#5a3420", seed=seed + k, grain=0.07, shade=0.5)
        y += h
        k += 1


def facets(c, body_d, chunks, seed):
    """Angular rock chunks jutting from a face: (cx, cy, r, sides)."""
    rng = np.random.default_rng(seed)
    for (cx, cy, r, n) in chunks:
        a0 = rng.uniform(0, 6.28)
        pts = []
        for i in range(n):
            a = a0 + i * 2 * np.pi / n + rng.uniform(-0.25, 0.25)
            rr = r * rng.uniform(0.7, 1.15)
            pts.append((cx + rr * np.cos(a), cy + rr * 0.8 * np.sin(a)))
        d = c.poly(pts)
        c.paint(d, ["#d49a5e", "#c07a44", "#e0ae72"][int(rng.integers(0, 3))], bevel=22, outline=4, ink=INK,
                seed=int(rng.integers(0, 999)), grain=0.07, shade=0.55)


def tree(c, x, y, h, seed, lean=0.0):
    """A small cliff tree: a crooked trunk and a soft round crown."""
    trunk = np.full(c.x.shape, 1e9, np.float32)
    pts = [(x, y)]
    for k in range(1, 5):
        pts.append((x + lean * h * k / 4 + 6 * np.sin(k * 1.9 + seed), y - h * 0.62 * k / 4))
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        trunk = np.minimum(trunk, c.capsule(ax, ay, bx, by, h * 0.06, h * 0.045))
    c.paint(trunk, "#7a4b2c", bevel=6, outline=3, ink=INK, seed=seed, grain=0.06)
    tx, ty = pts[-1]
    crown = np.full(c.x.shape, 1e9, np.float32)
    rng = np.random.default_rng(seed)
    for k in range(6):
        crown = P.smin(crown, c.circle(tx + rng.uniform(-0.32, 0.32) * h, ty - rng.uniform(0.0, 0.3) * h, h * rng.uniform(0.18, 0.26)), 10)
    c.paint(crown, "#4fae3a", bevel=16, outline=4, ink="#24461a", seed=seed + 1, grain=0.06, shade=0.5)


def vines(c, starts, seed):
    d = np.full(c.x.shape, 1e9, np.float32)
    for (vx, vy, length) in starts:
        pts = [(vx, vy)]
        for k in range(1, 8):
            pts.append((vx + 8 * np.sin(k * 1.3 + vx), vy + length * k / 7))
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            d = np.minimum(d, c.capsule(ax, ay, bx, by, 5, 3.5))
        for k in range(2, 7, 2):
            lx, ly = pts[k]
            d = np.minimum(d, c.ellipse(lx + 7, ly, 9, 5, 0.6))
    c.paint(d, "#4fb43a", bevel=5, outline=3, ink="#24461a", seed=seed, grain=0.05)


def ledge(c, x0, x1, y, depth, seed):
    """A rock shelf sticking out of a face, grass on top (decoration)."""
    xs = np.linspace(x0, x1, 10)
    under = [(float(x), float(y + depth * (1 - abs((x - (x0 + x1) / 2) / ((x1 - x0) / 2)) ** 1.6) + 6 * np.sin(x * 0.1)))
             for x in xs[::-1]]
    d = c.poly([(x0, y), (x1, y)] + under)
    c.paint(d, "#c98a52", bevel=20, outline=4, ink=INK, seed=seed, grain=0.07)
    grass_cap(c, [(x0 - 4, y - 10), (x1 + 4, y - 10)], seed + 1)


def gorge_left():
    W, H = 860, 1800
    c = P.Canvas(W, H)
    # The near cliff: flat run-up top at y 60, the lip at x 680. Under the
    # lip the face is undercut, then a great buttress juts out at mid
    # height with a shelf and a tree; below that it slants back in and
    # drops in rough steps into the dark.
    face = [(680, 60), (690, 96), (664, 150), (640, 230), (652, 300), (700, 360), (770, 430), (800, 520),
            (770, 600), (720, 650), (680, 740), (700, 860), (660, 980), (690, 1120), (640, 1300), (670, 1500),
            (630, 1800)]
    body = [(-60, 60)] + face + [(-60, 1800)]
    d = c.poly(body)
    c.paint(d, ROCK, bevel=50, outline=5, ink=INK, seed=11, grain=0.08, shade=0.55)
    bands(c, d, 110, 1780, 12, -60, 820, tilt=0.03)
    facets(c, d, [(668, 150, 38, 6), (720, 450, 54, 7), (760, 540, 40, 6), (690, 640, 46, 6), (672, 900, 52, 7),
                  (660, 1180, 48, 6), (650, 1420, 56, 7), (560, 340, 30, 5), (600, 800, 34, 5)], 13)
    ledge(c, 690, 830, 410, 60, 16)
    tree(c, 770, 404, 150, 17, lean=0.25)
    grass_cap(c, [(-60, 60), (200, 58), (420, 62), (600, 58), (690, 62)], 14)
    vines(c, [(676, 72, 170), (650, 74, 100), (700, 420, 140), (790, 430, 90)], 18)
    flowers(c, [(110, 64), (300, 62), (470, 64), (560, 62)], 15)
    depth_fade(c, 520, 1500)
    c.a = c.a * np.clip(c.x / 40.0, 0, 1)
    c.save("gorge_left")


def gorge_right():
    W, H = 1000, 1900
    c = P.Canvas(W, H)
    # Top at y 40 (world 1040), front at x 20 (world 2300): a heavy,
    # forward-leaning overhang with jagged teeth of rock under it; the face
    # recedes to x 580 (world 2860) with a buttress and a twisted tree
    # half-way down.
    under = [(1040, 40), (1040, 1900), (600, 1900), (620, 1560), (560, 1300), (430, 1180), (470, 1100),
             (600, 1020), (580, 760), (612, 560), (560, 470), (500, 455), (470, 520), (430, 440), (360, 430),
             (320, 500), (285, 420), (220, 400), (170, 450), (140, 375), (80, 330), (40, 260), (14, 170),
             (16, 90), (28, 40)]
    d = c.poly(under)
    c.paint(d, ROCK, bevel=50, outline=5, ink=INK, seed=21, grain=0.08, shade=0.55)
    bands(c, d, 80, 1880, 22, 0, 1040, tilt=-0.02)
    facets(c, d, [(40, 200, 40, 6), (120, 320, 48, 7), (260, 380, 44, 6), (420, 410, 38, 6), (600, 700, 50, 7),
                  (470, 1150, 58, 7), (600, 1450, 54, 6), (300, 150, 32, 5), (520, 260, 36, 5)], 23)
    ledge(c, 400, 560, 1120, 70, 27)
    tree(c, 470, 1114, 190, 28, lean=-0.35)
    roots = np.full(c.x.shape, 1e9, np.float32)
    for (rx, ry, ln) in [(110, 360, 120), (215, 400, 80), (330, 430, 150), (470, 500, 100), (520, 460, 60)]:
        pts = [(rx, ry)]
        for k in range(1, 6):
            pts.append((rx + 10 * np.sin(k * 1.7 + rx), ry + ln * k / 5))
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            roots = np.minimum(roots, c.capsule(ax, ay, bx, by, 6, 3))
    c.paint(roots, "#7a4a2a", bevel=4, outline=3, ink=INK, seed=24, grain=0.05)
    grass_cap(c, [(22, 40), (300, 38), (600, 42), (1040, 40)], 25)
    vines(c, [(30, 52, 120), (64, 54, 70), (130, 52, 160), (420, 1126, 120)], 29)
    flowers(c, [(180, 44), (340, 42), (520, 44), (700, 42), (860, 44)], 26)
    depth_fade(c, 620, 1650)
    c.save("gorge_right")


def skyline(keys, jitter, seed):
    """A weathered rim through `keys`: every edge broken up a little."""
    rng = np.random.default_rng(seed)
    out = []
    for (ax, ay), (bx, by) in zip(keys[:-1], keys[1:]):
        for t in np.linspace(0, 1, 7, endpoint=False):
            x = ax + (bx - ax) * t
            out.append((x, ay + (by - ay) * t + jitter * (np.sin(x * 0.07 + seed) * 0.6 + np.sin(x * 0.19 + seed * 2) * 0.4)
                        + rng.uniform(-jitter, jitter) * 0.3))
    out.append(keys[-1])
    return out


def mesa_range(c, keys, col, ink, seed, band_cols, band_h, H, jitter=7.0, shrubs=0, shrub_col="#7fa65a"):
    """One range of the canyon's far side: a rimmed silhouette with its own
    strata (different band heights and tilt per range, so no two read the
    same), a few shrubs along the rim."""
    sky = skyline(keys, jitter, seed)
    d = c.poly(sky + [(c.w + 20, H), (-20, H)])
    c.paint(d, col, bevel=46, outline=2.5, ink=ink, seed=seed, grain=0.05, shade=0.42)
    rng = np.random.default_rng(seed + 1)
    xs = np.linspace(-20, c.w + 20, 36)
    y = min(k[1] for k in keys) + rng.uniform(20, 60)
    k = 0
    tilt = rng.uniform(-0.04, 0.04)
    while y < H:
        h = rng.uniform(*band_h)
        top = y + 12 * np.sin(xs * rng.uniform(0.006, 0.012) + k) + 7 * np.sin(xs * 0.031 + seed + k) + (xs - c.w / 2) * tilt
        band = [(float(x), float(t)) for x, t in zip(xs, top)] + [(float(x), float(t + h)) for x, t in zip(xs[::-1], top[::-1])]
        c.paint(np.maximum(c.poly(band), d + 2), band_cols[k % len(band_cols)], bevel=22, outline=1.5, ink=ink,
                seed=seed + 10 + k, grain=0.05, shade=0.38)
        y += h
        k += 1
    rim = np.array(sky)
    for i in range(shrubs):
        x = rng.uniform(40, c.w - 40)
        ty = float(np.interp(x, rim[:, 0], rim[:, 1]))
        blob = np.minimum(c.ellipse(x, ty - 4, rng.uniform(16, 30), rng.uniform(8, 13)),
                          c.ellipse(x + rng.uniform(-18, 18), ty - 12, rng.uniform(10, 18), rng.uniform(8, 12)))
        c.paint(blob, shrub_col, bevel=7, outline=1.5, ink=ink, seed=seed + 50 + i, grain=0.03, shade=0.4)
    return d


def haze_mix(c, mask, color, k):
    """Wash what is inside `mask` (d < 0) toward the air colour."""
    m = (mask < 0).astype(np.float32)[..., None] * k
    c.rgb = c.rgb * (1 - m) + np.array(P.hexc(color), np.float32) * m * c.a[..., None]


def waterfall(c, fx, y0, y1, w, seed, mist_y):
    yy = np.linspace(y0, y1, 40)
    left = fx - w - (yy - y0) * 0.02 + 4 * np.sin(yy * 0.03 + seed)
    right = fx + w + (yy - y0) * 0.02 + 4 * np.sin(yy * 0.027 + seed + 1)
    fall = c.poly([(float(x), float(y)) for x, y in zip(left, yy)] + [(float(x), float(y)) for x, y in zip(right[::-1], yy[::-1])])
    c.paint(fall, "#e9f5ff", bevel=10, outline=1.5, ink="#8aa6cc", seed=seed, grain=0.02, shade=0.2)
    for i in range(int(w / 2.5)):
        x = fx - w + i * 5
        st = np.clip(1 - np.abs(c.x - (x + (c.y - y0) * (i - w / 5) * 0.004)) / 1.6, 0, 1) * (c.y > y0 + 8) * (c.y < y1)
        st = st * (0.6 + 0.4 * np.sin(c.y * 0.05 + i))
        c.rgb = c.rgb + (np.array([1, 1, 1], np.float32) * c.a[..., None] - c.rgb) * (0.45 * st)[..., None]
    for i in range(7):
        mist = np.clip(1 - np.hypot((c.x - fx - (i - 3) * w * 1.6) / (w * 4.5), (c.y - mist_y - (i % 3) * 18) / 60), 0, 1) ** 2
        c.rgb = c.rgb + (np.array([0.96, 0.98, 1.0], np.float32) - c.rgb) * (0.55 * mist)[..., None]
        c.a = np.maximum(c.a, 0.85 * mist)


def gorge_wall():
    """The canyon seen beyond the gap: three ranges of mesas stepping away
    into haze -- the farthest pale and low under open sky, the nearest warm
    and darker -- with waterfalls dropping from the middle range into mist,
    and the dark of the gorge below. Low enough that sky shows above the
    leap, layered so the air behind a falling runner has depth instead of a
    single wall. Top-left at world (1300, 520)."""
    W, H = 1900, 2300
    c = P.Canvas(W, H)
    ink = "#8c7f9c"
    # Farthest: low pale buttes on the horizon (world y ~950).
    far = mesa_range(c, [(-20, 320), (140, 305), (190, 250), (330, 242), (370, 296), (600, 302), (650, 270), (820, 265),
                         (860, 320), (1100, 312), (1150, 254), (1330, 248), (1380, 305), (1650, 298), (1700, 268), (1920, 270)],
                     "#e6c9b4", ink, 61, ["#e8cdb8", "#dcbfab", "#efd8c4"], (50, 90), H, jitter=5, shrubs=10, shrub_col="#a9c08e")
    haze_mix(c, far, "#d7dff2", 0.3)
    # Middle: taller mesas with a notch; waterfalls pour from it.
    mid = mesa_range(c, [(-20, 540), (90, 500), (140, 448), (300, 440), (350, 500), (520, 512), (560, 470), (700, 462),
                         (740, 520), (900, 532), (960, 460), (1120, 452), (1160, 510), (1420, 518), (1470, 475), (1700, 466),
                         (1750, 530), (1920, 540)],
                     "#d6aa8e", ink, 71, ["#d8ae90", "#c99c82", "#e0b898"], (60, 120), H, jitter=7, shrubs=14, shrub_col="#86a868")
    haze_mix(c, mid, "#d7dff2", 0.18)
    waterfall(c, 470, 500, 1250, 16, 81, 1080)
    waterfall(c, 1040, 512, 1200, 11, 83, 1050)
    # Nearest of the far side: a broken ledge line, warm, with shrubs, lower
    # still -- it passes behind the rescue (world y ~1230).
    near = mesa_range(c, [(-20, 780), (120, 740), (200, 700), (380, 712), (430, 770), (640, 760), (700, 716), (880, 706),
                          (930, 768), (1200, 776), (1260, 724), (1460, 716), (1500, 780), (1920, 790)],
                      "#c98f6c", "#7a5a6c", 91, ["#c99372", "#b98268", "#d39f7c"], (70, 140), H, jitter=9, shrubs=16,
                      shrub_col="#6f9a50")
    haze_mix(c, near, "#cdd6ee", 0.12)
    # The gorge falls away below all of it.
    depth_fade(c, 690, 1280, to=(0.07, 0.08, 0.17), k=0.95)
    c.save("gorge_wall")


def gorge_far():
    W, H = 1500, 1700
    c = P.Canvas(W, H)
    haze = np.array(P.hexc("#8fa6c4"), np.float32)
    # Two terraces of the far side, lighter (further) behind darker.
    for k, (top, col) in enumerate([(30, "#9a8a80"), (140, "#7d6e6a")]):
        xs = np.linspace(-20, W + 20, 26)
        xs = np.linspace(-20, W + 20, 60)
        ys = top + 18 * np.sin(xs * 0.011 + k * 2.0) + 12 * np.sin(xs * 0.037 + k) + 6 * np.sin(xs * 0.13 + k * 3)
        poly = [(float(x), float(y)) for x, y in zip(xs, ys)] + [(W + 20, H), (-20, H)]
        d = c.poly(poly)
        c.paint(d, col, bevel=60, outline=3, ink="#4a5a78", seed=31 + k, grain=0.05, shade=0.35,
                cracks=strata(c, d, list(range(top + 140, H, 150)), 33 + k, 0, W))
    # The waterfall: a pale ribbon from a notch, streaked, into mist.
    fx = 190
    fall = c.poly([(fx - 20, 120), (fx + 20, 120), (fx + 40, H), (fx - 40, H)])
    c.paint(fall, "#d8ecff", bevel=14, outline=2, ink="#6f8fb8", seed=35, grain=0.02, shade=0.25)
    rng = np.random.default_rng(36)
    for k in range(9):
        x = fx - 24 + k * 6 + rng.uniform(-2, 2)
        streak = np.clip(1 - np.abs(c.x - (x + (c.y - 190) * (k - 4) * 0.004)) / 1.6, 0, 1) * (c.y > 130) * (np.abs(c.x - fx) < 40)
        c.rgb = c.rgb + (np.array([1, 1, 1], np.float32) - c.rgb) * (0.5 * streak)[..., None]
    for k in range(6):
        mist = np.clip(1 - np.hypot((c.x - fx - (k - 2.5) * 50) / 120, (c.y - 700 - k * 40) / 70), 0, 1) ** 2
        c.rgb = c.rgb + (np.array([0.92, 0.96, 1.0], np.float32) - c.rgb) * (0.55 * mist)[..., None]
        c.a = np.maximum(c.a, 0.8 * mist)
    # Air between here and the runner: all of it washes toward the haze,
    # and the bottom sinks into the dark of the gorge.
    c.rgb = c.rgb * 0.75 + haze * 0.25
    depth_fade(c, 10, 300, k=0.96)
    # The falling water stays pale against the dark, fading with depth.
    wf = np.clip(1 - np.abs(c.x - fx) / 40, 0, 1) * (c.y > 130) * np.clip(1 - (c.y - 130) / 1200, 0, 1)
    c.rgb = c.rgb + (np.array([0.8, 0.9, 1.0], np.float32) - c.rgb) * (0.55 * wf)[..., None]
    c.save("gorge_far")


if __name__ == "__main__":
    which = sys.argv[1:] or ["gorge_left", "gorge_right", "gorge_far", "gorge_wall"]
    for name in which:
        globals()[name]()
