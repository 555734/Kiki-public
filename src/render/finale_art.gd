class_name FinaleArt
extends RefCounted
## Art for 1-10. Almost everything is an existing painted asset of an
## earlier stage (1-1 meadow, 1-3 ruins, 1-5 volcano, 1-6 desert, 1-7 tower,
## 1-8 cave); the few new pieces are in assets/stage_1_10, made by
## tools/make_finale_assets.py. Textures load on first use, so earlier stages
## never pay for this course's art.

const SPRITES := {
	"tree": "res://assets/props/tree.png",
	"flowers": "res://assets/props/flowers.png",
	"signpost": "res://assets/props/signpost.png",
	"fence": "res://assets/props/fence.png",
	"waterfall": "res://assets/stage_1_3/sprites/waterfall_wide.png",
	"ruin_tower": "res://assets/sky/beacon.png",
	"column": "res://assets/split/1-6/background/column.png",
	"broken_column": "res://assets/split/1-6/background/broken_column.png",
	"arch": "res://assets/split/1-6/background/arch.png",
	"broken_arch": "res://assets/split/1-6/background/broken_arch.png",
	"rubble": "res://assets/split/1-6/background/rubble.png",
	"palm": "res://assets/split/1-6/gimmicks/palm.png",
	"lavafall": "res://assets/split/1-5/gimmicks/volcano_asset_06.png",
	"lava_column": "res://assets/split/1-5/gimmicks/volcano_asset_07.png",
	"lava_strip": "res://assets/split/1-5/gimmicks/volcano_asset_08.png",
	"lava_spikes": "res://assets/split/1-5/gimmicks/volcano_asset_09.png",
	"lava_platform": "res://assets/split/1-5/gimmicks/volcano_asset_11.png",
	"chain": "res://assets/split/1-7/background/chain.png",
	"lamp": "res://assets/split/1-7/background/lamp.png",
	"viaduct": "res://assets/stage_1_3/sprites/bg_aqueduct.png",
	"rope_bridge": "res://assets/stage_1_3/sprites/rope_bridge.png",
	"grass": "res://assets/split/1-6/gimmicks/grass.png",
	"stone": "res://assets/split/1-6/background/stone.png",
	"golem_eye": "res://assets/keeper/core.png",
	"mace": "res://assets/split/1-7/gimmicks/pendulum_ball.png",
	"gear": "res://assets/split/1-7/background/gear.png",
	"crate": "res://assets/split/1-4/gimmicks/coast_asset_10.png",
	"boulder": "res://assets/split/1-8/gimmicks/boulder.png",
	"eruption": "res://assets/stage_1_5/generated/eruption_v1.png",
	"updraft": "res://assets/split/1-6/gimmicks/updraft.png",
	"turret_idle": "res://assets/split/1-7/enemies/turret_idle.png",
	"turret_fire": "res://assets/split/1-7/enemies/turret_fire.png",
	"seed_0": "res://assets/stage_1_3/sprites/seed_0.png",
	"seed_1": "res://assets/stage_1_3/sprites/seed_1.png",
	"seed_2": "res://assets/stage_1_3/sprites/seed_2.png",
	"seed_hurt": "res://assets/stage_1_3/sprites/seed_hurt.png",
	"magma_slime": "res://assets/split/1-5/enemies/magma_slime.png",
	"fire_bat": "res://assets/split/1-5/enemies/fire_bat.png",
	"pillar": "res://assets/stage_1_3/sprites/pillar_broken.png",
	"plank": "res://assets/stage_1_3/sprites/plank.png",
	"cloud_a": "res://assets/bg/cloud_a.png",
	"cloud_b": "res://assets/bg/cloud_b.png",
	"meadow": "res://assets/bg/parallax.png",
	"sand_sky": "res://assets/split/1-6/background/background.png",
	"lava_sky": "res://assets/split/1-5/background/background.png",
	"cliff_sky": "res://assets/stage_1_6/distant_desert.png",
	"aqueduct": "res://assets/stage_1_3/sprites/bg_aqueduct.png",
	"hills": "res://assets/stage_1_3/sprites/bg_hills_a.png",
	# New for 1-10 (tools/make_finale_assets.py).
	"wax_tile": "res://assets/stage_1_10/wax_tile.png",
	"honey_cap": "res://assets/stage_1_10/honey_cap.png",
	"bone_tile": "res://assets/stage_1_10/bone_tile.png",
	"sand_stream": "res://assets/stage_1_10/sand_stream.png",
	"magma_ball": "res://assets/stage_1_10/magma_ball.png",
	"skull_drone": "res://assets/stage_1_10/skull_drone.png",
	"brass_drone": "res://assets/stage_1_10/brass_drone.png",
	"honey_bubble": "res://assets/stage_1_10/honey_bubble.png",
	"saw": "res://assets/stage_1_10/saw_blade.png",
	"train_loco": "res://assets/stage_1_10/train_loco.png",
	"train_blue": "res://assets/stage_1_10/train_blue.png",
	"train_red": "res://assets/stage_1_10/train_red.png",
	"train_flat": "res://assets/stage_1_10/train_flat.png",
	"crane": "res://assets/stage_1_10/crane.png",
	"storm_sky": "res://assets/stage_1_10/storm_background.png",
	"hive_sky": "res://assets/stage_1_10/hive_background.png",
	"canyon_sky": "res://assets/stage_1_10/canyon_background.png",
	"rib_layer": "res://assets/stage_1_10/rib_layer.png",
	"wax_wisp_idle": "res://assets/stage_1_10/wax_wisp_idle.png",
	"wax_wisp_attack": "res://assets/stage_1_10/wax_wisp_attack.png",
	"spark_idle": "res://assets/stage_1_10/spark_idle.png",
	"spark_attack": "res://assets/stage_1_10/spark_attack.png",
}

