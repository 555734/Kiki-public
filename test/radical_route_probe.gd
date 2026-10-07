extends Node
const Route = preload("res://test/climb_route.gd")
var failures: Array[String] = []
func _ready() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("%s %s" % ["ok" if ok else "FAIL", message])
	if not ok: failures.append(message)
func run() -> void:
	for which in [Stage.Which.SEA, Stage.Which.SWAMP]:
		Stage.use(which)
		if OS.get_environment("RADICAL_STAGE") != "" and Stage.stage_number() != OS.get_environment("RADICAL_STAGE"): continue
		var number := Stage.stage_number()
		var rooms: Array[Dictionary] = Stage.data().rooms()
		var names := {}; var fingerprints := {}
		for room in rooms:
			names[room["name"]] = true
			var recipe: Array = []
			for step in Stage.route():
				if step["section"] != room["name"]: continue
				var a: Rect2 = step["from"]; var b: Rect2 = step["to"]
				recipe.append([step["via"], step.get("how", ""), b.position - a.position, a.size, b.size])
			fingerprints[str(recipe)] = true
		check(rooms.size() == 20 and names.size() == 20 and fingerprints.size() == 20, number + " twenty unique room recipes")
		check(Stage.goal().x - Stage.start().x > 10000 and Stage.goal().x < 30000, number + " complete route fits network")
		for cp in Stage.checkpoints():
			var safe := false
			for r in Stage.ground():
				if cp.x > r.position.x + 18 and cp.x < r.end.x - 18 and absf(cp.y + 52 - r.position.y) < 0.1: safe = true
			check(safe, number + " permanent checkpoint " + str(cp))
		var main := preload("res://src/main.tscn").instantiate()
		add_child(main); main.get_node("NetPanel").queue_free()
		await get_tree().process_frame
		var only: Array = []
		if OS.get_environment("RADICAL_ONLY") != "": only = OS.get_environment("RADICAL_ONLY").split(",")
		var missed := await Route.climb_all(get_tree(), main, 0, only)
		for failure in missed: check(false, failure)
		check(missed.is_empty(), "%s actual Runner/Guardian: %d steps, %d misses" % [number, Stage.route().size(), missed.size()])
		main.free(); await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	print("radical route probe: ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
