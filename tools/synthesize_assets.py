#!/usr/bin/env python3
"""Build the entities the concept mockups never showed.

The mockups cover the runner, the walker, the holograms, the props, the terrain
and the whole UI -- but not the flyer, turret, projectile, laser emitter,
switch, gate, moving platform, checkpoint or goal. Rather than leave half the
roster as flat vector shapes next to painted ones, each missing piece is
assembled from parts that *were* cut out, so it inherits the same palette,
the same light direction and the same rendering.

Run after tools/extract_assets.py.
"""
from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")


def load(rel: str) -> Image.Image:
    return Image.open(os.path.join(OUT, rel)).convert("RGBA")



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


def save(img: Image.Image, rel: str) -> None:
    if rel in SUPPLIED:
        print(f"  {rel}  SKIPPED (supplied painted art)")
        return
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(f"  {rel}  {img.width}x{img.height}")


def recolor(img: Image.Image, target: tuple[int, int, int], keep_lum: float = 0.85,
            saturation: float = 1.0) -> Image.Image:
    """Re-tint a sprite to a new hue while preserving its painted shading."""
    a = np.asarray(img, dtype=np.float32)
    rgb, alpha = a[..., :3], a[..., 3:]
    lum = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255.0
    lum = np.clip(lum, 0.0, 1.0)[..., None]
    base = np.array(target, dtype=np.float32)[None, None, :] / 255.0
    shaded = base * (0.35 + keep_lum * lum)
    grey = lum.repeat(3, axis=2)
    mixed = shaded * saturation + grey * (1.0 - saturation)
    return Image.fromarray(
        np.dstack([np.clip(mixed * 255.0, 0, 255), alpha]).astype(np.uint8), "RGBA")


