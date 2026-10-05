extends Node
## Frame times for one stage, measured in the real game.
##
##   godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --resolution 1280x720 \
##       tools/perf_probe.tscn -- --ci-skip-eos --stage 1-1
##
## Boots main.tscn, dismisses the home screen, walks the runner, and reports
## the median and p95 frame interval. Frame time is a comparison -- "heavy" is
## relative to the machine -- so it is reported, never judged.
##
## Draw calls and the object count are not: they depend on the scene, not on
## the GPU, and they are what went wrong on phones before (a decor change took
## 1-1 from 142 to 225 draw calls and stuttered). With `--budget` the probe
## fails when the peak of either over the walk exceeds the stage's line in
## tools/perf_budgets.cfg:
##
##   ... tools/perf_probe.tscn -- --ci-skip-eos --stage 1-1 --budget
##
## The first second is discarded -- shader compilation and the first frames of
## a scene are not what a player feels after the stage has started.

const MainScene: PackedScene = preload("res://src/main.tscn")
const WARMUP := 1.0
const MEASURE := 8.0

var _main: Node2D = null
var _t := 0.0
var _samples: Array[float] = []
var _stage_key := "1-1"
var _budget := false
var _peak_draw_calls := 0
var _peak_objects := 0

func _ready() -> void:
	# Vsync pins every frame to 16.67ms and hides how much room is left.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var which := Stage.Which.GREENFIELD
	var at_x := NAN
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--budget":
			_budget = true
		if args[i] == "--stage" and i + 1 < args.size():
			_stage_key = String(args[i + 1])
			match String(args[i + 1]):
				"1-2": which = Stage.Which.HORROR
				"1-3": which = Stage.Which.SKYWARD_RUINS
				"1-4": which = Stage.Which.SEA
				"1-5": which = Stage.Which.SWAMP
				"1-6": which = Stage.Which.DESERT
				"1-7": which = Stage.Which.TOWER
				"1-8": which = Stage.Which.CAVE
				_: which = Stage.Which.GREENFIELD
		if args[i] == "--at" and i + 1 < args.size():
			at_x = float(args[i + 1])
	Stage.use(which)
	_main = MainScene.instantiate()
	add_child(_main)
	await get_tree().process_frame
	var panel := _main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
	_main.resume_from_home(true)
	# The camera and stage keep running while this probe moves through a safe
	# route. Avoid deaths and respawns, which would skew frame timings.
	_main.runner.set_physics_process(false)
	_main.runner.collision_layer = 0
	_main.runner.collision_mask = 0
	if is_finite(at_x):
		_main.runner.global_position.x = at_x
		_main._snap_camera_to_runner()
	await get_tree().process_frame

func _process(delta: float) -> void:
	_t += delta
	if _t < WARMUP:
		return
	if _t > WARMUP + MEASURE:
		var within := _report()
		get_tree().quit(0 if within else 1)
		return
	_samples.append(delta * 1000.0)
	_peak_draw_calls = maxi(_peak_draw_calls,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_peak_objects = maxi(_peak_objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	# Keep the runner moving, so the measurement covers scrolling scenery
	# rather than one static screen.
	if _main != null and is_instance_valid(_main) and _main.runner != null:
		_main.runner.global_position.x += 220.0 * delta

## Prints the measurement; false when --budget is set and it is over.
func _report() -> bool:
	_samples.sort()
	var n := _samples.size()
	if n == 0:
		print("no samples")
		return not _budget
	var median: float = _samples[n / 2]
	var p95: float = _samples[int(float(n) * 0.95)]
	var worst: float = _samples[n - 1]
	print("frames=%d  median=%.2fms (%.0f fps)  p95=%.2fms  worst=%.2fms  objects=%d"
		% [n, median, 1000.0 / maxf(median, 0.001), p95, worst,
			Performance.get_monitor(Performance.OBJECT_COUNT)])
	print("draw_calls=%d  primitives=%d  video_mem=%.1fMB"
		% [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	print("peak_draw_calls=%d  peak_objects=%d" % [_peak_draw_calls, _peak_objects])
	if not _budget:
		return true
	var budgets := ConfigFile.new()
	if budgets.load("res://tools/perf_budgets.cfg") != OK or not budgets.has_section(_stage_key):
		print("BUDGET FAIL  %s: no budget in tools/perf_budgets.cfg" % _stage_key)
		return false
	var within := true
	for pair in [["draw_calls", _peak_draw_calls], ["objects", _peak_objects]]:
		var limit := int(budgets.get_value(_stage_key, pair[0], 0))
		var ok: bool = int(pair[1]) <= limit
		print("BUDGET %s  %s %s: %d / %d" % ["ok  " if ok else "FAIL", _stage_key, pair[0], pair[1], limit])
		within = within and ok
	return within
