class_name PanGesture
extends TouchGesture
## The guardian's look buttons. Held, they push the camera; slid off sideways,
## they scrub it, so a long look is one flick.

## finger index -> direction, while the thumb is still on its button.
var fingers: Dictionary = {}
## finger index -> last coordinate along the stage's direction of progress.
var drag_from: Dictionary = {}

func begin(index: int, position: Vector2, _size: Vector2, id: String) -> void:
	fingers[index] = -1.0 if id == "pan_left" else 1.0
	drag_from[index] = _along(position)
	refresh()

func drag(index: int, position: Vector2, _size: Vector2) -> void:
	var coordinate := _along(position)
	var from: float = drag_from.get(index, coordinate)
	hub._pan_drag += (coordinate - from) * -InputHub.PAN_DRAG_SCALE
	drag_from[index] = coordinate
	fingers.erase(index)
	refresh()

func end(index: int, _position: Vector2, _cancelled: bool, _previous: Variant) -> void:
	fingers.erase(index)
	drag_from.erase(index)
	refresh()

func reset() -> void:
	fingers.clear()
	drag_from.clear()
	refresh()

## Two thumbs on opposite arrows cancel, which is the only sane answer.
func refresh() -> void:
	var sum := 0.0
	for finger in fingers:
		sum += float(fingers[finger])
	hub.pan_axis = signf(sum)

func _along(position: Vector2) -> float:
	return position.y if Stage.progress_direction() == Vector2.UP else position.x
