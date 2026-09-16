class_name DrawUtil
extends RefCounted
## Shared shape helpers for the procedural artwork.
##
## The whole game is drawn from code -- there is not a single image file in the
## project -- so these are the primitives everything else is built out of.

const ARC_SEGMENTS := 6

## A rectangle with rounded corners, as a filled polygon.
static func rounded_rect(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	ci.draw_colored_polygon(rounded_rect_points(rect, radius), color)

static func rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var corners := [
		[Vector2(rect.position.x + rect.size.x - r, rect.position.y + r), -PI * 0.5],
		[Vector2(rect.position.x + rect.size.x - r, rect.position.y + rect.size.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.position.y + rect.size.y - r), PI * 0.5],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	for corner in corners:
		var center: Vector2 = corner[0]
		var start: float = corner[1]
		for i in range(ARC_SEGMENTS + 1):
			var a: float = start + (PI * 0.5) * (float(i) / float(ARC_SEGMENTS))
			points.append(center + Vector2(cos(a), sin(a)) * r)
	return points

## A thick line with round caps, used for limbs and scarves.
static func limb(ci: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	ci.draw_line(from, to, color, width)
	ci.draw_circle(from, width * 0.5, color)
	ci.draw_circle(to, width * 0.5, color)

## An outlined polygon: fill plus a closed border of the given width.
static func poly_outlined(ci: CanvasItem, points: PackedVector2Array, fill: Color, line: Color, width: float) -> void:
	if points.size() < 3:
		return
	ci.draw_colored_polygon(points, fill)
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	ci.draw_polyline(closed, line, width)

## A scalloped top edge -- the bumpy grass cap in the mockups.
static func scalloped_top(width: float, bump: float, phase: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(1, int(round(width / bump)))
	var step := width / float(count)
	for i in range(count + 1):
		var x := float(i) * step
		var y := -absf(sin(PI * (float(i) * 0.5 + phase))) * bump * 0.55
		points.append(Vector2(x, y))
	return points

## Deterministic pseudo-random in [0,1) from an integer seed. Used so that
## procedural decoration (cloud positions, dirt strata) is stable across frames
## and across runs, which keeps screenshots comparable.
static func hash01(n: int) -> float:
	var x := (n << 13) ^ n
	var h := (x * (x * x * 15731 + 789221) + 1376312589) & 0x7fffffff
	return float(h) / 2147483647.0
