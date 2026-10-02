extends Node
## Stage 1-8's route, underground cast, guardian crossing and live machinery.

const MainScene: PackedScene = preload("res://src/main.tscn")
const CaveData = preload("res://src/levels/level_cave_data.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Stage.use(Stage.Which.CAVE)
	check(Stage.stage_number() == "1-8" and Stage.stage_name() == "THE UNDERGROVE",
		"stage 1-8 is wired")
	check(not Stage.world_3d() and Stage.progress_direction() == Vector2.RIGHT,
		"cave uses a horizontal painted playfield")
	check(Stage.goal().x - Stage.start().x > 24000.0,
		"extended underground course spans more than 24,000 pixels")
	check(Stage.checkpoints().size() >= 20,
		"extended course has recovery checkpoints")
	check(Stage.needs_key() and Stage.sky_crows().is_empty(),
		"cave has a goal key without outdoor sky crows")
	check(Stage.key_position().x > 19162.0 and Stage.key_position().x < 22650.0
		and Stage.key_position().y < 200.0,
		"key waits on safe ground beyond the final cooperation gate")
	var cast := {}
	for spec in Stage.enemies():
		cast[String(spec["kind"])] = true
	check(Stage.enemies().size() >= 45 and cast.size() == 5,
		"five cave enemy types crowd the extended course")
	var kinds := {}
	var traps := {}
	var carts := 0
	for spec in Stage.gimmicks():
		kinds[String(spec["type"])] = true
		if spec["type"] == "cave_trap":
			traps[String(spec["kind"])] = true
		if spec.get("style", "") == "minecart":
			carts += 1
	check(carts == 4 and kinds.has("crumble") and kinds.has("updraft")
		and kinds.has("switch") and kinds.has("gate") and traps.size() == 2
		and Stage.springs().size() >= 6,
		"extended machinery has working stage data")
	# Allow a generous full second at the maximum triple-jump forward boost,
	# plus the runner's width. The actual held arc is shorter than this bound.
	var solo_reach_bound := Balance.RUNNER_RUN_SPEED \
		* Balance.RUNNER_SPRINT_MULTIPLIER * 1.12 + 46.0
	var fissures := []
	var ordinary_gaps_ok := true
	for i in range(1, CaveData.SLABS.size()):
		var gap: float = CaveData.SLABS[i][0] - CaveData.SLABS[i - 1][1]
		if gap > 230.0:
			fissures.append(gap)
		else:
			ordinary_gaps_ok = ordinary_gaps_ok and gap <= 230.0
	var fissures_need_help := fissures.size() == 3
	for gap in fissures:
		fissures_need_help = fissures_need_help and gap > solo_reach_bound
	check(fissures_need_help,
		"three fissures require guardian-built footing")
	check(ordinary_gaps_ok, "other route gaps stay within the authored jump range")
	var safe_checkpoints := true
	for cp in Stage.checkpoints():
		for enemy in Stage.enemies():
			if enemy["kind"] == "bat" or enemy["kind"] == "beetle":
				continue
			if absf(cp.x - enemy["pos"].x) < enemy["patrol"] + 54.0:
				print("  unsafe checkpoint enemy: ", cp, " / ", enemy["pos"])
				safe_checkpoints = false
		for spec in Stage.gimmicks():
			if spec["type"] == "cave_trap" and spec["kind"] == "boulder":
				if absf(cp.x - spec["pos"].x) < spec["travel"] + 70.0:
					print("  unsafe checkpoint boulder: ", cp, " / ", spec["pos"])
					safe_checkpoints = false
		for hazard in Stage.hazards():
			if absf(cp.x - hazard["pos"].x) < hazard["size"].x * 0.5 + 30.0:
				print("  unsafe checkpoint spikes: ", cp, " / ", hazard["pos"])
				safe_checkpoints = false
	check(safe_checkpoints, "checkpoints stay clear of patrols, rocks and spikes")
	var wire_x := Snapshot._u_x(Snapshot._q_x(Stage.goal().x))
	check(absf(wire_x - Stage.goal().x) <= 0.25,
		"far goal fits the online position codec")
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var panel := main.get_node_or_null("NetPanel")
	check(panel != null and panel._stage_1_8 != null,
		"third menu page contains the cave card")
	if panel != null:
		panel.queue_free()
	for _i in 25:
		await get_tree().physics_frame
	check(main.runner.is_on_floor(), "runner begins on solid cave ground")
	var entrance: Vector2 = main.runner.global_position
	for crossing in [
		{"runner": Vector2(5280, 170), "platform": Vector2(5675, 280)},
		{"runner": Vector2(13280, 210), "platform": Vector2(13690, 290)},
		{"runner": Vector2(18280, 150), "platform": Vector2(18680, 250)},
	]:
		main.runner.global_position = crossing["runner"]
		check(BuildAbility.platform().check(main.guardian, crossing["platform"]) == "",
			"guardian can place footing across the fissure near x=%.0f" \
				% crossing["platform"].x)
	main.runner.global_position = entrance
	var live_enemies := 0
	var live_carts := 0
	var live_traps := 0
	var gates := {}
	var switches := {}
	var sample_trap: CaveTrap = null
	for node in main.level._dynamic.get_children():
		if node is CaveEnemy:
			live_enemies += 1
		if node is MovingPlatform and node.visual_style == "minecart":
			live_carts += 1
		if node is CaveTrap:
			live_traps += 1
			if sample_trap == null:
				sample_trap = node
		if node is Gate:
			gates[node.switch_id] = node
		if node is ShootableSwitch:
			var wanted := 1 if node.switch_id == "cave_deep_gate" else 2
			if node.sigil == wanted:
				switches[node.switch_id] = node
	check(live_enemies >= 45 and live_carts == 4 and live_traps >= 17,
		"enemies, rideable carts and hazards build in the live level")
	if sample_trap != null:
		check(sample_trap.head_at(0) != sample_trap.head_at(
			Clock.ticks_for(sample_trap.period * 0.25)),
			"underground trap moves from the shared tick")
	check(gates.size() >= 3 and switches.size() >= 3,
		"three cooperation gates build with matching remote targets")
	for id in ["cave_bridge", "cave_deep_gate", "cave_last_gate"]:
		if not gates.has(id) or not switches.has(id):
			continue
		check(not gates[id]._shape.disabled, "%s starts closed" % id)
		switches[id].take_damage(1)
		for _i in 30:
			await get_tree().physics_frame
		check(gates[id]._shape.disabled, "guardian shot opens %s" % id)
	main.queue_free()
	await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	if failures.is_empty():
		print("cave stage probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("cave stage probe: " + failure)
		get_tree().quit(1)
