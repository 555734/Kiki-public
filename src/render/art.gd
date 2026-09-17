class_name Art
extends RefCounted
## Texture registry shared by every stage. Horror-specific aliases are resolved
## here so gameplay classes stay the same while stage 1-2 changes visual skin.

const BASE := "res://assets/"

const MANIFEST := {
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
	# holograms
	"platform": "holograms/platform.png",
	"wall": "holograms/wall.png",
	"warp_gate": "holograms/warp_gate.png",
	# props
	"pipe": "props/pipe.png",
	"qblock": "props/qblock.png",
	"brick": "props/brick.png",
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
	"castle": "bg/castle.png",
	"parallax": "bg/parallax.png",
	# stage 1-2 horror art. The painted pieces replaced the first vector pass;
	# the three still on .svg are the ones nothing was painted for yet.
	"horror_panorama": "bg/horror_stage_1_2.jpg",
	"horror_pursuer": "horror/pursuer.png",
	"horror_platform": "horror/platform.svg",
	"horror_checkpoint_off": "horror/checkpoint_off.svg",
	"horror_checkpoint_on": "horror/checkpoint_on.svg",
	"horror_goal": "horror/gate.png",
	"horror_fence": "horror/fence.png",
	"horror_thorns": "horror/thorns.png",
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
	# synthesised entities
	"flyer": "entities/flyer.png",
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
