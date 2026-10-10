extends Node2D
## Deterministic cinematic takes. Production game rules and assets are unchanged.
const MainScene: PackedScene = preload("res://src/main.tscn")
const OUTPUT := "res://build/promotion/"
const FPS := 60
var main: Node2D
var focus := Vector2.ZERO
var zoom := 1.5
var follow := false
var stroke := PackedVector2Array()
var pointer := Vector2(INF, INF)
var segments: Array[Dictionary] = []
var marks: Array[Dictionary] = []
var take_start := 0

func _ready() -> void:
	process_priority = 250
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	call_deferred("run")

func _process(delta: float) -> void:
	if is_instance_valid(main):
		if follow:
			focus = focus.lerp(main.runner.global_position + Vector2(110, -60), minf(1.0, delta * 5.0))
		main.camera.global_position = focus
		main.camera.zoom = Vector2.ONE * zoom
	queue_redraw()

func _draw() -> void:
	if stroke.size() > 1:
		draw_polyline(stroke, Color(0.15, 0.9, 1.0, 0.28), 16, true)
		draw_polyline(stroke, Color(0.8, 1.0, 1.0), 4, true)
	if pointer.x != INF:
		draw_circle(pointer, 10, Color(1, 0.82, 0.25, 0.95))
		draw_arc(pointer, 16, 0, TAU, 24, Color.WHITE, 2, true)

func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame

func seconds(t: float) -> void:
	await frames(roundi(t * FPS))

func drive(axis: float, jump := false) -> void:
	main.input_hub.drive_runner(axis, 0, jump, false)

func place(at: Vector2, path := PackedVector2Array()) -> Hologram:
	main.guardian.select_slot(1)
	main.guardian.place_path = path
	main.guardian.use_active(at)
	main.guardian.place_path = PackedVector2Array()
	var live: Array = main.guardian.holograms_of(Hologram.Kind.PLATFORM)
	if live.is_empty():
		push_error("promo placement refused: " + main.guardian._last_refusal)
		return null
	return live[-1]

func draw_platform(a: Vector2, b: Vector2, duration := 0.35) -> Hologram:
	stroke = PackedVector2Array([a])
	for i in maxi(2, roundi(duration * FPS)):
		pointer = a.lerp(b, float(i + 1) / float(maxi(2, roundi(duration * FPS))))
		stroke.append(pointer)
		await frames(1)
	var center := (a + b) * 0.5
	var holo := place(center, PackedVector2Array([a - center, b - center]))
	stroke = PackedVector2Array()
	pointer = Vector2(INF, INF)
	mark("platform", {"at": [center.x, center.y], "refusal": main.guardian._last_refusal})
	return holo

func shoot(at: Vector2) -> void:
	pointer = at
	main.guardian.select_slot(3)
	main.input_hub.aim_at_world(at)
	main.guardian.use_active(at)
	mark("shot", {"at": [at.x, at.y]})
	await seconds(0.12)
	pointer = Vector2(INF, INF)

func start_take(label: String) -> void:
	take_start = Engine.get_process_frames()
	segments.append({"name": label, "start_frame": take_start})
	print("TAKE ", label, " frame=", take_start)

func finish_take() -> void:
	segments[-1]["end_frame"] = Engine.get_process_frames()
	segments[-1]["runner_alive"] = main.runner.state != Runner.State.DEAD
	segments[-1]["runner_position"] = [main.runner.global_position.x, main.runner.global_position.y]

func mark(label: String, detail := {}) -> void:
	marks.append({"event": label, "frame": Engine.get_process_frames(), "detail": detail})

func new_stage(which: int) -> void:
	if is_instance_valid(main):
		main.queue_free()
		await frames(2)
	Stage.use(which)
	main = MainScene.instantiate()
	add_child(main)
	await frames(2)
	main.set_physics_process(false)
	main.set_process(false)
	main.input_hub.scripted = true
	for name in ["NetPanel", "Hud", "Quit", "Scope", "PlacementPreview"]:
		var node := main.get_node_or_null(name)
		if node != null: node.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	main.camera.limit_left = -100000
	main.camera.limit_right = 100000
	main.camera.limit_top = -100000
	main.camera.limit_bottom = 100000
	follow = false
	stroke = PackedVector2Array()
	pointer = Vector2(INF, INF)
	main.runner.respawn(Stage.start())
	focus = main.runner.global_position + Vector2(100, -100)
	zoom = 1.5
	await frames(4)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)