static var _cache: Dictionary = {}

static func tex(key: String) -> Texture2D:
	if not _cache.has(key):
		var path: String = SPRITES.get(key, "")
		_cache[key] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _cache[key]

## Bottom-centred sprite of a given height (aspect preserved).
static func sprite(ci: CanvasItem, key: String, bottom: Vector2, height: float,
		flip: bool = false, tint: Color = Color.WHITE) -> void:
	var t := tex(key)
	if t == null:
		return
	var size := Vector2(t.get_size())
	var w := height * size.x / size.y
	var r := Rect2(bottom.x - w * 0.5, bottom.y - height, w, height)
	if flip:
		ci.draw_set_transform(Vector2(2.0 * bottom.x, 0), 0.0, Vector2(-1, 1))
	ci.draw_texture_rect(t, r, false, tint)
	if flip:
		ci.draw_set_transform(Vector2.ZERO)

## Centred sprite fitted to a width, with rotation.
static func centred(ci: CanvasItem, key: String, centre: Vector2, width: float,
		angle: float = 0.0, tint: Color = Color.WHITE, flip: bool = false) -> void:
	var t := tex(key)
	if t == null:
		return
	var size := Vector2(t.get_size())
	var h := width * size.y / size.x
	ci.draw_set_transform(centre, angle, Vector2(-1 if flip else 1, 1))
	ci.draw_texture_rect(t, Rect2(-width * 0.5, -h * 0.5, width, h), false, tint)
	ci.draw_set_transform(Vector2.ZERO)

