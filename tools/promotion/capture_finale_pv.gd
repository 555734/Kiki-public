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
## On-air length of each storyboard beat (frames). The 49 beats keep the
## storyboard's order and its 49 s total (2,940 frames), but not one second
## each: a beat runs as long as its action needs, and consecutive beats of a
## take are one continuous shot when the camera is not snapped between them.
const BEAT_FRAMES := {
	1: 50, 2: 46, 3: 74, 4: 70, 5: 56, 6: 50, 7: 74, 8: 52, 9: 50, 10: 78,
	11: 56, 12: 66, 13: 58, 14: 52, 15: 62, 16: 66,
	17: 40, 18: 120, 19: 46, 20: 54,
	21: 66, 22: 60, 23: 66, 24: 48,
	25: 50, 26: 44, 27: 58, 28: 46, 29: 52, 30: 50,
	31: 48, 32: 84, 33: 80,
	34: 66, 35: 58, 36: 48, 37: 64, 38: 54, 39: 78,
	40: 60, 41: 60, 42: 60, 43: 66, 44: 54, 45: 60, 46: 60,
	47: 60, 48: 60, 49: 60,
}
## The visible size of the view (1280x720 at 16:9; taller when the window is
## taller, e.g. the vertical short's 1080x976 window shows 1280x1157).
var VIEW := Vector2(1280, 720)

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
	var total := 0
	for k in BEAT_FRAMES:
		total += int(BEAT_FRAMES[k])
	assert(total == 2940, "beats must add up to 49 s (got %d frames)" % total)
	process_priority = 250
	z_index = 50
	for s in SHOTS.all():
		shots[int(s["shot"])] = s
	rendering = DisplayServer.get_name() != "headless"
	VIEW = get_viewport().get_visible_rect().size
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
	# PV_NO_TITLE=1: the takes without the in-game MELOS GAME title (the short
	# PV puts its own name card at the end).
	behind.visible = OS.get_environment("PV_NO_TITLE") != "1"
	_connect_log()
	call_deferred("run")

# --------------------------------------------------------------- event log
func log_event(ev: String, detail: String = "") -> void:
	var at := r.global_position if r != null else Vector2.ZERO
	events.append({"frame": Engine.get_process_frames(), "cut": int(row.get("shot", 0)) if on_air else 0,
		"cut_frame": cut_frames if on_air else -1, "ev": ev, "detail": detail,
		"runner": [roundf(at.x), roundf(at.y)], "tick": Clock.tick})
	if _trace_on and ev != "sound":
		_trace_mark_next += ("%s%s%s" % [" | " if _trace_mark_next != "" else "", ev, (": " + detail.replace("\"", "'")) if detail != "" else ""])
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
		if OS.get_environment("HOP_LOG") != "" and i % 3 == 0:
			print("      hop f%d %s v%s st%d floor%s" % [i, r.global_position.round(), r.velocity.round(), r.state, r.is_on_floor()])
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
	if _land_fx.size() == 2 and int(_land_fx[1]) < 26:
		var at: Vector2 = _land_fx[0]
		var k := float(_land_fx[1]) / 26.0
		_land_fx[1] = int(_land_fx[1]) + 1
		draw_set_transform(at, 0.0, Vector2(1.0, 0.32))
		draw_arc(Vector2.ZERO, 18.0 + 70.0 * k, 0.0, TAU, 32, Color(0.75, 0.95, 1.0, 0.9 * (1.0 - k)), 6.0 * (1.0 - k) + 1.5, true)
		draw_set_transform(Vector2.ZERO)
		for i in 8:
			var a := PI + PI * (float(i) + 0.5) / 8.0
			draw_circle(at + Vector2(cos(a) * (14.0 + 46.0 * k), -6.0 + sin(a) * 26.0 * k), 5.0 * (1.0 - k) + 1.0, Color(0.85, 0.97, 1.0, 0.85 * (1.0 - k)))
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
	var at := r.global_position + Vector2(lead, 0) + off
	if cam.has("lock_y"):
		at.y = float(cam["lock_y"])
	return at

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
func world_of(screen: Vector2) -> Vector2:
	var c: Camera2D = main.camera
	return (screen - VIEW * 0.5).rotated(c.rotation) / c.zoom.x + c.global_position + c.offset

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
	# Not quite zero: moving bodies divide by the step (a zero step turns
	# a rider's velocity into NaN).
	Engine.time_scale = 0.02

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
	rw["frames"] = int(opts.get("frames", BEAT_FRAMES.get(n, CUT_FRAMES)))
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
	if cut_frames >= int(row["frames"]):
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
	rw["hero_on_screen"] = snappedf(float(rw["hero_on"]) / float(rw["frames"]), 0.01)
	var subj_ok := true
	if rw["_subject"].is_valid():
		rw["subject_on_screen"] = snappedf(float(rw["subject_on"]) / float(rw["frames"]), 0.01)
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
	_trace_step()
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
		"cut_frames": CUT_FRAMES, "beat_frames": BEAT_FRAMES, "shots": rows, "passed": ok, "total": rows.size(), "events": events,
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

