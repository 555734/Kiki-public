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
	check(Stage.stage_number() == "1-5" and Stage.stage_name() == "THE POISON MARSH",
		"stage identity is wired")
	check(not Stage.world_3d() and Stage.progress_direction() == Vector2.RIGHT,
		"the painted side-view stage runs left to right")
	check(Stage.water_y() < Stage.kill_y(), "poison is above the fall sensor")
	check(Stage.goal().x > Stage.start().x + 10000.0,
		"goal is a full stage from the start")
	check(Stage.goal().x < 30000.0, "route fits the online X codec")

	var footing: Array[Rect2] = Stage.ground()
	footing.append_array(Stage.solid_decor())
	footing.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		return a.position.x < b.position.x)
	var safe := true
	var free := 0
	var assisted := 0
	var raft_crossings := 0
	for r in footing:
		safe = safe and r.position.y < Stage.water_y() - 80.0
	for i in range(footing.size() - 1):
		var gap := footing[i + 1].position.x - footing[i].end.x
		if gap <= 0.0:
			continue
		var raft := false
		for g in Stage.gimmicks():
			if String(g.get("type", "")) != "moving_platform":
				continue
			var start: Vector2 = g["pos"]
			var travel: Vector2 = g["travel"]
			var half := float((g["span"] as Vector2).x) * 0.5
			if start.x - half <= footing[i].end.x + 40.0 \
					and start.x + travel.x + half >= footing[i + 1].position.x - 150.0:
				raft = true
		if raft:
			raft_crossings += 1
		elif gap <= 200.0:
			free += 1
		elif gap >= 500.0:
			assisted += 1
		else:
			check(false, "no gap is too wide for a jump and too short for assistance")
	check(safe, "all safe footing clears the poison surface")
	check(free >= 8 and assisted == 3 and raft_crossings == 1,
		"stepping stones, three guardian channels and one raft (%d/%d/%d)"
		% [free, assisted, raft_crossings])
	var poison := Stage.hazards()
	check(poison.size() == 1 and not bool(poison[0].get("draw_spikes", true)),
		"the surface kills without drawing spikes")
	for key in ["swamp_panorama", "swamp_props_atlas"]:
		check(Art.tex(key) != null, "%s is imported" % key)
	check(Art.tex("parallax") == Art.tex("swamp_panorama"),
		"the backdrop resolves to the marsh")

	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.level.find_child("PoisonWater", true, false) != null,
		"the level builds poison water")
	main.get_node("NetPanel").queue_free()
	await get_tree().process_frame
	for _i in 25:
		await get_tree().physics_frame
	check(main.runner.is_on_floor(), "the runner starts on dry ground")
	# The guardian's temporary floor must hold a runner above an actual channel.
	var guardian: Guardian = main.guardian
	guardian.select_slot(1)
	guardian.place_path = PackedVector2Array()
	main.runner.global_position = Vector2(3110, 260)
	main.runner.velocity = Vector2.ZERO
	await get_tree().physics_frame
	guardian.use_active(Vector2(3110, 360))
	for _i in 35:
		main.runner.set("_invuln", 9.0)
		await get_tree().physics_frame
	check(main.runner.is_on_floor() and main.runner.global_position.y < Stage.water_y(),
		"a guardian platform holds the runner over poison")
	guardian.clear_constructs()
	var deaths := [0]
	var died := func(_cause: String) -> void: deaths[0] += 1
	Events.runner_died.connect(died)
	main.runner.global_position = Vector2(3100, 480)
	main.runner.velocity = Vector2.ZERO
	for _i in 45:
		await get_tree().physics_frame
	Events.runner_died.disconnect(died)
	check(deaths[0] == 1, "touching poison kills once (%d)" % deaths[0])
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
