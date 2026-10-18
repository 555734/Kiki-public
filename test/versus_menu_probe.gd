extends Node
## Real GUI picking: emitting Button.pressed bypasses the overlay that stole
## taps on Back. Run with a display, like ui_probe, in both room modes.
const MAIN := preload("res://src/main.tscn")
var failures: Array[String] = []

func frames(n: int = 3) -> void:
	for i in n: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	print("VERSUS_MENU ", "PASS " if ok else "FAIL ", message)
	if not ok: failures.append(message)

func tap(at: Vector2, mouse: bool = false) -> void:
	for pressed in [true,false]:
		if mouse:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = at
			event.pressed = pressed
			Input.parse_input_event(event)
		else:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = at
			event.pressed = pressed
			Input.parse_input_event(event)
		await frames()

func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func() -> void:
		push_error("versus menu probe timed out")
		get_tree().quit(1))
	call_deferred("run")

func run() -> void:
	var main := MAIN.instantiate()
	add_child(main)
	await frames(5)
	var panel: NetPanel = main.get_node("NetPanel")
	var original_page: int = panel._stage_page
	for mouse in [false,true]:
		for mode in [VersusRoster.RoomMode.FREE_FOR_ALL,VersusRoster.RoomMode.TEAM_SPLIT]:
			panel._on_versus()
			await frames()
			var versus: Control = panel._versus_view
			var mode_card: Button = versus.find_child("Mode%d" % mode,true,false)
			check(mode_card != null, "mode has a touchable card")
			if mode_card == null:
				get_tree().quit(1)
				return
			await tap(mode_card.get_global_rect().get_center(),mouse)
			await frames()
			check(versus._step == 2, "room stage selection is open")
			await tap(versus._back.get_global_rect().get_center(),mouse)
			check(is_instance_valid(versus) and versus._step == 1,
				"real %s Back returns from stage selection to modes (%d)" % ["mouse" if mouse else "touch",mode])
			# Finish this iteration even before the fix, to report both modes.
			if versus._step == 2: versus._on_back()
			await frames()
			await tap(versus._back.get_global_rect().get_center(),mouse)
			check(not is_instance_valid(versus), "real Back closes mode selection")
			if is_instance_valid(versus):
				versus._on_back()
				await frames()
			check(panel._stage_page == original_page and panel._root.visible,
				"return preserves co-op browsing position")
	main.free()
	await frames()
	print("versus menu probe: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