# ------------------------------------------------------------------ terrain
## body texture, body tint, world size of one body tile, cap texture, cap
## source rows, cap height (world), how far the cap rises above the top.
const SKINS := {
	"grass": {"body": "res://assets/terrain/dirt_tile.png", "tint": Color(1, 1, 1), "tile": 180.0,
		"cap": "res://assets/terrain/grass_tile.png", "rows": Vector2(0, 115), "cap_h": 46.0, "lift": 12.0,
		"fill": Color("c8783a")},
	"storm": {"body": "res://assets/split/1-7/background/ground.png", "tint": Color(0.70, 0.80, 0.98), "tile": 210.0,
		"cap": "res://assets/split/1-7/background/platform.png", "rows": Vector2(0, 44), "cap_h": 26.0, "lift": 4.0,
		"fill": Color("3c4664")},
	"sand": {"body": "res://assets/split/1-6/background/stone.png", "tint": Color(1, 0.94, 0.84), "tile": 96.0,
		"cap": "res://assets/split/1-6/background/ground.png", "rows": Vector2(0, 58), "cap_h": 34.0, "lift": 6.0,
		"fill": Color("c98a4b")},
	"lava": {"body": "res://assets/split/1-5/gimmicks/volcano_asset_03.png", "tint": Color(1, 1, 1), "tile": 140.0,
		"cap": "res://assets/split/1-5/gimmicks/volcano_asset_04.png", "rows": Vector2(4, 64), "cap_h": 34.0, "lift": 4.0,
		"fill": Color("4a2a31")},
	"rail": {"body": "res://assets/props/masonry.png", "tint": Color(0.86, 0.82, 0.78), "tile": 96.0,
		"cap": "res://assets/stage_1_3/sprites/plate_grey.png", "rows": Vector2(0, 51), "cap_h": 24.0, "lift": 2.0,
		"fill": Color("6f6a66")},
	"hive": {"body": "res://assets/stage_1_10/wax_tile.png", "tint": Color(1.0, 0.78, 0.45), "tile": 150.0,
		"cap": "res://assets/stage_1_10/honey_cap.png", "rows": Vector2(0, 64), "cap_h": 34.0, "lift": 8.0,
		"fill": Color("d98a1a")},
	"cliff": {"body": "res://assets/split/1-6/background/stone.png", "tint": Color(0.82, 0.64, 0.52), "tile": 100.0,
		"cap": "res://assets/terrain/grass_tile.png", "rows": Vector2(0, 115), "cap_h": 44.0, "lift": 12.0,
		"fill": Color("8c5c44")},
	"bone": {"body": "res://assets/stage_1_10/bone_tile.png", "tint": Color(1, 1, 1), "tile": 160.0,
		"cap": "", "rows": Vector2.ZERO, "cap_h": 0.0, "lift": 0.0, "fill": Color("e3d6b8")},
}

static func _load(path: String) -> Texture2D:
	if path == "":
		return null
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

static func skin_for(rect: Rect2) -> String:
	return String(Stage.data().skin_for(rect))

## A tiled texture over a rect, through UVs rather than a draw transform, so
## whatever transform the caller set (a rotating slab, a swinging block)
## still applies. Needs texture_repeat on the CanvasItem.
static func tiled_rect(ci: CanvasItem, tex: Texture2D, rect: Rect2, tile: float, tint: Color) -> void:
	var tile_h := tile * float(tex.get_height()) / float(tex.get_width())
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(Vector2(p.x / tile, p.y / tile_h))
	ci.draw_polygon(pts, PackedColorArray([tint, tint, tint, tint]), uvs, tex)

## Several slabs of one skin, drawn pass by pass (all bodies, then all
## shading, then all caps) so the renderer batches each pass into one call
## instead of three per slab.
static func slabs_on(ci: CanvasItem, rects: Array, skin: String) -> void:
	var s: Dictionary = SKINS.get(skin, SKINS["grass"])
	var body := _load(s["body"])
	for rect in rects:
		ci.draw_rect(rect, s["fill"])
	if body != null:
		for rect in rects:
			tiled_rect(ci, body, rect, float(s["tile"]), s["tint"])
	for rect in rects:
		ci.draw_rect(Rect2(rect.position.x, rect.position.y + 40.0, rect.size.x, maxf(0.0, rect.size.y - 40.0)), Color(0.08, 0.03, 0.06, 0.16))
		ci.draw_rect(Rect2(rect.position.x, rect.position.y, 7.0, rect.size.y), Color(0, 0, 0, 0.14))
		ci.draw_rect(Rect2(rect.end.x - 7.0, rect.position.y, 7.0, rect.size.y), Color(0, 0, 0, 0.14))
	if skin == "bone":
		return
	for rect in rects:
		_cap_strip(ci, s, [rect.position, Vector2(rect.end.x, rect.position.y)])

