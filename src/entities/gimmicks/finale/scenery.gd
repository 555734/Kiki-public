extends FinaleMachine
## Painted dressing: trees, ruins, chains, lavafalls, aqueducts, fossil ribs.
## No collision and no simulation; Godot caches the drawing. Items marked
## `front` are drawn by a child above the terrain and the runner.

var _front: Node2D
var _falls: Node2D

func _build() -> void:
	z_index = -1
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_front = Front.new()
	_front.owner_scenery = self
	_front.z_index = 9
	add_child(_front)
	for item in data.get("items", []):
		if String(item[0]) == "waterfall" and _falls == null:
			_falls = Falls.new()
			_falls.owner_scenery = self
			add_child(_falls)

## Waterfalls move, so they get their own canvas item that redraws each frame
## (only while on screen); the rest of the dressing stays cached.
class Falls extends Node2D:
	var owner_scenery
	func _process(_delta: float) -> void:
		var cam := get_viewport().get_camera_2d()
		if cam == null:
			return
		for item in owner_scenery.data.get("items", []):
			if String(item[0]) == "waterfall" and absf(float(item[1]) - cam.global_position.x) < 1400.0:
				queue_redraw()
				return
	func _draw() -> void:
		var t := float(Clock.tick) / float(Clock.HZ)
		for item in owner_scenery.data.get("items", []):
			if String(item[0]) == "waterfall":
				owner_scenery.waterfall(self, Vector2(float(item[1]), float(item[2])), float(item[3]), 150.0, t)

func _physics_process(_delta: float) -> void:
	pass

func _draw() -> void:
	for item in data.get("items", []):
		if not bool(item[5]):
			draw_item(self, item)

class Front extends Node2D:
	var owner_scenery
	func _draw() -> void:
		for item in owner_scenery.data.get("items", []):
			if bool(item[5]):
				owner_scenery.draw_item(self, item)

func draw_item(ci: CanvasItem, item: Array) -> void:
	var key := String(item[0])
	var at := Vector2(float(item[1]), float(item[2]))
	var h := float(item[3])
	var flip := bool(item[4])
	match key:
		"waterfall":
			pass
		"chain":
			_tiled_column(ci, "chain", Vector2(at.x, at.y + h), h, 34.0)
		"lavafall":
			FinaleArt.sprite(ci, "lavafall", at + Vector2(0, 30), h)
		"ruin_tower":
			FinaleArt.sprite(ci, "ruin_tower", at, h, flip, Color(0.55, 0.62, 0.82))
		"column", "broken_column", "arch", "broken_arch", "rubble":
			var tint := Color.WHITE
			if at.x > 3000 and at.x < 5900:
				tint = Color(0.62, 0.70, 0.90)
			FinaleArt.sprite(ci, key, at, h, flip, tint)
		"viaduct":
			FinaleArt.sprite(ci, "viaduct", at, h, flip, Color(0.92, 0.9, 0.86))
		"rib":
			_rib(ci, at, h, flip)
		"skull_rock":
			var t := FinaleArt.tex("skull_drone")
			if t != null:
				var w := h * 1.0
				ci.draw_texture_rect_region(t, Rect2(at.x - w * 0.5, at.y - h, w, h),
					Rect2(0, 34, 256, 222), Color(0.95, 0.9, 0.82))
		"jaw_gate":
			# Two colossal fangs curving over the way out: the gate the jaws
			# slam shut against.
			for side in [-1.0, 1.0]:
				var path: Array = []
				for k in 7:
					var t := float(k) / 6.0
					path.append(at + Vector2(side * (150.0 - 120.0 * t * t), -h * t + 10.0))
				FinaleGround.bone_on(ci, path, 62.0 - 0.0, int(at.x + side))
				ci.draw_colored_polygon(PackedVector2Array([path[-1] + Vector2(-26, 0), path[-1] + Vector2(26, 0), path[-1] + Vector2(-side * 10.0, 60)]), FinaleGround.BONE_SHADE)
		"drip":
			_drip(ci, at, h)
		"abyss":
			_abyss(ci, at, h, float(item[6]) if item.size() > 6 else 600.0, float(item[7]) if item.size() > 7 else 10.0)
		"canyon_haze":
			_haze(ci, at, h, float(item[6]) if item.size() > 6 else 600.0, Color(0.42, 0.16, 0.08))
		_:
			FinaleArt.sprite(ci, key, at, h, flip)

