extends Node2D
## Director for the 1-10 PV (49 cuts, one second each). It plays the cuts in
## the real stage -- real Runner physics, real Guardian abilities, live
## machines and enemies -- from scripted controller input, frames each cut
## with its own camera, and records exactly 60 on-air frames per cut.
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --fixed-fps 60 --resolution 1280x720 \
##       --write-movie build/promotion/stage-1-10/pv/takes.avi \
##       res://tools/promotion/capture_finale_pv.tscn -- [--take=opening,...]
##
## Nothing here looks at the picture. Play is driven by code: the runner
## moves only through InputHub.drive_runner, the guardian acts only through
## Guardian.use_active, and every cut's success is read from game state
## (machine states, Events, positions). The camera, the slow motion and the
## screen layers (call card, YOU pointer, title, end cards) belong to the
## director. Headless runs do the same play and checks without images.
##
## Output (build/promotion/stage-1-10/pv/):
##   shots_report.json  per cut: on-air frame range, intent, what happened,
##                      visibility measurements (runner size on screen,
##                      subject on screen), verdict, and every game event and
##                      sound that fired on air; plus the slate frame.
## tools/promotion/render_finale_pv.py cuts the recording with that report.

const MainScene: PackedScene = preload("res://src/main.tscn")
const Overlay := preload("res://tools/promotion/pv_overlay.gd")
const SHOTS := preload("res://src/levels/finale_shots.gd")
const OUT := "res://build/promotion/stage-1-10/pv/"
const CUT_FRAMES := 60
const VIEW := Vector2(1280, 720)

var main: Node2D
var r: Runner
var hub: InputHub
var rendering := false
var only: Array = []

# ------------------------------------------------------------- input state
var _axis := 0.0
var _sprint := false
var _jump := false
var _crouch := false
## The guardian's aim, in world space; INF while YOU is not on screen.
var pointer := Vector2(INF, INF)
var stroke := PackedVector2Array()
## The guardian snipes enemies close to the runner (co-op cover), when on.
var cover := false
var cover_radius := 420.0

# --------------------------------------------------------------- cut state
var shots := {}
var report: Array[Dictionary] = []
var events: Array[Dictionary] = []
var row: Dictionary = {}
var on_air := false
var cut_frames := 0
var _pending_cut := 0
var _queued: Dictionary = {}
var _flags := {}
var slate_frame := -1
var _slate := false

# ------------------------------------------------------------------ camera
var cam: Dictionary = {}
var _cam_pos := Vector2.ZERO
var _cam_zoom := 1.0
var _cam_rot := 0.0
var _cam_age := 0
var _shake := 0.0
## Time scale ramp: from, to, frames, age.
var _ramp := [1.0, 1.0, 0, 0]
var _hitstop := 0
var _hitstop_resume := 1.0

# ------------------------------------------------------------------ layers
var overlay: Overlay
var title: Overlay
var _pointer_alpha_to := 0.0

func _ready() -> void:
	process_priority = 250
	z_index = 50
	for s in SHOTS.all():
		shots[int(s["shot"])] = s
	rendering = DisplayServer.get_name() != "headless"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--take="):
			only = a.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var top := CanvasLayer.new()
	top.layer = 40
	add_child(top)
	overlay = Overlay.new()
	top.add_child(overlay)
	var behind := CanvasLayer.new()
	behind.layer = -5
	add_child(behind)
	title = Overlay.new()
	title.title_only = true
	behind.add_child(title)
	_connect_log()
	call_deferred("run")

# --------------------------------------------------------------- event log
func log_event(ev: String, detail: String = "") -> void:
	var at := r.global_position if r != null else Vector2.ZERO
	events.append({"frame": Engine.get_process_frames(), "cut": int(row.get("shot", 0)) if on_air else 0,
		"cut_frame": cut_frames if on_air else -1, "ev": ev, "detail": detail,
		"runner": [roundf(at.x), roundf(at.y)], "tick": Clock.tick})
	if OS.get_environment("FINALE_LOG") != "":
		print("      [%s] %s %s at %s" % [("cut %d f%d" % [row.get("shot", 0), cut_frames]) if on_air else "off-air", ev, detail, at.round()])

func _connect_log() -> void:
	Audio.played.connect(func(key: String) -> void: log_event("sound", key))
	Events.runner_jumped.connect(func() -> void: log_event("jump"))
	Events.runner_air_jumped.connect(func(_p: Vector2) -> void: log_event("air_jump"))
	Events.runner_landed.connect(func(hard: bool) -> void: log_event("land", "hard" if hard else ""))
	Events.runner_damaged.connect(func(hp: int, _m: int) -> void: log_event("damaged", "hp=%d" % hp))
	Events.runner_died.connect(func(cause: String) -> void: log_event("died", cause))
	Events.runner_respawned.connect(func(i: int) -> void: log_event("respawned", "checkpoint %d" % i))
	Events.runner_landed_on_hologram.connect(func(_h: Node2D) -> void:
		_flags["on_holo"] = true
		log_event("landed_on_hologram"))
	Events.hologram_spawned.connect(func(kind: int, at: Vector2) -> void: log_event("hologram", "kind=%d at %s" % [kind, at.round()]))
	Events.rescue_scored.connect(func(tier: int, _p: Vector2) -> void: log_event("rescue", "tier %d" % tier))
	Events.switch_activated.connect(func(id: String) -> void: log_event("machine", id))
	Events.enemy_killed.connect(func(e: Node2D, by: String) -> void: log_event("enemy_killed", "%s by %s" % [e.get("kind"), by]))
	Events.runner_grabbed_ledge.connect(func(_p: Vector2) -> void: log_event("ledge_grab"))
	Events.checkpoint_reached.connect(func(i: int) -> void: log_event("checkpoint", str(i)))

# ------------------------------------------------------------------- input
func _apply() -> void:
	hub.drive_runner(_axis, 1.0 if _crouch else 0.0, _jump, _sprint)

func frames(n: int) -> void:
	for i in n:
		_apply()
		await get_tree().process_frame

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

## Jump toward `feet` (a world point or a Callable giving one), steering in
## the air like a player would, optionally with the air jump at the apex.
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
		if (i > 4 and r.is_on_floor()) or r.state == Runner.State.DEAD:
			break
	_jump = false
	_axis = 0.0
	_sprint = false
	await frames(1)
	return r.is_on_floor()

func x_past(x: float) -> Callable:
	return func() -> bool: return r.global_position.x >= x

func machine(id: String) -> FinaleMachine:
	for m in get_tree().get_nodes_in_group("finale_machine"):
		if m.switch_id == id:
			return m
	return null

func feet() -> Vector2:
	return r.global_position + Vector2(0, Balance.RUNNER_SIZE.y * 0.5)

# ---------------------------------------------------------------- guardian
## The YOU pointer glides to `to` over `n` frames (it is the guardian's aim).
func point(to: Vector2, n: int = 14) -> void:
	var from := to + Vector2(160, -120) if pointer.x == INF else pointer
	_pointer_alpha_to = 1.0
	for i in n:
		var k := float(i + 1) / float(n)
		pointer = from.lerp(to, 1.0 - (1.0 - k) * (1.0 - k))
		hub.aim_at_world(pointer)
		await frames(1)

func hide_pointer() -> void:
	_pointer_alpha_to = 0.0

## Draw a platform along `path` (world points) with the YOU pointer, the way
## the guardian traces one with a finger, then build it.
func trace(path: PackedVector2Array, per_segment: int = 5) -> Hologram:
	await point(path[0], 6)
	stroke = PackedVector2Array([path[0]])
	for i in range(1, path.size()):
		for k in per_segment:
			pointer = path[i - 1].lerp(path[i], float(k + 1) / float(per_segment))
			hub.aim_at_world(pointer)
			stroke.append(pointer)
			await frames(1)
	var lo := path[0]
	var hi := path[0]
	for p in path:
		lo = lo.min(p)
		hi = hi.max(p)
	var centre := ((lo + hi) * 0.5).round()
	var local := PackedVector2Array()
	for p in path:
		local.append(p - centre)
	main.guardian.select_slot(1)
	main.guardian.place_path = local
	var before: Array = main.guardian.holograms_of(Hologram.Kind.PLATFORM)
	main.guardian.use_active(centre)
	main.guardian.place_path = PackedVector2Array()
	overlay.pointer_pop = 1.0
	stroke = PackedVector2Array()
	for h in main.guardian.holograms_of(Hologram.Kind.PLATFORM):
		if not before.has(h):
			return h
	log_event("trace_refused", str(path))
	return null

func place(at: Vector2, path := PackedVector2Array()) -> void:
	await point(at, 8)
	main.guardian.select_slot(1)
	main.guardian.place_path = path
	main.guardian.use_active(at)
	main.guardian.place_path = PackedVector2Array()
	overlay.pointer_pop = 1.0

func shoot(at: Vector2) -> void:
	await point(at, 6)
	main.guardian.select_slot(3)
	hub.aim_at_world(at)
	main.guardian.use_active(at)

func _physics_process(_delta: float) -> void:
	if not cover or r == null or main == null or not is_instance_valid(main) or Clock.tick % 4 != 0:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node2D and not e.is_queued_for_deletion() and (e as Node2D).visible \
				and (e as Node2D).global_position.distance_to(r.global_position) < cover_radius:
			main.guardian.select_slot(3)
			hub.aim_at_world((e as Node2D).global_position)
			main.guardian.use_active((e as Node2D).global_position)
			return

func _draw() -> void:
	if stroke.size() > 1:
		draw_polyline(stroke, Color(0.25, 0.65, 1.0, 0.35), 26, true)
		draw_polyline(stroke, Color(0.85, 0.95, 1.0), 6, true)

# ------------------------------------------------------------------ camera
## Camera for what follows. Keys:
##   mode   "follow" (runner + lead), "fixed" (at, optional pan_to over the
##          cut), "frame" (fit every point in `fit` with `pad` around them)
##   zoom   target zoom; zoom_from to ease from, over zoom_frames
##   offset world offset added to the follow/fixed target
##   lead   px of look-ahead along the runner's horizontal velocity
##   smooth follow stiffness (per second); 0 = locked to the target
##   rotation, shake (decaying punch), fx (how much machine shake to pass)
##   snap   true: jump straight to the new framing (a hard cut)
func camera(spec: Dictionary) -> void:
	cam = spec.duplicate()
	_cam_age = 0
	if spec.has("shake"):
		_shake = float(spec["shake"])
	if spec.get("snap", false):
		_cam_pos = _cam_target()
		_cam_zoom = float(spec.get("zoom_from", spec.get("zoom", 1.3)))
		_cam_rot = float(spec.get("rotation", 0.0))

