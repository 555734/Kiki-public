class_name GuardianAbility
extends RefCounted
## One of the guardian's three tools. Chapter 4 is emphatic that there are only
## ever three, and that their depth comes from combination rather than from
## upgrades -- so this base class stays thin on purpose.

var slot: int = 0
var cost: float = 0.0
var display_name: String = ""

## Returns "" when the ability may fire, or a short reason code the HUD can show.
func check(_guardian: Node, _world_pos: Vector2) -> String:
	return ""

func execute(_guardian: Node, _world_pos: Vector2) -> void:
	pass

## Optional per-frame preview drawn under the cursor (mockup 2's dashed ghost).
## Returns { "kind": String, "rect": Rect2, "valid": bool } or an empty dict.
func preview(_guardian: Node, _world_pos: Vector2) -> Dictionary:
	return {}