## A rectangular slab. The cap's solid band sits on the collision top.
static func slab_on(ci: CanvasItem, rect: Rect2, skin: String) -> void:
	var s: Dictionary = SKINS.get(skin, SKINS["grass"])
	var body := _load(s["body"])
	ci.draw_rect(rect, s["fill"])
	if body != null:
		tiled_rect(ci, body, rect, float(s["tile"]), s["tint"])
	# Depth shading and soft side edges, as on the painted 1-1 banks.
	var shade := minf(rect.size.y, 600.0)
	for i in 4:
		var y := rect.position.y + 40.0 + shade * float(i) / 4.0
		ci.draw_rect(Rect2(rect.position.x, y, rect.size.x, rect.end.y - y), Color(0.08, 0.03, 0.06, 0.07))
	ci.draw_rect(Rect2(rect.position.x, rect.position.y, 7.0, rect.size.y), Color(0, 0, 0, 0.14))
	ci.draw_rect(Rect2(rect.end.x - 7.0, rect.position.y, 7.0, rect.size.y), Color(0, 0, 0, 0.14))
	if skin == "bone":
		ci.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("fff7e4"), 5.0)
		ci.draw_rect(rect, Color("6b5642"), false, 4.0)
		return
	_cap_strip(ci, s, [rect.position, Vector2(rect.end.x, rect.position.y)])

## A cap texture laid along a polyline (flat or sloped) with its band on top.
static func _cap_strip(ci: CanvasItem, s: Dictionary, top: Array) -> void:
	var cap := _load(s["cap"])
	if cap == null:
		return
	var rows: Vector2 = s["rows"]
	var h: float = s["cap_h"]
	var lift: float = s["lift"]
	var src_w := float(cap.get_width())
	var src_h := rows.y - rows.x
	var seg_w := h * src_w / src_h
	for i in range(top.size() - 1):
		var a: Vector2 = top[i]
		var b: Vector2 = top[i + 1]
		var length := a.distance_to(b)
		var dir := (b - a) / maxf(length, 0.001)
		var normal := Vector2(dir.y, -dir.x)
		var pieces := maxi(1, int(ceilf(length / seg_w)))
		for k in pieces:
			var t0 := float(k) / float(pieces)
			var t1 := float(k + 1) / float(pieces)
			var p0 := a.lerp(b, t0) + normal * lift
			var p1 := a.lerp(b, t1) + normal * lift
			var q0 := p0 - normal * h
			var q1 := p1 - normal * h
			var u1 := (t1 - t0) * length / seg_w
			var pts := PackedVector2Array([p0, p1, q1, q0])
			var uvs := PackedVector2Array([
				Vector2(0, rows.x / float(cap.get_height())), Vector2(u1, rows.x / float(cap.get_height())),
				Vector2(u1, rows.y / float(cap.get_height())), Vector2(0, rows.y / float(cap.get_height()))])
			# uv.x may exceed 1 only by rounding; one piece is one tile.
			uvs[1].x = minf(uvs[1].x, 1.0)
			uvs[2].x = minf(uvs[2].x, 1.0)
			ci.draw_polygon(pts, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, cap)

## A polygon slope. `top` is the walkable polyline (world space), `bottom`
## the y of the closed underside (or the thickness for a thin bridge).
static func slope_on(ci: CanvasItem, top: PackedVector2Array, poly: PackedVector2Array, skin: String) -> void:
	var s: Dictionary = SKINS.get(skin, SKINS["grass"])
	var body := _load(s["body"])
	var uvs := PackedVector2Array()
	var scale: float = float(s["tile"])
	for p in poly:
		uvs.append(p / scale)
	if body != null:
		var cols := PackedColorArray()
		cols.resize(poly.size())
		cols.fill(s["tint"])
		ci.draw_polygon(poly, cols, uvs, body)
	else:
		ci.draw_colored_polygon(poly, s["fill"])
	if skin == "bone":
		var outline := PackedVector2Array(poly)
		outline.append(poly[0])
		ci.draw_polyline(outline, Color("6b5642"), 4.0, true)
		ci.draw_polyline(top, Color("fff7e4"), 5.0, true)
		return
	var arr: Array = []
	for p in top:
		arr.append(p)
	_cap_strip(ci, s, arr)