func _cam_target() -> Vector2:
	var mode := String(cam.get("mode", "follow"))
	var off: Vector2 = cam.get("offset", Vector2.ZERO)
	match mode:
		"fixed":
			var at: Vector2 = cam["at"]
			if cam.has("pan_to"):
				var k := clampf(float(_cam_age) / float(cam.get("pan_frames", CUT_FRAMES)), 0.0, 1.0)
				at = at.lerp(cam["pan_to"], smoothstep(0.0, 1.0, k))
			return at + off
		"frame":
			var pts: Array = []
			for f in cam["fit"]:
				pts.append((f as Callable).call())
			var lo: Vector2 = pts[0]
			var hi: Vector2 = pts[0]
			for p in pts:
				lo = lo.min(p)
				hi = hi.max(p)
			return (lo + hi) * 0.5 + off
	var lead := float(cam.get("lead", 120.0)) * clampf(r.velocity.x / 400.0, -1.0, 1.0)
	return r.global_position + Vector2(lead, 0) + off

func _cam_zoom_target() -> float:
	var z := float(cam.get("zoom", 1.3))
	if String(cam.get("mode", "")) == "frame":
		var lo := Vector2(INF, INF)
		var hi := -lo
		for f in cam["fit"]:
			var p: Vector2 = (f as Callable).call()
			lo = lo.min(p)
			hi = hi.max(p)
		var pad := float(cam.get("pad", 160.0))
		var span := (hi - lo) + Vector2(pad, pad) * 2.0
		z = minf(z, minf(VIEW.x / span.x, VIEW.y / span.y))
		z = maxf(z, float(cam.get("min_zoom", 0.6)))
	if cam.has("zoom_from"):
		var k := clampf(float(_cam_age) / float(cam.get("zoom_frames", 40)), 0.0, 1.0)
		z = lerpf(float(cam["zoom_from"]), z, smoothstep(0.0, 1.0, k))
	return z

func _update_camera(delta: float) -> void:
	if cam.is_empty() or main == null or not is_instance_valid(main):
		return
	_cam_age += 1
	var target := _cam_target()
	var smooth := float(cam.get("smooth", 7.0))
	var dt := maxf(delta, 1.0 / 60.0)
	if smooth <= 0.0 or String(cam.get("mode", "")) == "fixed":
		_cam_pos = target
	else:
		var sy := float(cam.get("smooth_y", smooth))
		_cam_pos.x = lerpf(_cam_pos.x, target.x, minf(1.0, dt * smooth))
		_cam_pos.y = lerpf(_cam_pos.y, target.y, minf(1.0, dt * sy))
	var zt := _cam_zoom_target()
	_cam_zoom = zt if cam.has("zoom_from") or float(cam.get("zoom_smooth", 6.0)) <= 0.0 \
		else lerpf(_cam_zoom, zt, minf(1.0, dt * float(cam.get("zoom_smooth", 6.0))))
	_cam_rot = lerpf(_cam_rot, float(cam.get("rotation", 0.0)), minf(1.0, dt * 6.0))
	main.camera.global_position = _cam_pos
	main.camera.zoom = Vector2.ONE * _cam_zoom
	main.camera.ignore_rotation = false
	main.camera.rotation = _cam_rot
	var amp := _shake + FinaleFx._shake * float(cam.get("fx", 0.4))
	var f := float(Engine.get_process_frames())
	main.camera.offset = Vector2(sin(f * 1.9), cos(f * 2.3)) * amp
	_shake = maxf(0.0, _shake - 60.0 * dt * maxf(1.0, _shake * 0.12))

## Where a world point lands on screen with the camera as set this frame
## (the canvas transform lags a frame behind the director's camera).
func screen_of(world: Vector2) -> Vector2:
	var c: Camera2D = main.camera
	return (world - c.global_position - c.offset).rotated(-c.rotation) * c.zoom.x + VIEW * 0.5

## Short zoom punch (adds to zoom for n frames, eased out).
func punch(amount: float, n: int = 12) -> void:
	var base := float(cam.get("zoom", 1.3))
	cam["zoom"] = base + amount
	cam["zoom_smooth"] = 30.0
	await frames(n)
	cam["zoom"] = base
	cam["zoom_smooth"] = 6.0

# ------------------------------------------------------------- time scale
func ramp_time(to: float, n: int) -> void:
	_ramp = [Engine.time_scale, to, maxi(n, 1), 0]

func hitstop(n: int) -> void:
	_hitstop_resume = Engine.time_scale if _hitstop == 0 else _hitstop_resume
	_hitstop = n
	Engine.time_scale = 0.0

func _update_time() -> void:
	if _hitstop > 0:
		_hitstop -= 1
		if _hitstop == 0:
			Engine.time_scale = _hitstop_resume
		return
	if _ramp[3] < _ramp[2]:
		_ramp[3] += 1
		var k := float(_ramp[3]) / float(_ramp[2])
		Engine.time_scale = lerpf(_ramp[0], _ramp[1], smoothstep(0.0, 1.0, k))

# -------------------------------------------------------------------- cuts
## Start storyboard cut `n` on the next frame. A cut is exactly CUT_FRAMES
## on-air frames; if the previous cut is still running this waits for it
## (holding the current inputs), so cuts never overlap or shorten.
func cut(n: int, intent: String, check: Callable, subject: Callable = Callable(), opts: Dictionary = {}) -> void:
	# One cut may wait in the queue; it goes on air the frame after the
	# running one ends, so consecutive cuts are seamless.
	while not _queued.is_empty():
		await frames(1)
	var s: Dictionary = shots[n]
	var rw := {"shot": n, "name": s["name"], "t": s["t"], "area": s["area"], "intent": intent,
		"storyboard": s.get("move", ""), "phenomenon": s.get("phenomenon", ""),
		"happened": false, "key_frame": -1, "first_frame": -1, "last_frame": -1,
		"hero_frac": [], "hero_on": 0, "subject_on": 0, "subject_px": [], "check_desc": opts.get("check_desc", intent),
		"establish": opts.get("establish", false), "no_hero": opts.get("no_hero", false),
		"subject_name": opts.get("subject_name", ""), "camera_log": []}
	if opts.has("hero_floor"):
		rw["hero_floor"] = float(opts["hero_floor"])
	rw["allow_hurt"] = opts.get("allow_hurt", false)
	rw["_check"] = check
	rw["_subject"] = subject
	rw["_subject_r"] = float(opts.get("subject_r", 40.0))
	rw["_on_start"] = opts.get("on_start", Callable())
	rw["_start_when"] = opts.get("start_when", Callable())
	rw["_always"] = opts.get("always", Callable())
	rw["always_desc"] = opts.get("always_desc", "")
	_queued = rw
	if not on_air:
		_pending_cut = n
	if opts.get("wait", true):
		while not _queued.is_empty():
			await frames(1)

## Wait until the running cut has used all its frames.
func end_cut() -> void:
	while on_air or not _queued.is_empty():
		await frames(1)

func _measure_cut() -> void:
	var fr := Engine.get_process_frames()
	if not on_air and not _queued.is_empty() and _may_start():
		_start_queued(fr)
	if not on_air:
		return
	var z: float = main.camera.zoom.x
	var sp := screen_of(r.global_position)
	var frac: float = Balance.RUNNER_SPRITE_H * z / VIEW.y
	(row["hero_frac"] as Array).append(frac)
	if Rect2(Vector2(-10, -20), VIEW + Vector2(20, 40)).has_point(sp) and r.visible:
		row["hero_on"] += 1
	if row["_subject"].is_valid():
		var at: Variant = row["_subject"].call()
		if at is Vector2:
			var ss := screen_of(at)
			var rad: float = float(row["_subject_r"]) * z
			if Rect2(Vector2(-rad * 0.6, -rad * 0.6), VIEW + Vector2(rad * 1.2, rad * 1.2)).has_point(ss):
				row["subject_on"] += 1
			(row["subject_px"] as Array).append(rad * 2.0)
	if row["_always"].is_valid() and not row["_always"].call():
		row["always_broken"] = int(row.get("always_broken", 0)) + 1
	if not row["happened"] and row["_check"].call():
		row["happened"] = true
		row["key_frame"] = fr
		row["key_cut_frame"] = cut_frames
		row["runner_key"] = [r.global_position.x, r.global_position.y]
	if cut_frames % 20 == 0:
		(row["camera_log"] as Array).append([roundf(main.camera.global_position.x), roundf(main.camera.global_position.y), snappedf(z, 0.01)])
	cut_frames += 1
	if cut_frames >= CUT_FRAMES:
		row["last_frame"] = fr
		row["runner_end"] = [r.global_position.x, r.global_position.y]
		on_air = false
		_verdict(row)
		# A queued cut takes over from the very next frame, so whatever
		# happens before that frame's _process is already logged under it.
		if not _queued.is_empty() and _may_start():
			_start_queued(fr + 1)

func _may_start() -> bool:
	return not _queued["_start_when"].is_valid() or _queued["_start_when"].call()

func _start_queued(first: int) -> void:
	_pending_cut = 0
	row = _queued
	_queued = {}
	report.append(row)
	on_air = true
	cut_frames = 0
	row["first_frame"] = first
	row["runner_start"] = [r.global_position.x, r.global_position.y]
	print("SHOT %02d %s" % [row["shot"], row["name"]])
	if row["_on_start"].is_valid():
		row["_on_start"].call()

func _verdict(rw: Dictionary) -> void:
	var fr: Array = rw["hero_frac"]
	var avg := 0.0
	for v in fr:
		avg += float(v)
	avg /= maxf(1.0, float(fr.size()))
	rw["hero_frac_avg"] = snappedf(avg, 0.001)
	rw["hero_frac_min"] = snappedf(fr.min() if not fr.is_empty() else 0.0, 0.001)
	rw["hero_on_screen"] = snappedf(float(rw["hero_on"]) / float(CUT_FRAMES), 0.01)
	var subj_ok := true
	if rw["_subject"].is_valid():
		rw["subject_on_screen"] = snappedf(float(rw["subject_on"]) / float(CUT_FRAMES), 0.01)
		subj_ok = float(rw["subject_on_screen"]) >= 0.5
	var size_floor := float(rw["hero_floor"]) if rw.has("hero_floor") else (0.06 if rw["establish"] else 0.08)
	var hero_ok: bool = rw["no_hero"] or (float(rw["hero_on_screen"]) >= 0.85 and avg >= size_floor)
	# Getting hurt on air is a failed take unless the cut is about that.
	var hurt := false
	for e in events:
		if int(e["cut"]) == int(rw["shot"]) and String(e["ev"]) in ["damaged", "died"] and not String(e["detail"]).begins_with("hp=2"):
			hurt = true
	rw["runner_hurt"] = hurt
	if hurt and not rw.get("allow_hurt", false):
		rw["happened"] = false
		rw["check_desc"] = String(rw["check_desc"]) + " (runner was hurt on air)"
	rw["checks"] = {"intent_defined": String(rw["intent"]) != "", "happened": rw["happened"],
		"visible": hero_ok and subj_ok}
	var always_ok := int(rw.get("always_broken", 0)) == 0
	rw["verdict"] = "PASS" if rw["happened"] and hero_ok and subj_ok and always_ok else "FAIL"
	var why := []
	if not rw["happened"]:
		why.append("did not happen: " + String(rw["check_desc"]))
	if not hero_ok:
		why.append("runner too small/off screen (avg %.1f%%, on %.0f%%)" % [avg * 100.0, float(rw["hero_on_screen"]) * 100.0])
	if not subj_ok:
		why.append("%s on screen only %.0f%%" % [rw["subject_name"], float(rw.get("subject_on_screen", 0.0)) * 100.0])
	if not always_ok:
		why.append("%s broken on %d frames" % [rw["always_desc"], rw["always_broken"]])
	rw["why"] = why
	print("   -> %s  runner %.1f%% of height, on %.0f%%  %s->%s%s%s" % [rw["verdict"], avg * 100.0, float(rw["hero_on_screen"]) * 100.0,
		Vector2(rw["runner_start"][0], rw["runner_start"][1]).round(), Vector2(rw["runner_end"][0], rw["runner_end"][1]).round(),
		("  subject %.0f%%" % (float(rw.get("subject_on_screen", 0)) * 100.0)) if rw["_subject"].is_valid() else "",
		("  [%s]" % "; ".join(why)) if not why.is_empty() else ""])

