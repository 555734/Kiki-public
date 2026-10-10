extends Area2D
var owner_actor: ParadeActor
func shot_position() -> Vector2: return global_position
func take_damage(amount: int, by: String = "snipe") -> void:
	if is_instance_valid(owner_actor): owner_actor.take_damage(amount, by)
