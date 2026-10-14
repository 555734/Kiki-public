extends FinaleMachine
## Painted dressing: trees, ruins, chains, lavafalls, aqueducts, fossil ribs.
## No collision and no simulation; Godot caches the drawing. Items marked
## `front` are drawn by a child above the terrain and the runner.

var _front: Node2D

func _build() -> void:
	z_index = -1
	_front = Front.new()
	_front.owner_scenery = self
	_front.z_index = 9
	add_child(_front)

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
			_waterfall(ci, at, h, 150.0)
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
			FinaleArt.sprite(ci, "arch", at + Vector2(0, 6), h, flip, Color(0.98, 0.93, 0.82))
		"drip":
			_drip(ci, at, h)
		_:
			FinaleArt.sprite(ci, key, at, h, flip)

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

## The 1-3 waterfall painting: its sheet of water stretched to the height,
## its foam drawn once where it lands.
func _waterfall(ci: CanvasItem, bottom: Vector2, height: float, width: float) -> void:
	var t := FinaleArt.tex("waterfall")
	if t == null:
		return
	var tw := float(t.get_width())
	var th := float(t.get_height())
	var foam := width * th / tw * 0.42
	ci.draw_texture_rect_region(t, Rect2(bottom.x - width * 0.5, bottom.y - height, width, height - foam),
		Rect2(0, th * 0.08, tw, th * 0.40), Color(1, 1, 1, 0.92))
	ci.draw_texture_rect_region(t, Rect2(bottom.x - width * 0.5, bottom.y - foam, width, foam),
		Rect2(0, th * 0.58, tw, th * 0.42), Color(1, 1, 1, 0.95))

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
	cols.fill(Color(0.86, 0.8, 0.7))
	ci.draw_polygon(poly, cols, uvs, t)
	var line := PackedVector2Array(poly)
	line.append(poly[0])
	ci.draw_polyline(line, Color("6b5642"), 4.0, true)

func _drip(ci: CanvasItem, top: Vector2, length: float) -> void:
	var honey := Color("ffb21e")
	var w := 18.0
	ci.draw_rect(Rect2(top.x - w * 0.5, top.y, w, length - w), honey)
	ci.draw_circle(Vector2(top.x, top.y + length - w), w * 0.75, honey)
	ci.draw_line(Vector2(top.x - 3, top.y), Vector2(top.x - 3, top.y + length - w * 1.5), Color("fff0b0"), 3.0)
