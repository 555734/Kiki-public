extends "res://tools/promotion/capture_promo_v3.gd"
## Compact filming course assembled exclusively from production game pieces.
const OUT_V4 := "res://build/promotion/v4/"
var action_follow := false
var chase_enemy: Node2D
var course_vents: Array[VolcanicHazard] = []
var camera_wide := 0.0

func _ready() -> void:
	process_priority = 250
	TranslationServer.set_locale("en")
	Events.runner_died.connect(func(cause: String) -> void: print("V4 DEATH ", cause, " at ", main.runner.global_position))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_V4))
	call_deferred("run")

func _process(delta: float) -> void:
	if action_follow and is_instance_valid(main):
		var lead := Vector2(150, -50)
		focus = focus.lerp(main.runner.global_position + lead, minf(1, delta * 12))
		zoom = lerpf(zoom, 1.75 if camera_wide > 0 else 2.2, minf(1, delta * 8))
		camera_wide = maxf(0, camera_wide - delta)
	super._process(delta)

func new_stage(which: int) -> void:
	action_follow = false
	camera_wide = 0
	await super.new_stage(which)
	# Do not leave the original stages' visible enemies frozen for filming.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(true)

func save_metadata() -> void:
	var file := FileAccess.open(OUT_V4 + "takes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": FPS, "segments": segments, "events": marks, "frame_metrics": frame_metrics}, "\t"))

func start_take(label: String) -> void:
	super.start_take(label)
	if label in ["eruption", "gear", "cart", "relay"]:
		action_follow = true
		focus = main.runner.global_position + Vector2(120, -60)
		zoom = 2.1
		camera_wide = 1.3 if label in ["eruption", "relay"] else 0.0
	elif label == "title":
		action_follow = false
		focus = main.runner.global_position + Vector2(-110, -50)
		zoom = 1.75

func course(which := Stage.Which.SEA) -> void:
	await new_stage(which)
	# Retain the native sky and effects, replace only this filming instance's level.
	for child in main.level.get_children(): child.queue_free()
	await frames(2)
	var geometry: Array[Rect2] = [Rect2(-620, 300, 500, 120), Rect2(1740, 445, 580, 430)]
	var terrain := preload("res://src/render/terrain.gd").new()
	main.level.add_child(terrain)
	terrain.set_slabs(geometry)
	for rect in geometry:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.position = rect.get_center()
		body.add_child(shape)
		main.level.add_child(body)
	var sea := preload("res://src/render/sea_water.gd").new()
	sea.water_y = 870
	sea.poison = which == Stage.Which.SWAMP
	main.level.add_child(sea)
	crumble = CrumblingFloor.new()
	crumble.span = Vector2(240, 40)
	crumble.one_way = true
	crumble.position = Vector2(0, 320)
	main.level.add_child(crumble)
	top = Vector2(0, 300)
	course_vents.clear()
	for spec in [[0, 260, 0.0], [340, 360, 0.6], [960, 360, 1.8], [1550, 330, 2.7]]:
		var vent := VolcanicHazard.new()
		vent.position = Vector2(spec[0], 820 if spec[0] == 0 else 720)
		vent.travel = Vector2(0, -spec[1])
		vent.width = 90
		vent.phase_offset = spec[2]
		vent.period = 3.5
		main.level.add_child(vent)
		course_vents.append(vent)
	for at in [Vector2(520, 730), Vector2(1260, 745)]:
		var wheel := GearWheel.new()
		wheel.radius = 112
		wheel.angular_speed = 0.55
		wheel.position = at
		main.level.add_child(wheel)
	var lift := MovingPlatform.new()
	lift.position = Vector2(1040, 620)
	lift.span = Vector2(155, 26)
	lift.travel = Vector2(130, 85)
	lift.speed = 115
	main.level.add_child(lift)
	var goal := Goal.new()
	goal.position = Vector2(2090, 390)
	main.level.add_child(goal)
	GameState.has_key = true
	var pit := Hazard.new()
	pit.position = Vector2(900, 1040)
	pit.span = Vector2(3500, 120)
	pit.draw_spikes = false
	main.level.add_child(pit)
	chase_enemy = preload("res://src/entities/enemies/sky_pursuer.gd").new()
	chase_enemy.runner = main.runner
	chase_enemy.chase_direction = Vector2.RIGHT
	chase_enemy.cruise_speed = 160
	chase_enemy.catchup_speed = 360
	chase_enemy.wake_delay = 2.6
	chase_enemy.position = Vector2(-420, 245)
	main.level.add_child(chase_enemy)
	position_runner(top - Vector2(40, 24))
	main.input_hub.move_axis = 0
	focus = Vector2(40, 330)
	zoom = 2.2
	await frames(2)

