extends Node
## Structural and live smoke checks for Stage 1-3's vertical co-op contract.

const MainScene: PackedScene = preload("res://src/main.tscn")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Stage.use(Stage.Which.SKYWARD_RUINS)
	check(Stage.stage_number() == "1-3", "stage is numbered 1-3")
	check(Stage.stage_name() == "THE SKYWARD RUINS", "stage name is wired")
	check(Stage.progress_direction() == Vector2.UP, "progress direction is upward")
	check(Stage.goal().y < Stage.start().y - 5500.0, "goal is a full vertical climb above start")
	check(Stage.checkpoints().size() == 4, "four checkpoints split the five sections")
	check(Stage.start().y >= -1024.0 and Stage.start().y <= 7167.0,
		"start fits the online Y codec")
	check(Stage.goal().y >= -1024.0 and Stage.kill_y() <= 7167.0,
		"goal and kill plane fit the online Y codec")

	var pursuers := Stage.enemies().filter(func(e: Dictionary) -> bool:
		return String(e.get("type", "")) == "sky_pursuer")
	check(pursuers.size() == 1, "one permanent pursuer is authored")
	if not pursuers.is_empty():
		check(is_zero_approx(float(pursuers[0].get("delay", -1.0))),
			"pursuer has no gameplay wake delay")
		var chase_direction: Vector2 = pursuers[0].get("direction", Vector2.ZERO)
		check(chase_direction == Vector2.UP,
			"pursuer chases upward")

	var launch_rises := 0
	var tops: Array[float] = []
	for island in Stage.ground():
		tops.append(island.position.y)
	tops.sort()
	for i in range(tops.size() - 1):
		var rise := tops[i + 1] - tops[i]
		if rise > Balance.RUNNER_JUMP_HEIGHT + 90.0:
			launch_rises += 1
	check(launch_rises >= 10, "the route repeatedly exceeds a solo jump")
	check(Stage.crystals().size() * Balance.CRYSTAL_GAUGE >= 8.0 *
		(Balance.COST_PLATFORM + Balance.COST_SNIPE), "mandatory assists are funded")

	var moving := 0
	var switches := 0
	var gates := 0
	for gimmick in Stage.gimmicks():
		match String(gimmick.get("type", "")):
			"moving_platform": moving += 1
			"switch": switches += 1
			"gate": gates += 1
	check(moving >= 3, "timing sections contain moving platforms")
	check(switches == 1 and gates == 1, "timed switch and gate are paired")

	var main: Node2D = MainScene.instantiate()
	add_child(main)
	var pursuer: Node2D = null
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.get_script() != null \
				and String(enemy.get_script().resource_path).ends_with("sky_pursuer.gd"):
			pursuer = enemy
			break
	check(pursuer != null, "level builder creates the vertical pursuer")
	var frozen_tick := Clock.tick
	var frozen_runner: Vector2 = main.runner.global_position
	var frozen_pursuer := pursuer.global_position if pursuer != null else Vector2.ZERO
	for _i in 6:
		await get_tree().physics_frame
	check(Clock.tick == frozen_tick, "home screen freezes the stage clock")
	check(main.runner.global_position == frozen_runner, "home screen freezes the runner")
	check(pursuer == null or pursuer.global_position == frozen_pursuer,
		"home screen freezes the pursuer")

	main.get_node("NetPanel").queue_free()
	await get_tree().process_frame
	if pursuer != null:
		var before_chase := pursuer.global_position.y
		for _i in 12:
			await get_tree().physics_frame
		check(pursuer.global_position.y < before_chase,
			"pursuer moves upward immediately after play starts")
		var before_stun := pursuer.global_position.y
		pursuer.call("take_damage", 1, "snipe")
		check(bool(pursuer.call("stunned")), "guardian shot stuns the pursuer")
		check(pursuer.global_position.y > before_stun,
			"shot pushes the upward pursuer back down")

	# The redesign's pieces are all built, and each behaves the way the layout
	# relies on.
	var found := {}
	for node in main.level.find_children("*", "", true, false):
		for cls in ["BlinkBlock", "Conveyor", "WarpGate", "SkyMine", "SkySeedling", "SkyGolem",
				"CrumblingFloor"]:
			if node.get_script() != null and node.get_script().get_global_name() == cls:
				found[cls] = int(found.get(cls, 0)) + 1
	for cls in ["BlinkBlock", "Conveyor", "WarpGate", "SkyMine", "SkySeedling", "SkyGolem",
			"CrumblingFloor"]:
		check(found.has(cls), "1-3 builds a %s" % cls)
	if pursuer != null:
		pursuer.global_position = Vector2(-3000, 6900)
	var blink: BlinkBlock = null
	var belt: Conveyor = null
	var warp: WarpGate = null
	for node in main.level.find_children("*", "", true, false):
		if node is BlinkBlock and blink == null: blink = node
		if node is Conveyor and belt == null: belt = node
		if node is WarpGate and not node.is_exit and warp == null: warp = node
	if blink != null:
		var t := Clock.tick
		var half := Clock.ticks_for(blink.beat)
		check(blink.solid_at(t) != blink.solid_at(t + half),
			"a blink slab alternates every beat, from the clock alone")
		check(blink.solid_at(t) == blink.solid_at(t + half * 2),
			"and repeats exactly each cycle")
	if belt != null:
		var top := belt.global_position - Vector2(0, belt.span.y * 0.5 + Balance.RUNNER_SIZE.y * 0.5 + 1)
		main.runner.global_position = top
		main.runner.velocity = Vector2.ZERO
		for _i in 20:
			main.runner.set("_invuln", 9.0)
			await get_tree().physics_frame
		var dir := float(belt.direction_at(Clock.tick))
		check(signf(main.runner.global_position.x - top.x) == dir,
			"a conveyor carries the runner standing on it")
	if warp != null:
		main.runner.global_position = warp.global_position
		main.runner.velocity = Vector2.ZERO
		for _i in 3:
			await get_tree().physics_frame
		check(main.runner.global_position.distance_to(warp.exit) < 60.0,
			"a warp gate delivers the runner to its exit")
		check(warp.global_position.distance_to(warp.exit) > 300.0,
			"the warp jumps further than the guest's snap distance")

	# Falling off the world kills once, not again on the respawn frame.
	var deaths := [0]
	var causes: Array[String] = []
	var count_death := func(cause: String) -> void:
		deaths[0] += 1
		causes.append(cause)
	Events.runner_died.connect(count_death)
	if pursuer != null:
		pursuer.global_position = Vector2(-3000, 6900)
	main.runner.global_position = Vector2(main.runner.global_position.x, Stage.kill_y() + 60.0)
	for _i in 200:
		await get_tree().physics_frame
		# The respawn rebuilds the level, pursuer included; keep whichever one
		# exists out of the way so only the fall is being measured.
		for e in get_tree().get_nodes_in_group("enemy"):
			if String(e.get_script().resource_path).ends_with("sky_pursuer.gd"):
				e.global_position = Vector2(-3000, 6900)
	Events.runner_died.disconnect(count_death)
	check(deaths[0] == 1, "a fall kills once; the respawn does not kill again (%s)" % str(causes))
	for e in get_tree().get_nodes_in_group("enemy"):
		if String(e.get_script().resource_path).ends_with("sky_pursuer.gd"):
			pursuer = e

	# Chaser difficulty: the same chase covers less ground on easier settings.
	check(is_equal_approx(Difficulty.SCALES[Difficulty.Level.HARD], 1.0),
		"HARD is the speed the stage was tuned at")
	var saved_level := Difficulty.current()
	var travelled: Array[float] = []
	if pursuer != null:
		for lv in [Difficulty.Level.EASY, Difficulty.Level.NORMAL, Difficulty.Level.HARD]:
			Difficulty.set_level(lv, false)
			main.runner.global_position = Vector2(-180, 5000)
			main.runner.velocity = Vector2.ZERO
			pursuer.global_position = Vector2(-180, 5700)
			pursuer.set("_stun_left", 0.0)
			pursuer.set("_wake_left", 0.0)
			var from := pursuer.global_position.y
			for _i in 30:
				main.runner.set("_invuln", 9.0)
				main.runner.global_position = Vector2(-180, 5000)
				await get_tree().physics_frame
			travelled.append(from - pursuer.global_position.y)
		check(travelled[0] < travelled[1] and travelled[1] < travelled[2],
			"chaser speed rises EASY < NORMAL < HARD (%s)" % str(travelled))
	Difficulty.set_level(saved_level, false)

	var view = main.get_node_or_null("World3D")
	check(view != null, "Astra 3D world remains enabled")
	if view != null and pursuer != null:
		await get_tree().process_frame
		var binding: Dictionary = view.bindings.get(pursuer.get_instance_id(), {})
		check(String(binding.get("kind", "")) == "sky_predator",
			"1-3 uses the purple 3D predator model")
		check(SkySprites.texture("island_float") != null and SkySprites.texture("predator_0") != null,
			"1-3's painted sprites are imported")

	main.queue_free()
	await get_tree().process_frame
	Stage.use(Stage.Which.HORROR)
	check(Stage.progress_direction() == Vector2.RIGHT, "1-2 remains horizontal")
	check(Stage.stage_number() == "1-2", "1-2 remains selectable")
	finish()

func finish() -> void:
	if failures.is_empty():
		print("skyward ruins probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("skyward ruins probe: " + failure)
		get_tree().quit(1)
