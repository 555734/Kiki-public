class_name Art
extends RefCounted
## Texture registry shared by every stage. Horror-specific aliases are resolved
## here so gameplay classes stay the same while stage 1-2 changes visual skin.

const BASE := "res://assets/"

const MANIFEST := {
	"s17_pendulum_ball": "split/1-7/gimmicks/pendulum_ball.png",
	"s17_piston_head": "split/1-7/gimmicks/piston_head.png",
	"s16_terrain_arch": "split/1-6/background/arch.png",
	"s16_background": "split/1-6/background/background.png",
	"s16_terrain_broken_arch": "split/1-6/background/broken_arch.png",
	"s16_terrain_broken_column": "split/1-6/background/broken_column.png",
	"s16_terrain_column": "split/1-6/background/column.png",
	"s16_terrain_ground": "split/1-6/background/ground.png",
	"s16_terrain_rubble": "split/1-6/background/rubble.png",
	"s16_terrain_stone": "split/1-6/background/stone.png",
	"s16_bird_0": "split/1-6/enemies/bird_0.png",
	"s16_bird_1": "split/1-6/enemies/bird_1.png",
	"s16_bird_2": "split/1-6/enemies/bird_2.png",
	"s16_bird_3": "split/1-6/enemies/bird_3.png",
	"s16_bird_4": "split/1-6/enemies/bird_4.png",
	"s16_bird_5": "split/1-6/enemies/bird_5.png",
	"s16_golem_0": "split/1-6/enemies/golem_0.png",
	"s16_golem_1": "split/1-6/enemies/golem_1.png",
	"s16_golem_2": "split/1-6/enemies/golem_2.png",
	"s16_golem_3": "split/1-6/enemies/golem_3.png",
	"s16_golem_4": "split/1-6/enemies/golem_4.png",
	"s16_golem_5": "split/1-6/enemies/golem_5.png",
	"s16_mummy_0": "split/1-6/enemies/mummy_0.png",
	"s16_mummy_1": "split/1-6/enemies/mummy_1.png",
	"s16_mummy_2": "split/1-6/enemies/mummy_2.png",
	"s16_mummy_3": "split/1-6/enemies/mummy_3.png",
	"s16_mummy_4": "split/1-6/enemies/mummy_4.png",
	"s16_mummy_5": "split/1-6/enemies/mummy_5.png",
	"s16_mummy_6": "split/1-6/enemies/mummy_6.png",
	"s16_scarab_0": "split/1-6/enemies/scarab_0.png",
	"s16_scarab_1": "split/1-6/enemies/scarab_1.png",
	"s16_scarab_2": "split/1-6/enemies/scarab_2.png",
	"s16_scarab_3": "split/1-6/enemies/scarab_3.png",
	"s16_scarab_4": "split/1-6/enemies/scarab_4.png",
	"s16_scarab_5": "split/1-6/enemies/scarab_5.png",
	"s16_bridge": "split/1-6/gimmicks/bridge.png",
	"s16_bush": "split/1-6/gimmicks/bush.png",
	"s16_checkpoint_off": "split/1-6/gimmicks/checkpoint_off.png",
	"s16_checkpoint_on": "split/1-6/gimmicks/checkpoint_on.png",
	"s16_conveyor": "split/1-6/gimmicks/conveyor.png",
	"s16_crumble": "split/1-6/gimmicks/crumble.png",
	"s16_crystal": "split/1-6/gimmicks/crystal.png",
	"s16_gate": "split/1-6/gimmicks/gate.png",
	"s16_goal": "split/1-6/gimmicks/goal.png",
	"s16_grass": "split/1-6/gimmicks/grass.png",
	"s16_key": "split/1-6/gimmicks/key.png",
	"s16_lift": "split/1-6/gimmicks/lift.png",
	"s16_palm": "split/1-6/gimmicks/palm.png",
	"s16_palm_small": "split/1-6/gimmicks/palm_small.png",
	"s16_rocks": "split/1-6/gimmicks/rocks.png",
	"s16_spikes": "split/1-6/gimmicks/spikes.png",
	"s16_spring": "split/1-6/gimmicks/spring.png",
	"s16_switch_off": "split/1-6/gimmicks/switch_off.png",
	"s16_switch_on": "split/1-6/gimmicks/switch_on.png",
	"s16_updraft": "split/1-6/gimmicks/updraft.png",
	"s17_background": "split/1-7/background/background.png",
	"s17_terrain_banner": "split/1-7/background/banner.png",
	"s17_terrain_chain": "split/1-7/background/chain.png",
	"s17_terrain_clock": "split/1-7/background/clock.png",
	"s17_terrain_column": "split/1-7/background/column.png",
	"s17_terrain_gear": "split/1-7/background/gear.png",
	"s17_terrain_ground": "split/1-7/background/ground.png",
	"s17_terrain_lamp": "split/1-7/background/lamp.png",
	"s17_terrain_platform": "split/1-7/background/platform.png",
	"s17_terrain_wall": "split/1-7/background/wall.png",
	"s17_terrain_window": "split/1-7/background/window.png",
	"s17_mine_alert": "split/1-7/enemies/mine_alert.png",
	"s17_mine_attack": "split/1-7/enemies/mine_attack.png",
	"s17_mine_idle": "split/1-7/enemies/mine_idle.png",
	"s17_turret_alert": "split/1-7/enemies/turret_alert.png",
	"s17_turret_broken": "split/1-7/enemies/turret_broken.png",
	"s17_turret_fire": "split/1-7/enemies/turret_fire.png",
	"s17_turret_idle": "split/1-7/enemies/turret_idle.png",
	"s17_blink": "split/1-7/gimmicks/blink.png",
	"s17_clock_hand": "split/1-7/gimmicks/clock_hand.png",
	"s17_conveyor": "split/1-7/gimmicks/conveyor.png",
	"s17_crumble": "split/1-7/gimmicks/crumble.png",
	"s17_gate": "split/1-7/gimmicks/gate.png",
	"s17_gear": "split/1-7/gimmicks/gear.png",
	"s17_lift": "split/1-7/gimmicks/lift.png",
	"s17_pendulum": "split/1-7/gimmicks/pendulum.png",
	"s17_piston": "split/1-7/gimmicks/piston.png",
	"s17_rail": "split/1-7/gimmicks/rail.png",
	"s17_spikes": "split/1-7/gimmicks/spikes.png",
	"s17_spring": "split/1-7/gimmicks/spring.png",
	"s17_switch": "split/1-7/gimmicks/switch.png",
	"s17_updraft": "split/1-7/gimmicks/updraft.png",
	"s17_warp": "split/1-7/gimmicks/warp.png",
	"s17_warp_exit": "split/1-7/gimmicks/warp_exit.png",
	"s18_background": "split/1-8/background/background.png",
	"s18_terrain_bridge": "split/1-8/background/bridge.png",
	"s18_terrain_crystal": "split/1-8/background/crystal.png",
	"s18_terrain_crystal_small": "split/1-8/background/crystal_small.png",
	"s18_terrain_distant": "split/1-8/background/distant.png",
	"s18_terrain_ground": "split/1-8/background/ground.png",
	"s18_terrain_lamp": "split/1-8/background/lamp.png",
	"s18_terrain_platform": "split/1-8/background/platform.png",
	"s18_terrain_stalactite": "split/1-8/background/stalactite.png",
	"s18_terrain_wall": "split/1-8/background/wall.png",
	"s18_terrain_waterfall": "split/1-8/background/waterfall.png",
	"s18_bat_attack": "split/1-8/enemies/bat_attack.png",
	"s18_bat_idle": "split/1-8/enemies/bat_idle.png",
	"s18_bat_move": "split/1-8/enemies/bat_move.png",
	"s18_beetle_attack": "split/1-8/enemies/beetle_attack.png",
	"s18_beetle_idle": "split/1-8/enemies/beetle_idle.png",
	"s18_beetle_move": "split/1-8/enemies/beetle_move.png",
	"s18_burrower_idle": "split/1-8/enemies/burrower_idle.png",
	"s18_burrower_rise": "split/1-8/enemies/burrower_rise.png",
	"s18_mushroom_idle": "split/1-8/enemies/mushroom_idle.png",
	"s18_mushroom_jump": "split/1-8/enemies/mushroom_jump.png",
	"s18_mushroom_move": "split/1-8/enemies/mushroom_move.png",
	"s18_slime_idle": "split/1-8/enemies/slime_idle.png",
	"s18_slime_jump": "split/1-8/enemies/slime_jump.png",
	"s18_slime_move": "split/1-8/enemies/slime_move.png",
	"s18_blink": "split/1-8/gimmicks/blink.png",
	"s18_boulder": "split/1-8/gimmicks/boulder.png",
	"s18_checkpoint": "split/1-8/gimmicks/checkpoint.png",
	"s18_conveyor": "split/1-8/gimmicks/conveyor.png",
	"s18_crumble": "split/1-8/gimmicks/crumble.png",
	"s18_crystal": "split/1-8/gimmicks/crystal.png",
	"s18_goal": "split/1-8/gimmicks/goal.png",
	"s18_key": "split/1-8/gimmicks/key.png",
	"s18_lift": "split/1-8/gimmicks/lift.png",
	"s18_rail": "split/1-8/gimmicks/rail.png",
	"s18_spring": "split/1-8/gimmicks/spring.png",
	"s18_stalactite": "split/1-8/gimmicks/stalactite.png",
	"s18_switch": "split/1-8/gimmicks/switch.png",
	"s18_switch_bridge": "split/1-8/gimmicks/switch_bridge.png",
	"s18_updraft": "split/1-8/gimmicks/updraft.png",
	# Owner supplied split pack; see docs/split-assets.md.
	"s12_background": "split/1-2/background/background.png",
	"s12_nightwolf_chase": "split/1-2/enemies/nightwolf_chase.png",
	"s12_nightwolf_idle": "split/1-2/enemies/nightwolf_idle.png",
	"s12_thornmite_attack": "split/1-2/enemies/thornmite_attack.png",
	"s12_thornmite_idle": "split/1-2/enemies/thornmite_idle.png",
	"s12_thornmite_move": "split/1-2/enemies/thornmite_move.png",
	"s12_wisp_attack": "split/1-2/enemies/wisp_attack.png",
	"s12_wisp_idle": "split/1-2/enemies/wisp_idle.png",
	"s12_wisp_move": "split/1-2/enemies/wisp_move.png",
	"s12_broken_bridge": "split/1-2/gimmicks/broken_bridge.png",
	"s12_broken_fence": "split/1-2/gimmicks/broken_fence.png",
	"s12_dead_tree": "split/1-2/gimmicks/dead_tree.png",
	"s12_floating_ground_a": "split/1-2/gimmicks/floating_ground_a.png",
	"s12_floating_ground_b": "split/1-2/gimmicks/floating_ground_b.png",
	"s12_goal_gate": "split/1-2/gimmicks/goal_gate.png",
	"s12_grave": "split/1-2/gimmicks/grave.png",
	"s12_ground_long_a": "split/1-2/gimmicks/ground_long_a.png",
	"s12_ground_long_b": "split/1-2/gimmicks/ground_long_b.png",
	"s12_ground_short": "split/1-2/gimmicks/ground_short.png",
	"s12_lantern": "split/1-2/gimmicks/lantern.png",
	"s12_moving_platform": "split/1-2/gimmicks/moving_platform.png",
	"s12_puddle": "split/1-2/gimmicks/puddle.png",
	"s12_ruin_wall_a": "split/1-2/gimmicks/ruin_wall_a.png",
	"s12_ruin_wall_b": "split/1-2/gimmicks/ruin_wall_b.png",
	"s12_slope_ground": "split/1-2/gimmicks/slope_ground.png",
	"s12_thorn_hazard": "split/1-2/gimmicks/thorn_hazard.png",
	"s13_background": "split/1-3/background/background.png",
	"s13_golem_attack": "split/1-3/enemies/golem_attack.png",
	"s13_golem_idle": "split/1-3/enemies/golem_idle.png",
	"s13_golem_move": "split/1-3/enemies/golem_move.png",
	"s13_sky_bird_attack": "split/1-3/enemies/sky_bird_attack.png",
	"s13_sky_bird_dive": "split/1-3/enemies/sky_bird_dive.png",
	"s13_sky_bird_idle": "split/1-3/enemies/sky_bird_idle.png",
	"s13_wisp_attack": "split/1-3/enemies/wisp_attack.png",
	"s13_wisp_idle": "split/1-3/enemies/wisp_idle.png",
	"s13_wisp_move": "split/1-3/enemies/wisp_move.png",
	"s13_sky_asset_01": "split/1-3/gimmicks/sky_asset_01.png",
	"s13_sky_asset_02": "split/1-3/gimmicks/sky_asset_02.png",
	"s13_sky_asset_03": "split/1-3/gimmicks/sky_asset_03.png",
	"s13_sky_asset_04": "split/1-3/gimmicks/sky_asset_04.png",
	"s13_sky_asset_05": "split/1-3/gimmicks/sky_asset_05.png",
	"s13_sky_asset_06": "split/1-3/gimmicks/sky_asset_06.png",
	"s13_sky_asset_07": "split/1-3/gimmicks/sky_asset_07.png",
	"s13_sky_asset_08": "split/1-3/gimmicks/sky_asset_08.png",
	"s13_sky_asset_09": "split/1-3/gimmicks/sky_asset_09.png",
	"s13_sky_asset_10": "split/1-3/gimmicks/sky_asset_10.png",
	"s13_sky_asset_11": "split/1-3/gimmicks/sky_asset_11.png",
	"s13_sky_asset_12": "split/1-3/gimmicks/sky_asset_12.png",
	"s13_sky_asset_13": "split/1-3/gimmicks/sky_asset_13.png",
	"s13_sky_asset_14": "split/1-3/gimmicks/sky_asset_14.png",
	"s13_sky_asset_15": "split/1-3/gimmicks/sky_asset_15.png",
	"s13_sky_asset_16": "split/1-3/gimmicks/sky_asset_16.png",
	"s13_sky_asset_17": "split/1-3/gimmicks/sky_asset_17.png",
	"s13_sky_asset_18": "split/1-3/gimmicks/sky_asset_18.png",
	"s14_background": "split/1-4/background/background.png",
	"s14_puffer_alert": "split/1-4/enemies/puffer_alert.png",
	"s14_puffer_attack": "split/1-4/enemies/puffer_attack.png",
	"s14_puffer_idle": "split/1-4/enemies/puffer_idle.png",
	"s14_purple_pursuer_chase": "split/1-4/enemies/purple_pursuer_chase.png",
	"s14_purple_pursuer_idle": "split/1-4/enemies/purple_pursuer_idle.png",
	"s14_purple_pursuer_rise": "split/1-4/enemies/purple_pursuer_rise.png",
	"s14_sea_crab_hide": "split/1-4/enemies/sea_crab_hide.png",
	"s14_sea_crab_idle": "split/1-4/enemies/sea_crab_idle.png",
	"s14_sea_crab_move": "split/1-4/enemies/sea_crab_move.png",
	"s14_seabird_attack": "split/1-4/enemies/seabird_attack.png",
	"s14_seabird_dive": "split/1-4/enemies/seabird_dive.png",
	"s14_seabird_idle": "split/1-4/enemies/seabird_idle.png",
	"s14_coast_asset_01": "split/1-4/gimmicks/coast_asset_01.png",
	"s14_coast_asset_02": "split/1-4/gimmicks/coast_asset_02.png",
	"s14_coast_asset_03": "split/1-4/gimmicks/coast_asset_03.png",
	"s14_coast_asset_04": "split/1-4/gimmicks/coast_asset_04.png",
	"s14_coast_asset_05": "split/1-4/gimmicks/coast_asset_05.png",
	"s14_coast_asset_06": "split/1-4/gimmicks/coast_asset_06.png",
	"s14_coast_asset_07": "split/1-4/gimmicks/coast_asset_07.png",
	"s14_coast_asset_08": "split/1-4/gimmicks/coast_asset_08.png",
	"s14_coast_asset_09": "split/1-4/gimmicks/coast_asset_09.png",
	"s14_coast_asset_10": "split/1-4/gimmicks/coast_asset_10.png",
	"s14_coast_asset_11": "split/1-4/gimmicks/coast_asset_11.png",
	"s14_coast_asset_12": "split/1-4/gimmicks/coast_asset_12.png",
	"s14_coast_asset_13": "split/1-4/gimmicks/coast_asset_13.png",
	"s14_coast_asset_14": "split/1-4/gimmicks/coast_asset_14.png",
	"s14_coast_asset_15": "split/1-4/gimmicks/coast_asset_15.png",
	"s14_coast_asset_16": "split/1-4/gimmicks/coast_asset_16.png",
	"s14_coast_asset_17": "split/1-4/gimmicks/coast_asset_17.png",
	"s14_coast_asset_18": "split/1-4/gimmicks/coast_asset_18.png",
	"s14_coast_asset_19": "split/1-4/gimmicks/coast_asset_19.png",
	"s14_coast_asset_20": "split/1-4/gimmicks/coast_asset_20.png",
	"s14_coast_asset_21": "split/1-4/gimmicks/coast_asset_21.png",
	"s14_coast_asset_22": "split/1-4/gimmicks/coast_asset_22.png",
	"s15_background": "split/1-5/background/background.png",
	"s15_fire_bat": "split/1-5/enemies/fire_bat.png",
	"s15_lava_golem": "split/1-5/enemies/lava_golem.png",
	"s15_magma_slime": "split/1-5/enemies/magma_slime.png",
	"s15_volcano_asset_01": "split/1-5/gimmicks/volcano_asset_01.png",
	"s15_volcano_asset_02": "split/1-5/gimmicks/volcano_asset_02.png",
	"s15_volcano_asset_03": "split/1-5/gimmicks/volcano_asset_03.png",
	"s15_volcano_asset_04": "split/1-5/gimmicks/volcano_asset_04.png",
	"s15_volcano_asset_05": "split/1-5/gimmicks/volcano_asset_05.png",
	"s15_volcano_asset_06": "split/1-5/gimmicks/volcano_asset_06.png",
	"s15_volcano_asset_07": "split/1-5/gimmicks/volcano_asset_07.png",
	"s15_volcano_asset_08": "split/1-5/gimmicks/volcano_asset_08.png",
	"s15_volcano_asset_09": "split/1-5/gimmicks/volcano_asset_09.png",
	"s15_volcano_asset_10": "split/1-5/gimmicks/volcano_asset_10.png",
	"s15_volcano_asset_11": "split/1-5/gimmicks/volcano_asset_11.png",
	"s15_volcano_asset_12": "split/1-5/gimmicks/volcano_asset_12.png",
	"s15_volcano_asset_13": "split/1-5/gimmicks/volcano_asset_13.png",
	"s15_volcano_asset_14": "split/1-5/gimmicks/volcano_asset_14.png",

	# characters
	"runner_idle": "characters/runner_idle.png",
	"runner_run": "characters/runner_run.png",
	"runner_jump": "characters/runner_jump.png",
	"runner_fall": "characters/runner_fall.png",
	"runner_land": "characters/runner_land.png",
	"runner_dash": "characters/runner_dash.png",
	"runner_reach": "characters/runner_reach.png",
	"runner_cheer": "characters/runner_cheer.png",
	"walker": "characters/walker.png",
	## The second ground enemy of the 1-1 set. Same behaviour as `walker`; see
	## Walker.skin, which is static level data and so costs nothing on the wire.
	"walker_spiky": "characters/walker_spiky.png",
	# holograms
	"platform": "holograms/platform.png",
	"wall": "holograms/wall.png",
	"warp_gate": "holograms/warp_gate.png",
	# props
	# The stone set that replaced four cut-outs of Nintendo's furniture. Drawn
	# by tools/make-stone-textures.ps1 rather than painted, and a TEXTURE
	# rather than Node2D draw calls: the code-drawn version cost 1-1 eighty
	# draw calls and a 48ms frame, and the version cheap enough to be fast
	# looked like grey boxes. A sprite is one quad however detailed it is.
	# The broken tower on the horizon is still vector -- see SkyCanvas.
	"conduit": "props/conduit.png",
	"masonry": "props/masonry.png",
	"sigil_block": "props/sigil_block.png",
	"spikes": "props/spikes.png",
	"fence": "props/fence.png",
	"flowers": "props/flowers.png",
	"signpost": "props/signpost.png",
	"tree": "props/tree.png",
	"coin": "props/coin.png",
	# terrain
	"grass_tile": "terrain/grass_tile.png",
	"dirt_tile": "terrain/dirt_tile.png",
	"grass_cap": "terrain/grass_cap.png",
	"dirt_body": "terrain/dirt_body.png",
	"dirt_body_alt": "terrain/dirt_body_alt.png",
	"ground_block": "terrain/ground_block.png",
	# background
	"cloud_a": "bg/cloud_a.png",
	"cloud_b": "bg/cloud_b.png",
	"cloud_c": "bg/cloud_c.png",
	"parallax": "bg/parallax.png",
	# stage 1-2 horror art. The painted pieces replaced the first vector pass;
	# the three still on .svg are the ones nothing was painted for yet.
	"horror_panorama": "bg/horror_stage_1_2.svg",
	"horror_pursuer": "horror/pursuer.svg",
	"horror_wisp": "horror/wisp.svg",
	"horror_thornmite": "horror/thornmite.svg",
	"horror_ruin_block": "horror/ruin_block.svg",
	"horror_platform": "horror/platform.svg",
	"horror_checkpoint_off": "horror/checkpoint_off.svg",
	"horror_checkpoint_on": "horror/checkpoint_on.svg",
	"horror_goal": "horror/gate.svg",
	"horror_fence": "horror/fence.svg",
	"horror_thorns": "horror/thorns.svg",
	"horror_mud_tile": "horror/mud_tile.svg",
	"horror_moss_cap": "horror/moss_cap.svg",
	# ...and the dressing, which until now was drawn by hand in decor.gd.
	"horror_cart": "horror/cart.png",
	"horror_crate": "horror/crate.png",
	"horror_grave": "horror/grave.png",
	"horror_lantern": "horror/lantern.png",
	"horror_puddle": "horror/puddle.png",
	# stage 1-B, the boss arena. Nothing is painted for these yet; every one of
	# them falls back to vector drawing until docs/art-prompts-keeper.md comes
	# back, and the fallbacks are what the stage was designed and measured
	# against, so the art is a replacement rather than a dependency.
	"keeper_panorama": "keeper/panorama.jpg",
	"keeper_stand": "keeper/keeper_stand.png",
	"keeper_brace": "keeper/keeper_brace.png",
	"keeper_charge": "keeper/keeper_charge.png",
	"keeper_reel": "keeper/keeper_reel.png",
	"keeper_core": "keeper/core.png",
	"keeper_barricade": "keeper/barricade.png",
	"keeper_barricade_rubble": "keeper/barricade_rubble.png",
	"keeper_shockwave": "keeper/shockwave.png",
	"keeper_portcullis": "keeper/portcullis.png",
	"keeper_flagstone": "keeper/flagstone.png",
	"keeper_brazier": "keeper/brazier.png",
	"keeper_rubble": "keeper/rubble.png",
	# stage 1-S, the flight stage. Nothing is painted for these yet; every one
	# falls back to vector drawing until docs/art-prompts-sky.md comes back.
	"sky_panorama": "sky/panorama.jpg",
	"sky_island_tile": "sky/island_tile.png",
	"sky_island_cap": "sky/island_cap.png",
	"sky_keel": "sky/keel.png",
	"sky_updraft": "sky/updraft.png",
	"sky_streamer": "sky/streamer.png",
	"sky_arch": "sky/arch.png",
	"sky_beacon": "sky/beacon.png",
	"sky_flyer": "sky/flyer.png",
	# stage 1-4, the sea. From the 1-4 sea art pack via
	# tools/extract-stage-1-4.py.
	"sea_panorama": "stage_1_4/distant_sea.jpg",
	"sea_sand_tile": "stage_1_4/sand_tile.png",
	"sea_grass_cap": "stage_1_4/grass_cap.png",
	"sea_crab": "stage_1_4/crab.png",
	"sea_seabird": "stage_1_4/seabird.png",
	"sea_chaser": "stage_1_4/chaser.png",
	"sea_flag": "stage_1_4/flag.png",
	"sea_rock": "stage_1_4/rock.png",
	"sea_pier": "stage_1_4/pier.png",
	"sea_bridge": "stage_1_4/bridge.png",
	"sea_raft": "stage_1_4/raft.png",
	"sea_palm": "stage_1_4/palm_large.png",
	"sea_palm_small": "stage_1_4/palm_small.png",
	"sea_grass": "stage_1_4/grass_flower.png",
	"sea_boulder": "stage_1_4/boulder.png",
	"sea_seaweed": "stage_1_4/seaweed.png",
	# Stage 1-5: the panorama and four transparent props follow the approved
	# mid-detail swamp concept board. Ground and poison are drawn in world space.
	"swamp_panorama": "stage_1_5/distant_swamp.png",
	"swamp_props_atlas": "stage_1_5/props_atlas.png",
	"desert_panorama": "stage_1_6/distant_desert.png",
	# synthesised entities
	"flyer": "entities/flyer_bird.png",
	"turret": "entities/turret.png",
	"projectile": "entities/projectile.png",
	"laser_emitter": "entities/laser_emitter.png",
	"laser_beam": "entities/laser_beam.png",
	"switch_off": "entities/switch_off.png",
	"switch_on": "entities/switch_on.png",
	"gate": "entities/gate.png",
	"moving_platform": "entities/moving_platform.png",
	"checkpoint_off": "entities/checkpoint_off.png",
	"checkpoint_on": "entities/checkpoint_on.png",
	"goal": "entities/goal.png",
	"spring": "entities/spring.png",
	"hit_burst": "entities/hit_burst.png",
	# ui
	"portrait_lira": "ui/portrait_lira.png",
	"portrait_orion": "ui/portrait_orion.png",
	"heart": "ui/heart.png",
	"icon_platform": "ui/icon_platform.png",
	"icon_wall": "ui/icon_wall.png",
	"icon_snipe": "ui/icon_snipe.png",
	"icon_warp": "holograms/warp_gate.png",
	# scope furniture
	"zoom_slider": "scope/zoom_slider.png",
	"cartridge": "scope/cartridge.png",
	"btn_reticle": "scope/btn_reticle.png",
	"scope_ring": "scope/ring.png",
	"crosshair": "scope/crosshair.png",
}

