class_name ArenaStage
## The collision world the arena runs against: a list of static boxes.
##
## Deliberately NOT Godot's physics bodies. docs/coin-battle-plan.md 7.2 asks
## for a `step(state, input, collision_world, dt)` that the host and a client's
## prediction can both call, and a prediction has to re-run the same tick many
## times. Re-running means moving a body, reading `is_on_floor()`, rewinding and
## doing it again -- and `is_on_floor()` is a cached result of the last
## move_and_slide, not a property of a position. Owning the sweep keeps that
## answer in a struct that can be saved and restored.
##
## It is affordable because the plan's arena is nothing but static axis-aligned
## rectangles (6.1). The moment one-way platforms or moving floors arrive this
## has to be revisited, which is why the plan puts them out of scope.

var _boxes: Array[Rect2] = []

func _init(boxes: Array[Rect2] = []) -> void:
	_boxes = boxes.duplicate()

static func from_data() -> ArenaStage:
	return ArenaStage.new(ArenaStageData.floors())

func boxes() -> Array[Rect2]:
	return _boxes

## Does this body box overlap any floor?
##
## Rect2.intersects() with include_borders left false, so a body resting exactly
## on a surface is touching rather than overlapping. Without that a fighter
## standing still would be reported as inside the floor every tick.
func overlaps(body: Rect2) -> bool:
	for b in _boxes:
		if b.intersects(body, false):
			return true
	return false

## Move a body and stop at the first thing in the way, axis by axis.
##
## Returns {"position", "grounded", "hit_ceiling", "hit_wall"}. Horizontal first
## then vertical, which is what lets a fighter walk along a floor instead of
## catching on the seam between two boxes.
func sweep(centre: Vector2, size: Vector2, motion: Vector2) -> Dictionary:
	var pos := centre
	var grounded := false
	var ceiling := false
	var wall := false

	if motion.x != 0.0:
		var want := Vector2(pos.x + motion.x, pos.y)
		if overlaps(_body_at(want, size)):
			pos = _resolve_axis(pos, size, Vector2(motion.x, 0.0))
			wall = true
		else:
			pos = want

	if motion.y != 0.0:
		var want_y := Vector2(pos.x, pos.y + motion.y)
		if overlaps(_body_at(want_y, size)):
			pos = _resolve_axis(pos, size, Vector2(0.0, motion.y))
			if motion.y > 0.0:
				grounded = true
			else:
				ceiling = true
		else:
			pos = want_y

	# Standing still on a floor still counts as grounded; without this a fighter
	# who did not move vertically this tick would be told they were airborne and
	# would lose their jump.
	if not grounded and motion.y >= 0.0:
		grounded = on_floor(pos, size)

	return {
		"position": pos, "grounded": grounded,
		"hit_ceiling": ceiling, "hit_wall": wall,
	}

## A floor directly underfoot, within a pixel.
func on_floor(centre: Vector2, size: Vector2) -> bool:
	var probe := _body_at(Vector2(centre.x, centre.y + 1.0), size)
	return overlaps(probe)

## The nearest floor top below a point, or INF.
func floor_below(at: Vector2, within: float) -> float:
	var best := INF
	for b in _boxes:
		if at.x < b.position.x or at.x > b.position.x + b.size.x:
			continue
		var top := b.position.y
		if top >= at.y and top - at.y <= within and top < best:
			best = top
	return best

## Is the straight line between two points clear of terrain?
##
## Used so an attack does not reach through a floor (4.2) and a coin cannot be
## taken through one (3.2). Sampled rather than solved: the boxes are few and
## the distances are tens of pixels.
func line_clear(from: Vector2, to: Vector2) -> bool:
	var span := to - from
	var steps := int(ceil(span.length() / 6.0))
	if steps <= 0:
		return true
	for i in range(1, steps):
		var p := from + span * (float(i) / float(steps))
		for b in _boxes:
			if b.has_point(p):
				return false
	return true

func _body_at(centre: Vector2, size: Vector2) -> Rect2:
	return Rect2(centre - size * 0.5, size)

## Binary search the last position along `motion` that is still clear.
##
## Eight passes puts a 600px/tick move inside a quarter pixel, and the whole
## thing stays a pure function of the boxes -- which is what the re-simulation
## in section 9.3 needs.
func _resolve_axis(from: Vector2, size: Vector2, motion: Vector2) -> Vector2:
	var lo := 0.0
	var hi := 1.0
	for i in range(8):
		var mid := (lo + hi) * 0.5
		if overlaps(_body_at(from + motion * mid, size)):
			hi = mid
		else:
			lo = mid
	return from + motion * lo