# --------------------------------------------------------------- backdrops
static func _cover(ci: CanvasItem, key: String, view: Vector2, cam: Vector2, rate: float,
		alpha: float, vertical_rate: float = 0.04, crop: float = 1.0, tint: Color = Color.WHITE) -> void:
	var t := tex(key)
	if t == null:
		return
	var src := Rect2(Vector2.ZERO, Vector2(t.get_size()) * Vector2(1, crop))
	var height := view.y * 1.18
	var width := height * src.size.x / src.size.y
	var offset := cam.x * rate
	var y := -view.y * 0.09 - clampf(fposmod(cam.y, 4000.0) * vertical_rate, -view.y * 0.08, view.y * 0.08)
	var first := int(floorf(offset / width))
	var c := Color(tint.r, tint.g, tint.b, alpha)
	for i in range(-1, int(ceilf(view.x / width)) + 2):
		var x := float(i) * width - fposmod(offset, width)
		if posmod(first + i, 2) != 0:
			ci.draw_set_transform(Vector2(2.0 * x + width, 0), 0, Vector2(-1, 1))
		ci.draw_texture_rect_region(t, Rect2(x, y, width + 0.5, height), src, c)
		ci.draw_set_transform(Vector2.ZERO)

static func _layer(ci: CanvasItem, key: String, view: Vector2, cam: Vector2, rate: float, top: float,
		height: float, alpha: float, tint: Color = Color.WHITE) -> void:
	var t := tex(key)
	if t == null:
		return
	var width := height * float(t.get_width()) / float(t.get_height())
	var offset := cam.x * rate
	for i in range(-1, int(ceilf(view.x / width)) + 2):
		var x := float(i) * width - fposmod(offset, width)
		ci.draw_texture_rect(t, Rect2(x, top, width + 0.5, height), false, Color(tint, alpha))

## A few drifting clouds, spaced out (never a repeated strip). Drawn as soft
## clusters of circles rather than the mockup crops, whose edges were cut.
static func _clouds(ci: CanvasItem, view: Vector2, offset: float, alpha: float) -> void:
	var span := view.x * 1.6
	for i in 4:
		var w := view.x * (0.15 + 0.05 * float(i % 3))
		var x := fposmod(float(i) * span / 4.0 - offset * (0.6 + 0.15 * float(i)), span) - view.x * 0.3
		var y := view.y * (0.06 + 0.07 * float((i * 3) % 4)) + w * 0.25
		_cloud(ci, Vector2(x + w * 0.5, y), w, alpha * 0.92, i)

static func _cloud(ci: CanvasItem, base: Vector2, w: float, alpha: float, seed: int) -> void:
	var shade := Color(0.80, 0.88, 0.98, alpha)
	var white := Color(1, 1, 1, alpha)
	var puffs := [[-0.36, 0.0, 0.17], [-0.16, -0.12, 0.23], [0.08, -0.17, 0.27], [0.3, -0.06, 0.2], [0.42, 0.02, 0.13]]
	for p in puffs:
		var wob := 0.03 * float((seed * 7 + int(p[0] * 10.0)) % 3)
		ci.draw_circle(base + Vector2(float(p[0]), float(p[1]) + 0.05) * w, (float(p[2]) + wob) * w, shade)
	ci.draw_rect(Rect2(base + Vector2(-0.36, -0.02) * w, Vector2(0.78, 0.09) * w), shade)
	for p in puffs:
		var wob2 := 0.03 * float((seed * 7 + int(p[0] * 10.0)) % 3)
		ci.draw_circle(base + Vector2(float(p[0]), float(p[1])) * w, (float(p[2]) + wob2) * w * 0.93, white)
	ci.draw_rect(Rect2(base + Vector2(-0.36, -0.06) * w, Vector2(0.78, 0.08) * w), white)

