extends Node2D
## Plays the 49 storyboard cuts of the final PV in the real 1-10 (real Runner
## physics, real Guardian abilities, live machines and enemies), directs the
## camera per cut from src/levels/finale_shots.gd, checks each cut's success
## condition, and writes one still per cut plus a JSON report.
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --fixed-fps 60 \
##       res://tools/promotion/capture_finale_pv.tscn -- [--frames] [--take=opening,...]
##
## --frames also writes every frame of every take (PNG sequence) for the
## edit. Headless (no display) runs the same checks without images.
## Nothing here moves the runner except InputHub.drive_runner; the guardian
## acts only through Guardian.use_active. The camera is the only thing the
## director owns. Slow-motion cuts run at Engine.time_scale with physics
## interpolation, which slows the real simulation rather than faking it.

const MainScene: PackedScene = preload("res://src/main.tscn")
const OUT := "res://build/promotion/stage-1-10/pv/"
const SHOTS := preload("res://src/levels/finale_shots.gd")

var main: Node2D
var r: Runner
var hub: InputHub
var shots: Array[Dictionary] = []
var by_number := {}
var report: Array[Dictionary] = []
var current := {}
var current_start := 0
var rendering := false
var save_frames := false
var only: Array = []
var _axis := 0.0
var _sprint := false
var _jump := false
var _crouch := false
var pointer := Vector2(INF, INF)
var stroke := PackedVector2Array()
var _focus := Vector2.ZERO
var _cause := ""
var _landed_holo := false
var _flags := {}
## The guardian snipes enemies close to the runner (co-op cover), when on.
var cover := true
## How close an enemy must be before the guardian shoots it. Cuts that are
## about the enemies (the swarm, the drones) tighten it.
var cover_radius := 520.0

func _physics_process(_delta: float) -> void:
	if r != null and _near_enemies("brass_drone", 450.0) >= 1:
		_flags["drone_seen"] = true
	if not cover or r == null or main == null or not is_instance_valid(main) or Clock.tick % 4 != 0:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node2D and not e.is_queued_for_deletion() and (e as Node2D).visible \
				and (e as Node2D).global_position.distance_to(r.global_position) < (900.0 if e.get("kind") == "rail_gunner" else (700.0 if e is Turret else cover_radius)):
			main.guardian.select_slot(3)
			hub.aim_at_world((e as Node2D).global_position)
			main.guardian.use_active((e as Node2D).global_position)
			return

func _ready() -> void:
	process_priority = 250
	z_index = 50
	shots = SHOTS.all()
	for s in shots:
		by_number[int(s["shot"])] = s
	rendering = DisplayServer.get_name() != "headless"
	save_frames = OS.get_cmdline_user_args().has("--frames")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--take="):
			only = a.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Events.runner_died.connect(func(cause: String) -> void:
		_cause = cause
		print("   (runner died: %s at %s)" % [cause, r.global_position.round()]))
	Events.runner_landed_on_hologram.connect(func(_h: Node2D) -> void: _landed_holo = true)
	if OS.get_environment("FINALE_LOG") != "":
		Events.runner_damaged.connect(func(hp: int, _m: int) -> void:
			print("      damaged hp=%d at %s" % [hp, r.global_position.round()]))
		Events.enemy_killed.connect(func(e: Node2D, by: String) -> void:
			print("      killed %s by %s" % [e.get("kind"), by]))
	call_deferred("run")

# ------------------------------------------------------------------ input
func _apply() -> void:
	hub.drive_runner(_axis, 1.0 if _crouch else 0.0, _jump, _sprint)

func frames(n: int) -> void:
	for i in n:
		_apply()
		await get_tree().process_frame
		if save_frames and rendering and not current.is_empty():
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OUT + "frames/%s_%05d.png" % [current["take"], Engine.get_process_frames()])

func hold(axis: float, sprint: bool = false) -> void:
	_axis = axis
	_sprint = sprint

func release() -> void:
	_axis = 0.0
	_sprint = false
	_jump = false
	_crouch = false

func jump(held: int = 18) -> void:
	_jump = true
	await frames(held)
	_jump = false
	await frames(1)

func until(cond: Callable, limit: int = 600) -> bool:
	for i in limit:
		if cond.call():
			return true
		await frames(1)
	return cond.call()

func hop_to(feet: Variant, double: bool = false, held: int = 18, limit: int = 140) -> bool:
	var pressed := 0
	var doubled := not double
	var target := func() -> Vector2: return feet.call() if feet is Callable else feet
	_jump = true
	for i in limit:
		var dx: float = target.call().x - r.global_position.x
		_axis = clampf(dx / 28.0, -1.0, 1.0)
		_sprint = absf(dx) > 160.0
		pressed += 1
		if pressed == held:
			_jump = false
		if not doubled and pressed > held + 2 and r.velocity.y > -60.0:
			doubled = true
			_jump = true
			pressed = held - 10
		await frames(1)
		if r.state == Runner.State.HANG:
			_jump = false
			await frames(1)
			_jump = true
			pressed = 0
			continue
		if OS.get_environment("FINALE_LOG") == "2":
			note("hop frame %d axis=%.2f jump=%s" % [i, _axis, _jump])
		if (i > 4 and r.is_on_floor()) or r.state == Runner.State.DEAD:
			break
	_jump = false
	_axis = 0.0
	_sprint = false
	await frames(1)
	return r.is_on_floor()

