class_name StrokePath
extends RefCounted
## The guardian's traced platform: a finger's stroke turned into the few
## straight pieces that are placed and sent over the wire.

## A traced platform keeps the stroke's shape, simplified: points closer than
## SPACING are finger jitter, bends smaller than TOLERANCE are
## straightened, and at most MAX_POINTS corners go over the wire.
const SPACING: float = 8.0
const TOLERANCE: float = 4.0
const MAX_POINTS: int = 16

## The platform a finished stroke describes: the stroke itself -- level,
## sloped, upright or bent -- smoothed down to a few straight pieces and cut
## off at TRACE_MAX_LENGTH. Returns [centre, path relative to centre], or []
## when the stroke was too short to be anything but a tap.
static func from_points(points: PackedVector2Array) -> Array:
	if points.size() < 2:
		return []
	# Drop the jitter of a finger that is barely moving.
	var spaced := PackedVector2Array([points[0]])
	for i in range(1, points.size()):
		if points[i].distance_to(spaced[spaced.size() - 1]) >= SPACING:
			spaced.append(points[i])
	if spaced.size() < 2 and points[points.size() - 1] != points[0]:
		spaced.append(points[points.size() - 1])
	if spaced.size() < 2:
		return []
	# Cut at the longest a platform may be.
	var capped := PackedVector2Array([spaced[0]])
	var length := 0.0
	for i in range(1, spaced.size()):
		var step := spaced[i - 1].distance_to(spaced[i])
		if length + step >= Balance.TRACE_MAX_LENGTH:
			var left := Balance.TRACE_MAX_LENGTH - length
			capped.append(spaced[i - 1] + (spaced[i] - spaced[i - 1]).normalized() * left)
			length = Balance.TRACE_MAX_LENGTH
			break
		capped.append(spaced[i])
		length += step
	if length < Balance.TRACE_MIN_WIDTH:
		return []
	var tolerance := TOLERANCE
	var simple := _simplify(capped, tolerance)
	while simple.size() > MAX_POINTS:
		tolerance *= 1.5
		simple = _simplify(capped, tolerance)
	var lo := simple[0]
	var hi := simple[0]
	for p in simple:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var centre := ((lo + hi) * 0.5).round()
	var local := PackedVector2Array()
	for p in simple:
		local.append((p - centre).round())
	return [centre, local]

## Ramer-Douglas-Peucker: the fewest corners that stay within `tolerance`.
static func _simplify(p: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if p.size() <= 2:
		return p
	var worst := 0.0
	var at := 0
	for i in range(1, p.size() - 1):
		var near := Geometry2D.get_closest_point_to_segment(p[i], p[0], p[p.size() - 1])
		var d := near.distance_to(p[i])
		if d > worst:
			worst = d
			at = i
	if worst <= tolerance:
		return PackedVector2Array([p[0], p[p.size() - 1]])
	var left := _simplify(p.slice(0, at + 1), tolerance)
	var right := _simplify(p.slice(at), tolerance)
	left.remove_at(left.size() - 1)
	left.append_array(right)
	return left