func _process(delta: float) -> void:
	queue_redraw()
	_update_time()
	if main == null or not is_instance_valid(main):
		return
	_update_camera(delta)
	_measure_cut()
	# Pointer: screen position of the guardian's aim, with fade and pop.
	overlay.pointer = screen_of(pointer) if pointer.x != INF else Vector2(INF, INF)
	overlay.pointer_alpha = move_toward(overlay.pointer_alpha, _pointer_alpha_to, 0.12)
	overlay.pointer_pop = move_toward(overlay.pointer_pop, 0.0, 0.08)
	overlay.pointer_scale = clampf(main.camera.zoom.x / 1.4, 0.85, 1.6)
	overlay.call_t += 1.0 / 60.0
	overlay.card_t += 1.0 / 60.0
	if _slate:
		_slate = false
		slate_frame = Engine.get_process_frames()
		overlay.set_meta("slate", true)
	elif overlay.has_meta("slate"):
		overlay.remove_meta("slate")

# ------------------------------------------------------------------- takes
func begin_take(at: Vector2, checkpoint: int) -> void:
	await end_cut()
	# Machines are rebuilt below; drop any camera that points at old ones.
	camera({"mode": "follow", "zoom": 1.3, "snap": true})
	release()
	cover = false
	cover_radius = 420.0
	pointer = Vector2(INF, INF)
	_pointer_alpha_to = 0.0
	overlay.pointer_alpha = 0.0
	_flags.clear()
	Engine.time_scale = 1.0
	_ramp = [1.0, 1.0, 0, 0]
	main.guardian.clear_constructs()
	# Every take starts at tick 0, so a take plays the same alone or in the
	# full run (the machines are all functions of the shared clock).
	Clock.reset(0)
	GameState.checkpoint_index = checkpoint
	GameState.checkpoint_position = Stage.checkpoints()[checkpoint - 1] + Vector2(0, 26) if checkpoint > 0 else Stage.start()
	main._respawn_timer = -1.0
	r.respawn(at)
	main.level.reset_to_checkpoint()
	FinaleFx.reset()
	for i in 4:
		await frames(1)
		if OS.get_environment("FINALE_LOG") != "":
			print("      begin_take f%d at %s state %d" % [i, r.global_position.round(), r.state])

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
	# The director owns the camera; main keeps its respawn timer (_process).
	main.set_physics_process(false)
	get_tree().physics_interpolation = true
	# The soundtrack is laid under the cut afterwards (the same project
	# music, continuous across cuts); the recording carries game sounds only.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	camera({"mode": "follow", "zoom": 1.3, "snap": true})
	await frames(4)
	# One magenta slate frame lets the render map process frames to movie
	# frames without trusting any fixed offset.
	_slate = true
	await frames(3)
	# sand runs on into the volcano, title into the end cards (no retake).
	var takes := ["opening", "storm", "sand", "rail", "hive", "giant", "bone", "title", "end"]
	for take in (only if not only.is_empty() else takes):
		if not has_method("take_" + take):
			continue
		print("=== TAKE ", take)
		await call("take_" + take)
		await end_cut()
		Engine.time_scale = 1.0
	_write_report()
	main.queue_free()
	await get_tree().process_frame
	var ok := 0
	for rw in report:
		if rw.get("verdict", "") == "PASS":
			ok += 1
	get_tree().quit(0 if ok == report.size() else 1)

func _write_report() -> void:
	var ok := 0
	var rows: Array = []
	for rw in report:
		var clean := {}
		for k in rw:
			if not String(k).begins_with("_") and k != "hero_frac":
				clean[k] = rw[k]
		var evs: Array = []
		for e in events:
			if int(e["cut"]) == int(rw["shot"]):
				evs.append(e)
		clean["events"] = evs
		rows.append(clean)
		if rw.get("verdict", "") == "PASS":
			ok += 1
	var file := FileAccess.open(OUT + "shots_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage": "1-10", "rendered": rendering, "slate_frame": slate_frame,
		"cut_frames": CUT_FRAMES, "shots": rows, "passed": ok, "total": rows.size(), "events": events,
		"zones": Stage.data().zones(), "checkpoints": Stage.checkpoints().map(func(c: Vector2) -> Array: return [c.x, c.y]),
		"start": [Stage.start().x, Stage.start().y],
		"goal": [Stage.goal().x, Stage.goal().y]}, "\t"))
	print("finale PV: %d / %d cuts pass" % [ok, rows.size()])

# ----------------------------------------------------------- measurements
## --take=measure: the runner's sprint jump on flat ground, frame by frame.
func take_measure() -> void:
	await begin_take(Vector2(950, 1137), 0)
	hold(1.0, true)
	for i in 200:
		if r.global_position.x >= 1450.0:
			break
		if i % 10 == 0:
			print("  run f%d x=%.0f y=%.0f vx=%.0f state=%d floor=%s hp=%d" % [i, r.global_position.x, r.global_position.y, r.velocity.x, r.state, r.is_on_floor(), r.hp])
		await frames(1)
	print("speed at take-off %.0f" % r.velocity.x)
	var x0 := r.global_position.x
	var y0 := r.global_position.y
	_jump = true
	var air := false
	for i in 140:
		if i == 18:
			_jump = false
		if not air and i > 20 and r.velocity.y > -60.0:
			air = true
			_jump = true
		elif air and _jump and i > 30:
			_jump = false
		await frames(1)
		if i % 3 == 0:
			print("  f%3d dx=%5.0f dy=%5.0f vx=%4.0f vy=%5.0f" % [i, r.global_position.x - x0, r.global_position.y - y0, r.velocity.x, r.velocity.y])
		if r.global_position.y - y0 > 500:
			break

# ------------------------------------------------------------ helpers (2)
func walk_to(x: float, limit: int = 120) -> void:
	for i in limit:
		var dx := x - r.global_position.x
		if absf(dx) < 6.0:
			break
		_axis = clampf(dx / 30.0, -1.0, 1.0)
		_sprint = false
		await frames(1)
	release()

func enemy_near(kind: String, at: Vector2) -> Node2D:
	var best: Node2D = null
	for e in get_tree().get_nodes_in_group("finale_enemy"):
		if e.kind == kind and (best == null or e.global_position.distance_to(at) < best.global_position.distance_to(at)):
			best = e
	return best

func sfx(key: String, semitones: float = 0.0, volume: float = 1.0) -> void:
	Audio.play(key, semitones, 0.0, volume)

func fade_call(to: float, n: int) -> void:
	var from := overlay.call_alpha
	for i in n:
		overlay.call_alpha = lerpf(from, to, float(i + 1) / float(n))
		await frames(1)