## --take=stills: PV_STILLS="x,y,zoom;x,y,zoom;..." -> stills/NN.png. The
## runner stands at each point (feet), the camera frames it at that zoom.
func take_stills() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "stills"))
	var spec := OS.get_environment("PV_STILLS").split(";", false)
	for i in spec.size():
		var v := spec[i].split(",")
		var at := Vector2(float(v[0]), float(v[1]))
		var z := float(v[2]) if v.size() > 2 else 1.6
		await begin_take(at + Vector2(0, -24), 0)
		camera({"mode": "fixed", "at": at + Vector2(0, -40), "zoom": z, "snap": true})
		await frames(int(v[3]) if v.size() > 3 else 8)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "stills/%02d.png" % i))
		print("still %d at %s zoom %.2f" % [i, at, z])

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
	var lip := Vector2(1540, 1160)
	var bank := Vector2(2300, 1040)
	hold(1.0, true)
	await until(x_past(envf("PV_OPEN_X", 560.0)), 200)

	# 1 DOWNHILL START: a low, close tracking shot on the sprint; the one
	# enemy walks up into the frame from the right.
	# SHOT 1 (fixed, a slow drift right): the runner crosses the frame.
	camera({"mode": "fixed", "at": Vector2(1000, 990), "pan_to": Vector2(1130, 1000), "pan_frames": 110, "zoom": 1.3, "snap": true, "fx": 0.0})
	await cut(1, "Runner sprints down the curved green slope; a single enemy walks up toward them",
		func() -> bool: return r.velocity.x > 300.0 and r.is_on_floor() and bug.global_position.x - r.global_position.x < 700.0,
		func() -> Vector2: return bug.global_position, {"subject_name": "burrbug", "subject_r": 26.0})

	_trace_on = true
	_trace_rows.clear()
	_trace_mark("take_start", "variant %s" % OS.get_environment("PV_RESCUE"))

	# 2 ONE ENEMY, ONE LEAP: the hop over it, camera level again; the
	# ground ends ahead.
	await cut(2, "Runner jumps cleanly over the one enemy and lands running; the gap ahead comes into view",
		func() -> bool: return _flags.get("cleared_enemy", false),
		func() -> Vector2: return bug.global_position, {"subject_name": "burrbug", "subject_r": 26.0})
	await until(func() -> bool: return bug.global_position.x - r.global_position.x < 150.0, 90)
	_trace_mark("hop_enemy", "bug at %s" % bug.global_position.round())
	await jump(15)
	hold(1.0, true)
	await until(func() -> bool: return r.global_position.x > bug.global_position.x + 30.0 and r.is_on_floor(), 70)
	_flags["cleared_enemy"] = r.hp == Balance.RUNNER_MAX_HP and r.global_position.x > bug.global_position.x

	# The rescue (PV_RESCUE=nohelp: the same leap, nobody answers). Both
	# takes run the same inputs and the same camera up to the top of the
	# arc ("branch"); the edit joins them there (tools/promotion/
	# edit_rescue_versions.py). The runner moves only by the game's own
	# physics; slow motion is the engine's time scale (the fall goes on).
	var nohelp := OS.get_environment("PV_RESCUE") == "nohelp"

	# THE LEAP: both cliffs, the gap and the drop, as the runner sprints
	# off the lip -- framed as close as that allows.
	# CAMERA A (fixed, wide): both cliffs, the gap and the drop. It does not
	# move for the leap, the fall, the failure or the rewind; the runner rises
	# and falls through it.
	camera({"mode": "fixed", "at": GORGE_SHOT, "zoom": GORGE_ZOOM, "snap": true, "fx": 0.0})
	_trace_mark("wide", "the gorge: both cliffs and the drop")
	await cut(3, "The runner sprints off the left cliff toward a higher far bank that is too far; the gorge drops into the dark",
		func() -> bool: return not r.is_on_floor() and r.global_position.x > lip.x + 20.0,
		func() -> Vector2: return bank, {"subject_name": "far bank", "subject_r": 60.0, "establish": true, "hero_floor": 0.06, "frames": 44})
	hold(1.0, true)
	await until(x_past(1525), 80)
	_jump = true
	_trace_mark("jump_start", "take-off x %.0f vx %.0f" % [r.global_position.x, r.velocity.x])
	await frames(18)
	_jump = false
	await until(func() -> bool: return r.velocity.y > -60.0, 30)
	_jump = true
	_trace_mark("air_jump", "x %.0f: the last of the runner's height" % r.global_position.x)
	await frames(14)
	_jump = false
	# BRANCH: just after the air jump, still rising, 471 px short of where
	# the arc will top out. Up to here both takes are the same frame for
	# frame; the rewind ends here.
	_trace_mark("branch", "rising after the air jump at %s v %s, %.0f px short of the bank" % [r.global_position.round(), r.velocity.round(), bank.x - r.global_position.x])

	if nohelp:
		# THE FALL: nobody answers. Close on the runner, the dark below.
		cut(4, "Short of the bank, the runner falls past its edge into the dark gorge",
			func() -> bool: return feet().y > bank.y + 300.0, Callable(), {"wait": false, "frames": 110, "allow_hurt": true,
			"on_start": func() -> void: pass})
		await until(func() -> bool: return r.velocity.y >= 0.0, 60)
		_trace_mark("apex", "top of the arc at %s, %.0f px short of the bank" % [r.global_position.round(), bank.x - r.global_position.x])
		sfx("whoosh", -4.0, 0.8)
		await until(func() -> bool: return feet().y > FAIL_FEET_Y, 200)
		_trace_mark("fail_end", "deep in the gorge at %s, vy %.0f; nothing under the runner" % [r.global_position.round(), r.velocity.y])
		await until(func() -> bool: return r.state == Runner.State.DEAD, 120)
		_trace_mark("death", "runner %s" % r.global_position.round())
		await end_cut()
		_trace_on = false
		_write_trace("nohelp")
		return

	# SHOT B1 (a cut on the rewind's end; fixed): close on the runner at the
	# top of the arc -- the slow fall, the call, the accept; the finger then
	# dives out of the bottom of the frame toward the catch.
	camera({"mode": "fixed", "at": CALL_SHOT, "zoom": CALL_ZOOM, "snap": true, "fx": 0.0})
	# SLOW MOTION from the moment the rewind ends: the whole game runs on the
	# engine's time scale (0.35x, 0.28x for the call, 0.30x while the finger
	# works, 0.45x just before the landing); the call card and the YOU cursor
	# keep real time. The slow motion starts at the top of the arc, where the
	# runner barely moves, so the catch stays at the height the escape needs.
	ramp_time(envf("PV_SLOW_A", 0.35), 6)
	_trace_mark("slow_in", "time scale -> %.2f at %s" % [envf("PV_SLOW_A", 0.35), r.global_position.round()])
	await frames(int(envf("PV_SLOW_A_FRAMES", 12.0)))
	_trace_mark("apex", "near the top of the arc (slow) at %s v %s" % [r.global_position.round(), r.velocity.round()])
	ramp_time(envf("PV_SLOW_B", 0.25), 8)
	overlay.call_centre = Vector2(165, 185)
	overlay.call_scale = 0.5
	overlay.call_dim = 0.06
	overlay.call_state = 1
	overlay.call_t = 0.0
	sfx("ring", 0.0, 1.0)
	_trace_mark("call", "runner %s v %s" % [r.global_position.round(), r.velocity.round()])
	cut(4, "In slow motion the runner falls; the call comes in (Discord mark, decline, accept) at real speed in the top-left corner",
		func() -> bool: return overlay.call_alpha > 0.9 and overlay.call_state == 1 and not r.is_on_floor(), Callable(),
		{"wait": false, "frames": 56})
	await fade_call(1.0, 8)
	await frames(18)
	sfx("ring", 0.0, 1.0)
	await frames(12)
	# ANSWER: the YOU cursor appears on the card, presses accept, a beat...
	var acc := world_of(overlay.call_accept_pos())
	pointer = acc + Vector2(70, 60) / main.camera.zoom.x
	_pointer_alpha_to = 1.0
	await point(acc, 10)
	overlay.call_state = 2
	overlay.call_t = 0.0
	overlay.pointer_pop = 1.0
	sfx("accept")
	release()
	ramp_time(envf("PV_SLOW_C", 0.30), 4)
	_trace_mark("call_answered", "runner %s v %s" % [r.global_position.round(), r.velocity.round()])
	await frames(8)
	fade_call(0.0, 10)
	# ...then rushes (real time) to where the slowly falling runner will be: a
	# short platform aimed from the runner's own fall (terminal speed down,
	# the air brake on the drift), as far below as the rest of the slow
	# motion will carry them.
	# How far the runner falls while YOU rushes in and strokes (the frames
	# below, at this time scale, at full fall speed), plus a short approach
	# so the platform is there, building, a beat before they reach it.
	var stroke_frames := int(envf("PV_DASH_FRAMES", 12.0)) + int(envf("PV_STROKE_FRAMES", 10.0)) + 6
	var top1 := feet().y + Balance.RUNNER_TERMINAL_VELOCITY * envf("PV_SLOW_C", 0.30) * float(stroke_frames) / 60.0 + envf("PV_P1_APPROACH", 70.0)
	var t_hit := (top1 - feet().y) / maxf(r.velocity.y, 1.0)
	var vx0 := r.velocity.x
	var tt := minf(t_hit, vx0 / Balance.RUNNER_AIR_RELEASE_BRAKE)
	var x_land := r.global_position.x + vx0 * tt - 0.5 * Balance.RUNNER_AIR_RELEASE_BRAKE * tt * tt
	var p1 := PackedVector2Array([Vector2(x_land - 44.0, top1 + 13.0), Vector2(x_land + 46.0, top1 + 13.0)])
	_trace_mark("aim_1", "landing predicted at x %.0f; platform top %.0f (%.0f px under the feet)" % [x_land, top1, top1 - feet().y])
	cut(5, "The call is answered: the YOU cursor rushes at full speed from the card to below the slowly falling runner",
		func() -> bool: return overlay.pointer_alpha > 0.8 and pointer.y > r.global_position.y, Callable(), {"wait": false, "frames": 22})
	await point(p1[0], int(envf("PV_DASH_FRAMES", 12.0)))
	overlay.pointer_pop = 1.0
	cut(6, "YOU strokes a short platform under the slowly falling runner; its blocks build; the runner drops onto it",
		func() -> bool: return _flags.get("on_holo", false), func() -> Vector2: return (p1[0] + p1[1]) * 0.5,
		{"subject_name": "platform", "subject_r": 50.0, "wait": false, "frames": 70})
	# SHOT B2 (a cut as the finger starts its stroke; fixed until the jump to
	# the bank): the runner falls in from the top, the platform is drawn and
	# built under them, they land, recover and hop onto the next step.
	camera({"mode": "fixed", "at": CATCH_SHOT, "zoom": CATCH_ZOOM, "snap": true, "fx": 0.0})
	sfx("build_glow", 2.0, 1.0)
	_trace_mark("stroke_start", "runner %s vy %.0f; stroke y %.0f x %.0f..%.0f" % [r.global_position.round(), r.velocity.y, p1[0].y, p1[0].x, p1[1].x])
	var built := await trace(p1, int(envf("PV_STROKE_FRAMES", 10.0)))
	if built == null:
		push_error("rescue: platform 1 was refused")
	else:
		_trace_mark("platform_1", "created: top %.0f, x %.0f..%.0f (%.0f wide); runner feet %.0f (%.0f px above it), x %.0f" % [built.global_position.y - 13.0, p1[0].x, p1[1].x, p1[1].x - p1[0].x, feet().y, built.global_position.y - 13.0 - feet().y, r.global_position.x])
	# The blocks build (game time) while the runner comes down onto them,
	# time easing up toward full speed.
	ramp_time(envf("PV_SLOW_D", 0.45), 10)
	var vy_hit := r.velocity.y
	while not r.is_on_floor() and r.state != Runner.State.DEAD:
		vy_hit = r.velocity.y
		await frames(1)
	# CONTACT: the biggest change of speed -- a short hit stop, then full speed.
	_trace_mark("contact_1", "fall stopped by platform 1: vy %.0f -> %.0f, feet %.0f, x %.0f" % [vy_hit, r.velocity.y, feet().y, r.global_position.x])
	Engine.time_scale = 1.0
	_ramp = [1.0, 1.0, 0, 0]
	hitstop(5)
	_land_fx = [feet(), 0]
	sfx("thud", 4.0, 1.0)
	await frames(5)
	_trace_mark("normal_speed", "time scale back to 1.0")
	await frames(int(envf("PV_LINGER_FRAMES", 24.0)))

	# OUT: knees bent, back up; the finger adds the next step toward the bank;
	# a hard jump to it, at once off it onto the bank, running on.
	var top2 := top1 - envf("PV_P2_RISE", 112.0)
	var p2x := minf(p1[1].x + envf("PV_P2_GAP", 30.0), bank.x - 150.0)
	var p2 := PackedVector2Array([Vector2(p2x, top2 + 13.0), Vector2(p2x + 92.0, top2 + 13.0)])
	cut(7, "Caught, the runner springs to a second short platform the finger adds, onto the higher far bank, and runs on",
		func() -> bool: return r.is_on_floor() and r.global_position.x > bank.x + 60.0, func() -> Vector2: return bank,
		{"subject_name": "far bank", "subject_r": 60.0, "wait": false, "frames": 150, "on_start": func() -> void: pass})
	sfx("build_glow", 3.0, 0.85)
	var built2 := await trace(p2, 6)
	if built2 != null:
		_trace_mark("platform_2", "created: top %.0f, x %.0f..%.0f (%.0f wide); runner at %s" % [built2.global_position.y - 13.0, p2[0].x, p2[1].x, p2[1].x - p2[0].x, r.global_position.round()])
	hide_pointer()
	hold(1.0, true)
	await until(func() -> bool: return r.global_position.x > p1[1].x - 40.0, 40)
	_jump = true
	_trace_mark("jump_to_step", "from platform 1 at %s" % r.global_position.round())
	await frames(12)
	_jump = false
	await until(func() -> bool: return r.is_on_floor() and r.global_position.x > p2[0].x, 50)
	_trace_mark("on_step", "runner %s" % r.global_position.round())
	_land_fx = [feet(), 0]
	await frames(2)
	_jump = true
	_trace_mark("jump_to_bank", "from platform 2 at %s" % r.global_position.round())
	# SHOT C (a cut on the jump; fixed, then a slow sideways follow once on
	# the bank): the arc up onto the far bank and the run on.
	camera({"mode": "fixed", "at": ESCAPE_SHOT, "zoom": ESCAPE_ZOOM, "snap": true, "fx": 0.0})
	await frames(14)
	_jump = false
	await until(func() -> bool: return r.velocity.y > -80.0, 30)
	_jump = true
	await frames(10)
	_jump = false
	await until(func() -> bool: return r.is_on_floor() and r.global_position.x > bank.x, 60)
	_trace_mark("bank", "on the far bank at %s" % r.global_position.round())
	camera({"mode": "follow", "zoom": ESCAPE_ZOOM, "lead": 0.0, "offset": Vector2(120, 0), "lock_y": ESCAPE_SHOT.y, "smooth": 1.2, "fx": 0.0})
	_land_fx = [feet(), 0]
	sfx("checkpoint", 0.0, 0.8)
	await until(func() -> bool: return r.global_position.x > bank.x + 640.0, 120)
	_trace_mark("clip_end", "running on at %s" % r.global_position.round())
	await end_cut()
	release()
	_trace_on = false
	overlay.call_centre = Vector2(VIEW.x - 150 - 70, VIEW.y * 0.5)
	overlay.call_scale = 1.0
	overlay.call_dim = 0.28
	_write_trace("help")