## One backdrop per area, cross-faded over 500px at each border.
static func background(ci: CanvasItem, view: Vector2, cam: Vector2, time: float, flash: float) -> void:
	var zones: Array[Dictionary] = Stage.data().zones()
	var here := 0
	for i in zones.size():
		if cam.x >= float(zones[i]["from"]):
			here = i
	# The geyser lifts climb out of the volcano right under the station: the
	# backdrop follows height there, not just x.
	if cam.y > 1750.0 and cam.x > 10500.0 and cam.x < 11900.0:
		_sky(ci, "lava", view, cam, time, 1.0, flash)
		return
	_sky(ci, String(zones[here]["sky"]), view, cam, time, 1.0, flash)
	var fade := 300.0
	if here + 1 < zones.size():
		var edge := float(zones[here]["to"])
		var k := clampf((cam.x - (edge - fade)) / fade, 0.0, 1.0)
		if k > 0.0:
			_sky(ci, String(zones[here + 1]["sky"]), view, cam, time, k * 0.999, flash)

static func _sky(ci: CanvasItem, sky: String, view: Vector2, cam: Vector2, time: float, alpha: float, flash: float) -> void:
	match sky:
		"meadow":
			_cover(ci, "meadow", view, cam, 0.10, alpha, 0.03, 0.86)
			_clouds(ci, view, cam.x * 0.05 + time * 14.0, alpha)
		"storm":
			_cover(ci, "storm_sky", view, cam, 0.08, alpha, 0.03)
			# Rain, slanted, three depths. Cheap lines over the whole view.
			var rain := Color(0.75, 0.85, 1.0, 0.30 * alpha)
			var drops := PackedVector2Array()
			for i in 70:
				var seed := float(i) * 37.13
				var x := fposmod(seed * 13.7 - time * 520.0 - cam.x * 0.3, view.x + 120.0) - 60.0
				var y := fposmod(seed * 7.9 + time * 1500.0, view.y + 80.0) - 40.0
				drops.append(Vector2(x, y))
				drops.append(Vector2(x - 9, y + 26))
			ci.draw_multiline(drops, rain, 1.5)
			if flash > 0.0:
				ci.draw_rect(Rect2(Vector2.ZERO, view), Color(0.85, 0.92, 1.0, flash * 0.55 * alpha))
		"sand":
			_cover(ci, "sand_sky", view, cam, 0.10, alpha, 0.04)
			ci.draw_rect(Rect2(Vector2.ZERO, view), Color(1.0, 0.85, 0.6, 0.10 * alpha))
		"lava":
			_cover(ci, "lava_sky", view, cam, 0.10, alpha, 0.05)
			var pulse := 0.10 + 0.05 * sin(time * 1.7)
			ci.draw_rect(Rect2(0, view.y * 0.6, view.x, view.y * 0.4), Color(1.0, 0.35, 0.05, pulse * alpha))
		"rail":
			_cover(ci, "meadow", view, cam, 0.22, alpha, 0.02, 0.86)
			_layer(ci, "aqueduct", view, cam, 0.55, view.y * 0.48, view.y * 0.30, alpha)
		"hive":
			_cover(ci, "hive_sky", view, cam, 0.14, alpha, 0.10)
		"cliff":
			_cover(ci, "cliff_sky", view, cam, 0.08, alpha, 0.03, 0.9, Color(1.0, 0.94, 0.9))
			_clouds(ci, view, cam.x * 0.06 + time * 30.0, alpha)
		"canyon":
			_cover(ci, "canyon_sky", view, cam, 0.08, alpha, 0.03)
			_layer(ci, "rib_layer", view, cam, 0.22, view.y * 0.10, view.y * 0.95, alpha * 0.85)