# ----------------------------------------------------- 0-10 s: the rescue
func take_opening() -> void:
	await begin_take(Vector2(-60, 877), 0)
	var bug := enemy_near("burrbug", Vector2(1180, 1135))
	var lip := Vector2(2250, 960)
	camera({"mode": "follow", "zoom": 1.3, "snap": true})
	hold(1.0, true)
	await until(x_past(float(OS.get_environment("PV_OPEN_X")) if OS.get_environment("PV_OPEN_X") != "" else 300.0), 200)

	# 1 DOWNHILL START: locked wide, easing right with the runner.
	var p0 := r.global_position
	camera({"mode": "fixed", "at": p0 + Vector2(300, 70), "pan_to": p0 + Vector2(660, 190), "zoom": 1.3, "snap": true})
	await cut(1, "Runner sprints down the curved green slope; a single enemy walks up toward them",
		func() -> bool: return r.velocity.x > 300.0 and r.is_on_floor() and bug.global_position.x - r.global_position.x < 900.0,
		func() -> Vector2: return bug.global_position, {"subject_name": "burrbug", "subject_r": 26.0})

	# 2 ONE ENEMY, ONE LEAP: side follow, the jump, then the gap opens up.
	await cut(2, "Runner jumps cleanly over the one enemy and lands running; the gap ahead comes into view",
		func() -> bool: return _flags.get("cleared_enemy", false),
		func() -> Vector2: return bug.global_position, {"subject_name": "burrbug", "subject_r": 26.0})
	camera({"mode": "follow", "zoom": 1.45, "lead": 140.0, "offset": Vector2(60, -40), "smooth": 6.0})
	await until(func() -> bool: return bug.global_position.x - r.global_position.x < 150.0, 90)
	await jump(15)
	hold(1.0, true)
	await until(func() -> bool: return r.global_position.x > bug.global_position.x + 30.0 and r.is_on_floor(), 70)
	_flags["cleared_enemy"] = r.hp == Balance.RUNNER_MAX_HP and r.global_position.x > bug.global_position.x
	camera({"mode": "follow", "zoom": 1.3, "lead": 160.0, "offset": Vector2(260, -60), "smooth": 4.0})

	# 3 THE CLIFF: pull back over the chasm as the runner leaps for the high bank.
	await until(x_past(1450), 60)
	await cut(3, "Runner leaps from the precipice toward a far bank that stands higher than the jump",
		func() -> bool: return not r.is_on_floor() and r.global_position.x > 1580.0,
		func() -> Vector2: return lip, {"subject_name": "far bank lip", "subject_r": 60.0, "establish": true})
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(0, -120), func() -> Vector2: return lip + Vector2(60, 0),
		func() -> Vector2: return Vector2(1700, 1380)], "pad": 100.0, "zoom": 1.2, "min_zoom": 0.78, "smooth": 5.0})
	await until(x_past(1524), 40)
	log_event("cliff_jump")
	_jump = true
	await frames(18)
	_jump = false
	await until(func() -> bool: return r.velocity.y > -60.0, 30)
	_jump = true
	await frames(14)
	_jump = false

	# 4 NOT QUITE!: the arc comes up short below the lip; time all but stops.
	await until(func() -> bool: return r.global_position.y > 1010.0 and r.velocity.y > 0.0, 60)
	await cut(4, "Runner falls short below the far ledge, reaching for it; the action slows almost to a stop",
		func() -> bool: return not r.is_on_floor() and r.global_position.y > lip.y + 60.0 and r.global_position.x < lip.x - 40.0 and Engine.time_scale < 0.3,
		func() -> Vector2: return lip, {"subject_name": "ledge out of reach", "subject_r": 50.0})
	release()
	ramp_time(0.03, 8)
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position, func() -> Vector2: return lip + Vector2(10, -10)],
		"pad": 70.0, "zoom": 2.4, "zoom_from": 1.1, "zoom_frames": 34, "min_zoom": 1.5, "smooth": 8.0})
	await frames(56)

	# 5 INCOMING CALL: hold the frame; the call card rings (no text at all).
	await cut(5, "Frozen mid-fall, an incoming call appears: Discord mark, decline and accept only",
		func() -> bool: return overlay.call_alpha > 0.9 and overlay.call_state == 1 and Engine.time_scale < 0.1)
	ramp_time(0.012, 20)
	overlay.call_state = 1
	overlay.call_t = 0.0
	sfx("ring")
	await fade_call(1.0, 10)
	await frames(26)
	sfx("ring")

	# 6 YOUR PARTNER ARRIVES: accept; the blue YOU pointer joins the runner.
	await cut(6, "The call is accepted and the blue YOU pointer appears beside the runner (no second avatar)",
		func() -> bool: return overlay.call_state == 2 and overlay.pointer_alpha > 0.8 and pointer.distance_to(r.global_position) < 240.0,
		func() -> Vector2: return pointer if pointer.x != INF else r.global_position, {"subject_name": "YOU pointer", "subject_r": 30.0})
	await frames(6)
	overlay.call_state = 2
	overlay.call_t = 0.0
	sfx("accept")
	await frames(10)
	fade_call(0.0, 12)
	await point(r.global_position + Vector2(64, -36), 16)
	overlay.pointer_pop = 1.0

	# 7 BRIDGE, ON DEMAND: pull out to show the gap; YOU draws a staircase.
	var hx := r.global_position.x
	var y1 := lip.y + 250.0
	var path := PackedVector2Array([Vector2(minf(hx - 90.0, lip.x - 260.0), y1), Vector2(lip.x - 170.0, y1), Vector2(lip.x - 170.0, y1 - 90.0),
		Vector2(lip.x - 90.0, y1 - 90.0), Vector2(lip.x - 90.0, y1 - 180.0), Vector2(lip.x - 6.0, y1 - 180.0)])
	log_event("stairs_planned", "runner x %.0f feet %.0f" % [hx, feet().y])
	await cut(7, "YOU traces a staircase of glowing blocks in the open air between the runner and the far bank",
		func() -> bool: return main.guardian.holograms_of(Hologram.Kind.PLATFORM).size() >= 1,
		func() -> Vector2: return (path[0] + path[-1]) * 0.5, {"subject_name": "staircase", "subject_r": 90.0})
	camera({"mode": "fixed", "at": (r.global_position + lip) * 0.5 + Vector2(-20, 90), "pan_to": (r.global_position + lip) * 0.5 + Vector2(0, 60),
		"zoom": 1.35, "zoom_from": 2.2, "zoom_frames": 26})
	var built := await trace(path, 5)
	_flags["stairs"] = built
	await frames(6)
	ramp_time(1.0, 22)

	# 8 JUST IN TIME: the runner drops onto the first block and steadies.
	await cut(8, "Runner lands on the first glowing block and regains balance",
		func() -> bool: return _flags.get("on_holo", false) and r.is_on_floor(),
		func() -> Vector2: return path[1], {"subject_name": "first block", "subject_r": 60.0})
	hide_pointer()
	camera({"mode": "follow", "zoom": 1.6, "lead": 0.0, "offset": Vector2(40, -30), "smooth": 7.0})
	hold(0.3)
	await until(func() -> bool: return r.is_on_floor(), 60)
	release()
	await frames(14)
	await hop_to(path[3] + Vector2(-30, -12))

	# 9 KEEP MOVING: up the steps without stopping.
	await cut(9, "Runner climbs the temporary steps toward the far bank in one continuous move",
		func() -> bool: return r.is_on_floor() and r.global_position.y < y1 - 150.0,
		func() -> Vector2: return path[4], {"subject_name": "steps", "subject_r": 60.0})
	camera({"mode": "follow", "zoom": 1.45, "lead": 60.0, "offset": Vector2(80, -50), "smooth": 6.0})
	await hop_to(path[5] + Vector2(-30, -12))

	# 10 SAFE SIDE!: off the last block onto grass, and away.
	cut(10, "Runner reaches solid grass on the far bank and keeps running",
		func() -> bool: return r.is_on_floor() and r.global_position.x > lip.x + 40.0 and absf(feet().y - lip.y) < 6.0,
		func() -> Vector2: return Vector2(2340, 900), {"subject_name": "far bank", "subject_r": 60.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.1, "zoom_from": 1.45, "zoom_frames": 50, "lead": 200.0, "offset": Vector2(120, -70), "smooth": 5.0})})
	await hop_to(lip + Vector2(70, -12))
	hold(1.0, true)
	# The sprout on the far bank: hop it and run on.
	var bug2 := enemy_near("burrbug", Vector2(2800, 935))
	await until(func() -> bool: return bug2 == null or not is_instance_valid(bug2) or bug2.global_position.x - r.global_position.x < 140.0 or not on_air, 70)
	if on_air and bug2 != null and is_instance_valid(bug2):
		await jump(15)
		hold(1.0, true)
	await end_cut()
	release()

# ------------------------------------------------- 10-13 s: thunder bridge
func take_storm() -> void:
	var storm := machine("storm")
	await begin_take(Vector2(3000, 957), 1)
	storm = machine("storm")
	# Off air: wait for the arc on the first raised stone to be in its
	# quiet phase by the time the runner lands on it (cut 13).
	var phase := float(OS.get_environment("PV_STORM_PHASE")) if OS.get_environment("PV_STORM_PHASE") != "" else 1.7
	await until(func() -> bool: return absf(fposmod(Clock.seconds_at(Clock.tick), 3.0) - phase) < 0.02, 200)
	camera({"mode": "fixed", "at": Vector2(3330, 900), "pan_to": Vector2(3480, 920), "zoom": 1.05, "snap": true, "fx": 0.3})
	hold(1.0, true)
	await until(x_past(3040), 60)

	# 11 ELECTRIC BRIDGE: the storm and the battered bridge, wide.
	await cut(11, "Wide, cold-blue reveal of the storm bridge as the runner sprints onto it",
		func() -> bool: return r.global_position.x > 3200.0 and r.is_on_floor(),
		func() -> Vector2: return Vector2(3500, 1020), {"subject_name": "bridge deck", "subject_r": 120.0, "establish": true})

	# 12 A STRIKE!: the bolt blasts out the span just ahead; the runner leaps.
	var seg3 := storm.global_position + Vector2(160.0 * 3.5, 0)
	await cut(12, "Lightning blasts the span right in front of the runner; debris flies and the runner jumps the new gap",
		func() -> bool: return storm._spans[3].collision_layer == 0 and not r.is_on_floor() and r.global_position.x > seg3.x - 60.0,
		func() -> Vector2: return seg3, {"subject_name": "struck span", "subject_r": 90.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "fixed", "at": seg3 + Vector2(-120, -110), "pan_to": seg3 + Vector2(10, -130),
			"zoom": 1.75, "zoom_from": 1.2, "zoom_frames": 16, "fx": 0.8})})
	await until(func() -> bool: return storm._spans[3].collision_layer == 0 or r.global_position.x > seg3.x - 120.0, 120)
	await until(x_past(seg3.x - 120.0), 40)
	log_event("leap_gap")
	# 13 ESCAPE THE GAP: diagonal vaults up onto the broken, live spans.
	cut(13, "Runner lands across the gap and vaults diagonally up onto the broken, electrified spans",
		func() -> bool: return r.is_on_floor() and r.global_position.y < 930.0,
		func() -> Vector2: return Vector2(4385, 800), {"subject_name": "electrified span", "subject_r": 70.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.45, "lead": 60.0, "offset": Vector2(130, -100), "smooth": 6.0, "fx": 0.5})})
	await hop_to(seg3 + Vector2(150, -40))
	await hop_to(Vector2(4175, 920), true)
	await hop_to(Vector2(4385, 800))
	release()
	await end_cut()

func take_measure_crouch() -> void:
	await begin_take(Vector2(6450, 1137), 2)
	hold(1.0, true)
	await frames(40)
	_crouch = true
	for i in 60:
		await frames(1)
		if i % 5 == 0:
			print("  crouch f%d x=%.0f vx=%.0f crouched=%s" % [i, r.global_position.x, r.velocity.x, r.crouching()])

