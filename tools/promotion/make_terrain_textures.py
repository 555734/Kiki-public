#!/usr/bin/env python3
"""Seamless painted terrain textures for 1-10 (assets/stage_1_10/tex_*.png).

    python3 tools/promotion/make_terrain_textures.py

The 1-10 ground used to be the earlier stages' square tiles stretched over
rectangles. These are faceted rock faces in the style of the 1-3 cliff
paintings (cliff_a/cliff_b: flat, lit facets with dark crevices), one per
material, plus a honeycomb and a fossil-bone rock. All of them tile on both
axes (toroidal Voronoi), so FinaleArt can map them over any outline by UV.

Each texture: facets from a toroidal Voronoi diagram, each facet lit from
the upper left through its own random normal, a soft gradient inside the
facet, dark crevices where two facets meet, fine grain, and material extras
(lava veins, embedded bones, strata).
"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "stage_1_10")
N = 512
LIGHT = np.array([-0.55, -0.65, 0.52])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def torus_voronoi(points, n=N):
    """Nearest and second-nearest distances and the nearest index, wrapping."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d1 = np.full((n, n), 1e9, np.float32)
    d2 = np.full((n, n), 1e9, np.float32)
    idx = np.zeros((n, n), np.int32)
    vx = np.zeros((n, n), np.float32)
    vy = np.zeros((n, n), np.float32)
    for i, (px, py) in enumerate(points):
        dx = xx - px
        dy = yy - py
        dx = dx - n * np.round(dx / n)
        dy = dy - n * np.round(dy / n)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        d1 = np.where(closer, d, d1)
        idx = np.where(closer, i, idx)
        vx = np.where(closer, dx, vx)
        vy = np.where(closer, dy, vy)
    return d1, d2, idx, vx, vy


def tile_noise(rng, n=N, octaves=5):
    """Seamless value noise in [0, 1] (sums of wrapped, upsampled grids)."""
    out = np.zeros((n, n), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        g = 4 * 2 ** o
        grid = rng.random((g, g)).astype(np.float32)
        img = Image.fromarray((grid * 255).astype(np.uint8))
        # Wrap by tiling 3x3 then cropping the centre after a smooth resize.
        big = Image.new("L", (g * 3, g * 3))
        for i in range(3):
            for j in range(3):
                big.paste(img, (i * g, j * g))
        big = big.resize((n * 3, n * 3), Image.BICUBIC)
        layer = np.asarray(big, np.float32)[n:2 * n, n:2 * n] / 255.0
        out += layer * amp
        total += amp
        amp *= 0.5
    return out / total


def blur_wrap(a, radius):
    """Gaussian blur that wraps at the edges (keeps the tile seamless)."""
    f = np.fft.fftfreq(N)
    g = np.exp(-2 * (np.pi * radius) ** 2 * (f[:, None] ** 2 + f[None, :] ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g)).astype(np.float32)


def faceted(seed, cells, palette, crevice=(0.18, 3.2), facet_light=0.38, grain=0.06, stretch=(1.0, 1.0)):
    rng = np.random.default_rng(seed)
    pts = rng.random((cells, 2)) * N
    d1, d2, idx, vx, vy = torus_voronoi(pts)
    # Per-facet normal, tilted mostly up/left so faces read as lit rock.
    nrm = rng.normal(0, 1, (cells, 3)) * np.array([0.55, 0.55, 0.25]) + np.array([0, 0, 1.0])
    nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
    lit = np.clip(nrm @ LIGHT, 0, 1)
    base_pick = rng.integers(0, len(palette), cells)
    jitter = rng.normal(0, 0.012, (cells, 1))
    cols = np.array([hexc(palette[i]) for i in base_pick]) + jitter
    shade = (1.0 - facet_light) + facet_light * lit
    rgb = cols[idx] * shade[idx][..., None]
    # Gradient inside each facet toward its lit side.
    g = np.clip(-(vx * LIGHT[0] + vy * LIGHT[1]) / 40.0, -1, 1) * 0.06
    rgb += g[..., None]
    # Crevices where facets meet.
    edge = np.clip((d2 - d1) / crevice[1], 0, 1)
    rgb *= (1.0 - crevice[0] * (1.0 - edge) ** 2)[..., None]
    # Highlight just inside the upper-left edge of each facet.
    hl = np.clip(1.0 - (d2 - d1) / 2.0, 0, 1) * np.clip(-(vx * 0.7 + vy * 0.7) / 20.0, 0, 1)
    rgb += (hl * 0.10)[..., None]
    n = tile_noise(rng, octaves=6)
    rgb *= (1.0 - grain + 2 * grain * n)[..., None]
    # Large soft light/dark patches, as a painter would wash over the facets.
    wash = tile_noise(rng, octaves=2)
    rgb *= (0.88 + 0.24 * wash)[..., None]
    return np.clip(rgb, 0, 1), rng, idx, d1


def save(name, rgb, alpha=None):
    os.makedirs(OUT, exist_ok=True)
    a = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)
    if alpha is not None:
        a = np.dstack([a, (np.clip(alpha, 0, 1) * 255).astype(np.uint8)])
    Image.fromarray(a).save(os.path.join(OUT, name + ".png"), optimize=True)
    print("wrote", name)


