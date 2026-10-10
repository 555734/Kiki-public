extends Node
const MainScene = preload("res://src/main.tscn")
var main: Node2D
var checks := 0
var failures: Array[String] = []
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok: failures.append(msg)
	print("PARADE_V2 ", "PASS " if ok else "FAIL ", msg)
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func device(kind: String) -> ParadeDevice:
	for d in get_tree().get_nodes_in_group("parade_device"):
		if d.kind == kind: return d
	return null
func actor(kind: String) -> ParadeActor:
	for a in get_tree().get_nodes_in_group("parade_actor"):
		if a.kind == kind: return a
	return null
func park(at: Vector2) -> void:
	main.runner.respawn(at)
	main.input_hub.drive_runner(0,0,false,false)
func shoot(node: Node2D) -> void:
	var at: Vector2 = node.shot_position() if node.has_method("shot_position") else node.global_position
	main.guardian.select_slot(3)
	main.input_hub.aim_at_world(at)
	main.guardian.use_active(at)
func _ready() -> void: call_deferred("run")
func run() -> void:
	TranslationServer.set_locale("en")
	Stage.use(Stage.Which.PARADE)
	check(Stage.Which.PARADE == 14 and Stage.Which.ROYAL_ARENA == 13, "handshake stage values preserved")
	check(StageSpecSchema.errors(Stage.enemies(), Stage.gimmicks()).is_empty(), "all six acts validate against schema")
	check(Stage.data().zones().size() == 6 and Stage.checkpoints().size() == 5, "six acts have five retry checkpoints")
	main = MainScene.instantiate()
	add_child(main)
	await frames(3)
	main.get_node("NetPanel").free()
	main.set_process(false)
	main.set_physics_process(false)
	main.input_hub.scripted = true
	Clock.set_physics_process(false)
	Clock.reset(0)
	# Hold the cast while testing machinery with controlled real bodies.
	for e in get_tree().get_nodes_in_group("enemy"): e.set_physics_process(false)
	check(get_tree().get_nodes_in_group("parade_device").size() == 18, "18 distinct machines built")
	check(get_tree().get_nodes_in_group("parade_actor").size() == 11 and get_tree().get_nodes_in_group("enemy").size() == 89, "12 cast types, 89 authored enemies")
	park(Stage.start())
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is ParadeGremlin: enemy.set_physics_process(true)
	await frames(100)
	check(get_tree().get_nodes_in_group("enemy").size() == 89,"all distant crowds have solid waiting floors before their cue")
	for enemy in get_tree().get_nodes_in_group("enemy"): enemy.set_physics_process(false)
	for d in get_tree().get_nodes_in_group("parade_device"):
		shoot(d)
		await frames(2)
		check(d.active, "native sniper toggles " + d.kind)
		if d.kind != "breakaway":
			shoot(d)
			await frames(2)
			check(not d.active, "repeat shot reverses " + d.kind)
	var gate := device("mask")
	Clock.reset(92)
	park(gate.global_position + Vector2(0,-27))
	await frames(5)
	check(main.runner.state == Runner.State.DEAD, "mask bite is lethal after telegraph")
	shoot(gate)
	Clock.reset(0)
	park(gate.global_position + Vector2(0,-80))
	await frames(35)
	check(main.runner.is_on_floor() and main.runner.state != Runner.State.DEAD, "open jaw is a real walkable bridge")
	var e := ParadeGremlin.new()
	e.runner = main.runner
	e.net_id = 9000
	e.wake_x = 99999
	e.position = device("accordion").global_position + Vector2(0,-30)
	main.level._dynamic.add_child(e)
	e.set_physics_process(false)
	park(Vector2(3600,470))
	await frames(2)
	var accordion := device("accordion")
	shoot(accordion)
	await frames(2)
	check(accordion.charge >= 1 and main.runner.velocity.y < -550 and e.velocity.y < -550, "crowd-loaded accordion launches Lira and enemy using native velocity")
	var curtain := device("curtain")
	curtain.pose_at(0)
	var low := curtain._decks[0].position.y
	curtain.pose_at(170)
	check(absf(curtain._decks[0].position.y - low) > 100, "curtain lift really changes route height")
	var belt := device("conveyor")
	belt.set_active(false)
	belt.pose_at(0)
	var forward := belt._decks[0].constant_linear_velocity.x
	shoot(belt)
	await frames(2)
	check(forward > 0 and belt._decks[0].constant_linear_velocity.x < 0, "conveyor reverses native floor carry")
	park(device("vent").global_position + Vector2(0,-80))
	await frames(24)
	check(main.runner.velocity.y < -400, "confetti vent lifts actual runner")
	var shadow := actor("shadow")
	park(Vector2(4510,390))
	device("spot").set_active(false)
	await frames(2)
	check(shadow.active and shadow._platform.collision_layer == 1 and shadow.collision_layer == 0, "dark marionette is a safe collidable prop")
	shoot(device("spot"))
	await frames(2)
	check(not shadow.active and shadow.collision_layer == 4, "spotlight restores hostile marionette")
	shoot(actor("stilt"))
	await frames(3)
	check(actor("stilt").active and actor("stilt")._platform.collision_layer == 1, "shot knee folds the usher into a real ramp")
	shoot(actor("balloon"))
	shoot(actor("acrobat"))
	shoot(actor("twins"))
	await frames(3)
	check(actor("balloon").active and actor("acrobat").active and actor("twins").active, "cord, ribbon and mirror shots transform three enemies")
	var wall := device("breakaway")
	wall.set_active(false)
	var hound := actor("hound")
	hound.global_position = wall.global_position + Vector2(-60,-26)
	hound.velocity.x = 470
	park(Vector2(5300,450))
	await frames(3)
	check(wall.active and wall._decks[3].position.y < -100, "charging hound reveals collision stairs")
	var wheel := device("wheel")
	wheel.set_active(false)
	Clock.reset(300)
	shoot(wheel)
	await frames(3)
	var stopped := wheel._decks[0].position
	wheel.pose_at(600)
	check(wheel._decks[0].position.distance_to(stopped) < 0.01, "brake parks all wheel cabins")
	var state := MigrationState.decode(MigrationState.capture(main))
	wheel.active = false
	actor("stilt").active = false
	check(MigrationState.apply(main,state) and wheel.active and actor("stilt").active and actor("stilt")._platform.collision_layer == 1, "migration restores device/cast states and physical ramp")
	var saved := wheel.replay_id()
	wheel.active = false
	Events.switch_activated.emit(saved)
	check(wheel.active, "reconnect replay restores an active brake")
	wheel.set_active(false)
	saved = wheel.replay_id()
	wheel.active = true
	Events.switch_activated.emit(saved)
	check(not wheel.active, "reconnect also restores a reversed/off device")
	# Check forces and actual rides, beyond accepting a shot on each latch.
	e.global_position = device("turntable").global_position + Vector2(0,-28)
	e.velocity = Vector2.ZERO
	device("turntable").set_active(true)
	park(Vector2(2480,250))
	await frames(3)
	check(e.velocity.x > 200 and e.velocity.y < -600, "turntable directs a real crowd body into the upper exit")
	e.global_position = device("magnet").global_position + Vector2(0,240)
	device("magnet").set_active(false)
	park(Vector2(2030,250))
	await frames(3)
	check(e.velocity.y < -150, "magnet attracts the metal enemy")
	device("magnet").set_active(true)
	e.global_position = device("magnet").global_position + Vector2(0,70)
	await frames(3)
	check(e.velocity.x > 200 and e.velocity.y > 200, "magnet releases the enemy toward the counterweight pan")
	var trap := device("trapdoors")
	trap.set_active(false)
	e.global_position = trap.global_position + Vector2(-70,-25)
	park(Vector2(1150,450))
	Clock.reset(0)
	await frames(3)
	Clock.reset(30)
	await frames(3)
	var first_open := -1
	for i in trap._decks.size():
		if trap._decks[i].collision_layer == 0: first_open = i
	Clock.reset(50)
	await frames(3)
	check(trap.active and first_open >= 0 and trap._decks[first_open].collision_layer == 1, "enemy pressure starts a travelling trapdoor opening")
	var moon := device("moon")
	moon.set_active(false)
	moon.pose_at(Clock.tick)
	var high := moon._decks[0].position.y
	moon.set_active(true)
	check(moon._decks[0].position.y - high > 150, "paper moon lowers four collidable curve segments")
	park(Vector2(1480,440))
	curtain.set_active(false)
	Clock.reset(0)
	await frames(20)
	var ride_start: float = main.runner.global_position.y
	Clock.set_physics_process(true)
	await frames(130)
	check(main.runner.state != Runner.State.DEAD and main.runner.global_position.y < ride_start - 70, "real runner rides the moving curtain lift")
	Clock.set_physics_process(false)
	Clock.reset(0)
	device("cannon").set_active(true)
	park(Vector2(2670,470))
	main.input_hub.drive_runner(1,0,false,false)
	await frames(60)
	check(main.runner.global_position.x > 2940 and main.runner.state != Runner.State.DEAD, "high cannon arc crosses the actual crossing gap")
	main.input_hub.drive_runner(0,0,false,false)
	Clock.reset(0)
	moon.set_active(true)
	wheel.set_active(false)
	park(Vector2(5705,300))
	await frames(22)
	ride_start = main.runner.global_position.y
	Clock.set_physics_process(true)
	await frames(120)
	check(main.runner.state != Runner.State.DEAD and main.runner.global_position.y < ride_start - 60, "real runner is carried upward by a wheel gondola")
	Clock.set_physics_process(false)
	main.level.rebuild_dynamic()
	await frames(3)
	check(not device("mask").active and get_tree().get_nodes_in_group("enemy").size() == 89, "retry resets whole company and machinery")
	# Real launch trigger + actual runner input to the final flag.
	for enemy in get_tree().get_nodes_in_group("enemy"): enemy.set_physics_process(false)
	park(Vector2(6350,-80))
	main.guardian.select_slot(1)
	main.guardian.use_active(Vector2(6350,50))
	await frames(38)
	var slabs: Array = main.guardian.holograms_of(Hologram.Kind.PLATFORM)
	check(not slabs.is_empty() and slabs[-1].trigger.loaded(), "final guardian catch loads a launch platform at %s (%s)" % [main.runner.global_position,main.guardian._last_refusal])
	if not slabs.is_empty():
		shoot(slabs[-1].trigger)
		for i in 220:
			var dx: float = Stage.goal().x - main.runner.global_position.x
			main.input_hub.drive_runner(0 if absf(dx) < 20 else signf(dx),0,false,false)
			await frames(1)
			if main.runner.cleared: break
	check(main.runner.cleared, "existing launch and movement controls reach real flag")
	var report := {"checks":checks, "failures":failures}
	var report_path := "res://build/promotion/stage-1-9/playable-v2/probe.json"
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
	if mkdir_error != OK:
		push_error("parade probe cannot create its report directory: " + error_string(mkdir_error))
		get_tree().quit(1)
		return
	var f := FileAccess.open(report_path,FileAccess.WRITE)
	if f == null:
		push_error("parade probe cannot save its report: " + error_string(FileAccess.get_open_error()))
		get_tree().quit(1)
		return
	f.store_string(JSON.stringify(report,"\t"))
	print("parade v2 probe: ",JSON.stringify(report))
	main.free()
	await frames(2)
	get_tree().quit(0 if failures.is_empty() else 1)
