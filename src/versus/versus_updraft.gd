extends Updraft
## Co-op's Updraft for the star battle: the same column of air, lifting every
## runner this device moves itself.

var riders: Array = []

func _physics_process(delta: float) -> void:
	for who in riders:
		if who == null or not is_instance_valid(who) or not who.is_physics_processing():
			continue
		if not holds(who.global_position):
			continue
		_occupied = 1.0
		who.velocity.y = move_toward(
			who.velocity.y, -Balance.UPDRAFT_RISE, Balance.UPDRAFT_ACCEL * delta)
		who.velocity.x = move_toward(
			who.velocity.x, 0.0, Balance.UPDRAFT_DRAG * delta)
