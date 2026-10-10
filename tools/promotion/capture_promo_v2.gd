extends "res://tools/promotion/capture_promo.gd"
## V2: continuous native actions, visible aiming, and complete rescue payoffs.
const OUT_V2 := "res://build/promotion/v2/"
var taking := false
var aiming := false
var frame_metrics: Array[Dictionary] = []

func _ready() -> void:
	process_priority = 250
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_V2))
	call_deferred("run")

func _process(delta: float) -> void:
	if is_instance_valid(main):
		if follow:
			focus = focus.lerp(main.runner.global_position + Vector2(80, -45), minf(1.0, delta * 10.0))
		main.camera.global_position = focus
		main.camera.zoom = Vector2.ONE * zoom
		if taking:
			var screen: Vector2 = (main.runner.global_position - focus) * zoom + Vector2(640, 360)
			frame_metrics.append({"frame": Engine.get_process_frames(), "take": segments[-1]["name"], "runner_screen": [screen.x, screen.y], "zoom": zoom})
	queue_redraw()

func _draw() -> void:
	if stroke.size() > 1:
		draw_polyline(stroke, Color(0.1, 0.9, 1, 0.35), 20, true)
		draw_polyline(stroke, Color(0.85, 1, 1), 5, true)
	if pointer.x != INF:
		if aiming:
			draw_circle(pointer, 31, Color(0.1, 0.8, 1, 0.13))
			draw_arc(pointer, 27, 0, TAU, 48, Color("b1f7ff"), 3, true)
			for axis in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
				draw_line(pointer + axis * 19, pointer + axis * 36, Color.WHITE, 3, true)
		else:
			draw_circle(pointer, 12, Color("b1f7ff"))
			draw_arc(pointer, 19, 0, TAU, 32, Color.WHITE, 3, true)

func start_take(label: String) -> void:
	super.start_take(label)
	taking = true

func finish_take() -> void:
	taking = false
	super.finish_take()

func mark(label: String, detail := {}) -> void:
	marks.append({"event": label, "frame": Engine.get_process_frames(), "take": segments[-1]["name"] if taking else "setup", "detail": detail})

func shoot(at: Vector2) -> void:
	main.guardian.select_slot(3)
	main.input_hub.aim_at_world(at)
	pointer = at
	aiming = true
	mark("aim", {"at": [at.x, at.y]})
	await seconds(0.2)
	var actual_target: Node = main.guardian.abilities[3].target_at(main.guardian, at)
	main.guardian.use_active(at)
	mark("shot", {"at": [at.x, at.y], "target": actual_target.get_script().resource_path if actual_target != null else "none"})
	await seconds(0.12)
	aiming = false
	pointer = Vector2(INF, INF)

func save_metadata() -> void:
	var file := FileAccess.open(OUT_V2 + "takes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": FPS, "segments": segments, "events": marks, "frame_metrics": frame_metrics}, "\t"))

func run() -> void:
	await opening()
	await chase()
	await expiry()
	await switch_take()
	await launch_hazard(Stage.Which.SWAMP, "eruption", "geyser")
	await launch_hazard(Stage.Which.SEA, "anchor", "meteor")
	await cart_take()
	await gear_take()
	await finale()
	save_metadata()
	main.queue_free()
	await frames(2)
	print("promo v2: capture finished")
	get_tree().quit()

func opening() -> void:
	await new_stage(Stage.Which.CAVE)
	var chosen: CrumblingFloor = null
	var room: Dictionary
	for r in Stage.data().rooms():
		if r["name"] == "crumble_shaft": room = r
	for node in main.level.find_children("*", "", true, false):
		if node is CrumblingFloor and node.global_position.y < float(room["bottom"]) and node.global_position.y > float(room["top"]):
			if chosen == null or node.global_position.y > chosen.global_position.y: chosen = node
	assert(chosen != null)
	var top: Vector2 = chosen.global_position - Vector2(0, chosen.span.y * 0.5)
	position_runner(top - Vector2(0, 34))
	zoom = 1.6
	focus = top + Vector2(65, 100)
	await seconds(0.18)
	start_take("opening")
	for _i in 70:
		if chosen._gone: break
		await frames(1)
	mark("collapse")
	var deck := top + Vector2(0, 225)
	var slab := await draw_platform(deck + Vector2(-90, 0), deck + Vector2(90, 0), 0.3)
	assert(slab != null)
	for _i in 80:
		await frames(1)
		if slab.trigger.loaded(): break
	mark("rescue", {"grounded": main.runner.on_ground(), "loaded": slab.trigger.loaded()})
	assert(slab.trigger.loaded())
	await seconds(0.18)
	main.runner.facing = 1
	await shoot(slab.trigger.global_position)
	mark("launch", {"airborne": not main.runner.on_ground()})
	follow = true
	await seconds(1.1)
	finish_take()

