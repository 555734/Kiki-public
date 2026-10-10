#!/usr/bin/env python3
"""Cut 1-9's flat castle art out of the sheets it was generated as.

    python3 -I tools/import_castle_art.py <folder>

The folder holds the seven images made to the prompts in
docs/art-prompts-castle.md (second set), under these names:

    sky.png        the sky, opaque
    far.png        far layer: mountains, the castle silhouette, the aqueduct
    hills.png      near layer: hills and pines
    tiles.png      ground, water, brick, stone, two bushes
    traps.png      spike block, spiked ball, chain, cannon barrel, carriage, ball
    buildings.png  gatehouse, portcullis, broken bridge, castle tower
    wall.png       a section of the keep wall

Writes assets/castle/*.png (and the panorama as .jpg). Boxes are the sheets'
own: every sprite is a separate island of opaque pixels, found by hand once and
written down here so the import is repeatable.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "castle"

# name: (sheet, (x0, y0, x1, y1)) -- the sprite's island, inclusive.
CUTS = {
    "castle_gate_arch": ("buildings", (32, 233, 785, 702)),
    "castle_gate_bars": ("buildings", (808, 443, 1028, 704)),
    "castle_goal_door": ("buildings", (1024, 55, 1418, 971)),
    "castle_spike_block": ("traps", (90, 189, 550, 558)),
    "castle_spike_ball": ("traps", (653, 159, 1106, 589)),
    "castle_cannonball": ("traps", (1190, 760, 1386, 960)),
    "castle_brick": ("tiles", (127, 726, 367, 959)),
    "castle_stone": ("tiles", (473, 726, 708, 960)),
    "castle_bush_0": ("tiles", (806, 765, 1089, 960)),
    "castle_bush_1": ("tiles", (1151, 816, 1340, 960)),
}


def load(folder: Path, name: str) -> Image.Image:
    return Image.open(folder / f"{name}.png").convert("RGBA")


def cut(img: Image.Image, box: tuple, pad: int = 4) -> Image.Image:
    x0, y0, x1, y1 = box
    return img.crop((max(0, x0 - pad), max(0, y0 - pad), x1 + 1 + pad, y1 + 1 + pad))


def seamless_x(a: np.ndarray, blend: int) -> np.ndarray:
    """Cross-fade the right edge into the left so the strip tiles sideways."""
    w = a.shape[1] - blend
    out = a[:, :w].astype(np.float32).copy()
    k = np.linspace(0.0, 1.0, blend)[None, :, None]
    out[:, :blend] = a[:, w:].astype(np.float32) * (1.0 - k) + a[:, :blend].astype(np.float32) * k
    return out.clip(0, 255).astype(np.uint8)


def seamless_y(a: np.ndarray, blend: int) -> np.ndarray:
    return seamless_x(a.transpose(1, 0, 2), blend).transpose(1, 0, 2)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    src = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = {n: load(src, n) for n in ("tiles", "traps", "buildings", "wall", "far", "hills")}

    for name, (sheet, box) in CUTS.items():
        cut(sheets[sheet], box).save(OUT / f"{name}.png")

    # The chain: one run of links, trimmed to whole links so it tiles upward.
    chain = np.array(sheets["traps"])[100:604, 1218:1314]
    Image.fromarray(chain).save(OUT / "castle_chain.png")

    # Ground: the stone strip along the top (one stone, gap to gap, so it
    # repeats) and the earth under it (cross-faded both ways).
    tiles = np.array(sheets["tiles"])
    Image.fromarray(tiles[160:262, 281:464]).save(OUT / "castle_ground_cap.png")
    earth = tiles[264:612, 142:606]
    earth = seamless_y(seamless_x(earth, 60), 60)
    Image.fromarray(earth).convert("RGB").save(OUT / "castle_ground_tile.png")
    # The moat: its wave line on top, cross-faded sideways.
    water = tiles[196:626, 734:1258]
    Image.fromarray(seamless_x(water, 70)).save(OUT / "castle_water.png")

    # The keep wall, crenellations on top: tiled sideways, a bay at a time.
    cut(sheets["wall"], (31, 109, 855, 1710), pad=0).save(OUT / "castle_keep_wall.png")

    # The cannon, put together: the barrel resting in its carriage.
    traps = sheets["traps"]
    barrel = cut(traps, (66, 695, 528, 957))
    carriage = cut(traps, (632, 729, 1082, 986))
    for name, kick in (("castle_cannon_idle", 0), ("castle_cannon_fire", 26)):
        canvas = Image.new("RGBA", (barrel.width + 90 + kick, barrel.height + carriage.height - 120))
        canvas.alpha_composite(carriage, (90 + kick // 2, canvas.height - carriage.height))
        canvas.alpha_composite(barrel, (kick, 0))
        canvas.save(OUT / f"{name}.png")

    # The backdrop: sky, then the far layer, then the hills, as one panorama;
    # below the hills' foot, their own darkest green to the bottom.
    pano = load(src, "sky")
    pano.alpha_composite(sheets["far"])
    pano.alpha_composite(sheets["hills"])
    a = np.array(pano)
    hills = np.array(sheets["hills"])[..., 3]
    foot = int(np.max(np.nonzero(hills.max(axis=1) > 200)[0]))
    a[foot:] = a[foot - 4]
    Image.fromarray(a).convert("RGB").save(OUT / "castle_panorama.jpg", quality=92)

    print("castle art written to", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