def strata(rgb, rng, bands, amount):
    """Wavy sedimentary bands across the tile (periodic in x and y)."""
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    wav = np.sin(xx / N * 2 * np.pi * 2 + rng.random() * 6) * 6 + np.sin(xx / N * 2 * np.pi * 5) * 3
    phase = (yy + wav) / N * bands
    band = 0.5 + 0.5 * np.sin(phase * 2 * np.pi)
    return rgb * (1.0 - amount + amount * (0.6 + 0.4 * band))[..., None]


def earth():
    # Warm earth cliff under the meadow grass (matches the 1-1 dirt hue).
    rgb, rng, idx, d1 = faceted(11, 42, ["c9773b", "c27237", "cf7f42", "bd6f37"], crevice=(0.32, 3.0))
    rgb = strata(rgb, rng, 4, 0.18)
    save("tex_earth", rgb)


def sandstone():
    rgb, rng, idx, d1 = faceted(23, 36, ["e0a96a", "dba264", "e6b076", "d69c5e"], crevice=(0.30, 2.6), facet_light=0.32)
    rgb = strata(rgb, rng, 6, 0.30)
    save("tex_sandstone", rgb)


def basalt():
    rgb, rng, idx, d1 = faceted(37, 48, ["4b2f36", "3d2730", "5a3540", "352129"], crevice=(0.45, 3.4), facet_light=0.42)
    # Lava veins: thin glowing lines along some facet borders.
    pts = rng.random((26, 2)) * N
    e1, e2, _, _, _ = torus_voronoi(pts)
    vein = np.clip(1.0 - (e2 - e1) / 2.2, 0, 1) ** 2
    glow = blur_wrap(vein, 4) * 1.6
    hot = hexc("ff7a1a")
    rgb = rgb * (1 - vein[..., None] * 0.9) + hot * vein[..., None] * 0.95 + hexc("ff4a10") * glow[..., None] * 0.35
    save("tex_basalt", rgb)


def slate():
    # Wet storm stone, blue-grey.
    rgb, rng, idx, d1 = faceted(41, 40, ["55627e", "4a5672", "616f8c", "414b63"], crevice=(0.40, 3.0))
    save("tex_slate", rgb)


def mesa():
    # Red-orange canyon rock for the giant's cliffs.
    rgb, rng, idx, d1 = faceted(53, 38, ["c46a3c", "bd6338", "cc7344", "b85e35"], crevice=(0.36, 3.0))
    rgb = strata(rgb, rng, 5, 0.22)
    save("tex_mesa", rgb)


def giant_stone():
    # The stone giant's body: cool grey-blue blocks, mossy.
    rgb, rng, idx, d1 = faceted(67, 34, ["8d97a8", "7d8798", "9aa4b4", "6f7a8c"], crevice=(0.5, 3.6), facet_light=0.42)
    n = tile_noise(rng, octaves=4)
    moss = np.clip((n - 0.62) * 5, 0, 1)
    rgb = rgb * (1 - moss[..., None] * 0.7) + hexc("5f8f3a") * moss[..., None] * 0.7
    save("tex_giant", rgb)


