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
* gorge_wall  -- the far wall of the whole gorge: hazy mesas whose top is
  well above the leap, a big waterfall pouring from a notch into mist and
  the dark. Top-left at world (1300, 520).
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


def gorge_wall():
    """The gorge's far wall: a great hazy sandstone massif behind the gap,
    its top well above the leap, sinking behind both cliffs at its ends (sky
    beyond), a big waterfall pouring from a notch into mist and the dark.
    Top-left at world (1300, 520)."""
    W, H = 1900, 2300
    c = P.Canvas(W, H)
    haze = np.array(P.hexc("#c4cdea"), np.float32)
    # Skyline: low behind the near cliff, buttes over the gap, a notch for the
    # fall, and down again behind the far bank.
    keys = [(-20, 760), (60, 720), (130, 560), (190, 430), (250, 300), (300, 170), (360, 150), (420, 70),
            (560, 58), (610, 120), (700, 132), (760, 40), (900, 30), (960, 110), (1080, 118), (1120, 86),
            (1250, 92), (1290, 150), (1370, 152), (1410, 70), (1560, 62), (1620, 180), (1700, 330),
            (1760, 470), (1830, 590), (1920, 640)]
    sky = []
    for (ax, ay), (bx, by) in zip(keys[:-1], keys[1:]):
        for t in np.linspace(0, 1, 7, endpoint=False):
            x = ax + (bx - ax) * t
            sky.append((x, ay + (by - ay) * t + 8 * np.sin(x * 0.07) + 5 * np.sin(x * 0.19) + 3 * np.sin(x * 0.53)))
    sky.append(keys[-1])
    d = c.poly(sky + [(1920, H), (-20, H)])
    c.paint(d, "#d4ad90", bevel=80, outline=3, ink="#8a7f9e", seed=41, grain=0.06, shade=0.45)
    rng = np.random.default_rng(42)
    cols = ["#dcb08c", "#c99a7c", "#e3bf98", "#bf8f78", "#d6a888"]
    k = 0
    y = 60
    ledges = []
    while y < H:
        h = rng.uniform(80, 160)
        xs = np.linspace(-20, W + 20, 40)
        tilt = (xs - W / 2) * 0.03 * np.sin(k * 1.7)
        top = y + 16 * np.sin(xs * 0.008 + k) + 9 * np.sin(xs * 0.029 + k) + tilt
        bot = top + h
        band = [(float(x), float(t)) for x, t in zip(xs, top)] + [(float(x), float(b)) for x, b in zip(xs[::-1], bot[::-1])]
        c.paint(np.maximum(c.poly(band), d + 2), cols[k % len(cols)], bevel=30, outline=2,
                ink="#8d7c96", seed=43 + k, grain=0.05, shade=0.4)
        ledges.append((xs, top))
        y += h
        k += 1
    # Broad gullies worn down the face (soft shadow, lit rim on one side).
    for i in range(16):
        x = rng.uniform(80, W - 80)
        y0 = rng.uniform(80, 500)
        ln = rng.uniform(300, 1100)
        wd = rng.uniform(10, 26)
        pts = [(x + 22 * np.sin(j * 0.9 + i), y0 + ln * j / 10) for j in range(11)]
        cd = c.line_dist(pts)
        fade = np.clip(1 - (c.y - y0) / ln, 0, 1) * (d < -6)
        k2 = np.clip(1 - cd / wd, 0, 1) ** 1.5 * fade
        c.rgb = c.rgb * (1 - 0.28 * k2[..., None])
        side = np.clip(1 - np.abs(cd - wd) / 4, 0, 1) * (c.x > np.interp(c.y, [p[1] for p in pts], [p[0] for p in pts])) * fade
        c.rgb = c.rgb + (np.array([1.0, 0.95, 0.88], np.float32) - c.rgb) * (0.22 * side)[..., None]
    # Moss and shrubs on the ledges (small, hazed: far away).
    for (xs, top) in ledges[:9]:
        for _ in range(9):
            x = rng.uniform(0, W)
            ty = float(np.interp(x, xs, top))
            if d[int(np.clip(ty + 6, 0, H - 1)), int(np.clip(x, 0, W - 1))] > -10:
                continue
            for j in range(rng.integers(2, 5)):
                cx = x + rng.uniform(-30, 30)
                r = rng.uniform(9, 18)
                blob = c.ellipse(cx, ty - r * 0.25, r * 1.9, r * 0.62)
                c.paint(blob, ["#7fa65a", "#6b9450", "#93b866"][j % 3], bevel=6, outline=1.5, ink="#5f7a62",
                        seed=int(cx), grain=0.03, shade=0.4)
    # The waterfall from the notch between the buttes: ragged edges, streaks,
    # a plunge of mist low down.
    fx = 1330
    yy = np.linspace(150, H, 40)
    left = fx - 34 - (yy - 150) * 0.02 + 5 * np.sin(yy * 0.03)
    right = fx + 34 + (yy - 150) * 0.02 + 5 * np.sin(yy * 0.027 + 1)
    fall = c.poly([(float(x), float(y)) for x, y in zip(left, yy)] + [(float(x), float(y)) for x, y in zip(right[::-1], yy[::-1])])
    c.paint(fall, "#e6f3ff", bevel=18, outline=2, ink="#8aa6cc", seed=45, grain=0.02, shade=0.22)
    for i in range(14):
        x = fx - 32 + i * 5
        streak = np.clip(1 - np.abs(c.x - (x + (c.y - 150) * (i - 7) * 0.004)) / 1.8, 0, 1) * (c.y > 160)
        streak = streak * (np.abs(c.x - fx) < 75) * (0.6 + 0.4 * np.sin(c.y * 0.05 + i))
        c.rgb = c.rgb + (np.array([1, 1, 1], np.float32) - c.rgb) * (0.45 * streak)[..., None]
    for i in range(9):
        mist = np.clip(1 - np.hypot((c.x - fx - (i - 4) * 60) / 170, (c.y - 1230 - (i % 3) * 40) / 95), 0, 1) ** 2
        c.rgb = c.rgb + (np.array([0.95, 0.97, 1.0], np.float32) - c.rgb) * (0.6 * mist)[..., None]
    # Distance: washed toward the sky (more at the top), then sinking into
    # the gorge's dark below the lips.
    wash = np.clip(0.30 - c.y / H * 0.2, 0.16, 0.30)[..., None]
    c.rgb = c.rgb * (1 - wash) + haze * wash
    depth_fade(c, 650, 1900, to=(0.08, 0.10, 0.20), k=0.9)
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