## The rescue's one fixed shot (world centre, zoom): both cliffs' edges, the
## gap, the drop, the top of the leap, the call card's corner and the catch
## platform, for the leap, the fall, the rewind, the call and the catch.
const GORGE_SHOT := Vector2(1960, 1100)
const GORGE_ZOOM := 1.1
## Where the failed fall is cut (feet), still inside that frame.
const FAIL_FEET_Y := 1400.0
## The rescue's fixed shots, cut on the action. B1: the top of the arc and
## the call (the runner keeps its horizontal place on screen across the cut
## from the wide shot). B2: the catch -- the runner falls in from the top,
## the platform and the finger's hand below. C: the jump to the far bank.
const CALL_SHOT := Vector2(1886, 920)
const CALL_ZOOM := 2.2
const CATCH_SHOT := Vector2(2050, 1183)
const CATCH_ZOOM := 1.9
const ESCAPE_SHOT := Vector2(2113, 1100)
const ESCAPE_ZOOM := 1.3

## A short burst at the runner's feet when they land on a drawn platform
## (director overlay, world space): [position, age in frames].
var _land_fx: Array = []

## Per-frame state of the runner while a rescue take is on (CSV), with the
## events of the take marked on the frame they happened.
var _trace_on := false
var _trace_rows: Array = []
var _trace_mark_next := ""
var _trace_floor := false

