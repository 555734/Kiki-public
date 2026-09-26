extends Node
## Stage 1-4, the sea: the layout's promises and a live smoke run.
##
## The layout promises that the rock and stack hops are free, that the step-ups
## are fair, that at least three water crossings need the guardian, that the
## coast really rises and falls, that everything you stand on is
## above the sea, and that falling in is a fall. The live part builds the stage
## and checks the sea, the reskinned enemies, a guardian slab over open water,
## and that the water kills once.

const MainScene: PackedScene = preload("res://src/main.tscn")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Stage.use(Stage.Which.SEA)
	check(Stage.stage_number() == "1-4", "stage is numbered 1-4")
	check(Stage.stage_name() == "THE SUNLIT COAST", "stage name is wired")
	check(not Stage.world_3d(), "1-4 is painted 2D, like 1-1 and 1-2")
	check(Stage.progress_direction() == Vector2.RIGHT, "1-4 runs left to right")
	var water := Stage.water_y()
	check(water != INF and water < Stage.kill_y(), "the sea is above the kill line")
	check(Stage.goal().x > Stage.start().x + 10000.0, "the goal is a full stage away")
	check(Stage.goal().x < 30000.0 and Stage.start().x > -2048.0,
		"the route fits the online X codec")

	# Every surface, in order along the route.
	var footing: Array[Rect2] = Stage.ground()
	footing.append_array(Stage.solid_decor())
	footing.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var above := true
	for r in footing:
		above = above and r.position.y < water - 40.0
	check(above, "everything you stand on is above the sea")
	var free := 0
	var assisted := 0
	var worst := 0.0
	var worst_step := 0.0
	for i in range(footing.size() - 1):
		var here := footing[i]
		var there := footing[i + 1]
		var gap := there.position.x - here.end.x
		# The raft, the blink steps and the crumbling planks bridge some gaps,
		# and the spring lifts the runner over the sea wall.
		var bridged := false
		for g in Stage.gimmicks():
			var at: Vector2 = g["pos"]
			var reach: Vector2 = g.get("travel", Vector2.ZERO)
			var half := float((g.get("span", Vector2(120, 30)) as Vector2).x) * 0.5
			if at.x - half < there.position.x + 1.0 \
					and at.x + maxf(reach.x, 0.0) + half > here.end.x - 1.0:
				bridged = true
		var sprung := false
		for sp in Stage.springs():
			if sp.x >= here.position.x and sp.x <= here.end.x and sp.x > here.end.x - 150.0:
				sprung = true
		var rise := here.position.y - there.position.y
		if not bridged and not sprung:
			worst_step = maxf(worst_step, rise)
		if gap <= 0.0 or bridged:
			continue
		if gap <= 200.0:
			free += 1
		elif gap >= 500.0:
			assisted += 1
		worst = maxf(worst, gap if gap < 500.0 else 0.0)
	check(free >= 6, "the rock and stack hops are free jumps (%d)" % free)
	check(assisted >= 3, "at least three water crossings need the guardian (%d)" % assisted)
	check(worst <= 200.0, "no gap sits in the unfair middle (%.0fpx)" % worst)
	check(worst_step <= 130.0,
		"every unassisted step up is a jump anyone can make (%.0fpx)" % worst_step)
	var top := INF
	var low := -INF
	for r in Stage.ground():
		top = minf(top, r.position.y)
		low = maxf(low, r.position.y)
	check(low - top >= 500.0, "the coast rises and falls (%.0fpx of relief)" % (low - top))
	var turrets := 0
	for e in Stage.enemies():
		if String(e.get("type", "")) == "turret":
			turrets += 1
	check(turrets >= 3, "turrets hold the cliff tops (%d)" % turrets)
	check(Stage.checkpoints().size() >= 6, "checkpoints split the beats")

	var crabs := 0
	var birds := 0
	var chasers := 0
	for e in Stage.enemies():
		match String(e.get("type", "")):
			"walker":
				if String(e.get("skin", "")) == "sea_crab":
					crabs += 1
			"flyer": birds += 1
			"sky_pursuer": chasers += 1
	check(crabs >= 5 and birds >= 4 and chasers == 1,
		"crabs, seabirds and one purple chaser (%d/%d/%d)" % [crabs, birds, chasers])

	# The pack's paintings are imported and the stage resolves to them.
	for key in ["sea_panorama", "sea_sand_tile", "sea_grass_cap", "sea_crab", "sea_seabird",
			"sea_chaser", "sea_flag", "sea_rock", "sea_pier", "sea_raft", "sea_bridge",
			"sea_palm", "sea_palm_small", "sea_grass", "sea_boulder", "sea_seaweed"]:
		check(Art.tex(key) != null, "%s is imported" % key)
	var bg := Art.tex("parallax")
	check(bg != null and bg.resource_path.contains("stage_1_4"), "the backdrop is the sea")
	var bird := Art.tex("flyer")
	check(bird != null and bird.resource_path.contains("seabird"), "flyers are seabirds")

	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.level.find_child("Sea", true, false) != null, "the level builds the sea")
	main.get_node("NetPanel").queue_free()
	await get_tree().process_frame
	for e in get_tree().get_nodes_in_group("enemy"):
		if String(e.get_script().resource_path).ends_with("sky_pursuer.gd"):
			e.global_position = Vector2(-2000, 330)
			e.set("_wake_left", 99.0)
	for _i in 30:
		await get_tree().physics_frame
	check(main.runner.is_on_floor(), "the runner starts on the beach")

	# A guardian slab over the pier's missing middle holds the runner up.
	var g: Guardian = main.guardian
	g.select_slot(1)
	g.place_path = PackedVector2Array()
	var slab_at := Vector2(3300, 240)
	check(g.abilities[1].check(g, slab_at) == "" or g.runner == null
		or slab_at.distance_to(g.runner.global_position) > Balance.PLACE_MAX_RANGE,
		"a slab can be placed over open water")
	main.runner.global_position = Vector2(3300, 130)
	main.runner.velocity = Vector2.ZERO
	await get_tree().physics_frame
	g.use_active(slab_at)
	for _i in 40:
		main.runner.set("_invuln", 9.0)
		await get_tree().physics_frame
	check(main.runner.is_on_floor() and main.runner.global_position.y < water,
		"the runner stands on a guardian slab over the sea (y=%.0f)" % main.runner.global_position.y)
	g.clear_constructs()

	# The sea is a fall, and it kills once.
	var deaths := [0]
	var count := func(_cause: String) -> void: deaths[0] += 1
	Events.runner_died.connect(count)
	main.runner.global_position = Vector2(6510, 200)
	main.runner.velocity = Vector2.ZERO
	for _i in 150:
		await get_tree().physics_frame
		for e in get_tree().get_nodes_in_group("enemy"):
			if String(e.get_script().resource_path).ends_with("sky_pursuer.gd"):
				e.global_position = Vector2(-2000, 330)
	Events.runner_died.disconnect(count)
	check(deaths[0] == 1, "falling into the sea kills once (%d)" % deaths[0])

	main.queue_free()
	await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	if failures.is_empty():
		print("sea stage probe: all checks passed")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("sea stage probe: " + f)
		get_tree().quit(1)
