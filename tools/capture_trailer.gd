extends Node
## Renders the 30-second trailer from the real game, one frame at a time.
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --audio-driver Dummy \
##       tools/capture_trailer.tscn --fixed-fps 60 -- --ci-skip-eos
##
## Optional user args:  --size 960x540   --only 01_runs,02_builds
##
## tools/make_trailer.sh runs this and then tools/trailer_mix.py and ffmpeg.
##
## Every shot is the real main scene on a real stage, driven through the same
## InputHub seam the probes use (`scripted = true`). The game ticks at its own
## 60 Hz under --fixed-fps, and every second tick is kept, so the film is 30 fps
## and the result is the same on every run however slow the renderer is.
##
## The cut list sits on the music's beat grid (132 BPM, tools/make_audio.py),
## so cuts land on the downbeat without any editing afterwards. Sounds the game
## plays are logged with their film time instead of recorded -- the audio driver
## is a dummy here -- and trailer_mix.py lays them over the music.
##
## Output: user://trailer/frames/%05d.png, sfx.json, shots.json.

const MainScene: PackedScene = preload("res://src/main.tscn")
const ShotsScript := preload("res://tools/trailer_shots.gd")
const Overlay := preload("res://tools/trailer_overlay.gd")

const DESIGN := Vector2i(1280, 720)
const FPS := 30
const TICKS_PER_FRAME := 2
const BPM := 132.0
const BEAT := 60.0 / BPM

var size := Vector2i(1920, 1080)
var only: PackedStringArray = []
var dir := "user://trailer"

var view: SubViewport = null
var overlay: Node = null
var main: Node2D = null

var frame := 0           # next film frame to write
var sfx: Array = []      # {"t", "key", "pitch", "db"}
var shots_log: Array = []
var _voice_cursor := 0
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

## Film frame at which a beat falls. Rounded once from the beat count, so
## shot lengths never accumulate rounding drift.
static func beat_frame(beats: float) -> int:
	return int(round(beats * BEAT * FPS))

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
	var beat := 0.0
	for shot in shots.list():
		var start := beat
		beat += float(shot["beats"])
		if not only.is_empty() and not only.has(String(shot["name"])):
			continue
		var frames := beat_frame(beat) - beat_frame(start)
		var t0 := Time.get_ticks_msec()
		await _shot(shots, shot, frames, beat_frame(start))
		print("shot %-14s %4d frames  (%.1fs to render)" % [shot["name"], frames,
			(Time.get_ticks_msec() - t0) / 1000.0])

	var f := FileAccess.open(dir + "/sfx.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(sfx, "  "))
	f = FileAccess.open(dir + "/shots.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": FPS, "frames": frame, "shots": shots_log}, "  "))
	print("trailer frames written to ", ProjectSettings.globalize_path(dir))
	get_tree().quit()

## Build a fresh game on the shot's stage, let the shot set it up, roll the
## pre-roll unrecorded, then record exactly `frames` frames.
func _shot(shots: Node, shot: Dictionary, frames: int, film_start: int) -> void:
	shots_log.append({"name": shot["name"], "start": frame, "frames": frames,
		"film_start": film_start})
	var ctx: Dictionary = {"t": 0, "frames": frames}
	if shot.has("stage"):
		Stage.use(int(shot["stage"]))
		main = MainScene.instantiate()
		view.add_child(main)
		view.move_child(overlay, -1)
		await get_tree().process_frame
		# The home screen goes; the HUD layers stay alive (main reads them) but
		# are not drawn. A trailer is the game without its interface, as the
		# store's --no-hud feature graphic is.
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
		ctx["main"] = main
	overlay.begin_shot()
	var tick: Callable = shots.call("setup_" + String(shot["name"]), ctx)
	var preroll: int = int(shot.get("preroll", 0))
	_voice_cursor = Audio._next
	var total := preroll + frames * TICKS_PER_FRAME
	for i in total:
		var t := i - preroll
		ctx["t"] = t
		tick.call(ctx)
		if _trace and main != null and t % 10 == 0:
			var r: Runner = main.runner
			print("  t=%d pos=%s v=%s st=%d floor=%s" % [t, r.global_position.round(),
				r.velocity.round(), r.state, r.is_on_floor()])
		if t >= 0 and t % TICKS_PER_FRAME == 0:
			overlay.set_time(float(t) / 60.0, frame)
		await RenderingServer.frame_post_draw
		_log_sounds(float(frame) / FPS, t >= 0)
		if t >= 0 and t % TICKS_PER_FRAME == TICKS_PER_FRAME - 1:
			_save()
	overlay.end_shot()
	if main != null:
		main.queue_free()
		main = null
		await get_tree().process_frame

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
