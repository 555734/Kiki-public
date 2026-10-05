extends Node
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	ControlLayout.forget()
	Options.forget()
	var hub := InputHub.new()
	hub.scripted = true
	add_child(hub)
	var size := hub._screen_size()
	for mode in ["", "runner"]:
		hub.solo_role = mode
		for point in [Vector2(12, size.y - 12), size * Vector2(0.45, 0.6), size * Vector2(0.18, 0.85)]:
			hub._touch_down(0, point)
			check(hub._stick_finger == 0 and hub.move_axis == 0.0, "floating press starts neutral anywhere in bottom left")
			check(hub.stick_place(size)["center"] == point, "visible stick follows its pressed origin")
			hub._touch_move(0, point + Vector2(ControlLayout.stick_travel(hub.stick_place(size)), 0))
			check(hub.move_axis > 0.99, "drag right from the floating anchor moves right")
			hub._touch_down(1, size * Vector2(0.3, 0.8))
			check(hub._stick_finger == 0, "another finger cannot replace the active stick")
			hub._touch_up(1)
			check(hub.move_axis > 0.99, "releasing the extra finger leaves steering held")
			var jump: Dictionary = hub.cluster(size)["jump"]
			hub._touch_down(2, jump["center"])
			check(hub.jump_held and hub.take_jump() and hub.move_axis > 0.99, "jump and steering work together")
			hub._touch_up(2)
			hub._touch_up(0)
			check(hub.move_axis == 0 and not hub.jump_held, "release clears movement and jump")
	hub.solo_role = ""
	hub.runner_on_left = false
	var mirrored := size * Vector2(0.8, 0.8)
	hub._touch_down(0, mirrored)
	check(hub.stick_place(size)["center"] == mirrored, "mirrored seating uses the bottom right stick zone")
	hub.release_everything()
	check(hub._stick_finger == -1 and hub.move_axis == 0, "focus cancellation clears floating input")
	ControlLayout.set_place("shared", "stick", Vector2(0.15, 0.75))
	check(not ControlLayout.floating_stick("shared"), "a deliberately moved stick retains fixed positioning")
	ControlLayout.reset("shared")
	for view in [Vector2(1280, 720), Vector2(960, 720), Vector2(1560, 720)]:
		var places := ControlLayout.layout("shared", view)
		var jump: Dictionary = places["jump"]
		check(jump["center"].x > view.x * 0.75 and jump["center"].y > view.y * 0.7, "shared jump defaults to bottom right")
		for tool in ["slot_1", "slot_3"]:
			check(places[tool]["radius"] < jump["radius"] and places[tool]["center"].y < jump["center"].y, "smaller tools sit above jump")
			check(ControlLayout.hit("shared", view, false, places[tool]["center"]) == tool, "both tools remain independently pressable")
	for stage in [Stage.Which.HORROR, Stage.Which.SKYWARD_RUINS, Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.DESERT, Stage.Which.TOWER, Stage.Which.CAVE]:
		Stage.use(stage)
		check(Art.tex(Art.pursuer_frame(false, 1.0)) != null, "stage chasing art resolves")
		var present := false
		for enemy in Stage.enemies():
			if enemy["type"] == "sky_pursuer": present = true
		check(present, "each supplied stage has its pursuer")
	var scene := preload("res://src/main.tscn")
	for stage in [Stage.Which.SWAMP, Stage.Which.DESERT, Stage.Which.TOWER, Stage.Which.CAVE]:
		Stage.use(stage)
		var main := scene.instantiate()
		add_child(main)
		await get_tree().process_frame
		var chaser: Node = null
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy.get_script() == preload("res://src/entities/enemies/sky_pursuer.gd"): chaser = enemy
		check(chaser != null, "theme pursuer is present in the live level")
		if chaser != null:
			chaser.set_physics_process(false)
			var before: Vector2 = chaser.global_position
			chaser._physics_process(10.0)
			check(chaser.global_position == before and not chaser._activated, "waiting at start does not start pursuit")
			main.runner.global_position += Stage.progress_direction() * 180.0
			chaser._physics_process(4.1)
			chaser._physics_process(0.1)
			check(chaser._activated and chaser.global_position != before, "moving off starts pursuit after its grace period")
			chaser.take_damage(1)
			before = chaser.global_position
			chaser._physics_process(0.1)
			check(chaser.stunned() and chaser.global_position == before, "guardian shots stop pursuit without deleting it")
		main.queue_free()
		await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	print("floating controls: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
