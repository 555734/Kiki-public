extends Node
## Renders the trailer from the real game, one frame at a time.
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --audio-driver Dummy \
##       tools/capture_trailer.tscn --fixed-fps 60 -- --ci-skip-eos
##
## Optional user args:  --size 960x540   --only 01_caught,02_drawn
##
## tools/make_trailer.sh runs this and then tools/trailer_mix.py and ffmpeg.
##
## Every shot is the real game on a real stage -- the co-op main scene, or the
## star battle's arena -- driven through the same InputHub seam the probes use
## (`scripted = true`). The game ticks at its own 60 Hz under --fixed-fps and
## the film is 30 fps, so normal speed keeps every second tick, half speed
## keeps every tick, and the result is the same on every run however slow the
## renderer is. A shot can also slow down (ctx["speed"]) and freeze
## (ctx["freeze"]): a freeze stops the world, stage clock included, while the
## camera and the overlay keep moving.
##
## The shots before the music are timed in seconds; from the shot that brings
## the music in, they are timed in beats of it (110 BPM, the tempo
## tools/trailer_music.py composes the score in), so the cuts land on the beat. Sounds the game
## plays are logged with their film time instead of recorded -- the audio driver
## is a dummy here -- and so are the shots' audio cues (silence, rumble, music);
## trailer_mix.py builds the soundtrack from both.
##
## Output: user://trailer/frames/%05d.png, sfx.json, shots.json.

const MainScene: PackedScene = preload("res://src/main.tscn")
const ArenaScene: PackedScene = preload("res://src/versus/versus_main.tscn")
const ShotsScript := preload("res://tools/trailer_shots.gd")
const Overlay := preload("res://tools/trailer_overlay.gd")

const DESIGN := Vector2i(1280, 720)
const FPS := 30
const TICK_HZ := 60
const BPM := 110.0
const BEAT := 60.0 / BPM

var size := Vector2i(1920, 1080)
var only: PackedStringArray = []
var dir := "user://trailer"

var view: SubViewport = null
var overlay: Node = null
## The game the current shot is filming: the co-op main or the arena.
var main: Node = null

var frame := 0           # next film frame to write
var sfx: Array = []      # {"t", "key", "pitch", "db"}
var cues: Array = []     # {"t", "cue"}
var shots_log: Array = []
var _voice_cursor := 0
var _begin := 0
var _trace := OS.get_environment("TRAILER_TRACE") != ""

func _ready() -> void:
	call_deferred("run")

func _args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--size" and i + 1 < args.size():
			var p := String(args[i + 1]).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif args[i] == "--only" and i + 1 < args.size():
			only = String(args[i + 1]).split(",")
		elif args[i] == "--out" and i + 1 < args.size():
			dir = String(args[i + 1])

## Film frame at which a beat of the music falls, counted from its entry.
## Rounded once from the beat count, so lengths never accumulate drift.
static func beat_frame(beats: float) -> int:
	return int(round(beats * BEAT * FPS))

## Film time of the next frame to be written.
func now() -> float:
	return float(frame) / FPS

## Film time of the next frame, from the start of the current shot.
func shot_time() -> float:
	return float(frame - _begin) / FPS

## An audio cue at the current film time, for trailer_mix.py.
func cue(name: String) -> void:
	cues.append({"t": snappedf(now(), 0.001), "cue": name})

func run() -> void:
	_args()
	view = SubViewport.new()
	view.size = size
	view.size_2d_override = DESIGN
	view.size_2d_override_stretch = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.transparent_bg = false
	view.audio_listener_enable_2d = false
	add_child(view)
	overlay = Overlay.new()
	view.add_child(overlay)

	var frames_dir := dir + "/frames"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames_dir))
	for f in DirAccess.get_files_at(frames_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(frames_dir + "/" + f))

	var shots: Node = ShotsScript.new()
	shots.cap = self
	add_child(shots)
	# Where each shot starts and ends on the film's timeline.
	var at := 0
	var anchor := -1
	var beats := 0.0
	for shot in shots.list():
		var start := at
		if shot.has("beats"):
			if anchor < 0:
				anchor = at
			beats += float(shot["beats"])
			at = anchor + beat_frame(beats)
		else:
			at += int(round(float(shot["sec"]) * FPS))
		if not only.is_empty() and not only.has(String(shot["name"])):
			continue
		var t0 := Time.get_ticks_msec()
		await _shot(shots, shot, at - start, start)
		print("shot %-14s %4d frames  (%.1fs to render)" % [shot["name"], at - start,
			(Time.get_ticks_msec() - t0) / 1000.0])

	var f := FileAccess.open(dir + "/sfx.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(sfx, "  "))
	f = FileAccess.open(dir + "/shots.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": FPS, "frames": frame, "shots": shots_log,
		"cues": cues}, "  "))
	print("trailer frames written to ", ProjectSettings.globalize_path(dir))
	get_tree().quit()

