class_name Art
extends RefCounted
## Texture registry shared by every stage. Horror-specific aliases are resolved
## here so gameplay classes stay the same while stage 1-2 changes visual skin.

const BASE := "res://assets/"

static var MANIFEST: Dictionary = _all_assets()

static func _all_assets() -> Dictionary:
	var result := {}
	for manifest in [
		preload("res://src/render/manifests/common.gd"),
		preload("res://src/render/manifests/royal_arena.gd"),
		preload("res://src/render/manifests/stage_1_2.gd"),
		preload("res://src/render/manifests/stage_1_3.gd"),
		preload("res://src/render/manifests/stage_1_4.gd"),
		preload("res://src/render/manifests/stage_1_5.gd"),
		preload("res://src/render/manifests/stage_1_6.gd"),
		preload("res://src/render/manifests/stage_1_7.gd"),
		preload("res://src/render/manifests/stage_1_8.gd"),
		preload("res://src/render/manifests/stage_1_9.gd"),
	]:
		result.merge(manifest.TEXTURES)
	return result

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
## 1-9 has: its paintings are being made from docs/art-prompts-castle.md.
const PENDING := [
	"castle_bat_0", "castle_bat_1", "castle_gate_arch", "castle_gate_bars",
	"castle_golem_hit", "castle_goal_door",
]

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
		Stage.Which.CASTLE:
			# Each painting as it lands; until then, the art the stage
			# borrows (the 1-1 panorama has a castle on its hill).
			match key:
				"parallax": return _prefer(["castle_panorama", "parallax"])
				"goal": return _prefer(["castle_goal_door", "goal"])
				"turret": return _prefer(["castle_cannon_idle", "turret"])
				"projectile": return _prefer(["castle_cannonball", "projectile"])
				"keeper_portcullis": return _prefer(["castle_gate_bars", "keeper_portcullis"])
		Stage.Which.ROYAL_ARENA:
			match key:
				"parallax": return "royal_royal_sky_kingdom"
				"moving_platform": return "royal_floating_platform_medium"
				"platform": return "royal_platform_medium_top"
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

## Stage-local chase art, shared by both pursuing enemy behaviors.
static func pursuer_frame(idle: bool = false, phase: float = 0.0) -> String:
	match Stage.current():
		Stage.Which.HORROR: return "s12_nightwolf_idle" if idle else "s12_nightwolf_chase"
		Stage.Which.SKYWARD_RUINS: return "s13_golem_idle" if idle else "s13_golem_move"
		Stage.Which.SEA: return "s14_purple_pursuer_idle" if idle else "s14_purple_pursuer_chase"
		Stage.Which.SWAMP: return "s15_lava_golem"
		Stage.Which.DESERT: return "s16_mummy_%d" % (0 if idle else int(phase * 4.0) % 6)
		Stage.Which.TOWER: return "s17_mine_idle" if idle else "s17_mine_alert"
		Stage.Which.CAVE: return "s18_bat_idle" if idle else "s18_bat_attack"
		Stage.Which.CASTLE:
			# The castle hound; 1-2's night wolf runs in its place until painted.
			if tex("castle_hound_0") != null:
				return "castle_hound_%d" % (0 if idle else int(phase * 5.0) % 4)
			return "s12_nightwolf_idle" if idle else "s12_nightwolf_chase"
	return "horror_pursuer"

## Whether this stage's chase art is drawn facing left (1-9's hound, painted
## to face the runner) and so has to be mirrored to chase to the right.
static func pursuer_faces_left() -> bool:
	return Stage.current() == Stage.Which.CASTLE and tex("castle_hound_0") != null

static func platform_skin(length: float) -> String:
	if Stage.current() != Stage.Which.ROYAL_ARENA: return ""
	return "royal_platform_long_top" if length > 230.0 else \
		"royal_platform_short_top" if length < 140.0 else "royal_platform_medium_top"

## A visual style is bound when a node is created. It may be overridden by
## stage data without changing the node's mechanics or consulting Stage in it.
static func bind_style(node: Node) -> void:
	if node.has_meta("art_style"): return
	var styles := {
		Stage.Which.GREENFIELD: "greenfield", Stage.Which.HORROR: "horror",
		Stage.Which.SKYWARD_RUINS: "skyward_ruins", Stage.Which.SEA: "sea",
		Stage.Which.SWAMP: "swamp", Stage.Which.DESERT: "desert",
		Stage.Which.TOWER: "tower", Stage.Which.CAVE: "cave",
		Stage.Which.ROYAL_ARENA: "royal_arena", Stage.Which.CASTLE: "castle",
	}
	node.set_meta("art_style", styles.get(Stage.current(), "common"))

static func style(node: Node) -> String:
	return String(node.get_meta("art_style", "common"))