# ---------------------------------------------------- 13-16 s: sand ruins
func take_sand() -> void:
	await begin_take(Vector2(5990, 1017), 2)
	var pend := machine("ruin_pendulum")
	var floor_lid := machine("ruin_floor")
	# Off air: start running at a fixed point of the pendulum's swing, so the
	# block reaches the bottom of its arc just as the runner slides under it.
	var phase := float(OS.get_environment("PV_SAND_PHASE")) if OS.get_environment("PV_SAND_PHASE") != "" else 1.32
	await until(func() -> bool: return absf(fposmod(Clock.seconds_at(Clock.tick), 1.7) - phase) < 0.009, 200)
	camera({"mode": "fixed", "at": Vector2(6330, 960), "pan_to": Vector2(6520, 900), "zoom": 1.0, "zoom_from": 1.55, "zoom_frames": 55, "snap": true, "fx": 0.3})
	hold(1.0, true)
	await frames(int(OS.get_environment("PV_SAND_LEAD")) if OS.get_environment("PV_SAND_LEAD") != "" else 34)
	camera({"mode": "fixed", "at": Vector2(6380, 960), "pan_to": Vector2(6560, 900), "zoom": 1.0, "zoom_from": 1.55, "zoom_frames": 55, "snap": true, "fx": 0.3})

	# 14 SHIFTING RUINS: pull out over the levels of the ruin and its sandfall.
	await cut(14, "Pull out to reveal the multi-level ruin hall, sandfall and the swinging block as the runner drops in",
		func() -> bool: return r.global_position.x > 6250.0,
		func() -> Vector2: return pend.global_position + pend.centre_at(Clock.tick), {"subject_name": "pendulum block", "subject_r": 80.0, "establish": true})

	# 15 SWINGING MASS: duck-slide under the block at the bottom of its arc.
	cut(15, "The giant chained block sweeps through inches above the runner, who slides under it",
		func() -> bool: return _flags.get("ducked", false) and r.hp == Balance.RUNNER_MAX_HP,
		func() -> Vector2: return pend.global_position + pend.centre_at(Clock.tick), {"subject_name": "pendulum block", "subject_r": 80.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "fixed", "at": Vector2(6700, 1010), "pan_to": Vector2(6790, 1030), "zoom": 1.8, "zoom_from": 1.6, "zoom_frames": 50, "fx": 0.6})})
	await until(x_past(6688), 200)
	log_event("duck")
	_crouch = true
	for i in 60:
		var c: Vector2 = pend.global_position + pend.centre_at(Clock.tick)
		if absf(c.x - r.global_position.x) < 50.0 and c.y > 1000.0 and r.crouching():
			_flags["ducked"] = true
		if _flags.get("ducked", false) and absf(c.x - r.global_position.x) > 140.0:
			break
		await frames(1)
	_crouch = false
	hold(1.0, true)

	# 16 VERTICAL COLLAPSE: the floor caves in and the runner drops down the shaft.
	await until(func() -> bool: return floor_lid.state == 1, 160)
	await cut(16, "The floor cracks and caves in under the runner, who plunges down a deep shaft among falling stones",
		func() -> bool: return floor_lid.state == 1 and r.global_position.y > 1400.0 and not r.is_on_floor(),
		func() -> Vector2: return floor_lid.global_position + Vector2(200, 40), {"subject_name": "collapsing floor", "subject_r": 100.0,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.35, "lead": 0.0, "offset": Vector2(30, 60), "smooth": 9.0, "smooth_y": 10.0, "fx": 0.8})})
	# Steer the fall down the clear lane between the rockfalls.
	for i in 150:
		_axis = clampf((7238.0 - r.global_position.x) / 40.0, -1.0, 1.0)
		_sprint = false
		if i == 26:
			camera({"mode": "follow", "zoom": 1.2, "lead": 0.0, "offset": Vector2(20, 230), "smooth": 9.0, "smooth_y": 14.0, "fx": 0.8})
		if r.global_position.y > 2300.0:
			break
		await frames(1)
	await take_volcano()

# ------------------------------------------------------ 16-20 s: volcano
func take_volcano() -> void:
	if r.global_position.y < 1400.0:
		await begin_take(Vector2(7250, 2000), 3)
	var ball := machine("magma")
	# 17 VOLCANO CORE: land in the core among stepped platforms and chains.
	await until(func() -> bool: return r.global_position.y > 2380.0, 200)
	camera({"mode": "fixed", "at": Vector2(7560, 2460), "pan_to": Vector2(7760, 2470), "zoom": 1.05, "zoom_from": 1.35, "zoom_frames": 40, "snap": true, "fx": 0.4})
	await cut(17, "The runner drops into the volcano core and lands among staggered lava platforms and hanging chains",
		func() -> bool: return r.is_on_floor() and r.global_position.y > 2600.0,
		func() -> Vector2: return Vector2(8300, 2560), {"subject_name": "lava platforms", "subject_r": 120.0, "establish": true})
	await until(func() -> bool: return r.is_on_floor(), 60)
	hold(1.0, true)
	await end_cut()
	# Off air: up the steps to the top of the cracked slope. YOU covers the
	# runner from the slime that hops these platforms.
	cover = true
	cover_radius = 420.0
	for step in [[8030.0, Vector2(8145, 2660)], [8180.0, Vector2(8360, 2560)], [8395.0, Vector2(8565, 2620)], [8600.0, Vector2(8790, 2520)]]:
		hold(1.0)
		await until(x_past(step[0]), 200)
		await hop_to(step[1])
	hold(1.0)
	await until(x_past(8960), 120)
	release()
	await frames(20)
	cover = false
	ball = machine("magma")

	# 18 HOT PURSUIT: the magma sphere breaks loose right behind the runner.
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(140, 0), func() -> Vector2: return ball.centre()],
		"pad": 150.0, "zoom": 1.55, "min_zoom": 1.05, "smooth": 8.0, "fx": 0.6, "snap": true})
	hold(1.0)
	await cut(18, "A giant magma sphere rolls out after the runner down the cracked slope, closing in",
		func() -> bool: return ball.state == 1 and ball.centre().x < r.global_position.x and r.global_position.x - ball.centre().x < 330.0,
		func() -> Vector2: return ball.centre(), {"subject_name": "magma sphere", "subject_r": 100.0})
	await until(x_past(9250), 120)
	await hop_to(Vector2(9470, 2420))
	log_event("on_escape_ledge")

	# 19 SWING OVER LAVA: from the ledge onto a chain-hung platform.
	hold(1.0)
	await until(x_past(9540), 60)
	release()
	var moving_left := func(m: FinaleMachine) -> bool: return m.offset_at(Clock.tick + 1).x < m.offset_at(Clock.tick).x
	await until(func() -> bool: return machine("swing_a")._deck.global_position.x < 9960.0 and moving_left.call(machine("swing_a")), 300)
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position, func() -> Vector2: return machine("swing_a").global_position + Vector2(0, 60),
		func() -> Vector2: return machine("swing_a")._deck.global_position + Vector2(0, 30)], "pad": 130.0, "zoom": 1.5, "min_zoom": 1.05, "smooth": 6.0, "fx": 0.4, "snap": true})
	await cut(19, "The runner leaps off the ledge onto a chain-hung platform and rides its arc over the lava",
		func() -> bool: return r.is_on_floor() and machine("swing_a").runner_on(machine("swing_a")._deck),
		func() -> Vector2: return machine("swing_a")._deck.global_position, {"subject_name": "swinging platform", "subject_r": 80.0})
	await frames(int(OS.get_environment("PV_SWING_WAIT")) if OS.get_environment("PV_SWING_WAIT") != "" else 8)
	await hop_to(func() -> Vector2: return machine("swing_a")._deck.global_position + Vector2(0, -12))
	await end_cut()

	# 20 BETWEEN THE GEYSERS: ride the vent lifts up past the eruptions.
	await begin_take(Vector2(10820, 2397), 5)
	var lift := func() -> FinaleMachine: return machine("lift_2440")
	await until(func() -> bool: return lift.call().lift_at(Clock.tick) < 0.5 and lift.call().warning_at(Clock.tick), 400)
	await hop_to(Vector2(10990, 2440))
	camera({"mode": "follow", "zoom": 1.35, "lead": 0.0, "offset": Vector2(150, -150), "smooth": 8.0, "smooth_y": 12.0, "snap": true, "fx": 0.6})
	await cut(20, "Rapid upward ride on the vent lifts between staggered lava eruptions",
		func() -> bool:
			var l := lift.call() as FinaleMachine
			return l.runner_on(l._slab) and l.lift_at(Clock.tick) > 60.0,
		func() -> Vector2: return Vector2(11160, 2290) if r.global_position.y > 2230.0 else Vector2(11430, 1960), {"subject_name": "lava geyser", "subject_r": 80.0})
	await until(func() -> bool: return lift.call().lift_at(Clock.tick) >= 300.0, 200)
	await hop_to(Vector2(11150, 2100))
	await end_cut()

# ------------------------------------------------------ 20-24 s: iron rail
func rail() -> FinaleMachine:
	return machine("rail")

func take_rail() -> void:
	await begin_take(Vector2(11250, 1477), 6)
	cover = true
	cover_radius = 700.0
	# Off air: board train 0 at the station and wait for it to pull away.
	await until(func() -> bool: return rail().beat() > 4.3 and rail().beat() < 5.0, 1700)
	hold(1.0)
	for i in 30:
		await frames(8)
		if r.is_on_floor() and r.global_position.x > 11560.0 and r.global_position.y > 1520.0:
			break
	release()
	# While the train stands at the platform, walk up to the low flatcar.
	for i in 400:
		var target: float = rail().car_x(0, 1, rail().beat()) + 255.0
		var dx: float = target - r.global_position.x
		_axis = clampf(dx / 40.0, -0.6, 0.6)
		if r.is_on_floor() and r.is_on_wall() and dx > 0.0:
			await jump(14)
		elif absf(dx) < 8.0 and r.is_on_floor():
			break
		else:
			await frames(1)
	release()
	log_event("rail_ready", "beat %.2f x %.0f flat %.0f" % [rail().beat(), r.global_position.x, rail().car_x(0, 1, rail().beat())])
	var go := float(OS.get_environment("PV_RAIL_GO")) if OS.get_environment("PV_RAIL_GO") != "" else 9.95
	await until(func() -> bool: return rail().beat() > go, 900)
	camera({"mode": "follow", "zoom": 1.55, "lead": 150.0, "offset": Vector2(90, -40), "smooth": 9.0, "snap": true, "fx": 0.3})

	# 21 ROOFTOP TRAIN RUN: tracking fast along roofs of mismatched height.
	await cut(21, "Fast tracking run along a moving train, dropping and climbing between roofs of different heights",
		func() -> bool: return rail()._riding() >= 0 and rail().train_speed(0, rail().beat()) > 200.0 and absf(r.velocity.x) > 100.0 and _flags.get("roof_changes", 0) >= 1,
		func() -> Vector2: return Vector2(rail().car_x(0, 2, rail().beat()) + 150.0, rail().roof_y(0, 2)), {"subject_name": "train roofs", "subject_r": 120.0})
	var last_floor := r.global_position.y
	var loco_end := func() -> float: return rail().car_x(0, 3, rail().beat()) + 320.0
	for i in 600:
		if r.is_on_floor() and r.global_position.x > loco_end.call() - 60.0:
			break
		hold(1.0, true)
		if r.is_on_floor() and absf(r.global_position.y - last_floor) > 40.0:
			_flags["roof_changes"] = int(_flags.get("roof_changes", 0)) + 1
			last_floor = r.global_position.y
		if r.is_on_floor() and r.is_on_wall():
			await jump(16)
		else:
			await frames(1)

	# 22 TRAIN-TO-TRAIN: the leap across the moving gap between two trains.
	var b_rear := func() -> float: return rail().car_x(1, 0, rail().beat())
	await cut(22, "A huge airborne leap from one moving train across the gap onto the taller train ahead",
		func() -> bool: return _flags.get("leapt_trains", false),
		func() -> Vector2: return Vector2(b_rear.call() + 60.0, rail().roof_y(1, 0)), {"subject_name": "second train", "subject_r": 90.0,
		"on_start": func() -> void: camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position, func() -> Vector2: return Vector2(b_rear.call() + 100.0, rail().roof_y(1, 0) - 40.0)],
			"pad": 170.0, "zoom": 1.45, "min_zoom": 1.05, "smooth": 8.0, "fx": 0.3})})
	await hop_to(func() -> Vector2: return Vector2(b_rear.call() + 120.0, rail().roof_y(1, 0)), true)
	_flags["leapt_trains"] = r.global_position.x > b_rear.call() and r.is_on_floor()
	log_event("rail_state", "beat %.2f rear1 %.0f car1 %.0f..%.0f riding %d drop1 t=%.2f land=%.2f" % [rail().beat(), rail().car_x(1, 0, rail().beat()),
		rail().car_x(1, 1, rail().beat()), rail().car_x(1, 1, rail().beat()) + 300.0, rail()._riding(), rail()._drops[1]["t"], rail()._drops[1]["land"]])

	# 23 CRANE DROPS: a crate drops from the crane; change course at once.
	var drop: Dictionary = rail()._drops[1]
	hold(1.0)
	await until(func() -> bool: return rail().beat() > float(drop["t"]) - 0.55, 400)
	camera({"mode": "follow", "zoom": 1.3, "lead": 40.0, "offset": Vector2(80, -170), "smooth": 7.0, "fx": 0.6})
	await cut(23, "A cargo crate drops from the crane onto the car just ahead; the runner checks and jumps back to dodge it",
		func() -> bool:
			var at: Array = rail().crate_at(1, rail().beat())
			return at[1] == 2 and (at[0] as Vector2).distance_to(r.global_position) < 320.0 and r.hp == Balance.RUNNER_MAX_HP,
		func() -> Vector2: return rail().crate_at(1, rail().beat())[0], {"subject_name": "falling crate", "subject_r": 50.0})
	await until(func() -> bool: return rail().crate_at(1, rail().beat())[1] >= 1, 60)
	hold(-1.0)
	await jump(14)
	hold(-0.3)
	await until(func() -> bool: return r.is_on_floor(), 40)
	release()
	await until(func() -> bool: return rail().crate_at(1, rail().beat())[1] == 2, 60)
	await frames(4)

	# 24 FULL-SPEED ROOFTOPS: low and fast over the crate and the roofs.
	cut(24, "Low, fast tracking over the jagged roofs and the landed crate as the line-side posts whip past",
		func() -> bool:
			var crate: Vector2 = rail().crate_at(1, rail().beat())[0]
			var on_crate := r.is_on_floor() and absf(r.global_position.x - crate.x) < 60.0 and r.global_position.y < crate.y - 40.0
			if on_crate:
				_flags["on_crate"] = true
			return _flags.get("on_crate", false) and r.global_position.x > crate.x + 40.0 and absf(r.velocity.x) > 150.0,
		func() -> Vector2: return Vector2(rail().car_x(1, 2, rail().beat()) + 160.0, rail().roof_y(1, 2)), {"subject_name": "train roofs", "subject_r": 120.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.65, "lead": 170.0, "offset": Vector2(110, 10), "smooth": 10.0, "fx": 0.3})})
	await hop_to(func() -> Vector2: return rail().crate_at(1, rail().beat())[0] + Vector2(0, -60), true)
	hold(1.0, true)
	for i in 120:
		if i % 6 == 0:
			log_event("c24", "crate %s floor %s vx %.0f" % [rail().crate_at(1, rail().beat())[0].round(), r.is_on_floor(), r.velocity.x])
		if r.is_on_floor() and r.is_on_wall():
			await jump(16)
		elif not on_air and _queued.is_empty():
			break
		else:
			await frames(1)
	release()
	await end_cut()