func _trace_mark(ev: String, detail: String = "") -> void:
	log_event(ev, detail)

func _trace_step() -> void:
	if not _trace_on or r == null:
		return
	var fl := r.is_on_floor()
	var ev := _trace_mark_next
	_trace_mark_next = ""
	if fl != _trace_floor:
		ev += ("%s%s" % [" | " if ev != "" else "", "floor_on" if fl else "floor_off"])
		_trace_floor = fl
	_trace_rows.append([Engine.get_process_frames(), int(row.get("shot", 0)) if on_air else 0, cut_frames if on_air else -1,
		Clock.tick, snappedf(Engine.time_scale, 0.001), roundf(r.global_position.x), roundf(r.global_position.y),
		roundf(r.velocity.x), roundf(r.velocity.y), fl, r.is_on_wall(), r.state, r.state == Runner.State.DEAD,
		snappedf(main.camera.get_screen_center_position().x, 0.1), snappedf(main.camera.get_screen_center_position().y, 0.1),
		snappedf(main.camera.zoom.x, 0.001), ev])

func _write_trace(variant: String) -> void:
	var f := FileAccess.open(OUT + "rescue_trace_%s.csv" % variant, FileAccess.WRITE)
	f.store_line("process_frame,beat,beat_frame,clock_tick,time_scale,x,y,vx,vy,on_floor,on_wall,state,dead,cam_x,cam_y,cam_zoom,events")
	for rw in _trace_rows:
		var cells: Array = []
		for v in rw:
			cells.append(("\"%s\"" % v) if v is String else str(v))
		f.store_line(",".join(cells))
	f.close()
	print("rescue trace: %d rows -> rescue_trace_%s.csv" % [_trace_rows.size(), variant])

func _nearest_launch_ring() -> LaunchTrigger:
	var best: LaunchTrigger = null
	for t in get_tree().get_nodes_in_group("launch_trigger"):
		if t is LaunchTrigger and (t as LaunchTrigger).armed and (best == null \
				or (t as Node2D).global_position.distance_to(r.global_position) < best.global_position.distance_to(r.global_position)):
			best = t
	return best

## Runs beside the leap: time comes back once the sphere is under the
## runner; notes when the runner is safe on the ledge.
func _watch_ball(ball: FinaleMachine) -> void:
	for i in 160:
		if ball.centre().x > r.global_position.x - 150.0 and not _flags.get("ball_slow", false):
			_flags["ball_slow"] = true
			ramp_time(0.22, 5)
			sfx("whoosh", 2.0, 0.8)
		if ball.centre().x > r.global_position.x and not _flags.get("ball_under", false):
			_flags["ball_under"] = true
			log_event("ball_under", "runner y %.0f ball y %.0f" % [r.global_position.y, ball.centre().y])
			ramp_time(1.0, 14)
		if r.is_on_floor() and r.global_position.y < 2440.0 and r.global_position.x > 9390.0:
			_flags["on_ledge"] = true
		if _flags.get("on_ledge", false) and _flags.get("ball_under", false):
			return
		await get_tree().process_frame

## Beside the dive through the gate: time drags as the jaws reach the
## runner, and stops dead for a beat when they slam shut.
func _watch_jaws(gate: float) -> void:
	var slowed := false
	for i in 200:
		var b := machine("beast")
		if b == null:
			return
		if not slowed and r.global_position.x > gate - 140.0:
			slowed = true
			ramp_time(0.3, 6)
		if b._snapped:
			hitstop(6)
			_shake = 16.0
			await frames(7)
			ramp_time(1.0, 10)
			return
		await get_tree().process_frame

## Beside the train-to-train leap: slow over the gap between the trains.
func _watch_gap(b_rear: Callable) -> void:
	var slowed := false
	for i in 120:
		if not slowed and not r.is_on_floor() and r.global_position.x > float(b_rear.call()) - 200.0:
			slowed = true
			ramp_time(0.35, 5)
		if slowed and (r.is_on_floor() or r.global_position.x > float(b_rear.call()) + 20.0):
			ramp_time(1.0, 8)
			return
		await get_tree().process_frame

func envf(key: String, fallback: float) -> float:
	return float(OS.get_environment(key)) if OS.get_environment(key) != "" else fallback

