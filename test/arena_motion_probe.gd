extends Node
## Can the arena's movement be re-run, and does it move like the game does?
##
## docs/coin-battle-plan.md 13.2 item 9: "同じ静止地形・同じ入力列で、host と
## 再実行の位置差が1px以内". That sentence is the whole reason ArenaMotor keeps
## its state in a struct instead of on a node, and it is what the prediction and
## correction in P2 will be built on -- so it is checked now, before anything
## depends on it, rather than discovered when four machines disagree.
##
## Two other things are measured here rather than assumed:
##
## - that JumpMath really is the cooperative runner's jump. The extraction was
##   supposed to be verbatim; a comparison against Runner._normal_vertical_step
##   is the only thing that can say it was. The plan makes that comparison the
##   precondition for ever pointing Runner at JumpMath (7.2).
## - that the plan's arena is actually climbable. 6.1 gives 120px and 110px
##   between its floors and says plainly that they are provisional: "到達性は
##   実装後に測る". So they are measured, and if a shelf were out of reach the
##   answer would be to move the shelf, not to raise the jump.

var failures: Array[String] = []
var _current: String = ""

const DELTA: float = 1.0 / 60.0
## The plan's tolerance for a re-simulation (9.3). Every comparison here comes
## out exact, and it is asserted at 1px because that is the contract P2 needs
## rather than the number this machine happens to produce.
const REPLAY_TOLERANCE: float = 1.0

func check(ok: bool, label: String) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		failures.append("%s: %s" % [_current, label])
		print("  FAIL  %s" % label)

func _ready() -> void:
	_test_replay()
	_test_state_restore()
	_test_matches_runner()
	_test_reachability()

	print("arena motion probe: %d checks failed" % failures.size())
	if failures.is_empty():
		print("the arena's movement re-runs, and it is the game's jump")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("arena motion probe: " + f)
		get_tree().quit(1)

