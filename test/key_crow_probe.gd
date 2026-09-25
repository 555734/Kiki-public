extends Node
## The key that opens the goal, and the crows over the side-scrolling stages.
##
## Every side-scrolling menu stage puts its key on reachable ground (a floor
## with no hazard on it, between start and goal) and a fixed row of crows high
## over the course; the rising stage has neither. The goal will not clear
## without the key, and clears once it is picked up.

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var sides := {
		"1-1": Stage.Which.GREENFIELD, "1-2": Stage.Which.HORROR,
		"1-4": Stage.Which.SEA, "1-5": Stage.Which.SWAMP,
	}
	for label in sides:
		Stage.use(sides[label])
		check(Stage.needs_key(), "%s needs a key" % label)
		var k := Stage.key_position()
		check(k.x > Stage.start().x and k.x < Stage.goal().x,
			"%s key lies between start and goal (%s)" % [label, str(k)])
		var on_floor := false
		for rect in Stage.ground():
			if k.x >= rect.position.x and k.x <= rect.end.x \
					and absf(k.y - (rect.position.y - 4.0)) < 0.5:
				on_floor = true
		check(on_floor, "%s key rests on a floor" % label)
		var crows := Stage.sky_crows()
		check(crows.size() >= 3, "%s has crows over it (%d)" % [label, crows.size()])
		var high := true
		for c in crows:
			for rect in Stage.ground():
				if rect.end.x > c.x - 350.0 and rect.position.x < c.x + 350.0:
					high = high and c.y <= rect.position.y - 300.0
		check(high, "%s crows fly well above the ground" % label)
		Difficulty.set_level(0, false)
		var easy := Stage.sky_crows().size()
		Difficulty.set_level(2, false)
		check(Stage.sky_crows().size() == easy,
			"%s crow count does not change with difficulty" % label)
	Stage.use(Stage.Which.SKYWARD_RUINS)
	check(not Stage.needs_key(), "1-3 has no key")
	check(Stage.sky_crows().is_empty(), "1-3 has no crows")

	# In a built stage: the goal stays shut until the key is picked up.
	Stage.use(Stage.Which.GREENFIELD)
	GameState.reset_run(Stage.start())
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	main.get_node("NetPanel").queue_free()
	for _i in 5:
		await get_tree().process_frame
	var r: Runner = main.runner
	var keys := find_children_of(main, "StageKey")
	check(keys.size() == 1, "the stage builds one key")
	var crow_nodes := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is SkyCrow:
			crow_nodes += 1
	check(crow_nodes == Stage.sky_crows().size(), "and its crows (%d)" % crow_nodes)
	var ids := {}
	var unique := true
	for e in get_tree().get_nodes_in_group("enemy"):
		unique = unique and not ids.has(e.net_id)
		ids[e.net_id] = true
	check(unique, "every enemy keeps its own net id")

	var cleared := [false]
	Events.stage_cleared.connect(func(_s): cleared[0] = true)
	r.global_position = Stage.goal()
	for _i in 6:
		await get_tree().physics_frame
	check(not cleared[0] and GameState.running, "the goal is locked without the key")
	r.global_position = Stage.key_position() + Vector2(0, -10)
	for _i in 4:
		await get_tree().process_frame
	check(GameState.has_key, "walking onto the key picks it up")
	r.global_position = Stage.goal()
	for _i in 6:
		await get_tree().physics_frame
		await get_tree().process_frame
	check(cleared[0], "with the key, the goal clears")

	main.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("key crow probe: all checks passed")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("key crow probe: " + f)
		get_tree().quit(1)

func find_children_of(root: Node, cls: String) -> Array:
	var out: Array = []
	for n in root.find_children("*", "", true, false):
		if n.get_script() != null and n.get_script().get_global_name() == cls:
			out.append(n)
	return out
