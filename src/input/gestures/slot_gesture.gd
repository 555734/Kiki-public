class_name SlotGesture
extends TouchGesture
## A tool button. Holding it is aiming with that tool; letting go uses it.
## Dragged out onto the world, the release is also where it goes.

var finger: int = -1
var held: int = -1
var dragged: bool = false

func begin(index: int, _position: Vector2, _size: Vector2, id: String) -> void:
	finger = index
	held = int(id.substr(5))
	dragged = false

func drag(_index: int, position: Vector2, _size: Vector2) -> void:
	dragged = true
	hub.aim_at_screen(position)

func end(index: int, position: Vector2, cancelled: bool, _previous: Variant) -> void:
	if position.x != INF:
		hub.aim_at_screen(position)
	if not cancelled:
		hub._slot_latched_dragged = dragged
		hub.press_slot(held)
		if dragged and not hub.touch.over_a_control(index):
			hub._place_latched = hub.touch.world_under(index)
	reset()

func reset() -> void:
	finger = -1
	held = -1
	dragged = false