## Depth filling a chasm, so a drop reads as a drop even when the floor is
## out of frame. `at` is the top-left corner. `drop`: how far under the lip
## the first far ridge starts. Small: a near back wall just under the lip.
## Large (an open gorge): nothing stands behind a runner in the air; under
## them, ridge after ridge of the gorge's far side sinks into blue-black
## haze, and the scenery behind is covered so no meadow shows at the bottom.
func _abyss(ci: CanvasItem, at: Vector2, height: float, width: float, drop: float = 10.0) -> void:
	var deep := Color(0.03, 0.06, 0.13)
	var tex := FinaleArt._load("res://assets/stage_1_10/tex_slate.png")
	var n := 18
	# Three ridges, each further down and further into the haze.
	var layers := 1 if drop < 100.0 else 3
	for l in layers:
		var top_y := at.y + drop + float(l) * 170.0
		var wall := PackedVector2Array()
		for k in n + 1:
			var x := at.x - 30.0 + (width + 60.0) * float(k) / float(n)
			var jag := sin(float(k) * 1.7 + float(l) * 2.3) * 26.0 + FinaleGround.h(k * 13 + l * 5) * 46.0
			wall.append(Vector2(x, top_y + jag))
		wall.append(Vector2(at.x + width + 30.0, at.y + height))
		wall.append(Vector2(at.x - 30.0, at.y + height))
		var wc := PackedColorArray()
		var uv := PackedVector2Array()
		var fade := float(l) / 3.0
		for p in wall:
			if layers == 1:
				var k1 := clampf((p.y - top_y) / 700.0, 0.0, 1.0)
				wc.append(Color(1.25, 1.3, 1.4).lerp(Color(0.10, 0.13, 0.22), sqrt(k1)))
				continue
			# Far side of the gorge: pale and blue at the top (air between
			# it and the runner), darker lower down, the deeper ridges
			# already dimmer where they start.
			var k2 := clampf((p.y - top_y) / 380.0, 0.0, 1.0)
			var lit := Color(0.42, 0.52, 0.70).lerp(Color(0.20, 0.27, 0.42), fade)
			wc.append(lit.lerp(Color(0.04, 0.06, 0.13), sqrt(k2)))
			uv.append(p / (300.0 + 90.0 * float(l)))
		if layers > 1:
			# Mostly the haze's colour: the slate shows through faintly.
			ci.draw_polygon(wall, wc)
		if tex != null:
			if layers > 1:
				var faint := PackedColorArray()
				for c in wc:
					faint.append(Color(c.r * 1.1, c.g * 1.1, c.b * 1.1, 0.18))
				ci.draw_polygon(wall, faint, uv, tex)
			else:
				ci.draw_polygon(wall, wc, uv, tex)
		var ridge := PackedVector2Array()
		for k in n + 1:
			ridge.append(wall[k])
		ci.draw_polyline(ridge, Color(0.16, 0.18, 0.30, 0.8 - 0.2 * float(l)), 4.0, true)
		# Haze between the ridges: each one sits deeper in the blue.
		if layers > 1:
			ci.draw_polygon(PackedVector2Array([Vector2(at.x - 30, top_y - 60), Vector2(at.x + width + 30, top_y - 60),
				Vector2(at.x + width + 30, top_y + 260), Vector2(at.x - 30, top_y + 260)]),
				PackedColorArray([Color(0.70, 0.82, 0.95, 0.0), Color(0.70, 0.82, 0.95, 0.0),
				Color(0.55, 0.68, 0.85, 0.22), Color(0.55, 0.68, 0.85, 0.22)]))
	var start := at.y + (drop if layers > 1 else 0.0)
	var mid := start + (height - (start - at.y)) * 0.4
	ci.draw_polygon(PackedVector2Array([Vector2(at.x, start), Vector2(at.x + width, start), Vector2(at.x + width, mid), Vector2(at.x, mid)]),
		PackedColorArray([Color(deep, 0.0), Color(deep, 0.0), Color(deep, 0.55), Color(deep, 0.55)]))
	ci.draw_polygon(PackedVector2Array([Vector2(at.x, mid), Vector2(at.x + width, mid), at + Vector2(width, height), at + Vector2(0, height)]),
		PackedColorArray([Color(deep, 0.55), Color(deep, 0.55), Color(deep, 1.0), Color(deep, 1.0)]))
	for i in 4:
		var y := start + 120.0 + 170.0 * float(i)
		var mist := Color(0.75, 0.88, 1.0, 0.10 - 0.018 * float(i))
		var band := PackedVector2Array()
		for k in 13:
			var x := at.x + width * float(k) / 12.0
			band.append(Vector2(x, y + sin(float(k) * 1.3 + float(i) * 2.0) * 14.0))
		ci.draw_polyline(band, mist, 46.0 - 6.0 * float(i), true)

## Depth haze without a back wall (the canyon has its painted backdrop):
## clear at the top, `deep` and nearly opaque at the bottom.
func _haze(ci: CanvasItem, at: Vector2, height: float, width: float, deep: Color) -> void:
	var mid := at.y + height * 0.5
	ci.draw_polygon(PackedVector2Array([at, at + Vector2(width, 0), Vector2(at.x + width, mid), Vector2(at.x, mid)]),
		PackedColorArray([Color(deep, 0.0), Color(deep, 0.0), Color(deep, 0.45), Color(deep, 0.45)]))
	ci.draw_polygon(PackedVector2Array([Vector2(at.x, mid), Vector2(at.x + width, mid), at + Vector2(width, height), at + Vector2(0, height)]),
		PackedColorArray([Color(deep, 0.45), Color(deep, 0.45), Color(deep, 0.9), Color(deep, 0.9)]))