# ------------------------------------------------- 10-13 s: thunder bridge
func take_storm() -> void:
	var storm := machine("storm")
	await begin_take(Vector2(3000, 957), 1)
	storm = machine("storm")
	# Off air: wait for the arc on the first raised stone to be in its
	# quiet phase by the time the runner lands on it (cut 13).
	var phase := float(OS.get_environment("PV_STORM_PHASE")) if OS.get_environment("PV_STORM_PHASE") != "" else 1.7
	await until(func() -> bool: return absf(fposmod(Clock.seconds_at(Clock.tick), 3.0) - phase) < 0.02, 200)
	camera({"mode": "fixed", "at": Vector2(3360, 940), "pan_to": Vector2(3520, 950), "zoom": 1.4, "snap": true, "fx": 0.3})
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
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.75, "lead": 60.0, "offset": Vector2(110, -80), "smooth": 6.0, "fx": 0.5})})
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
	camera({"mode": "fixed", "at": Vector2(6330, 960), "pan_to": Vector2(6520, 900), "zoom": 1.3, "zoom_from": 1.7, "zoom_frames": 55, "snap": true, "fx": 0.3})
	hold(1.0, true)
	await frames(int(OS.get_environment("PV_SAND_LEAD")) if OS.get_environment("PV_SAND_LEAD") != "" else 34)
	camera({"mode": "fixed", "at": Vector2(6380, 960), "pan_to": Vector2(6560, 900), "zoom": 1.3, "zoom_from": 1.7, "zoom_frames": 55, "snap": true, "fx": 0.3})

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
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.6, "lead": 0.0, "offset": Vector2(30, 50), "smooth": 9.0, "smooth_y": 10.0, "fx": 0.8})})
	# Steer the fall down the clear lane between the rockfalls.
	for i in 150:
		_axis = clampf((7238.0 - r.global_position.x) / 40.0, -1.0, 1.0)
		_sprint = false
		if i == 26:
			camera({"mode": "follow", "zoom": 1.45, "lead": 0.0, "offset": Vector2(20, 190), "smooth": 9.0, "smooth_y": 14.0, "fx": 0.8})
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
	camera({"mode": "follow", "zoom": 1.55, "zoom_from": 1.3, "zoom_frames": 30, "lead": 0.0, "offset": Vector2(120, 40), "smooth": 9.0, "smooth_y": 16.0, "snap": true, "fx": 0.6})
	await cut(17, "The runner drops into the volcano core and slams down on the basalt floor, lava glowing all around",
		func() -> bool: return r.is_on_floor() and r.global_position.y > 2600.0,
		func() -> Vector2: return Vector2(7400, 2700), {"subject_name": "volcano floor", "subject_r": 120.0})
	await until(func() -> bool: return r.is_on_floor(), 60)
	hitstop(4)
	sfx("thud", 0.0, 1.0)
	_shake = 10.0
	punch(0.12, 10)
	hold(1.0, true)
	camera({"mode": "follow", "zoom": 1.45, "lead": 200.0, "offset": Vector2(160, -40), "smooth": 6.0, "fx": 0.6})
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

	# 18 HOT PURSUIT, in three moves. (a) The runner steps past the trigger;
	# the sphere bursts out of its tube right behind them: close, low, the
	# ball filling the left of the frame. (b) The runner flees down the
	# cracked slope at a run, and the sphere, speeding up, closes the gap:
	# the camera trucks with both. (c) It is on their heels: the runner
	# leaps for the escape ledge, time drags while the sphere rolls through
	# under their feet, and it smashes the crust bridge into the lake.
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(170, -20), func() -> Vector2: return ball.centre() + Vector2(-60, 0)],
		"pad": 90.0, "zoom": 2.0, "min_zoom": 1.45, "smooth": 9.0, "fx": 0.9, "snap": true, "offset": Vector2(0, -30)})
	await cut(18, "The magma sphere bursts out right behind the runner, chases them down the slope, nearly catches them, and rolls under their leap to the ledge",
		func() -> bool: return _flags.get("ball_under", false) and _flags.get("on_ledge", false) and r.hp == Balance.RUNNER_MAX_HP,
		func() -> Vector2: return ball.centre(), {"subject_name": "magma sphere", "subject_r": 100.0})
	hold(1.0)
	await until(func() -> bool: return ball.state == 1, 60)
	punch(0.22, 14)
	_shake = 9.0
	# (b) flee at a run: the sphere gains on the runner.
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(220, -40), func() -> Vector2: return ball.centre() + Vector2(-40, 0)],
		"pad": 80.0, "zoom": 1.85, "min_zoom": 1.4, "smooth": 7.0, "fx": 0.9, "rotation": 0.05})
	hold(1.0)
	var gap := func() -> float: return r.global_position.x - ball.centre().x
	await until(x_past(envf("PV_BALL_SPRINT", 9050.0)), 150)
	hold(1.0, true)
	await until(x_past(envf("PV_BALL_LEAP", 9290.0)), 150)
	log_event("ball_close", "gap %.0f" % gap.call())
	# (c) the leap; the sphere passes under in slow motion.
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(40, -30), func() -> Vector2: return ball.centre(), func() -> Vector2: return Vector2(9470, 2420)],
		"pad": 70.0, "zoom": 2.1, "min_zoom": 1.5, "smooth": 10.0, "fx": 0.7, "rotation": -0.03})
	_watch_ball(ball)
	await hop_to(Vector2(9480, 2420), true)
	await until(func() -> bool: return _flags.get("on_ledge", false), 60)
	Engine.time_scale = 1.0
	log_event("on_escape_ledge")
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position, func() -> Vector2: return ball.centre()],
		"pad": 120.0, "zoom": 1.6, "min_zoom": 1.1, "smooth": 6.0, "fx": 1.0})
	release()
	await until(func() -> bool: return ball.sunk() or not on_air, 120)

	await end_cut()
	# 19 SWING OVER LAVA: from the ledge onto a chain-hung platform.
	hold(1.0)
	await until(x_past(9540), 60)
	release()
	var moving_left := func(m: FinaleMachine) -> bool: return m.offset_at(Clock.tick + 1).x < m.offset_at(Clock.tick).x
	await until(func() -> bool: return machine("swing_a")._deck.global_position.x < 9960.0 and moving_left.call(machine("swing_a")), 300)
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position, func() -> Vector2: return machine("swing_a").global_position + Vector2(0, 60),
		func() -> Vector2: return machine("swing_a")._deck.global_position + Vector2(0, 30)], "pad": 90.0, "zoom": 1.7, "min_zoom": 1.25, "smooth": 6.0, "fx": 0.4, "snap": true})
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
	camera({"mode": "follow", "zoom": 1.6, "lead": 0.0, "offset": Vector2(120, -110), "smooth": 8.0, "smooth_y": 12.0, "snap": true, "fx": 0.6})
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
	camera({"mode": "follow", "zoom": 1.85, "lead": 170.0, "offset": Vector2(100, 30), "smooth": 9.0, "smooth_y": 3.0, "snap": true, "fx": 0.3, "rotation": 0.03})

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
		"on_start": func() -> void: camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position, func() -> Vector2: return Vector2(b_rear.call() + 100.0, rail().roof_y(1, 0) - 40.0),
			func() -> Vector2: return Vector2(r.global_position.x, rail().roof_y(1, 0) + 130.0)],
			"pad": 110.0, "zoom": 1.7, "min_zoom": 1.25, "smooth": 8.0, "fx": 0.3, "rotation": -0.04})})
	await hop_to(func() -> Vector2: return Vector2(b_rear.call() + 120.0, rail().roof_y(1, 0)), true)
	Engine.time_scale = 1.0
	_ramp = [1.0, 1.0, 0, 0]
	_flags["leapt_trains"] = r.global_position.x > b_rear.call() and r.is_on_floor()
	log_event("rail_state", "beat %.2f rear1 %.0f car1 %.0f..%.0f riding %d drop1 t=%.2f land=%.2f" % [rail().beat(), rail().car_x(1, 0, rail().beat()),
		rail().car_x(1, 1, rail().beat()), rail().car_x(1, 1, rail().beat()) + 300.0, rail()._riding(), rail()._drops[1]["t"], rail()._drops[1]["land"]])

	# 23 CRANE DROPS: a crate drops from the crane; change course at once.
	var drop: Dictionary = rail()._drops[1]
	hold(1.0)
	await until(func() -> bool: return rail().beat() > float(drop["t"]) - 0.55, 400)
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(0, 40), func() -> Vector2: return rail().crate_at(1, rail().beat())[0] + Vector2(0, -60)],
		"pad": 90.0, "zoom": 1.75, "min_zoom": 1.2, "smooth": 8.0, "fx": 0.8, "offset": Vector2(40, 0)})
	cut(23, "A cargo crate drops from the crane onto the car just ahead; the runner checks and jumps back to dodge it",
		func() -> bool:
			var at: Array = rail().crate_at(1, rail().beat())
			return at[1] == 2 and (at[0] as Vector2).distance_to(r.global_position) < 320.0 and r.hp == Balance.RUNNER_MAX_HP,
		func() -> Vector2: return rail().crate_at(1, rail().beat())[0], {"subject_name": "falling crate", "subject_r": 50.0, "wait": false})
	await until(func() -> bool: return rail().crate_at(1, rail().beat())[1] >= 1, 60)
	hold(-1.0)
	await jump(14)
	hold(-0.3)
	await until(func() -> bool: return r.is_on_floor(), 40)
	release()
	await until(func() -> bool: return rail().crate_at(1, rail().beat())[1] == 2, 60)
	hitstop(5)
	sfx("thud", -3.0, 1.0)
	_shake = 12.0
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
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.9, "lead": 190.0, "offset": Vector2(110, 30), "smooth": 10.0, "smooth_y": 3.0, "fx": 0.3, "rotation": -0.03})})
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
	camera({"mode": "fixed", "at": Vector2(15940, 1060), "pan_to": Vector2(15990, 1080), "zoom": 1.3, "snap": true, "fx": 0.3})
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
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.75, "lead": 60.0, "offset": Vector2(40, -70), "smooth": 7.0, "smooth_y": 8.0, "fx": 0.3})})
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
	camera({"mode": "fixed", "at": Vector2(16890, 1130), "zoom": 1.85, "snap": true, "fx": 0.4})
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
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.7, "lead": 0.0, "offset": Vector2(0, -160), "smooth": 6.0, "smooth_y": 12.0, "fx": 0.3})})
	await until(func() -> bool: return r.global_position.y < 520.0, 200)

	# 30 BREAK THROUGH THE HIVE: burst through the wax ceiling into daylight.
	cut(30, "The runner bursts through the wax membrane at the top of the hive; glowing comb debris rains down",
		func() -> bool: return machine("hive_shaft").state == 1,
		func() -> Vector2: return Vector2(16900, 230), {"subject_name": "membrane", "subject_r": 70.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.55, "zoom_from": 1.3, "zoom_frames": 40, "lead": 0.0, "offset": Vector2(60, -60), "smooth": 9.0, "smooth_y": 12.0, "fx": 0.6})})
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
	camera({"mode": "follow", "zoom": 1.8, "lead": 120.0, "offset": Vector2(100, 0), "smooth": 7.0, "smooth_y": 12.0, "snap": true, "rotation": 0.0, "fx": 0.6})
	hold(1.0, true)
	await until(x_past(17290), 60)
	hop_to(Vector2(17730, 300), true)
	await frames(24)

	# 31 OFF-CENTER LANDING: a leap down onto a lone, tilted ledge.
	await cut(31, "The runner leaps out of the hive onto an isolated, tilted ledge; the camera tilts and jolts on landing",
		func() -> bool: return r.is_on_floor() and r.global_position.x > 17620.0 and r.global_position.x < 17880.0,
		func() -> Vector2: return Vector2(17750, 300), {"subject_name": "tilted ledge", "subject_r": 90.0})
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position, func() -> Vector2: return Vector2(17760, 320)],
		"pad": 80.0, "zoom": 1.8, "min_zoom": 1.3, "smooth": 7.0, "smooth_y": 12.0, "rotation": -0.05, "fx": 0.6})
	await until(func() -> bool: return r.is_on_floor(), 60)
	camera({"mode": "follow", "zoom": 1.55, "lead": 60.0, "offset": Vector2(60, -30), "smooth": 7.0, "rotation": -0.08, "shake": 12.0, "fx": 0.6})
	release()
	await end_cut()

	# Off air: onto the last rock before the bridge.
	camera({"mode": "follow", "zoom": 1.3, "rotation": 0.0, "snap": true})
	var giant := machine("giant")
	await hop_to(Vector2(18010, 300), true)

	# 32 IT SEES YOU: a short wide shot -- the giant stands in the gorge
	# across the way, the long stone bridge the only path past it. It sees
	# the runner step onto the bridge; then close: the fist goes up, its
	# shadow gathers on the stone just ahead, the runner pulls up and backs
	# off -- and the fist smashes down right in front of them.
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(-80, 40), func() -> Vector2: return giant.global_position + Vector2(0, -1160),
		func() -> Vector2: return Vector2(19500, 330)], "pad": 30.0, "zoom": 0.62, "min_zoom": 0.5, "smooth": 4.0, "snap": true, "fx": 0.7})
	await cut(32, "Wide: the giant blocks the way past its stone bridge; it notices the runner and raises its fist; close: the runner pulls up as the fist slams the bridge just ahead",
		func() -> bool: return giant.bridge_broken() and r.hp == Balance.RUNNER_MAX_HP and absf(giant.slam_fist().x - r.global_position.x) < 200.0,
		func() -> Vector2: return giant.slam_fist(), {"subject_name": "giant's fist", "subject_r": 80.0, "hero_floor": 0.045, "frames": 140})
	log_event("giant_sees", "runner %s, giant state %d" % [r.global_position.round(), giant.state])
	hold(0.8)
	await until(x_past(18060), 40)
	# Close: the runner and the rising fist together.
	# The fist comes in from the top of the frame; the frame never climbs
	# after it to the giant's body.
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(-110, 60),
		func() -> Vector2: return Vector2(giant.slam_fist().x, maxf(giant.slam_fist().y - 60.0, giant.slam_target().y - 520.0)),
		func() -> Vector2: return giant.slam_target() + Vector2(110, 70)], "pad": 30.0, "zoom": 1.45, "zoom_from": 0.62, "zoom_frames": 26, "min_zoom": 1.0,
		"smooth": 6.0, "fx": 0.8, "rotation": 0.02})
	await until(func() -> bool: return r.global_position.x > 18135.0 or giant.windup() > 0.35, 60)
	release()
	await until(func() -> bool: return giant.windup() > 0.45, 60)
	log_event("windup", "fist %s over the bridge, shadow at x %.0f, runner %.0f" % [giant.slam_fist().round(), giant.slam_target().x, r.global_position.x])
	# The dodge: a step back from the shadow.
	hold(-0.3)
	await frames(6)
	release()
	await until(func() -> bool: return giant.bridge_broken(), 60)
	log_event("slam_impact", "fist %s, runner %s: %.0f px in front" % [giant.slam_fist().round(), r.global_position.round(), giant.slam_fist().x - r.global_position.x])
	hitstop(6)
	_shake = 16.0
	punch(0.15, 12)
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(-70, 60), func() -> Vector2: return giant.slam_target() + Vector2(200, 80),
		func() -> Vector2: return giant.slam_target() + Vector2(150, -180)], "pad": 60.0, "zoom": 1.3, "min_zoom": 1.0, "smooth": 8.0, "fx": 1.0})
	await end_cut()

	# 33 UP THE ARM: the bridge falls apart block by block, the runner's own
	# block sagging; they jump onto the giant's planted fist and run up the
	# arm; the other fist rises over the arm's top; they leap off the
	# shoulder across the gorge and it crashes down where they took off.
	var line: PackedVector2Array = giant.ramp_line()
	await cut(33, "The bridge collapses under the runner; they jump onto the planted arm, run up it and leap off the shoulder to the far plateau just before the other fist smashes down on the arm",
		func() -> bool: return _flags.get("off_arm_before_swat", false) and r.hp == Balance.RUNNER_MAX_HP and r.global_position.x > 18900.0 and r.is_on_floor(),
		func() -> Vector2: return r.global_position, {"subject_name": "runner", "subject_r": 40.0, "frames": 238})
	# Wait on the cracking block until it starts to go.
	var mine := -1
	for i in giant.block_count():
		var rect: Rect2 = giant.block_rect(i)
		if rect.position.x <= r.global_position.x and rect.end.x > r.global_position.x:
			mine = i
	await until(func() -> bool: return mine < 0 or giant.since_break() > float(giant._block_info[mine][1]) - 0.3, 60)
	log_event("bridge_gives", "block %d under the runner: %d of %d blocks already fallen" % [mine, giant._fell, giant.block_count()])
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(-60, 70), func() -> Vector2: return r.global_position + Vector2(260, -170)],
		"pad": 60.0, "zoom": 1.35, "min_zoom": 1.1, "smooth": 7.0, "fx": 0.8, "rotation": -0.02})
	await hop_to(line[0] + (line[1] - line[0]).normalized() * 50.0, true)
	log_event("on_arm", "runner %s on the giant's arm, ramp solid %s" % [r.global_position.round(), giant.ramp_body().collision_layer != 0])
	sfx("thud", 4.0, 0.6)
	# Up the arm, the far fist rising over its top.
	# Close on the runner on the arm; the raised fist enters from above
	# once it is up (its rest pose behind the body stays out of the frame).
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(-150, 90), func() -> Vector2: return r.global_position + Vector2(170, -130),
		func() -> Vector2: return giant.swat_fist() + Vector2(0, 60) if giant.cycle_time() > giant.SWAT_WIND + 0.4 else r.global_position]
		, "pad": 50.0, "zoom": 1.55, "min_zoom": 1.2, "smooth": 6.0, "fx": 0.8, "rotation": -0.03})
	hold(1.0, true)
	await until(func() -> bool: return r.global_position.x > line[1].x - 40.0, 200)
	var c: float = giant.cycle_time()
	_flags["off_arm_before_swat"] = c < giant.SWAT_AT and r.is_on_floor()
	log_event("leap", "off the elbow at cycle %.2f, swat falls at %.2f" % [c, giant.SWAT_AT])
	# The leap: the runner and, behind them, the fist smashing the arm.
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(-60, -60), func() -> Vector2: return r.global_position + Vector2(160, 80),
		func() -> Vector2: return giant.swat_target() + Vector2(-40, 0)], "pad": 60.0, "zoom": 1.35, "min_zoom": 1.1, "smooth": 7.0, "fx": 1.0})
	_watch_swat(giant)
	_landing_camera(giant)
	await hop_to(Vector2(19030, 300), true)
	log_event("far_plateau", "runner %s hp %d" % [r.global_position.round(), r.hp])
	release()
	await end_cut()

