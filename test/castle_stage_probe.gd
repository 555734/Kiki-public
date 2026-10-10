extends Node
## 1-9 "The King's Road": eight obstacles the runner cannot pass alone, each
## one opened by the guardian's hand.

const MainScene: PackedScene = preload("res://src/main.tscn")
const Castle = preload("res://src/levels/level_castle_data.gd")
const SkyPursuerScript = preload("res://src/entities/enemies/sky_pursuer.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func _physics(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame

func run() -> void:
	Stage.use(Stage.Which.CASTLE)
	check(Stage.stage_number() == "1-9" and Stage.stage_name() == "THE KING'S ROAD" and Stage.is_castle(),
		"stage identity")
	check(Stage.current() == Stage.Which.size() - 1, "1-9 was added at the end of the handshake enum")
	check(Castle.sections().size() == 7, "seven obstacles along one road")

	# What the runner can do alone, at best: a sprinting triple jump.
	var best_height := Balance.RUNNER_JUMP_HEIGHT * (1.0 + Balance.RUNNER_SPRINT_JUMP_BONUS) \
		* Balance.RUNNER_TRIPLE_HEIGHT
	var best_speed := Balance.RUNNER_RUN_SPEED * Balance.RUNNER_SPRINT_MULTIPLIER \
		* Balance.RUNNER_TOP_GEAR_MULTIPLIER * Balance.RUNNER_TRIPLE_FORWARD_BOOST
	var best_leap := best_speed * 2.0 * sqrt(2.0 * best_height / Balance.RUNNER_GRAVITY)
	check(Castle.CHASM.y - Castle.CHASM.x > best_leap * 1.3,
		"A: the chasm is far wider than any leap (%.0f vs %.0f)" % [Castle.CHASM.y - Castle.CHASM.x, best_leap])
	# B, D: the ball and the block both reach down onto the road: neither can
	# just be walked under.
	var ball_low := Castle.BALL_PIVOT.y + Castle.BALL_CHAIN
	check(ball_low + 31.0 > Castle.GROUND_TOP - 46.0 and ball_low - 31.0 < Castle.GROUND_TOP,
		"B: the spiked ball swings through the runner's height")
	# The stair can be climbed: each step lower than a jump.
	for step in Castle.stair():
		check(step.size.x == Castle.STEP_W, "the stair's steps are whole bricks")
	check(Castle.STEP_W < best_height, "the stair can be climbed a step at a time")
	var keep_height := Castle.GROUND_TOP - Castle.KEEP_TOP
	check(keep_height > best_height * 1.5 and keep_height < Balance.SLING_HEIGHT,
		"G: the keep wall is past any jump and within the slingshot (%.0f)" % keep_height)
	check(SkyGolem.BASE_SIZE.y * Castle.GOLEM_SCALE > best_height,
		"H: the stone guardian is taller than any jump")

	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
	main._respawn_timer = -1.0
	var castle_set := false
	for child in main.level._static_root.get_children():
		castle_set = castle_set or child is CastleSet
	check(castle_set, "the castle's set is built")
	var g: Guardian = main.guardian
	var r: Runner = main.runner
	var pursuer: Node2D = null
	var gate: LiftGate = null
	var golem: SkyGolem = null
	var turret: Turret = null
	var block: HoldableTowerTrap = null
	var ball: HoldableTowerTrap = null
	for node in get_tree().get_nodes_in_group("enemy"):
		if node.get_script() == SkyPursuerScript: pursuer = node
		if node is SkyGolem: golem = node
		if node is Turret: turret = node
	for node in get_tree().get_nodes_in_group("hand_holdable"):
		if node is LiftGate: gate = node
		if node is HoldableTowerTrap:
			if node.kind == "piston": block = node
			if node.kind == "pendulum": ball = node
	check(pursuer != null and gate != null and golem != null and turret != null and block != null
		and ball != null, "every obstacle is built")
	if failures.is_empty():
		# E: the hound is shut out by the dropped gate, however far ahead the
		# runner gets -- it does not leap past to catch up.
		r.global_position = Vector2(Castle.GATE_X + 300.0, Castle.GROUND_TOP - 23.0)
		r.velocity = Vector2.ZERO
		pursuer.global_position = Vector2(Castle.GATE_X - 500.0, Castle.GROUND_TOP - 65.0)
		pursuer._activated = true
		pursuer._wake_left = 0.0
		await _physics(150)
		check(pursuer.global_position.x < Castle.GATE_X, "E: a shut gate holds the hound")
		# Far enough ahead that an ungated hound would jump to catch up.
		r.global_position = Vector2(Castle.KEEP_END - 200.0, Castle.KEEP_TOP - 23.0)
		await _physics(90)
		check(pursuer.global_position.x < Castle.GATE_X and r.state != Runner.State.DEAD,
			"E: and keeps holding it when the runner is far ahead")
		GuardianHand.apply(g, GuardianHand.Act.HOLD, gate.hand_id, gate.hand_point(), Vector2.ZERO)
		await _physics(90)
		check(pursuer.global_position.x > Castle.GATE_X, "E: lifted, it lets the hound through too")
		GuardianHand.apply(g, GuardianHand.Act.LET_GO, gate.hand_id, gate.hand_point(), Vector2.ZERO)
		# Done with it: back to sleep, or it runs down the runner below.
		pursuer.set_physics_process(false)
		pursuer.global_position = Vector2(-1500, 335)
		# G: the slingshot puts the runner on top of the keep.
		r.global_position = Vector2(Castle.KEEP_X - 220.0, Castle.GROUND_TOP - 23.0)
		r.velocity = Vector2.ZERO
		await _physics(20)
		check(r.is_on_floor(), "G: the runner stands at the foot of the keep")
		var from := r.global_position
		GuardianHand.apply(g, GuardianHand.Act.SLING, 0, from, from + Vector2(-50.0, 170.0))
		var landed := false
		# The runner's player steers toward the wall in the air, as anyone would.
		main.input_hub.scripted = true
		for _i in 180:
			main.input_hub.drive_runner(1.0, 0.0, false, false)
			await _physics(1)
			if r.is_on_floor() and r.global_position.y < Castle.KEEP_TOP:
				landed = true
				break
		main.input_hub.drive_runner(0.0, 0.0, false, false)
		check(landed, "G: the slingshot lands the runner on the keep (%s)" % r.global_position)
		# H: flicked, the guardian of the door goes.
		GuardianHand.apply(g, GuardianHand.Act.FLICK, golem.net_id, golem.global_position, Vector2(900, -700))
		await _physics(60)
		check(not is_instance_valid(golem) or golem.is_queued_for_deletion(), "H: a flick throws the stone guardian off")
		# B, D: held by the finger, the ball and the block stay where they are.
		for trap in [block, ball]:
			GuardianHand.apply(g, GuardianHand.Act.HOLD, trap.hand_id, trap.hand_point(), Vector2.ZERO)
			var held: Vector2 = trap.hand_point()
			await _physics(30)
			check(trap.hand_point().distance_to(held) < 1.0, "%s: held, it stays put" % trap.kind)
			GuardianHand.apply(g, GuardianHand.Act.LET_GO, trap.hand_id, held, Vector2.ZERO)
			# The block waits at the top of its beat: give it a whole one.
			var moved := false
			for _i in int(trap.period * 60.0) + 10:
				await _physics(1)
				moved = moved or trap.hand_point().distance_to(held) > 1.0
			check(moved, "%s: let go, it moves again" % trap.kind)
	main.queue_free()
	await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	if failures.is_empty():
		print("castle stage probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("castle stage probe: " + failure)
		get_tree().quit(1)