func advance(cond: Callable, sprint: bool = false, limit: int = 900) -> bool:
	for i in limit:
		if cond.call() or r.state == Runner.State.DEAD:
			return cond.call()
		hold(1.0, sprint)
		if r.is_on_floor() and r.is_on_wall():
			await jump(16)
		else:
			await frames(1)
	return cond.call()

func note(label: String) -> void:
	if OS.get_environment("FINALE_LOG") != "":
		print("      %s at %s v=%s state=%d floor=%s" % [label, r.global_position.round(), r.velocity.round(), r.state, r.is_on_floor()])

func x_past(x: float) -> Callable:
	return func() -> bool: return r.global_position.x >= x

func machine(id: String) -> FinaleMachine:
	for m in get_tree().get_nodes_in_group("finale_machine"):
		if m.switch_id == id:
			return m
	return null

# --------------------------------------------------------------- guardian
## The YOU pointer glides to `to` over `n` frames (it is the guardian's aim).
func point(to: Vector2, n: int = 14) -> void:
	var from := to + Vector2(160, -120) if pointer.x == INF else pointer
	for i in n:
		var k := float(i + 1) / float(n)
		pointer = from.lerp(to, 1.0 - (1.0 - k) * (1.0 - k))
		hub.aim_at_world(pointer)
		await frames(1)

func place(at: Vector2, path := PackedVector2Array()) -> void:
	await point(at, 8)
	main.guardian.select_slot(1)
	main.guardian.place_path = path
	main.guardian.use_active(at)
	main.guardian.place_path = PackedVector2Array()

func draw_stroke(a: Vector2, b: Vector2, n: int = 12) -> void:
	await point(a, 6)
	stroke = PackedVector2Array([a])
	for i in n:
		pointer = a.lerp(b, float(i + 1) / float(n))
		stroke.append(pointer)
		await frames(1)
	var centre := (a + b) * 0.5
	main.guardian.select_slot(1)
	main.guardian.place_path = PackedVector2Array([a - centre, b - centre])
	main.guardian.use_active(centre)
	main.guardian.place_path = PackedVector2Array()
	stroke = PackedVector2Array()

func shoot(at: Vector2) -> void:
	await point(at, 6)
	main.guardian.select_slot(3)
	hub.aim_at_world(at)
	main.guardian.use_active(at)

func _draw() -> void:
	if stroke.size() > 1:
		draw_polyline(stroke, Color(0.2, 0.6, 1.0, 0.35), 22, true)
		draw_polyline(stroke, Color(0.85, 0.95, 1.0), 5, true)
	if pointer.x != INF:
		# The guardian's pointer: a blue hand-cursor badge reading YOU.
		var p := pointer
		draw_circle(p, 26, Color(0.15, 0.55, 1.0, 0.25))
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(10, 30), p + Vector2(17, 21), p + Vector2(30, 32),
			p + Vector2(35, 27), p + Vector2(23, 15), p + Vector2(33, 10)]), Color("2f8cff"))
		draw_polyline(PackedVector2Array([p, p + Vector2(10, 30), p + Vector2(17, 21), p + Vector2(30, 32),
			p + Vector2(35, 27), p + Vector2(23, 15), p + Vector2(33, 10), p]), Color.WHITE, 3, true)
		draw_string(ThemeDB.fallback_font, p + Vector2(-34, -16), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("2f8cff"))

# ----------------------------------------------------------------- camera
func _process(delta: float) -> void:
	queue_redraw()
	if main == null or not is_instance_valid(main) or current.is_empty():
		return
	var cam: Dictionary = current["camera"]
	var k := clampf(float(Engine.get_process_frames() - current_start) / 60.0, 0.0, 1.0)
	var zoom: Array = cam["zoom"]
	var z := lerpf(float(zoom[0]), float(zoom[1]), smoothstep(0.0, 1.0, k))
	var target := _focus
	match String(cam["mode"]):
		"fixed":
			target = cam["at"]
			if cam.has("pan_to"):
				target = (cam["at"] as Vector2).lerp(cam["pan_to"], smoothstep(0.0, 1.0, k))
		"follow":
			target = r.global_position + (cam["at"] as Vector2)
		"track_x":
			target = Vector2(r.global_position.x + (cam["at"] as Vector2).x, (cam["at"] as Vector2).y)
		"track_y":
			target = Vector2((cam["at"] as Vector2).x, r.global_position.y + (cam["at"] as Vector2).y)
		"between":
			var other: FinaleMachine = machine(String(cam["target"]))
			target = r.global_position.lerp(other.centre() if other != null and other.state > 0 else r.global_position, 0.45) + Vector2(0, -40)
	_focus = _focus.lerp(target, minf(1.0, delta * 9.0)) if String(cam["mode"]) != "fixed" else target
	main.camera.global_position = _focus
	main.camera.zoom = Vector2.ONE * z
	main.camera.ignore_rotation = false
	main.camera.rotation = float(cam.get("rotation", 0.0))
	var shake := float(cam.get("shake", 0.0)) * (1.0 - k) + FinaleFx._shake
	main.camera.offset = Vector2(sin(Engine.get_process_frames() * 1.9), cos(Engine.get_process_frames() * 2.3)) * shake
	_evaluate()

