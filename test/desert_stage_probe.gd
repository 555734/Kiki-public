extends Node
## Stage 1-6 climbs the sandglass ruins: four desert enemy kinds, belts, blinking
## stones, falling stones, lifts, wind, guardian-revealed mirage ledges and
## arrow pads -- and every solid step climbable by a real runner.

const MainScene: PackedScene = preload("res://src/main.tscn")
const ClimbRoute = preload("res://test/climb_route.gd")
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
	check(not Stage.world_3d() and Stage.needs_key()
		and Stage.progress_direction() == Vector2.UP,
		"a painted 2D climb with a required key")
	var climb := Stage.start().y - Stage.goal().y
	check(climb > 7000.0 and climb < Stage.start().y,
		"a long climb that stays inside the online codec (%.0fpx)" % climb)
	var kinds := {}
	for spec in Stage.enemies():
		if String(spec.get("type", "")) == "desert_enemy":
			kinds[String(spec.get("kind", ""))] = true
	check(kinds.size() == 4 and kinds.has("scarab") and kinds.has("cactus")
		and kinds.has("jelly") and kinds.has("fin"), "all four desert enemy kinds are placed")
	var counts := {}
	for spec in Stage.gimmicks():
		counts[String(spec["type"])] = int(counts.get(String(spec["type"]), 0)) + 1
	check(counts.get("crumble", 0) >= 4 and counts.get("blink", 0) >= 4
		and counts.get("moving_platform", 0) >= 2 and counts.get("conveyor", 0) >= 3
		and counts.get("updraft", 0) >= 2 and counts.get("switch_bridge", 0) >= 2
		and counts.get("trick_pad", 0) == 2,
		"belts, blinks, falling stones, lifts, wind, mirages and arrow pads (%s)" % str(counts))
	check(Stage.checkpoints().size() >= 7, "checkpoints break up the climb")

	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var panel := main.get_node_or_null("NetPanel")
	check(panel != null and panel._cards().size() == 8,
		"selection includes the desert, tower and cave stages")
	if panel != null:
		await get_tree().process_frame
		check(panel._stage_1_6 != null, "desert card appears on the second page")
		panel.queue_free()
	for _i in 30:
		await get_tree().physics_frame
	check(main.runner.is_on_floor(), "runner starts on sandstone")
	var built := {}
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is DesertEnemy:
			built[node.kind] = true
	check(built.size() == 4, "all four enemy classes build in the live level")
	var mirage: SwitchBridge = null
	var mirage_switch: ShootableSwitch = null
	var pads := 0
	for node in main.level._dynamic.get_children():
		if node is SwitchBridge and mirage == null:
			mirage = node
		if node is TrickPad:
			pads += 1
	if mirage != null:
		for node in get_tree().get_nodes_in_group("switch"):
			if node is ShootableSwitch and node.switch_id == mirage.switch_id:
				mirage_switch = node
	check(mirage != null and mirage_switch != null and pads == 2,
		"mirage ledges and arrow pads build in the live level")
	if mirage != null and mirage_switch != null:
		check(mirage._shape.disabled, "a mirage starts as a ghost, without collision")
		mirage_switch.take_damage(1)
		for _i in 24:
			await get_tree().physics_frame
		check(not mirage._shape.disabled, "the guardian's shot makes it solid")

	var failed: Array[String] = await ClimbRoute.climb_all(get_tree(), main, 140.0)
	check(failed.is_empty(), "every solid step of the climb is jumpable (%d failed: %s)"
		% [failed.size(), ", ".join(failed.slice(0, 4))])
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
