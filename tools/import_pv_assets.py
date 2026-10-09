#!/usr/bin/env python3
"""Bring the generated PV art (docs/art-prompts-characters.md and
docs/art-prompts-castle.md) into the game.

    python3 -I tools/import_pv_assets.py <unpacked asset folder>

The folder is the processed pack: characters/<sheet>_NN.png frames in 256px
cells and castle/*.png singles. Only the frames listed in FRAMES and SINGLES
are taken -- the rest of the pack was cut from the wrong grid and is left out
on purpose (see the notes beside each list).

Every frame is cropped to what is actually drawn, keeping only its largest
pieces, so a neighbour's stray wing or foot does not come with it. A sheet is
scaled as one, by a factor fixed from one reference frame, so the character is
the same size in every frame; each frame is then stood on the same baseline.
Runner frames go on the same 172x136 canvas (at 2x) the existing runner poses
use, figure where the old pose's figure was, so they drop into RunnerVisual
with no change of anchor.
"""
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_CHAR = ROOT / "assets" / "characters" / "anim"
OUT_CASTLE = ROOT / "assets" / "castle"
ALPHA = 28

# Runner sheets: (sheet, frames taken, output key, the old pose whose figure
# height and place the sheet is fitted to, the frame measured against it).
#   run    all eight -- a clean cycle.
#   idle   all four.
#   hurt   00 flinch, 01 knocked into a ball; 02-04 are cut through.
#   launch 03, flying with a hand forward; 00-02 are cut or not the pose.
#   jump and react are cut across cells throughout and are not used.
RUNNER = [
    ("runner_run", [0, 1, 2, 3, 4, 5, 6, 7], "runner_run", "runner_run", 0),
    ("runner_idle", [0, 1, 2, 3], "runner_idle", "runner_idle", 0),
    ("runner_hurt", [0, 1], "runner_hurt", "runner_idle", 0),
    ("runner_launch", [3], "runner_launch", "runner_run", 2),
]

# Castle creatures: (sheet, frames, output key, output height in px).
#   hound  row one, the gallop (00-03); row two is cut or another character.
#   golem  00 standing, 01 shield arm up (the stomp); the rest is rubble.
CREATURES = [
    ("castle_hound", [0, 1, 2, 3], "castle_hound", 320),
    ("castle_golem", [0, 1], "castle_golem", 420),
]

# Castle singles: (file, output key, output height, crop box or None, mode).
SINGLES = [
    ("castle/cannon_idle.png", "castle_cannon_idle", 240, None, "largest"),
    ("castle/cannon_fire.png", "castle_cannon_fire", 240, None, "largest"),
    ("castle/cannonball.png", "castle_cannonball", 128, None, "largest"),
    ("castle/boulder.png", "castle_boulder", 256, None, "largest"),
    ("castle/bridge_end.png", "castle_bridge_end", 300, None, "pieces"),
    # Two torches side by side: the unlit one is on the right.
    ("castle/torch.png", "castle_torch", 200, (211, 0, 422, 210), "largest"),
]


def alpha_mask(im):
    return im.getchannel("A").point(lambda a: 255 if a > ALPHA else 0)