# ----------------------------------------------------------------- shots
func shot(n: int) -> void:
	await _close_shot()
	current = by_number[n].duplicate()
	current_start = Engine.get_process_frames()
	if String(current["camera"]["mode"]) == "fixed":
		_focus = current["camera"]["at"]
	elif r != null:
		_focus = r.global_position
	var cam: Dictionary = current["camera"]
	var camera := {"mode": cam["mode"], "zoom": cam["zoom"]}
	for k in ["at", "pan_to"]:
		if cam.has(k):
			camera[k] = [cam[k].x, cam[k].y]
	for k in ["rotation", "shake", "target"]:
		if cam.has(k):
			camera[k] = cam[k]
	var overlay := {}
	for k in current.get("overlay", {}):
		var rr: Rect2 = current["overlay"][k]
		overlay[k] = [rr.position.x, rr.position.y, rr.size.x, rr.size.y]
	report.append({"shot": n, "name": current["name"], "t": current["t"], "take": current["take"],
		"area": current["area"], "runner_start": [current["runner"].x, current["runner"].y],
		"setup": current["setup"], "camera": camera, "move": current["move"],
		"phenomenon": current["phenomenon"], "overlay": overlay, "slow_motion": current.get("slow_motion", false),
		"start_frame": current_start, "success": false, "check": current["success"]["id"],
		"means": current["success"]["means"], "key_frame": -1, "still": "shot_%02d.png" % n})
	print("SHOT %02d %s" % [n, current["name"]])

func _close_shot() -> void:
	if current.is_empty():
		return
	var row: Dictionary = report[-1]
	row["frames"] = Engine.get_process_frames() - current_start
	row["runner_end"] = [r.global_position.x, r.global_position.y]
	if not row["success"]:
		_evaluate()
	if rendering and row["key_frame"] < 0:
		await _still("shot_%02d_end" % row["shot"])
	print("   -> %s %s" % ["OK  " if row["success"] else "MISS", row["means"]])
	current = {}

