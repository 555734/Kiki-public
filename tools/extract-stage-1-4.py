#!/usr/bin/env python3
"""Prepare the stage 1-4 sea art pack for the game.

    python tools/extract-stage-1-4.py <Kiki_1-4_Sea_Assets folder or .zip>

The pack's sprites were cut from generated sheets, and several carry slivers of
their neighbours along an edge (a crab leg above the crab, a palm frond above
the grass, a fence post above the boulder). Those are removed by keeping only
the large connected pieces of each sprite. Everything is then trimmed to its
opaque bounds and written to assets/stage_1_4/.

Two files in the pack are empty (surf_foam.png, sand_right_edge.png), and
rope_fence.png holds only the tops of two posts; the foam is drawn in code
(SeaWater). The lighthouse, cliff block, sand edge and pier post are not used
by the stage and are left out.

The terrain tiles are made here too: the sand body and the grass cap are cut
from the middle of the painted blocks and cross-faded so they repeat.
"""
import os
import sys
import zipfile
import tempfile

from PIL import Image, ImageChops, ImageFilter, ImageOps

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "stage_1_4")

# name in pack -> (output name, mirror?)
SPRITES = {
    "actors/enemy_crab.png": ("crab", False),
    # Every painted sprite faces LEFT (Flyer flips it when heading right).
    "actors/enemy_seabird.png": ("seabird", True),
    "actors/enemy_purple_chaser.png": ("chaser", False),
    "props/beach_grass_flower.png": ("grass_flower", False),
    "props/checkpoint_flag.png": ("flag", False),
    "props/mossy_boulder.png": ("boulder", False),
    "props/palm_large.png": ("palm_large", False),
    "props/palm_small.png": ("palm_small", False),
    "props/seaweed_starfish.png": ("seaweed", False),
    "terrain/bridge_with_post.png": ("bridge", False),
    "terrain/grass_sand_center.png": ("grass_sand_block", False),
    "terrain/mossy_stepping_rock.png": ("rock", False),
    "terrain/pier_platform.png": ("pier", False),
    "terrain/sand_center.png": ("sand_block", False),
}


def clean(img: Image.Image) -> Image.Image:
    """Keep only the connected opaque pieces that are a real part of the sprite."""
    img = img.convert("RGBA")
    w, h = img.size
    alpha = img.getchannel("A").load()
    seen = bytearray(w * h)
    pieces = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx] or alpha[sx, sy] < 24:
                continue
            stack = [(sx, sy)]
            seen[sy * w + sx] = 1
            pixels = []
            while stack:
                x, y = stack.pop()
                pixels.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] \
                            and alpha[nx, ny] >= 24:
                        seen[ny * w + nx] = 1
                        stack.append((nx, ny))
            pieces.append(pixels)
    if not pieces:
        return img
    pieces.sort(key=len, reverse=True)

    def box(p):
        xs = [q[0] for q in p]
        ys = [q[1] for q in p]
        return min(xs), min(ys), max(xs), max(ys)

    # The sprite itself is the big piece standing on the bottom centre -- the
    # pack's suggested origin -- not merely the biggest: in the flag and the
    # grass tuft the neighbour's sliver is larger than the sprite.
    def anchored(p):
        x0, _y0, x1, y1 = box(p)
        return w * 0.25 <= (x0 + x1) * 0.5 <= w * 0.78 and y1 >= h * 0.75

    grounded = [p for p in pieces if anchored(p) and len(p) >= len(pieces[0]) * 0.05]
    if grounded:
        pieces.remove(grounded[0])
        pieces.insert(0, grounded[0])
    main = box(pieces[0])
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for i, p in enumerate(pieces):
        x0, y0, x1, y1 = box(p)
        if i > 0:
            # A piece touching the border is a neighbour's sliver cut off by
            # the sheet; so is one standing apart from the sprite. Pieces next
            # to the main body (a leaf, a starfish, a flower) are kept.
            on_edge = x0 == 0 or y0 == 0 or x1 == w - 1
            apart = x1 < main[0] - 24 or x0 > main[2] + 24 \
                or y1 < main[1] - 24 or y0 > main[3] + 24
            if on_edge or apart or len(p) < 30:
                continue
        for x, y in p:
            mp[x, y] = 255
    # Grow the mask a little so anti-aliased fringes survive.
    mask = mask.filter(ImageFilter.MaxFilter(5))
    out = img.copy()
    out.putalpha(ImageChops.multiply(img.getchannel("A"), mask))
    return out


def trim(img: Image.Image) -> Image.Image:
    box = img.getchannel("A").point(lambda v: 255 if v >= 12 else 0).getbbox()
    return img.crop(box) if box else img


