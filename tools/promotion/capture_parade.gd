extends "res://tools/promotion/capture_promo_v3.gd"
## Films the production 1-9 course. Only camera and player inputs are directed.
const OUT_PARADE := "res://build/promotion/stage-1-9/"
var machine_kills := 0
var launched := 0

func _ready() -> void:
	process_priority = 250
	TranslationServer.set_locale("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PARADE))
	Events.enemy_killed.connect(func(_e: Node2D, by: String) -> void:
		if by == "parade": machine_kills += 1)
	Events.runner_launched.connect(func(_at: Vector2) -> void: launched += 1)
	call_deferred("run")

func stage_at(at: Vector2) -> void:
	await new_stage(Stage.Which.PARADE)
	for e in get_tree().get_nodes_in_group("enemy"): e.set_physics_process(true)
	Clock.reset(0)
	position_runner(at)
	add_controls()

func machine(id: String) -> ParadeMachine:
	for node in get_tree().get_nodes_in_group("parade_machine"):
		if node.switch_id == id: return node
	return null

func fire_now(at: Vector2) -> void:
	main.guardian.select_slot(3)
	pointer = at
	aiming = true
	main.input_hub.aim_at_world(at)
	var target: Node = main.guardian.abilities[3].target_at(main.guardian, at)
	main.guardian.use_active(at)
	mark("shot", {"hit": target != null})
	await frames(4)
	pointer = Vector2(INF, INF)
	aiming = false
	shake = 5

func wait_loaded(slab: Hologram) -> void:
	if slab == null: return
	for i in 100:
		await frames(1)
		if slab.trigger.loaded() or main.runner.state == Runner.State.DEAD: break
	mark("catch", {"loaded": slab.trigger.loaded(), "alive": main.runner.state != Runner.State.DEAD})

func run() -> void:
	await stage_at(Vector2(420, 474))
	Clock.reset(30)
	controls.hide()
	zoom = 1.8
	focus = Vector2(450, 310)
	start_take("false_goal")
	await seconds(1.65)
	mark("bite", {"dead": main.runner.state == Runner.State.DEAD, "clock": Clock.tick, "seconds": (Engine.get_process_frames() - take_start) / 60.0})
	shake = 15
	await seconds(0.2)
	var near := focus
	for i in 36:
		var t := float(i + 1) / 36.0
		zoom = lerpf(1.8, 0.8, t)
		focus = near.lerp(Vector2(70, 300), t)
		await frames(1)
	mark("crowd_reveal", {"enemies": get_tree().get_nodes_in_group("enemy").size()})
	await seconds(1.35)
	finish_take()

	await stage_at(Vector2(850, 282))
	var mouth := machine("parade_mouth_a")
	await fire_now(mouth.global_position + mouth.target_offset())
	await seconds(4.7)
	zoom = 1.1
	focus = Vector2(1130, 265)
	start_take("crowd_crusher")
	var before := machine_kills
	await seconds(0.18)
	var hammer := machine("parade_hammer_a")
	await fire_now(hammer.global_position)
	await seconds(3.65)
	mark("mass_crush", {"killed": machine_kills - before, "hero_alive": main.runner.state != Runner.State.DEAD})
	finish_take()

	await stage_at(Vector2(1740, 443))
	zoom = 1.65
	focus = Vector2(1850, 430)
	start_take("floor_rescue")
	await seconds(0.52)
	mark("floor_betrayal", {"falling": main.runner.global_position.y > 445})
	var slab := await draw_platform(Vector2(1640, 635), Vector2(1830, 635), 0.13)
	await wait_loaded(slab)
	if slab != null and slab.trigger.loaded():
		await fire_now(slab.trigger.global_position)
		mark("rescue_launch", {"launched": launched > 0})
		follow = true
		drive(1)
	await seconds(1.45)
	drive(0)
	finish_take()

	await stage_at(Vector2(2700, 410))
	zoom = 1.4
	focus = Vector2(2820, 265)
	start_take("second_mouth")
	await seconds(0.43)
	mouth = machine("parade_mouth_b")
	await fire_now(mouth.global_position + mouth.target_offset())
	drive(1)
	await seconds(1.25)
	mark("second_gate", {"open": mouth.active, "alive": main.runner.state != Runner.State.DEAD})
	finish_take()

	await stage_at(Vector2(3200, 202))
	zoom = 1.05
	focus = Vector2(3490, 205)
	start_take("reverse_wave")
	before = machine_kills
	hammer = machine("parade_hammer_b")
	await fire_now(hammer.global_position)
	await seconds(2.95)
	mark("reverse_crush", {"killed": machine_kills - before, "alive": main.runner.state != Runner.State.DEAD})
	finish_take()

	await stage_at(Vector2(4410, 250))
	zoom = 1.7
	focus = Vector2(4510, 320)
	start_take("final_launch")
	slab = await draw_platform(Vector2(4320, 480), Vector2(4500, 480), 0.16)
	await wait_loaded(slab)
	if slab != null and slab.trigger.loaded(): await fire_now(slab.trigger.global_position)
	mark("final_flight", {"airborne": main.runner.velocity.y < -300})
	follow = true
	drive(1)
	for i in 150:
		await frames(1)
		if main.runner.cleared: break
	mark("goal", {"cleared": main.runner.cleared})
	drive(0)
	await seconds(0.2)
	finish_take()
	start_take("title")
	controls.hide()
	follow = false
	zoom = 1.6
	focus = Vector2(4910, 110)
	await seconds(3)
	finish_take()
	var name_ := "takes-probe.json" if OS.get_cmdline_user_args().has("--probe-only") else "takes.json"
	var file := FileAccess.open(OUT_PARADE + name_, FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": 60, "stage": "1-9", "segments": segments,
		"events": marks, "framing": frame_metrics, "machine_kills": machine_kills}, "\t"))
	file.close()
	main.free()
	await frames(2)
	get_tree().quit()