func _still(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")

func _screen(p: Vector2) -> Vector2:
	return (p - main.camera.global_position) * main.camera.zoom + Vector2(640, 360)

func _evaluate() -> void:
	if current.is_empty() or report.is_empty():
		return
	var row: Dictionary = report[-1]
	if row["success"] and String(row["check"]) != "upper_half":
		return
	var ok := _check(String(row["check"]))
	if String(row["check"]) == "upper_half":
		# Whole-cut condition: fails if the runner ever leaves the upper half.
		if not _flags.has("upper_%d" % row["shot"]):
			_flags["upper_%d" % row["shot"]] = true
			row["success"] = true
		if not ok:
			row["success"] = false
			row["violation"] = [r.global_position.x, r.global_position.y]
		elif row["key_frame"] < 0 and Engine.get_process_frames() - current_start > 30:
			row["key_frame"] = Engine.get_process_frames()
			row["runner_world"] = [r.global_position.x, r.global_position.y]
			row["camera_world"] = [main.camera.global_position.x, main.camera.global_position.y, main.camera.zoom.x]
			if rendering:
				_still.call_deferred("shot_%02d" % row["shot"])
		return
	if ok:
		row["success"] = true
		row["key_frame"] = Engine.get_process_frames()
		row["runner_screen"] = [_screen(r.global_position).x, _screen(r.global_position).y]
		row["runner_world"] = [r.global_position.x, r.global_position.y]
		row["camera_world"] = [main.camera.global_position.x, main.camera.global_position.y, main.camera.zoom.x]
		if rendering:
			_still.call_deferred("shot_%02d" % row["shot"])

func _near_enemies(kind: String, radius: float) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("finale_enemy"):
		if e.kind == kind and e.global_position.distance_to(r.global_position) < radius:
			n += 1
	return n

func _check(id: String) -> bool:
	var p := r.global_position
	match id:
		"running_downhill":
			return r.velocity.x > 150.0 and p.x > 300.0 and p.x < 900.0
		"cleared_enemy":
			return _flags.get("cleared_enemy", false)
		"leapt_cliff":
			return not r.is_on_floor() and p.x > 1560.0 and p.y < 1200.0
		"falling_short":
			return not r.is_on_floor() and p.y > 1100.0 and p.x < 2240.0 and r.velocity.y > 0.0
		"pointer_near_runner":
			return pointer.x != INF and pointer.distance_to(p) < 200.0
		"built_steps":
			return main.guardian.holograms_of(Hologram.Kind.PLATFORM).size() >= 2
		"landed_on_hologram":
			return _landed_holo
		"on_hologram_rising":
			return _landed_holo and r.is_on_floor() and p.y < float(_flags.get("catch_y", 9999.0)) - 40.0
		"on_far_bank":
			return r.is_on_floor() and p.x > 2240.0 and absf(p.y + 23.0 - 1040.0) < 4.0
		"strike_called":
			return machine("storm").state & 1 != 0
		"span_broken":
			return machine("storm")._spans[3].collision_layer == 0
		"on_high_span":
			return r.is_on_floor() and p.y < 930.0 and machine("storm")._spans[7].collision_layer == 0
		"ruins_revealed":
			return p.x > 6400.0 and p.y > 1100.0
		"ducked_block":
			var pend := machine("ruin_pendulum")
			var c: Vector2 = pend.global_position + pend.centre_at(Clock.tick)
			if r.crouching() and absf(c.x - p.x) < 60.0 and c.y > 1000.0:
				_flags["ducked"] = true
			return _flags.get("ducked", false) and r.hp == Balance.RUNNER_MAX_HP
		"shaft_fall":
			return machine("ruin_floor").state == 1 and p.y > 1500.0 and not r.is_on_floor()
		"on_lava_platform":
			return r.is_on_floor() and p.x > 8080.0 and p.x < 8880.0
		"ball_chasing":
			var ball := machine("magma")
			return ball.state == 1 and ball.centre().x < p.x and p.x - ball.centre().x < 450.0
		"on_swing":
			return r.is_on_floor() and (machine("swing_a").runner_on(machine("swing_a")._deck) or machine("swing_b").runner_on(machine("swing_b")._deck))
		"riding_lift":
			for id2 in ["lift_2440", "lift_2100", "lift_1800"]:
				var lift := machine(id2)
				if lift.runner_on(lift._slab) and lift.lift_at(Clock.tick) > 20.0 and lift.lift_at(Clock.tick) < float(lift.data["rise"]) - 5.0:
					return true
			return false
		"running_on_train":
			var line := machine("rail")
			return line._riding() >= 0 and line.train_speed(0, line.beat()) > 200.0 and absf(r.velocity.x) > 100.0
		"train_leap":
			return _flags.get("leapt_trains", false)
		"crate_dropped":
			var line := machine("rail")
			var at: Array = line.crate_at(1, line.beat())
			return at[1] == 2 and (at[0] as Vector2).distance_to(p) < 300.0 and r.hp >= int(_flags.get("hp_at_23", 0))
		"in_hive":
			return p.x > 15700.0 and p.y > 1100.0
		"stuck_in_honey":
			return r.is_on_floor() and absf(r.velocity.x) <= 130.0 and p.x > 15760.0 and p.x < 15900.0 and _axis > 0.5
		"swarm_close":
			return _near_enemies("wax_wisp", 320.0) >= 2 and p.y < 1250.0
		"bubble_launch":
			var shaft := machine("hive_shaft")
			if shaft.squash() > 0.2:
				_flags["squashed"] = true
			return _flags.get("squashed", false) and r.velocity.y < -800.0
		"in_shaft":
			return p.x > 16830.0 and p.x < 16970.0 and p.y < 900.0 and r.velocity.y < -300.0
		"membrane_broken":
			return machine("hive_shaft").state == 1
		"on_tilted_ledge":
			return r.is_on_floor() and p.x > 17620.0 and p.x < 17880.0
		"giant_rising":
			var g := machine("giant")
			return g.state == 1 and g.rise() < g.SUNK * 0.5
		"jumped_mace":
			var g := machine("giant")
			if g.state == 1 and not r.is_on_floor() and absf(g.mace_centre().x - p.x) < 70.0 and g.mace_centre().y > p.y + 40.0:
				_flags["over_mace"] = true
			return _flags.get("over_mace", false) and r.hp == Balance.RUNNER_MAX_HP
		"on_rib_bridge":
			for s in get_tree().get_nodes_in_group("finale_slope"):
				if s.skin == "bone" and r.is_on_floor() and s.top_at(p.x) < INF and absf(s.top_at(p.x) - (p.y + 23.0)) < 8.0:
					return true
			return false
		"drones_close":
			return _near_enemies("skull_drone", 450.0) >= 3
		"beast_erupted":
			var b := machine("beast")
			return b.state >= 1 and b.broken()
		"pillars_and_jets":
			var b := machine("beast")
			var falling := false
			for m in get_tree().get_nodes_in_group("finale_machine"):
				if m.kind == "bone_pillar" and m.drop() > 20.0:
					falling = true
			var jets := false
			for id3 in ["sandjet_23205", "sandjet_23610"]:
				if machine(id3).active():
					jets = true
			return b.state == 2 and falling and jets
		"jaws_snapped":
			var b := machine("beast")
			return b._snapped and p.x > float(b.data["gate_x"])
		"runner_below_title":
			return _screen(p).y > 720.0 * 0.55 and absf(r.velocity.x) > 100.0
		"drone_pursuit":
			return _flags.get("drone_seen", false) and _flags.get("hopped_saw", false)
		"height_changes":
			return int(_flags.get("height_changes", 0)) >= 2
		"knocked_into_saw":
			return _cause == "saw" and _flags.get("hurt_first", false)
		"respawned":
			return _flags.get("respawned", false) and absf(r.velocity.x) > 50.0
		"awkward_blocks":
			var live: Array = main.guardian.holograms_of(Hologram.Kind.PLATFORM)
			var slanted := false
			for h in live:
				if h.path.size() >= 2:
					var d: Vector2 = h.path[-1] - h.path[0]
					if absf(atan2(d.y, d.x)) > deg_to_rad(20.0):
						slanted = true
			return live.size() >= 2 and slanted
		"recovered":
			return _flags.get("touched_block", false) and p.x > 26700.0 and r.is_on_floor()
		"upper_half":
			return _screen(p).y < 720.0 * 0.48
	return false

# ------------------------------------------------------------------- takes
func begin_take(at: Vector2, checkpoint: int) -> void:
	release()
	cover = true
	cover_radius = 520.0
	pointer = Vector2(INF, INF)
	_flags.clear()
	_landed_holo = false
	_cause = ""
	main.guardian.clear_constructs()
	GameState.checkpoint_index = checkpoint
	GameState.checkpoint_position = Stage.checkpoints()[checkpoint - 1] + Vector2(0, 26) if checkpoint > 0 else Stage.start()
	r.respawn(at)
	main.level.reset_to_checkpoint()
	await frames(4)

func run() -> void:
	Stage.use(Stage.Which.FINALE)
	main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	for n in ["NetPanel", "Hud", "Quit", "Scope", "PlacementPreview"]:
		var node := main.get_node_or_null(n)
		if node != null:
			node.queue_free()
	hub = main.input_hub
	hub.scripted = true
	r = main.runner
	# The director owns the camera; main still runs the respawn timer.
	main.set_physics_process(false)
	get_tree().physics_interpolation = true
	if save_frames:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
	await frames(4)
	for take in ["opening", "storm", "sand", "volcano", "rail", "hive", "giant", "bone", "title", "oops", "end"]:
		if not only.is_empty() and not only.has(take):
			continue
		print("=== TAKE ", take)
		await call("take_" + take)
		await _close_shot()
		Engine.time_scale = 1.0
	var ok := 0
	for row in report:
		if row["success"]:
			ok += 1
	var file := FileAccess.open(OUT + "shots_report.json", FileAccess.WRITE)
	var cps: Array = []
	for cp in Stage.checkpoints():
		cps.append([cp.x, cp.y])
	file.store_string(JSON.stringify({"stage": "1-10", "rendered": rendering, "shots": report,
		"passed": ok, "total": report.size(), "zones": Stage.data().zones(), "checkpoints": cps,
		"start": [Stage.start().x, Stage.start().y], "goal": [Stage.goal().x, Stage.goal().y]}, "\t"))
	print("finale PV: %d / %d cuts shot successfully" % [ok, report.size()])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if ok == report.size() else 1)

