extends Node
## Does the runner survive the shapes that are not open ground?
##
## Every number in balance.gd was chosen on a flat plateau and every arc in the
## suite is measured on one. A plateau is the one place a platformer cannot go
## wrong: the runner who feels perfect there and snags on the seam between two
## slabs is the runner nobody trusts, and checking the jump arc would never say
## so, because the arc is fine.
##
## So this walks 1-T shape by shape and asks, of each one, the question that
## shape exists to ask. Every check names the shape, so a failure says where.
##
##   godot --headless --path . --fixed-fps 60 res://test/workshop_probe.tscn

var main: Node2D = null
var failures: int = 0
var checks: int = 0
var _finished: bool = false

var _runner: Runner = null
var _hub: InputHub = null

func _ready() -> void:
	Stage.use(Stage.Which.WORKSHOP)
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(6)
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
		await _frames(2)
	main.input_hub.scripted = true
	_runner = main.runner
	_hub = main.input_hub
	main._respawn_timer = -1.0

	print("== the shapes that are not open ground ==")
	await _seam()
	await _step_up()
	await _step_down()
	await _narrow_perch()
	await _low_ceiling()
	await _corridor()
	await _outside_corner()
	await _inside_corner()
	await _moving_floor()
	await _the_straight()
	_finished = true

	print("")
	# A runtime error inside an awaited function abandons it without failing
	# anything, so "did we get to the end" is itself a check.
	if not _finished:
		failures += 1
		checks += 1
		print("  FAIL  the probe ran to the end (it stopped early)")
	if failures == 0:
		print("the workshop is clean (%d checks)" % checks)
	else:
		print("%d of %d checks FAILED" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)

func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame

func _physics(n: int) -> void:
	for _i in range(n):
		await get_tree().physics_frame

