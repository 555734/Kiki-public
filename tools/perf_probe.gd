extends Node
## Frame times for one stage, measured in the real game.
##
##   godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --resolution 1280x720 \
##       tools/perf_probe.tscn -- --ci-skip-eos --stage 1-1
##
## Boots main.tscn, dismisses the home screen, walks the runner, and reports
## the median and p95 frame interval. Reports what it measured rather than a
## pass/fail, because "heavy" is a comparison: run it on two commits.
##
## The first second is discarded -- shader compilation and the first frames of
## a scene are not what a player feels after the stage has started.

const MainScene: PackedScene = preload("res://src/main.tscn")
const WARMUP := 1.0
const MEASURE := 8.0

var _main: Node2D = null
var _t := 0.0
var _samples: Array[float] = []

func _ready() -> void:
	# Vsync pins every frame to 16.67ms and hides how much room is left.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var which := Stage.Which.GREENFIELD
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--stage" and i + 1 < args.size():
			match String(args[i + 1]):
				"1-2": which = Stage.Which.HORROR
				"1-3": which = Stage.Which.SKYWARD_RUINS
				"1-4": which = Stage.Which.SEA
				"1-5": which = Stage.Which.SWAMP
				_: which = Stage.Which.GREENFIELD
	Stage.use(which)
	_main = MainScene.instantiate()
	add_child(_main)
	await get_tree().process_frame
	var panel := _main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
	await get_tree().process_frame

func _process(delta: float) -> void:
	_t += delta
	if _t < WARMUP:
		return
	if _t > WARMUP + MEASURE:
		_report()
		get_tree().quit()
		return
	_samples.append(delta * 1000.0)
	# Keep the runner moving, so the measurement covers scrolling scenery
	# rather than one static screen.
	if _main != null and is_instance_valid(_main) and _main.runner != null:
		_main.runner.global_position.x += 220.0 * delta

func _report() -> void:
	_samples.sort()
	var n := _samples.size()
	if n == 0:
		print("no samples")
		return
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