func take_opening() -> void:
	await begin_take(Vector2(160, 877), 0)
	cover = false
	var bug: Node2D = null
	for e in get_tree().get_nodes_in_group("finale_enemy"):
		if e.kind == "burrbug" and absf(e.global_position.x - 1460.0) < 300.0:
			bug = e
	await shot(1)
	hold(1.0, true)
	await until(x_past(880), 200)
	await shot(2)
	await until(func() -> bool: return bug.global_position.x - r.global_position.x < 125.0, 200)
	await jump(16)
	hold(1.0, true)
	await until(func() -> bool: return r.global_position.x > bug.global_position.x + 40.0 and r.is_on_floor(), 120)
	_flags["cleared_enemy"] = r.hp == Balance.RUNNER_MAX_HP
	cover = true
	await until(x_past(1380), 100)
	await shot(3)
	hold(1.0, false)
	await until(x_past(1528), 120)
	await jump(18)
	await frames(12)
	await jump(10)
	await until(func() -> bool: return r.global_position.y > 1100.0, 120)
	# Slow motion: the real simulation, slowed, with interpolated frames.
	Engine.time_scale = 0.2
	await shot(4)
	hold(0.0)
	await frames(18)
	await shot(5)
	await frames(18)
	await shot(6)
	await point(r.global_position + Vector2(70, 30), 18)
	await shot(7)
	var under := Vector2(r.global_position.x + 20.0, r.global_position.y + 90.0)
	await place(under)
	await place(under + Vector2(160, -95))
	await until(func() -> bool: return r.is_on_floor(), 120)
	Engine.time_scale = 1.0
	await shot(8)
	_flags["catch_y"] = r.global_position.y
	await frames(16)
	await shot(9)
	var feet := r.global_position.y + 23.0
	await hop_to(Vector2(under.x + 160.0, feet - 95.0))
	# The first slab is behind now: YOU recycles it as the last step up.
	await place(Vector2(minf(r.global_position.x + 160.0, 2150.0), r.global_position.y + 23.0 - 80.0))
	await frames(22)
	await hop_to(Vector2(minf(r.global_position.x + 160.0, 2150.0), r.global_position.y + 23.0 - 80.0))
	await shot(10)
	await hop_to(Vector2(2320, 1040), true)
	hold(1.0)
	await until(x_past(2480), 120)
	release()
	await frames(20)

