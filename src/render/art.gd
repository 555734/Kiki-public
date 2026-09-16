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

const FONT_UI := BASE + "fonts/Nunito-ExtraBold.ttf"
const FONT_DISPLAY := BASE + "fonts/Baloo2-Bold.ttf"

static var _cache: Dictionary = {}
static var _fonts: Dictionary = {}

static func _resolved_key(key: String) -> String:
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
		if not ResourceLoader.exists(BASE + MANIFEST[key]):
			gone.append("%s -> %s" % [key, MANIFEST[key]])
	for path in [FONT_UI, FONT_DISPLAY]:
		if not ResourceLoader.exists(path):
			gone.append("font -> " + path)
	return gone