def seamless(strip: Image.Image, blend: int) -> Image.Image:
    """Cross-fade the strip's two ends so it tiles horizontally."""
    w, h = strip.size
    body = strip.crop((0, 0, w - blend, h))
    tail = strip.crop((w - blend, 0, w, h))
    head = body.crop((0, 0, blend, h))
    ramp = Image.linear_gradient("L").rotate(90, expand=True).resize((blend, h))
    mixed = Image.composite(head, tail, ramp)
    body.paste(mixed, (0, 0))
    return body


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else "Kiki_1-4_Sea_Assets"
    if src.endswith(".zip"):
        tmp = tempfile.mkdtemp()
        zipfile.ZipFile(src).extractall(tmp)
        src = os.path.join(tmp, "Kiki_1-4_Sea_Assets")
    os.makedirs(OUT, exist_ok=True)

    for name, (out, mirror) in SPRITES.items():
        img = trim(clean(Image.open(os.path.join(src, name))))
        if mirror:
            img = ImageOps.mirror(img)
        img.save(os.path.join(OUT, out + ".png"), optimize=True)
        print("wrote", out, img.size)

    # Background: one painting, stored as JPEG (it has no transparency).
    bg = Image.open(os.path.join(src, "background", "distant_sea.png")).convert("RGB")
    bg.save(os.path.join(OUT, "distant_sea.jpg"), quality=90, optimize=True)

    # Sand body tile: the middle of the plain sand block, below its top face.
    sand = Image.open(os.path.join(OUT, "sand_block.png"))
    sw, sh = sand.size
    body = sand.crop((int(sw * 0.12), int(sh * 0.34), int(sw * 0.88), int(sh * 0.86)))
    body = seamless(body.convert("RGBA"), max(16, body.size[0] // 6))
    body = body.convert("RGB")
    body.save(os.path.join(OUT, "sand_tile.png"), optimize=True)
    print("wrote sand_tile", body.size)

    # Grass cap: the top band of the grass-over-sand block, blade tips kept.
    grass = Image.open(os.path.join(OUT, "grass_sand_block.png"))
    gw, gh = grass.size
    cap = grass.crop((int(gw * 0.10), 0, int(gw * 0.90), int(gh * 0.42)))
    cap = seamless(cap, max(16, cap.size[0] // 6))
    cap.save(os.path.join(OUT, "grass_cap.png"), optimize=True)
    print("wrote grass_cap", cap.size)

    # Raft: the pier's plank deck alone, for the moving platform.
    pier = Image.open(os.path.join(OUT, "pier.png"))
    pw, ph = pier.size
    raft = trim(pier.crop((0, 0, pw, int(ph * 0.36))))
    raft.save(os.path.join(OUT, "raft.png"), optimize=True)
    print("wrote raft", raft.size)

    # The whole blocks were only sources for the tiles.
    for name in ("sand_block.png", "grass_sand_block.png"):
        os.remove(os.path.join(OUT, name))

    make_preview()


def make_preview() -> None:
    """The start menu's card: the backdrop with a beach, a palm, a rock, a crab
    and a gull from the pack, so the card shows this stage and not the board."""
    def load(n):
        return Image.open(os.path.join(OUT, n)).convert("RGBA")

    def put(canvas, img, height, bottom_centre, mirror=False):
        w = int(img.size[0] * height / img.size[1])
        im = img.resize((w, int(height)), Image.LANCZOS)
        if mirror:
            im = ImageOps.mirror(im)
        x, y = bottom_centre
        canvas.alpha_composite(im, (int(x - w / 2), int(y - height)))

    bg = Image.open(os.path.join(OUT, "distant_sea.jpg")).convert("RGBA")
    W, H = 1280, 720
    canvas = bg.resize((W, int(bg.size[1] * W / bg.size[0])), Image.LANCZOS).crop((0, 0, W, H))
    sand = load("sand_tile.png")
    cap = load("grass_cap.png")
    ground_top = 560
    for x in range(-40, 700, 180):
        canvas.alpha_composite(sand.resize((180, 91)), (x, ground_top + 20))
        canvas.alpha_composite(sand.resize((180, 91)), (x, ground_top + 110))
    for x in range(-40, 700, 140):
        canvas.alpha_composite(cap.resize((140, 57)), (x, ground_top - 10))
    put(canvas, load("rock.png"), 120, (880, 700))
    put(canvas, load("pier.png"), 150, (1150, 720))
    put(canvas, load("palm_large.png"), 330, (150, ground_top + 12))
    put(canvas, load("grass_flower.png"), 70, (560, ground_top + 12))
    put(canvas, load("crab.png"), 88, (420, ground_top + 14))
    put(canvas, load("seabird.png"), 110, (900, 250), mirror=True)
    canvas.convert("RGB").save(os.path.join(OUT, "preview.jpg"), quality=88)
    print("wrote preview")


if __name__ == "__main__":
    main()
