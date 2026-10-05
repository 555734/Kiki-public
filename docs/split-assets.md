# Stage 1-2 through 1-5: split asset integration

Active repository: https://github.com/555734/Kiki-public.git
Base: `6b24c6f21e9988167ad8914691af297099b893f2` (2026-10-04).
Branch: `codex/split-stage-assets`.

The owner provided `Kiki_assets_split.zip` on 2026-10-05. Its 107 PNGs are
stored in `assets/split/1-2` through `1-5`. Backgrounds are preserved; other
images have only transparent outer padding trimmed. No third-party artwork
was added. Unused alternate frames and props are retained for future design.
Reimport with `python tools/integrate_split_assets.py path/to/Kiki_assets_split.zip`
(Pillow required), then run the Godot editor import pass.

## Placement

| Stage | Integration |
| --- | --- |
| 1-2 | Night village backdrop, moss banks, ruin walls, graves, lanterns, fences, thorns, floating and moving platforms, Nightwolf pursuit/stun and Thornmite mode frames, Wisp flyers, skull gate. |
| 1-3 | Vertical sky backdrop, alternating floating islands, columns and arches, mist columns, cloud banks, timed platforms, checkpoint flags, summit gate, bird/Wisp/stone golem frames. World is painted 2D with the existing runner rendering. |
| 1-4 | Coastal backdrop, sand banks, rock islands, piers/bridges, palms and rocks, raft and spring, crab movement, seabirds and purple pursuer. Two Clock-driven pufferfish use the existing mine alert/attack behavior. |
| 1-5 | Molten Crossing replaces the marsh theme: lava backdrop and lethal orange surface, volcanic banks and stepping stones, lavafall scenery, moving/crumbling rock, magma slimes, fire bats, two stomping golems and volcano gate. |

Stage enum values, network codecs and checkpoint positions remain stable.
Existing cooperative gaps and platform/launch requirements are preserved.
Pufferfish and golems use existing enemy protocols and deterministic clocks.
Background foreground strips are excluded at render time so the board's baked
floor does not read as an additional playable route. Terrain source surface
rows are measured from alpha coverage and aligned to each collision top.
The SWAMP enum and `level_swamp_data.gd` filename remain for compatibility,
while player-facing names and Japanese/English menu strings use the volcano.

## Verification

Run headless scenes: `horror_stage_probe`, `skyward_ruins_probe`,
`sea_stage_probe`, `swamp_stage_probe`, `stage_menu_probe`, and
`split_assets_probe` under `res://test/` with `--fixed-fps 60`.
The asset probe checks all 107 textures, cache isolation when switching stages,
puffer hurt areas, and golem patrol support. Existing stage probes exercise
live pursuit, guardian assists, safe spawn ground and lethal water/lava.

Recapture the four menu cards with:
`godot --path . --fixed-fps 60 tools/capture_stage_cards.tscn -- --split-assets-only`
Use a graphics-capable renderer; headless mode cannot capture these images.

The full `run_tests` suite reports the same 34 failures out of 1,181 checks on
both the changed code and the unchanged baseline (identical failure messages).
It reports input/layout/network test failures on
the unchanged public baseline. Its old test calls include `_unhandled_input`
and removed layout dictionary keys. See `build/split-baseline-logic.log` and
`build/split-logic-writable.log`; these failures are outside this asset change.

## Stage 1-6 through 1-8 (0.9.5)

Base public main: `95146a7`. The owner's second zip provides 12 composite
boards; `tools/integrate_late_stage_assets.py` cuts 129 runtime images with
recorded coordinates and blue/purple panel keying. The original zip is kept
outside the repository. No labels or demo player figures become game sprites.

- 1-6: sand banks, ruin arches, palms, crystals, scarab and mummy ground
  patrols, flying birds, sand-sweeping scarabs, golem turret charge, mechanical
  lifts/belts, stone crumble, springs, switches and golden exit portal.
- 1-7: distant clock window, violet stone banks, banners/lamps/rails, charged
  turrets and expanding mines, lift/clock-hand/gear platforms, blinking and
  crumbling ledges, conveyors, wind columns, portals, sigil gates and three
  clock-driven trap types.
- 1-8: distant violet cavern, stone banks, crimson crystals, lamps and mine
  rails, five enemy types with movement/airborne frames, cart lifts, timed
  ledges, conveyors, wind columns, guardian-triggered bridges, rolling rocks,
  dropping stalactites, key, checkpoint flags and exit marker.

Stage enum IDs, networking, collision sizes, Clock phase functions, authored
route and cooperative gate requirements stay stable. Decorations and carts
hang below the true collision top. Cave scenery/terrain retain per-item
culling. The roof still opens to daylight at the existing exit height.

Validation: `desert_stage_probe`, `tower_stage_probe`, `cave_stage_probe`,
`stage_menu_probe`, `versus_play_probe`, `split_assets_probe` (236 images from
both packs), and `check_scripts`. Normal gameplay captures are 1280x720,
including HUD, in `build/landscape/stage-1-{6,7,8}.png`; additional mid-route
captures end in `-detail.png`. The menu cards intentionally remain portrait.
Run `tools/capture_stage_cards.tscn -- --late-assets-only` to recapture them.
