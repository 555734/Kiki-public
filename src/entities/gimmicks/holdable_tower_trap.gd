class_name HoldableTowerTrap
extends TowerTrap
## A swinging ball or a dropping block the guardian's hand can press still --
## 1-9's ("holdable": true in the spec). Held, its clock stops where it is:
## the same HoldTimeline a boulder or a gate keeps, decided by the host.

## Numbered by the builder in spec order, the same on both devices.
var hand_id: int = -1

func _ready() -> void:
	super._ready()
	add_to_group("hand_holdable")

## Where a finger has to land to press it still: on the ball or the block.
func hand_grab_at(world: Vector2) -> bool:
	var reach := CASTLE_BALL * 0.6 if kind == "pendulum" else CASTLE_BLOCK.x * 0.55
	return world.distance_to(hand_point()) <= reach

func hand_point() -> Vector2:
	return global_position + head_at(Clock.tick)

func hold_begin(tick: int) -> void:
	hold.begin(tick)
	queue_redraw()

func hold_end(tick: int) -> void:
	hold.end(tick)
	queue_redraw()
