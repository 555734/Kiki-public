extends "res://tools/promotion/capture_promo_v3.gd"
## Trailer direction changes only camera and real player inputs. The full cast
## stays live, and every transformation, collision and goal is native gameplay.
const OUT_PV := "res://build/promotion/stage-1-9/pv-v2/"
var killed := 0
var deaths := 0
var launched_count := 0
var probe_only := false
var death_cause := ""

func _ready() -> void:
	process_priority = 250
	TranslationServer.set_locale("en")
	probe_only = OS.get_cmdline_user_args().has("--probe-only")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PV))
	Events.enemy_killed.connect(func(_e: Node2D, _by: String) -> void: killed += 1)
	Events.runner_died.connect(func(cause: String) -> void:
		deaths += 1
		death_cause = cause)
	Events.runner_launched.connect(func(_at: Vector2) -> void: launched_count += 1)
	call_deferred("run")

func device(kind: String) -> ParadeDevice:
	for d in get_tree().get_nodes_in_group("parade_device"):
		if d.kind == kind: return d
	return null

func actor(kind: String) -> ParadeActor:
	for a in get_tree().get_nodes_in_group("parade_actor"):
		if a.kind == kind: return a
	return null

func begin(at: Vector2, center: Vector2, scale: float) -> void:
	await new_stage(Stage.Which.PARADE)
	for e in get_tree().get_nodes_in_group("enemy"): e.set_physics_process(true)
	Clock.set_physics_process(true)
	position_runner(at)
	Clock.reset(0)
	focus = center
	zoom = scale
	add_controls()
	controls.hide()

func shot(node: Node2D) -> void:
	main.guardian.select_slot(3)
	aiming = true
	for i in 10:
		pointer = node.shot_position() if node.has_method("shot_position") else node.global_position
		main.input_hub.aim_at_world(pointer)
		await frames(1)
	var hit: Node = main.guardian.abilities[3].target_at(main.guardian, pointer)
	main.guardian.use_active(pointer)
	mark("shot", {"hit": hit != null, "at": serial(pointer), "target": hit.get_script().resource_path if hit != null else "none"})
	shake = 3
	await frames(6)
	aiming = false
	pointer = Vector2(INF, INF)

func state(label: String, extra := {}) -> void:
	var detail := {"alive": main.runner.state != Runner.State.DEAD,
		"at": serial(main.runner.global_position), "velocity": serial(main.runner.velocity),
		"clock": Clock.tick, "killed": killed, "launches": launched_count}
	detail.merge(extra)
	mark(label, detail)
	print("PV ", segments[-1].name, " ", label, " ", JSON.stringify(detail))

func still(label: String) -> void:
	if probe_only: return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_PV + label + ".png")

func start_take(label: String) -> void:
	super.start_take(label)
	state("start")

func finish_take() -> void:
	state("end")
	super.finish_take()

