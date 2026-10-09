class_name HandGesture
extends TouchGesture
## A finger that came down ON something: the guardian's hand has taken hold of
## it. What the hand then does -- pull the runner back like a slingshot, flick
## a golem away, pinch a bullet, press a boulder still, hold a gate up -- is
## decided by Guardian from the target and from how the finger let go; this
## only reports the grab and the release.
##
## The router hands a finger here only when hub.hand_probe found a target under
## it, so a press on empty world is still the AimGesture's: aiming, tapping and
## drawing platforms are unchanged.

## How far back the release velocity looks. Long enough to smooth one jittery
## sample, short enough that a finger that stopped and then lifted reads as
## stopped.
const VELOCITY_WINDOW_MS: int = 90

## The finger holding something, or -1. One at a time: the guardian has one hand.
var finger: int = -1
var target: Dictionary = {}
var start_world: Vector2 = Vector2.ZERO
var _start_screen: Vector2 = Vector2.ZERO
var _moved: float = 0.0
## [msec, world point] samples for the release velocity, newest last.
var _samples: Array = []

func begin(index: int, position: Vector2, _size: Vector2, _id: String) -> void:
	finger = index
	target = hub._hand_pending
	hub._hand_pending = {}
	start_world = hub._screen_to_world(position)
	_start_screen = position
	_moved = 0.0
	_samples = [[InputHub.hand_ms(), start_world]]
	hub.aim_at_screen(position)
	hub.hand_state = {"target": target, "start": start_world}
	hub._hand_events.append({"type": "grab", "target": target, "at": start_world})

func drag(index: int, position: Vector2, _size: Vector2) -> void:
	if index != finger:
		return
	_moved = maxf(_moved, position.distance_to(_start_screen))
	hub.aim_at_screen(position)
	_sample(hub._screen_to_world(position))

func end(index: int, position: Vector2, cancelled: bool, _previous: Variant) -> void:
	if index != finger:
		return
	if position.x != INF:
		_moved = maxf(_moved, position.distance_to(_start_screen))
		hub.aim_at_screen(position)
		_sample(hub._screen_to_world(position))
	var at: Vector2 = _samples[_samples.size() - 1][1]
	# A tap on an enemy or on the runner is not the hand -- it is the tool, as
	# it always was: the rifle shoots what was tapped. Only a finger that
	# pulled or flicked was the hand.
	var kind := String(target.get("kind", ""))
	if not cancelled and _moved <= InputHub.TAP_SLOP and (kind == "enemy" or kind == "runner"):
		hub._place_latched = start_world
		hub._place_path = PackedVector2Array()
	hub._hand_events.append({"type": "release", "target": target, "from": start_world,
		"at": at, "velocity": _velocity(), "cancelled": cancelled})
	hub.hand_state = {}
	finger = -1
	target = {}
	_samples = []

func reset() -> void:
	finger = -1
	target = {}
	_samples = []
	hub.hand_state = {}

func _sample(at: Vector2) -> void:
	var now := InputHub.hand_ms()
	_samples.append([now, at])
	while _samples.size() > 2 and now - int(_samples[0][0]) > VELOCITY_WINDOW_MS:
		_samples.pop_front()

## World pixels per second over the last few samples.
func _velocity() -> Vector2:
	if _samples.size() < 2:
		return Vector2.ZERO
	var first: Array = _samples[0]
	var last: Array = _samples[_samples.size() - 1]
	var seconds := maxf(float(int(last[0]) - int(first[0])) / 1000.0, 1.0 / 120.0)
	return (Vector2(last[1]) - Vector2(first[1])) / seconds
