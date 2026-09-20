class_name JumpMath
## The vertical shaping of a player jump, as state in and state out.
##
## Lifted verbatim out of Runner._normal_vertical_step() so the arena's fighters
## can have the same variable jump the cooperative runner has without inheriting
## the runner itself -- which carries HP, a single InputHub, global events and
## cooperative contact (docs/coin-battle-plan.md section 7.2).
##
## The branch order, the deltas, the minimum-time gate, the release latch and
## the apex budget are all as they were. That matters more than the tidiness of
## the result: this is the feel the game already has, and the arena is supposed
## to start from it rather than re-derive it. Any change here changes both modes
## at once, so movement/ground_movement/touch_feel are the check.
##
## What did NOT come along is the release SEQUENCE comparison. Deciding that a
## particular press has ended is input plumbing -- Runner does it by comparing
## InputHub.jump_release_sequence against the sequence it started with -- so the
## caller resolves that and passes a plain `held`.

## Everything Runner kept in fields for one jump. Explicit, so a prediction can
## save it, roll back and replay it (section 9.3).
class State:
	var active: bool = false
	var release_latched: bool = false
	var release_gravity_time: float = 0.0
	var apex_time_left: float = 0.0
	var apex_finished: bool = true
	var jump_time: float = 0.0

	func copy_from(other: State) -> void:
		active = other.active
		release_latched = other.release_latched
		release_gravity_time = other.release_gravity_time
		apex_time_left = other.apex_time_left
		apex_finished = other.apex_finished
		jump_time = other.jump_time

	func duplicate_state() -> State:
		var s := State.new()
		s.copy_from(self)
		return s

## Runner._begin_player_jump, minus the press sequence it remembers.
static func begin(s: State) -> void:
	s.active = true
	s.jump_time = 0.0
	s.release_latched = false
	s.release_gravity_time = 0.0
	s.apex_time_left = Balance.RUNNER_APEX_MAX_TIME
	s.apex_finished = false

## Runner._end_player_jump.
static func end(s: State) -> void:
	s.active = false
	s.release_latched = false
	s.release_gravity_time = 0.0
	s.apex_time_left = 0.0
	s.apex_finished = true
	s.jump_time = 0.0

## Runner._update_jump_release, with the sequence test already resolved.
static func update_release(s: State, held: bool) -> void:
	if not s.active:
		return
	if not held:
		s.release_latched = true
		s.apex_finished = true

## One tick of vertical motion. Returns the new vy.
##
## `held` is whether the press that STARTED this jump is still down; a new press
## after a release does not revive the jump, which is why Runner compares
## sequences rather than reading the button.
static func step(s: State, vy: float, held: bool, delta: float) -> float:
	update_release(s, held)

	# A release is irreversible for this jump. Before the minimum time expires we
	# keep ordinary rise gravity; after it, stronger gravity blends in smoothly.
	if s.active and s.release_latched and vy < 0.0:
		if s.jump_time < Balance.RUNNER_MIN_JUMP_TIME:
			return vy + Balance.RUNNER_GRAVITY * delta
		s.release_gravity_time += delta
		var blend := clampf(s.release_gravity_time \
			/ Balance.RUNNER_JUMP_RELEASE_BLEND_TIME, 0.0, 1.0)
		var release_gravity := Balance.RUNNER_GRAVITY * lerpf(
			1.0, Balance.RUNNER_JUMP_RELEASE_GRAVITY_RATIO, blend)
		# Do not turn excess release gravity into a downward impulse. The next
		# tick resumes ordinary fall gravity from zero.
		return minf(0.0, vy + release_gravity * delta)

	var base_gravity := Balance.RUNNER_GRAVITY if vy < 0.0 \
		else Balance.RUNNER_FALL_GRAVITY
	var gravity := base_gravity
	if s.active and not s.release_latched and held \
			and not s.apex_finished and s.apex_time_left > 0.0 \
			and absf(vy) < Balance.RUNNER_APEX_SPEED:
		var q := clampf(absf(vy) / Balance.RUNNER_APEX_SPEED, 0.0, 1.0)
		var smooth := q * q * (3.0 - 2.0 * q)
		var apex_gravity := Balance.RUNNER_GRAVITY * Balance.RUNNER_APEX_GRAVITY_RATIO
		gravity = lerpf(apex_gravity, base_gravity, smooth)
		s.apex_time_left = maxf(0.0, s.apex_time_left - delta)
		if s.apex_time_left <= 0.0:
			s.apex_finished = true

	var out := minf(vy + gravity * delta, Balance.RUNNER_TERMINAL_VELOCITY)
	if s.active and out >= Balance.RUNNER_APEX_SPEED:
		s.apex_finished = true
	return out

## Runner advances this in its own timer pass (runner.gd, `_jump_time += delta`
## while airborne), so the arena does the same rather than folding it into
## step() -- the order relative to the minimum-time gate is load-bearing.
static func advance_time(s: State, delta: float) -> void:
	if s.active:
		s.jump_time += delta