func position_runner(at: Vector2) -> void:
	main._respawn_timer = -1
	drive(0)
	main.guardian.clear_constructs()
	main.runner.respawn(at)
	main.runner.velocity = Vector2.ZERO

func save_metadata() -> void:
	var file := FileAccess.open(OUTPUT + "takes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": FPS, "segments": segments, "events": marks}, "\t"))

func serial(value: Variant) -> Variant:
	if value is Vector2: return [value.x, value.y]
	if value is Rect2: return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Array:
		var out: Array = []
		for v in value: out.append(serial(v))
		return out
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = serial(value[key])
		return out
	return value

func inspect() -> void:
	var out := {}
	for which in [Stage.Which.CAVE, Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.TOWER, Stage.Which.SKYWARD_RUINS]:
		Stage.use(which)
		var data := Stage.data()
		out[Stage.stage_number()] = serial({"rooms": data.call("rooms") if data.has_method("rooms") else [], "gimmicks": Stage.gimmicks(), "ground": Stage.ground(), "goal": Stage.goal(), "start": Stage.start(), "route": Stage.route()})
	var file := FileAccess.open(OUTPUT + "stage-data.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	print("promo: stage data saved")
	get_tree().quit()

func run() -> void:
	if OS.get_environment("PROMO_MODE") == "inspect":
		inspect()
		return
	await opening()
	if OS.get_environment("PROMO_MODE") != "opening":
		await chase()
		await expiry()
		await hazard_take(Stage.Which.SEA, "anchor", "meteor")
		await hazard_take(Stage.Which.SEA, "surge", "geyser")
		await hazard_take(Stage.Which.SWAMP, "eruption", "geyser")
		await gear_take()
		await cart_take()
		await wind_take()
		await finale()
	save_metadata()
	if is_instance_valid(main):
		main.queue_free()
		await frames(2)
	print("promo: capture finished")
	get_tree().quit()

func opening() -> void:
	await new_stage(Stage.Which.CAVE)
	var chosen: CrumblingFloor = null
	var room: Dictionary
	for r in Stage.data().rooms():
		if r["name"] == "crumble_shaft": room = r
	for node in main.level.find_children("*", "", true, false):
		if node is CrumblingFloor and node.global_position.y < float(room["bottom"]) and node.global_position.y > float(room["top"]):
			if chosen == null or node.global_position.y > chosen.global_position.y:
				chosen = node
	assert(chosen != null)
	var top: Vector2 = chosen.global_position - Vector2(0, chosen.span.y * 0.5)
	position_runner(top - Vector2(0, 34))
	zoom = 1.9
	focus = top + Vector2(65, 130)
	await frames(2)
	start_take("opening")
	for _i in 70:
		if chosen._gone: break
		await frames(1)
	var deck := top + Vector2(0, 270)
	var slab := await draw_platform(deck + Vector2(-110, 0), deck + Vector2(110, 0), 0.22)
	assert(slab != null)
	await seconds(0.85)
	print("OPEN landing ", main.runner.global_position, " grounded=", main.runner.on_ground(), " loaded=", slab.trigger.loaded())
	mark("rescue", {"grounded": main.runner.on_ground(), "loaded": slab.trigger.loaded()})
	assert(slab.trigger.loaded(), "Opening rescue must land on the drawn platform")
	await seconds(1.7)
	main.runner.facing = 1
	await shoot(slab.trigger.global_position)
	mark("launch", {"airborne": not main.runner.on_ground(), "velocity": [main.runner.velocity.x, main.runner.velocity.y]})
	follow = true
	zoom = 1.65
	await seconds(0.9)
	finish_take()

func chase() -> void:
	await new_stage(Stage.Which.SEA)
	position_runner(Vector2(-850, 355))
	await seconds(0.15)
	var pursuer: Node2D
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get_script() == preload("res://src/entities/enemies/sky_pursuer.gd"):
			pursuer = e
		else:
			e.queue_free()
	pursuer.global_position = main.runner.global_position + Vector2(-310, -25)
	pursuer._wake_left = 0.0
	pursuer._activated = true
	focus = main.runner.global_position + Vector2(-110, -70)
	zoom = 1.7
	await frames(2)
	start_take("chase")
	pursuer.set_physics_process(true)
	drive(0.65)
	for _i in 130:
		focus = main.runner.global_position + Vector2(-110, -65)
		if main.runner.global_position.distance_to(pursuer.global_position) < 135: break
		await frames(1)
	mark("pursuer_close", {"gap": main.runner.global_position.distance_to(pursuer.global_position)})
	await shoot(pursuer.global_position)
	mark("pursuer_stopped", {"stunned": pursuer.stunned()})
	for _i in 86:
		focus = main.runner.global_position + Vector2(-90, -65)
		await frames(1)
	drive(0)
	finish_take()

func expiry() -> void:
	await new_stage(Stage.Which.SEA)
	var deck := Vector2(3930, 145)
	position_runner(deck - Vector2(0, 70))
	var slab := place(deck)
	assert(slab != null)
	focus = deck + Vector2(110, -90)
	zoom = 1.9
	await seconds(4.8)
	assert(slab.trigger.loaded())
	start_take("expiry")
	await seconds(0.55)
	drive(1, true)
	await seconds(0.15)
	var next_deck := deck + Vector2(160, -90)
	await draw_platform(next_deck - Vector2(100, 0), next_deck + Vector2(100, 0), 0.25)
	drive(1, false)
	for i in 90:
		var distance: float = next_deck.x - main.runner.global_position.x
		drive(clampf(distance / 80.0, -1, 1))
		await frames(1)
		if i > 18 and main.runner.on_ground(): break
	mark("expiry_rescue", {"grounded": main.runner.on_ground(), "alive": main.runner.state != Runner.State.DEAD})
	drive(0)
	await seconds(0.25)
	finish_take()

func closest_ground(at: Vector2) -> Rect2:
	var best := INF
	var chosen: Rect2
	for rect in Stage.ground():
		var point := Vector2(clampf(at.x, rect.position.x + 35, rect.end.x - 35), rect.position.y)
		var distance := point.distance_to(at)
		if distance < best:
			chosen = rect
			best = distance
	return chosen

func hazard_take(which: int, label: String, kind: String) -> void:
	await new_stage(which)
	var hazard: VolcanicHazard
	for node in main.level.find_children("*", "", true, false):
		if node is VolcanicHazard and node.kind == kind:
			hazard = node
			break
	assert(hazard != null)
	var target: Vector2 = hazard.global_position + hazard.travel if kind == "meteor" else hazard.global_position
	var ground := closest_ground(target - Vector2(170, 0))
	var actor := Vector2(clampf(target.x - 170, ground.position.x + 40, ground.end.x - 40), ground.position.y - 34)
	position_runner(actor)
	focus = (actor + target) * 0.5 + Vector2(30, -135)
	zoom = 1.65
	Clock.tick = roundi((1.05 - hazard.phase_offset + hazard.period) * 60)
	await frames(2)
	start_take(label)
	drive(0, true)
	await seconds(0.3)
	drive(0, false)
	await seconds(1.45)
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
	focus = wheel.global_position + Vector2(15, -85)
	zoom = 1.7
	await frames(4)
	start_take("gear")
	await seconds(1.65)
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
	focus = cart.global_position + Vector2(110, -95)
	zoom = 1.8
	await frames(5)
	start_take("cart")
	await seconds(1.65)
	finish_take()

func wind_take() -> void:
	await new_stage(Stage.Which.SEA)
	position_runner(Vector2(4280, -185))
	focus = Vector2(4450, -340)
	zoom = 1.5
	await frames(2)
	start_take("wind")
	drive(0.55)
	await seconds(1.65)
	drive(0)
	finish_take()

func finale() -> void:
	await new_stage(Stage.Which.SEA)
	GameState.has_key = true
	var deck := Vector2(8760, 950)
	position_runner(deck - Vector2(0, 55))
	var slab := place(deck)
	assert(slab != null)
	focus = Vector2(9075, 715)
	zoom = 1.5
	await seconds(0.3)
	assert(slab.trigger.loaded())
	start_take("finale")
	await seconds(0.35)
	main.runner.facing = 1
	await shoot(slab.trigger.global_position)
	await seconds(0.26)
	var catch_at := Vector2(9220, 760)
	await draw_platform(catch_at - Vector2(80, 0), catch_at + Vector2(80, 0), 0.2)
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
	await seconds(1.3)
	finish_take()