## Beside the run: log a bite of the maw (and shake) when it lands.
func _watch_bite(maw: FinaleMachine, piece: String) -> void:
	for i in 240:
		if maw.destroyed(piece):
			await frames(2)
			_shake = 10.0
			log_event("bite_" + piece, "%s bitten, collider %d; runner %s" % [piece, maw.piece_body(piece).collision_layer, r.global_position.round()])
			return
		await get_tree().process_frame

## Once over the far plateau's edge: hold on the runner and the arm behind
## (the giant's body stays out to the right).
func _landing_camera(giant: FinaleMachine) -> void:
	await until(func() -> bool: return r.global_position.x > 18880.0, 90)
	# The runner at the right of the frame, looking back at the arm and the
	# wreck of the bridge; the giant's body stays out past the right edge.
	camera({"mode": "follow", "zoom": 1.5, "lead": 0.0, "offset": Vector2(-320, -70), "smooth": 4.0, "smooth_y": 6.0, "fx": 1.0})

## Beside the leap off the giant's shoulder: the swat behind the runner.
func _watch_swat(giant: FinaleMachine) -> void:
	for i in 120:
		if giant.cycle_time() >= giant.SWAT_AT + giant.SWAT_DROP:
			log_event("swat_impact", "fist %s on the arm's top; runner %s" % [giant.swat_fist().round(), r.global_position.round()])
			_shake = 12.0
			return
		await get_tree().process_frame


