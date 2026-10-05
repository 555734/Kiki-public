class_name StickGesture
extends TouchGesture
## The runner's virtual stick: sideways is movement, a deliberate down lets go
## of a ledge.

var finger: int = -1
var anchor: Vector2 = Vector2.ZERO
## Where the thumb is, for the HUD to draw.
var thumb: Vector2 = Vector2.ZERO

func begin(index: int, position: Vector2, size: Vector2, _id: String) -> void:
	finger = index
	anchor = position if ControlLayout.floating_stick(hub.layout_mode()) else hub.cluster(size)["stick"]["center"]
	apply(position, size)

func drag(_index: int, position: Vector2, size: Vector2) -> void:
	apply(position, size)

func end(_index: int, _position: Vector2, _cancelled: bool, _previous: Variant) -> void:
	finger = -1
	hub.move_axis = 0.0
	hub.move_axis_y = 0.0
	hub._jump_from_stick = false
	hub._refresh_jump_held()

func reset() -> void:
	finger = -1

func apply(position: Vector2, size: Vector2) -> void:
	thumb = position
	var place := hub.stick_place(size)
	if place.is_empty():
		return
	var anchor: Vector2 = place["center"]
	var travel_px: float = maxf(ControlLayout.stick_travel(place), 1.0)

	var up := anchor.y - position.y
	var in_jump_zone := Options.stick_jump() and up > travel_px * ControlLayout.STICK_JUMP_FRACTION
	var entered_jump_zone := in_jump_zone and not hub._jump_from_stick
	hub._jump_from_stick = in_jump_zone
	hub._refresh_jump_held()
	if entered_jump_zone:
		hub._latch_jump_press()

	hub.move_axis_y = clampf(-up / travel_px, -1.0, 1.0)
	if Options.responsive_touch() and -up < absf(position.x - anchor.x) * 0.85:
		hub.move_axis_y = minf(hub.move_axis_y, 0.0)

	var dx: float = position.x - anchor.x
	if not hub.runner_on_left:
		dx = -dx
	var dead: float = travel_px * 0.07 if Options.responsive_touch() else ControlLayout.stick_deadzone(place)
	if absf(dx) <= dead:
		hub.move_axis = 0.0
		return
	var travel: float = travel_px * 0.55 if Options.responsive_touch() else travel_px
	var reach := (absf(dx) - dead) / maxf(travel - dead, 1.0)
	hub.move_axis = clampf(reach, 0.0, 1.0) * signf(dx)
