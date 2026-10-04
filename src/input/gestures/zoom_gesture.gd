class_name ZoomGesture
extends TouchGesture
## The scope's zoom slider: a finger on it steps the zoom one notch at a time
## towards wherever it is held.

var finger: int = -1
var _value: float = -1.0

func begin(index: int, position: Vector2, size: Vector2, _id: String) -> void:
	finger = index
	apply(position, size)

func drag(_index: int, position: Vector2, size: Vector2) -> void:
	apply(position, size)

func end(_index: int, _position: Vector2, _cancelled: bool, _previous: Variant) -> void:
	finger = -1

func reset() -> void:
	finger = -1

func apply(position: Vector2, size: Vector2) -> void:
	var rect := TouchLayout.ZOOM_SLIDER
	var t := clampf((position.y / size.y - rect.position.y) / rect.size.y, 0.0, 1.0)
	var steps := Balance.SCOPE_ZOOM_STEPS.size()
	var target := int(round((1.0 - t) * float(steps - 1)))
	if _value < 0.0:
		_value = float(target)
	var current := int(round(_value))
	if target != current:
		hub._zoom_latched = signi(target - current)
		_value = float(target)
