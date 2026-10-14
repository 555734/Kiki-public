#!/usr/bin/env python3
"""Raster art for stage 1-10 (THE LAST RUN).

Everything here is either a colour-graded / composited derivative of the
painted sets already in assets/ (1-3 wisps, 1-6 desert board, 1-8 boulder,
1-1 panorama ...) or painted procedurally at 4x and downsampled, with the
same thick warm outline, soft top-left light and saturated palette as the
existing split assets. Output goes to assets/stage_1_10/. Run from the repo
root:

    python3 tools/make_finale_assets.py

Pillow and numpy are required. The output is deterministic (fixed seeds).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "stage_1_10")
SS = 4  # supersampling factor for procedural shapes

OUTLINE = (58, 32, 24, 255)


def src(path):
    return Image.open(os.path.join(ROOT, path)).convert("RGBA")


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name), optimize=True)
    print("wrote", name, img.size)


def rng(seed):
    return np.random.default_rng(seed)


# ------------------------------------------------------------------ helpers

def arr(img):
    return np.asarray(img).astype(np.float32) / 255.0


def to_img(a):
    return Image.fromarray(np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8))


def blur_mask(mask, radius):
    return np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(radius))).astype(np.float32) / 255.0


def value_noise(w, h, scale, seed, octaves=4):
    """Smooth tileable-ish fractal noise in 0..1."""
    r = rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cells = max(2, int(scale * (2 ** o)))
        grid = r.random((cells + 1, cells + 1)).astype(np.float32)
        grid[-1, :] = grid[0, :]
        grid[:, -1] = grid[:, 0]
        layer = np.asarray(Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (w, h), Image.BICUBIC)).astype(np.float32) / 255.0
        out += layer * amp
        total += amp
        amp *= 0.5
    return out / total


def shade_shape(mask, base, light=(1.0, 0.96, 0.85), dark=(0.35, 0.22, 0.2),
                rim=6, outline=5, outline_col=OUTLINE, texture=None, gloss=0.0):
    """Paint a filled mask (HxW float 0..1) like the split assets: soft bevel,
    top-left light, darker lower edge, warm outline. Returns RGBA image."""
    h, w = mask.shape
    col = np.zeros((h, w, 3), np.float32)
    col[:] = np.array(base, np.float32) / 255.0
    if texture is not None:
        col = col * (0.75 + 0.5 * texture[..., None])
    soft = blur_mask(mask, rim)
    # Light from the upper left: compare with a shifted copy.
    shifted = np.roll(np.roll(soft, rim, axis=0), rim, axis=1)
    hi = np.clip(soft - shifted, 0, 1)
    lo = np.clip(shifted - soft, 0, 1)
    edge = np.clip(1.0 - soft, 0, 1) * mask
    col = col + hi[..., None] * (np.array(light) - col) * 0.9
    col = col + lo[..., None] * (np.array(dark) - col) * 0.8
    col = col * (1.0 - edge[..., None] * 0.35)
    # Gentle vertical gradient: tops catch light.
    ys = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    col = col * (1.08 - ys * 0.18)
    if gloss > 0:
        g = np.clip(hi * 3.0, 0, 1) * gloss
        col = col + g[..., None] * (1 - col)
    alpha = mask.copy()
    if outline > 0:
        grown = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(
            ImageFilter.MaxFilter(outline * 2 + 1))).astype(np.float32) / 255.0
        ring = np.clip(grown - mask, 0, 1)
        oc = np.array(outline_col[:3], np.float32) / 255.0
        col = col * (1 - ring[..., None]) + oc * ring[..., None]
        alpha = np.maximum(alpha, ring)
    rgba = np.dstack([np.clip(col, 0, 1), alpha])
    return to_img(rgba)


def downsample(img, factor=SS):
    return img.resize((img.width // factor, img.height // factor), Image.LANCZOS)


def mask_from_draw(size, draw_fn):
    m = Image.new("L", size, 0)
    draw_fn(ImageDraw.Draw(m))
    return np.asarray(m).astype(np.float32) / 255.0


def recolor(img, matrix, add=(0, 0, 0)):
    """3x3 colour matrix on RGB, alpha kept."""
    a = arr(img)
    rgb = a[..., :3] @ np.array(matrix, np.float32).T + np.array(add, np.float32)
    return to_img(np.dstack([np.clip(rgb, 0, 1), a[..., 3]]))


def hue_map(img, ramp):
    """Map luminance through a colour ramp [(t, (r,g,b)), ...]; keep alpha."""
    a = arr(img)
    lum = a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11
    ts = np.array([t for t, _ in ramp], np.float32)
    cs = np.array([c for _, c in ramp], np.float32) / 255.0
    out = np.zeros(a.shape[:2] + (3,), np.float32)
    for ch in range(3):
        out[..., ch] = np.interp(lum, ts, cs[:, ch])
    return to_img(np.dstack([out, a[..., 3]]))


# --------------------------------------------------------------- textures

def honeycomb_tile_v2(seed=3):
    """Tileable wax comb (pointy-top hexes): 4 columns x 2 row pairs."""
    r = 37.0
    hw = math.sqrt(3) * r
    W, H = int(round(4 * hw)), int(round(6 * r))
    S = 3
    yy, xx = np.mgrid[0:H * S, 0:W * S].astype(np.float32) / S
    best = np.full(xx.shape, 1e9, np.float32)
    second = np.full(xx.shape, 1e9, np.float32)
    val = np.zeros(xx.shape, np.float32)
    rr = rng(seed)
    for row in range(-1, 6):
        for col in range(-1, 6):
            cx = col * hw + (hw / 2 if row % 2 else 0)
            cy = row * 1.5 * r
            v = rr.random()
            for ox in (-W, 0, W):
                for oy in (-H, 0, H):
                    dd = np.hypot(xx - cx - ox, yy - cy - oy)
                    closer = dd < best
                    second = np.where(closer, best, np.minimum(second, dd))
                    val = np.where(closer, v, val)
                    best = np.where(closer, dd, best)
    wall = np.clip(1 - (second - best) / 7.0, 0, 1)
    depth = np.clip(best / (r * 0.9), 0, 1)
    deep = np.array([0.72, 0.36, 0.04])
    bright = np.array([1.0, 0.74, 0.20])
    cell = deep * (1 - depth[..., None]) + bright * depth[..., None]
    cell = cell * (0.9 + 0.2 * val[..., None])
    rim = np.array([1.0, 0.90, 0.58])
    edge_dark = np.clip(1 - (second - best) / 14.0, 0, 1) * (1 - wall)
    col = cell * (1 - wall[..., None]) + rim * wall[..., None]
    col = col * (1 - edge_dark[..., None] * 0.25)
    img = to_img(np.clip(col, 0, 1)).resize((W, H), Image.LANCZOS)
    return img


def honey_cap(w=256, h=64, seed=6):
    """Honey poured over a ledge: glossy band with drips, tileable in x."""
    S = 4
    img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    band = int(h * S * 0.42)
    d.rectangle([0, 0, w * S, band], fill=(244, 160, 22, 255))
    rr = rng(seed)
    x = 0
    while x < w * S:
        dw = int((10 + rr.random() * 14) * S)
        dl = int((8 + rr.random() * 22) * S)
        if x + dw < w * S - 4 * S:
            d.rounded_rectangle([x, band - 4 * S, x + dw, band + dl], radius=dw // 2, fill=(244, 160, 22, 255))
        x += dw + int((6 + rr.random() * 18) * S)
    a = arr(img)
    m = a[..., 3]
    img = shade_shape(m, (244, 160, 22), light=(1.0, 0.95, 0.6), dark=(0.55, 0.25, 0.02),
                      rim=3 * S, outline=int(1.5 * S), outline_col=(120, 58, 8, 255), gloss=0.6)
    d = ImageDraw.Draw(img)
    d.line([(0, 3 * S), (w * S, 3 * S)], fill=(255, 240, 170, 255), width=3 * S)
    return downsample(img, S)


def honeycomb_tile(size=256, cell=32, seed=3):
    """Tileable wax comb texture used for hive terrain bodies."""
    S = size * 2
    img = np.zeros((S, S, 3), np.float32)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    r = cell * 2
    # Hex grid distance field (pointy-top), tileable because S is a multiple.
    w = math.sqrt(3) * r
    hgt = 1.5 * r
    q = (xx / w)
    rr = (yy / hgt)
    best = np.full((S, S), 1e9, np.float32)
    cx_best = np.zeros((S, S), np.float32)
    for dy in range(-1, int(S / hgt) + 2):
        for dx in range(-1, int(S / w) + 2):
            cx = dx * w + (w / 2 if dy % 2 else 0)
            cy = dy * hgt
            d = np.hypot(xx - cx, yy - cy)
            closer = d < best
            best = np.where(closer, d, best)
            cx_best = np.where(closer, (cx * 7 + cy * 13) % 1.0, cx_best)
    # Approximate hex edge from second-nearest via Voronoi distance (cheap):
    edge = np.clip((best / (r * 0.95)), 0, 1) ** 3
    noise = value_noise(S, S, 6, seed)
    base = np.array([0.98, 0.70, 0.18])
    deep = np.array([0.80, 0.42, 0.06])
    wall = np.array([0.99, 0.86, 0.45])
    t = np.clip(best / r, 0, 1)[..., None]
    img = deep * (1 - t) + base * t
    img = img * (0.85 + 0.3 * noise[..., None])
    img = img * (1 - edge[..., None]) + wall * edge[..., None]
    # Glossy highlight in the upper-left of each cell.
    img = np.clip(img, 0, 1)
    out = to_img(img).resize((size, size), Image.LANCZOS)
    return out


def bone_tile(size=256, seed=11):
    S = size
    n1 = value_noise(S, S, 4, seed, 5)
    n2 = value_noise(S, S, 16, seed + 1, 3)
    base = np.array([0.93, 0.87, 0.74])
    warm = np.array([0.82, 0.70, 0.52])
    col = base * (1 - n1[..., None] * 0.6) + warm * n1[..., None] * 0.6
    # Fine porous dots and hairline cracks.
    pores = (n2 > 0.72).astype(np.float32)
    col = col * (1 - pores[..., None] * 0.18)
    r = rng(seed)
    img = to_img(np.clip(col, 0, 1)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for _ in range(14):
        x, y = r.random() * S, r.random() * S
        pts = [(x, y)]
        for _k in range(5):
            x += (r.random() - 0.5) * 40
            y += (r.random() - 0.3) * 30
            pts.append((x % S, y % S))
        for a, b in zip(pts, pts[1:]):
            if abs(a[0] - b[0]) < S / 2 and abs(a[1] - b[1]) < S / 2:
                d.line([a, b], fill=(150, 120, 90, 160), width=2)
    return img


def sandstream_tile(w=96, h=512, seed=21):
    n = value_noise(w, h, 3, seed, 5)
    yy = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    xx = np.linspace(-1, 1, w, dtype=np.float32)[None, :]
    streak = value_noise(w, h // 8, 12, seed + 4, 2)
    streak = np.asarray(Image.fromarray((streak * 255).astype(np.uint8)).resize((w, h))).astype(np.float32) / 255
    body = np.clip(1 - np.abs(xx) ** 2.2, 0, 1)
    col = np.dstack([0.98 - 0.18 * n, 0.83 - 0.2 * n, 0.52 - 0.22 * n])
    col = col * (0.8 + 0.35 * streak[..., None])
    alpha = body * (0.65 + 0.35 * streak)
    return to_img(np.dstack([np.clip(col, 0, 1), alpha]))


# ----------------------------------------------------------------- sprites

def magma_ball(size=360, seed=5):
    S = size * SS
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    c = S / 2
    rad = S * 0.45
    d = np.hypot(xx - c, yy - c) / rad
    mask = (d < 1).astype(np.float32)
    # Voronoi plates: glowing cracks where the nearest two seeds are close.
    r = rng(seed)
    pts = r.random((34, 2)) * S
    d1 = np.full((S, S), 1e9, np.float32)
    d2 = np.full((S, S), 1e9, np.float32)
    for px, py in pts:
        dd = np.hypot(xx - px, yy - py)
        d2 = np.where(dd < d1, d1, np.minimum(d2, dd))
        d1 = np.minimum(d1, dd)
    crack = np.clip(1 - (d2 - d1) / (S * 0.018), 0, 1)
    # Sphere lighting.
    nz = np.sqrt(np.clip(1 - d ** 2, 0, 1))
    nx = (xx - c) / rad
    ny = (yy - c) / rad
    light = np.clip(-nx * 0.45 - ny * 0.6 + nz * 0.7, 0, 1)
    rock = np.array([0.25, 0.14, 0.14]) + np.array([0.33, 0.2, 0.17]) * light[..., None]
    noise = value_noise(S // 4, S // 4, 8, seed, 4)
    noise = np.asarray(Image.fromarray((noise * 255).astype(np.uint8)).resize((S, S))).astype(np.float32) / 255
    rock = rock * (0.8 + 0.4 * noise[..., None])
    lava = np.array([1.0, 0.55, 0.08]) * (1 - crack[..., None] * 0) + np.array([0, 0.35, 0.3]) * crack[..., None] ** 3
    col = rock * (1 - crack[..., None]) + lava * crack[..., None]
    # Hot glowing underside.
    under = np.clip((ny + 0.2) * 1.2, 0, 1) * mask
    col = col + np.array([0.6, 0.18, 0.0]) * under[..., None] * 0.35
    rim = np.clip((d - 0.86) / 0.14, 0, 1) * mask
    col = col * (1 - rim[..., None] * 0.25) + np.array([1.0, 0.45, 0.05]) * rim[..., None] * 0.25
    alpha = mask
    ring = np.clip((d - 1.0) / 0.035, 0, 1) * (d < 1.035)
    oc = np.array([0.22, 0.08, 0.06])
    col = col * (1 - ring[..., None]) + oc * ring[..., None]
    alpha = np.maximum(alpha, ring)
    # Outer glow halo.
    halo = np.clip(1 - (d - 1.03) / 0.10, 0, 1) * (d >= 1.035) * 0.55
    col = np.where((halo > 0)[..., None], np.array([1.0, 0.5, 0.1]), col)
    alpha = np.maximum(alpha, halo)
    return downsample(to_img(np.dstack([np.clip(col, 0, 1), alpha])))


def skull(size=256, brass=False):
    S = size * SS

    def draw(d):
        d.ellipse([S * 0.16, S * 0.10, S * 0.84, S * 0.70], fill=255)
        d.rounded_rectangle([S * 0.28, S * 0.50, S * 0.72, S * 0.86], radius=S * 0.08, fill=255)
    mask = mask_from_draw((S, S), draw)
    base = (214, 164, 72) if brass else (240, 230, 206)
    img = shade_shape(mask, base, rim=S * 0.03, outline=int(S * 0.022),
                      outline_col=(60, 38, 30, 255),
                      texture=value_noise(S, S, 5, 9 if brass else 4, 3))
    d = ImageDraw.Draw(img)
    eye = (40, 20, 24, 255)
    for ex in (0.36, 0.64):
        d.ellipse([S * (ex - 0.11), S * 0.34, S * (ex + 0.11), S * 0.56], fill=eye)
        d.ellipse([S * (ex - 0.05), S * 0.40, S * (ex + 0.05), S * 0.50], fill=(255, 70, 50, 255))
        d.ellipse([S * (ex - 0.02), S * 0.415, S * (ex + 0.015), S * 0.445], fill=(255, 230, 200, 255))
    d.polygon([(S * 0.5, S * 0.56), (S * 0.45, S * 0.66), (S * 0.55, S * 0.66)], fill=eye)
    for i in range(5):
        x = S * (0.33 + i * 0.085)
        d.rounded_rectangle([x, S * 0.70, x + S * 0.065, S * 0.82], radius=S * 0.015,
                            fill=(255, 250, 238, 255), outline=(70, 45, 35, 255), width=int(S * 0.008))
    # Rotor hub on top (blades are drawn spinning at runtime).
    d.rounded_rectangle([S * 0.44, S * 0.02, S * 0.56, S * 0.13], radius=S * 0.02,
                        fill=(90, 96, 110, 255), outline=(40, 30, 30, 255), width=int(S * 0.01))
    return downsample(img)


def bubble(size=256):
    S = size * SS
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    c = S / 2
    d = np.hypot(xx - c, yy - c) / (S * 0.46)
    mask = d < 1
    body = np.array([1.0, 0.72, 0.12])
    edge = np.clip((d - 0.55) / 0.45, 0, 1) ** 1.5
    col = np.array([1.0, 0.86, 0.35]) * (1 - edge[..., None]) + np.array([0.86, 0.45, 0.04]) * edge[..., None]
    alpha = np.where(mask, 0.55 + 0.4 * edge, 0)
    hl = np.exp(-(((xx - S * 0.37) / (S * 0.09)) ** 2 + ((yy - S * 0.32) / (S * 0.06)) ** 2))
    col = col + hl[..., None] * (1 - col)
    alpha = np.maximum(alpha, hl * mask)
    ring = (d >= 0.97) & (d < 1.02)
    col[ring] = np.array([0.55, 0.26, 0.04])
    alpha = np.where(ring, 1.0, alpha)
    return downsample(to_img(np.dstack([np.clip(col, 0, 1), alpha])))


def saw(size=256):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    c = S / 2
    teeth = 18
    pts = []
    for i in range(teeth * 2):
        a = i * math.pi / teeth
        rr = S * (0.47 if i % 2 == 0 else 0.38)
        a2 = a + (0.12 if i % 2 == 0 else 0)
        pts.append((c + math.cos(a2) * rr, c + math.sin(a2) * rr))
    mask = mask_from_draw((S, S), lambda d: d.polygon(pts, fill=255))
    img = shade_shape(mask, (196, 204, 214), light=(1, 1, 1), dark=(0.3, 0.32, 0.38),
                      rim=S * 0.02, outline=int(S * 0.012), outline_col=(40, 42, 54, 255),
                      texture=value_noise(S, S, 3, 17, 2), gloss=0.5)
    d = ImageDraw.Draw(img)
    for k, rr in enumerate([0.28, 0.20]):
        d.ellipse([c - S * rr, c - S * rr, c + S * rr, c + S * rr],
                  outline=(120, 126, 140, 255), width=int(S * 0.01))
    d.ellipse([c - S * 0.09, c - S * 0.09, c + S * 0.09, c + S * 0.09], fill=(232, 90, 60, 255),
              outline=(60, 30, 30, 255), width=int(S * 0.012))
    for i in range(4):
        a = i * math.pi / 2 + 0.4
        x, y = c + math.cos(a) * S * 0.18, c + math.sin(a) * S * 0.18
        d.ellipse([x - S * 0.025, y - S * 0.025, x + S * 0.025, y + S * 0.025], fill=(80, 84, 98, 255))
    return downsample(img)


def _panel_box(d, box, fill, outline, radius, width):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def train_car(kind, w=360, h=190):
    """Side view railway carriages: 'loco', 'blue', 'red', 'flat'."""
    W, H = w * SS, h * SS
    body_col = {"loco": (52, 82, 150), "blue": (58, 110, 190), "red": (196, 62, 52), "flat": (120, 86, 60)}[kind]
    roof_top = 0.10 if kind != "flat" else 0.56
    def body(d):
        if kind == "flat":
            d.rounded_rectangle([W * 0.02, H * 0.56, W * 0.98, H * 0.78], radius=W * 0.01, fill=255)
        else:
            d.rounded_rectangle([W * 0.02, H * roof_top, W * 0.98, H * 0.80], radius=W * 0.03, fill=255)
            if kind == "loco":
                d.rounded_rectangle([W * 0.62, H * 0.0, W * 0.80, H * 0.2], radius=W * 0.02, fill=255)
    mask = mask_from_draw((W, H), body)
    tex = value_noise(W, H, 4, 31, 3)
    img = shade_shape(mask, body_col, rim=W * 0.008, outline=int(W * 0.006),
                      outline_col=(30, 26, 40, 255), texture=tex)
    d = ImageDraw.Draw(img)
    lw = int(W * 0.004)
    if kind != "flat":
        # Roof trim (the standing surface is the very top line).
        d.rounded_rectangle([W * 0.015, H * roof_top - H * 0.02, W * 0.985, H * (roof_top + 0.07)],
                            radius=W * 0.01, fill=(70, 72, 88, 255), outline=(30, 26, 40, 255), width=lw)
        d.rectangle([W * 0.03, H * (roof_top + 0.01), W * 0.97, H * (roof_top + 0.03)], fill=(150, 156, 176, 255))
        # Windows.
        n = 3 if kind == "loco" else 4
        x0 = W * (0.08 if kind != "loco" else 0.10)
        span = W * (0.84 if kind != "loco" else 0.45)
        ww = span / n * 0.7
        for i in range(n):
            x = x0 + i * span / n
            _panel_box(d, [x, H * 0.28, x + ww, H * 0.48], (255, 236, 170, 255), (30, 26, 40, 255), W * 0.008, lw)
            d.rectangle([x + ww * 0.08, H * 0.30, x + ww * 0.3, H * 0.46], fill=(255, 255, 230, 255))
        d.rectangle([W * 0.02, H * 0.56, W * 0.98, H * 0.60], fill=(240, 196, 70, 255))
        for i in range(14):
            x = W * (0.05 + i * 0.065)
            d.ellipse([x, H * 0.66, x + W * 0.012, H * 0.66 + W * 0.012], fill=(30, 30, 40, 200))
        if kind == "loco":
            d.rounded_rectangle([W * 0.86, H * 0.25, W * 0.99, H * 0.62], radius=W * 0.02,
                                fill=(40, 46, 60, 255), outline=(20, 18, 28, 255), width=lw)
            d.ellipse([W * 0.90, H * 0.34, W * 0.97, H * 0.47], fill=(255, 240, 160, 255))
    else:
        for i in range(8):
            x = W * (0.05 + i * 0.115)
            d.rectangle([x, H * 0.58, x + W * 0.07, H * 0.62], fill=(160, 120, 80, 255))
    # Chassis and wheels.
    d.rectangle([W * 0.04, H * 0.78, W * 0.96, H * 0.84], fill=(38, 34, 44, 255))
    for wx in (0.14, 0.30, 0.70, 0.86):
        cx, cy, rr = W * wx, H * 0.86, H * 0.11
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(46, 46, 56, 255), outline=(20, 18, 24, 255), width=lw)
        d.ellipse([cx - rr * 0.45, cy - rr * 0.45, cx + rr * 0.45, cy + rr * 0.45], fill=(170, 174, 186, 255))
    return downsample(img)


def crane(w=300, h=420):
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    yel, dark = (246, 186, 40, 255), (70, 44, 20, 255)
    lw = int(W * 0.012)
    # Vertical mast with lattice.
    d.rectangle([W * 0.06, H * 0.06, W * 0.18, H], fill=yel, outline=dark, width=lw)
    for i in range(12):
        y = H * (0.08 + i * 0.075)
        d.line([W * 0.06, y, W * 0.18, y + H * 0.075], fill=dark, width=lw)
    # Jib.
    d.rectangle([W * 0.06, H * 0.04, W * 0.98, H * 0.12], fill=yel, outline=dark, width=lw)
    for i in range(10):
        x = W * (0.18 + i * 0.08)
        d.line([x, H * 0.04, x + W * 0.08, H * 0.12], fill=dark, width=lw)
    d.rectangle([W * 0.0, H * 0.0, W * 0.24, H * 0.05], fill=(200, 70, 50, 255), outline=dark, width=lw)
    # Operator cab.
    d.rounded_rectangle([W * 0.18, H * 0.12, W * 0.36, H * 0.22], radius=W * 0.02, fill=(80, 120, 190, 255),
                        outline=dark, width=lw)
    d.rectangle([W * 0.21, H * 0.14, W * 0.33, H * 0.18], fill=(220, 240, 255, 255))
    return downsample(img)


# ------------------------------------------------------------ backgrounds

def storm_background():
    """1-6 ruin board graded to a thunderstorm, with rolling cloud bands."""
    board = src("assets/split/1-6/background/background.png")
    w, h = board.size
    graded = hue_map(board, [(0.0, (8, 14, 34)), (0.35, (30, 52, 96)),
                             (0.65, (78, 112, 160)), (0.9, (160, 190, 220)), (1.0, (220, 236, 250))])
    a = arr(graded)
    clouds = value_noise(w, h, 3, 77, 5)
    band = np.clip(1.15 - np.linspace(0, 1, h)[:, None] * 1.6, 0, 1)
    c = np.clip((clouds - 0.42) * 2.6, 0, 1) * band
    cloud_col = np.array([0.20, 0.25, 0.38])
    rgb = a[..., :3] * (1 - c[..., None] * 0.85) + cloud_col * c[..., None] * 0.85
    rgb = rgb * 0.9
    return to_img(np.dstack([rgb, np.ones((h, w), np.float32)]))


def hive_background(w=1600, h=900, seed=8):
    S = 2
    W, H = w * S, h * S
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    r = 46.0 * S
    hw = math.sqrt(3) * r
    hh = 1.5 * r
    best = np.full((H, W), 1e9, np.float32)
    second = np.full((H, W), 1e9, np.float32)
    seed_val = np.zeros((H, W), np.float32)
    rr = rng(seed)
    for row in range(-1, int(H / hh) + 2):
        for col in range(-1, int(W / hw) + 2):
            cx = col * hw + (hw / 2 if row % 2 else 0)
            cy = row * hh
            dd = np.hypot(xx - cx, yy - cy)
            v = rr.random()
            closer = dd < best
            second = np.where(closer, best, np.minimum(second, dd))
            seed_val = np.where(closer, v, seed_val)
            best = np.where(closer, dd, best)
    wall = np.clip(1 - (second - best) / (r * 0.22), 0, 1)
    depth = np.clip(best / (r * 0.95), 0, 1)
    deep = np.array([0.55, 0.22, 0.03])
    bright = np.array([1.0, 0.70, 0.16])
    glow = (seed_val > 0.82).astype(np.float32)
    cell = deep * (1 - depth[..., None]) + bright * depth[..., None]
    cell = cell + glow[..., None] * np.array([0.35, 0.25, 0.05]) * (1 - depth[..., None])
    wax = np.array([1.0, 0.86, 0.48])
    col = cell * (1 - wall[..., None]) + wax * wall[..., None]
    # Atmospheric fade: centre lighter, edges darker, plus light shafts.
    vign = np.clip(1.15 - np.hypot((xx - W / 2) / W, (yy - H * 0.4) / H) * 1.3, 0.55, 1.1)
    col = col * vign[..., None]
    shafts = np.clip(np.sin((xx * 0.6 + yy * 0.35) / (W * 0.05)) * 0.5 + 0.5, 0, 1) ** 6 * 0.12
    col = col + shafts[..., None]
    col = col * 0.82 + np.array([0.18, 0.10, 0.0]) * 0.18
    img = to_img(np.clip(col, 0, 1)).resize((w, h), Image.LANCZOS)
    # Honey drips from the top edge.
    d = ImageDraw.Draw(img)
    for i in range(26):
        x = rr.random() * w
        ln = 40 + rr.random() * 160
        wdt = 10 + rr.random() * 18
        d.rounded_rectangle([x - wdt / 2, -10, x + wdt / 2, ln], radius=wdt / 2, fill=(255, 176, 30))
        d.ellipse([x - wdt * 0.8, ln - wdt, x + wdt * 0.8, ln + wdt * 0.6], fill=(255, 176, 30))
        d.line([x - wdt * 0.2, 0, x - wdt * 0.2, ln - 6], fill=(255, 236, 150), width=3)
    return img.filter(ImageFilter.GaussianBlur(1.2))


def rib_layer(w=1600, h=900, seed=12, bone=(236, 226, 200)):
    """Distant giant fossil ribs for the canyon parallax (transparent)."""
    W, H = w * 2, h * 2
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(seed)
    for k in range(6):
        x0 = W * (0.05 + k * 0.17) + r.random() * 80
        top = H * (0.10 + r.random() * 0.15)
        width = W * (0.08 + r.random() * 0.05)
        thick = 34 + r.random() * 20
        m = Image.new("L", (W, H), 0)
        md = ImageDraw.Draw(m)
        pts = []
        for i in range(40):
            t = i / 39
            x = x0 + math.sin(t * math.pi * 0.9) * width
            y = top + t * (H - top) * 1.05
            pts.append((x, y))
        md.line(pts, fill=255, width=int(thick), joint="curve")
        md.ellipse([pts[0][0] - thick * 0.8, pts[0][1] - thick * 0.8, pts[0][0] + thick * 0.8, pts[0][1] + thick * 0.8], fill=255)
        mask = np.asarray(m).astype(np.float32) / 255
        rib = shade_shape(mask, bone, rim=10, outline=5, outline_col=(110, 88, 70, 255),
                          texture=value_noise(W, H, 6, seed + k, 3))
        img.alpha_composite(rib)
    return img.resize((w, h), Image.LANCZOS)


def canyon_background():
    board = src("assets/split/1-6/background/background.png")
    w, h = board.size
    warm = recolor(board, [[1.05, 0.05, 0.0], [0.02, 0.92, 0.0], [0.0, 0.05, 0.85]], (0.02, 0.0, -0.02))
    ribs = rib_layer(w, h, 12, (226, 214, 188))
    a = arr(ribs)
    a[..., 3] *= 0.75
    warm.alpha_composite(to_img(a))
    return warm


def wisp(path, ramp, flip=False):
    img = hue_map(src(path), ramp)
    return img.transpose(Image.FLIP_LEFT_RIGHT) if flip else img


def main():
    os.makedirs(OUT, exist_ok=True)
    save(honeycomb_tile_v2(), "wax_tile.png")
    save(honey_cap(), "honey_cap.png")
    save(bone_tile(), "bone_tile.png")
    save(sandstream_tile(), "sand_stream.png")
    save(magma_ball(), "magma_ball.png")
    save(skull(), "skull_drone.png")
    save(skull(brass=True), "brass_drone.png")
    save(bubble(), "honey_bubble.png")
    save(saw(), "saw_blade.png")
    for kind in ("loco", "blue", "red", "flat"):
        save(train_car(kind), "train_%s.png" % kind)
    save(crane(), "crane.png")
    save(storm_background(), "storm_background.png")
    save(hive_background(), "hive_background.png")
    save(canyon_background(), "canyon_background.png")
    save(rib_layer(1400, 800, 41), "rib_layer.png")
    honey = [(0.0, (90, 40, 0)), (0.4, (214, 120, 10)), (0.75, (255, 196, 60)), (1.0, (255, 246, 200))]
    volt = [(0.0, (8, 16, 60)), (0.35, (30, 90, 220)), (0.62, (60, 190, 255)), (0.85, (150, 240, 255)), (1.0, (255, 250, 150))]
    save(wisp("assets/split/1-3/enemies/wisp_idle.png", honey), "wax_wisp_idle.png")
    save(wisp("assets/split/1-3/enemies/wisp_attack.png", honey), "wax_wisp_attack.png")
    save(wisp("assets/split/1-3/enemies/wisp_idle.png", volt), "spark_idle.png")
    save(wisp("assets/split/1-3/enemies/wisp_attack.png", volt), "spark_attack.png")


if __name__ == "__main__":
    sys.exit(main())