func _tiled_column(ci: CanvasItem, key: String, bottom: Vector2, height: float, width: float,
		tint: Color = Color.WHITE) -> void:
	var t := FinaleArt.tex(key)
	if t == null:
		return
	var tile_h := width * float(t.get_height()) / float(t.get_width())
	var y := bottom.y - height
	while y < bottom.y - 1.0:
		var h := minf(tile_h, bottom.y - y)
		ci.draw_texture_rect_region(t, Rect2(bottom.x - width * 0.5, y, width, h),
			Rect2(0, 0, t.get_width(), t.get_height() * h / tile_h), tint)
		y += h

## A painted waterfall: a translucent sheet with streaks running down it,
## foam where it pours over the lip and mist where it lands. Driven by the
## shared Clock so every device (and every recording) shows the same water.
func waterfall(ci: CanvasItem, bottom: Vector2, height: float, width: float, t: float) -> void:
	var top := bottom.y - height
	var x0 := bottom.x - width * 0.5
	var x1 := bottom.x + width * 0.5
	var sheet := PackedVector2Array([Vector2(x0 + 6, top), Vector2(x1 - 6, top), Vector2(x1 + 4, bottom.y), Vector2(x0 - 4, bottom.y)])
	ci.draw_polygon(sheet, PackedColorArray([Color(0.38, 0.74, 1.0, 0.9), Color(0.38, 0.74, 1.0, 0.9),
		Color(0.16, 0.46, 0.9, 0.9), Color(0.16, 0.46, 0.9, 0.9)]))
	# Darker banks of the stream at both sides.
	ci.draw_line(Vector2(x0 + 8, top), Vector2(x0 - 1, bottom.y), Color(0.12, 0.38, 0.75, 0.55), 8.0)
	ci.draw_line(Vector2(x1 - 8, top), Vector2(x1 + 1, bottom.y), Color(0.12, 0.38, 0.75, 0.55), 8.0)
	# Streaks falling at two speeds.
	var streaks := PackedVector2Array()
	var faint := PackedVector2Array()
	for i in 13:
		var lane := x0 + 14.0 + float(i) * (width - 28.0) / 12.0
		var speed := 420.0 + float((i * 37) % 5) * 70.0
		var dash := 70.0 + float((i * 53) % 4) * 35.0
		var gap := dash * 1.6
		var y := top - fposmod(-t * speed + float(i) * 91.0, dash + gap)
		while y < bottom.y:
			var a := maxf(y, top)
			var b := minf(y + dash, bottom.y)
			if b > a:
				(streaks if i % 2 == 0 else faint).append(Vector2(lane, a))
				(streaks if i % 2 == 0 else faint).append(Vector2(lane, b))
			y += dash + gap
	if not faint.is_empty():
		ci.draw_multiline(faint, Color(1, 1, 1, 0.28), 5.0)
	if not streaks.is_empty():
		ci.draw_multiline(streaks, Color(1, 1, 1, 0.6), 3.0)
	# Mist where it lands (the top pours from above the view).
	for i in 7:
		var k := float(i) / 6.0
		var puff := 34.0 + 12.0 * sin(t * 2.3 + float(i) * 1.7)
		ci.draw_circle(Vector2(lerpf(x0 - 40.0, x1 + 40.0, k), bottom.y - 18.0 - 10.0 * sin(t * 3.0 + float(i))),
			puff, Color(1, 1, 1, 0.55))

## A colossal fossil rib: a textured curved band from the canyon floor.
func _rib(ci: CanvasItem, base: Vector2, height: float, flip: bool) -> void:
	var t := FinaleArt.tex("bone_tile")
	var side := -1.0 if flip else 1.0
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 25:
		var k := float(i) / 24.0
		var x := base.x + side * sin(k * PI * 0.85) * height * 0.32
		var y := base.y - k * height
		var w := lerpf(70.0, 34.0, k)
		outer.append(Vector2(x - w * 0.5, y))
		inner.append(Vector2(x + w * 0.5, y))
	inner.reverse()
	var poly := outer + inner
	var uvs := PackedVector2Array()
	for p in poly:
		uvs.append(p / 220.0)
	var cols := PackedColorArray()
	cols.resize(poly.size())
	# Background fossil: dimmer than the bones the runner stands on, so the
	# way across reads in front of it.
	cols.fill(Color(0.58, 0.44, 0.38, 0.8))
	ci.draw_polygon(poly, cols, uvs, t)
	var line := PackedVector2Array(poly)
	line.append(poly[0])
	ci.draw_polyline(line, Color(0.32, 0.2, 0.15, 0.7), 3.0, true)

func _drip(ci: CanvasItem, top: Vector2, length: float) -> void:
	var honey := Color("ffb21e")
	var w := 18.0
	ci.draw_rect(Rect2(top.x - w * 0.5, top.y, w, length - w), honey)
	ci.draw_circle(Vector2(top.x, top.y + length - w), w * 0.75, honey)
	ci.draw_line(Vector2(top.x - 3, top.y), Vector2(top.x - 3, top.y + length - w * 1.5), Color("fff0b0"), 3.0)