func run() -> void:
	# The false entrance bites the real runner before two seconds.
	await begin(Vector2(535,430),Vector2(535,360),1.9)
	place(Vector2(535,500))
	Clock.reset(30)
	start_take("bite_reveal")
	for i in 90:
		await frames(1)
		if main.runner.state == Runner.State.DEAD: break
	state("bite", {"dead": main.runner.state == Runner.State.DEAD, "cause": death_cause,"seconds": float(Engine.get_process_frames()-take_start)/60})
	await still("01-bite")
	shake = 15
	await seconds(0.18)
	var close := focus
	for i in 36:
		var t := float(i+1)/36
		focus = close.lerp(Vector2(-60,330),t)
		zoom = lerpf(1.9,0.82,t)
		await frames(1)
	state("crowd", {"company": get_tree().get_nodes_in_group("enemy").size()})
	await still("02-crowd")
	await until_take(3.8)
	finish_take()

	# Reveal the second player's reticle; a jaw becomes a bridge.
	await begin(Vector2(330,470),Vector2(540,340),1.45)
	start_take("partner_bridge")
	await seconds(0.3)
	controls.show()
	await shot(device("mask"))
	drive(1,true)
	await frames(6)
	drive(1,false)
	for i in 115:
		await frames(1)
		if main.runner.global_position.x > 704: break
	drive(0)
	state("bridge_crossed", {"open": device("mask").active, "crossed": main.runner.global_position.x > 680})
	await still("03-bridge")
	await until_take(3.4)
	finish_take()

	# Natural crowd approaches while the runner waits on the upper scenery.
	await begin(Vector2(890,275),Vector2(585,390),1.35)
	await shot(device("mask"))
	await seconds(7.65)
	start_take("jaw_reversal")
	var before := killed
	await shot(device("mask"))
	await seconds(1.65)
	state("reversal", {"closed": not device("mask").active,"new_kills": killed-before})
	await still("04-reversal")
	finish_take()

	# Crowd weight visibly compresses a spring before the shot releases it.
	await begin(Vector2(3670,-40),Vector2(3605,250),1.23)
	place(Vector2(3670,50))
	await seconds(0.45)
	start_take("accordion")
	await seconds(0.35)
	var spring := device("accordion")
	state("loaded_spring", {"weight": spring._weight})
	await shot(spring)
	var flying := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is ParadeGremlin and absf(e.global_position.x-3510)<330 and e.velocity.y < -550: flying += 1
	state("crowd_launch", {"flying": flying,"charge": spring.charge})
	for i in 72:
		focus.y = lerpf(250,210,minf(1,float(i)/40))
		await frames(1)
	await still("05-accordion")
	await until_take(2.4)
	finish_take()

	# Moving curtain carries Lira; the spider controls the ropes above it.
	await begin(Vector2(1480,440),Vector2(1540,300),1.5)
	await shot(actor("spider"))
	if device("curtain").active: await shot(device("curtain"))
	Clock.reset(0)
	position_runner(Vector2(1480,425))
	await seconds(0.35)
	start_take("curtain")
	var start_y: float = main.runner.global_position.y
	await seconds(1.6)
	state("ride", {"rise": start_y-main.runner.global_position.y})
	await still("06-curtain")
	finish_take()

	# Magnet catches the little metal cast, then releases the suspended crowd.
	await begin(Vector2(2120,255),Vector2(1935,300),1.43)
	await seconds(1.65)
	start_take("magnet")
	await seconds(0.3)
	await shot(device("magnet"))
	await seconds(1.1)
	state("released", {"active": device("magnet").active})
	await still("07-magnet")
	finish_take()

	# A towering actor collapses into a traversable ramp.
	await begin(Vector2(2050,255),Vector2(1855,330),1.6)
	start_take("stilt")
	await seconds(0.22)
	await shot(actor("stilt"))
	await seconds(1.02)
	state("folded", {"ramp": actor("stilt").active})
	await still("08-stilt")
	finish_take()

	# The same cannon sends the actual runner over the gap.
	await begin(Vector2(2670,270),Vector2(2810,310),1.22)
	start_take("cannon")
	await shot(device("cannon"))
	var launches_before := launched_count
	drive(0.4)
	for i in 90:
		await frames(1)
		if launched_count > launches_before: break
	state("fired", {"cannon_launch": launched_count>launches_before})
	drive(1)
	for i in 100:
		await frames(1)
		if main.runner.global_position.x > 2985 or main.runner.state == Runner.State.DEAD: break
	state("gap_crossed", {"crossed": main.runner.global_position.x > 2940})
	drive(0)
	await still("09-cannon")
	await until_take(2.0)
	finish_take()

	# The light reverses the shadow's threat into a safe prop.
	await begin(Vector2(4380,275),Vector2(4520,360),1.6)
	await shot(device("spot"))
	start_take("shadow")
	await seconds(0.3)
	await shot(device("spot"))
	await seconds(0.9)
	state("safe_shadow", {"prop": actor("shadow").active})
	await still("10-shadow")
	finish_take()

	# Baiting a charging hound reveals stairs in the false wall.
	await begin(Vector2(5405,275),Vector2(5190,350),1.47)
	start_take("hound")
	await seconds(1.65)
	state("stairs", {"broken": device("breakaway").active})
	await still("11-stairs")
	finish_take()

	# Defeat the native three-HP manager before boarding his wheel.
	await begin(Vector2(5705,300),Vector2(5930,290),1.08)
	await shot(actor("manager"))
	await shot(actor("manager"))
	if not device("moon").active: await shot(device("moon"))
	if device("wheel").active: await shot(device("wheel"))
	await seconds(0.2)
	start_take("wheel")
	var ride_y: float = main.runner.global_position.y
	await seconds(1.9)
	state("gondola", {"rise": ride_y-main.runner.global_position.y})
	await still("12-wheel")
	finish_take()

	# One visible draw catches a fall; one shot launches to the real goal flag.
	await begin(Vector2(6350,-80),Vector2(6370,50),1.3)
	await shot(actor("manager"))
	await shot(actor("manager"))
	# Start this separate take in a falling state, before drawing the catch.
	position_runner(Vector2(6350,-80))
	start_take("final_rescue")
	controls.show()
	var slab := await draw_platform(Vector2(6260,50),Vector2(6440,50),0.22)
	for i in 90:
		await frames(1)
		if slab != null and slab.trigger.loaded(): break
	state("catch", {"loaded": slab != null and slab.trigger.loaded()})
	await seconds(0.1)
	main.runner.facing = 1
	if slab != null: await shot(slab.trigger)
	state("flight", {"airborne": main.runner.velocity.y < -300})
	for i in 220:
		var dx: float = Stage.goal().x-main.runner.global_position.x
		drive(0 if absf(dx)<20 else signf(dx))
		focus.y = clampf(main.runner.global_position.y+50,-180,65)
		await frames(1)
		if main.runner.cleared: break
	drive(0)
	state("goal", {"cleared": main.runner.cleared})
	await still("13-goal")
	await seconds(0.2)
	finish_take()
	start_take("title")
	controls.hide()
	focus = Vector2(6320,185)
	zoom = 1.0
	await seconds(3.2)
	finish_take()
	var name_ := "takes-probe.json" if probe_only else "takes.json"
	var f := FileAccess.open(OUT_PV+name_,FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps":FPS,"segments":segments,"events":marks,"frame_metrics":frame_metrics,"native_gameplay":true},"\t"))
	f.close()
	main.free()
	await frames(2)
	get_tree().quit()