func chase() -> void:
	await new_stage(Stage.Which.SEA)
	position_runner(Vector2(-850, 355))
	await seconds(0.15)
	var pursuer: Node2D
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get_script() == preload("res://src/entities/enemies/sky_pursuer.gd"): pursuer = e
		else: e.queue_free()
	pursuer.global_position = main.runner.global_position + Vector2(-240, -25)
	pursuer._wake_left = 0.0
	pursuer._activated = true
	focus = main.runner.global_position + Vector2(-90, -60)
	zoom = 2.0
	await frames(2)
	start_take("chase")
	pursuer.set_physics_process(true)
	drive(0.65)
	for _i in 130:
		focus = main.runner.global_position + Vector2(-90, -60)
		if main.runner.global_position.distance_to(pursuer.global_position) < 145: break
		await frames(1)
	mark("pursuer_close")
	await shoot(pursuer.global_position)
	mark("pursuer_stopped", {"stunned": pursuer.stunned()})
	for _i in 62:
		focus = main.runner.global_position + Vector2(-80, -60)
		await frames(1)
	drive(0)
	finish_take()

func switch_take() -> void:
	await new_stage(Stage.Which.SEA)
	position_runner(Vector2(2840, 246))
	focus = Vector2(3030, 145)
	zoom = 1.9
	var target: ShootableSwitch
	for node in get_tree().get_nodes_in_group("switch"):
		if node.switch_id == "coast_tide" and node.global_position.x < 3000: target = node
	assert(target != null)
	await seconds(0.25)
	start_take("bridge")
	await shoot(target.global_position)
	mark("bridge_opened", {"active": target.active})
	drive(1, true)
	await seconds(0.28)
	drive(1, false)
	for _i in 100:
		await frames(1)
		if main.runner.global_position.x > 3080 and main.runner.on_ground(): break
	drive(1, true)
	await seconds(0.22)
	drive(1, false)
	for _i in 100:
		await frames(1)
		if main.runner.global_position.x > 3200 and main.runner.on_ground(): break
	mark("bridge_crossed", {"x": main.runner.global_position.x, "alive": main.runner.state != Runner.State.DEAD})
	await seconds(0.35)
	drive(0)
	finish_take()

func launch_hazard(which: int, label: String, kind: String) -> void:
	await new_stage(which)
	for enemy in get_tree().get_nodes_in_group("enemy"): enemy.queue_free()
	await frames(2)
	var hazard: VolcanicHazard
	for node in main.level.find_children("*", "", true, false):
		if node is VolcanicHazard and node.kind == kind:
			hazard = node
			break
	assert(hazard != null)
	var target: Vector2 = hazard.global_position + hazard.travel if kind == "meteor" else hazard.global_position
	Clock.tick = roundi((0.9 - hazard.phase_offset + hazard.period) * 60)
	var deck := target + Vector2(-180, -85)
	position_runner(deck - Vector2(0, 58))
	var build: BuildAbility = main.guardian.abilities[1]
	for _i in 10:
		if build.check(main.guardian, deck) == "": break
		deck.y -= 35
	position_runner(deck - Vector2(0, 58))
	var slab := place(deck)
	assert(slab != null)
	focus = deck + Vector2(300, -140)
	zoom = 1.2
	await seconds(0.3)
	assert(slab.trigger.loaded())
	start_take(label)
	main.runner.facing = 1
	await shoot(slab.trigger.global_position)
	mark("hazard_launch", {"airborne": not main.runner.on_ground()})
	var catch_at := deck + Vector2(520, -25)
	await seconds(0.15)
	var catch_slab := await draw_platform(catch_at - Vector2(75, 0), catch_at + Vector2(75, 0), 0.28)
	assert(catch_slab != null)
	var active_seen := false
	var passed := false
	for _i in 110:
		await frames(1)
		active_seen = active_seen or hazard.state_at(Clock.tick)["active"]
		passed = passed or main.runner.global_position.x > target.x + 65
		if main.runner.on_ground(): break
	mark("hazard_passed", {"active_seen": active_seen, "passed": passed, "grounded": main.runner.on_ground(), "loaded": catch_slab.trigger.loaded(), "alive": main.runner.state != Runner.State.DEAD})
	await seconds(0.4)
	finish_take()