func take_storm() -> void:
	await begin_take(Vector2(2950, 1017), 1)
	await shot(11)
	hold(1.0, true)
	await until(x_past(3420), 200)
	await shot(12)
	await until(x_past(3630), 200)
	hold(0.0)
	await until(func() -> bool: return machine("storm")._spans[3].collision_layer == 0, 90)
	await frames(30)
	# Back up for a run-up, then leap the fresh gap at speed.
	hold(-1.0)
	await until(func() -> bool: return r.global_position.x < 3480.0, 90)
	hold(1.0, true)
	await until(x_past(3650), 90)
	await hop_to(Vector2(3930, 1040))
	note("over the first gap")
	await shot(13)
	hold(1.0, true)
	await until(x_past(4120), 200)
	note("before rod")
	await shoot(machine("storm").global_position + machine("storm")._rod)
	note("after rod")
	for feet in [Vector2(4175, 920), Vector2(4385, 800)]:
		await hop_to(feet)
		note("hop %s" % feet)
	await frames(70)

func take_sand() -> void:
	await begin_take(Vector2(6050, 1017), 2)
	await shot(14)
	hold(1.0)
	await until(x_past(6470), 300)
	await until(func() -> bool: return r.is_on_floor(), 60)
	await shot(15)
	_crouch = true
	await until(x_past(6780), 600)
	hold(0.0)
	await until(func() -> bool: return _flags.get("ducked", false), 240)
	await frames(10)
	hold(1.0)
	await until(x_past(7020), 600)
	_crouch = false
	await shot(16)
	await until(x_past(7280), 120)
	hold(0.0)
	await until(func() -> bool: return r.global_position.y > 2000.0, 240)
	await frames(10)

func take_volcano() -> void:
	await begin_take(Vector2(7900, 2677), 3)
	await shot(17)
	for step in [[8030.0, Vector2(8145, 2660)], [8180.0, Vector2(8360, 2560)]]:
		hold(1.0)
		await until(x_past(step[0]), 200)
		await hop_to(step[1])
	await frames(20)
	for step in [[8395.0, Vector2(8565, 2620)], [8600.0, Vector2(8790, 2520)]]:
		hold(1.0)
		await until(x_past(step[0]), 200)
		await hop_to(step[1])
	await shot(18)
	hold(1.0, true)
	await until(x_past(9330), 200)
	await hop_to(Vector2(9480, 2420), true)
	await until(func() -> bool: return machine("magma").sunk(), 400)
	await shot(19)
	var moving_left := func(m: FinaleMachine) -> bool: return m.offset_at(Clock.tick + 1).x < m.offset_at(Clock.tick).x
	await until(func() -> bool: return machine("swing_a")._deck.global_position.x < 9800.0 and moving_left.call(machine("swing_a")), 400)
	await hop_to(func() -> Vector2: return machine("swing_a")._deck.global_position + Vector2(0, -12))
	await frames(40)
	await begin_take(Vector2(10820, 2397), 5)
	await shot(20)
	var lift := func() -> FinaleMachine: return machine("lift_2440")
	await until(func() -> bool: return lift.call().lift_at(Clock.tick) < 0.5 and lift.call().warning_at(Clock.tick), 400)
	await hop_to(Vector2(10990, 2440))
	await until(func() -> bool: return lift.call().lift_at(Clock.tick) >= 339.5, 200)
	await hop_to(Vector2(11150, 2100))
	await frames(20)

func rail() -> FinaleMachine:
	return machine("rail")

