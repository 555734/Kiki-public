extends Node
## Stage 1-5 climbs out of the poison marsh: the lethal pool at the bottom,
## pass-through moss ledges, rot that gives way, log lifts, gas columns, a
## guardian-revealed ledge, and every solid step climbable by a real runner.

const MainScene: PackedScene = preload("res://src/main.tscn")
const ClimbRoute = preload("res://test/climb_route.gd")
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
	check(not Stage.world_3d() and Stage.progress_direction() == Vector2.UP,
		"the painted marsh is now an upward climb")
	check(Stage.water_y() > Stage.start().y and Stage.water_y() < Stage.kill_y(),
		"the poison lies under the starting bank, above the fall sensor")
	var climb := Stage.start().y - Stage.goal().y
	check(climb > 5500.0 and climb < Stage.start().y,
		"a long climb that stays inside the online codec (%.0fpx)" % climb)
	var poison := Stage.hazards()
	check(poison.size() >= 1 and not bool(poison[0].get("draw_spikes", true)),
		"the pool's surface kills without drawing spikes")
	var counts := {}
	for spec in Stage.gimmicks():
		counts[String(spec["type"])] = int(counts.get(String(spec["type"]), 0)) + 1
	check(counts.get("crumble", 0) >= 4 and counts.get("moving_platform", 0) >= 2
		and counts.get("updraft", 0) >= 2 and counts.get("switch_bridge", 0) >= 2,
		"rot, log lifts, gas columns and guardian ledges along the way (%s)" % str(counts))
	var assists := 0
	var ends := {}
	var forks := 0
	for step in Stage.route():
		if String(step["via"]) == "assist":
			assists += 1
		var key := str((step["to"] as Rect2).position)
		ends[key] = int(ends.get(key, 0)) + 1
		if ends[key] == 2:
			forks += 1
	check(assists >= 5, "the guardian has to build the way up (%d assisted steps)" % assists)
	check(forks >= 1, "the route forks (%d)" % forks)
	var per_km := float(Stage.ground().size()) * 1000.0 / climb
	check(per_km < 6.0, "fewer ledges than the old staircase (%.1f per 1000px)" % per_km)
	check(Stage.checkpoints().size() >= 6, "regular checkpoints on the climb")
	var kinds := {}
	for spec in Stage.enemies():
		kinds[String(spec["type"])] = true
	check(kinds.has("sky_pursuer") and kinds.has("walker") and kinds.has("flyer"),
		"the chaser, spiked crawlers and marsh flies")
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
	check(main.runner.is_on_floor(), "the runner starts on the dry bank")
	var shapes: Array[Node] = main.level._static_root.get_node("Ground").get_children()
	check(not (shapes[0] as CollisionShape2D).one_way_collision
		and (shapes[1] as CollisionShape2D).one_way_collision,
		"the bank is solid; the ledges can be jumped through from below")

	var deaths := [0]
	var died := func(_cause: String) -> void: deaths[0] += 1
	Events.runner_died.connect(died)
	main.runner.global_position = Vector2(700, Stage.water_y() - 40.0)
	main.runner.velocity = Vector2.ZERO
	for _i in 45:
		await get_tree().physics_frame
	Events.runner_died.disconnect(died)
	check(deaths[0] == 1, "touching the poison kills once (%d)" % deaths[0])
	for _i in int(Balance.RESPAWN_DELAY * 60.0) + 20:
		await get_tree().physics_frame

	var failed: Array[String] = await ClimbRoute.climb_all(get_tree(), main, 140.0)
	check(failed.is_empty(), "every jump and guardian-assisted step of the route works (%d failed: %s)"
		% [failed.size(), ", ".join(failed.slice(0, 4))])
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
