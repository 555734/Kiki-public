extends Spring
## Co-op's Spring for the star battle: the same pad, the same throw, for every
## runner this device moves itself (two on the keyboard test, one online).
## Other players' runners are puppets placed from the network; their own
## device throws them, and the pad here only squashes as they leave it.

var riders: Array = []

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_squash = maxf(0.0, _squash - delta * 4.0)
	queue_redraw()
	for who in riders:
		if who == null or not is_instance_valid(who):
			continue
		if _near(who) and who.velocity.y < -Balance.SPRING_VELOCITY * 0.5:
			_squash = 1.0
		if not who.is_physics_processing() or _cooldown > 0.0:
			continue
		if who.velocity.y < -1.0 or not _near(who):
			continue
		who.bounce(Balance.SPRING_VELOCITY)
		_cooldown = REARM
		_squash = 1.0
		Events.spring_bounced.emit(global_position)