func opening_v4() -> void:
	await course()
	hold_crumble = true
	crumble.set_process(false)
	chase_enemy.position = Vector2(-290, 250)
	chase_enemy._wake_left = 0
	zoom = 2.45
	focus = Vector2(-75, 240)
	await frames(2)
	start_take("intro")
	for _i in 120:
		await frames(1)
		if main.runner.state == Runner.State.DEAD: break
	assert(main.runner.state == Runner.State.DEAD, "Opening catch must be native")
	mark("opening_death", {"dead": true, "elapsed": float(Engine.get_process_frames() - take_start) / FPS})
	shake = 16
	await seconds(0.18)
	main.runner.hide()
	await until_take(1.8)
	var near := focus
	mark("pullback")
	for i in 65:
		var t := smoothstep(0, 1, float(i + 1) / 65)
		zoom = lerpf(2.45, 0.92, t)
		focus = near.lerp(Vector2(570, 500), t)
		await frames(1)
	mark("moving_course_reveal", {"gears": 2, "vents": 4, "moving_lift": true})
	await until_take(3.5)
	finish_take()

func failure_v4() -> void:
	await course()
	chase_enemy._wake_left = 100
	Clock.tick = 35
	zoom = 2.2
	focus = Vector2(35, 370)
	start_take("failure")
	for _i in 100:
		await frames(1)
		if main.runner.global_position.y > top.y + 200: break
	mark("unassisted_fall", {"distance": main.runner.global_position.y - top.y})
	action_follow = true
	await seconds(0.38)
	finish_take()

func quick_shot(at: Vector2, cue := 0.12) -> void:
	main.guardian.select_slot(3)
	pointer = at
	aiming = true
	await seconds(cue)
	# Track the moving enemy while the aiming cue is on screen.
	if is_instance_valid(chase_enemy) and at.distance_to(chase_enemy.global_position) < 160:
		at = chase_enemy.global_position
		pointer = at
	main.input_hub.aim_at_world(at)
	var target: Node = main.guardian.abilities[3].target_at(main.guardian, at)
	main.guardian.use_active(at)
	mark("shot", {"target": target.get_script().resource_path if target != null else "none"})
	shake = 5
	await frames(2)
	aiming = false
	pointer = Vector2(INF, INF)

func wait_loaded(slab: Hologram, label: String) -> void:
	assert(slab != null, "Filming placement must succeed")
	for _i in 150:
		await frames(1)
		if main.runner.state == Runner.State.DEAD or slab.trigger.loaded(): break
	mark(label, {"loaded": slab.trigger.loaded(), "alive": main.runner.state != Runner.State.DEAD,
		"at": [main.runner.global_position.x, main.runner.global_position.y]})
	assert(slab.trigger.loaded(), "V4 must show the real receiving-platform landing")
	shake = 7

