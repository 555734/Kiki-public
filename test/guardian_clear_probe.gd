extends Node
## The two-button guardian and the stage clear.
##
## The guardian has one tool per thumb (platform left, shot right), draws a
## platform with a finger in the stroke's own shape, keeps at most two for six
## seconds each, and shoots without limit or cooldown. The runner has no sprint
## button. When the goal is reached nothing can hurt the runner any more.

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	# A level stroke becomes a level platform as long as the stroke.
	var made := InputHub.path_from_stroke(PackedVector2Array([
		Vector2(100, 200), Vector2(200, 200), Vector2(300, 200)]))
	check(made.size() == 2 and (made[1] as PackedVector2Array).size() == 2,
		"a straight stroke is one straight piece")
	if made.size() == 2:
		check(made[0].distance_to(Vector2(200, 200)) < 0.6, "centred on the stroke")
		check(is_equal_approx(Hologram.path_size(made[1]).x, 200.0),
			"a 200px stroke draws a 200px platform")

	# A diagonal stroke stays diagonal.
	var slope := InputHub.path_from_stroke(PackedVector2Array([
		Vector2(0, 0), Vector2(50, -50), Vector2(100, -100), Vector2(150, -150)]))
	check(not slope.is_empty(), "a diagonal stroke draws a platform")
	if not slope.is_empty():
		var sp: PackedVector2Array = slope[1]
		var dir := (sp[sp.size() - 1] - sp[0]).normalized()
		check(absf(dir.angle_to(Vector2(1, -1).normalized())) < 0.05,
			"and it keeps the stroke's slope")

	# An upright stroke draws an upright platform.
	var upright := InputHub.path_from_stroke(PackedVector2Array([
		Vector2(40, 0), Vector2(40, 60), Vector2(40, 120), Vector2(40, 180)]))
	check(not upright.is_empty(), "a vertical stroke draws a platform")
	if not upright.is_empty():
		var us := Hologram.path_size(upright[1])
		check(us.y > 170.0 and us.x < 40.0, "and it stands upright (%s)" % str(us))

	# A bent stroke keeps its corner.
	var bent := InputHub.path_from_stroke(PackedVector2Array([
		Vector2(0, 0), Vector2(50, 0), Vector2(100, 0), Vector2(100, -50), Vector2(100, -100)]))
	check(not bent.is_empty() and (bent[1] as PackedVector2Array).size() == 3,
		"an L-shaped stroke keeps its bend")

	check(InputHub.path_from_stroke(PackedVector2Array([Vector2(0, 0), Vector2(20, 0)])).is_empty(),
		"a short wiggle is a tap, not a platform")
	var long := InputHub.path_from_stroke(PackedVector2Array([Vector2(0, 0), Vector2(2000, 0)]))
	check(not long.is_empty() and Hologram.path_size(long[1]).x <= Balance.TRACE_MAX_LENGTH + 0.5,
		"a very long stroke is cut off")

	# The shape survives the wire.
	var shape := PackedVector2Array([Vector2(-60, 40), Vector2(0, -12), Vector2(60, -40)])
	var bytes := Protocol.place(1, Vector2(10, 20), 5, 7, shape)
	var parsed := Protocol.reader(bytes)
	var b: StreamPeerBuffer = parsed[1]
	b.get_u8(); Protocol.get_pos(b); b.get_u32(); b.get_u16()
	check(Protocol.get_shape(b) == shape, "a traced shape travels in the placement")
	var spawn: StreamPeerBuffer = Protocol.reader(
		Protocol.holo_spawn(3, 0, Vector2(10, 20), 1, 2, 9, shape))[1]
	spawn.get_u16(); spawn.get_u8(); Protocol.get_pos(spawn)
	spawn.get_u32(); spawn.get_u32(); spawn.get_u16()
	check(Protocol.get_shape(spawn) == shape, "and in the host's spawn")
	var listed: StreamPeerBuffer = Protocol.reader(Protocol.holo_list([{"net_id": 3, "kind": 0,
		"at": Vector2(10, 20), "birth": 1, "death": 2, "armed": true, "path": shape}]))[1]
	listed.get_u8(); listed.get_u16(); listed.get_u8(); Protocol.get_pos(listed)
	listed.get_u32(); listed.get_u32(); listed.get_u8()
	check(Protocol.get_shape(listed) == shape, "and in the resync list")

	# A drawn slab is built from one piece per segment plus a round joint.
	var pieces := Hologram.path_shapes(shape)
	check(pieces.size() == 3, "two segments and one joint")
	for piece in pieces:
		piece.free()
	var holo := Hologram.create(Hologram.Kind.PLATFORM, Vector2(0, 0), shape)
	check(is_equal_approx(holo.lifetime, 6.0), "a platform lasts six seconds")
	holo.free()

	# The runner has no sprint button in any layout.
	ControlLayout.forget()
	for mode in ["runner", "shared"]:
		check(not ControlLayout.layout(mode, Vector2(1280, 720), false).has("sprint"),
			"no sprint button on the %s screen" % mode)

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
	g.select_slot(3)
	var fired := 0
	for _i in 12:
		if g.abilities[3].check(g, r.global_position + Vector2(200, 0)) == "":
			g.use_active(r.global_position + Vector2(200, 0))
			fired += 1
	check(fired == 12, "twelve shots in one frame, no cooldown or reload (%d)" % fired)

	# Draw three platforms: two stay, the oldest goes, each in its drawn shape.
	g.select_slot(1)
	var shapes := [
		PackedVector2Array([Vector2(-60, 0), Vector2(60, 0)]),
		PackedVector2Array([Vector2(-60, 40), Vector2(60, -40)]),
		PackedVector2Array([Vector2(0, -80), Vector2(0, 80)]),
	]
	for i in 3:
		var at: Vector2 = r.global_position + Vector2(260.0 + 360.0 * i, -250.0)
		g.place_path = shapes[i]
		g.use_active(at)
		g.place_path = PackedVector2Array()
		await get_tree().process_frame
	var live: Array = g.holograms_of(Hologram.Kind.PLATFORM)
	check(live.size() == Balance.PLATFORM_MAX_ALIVE, "at most two platforms (%d)" % live.size())
	if live.size() == 2:
		check(live[0].path == shapes[1] and live[1].path == shapes[2],
			"the oldest was replaced and the drawn shapes kept")
		var solid := 0
		for c in live[1].get_children():
			if c is CollisionShape2D:
				solid += 1
		check(solid == 1, "an upright slab is solid along its length")
		# Six seconds, then gone.
		var first: Hologram = live[0]
		Clock.tick += Clock.ticks_for(Balance.PLATFORM_LIFETIME) + 1
		await get_tree().process_frame
		await get_tree().process_frame
		check(not is_instance_valid(first), "a platform is gone after six seconds")

	# Tracing a diagonal with a finger through the input hub places a
	# diagonal platform.
	var hub: InputHub = main.input_hub
	hub.solo_role = "guardian"
	g.clear_constructs()
	await get_tree().process_frame
	hub.trace_mode = true
	hub._touch_down(3, Vector2(500, 380))
	for k in [1, 2, 3, 4]:
		hub._touch_move(3, Vector2(500 + 50 * k, 380 - 40 * k))
	hub._touch_up(3, Vector2(750, 180))
	await get_tree().process_frame
	await get_tree().process_frame
	live = g.holograms_of(Hologram.Kind.PLATFORM)
	check(live.size() == 1, "a finger stroke builds a platform")
	if live.size() == 1:
		var p: PackedVector2Array = live[0].path
		var want := hub._screen_to_world(Vector2(750, 180)) - hub._screen_to_world(Vector2(500, 380))
		var got := p[p.size() - 1] - p[0]
		check(absf(got.angle_to(want)) < 0.08,
			"in the stroke's slope (%s vs %s)" % [str(got), str(want)])

	# On a shared screen the guardian can draw on the runner's third too, away
	# from the runner's own controls.
	hub.solo_role = ""
	hub.trace_mode = true
	var screen := hub._screen_size()
	var mirrored := not hub.runner_on_left
	var shared := ControlLayout.layout("shared", screen, mirrored)
	var left_x := screen.x * (0.88 if mirrored else 0.12)
	hub._touch_down(5, Vector2(left_x, screen.y * 0.18))
	check(String(hub._touch_owner.get(5, "")) == "aim",
		"the runner's third of a shared screen takes a drawing finger")
	hub._touch_up(5, Vector2(left_x, screen.y * 0.18))
	var stick_at: Vector2 = shared["stick"]["center"]
	var edge := stick_at + Vector2(0.0, -float(shared["stick"]["radius"]) \
		* ControlLayout.STICK_CAPTURE * 1.2)
	hub._touch_down(6, edge)
	check(String(hub._touch_owner.get(6, "")) != "aim",
		"but a near miss of the stick is still the runner's")
	hub._touch_up(6, edge)
	hub.solo_role = "guardian"

	# Platforms are drawn warm, not in the sky's blue.
	check(Balance.C_PLATFORM.r > Balance.C_PLATFORM.b + 0.4, "platforms are a warm colour")

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
