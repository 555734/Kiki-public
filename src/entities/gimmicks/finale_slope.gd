class_name FinaleSlope
extends StaticBody2D
## Sloped or arched ground for 1-10: hills, the magma downhill, tilted
## ledges and the thin fossil rib bridges. The runner already handles slopes
## up to 50 degrees (floor_max_angle), so this is only collision + paint.
##
## `points` is the walkable top, left to right, relative to the node. A
## `thick` value makes a bridge of that thickness that follows the curve;
## otherwise the polygon closes straight down `depth` below the lowest point.

var points := PackedVector2Array()
var depth := 400.0
var thick := 0.0
var skin := "grass"
var _poly := PackedVector2Array()

static func from_spec(spec: Dictionary, _runner: Runner) -> Node2D:
	var s := FinaleSlope.new()
	s.points = spec.get("points", PackedVector2Array([Vector2.ZERO, Vector2(200, 0)]))
	s.depth = float(spec.get("depth", 400.0))
	s.thick = float(spec.get("thick", 0.0))
	s.skin = String(spec.get("skin", "grass"))
	return s

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 2
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_to_group("finale_slope")
	_poly = polygon()
	var shape := CollisionPolygon2D.new()
	shape.polygon = _poly
	add_child(shape)

## Closed outline, local space.
func polygon() -> PackedVector2Array:
	var poly := PackedVector2Array(points)
	if thick > 0.0:
		for i in range(points.size() - 1, -1, -1):
			poly.append(points[i] + Vector2(0, thick))
		return poly
	var low := -INF
	for p in points:
		low = maxf(low, p.y)
	poly.append(Vector2(points[-1].x, low + depth))
	poly.append(Vector2(points[0].x, low + depth))
	return poly

## The walkable height at a world x, or INF outside the slope.
func top_at(world_x: float) -> float:
	var x := world_x - global_position.x
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		if x >= a.x and x <= b.x:
			return global_position.y + lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return INF

func _draw() -> void:
	FinaleArt.slope_on(self, points, _poly, skin)
