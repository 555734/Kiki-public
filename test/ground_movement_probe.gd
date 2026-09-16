extends Node2D
## Ordinary running on flat ground, measured on the real Runner through the real
## InputHub. Every figure here is a distance or a tick count, because that is
## what a thumb on a small ledge actually deals with.
##
## The rest of the suite measures the jump; this measures getting to it. It is
## separate from movement_probe for one reason: these numbers are read off a
## stopped, flat, empty floor with the input injected a frame at a time, and
## mixing that with arcs that need a run-up makes both harder to trust.
##
##   godot --headless --path . --fixed-fps 60 res://test/ground_movement_probe.tscn

var runner: Runner
var hub: InputHub
var perch: StaticBody2D
var checks := 0
var failures := 0
var completed := false
var _resets := 0
var _dirty_starts := 0

const ORIGIN := Vector2(-5000, 300)
const FLOOR_TOP: float = 400.0
## One block wide, and high enough above the floor that falling off it is
## visible as falling off rather than as a slightly lower y.
const PERCH_X: float = 6000.0
const PERCH_TOP: float = 200.0
const PERCH_WIDTH: float = 48.0

var W: float = Balance.RUNNER_RUN_SPEED
var S: float = Balance.RUNNER_RUN_SPEED * Balance.RUNNER_SPRINT_MULTIPLIER

