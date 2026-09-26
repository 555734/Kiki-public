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
OUTSKIRTS. **Half of it has since been rolled back** -- see the note under the
table; the five rows marked *(reverted)* are no longer in the project and their
SVG placeholders are back in their place.

| file | size | replaced |
|---|---|---|
| ~~`bg/horror_stage_1_2.jpg`~~ *(reverted)* | 1280x720 | `bg/horror_stage_1_2.svg` |
| ~~`horror/pursuer.png`~~ *(reverted)* | 320x427 | `horror/pursuer.svg` |
| ~~`horror/gate.png`~~ *(reverted)* | 384x480 | `horror/gate.svg`, the stage's goal |
| ~~`horror/fence.png`~~ *(reverted)* | 512x377 | `horror/fence.svg` |
| ~~`horror/thorns.png`~~ *(reverted)* | 512x372 | `horror/thorns.svg`, the hazard strip |
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
graveyard the old warm sand read as a beach. The recolour was **kept**.

**The reversal.** The five subjects that had an SVG placeholder before this
hand-over are back on those placeholders, restored from `312f8a0^`, and the
paintings that replaced them are deleted along with their `.import` files.
`Art.MANIFEST` points `horror_panorama`, `horror_pursuer`, `horror_goal`,
`horror_fence` and `horror_thorns` at the `.svg` files again.

Only those five. The other five rows above (`cart`, `crate`, `grave`,
`lantern`, `puddle`) were never SVGs -- `decor.gd` drew them by hand and there
is nothing to go back to -- so those paintings stay, as does the tile recolour
above. That split is deliberate: this reverts a replacement, not the whole
hand-over.

Nothing else moves with them. The SVG set has no tracked `.import` (the
repository ignores `*.svg.import`, because every build path runs its own
`--editor --import` pass) and `test/horror_stage_probe.gd` walks the
`horror_*` keys out of the manifest rather than naming files, so it follows
the manifest wherever it points.

Unlike the first hand-over these are used at their supplied resolution and
have not been through `tools/import_assets.py`; they arrived already
cropped to their subjects.

**Supplied painted art, stages 1-B and 1-S.** A third hand-over: thirteen
paintings for THE KEEPER and nine for THE OPEN SKY, generated from the
prompts in `docs/art-prompts-keeper.md` and `docs/art-prompts-sky.md`.
Both stages were designed, measured and shipped with none of them --
`Art.PENDING` held all twenty-two keys, and every dimension in either stage
was taken off the vector fallbacks. These are a replacement, not a
foundation.

Brought in by `tools/import_assets.py --stage-art`, whose `STAGE_PLAN` table
holds the sizes and the reason for each. Three modes beyond the first
hand-over's crop-and-shrink:

