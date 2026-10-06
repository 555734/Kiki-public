extends Node
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	get_viewport().size = Vector2i(1280, 720)
	ControlLayout.forget()
	Options.forget()
	for mouse in [true, false]:
		for role in ["", "runner"]:
			for fixed in [false, true]:
				await exercise(mouse, role, fixed)
	for control in ["jump", "stick"]:
		await first_touch_through_input(control)
	print("co-op pointer probe: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func press(mouse: bool, at: Vector2, down: bool) -> void:
	if mouse:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.pressed = down
		get_viewport().push_input(e)
	else:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = at
		e.pressed = down
		get_viewport().push_input(e)
func drag(mouse: bool, at: Vector2) -> void:
	if mouse:
		var e := InputEventMouseMotion.new()
		e.position = at
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(e)
	else:
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = at
		get_viewport().push_input(e)
func exercise(mouse: bool, role: String, fixed: bool) -> void:
	Stage.use(Stage.Which.GREENFIELD)
	var main := preload("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("NetPanel")._on_local()
	await get_tree().process_frame
	var hub: InputHub = main.input_hub
	hub.solo_role = role
	var mode := hub.layout_mode()
	ControlLayout.reset(mode)
	if fixed:
		ControlLayout.set_place(mode, "stick", Vector2(0.15, 0.80))
	var origin: Vector2 = hub.cluster(Vector2(1280, 720))["stick"]["center"]
	var label := "%s/%s/%s" % ["mouse" if mouse else "touch", mode, "fixed" if fixed else "floating"]
	press(mouse, origin, true)
	await get_tree().process_frame
	# Multiple small motion events used to switch the mouse off before the
	# thumb had crossed the dead zone. Real viewport routing is intentional.
	for i in range(1, 9):
		drag(mouse, origin + Vector2(i * 10.0, 0))
		await get_tree().process_frame
	var before: Vector2 = main.runner.global_position
	for i in range(20):
		await get_tree().physics_frame
	check(hub.move_axis > 0.9, label + " keeps steering across frames")
	check(main.runner.global_position.x > before.x + 30.0, label + " moves the live runner")
	check(hub._has_touch == not mouse, label + " preserves input source")
	check(hub.stick_visual()["touch_mode"], label + " shows the virtual controls")
	press(mouse, origin + Vector2(80, 0), false)
	await get_tree().process_frame
	check(hub.move_axis == 0.0 and hub._stick_finger == -1, label + " releases the stick")
	if mouse:
		var key := InputEventAction.new()
		key.action = "p1_right"
		key.pressed = true
		Input.parse_input_event(key)
		await get_tree().process_frame
		await get_tree().process_frame
		check(hub.move_axis > 0.9, label + " keyboard remains usable after mouse steering")
		key.pressed = false
		Input.parse_input_event(key)
		await get_tree().process_frame
		var jump: Vector2 = hub.cluster(Vector2(1280, 720))["jump"]["center"]
		press(true, jump, true)
		for i in range(3): await get_tree().process_frame
		check(hub.jump_held, label + " preserves held jump against keyboard polling")
		press(true, jump, false)
		await get_tree().process_frame
		check(not hub.jump_held, label + " releases jump")
	main.queue_free()
	await get_tree().process_frame
	ControlLayout.reset(mode)

## The first touch of a session, sent the way the engine delivers it: through
## Input, so emulate_mouse_from_touch also makes a mouse press -- one that
## arrives before the touch it copies. The control must end up the finger's
## alone, and be let go when the finger lifts.
func first_touch_through_input(control: String) -> void:
	check(Input.is_emulating_mouse_from_touch(), "the project emulates the mouse from touch")
	Stage.use(Stage.Which.GREENFIELD)
	var main := preload("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("NetPanel")._on_local()
	await get_tree().process_frame
	var hub: InputHub = main.input_hub
	ControlLayout.reset(hub.layout_mode())
	check(not hub._has_touch, control + ": the hub has not seen a touch yet")
	var at: Vector2 = hub.cluster(Vector2(1280, 720))[control]["center"]
	for down in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = at
		e.pressed = down
		Input.parse_input_event(e)
		for i in range(3):
			await get_tree().process_frame
		if down:
			check(hub._touch_owner.get(0, "") == control, control + ": the finger takes the control")
			check(not hub._touch_owner.has(InputHub.MOUSE_FINGER),
				control + ": the emulated mouse takes nothing")
	check(hub._touch_owner.is_empty(), control + ": nothing is left holding a control")
	check(not hub.jump_held and hub.move_axis == 0.0, control + ": nothing is left pressed")
	main.queue_free()
	await get_tree().process_frame
