#!/usr/bin/env python3
"""Painted raster sprites for 1-10's two giants: the stone giant (body and
arm segments) and the skeletal beast (skull, lower jaw, vertebra, rib).

    python3 tools/promotion/make_creature_art.py

No image generator is available to this project's tooling, so these are
painted procedurally: every shape is a signed-distance field, lit as a
rounded, bevelled solid from the upper left (soft toon bands, a warm
highlight, cool occlusion in the creases), with a thick dark outline and
fine surface grain -- the soft, outlined look of the 1-1 art -- and saved as
PNGs with alpha. Godot draws them as textures (FinaleArt / the machines);
nothing here is drawn as flat shapes at runtime.

Output: assets/stage_1_10/giant_body.png, giant_upper_arm.png,
giant_fist_arm.png, beast_skull.png, beast_jaw.png, beast_vertebra.png,
beast_rib.png (+ PIVOTS printed for the scripts).
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "stage_1_10")
LIGHT = np.array([-0.55, -0.7, 0.62])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        self.x, self.y = xx + 0.5, yy + 0.5
        self.rgb = np.zeros((h, w, 3), np.float32)
        self.a = np.zeros((h, w), np.float32)

    # ------------------------------------------------------------ shapes
    def circle(self, cx, cy, r):
        return np.hypot(self.x - cx, self.y - cy) - r

    def ellipse(self, cx, cy, rx, ry, ang=0.0):
        c, s = np.cos(ang), np.sin(ang)
        dx, dy = self.x - cx, self.y - cy
        u, v = dx * c + dy * s, -dx * s + dy * c
        k = np.hypot(u / rx, v / ry)
        return (k - 1.0) * min(rx, ry)

    def capsule(self, ax, ay, bx, by, ra, rb=None):
        rb = ra if rb is None else rb
        px, py = self.x - ax, self.y - ay
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        t = np.clip((px * dx + py * dy) / L2, 0, 1)
        d = np.hypot(px - dx * t, py - dy * t)
        return d - (ra + (rb - ra) * t)

    def rbox(self, cx, cy, hw, hh, r, ang=0.0):
        c, s = np.cos(ang), np.sin(ang)
        dx, dy = self.x - cx, self.y - cy
        u, v = np.abs(dx * c + dy * s) - hw + r, np.abs(-dx * s + dy * c) - hh + r
        return np.hypot(np.maximum(u, 0), np.maximum(v, 0)) + np.minimum(np.maximum(u, v), 0) - r

    def poly(self, pts):
        pts = np.asarray(pts, np.float32)
        d = np.full(self.x.shape, 1e9, np.float32)
        inside = np.zeros(self.x.shape, bool)
        n = len(pts)
        for i in range(n):
            ax, ay = pts[i]
            bx, by = pts[(i + 1) % n]
            dx, dy = bx - ax, by - ay
            t = np.clip(((self.x - ax) * dx + (self.y - ay) * dy) / (dx * dx + dy * dy + 1e-9), 0, 1)
            d = np.minimum(d, np.hypot(self.x - ax - dx * t, self.y - ay - dy * t))
            cond = ((ay > self.y) != (by > self.y)) & (self.x < (bx - ax) * (self.y - ay) / (by - ay + 1e-9) + ax)
            inside ^= cond
        return np.where(inside, -d, d)

    def line_dist(self, pts):
        d = np.full(self.x.shape, 1e9, np.float32)
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            dx, dy = bx - ax, by - ay
            t = np.clip(((self.x - ax) * dx + (self.y - ay) * dy) / (dx * dx + dy * dy + 1e-9), 0, 1)
            d = np.minimum(d, np.hypot(self.x - ax - dx * t, self.y - ay - dy * t))
        return d

    # ------------------------------------------------------------ paint
    def paint(self, d, base, bevel=18.0, outline=5.0, ink="#2b1d16", shade=0.58, hi=0.45, grain=0.06,
              seed=0, cracks=None, bands=4, cool="#3a4a78", warm="#fff3cf"):
        """Paint a solid whose signed distance is d over what is there."""
        base = hexc(base) if isinstance(base, str) else base
        # Height of a bevelled, rounded solid, and its normal.
        z = np.clip(-d / bevel, 0, 1)
        z = np.sqrt(1 - (1 - z) ** 2) * bevel
        gy, gx = np.gradient(z)
        n = np.dstack([-gx, -gy, np.ones_like(z)])
        n /= np.linalg.norm(n, axis=2, keepdims=True)
        lam = np.clip(n @ LIGHT, 0, 1)
        # Soft toon: lambert eased toward a few bands.
        q = np.round(lam * bands) / bands
        lam = lam * 0.55 + q * 0.45
        rng = np.random.default_rng(seed)
        noise = _noise(self.w, self.h, rng)
        col = base * (1 - shade + shade * lam)[..., None]
        col = col * (1 - grain + 2 * grain * noise)[..., None]
        # Cool occlusion near the outline on the shadow side, warm highlight
        # on the lit crown.
        occl = np.clip(1 - (-d) / (bevel * 1.6), 0, 1) * np.clip(-(n[..., 0] * LIGHT[0] + n[..., 1] * LIGHT[1]), 0, 1)
        col = col * (1 - 0.25 * occl[..., None]) + hexc(cool) * 0.25 * occl[..., None]
        spec = np.clip((lam - 0.86) / 0.14, 0, 1) ** 2
        col = col + (hexc(warm) - col) * (hi * spec)[..., None]
        if cracks is not None:
            for pts, w in cracks:
                cd = self.line_dist(pts)
                k = np.clip(1 - cd / w, 0, 1)
                col = col * (1 - 0.55 * k[..., None])
                lit = np.clip(1 - np.abs(cd - w * 1.4) / (w * 0.6), 0, 1)
                col = col + (hexc(warm) - col) * (0.25 * lit)[..., None] * (cd > w)[..., None]
        ink_c = hexc(ink)
        edge = np.clip((d + outline) / 1.2, 0, 1)
        col = col * (1 - edge[..., None]) + ink_c * edge[..., None]
        alpha = np.clip(0.5 - d, 0, 1)
        self.rgb = self.rgb * (1 - alpha[..., None]) + col * alpha[..., None]
        self.a = self.a + alpha * (1 - self.a)

    def glow(self, cx, cy, r, color, strength=1.0):
        k = np.clip(1 - np.hypot(self.x - cx, self.y - cy) / r, 0, 1) ** 2 * strength
        self.rgb = self.rgb + (hexc(color) - self.rgb) * k[..., None] * (self.a > 0)[..., None]

    def save(self, name):
        os.makedirs(OUT, exist_ok=True)
        img = np.dstack([np.clip(self.rgb / np.maximum(self.a, 1e-4)[..., None], 0, 1), self.a])
        Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"), optimize=True)
        print("wrote %s (%dx%d)" % (name, self.w, self.h))


def _noise(w, h, rng):
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(5):
        g = 3 * 2 ** o
        grid = rng.random((g + 1, g + 1)).astype(np.float32)
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.asarray(img, np.float32) / 255.0 * amp
        tot += amp
        amp *= 0.55
    return out / tot


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


# ======================================================== the stone giant
# Sprites are painted at half world size (scale 0.5): the scripts draw them
# at 2x. Body: 760x1220 px covers world x -760..760, y -2440..0? No -- the
# body's pivot (its feet on the gorge floor line) is noted in PIVOTS.
STONE = "#8e9bb0"
STONE_DARK = "#6c788e"
MOSS = "#6aa33d"


def giant_body():
    c = Canvas(720, 640)
    # World 1 px = 0.5 sprite px. Origin (giant base) at sprite (360, 620).
    ox, oy = 360, 620
    W = lambda x, y: (ox + x * 0.5, oy + y * 0.5)
    # Legs.
    for s in (-1, 1):
        a, b = W(s * 120, -470), W(s * 140, 40)
        c.paint(c.capsule(*a, *b, 70, 84), STONE_DARK, bevel=26, seed=1 + s)
    # Hips / belt.
    belt = c.rbox(*W(0, -440), 200, 50, 30)
    c.paint(belt, "#7a6a5a", bevel=20, seed=4)
    # Torso: a broad chest boulder.
    t1 = c.ellipse(*W(0, -690), 150, 150)
    t2 = c.rbox(*W(0, -560), 120, 110, 60)
    torso = smin(t1, t2, 40)
    cracks = [([W(-120, -800), W(-70, -720), W(-95, -640)], 3.0), ([W(130, -560), W(90, -500), W(110, -450)], 3.0),
              ([W(20, -860), W(55, -800)], 2.5)]
    c.paint(torso, STONE, bevel=60, seed=7, cracks=cracks, grain=0.08)
    # Chest core socket (the glowing core is drawn live on top).
    c.paint(c.circle(*W(0, -620), 38), "#2a2c38", bevel=10, seed=8)
    # Shoulder boulders.
    for s in (-1, 1):
        c.paint(c.ellipse(*W(s * 250, -830), 64, 58, s * 0.3), STONE, bevel=40, seed=10 + s,
                cracks=[([W(s * 230, -880), W(s * 270, -830)], 2.5)])
        moss = c.ellipse(*W(s * 250, -880), 52, 22, s * 0.25)
        c.paint(moss, MOSS, bevel=10, outline=4, ink="#2c4a1c", seed=12 + s, shade=0.3, grain=0.12)
    # Head: a blocky crown with a heavy brow.
    head = smin(c.rbox(*W(0, -1030), 74, 70, 34), c.ellipse(*W(0, -1100), 64, 34), 20)
    c.paint(head, STONE, bevel=40, seed=20, cracks=[([W(40, -1130), W(70, -1070)], 2.5)])
    brow = c.rbox(*W(0, -1048), 70, 14, 10)
    c.paint(brow, STONE_DARK, bevel=10, seed=21)
    for s in (-1, 1):
        c.paint(c.ellipse(*W(s * 62, -1002), 22, 16), "#16171f", bevel=6, outline=3, seed=22 + s)
    c.paint(c.rbox(*W(0, -942), 40, 6, 4), "#1c1d26", bevel=4, outline=2, seed=24)
    moss = c.ellipse(*W(-20, -1150), 66, 20)
    c.paint(moss, MOSS, bevel=10, outline=4, ink="#2c4a1c", seed=25, shade=0.3, grain=0.12)
    c.save("giant_body")
    return {"giant_body": {"origin": (ox, oy), "scale": 0.5}}


def giant_upper_arm():
    # Shoulder at left, elbow at right; length 300 world (150 px), thick.
    c = Canvas(240, 140)
    a, b = (50, 70), (190, 70)
    arm = smin(c.capsule(*a, *b, 46, 38), c.circle(*b, 40), 12)
    c.paint(arm, STONE, bevel=30, seed=31, cracks=[([(90, 52), (120, 66), (110, 88)], 2.2)])
    c.save("giant_upper_arm")
    return {"giant_upper_arm": {"from": a, "to": b, "scale": 0.5}}


def giant_fist_arm():
    # Elbow at left, fist at right; forearm 280 world, fist ~150 world.
    c = Canvas(300, 170)
    a, b = (44, 85), (200, 85)
    fore = c.capsule(*a, *b, 36, 44)
    fist = c.rbox(232, 85, 52, 58, 24)
    knuck = np.minimum.reduce([c.circle(268, 85 + k * 30, 18) for k in (-1.5, -0.5, 0.5, 1.5)])
    c.paint(smin(fore, fist, 16), STONE, bevel=32, seed=41, cracks=[([(110, 66), (140, 80)], 2.0)])
    c.paint(knuck, STONE_DARK, bevel=12, outline=4, seed=42)
    c.save("giant_fist_arm")
    return {"giant_fist_arm": {"from": a, "to": (232, 85), "scale": 0.5}}


# ===================================================== the skeletal beast
BONE = "#efe2c2"
BONE_INK = "#4a3424"


def beast_skull():
    # Facing right. Painted at 0.6 of world size; origin = jaw hinge.
    c = Canvas(620, 330)
    hx, hy = 150, 230
    cran = c.ellipse(170, 150, 120, 100)
    snout = c.capsule(230, 175, 560, 200, 70, 34)
    brow = c.ellipse(250, 110, 100, 34, -0.1)
    skull = smin(smin(cran, snout, 40), brow, 30)
    # Horns sweeping back.
    horn1 = c.capsule(120, 90, 20, 10, 30, 6)
    horn2 = c.capsule(170, 70, 110, -10, 26, 5)
    c.paint(np.minimum(horn1, horn2), "#d9c7a0", bevel=18, ink=BONE_INK, seed=51,
            cracks=[([(90, 60), (60, 40)], 2.0)])
    # Upper teeth (painted before the skull so their roots tuck under it).
    teeth = []
    for k in range(9):
        x = 250 + k * 34
        t = (x - 230) / 330.0
        edge = (175 + 70) * (1 - t) + (200 + 34) * t
        L = 62 if k % 3 == 1 else 46
        teeth.append(c.poly([(x - 15, edge - 14), (x + 15, edge - 14), (x + 2, edge + L - 14)]))
    c.paint(np.minimum.reduce(teeth), "#fff8e8", bevel=6, outline=3, ink=BONE_INK, seed=52, shade=0.25)
    c.paint(skull, BONE, bevel=46, ink=BONE_INK, seed=53, grain=0.07,
            cracks=[([(110, 120), (150, 160), (140, 200)], 2.4), ([(380, 170), (430, 160)], 2.0)])
    # Eye socket, nostril, cheek groove.
    c.paint(c.ellipse(268, 140, 46, 36, -0.15), "#2a1712", bevel=14, outline=4, ink=BONE_INK, seed=54)
    c.paint(c.ellipse(520, 168, 16, 10, -0.3), "#2a1712", bevel=4, outline=3, ink=BONE_INK, seed=55)
    c.save("beast_skull")
    return {"beast_skull": {"hinge": (hx, hy), "eye": (268, 140), "scale": 0.6}}


def beast_jaw():
    c = Canvas(560, 200)
    hx, hy = 40, 90
    jaw = c.capsule(50, 110, 500, 100, 46, 26)
    teeth = []
    for k in range(9):
        x = 150 + k * 36
        L = 58 if k % 3 == 0 else 44
        teeth.append(c.poly([(x - 15, 84), (x + 15, 84), (x, 84 - L)]))
    # Teeth stand above the jaw line: give them room.
    c.paint(np.minimum.reduce(teeth), "#fff8e8", bevel=6, outline=3, ink=BONE_INK, seed=61, shade=0.25)
    c.paint(jaw, BONE, bevel=34, ink=BONE_INK, seed=62, grain=0.07, cracks=[([(220, 120), (260, 136)], 2.0)])
    c.save("beast_jaw")
    return {"beast_jaw": {"hinge": (hx, hy), "scale": 0.6}}


def beast_vertebra():
    c = Canvas(200, 200)
    body = c.rbox(100, 110, 58, 38, 22)
    spine = c.capsule(100, 90, 112, 14, 16, 7)
    wings = np.minimum(c.capsule(56, 110, 18, 128, 14, 6), c.capsule(144, 110, 182, 128, 14, 6))
    c.paint(np.minimum(spine, wings), "#e2d2ae", bevel=12, ink=BONE_INK, seed=71)
    c.paint(body, BONE, bevel=26, ink=BONE_INK, seed=72, cracks=[([(80, 100), (96, 122)], 2.0)])
    c.paint(c.ellipse(100, 112, 14, 10), "#5a4330", bevel=4, outline=2, ink=BONE_INK, seed=73)
    c.save("beast_vertebra")
    return {"beast_vertebra": {"centre": (100, 110), "scale": 0.6}}


def beast_rib():
    # A long curved rib, root at the bottom left, tip at the top right.
    c = Canvas(260, 560)
    pts = [(40, 540)]
    for k in range(1, 13):
        t = k / 12
        pts.append((40 + 190 * np.sin(t * 1.4), 540 - 520 * t))
    d = np.full(c.x.shape, 1e9, np.float32)
    for k, (a, b) in enumerate(zip(pts[:-1], pts[1:])):
        t = k / 12
        d = np.minimum(d, c.capsule(*a, *b, 22 - 12 * t, 22 - 12 * (t + 1 / 12)))
    d = smin(d, c.circle(40, 540, 30), 10)
    c.paint(d, BONE, bevel=18, ink=BONE_INK, seed=81, cracks=[([(110, 330), (126, 300)], 1.8)])
    c.save("beast_rib")
    return {"beast_rib": {"root": (40, 540), "scale": 0.6}}


if __name__ == "__main__":
    pivots = {}
    for f in (giant_body, giant_upper_arm, giant_fist_arm, beast_skull, beast_jaw, beast_vertebra, beast_rib):
        pivots.update(f())
    for k, v in pivots.items():
        print(k, v)