## Keys that are registered in the MANIFEST but whose painting has not arrived.
##
## EMPTY, and that is the point: 1-B and 1-S were built and measured with their
## twenty-two keys sitting in here, and the paintings have now all landed.
##
## The list works because a missing texture is INVISIBLE -- tex() returns null,
## the renderer drops to its vector path, and nobody finds out until somebody
## looks at a screenshot. So "not painted yet" could not be expressed by leaving
## the keys out of the audit, and could not be expressed by leaving them out of
## the MANIFEST either (then the fallbacks would be the design rather than a
## stand-in). Instead they are registered, listed here, and audited the other
## way round: missing() forgives whatever is in here, and pending_but_present()
## fails the moment one of their files turns up -- because a stale entry would
## switch the real audit off for a key that is being shipped.
##
## The next stage that ships ahead of its art puts its keys back in here.
const PENDING := []

const FONT_UI := BASE + "fonts/Nunito-ExtraBold.ttf"
const FONT_DISPLAY := BASE + "fonts/Baloo2-Bold.ttf"

static var _cache: Dictionary = {}
static var _fonts: Dictionary = {}

## Cache for _prefer, which asks the filesystem and must not do so per draw call.
static var _preferred: Dictionary = {}

## The first of these keys whose file actually exists, or the last one.
##
## This is what lets 1-B ship before its art does and still look like the place
## it is set. 1-B is the inside of 1-2's gate, so every surface falls back to
## that stage's painted night set: the ground, the backdrop and the gate all
## have a keeper_* key registered for the day the paintings arrive, and until
## then they resolve to the horror one, which exists.
##
## The alternative was to leave the keys unresolved and let tex() return null,
## and that is worse than it sounds -- null means the VECTOR fallback, and the
## vector fallback is the bright green 1-1 set. A night boss arena in a sunny
## field is not "art pending", it is wrong, and it would have been wrong in the
## screenshots people judge the stage by.
static func _prefer(keys: Array) -> String:
	var memo: String = _preferred.get(keys[0], "")
	if memo != "":
		return memo
	var chosen: String = keys[keys.size() - 1]
	for key in keys:
		if MANIFEST.has(key) and ResourceLoader.exists(BASE + MANIFEST[key]):
			chosen = key
			break
	_preferred[keys[0]] = chosen
	return chosen