# ------------------------------------------------- 24-30 s: honeycomb hive
func take_hive() -> void:
	await begin_take(Vector2(15440, 1267), 7)
	cover = true
	cover_radius = 75.0
	camera({"mode": "fixed", "at": Vector2(15940, 1000), "pan_to": Vector2(15990, 1020), "zoom": 0.98, "snap": true, "fx": 0.3})
	hold(1.0, true)
	await frames(2)

	# 25 INSIDE THE HIVE: tall view of the dripping tiers as the runner enters.
	await cut(25, "Tall establishing view of the hive: dripping honey tiers, inverted ledges and the paddle wheel, the runner entering",
		func() -> bool: return r.global_position.x > 15600.0,
		func() -> Vector2: return machine("paddles_a").global_position, {"subject_name": "paddle wheel", "subject_r": 140.0, "establish": true})
	var honey := machine("honey_15760")
	# 26 STUCK!: the boots sink into thick honey and the run stalls.
	cut(26, "Close on the runner's boots sinking into thick honey; the sprint stalls to a crawl",
		func() -> bool:
			if honey._in and _axis > 0.5:
				_flags["honey_frames"] = int(_flags.get("honey_frames", 0)) + 1
			return int(_flags.get("honey_frames", 0)) >= 24,
		func() -> Vector2: return honey.global_position + Vector2(70, 0), {"subject_name": "honey pool", "subject_r": 70.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 2.5, "zoom_from": 1.6, "zoom_frames": 8, "lead": 0.0, "offset": Vector2(10, 10), "smooth": 12.0, "fx": 0.2})})
	await until(func() -> bool: return honey.covers() and r.is_on_floor(), 120)
	log_event("in_honey")
	hold(1.0, true)
	await until(x_past(15905), 120)

	# 27 SWARM AND PADDLES: up the comb tiers with the bees on the runner.
	cut(27, "The runner jumps up the comb tiers past the turning paddle wheel with a swarm of bees right behind",
		func() -> bool: return _near_kind("wax_wisp", 330.0) >= 2 and r.global_position.y < 1200.0,
		func() -> Vector2: return machine("paddles_a").global_position + Vector2(140, 0), {"subject_name": "paddles and swarm", "subject_r": 120.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.45, "lead": 60.0, "offset": Vector2(40, -90), "smooth": 7.0, "smooth_y": 8.0, "fx": 0.3})})
	hold(1.0)
	await until(x_past(15975), 40)
	for f in [Vector2(16030, 1120), Vector2(16195, 990), Vector2(16380, 1000)]:
		await hop_to(f, true)
	hold(1.0)
	await until(x_past(16620), 200)
	await until(func() -> bool: return r.is_on_floor(), 60)
	cover_radius = 420.0

	# 28 BUBBLE SLINGSHOT: the honey bubble bends, then flings the runner up.
	var shaft := machine("hive_shaft")
	hold(1.0)
	await until(x_past(16790), 200)
	camera({"mode": "fixed", "at": Vector2(16890, 1110), "zoom": 1.55, "snap": true, "fx": 0.4})
	await cut(28, "The runner lands on a giant honey bubble; it bends under them and slingshots them straight up",
		func() -> bool:
			if shaft.squash() > 0.2:
				_flags["squashed"] = true
			return _flags.get("squashed", false) and r.velocity.y < -700.0,
		func() -> Vector2: return shaft.global_position + Vector2(0, -70), {"subject_name": "honey bubble", "subject_r": 70.0})
	await until(x_past(16880), 120)
	hold(0.0)
	await until(func() -> bool: return r.velocity.y < -700.0, 120)
	camera({"mode": "follow", "zoom": 1.45, "lead": 0.0, "offset": Vector2(0, -150), "smooth": 6.0, "smooth_y": 5.0, "fx": 0.3})

	# 29 HIVE SHAFT ASCENT: the launch carries on up the narrow honey shaft.
	cut(29, "Tracking up the narrow honey-filled shaft as the launch carries the runner upward",
		func() -> bool: return r.global_position.x > 16820.0 and r.global_position.x < 16980.0 and r.velocity.y < -300.0 and r.global_position.y < 900.0,
		func() -> Vector2: return Vector2(16900, r.global_position.y - 120.0), {"subject_name": "shaft", "subject_r": 70.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.4, "lead": 0.0, "offset": Vector2(0, -200), "smooth": 6.0, "smooth_y": 12.0, "fx": 0.3})})
	await until(func() -> bool: return r.global_position.y < 520.0, 200)

	# 30 BREAK THROUGH THE HIVE: burst through the wax ceiling into daylight.
	cut(30, "The runner bursts through the wax membrane at the top of the hive; glowing comb debris rains down",
		func() -> bool: return machine("hive_shaft").state == 1,
		func() -> Vector2: return Vector2(16900, 230), {"subject_name": "membrane", "subject_r": 70.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.25, "zoom_from": 1.0, "zoom_frames": 40, "lead": 0.0, "offset": Vector2(60, -60), "smooth": 9.0, "smooth_y": 12.0, "fx": 0.6})})
	await until(func() -> bool: return machine("hive_shaft").state == 1, 200)
	hold(1.0)
	await until(func() -> bool: return r.is_on_floor(), 200)
	release()
	await end_cut()

func _near_kind(kind: String, radius: float) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("finale_enemy"):
		if e.kind == kind and e.global_position.distance_to(r.global_position) < radius:
			n += 1
	return n

