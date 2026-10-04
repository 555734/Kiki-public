class_name ButtonGesture
extends TouchGesture
## A control that does its whole job on the press: the scope and undo buttons.

func begin(_index: int, _position: Vector2, _size: Vector2, _id: String) -> void:
	match role:
		"scope":
			hub.press_scope()
		"undo":
			hub._undo_latched = true
