class_name TouchGesture
extends RefCounted
## One kind of thing a finger can be doing: holding the stick, pressing jump,
## aiming at the world.
##
## TouchRouter decides which gesture a new finger belongs to and calls begin,
## drag and end on it. A gesture keeps its own state and writes only the
## intents InputHub publishes. reset() is for when the device loses track of
## every finger, so each gesture forgets everything it holds right here, next
## to the fields it declares.

var hub: InputHub
## The name the router reports for a finger owned by this gesture.
var role: String

func _init(owner_hub: InputHub, role_name: String) -> void:
	hub = owner_hub
	role = role_name

## A finger has come down on this gesture. `id` is the control that was hit
## ("slot_2", "pan_left"...), or the role for a gesture with no control.
func begin(_index: int, _position: Vector2, _size: Vector2, _id: String) -> void:
	pass

func drag(_index: int, _position: Vector2, _size: Vector2) -> void:
	pass

## The finger has lifted. `position` is INF when the release carried no
## position; `previous` is where the finger was last seen before this, or
## null. A cancelled end is a finger the device lost, not one the player
## lifted, so it must not commit anything.
func end(_index: int, _position: Vector2, _cancelled: bool, _previous: Variant) -> void:
	pass

## Forget every finger. Called after every owned finger has been ended
## cancelled, so this only has to clear what that left behind.
func reset() -> void:
	pass
