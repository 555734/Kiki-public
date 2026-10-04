extends Node
## The やめる button on a stage and in versus: it asks first, 続ける carries on,
## a ticked "次回から確認しない" is remembered, and from then on it quits at
## once. Pressed with a real click through the InputHub, which reads the
## pointer before the GUI and has to leave this button alone.

const MainScene: PackedScene = preload("res://src/main.tscn")

var failures: Array[String] = []
var quits: int = 0

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = pressed
		get_viewport().push_input(e, true)
		await get_tree().process_frame

func _centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func run() -> void:
	UiPrefs.set_skip_quit_confirm(false)
	Stage.use(Stage.Which.GREENFIELD)
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await _frames(4)
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
	await _frames(4)
	var quit: QuitConfirm = main.quit
	quit.on_quit = func() -> void: quits += 1
	var button: Button = quit._button
	check(button.is_visible_in_tree(), "a stage shows the やめる button once play starts")

	await _click(_centre(button))
	await _frames(2)
	check(quit.asking() and quits == 0, "a click on it asks before quitting")
	check(get_tree().paused, "an offline game waits while it asks")
	check(quit.claims(Vector2(640, 600)), "and every press is the question's while it is up")
	await _click(_centre(quit._popup.find_child("Stay", true, false)))
	await _frames(2)
	check(not quit.asking() and quits == 0 and not get_tree().paused,
		"続ける closes it and play carries on")

	await _click(_centre(button))
	await _frames(2)
	await _click(_centre(quit._check))
	await _click(_centre(quit._popup.find_child("Leave", true, false)))
	await _frames(2)
	check(quits == 1 and not quit.asking(), "やめる quits")
	UiPrefs.reload()
	check(UiPrefs.skip_quit_confirm(), "and the ticked box is remembered on this device")
	await _click(_centre(button))
	await _frames(2)
	check(quits == 2 and not quit.asking(), "after that the button quits without asking")

	main.runner.cleared = true
	await _frames(2)
	check(not button.is_visible_in_tree(), "the clear panel's own button takes over after a clear")
	main.queue_free()
	await _frames(2)

	# Versus: its own menu button, the same question.
	UiPrefs.set_skip_quit_confirm(false)
	VersusLaunch.clear()
	VersusLaunch.how = VersusLaunch.How.SOLO
	var arena: Node = load("res://src/versus/versus_main.tscn").instantiate()
	add_child(arena)
	await _frames(6)
	arena._quit.on_quit = func() -> void: quits += 1
	await _click(_centre(arena._leave_button))
	await _frames(2)
	check(arena._quit.asking() and quits == 2, "versus: やめる asks too")
	await _click(_centre(arena._quit._popup.find_child("Leave", true, false)))
	await _frames(2)
	check(quits == 3, "versus: and quits on the answer")
	arena.queue_free()
	VersusLaunch.clear()
	UiPrefs.set_skip_quit_confirm(false)
	get_tree().paused = false
	await _frames(2)
	if failures.is_empty():
		print("quit confirm probe: all checks passed")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("quit confirm probe: " + f)
		get_tree().quit(1)
