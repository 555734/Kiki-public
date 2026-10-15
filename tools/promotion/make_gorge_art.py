#!/usr/bin/env python3
"""Paint the opening gorge of 1-10 (the rescue) as production PNGs.

    python3 tools/promotion/make_gorge_art.py

Writes assets/stage_1_10/gorge_left.png, gorge_right.png and gorge_far.png
with the soft, outlined, lit-solid painter of make_creature_art.py (shapes as
signed distance fields, lit from the upper left, a dark outline, grain).

* gorge_left  -- the near cliff: grass run-up, its lip at the gorge, a rock
  face of bulging strata with vines, falling away into the dark.
  Drawn 1:1 with its top-left at world (860, 1100); the walkable top is
  world y 1160 (image y 60), the lip at world x 1540 (image x 680).
* gorge_right -- the far bank: a grass-topped overhang (top world y 1040,
  front edge world x 2300) whose underside recedes to a wall at world
  x 2860; roots and rocks hang from it. Top-left at world (2280, 1000).
* gorge_far   -- the gorge's far side seen across the gap: blue, hazy rock
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


def gorge_left():
    W, H = 760, 1800
    c = P.Canvas(W, H)
    # The near cliff: flat run-up top at y 60, a lip at x 680; the face
    # bulges in and out in layers as it drops.
    face = [(680, 60), (694, 92), (676, 150), (708, 230), (690, 320), (722, 420), (680, 520),
            (712, 640), (668, 780), (704, 930), (660, 1100), (690, 1300), (650, 1550), (676, 1800)]
    body = [(-60, 60)] + face + [(-60, 1800)]
    d = c.poly(body)
    rows = list(range(150, 1700, 105))
    c.paint(d, ROCK, bevel=46, outline=5, ink=INK, seed=11, grain=0.08, shade=0.55,
            cracks=strata(c, d, rows, 12, -40, 720))
    # Boulders standing out of the face, each lit on its own.
    rng = np.random.default_rng(13)
    for (bx, by, r) in [(640, 200, 46), (660, 380, 58), (630, 600, 52), (668, 760, 40), (620, 980, 62),
                        (650, 1240, 54), (560, 300, 38), (520, 520, 44), (560, 860, 50), (500, 1120, 46)]:
        bd = c.ellipse(bx, by, r * 1.15, r * 0.82, rng.uniform(-0.4, 0.4))
        c.paint(np.maximum(bd, d), ["#c9874e", "#b56d3c", "#d09358"][int(rng.integers(0, 3))], bevel=26, outline=4,
                ink=INK, seed=int(rng.integers(0, 999)), grain=0.07)
    # Grass top with a mossy lip and vines hanging down the face.
    top = [(-60, 60), (200, 58), (420, 62), (600, 58), (686, 62)]
    grass_cap(c, top, 14, lip_vines=[(676, 70, 150), (650, 72, 90), (690, 74, 230)])
    flowers(c, [(110, 64), (300, 62), (470, 64), (560, 62)], 15)
    depth_fade(c, 420, 1500)
    # Blend into the slope at the left edge.
    c.a = c.a * np.clip(c.x / 40.0, 0, 1)
    c.save("gorge_left")


def gorge_right():
    W, H = 960, 1900
    c = P.Canvas(W, H)
    # Top at y 40 (world 1040). Front of the overhang at x 20 (world 2300);
    # its underside sags and recedes to the wall at x 580 (world 2860).
    under = [(1000, 40), (1000, 1900), (580, 1900), (600, 1500), (566, 1160), (604, 860), (570, 600),
             (590, 470), (520, 420), (430, 400), (330, 410), (240, 380), (150, 360), (80, 320), (36, 250),
             (18, 160), (22, 80), (30, 40)]
    d = c.poly(under)
    rows = list(range(130, 1800, 110))
    c.paint(d, ROCK, bevel=48, outline=5, ink=INK, seed=21, grain=0.08, shade=0.55,
            cracks=strata(c, d, rows, 22, 0, 960))
    rng = np.random.default_rng(23)
    for (bx, by, r) in [(60, 180, 44), (150, 300, 50), (280, 350, 46), (420, 360, 40), (560, 700, 52),
                        (600, 1000, 48), (580, 1320, 56), (230, 180, 36), (380, 240, 42), (760, 300, 60)]:
        bd = c.ellipse(bx, by, r * 1.2, r * 0.8, rng.uniform(-0.4, 0.4))
        c.paint(np.maximum(bd, d), ["#c9874e", "#b56d3c", "#d09358"][int(rng.integers(0, 3))], bevel=26, outline=4,
                ink=INK, seed=int(rng.integers(0, 999)), grain=0.07)
    # Roots hanging from the overhang's underside.
    roots = np.full(c.x.shape, 1e9, np.float32)
    for (rx, ry, ln) in [(110, 350, 120), (210, 375, 80), (330, 405, 150), (470, 410, 100), (520, 420, 60)]:
        pts = [(rx, ry)]
        for k in range(1, 6):
            pts.append((rx + 10 * np.sin(k * 1.7 + rx), ry + ln * k / 5))
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            roots = np.minimum(roots, c.capsule(ax, ay, bx, by, 6, 3))
    c.paint(roots, "#7a4a2a", bevel=4, outline=3, ink=INK, seed=24, grain=0.05)
    top = [(22, 40), (300, 38), (600, 42), (980, 40)]
    grass_cap(c, top, 25, lip_vines=[(30, 50, 110), (60, 52, 60), (120, 50, 150)])
    flowers(c, [(180, 44), (340, 42), (520, 44), (700, 42), (860, 44)], 26)
    depth_fade(c, 520, 1600)
    c.save("gorge_right")


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
    gorge_left()
    gorge_right()
    gorge_far()
