extends Node
## Stage 1-6 wiring, route and four enemy behaviours.

const MainScene: PackedScene = preload("res://src/main.tscn")
const SwitchBridge = preload("res://src/entities/gimmicks/switch_bridge.gd")
const TrickPad = preload("res://src/entities/gimmicks/trick_pad.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Stage.use(Stage.Which.DESERT)
	check(Stage.stage_number() == "1-6" and Stage.stage_name() == "THE SANDGLASS RUINS",
		"desert stage identity")
	check(not Stage.world_3d() and Stage.needs_key(),
		"painted 2D world with a required key")
	check(Stage.goal().x > Stage.start().x + 7000.0 and Stage.goal().x < 30000.0,
		"full route fits online coordinates")
	var kinds := {}
	for spec in Stage.enemies():
		if spec["type"] != "desert_enemy": continue
		kinds[String(spec.get("kind", ""))] = true
	check(kinds.size() == 4 and kinds.has("scarab") and kinds.has("cactus")
		and kinds.has("jelly") and kinds.has("fin"), "all four desert enemy kinds are placed")
	var bridge: Rect2 = Stage.solid_decor()[0]
	check(bridge.position.x == Stage.ground()[3].end.x
		and bridge.end.x == Stage.ground()[4].position.x,
		"rope bridge has solid collision")
	var gimmick_counts := {}
	for spec in Stage.gimmicks():
		var kind: String = spec["type"]
		gimmick_counts[kind] = int(gimmick_counts.get(kind, 0)) + 1
	check(gimmick_counts.get("crumble", 0) >= 6
		and gimmick_counts.get("blink", 0) >= 4
		and gimmick_counts.get("moving_platform", 0) >= 2
		and gimmick_counts.get("conveyor", 0) >= 2
		and gimmick_counts.get("switch_bridge", 0) >= 5
		and gimmick_counts.get("trick_pad", 0) >= 3
		and gimmick_counts.has("updraft") and gimmick_counts.has("tower_trap")
		and gimmick_counts.has("warp") and gimmick_counts.has("gear_wheel")
		and gimmick_counts.has("clock_hand"),
		"desert route mixes launch pads and revealed bridges with its earlier beats")
	check(Stage.checkpoints().size() >= 14,
		"checkpoints break up the harder route")
	check(Stage.ground()[7].position.x - Stage.ground()[6].end.x == 790.0,
		"guardian crossing keeps a clear cooperative challenge")
	var oracle_switches := 0
	var oracle_gate: Dictionary = {}
	for spec in Stage.gimmicks():
		if spec.get("id", "") != "desert_oracle":
			continue
		if spec["type"] == "switch":
			oracle_switches += 1
		elif spec["type"] == "gate":
			oracle_gate = spec
	check(oracle_switches == 2 and oracle_gate.get("wants", 0) == 2
		and oracle_gate.get("span", Vector2.ZERO).y > Balance.RUNNER_JUMP_HEIGHT,
		"guardian-only sigil gate requires the pair to communicate")
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var panel := main.get_node_or_null("NetPanel")
	check(panel != null and panel._cards().size() == 9,
		"nine-stage selection includes the desert, tower, cave and parade stages")
	if panel != null:
		await get_tree().process_frame
		check(panel._stage_1_6 != null, "desert card appears on its own page")
		panel.queue_free()
	for _i in 30:
		await get_tree().physics_frame
	check(main.runner.is_on_floor(), "runner starts on sandstone")
	var built := {}
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is DesertEnemy:
			built[node.kind] = true
	check(built.size() == 4, "all four enemy classes build in the live level")
	var oracle: Gate = null
	var correct: ShootableSwitch = null
	var mirage: SwitchBridge = null
	var delayed_mirage: SwitchBridge = null
	var mirage_switch: ShootableSwitch = null
	var pad_count := 0
	var first_pad: TrickPad = null
	for node in main.level._dynamic.get_children():
		if node is SwitchBridge and node.switch_id == "desert_mirage":
			if node.delay > 0.0:
				delayed_mirage = node
			else:
				mirage = node
		if node is TrickPad:
			pad_count += 1
			if first_pad == null:
				first_pad = node
	for node in get_tree().get_nodes_in_group("gate"):
		if node is Gate and node.switch_id == "desert_oracle":
			oracle = node
	for node in get_tree().get_nodes_in_group("switch"):
		if node is ShootableSwitch and node.switch_id == "desert_mirage":
			mirage_switch = node
		if node is ShootableSwitch and node.switch_id == "desert_oracle" \
				and node.sigil == 2:
			correct = node
	check(oracle != null and correct != null and Sigil.wanted("desert_oracle") == 2,
		"cooperative gate and matching target exist in the live level")
	if oracle != null and correct != null:
		check(not oracle._shape.disabled, "oracle gate starts closed")
		correct.take_damage(1)
		for _i in 30:
			await get_tree().physics_frame
		check(oracle._shape.disabled, "guardian shot opens the oracle gate")
	check(mirage != null and delayed_mirage != null and mirage_switch != null
		and pad_count >= 3,
		"new desert set pieces build in the live level")
	if mirage != null and delayed_mirage != null and mirage_switch != null:
		check(mirage._shape.disabled, "mirage starts as a visible ghost, without collision")
		mirage_switch.take_damage(1)
		for _i in 24:
			await get_tree().physics_frame
		check(not mirage._shape.disabled, "guardian shot makes the mirage bridge solid")
		check(delayed_mirage._shape.disabled, "second mirage waits for its own beat")
		for _i in 20:
			await get_tree().physics_frame
		check(not delayed_mirage._shape.disabled, "second mirage follows the first")
		mirage_switch.take_damage(1)
		await get_tree().physics_frame
		check(not mirage._shape.disabled,
			"shooting again extends the bridge without dropping its rider")
		Events.switch_activated.emit("desert_mirage:off")
		await get_tree().physics_frame
		check(mirage._shape.disabled, "mirage withdraws when the target expires")
	if first_pad != null:
		var original_position: Vector2 = main.runner.global_position
		main.runner.global_position = first_pad.global_position + Vector2(0, -23)
		main.runner.velocity = Vector2.ZERO
		first_pad._physics_process(1.0 / 60.0)
		check(main.runner.velocity.x > 400.0 and main.runner.velocity.y < -800.0,
			"arrow pad throws the runner forward and over the obstacle")
		main.runner.global_position = original_position
		main.runner.velocity = Vector2.ZERO
	main.queue_free()
	await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	if failures.is_empty():
		print("desert stage probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("desert stage probe: " + failure)
		get_tree().quit(1)