func take_rail() -> void:
	await begin_take(Vector2(11250, 1477), 6)
	await until(func() -> bool: return rail().beat() > 4.3 and rail().beat() < 5.0, 1700)
	note("parked beat %.2f train0 rear %.0f" % [rail().beat(), rail().car_x(0, 0, rail().beat())])
	hold(1.0)
	for i in 20:
		await frames(10)
		note("boarding %d beat %.2f" % [i, rail().beat()])
		if r.is_on_floor() and r.global_position.x > 11560.0 and r.global_position.y > 1520.0:
			break
	note("boarded")
	release()
	# Wait on the rear car for the train to pull away, then run the roofs.
	await until(func() -> bool: return rail().beat() > 9.3, 600)
	await shot(21)
	var loco_end := func() -> float: return rail().car_x(0, 3, rail().beat()) + 320.0
	await advance(func() -> bool: return r.is_on_floor() and r.global_position.x > loco_end.call() - 40.0, true, 600)
	note("front of the train (beat %.2f)" % rail().beat())
	await shot(22)
	var b_rear := func() -> float: return rail().car_x(1, 0, rail().beat())
	await hop_to(func() -> Vector2: return Vector2(b_rear.call() + 120.0, rail().roof_y(1, 0)), true)
	_flags["leapt_trains"] = r.global_position.x > b_rear.call() and r.is_on_floor()
	await shot(23)
	_flags["hp_at_23"] = r.hp
	release()
	var drop: Dictionary = rail()._drops[1]
	await until(func() -> bool: return rail().beat() > float(drop["land"]) + 0.3, 900)
	await frames(20)
	await shot(24)
	await advance(func() -> bool: return r.global_position.x > rail().car_x(1, 2, rail().beat()) + 200.0, true, 400)
	release()
	await frames(20)

func take_hive() -> void:
	await begin_take(Vector2(15450, 1267), 7)
	await shot(25)
	hold(1.0)
	await until(x_past(15700), 200)
	await shot(26)
	await until(x_past(15880), 300)
	await shot(27)
	cover_radius = 150.0
	await until(x_past(15990), 300)
	for feet in [Vector2(16030, 1120), Vector2(16195, 990), Vector2(16380, 1000)]:
		await hop_to(feet, true)
	hold(1.0)
	await until(x_past(16620), 200)
	await until(func() -> bool: return r.is_on_floor(), 60)
	await shot(28)
	cover_radius = 520.0
	await until(x_past(16880), 600)
	hold(0.0)
	await until(func() -> bool: return r.global_position.y < 1000.0, 200)
	await shot(29)
	await until(func() -> bool: return r.global_position.y < 450.0, 200)
	await shot(30)
	await until(func() -> bool: return machine("hive_shaft").state == 1, 200)
	hold(1.0)
	await until(func() -> bool: return r.is_on_floor(), 200)
	release()
	await frames(20)

func take_giant() -> void:
	await begin_take(Vector2(17200, 177), 8)
	await shot(31)
	hold(1.0, true)
	await until(x_past(17460), 200)
	await hop_to(Vector2(17760, 300))
	await frames(20)
	await hop_to(Vector2(18050, 300), true)
	hold(1.0)
	await until(x_past(18300), 200)
	release()
	await shot(32)
	await until(func() -> bool: return machine("giant").slab_angle() >= PI * 0.5 - 0.01, 300)
	await shot(33)
	hold(1.0)
	await until(x_past(18440), 100)
	await hop_to(Vector2(18620, 240))
	release()
	# Wait on the bridge for the mace to come round low, then jump it.
	await until(func() -> bool: return absf(machine("giant").mace_angle()) < 0.45 and machine("giant").mace_centre().x < r.global_position.x - 120.0 \
		and machine("giant").mace_angle() > machine("giant").mace_angle(Clock.tick - 1), 400)
	await jump(18)
	await until(func() -> bool: return r.is_on_floor(), 90)
	hold(1.0, true)
	await until(x_past(18980), 120)
	release()
	await frames(10)

func take_bone() -> void:
	await begin_take(Vector2(19300, 277), 9)
	cover_radius = 160.0
	await shot(34)
	hold(1.0)
	await until(x_past(19800), 300)
	await until(x_past(20280), 300)
	await hop_to(Vector2(20360, 320))
	await shot(35)
	hold(1.0)
	await until(x_past(20600), 300)
	await shot(36)
	cover = false
	await until(x_past(20950), 300)
	await frames(20)
	await begin_take(Vector2(21300, 257), 10)
	await shot(37)
	cover = true
	hold(1.0)
	await until(x_past(21700), 200)
	release()
	await until(func() -> bool: return machine("beast").broken(), 60)
	await frames(100)
	hold(1.0, true)
	await until(x_past(21880), 100)
	await hop_to(Vector2(22400, 300), true)
	hold(1.0, true)
	await until(x_past(22560), 200)
	await shot(38)
	for feet in [Vector2(22710, 320), Vector2(22905, 260), Vector2(23105, 330), Vector2(23305, 240)]:
		await hop_to(feet + Vector2(25, 0))
	await shot(39)
	for feet in [Vector2(23510, 300), Vector2(23710, 270)]:
		await hop_to(feet + Vector2(25, 0))
	await hop_to(Vector2(24080, 300), true)
	await until(func() -> bool: return machine("beast")._snapped, 200)
	await frames(30)