def components(im, keep):
    """Keep the `keep` largest connected pieces (or all, keep=0)."""
    small = alpha_mask(im).resize((im.width // 2, im.height // 2), Image.NEAREST)
    w, h = small.size
    px = small.load()
    seen = [[False] * w for _ in range(h)]
    found = []
    for y in range(h):
        for x in range(w):
            if px[x, y] and not seen[y][x]:
                q = deque([(x, y)])
                seen[y][x] = True
                pts = []
                while q:
                    cx, cy = q.popleft()
                    pts.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            q.append((nx, ny))
                found.append(pts)
    found.sort(key=len, reverse=True)
    if not found:
        return im
    biggest = len(found[0])
    # A piece of the same drawing (a scarf end, a chip of stone) is kept; a
    # sliver from the next cell is far smaller than the figure and is not.
    chosen = found if keep == 0 else [c for c in found if len(c) >= biggest * 0.06][:keep]
    mask = Image.new("L", small.size, 0)
    mp = mask.load()
    for c in chosen:
        for x, y in c:
            mp[x, y] = 255
    mask = mask.resize(im.size, Image.NEAREST)
    out = im.copy()
    a = Image.composite(im.getchannel("A"), Image.new("L", im.size, 0), mask)
    out.putalpha(a)
    return out


def tight(im):
    box = alpha_mask(im).getbbox()
    return im.crop(box) if box else im


def clean(path, keep=3):
    return tight(components(Image.open(path).convert("RGBA"), keep))


def place(fig, canvas, scale, bottom, centre_x):
    w = max(1, round(fig.width * scale))
    h = max(1, round(fig.height * scale))
    fig = fig.resize((w, h), Image.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    out.alpha_composite(fig, (round(centre_x - w / 2), round(bottom - h)))
    return out


def runner(src):
    for sheet, frames, key, fit_to, ref in RUNNER:
        old = Image.open(ROOT / "assets" / "characters" / f"{fit_to}.png").convert("RGBA")
        box = alpha_mask(old).getbbox()
        target_h = (box[3] - box[1]) * 2
        centre = (box[0] + box[2])  # x2 canvas: (a+b)/2 * 2
        bottom = box[3] * 2
        canvas = (old.width * 2, old.height * 2)
        figs = {i: clean(src / "characters" / f"{sheet}_{i:02d}.png") for i in set(frames + [ref])}
        scale = target_h / figs[ref].height
        for n, i in enumerate(frames):
            out = place(figs[i], canvas, scale, bottom, centre)
            out.save(OUT_CHAR / f"{key}_{n}.png")
            print(f"{key}_{n}  from {sheet}_{i:02d}")


def creatures(src):
    for sheet, frames, key, height in CREATURES:
        figs = [clean(src / "characters" / f"{sheet}_{i:02d}.png") for i in frames]
        tallest = max(f.height for f in figs)
        scale = height / tallest
        width = round(max(f.width for f in figs) * scale) + 8
        for n, f in enumerate(figs):
            out = place(f, (width, height), scale, height, width / 2)
            out.save(OUT_CASTLE / f"{key}_{n}.png")
            print(f"{key}_{n}  from {sheet}_{frames[n]:02d}")


def singles(src):
    for name, key, height, crop, mode in SINGLES:
        im = Image.open(src / name).convert("RGBA")
        if crop:
            im = im.crop(crop)
        fig = tight(components(im, 1 if mode == "largest" else 8))
        scale = height / fig.height
        fig = fig.resize((max(1, round(fig.width * scale)), height), Image.LANCZOS)
        fig.save(OUT_CASTLE / f"{key}.png")
        print(f"{key}  from {name}")


def mirror_tile(card):
    """A seamless tile from one card: the card and its mirror images, 2x2."""
    w, h = card.size
    out = Image.new("RGB", (w * 2, h * 2))
    out.paste(card, (0, 0))
    out.paste(card.transpose(Image.FLIP_LEFT_RIGHT), (w, 0))
    out.paste(card.transpose(Image.FLIP_TOP_BOTTOM), (0, h))
    out.paste(card.transpose(Image.ROTATE_180), (w, h))
    return out.resize((512, 512), Image.LANCZOS)


def textures(src):
    # Each "tile" in the pack is four framed cards; one card's inside, mirrored,
    # tiles with no seam.
    for name, key in (("ground_tile", "castle_ground_tile"), ("dungeon_wall", "castle_dungeon_wall"),
                      ("keep_wall", "castle_keep_wall")):
        im = Image.open(src / "castle" / f"{name}.png").convert("RGB")
        card = im.crop((24, 64, 238, 238))
        mirror_tile(card).save(OUT_CASTLE / f"{key}.png")
        print(f"{key}  from {name} (one card, mirrored)")
    # The road's top edge: the opaque band, its haze cleared.
    cap = Image.open(src / "castle" / "ground_cap.png").convert("RGBA").crop((0, 44, 512, 118))
    a = cap.getchannel("A").point(lambda v: 255 if v > 200 else 0)
    cap.putalpha(a)
    cap.save(OUT_CASTLE / "castle_ground_cap.png")
    print("castle_ground_cap  from ground_cap (band only)")
    # The panorama, without the frame and caption strip it was cut with.
    pano = Image.open(src / "castle" / "panorama.jpg").convert("RGB")
    w, h = pano.size
    pano = pano.crop((round(w * 0.02), round(h * 0.035), round(w * 0.98), round(h * 0.965)))
    pano.resize((2048, 1152), Image.LANCZOS).save(OUT_CASTLE / "castle_panorama.jpg", quality=92)
    print("castle_panorama  from panorama.jpg (frame cropped)")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    src = Path(sys.argv[1]).resolve()
    OUT_CHAR.mkdir(parents=True, exist_ok=True)
    OUT_CASTLE.mkdir(parents=True, exist_ok=True)
    runner(src)
    creatures(src)
    singles(src)
    textures(src)
    return 0


if __name__ == "__main__":
    sys.exit(main())
