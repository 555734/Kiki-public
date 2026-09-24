extends Node2D
## The open sea of stage 1-4, drawn in the world.
##
## Everything below the waterline is water: a deep body, a bright turquoise
## band under a rolling surface, glints, and foam where the sea meets a beach,
## a rock or a pier post. Only the part of the sea on screen is drawn, and it is
## redrawn every frame so the surface moves; the cost is a few polygons whatever
## the length of the stage.
##
## It sits behind the terrain (the beaches run down into it) but in front of the
## rock and pier paintings, so their feet are under the water. The foam is a
## child drawn in front of the terrain, where the shore actually shows.

const DEEP := Color(0.10, 0.42, 0.74, 0.90)
const BAND := Color(0.24, 0.76, 0.90, 0.88)
const LINE := Color(0.88, 0.98, 1.0, 0.85)
const FOAM := Color(1.0, 1.0, 1.0, 0.82)

var water_y: float = 500.0
## x positions where something stands in the water, for the foam.
var shore_x: PackedFloat32Array = PackedFloat32Array()

var _time: float = 0.0
var _foam: Node2D = null

func _ready() -> void:
	z_index = 1
	_foam = Node2D.new()
	_foam.z_index = 2      # relative: in front of the terrain (z 2)
	_foam.draw.connect(_draw_foam)
	add_child(_foam)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	_foam.queue_redraw()

## The world x range on screen, with a margin.
func _visible_x() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(-2000, 12000)
	var inv := vp.get_canvas_transform().affine_inverse()
	var r := vp.get_visible_rect()
	var a := inv * r.position
	var b := inv * r.end
	return Vector2(minf(a.x, b.x) - 80.0, maxf(a.x, b.x) + 80.0)

func surface(x: float) -> float:
	return water_y + sin(x * 0.012 + _time * 1.6) * 5.0 + sin(x * 0.031 - _time * 2.3) * 2.5

func _draw() -> void:
	var span := _visible_x()
	var step := 24.0
	var top := PackedVector2Array()
	var x := floorf(span.x / step) * step
	while x <= span.y + step:
		top.append(Vector2(x, surface(x)))
		x += step
	if top.size() < 2:
		return
	# Deep water, all the way down past anything the camera can show.
	var body := PackedVector2Array(top)
	body.append(Vector2(top[top.size() - 1].x, water_y + 1400.0))
	body.append(Vector2(top[0].x, water_y + 1400.0))
	draw_colored_polygon(body, DEEP)
	# The bright shallow band just under the surface.
	var band := PackedVector2Array(top)
	for i in range(top.size() - 1, -1, -1):
		band.append(top[i] + Vector2(0.0, 46.0 + sin(top[i].x * 0.02) * 6.0))
	draw_colored_polygon(band, BAND)
	# Light ripples further down.
	for row in range(3):
		var y := water_y + 90.0 + float(row) * 70.0
		var drift := _time * (18.0 + float(row) * 7.0)
		var gap := 210.0 + float(row) * 40.0
		var gx := floorf((span.x - drift) / gap) * gap + drift
		while gx < span.y:
			var w := 50.0 + DrawUtil.hash01(int(gx / gap) * 7 + row) * 60.0
			draw_line(Vector2(gx, y), Vector2(gx + w, y), Color(1, 1, 1, 0.13), 3.0)
			gx += gap
	# The surface line and its glints.
	draw_polyline(top, LINE, 3.0, true)
	var gx2 := floorf(span.x / 90.0) * 90.0
	while gx2 < span.y:
		var h := DrawUtil.hash01(int(gx2 / 90.0) * 13 + 5)
		var tw := 0.5 + 0.5 * sin(_time * (2.0 + h * 3.0) + h * TAU)
		if tw > 0.55:
			var at := Vector2(gx2 + h * 60.0, surface(gx2 + h * 60.0) + 12.0 + h * 20.0)
			draw_line(at - Vector2(9.0, 0.0), at + Vector2(9.0, 0.0),
				Color(1, 1, 1, (tw - 0.55) * 1.6), 2.0)
		gx2 += 90.0

func _draw_foam() -> void:
	var span := _visible_x()
	for sx in shore_x:
		if sx < span.x - 60.0 or sx > span.y + 60.0:
			continue
		var y := surface(sx)
		var pulse := 0.5 + 0.5 * sin(_time * 2.4 + sx * 0.05)
		for k in range(4):
			var off := (float(k) - 1.5) * 16.0
			var r := 9.0 + pulse * 4.0 - absf(off) * 0.12
			_foam.draw_circle(Vector2(sx + off, y + 2.0), r, FOAM)
		_foam.draw_line(Vector2(sx - 40.0, y + 3.0), Vector2(sx + 40.0, y + 3.0),
			Color(1, 1, 1, 0.55), 3.0)
