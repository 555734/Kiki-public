extends Node2D
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("platform clip: " + message)
func _ready() -> void:
	Clock.is_host = true
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = 1
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(40, 120)
	collision.shape = box
	obstacle.position = Vector2(180, 0)
	obstacle.add_child(collision)
	add_child(obstacle)
	var g := Guardian.new()
	add_child(g)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ability := g.abilities[1] as BuildAbility
	var path := PackedVector2Array([Vector2.ZERO, Vector2(260, 0)])
	var clipped := ability.clip_trace(g, Vector2.ZERO, path)
	check(not clipped.is_empty(), "a collision keeps the clear prefix")
	if not clipped.is_empty():
		var end: Vector2 = clipped[0] + clipped[1][-1]
		check(end.x > 150 and end.x <= 162, "endpoint stops at the obstacle")
		g.place_path = path
		g.use_active(Vector2.ZERO)
		var live := g.holograms_of(Hologram.Kind.PLATFORM)
		check(live.size() == 1, "release creates the prefix rather than losing the whole stroke")
		if not live.is_empty():
			var holo: Hologram = live[0]
			check(holo.path.size() == 2, "created platform has the clipped path")
			check((holo.global_position + holo.path[-1]).distance_to(end) < 2, "preview and commit agree")
		g.clear_constructs()
		await get_tree().physics_frame
		await get_tree().physics_frame
	var longer := ability.clip_trace(g, Vector2.ZERO, PackedVector2Array([Vector2.ZERO, Vector2(350, 0)]))
	check(not longer.is_empty() and (longer[0] + longer[1][-1]).x <= 162, "dragging deeper into terrain keeps the prefix")
	var reverse := ability.clip_trace(g, Vector2.ZERO, PackedVector2Array([Vector2(300, 0), Vector2(100, 0)]))
	check(not reverse.is_empty() and (reverse[0] + reverse[1][-1]).x >= 198, "right-to-left strokes clip correctly")
	var blocked := ability.clip_trace(g, Vector2.ZERO, PackedVector2Array([Vector2(180, 0), Vector2(260, 0)]))
	check(blocked.is_empty(), "a stroke starting inside a blocker never creates overlapping ground")
	var short := ability.clip_trace(g, Vector2.ZERO, PackedVector2Array([Vector2(150, 0), Vector2(250, 0)]))
	check(not short.is_empty(), "a clear prefix shorter than the normal stroke threshold survives")
	var bend := ability.clip_trace(g, Vector2.ZERO, PackedVector2Array([Vector2(0, -100), Vector2(90, -100), Vector2(240, 0)]))
	check(not bend.is_empty() and bend[1].size() == 3, "a bent stroke preserves its earlier corner")
	if not bend.is_empty():
		g.place_path = bend[1]
		check(ability.check(g, bend[0]) == "", "clipped bent shape passes authoritative validation")
	var clear := PackedVector2Array([Vector2(0, -180), Vector2(260, -180)])
	var untouched := ability.clip_trace(g, Vector2.ZERO, clear)
	check(not untouched.is_empty() and (untouched[0] + untouched[1][-1]) == clear[-1], "clear strokes retain their endpoint")
	g.input_hub = InputHub.new()
	add_child(g.input_hub)
	g.input_hub.trace_points = path
	g.place_path = PackedVector2Array()
	var preview := g.current_preview()
	check(not preview.is_empty() and preview.get("valid", false), "live preview remains valid when the finger reaches an obstacle")
	check(g.place_path.is_empty(), "preview does not leak placement state")
	print("platform clip probe: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
