extends Node
## Frame times for the versus arena, measured in the real scene.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --resolution 1280x720 tools/versus_perf_probe.tscn -- --stage 1-1
##
## The phone's 「1台で ためす」: on-screen controls, the co-op Guardian, a
## practice partner. The runner is carried round the loop (across the join
## several times) while a platform is drawn now and then, so the measurement
## covers scrolling scenery, the seam and the platform copies. Reports what it
## measured -- "heavy" is a comparison, so run it on two commits.

class TouchSolo extends "res://src/versus/versus_main.gd":
	func _read_command_line() -> void:
		mode = Mode.SOLO
		room_mode = VersusRoster.RoomMode.TEAM_SPLIT
		_seat = 0
		_set_local_team()
	func _wants_touch() -> bool:
		return true
	func _start_debug_log() -> void:
		pass

const WARMUP := 1.5
const MEASURE := 8.0

var _arena = null
var _t := 0.0
var _frames: Array[float] = []
var _process_ms: Array[float] = []
var _physics_ms: Array[float] = []
var _next_platform := 0.0

func _ready() -> void:
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
	VersusLaunch.stage = which
	_arena = TouchSolo.new()
	_arena._theme = which
	add_child(_arena)
	# --without A,B: hide those nodes (by name, anywhere in the arena), to
	# see what each one costs.
	for i in args.size():
		if args[i] == "--without" and i + 1 < args.size():
			await get_tree().process_frame
			for name in String(args[i + 1]).split(","):
				var n: Node = _arena.find_child(name, true, false)
				if n == null:
					print("no node %s" % name)
				elif n is CanvasItem:
					n.visible = false
				elif n is CanvasLayer:
					n.visible = false
				else:
					n.process_mode = Node.PROCESS_MODE_DISABLED

func _process(delta: float) -> void:
	_t += delta
	if _t < WARMUP:
		return
	if _t > WARMUP + MEASURE:
		_report()
		get_tree().quit()
		return
	_frames.append(delta * 1000.0)
	_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	# Carried along fast enough to cross the join several times.
	var r: Runner = _arena.runners[0]
	r.global_position.x += 900.0 * delta
	r.global_position.y = minf(r.global_position.y, 150.0)
	if _t > _next_platform and _arena.guardian != null:
		_next_platform = _t + 1.0
		_arena.guardian.place_path = PackedVector2Array()
		_arena.guardian.use_active(r.global_position + Vector2(260.0, 60.0))

func _report() -> void:
	print("versus perf %s: %s" % [VersusStageData.theme_label(VersusStageData.theme), _line("frame", _frames)])
	print("  %s" % _line("process", _process_ms))
	print("  %s" % _line("physics", _physics_ms))
	print("  objects=%d nodes=%d draw_calls=%d primitives=%d" % [
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])

func _line(name: String, samples: Array[float]) -> String:
	var s := samples.duplicate()
	s.sort()
	var n := s.size()
	if n == 0:
		return "%s: no samples" % name
	return "%s median=%.2fms p95=%.2fms (n=%d)" % [name, s[n / 2], s[int(float(n) * 0.95)], n]