func _ready() -> void:
	Options.forget()
	hub = InputHub.new()
	hub.scripted = true
	add_child(hub)
	_body(Rect2(-10000, FLOOR_TOP, 20000, 100))
	perch = _body(Rect2(PERCH_X - PERCH_WIDTH * 0.5, PERCH_TOP, PERCH_WIDTH, 24))
	runner = Runner.new()
	runner.input_hub = hub
	add_child(runner)
	# Exactly one manual physics tick per physics frame, as movement_probe does.
	runner.set_physics_process(false)
	get_tree().create_timer(180.0).timeout.connect(func() -> void:
		if not completed:
			push_error("ground movement probe did not reach its last assertion")
			get_tree().quit(1))

	print("== running on flat ground ==")
	await _first_strides()
	await _to_top_speed()
	await _cruise()
	await _letting_go()
	await _turning_round()
	await _easing_off()
	await _input_curve()
	await _taps()
	await _one_block_perch()
	_ok(_dirty_starts == 0,
		"all %d cases started stopped on the floor" % _resets)
	completed = true
	Options.forget()
	print("ground movement: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ fixture

func _body(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body

func _tick(count: int = 1) -> void:
	for _i in range(count):
		await get_tree().physics_frame
		runner._physics_process(Clock.DT)
		await get_tree().process_frame

func _ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
		print("  FAIL  ", label)
	else:
		print("  ok    ", label)

## Everything a measurement could inherit from the one before it. respawn()
## clears the runner's own history -- velocity, buffer, chain, pound, stance,
## wall lock, the pending external take-off -- and this clears the hub's press
## and release edges on top of it, so a case never starts with a stored press.
func _reset(at: Vector2 = ORIGIN) -> void:
	hub.move_axis = 0.0
	hub.move_axis_y = 0.0
	hub.release_jump()
	hub.release_dash()
	hub.take_jump()
	hub.take_dash()
	runner.respawn(at)
	await _tick(40)
	# Counted once at the end rather than thirty times in the log.
	_resets += 1
	if not (runner.is_on_floor() and absf(runner.velocity.x) < 0.001):
		_dirty_starts += 1

func _sprint(on: bool) -> void:
	if on:
		hub.press_dash()
	else:
		hub.release_dash()

## Hold one axis for a number of ticks and report what happened. Every tick is
## recorded, not just the last one, so a case can ask about the shape of the
## run rather than only its end.
func _hold(axis: float, sprint: bool, ticks: int) -> Array:
	var trace: Array = []
	hub.move_axis = axis
	_sprint(sprint)
	var from := runner.position.x
	for _i in range(ticks):
		await _tick()
		trace.append({
			"axis": hub.move_axis,
			"sprint": runner.ground_sprint_requested(),
			"vx": runner.velocity.x,
			"vy": runner.velocity.y,
			"x": runner.position.x,
			"travelled": runner.position.x - from,
			"floor": runner.is_on_floor(),
			"state": runner.state,
			"chain": runner.jump_chain(),
		})
	return trace

## Let go and report [ticks, distance] to a full stop.
func _let_go_and_stop(limit: int = 90) -> Array:
	hub.move_axis = 0.0
	var from := runner.position.x
	var ticks := 0
	for _i in range(limit):
		await _tick()
		ticks += 1
		if runner.velocity.x == 0.0:
			break
	return [ticks, absf(runner.position.x - from)]

func _ticks_to(axis: float, sprint: bool, speed: float, limit: int = 120) -> int:
	hub.move_axis = axis
	_sprint(sprint)
	for i in range(limit):
		await _tick()
		if absf(runner.velocity.x - speed) < 0.001:
			return i + 1
	return -1

# ------------------------------------------------------------- measurements

## The first thing a press does. It is the same for a walk and a sprint on
## purpose: the sprint button raises the ceiling, it never softens the push.
func _first_strides() -> void:
	await _reset()
	var walk_one := await _hold(1.0, false, 1)
	var walk_vx: float = walk_one[0]["vx"]
	var walk_step: float = walk_one[0]["travelled"]
	await _reset()
	var sprint_one := await _hold(1.0, true, 1)
	var sprint_vx: float = sprint_one[0]["vx"]
	var sprint_step: float = sprint_one[0]["travelled"]
	_ok(walk_vx > 25.0 and walk_vx < 35.0,
		"one frame of full input moves at %.2fpx/s" % walk_vx)
	_ok(walk_step > 0.4 and walk_step < 0.6,
		"and covers %.3fpx of ground" % walk_step)
	_ok(absf(sprint_vx - walk_vx) <= 0.1 and absf(sprint_step - walk_step) <= 0.1,
		"asking for a sprint does not slow the first frame (%.2f vs %.2f)"
			% [sprint_vx, walk_vx])

	await _reset()
	var walk_six := await _hold(1.0, false, 6)
	var six_vx: float = walk_six[5]["vx"]
	var six_x: float = walk_six[5]["travelled"]
	await _reset()
	var sprint_six := await _hold(1.0, true, 6)
	_ok(six_vx > 160.0 and six_vx < 185.0,
		"six frames reach %.2fpx/s" % six_vx)
	_ok(six_x > 9.0 and six_x < 12.0, "over %.2fpx" % six_x)
	_ok(absf(float(sprint_six[5]["vx"]) - six_vx) <= 0.1,
		"and a sprint is no different over the same six frames")
	# The push eases off as the speed climbs rather than switching over.
	var gained: Array[float] = []
	for i in range(6):
		var was: float = 0.0 if i == 0 else float(walk_six[i - 1]["vx"])
		gained.append(float(walk_six[i]["vx"]) - was)
	var eased := true
	for i in range(1, 6):
		if gained[i] > gained[i - 1] + 0.001:
			eased = false
	_ok(eased, "and each frame adds a little less than the one before it")

func _to_top_speed() -> void:
	await _reset()
	var walk := await _ticks_to(1.0, false, W)
	_ok(walk >= 10 and walk <= 12, "a walk reaches top speed in %d frames" % walk)
	await _reset()
	var sprint := await _ticks_to(1.0, true, S)
	_ok(sprint >= 16 and sprint <= 18,
		"a sprint reaches its own top speed in %d frames" % sprint)
	_ok(walk < sprint, "which is further away, so it takes longer to get to")

## Holding full input has to stay exactly at the cap: no creep, no oscillation
## around it, no slow drift out of the sprint into the walk.
func _cruise() -> void:
	await _reset()
	await _ticks_to(1.0, true, S)
	var drift := 0.0
	var trace := await _hold(1.0, true, 120)
	for step in trace:
		drift = maxf(drift, absf(float(step["vx"]) - S))
	_ok(drift <= 0.1, "two seconds of cruising stay at the cap (%.4f off)" % drift)
	_ok(bool(trace[119]["state"] == Runner.State.RUN), "and still read as running")

func _letting_go() -> void:
	await _reset()
	await _ticks_to(1.0, false, W)
	var walk := await _let_go_and_stop()
	_ok(int(walk[0]) >= 7 and int(walk[0]) <= 9,
		"letting go of a walk stops in %d frames" % walk[0])
	_ok(float(walk[1]) > 13.0 and float(walk[1]) < 16.0,
		"after %.2fpx" % walk[1])
	_ok(runner.velocity.x == 0.0, "and the last frame is a real zero")

	await _reset()
	await _ticks_to(1.0, true, S)
	var sprint := await _let_go_and_stop()
	_ok(int(sprint[0]) >= 10 and int(sprint[0]) <= 12,
		"letting go of a sprint stops in %d frames" % sprint[0])
	_ok(float(sprint[1]) > 32.0 and float(sprint[1]) < 36.0,
		"after %.2fpx" % sprint[1])
	_ok(runner.velocity.x == 0.0, "and the last frame is a real zero")

## Pressing the other way. Two separate questions: how long before the runner
## goes the other way at all, and how far do they carry on first.
func _turning_round() -> void:
	for sprint in [false, true]:
		var top := S if sprint else W
		var name := "sprint" if sprint else "walk"
		await _reset()
		await _ticks_to(1.0, sprint, top)
		hub.move_axis = -1.0
		var from := runner.position.x
		var furthest := 0.0
		var moved_back := -1
		var reached := -1
		for i in range(60):
			await _tick()
			furthest = maxf(furthest, runner.position.x - from)
			if moved_back < 0 and runner.velocity.x < 0.0:
				moved_back = i + 1
			if absf(runner.velocity.x + top) < 0.001:
				reached = i + 1
				break
		var back_want := 8 if sprint else 5
		var top_want := 24 if sprint else 16
		_ok(moved_back >= back_want - 1 and moved_back <= back_want + 1,
			"a %s starts going the other way after %d frames" % [name, moved_back])
		_ok(reached >= top_want - 1 and reached <= top_want + 1,
			"and is at full speed the other way after %d" % reached)
		var low := 20.0 if sprint else 8.0
		var high := 23.0 if sprint else 11.0
		_ok(furthest >= low and furthest <= high,
			"carrying %.2fpx past the turn" % furthest)
		# The hard brake belongs to the stop, not to the new direction.
		var after := await _hold(-1.0, sprint, 1)
		_ok(float(after[0]["vx"]) <= 0.0,
			"and the brake does not push on into the new direction")

## Weakening the input, or letting go of sprint, is a brake in its own right --
## not a weaker push, and not an instant clamp down to the new ceiling.
func _easing_off() -> void:
	var rate := Balance.RUNNER_GROUND_DECEL
	await _reset()
	await _ticks_to(1.0, true, S)
	# Sprint released: the target drops to a walk and the speed has to come down
	# to it at the deceleration rate.
	_sprint(false)
	var last := runner.velocity.x
	var measured: Array[float] = []
	var overshot := false
	for _i in range(20):
		await _tick()
		var vx := runner.velocity.x
		if vx < W - 0.001:
			overshot = true
		if absf(vx - W) > 0.001:
			measured.append((last - vx) * 60.0)
		last = vx
		if absf(vx - W) < 0.001:
			break
	_ok(measured.size() >= 2, "releasing sprint takes several frames to come down")
	var worst := 0.0
	for r in measured:
		worst = maxf(worst, absf(r - rate))
	_ok(worst <= 1.0, "at %.0fpx/s^2, the asked-for rate (worst %.2f off)"
		% [rate, worst])
	_ok(not overshot, "and stops at a walk rather than dropping under it")
	_ok(absf(runner.velocity.x - W) < 0.001, "landing exactly on the walking cap")

	# The same thing with the thumb: full input eased back to half.
	await _reset()
	await _ticks_to(1.0, false, W)
	var half := Runner.ground_target(0.5, false)
	hub.move_axis = 0.5
	var last_half := runner.velocity.x
	var worst_half := 0.0
	var under := false
	for _i in range(30):
		await _tick()
		var vx := runner.velocity.x
		if vx < half - 0.001:
			under = true
		if absf(vx - half) > 0.001:
			worst_half = maxf(worst_half, absf((last_half - vx) * 60.0 - rate))
		last_half = vx
		if absf(vx - half) < 0.001:
			break
	_ok(worst_half <= 1.0,
		"easing the thumb back brakes at the same rate (worst %.2f off)" % worst_half)
	_ok(not under and absf(runner.velocity.x - half) < 0.001,
		"and settles on what the thumb is asking for (%.2fpx/s)" % half)

## The shape of the stick's answer. The table is the design's; these are the
## speeds the real runner comes to rest at.
func _input_curve() -> void:
	var want := {
		0.05: [0.0, 0.0], 0.06: [1.46, 2.18], 0.10: [7.58, 11.37],
		0.11: [9.19, 13.78], 0.25: [34.86, 52.29], 0.50: [95.49, 143.24],
		0.75: [175.07, 262.61], 1.00: [273.60, 410.40],
	}
	var axes: Array = want.keys()
	axes.sort()
	for sprint in [false, true]:
		var name := "sprint" if sprint else "walk"
		var previous := -1.0
		var monotonic := true
		var worst := 0.0
		var asymmetric := 0.0
		for axis in axes:
			await _reset()
			await _hold(float(axis), sprint, 60)
			var right := runner.velocity.x
			await _reset()
			await _hold(-float(axis), sprint, 60)
			var left := runner.velocity.x
			var expected: float = float(want[axis][1 if sprint else 0])
			worst = maxf(worst, absf(right - expected))
			asymmetric = maxf(asymmetric, absf(right + left))
			if right < previous - 0.001:
				monotonic = false
			previous = right
		_ok(worst <= 0.1,
			"%s speeds match the designed curve (worst %.3f off)" % [name, worst])
		_ok(asymmetric <= 0.001, "%s reads the same left and right" % name)
		_ok(monotonic, "%s speed only ever rises with the lean" % name)

	# The two places the old reading had a step in it: just past the deadzone,
	# where speed used to appear from nowhere, and around 0.1, where the sprint
	# cap used to switch in. Neither may be a jump now.
	await _reset()
	await _hold(0.0501, true, 60)
	var barely := absf(runner.velocity.x)
	_ok(barely < 0.5, "a lean barely past the deadzone is barely any speed (%.3f)"
		% barely)
	var around: Array[float] = []
	for axis in [0.09, 0.10, 0.11, 0.12]:
		await _reset()
		await _hold(axis, true, 60)
		around.append(absf(runner.velocity.x))
	var biggest := 0.0
	for i in range(1, around.size()):
		biggest = maxf(biggest, around[i] - around[i - 1])
	_ok(biggest < 5.0,
		"and nothing switches over around 0.1 (biggest step %.2fpx/s)" % biggest)

## What a tap is worth. The whole distance, press to standstill, because that is
## what has to fit on a ledge.
func _taps() -> void:
	var want := {1: 0.50, 3: 4.04, 6: 15.27}
	for held in [1, 3, 6]:
		var measured: Array[float] = []
		for sprint in [false, true]:
			await _reset()
			var from := runner.position.x
			await _hold(1.0, sprint, held)
			await _let_go_and_stop()
			measured.append(absf(runner.position.x - from))
		var expected: float = float(want[held])
		_ok(absf(measured[0] - expected) <= 1.0,
			"a %d-frame tap covers %.2fpx in all (asked %.2f)"
				% [held, measured[0], expected])
		_ok(absf(measured[1] - measured[0]) <= 0.1,
			"and a sprinted %d-frame tap covers the same" % held)

## The one-block ledge. Not a promise that a full sprint stops on it -- it does
## not, and the design says so -- but that the slow end of the stick is enough
## to place a runner on one, and that a gentle landing stays on it.
func _one_block_perch() -> void:
	var centre := PERCH_X
	var resting := PERCH_TOP - Balance.RUNNER_SIZE.y * 0.5
	var room := PERCH_WIDTH * 0.5 - Balance.RUNNER_SIZE.x * 0.5

	Options.set_auto_dash(true)
	await _reset(Vector2(centre, resting - 4.0))
	_ok(absf(runner.position.x - centre) < 0.001 and runner.position.y < FLOOR_TOP,
		"the runner settles in the middle of the block")
	var from := runner.position.x
	await _hold(0.25, false, 9)
	hub.move_axis = 0.0
	var stopped := await _let_go_and_stop()
	var travelled: float = absf(runner.position.x - from)
	_ok(travelled <= 8.5,
		"nine frames of a quarter lean move %.2fpx, inside the block" % travelled)
	_ok(runner.is_on_floor() and runner.position.y < FLOOR_TOP,
		"and the runner is still standing on it")
	_ok(absf(runner.position.x - centre) <= room,
		"with the whole body over it (%.2fpx of %.2f)"
			% [absf(runner.position.x - centre), room])
	_ok(runner.velocity.x == 0.0 and int(stopped[0]) > 0,
		"and stopped rather than still creeping")
	Options.set_auto_dash(false)
	Options.forget()

	# And a gentle landing: no input, a landing speed the air control can reach,
	# and the stop has to happen on the block.
	await _reset(Vector2(centre - 12.0, resting - 8.0))
	runner.position = Vector2(centre - 12.0, resting - 8.0)
	runner.velocity = Vector2(160.0, 0.0)
	hub.move_axis = 0.0
	var landed_at := INF
	var landing_speed := 0.0
	for _i in range(40):
		await _tick()
		if runner.is_on_floor():
			landed_at = runner.position.x
			landing_speed = absf(runner.velocity.x)
			break
	_ok(landed_at != INF and landing_speed <= 160.0,
		"a landing at %.1fpx/s arrives on the block" % landing_speed)
	var run_on := await _let_go_and_stop()
	_ok(float(run_on[1]) <= 9.0 and absf(runner.position.x - landed_at) <= 9.0,
		"and runs on %.2fpx before stopping" % run_on[1])
	_ok(runner.is_on_floor() and runner.position.y < FLOOR_TOP,
		"ending on the block rather than under it")
	_ok(absf(runner.position.x - centre) <= room,
		"with the whole body still over it (%.2fpx of %.2f)"
			% [absf(runner.position.x - centre), room])
	_ok(runner.velocity.x == 0.0, "and at a standstill")
