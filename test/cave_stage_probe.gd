extends Node
## The upward cave route, cooperative echo bridges, culling and camera.

const MainScene: PackedScene = preload("res://src/main.tscn")
const CaveData = preload("res://src/levels/level_cave_data.gd")
const SwitchBridge = preload("res://src/entities/gimmicks/switch_bridge.gd")
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
		"stage identity")
	check(not Stage.world_3d() and Stage.progress_direction() == Vector2.UP,
		"the cave is a painted upward route")
	check(Stage.start().y - Stage.goal().y > 12000.0
		and Stage.goal().y < CaveData.SURFACE_Y,
		"the long climb ends above the cave roof")
	check(Stage.key_position().y > Stage.goal().y
		and Stage.key_position().y < 1300.0 and Stage.needs_key(),
		"the final cave landing holds the exit key")
	check(CaveData.CHAMBERS >= 24 and Stage.checkpoints().size() >= 12,
		"the climb has long pacing and regular recovery")
	check(Stage.ground().size() >= 60 and Stage.ground()[-1].position.y < CaveData.SURFACE_Y,
		"individually culled cave ledges reach the surface shelf")
	var ordered := true
	var fixed_landings := true
	for chamber in CaveData.CHAMBERS:
		for step in 3:
			ordered = ordered and CaveData._top(chamber, step + 1) < CaveData._top(chamber, step)
		fixed_landings = fixed_landings and CaveData._kind(chamber, 3) == "stone"
	check(ordered and fixed_landings, "every chamber rises through readable steps")
	var kinds := {}
	for spec in Stage.enemies():
		if String(spec.get("type", "")) == "cave_enemy":
			kinds[String(spec["kind"])] = true
	check(Stage.enemies().size() >= 50 and kinds.size() == 5,
		"all five cave enemy types populate the vertical shaft")
	var gimmick_counts := {}
	var trap_kinds := {}
	var bridge_ids := {}
	var switch_ids := {}
	for spec in Stage.gimmicks():
		var type: String = spec["type"]
		gimmick_counts[type] = int(gimmick_counts.get(type, 0)) + 1
		if type == "cave_trap":
			trap_kinds[String(spec["kind"])] = true
		if type == "switch_bridge":
			bridge_ids[String(spec["id"])] = true
		if type == "switch":
			switch_ids[String(spec["id"])] = true
	check(gimmick_counts.get("moving_platform", 0) >= 8
		and gimmick_counts.get("updraft", 0) >= 4
		and gimmick_counts.get("blink", 0) >= 6
		and gimmick_counts.get("crumble", 0) >= 6
		and trap_kinds.size() == 2,
		"lifts, wind, timed ledges and two trap types vary the ascent")
	var paired := bridge_ids.size() == 4
	for id in bridge_ids:
		paired = paired and switch_ids.has(id)
	check(paired, "four missing landings need the guardian's shot")
	var safe_checkpoints := true
	for cp in Stage.checkpoints():
		for enemy in Stage.enemies():
			if cp.distance_to(enemy["pos"]) < 78.0:
				safe_checkpoints = false
		for hazard in Stage.hazards():
			if cp.distance_to(hazard["pos"]) < 80.0:
				safe_checkpoints = false
	check(safe_checkpoints, "checkpoint flags are clear of immediate danger")
	var wire_y := Snapshot._u_y(Snapshot._q_y(Stage.start().y))
	check(absf(wire_y - Stage.start().y) <= 0.25,
		"deep starting position fits the online codec")

	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var panel := main.get_node_or_null("NetPanel")
	check(panel != null and panel._stage_1_8 != null,
		"menu still offers the new cave route")
	if panel != null:
		panel.queue_free()
	check(main.level._terrain._cave_chunks.size() == Stage.ground().size(),
		"each cave ledge is rendered as a separate culled item")
	for _i in 30:
		await get_tree().physics_frame
	check(main.runner.is_on_floor(), "runner begins on deep cave ground")
	var ground_shapes: Array[Node] = main.level._static_root.get_node("Ground").get_children()
	var base_shape: CollisionShape2D = ground_shapes[0]
	var ledge_shape: CollisionShape2D = ground_shapes[1]
	check(not base_shape.one_way_collision and ledge_shape.one_way_collision,
		"floating cave stone can be jumped through from below")
	var first: Rect2 = Stage.ground()[1]
	main.runner.global_position = Vector2(first.get_center().x, CaveData.BASE_Y - 23.0)
	main.runner.velocity = Vector2.ZERO
	for _i in 8:
		await get_tree().physics_frame
	var jump_button: Dictionary = ControlLayout.layout("shared",
		Vector2(get_viewport().get_visible_rect().size))["jump"]
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 77
	touch_down.position = jump_button["center"]
	touch_down.pressed = true
	get_viewport().push_input(touch_down, true)
	for _i in 20:
		await get_tree().physics_frame
	check(main.runner.global_position.y < first.position.y - 23.0,
		"a real jump-button touch carries the runner through the first ledge")
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 77
	touch_up.position = jump_button["center"]
	touch_up.pressed = false
	get_viewport().push_input(touch_up, true)
	for _i in 48:
		await get_tree().physics_frame
	check(main.runner.is_on_floor()
		and absf(main.runner.global_position.y - (first.position.y - 23.0)) < 4.0,
		"runner lands on the same ledge after passing through it")
	var entrance: Vector2 = main.runner.global_position
	main._snap_camera_to_runner()
	var stable_y: float = main.camera.global_position.y
	main.runner.global_position = entrance + Vector2(0, -100)
	main._update_camera(1.0 / 60.0)
	check(absf(main.camera.global_position.y - stable_y) < 0.01,
		"ordinary jumps do not bounce the vertical camera")
	main.runner.global_position = entrance + Vector2(0, -220)
	for _i in 24:
		main._update_camera(1.0 / 60.0)
	check(main.camera.global_position.y < stable_y - 20.0,
		"camera follows sustained upward progress")
	main.runner.global_position = entrance
	main._snap_camera_to_runner()
	main.runner.global_position = entrance + Vector2(0, 620)
	main._update_camera(1.0 / 60.0)
	var safe_y: float = get_viewport().get_visible_rect().size.y * 0.5 \
		/ main.camera.zoom.y - 70.0
	check(absf(main.runner.global_position.y - main.camera.global_position.y) <= safe_y + 0.01,
		"camera keeps the runner visible through a fall")
	main.runner.global_position = entrance
	main._snap_camera_to_runner()
	var live_enemies := 0
	var live_traps := 0
	var bridge: SwitchBridge = null
	var target: ShootableSwitch = null
	var far_enemy: CaveEnemy = null
	var sample_trap: CaveTrap = null
	for node in main.level._dynamic.get_children():
		if node is CaveEnemy:
			live_enemies += 1
			if node.global_position.y < 4000.0 and far_enemy == null:
				far_enemy = node
		if node is CaveTrap:
			live_traps += 1
			if sample_trap == null:
				sample_trap = node
		if node is SwitchBridge and node.switch_id == "cave_rise_5":
			bridge = node
		if node is ShootableSwitch and node.switch_id == "cave_rise_5":
			target = node
	check(live_enemies >= 50 and live_traps >= 8 and bridge != null and target != null,
		"vertical cave actors build in the live level")
	if bridge != null and target != null:
		check(bridge._shape.disabled and bridge._shape.one_way_collision,
			"echo landing starts intangible and becomes a one-way ledge")
		target.take_damage(1)
		for _i in 24:
			await get_tree().physics_frame
		check(not bridge._shape.disabled, "guardian shot reveals the missing landing")
		Events.switch_activated.emit("cave_rise_5:off")
		await get_tree().physics_frame
		check(bridge._shape.disabled, "echo landing fades after the timed shot")
	if far_enemy != null:
		var dormant: Vector2 = far_enemy.global_position
		for _i in 6:
			await get_tree().physics_frame
		check(far_enemy.global_position == dormant,
			"distant cave enemies sleep despite sharing the same narrow shaft")
		main.runner.global_position = dormant + Vector2(0, -130)
		main._snap_camera_to_runner()
		for _i in 10:
			await get_tree().physics_frame
		check(far_enemy.global_position != dormant,
			"enemies wake before the camera reaches their chamber")
	if sample_trap != null:
		check(sample_trap.head_at(0) != sample_trap.head_at(
			Clock.ticks_for(sample_trap.period * 0.25)),
			"cave traps still follow the shared clock")
	# Online. The host's failover frame is taken four times a second, so it
	# has to be cheap and small for the longest stage.
	var started := Time.get_ticks_usec()
	MigrationState.capture(main)
	var frame := MigrationState.capture(main)
	var capture_ms := float(Time.get_ticks_usec() - started) / 2000.0
	check(MigrationState.chunks(frame, 1, 0).size() <= 4,
		"the host's failover frame fits in a few packets (%d bytes)" % frame.size())
	check(capture_ms < 8.0,
		"and is taken without stalling a frame (%.1f ms)" % capture_ms)
	check(MigrationState.decode(frame).get("groups", {}).get("enemy", []).size() \
			== get_tree().get_nodes_in_group("enemy").size(), "and still describes every enemy")
	# On the guest the host moves every enemy. The cave's wake timer must not
	# switch their own patrols back on, or they walk away from where they hit.
	main._become_client(LoopbackTransport.pair(0.0)[0])
	main.runner.global_position = Stage.start()
	main._snap_camera_to_runner()
	for _i in 20:
		await get_tree().physics_frame
	var simulating := 0
	for node in main.level._dynamic.get_children():
		if node is CaveEnemy and node.is_physics_processing():
			simulating += 1
	check(simulating == 0,
		"the guest's cave enemies follow the host instead of patrolling (%d did)" % simulating)
	main._end_any_session()
	Clock.is_host = true
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
