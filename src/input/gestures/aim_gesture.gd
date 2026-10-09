class_name AimGesture
extends TouchGesture
## A finger on the world aims the shot or draws a platform. Dragging while
## shooting never changes the camera. A tap commits the current tool.

## The finger most recently put on the world, or -1. Several can be down; any
## of them lifting means nobody is aiming any more.
var finger: int = -1
var trace_finger: int = -1
## Per finger: where it was last frame. Rewritten on every move, so it is not
## the origin of the gesture -- see moved.
var from: Dictionary = {}
var from_y: Dictionary = {}
## Distance covered since the finger went down, per finger. Accumulated rather
## than measured start-to-end: `from` holds the PREVIOUS position, not the
## origin, and the reticle itself is rate limited, so neither of them can
## answer "has this finger moved". A finger that wanders out and comes back is
## a drag, and this counts it as one.
var moved: Dictionary = {}
## Per finger: the world points it has passed through and when it went down,
## so a quick stroke can be told apart from a drawn one -- see _swipe.
var stroke: Dictionary = {}
var stroke_ms: Dictionary = {}

## A stroke this fast and this long is a swipe of the hand, not a drawing.
const SWIPE_MAX_MS: int = 300
const SWIPE_MIN_LENGTH: float = 150.0

func begin(index: int, position: Vector2, _size: Vector2, _id: String) -> void:
	finger = index
	stroke[index] = PackedVector2Array([hub._screen_to_world(position)])
	stroke_ms[index] = Time.get_ticks_msec()
	if hub.trace_mode:
		trace_finger = index
		hub.trace_points = PackedVector2Array([hub._screen_to_world(position)])
	from[index] = position.x
	from_y[index] = position.y
	moved[index] = 0.0
	hub.aim_at_screen(position)

func drag(index: int, position: Vector2, _size: Vector2) -> void:
	var travel: float = position.x - float(from.get(index, position.x))
	moved[index] = float(moved.get(index, 0.0)) \
		+ Vector2(travel, position.y - float(from_y.get(index, position.y))).length()
	if index == trace_finger:
		hub.trace_points.append(hub._screen_to_world(position))
	if stroke.has(index):
		(stroke[index] as PackedVector2Array).append(hub._screen_to_world(position))
	hub.aim_at_screen(position)
	from[index] = position.x
	from_y[index] = position.y

func end(index: int, position: Vector2, cancelled: bool, previous: Variant) -> void:
	if position.x != INF:
		if previous != null:
			moved[index] = float(moved.get(index, 0.0)) + (position - Vector2(previous)).length()
		hub.aim_at_screen(position)
		if stroke.has(index):
			(stroke[index] as PackedVector2Array).append(hub._screen_to_world(position))
	if not cancelled:
		_swipe(index)
	if cancelled:
		if index == trace_finger:
			_end_trace()
	elif index == trace_finger:
		if position.x != INF:
			hub.trace_points.append(hub._screen_to_world(position))
		var made := InputHub.path_from_stroke(hub.trace_points)
		if not made.is_empty():
			hub._place_latched = made[0]
			hub._place_path = made[1]
		elif float(moved.get(index, 0.0)) <= InputHub.TAP_SLOP * 3.0:
			hub._place_latched = hub.touch.world_under(index)
			hub._place_path = PackedVector2Array()
		_end_trace()
	elif float(moved.get(index, 0.0)) <= InputHub.TAP_SLOP:
		hub._place_latched = hub.touch.world_under(index)
		hub._place_path = PackedVector2Array()
	finger = -1
	from.erase(index)
	from_y.erase(index)
	moved.erase(index)
	stroke.erase(index)
	stroke_ms.erase(index)

func reset() -> void:
	finger = -1
	from.clear()
	from_y.clear()
	moved.clear()
	stroke.clear()
	stroke_ms.clear()
	if trace_finger >= 0:
		_end_trace()

func _end_trace() -> void:
	trace_finger = -1
	hub.trace_points = PackedVector2Array()

## Report a quick, long stroke as a swipe. Whether it hit anything worth
## sweeping away -- and so whether it replaces the platform the same stroke
## may also have drawn -- is the guardian's question, not the finger's.
func _swipe(index: int) -> void:
	if not stroke.has(index):
		return
	var points: PackedVector2Array = stroke[index]
	if Time.get_ticks_msec() - int(stroke_ms.get(index, 0)) > SWIPE_MAX_MS:
		return
	var length := 0.0
	for i in range(1, points.size()):
		length += points[i].distance_to(points[i - 1])
	if length >= SWIPE_MIN_LENGTH:
		hub._hand_events.append({"type": "swipe", "points": points})