def glow(size: tuple[int, int], colour: tuple[int, int, int], radius: float,
         power: float = 2.0) -> Image.Image:
    """Soft radial light, used for muzzles, bullets and switch lamps."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx - w / 2) / max(radius, 1)) ** 2 + ((yy - h / 2) / max(radius, 1)) ** 2)
    a = np.clip(1.0 - d, 0.0, 1.0) ** power
    rgb = np.array(colour, dtype=np.float32)[None, None, :] * np.ones((h, w, 1), np.float32)
    rgb = rgb + (255.0 - rgb) * (np.clip(1.0 - d * 2.2, 0, 1) ** 2)[..., None]
    return Image.fromarray(np.dstack([rgb, a * 255.0]).astype(np.uint8), "RGBA")


def paste(base: Image.Image, layer: Image.Image, xy: tuple[int, int]) -> None:
    base.alpha_composite(layer, xy)


# ------------------------------------------------------------------ terrain

def flatten_lighting(a: np.ndarray, strength: float = 0.55) -> np.ndarray:
    """Divide out the broad light gradient baked into a cropped painting.

    Any crop out of a rendered scene carries that scene's lighting -- brighter
    toward the light, darker into a vignette. Tiled, that gradient turns into
    obvious bands. Dividing by a heavily blurred copy and restoring the mean
    keeps the brush detail and throws away the slope.
    """
    from scipy import ndimage as ndi
    sigma = max(a.shape[0], a.shape[1]) * 0.25
    low = ndi.gaussian_filter(a, sigma=(sigma, sigma, 0), mode="reflect")
    mean = a.reshape(-1, 3).mean(axis=0)[None, None, :]
    flat = a / np.maximum(low, 1.0) * mean
    out = a * (1.0 - strength) + flat * strength
    # Flattening always costs some bite; put a little back so the strata still
    # read at the size the tile is actually drawn.
    m = out.reshape(-1, 3).mean(axis=0)[None, None, :]
    out = m + (out - m) * 1.22
    return np.clip(out, 0, 255)


def make_seamless(img: Image.Image, blend: float = 0.28) -> Image.Image:
    """Offset-and-crossfade so a cropped photograph tiles without a visible seam.

    The dirt strip is a straight crop out of a painting, so its left/right and
    top/bottom edges do not meet. Rolling the image by half and cross-fading the
    join hides both seams, which is what lets a 300px sample cover a 9,000px
    stage without a repeating scar down the middle.
    """
    a = flatten_lighting(np.asarray(img.convert("RGB"), dtype=np.float32))
    h, w, _ = a.shape
    rolled = np.roll(np.roll(a, w // 2, axis=1), h // 2, axis=0)

    bx = max(2, int(w * blend))
    by = max(2, int(h * blend))
    mx = np.ones(w, np.float32)
    mx[:bx] = np.linspace(0.0, 1.0, bx)
    mx[-bx:] = np.linspace(1.0, 0.0, bx)
    my = np.ones(h, np.float32)
    my[:by] = np.linspace(0.0, 1.0, by)
    my[-by:] = np.linspace(1.0, 0.0, by)
    m = (my[:, None] * mx[None, :])[..., None]

    out = a * m + rolled * (1.0 - m)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def make_terrain_tiles() -> None:
    save(make_seamless(load("terrain/dirt_body.png")), "terrain/dirt_tile.png")
    # The grass lip only ever tiles sideways, so its vertical edges are left alone.
    grass = load("terrain/grass_cap.png")
    a = np.asarray(grass.convert("RGB"), dtype=np.float32)
    h, w, _ = a.shape
    bx = max(2, int(w * 0.22))
    rolled = np.roll(a, w // 2, axis=1)
    mx = np.ones(w, np.float32)
    mx[:bx] = np.linspace(0.0, 1.0, bx)
    mx[-bx:] = np.linspace(1.0, 0.0, bx)
    out = np.clip(a * mx[None, :, None] + rolled * (1.0 - mx[None, :, None]), 0, 255)
    # The grass tufts stand against sky in the mockup. Key that sky out or the
    # tile paints an opaque blue band along the top of every ledge.
    r, g, b = out[..., 0], out[..., 1], out[..., 2]
    alpha = np.clip(((r - b) - (-70.0)) / 44.0, 0.0, 1.0)
    alpha[int(h * 0.35):, :] = 1.0        # everything below the tufts is solid
    alpha[alpha < 0.45] = 0.0             # no half-lit sky pixels along the top
    rgba = np.dstack([out, alpha * 255.0]).astype(np.uint8)
    tile = Image.fromarray(rgba, "RGBA")
    # Drop leading rows that are almost entirely empty: they otherwise render as
    # a thin grey band sitting on top of every ledge in the game.
    cover = (alpha > 0.05).mean(axis=1)
    first = int(np.argmax(cover > 0.12)) if (cover > 0.12).any() else 0
    if first > 0:
        tile = tile.crop((0, first, tile.width, tile.height))
    save(tile, "terrain/grass_tile.png")


# --------------------------------------------------------------------- flyer

def make_flyer() -> None:
    """Walker body, shrunk, with painted wings. Chapter 2 wants the flyer read
    as 'one of those, but out of reach', so sharing the walker's body is right."""
    body = load("characters/walker.png")
    body = body.resize((int(body.width * 0.82), int(body.height * 0.78)), Image.LANCZOS)
    w, h = body.width + 96, body.height + 34
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    for side in (-1, 1):
        wing = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(wing)
        cx, cy = w // 2, h // 2 - 2
        tip = (cx + side * 62, cy - 26)
        pts = [(cx + side * 10, cy - 4), tip, (cx + side * 58, cy + 6), (cx + side * 26, cy + 20)]
        d.polygon(pts, fill=(250, 251, 255, 245), outline=(178, 194, 214, 255))
        d.line([(cx + side * 16, cy + 2), (cx + side * 52, cy + 2)], fill=(206, 218, 232, 255), width=3)
        wing = wing.filter(ImageFilter.GaussianBlur(0.6))
        out.alpha_composite(wing)
    paste(out, body, ((w - body.width) // 2, (h - body.height) // 2))
    save(out.crop(out.getbbox()), "entities/flyer.png")


# -------------------------------------------------------------------- turret

def make_turret() -> None:
    """Pipe metal + brick masonry, restyled to gunmetal, with a hot muzzle."""
    pipe = load("props/pipe.png")
    steel = recolor(pipe, (108, 120, 136), keep_lum=0.95)
    barrel = steel.resize((96, 58), Image.LANCZOS)

    base_src = load("props/brick.png")
    base = recolor(base_src, (74, 82, 96), keep_lum=0.9).resize((108, 104), Image.LANCZOS)

    w, h = 176, 116
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    paste(out, barrel, (w - barrel.width - 4, (h - barrel.height) // 2))
    paste(out, base, (0, h - base.height))

    muzzle = glow((72, 72), (255, 150, 46), 26.0, 2.4)
    paste(out, muzzle, (w - 56, h // 2 - 36))
    save(out, "entities/turret.png")


# ---------------------------------------------------------------- projectile

def make_projectile() -> None:
    orb = glow((64, 64), (255, 168, 60), 24.0, 1.7)
    core = glow((30, 30), (255, 246, 214), 13.0, 1.2)
    out = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    paste(out, orb, (0, 0))
    paste(out, core, (17, 17))
    save(out, "entities/projectile.png")


# -------------------------------------------------------------- laser + beam

def make_laser() -> None:
    pipe = load("props/pipe.png")
    housing = recolor(pipe, (126, 88, 168), keep_lum=0.9).resize((88, 78), Image.LANCZOS)
    out = Image.new("RGBA", (96, 86), (0, 0, 0, 0))
    paste(out, housing, (0, 4))
    paste(out, glow((44, 44), (255, 92, 116), 17.0, 2.0), (52, 20))
    save(out, "entities/laser_emitter.png")

    # A 1px-tall beam slice the renderer stretches along the ray.
    h = 48
    prof = np.linspace(-1.0, 1.0, h)[:, None]
    core = np.clip(1.0 - np.abs(prof) * 5.0, 0, 1) ** 0.6
    mid = np.clip(1.0 - np.abs(prof) * 2.1, 0, 1) ** 1.4
    halo = np.clip(1.0 - np.abs(prof), 0, 1) ** 2.6
    rgb = (np.array([255, 245, 246]) * core + np.array([255, 86, 108]) * (mid - core).clip(0)
           + np.array([220, 40, 70]) * (halo - mid).clip(0))
    a = np.clip(core + mid * 0.85 + halo * 0.45, 0, 1)
    strip = np.concatenate(
        [np.clip(rgb, 0, 255).reshape(h, 1, 3), (a * 255.0).reshape(h, 1, 1)], axis=2)
    save(Image.fromarray(np.repeat(strip.astype(np.uint8), 8, axis=1), "RGBA"),
         "entities/laser_beam.png")


# -------------------------------------------------------------------- switch

def make_switch() -> None:
    plate = recolor(load("props/qblock.png"), (92, 102, 118), keep_lum=0.95).resize((84, 84), Image.LANCZOS)
    for name, colour in (("switch_off", (150, 162, 178)), ("switch_on", (255, 208, 74))):
        out = Image.new("RGBA", (108, 108), (0, 0, 0, 0))
        paste(out, plate, (12, 12))
        paste(out, glow((72, 72), colour, 24.0, 1.9), (18, 18))
        save(out, f"entities/{name}.png")


# ------------------------------------------------------- gate, floor, flags

def make_gate() -> None:
    brick = load("props/brick.png")
    stone = recolor(brick, (128, 112, 84), keep_lum=0.95).resize((72, 72), Image.LANCZOS)
    out = Image.new("RGBA", (72, 288), (0, 0, 0, 0))
    for i in range(4):
        paste(out, stone, (0, i * 72))
    save(out, "entities/gate.png")


def make_moving_platform() -> None:
    steel = recolor(load("props/brick.png"), (122, 134, 150), keep_lum=0.95).resize((72, 48), Image.LANCZOS)
    out = Image.new("RGBA", (288, 48), (0, 0, 0, 0))
    for i in range(4):
        paste(out, steel, (i * 72, 0))
    d = ImageDraw.Draw(out)
    d.line([(0, 3), (out.width, 3)], fill=(206, 218, 232, 210), width=4)
    save(out, "entities/moving_platform.png")


def make_flags() -> None:
    post = recolor(load("props/fence.png"), (150, 160, 176), keep_lum=0.95)
    post = post.crop((0, 0, max(18, post.width // 4), post.height)).resize((22, 150), Image.LANCZOS)
    for name, colour in (("checkpoint_off", (150, 162, 178)), ("checkpoint_on", (74, 214, 255))):
        out = Image.new("RGBA", (110, 176), (0, 0, 0, 0))
        paste(out, post, (10, 26))
        d = ImageDraw.Draw(out)
        d.polygon([(30, 34), (100, 48), (100, 88), (30, 76)], fill=colour + (235,))
        paste(out, glow((56, 56), colour, 20.0, 2.0), (0, 6))
        save(out, f"entities/{name}.png")


def make_goal() -> None:
    """The Ancient Gate: stone arch from brick masonry, holographic portal."""
    stone = recolor(load("props/brick.png"), (146, 132, 108), keep_lum=0.95).resize((56, 56), Image.LANCZOS)
    w, h = 260, 300
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for i in range(4):
        paste(out, stone, (8, h - 56 * (i + 1)))
        paste(out, stone, (w - 64, h - 56 * (i + 1)))
    for i in range(24):
        t = i / 23.0
        a = math.pi * t
        x = int(w / 2 - math.cos(a) * (w / 2 - 34) - 28)
        y = int(h - 224 - math.sin(a) * 46)
        paste(out, stone, (x, y))

    portal = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(portal).ellipse([56, 40, w - 56, h - 18], fill=(64, 186, 236, 150))
    portal = portal.filter(ImageFilter.GaussianBlur(9))
    combined = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    combined.alpha_composite(portal)
    combined.alpha_composite(out)
    save(combined, "entities/goal.png")


def main() -> int:
    for fn in (make_terrain_tiles, make_flyer, make_turret, make_projectile, make_laser, make_switch,
               make_gate, make_moving_platform, make_flags, make_goal):
        fn()
    return 0


if __name__ == "__main__":
    sys.exit(main())