# --------------------------------------------- 33-39 s: dragon bone canyon
func take_bone() -> void:
	await begin_take(Vector2(19420, 277), 9)
	cover = true
	cover_radius = 150.0
	# A crane move down into the canyon: from the rib tops to the runner.
	camera({"mode": "fixed", "at": Vector2(19980, -260), "pan_to": Vector2(20200, 70), "pan_frames": 66, "zoom": 0.9, "zoom_from": 0.62, "zoom_frames": 66, "snap": true, "fx": 0.3})
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
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.95, "lead": 150.0, "offset": Vector2(70, 10), "smooth": 9.0, "rotation": -0.07, "snap": true, "fx": 0.3})})
	hold(1.0, true)
	await until(x_past(20250), 200)
	await hop_to(Vector2(20360, 320))

	# 36 ROTORS EVERYWHERE: rotor skulls swarm between the ribs.
	cut(36, "Rotor-skull drones close in from every side between the ribs; the runner weaves through them",
		func() -> bool: return _near_kind("skull_drone", 460.0) >= 3,
		func() -> Vector2: return Vector2(20750, 60), {"subject_name": "rotor skulls", "subject_r": 160.0, "wait": false,
		"on_start": func() -> void: camera({"mode": "follow", "zoom": 1.5, "lead": 120.0, "offset": Vector2(50, -80), "smooth": 6.0, "rotation": 0.04, "fx": 0.3})})
	hold(1.0)
	await until(x_past(20700), 300)
	cover_radius = 120.0
	await until(x_past(20980), 300)
	await end_cut()

	# 37 UP THE GREAT RIB: the runner sprints diagonally up a huge rib arcing
	# out over the canyon. Under it the maw comes up, tilts at the span the
	# runner is on, jaws wide -- and snaps shut on that span just as they
	# run off it: span B bursts apart behind them.
	await begin_take(Vector2(21300, 257), 10)
	cover = true
	cover_radius = 150.0
	var maw := machine("maw")
	hold(1.0, true)
	await until(x_past(21420), 60)
	camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(-120, 60), func() -> Vector2: return r.global_position + Vector2(240, -120),
		func() -> Vector2: return maw.centre("B") + Vector2(0, 300)], "pad": 50.0, "zoom": 1.35, "min_zoom": 1.05, "smooth": 7.0, "snap": true, "fx": 0.8, "rotation": -0.03})
	await cut(37, "The runner sprints diagonally up a huge rib over the canyon; the maw rises beneath, opens on the span under them and bites it apart just behind them",
		func() -> bool: return maw.destroyed("B") and r.global_position.x > maw.piece("B")["b"].x and r.state != Runner.State.DEAD,
		func() -> Vector2: return maw.head()[0], {"subject_name": "the maw", "subject_r": 120.0, "frames": 104})
	await until(func() -> bool: return maw.state == 1, 60)
	log_event("maw_rises", "runner %s on the rib, span B %s..%s" % [r.global_position.round(), maw.piece("B")["a"], maw.piece("B")["b"]])
	await until(func() -> bool: return maw.t1() >= maw.RISE, 60)
	log_event("maw_opens", "jaws opening under span B; runner at x %.0f" % r.global_position.x)
	await until(func() -> bool: return maw.destroyed("B"), 90)
	# No hit-stop here: the runner stands on the span that starts to move.
	_shake = 12.0
	hold(0.5)
	await frames(2)
	log_event("bite_B", "span B bitten, collider %d; runner %s (B ends at x %.0f)" % [maw.piece_body("B").collision_layer, r.global_position.round(), maw.piece("B")["b"].x])

	# 38 THE TIP GOES: with B gone, the rib's tip -- the runner on it --
	# tips and drops; they ride it down onto the tilted thigh bone below
	# and slide down it. The maw dives and comes up again behind them,
	# chasing under the bone, and bites its lower end off as they jump.
	cut(38, "The rib's tip drops away under the runner onto a tilted thigh bone below; they slide down it, the maw surfaces again behind and bites the bone's end off as they jump clear",
		func() -> bool: return _flags.get("on_L1", false) and maw.destroyed("L1b") and r.state != Runner.State.DEAD and r.global_position.x > maw.piece("L1b")["b"].x,
		func() -> Vector2: return r.global_position, {"subject_name": "runner", "subject_r": 40.0, "wait": false, "frames": 160,
		"on_start": func() -> void: camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(-140, -90), func() -> Vector2: return r.global_position + Vector2(220, 150),
			func() -> Vector2: return maw.head()[0] if maw.head()[0].y < 900.0 else r.global_position], "pad": 50.0, "zoom": 1.35, "min_zoom": 1.0, "smooth": 6.0, "fx": 0.8})})
	await until(func() -> bool: return maw.piece_body("C").collision_layer == 0 or not r.is_on_floor(), 40)
	await frames(1)
	log_event("tip_falls", "span C lost its hold; runner %s" % r.global_position.round())
	for i in 90:
		if r.is_on_floor() and r.global_position.y > 250.0:
			break
		if OS.get_environment("FINALE_LOG") != "" and i % 3 == 0:
			print("      drop f%d %s v%s floor %s L1a layer %d at %s rot %.2f" % [i, r.global_position.round(), r.velocity.round(), r.is_on_floor(),
				maw.piece_body("L1a").collision_layer, maw.piece_body("L1a").global_position.round(), maw.piece_body("L1a").rotation])
		await frames(1)
	_flags["on_L1"] = true
	log_event("on_thigh_bone", "landed on the lower route at %s (was up at y~40)" % r.global_position.round())
	sfx("thud", 2.0, 0.7)
	_crouch = true
	hold(1.0)
	await until(func() -> bool: return maw.state == 2, 60)
	log_event("maw_again", "the maw comes up again behind; runner %s sliding" % r.global_position.round())
	await until(func() -> bool: return r.global_position.x > maw.piece("L1b")["b"].x - 60.0, 120)
	_crouch = false
	await hop_to(Vector2(22800, 568), true)
	log_event("on_curved_rib", "runner %s" % r.global_position.round())
	_watch_bite(maw, "L1b")
	_watch_bite(maw, "P2")

	# 39 THE LAST JUMP: across the curved rib with the maw coming up under
	# it, a long jump over the open canyon -- the jaws snap the rib just
	# behind -- onto the slope by the jaw gate.
	cut(39, "The runner races over the curved rib with the maw rising under it and makes a long last jump over the canyon as the jaws snap the rib behind, landing by the jaw gate",
		func() -> bool: return maw.destroyed("P2") and r.global_position.x > 23380.0 and r.is_on_floor() and r.state != Runner.State.DEAD,
		func() -> Vector2: return r.global_position, {"subject_name": "runner", "subject_r": 40.0, "wait": false, "frames": 112,
		"on_start": func() -> void: camera({"mode": "frame", "fit": [func() -> Vector2: return r.global_position + Vector2(-160, -100), func() -> Vector2: return r.global_position + Vector2(260, 140),
			func() -> Vector2: return maw.head()[0] if maw.head()[0].y < 1000.0 else r.global_position], "pad": 50.0, "zoom": 1.3, "min_zoom": 0.95, "smooth": 6.0, "fx": 0.8})})
	hold(1.0, true)
	await until(x_past(23010), 80)
	log_event("final_jump", "from the curved rib's end at %s; maw at %s" % [r.global_position.round(), maw.head()[0].round()])
	await hop_to(Vector2(23520, 495), true)
	log_event("landed", "by the jaw gate at %s; curved rib bitten: %s" % [r.global_position.round(), maw.destroyed("P2")])
	hold(1.0)
	await frames(12)
	release()
	await end_cut()

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

