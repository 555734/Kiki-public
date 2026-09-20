class_name ArenaMotor
## The arena's movement: run, variable jump, air steering, coyote, buffer.
##
## Nothing else. docs/coin-battle-plan.md 4.1 switches off the triple jump, wall
## kick, crouch, slide, pound, ledge hang, dash, warp and moving platforms for
## this mode -- not because they are bad but because seven coins is the thing
## being tested, and every extra verb is another variable in that answer.
##
## The ground maths is not reimplemented. Runner.ground_input/ground_target/
## ground_step are already static and already pure, so they are called directly
## and the arena gets the acceleration curve, the weak-input curve and the turn
## speed the game was tuned to. The jump goes through JumpMath, which is the
## same code the cooperative runner uses.
##
## Everything that persists between ticks lives in MotorState. That is what
## makes `step()` re-runnable: a client can save the state at the tick a
## snapshot describes, replay its own inputs on top and arrive where the host
## did (9.3). None of it may be recovered from a node -- particularly not
## `is_on_floor()`, which is a cache of the last move rather than a fact about
## a position.

class MotorState:
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var facing: int = 1
	var grounded: bool = false
	var coyote: float = 0.0
	var jump_buffer: float = 0.0
	var jump := JumpMath.State.new()
	## The press this jump belongs to, so a release that arrives late cannot
	## end a jump that a newer press already started.
	##
	## Starts at 0, the same value a controller that has never been touched
	## reports, so "no presses yet" is not read as a press. It started at -1 and
	## the motion probe caught what that costs: every fighter jumped on the first
	## tick of every match, because seq 0 was greater than -1. A respawn
	## deliberately does NOT reset this -- a press made before a death must not
	## fire on the new life.
	var jump_press_seq: int = 0
	var prev_jump_held: bool = false

	func copy_from(o: MotorState) -> void:
		position = o.position
		velocity = o.velocity
		facing = o.facing
		grounded = o.grounded
		coyote = o.coyote
		jump_buffer = o.jump_buffer
		jump.copy_from(o.jump)
		jump_press_seq = o.jump_press_seq
		prev_jump_held = o.prev_jump_held

	func duplicate_state() -> MotorState:
		var s := MotorState.new()
		s.copy_from(self)
		return s

## One tick of input. `jump_press_seq` counts presses rather than reporting a
## level, so a press that is already released by the time it arrives is still a
## short hop instead of being lost (9.3).
class MotorInput:
	var axis: float = 0.0
	var jump_held: bool = false
	var jump_press_seq: int = 0

	func _init(a: float = 0.0, held: bool = false, seq: int = 0) -> void:
		axis = a
		jump_held = held
		jump_press_seq = seq

## Advance one fixed tick. Pure in everything but `s`, which it writes.
##
## `frozen` is hitstun: the fighter keeps falling and keeps draining sideways
## but cannot steer, jump or turn (4.2).
static func step(s: MotorState, input: MotorInput, world: ArenaStage,
		delta: float, frozen: bool = false) -> void:
	var axis: float = 0.0 if frozen else clampf(input.axis, -1.0, 1.0)

	# Runner advances this in _tick_timers, which runs at the TOP of its
	# _physics_process -- before _read_input can start a jump and long before
	# _normal_vertical_step reads it (runner.gd:103, 288, 468). So the tick a
	# jump begins on sees jump_time == 0, and doing it further down would give
	# the arena one delta more than the cooperative runner on that tick. That is
	# only one frame, and it is exactly one frame of the minimum-jump-time gate:
	# it decides whether the shortest possible tap is a hop or a full rise.
	JumpMath.advance_time(s.jump, delta)

	# --- jump bookkeeping ---------------------------------------------------
	var new_press := input.jump_press_seq > s.jump_press_seq
	if new_press and not frozen:
		s.jump_buffer = ArenaRules.jump_buffer_time()
	if new_press:
		# Consumed either way. A press that arrived during hitstun must not
		# fire the moment the stun ends (4.2).
		s.jump_press_seq = input.jump_press_seq

	# Is the press that started the current jump still down? A new press cannot
	# revive a jump that was already released.
	var held_for_jump := input.jump_held and not frozen

	if not frozen and s.jump_buffer > 0.0 and (s.grounded or s.coyote > 0.0):
		s.velocity.y = ArenaRules.jump_velocity()
		s.jump_buffer = 0.0
		s.coyote = 0.0
		s.grounded = false
		JumpMath.begin(s.jump)
		held_for_jump = true

	# --- horizontal ---------------------------------------------------------
	if frozen:
		s.velocity.x = move_toward(s.velocity.x, 0.0, ArenaRules.HITSTUN_DRAG * delta)
	elif s.grounded:
		s.velocity.x = Runner.ground_step(
			s.velocity.x, axis, ArenaRules.ALWAYS_SPRINT, delta)
	else:
		s.velocity.x = _air_step(s.velocity.x, axis, delta)

	if not frozen and absf(axis) > 0.01:
		s.facing = 1 if axis > 0.0 else -1

	# --- vertical -----------------------------------------------------------
	s.velocity.y = JumpMath.step(s.jump, s.velocity.y, held_for_jump, delta)

	# --- move ---------------------------------------------------------------
	var result := world.sweep(s.position, ArenaRules.BODY_SIZE, s.velocity * delta)
	s.position = result["position"]
	var was_grounded := s.grounded
	s.grounded = bool(result["grounded"])

	if bool(result["hit_wall"]):
		s.velocity.x = 0.0
	if bool(result["hit_ceiling"]):
		s.velocity.y = 0.0
		JumpMath.end(s.jump)
	if s.grounded:
		s.velocity.y = 0.0
		s.coyote = ArenaRules.coyote_time()
		JumpMath.end(s.jump)
	else:
		if was_grounded:
			s.coyote = ArenaRules.coyote_time()
		s.coyote = maxf(0.0, s.coyote - delta)

	s.jump_buffer = maxf(0.0, s.jump_buffer - delta)
	s.prev_jump_held = input.jump_held

## Air steering. Runner does this against its chain and launch momentum rules;
## the arena has neither, so this is the plain version: accelerate towards the
## same top speed, with the air constants.
static func _air_step(vx: float, axis: float, delta: float) -> float:
	var shaped := Runner.ground_input(axis)
	var target := Runner.ground_target(axis, ArenaRules.ALWAYS_SPRINT)
	if target == 0.0:
		return move_toward(vx, 0.0, Balance.AIR_MOMENTUM_DRAG * delta)
	var turning := (vx > 0.0 and target < 0.0) or (vx < 0.0 and target > 0.0)
	var rate := Balance.RUNNER_AIR_TURN if turning else Balance.RUNNER_AIR_ACCEL
	return move_toward(vx, target, rate * absf(shaped) * delta)

## Put a fighter somewhere with nothing left over from before: no buffered
## jump, no coyote, no half-finished apex (5).
static func reset_at(s: MotorState, at: Vector2, facing: int) -> void:
	s.position = at
	s.velocity = Vector2.ZERO
	s.facing = facing
	s.grounded = false
	s.coyote = 0.0
	s.jump_buffer = 0.0
	s.prev_jump_held = false
	JumpMath.end(s.jump)

## The body box, for overlap tests and for drawing.
static func body_rect(s: MotorState) -> Rect2:
	return Rect2(s.position - ArenaRules.BODY_SIZE * 0.5, ArenaRules.BODY_SIZE)
