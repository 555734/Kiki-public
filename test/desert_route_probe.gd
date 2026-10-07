extends Node
const Main = preload("res://src/main.tscn")
const Route = preload("res://test/climb_route.gd")
var failures: Array[String] = []

func _ready() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("%s %s" % ["ok" if ok else "FAIL", message])
	if not ok: failures.append(message)

func run() -> void:
	Stage.use(Stage.Which.DESERT)
	var rooms: Array[Dictionary] = Stage.data().rooms()
	var names := {}
	var fingerprints := {}
	for room in rooms:
		names[room["name"]] = true
		var pattern: Array = []
		for step in Stage.route():
			if step["section"] != room["name"]: continue
			var a: Rect2 = step["from"]
			var b: Rect2 = step["to"]
			pattern.append([step["via"], step.get("how", ""), b.position - a.position, a.size, b.size])
		fingerprints[str(pattern)] = true
	check(rooms.size() == 20 and names.size() == 20, "twenty distinct authored sections")
	check(fingerprints.size() == 20, "no section repeats the same relative route recipe")
	check(Stage.goal().x > 15000 and Stage.goal().x < 30000, "extended route fits network coordinates")
	for checkpoint in Stage.checkpoints():
		var supported := false
		for slab in Stage.ground():
			if checkpoint.x > slab.position.x + 18 and checkpoint.x < slab.end.x - 18:
				if absf(checkpoint.y + 50 - slab.position.y) <= 2: supported = true
		check(supported, "checkpoint has permanent ground: %s" % checkpoint)
	var main := Main.instantiate()
	add_child(main)
	main.get_node("NetPanel").queue_free()
	await get_tree().process_frame
	var only: Array = []
	if OS.get_environment("DESERT_ONLY") != "": only = OS.get_environment("DESERT_ONLY").split(",")
	var missed := await Route.climb_all(get_tree(), main, 0, only)
	for failure in missed: check(false, failure)
	check(missed.is_empty(), "real Runner/Guardian route: %d steps, %d misses" % [Stage.route().size(), missed.size()])
	main.free()
	Stage.use(Stage.Which.GREENFIELD)
	print("desert route probe: ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
