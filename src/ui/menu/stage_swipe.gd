class_name StageSwipe
extends RefCounted
## One pointer owns a horizontal stage-selection gesture. A swipe must not
## also activate the card on release, including at the end of the catalogue.
var consumed := false
var _active := false
var _touch := false
var _index := -1
var _start := Vector2.ZERO

func handle(event: InputEvent, bounds: Rect2, turn: Callable) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed and not _active:
			_begin(event.position, bounds, true, event.index)
		elif not event.pressed and _touch and event.index == _index:
			_active = false
	elif event is InputEventScreenDrag:
		if _active and _touch and event.index == _index:
			return _track(event.position, turn)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _active:
			_begin(event.position, bounds, false, -1)
		elif not event.pressed and not _touch:
			_active = false
	elif event is InputEventMouseMotion and _active and not _touch:
		return _track(event.position, turn)
	return false

func _begin(at: Vector2, bounds: Rect2, touch: bool, index: int) -> void:
	if not bounds.has_point(at): return
	_active = true
	_touch = touch
	_index = index
	_start = at
	consumed = false

func _track(at: Vector2, turn: Callable) -> bool:
	var distance := at - _start
	if absf(distance.x) < 90.0 or absf(distance.x) < absf(distance.y) * 1.4: return false
	consumed = true
	_active = false
	turn.call(1 if distance.x < 0 else -1)
	return true
