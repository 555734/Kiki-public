#!/usr/bin/env python3
"""Cut the owner-supplied 1-3 sprite sheets into individual runtime sprites.

The sheets in assets/stage_1_3/reference/ were exported with a soft, neon
coloured halo around every piece (green, cyan, yellow fringes over a
transparent background). Drawn as-is on a sky they read as glowing outlines,
so each piece is cropped, its fringe is removed and its alpha is tightened
for alpha-scissor rendering.

    python3 tools/extract-stage-1-3.py      # needs Pillow, numpy, scipy

Writes assets/stage_1_3/sprites/<name>.png. Re-running is deterministic.
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/stage_1_3/reference"
OUT = ROOT / "assets/stage_1_3/sprites"

# name: (sheet, (x0, y0, x1, y1), [exclude rects])
T, P, E, B = "terrain", "platforms", "enemies", "backgrounds"
PILL_PREDATOR = (16, 172, 362, 206)
PILL_SEED = (16, 474, 300, 500)
PILL_BIRD = (16, 614, 245, 645)
PILL_MINE = (16, 765, 296, 796)
PILL_GOLEM = (16, 925, 285, 955)
PILL_TURRET = (16, 1046, 303, 1080)
SPRITES = {
    # --- terrain & ruins
    "tree_big": (T, (668, 20, 910, 236), [(668, 180, 712, 236)]),
    "tree_tall": (T, (887, 27, 987, 209), []),
    "arch": (T, (979, 28, 1219, 231), []),
    "pillar_vine": (T, (1199, 13, 1275, 181), []),
    "pillar": (T, (1339, 21, 1432, 231), []),
    "ruin_steps": (T, (1237, 135, 1332, 229), []),
    "island_float": (T, (827, 255, 1094, 429), []),
    "cliff_a": (T, (1189, 244, 1313, 530), []),
    "cliff_b": (T, (1319, 245, 1434, 539), []),
    "rock_island": (T, (380, 362, 492, 508), []),
    "slope_island": (T, (510, 363, 745, 527), []),
    "stone_block": (T, (16, 514, 109, 619), []),
    "stone_wall": (T, (354, 528, 557, 667), []),
    "stone_vine": (T, (234, 523, 334, 686), []),
    "ruin_stairs": (T, (664, 501, 876, 665), []),
    "waterfall_wide": (T, (888, 540, 1038, 718), []),
    "waterfall_mid": (T, (1070, 539, 1179, 691), []),
    "waterfall_thin": (T, (1196, 548, 1260, 706), []),
    "sign_arrow": (T, (18, 652, 132, 785), []),
    "rope_bridge": (T, (165, 670, 481, 779), []),
    "plank": (T, (502, 670, 686, 722), []),
    "swing": (T, (712, 670, 837, 802), []),
    "bench": (T, (877, 733, 1042, 781), []),
    "conveyor": (T, (16, 807, 244, 871), []),
    "plate_red": (T, (265, 811, 467, 863), []),
    "plate_grey": (T, (488, 810, 693, 861), []),
    "plank_thin": (T, (715, 821, 871, 858), []),
    "ice_plate": (T, (894, 807, 1058, 859), []),
    "blink_blue": (T, (672, 879, 857, 929), []),
    "blink_purple": (T, (878, 878, 1062, 929), []),
    "flag_blue": (T, (1285, 696, 1432, 930), []),
    "spikeball": (T, (22, 898, 124, 1000), []),
    "spike_strip": (T, (19, 1009, 225, 1070), []),
    "vine_a": (T, (325, 885, 370, 1041), []),
    "vine_b": (T, (401, 884, 456, 1064), []),
    "vine_c": (T, (469, 884, 524, 1015), []),
    "bush_flower": (T, (588, 974, 731, 1068), []),
    "bush": (T, (751, 1002, 878, 1068), []),
    "grass_a": (T, (246, 1017, 335, 1069), []),
    "grass_b": (T, (702, 942, 785, 990), []),
    "rock_mossy": (T, (1293, 953, 1431, 1059), []),
    "ruin_pile": (T, (978, 917, 1171, 1061), []),
    "pillar_broken": (T, (1183, 915, 1296, 1066), []),
    # --- pickups & gimmicks
    "coin_0": (P, (32, 16, 113, 98), []),
    "coin_1": (P, (146, 17, 198, 96), []),
    "coin_2": (P, (238, 17, 269, 97), []),
    "coin_3": (P, (426, 26, 446, 87), []),
    "gem_blue": (P, (618, 20, 683, 94), []),
    "crystal": (P, (547, 20, 583, 94), []),
    "spring_low": (P, (1188, 275, 1284, 363), []),
    "spring_high": (P, (1316, 238, 1421, 363), []),
    "portal_blue": (P, (683, 380, 891, 569), []),
    "portal_gold": (P, (902, 379, 1111, 568), []),
    "goal_gate": (P, (1149, 376, 1432, 569), []),
    "flag_red": (P, (374, 384, 504, 561), []),
    "log_platform": (P, (19, 733, 212, 784), []),
    "conveyor_small": (P, (227, 729, 379, 790), []),
    "swing_chain": (P, (582, 696, 752, 792), []),
    "vine_log": (P, (770, 694, 952, 832), []),
    "cloud_platform": (P, (975, 739, 1134, 792), []),
    "bridge_whole": (P, (15, 840, 221, 925), []),
    "bridge_broken": (P, (243, 841, 399, 916), []),
    "spike_row": (P, (8, 959, 121, 1046), []),
    "spikeball_big": (P, (339, 938, 451, 1058), []),
    "switch_blue": (P, (949, 113, 1055, 217), []),
    "switch_red": (P, (1081, 113, 1187, 217), []),
    "beam_blue": (P, (876, 915, 994, 1054), []),
    "beam_gold": (P, (1014, 943, 1121, 1053), []),
    # --- enemies (animation frames)
    "predator_0": (E, (18, 31, 271, 169), [PILL_PREDATOR]),
    "predator_1": (E, (292, 40, 528, 205), [PILL_PREDATOR]),
    "predator_2": (E, (506, 14, 759, 198), []),
    "predator_3": (E, (755, 11, 1017, 220), []),
    "predator_4": (E, (970, 32, 1194, 210), []),
    "predator_head": (E, (51, 218, 153, 328), []),
    "seed_0": (E, (16, 344, 165, 476), [PILL_SEED]),
    "seed_1": (E, (165, 344, 307, 476), [PILL_SEED]),
    "seed_2": (E, (331, 354, 444, 474), []),
    "seed_3": (E, (467, 360, 583, 474), []),
    "seed_hurt": (E, (1153, 355, 1267, 478), []),
    "bird_0": (E, (16, 515, 190, 612), [PILL_BIRD]),
    "bird_1": (E, (189, 515, 317, 611), []),
    "bird_2": (E, (344, 515, 471, 612), []),
    "bird_3": (E, (498, 517, 649, 616), []),
    "bird_dive": (E, (676, 496, 803, 626), []),
    "mine_0": (E, (26, 652, 130, 763), [PILL_MINE]),
    "mine_1": (E, (160, 652, 294, 764), [PILL_MINE]),
    "mine_glow": (E, (442, 652, 563, 764), []),
    "mine_alert": (E, (578, 630, 704, 762), []),
    "mine_burst": (E, (1120, 650, 1275, 780), []),
    "golem_0": (E, (16, 801, 190, 925), [PILL_GOLEM]),
    "golem_1": (E, (204, 801, 372, 924), []),
    "golem_2": (E, (383, 795, 583, 924), []),
    "golem_stomp": (E, (775, 785, 957, 942), []),
    "turret_0": (E, (16, 961, 160, 1046), [PILL_TURRET]),
    "turret_1": (E, (170, 961, 301, 1046), [PILL_TURRET]),
    "turret_charge": (E, (850, 968, 972, 1071), []),
    "wind_shot": (E, (476, 968, 653, 1053), []),
    # --- background
    "bg_mountains_a": (B, (9, 14, 626, 138), []),
    "bg_mountains_b": (B, (638, 12, 1085, 138), []),
    "bg_hills_a": (B, (9, 156, 435, 249), []),
    "bg_hills_b": (B, (448, 156, 871, 249), []),
    "bg_cloud_big": (B, (1100, 4, 1438, 177), []),
    "bg_cloud_long": (B, (11, 276, 524, 422), []),
    "bg_cloud_bank_a": (B, (10, 999, 471, 1073), []),
    "bg_cloud_bank_b": (B, (484, 971, 1060, 1073), []),
    "bg_cloud_s1": (B, (553, 264, 691, 324), []),
    "bg_cloud_s2": (B, (273, 436, 417, 485), []),
    "bg_island_ruins": (B, (808, 207, 1162, 548), []),
    "bg_island_falls": (B, (1183, 183, 1437, 598), []),
    "bg_island_a": (B, (706, 268, 844, 405), []),
    "bg_island_b": (B, (1033, 632, 1169, 773), []),
    "bg_island_c": (B, (1219, 624, 1388, 793), []),
    "bg_island_d": (B, (884, 148, 969, 238), []),
    "bg_aqueduct": (B, (10, 520, 700, 722), [(10, 680, 160, 722)]),
    "bg_ruins": (B, (219, 725, 751, 918), []),
}


# Single solid objects whose crop also catches slivers of their neighbours.
LARGEST_ONLY = {
    "island_float", "tree_big", "tree_tall", "cliff_a", "cliff_b", "rock_island",
    "slope_island", "bg_island_ruins", "bg_island_falls", "bg_island_a",
    "bg_island_b", "bg_island_c", "bg_island_d", "arch", "pillar", "pillar_vine",
}


def inside(cx, cy, r):
    return r[0] <= cx < r[2] and r[1] <= cy < r[3]


def cut(sheet: np.ndarray, rect, excludes, largest: bool = False) -> Image.Image:
    x0, y0, x1, y1 = rect
    a = sheet[y0:y1, x0:x1].copy()
    alpha = a[..., 3].astype(np.int32)
    solid = alpha >= 128
    for ex in excludes:
        ex0, ey0 = max(ex[0], x0) - x0, max(ex[1], y0) - y0
        ex1, ey1 = min(ex[2], x1) - x0, min(ex[3], y1) - y0
        if ex1 > ex0 and ey1 > ey0:
            solid[ey0:ey1, ex0:ex1] = False
    # Keep only the pieces that belong to this crop: components whose centre
    # lies well inside it, so a neighbour poking over the edge is dropped.
    lab, n = nd.label(solid)
    keep = np.zeros_like(solid)
    if n:
        areas = nd.sum(solid, lab, range(1, n + 1))
        coms = nd.center_of_mass(solid, lab, range(1, n + 1))
        h, w = solid.shape
        inner = (w * 0.04, h * 0.04, w * 0.96, h * 0.96)
        big = max(areas)
        for i, (area, (cy, cx)) in enumerate(zip(areas, coms)):
            if largest and area < big:
                continue
            if area >= max(40, big * 0.004) and inside(cx, cy, inner):
                keep |= lab == i + 1
    # Defringe: every edge pixel takes the colour of the nearest fully opaque
    # pixel, so the neon halo cannot survive in the RGB either.
    core = keep & (alpha >= 250)
    if core.any():
        _, (iy, ix) = nd.distance_transform_edt(~core, return_indices=True)
        rgb = a[..., :3]
        a[..., :3] = rgb[iy, ix]
    edge = keep & ~nd.binary_erosion(keep, iterations=1)
    out_alpha = np.where(keep, 255, 0).astype(np.uint8)
    out_alpha[edge] = 190   # soft enough for linear filtering, above the scissor
    a[..., 3] = out_alpha
    ys, xs = np.nonzero(keep)
    if len(xs) == 0:
        raise SystemExit(f"empty crop {rect}")
    pad = 2
    bx0, by0 = max(0, xs.min() - pad), max(0, ys.min() - pad)
    bx1, by1 = min(a.shape[1], xs.max() + 1 + pad), min(a.shape[0], ys.max() + 1 + pad)
    a = a[by0:by1, bx0:bx1]
    return Image.fromarray(a, "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = {n: np.array(Image.open(SRC / f"{n}.png").convert("RGBA")) for n in (T, P, E, B)}
    for name, (sheet, rect, excludes) in SPRITES.items():
        img = cut(sheets[sheet], rect, excludes, name in LARGEST_ONLY)
        img.save(OUT / f"{name}.png", optimize=True)
    print(f"wrote {len(SPRITES)} sprites to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
