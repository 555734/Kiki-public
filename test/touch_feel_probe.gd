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

	await _gui_keeps_open_ground(hub, size)
	await _stood_down_hub_takes_nothing(hub, shared_jump["center"])
	_fuzz_finger_lifecycles(hub, size)

	hub.free()
	print("touch feel: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _touch(index: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	return e

func _drag(index: int, at: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	return e

## Only the painted controls are claimed ahead of the GUI. A Button over open
## ground must still get its press, or no menu drawn over the world could ever
## be used.
func _gui_keeps_open_ground(hub: InputHub, size: Vector2) -> void:
	hub.solo_role = ""
	hub.release_everything()
	var open := Vector2(size.x * 0.62, size.y * 0.45)
	check(hub.layout_mode() == "shared" and not hub._on_a_control(open),
		"the probe point is open ground")
	var button := Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(button)
	get_viewport().push_input(_touch(80, open, true), true)
	await get_tree().process_frame
	check(not hub._touch_owner.has(80),
		"a press on open ground under a GUI Control is left to the Control")
	get_viewport().push_input(_touch(80, open, false), true)
	await get_tree().process_frame
	button.free()
	await get_tree().process_frame
	get_viewport().push_input(_touch(81, open, true), true)
	await get_tree().process_frame
	check(hub._touch_owner.get(81, "") == "aim",
		"with nothing over it, the same press aims")
	get_viewport().push_input(_touch(81, open, false), true)
	await get_tree().process_frame
	check(hub._touch_owner.is_empty(), "and its release is the hub's too")
	hub.release_everything()

## A hub that has been stood down -- the versus puppet, or the game's hub
## behind the connect panel -- must not take touches through either pass.
## Turning off only _unhandled_input left the puppet eating every touch in
## _input once the hub moved to it.
func _stood_down_hub_takes_nothing(hub: InputHub, jump_at: Vector2) -> void:
	hub.release_everything()
	var puppet := InputHub.new()
	puppet.scripted = true
	add_child(puppet)   # after hub, so it is asked first
	puppet.set_listening(false)
	check(not puppet.is_listening() and hub.is_listening(),
		"set_listening switches both passes")
	get_viewport().push_input(_touch(82, jump_at, true), true)
	await get_tree().process_frame
	check(puppet._touch_owner.is_empty() and hub._touch_owner.get(82, "") == "jump",
		"a stood-down hub leaves the touch for the live one")
	get_viewport().push_input(_touch(82, jump_at, false), true)
	await get_tree().process_frame
	check(not hub.jump_held, "and the live one sees the release")
	hub.take_jump()
	puppet.free()

## Whatever order fingers arrive in, once every one of them has lifted nothing
## may still be held. Android also drops releases; after focus loss clears up,
## the same must hold.
func _fuzz_finger_lifecycles(hub: InputHub, size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8008
	var spots: Array[Vector2] = []
	for mode in ["shared", "runner"]:
		for item in ControlLayout.layout(mode, size, false).values():
			spots.append(item["center"])
	for i in 6:
		spots.append(Vector2(rng.randf() * size.x, rng.randf() * size.y))
	for role in ["", "runner", "guardian"]:
		hub.solo_role = role
		var stuck := 0
		var lossy := 0
		for round in 60:
			hub.release_everything()
			var down := {}
			var dropped := false
			for step in 40:
				var finger := rng.randi_range(0, 4)
				var at: Vector2 = spots[rng.randi_range(0, spots.size() - 1)] \
					+ Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
				var roll := rng.randf()
				if not down.has(finger) or roll < 0.15:
					# roll < 0.15 on a finger already down is a lost release
					# followed by Android recycling the index.
					if down.has(finger):
						dropped = true
					hub.feed(_touch(finger, at, true))
					down[finger] = true
				elif roll < 0.6:
					hub.feed(_drag(finger, at))
				else:
					hub.feed(_touch(finger, at, false))
					down.erase(finger)
				hub.take_jump()
				hub.take_slot_choice()
				hub.take_ping()
			for finger in down.keys():
				hub.feed(_touch(int(finger), Vector2(size.x * 0.5, size.y * 0.5), false))
			if not _at_rest(hub):
				stuck += 1
			if dropped:
				hub.release_everything()
				if not _at_rest(hub) or hub.take_slot_choice() != -1 \
						or hub.take_place_at().x != INF or hub.take_ping() != 0:
					lossy += 1
		check(stuck == 0, "role '%s': all fingers lifted leaves nothing held (%d of 60 rounds stuck)"
			% [role, stuck])
		check(lossy == 0, "role '%s': lost releases clear on focus loss (%d of 60 rounds left state)"
			% [role, lossy])
	hub.solo_role = ""
	hub.release_everything()

func _at_rest(hub: InputHub) -> bool:
	return hub._touch_owner.is_empty() and not hub.jump_held and hub.move_axis == 0.0 \
		and hub.move_axis_y == 0.0 and hub.pan_axis == 0.0 and hub._stick_finger == -1 \
		and hub._slot_finger == -1 and hub._zoom_finger == -1
