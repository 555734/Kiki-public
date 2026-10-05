class_name JumpGesture
extends TouchGesture
## The jump button. Two fingers can overlap it while the player changes grip:
## every finger down is a press edge, and only the last one up releases.

var fingers: Dictionary = {}

func begin(index: int, _position: Vector2, _size: Vector2, _id: String) -> void:
	fingers[index] = true
	# Every physical down is an edge. A stale held finger or a second thumb
	# must not make the button look pressed while Runner receives nothing.
	hub.press_jump()

func end(index: int, _position: Vector2, _cancelled: bool, _previous: Variant) -> void:
	fingers.erase(index)
	if fingers.is_empty():
		hub.release_jump()

func reset() -> void:
	fingers.clear()