# --------------------------------------------------------------------- inputs
## A long, deterministic input sequence with plenty of edges in it: turns,
## stick-centre coasting, taps, holds and releases. Derived from a seed rather
## than written out, because a hand-written sequence tests the cases its author
## thought of.
func _sequence(length: int, input_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = input_seed
	var out: Array = []
	var axis := 0.0
	var held := false
	var seq := 0
	for i in range(length):
		if rng.randf() < 0.08:
			axis = rng.randf_range(-1.0, 1.0)
		if rng.randf() < 0.10:
			if held:
				held = false
			else:
				held = true
				seq += 1
		out.append(ArenaMotor.MotorInput.new(axis, held, seq))
	return out

func _play(s: ArenaMotor.MotorState, world: ArenaStage, inputs: Array,
		from: int, to: int) -> void:
	for i in range(from, to):
		ArenaMotor.step(s, inputs[i], world, DELTA)

# -------------------------------------------------------------- 13.2 item 9
## Save the state partway through, replay the rest of the same inputs, and land
## in the same place.
func _test_replay() -> void:
	_current = "replay"
	var world := ArenaStage.from_data()
	var inputs := _sequence(480, 90210)

	# The host's run, with a copy of the state kept at every tick.
	var host := ArenaMotor.MotorState.new()
	ArenaMotor.reset_at(host, Vector2(-200.0,
		ArenaStageData.standing_on(ArenaStageData.MAIN_FLOOR_TOP)), 1)
	var saves: Array = []
	var track: Array[Vector2] = []
	for i in range(inputs.size()):
		saves.append(host.duplicate_state())
		ArenaMotor.step(host, inputs[i], world, DELTA)
		track.append(host.position)

	var worst := 0.0
	for at in [1, 7, 33, 90, 91, 200, 331, 479]:
		var replay: ArenaMotor.MotorState = saves[at].duplicate_state()
		_play(replay, world, inputs, at, inputs.size())
		var drift := replay.position.distance_to(host.position)
		worst = maxf(worst, drift)
	check(worst <= REPLAY_TOLERANCE,
		"re-simulating from any of 8 save points lands within 1px (worst %.4f)" % worst)

	# The same inputs from the same start must also give the same track, tick
	# for tick -- not just the same end point. A path that differs in the middle
	# and agrees at the end would still show a client's fighter in the wrong
	# place for a second.
	var again := ArenaMotor.MotorState.new()
	ArenaMotor.reset_at(again, Vector2(-200.0,
		ArenaStageData.standing_on(ArenaStageData.MAIN_FLOOR_TOP)), 1)
	var tick_worst := 0.0
	for i in range(inputs.size()):
		ArenaMotor.step(again, inputs[i], world, DELTA)
		tick_worst = maxf(tick_worst, again.position.distance_to(track[i]))
	check(tick_worst <= REPLAY_TOLERANCE,
		"and the whole 480-tick track matches, not just the end (worst %.4f)" % tick_worst)

	# A negative control for the tolerance itself: a replay given the WRONG
	# inputs must not pass. Without this, a comparison that accidentally
	# compared a state with itself would look identical to a correct one.
	var wrong: ArenaMotor.MotorState = saves[90].duplicate_state()
	var other := _sequence(480, 55555)
	_play(wrong, world, other, 90, other.size())
	check(wrong.position.distance_to(host.position) > REPLAY_TOLERANCE,
		"and a replay of DIFFERENT inputs does not land in the same place")

## Save and restore across the moments where state is easiest to lose: the tick
## a jump starts, the tick a body lands, and the tick it hits its head.
func _test_state_restore() -> void:
	_current = "state restore"
	# A box with a low ceiling, so the ceiling branch is actually reached. The
	# arena's own ceiling is 500px up and no jump gets near it.
	var boxes: Array[Rect2] = [
		Rect2(-200.0, 100.0, 400.0, 20.0),     # floor, top at 100
		Rect2(-200.0, -20.0, 400.0, 20.0),     # ceiling, underside at 0
	]
	var world := ArenaStage.new(boxes)
	var stand := 100.0 - ArenaRules.BODY_SIZE.y * 0.5

	var inputs: Array = []
	for i in range(180):
		# Hold right and hold jump: rise, hit the ceiling, fall, land, repeat.
		var held := (i % 45) < 20
		var seq := int(i / 45) + 1
		inputs.append(ArenaMotor.MotorInput.new(1.0, held, seq))

	var host := ArenaMotor.MotorState.new()
	ArenaMotor.reset_at(host, Vector2(-150.0, stand), 1)
	var saves: Array = []
	var flags: Array = []
	for i in range(inputs.size()):
		saves.append(host.duplicate_state())
		var was_grounded := host.grounded
		var was_vy := host.velocity.y
		ArenaMotor.step(host, inputs[i], world, DELTA)
		flags.append({
			"takeoff": was_grounded and not host.grounded,
			"landing": not was_grounded and host.grounded,
			"ceiling": was_vy < 0.0 and host.velocity.y == 0.0 and not host.grounded,
		})

	var interesting := {"takeoff": -1, "landing": -1, "ceiling": -1}
	for i in range(flags.size()):
		for k in ["takeoff", "ceiling"]:
			if interesting[k] < 0 and bool(flags[i][k]):
				interesting[k] = i
	# The landing has to be one that follows a take-off. The state starts
	# airborne and settles on tick 0, which is a landing and is not the case
	# worth restoring across.
	for i in range(flags.size()):
		if interesting["takeoff"] >= 0 and i > interesting["takeoff"] \
				and bool(flags[i]["landing"]):
			interesting["landing"] = i
			break

	for k in ["takeoff", "landing", "ceiling"]:
		var at: int = interesting[k]
		if at < 0:
			check(false, "the scenario reaches a %s at all" % k)
			continue
		var replay: ArenaMotor.MotorState = saves[at].duplicate_state()
		_play(replay, world, inputs, at, inputs.size())
		var drift := replay.position.distance_to(host.position)
		check(drift <= REPLAY_TOLERANCE,
			"restoring on the %s tick (%d) replays exactly (%.4f)" % [k, at, drift])

	# The apex budget is state too, and it is the easiest thing to leave out of
	# a copy: a duplicate that shared the JumpMath.State object would drift the
	# moment the original kept rising.
	var origin: ArenaMotor.MotorState = saves[interesting["takeoff"]]
	var before_apex := origin.jump.apex_time_left
	var before_time := origin.jump.jump_time
	var moved := origin.duplicate_state()
	_play(moved, world, inputs, interesting["takeoff"], inputs.size())
	check(origin.jump.apex_time_left == before_apex
			and origin.jump.jump_time == before_time,
		"and a duplicated state does not share its jump with the original")

# ------------------------------------------------ the game's jump, not a new one
## JumpMath against the code it was lifted from.
##
## Runner._normal_vertical_step is driven directly. It touches no collision, no
## tree and no events -- only `velocity.y` and its own jump fields -- so an
## unparented Runner with a stub hub is a faithful way to ask what the
## cooperative jump does, and the alternative (reading both and agreeing they
## look the same) is what let the difference exist in the first place.
func _test_matches_runner() -> void:
	_current = "matches runner"
	for release_at in [-1, 1, 3, 6, 14, 30]:
		var label := "held throughout" if release_at < 0 \
			else "released on tick %d" % release_at
		var drift := _compare_vertical(release_at)
		check(drift == 0.0,
			"JumpMath matches Runner's vertical step exactly, %s (worst %.8f)"
				% [label, drift])

	# Negative control: if the comparison could not tell two trajectories apart
	# it would pass for the wrong reason. Hand it a jump that starts from a
	# different velocity and it has to fail.
	var bad := _compare_vertical(-1, 0.75)
	check(bad > 1.0,
		"and the comparison does notice a jump that starts 25% weaker")

	# Why the comparison is run through a Vector2 rather than a bare float.
	#
	# Measured, not assumed: the first version of this check kept the arena's vy
	# in a plain float and failed by 2.7e-4 over 120 ticks. That is not a
	# difference in the maths -- it is that CharacterBody2D.velocity is a
	# Vector2, whose components are single precision, so Runner rounds its vy on
	# every store and a GDScript float does not. Putting the arena's vy in a
	# Vector2 as well makes the two agree to the last bit, which is the proof
	# that the extraction was verbatim; loosening the tolerance instead would
	# have hidden any real difference smaller than the rounding.
	var loose := _compare_vertical(-1, 1.0, false)
	print("    single precision costs %.8f px/s over 120 ticks" % loose)
	check(loose > 0.0 and loose < 1e-3,
		"and the whole difference is Vector2's single precision (%.8f)" % loose)

## Returns the worst per-tick difference in vy between Runner and JumpMath.
##
## `through_vector2` stores the arena's vy the way Runner has to store its own.
func _compare_vertical(release_at: int, arena_scale: float = 1.0,
		through_vector2: bool = true) -> float:
	var hub := InputHub.new()
	hub.jump_held = true
	hub.jump_release_sequence = 0
	var runner := Runner.new()
	runner.input_hub = hub
	runner.velocity = Vector2(0.0, Balance.RUNNER_JUMP_VELOCITY)
	runner._begin_player_jump(0)

	var st := JumpMath.State.new()
	JumpMath.begin(st)
	var vy := Balance.RUNNER_JUMP_VELOCITY * arena_scale
	var packed := Vector2(0.0, vy)

	var worst := 0.0
	for i in range(120):
		if release_at >= 0 and i == release_at:
			# Runner decides a release by the sequence moving on; JumpMath is
			# handed the resolved answer. Both have to be told at the same tick.
			hub.jump_held = false
			hub.jump_release_sequence = 1
		var held := hub.jump_held
		# Runner's order: _tick_timers first, then the vertical step.
		if runner._player_jump_active:
			runner._jump_time += DELTA
		runner._normal_vertical_step(DELTA)
		JumpMath.advance_time(st, DELTA)
		if through_vector2:
			packed.y = JumpMath.step(st, packed.y, held, DELTA)
			vy = packed.y
		else:
			vy = JumpMath.step(st, vy, held, DELTA)
		worst = maxf(worst, absf(vy - runner.velocity.y))
	runner.free()
	hub.free()
	return worst

# ------------------------------------------------------ is the arena climbable
## Measure the jump, then check the plan's floors against it (6.1).
func _test_reachability() -> void:
	_current = "reachability"
	var flat: Array[Rect2] = [Rect2(-600.0, 100.0, 1200.0, 40.0)]
	var world := ArenaStage.new(flat)
	var stand := 100.0 - ArenaRules.BODY_SIZE.y * 0.5

	var rise := _measure_rise(world, Vector2(0.0, stand), 0.0)
	var running_rise := _measure_rise(world, Vector2(-300.0, stand), 1.0)
	print("    standing rise %.1fpx, running rise %.1fpx" % [rise, running_rise])

	# A closed form for the same jump, ignoring the apex hover: v^2 / 2g.
	#
	# The measurement comes out BELOW it, and should: the peak is sampled once a
	# tick, and one tick of the launch velocity is 10px. So the bound is the
	# closed form less two ticks of launch travel rather than a round fraction of
	# it -- a fudged 0.9 here would pass just as happily if the jump lost a fifth
	# of its height.
	var v := absf(Balance.RUNNER_JUMP_VELOCITY)
	var ballistic := v * v / (2.0 * Balance.RUNNER_GRAVITY)
	var sampling := v * DELTA
	print("    launch %.1fpx/s, ballistic %.1fpx, sampling loss up to %.1fpx"
		% [v, ballistic, sampling])
	check(rise > ballistic - sampling and rise < ballistic * 1.5,
		"a full jump is the ballistic %.1fpx it should be (%.1f)" % [ballistic, rise])

	# The two climbs the plan's arena asks for. Body clearance is already in the
	# measurement: `rise` is how far the body's centre travelled, and the same
	# centre has to end up half a body above the shelf it lands on -- which is
	# what standing_on() means, and why the required climb is exactly the
	# difference between the two surface tops.
	var to_mid := ArenaStageData.MAIN_FLOOR_TOP - ArenaStageData.MID_SHELF_TOP
	var to_top := ArenaStageData.MID_SHELF_TOP - ArenaStageData.TOP_SHELF_TOP
	check(rise > to_mid,
		"the main floor reaches the mid shelf: needs %.0fpx, jump gives %.1fpx"
			% [to_mid, rise])
	check(rise > to_top,
		"and the mid shelf reaches the top shelf: needs %.0fpx, jump gives %.1fpx"
			% [to_top, rise])

	# Really climb it, on the real stage, rather than trusting the arithmetic.
	#
	# Started from BESIDE each shelf rather than under it, which the first
	# version of this check got wrong: a jump from x=-200 is a jump straight into
	# the mid shelf's underside, and it failed for the right reason. There is
	# only 100px of headroom under that shelf and a body is 46 tall, so the climb
	# has to happen off its edge. That is not a flaw in the arena -- it is what a
	# platform is -- but it does mean the route matters, so the route is stated.
	check(_can_climb(ArenaStageData.MAIN_FLOOR_TOP, -60.0,
			ArenaStageData.MID_SHELF_TOP, -1),
		"and a fighter actually lands on the mid shelf from the main floor")
	check(_can_climb(ArenaStageData.MID_SHELF_TOP, -130.0,
			ArenaStageData.TOP_SHELF_TOP, 1),
		"and on the top shelf from the mid shelf")

	# Stopping distance, against the closed form for the same deceleration. This
	# is the ground half of "現行 Runner との比較": the arena calls
	# Runner.ground_step, so a mismatch here would mean the arena had stopped
	# using it rather than that the two disagreed.
	var stop := _measure_stop()
	var top_speed := Balance.RUNNER_RUN_SPEED * Balance.RUNNER_SPRINT_MULTIPLIER
	var ideal := top_speed * top_speed / (2.0 * Balance.RUNNER_GROUND_DECEL)
	# One tick of travel is the most that discretising the deceleration can cost
	# or gain, so that is the tolerance rather than a percentage.
	var slack := top_speed * DELTA
	print("    stop from %.1fpx/s in %.1fpx (closed form %.1f, slack %.1f)"
		% [top_speed, stop, ideal, slack])
	check(absf(stop - ideal) <= slack,
		"stopping distance is the deceleration Balance asks for (%.1f vs %.1f)"
			% [stop, ideal])

## How far the body's centre rises on one held jump.
func _measure_rise(world: ArenaStage, from: Vector2, axis: float) -> float:
	var s := ArenaMotor.MotorState.new()
	ArenaMotor.reset_at(s, from, 1)
	# Settle, and pick up running speed if asked for.
	for i in range(60):
		ArenaMotor.step(s, ArenaMotor.MotorInput.new(axis, false, 0), world, DELTA)
	var start := s.position.y
	var best := start
	for i in range(140):
		ArenaMotor.step(s, ArenaMotor.MotorInput.new(axis, true, 1), world, DELTA)
		best = minf(best, s.position.y)
	return start - best

## Stand on `from_top` at `x`, jump, steer `towards` once clear of the target
## surface, and see whether the body ends up resting on `to_top`.
##
## The steering is deliberately closed-loop rather than a fixed input list: go
## straight up until the feet are above the shelf, then move sideways onto it.
## That is what a player does, and an open-loop sequence would be measuring
## whether the author guessed the right tick to turn at.
func _can_climb(from_top: float, x: float, to_top: float, towards: int) -> bool:
	var world := ArenaStage.from_data()
	var s := ArenaMotor.MotorState.new()
	ArenaMotor.reset_at(s, Vector2(x, ArenaStageData.standing_on(from_top)), 1)
	for i in range(20):
		ArenaMotor.step(s, ArenaMotor.MotorInput.new(0.0, false, 0), world, DELTA)
	var want := ArenaStageData.standing_on(to_top)
	for i in range(240):
		var feet := s.position.y + ArenaRules.BODY_SIZE.y * 0.5
		var axis := float(towards) if feet < to_top else 0.0
		ArenaMotor.step(s, ArenaMotor.MotorInput.new(axis, true, 1), world, DELTA)
		if s.grounded and absf(s.position.y - want) < 2.0:
			return true
	return false

## Distance covered between letting go of the stick at top speed and coming to
## rest.
##
## On its own long floor. The first version used the same 1200px test floor as
## the jump measurement, and three seconds at 410px/s ran off the end of it --
## so it measured a fighter falling, not a fighter stopping, and said 1159px.
func _measure_stop() -> float:
	var long_floor: Array[Rect2] = [Rect2(-4000.0, 100.0, 8000.0, 40.0)]
	var world := ArenaStage.new(long_floor)
	var s := ArenaMotor.MotorState.new()
	ArenaMotor.reset_at(s, Vector2(-2000.0, 100.0 - ArenaRules.BODY_SIZE.y * 0.5), 1)
	for i in range(180):
		ArenaMotor.step(s, ArenaMotor.MotorInput.new(1.0, false, 0), world, DELTA)
	var start := s.position.x
	for i in range(240):
		ArenaMotor.step(s, ArenaMotor.MotorInput.new(0.0, false, 0), world, DELTA)
		if absf(s.velocity.x) < 0.01:
			break
	return s.position.x - start