## Build the shot's game, let the shot set it up, roll the pre-roll without
## rendering it, then film exactly `frames` frames.
func _shot(shots: Node, shot: Dictionary, frames: int, film_start: int) -> void:
	shots_log.append({"name": shot["name"], "start": frame, "frames": frames,
		"film_start": film_start})
	var ctx: Dictionary = {"t": 0, "frames": frames, "speed": 1.0, "freeze": 0, "shot": shot}
	_begin = frame
	if shot.has("stage"):
		await _open_coop(int(shot["stage"]))
		ctx["main"] = main
	elif shot.get("arena", false):
		await _open_arena()
		ctx["arena"] = main
	overlay.begin_shot()
	if shot.get("music_in", false):
		cue("music_in")
	var tick: Callable = shots.call("setup_" + String(shot["name"]), ctx)
	var preroll: int = int(shot.get("preroll", 0))
	_voice_cursor = Audio._next
	var written := 0
	var owed := 0.0
	var t := -preroll
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	while written < frames:
		ctx["t"] = t
		ctx["written"] = written
		if t == 0:
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		overlay.set_time(shot_time() if t >= 0 else 0.0, frame)
		tick.call(ctx)
		if _trace and t % int(OS.get_environment("TRAILER_TRACE")) == 0 and ctx.has("main"):
			var r: Runner = main.runner
			print("  t=%d pos=%s v=%s st=%d floor=%s" % [t, r.global_position.round(),
				r.velocity.round(), r.state, r.is_on_floor()])
		var hold: int = int(ctx["freeze"])
		ctx["freeze"] = 0
		if hold > 0 and t >= 0:
			# The world holds; then this same tick goes on to run as usual, so
			# whatever the shot did on it is not done a second time.
			written += await _freeze(ctx, mini(hold, frames - written))
			if written >= frames:
				break
		await RenderingServer.frame_post_draw
		_log_sounds(now(), t >= 0)
		if t >= 0:
			# Half a film frame per tick at normal speed; more when slowed.
			owed += float(FPS) / TICK_HZ / maxf(float(ctx["speed"]), 0.05)
			while owed >= 1.0 and written < frames:
				_save()
				written += 1
				owed -= 1.0
		t += 1
	overlay.end_shot()
	if main != null:
		main.queue_free()
		main = null
		await get_tree().process_frame

func _open_coop(which: int) -> void:
	Stage.use(which)
	main = MainScene.instantiate()
	view.add_child(main)
	view.move_child(overlay, -1)
	await get_tree().process_frame
	# The home screen goes; the HUD layers stay alive (main reads them) but
	# are not drawn unless a shot asks for them.
	main.get_node("NetPanel").free()
	for name in ["Hud", "Quit", "Scope"]:
		var layer: CanvasLayer = main.get_node(name)
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED
	main.input_hub.scripted = true
	# PlacementPreview stays for the shot tracers, but the build ghost that
	# follows an unheld cursor is the runner-seat view's: not drawn there.
	main.input_hub.solo_role = "runner"
	main.resume_from_home(true)
	# The camera is the trailer's from here: main's follow is turned off and
	# the shot's rig drives the same Camera2D.
	main.set_physics_process(false)

## The star battle as a one-device match: both seats are steered by the
## shot (VersusCpu), not by a keyboard.
func _open_arena() -> void:
	VersusLaunch.clear()
	VersusLaunch.how = VersusLaunch.How.SOLO
	main = ArenaScene.instantiate()
	view.add_child(main)
	view.move_child(overlay, -1)
	await get_tree().process_frame
	for hub in main.input.hubs:
		hub.scripted = true
		hub.set_listening(false)
	# Otherwise the shared-keyboard poll writes "no keys held" into both hubs
	# every tick, over whatever the shot steered.
	main.input.shared_keyboard = false
	main.cpu_enabled = false

## Stop the world and keep filming: the stage clock and every gameplay node
## stand still, the camera and the overlay do not. Co-op shots only.
func _freeze(ctx: Dictionary, frames: int) -> int:
	var cam: Camera2D = main.camera
	var keep: Array = [cam]
	if ctx.has("rig"):
		keep.append(ctx["rig"])
	for n in keep:
		n.process_mode = Node.PROCESS_MODE_ALWAYS
	main.suspend_for_home()
	for k in frames:
		ctx["frozen"] = k
		if ctx.has("on_freeze"):
			(ctx["on_freeze"] as Callable).call(ctx, k)
		overlay.set_time(shot_time(), frame)
		await RenderingServer.frame_post_draw
		_save()
	main.resume_from_home(false)
	for n in keep:
		n.process_mode = Node.PROCESS_MODE_INHERIT
	ctx.erase("frozen")
	return frames

func _save() -> void:
	var image := view.get_texture().get_image()
	image.save_png("%s/frames/%05d.png" % [dir, frame])
	frame += 1

## Audio has a fixed ring of voices and advances `_next` once per sound, so
## every voice between the last cursor and now has just been started.
## Sounds from the pre-roll are passed over, not logged.
func _log_sounds(at: float, record: bool) -> void:
	var voices: Array = Audio._voices
	while _voice_cursor != Audio._next:
		var p: AudioStreamPlayer = voices[_voice_cursor]
		if record and p.stream != null:
			sfx.append({"t": snappedf(at, 0.001),
				"key": p.stream.resource_path.get_file().get_basename(),
				"pitch": snappedf(p.pitch_scale, 0.0001),
				"db": snappedf(p.volume_db, 0.01)})
		_voice_cursor = (_voice_cursor + 1) % voices.size()