const TITLE_CENTRE := Vector2(640, 250)
const TITLE_SCALE := 0.68

func take_title() -> void:
	await begin_take(Vector2(24420, 277), 11)
	# YOU only fires on a drone actually swooping into the runner.
	cover = true
	cover_radius = 140.0
	title.title_alpha = 0.0
	title.title_scale = TITLE_SCALE * 1.35
	title.title_centre = TITLE_CENTRE
	# The runner keeps to the lower third; the title owns the sky above.
	# Close enough that the runner reads at full size, the title huge behind.
	camera({"mode": "follow", "zoom": 1.7, "lead": 150.0, "offset": Vector2(110, -95), "smooth": 6.0, "smooth_y": 4.0, "snap": true, "fx": 0.3})
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
	camera({"mode": "follow", "zoom": 1.8, "lead": 0.0, "offset": Vector2(40, -95), "smooth": 8.0, "snap": true, "fx": 0.8})
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
	camera({"mode": "fixed", "at": Stage.checkpoints()[11] + Vector2(100, -80), "zoom": 1.75, "zoom_from": 1.6, "zoom_frames": 50, "snap": true, "fx": 0.3})
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
	camera({"mode": "fixed", "at": Vector2(26560, 360), "zoom": 1.55, "snap": true, "fx": 0.3})
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
	camera({"mode": "follow", "zoom": 1.7, "lead": 60.0, "offset": Vector2(60, -110), "smooth": 7.0, "rotation": 0.04, "snap": true, "fx": 0.3})
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
	camera({"mode": "follow", "zoom": 1.45, "lead": 160.0, "offset": Vector2(150, 130), "smooth": 6.0, "smooth_y": 5.0, "fx": 0.3})
	var upper := func() -> bool: return screen_of(r.global_position).y < VIEW.y * 0.48
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
