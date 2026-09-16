# Asset provenance

Two sources.

**Supplied painted art.** Sixteen finished PNGs handed over directly.
`tools/import_assets.py` crops each to its alpha bounding box (keeping a
little halo, which is what makes the holograms read as light) and resizes
it on premultiplied pixels to roughly twice its on-screen size. These
override the earlier cut-outs of the same subject:

| file | size | note |
|---|---|---|
| `props/brick.png` | 128x128 | three-brick block |
| `props/pipe.png` | 160x227 | green pipe |
| `props/qblock.png` | 128x119 | star block |
| `props/spikes.png` | 384x95 | five-spike plate, tiled along a hazard |
| `props/signpost.png` | 168x203 | wooden direction sign |
| `props/coin.png` | 112x113 | gauge pickup |
| `terrain/ground_block.png` | 384x169 | grass over strata; the discrete slabs |
| `entities/laser_beam.png` | 512x59 | beam with a bright head |
| `entities/spring.png` | 152x131 | bounce pad |
| `entities/hit_burst.png` | 256x242 | shot impact |
| `holograms/platform.png` | 384x76 | the guardian's slab |
| `holograms/wall.png` | 96x239 | the guardian's panel |
| `holograms/warp_gate.png` | 232x286 | the warp gate, slot 4 |
| `scope/ring.png` | 512x501 | optic rim |
| `scope/crosshair.png` | 256x261 | reticle |
| `bg/parallax.png` | 1280x720 | the backdrop, mirror-tiled |

**Cut from the concept mockups.** Everything below was lifted out of one of
the three mockups supplied with the brief, by `tools/extract_assets.py`.
Re-run that script to regenerate; the crop boxes live in its `ASSETS`
table. It will not overwrite anything in the list above.

| file | mockup | crop (x0,y0,x1,y1) | method | size | note |
|---|---|---|---|---|---|
| `characters/runner_run.png` | m2 | `(656, 424, 750, 526)` | cut | 73x76 | running, clear sky |
| `characters/runner_jump.png` | m1 | `(776, 300, 906, 446)` | cut | 117x116 | mid-jump, clear sky |
| `characters/walker.png` | m2 | `(1356, 460, 1444, 552)` | cut | 74x78 | on grass, unobstructed |
| `holograms/platform.png` | m1 | `(662, 424, 968, 502)` | cut | 281x53 | solid slab, face-on |
| `holograms/wall.png` | m1 | `(0, 0, 0, 0)` | derive | 53x281 | platform rotated 90deg |
| `props/pipe.png` | m3 | `(470, 430, 604, 524)` | cut | 101x82 | zoomed, highest res |
| `props/qblock.png` | m3 | `(332, 332, 448, 402)` | cut | 54x52 | zoomed |
| `props/brick.png` | m1 | `(192, 318, 290, 420)` | cut | 67x69 | single brick block, sky margin |
| `props/spikes.png` | m3 | `(606, 626, 916, 694)` | cut | 306x53 | zoomed spike row |
| `props/fence.png` | m1 | `(218, 484, 316, 550)` | key | 98x66 | wooden rail on grass |
| `props/flowers.png` | m1 | `(134, 474, 216, 536)` | cut | 80x56 | daisies |
| `terrain/grass_cap.png` | m2 | `(1186, 526, 1360, 606)` | rect | 174x80 | grass band, prop-free plateau |
| `terrain/dirt_body.png` | m1 | `(60, 616, 520, 756)` | rect | 460x140 | dirt strata, measured |
| `terrain/dirt_body_alt.png` | m1 | `(60, 606, 460, 700)` | rect | 400x94 | second strata variation |
| `bg/cloud_a.png` | m1 | `(440, 18, 668, 122)` | key | 218x104 |  |
| `bg/cloud_b.png` | m1 | `(1080, 146, 1312, 244)` | key | 204x74 |  |
| `bg/cloud_c.png` | m1 | `(176, 206, 352, 294)` | key | 167x88 |  |
| `bg/castle.png` | m2 | `(1410, 120, 1624, 306)` | key | 214x164 | distant skyline |
| `ui/panel_p1.png` | m3 | `(0, 4, 316, 96)` | rect | 316x92 | P1 plate with hearts |
| `ui/panel_p2.png` | m3 | `(4, 104, 330, 196)` | rect | 326x92 | P2 plate |
| `ui/portrait_lira.png` | m3 | `(10, 10, 104, 92)` | rect | 94x82 |  |
| `ui/portrait_orion.png` | m3 | `(14, 110, 108, 192)` | rect | 94x82 |  |
| `ui/stage_plate.png` | m1 | `(1336, 8, 1672, 100)` | rect | 336x92 | stage name + objective |
| `ui/ability_bar.png` | m1 | `(586, 738, 1084, 924)` | rect | 498x186 | unselected state |
| `ui/icon_platform.png` | m3 | `(676, 800, 762, 880)` | key | 84x80 | lit frame |
| `ui/icon_wall.png` | m3 | `(794, 800, 880, 880)` | key | 81x80 |  |
| `ui/icon_snipe.png` | m3 | `(912, 800, 998, 880)` | key | 86x80 | selected state |
| `ui/heart.png` | m3 | `(123, 46, 164, 83)` | key | 39x35 | single filled heart |
| `scope/zoom_slider.png` | m3 | `(1490, 272, 1560, 552)` | rect | 70x280 |  |
| `scope/cartridge.png` | m3 | `(1404, 640, 1604, 796)` | key | 67x69 | bullet glyph for the fire button |
| `scope/btn_reticle.png` | m3 | `(1556, 808, 1648, 894)` | cut | 65x65 |  |

Mockups: `m1` solid holograms + mid-jump runner, `m2` dashed previews +
clear walker, `m3` full-screen scope (~1.5x scale, best for detail).

**Supplied painted art, stage 1-2.** A second hand-over, for THE HOLLOW
OUTSKIRTS. These replaced the hand-written SVG placeholders of the same
subjects, which are gone; the three horror SVGs still in `horror/` are the
ones nothing was painted for.

| file | size | replaced |
|---|---|---|
| `bg/horror_stage_1_2.jpg` | 1280x720 | `bg/horror_stage_1_2.svg` |
| `horror/pursuer.png` | 320x427 | `horror/pursuer.svg` |
| `horror/gate.png` | 384x480 | `horror/gate.svg`, the stage's goal |
| `horror/fence.png` | 512x377 | `horror/fence.svg` |
| `horror/thorns.png` | 512x372 | `horror/thorns.svg`, the hazard strip |
| `horror/cart.png` | 512x374 | drawn by hand in `decor.gd` |
| `horror/crate.png` | 256x260 | drawn by hand in `decor.gd` |
| `horror/grave.png` | 200x276 | drawn by hand in `decor.gd` |
| `horror/lantern.png` | 240x322 | borrowed the checkpoint's lamp |
| `horror/puddle.png` | 512x379 | drawn by hand in `decor.gd` |

The hand-over also carried `background_q55/q60/q65.jpg` (the same backdrop
at lower quality) and `gate_small.png`. Neither is in the project: one
backdrop is enough at 68KB next to a 977KB `parallax.png`, and 1-2 has no
gate gimmick for the small one to be.

`horror/mud_tile.svg` and `horror/moss_cap.svg` were recoloured to suit the
new backdrop -- colour values only, the same shapes. Against a night
graveyard the old warm sand read as a beach.

Unlike the first hand-over these are used at their supplied resolution and
have not been through `tools/import_assets.py`; they arrived already
cropped to their subjects.