static func _resolved_key(key: String) -> String:
	# Resolve by stage before legacy skins so other stages retain their art.
	match Stage.current():
		Stage.Which.HORROR:
			match key:
				"parallax": return "s12_background"
				"horror_pursuer": return "s12_nightwolf_idle"
				"horror_wisp": return "s12_wisp_idle"
				"flyer": return "s12_wisp_idle"
				"horror_thornmite": return "s12_thornmite_idle"
				"horror_ruin_block": return "s12_ruin_wall_a"
				"horror_platform": return "s12_floating_ground_b"
				"platform": return "s12_moving_platform"
				"moving_platform": return "s12_moving_platform"
				"goal": return "s12_goal_gate"
				"horror_goal": return "s12_goal_gate"
				"fence": return "s12_broken_fence"
				"horror_fence": return "s12_broken_fence"
				"spikes": return "s12_thorn_hazard"
				"horror_thorns": return "s12_thorn_hazard"
				"tree": return "s12_dead_tree"
				"horror_grave": return "s12_grave"
				"horror_lantern": return "s12_lantern"
				"horror_puddle": return "s12_puddle"
				"ground_block": return "s12_floating_ground_a"
		Stage.Which.SKYWARD_RUINS:
			match key:
				"parallax": return "s13_background"
				"flyer": return "s13_sky_bird_idle"
				"horror_pursuer": return "s13_golem_attack"
				"goal": return "s13_sky_asset_16"
				"gate": return "s13_sky_asset_09"
				"moving_platform": return "s13_sky_asset_14"
				"ground_block": return "s13_sky_asset_05"
				"platform": return "s13_sky_asset_14"
				"checkpoint_off": return "s13_sky_asset_17"
				"checkpoint_on": return "s13_sky_asset_17"
				"spring": return "s13_sky_asset_18"
				"sky_updraft": return "s13_sky_asset_13"
		Stage.Which.SEA:
			match key:
				"parallax": return "s14_background"
				"sea_panorama": return "s14_background"
				"sea_crab": return "s14_sea_crab_idle"
				"flyer": return "s14_seabird_idle"
				"sea_seabird": return "s14_seabird_idle"
				"horror_pursuer": return "s14_purple_pursuer_idle"
				"sea_chaser": return "s14_purple_pursuer_idle"
				"sea_rock": return "s14_coast_asset_19"
				"sea_pier": return "s14_coast_asset_07"
				"sea_bridge": return "s14_coast_asset_06"
				"moving_platform": return "s14_coast_asset_08"
				"sea_raft": return "s14_coast_asset_08"
				"sea_palm": return "s14_coast_asset_16"
				"sea_palm_small": return "s14_coast_asset_16"
				"sea_boulder": return "s14_coast_asset_18"
				"sea_seaweed": return "s14_coast_asset_20"
				"sea_grass": return "s14_coast_asset_20"
				"spring": return "s14_coast_asset_13"
				"ground_block": return "s14_coast_asset_07"
				"fence": return "s14_coast_asset_12"
		Stage.Which.SWAMP:
			match key:
				"parallax": return "s15_background"
				"swamp_panorama": return "s15_background"
				"walker": return "s15_magma_slime"
				"walker_spiky": return "s15_magma_slime"
				"flyer": return "s15_fire_bat"
				"goal": return "s15_volcano_asset_13"
				"moving_platform": return "s15_volcano_asset_11"
				"ground_block": return "s15_volcano_asset_05"
				"spikes": return "s15_volcano_asset_09"
				"platform": return "s15_volcano_asset_12"
		Stage.Which.DESERT:
			match key:
				"parallax": return "s16_background"
				"moving_platform": return "s16_lift"
				"ground_block": return "s16_crumble"
				"platform": return "s16_lift"
				"spring": return "s16_spring"
				"switch_off": return "s16_switch_off"
				"switch_on": return "s16_switch_on"
				"gate": return "s16_gate"
				"goal": return "s16_goal"
				"checkpoint_off": return "s16_checkpoint_off"
				"checkpoint_on": return "s16_checkpoint_on"
				"spikes": return "s16_spikes"
				"sky_updraft": return "s16_updraft"
				"turret": return "s16_golem_0"
		Stage.Which.TOWER:
			match key:
				"parallax": return "s17_background"
				"moving_platform": return "s17_lift"
				"ground_block": return "s17_crumble"
				"platform": return "s17_blink"
				"spring": return "s17_spring"
				"switch_off": return "s17_switch"
				"switch_on": return "s17_switch"
				"gate": return "s17_gate"
				"goal": return "s17_gate"
				"sky_updraft": return "s17_updraft"
				"checkpoint_off": return "s17_terrain_banner"
				"checkpoint_on": return "s17_terrain_banner"
				"turret": return "s17_turret_idle"
				"spikes": return "s17_spikes"
		Stage.Which.CAVE:
			match key:
				"parallax": return "s18_background"
				"moving_platform": return "s18_lift"
				"ground_block": return "s18_crumble"
				"platform": return "s18_blink"
				"spring": return "s18_spring"
				"switch_off": return "s18_switch"
				"switch_on": return "s18_switch"
				"goal": return "s18_goal"
				"checkpoint_off": return "s18_checkpoint"
				"checkpoint_on": return "s18_checkpoint"
				"sky_updraft": return "s18_updraft"
	if Stage.is_desert():
		match key:
			"parallax": return "desert_panorama"
			_: return key
	if Stage.is_swamp():
		match key:
			"parallax": return "swamp_panorama"
			_: return key
	# 1-4 wears its own pack wholesale: sand and grass for the ground, the
	# crab, gull and purple chaser for the three enemy roles, and the flag as
	# the goal. Keys it does not name fall through to the originals.
	if Stage.is_sea():
		match key:
			"parallax": return "sea_panorama"
			"dirt_tile": return "sea_sand_tile"
			"grass_tile": return "sea_grass_cap"
			"flyer": return "sea_seabird"
			"horror_pursuer": return "sea_chaser"
			"goal": return "sea_flag"
			"moving_platform": return "sea_raft"
			_: return key
	# 1-S has no other stage to borrow from -- it is the first daylight stage
	# since 1-1 and it is nowhere near the ground -- so unlike 1-B these fall
	# through to the ORIGINAL keys rather than to another skin. That is the
	# right answer here: the vector fallback for a sky stage is a sky.
	if Stage.is_sky():
		match key:
			"parallax": return "sky_panorama"
			"dirt_tile": return "sky_island_tile"
			"grass_tile": return "sky_island_cap"
			"goal": return "sky_beacon"
			"flyer": return "sky_flyer"
			_: return key
	if Stage.is_keeper():
		match key:
			"parallax": return _prefer(["keeper_panorama", "horror_panorama"])
			"dirt_tile": return _prefer(["keeper_flagstone", "horror_mud_tile"])
			"grass_tile": return "horror_moss_cap"
			"gate": return _prefer(["keeper_portcullis", "horror_goal"])
			"platform": return "horror_platform"
			"checkpoint_off": return "horror_checkpoint_off"
			"checkpoint_on": return "horror_checkpoint_on"
			"goal": return "horror_goal"
			"fence": return "horror_fence"
			"spikes": return "horror_thorns"
			_: return key
	if not Stage.is_horror():
		return key
	match key:
		"parallax": return "horror_panorama"
		"flyer": return "horror_wisp"
		"ground_block": return "horror_mud_tile"
		"platform": return "horror_platform"
		"checkpoint_off": return "horror_checkpoint_off"
		"checkpoint_on": return "horror_checkpoint_on"
		"goal": return "horror_goal"
		"fence": return "horror_fence"
		"spikes": return "horror_thorns"
		"dirt_tile": return "horror_mud_tile"
		"grass_tile": return "horror_moss_cap"
		_: return key