def fossil():
    # Pale canyon rock with bones set in it.
    rgb, rng, idx, d1 = faceted(79, 34, ["dcc196", "d4b88a", "e3caa0", "cfb184"], crevice=(0.28, 2.6), facet_light=0.28)
    rgb = strata(rgb, rng, 5, 0.2)
    img = Image.fromarray((rgb * 255).astype(np.uint8)).convert("RGBA")
    big = Image.new("RGBA", (N * 3, N * 3))
    for i in range(3):
        for j in range(3):
            big.paste(img, (i * N, j * N))
    from PIL import ImageDraw
    d = ImageDraw.Draw(big)
    bone, shade = (244, 233, 205, 255), (150, 120, 88, 255)
    for k in range(4):
        cx, cy = rng.random(2) * N + N
        ang = rng.random() * np.pi
        L = 60 + rng.random() * 80
        w = 9 + rng.random() * 6
        dx, dy = np.cos(ang) * L / 2, np.sin(ang) * L / 2
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                a = (cx - dx + ox, cy - dy + oy)
                b = (cx + dx + ox, cy + dy + oy)
                d.line([a, b], fill=shade, width=int(w + 4))
                for p in (a, b):
                    for s in (-1, 1):
                        q = (p[0] + s * np.sin(ang) * w * 0.55, p[1] - s * np.cos(ang) * w * 0.55)
                        d.ellipse([q[0] - w * 0.75 - 2, q[1] - w * 0.75 - 2, q[0] + w * 0.75 + 2, q[1] + w * 0.75 + 2], fill=shade)
                d.line([a, b], fill=bone, width=int(w))
                for p in (a, b):
                    for s in (-1, 1):
                        q = (p[0] + s * np.sin(ang) * w * 0.55, p[1] - s * np.cos(ang) * w * 0.55)
                        d.ellipse([q[0] - w * 0.75, q[1] - w * 0.75, q[0] + w * 0.75, q[1] + w * 0.75], fill=bone)
    out = np.asarray(big, np.float32)[N:2 * N, N:2 * N, :3] / 255.0
    save("tex_fossil", out)


def comb():
    # Honeycomb wall: hexagonal cells, wax rims, honey in some cells.
    rng = np.random.default_rng(91)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    # 8 hex columns across: size so the pattern tiles on both axes.
    cols = 8
    w = N / cols                     # horizontal pitch
    r = w / np.sqrt(3)               # hex radius
    rows = int(round(N / (1.5 * r)))
    rows += rows % 2
    pitch_y = N / rows
    centres = []
    for j in range(rows):
        for i in range(cols):
            centres.append(((i + 0.5 * (j % 2)) * w, (j + 0.5) * pitch_y))
    d1, d2, idx, vx, vy = torus_voronoi(centres)
    edge = np.clip((d2 - d1) / 7.0, 0, 1)
    fill = rng.random(len(centres))
    honey = fill[idx] > 0.55
    depth = np.clip(d1 / (r * 0.85), 0, 1)
    wax = hexc("f0b84a")
    cell_dark = hexc("a85e10")
    honey_col = hexc("ffb31a")
    inner = np.where(honey[..., None], honey_col * (1.05 - 0.35 * depth[..., None]),
                     cell_dark * (0.75 + 0.45 * depth[..., None]))
    # Lit upper-left inner wall.
    wall = np.clip((vx * 0.6 + vy * 0.8) / (r * 0.9), -1, 1)
    inner = inner * (1.0 + 0.18 * wall[..., None])
    spec = np.where(honey, np.clip(1.0 - np.hypot(vx + r * 0.3, vy + r * 0.3) / (r * 0.22), 0, 1), 0)
    inner = inner + spec[..., None] * 0.5
    rim = wax * (0.85 + 0.25 * np.clip(-(vx * 0.6 + vy * 0.8) / r, 0, 1))[..., None]
    k = (edge ** 1.5)[..., None]
    rgb = rim * (1 - k) + inner * k
    n = tile_noise(rng, octaves=5)
    rgb *= (0.94 + 0.12 * n)[..., None]
    save("tex_comb", rgb)


if __name__ == "__main__":
    earth()
    sandstone()
    basalt()
    slate()
    mesa()
    giant_stone()
    fossil()
    comb()
