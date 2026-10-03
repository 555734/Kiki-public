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
	var jump_radius := float(jump["radius"])
	var outer_tap: Vector2 = jump["center"] + Vector2(jump_radius * 1.1, 0.0)
	check(ControlLayout.hit("runner", size, false, outer_tap) == "jump",
		"runner jump accepts a thumb just outside its painted ring")
	check(ControlLayout.hit("runner", size, false,
		jump["center"] + Vector2(jump_radius * 1.21, 0.0)) != "jump",
		"jump capture does not spread indefinitely into the playfield")
	var shared := ControlLayout.layout("shared", size, false)
	var shared_jump: Dictionary = shared["jump"]
	var shared_radius := float(shared_jump["radius"])
	check(size.x - float(shared_jump["center"].x) - shared_radius >= size.y * 0.03
		and size.y - float(shared_jump["center"].y) - shared_radius >= size.y * 0.08,
		"shared jump stays clear of the screen edges")
	check(ControlLayout.hit("shared", size, false,
		shared_jump["center"] + Vector2(shared_radius * 1.1, 0.0)) == "jump",
		"shared jump accepts an outer-ring tap")
	check(ControlLayout.hit("shared", size, true,
		Vector2(size.x - float(shared_jump["center"].x) - shared_radius * 1.1,
			float(shared_jump["center"].y))) == "jump",
		"mirrored jump accepts the same outer-ring tap")
	check(ControlLayout.hit("shared", size, false, shared["slot_1"]["center"]) == "slot_1"
		and ControlLayout.hit("shared", size, false, shared["slot_3"]["center"]) == "slot_3",
		"larger jump target leaves both guardian tool buttons usable")
	var release_before := hub.jump_release_sequence
	hub._touch_down(71, outer_tap)
	check(hub.take_jump() and hub.jump_held, "jump reacts on finger down")
	check(hub.jump_press_release_sequence == release_before,
		"jump press snapshots the current aggregate release sequence")
	hub._touch_move(71, Vector2(size.x * 0.5, 0))
	check(hub.jump_held and hub.jump_release_sequence == release_before,
		"jump stays held when its finger slides outside")
	hub._touch_up(71)
	check(not hub.jump_held and hub.jump_release_sequence == release_before + 1,
		"lifting the last jump source records one aggregate release")
	var overlapping: Vector2 = jump["center"]
	hub._touch_down(72, overlapping)
	var overlap_press := hub.jump_press_sequence
	hub._touch_down(73, overlapping)
	check(hub.jump_press_sequence == overlap_press + 1,
		"every new contact on jump supplies a press edge")
	hub._touch_up(72)
	check(hub.jump_held, "jump stays held until the second finger lifts")
	hub._touch_up(73)
	check(not hub.jump_held, "the last jump finger releases the button")
	hub._touch_down(74, overlapping)
	var before_reused := hub.jump_press_sequence
	# Simulate Android dropping this finger's release and recycling its index.
	hub._touch_down(74, overlapping)
	check(hub.jump_press_sequence == before_reused + 1 and hub.take_jump(),
		"a recycled finger index is a fresh jump even after a lost release")
	hub._touch_up(74)
	# A full-screen Control that consumes GUI input must not steal a gameplay
	# finger before the router has seen the jump down/up pair.
	var covering_ui := Control.new()
	covering_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	covering_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(covering_ui)
	var real_down := InputEventScreenTouch.new()
	real_down.index = 75
	real_down.position = jump["center"]
	real_down.pressed = true
	get_viewport().push_input(real_down, true)
	await get_tree().process_frame
	check(hub.take_jump() and hub.jump_held,
		"gameplay jump receives the touch before an overlapping GUI Control")
	var real_up := InputEventScreenTouch.new()
	real_up.index = 75
	real_up.position = jump["center"]
	real_up.pressed = false
	get_viewport().push_input(real_up, true)
	await get_tree().process_frame
	check(not hub.jump_held, "the same path receives the touch release")
	covering_ui.free()

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
	hub.solo_role = ""
	hub._touch_down(76, shared["slot_1"]["center"])
	hub._touch_down(76, shared_jump["center"])
	check(hub.take_slot_choice() == -1 and hub.take_jump(),
		"a recycled tool finger cannot fire the old tool instead of jump")
	hub.release_everything()
	check(hub.take_slot_choice() == -1 and hub.take_place_at().x == INF,
		"focus loss cancels tools without placing anything")

	hub.free()
	print("touch feel: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
