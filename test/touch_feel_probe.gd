extends Node

var failures := 0
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _ready() -> void:
	Options.forget()
	var hub := InputHub.new()
	hub.scripted = true
	hub.solo_role = "runner"
	add_child(hub)
	var size := hub._screen_size()
	var place := hub.stick_place(size)
	var center: Vector2 = place["center"]
	var travel := ControlLayout.stick_travel(place)
	hub._apply_stick(center + Vector2(travel * 0.55, 0), size)
	check(hub.move_axis > 0.99, "half travel reaches full horizontal input")
	hub._apply_stick(center + Vector2(-travel * 0.55, 0), size)
	check(hub.move_axis < -0.99, "a short crossing reverses input")
	hub._apply_stick(center + Vector2(travel * 0.03, 0), size)
	check(hub.move_axis == 0.0, "small center jitter stays neutral")
	hub._apply_stick(center + Vector2(travel, -travel), size)
	check(not hub.take_jump() and not hub.jump_held, "diagonal steering does not jump by default")
	hub._apply_stick(center + Vector2(travel, travel * 0.6), size)
	check(hub.move_axis_y <= 0.0, "sideways steering drift does not ground pound")
	hub._apply_stick(center + Vector2(0, travel), size)
	check(hub.move_axis_y > 0.9, "deliberate down remains available")
	Options._cache["stick_jump"] = true
	hub._apply_stick(center + Vector2(0, -travel), size)
	check(not hub.take_jump() and not hub.jump_held,
		"legacy stick-jump cache cannot re-enable upward stick jumping")
	hub._apply_stick(center, size)
	Options._cache["stick_jump"] = false

	var jump: Dictionary = ControlLayout.layout(hub.layout_mode(), size, false)["jump"]
	var release_before := hub.jump_release_sequence
	hub._touch_down(71, jump["center"])
	check(hub.take_jump() and hub.jump_held, "jump reacts on finger down")
	check(hub.jump_press_release_sequence == release_before,
		"jump press snapshots the current aggregate release sequence")
	hub._touch_move(71, Vector2(size.x * 0.5, 0))
	check(hub.jump_held and hub.jump_release_sequence == release_before,
		"jump stays held when its finger slides outside")
	hub._touch_up(71)
	check(not hub.jump_held and hub.jump_release_sequence == release_before + 1,
		"lifting the last jump source records one aggregate release")

	# A second source holding jump must prevent a false release. This direct
	# source setup exercises aggregation even though stick jump is disabled in
	# shipping options.
	hub._jump_from_stick = true
	hub._refresh_jump_held()
	var aggregate_before := hub.jump_release_sequence
	hub.press_jump()
	hub.take_jump()
	hub.release_jump()
	check(hub.jump_held and hub.jump_release_sequence == aggregate_before,
		"releasing one source does not release aggregate jump")
	hub._jump_from_stick = false
	hub._refresh_jump_held()
	check(not hub.jump_held and hub.jump_release_sequence == aggregate_before + 1,
		"aggregate release is recorded when the final source lifts")

	# Focus loss goes through ordinary release accounting but throws away a
	# press edge that has not yet reached Runner.
	hub.press_jump()
	var focus_before := hub.jump_release_sequence
	hub.release_everything()
	check(hub.jump_release_sequence == focus_before + 1 and not hub.jump_held,
		"release_everything records a held jump release")
	check(not hub.take_jump(), "release_everything discards pending jump presses")

	hub.free()
	print("touch feel: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