## Texture for a manifest key, or null when textures are off or the file is gone.
static func tex(key: String) -> Texture2D:
	if not Balance.USE_TEXTURES:
		return null
	var resolved := _resolved_key(key)
	if _cache.has(resolved):
		return _cache[resolved]
	var texture: Texture2D = null
	if MANIFEST.has(resolved):
		var path: String = BASE + MANIFEST[resolved]
		if ResourceLoader.exists(path):
			texture = load(path)
	_cache[resolved] = texture
	return texture

static func font(path: String = FONT_UI) -> Font:
	if _fonts.has(path):
		return _fonts[path]
	var f: Font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	_fonts[path] = f
	return f

static func draw_sprite(ci: CanvasItem, key: String, bottom_centre: Vector2,
		height: float, flip_h: bool = false, modulate: Color = Color.WHITE) -> bool:
	var t := tex(key)
	if t == null:
		return false
	var size := Vector2(t.get_size())
	if size.y <= 0.0:
		return false
	var w := size.x * (height / size.y)
	var rect := Rect2(bottom_centre - Vector2(w * 0.5, height), Vector2(w, height))
	if flip_h:
		ci.draw_set_transform(Vector2((rect.position.x + rect.size.x * 0.5) * 2.0, 0.0),
			0.0, Vector2(-1.0, 1.0))
		ci.draw_texture_rect(t, rect, false, modulate)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return true
	ci.draw_texture_rect(t, rect, false, modulate)
	return true

