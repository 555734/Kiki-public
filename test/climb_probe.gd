extends Node
## 1-7 and 1-8 climbed for real, room by room: every jump, second jump,
## guardian stair and gimmick ride on each stage's recorded route, with a real
## runner, real guardian platforms and the real moving pieces
## (test/climb_route.gd). Also the layout rules no single step can see: rooms
## stack upwards without sharing ground, stay inside the shaft, and no two
## rooms in a row are built the same way.
##
## CLIMB_STAGE=tower|cave limits it to one stage; CLIMB_ONLY=room,room to some
## rooms (for working on a layout).

const MainScene: PackedScene = preload("res://src/main.tscn")
const ClimbRoute = preload("res://test/climb_route.gd")

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var stages := {"tower": Stage.Which.TOWER, "cave": Stage.Which.CAVE}
	var only_stage := OS.get_environment("CLIMB_STAGE")
	for name in stages:
		if only_stage != "" and only_stage != name:
			continue
		await _stage(name, stages[name])
	Stage.use(Stage.Which.GREENFIELD)
	if failures.is_empty():
		print("climb probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("climb probe: " + failure)
		get_tree().quit(1)

func _stage(name: String, which: int) -> void:
	Stage.use(which)
	var label := Stage.stage_number()
	var data = Stage.data()
	var rooms: Array[Dictionary] = data.rooms()
	check(rooms.size() >= 20, "%s is built from at least twenty rooms (%d)" % [label, rooms.size()])
	var names := {}
	var rising := true
	for i in rooms.size():
		names[String(rooms[i]["name"])] = true
		if i > 0:
			rising = rising and float(rooms[i]["bottom"]) == float(rooms[i - 1]["top"])
	check(names.size() == rooms.size(), "%s: no room is used twice" % label)
	check(rising, "%s: each room starts where the last one ended" % label)
	var edge: float = data.EDGE
	var inside := true
	for r in Stage.ground():
		inside = inside and r.position.x >= -edge - 1.0 and r.end.x <= edge + 1.0
	check(inside, "%s: every ledge is inside the shaft (|x| <= %.0f)" % [label, edge])
	var overlaps: Array[String] = []
	var g: Array[Rect2] = Stage.ground()
	for i in g.size():
		for j in range(i + 1, g.size()):
			if g[i].intersects(g[j]):
				overlaps.append("%s/%s" % [str(g[i].position), str(g[j].position)])
	check(overlaps.is_empty(), "%s: no two pieces of ground overlap (%s)" % [label, ", ".join(overlaps.slice(0, 3))])
	var clashes := SectionBuilder.clashes_between(data.boxes(), rooms)
	check(clashes.is_empty(), "%s: no room is in another's way (%s)"
		% [label, ", ".join(clashes.slice(0, 3))])
	var climb := Stage.start().y - Stage.goal().y
	check(climb > 10000.0, "%s climbs more than 10,000px (%.0f)" % [label, climb])

	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
	for _i in 20:
		await get_tree().physics_frame
	var only: Array = []
	if OS.get_environment("CLIMB_ONLY") != "":
		only = Array(OS.get_environment("CLIMB_ONLY").split(","))
	var failed: Array[String] = await ClimbRoute.climb_all(get_tree(), main, 0.0, only)
	for f in failed:
		print("    failed step: ", f)
	check(failed.is_empty(), "%s: every step of the route works (%d of %d failed)"
		% [label, failed.size(), Stage.route().size()])
	main.queue_free()
	await get_tree().process_frame