* **box** -- the sprite is drawn with `Art.draw_stretched` into a rect the
  physics owns (the barricade's 70x128 collider, the shockwave's 110x48
  hazard, the gate's 56x420 slot). It is resampled to exactly twice that
  rect, so the painting fills the box the game actually uses. A picture that
  stops short of its collider is a lie about where the edge is.
* **tile** -- seamless, so it is never cropped and is resized as the middle
  of a 3x3 wrap of itself. Plain LANCZOS at an edge has nothing beyond it to
  sample, leans inward, and the tile stops meeting itself.
* **poses** -- the Keeper's four states go on one canvas at one scale,
  aligned by the feet, exactly like the runner's eight. The four boards put
  the floor in four different places (45, 96, 149 and 62px up from the
  bottom edge); left alone, the boss grows and shrinks as it braces.

| file | size | note |
|---|---|---|
| `keeper/panorama.jpg` | 1280x720 | the arena backdrop |
| `keeper/keeper_stand.png` | 336x242 | one canvas, one scale, feet aligned |
| `keeper/keeper_brace.png` | 336x242 | " |
| `keeper/keeper_charge.png` | 336x242 | " |
| `keeper/keeper_reel.png` | 336x242 | " |
| `keeper/core.png` | 128x128 | the weak point, halo kept |
| `keeper/barricade.png` | 140x256 | drawn into 70x128 |
| `keeper/barricade_rubble.png` | 168x77 | the stump after it is broken |
| `keeper/shockwave.png` | 220x96 | drawn into 110x48, mirrored by direction |
| `keeper/portcullis.png` | 112x840 | drawn into the gate's 56x420 |
| `keeper/flagstone.png` | 132x132 | seamless, laid at `DIRT_TILE_H` |
| `keeper/brazier.png` | 130x303 | decor, drawn 150px tall |
| `keeper/rubble.png` | 460x149 | decor, drawn 74px tall |
| `sky/panorama.jpg` | 1280x720 | dawn cloud sea |
| `sky/island_tile.png` | 132x132 | seamless island cross-section |
| `sky/island_cap.png` | 1257x92 | the moss band along an island's top |
| `sky/keel.png` | 480x298 | the taper under an island, chains included |
| `sky/updraft.png` | 240x720 | the column; 1:1, the only one not at 2x |
| `sky/streamer.png` | 200x385 | landmark, drawn 190px tall |
| `sky/arch.png` | 440x520 | landmark, drawn into 220x260 |
| `sky/beacon.png` | 120x488 | the goal |
| `sky/flyer.png` | 128x90 | the stage's only enemy |

Three drawing changes came out of looking at the result rather than at the
files:

* `sky/keel.png` has its own hanging chains, so `decor.gd` no longer draws
  the vector ones over it -- two sets, half a link apart.
* `updraft.gd` now stretches its column instead of tiling it: the stage has
  two column shapes, and tiled at the taller one's scale the shorter one lost
  its right-hand edge -- which is the bright part that says where the lift
  ends.
* `sky_canvas.gd` now reads the strip drawn under the painted backdrop out of
  the backdrop itself. `PANORAMA_FLOOR` was a constant sampled from 1-1's
  `bg/parallax.png` -- an earth brown -- and it was right for exactly as long
  as there was one backdrop. Under 1-S's dawn cloud sea it drew a band of soil
  across the bottom of the sky. Nothing in the test suite can see this: it is
  a colour, in a strip that only appears when the camera is low enough, and it
  took a screenshot.

**Supplied painted art, stage 1-1.** A fourth hand-over, and the first to
arrive as **atlas sheets** rather than one file per subject: nine boards
carrying about a hundred separate drawings. Brought in by
`tools/import_assets.py --one-one`, whose `ONE_ONE_PLAN` holds every crop box.

Finding the subjects was machine-assisted and human-checked. Connected-
component labelling on the alpha channel separates most of them, but it cannot
tell a tree from the bush touching it -- on `03_decorations` it merged six
subjects into one -- and it splits a starburst into a core plus three rays that
do not touch it. So the boxes were read off a numbered contact sheet by eye and
written down, which is why they are a table rather than a detection pass.

| key | sheet | note |
|---|---|---|
| `parallax` | 01_background | the whole board, 1280x720 |
| `dirt_tile`, `grass_tile` | 02_terrain_tiles | cut from the middle of the long slab -- see below |
| `ground_block` | 02_terrain_tiles | a whole grass-topped block; `crumbling_floor.gd` stretches it |
| `runner_*` (8) | 04_player_sprites | nineteen frames on the sheet, eight named poses here |
| `walker`, `walker_spiky` | 05_enemy_sprites | two ground enemies arrived; see `Walker.skin` |
| `qblock`, `brick`, `coin`, `moving_platform` | 06_items_blocks_platform | |
| `goal` | 07_goal_gate | |
| `tree`, `fence`, `flowers` | 03_decorations | |
| `signpost`, `heart` | 08_ui_and_signs | |
| `hit_burst` | 09_effects_and_misc | the union of four components |

**The terrain needed measuring, not cropping.** The sheet holds thirteen
finished slabs; `terrain.gd` calls `Art.draw_tiled()` and repeats a seamless
texture across a rect of any width. Tiling a finished slab would repeat its
rounded ends forever. The two tiles are therefore cut from the MIDDLE of the
816px slab, and the window was chosen by measurement: the slab's own left and
right edges differ by 65x its internal grain, while this window's differ by
1.9x (dirt) and 1.4x (grass). The seamless tile that was already in the
repository measures 1.1x, so the cut is in the same class. Neither tile is
resized, because a resize would undo the property they were cut for.

The grass tile's crop starts 28 rows ABOVE the grass, in empty space, and that
was found by a test rather than by looking. `terrain.gd` lifts the cap by
`Balance.GRASS_LIP` so the tile's solid part lands on the collision surface and
whatever is above it overhangs; the old tile spent its top quarter on feathered
blade tips, while this painting has a hard silhouette -- measured, it goes from
0% to 95% opaque in ONE row. So the quarter is transparent headroom instead of
tips. The geometry is the same either way and the grass starts exactly at the
surface; cut tight to the paint, the tile is solid from its first row and the
grass sinks a quarter of its height into the ground. `run_tests` compares the
artwork to the constant and failed at 0.0px against a required 11.5; the crop
above measures 11.6.

**The poses were matched by meaning, not by frame order.** The mapping was made
with the sheet beside the eight poses already in use: `land` is a deep crouch
here, `dash` is a low forward lean, `reach` is an arm extended forward. Frame
order is an animation's order, not this game's. All eight go on one canvas at
one scale aligned by the feet, as the first hand-over's poses do, which moved
`Balance.RUNNER_POSE_HEADROOM` from 1.125 to 1.0625.

**Not covered by this hand-over.** Roughly thirty registered keys have no
drawing on these sheets and keep the art they had: the guardian's `platform`,
`wall` and `warp_gate`, the whole optic (`scope_ring`, `crosshair`,
`zoom_slider`, `cartridge`, `btn_reticle`), `spikes`, `spring`, `pipe`,
`turret`, `flyer`, `projectile`, the lasers, the switches, the checkpoints,
`cloud_a/b/c`, `castle`, the portraits and the HUD icons. The result is
deliberately a mixed set.

**Arrived with no home.** Ten number tiles, four clock faces, a second signpost,
the enemies' shell and flattened frames, a dust puff, a sparkle, and about ten
small plants and rocks. Nothing in the registry asks for them.

`grass_cap`, `dirt_body` and `dirt_body_alt` were left alone: they are
registered but drawn from nowhere, so replacing them would have been work
nobody can see.


**Original stage 1-2 runtime SVGs (2026-09-21).** These were authored for
the 1-2 redesign from the approved character/environment direction rather than
cropped from a third-party game or from the earlier mockups. They are transparent
runtime assets and intentionally use simple 2.5D planes so silhouettes stay
readable on a phone.

| file | purpose |
|---|---|
| `horror/thornmite.svg` | low quadruped rock enemy; replaces the rejected round walker silhouette |
| `horror/wisp.svg` | dark airborne Wisp skin for the existing Flyer behaviour |
| `horror/ruin_block.svg` | beveled dark masonry used by collidable floating block rows |
# Stage 1-3: THE SKYWARD RUINS

- `stage_1_3/reference/platforms.png`, `terrain.png`, `enemies.png`, and
  `backgrounds.png` were supplied by the project owner on 2026-09-23 as visual
  reference sheets. They are not read as gameplay instructions and are not
  rendered as a replacement for the 3D world.
- `stage_1_3/preview.png` was generated for this project with OpenAI's built-in
  image generation tool on 2026-09-23, using those four owner-supplied sheets
  as style references. Prompt: "Create a polished 16:9 stage-selection preview
  of a bright vertical ascent through floating grassy islands and pale stone
  sky ruins toward a summit gate, with a purple smoky predator rising from
  below and cyan hologram platforms suggesting two-player cooperation; colorful
  low-poly 3D game key art; no text, logo, UI, watermark, or black background."
- Since the 1-3 redesign, the four owner-supplied sheets ARE used at runtime:
  `tools/extract-stage-1-3.py` cuts them into `stage_1_3/sprites/*.png`
  (islands, ruins, trees, waterfalls, bridges, platforms, pickups, portals,
  enemy animation frames and background layers), removes the coloured halo
  the sheets were exported with and tightens alpha for alpha-scissor quads.
  `src/render/three/sky_sprites.gd` places them in the 3D world and
  `src/render/sky_canvas.gd` layers the background pieces. Re-run the script
  to regenerate them; the crop rectangles are listed in it by name.
- `entities/flyer.png` (a winged chestnut that read as a Goomba) was removed.
  The `flyer` key now points at `entities/flyer_bird.png`: the blue sky-fish
  frame `stage_1_3/sprites/bird_0.png`, mirrored to face left like the rest
  of the painted set.
- Other stages' terrain and props remain original deterministic
  vertex-coloured recipes in `src/render/three/`.

## Stage 1-4 "THE SUNLIT COAST" (`stage_1_4/`)

- Owner-supplied art pack `Kiki_1-4_Sea_Assets.zip` (first bright ocean
  concept, generated images). `tools/extract-stage-1-4.py` prepares it: it
  removes the slivers of neighbouring sprites the pack's cut-outs carry, trims
  each sprite, mirrors the seabird to face left like the rest of the painted
  set, stores the backdrop as JPEG, cuts a repeating sand tile and grass cap
  from the painted blocks, cuts the raft from the pier deck, and composes the
  start-menu `preview.jpg` from the pieces.
- Not used: `surf_foam.png` and `sand_right_edge.png` are empty files in the
  pack (the foam is drawn by `src/render/sea_water.gd`), `rope_fence.png` holds
  only two post tops, the three runner poses (the runner stays LIRA), and the
  concept board, which the pack says is not for in-game use.

## Stage 1-5 "THE POISON MARSH" (`stage_1_5/`)

- `concept_board.png`, `concept_board_v2.png`, and `concept_board_v3.png` were
  generated with OpenAI's built-in image generation tool in this task. The
  owner-provided platform-game screenshot served only as a texture/style
  reference for v2; v3 adds moderate material depth. The boards are design
  references, and v3 supplies the stage-selection preview's scene area.
- `distant_swamp.png` is a separately generated distant background, with no
  gameplay geometry. `props_atlas.png` is a separately generated transparent
  2x2 sheet of a willow, mushrooms, reeds, and a boulder. Both were generated
  with the same built-in tool from the approved v3 direction.
- Walkable ground and stones reuse the existing `sky/island_tile.png` and
  `sky/island_cap.png` textures with swamp tinting; the poisonous water, bridge,
  raft, and falling floor are drawn at runtime. No image from the owner's
  screenshot is copied into the game.
