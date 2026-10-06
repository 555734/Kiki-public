extends Node
## Stage 1-7's long vertical route, stage wiring and deterministic machinery.

const MainScene: PackedScene = preload("res://src/main.tscn")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Stage.use(Stage.Which.TOWER)
	check(Stage.stage_number() == "1-7" and Stage.stage_name() == "THE CLOCKWORK TOWER",
		"stage 1-7 is selectable")
	check(not Stage.world_3d() and Stage.progress_direction() == Vector2.UP,
		"tower uses painted vertical view")
	check(Stage.start().y - Stage.goal().y > 10000,
		"route climbs more than 10,000 pixels")
	check(Stage.start().y < 15359 and Stage.kill_y() < 15359,
		"online coordinate codec covers the entire tower")
	check(Stage.checkpoints().size() >= 10,
		"long route has regular checkpoints")
	var kinds := {}
	var trap_kinds := {}
	var gate_count := 0
	var targets := {}
	for g in Stage.gimmicks():
		kinds[String(g["type"])] = true
		if g["type"] == "tower_trap":
			trap_kinds[String(g["kind"])] = true
		if g["type"] == "gate":
			gate_count += 1
		if g["type"] == "switch":
			targets[String(g["id"])] = true
	check(kinds.has("moving_platform") and kinds.has("clock_hand")
		and kinds.has("gear_wheel")
		and kinds.has("blink") and kinds.has("conveyor")
		and kinds.has("crumble") and kinds.has("updraft")
		and kinds.has("warp") and kinds.has("switch"),
		"image-board platform and traversal gimmicks are present")
	check(trap_kinds.has("pendulum") and trap_kinds.has("piston")
		and trap_kinds.has("spikes"), "all three clockwork traps are present")
	check(gate_count >= 1 and targets.size() >= 3,
		"the guardian's shots open a door and raise bridges on the way up")
	# The guardian's wall: a climb no jump of the runner's own makes.
	var assist := {}
	for step in Stage.route():
		if String(step["via"]) == "assist":
			assist = step
	var solo_rise := Runner.ground_jump_height(
		Balance.RUNNER_RUN_SPEED * Balance.RUNNER_SPRINT_MULTIPLIER, 3) \
		+ Balance.RUNNER_AIR_JUMP_HEIGHT
	check(not assist.is_empty() and (assist["from"] as Rect2).position.y
			- (assist["to"] as Rect2).position.y > solo_rise,
		"the guardian's stair climbs higher than any jump and second jump")
	var y_wire := Snapshot._u_y(Snapshot._q_y(Stage.start().y))
	check(absf(y_wire - Stage.start().y) <= 0.125,
		"the start position survives the online snapshot codec")
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var panel := main.get_node_or_null("NetPanel")
	check(panel != null and panel._stage_1_7 != null,
		"third menu page shows the tower card")
	if panel != null:
		panel.queue_free()
	for _i in 25:
		await get_tree().physics_frame
	check(main.runner.is_on_floor(), "runner starts on the tower's entrance floor")
	var camera_start: Vector2 = main.runner.global_position
	main._snap_camera_to_runner()
	var stable_y: float = main.camera.global_position.y
	main.runner.global_position = camera_start + Vector2(0.0, -80.0)
	main._update_camera(1.0 / 60.0)
	check(absf(main.camera.global_position.y - stable_y) < 0.01,
		"short tower jump stays inside the camera's vertical band")
	main.runner.global_position = camera_start + Vector2(0.0, -230.0)
	for _i in 24:
		main._update_camera(1.0 / 60.0)
	check(main.camera.global_position.y < stable_y - 30.0,
		"camera follows the tower's long ascent")
	main.runner.global_position = camera_start + Vector2(0.0, 650.0)
	main._update_camera(1.0 / 60.0)
	var safe_y: float = get_viewport().get_visible_rect().size.y * 0.5 \
		/ main.camera.zoom.y - 70.0
	check(absf(main.runner.global_position.y - main.camera.global_position.y) <= safe_y + 0.01,
		"camera keeps runner visible during a sudden tower fall")
	main.runner.global_position = camera_start
	main._snap_camera_to_runner()
	if not assist.is_empty():
		var at_entrance: Vector2 = main.runner.global_position
		var from: Rect2 = assist["from"]
		main.runner.global_position = Vector2(from.get_center().x, from.position.y - 26.0)
		var first: Rect2 = assist["platforms"][0]
		check(BuildAbility.platform().check(main.guardian, first.get_center()) == "",
			"guardian can build the first step of the stair up the wall")
		main.runner.global_position = at_entrance
	var hands := 0
	var wheels := 0
	var traps := 0
	var sample_hand: ClockHandBridge = null
	var sample_trap: TowerTrap = null
	var gate: Gate = null
	var right_switch: ShootableSwitch = null
	for node in get_tree().get_nodes_in_group("instant_death"):
		if node is TowerTrap:
			traps += 1
			if sample_trap == null and node.kind == "pendulum":
				sample_trap = node
	for node in main.level._dynamic.get_children():
		if node is ClockHandBridge:
			hands += 1
			if sample_hand == null:
				sample_hand = node
		if node is GearWheel:
			wheels += 1
		if node is Gate and node.switch_id == "tower_sigil":
			gate = node
		if node is ShootableSwitch and node.switch_id == "tower_sigil" \
				and node.sigil == Sigil.SQUARE:
			right_switch = node
	check(hands >= 2 and wheels >= 2 and traps >= 9,
		"rotating bridges, rideable gears and timed traps build in the live stage")
	if sample_hand != null:
		check(not is_equal_approx(sample_hand.angle_at(0),
			sample_hand.angle_at(Clock.ticks_for(sample_hand.period * 0.25))),
			"clock-hand bridge rotates from the shared tick")
	if sample_trap != null:
		check(sample_trap.head_at(0) != sample_trap.head_at(
			Clock.ticks_for(sample_trap.period * 0.25)),
			"pendulum position changes from the shared tick")
	check(gate != null and right_switch != null,
		"the sigil door has its matching remote target")
	if gate != null and right_switch != null:
		check(not gate._shape.disabled, "the sigil door starts closed")
		right_switch.take_damage(1)
		for _i in 30:
			await get_tree().physics_frame
		check(gate._shape.disabled, "guardian shot opens the tower gate")
	main.queue_free()
	await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	if failures.is_empty():
		print("tower stage probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("tower stage probe: " + failure)
		get_tree().quit(1)
