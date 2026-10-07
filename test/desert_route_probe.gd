extends Node
const Main = preload("res://src/main.tscn")
const Route = preload("res://test/climb_route.gd")
var failures: Array[String] = []

func _ready() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("%s %s" % ["ok" if ok else "FAIL", message])
	if not ok: failures.append(message)

func run() -> void:
	Stage.use(Stage.Which.DESERT)
	var rooms: Array[Dictionary] = Stage.data().rooms()
	var names := {}
	var fingerprints := {}
	for room in rooms:
		names[room["name"]] = true
		var pattern: Array = []
		for step in Stage.route():
			if step["section"] != room["name"]: continue
			var a: Rect2 = step["from"]
			var b: Rect2 = step["to"]
			pattern.append([step["via"], step.get("how", ""), b.position - a.position, a.size, b.size])
		fingerprints[str(pattern)] = true
	check(rooms.size() == 20 and names.size() == 20, "twenty distinct authored sections")
	check(fingerprints.size() == 20, "no section repeats the same relative route recipe")
	check(Stage.goal().x > 10000 and Stage.goal().x < 12000, "two-tier route ends on the lower right bank")
	var lower: Rect2 = rooms[0]["entry"]
	var upper: Rect2 = rooms[10]["entry"]
	check(upper.position.x > lower.position.x and upper.position.x < Stage.goal().x * 0.4 and lower.position.y - upper.position.y > 800,
		"upper ruins overlap the lower route horizontally with clear vertical separation")
	check(rooms[19]["exit"].end.x < 10500, "twenty encounters are folded into one shared horizontal span")
	var transfers := 0
	for step in Stage.route():
		if step.get("how", "") == "warp" and absf(step["to"].position.y - step["from"].position.y) > 500:
			transfers += 1
	check(transfers == 2, "production route really climbs to the upper tier and returns to the goal")
	check(Stage.key_position().y < -500, "required key remains on the upper journey")
	check(Stage.key_position().x > rooms[-1]["exit"].position.x,
		"key is beyond the upper rescue wall so dropping downstairs cannot skip the finale")
	for checkpoint in Stage.checkpoints():
		var supported := false
		for slab in Stage.ground():
			if checkpoint.x > slab.position.x + 18 and checkpoint.x < slab.end.x - 18:
				if absf(checkpoint.y + 50 - slab.position.y) <= 2: supported = true
		check(supported, "checkpoint has permanent ground: %s" % checkpoint)
	var main := Main.instantiate()
	add_child(main)
	main.get_node("NetPanel").queue_free()
	await get_tree().process_frame
	# Cross the fold with real checkpoint Areas, then exercise the game's
	# respawn path. An upstairs arrival appended after the upstairs checkpoints
	# would give it a larger index than later rooms and break network progress.
	main.input_hub.scripted = true
	Route._quiet(get_tree())
	GameState.reset_run(Stage.start())
	for i in [8, 9, 10]:
		main.runner.respawn(Stage.checkpoints()[i] + Vector2(0, 24))
		for _frame in 6: await get_tree().physics_frame
		check(GameState.checkpoint_index == i + 1, "real checkpoint advances across the tier change: %d" % (i + 1))
	var saved := GameState.respawn_position()
	# A fall onto a previously skipped lower checkpoint must not roll back the
	# upstairs save point, even though its Area has not been reached before.
	main.runner.respawn(Stage.checkpoints()[0] + Vector2(0, 24))
	for _frame in 6: await get_tree().physics_frame
	check(GameState.checkpoint_index == 11 and GameState.respawn_position().distance_to(saved) < 1.0,
		"falling onto an earlier lower checkpoint preserves the upper save point")
	main._do_respawn()
	check(main.runner.global_position.distance_to(saved) < 1.0 and saved.y < -500,
		"real respawn returns to the latest upper checkpoint")
	var only: Array = []
	if OS.get_environment("DESERT_ONLY") != "": only = OS.get_environment("DESERT_ONLY").split(",")
	var missed := await Route.climb_all(get_tree(), main, 0, only)
	for failure in missed: check(false, failure)
	check(missed.is_empty(), "real Runner/Guardian route: %d steps, %d misses" % [Stage.route().size(), missed.size()])
	main.free()
	Stage.use(Stage.Which.GREENFIELD)
	print("desert route probe: ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
