extends Node
## The two-button guardian and the stage clear.
##
## The guardian has one tool per thumb (platform left, shot right), draws a
## platform with a finger, keeps at most two, and shoots without limit. When the
## goal is reached nothing can hurt the runner any more.

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	# A stroke becomes a level platform as wide as the stroke.
	var made := InputHub.platform_from_stroke(PackedVector2Array([
		Vector2(100, 210), Vector2(180, 190), Vector2(300, 200)]))
	check(made.size() == 2 and is_equal_approx(float(made[1]), 200.0),
		"a 200px stroke draws a 200px platform")
	check(not made.is_empty() and absf(made[0].x - 200.0) < 0.1 and absf(made[0].y - 200.0) < 0.1,
		"centred on the stroke")
	check(InputHub.platform_from_stroke(PackedVector2Array([Vector2(0, 0), Vector2(20, 0)])).is_empty(),
		"a short wiggle is a tap, not a platform")
	var long := InputHub.platform_from_stroke(PackedVector2Array([Vector2(0, 0), Vector2(2000, 0)]))
	check(float(long[1]) == Balance.TRACE_MAX_WIDTH, "a very long stroke is capped")

	# The width survives the wire.
	var bytes := Protocol.place(1, Vector2(10, 20), 5, 7, 233.0)
	var parsed := Protocol.reader(bytes)
	var b: StreamPeerBuffer = parsed[1]
	b.get_u8(); Protocol.get_pos(b); b.get_u32(); b.get_u16()
	check(b.get_u16() == 233, "a traced width travels in the placement")

	# Two buttons, one on each side.
	ControlLayout.forget()
	var view := Vector2(1280, 720)
	var places := ControlLayout.layout("guardian", view, false)
	check(places.has("slot_1") and places.has("slot_3"), "the guardian has platform and shot")
	for id in ["slot_2", "slot_4", "scope", "undo", "ping"]:
		check(not places.has(id), "and no %s button" % id)
	if places.has("slot_1") and places.has("slot_3"):
		check(places["slot_1"]["center"].x < view.x * 0.5, "platform is on the left")
		check(places["slot_3"]["center"].x > view.x * 0.5, "shot is on the right")

	Stage.use(Stage.Which.GREENFIELD)
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	main.get_node("NetPanel").queue_free()
	for _i in 5:
		await get_tree().process_frame
	var g: Guardian = main.guardian
	var r: Runner = main.runner

	# No points: the shot never runs out.
	g.gauge = 0.0
	check(g.abilities[3].check(g, r.global_position + Vector2(200, 0)) != "gauge",
		"shooting needs no gauge")
	check(SniperAbility.ammo_for(0.0) > 0, "and the scope never shows empty")

	# Draw three platforms: two stay, the oldest goes, each as wide as drawn.
	g.select_slot(1)
	var widths := [120.0, 200.0, 260.0]
	for i in 3:
		var at: Vector2 = r.global_position + Vector2(260.0 + 360.0 * i, -150.0)
		g.place_width = widths[i]
		g.use_active(at)
		g.place_width = 0.0
		await get_tree().process_frame
	var live: Array = g.holograms_of(Hologram.Kind.PLATFORM)
	check(live.size() == Balance.PLATFORM_MAX_ALIVE, "at most two platforms (%d)" % live.size())
	if live.size() == 2:
		check(is_equal_approx(live[0].size.x, 200.0) and is_equal_approx(live[1].size.x, 260.0),
			"the oldest was replaced and the drawn widths kept")

	# Tracing with a finger through the input hub places a platform.
	var hub: InputHub = main.input_hub
	hub.solo_role = "guardian"
	g.clear_constructs()
	await get_tree().process_frame
	hub.trace_mode = true
	var y := 300.0
	hub._touch_down(3, Vector2(500, y))
	for x in [560, 620, 680, 740]:
		hub._touch_move(3, Vector2(x, y))
	hub._touch_up(3, Vector2(760, y))
	await get_tree().process_frame
	await get_tree().process_frame
	live = g.holograms_of(Hologram.Kind.PLATFORM)
	check(live.size() == 1, "a finger stroke builds a platform")
	if live.size() == 1:
		var expect := hub._screen_to_world(Vector2(760, y)).x - hub._screen_to_world(Vector2(500, y)).x
		expect = clampf(expect, Balance.TRACE_MIN_WIDTH, Balance.TRACE_MAX_WIDTH)
		check(absf(live[0].size.x - expect) < 2.0,
			"as wide as the stroke (%.0f)" % live[0].size.x)

	# The clear: no more harm, and the enemies stop.
	Events.stage_cleared.emit({})
	await get_tree().process_frame
	var hp := r.hp
	r.take_damage(1)
	check(r.hp == hp, "after the clear the runner cannot be hurt")
	r.die("hazard")
	check(r.state != Runner.State.DEAD, "or killed")
	var frozen := true
	for e in get_tree().get_nodes_in_group("enemy"):
		frozen = frozen and (e as Node).process_mode == Node.PROCESS_MODE_DISABLED
	check(frozen, "every enemy stops at the clear")
	check(r.visual._pose_key() == "runner_cheer" or not r.on_ground(), "the runner celebrates")

	main.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("guardian clear probe: all checks passed")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("guardian clear probe: " + f)
		get_tree().quit(1)
