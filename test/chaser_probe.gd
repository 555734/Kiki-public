extends Node
## Focused regression probe for the pursuit prototype.
## Run with:
## godot --headless --path . res://test/chaser_probe.tscn

const BlackHoleChaserScript = preload("res://src/entities/enemies/black_hole_chaser.gd")

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _ready() -> void:
	var runner := Runner.new()
	runner.name = "ProbeRunner"
	runner.global_position = Vector2.ZERO
	add_child(runner)
	runner.set_physics_process(false)

	var chaser = BlackHoleChaserScript.new()
	chaser.name = "ProbeChaser"
	chaser.runner = runner
	chaser.global_position = Vector2(-420.0, 0.0)
	add_child(chaser)
	chaser.set_physics_process(false)

	check(chaser.is_in_group("enemy"), "chaser participates in normal enemy networking")
	check(chaser.is_in_group("instant_death"), "chaser contact is marked instant death")
	check(chaser.global_position.x < runner.global_position.x, "chaser starts behind runner")

	var asleep_x: float = float(chaser.global_position.x)
	chaser._physics_process(1.0 / 60.0)
	check(chaser.velocity.is_zero_approx(),
		"chaser stays idle while runner has not left the start")
	check(is_equal_approx(chaser.global_position.x, asleep_x),
		"idle chaser does not drift")

	# move_and_slide() is meaningful on a real physics tick. Calling a physics
	# method manually from _ready can set velocity without advancing the body,
	# so exercise the same scheduling the game actually uses.
	runner.global_position.x = 120.0
	chaser.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	chaser.set_physics_process(false)
	check(chaser.velocity.x > 0.0, "chaser aims toward runner after activation")
	check(chaser.global_position.x > asleep_x, "chaser moves toward runner after activation")

	runner._resolve_hazard(chaser)
	check(runner.state == Runner.State.DEAD, "touching chaser kills runner immediately")

	chaser.queue_free()
	runner.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("chaser probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("chaser probe: " + failure)
		get_tree().quit(1)
