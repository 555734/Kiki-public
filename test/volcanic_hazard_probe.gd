extends Node
var failures: Array[String] = []
func _ready() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("%s %s" % ["ok" if ok else "FAIL", message])
	if not ok: failures.append(message)

func run() -> void:
	Stage.use(Stage.Which.SWAMP)
	var rooms: Array[Dictionary] = Stage.data().rooms()
	var upper: Rect2 = rooms[1]["exit"]
	var lower: Rect2 = rooms[11]["entry"]
	check(lower.position.y - upper.position.y >= 800 and lower.position.x < rooms[9]["exit"].position.x,
		"real lower course overlaps the upper canyon horizontally")
	var descent: Array = Stage.route().filter(func(s: Dictionary) -> bool: return s["section"] == "caldera_descent")
	check(descent.size() == 5 and descent[3]["to"].position.y - descent[0]["from"].position.y == 850,
		"four real terraces descend into the caldera before the lower-course portal")
	check(Stage.key_position().x > rooms[-1]["exit"].position.x and Stage.key_position().y > 800,
		"the gate key is beyond both final lower-course Guardian rescues")
	var counts := {"geyser": 0, "meteor": 0}
	for spec in Stage.gimmicks():
		if spec["type"] == "volcanic_hazard": counts[spec["kind"]] += 1
	check(counts["geyser"] >= 8 and counts["meteor"] >= 7, "mixed authored eruptions and meteor strikes")
	for key in ["s15_meteor", "s15_eruption"]: check(Art.tex(key) != null, key + " sprite imports")
	for invalid in [
		{"kind": "meteor", "travel": Vector2(0, -20)},
		{"kind": "geyser", "travel": Vector2(1, -20)},
		{"period": 2.0}, {"period": Vector2.ONE}, {"width": -1.0}, {"kind": "metoer"}, {"travel": Vector2(INF, 4)}]:
		var spec := {"type": "volcanic_hazard", "pos": Vector2.ZERO}
		spec.merge(invalid, true)
		check(not StageSpecSchema.errors([], [spec]).is_empty(), "invalid volcanic spec rejected: " + str(invalid))
	var main := preload("res://src/main.tscn").instantiate()
	add_child(main)
	main.get_node("NetPanel").queue_free()
	main.input_hub.scripted = true
	for enemy in get_tree().get_nodes_in_group("enemy"): enemy.queue_free()
	Clock.set_physics_process(false)
	for kind in ["geyser", "meteor"]:
		var spec := {"type": "volcanic_hazard", "pos": Vector2(-2000, 1000), "kind": kind,
			"travel": Vector2(0, -230) if kind == "geyser" else Vector2(0, 320)}
		var trap: VolcanicHazard = main.level._make_gimmick(spec)
		trap.position = spec["pos"]
		add_child(trap); trap.set_physics_process(false)
		# Rebuild and guest evaluation agree at every boundary, including wrap.
		var clone: VolcanicHazard = VolcanicHazard.from_spec(spec, main.runner)
		add_child(clone); clone.set_physics_process(false); clone.collision_layer = 0
		for tick in [0, 12, 83, 84, 100, 125, 135, 155, 156, 288, 372, 65536]:
			Clock.is_host = true
			var host := trap.state_at(tick)
			Clock.is_host = false
			check(host == clone.state_at(tick), "%s host/guest/rebuild match at %d" % [kind, tick])
		Clock.is_host = true
		check(trap.state_at(30)["warning"] and not trap.state_at(30)["active"], kind + " warns before damage")
		check(not trap.state_at(83)["active"] and trap.state_at(84)["active"], kind + " damage begins after the full telegraph")
		check(not trap.state_at(170)["active"], kind + " cooldown is harmless")
		if kind == "meteor":
			check(trap.state_at(84)["head"] == Vector2.ZERO and trap.state_at(126)["head"] == trap.travel,
				"meteor falls from source to destination before disappearing")
		Clock.tick = 105
		trap.sync_at(Clock.tick)
		var active: Rect2 = trap.state_at(Clock.tick)["rect"]
		check((trap._shape.shape as RectangleShape2D).size == active.size and trap._shape.position == active.get_center(), kind + " drawn pose matches actual collider")
		var at := trap.position + active.get_center()
		Clock.tick = 30; trap.sync_at(Clock.tick)
		main.runner.respawn(at)
		for _i in 5: await get_tree().physics_frame
		check(main.runner.state != Runner.State.DEAD, kind + " real Runner survives warning")
		Clock.tick = 105; trap.sync_at(Clock.tick)
		main.runner.respawn(at)
		for _i in 5: await get_tree().physics_frame
		check(main.runner.state == Runner.State.DEAD, kind + " real lethal contact during active phase")
		Clock.tick = 170; trap.sync_at(Clock.tick)
		main.runner.respawn(at)
		for _i in 5: await get_tree().physics_frame
		check(main.runner.state != Runner.State.DEAD, kind + " real Runner survives cooldown at the same position")
		trap.free(); clone.free()
		await get_tree().physics_frame
	# Visit checkpoints around the tier transition with real Areas. Earlier
	# upstairs pickups must not reset the lower-route save point after a fall.
	GameState.reset_run(Stage.start())
	var points := Stage.checkpoints()
	for i in [5, 6, 7]:
		main.runner.respawn(points[i] + Vector2(0, 24))
		for _j in 6: await get_tree().physics_frame
		check(GameState.checkpoint_index == i + 1, "checkpoint advances across descent: %d" % (i + 1))
	var saved := GameState.respawn_position()
	main.runner.respawn(points[0] + Vector2(0, 24))
	for _j in 6: await get_tree().physics_frame
	check(GameState.respawn_position() == saved, "earlier upper checkpoint cannot overwrite lower save")
	main._do_respawn()
	check(main.runner.position.distance_to(saved) < 1, "real respawn returns to lower course")
	GameState.has_key = false
	main.runner.respawn(Stage.key_position() + Vector2(0, -22))
	for _j in 3: await get_tree().process_frame
	check(GameState.has_key, "real Runner picks up the required key on the final dry bank")
	main.free(); Clock.is_host = true
	Stage.use(Stage.Which.GREENFIELD)
	print("volcanic hazard probe: ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