func teamwork_v4() -> void:
	await course()
	chase_enemy._wake_left = 1.7
	zoom = 2.15
	focus = Vector2(60, 380)
	start_take("teamwork")
	add_controls()
	# The role reveal is the actual intervention into the previously failed fall.
	for _i in 70:
		await frames(1)
		if crumble._gone: break
	mark("collapse")
	var deck := Vector2(-40, 520)
	var slab := await draw_platform(deck - Vector2(100, 0), deck + Vector2(100, 0), 0.28)
	await wait_loaded(slab, "rescue")
	mark("role_reveal", {"intervention": true})
	await seconds(0.2)
	main.runner.facing = 1
	action_follow = true
	camera_wide = 1.1
	await quick_shot(slab.trigger.global_position, 0.18)
	mark("launch_1", {"airborne": not main.runner.on_ground()})
	# Hide large controls after the role is clear; keep the drawing/reticle visible.
	controls.hide()
	var receiving := deck + Vector2(650, -25)
	await seconds(0.16)
	var next := await draw_platform(receiving - Vector2(190, 0), receiving + Vector2(190, 0), 0.3)
	await wait_loaded(next, "catch_1")
	main.runner.facing = 1
	camera_wide = 1.0
	await quick_shot(next.trigger.global_position, 0.05)
	mark("launch_2", {"airborne": not main.runner.on_ground()})
	var final_deck := receiving + Vector2(600, -25)
	await seconds(0.15)
	var third := await draw_platform(final_deck - Vector2(180, 0), final_deck + Vector2(180, 0), 0.28)
	await wait_loaded(third, "catch_2")
	main.runner.facing = 1
	camera_wide = 1.1
	await quick_shot(third.trigger.global_position, 0.05)
	mark("launch_3", {"airborne": not main.runner.on_ground()})
	for _i in 160:
		await frames(1)
		if main.runner.on_ground(): break
	mark("island_landing", {"grounded": main.runner.on_ground(), "alive": main.runner.state != Runner.State.DEAD})
	assert(main.runner.on_ground() and main.runner.state != Runner.State.DEAD)
	drive(1)
	for _i in 150:
		await frames(1)
		if main.runner.cleared: break
	mark("goal", {"cleared": main.runner.cleared})
	assert(main.runner.cleared)
	drive(0)
	await seconds(0.15)
	finish_take()

func pressure_v4() -> void:
	await course(Stage.Which.SWAMP)
	# A second, closer rescue under enemy pressure; no idle success interval.
	hold_crumble = true
	crumble.set_process(false)
	position_runner(Vector2(-390, 276))
	chase_enemy.position = Vector2(-670, 250)
	chase_enemy._wake_left = 0
	zoom = 2.25
	focus = Vector2(-340, 245)
	start_take("pressure")
	action_follow = true
	drive(0.7)
	for _i in 160:
		await frames(1)
		if main.runner.global_position.x > -55: break
	drive(0)
	mark("enemy_close", {"gap": main.runner.global_position.distance_to(chase_enemy.global_position)})
	await quick_shot(chase_enemy.global_position)
	mark("enemy_stopped", {"stunned": chase_enemy.stunned()})
	assert(chase_enemy.stunned())
	hold_crumble = false
	crumble.set_process(true)
	for _i in 70:
		await frames(1)
		if crumble._gone: break
	var deck := Vector2(main.runner.global_position.x, 520)
	var slab := await draw_platform(deck - Vector2(100, 0), deck + Vector2(100, 0), 0.24)
	await wait_loaded(slab, "pressure_rescue")
	main.runner.facing = 1
	camera_wide = 1.1
	await quick_shot(slab.trigger.global_position, 0.05)
	mark("pressure_launch", {"airborne": not main.runner.on_ground()})
	await seconds(0.6)
	finish_take()

func run() -> void:
	var mode := OS.get_environment("PROMO_MODE")
	if mode == "opening":
		await opening_v4()
		await failure_v4()
	elif mode == "core":
		await teamwork_v4()
		await pressure_v4()
	else:
		await opening_v4()
		await failure_v4()
		await teamwork_v4()
		await pressure_v4()
		await launch_hazard(Stage.Which.SWAMP, "eruption", "geyser")
		await launch_hazard(Stage.Which.SEA, "anchor", "meteor")
		await gear_take()
		await cart_take()
		await relay()
	# Native digest takes keep their existing validated mechanics.
	save_metadata()
	main.queue_free()
	await frames(2)
	print("promo v4: capture finished")
	get_tree().quit()