func cart_take() -> void:
	await new_stage(Stage.Which.CAVE)
	var cart: MovingPlatform
	for node in main.level.find_children("*", "", true, false):
		if node is MovingPlatform and node.visual_style == "minecart" and node.travel.x > 0:
			cart = node
			break
	Clock.tick = 55
	await frames(2)
	position_runner(cart.global_position + Vector2(0, -cart.span.y * 0.5 - 34))
	focus = cart.global_position + Vector2(130, -105)
	zoom = 1.8
	await seconds(0.2)
	start_take("cart")
	await seconds(0.28)
	var deck := cart.global_position + Vector2(200, -65)
	var catch_slab := await draw_platform(deck - Vector2(85, 0), deck + Vector2(85, 0), 0.28)
	drive(0.7, true)
	await seconds(0.25)
	drive(0.7, false)
	for _i in 70:
		await frames(1)
		if main.runner.on_ground(): break
	mark("cart_rescue", {"grounded": main.runner.on_ground(), "loaded": catch_slab != null and catch_slab.trigger.loaded(), "alive": main.runner.state != Runner.State.DEAD})
	drive(0)
	await seconds(0.4)
	finish_take()

func gear_take() -> void:
	await new_stage(Stage.Which.TOWER)
	var wheel: GearWheel
	for node in main.level.find_children("*", "", true, false):
		if node is GearWheel:
			wheel = node
			break
	Clock.tick = 0
	position_runner(wheel.global_position + Vector2(0, -wheel.radius - 45))
	focus = wheel.global_position + Vector2(70, -155)
	zoom = 1.5
	await seconds(0.2)
	start_take("gear")
	await seconds(0.25)
	drive(1, true)
	await seconds(0.25)
	var deck := wheel.global_position + Vector2(225, -wheel.radius - 70)
	var catch_slab := await draw_platform(deck - Vector2(85, 0), deck + Vector2(85, 0), 0.28)
	drive(1, false)
	for _i in 70:
		await frames(1)
		if main.runner.on_ground(): break
	mark("gear_rescue", {"grounded": main.runner.on_ground(), "loaded": catch_slab != null and catch_slab.trigger.loaded(), "alive": main.runner.state != Runner.State.DEAD})
	drive(0)
	await seconds(0.4)
	finish_take()

func finale() -> void:
	await new_stage(Stage.Which.SEA)
	GameState.has_key = true
	var deck := Vector2(8760, 950)
	position_runner(deck - Vector2(0, 55))
	var slab := place(deck)
	assert(slab != null)
	focus = Vector2(9075, 715)
	zoom = 1.2
	await seconds(0.3)
	assert(slab.trigger.loaded())
	start_take("finale")
	main.runner.facing = 1
	await shoot(slab.trigger.global_position)
	await seconds(0.22)
	var catch_at := Vector2(9220, 760)
	await draw_platform(catch_at - Vector2(80, 0), catch_at + Vector2(80, 0), 0.28)
	for _i in 140:
		await frames(1)
		if main.runner.on_ground(): break
	mark("final_landing", {"alive": main.runner.state != Runner.State.DEAD, "grounded": main.runner.on_ground()})
	drive(1)
	for _i in 170:
		await frames(1)
		if main.runner.cleared: break
	drive(0)
	mark("goal", {"cleared": main.runner.cleared})
	await seconds(0.35)
	finish_take()
	start_take("title")
	await seconds(1.8)
	finish_take()