static func draw_sprite_w(ci: CanvasItem, key: String, bottom_centre: Vector2,
		width: float, flip_h: bool = false, modulate: Color = Color.WHITE) -> bool:
	var t := tex(key)
	if t == null:
		return false
	var size := Vector2(t.get_size())
	if size.x <= 0.0:
		return false
	return draw_sprite(ci, key, bottom_centre, size.y * (width / size.x), flip_h, modulate)

static func draw_stretched(ci: CanvasItem, key: String, rect: Rect2,
		modulate: Color = Color.WHITE) -> bool:
	var t := tex(key)
	if t == null:
		return false
	ci.draw_texture_rect(t, rect, false, modulate)
	return true

## draw_stretched, optionally mirrored about the rect's own centre.
##
## Everything in the painted set is drawn facing one way (see
## docs/art-prompts-keeper.md: "all characters face LEFT"), so anything that
## exists in both directions needs this rather than a second file -- two files
## means two light sources, and the second one is always wrong.
static func draw_stretched_flipped(ci: CanvasItem, key: String, rect: Rect2,
		flip_h: bool, modulate: Color = Color.WHITE) -> bool:
	if not flip_h:
		return draw_stretched(ci, key, rect, modulate)
	var t := tex(key)
	if t == null:
		return false
	ci.draw_set_transform(Vector2((rect.position.x + rect.size.x * 0.5) * 2.0, 0.0),
		0.0, Vector2(-1.0, 1.0))
	ci.draw_texture_rect(t, rect, false, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

static func draw_tiled(ci: CanvasItem, key: String, rect: Rect2, tile_height: float,
		modulate: Color = Color.WHITE) -> bool:
	var t := tex(key)
	if t == null:
		return false
	var size := Vector2(t.get_size())
	if size.y <= 0.0:
		return false
	var scale := tile_height / size.y
	ci.draw_set_transform(rect.position, 0.0, Vector2(scale, scale))
	ci.draw_texture_rect(t, Rect2(Vector2.ZERO, rect.size / scale), true, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

static func draw_sprite_fit(ci: CanvasItem, key: String, centre: Vector2,
		box: float, modulate: Color = Color.WHITE) -> bool:
	var t := tex(key)
	if t == null:
		return false
	var size := Vector2(t.get_size())
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var scale := minf(box / size.x, box / size.y)
	var drawn := size * scale
	ci.draw_texture_rect(t, Rect2(centre - drawn * 0.5, drawn), false, modulate)
	return true

static func missing() -> Array:
	var gone: Array = []
	for key in MANIFEST.keys():
		if key in PENDING:
			continue
		if not ResourceLoader.exists(BASE + MANIFEST[key]):
			gone.append("%s -> %s" % [key, MANIFEST[key]])
	for path in [FONT_UI, FONT_DISPLAY]:
		if not ResourceLoader.exists(path):
			gone.append("font -> " + path)
	return gone

## Pending keys whose file has actually turned up. Every one of these is a line
## to delete from PENDING -- until it is, that key is exempt from the audit
## while being shipped, which is the one failure mode this whole arrangement
## could have introduced.
static func pending_but_present() -> Array:
	var arrived: Array = []
	for key in PENDING:
		if MANIFEST.has(key) and ResourceLoader.exists(BASE + MANIFEST[key]):
			arrived.append(key)
	return arrived

## Pending keys that are not in the manifest at all -- a typo in PENDING, which
## would silently exempt nothing and hide a real missing file under a name that
## does not exist.
static func pending_unknown() -> Array:
	var unknown: Array = []
	for key in PENDING:
		if not MANIFEST.has(key):
			unknown.append(key)
	return unknown

## Prefix for the late-stage boards; empty elsewhere so legacy art stays intact.
static func late_pack() -> String:
	match Stage.current():
		Stage.Which.DESERT: return "s16_"
		Stage.Which.TOWER: return "s17_"
		Stage.Which.CAVE: return "s18_"
	return ""

## The flat source cap sits on the collision top. Wheels/stone hang underneath.
static func draw_late_platform(ci: CanvasItem, key: String, rect: Rect2,
		modulate: Color = Color.WHITE, flip_h: bool = false) -> bool:
	var prefix := late_pack()
	if prefix == "": return false
	var texture := tex(prefix + key)
	if texture == null: return false
	var height := maxf(rect.size.y, minf(rect.size.x * texture.get_height() / texture.get_width(), 82.0))
	var target := Rect2(rect.position, Vector2(rect.size.x, height))
	if flip_h:
		ci.draw_set_transform(Vector2(target.get_center().x * 2.0, 0), 0, Vector2(-1, 1))
	ci.draw_texture_rect(texture, target, false, modulate)
	if flip_h: ci.draw_set_transform(Vector2.ZERO)
	return true