# ------------------------------------------------- 30-33 s: stone giant
func take_giant() -> void:
	await begin_take(Vector2(17150, 177), 8)
	cover = false
	camera({"mode": "follow", "zoom": 1.5, "lead": 120.0, "offset": Vector2(120, -10), "smooth": 7.0, "snap": true, "rotation": 0.0, "fx": 0.6})
	hold(1.0, true)
	await until(x_past(17290), 60)
	hop_to(Vector2(17730, 300), true)
	await frames(24)

	# 31 OFF-CENTER LANDING: a leap down onto a lone, tilted ledge.
	await cut(31, "The runner leaps out of the hive onto an isolated, tilted ledge; the camera tilts and jolts on landing",
		func() -> bool: return r.is_on_floor() and r.global_position.x > 17620.0 and r.global_position.x < 17880.0,
		func() -> Vector2: return Vector2(17750, 300), {"subject_name": "tilted ledge", "subject_r": 90.0})
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position, func() -> Vector2: return Vector2(17760, 320)],
		"pad": 120.0, "zoom": 1.55, "min_zoom": 1.1, "smooth": 7.0, "rotation": -0.05, "fx": 0.6})
	await until(func() -> bool: return r.is_on_floor(), 60)
	camera({"mode": "follow", "zoom": 1.55, "lead": 60.0, "offset": Vector2(60, -30), "smooth": 7.0, "rotation": -0.08, "shake": 12.0, "fx": 0.6})
	release()
	await end_cut()

	# Off air: onto the plateau, toward the gorge.
	camera({"mode": "follow", "zoom": 1.3, "rotation": 0.0, "snap": true})
	await hop_to(Vector2(18050, 300), true)
	hold(1.0)
	await until(x_past(18120), 120)
	await until(func() -> bool: return machine("giant").state == 1 and machine("giant").since() > 0.6, 120)
	# 32 SOMETHING HUGE WAKES: the whole automaton, low and wide.
	camera({"mode": "fixed", "at": Vector2(18560, 120), "pan_to": Vector2(18580, 40), "zoom": 0.62, "zoom_from": 0.8, "zoom_frames": 60, "snap": true, "fx": 0.6})
	await cut(32, "Wide, low reveal of the whole stone automaton rising out of the gorge; the runner tiny beside it",
		func() -> bool: return machine("giant").state == 1 and machine("giant").rise() < machine("giant").SUNK * 0.4,
		func() -> Vector2: return machine("giant").global_position + Vector2(0, -620 + machine("giant").rise()), {"subject_name": "stone giant", "subject_r": 300.0, "hero_floor": 0.045})
	await until(x_past(18300), 60)
	release()
	await end_cut()

	# Off air: the slab is swatted down into a bridge; step onto it just
	# after the mace has swept past going right.
	await until(func() -> bool: return machine("giant").slab_angle() >= PI * 0.5 - 0.01, 300)
	hold(1.0)
	await until(x_past(18440), 100)
	release()
	await until(func() -> bool:
		var g := machine("giant")
		return g.mace_angle() > 0.04 and g.mace_angle() < 0.2 and g.mace_angle() > g.mace_angle(Clock.tick - 1), 400)
	await hop_to(Vector2(18745, 240))
	log_event("landed_bridge", "mace a=%.2f c=%s" % [machine("giant").mace_angle(), machine("giant").mace_centre().round()])
	await walk_to(18745.0)
	log_event("on_bridge", "mace a=%.2f c=%s" % [machine("giant").mace_angle(), machine("giant").mace_centre().round()])


	await until(func() -> bool:
		var g := machine("giant")
		return g.mace_angle() < 0.95 and g.mace_angle() < g.mace_angle(Clock.tick - 1), 400)
	# 33 SWEEP!: the mace swings across the bridge; jump it by inches.
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(0, -60), func() -> Vector2: return machine("giant").mace_centre(),
		func() -> Vector2: return r.global_position + Vector2(0, 40)], "pad": 120.0, "zoom": 1.45, "min_zoom": 1.0, "smooth": 7.0, "snap": true, "fx": 0.8})
	await cut(33, "The giant's spiked mace sweeps across the bridge; the runner jumps it with inches to spare",
		func() -> bool:
			var g := machine("giant")
			if not r.is_on_floor() and absf(g.mace_centre().x - r.global_position.x) < 70.0 and g.mace_centre().y > r.global_position.y + 40.0:
				_flags["over_mace"] = true
			return _flags.get("over_mace", false) and r.hp == Balance.RUNNER_MAX_HP,
		func() -> Vector2: return machine("giant").mace_centre(), {"subject_name": "mace", "subject_r": 70.0})
	await until(func() -> bool: return machine("giant").mace_angle() < 0.56 and machine("giant").mace_angle() > 0.0 \
		and machine("giant").mace_angle() < machine("giant").mace_angle(Clock.tick - 1), 160)
	await jump(18)
	await until(func() -> bool: return r.is_on_floor(), 90)
	hold(1.0, true)
	await end_cut()
	release()

# --------------------------------------------- 33-39 s: dragon bone canyon
func take_bone() -> void:
	await begin_take(Vector2(19420, 277), 9)
	cover = true
	cover_radius = 150.0
	camera({"mode": "fixed", "at": Vector2(20060, 60), "pan_to": Vector2(20240, 40), "zoom": 0.74, "zoom_from": 0.9, "zoom_frames": 60, "snap": true, "fx": 0.3})
	hold(1.0)
	await frames(2)

	# 34 THE FOSSIL CANYON: the whole winding canyon of colossal ribs.
	await cut(34, "Massive wide reveal of the fossil canyon: arched rib bridges, bone pillars and drones over a deep gorge",
		func() -> bool: return r.global_position.x > 19500.0,
		func() -> Vector2: return Vector2(20100, 200), {"subject_name": "rib bridges", "subject_r": 200.0, "establish": true})
	# 35 BONE ARCH RUN: up the narrow arched rib, high over the canyon.
	cut(35, "The runner sprints up a narrow arched rib-bridge high above the canyon floor",
		func() -> bool:
			for sl in get_tree().get_nodes_in_group("finale_slope"):
				if sl.skin == "bone" and r.is_on_floor() and sl.top_at(r.global_position.x) < INF and absf(sl.top_at(r.global_position.x) - feet().y) < 8.0:
					return true
			return false,
		func() -> Vector2: return Vector2(19960, 210), {"subject_name": "rib bridge", "subject_r": 120.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.45, "lead": 140.0, "offset": Vector2(80, 40), "smooth": 7.0, "rotation": -0.05, "fx": 0.3})})
	hold(1.0, true)
	await until(x_past(20250), 200)
	await hop_to(Vector2(20360, 320))

	# 36 ROTORS EVERYWHERE: rotor skulls swarm between the ribs.
	cut(36, "Rotor-skull drones close in from every side between the ribs; the runner weaves through them",
		func() -> bool: return _near_kind("skull_drone", 460.0) >= 3,
		func() -> Vector2: return Vector2(20750, 60), {"subject_name": "rotor skulls", "subject_r": 160.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.3, "lead": 120.0, "offset": Vector2(60, -110), "smooth": 6.0, "rotation": 0.04, "fx": 0.3})})
	hold(1.0)
	await until(x_past(20700), 300)
	cover_radius = 120.0
	await until(x_past(20980), 300)
	await end_cut()

	# 37 IT COMES ALIVE: the skeletal beast bursts up through the deck.
	await begin_take(Vector2(21300, 257), 10)
	cover = true
	cover_radius = 150.0
	# Off air: a fixed beat on the clock, so the sand jets fire between the
	# runner's leaps rather than under one.
	await frames(int(OS.get_environment("PV_BONE_WAIT")) if OS.get_environment("PV_BONE_WAIT") != "" else 20)
	hold(1.0)
	await until(x_past(21655), 100)
	camera({"mode": "fixed", "at": Vector2(21860, 330), "pan_to": Vector2(21900, 110), "pan_frames": 36, "zoom": 1.0, "snap": true, "fx": 0.8})
	await cut(37, "An ancient skeletal beast erupts from below, smashing up through the vertebra bridge ahead of the runner",
		func() -> bool: return machine("beast").state >= 1 and machine("beast").broken(),
		func() -> Vector2: return machine("beast").erupt_head(), {"subject_name": "skeletal beast", "subject_r": 160.0})
	await until(x_past(21700), 100)
	release()
	await end_cut()
	await until(func() -> bool: return machine("beast").since() > 1.9, 200)
	hold(1.0, true)
	await until(x_past(21880), 100)
	await hop_to(Vector2(22400, 300), true)
	hold(1.0, true)
	await until(x_past(22600), 200)

	# 38 SAND GOES VERTICAL: up the collapsing pillars, sand blasting up.
	cut(38, "Chased by the beast's jaws, the runner leaps up crumbling bone pillars as sand geysers blast up between them",
		func() -> bool:
			for m in get_tree().get_nodes_in_group("finale_machine"):
				if m.kind == "bone_pillar" and m.state == 1 and m.since() > 0.2:
					_flags["pillar_fell"] = true
			for id3 in ["sandjet_23205", "sandjet_23610", "sandjet_22050"]:
				if machine(id3).active() and absf(machine(id3).global_position.x - r.global_position.x) < 700.0:
					_flags["jet_seen"] = true
			return machine("beast").state == 2 and _flags.get("pillar_fell", false) and _flags.get("jet_seen", false),
		func() -> Vector2: return machine("beast").chase_head(), {"subject_name": "chasing jaws", "subject_r": 160.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(120, -60), func() -> Vector2: return machine("beast").chase_head() + Vector2(120, -80)],
			"pad": 140.0, "zoom": 1.3, "min_zoom": 0.95, "smooth": 7.0, "fx": 0.9})})
	for f in [Vector2(22710, 320), Vector2(22905, 260), Vector2(23105, 330), Vector2(23305, 240)]:
		await hop_to(f + Vector2(25, 0))

	# 39 CLOSING JAWS: the jaws slam shut at the gate right behind the runner.
	log_event("c38flags", "%s beast %d front %.0f" % [_flags, machine("beast").state, machine("beast").jaw_front()])
	var gate := float(machine("beast").data["gate_x"])
	cut(39, "The gigantic fossil jaws snap shut right behind the runner as they dive through the stone gate",
		func() -> bool: return machine("beast")._snapped and r.global_position.x > gate,
		func() -> Vector2: return Vector2(gate - 120.0, 160.0), {"subject_name": "closing jaws", "subject_r": 160.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(100, 0), func() -> Vector2: return machine("beast").chase_head() + Vector2(160, -40)],
			"pad": 110.0, "zoom": 1.45, "min_zoom": 1.0, "smooth": 8.0, "rotation": -0.07, "fx": 1.0, "snap": true}),
		"start_when": func() -> bool: return machine("beast").jaw_front() > gate - 300.0})
	# Across the last pillars -- or, if a sand jet has thrown the runner up
	# onto the rib path, along the ribs -- and down through the gate.
	for i in 6:
		if r.global_position.x > 23690.0:
			break
		if r.global_position.y < 120.0:
			if r.global_position.x < 23400.0:
				await hop_to(Vector2(23560, 60))
			hold(1.0, true)
			await until(func() -> bool: return r.global_position.x > 23660.0 or not r.is_on_floor(), 120)
		else:
			var next := Vector2(23535, 300) if r.global_position.x < 23450.0 else Vector2(23735, 270)
			await hop_to(next)
	await hop_to(Vector2(24080, 300), true)
	log_event("through_gate", "front %.0f t %.2f" % [machine("beast").jaw_front(), machine("beast").since()])
	hold(1.0)
	await end_cut()
	release()

# --------------------------------------------- 39-46 s: title over gameplay
## Ease the title (behind the world) to a scale, centre and alpha.
func title_to(scale: float, centre: Vector2, alpha: float, n: int) -> void:
	var s0 := title.title_scale
	var c0 := title.title_centre
	var a0 := title.title_alpha
	for i in n:
		var k := float(i + 1) / float(n)
		var e := 1.0 - pow(1.0 - k, 3.0)
		title.title_scale = lerpf(s0, scale, e)
		title.title_centre = c0.lerp(centre, e)
		title.title_alpha = lerpf(a0, alpha, minf(1.0, k * 2.0))
		await frames(1)

const TITLE_CENTRE := Vector2(640, 238)
const TITLE_SCALE := 0.56

