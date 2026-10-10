extends "res://tools/promotion/capture_promo_v2.gd"
## Reference-shaped V3. Only the director is scripted; native abilities do the work.
const OUT_V3 := "res://build/promotion/v3/"
var controls: Control
var controls_hud: Hud
var shake := 0.0
var intro_death_frame := -1
var crumble: CrumblingFloor
var top := Vector2.ZERO
var pursuer: Node2D
var hold_crumble := false

func _ready() -> void:
	process_priority = 250
	if OS.get_environment("PROMO_LANG") == "en": TranslationServer.set_locale("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_V3))
	call_deferred("run")

func _process(delta: float) -> void:
	super._process(delta)
	if hold_crumble and is_instance_valid(crumble): crumble.set_process(false)
	if is_instance_valid(main) and shake > 0.0:
		main.camera.offset = Vector2(sin(Engine.get_process_frames() * 1.7), cos(Engine.get_process_frames() * 2.1)) * shake
		shake = maxf(0.0, shake - delta * 22.0)
	elif is_instance_valid(main):
		main.camera.offset = Vector2.ZERO

func new_stage(which: int) -> void:
	await super.new_stage(which)
	controls = null
	controls_hud = null
	shake = 0.0
	hold_crumble = false

func add_controls() -> void:
	main.input_hub.solo_role = "guardian"
	controls_hud = Hud.new()
	controls_hud.guardian = main.guardian
	controls_hud.input_hub = main.input_hub
	main.add_child(controls_hud)
	controls_hud._root.hide()
	controls_hud._overlay.hide()
	var layer := CanvasLayer.new()
	layer.layer = 7
	main.add_child(layer)
	controls = Control.new()
	controls.set_script(preload("res://tools/promotion/promo_controls.gd"))
	controls.hud = controls_hud
	layer.add_child(controls)
	controls.set_anchors_preset(Control.PRESET_TOP_LEFT)
	controls.size = Vector2(1280, 720)
	mark("role_controls", {"native_painter": true})

func save_metadata() -> void:
	var name := "lesson-takes.json" if OS.get_environment("PROMO_MODE") == "lesson-only" else "takes.json"
	if OS.get_environment("PROMO_LANG") == "en": name = name.replace(".json", "-en.json")
	var file := FileAccess.open(OUT_V3 + name, FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": FPS, "segments": segments, "events": marks, "frame_metrics": frame_metrics}, "\t"))

func until_take(t: float) -> void:
	var left := roundi(t * FPS) - (Engine.get_process_frames() - take_start)
	if left > 0: await frames(left)

func choose_crumble() -> void:
	var room: Dictionary
	for r in Stage.data().rooms():
		if r["name"] == "crumble_shaft": room = r
	crumble = null
	for node in main.level.find_children("*", "", true, false):
		if node is CrumblingFloor and node.global_position.y < float(room["bottom"]) and node.global_position.y > float(room["top"]):
			if crumble == null or node.global_position.y > crumble.global_position.y: crumble = node
	assert(crumble != null)
	top = crumble.global_position - Vector2(0, crumble.span.y * 0.5)
	print("CRUMBLE ", top)

func find_pursuer() -> void:
	pursuer = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get_script() == preload("res://src/entities/enemies/sky_pursuer.gd"): pursuer = e
	assert(pursuer != null)

func intro() -> void:
	await new_stage(Stage.Which.CAVE)
	choose_crumble()
	find_pursuer()
	position_runner(top - Vector2(0, 35))
	hold_crumble = true
	crumble.set_process(false)
	zoom = 2.15
	focus = top + Vector2(75, -58)
	pursuer.global_position = top + Vector2(-45, 115)
	pursuer._wake_left = 0.25
	pursuer._activated = true
	pursuer.runner = main.runner
	await frames(2)
	crumble.set_process(false)
	start_take("intro")
	pursuer.set_physics_process(true)
	drive(0.2)
	for i in 120:
		crumble.set_process(false)
		if i == 25: drive(0)
		await frames(1)
		if main.runner.state == Runner.State.DEAD:
			intro_death_frame = Engine.get_process_frames()
			mark("opening_death", {"dead": true, "elapsed": float(intro_death_frame - take_start) / FPS})
			break
	assert(intro_death_frame > 0, "Opening must show a native pursuer death within two seconds")
	drive(0)
	await seconds(0.1)
	main.runner.hide()
	await until_take(2.2)
	shake = 13.0
	mark("pullback")
	var near := focus
	for i in 72:
		var t := smoothstep(0.0, 1.0, float(i + 1) / 72.0)
		zoom = lerpf(2.15, 0.62, t)
		focus = near.lerp(top + Vector2(160, -410), t)
		await frames(1)
	await until_take(5.0)
	finish_take()

func failure() -> void:
	await new_stage(Stage.Which.CAVE)
	choose_crumble()
	position_runner(top - Vector2(0, 34))
	zoom = 1.35
	focus = top + Vector2(80, 90)
	await frames(2)
	start_take("failure")
	for _i in 70:
		await frames(1)
		if crumble._gone: break
	mark("unassisted_collapse")
	await seconds(0.4)
	mark("unassisted_fall", {"distance": main.runner.global_position.y - top.y})
	follow = true
	await until_take(3.0)
	finish_take()

func lesson() -> void:
	await new_stage(Stage.Which.CAVE)
	choose_crumble()
	find_pursuer()
	position_runner(top - Vector2(0, 34))
	hold_crumble = true
	zoom = 1.35
	focus = top + Vector2(80, 90)
	await frames(2)
	main.runner.set_physics_process(false)
	crumble.set_process(false)
	start_take("role")
	add_controls()
	main.guardian.select_slot(1)
	pointer = top + Vector2(115, 80)
	for i in 120:
		pointer = (top + Vector2(115, 80)).lerp(top + Vector2(-90, 225), smoothstep(0.0, 1.0, float(i) / 119.0))
		await frames(1)
	await seconds(0.65)
	var deck := top + Vector2(0, 225)
	var slab := await draw_platform(deck - Vector2(95, 0), deck + Vector2(95, 0), 0.65)
	assert(slab != null)
	await until_take(4.0)
	finish_take()
	start_take("success")
	hold_crumble = false
	main.runner.set_physics_process(true)
	crumble.set_process(true)
	for _i in 100:
		await frames(1)
		if slab.trigger.loaded(): break
	mark("assisted_landing", {"loaded": slab.trigger.loaded(), "grounded": main.runner.on_ground(), "at": [main.runner.global_position.x, main.runner.global_position.y], "floor_armed": crumble._armed, "floor_gone": crumble._gone})
	assert(slab.trigger.loaded(), "Before/after rescue must land")
	await until_take(4.0)
	finish_take()
	start_take("launch")
	main.runner.facing = 1
	await shoot(slab.trigger.global_position)
	mark("lesson_launch", {"airborne": not main.runner.on_ground()})
	var catch_at := deck + Vector2(650, -25)
	await seconds(0.12)
	var catch_slab := await draw_platform(catch_at - Vector2(210, 0), catch_at + Vector2(210, 0), 0.3)
	assert(catch_slab != null)
	for i in 110:
		var t := minf(1.0, float(i) / 40.0)
		focus = (top + Vector2(80, 90)).lerp(deck + Vector2(310, -135), t)
		zoom = lerpf(1.35, 1.15, t)
		await frames(1)
		if catch_slab.trigger.loaded(): break
	mark("lesson_catch", {"loaded": catch_slab.trigger.loaded(), "alive": main.runner.state != Runner.State.DEAD})
	assert(catch_slab.trigger.loaded(), "Launch must end on the drawn receiving slab")
	focus = deck + Vector2(360, -110)
	zoom = 1.15
	await brake()
	await until_take(4.0)
	finish_take()
	start_take("timing")
	var standing: Vector2 = main.runner.global_position
	pursuer.global_position = standing + Vector2(-170, 165)
	pursuer._wake_left = 0.0
	pursuer._activated = true
	pursuer.set_physics_process(true)
	await seconds(0.24)
	await shoot(pursuer.global_position)
	mark("pursuer_stopped", {"stunned": pursuer.stunned()})
	assert(pursuer.stunned())
	await seconds(0.5)
	pursuer.set_physics_process(false)
	await until_take(2.55)
	var next_deck := Vector2(standing.x, catch_at.y + 110)
	var next_slab := await draw_platform(next_deck - Vector2(95, 0), next_deck + Vector2(95, 0), 0.35)
	assert(next_slab != null)
	for _i in 100:
		await frames(1)
		if next_slab.trigger.loaded(): break
	mark("expiry_rescue", {"loaded": next_slab.trigger.loaded(), "old_expired": not is_instance_valid(catch_slab), "alive": main.runner.state != Runner.State.DEAD})
	assert(next_slab.trigger.loaded())
	await until_take(4.0)
	finish_take()

func brake() -> void:
	for _i in 32:
		if absf(main.runner.velocity.x) < 12.0: break
		drive(-signf(main.runner.velocity.x))
		await frames(1)
	drive(0)
	await frames(3)

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
	focus = deck + Vector2(320, -140)
	zoom = 1.15
	await seconds(0.3)
	assert(slab.trigger.loaded())
	start_take(label)
	main.runner.facing = 1
	await shoot(slab.trigger.global_position)
	mark("hazard_launch", {"airborne": not main.runner.on_ground()})
	var catch_at := deck + Vector2(650, -25)
	await seconds(0.15)
	var catch_slab := await draw_platform(catch_at - Vector2(210, 0), catch_at + Vector2(210, 0), 0.28)
	assert(catch_slab != null)
	var active_seen := false
	var passed := false
	for _i in 110:
		await frames(1)
		active_seen = active_seen or hazard.state_at(Clock.tick)["active"]
		passed = passed or main.runner.global_position.x > target.x + 65
		if catch_slab.trigger.loaded(): break
	mark("hazard_passed", {"active_seen": active_seen, "passed": passed, "grounded": main.runner.on_ground(), "loaded": catch_slab.trigger.loaded(), "alive": main.runner.state != Runner.State.DEAD})
	assert(catch_slab.trigger.loaded())
	await brake()
	await until_take(2.0)
	finish_take()

func gear_take() -> void:
	await super.gear_take()
	taking = true
	await until_take(2.0)
	finish_take()

func cart_take() -> void:
	await super.cart_take()
	taking = true
	await until_take(2.0)
	finish_take()

func collapse_digest() -> void:
	await new_stage(Stage.Which.CAVE)
	choose_crumble()
	position_runner(top - Vector2(0, 34))
	zoom = 1.6
	focus = top + Vector2(65, 100)
	await frames(2)
	start_take("collapse")
	for _i in 70:
		if crumble._gone: break
		await frames(1)
	var deck := top + Vector2(0, 225)
	var slab := await draw_platform(deck - Vector2(90, 0), deck + Vector2(90, 0), 0.3)
	assert(slab != null)
	for _i in 80:
		await frames(1)
		if slab.trigger.loaded(): break
	mark("digest_catch", {"loaded": slab.trigger.loaded()})
	assert(slab.trigger.loaded())
	await until_take(2.1)
	finish_take()

func relay() -> void:
	await new_stage(Stage.Which.SEA)
	for enemy in get_tree().get_nodes_in_group("enemy"): enemy.queue_free()
	await frames(2)
	GameState.has_key = true
	var first := Vector2(8260, 1140)
	var build: BuildAbility = main.guardian.abilities[1]
	position_runner(first - Vector2(0, 58))
	for _i in 12:
		if build.check(main.guardian, first) == "": break
		first.y -= 35
	position_runner(first - Vector2(0, 58))
	var start_slab := place(first)
	assert(start_slab != null)
	zoom = 1.1
	focus = first + Vector2(300, -180)
	await seconds(0.3)
	assert(start_slab.trigger.loaded())
	start_take("relay")
	main.runner.facing = 1
	await shoot(start_slab.trigger.global_position)
	mark("relay_launch_1", {"airborne": not main.runner.on_ground()})
	var second := Vector2(8760, 950)
	await seconds(0.08)
	var middle_slab := await draw_platform(second - Vector2(120, 0), second + Vector2(250, 0), 0.3)
	assert(middle_slab != null)
	for _i in 125:
		await frames(1)
		if middle_slab.trigger.loaded(): break
	mark("relay_catch_1", {"loaded": middle_slab.trigger.loaded(), "alive": main.runner.state != Runner.State.DEAD, "at": [main.runner.global_position.x, main.runner.global_position.y], "first": [first.x, first.y]})
	assert(middle_slab.trigger.loaded())
	main.runner.facing = 1
	# The second player fires on touchdown, before the moving runner leaves.
	main.guardian.select_slot(3)
	pointer = middle_slab.trigger.global_position
	aiming = true
	main.input_hub.aim_at_world(pointer)
	await frames(3)
	var target: Node = main.guardian.abilities[3].target_at(main.guardian, pointer)
	main.guardian.use_active(pointer)
	mark("shot", {"target": target.get_script().resource_path if target != null else "none"})
	await frames(2)
	pointer = Vector2(INF, INF)
	aiming = false
	mark("relay_launch_2", {"airborne": not main.runner.on_ground()})
	focus = Vector2(9075, 715)
	var third := Vector2(9220, 760)
	await seconds(0.08)
	var last_slab := await draw_platform(third - Vector2(100, 0), third + Vector2(140, 0), 0.3)
	assert(last_slab != null)
	for _i in 130:
		await frames(1)
		if last_slab.trigger.loaded(): break
	mark("relay_catch_2", {"loaded": last_slab.trigger.loaded(), "alive": main.runner.state != Runner.State.DEAD})
	assert(last_slab.trigger.loaded())
	drive(1)
	for _i in 160:
		await frames(1)
		if main.runner.cleared: break
	drive(0)
	mark("goal", {"cleared": main.runner.cleared})
	assert(main.runner.cleared)
	await seconds(0.2)
	finish_take()
	start_take("title")
	await seconds(4.0)
	finish_take()

func run() -> void:
	if OS.get_environment("PROMO_MODE") == "lesson-only":
		await lesson()
		save_metadata()
		main.queue_free()
		await frames(2)
		print("promo v3: lesson capture finished")
		get_tree().quit()
		return
	await intro()
	await failure()
	await lesson()
	if OS.get_environment("PROMO_MODE") != "lesson":
		await collapse_digest()
		await launch_hazard(Stage.Which.SWAMP, "eruption", "geyser")
		await gear_take()
		await cart_take()
		await relay()
	save_metadata()
	main.queue_free()
	await frames(2)
	print("promo v3: capture finished")
	get_tree().quit()