func _ok(label: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("  ok    ", label)
	else:
		failures += 1
		print("  FAIL  ", label, "" if detail.is_empty() else "  -- " + detail)

## Put the runner down at a place and let them settle.
func _stand_at(x: float, y: float) -> void:
	_hub.move_axis = 0.0
	_hub.dash_held = false
	_hub.release_jump()
	_runner.global_position = Vector2(x, y)
	_runner.velocity = Vector2.ZERO
	for _i in range(60):
		await get_tree().physics_frame
		if _runner.is_on_floor():
			break

## Walk right for a while and report the slowest the runner got while doing it.
## Snagging is a loss of speed, so that is what this measures.
func _walk_through(to_x: float, seconds: float) -> Dictionary:
	_hub.move_axis = 1.0
	var slowest := 99999.0
	var stalled := 0
	var frames := int(seconds * 60.0)
	var reached := false
	for _i in range(frames):
		await get_tree().physics_frame
		# Only once up to speed: the first strides are acceleration, not a snag.
		if _i > 20 and _runner.is_on_floor():
			var speed := absf(_runner.velocity.x)
			slowest = minf(slowest, speed)
			if speed < Balance.RUNNER_RUN_SPEED * 0.25:
				stalled += 1
		if _runner.global_position.x >= to_x:
			reached = true
			break
	_hub.move_axis = 0.0
	return {"reached": reached, "slowest": slowest, "stalled": stalled,
		"x": _runner.global_position.x}

# ------------------------------------------------------------------ the shapes

## Two slabs meeting flush. Nothing to see and everything to get wrong: if the
## collision shapes disagree by a pixel the runner trips on thin air.
func _seam() -> void:
	await _stand_at(Level03Data.SEAM_X - 400.0, Level03Data.FLOOR - 60.0)
	var walk := await _walk_through(Level03Data.SEAM_X + 300.0, 8.0)
	_ok("the seam: the runner walks over it", walk["reached"],
		"stopped at x=%.0f" % walk["x"])
	_ok("the seam: without losing speed (slowest %.0f of %.0f)"
			% [walk["slowest"], Balance.RUNNER_RUN_SPEED],
		float(walk["slowest"]) > Balance.RUNNER_RUN_SPEED * 0.9)
	_ok("the seam: and never stalls on it (%d frames)" % walk["stalled"],
		int(walk["stalled"]) == 0)

## A one-block step, walked into rather than jumped. Either the runner steps up
## or they stop; both are defensible, but stopping dead at ankle height and
## still playing the run animation is not.
func _step_up() -> void:
	await _stand_at(Level03Data.STEP_UP_X - 400.0, Level03Data.FLOOR - 60.0)
	var walk := await _walk_through(Level03Data.STEP_UP_X + 200.0, 8.0)
	var climbed: bool = bool(walk["reached"])
	if not climbed:
		# Refused is fine. It has to be refused HONESTLY: pressed against it,
		# not walking on the spot half way up.
		_ok("the step up: a one-block step is refused rather than half-climbed",
			absf(_runner.global_position.y - (Level03Data.FLOOR - 60.0)) < 40.0,
			"ended at y=%.0f" % _runner.global_position.y)
		# And a jump gets over it, which is what makes refusing acceptable.
		_hub.move_axis = 1.0
		_hub.press_jump()
		await _physics(30)
		_hub.release_jump()
		await _physics(30)
		_hub.move_axis = 0.0
		_ok("the step up: and one jump clears it",
			_runner.global_position.x > Level03Data.STEP_UP_X + 40.0,
			"ended at x=%.0f" % _runner.global_position.x)
	else:
		_ok("the step up: the runner walks straight up it", true)
		_ok("the step up: and is standing on it afterwards", _runner.is_on_floor())

## The same step going down. The runner must not float out over the drop or
## stick to the lip.
func _step_down() -> void:
	await _stand_at(Level03Data.STEP_DOWN_X - 400.0,
		Level03Data.FLOOR - Level03Data.BLOCK - 60.0)
	var walk := await _walk_through(Level03Data.STEP_DOWN_X + 300.0, 8.0)
	_ok("the step down: the runner walks off it", walk["reached"],
		"stopped at x=%.0f" % walk["x"])
	await _physics(30)
	_ok("the step down: and lands on the lower floor",
		_runner.is_on_floor()
			and absf(_runner.global_position.y - (Level03Data.FLOOR - 23.0)) < 8.0,
		"y=%.0f wanted %.0f" % [_runner.global_position.y, Level03Data.FLOOR - 23.0])

## One block wide, two blocks up. Landing on it is one question; staying on it
## is the other, and the answer to the second one is the stopping distance.
func _narrow_perch() -> void:
	var top := Level03Data.FLOOR - 2.0 * Level03Data.BLOCK
	await _stand_at(Level03Data.PERCH_X + Level03Data.BLOCK * 0.5, top - 40.0)
	_ok("the perch: a runner put on it stays on it", _runner.is_on_floor(),
		"y=%.0f" % _runner.global_position.y)
	# Walking off the end and stopping: how far past the edge does a thumb have
	# to let go? That distance is RUNNER_TIME_TO_STOP, and if it is longer than
	# the perch the perch is unusable.
	var stop_from := _runner.global_position.x
	var ran_on := await _tap_and_stop(6)
	_ok("the perch: letting go stops inside a block (%.0fpx of %.0f)"
			% [ran_on, Level03Data.BLOCK], ran_on < Level03Data.BLOCK)
	_ok_on_perch("the perch", top, stop_from)

	# And the same thing with auto-dash on, which is the question the setting
	# raises: giving the sprint away for free also gives away the stopping
	# distance, and this is the place where that would show. A setting that
	# quietly makes a one-block perch unusable is a setting that makes the game
	# harder somewhere the player cannot see.
	Options.forget()
	Options.set_auto_dash(true)
	await _stand_at(Level03Data.PERCH_X + Level03Data.BLOCK * 0.5, top - 40.0)
	var auto_from := _runner.global_position.x
	var auto_ran := await _tap_and_stop(6)
	_ok("the perch: and still stops inside a block with auto-dash on (%.0fpx)"
			% auto_ran, auto_ran < Level03Data.BLOCK)
	_ok_on_perch("the perch with auto-dash", top, auto_from)
	Options.set_auto_dash(false)
	Options.forget()

## Six frames of input and then nothing, reported as the whole distance covered
## -- including any of it spent in the air. Measuring only the grounded frames
## is how a runner who walks off the end still passes: the last reading taken
## while there was still a floor under them is a small number.
func _tap_and_stop(frames: int) -> float:
	var from := _runner.global_position.x
	_hub.move_axis = 1.0
	await _physics(frames)
	_hub.move_axis = 0.0
	for _i in range(90):
		await get_tree().physics_frame
		if absf(_runner.velocity.x) < 0.001:
			break
	return absf(_runner.global_position.x - from)

## Still up there, still stopped, and still over the block rather than hooked on
## its lip by a corner.
func _ok_on_perch(what: String, top: float, started_at: float) -> void:
	var left := Level03Data.PERCH_X
	var right := Level03Data.PERCH_X + Level03Data.BLOCK
	var feet := _runner.global_position.x
	_ok("%s: the runner is still standing on it" % what,
		_runner.is_on_floor()
			and absf(_runner.global_position.y - (top - Balance.RUNNER_SIZE.y * 0.5)) < 8.0,
		"y=%.0f wanted %.0f (started at x=%.0f)"
			% [_runner.global_position.y, top - Balance.RUNNER_SIZE.y * 0.5, started_at])
	# Overhanging the lip is fine and normal -- a body keeps its floor while any
	# of it is over one. Walking off the end is not: the feet have to be over
	# the block, not merely touching its corner.
	_ok("%s: with the feet over it and the body still on it" % what,
		feet >= left and feet <= right
			and feet + Balance.RUNNER_SIZE.x * 0.5 > left
			and feet - Balance.RUNNER_SIZE.x * 0.5 < right,
		"feet at %.0f, body spans %.0f..%.0f of %.0f..%.0f"
			% [feet, feet - Balance.RUNNER_SIZE.x * 0.5,
				feet + Balance.RUNNER_SIZE.x * 0.5, left, right])
	_ok("%s: and has actually stopped" % what, _runner.velocity.x == 0.0,
		"still moving at %.2fpx/s" % _runner.velocity.x)

## A ceiling just under a full jump. The rise has to end at it without the
## runner clinging to it or being thrown along it.
func _low_ceiling() -> void:
	await _stand_at(Level03Data.LOW_CEILING_X, Level03Data.FLOOR - 60.0)
	_hub.move_axis = 0.0
	_hub.press_jump()
	var bonked := false
	var climbed_frames := 0
	var thrown := 0.0
	for _i in range(70):
		await get_tree().physics_frame
		if _runner.is_on_ceiling():
			bonked = true
			thrown = maxf(thrown, absf(_runner.velocity.x))
			if _runner.velocity.y < -1.0:
				climbed_frames += 1
		if bonked and _runner.is_on_floor():
			break
	_hub.release_jump()
	_ok("the low ceiling: a full jump reaches it", bonked)
	_ok("the low ceiling: the rise ends there (%d frames pushing into it)"
			% climbed_frames, climbed_frames == 0)
	_ok("the low ceiling: nothing is added sideways (%.0fpx/s)" % thrown,
		thrown < 20.0)
	_ok("the low ceiling: and the runner comes back down", _runner.is_on_floor())

## A low ceiling and a seam in the same place. Each is survivable alone; this is
## where a runner who survives both still snags.
func _corridor() -> void:
	await _stand_at(Level03Data.CORRIDOR_X - 400.0, Level03Data.FLOOR - 60.0)
	var walk := await _walk_through(Level03Data.CORRIDOR_X + 350.0, 8.0)
	_ok("the corridor: the runner gets through it", walk["reached"],
		"stopped at x=%.0f" % walk["x"])
	_ok("the corridor: without stalling (%d frames)" % walk["stalled"],
		int(walk["stalled"]) == 0)
	# And jumping inside it, which is the case that puts a head on the ceiling
	# while the feet are still moving.
	_hub.move_axis = 1.0
	_hub.press_jump()
	var kept_going := true
	for _i in range(40):
		await get_tree().physics_frame
		if _runner.is_on_ceiling() and absf(_runner.velocity.x) < 40.0:
			kept_going = false
	_hub.release_jump()
	_hub.move_axis = 0.0
	_ok("the corridor: jumping under the ceiling does not stop them dead",
		kept_going)

## The lip a jump is taken from. Coyote time lives here: a press just after
## leaving it still jumps, and a press well after it does not.
func _outside_corner() -> void:
	var lip := Level03Data.OUTSIDE_CORNER_X
	# Just after: inside the grace window.
	await _stand_at(lip - 200.0, Level03Data.FLOOR - 60.0)
	_hub.move_axis = 1.0
	var left_at := -1.0
	for _i in range(120):
		await get_tree().physics_frame
		if not _runner.is_on_floor():
			left_at = 0.0
			break
	var jumped_late := false
	if left_at >= 0.0:
		# Half the grace window after the lip: must still jump.
		await _physics(maxi(1, int(Balance.RUNNER_COYOTE_TIME * 60.0 * 0.5)))
		var before := _runner.velocity.y
		_hub.press_jump()
		await _physics(2)
		jumped_late = _runner.velocity.y < before - 100.0
	_hub.move_axis = 0.0
	_ok("the outside corner: a press just after the lip still jumps", jumped_late)

	# Well after: outside it. The window has to have an outside edge or it is
	# not a window, it is a second jump.
	await _stand_at(lip - 200.0, Level03Data.FLOOR - 60.0)
	_hub.move_axis = 1.0
	for _i in range(120):
		await get_tree().physics_frame
		if not _runner.is_on_floor():
			break
	await _physics(int(Balance.RUNNER_COYOTE_TIME * 60.0) + 8)
	var falling := _runner.velocity.y
	_hub.press_jump()
	await _physics(2)
	var jumped_too_late := _runner.velocity.y < falling - 100.0
	_hub.move_axis = 0.0
	_ok("the outside corner: and a press well after it does not", not jumped_too_late)

## Floor meeting wall. A run into it ends; it must not climb, stick, or shudder.
func _inside_corner() -> void:
	await _stand_at(Level03Data.INSIDE_CORNER_X - 300.0, Level03Data.FLOOR - 60.0)
	_hub.move_axis = 1.0
	await _physics(120)
	var against := _runner.global_position
	await _physics(30)
	_hub.move_axis = 0.0
	_ok("the inside corner: a run into the wall stops",
		absf(_runner.global_position.x - against.x) < 4.0,
		"drifted %.1fpx" % absf(_runner.global_position.x - against.x))
	_ok("the inside corner: and does not climb it",
		absf(_runner.global_position.y - against.y) < 4.0,
		"rose %.1fpx" % (against.y - _runner.global_position.y))
	_ok("the inside corner: the runner is still on the ground",
		_runner.is_on_floor())

## Carried sideways, standing and jumping. A floor that moves under a runner is
## the classic place for the two to disagree about where the runner is.
func _moving_floor() -> void:
	# By type, and anywhere under the world: moving platforms are not in a
	# group, and adding one just for a test would be the test changing the game
	# to suit itself. The level builder parents them a couple of levels down.
	var pads: Array[Node2D] = []
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			if child is MovingPlatform:
				pads.append(child)
			stack.append(child)
	_ok("the moving floor: there is one", pads.size() >= 1)
	if pads.is_empty():
		return
	var pad: Node2D = pads[0]
	await _stand_at(pad.global_position.x, pad.global_position.y - 60.0)
	_ok("the moving floor: the runner stands on it", _runner.is_on_floor(),
		"y=%.0f pad y=%.0f" % [_runner.global_position.y, pad.global_position.y])
	if not _runner.is_on_floor():
		return
	# Carried: over a second, the runner should still be on it.
	var off := _runner.global_position.x - pad.global_position.x
	await _physics(60)
	var drift: float = absf((_runner.global_position.x - pad.global_position.x) - off)
	_ok("the moving floor: and is carried with it (drifted %.0fpx)" % drift,
		_runner.is_on_floor() and drift < 40.0)
	# And a jump off it lands somewhere, rather than falling through.
	_hub.press_jump()
	await _physics(8)
	_hub.release_jump()
	var landed := false
	for _i in range(120):
		await get_tree().physics_frame
		if _runner.is_on_floor():
			landed = true
			break
	_ok("the moving floor: a jump off it lands", landed,
		"ended at y=%.0f" % _runner.global_position.y)

## The measuring straight: long, flat, empty. The dials are checked here, in the
## same stage as the awkward shapes rather than in a different one.
func _the_straight() -> void:
	await _stand_at(Level03Data.STRAIGHT_X, Level03Data.FLOOR - 60.0)
	var floor_y := _runner.global_position.y
	var apex := floor_y
	var rose := 0.0
	var to_apex := 0.0
	_hub.press_jump()
	for i in range(90):
		await get_tree().physics_frame
		rose += Clock.DT
		if _runner.global_position.y < apex:
			apex = _runner.global_position.y
			to_apex = rose
		if i > 4 and _runner.is_on_floor():
			break
	_hub.release_jump()
	var height := floor_y - apex
	_ok("the straight: a held jump goes %.2f blocks up" % (height / Balance.B),
		absf(height - Balance.RUNNER_JUMP_HEIGHT) < Balance.B * 0.35,
		"asked %.0f, got %.0f" % [Balance.RUNNER_JUMP_HEIGHT, height])
	# The held-jump target after the apex easing was added, not the band that
	# was written down before it. The dial itself (RUNNER_TIME_TO_APEX) is
	# still 0.33; the easing is what the extra is.
	_ok("the straight: in %.3fs" % to_apex,
		to_apex >= 0.34 and to_apex <= 0.39)
	# Measured here AND in 1-1 by run_tests. Two stages, one answer -- if they
	# ever disagree, something is reading the ground rather than the dials.
	_ok("the straight: which is the same answer the other stages give",
		absf(height - Balance.RUNNER_JUMP_HEIGHT) < Balance.B * 0.35)
