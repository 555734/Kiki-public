extends Node
## Stage 1-5 promises a lethal liquid, safe stepping stones, three crossings
## that need guardian support, and a moving raft for the broad central channel.

const MainScene: PackedScene = preload("res://src/main.tscn")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Stage.use(Stage.Which.SWAMP)
	check(Stage.stage_number() == "1-5" and Stage.stage_name() == "THE MOLTEN CROSSING",
		"stage identity is wired")
	check(not Stage.world_3d() and Stage.progress_direction() == Vector2.RIGHT,
		"the painted side-view stage runs left to right")
	check(Stage.water_y() < Stage.kill_y(), "lava is above the fall sensor")
	check(Stage.goal().x > Stage.start().x + 10000.0,
		"goal is a full stage from the start")
	check(Stage.goal().x < 30000.0, "route fits the online X codec")

	var footing: Array[Rect2] = Stage.ground()
	footing.append_array(Stage.solid_decor())
	footing.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		return a.position.x < b.position.x)
	var safe := true
	for r in footing:
		safe = safe and r.position.y < Stage.water_y() - 80.0
	var jumps := 0
	var assists := 0
	var lifts := 0
	for step in Stage.route():
		if step["via"] == "jump": jumps += 1
		if step["via"] == "assist": assists += 1
	for spec in Stage.gimmicks():
		if spec["type"] == "moving_platform": lifts += 1
	check(safe, "all permanent footing clears the lava surface")
	check(jumps >= 12 and assists == 3 and lifts >= 4,
		"authored hops, three Guardian rescues and crossing lift routes")
	check(Stage.data().rooms().size() == 20, "twenty individually authored molten encounters")
	# Upper/lower portals and overlapping safety decks require real route
	# validation (radical_route_probe), not an adjacent-X gap approximation.
	var lava := Stage.hazards()
	check(lava.size() == 1 and not bool(lava[0].get("draw_spikes", true)),
		"the surface kills without drawing spikes")
	for key in ["swamp_panorama", "swamp_props_atlas"]:
		check(Art.tex(key) != null, "%s is imported" % key)
	check(Art.tex("parallax") == Art.tex("swamp_panorama"),
		"the backdrop resolves to the lava gorge")

	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.level.find_child("PoisonWater", true, false) != null,
		"the level builds lava water")
	main.get_node("NetPanel").queue_free()
	await get_tree().process_frame
	for _i in 25:
		await get_tree().physics_frame
	check(main.runner.is_on_floor(), "the runner starts on dry ground")
	# The guardian's temporary floor must hold a runner above an actual channel.
	var guardian: Guardian = main.guardian
	guardian.select_slot(1)
	guardian.place_path = PackedVector2Array()
	var rescue: Dictionary = Stage.route().filter(func(s: Dictionary) -> bool: return s["via"] == "assist")[0]
	var void_x := ((rescue["from"] as Rect2).end.x + (rescue["to"] as Rect2).position.x) * 0.5
	main.runner.global_position = Vector2(void_x, 260)
	main.runner.velocity = Vector2.ZERO
	await get_tree().physics_frame
	guardian.use_active(Vector2(void_x, 360))
	for _i in 35:
		main.runner.set("_invuln", 9.0)
		await get_tree().physics_frame
	check(main.runner.is_on_floor() and main.runner.global_position.y < Stage.water_y(),
		"a guardian platform holds the runner over lava")
	guardian.clear_constructs()
	var deaths := [0]
	var died := func(_cause: String) -> void: deaths[0] += 1
	Events.runner_died.connect(died)
	main.runner.global_position = Vector2(void_x, Stage.water_y() - 40)
	main.runner.velocity = Vector2.ZERO
	for _i in 45:
		await get_tree().physics_frame
	Events.runner_died.disconnect(died)
	check(deaths[0] == 1, "touching lava kills once (%d)" % deaths[0])
	main.queue_free()
	await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	if failures.is_empty():
		print("swamp stage probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("swamp stage probe: " + failure)
		get_tree().quit(1)