func take_title() -> void:
	await begin_take(Vector2(24420, 277), 11)
	# YOU only fires on a drone actually swooping into the runner.
	cover = true
	cover_radius = 140.0
	title.title_alpha = 0.0
	title.title_scale = TITLE_SCALE * 1.35
	title.title_centre = TITLE_CENTRE
	# The runner keeps to the lower third; the title owns the sky above.
	camera({"mode": "follow", "zoom": 1.2, "lead": 150.0, "offset": Vector2(120, -130), "smooth": 6.0, "smooth_y": 4.0, "snap": true, "fx": 0.3})
	hold(1.0, true)
	await until(x_past(24560), 60)

	# 40 THE NAME APPEARS: MELOS GAME lands centre screen; play goes on.
	await cut(40, "MELOS GAME lands big in the centre of the screen behind the action while the runner keeps running",
		func() -> bool: return title.title_alpha > 0.95 and absf(r.velocity.x) > 150.0,
		func() -> Vector2: return r.global_position, {"subject_name": "runner under title", "subject_r": 30.0})
	sfx("sting")
	await title_to(TITLE_SCALE, TITLE_CENTRE, 1.0, 16)

	# 41 CHASE UNDER THE TITLE: drones swoop in; jump the rolling saw.
	var saw := func() -> Vector2: return machine("saw_a").global_position + machine("saw_a").centre()
	var saw_left := func() -> bool: return machine("saw_a").centre(Clock.tick + 1).x < machine("saw_a").centre().x
	hold(1.0, true)
	await until(x_past(25190), 120)
	release()
	await until(func() -> bool: return saw_left.call() and saw.call().x < 25560.0 and saw.call().x > 25500.0, 260)
	await cut(41, "Brass drones swoop in behind as the runner jumps a rolling saw under the title",
		func() -> bool:
			if _near_kind("brass_drone", 620.0) >= 1:
				_flags["drone_seen"] = true
			return _flags.get("drone_seen", false) and _flags.get("hopped_saw", false),
		func() -> Vector2: return saw.call(), {"subject_name": "saw", "subject_r": 50.0})
	hold(1.0, true)
	await until(func() -> bool:
		if _near_kind("brass_drone", 560.0) >= 1:
			_flags["drone_seen"] = true
		return saw.call().x - r.global_position.x < 150.0, 60)
	await hop_to(Vector2(saw.call().x + 150.0, 520.0))
	_flags["hopped_saw"] = r.state != Runner.State.DEAD and r.hp == Balance.RUNNER_MAX_HP
	if _near_kind("brass_drone", 560.0) >= 1:
		_flags["drone_seen"] = true

	# 42 THE CHASE TIGHTENS: up and down the stepped blocks, title held centre.
	cut(42, "The runner weaves over platforms of changing height with the drones on their tail, the title held centre",
		func() -> bool:
			if _near_kind("brass_drone", 620.0) >= 1:
				_flags["drone_42"] = true
			if r.is_on_floor() and absf(r.global_position.y - float(_flags.get("last_floor_y", r.global_position.y))) > 50.0:
				_flags["height_changes"] = int(_flags.get("height_changes", 0)) + 1
			if r.is_on_floor():
				_flags["last_floor_y"] = r.global_position.y
			return int(_flags.get("height_changes", 0)) >= 1 and _flags.get("drone_42", false),
		func() -> Vector2: return r.global_position + Vector2(-160, -120), {"subject_name": "pursuers", "subject_r": 120.0, "wait": false,
		"start_when": func() -> bool: return r.global_position.x > 25590.0,
		"on_start": func() -> void: cover = false})
	var floors := [r.global_position.y]
	for f in [Vector2(25900, 460), Vector2(26240, 560)]:
		hold(1.0, true)
		await until(x_past(f.x - 300.0), 90)
		await hop_to(f, true)
		if absf(r.global_position.y - float(floors[-1])) >= 55.0:
			_flags["height_changes"] = int(_flags.get("height_changes", 0)) + 1
		floors.append(r.global_position.y)
	await end_cut()

	# Off air: on to the block beside the saw post. The next drone dive
	# will catch the runner there (YOU is not covering now).
	cover = false
	await hop_to(Vector2(26240, 560), true)
	await walk_to(26392.0)
	hold(-0.25)
	await frames(2)
	release()
	var drone := func() -> Node2D:
		var best: Node2D = null
		for e in get_tree().get_nodes_in_group("finale_enemy"):
			if e.kind == "brass_drone" and (best == null or e.global_position.distance_to(r.global_position) < best.global_position.distance_to(r.global_position)):
				best = e
		return best
	var dive_soon := func() -> bool:
		var d: Node2D = drone.call()
		return d != null and d.global_position.distance_to(r.global_position) < 420.0 and fposmod(d._t(), 3.2) > 1.95 and fposmod(d._t(), 3.2) < 2.1

	# 43 OOPS, DOWN AGAIN: a drone dives in and knocks the runner into the saw.
	await until(dive_soon, 400)
	camera({"mode": "follow", "zoom": 1.45, "lead": 0.0, "offset": Vector2(40, -120), "smooth": 8.0, "snap": true, "fx": 0.8})
	var hits := [0]
	var on_hit := func(_hp: int, _m: int) -> void:
		if on_air and int(row.get("shot", 0)) == 43 and hits[0] == 0:
			hits[0] = 1
			hitstop(7)
			punch(0.45, 10)
			_shake = 16.0
	Events.runner_damaged.connect(on_hit)
	await cut(43, "A diving drone strikes the runner and knocks them into the spinning saw: a hit-stop, then down they go",
		func() -> bool: return r.state == Runner.State.DEAD,
		func() -> Vector2: return machine("saw_b").global_position, {"subject_name": "saw", "subject_r": 60.0, "allow_hurt": true})
	await until(func() -> bool: return r.state == Runner.State.DEAD, 120)
	await end_cut()
	Events.runner_damaged.disconnect(on_hit)

	# 44 CHECKPOINT RESTART: back at the flag, running again at once.
	camera({"mode": "fixed", "at": Stage.checkpoints()[11] + Vector2(120, -70), "zoom": 1.35, "zoom_from": 1.25, "zoom_frames": 50, "snap": true, "fx": 0.3})
	cut(44, "Respawn at the checkpoint flag and straight back into the run",
		func() -> bool: return _flags.get("respawned", false) and absf(r.velocity.x) > 50.0,
		func() -> Vector2: return Stage.checkpoints()[11], {"subject_name": "checkpoint", "subject_r": 50.0, "wait": false,
		"start_when": func() -> bool: return r.state != Runner.State.DEAD})
	await until(func() -> bool: return r.state != Runner.State.DEAD, 200)
	_flags["respawned"] = r.global_position.distance_to(Stage.checkpoints()[11] + Vector2(0, 27)) < 90.0
	# YOU is back on cover duty for the rest of the run.
	cover = true
	cover_radius = 150.0
	await frames(10)
	hold(1.0)
	await until(x_past(26400), 60)
	release()
	await end_cut()

	# 45 WHAT ARE THOSE BLOCKS?: YOU builds two very questionable steps.
	camera({"mode": "fixed", "at": Vector2(26560, 400), "zoom": 1.15, "snap": true, "fx": 0.3})
	await cut(45, "YOU traces temporary blocks at awkward angles over the spike bed: a steep slant and one far too high",
		func() -> bool:
			var live: Array = main.guardian.holograms_of(Hologram.Kind.PLATFORM)
			var slanted := false
			for h in live:
				if h.path.size() >= 2:
					var d: Vector2 = h.path[-1] - h.path[0]
					if absf(atan2(d.y, d.x)) > deg_to_rad(20.0):
						slanted = true
			return live.size() >= 2 and slanted,
		func() -> Vector2: return Vector2(26580, 360), {"subject_name": "odd blocks", "subject_r": 90.0})
	await trace(PackedVector2Array([Vector2(26468, 470), Vector2(26556, 380)]), 7)
	await frames(4)
	await trace(PackedVector2Array([Vector2(26600, 330), Vector2(26690, 330)]), 6)
	await end_cut()

	# 46 THAT WAS NOT THE PLAN: scramble up the slant, over, and on.
	hide_pointer()
	camera({"mode": "follow", "zoom": 1.35, "lead": 60.0, "offset": Vector2(60, -150), "smooth": 7.0, "rotation": 0.04, "snap": true, "fx": 0.3})
	Events.runner_landed_on_hologram.connect(func(_h: Node2D) -> void: _flags["touched_block"] = true)
	await cut(46, "The runner scrambles onto the bad slant and up onto the too-high block, wobbling but safe",
		func() -> bool: return _flags.get("touched_block", false) and r.global_position.x > 26595.0 and r.global_position.y < 330.0 and r.is_on_floor(),
		func() -> Vector2: return Vector2(26600, 360), {"subject_name": "odd blocks", "subject_r": 90.0})
	await hop_to(Vector2(26520, 420))
	await hop_to(Vector2(26645, 318))
	await end_cut()
	await hop_to(Vector2(26790, 420))

# -------------------------------------------------- 46-49 s: the end cards
func take_end() -> void:
	cover = true
	cover_radius = 160.0
	# Upper half: the run goes on, the runner riding high in the frame.
	camera({"mode": "follow", "zoom": 1.15, "lead": 160.0, "offset": Vector2(170, 170), "smooth": 6.0, "smooth_y": 5.0, "fx": 0.3})
	var upper := func() -> bool: return screen_of(r.global_position).y < 720.0 * 0.48
	var card := func(n: int) -> Callable:
		return func() -> void:
			overlay.lower_panel = true
			overlay.card = n
			overlay.card_t = 0.0
	hold(1.0)
	await until(x_past(26900), 60)
	title_to(TITLE_SCALE * 0.5, Vector2(640, 112), 1.0, 20)

	# 47 AVAILABLE IN STORES: Google Play and App Store badges only.
	await cut(47, "Upper half: the run continues. Lower half: the Google Play and App Store badges only",
		func() -> bool: return overlay.card == 1 and upper.call(),
		Callable(), {"on_start": card.call(1), "always": upper, "always_desc": "runner in the upper half"})
	await until(x_past(27030), 200)
	hold(0.0)
	await until(func() -> bool: return machine("saw_c").centre().y > 95.0, 200)
	await until(func() -> bool: return machine("saw_c").centre().y < 45.0, 200)
	hold(1.0, true)
	await until(x_past(27260), 100)

	# 48 COMING OCTOBER 2026: previous card gone; the date only.
	cut(48, "Upper half: the run continues. Lower half: COMING OCTOBER 2026 only",
		func() -> bool: return overlay.card == 2 and upper.call(),
		Callable(), {"on_start": card.call(2), "wait": false, "always": upper, "always_desc": "runner in the upper half"})
	var lift: MovingPlatform = null
	for node in main.level.find_children("*", "", true, false):
		if node is MovingPlatform:
			lift = node
	release()
	await until(func() -> bool: return lift.global_position.y > 500.0, 300)
	await hop_to(func() -> Vector2: return lift.global_position + Vector2(0, -13))
	await until(func() -> bool: return lift.global_position.y < 400.0, 300)
	await hop_to(Vector2(27760, 480))

	# 49 CREATED BY: previous card gone; the credit only.
	cut(49, "Upper half: the run continues to the goal. Lower half: Created by Takumi & TyoRo only",
		func() -> bool: return overlay.card == 3 and upper.call(),
		Callable(), {"on_start": card.call(3), "wait": false, "always": upper, "always_desc": "runner in the upper half"})
	hold(1.0, true)
	await until(x_past(28100), 300)
	await hop_to(Vector2(28250, 420))
	hold(1.0)
	await end_cut()
	release()