func take_title() -> void:
	await begin_take(Vector2(24250, 277), 11)
	# Drones keep pursuing; the guardian only intercepts a dive.
	cover_radius = 150.0
	await shot(40)
	hold(1.0)
	await until(x_past(25220), 400)
	await shot(41)
	hold(0.0)
	await until(func() -> bool: return _flags.get("drone_seen", false), 240)
	cover_radius = 340.0
	await until(func() -> bool: return machine("saw_a").centre().x < 60.0 and machine("saw_a").centre(Clock.tick + 1).x < machine("saw_a").centre().x, 300)
	await hop_to(Vector2(25440, 520))
	_flags["hopped_saw"] = r.state != Runner.State.DEAD
	hold(1.0, true)
	await until(x_past(25630), 120)
	await shot(42)
	# Time the jump between cannon shots, as a player would.
	release()
	await until(func() -> bool:
		for shot_node in get_tree().get_nodes_in_group("projectile"):
			if (shot_node as Node2D).global_position.distance_to(r.global_position) < 520.0:
				return false
		return true, 240)
	var floors := [r.global_position.y]
	for feet in [Vector2(25900, 460), Vector2(26260, 560)]:
		await hop_to(feet)
		note("floor %.0f (prev %.0f)" % [r.global_position.y, float(floors[-1])])
		if absf(r.global_position.y - float(floors[-1])) >= 55.0:
			_flags["height_changes"] = int(_flags.get("height_changes", 0)) + 1
		floors.append(r.global_position.y)
		hold(1.0)
		await until(x_past(feet.x + 120.0), 120)
	release()
	await frames(10)

func take_oops() -> void:
	await begin_take(Vector2(26414, 537), 12)
	cover = false
	await shot(43)
	# A brass drone swoops from behind while the runner looks back at it.
	var drone: FinaleEnemy = null
	for e in get_tree().get_nodes_in_group("finale_enemy"):
		if e.kind == "brass_drone":
			if drone == null or e.global_position.distance_to(r.global_position) < drone.global_position.distance_to(r.global_position):
				drone = e
	drone.global_position = r.global_position + Vector2(-220, -40)
	hold(-0.3)
	await frames(6)
	release()
	var hp := r.hp
	for i in 42:
		await frames(10)
		note("oops %d drone d=%.0f inv=%s" % [i, drone.global_position.distance_to(r.global_position) if is_instance_valid(drone) else -1.0, r.is_invulnerable()])
		if r.hp < hp or r.state == Runner.State.DEAD:
			break
	_flags["hurt_first"] = r.hp < hp
	await until(func() -> bool: return r.state == Runner.State.DEAD, 90)
	await frames(30)
	await shot(44)
	await until(func() -> bool: return r.state != Runner.State.DEAD, 200)
	_flags["respawned"] = r.global_position.distance_to(Stage.checkpoints()[11] + Vector2(0, 27)) < 40.0
	cover = true
	hold(-1.0)
	await frames(20)
	release()
	await shot(45)
	await place(Vector2(26520, 400), PackedVector2Array([Vector2(-50, 40), Vector2(50, -40)]))
	await frames(10)
	await place(Vector2(26640, 320))
	await frames(20)
	await shot(46)
	Events.runner_landed_on_hologram.connect(func(_h: Node2D) -> void: _flags["touched_block"] = true)
	hold(1.0)
	await until(x_past(26360), 60)
	await hop_to(Vector2(26520, 380))
	await hop_to(Vector2(26660, 430))
	await hop_to(Vector2(26800, 420))
	release()
	await frames(20)

func take_end() -> void:
	await begin_take(Vector2(26760, 397), 12)
	await shot(47)
	hold(1.0)
	await until(x_past(27030), 200)
	hold(0.0)
	await until(func() -> bool: return machine("saw_c").centre().y > 95.0, 200)
	await until(func() -> bool: return machine("saw_c").centre().y < 45.0, 200)
	hold(1.0, true)
	await until(x_past(27260), 100)
	await shot(48)
	var lift: MovingPlatform = null
	for i in 10:
		for node in main.level.find_children("*", "", true, false):
			if node is MovingPlatform:
				lift = node
		if lift != null:
			break
		await frames(1)
	note("lift found %s" % [lift != null])
	release()
	await until(func() -> bool: return lift.global_position.y > 500.0, 300)
	note("lift low %s" % lift.global_position)
	await hop_to(func() -> Vector2: return lift.global_position + Vector2(0, -13))
	note("on lift?")
	await until(func() -> bool: return lift.global_position.y < 400.0, 300)
	await hop_to(Vector2(27760, 480))
	hold(1.0)
	await until(x_past(27950), 120)
	await shot(49)
	await until(x_past(28100), 300)
	await hop_to(Vector2(28250, 420))
	hold(1.0)
	await until(func() -> bool: return r.cleared, 300)
	await frames(30)
