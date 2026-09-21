class_name Runner
extends CharacterBody2D
## Player 1. Variable, speed-sensitive jumps with continuous air steering.
## Consecutive timed landings and walls extend the player's movement.
## The guardian creates routes and rescues; normal movement is never disabled
## to force cooperation. Tuning values are our own, not an exact Mario replica.

## Eight states, and eight is the ceiling: the snapshot packs this into three
## bits (Snapshot.encode). A ninth needs a wider field on the wire.
enum State { IDLE, RUN, JUMP, FALL, DASH, HURT, DEAD, HANG }

const LAYER_TERRAIN := 1
const LAYER_RUNNER := 2
const LAYER_HOLOGRAM := 8

signal state_changed(state: State)

var state: State = State.IDLE
var facing: int = 1
var hp: int = Balance.RUNNER_MAX_HP

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _buffer_press_release_sequence: int = 0
var _jump_time: float = 0.0
var _player_jump_active: bool = false
var _jump_release_latched: bool = false
var _jump_release_gravity_time: float = 0.0
var _apex_time_left: float = 0.0
var _apex_finished: bool = true
var _jump_press_release_sequence: int = 0
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _air_dashes: int = 0
var _invuln: float = 0.0
var _impact_speed: float = 0.0
var _hurt_timer: float = 0.0
var _was_on_floor: bool = false
var _airborne_time: float = 0.0
var _jump_chain: int = 0
var _chain_window: float = 0.0
var _chain_direction: int = 0
var _chain_flight: bool = false
var _wall_kick_lock: float = 0.0
var _wall_kick_visual: float = 0.0
var _crouched: bool = false
var _pound_phase: int = 0  # 0 normal, 1 wind-up, 2 falling
var _pound_timer: float = 0.0
var _down_was_held: bool = false
var _wall_sliding: bool = false
## Set by bounce() and launch(): something other than the runner's legs owns the
## next take-off, so a jump press cannot be stored and spent on top of it.
## Cleared by the first move that uses the external velocity.
var _external_takeoff_pending: bool = false
var _body_shape: CollisionShape2D = null
var _hurt_shape: CollisionShape2D = null
## Set while the runner is standing on a guardian hologram, so a rescue can be
## counted exactly once per landing.
var _hologram_credit: Node2D = null

var input_hub: InputHub = null
var visual: Node2D = null

@onready var _hurtbox: Area2D = Area2D.new()

func _ready() -> void:
	collision_layer = LAYER_RUNNER
	# Barricades are terrain as far as the runner is concerned -- they can be
	# hopped and stood on -- but they are NOT on the terrain layer, because a
	# walking Keeper has to step over one. See Barricade and Balance.LAYER_BARRICADE.
	collision_mask = LAYER_TERRAIN | LAYER_HOLOGRAM | Balance.LAYER_BARRICADE
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(50.0)

	var shape := CollisionShape2D.new()
	_body_shape = shape
	var rect := RectangleShape2D.new()
	rect.size = Balance.RUNNER_SIZE
	shape.shape = rect
	add_child(shape)

	# Contact damage and hazards come in through an Area2D rather than the body
	# mask, so enemies never physically push the runner around.
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = 4 | 16 | 32   # enemy | projectile | hazard
	var hurt_shape := CollisionShape2D.new()
	_hurt_shape = hurt_shape
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = Balance.RUNNER_SIZE - Vector2(4, 4)
	hurt_shape.shape = hurt_rect
	_hurtbox.add_child(hurt_shape)
	add_child(_hurtbox)

	visual = preload("res://src/runner/runner_visual.gd").new()
	visual.runner = self
	add_child(visual)

	Events.runner_spawned.emit(self)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_tick_timers(delta)
	_read_input(delta)
	_update_stance()
	_wall_sliding = false
	if _pound_phase > 0:
		_process_pound(delta)
	else:
		_process_motion(delta)

	var was_airborne := not is_on_floor()
	var fell_at := velocity.y
	_impact_speed = fell_at
	# The external take-off is spent by the move that carries it. Anything the
	# landing or contact resolution below throws sets a fresh one for next tick.
	_external_takeoff_pending = false
	move_and_slide()
	if is_on_ceiling():
		_end_player_jump()
	if was_airborne and is_on_floor():
		_end_player_jump()
		_pound_phase = 0
		if _chain_flight:
			_chain_window = Balance.RUNNER_CHAIN_WINDOW
			_chain_flight = false
		else:
			_reset_jump_chain()
		Events.runner_landed.emit(fell_at > Balance.RUNNER_TERMINAL_VELOCITY * 0.55)
	_hug_the_ground()
	# Floor snap can establish the floor after move_and_slide without going
	# through the landing branch above. Do not let vy=0 be mistaken for an apex.
	if was_airborne and is_on_floor() and velocity.y >= 0.0:
		_end_player_jump()
	grounded = is_on_floor()
	_settle_normal_state()
	_after_move(was_airborne)
	_resolve_contacts()

func _process_motion(delta: float) -> void:
	match state:
		State.DASH:
			_process_dash(delta)
		State.HURT:
			_process_hurt(delta)
		State.HANG:
			_process_hang(delta)
		_:
			_process_normal(delta)

## How far below the soles to look for a floor the runner should be resting on.
const GROUND_GRAB: float = 8.0
const GROUND_GRAB_WINDOW: float = 0.20
var _left_floor_at: float = -999.0

func _hug_the_ground() -> void:
	if is_on_floor():
		_left_floor_at = Clock.seconds()
		return
	if velocity.y < 0.0 or state == State.DASH or state == State.DEAD:
		return
	if Clock.seconds() - _left_floor_at > GROUND_GRAB_WINDOW:
		return
	apply_floor_snap()

# ------------------------------------------------------------- walls
var _wall_coyote: float = 0.0
var _wall_normal: float = 0.0
var _wall_slide_time: float = 0.0
var _wall_jump_ready: bool = false
const WALL_PROBE_DISTANCE: float = 8.0

func _probe_wall_normal() -> float:
	# move_and_slide only reports a wall after collision resolution. For a
	# platformer input this is one frame too late, especially on touch screens.
	# Probe a few pixels in the intended direction so a buffered jump at the wall
	# is consumed as a wall kick instead of a normal falling frame.
	var axis := _move_axis()
	var first := signf(axis) if absf(axis) > 0.05 else float(facing)
	if first == 0.0:
		first = 1.0
	for direction in [first, -first]:
		if test_move(global_transform, Vector2(direction * WALL_PROBE_DISTANCE, 0.0)):
			return -direction
	return 0.0

func _track_wall(delta: float) -> void:
	_wall_coyote = maxf(0.0, _wall_coyote - delta)
	if is_on_floor():
		_wall_coyote = 0.0
		_wall_jump_ready = false
		return
	if _wall_kick_lock > 0.0:
		_wall_coyote = 0.0
		_wall_jump_ready = false
		return
	var normal := _probe_wall_normal()
	if normal == 0.0 and _kickable_wall() != null:
		normal = signf(get_wall_normal().x)
	if normal != 0.0:
		_wall_normal = normal
		_wall_coyote = Balance.WALL_COYOTE_TIME
		_wall_jump_ready = true
	elif _wall_coyote <= 0.0:
		_wall_jump_ready = false

func _kickable_wall() -> Node2D:
	if not is_on_wall():
		return null
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if absf(hit.get_normal().x) < 0.9:
			continue
		var collider := hit.get_collider()
		if collider is Hologram:
			if collider.kind == Hologram.Kind.WALL:
				return collider
		elif collider is PhysicsBody2D and (collider.collision_layer & LAYER_TERRAIN) != 0:
			return collider
	return null

func can_wall_jump() -> bool:
	return _wall_jump_ready and _wall_coyote > 0.0 \
		and _wall_kick_lock <= 0.0 and not is_on_floor()

# ------------------------------------------------------- player jump shaping
func _begin_player_jump(press_sequence: int) -> void:
	_player_jump_active = true
	_jump_time = 0.0
	_jump_release_latched = false
	_jump_release_gravity_time = 0.0
	_apex_time_left = Balance.RUNNER_APEX_MAX_TIME
	_apex_finished = false
	_jump_press_release_sequence = press_sequence
	_update_jump_release()

func _end_player_jump() -> void:
	_player_jump_active = false
	_jump_release_latched = false
	_jump_release_gravity_time = 0.0
	_apex_time_left = 0.0
	_apex_finished = true
	_jump_time = 0.0

## Narrow public seam for host-side delayed rescue. It deliberately does not
## clear jump buffering, chain state, horizontal velocity or any network state.
func end_player_jump_control() -> void:
	_end_player_jump()

func _update_jump_release() -> void:
	if not _player_jump_active or input_hub == null:
		return
	if input_hub.jump_release_sequence != _jump_press_release_sequence \
			or not input_hub.jump_held:
		_jump_release_latched = true
		_apex_finished = true

func _normal_vertical_step(delta: float) -> void:
	_update_jump_release()

	# A release is irreversible for this jump. Before the minimum time expires we
	# keep ordinary rise gravity; after it, stronger gravity blends in smoothly.
	if _player_jump_active and _jump_release_latched and velocity.y < 0.0:
		if _jump_time < Balance.RUNNER_MIN_JUMP_TIME:
			velocity.y += Balance.RUNNER_GRAVITY * delta
			return
		_jump_release_gravity_time += delta
		var blend := clampf(_jump_release_gravity_time \
			/ Balance.RUNNER_JUMP_RELEASE_BLEND_TIME, 0.0, 1.0)
		var gravity := Balance.RUNNER_GRAVITY * lerpf(
			1.0, Balance.RUNNER_JUMP_RELEASE_GRAVITY_RATIO, blend)
		# Do not turn excess release gravity into a downward impulse. The next
		# tick resumes ordinary fall gravity from zero.
		velocity.y = minf(0.0, velocity.y + gravity * delta)
		return

	var base_gravity := Balance.RUNNER_GRAVITY if velocity.y < 0.0 \
		else Balance.RUNNER_FALL_GRAVITY
	var gravity := base_gravity
	if _player_jump_active and not _jump_release_latched and _jump_held() \
			and not _apex_finished and _apex_time_left > 0.0 \
			and absf(velocity.y) < Balance.RUNNER_APEX_SPEED:
		var q := clampf(absf(velocity.y) / Balance.RUNNER_APEX_SPEED, 0.0, 1.0)
		var smooth := q * q * (3.0 - 2.0 * q)
		var apex_gravity := Balance.RUNNER_GRAVITY * Balance.RUNNER_APEX_GRAVITY_RATIO
		gravity = lerpf(apex_gravity, base_gravity, smooth)
		_apex_time_left = maxf(0.0, _apex_time_left - delta)
		if _apex_time_left <= 0.0:
			_apex_finished = true

	velocity.y = minf(velocity.y + gravity * delta, Balance.RUNNER_TERMINAL_VELOCITY)
	if _player_jump_active and velocity.y >= Balance.RUNNER_APEX_SPEED:
		_apex_finished = true

func _tick_timers(delta: float) -> void:
	_wall_kick_lock = maxf(0.0, _wall_kick_lock - delta)
	_wall_kick_visual = maxf(0.0, _wall_kick_visual - delta)
	_chain_window = maxf(0.0, _chain_window - delta)
	if is_on_floor() and not _chain_flight and _chain_window <= 0.0:
		_reset_jump_chain()
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if is_on_floor():
		# is_on_floor() is from the prior move, so the floor a launch is leaving
		# would otherwise hand the player a fresh coyote window to jump from on
		# top of it. An external take-off owns this frame.
		_coyote = 0.0 if _external_takeoff_pending else Balance.RUNNER_COYOTE_TIME
		_air_dashes = Balance.RUNNER_AIR_DASHES
		_airborne_time = 0.0
		# Do not erase launch momentum on the same tick a launch starts upward.
		if velocity.y >= 0.0:
			_launched = false
	else:
		_coyote = 0.0 if _external_takeoff_pending else maxf(0.0, _coyote - delta)
		_airborne_time += delta
	if _player_jump_active:
		_jump_time += delta

## Hand the next take-off to whatever threw the runner. The press edge sitting
## unconsumed in the hub is thrown away here, because clearing Runner's own
## buffer is not enough: the next _read_input would simply take it again and
## turn a spring into a spring plus a jump.
func _begin_external_takeoff() -> void:
	_external_takeoff_pending = true
	if input_hub != null:
		input_hub.take_jump()

## Launched by something other than the player -- currently the bounce pads.
func bounce(speed: float) -> void:
	_end_player_jump()
	_pound_phase = 0
	_reset_jump_chain()
	velocity.y = -absf(speed)
	_coyote = 0.0
	_jump_buffer = 0.0
	_begin_external_takeoff()

func _read_input(_delta: float) -> void:
	if input_hub == null:
		return
	# Always take the edge, so an unconsumed press cannot come back next tick.
	var pressed := input_hub.take_jump()
	if _external_takeoff_pending:
		# A bounce or a launch owns this take-off. The press is spent here
		# rather than stored: holding the button through a spring must not turn
		# into a jump on top of it, and neither must a press that arrives in the
		# same frame. Later air control and wall kicks are unaffected.
		_jump_buffer = 0.0
	elif pressed:
		_jump_buffer = Balance.RUNNER_JUMP_BUFFER
		_buffer_press_release_sequence = input_hub.jump_press_release_sequence
	_update_jump_release()
	# Sprint is the same held modifier on the ground and in the air.
	input_hub.take_dash()
	var down := input_hub.move_axis_y > 0.55
	if down and not _down_was_held and not is_on_floor() and _pound_phase == 0 \
			and state in [State.JUMP, State.FALL] and not _crouched:
		_pound_phase = 1
		_pound_timer = Balance.RUNNER_POUND_WINDUP
		_jump_buffer = 0.0
		_end_player_jump()
		_reset_jump_chain()
	_down_was_held = down

func _move_axis() -> float:
	return input_hub.move_axis if input_hub != null else 0.0

func _jump_held() -> bool:
	return input_hub.jump_held if input_hub != null else false

## Sprint remains available in the air, including after braking or reversing.
func is_sprinting() -> bool:
	if input_hub == null or state == State.HURT or state == State.DEAD:
		return false
	if absf(_move_axis()) <= 0.1:
		return false
	return input_hub.dash_held or Options.auto_dash()

## Explicit launches still carry their earned excess speed.
var _launched: bool = false

func _coasting(axis: float) -> bool:
	if is_on_floor():
		return false
	var limit := Balance.RUNNER_RUN_SPEED * Balance.RUNNER_SPRINT_MULTIPLIER
	if absf(velocity.x) <= limit:
		return false
	return axis * velocity.x >= 0.0

func _push_rate(axis: float) -> float:
	var against := axis * velocity.x < 0.0 and absf(velocity.x) > 1.0
	if is_on_floor():
		if against:
			return Balance.RUNNER_TURN_BRAKE
		if is_sprinting() or absf(velocity.x) > Balance.RUNNER_RUN_SPEED:
			return Balance.RUNNER_SPRINT_ACCEL
		return Balance.RUNNER_ACCEL
	if _coasting(axis):
		return Balance.AIR_MOMENTUM_DRAG
	return Balance.RUNNER_AIR_TURN if against else Balance.RUNNER_AIR_ACCEL

func _let_go_rate() -> float:
	if _coasting(0.0):
		return Balance.AIR_MOMENTUM_DRAG
	return Balance.RUNNER_FRICTION if is_on_floor() else Balance.RUNNER_AIR_RELEASE_BRAKE

# ------------------------------------------------------------ running on foot
#
# The ground has its own reading of the stick and its own speed update. Both are
# pure functions of the axis and the current speed: there is no acceleration
# history, no extra state and nothing to reset at a take-off or a landing, which
# is what keeps the jump physics above untouched.

## The ground's reading of the stick. Past the deadzone the input is
## re-normalised, so speed starts climbing from zero the moment the lean is real
## rather than jumping to whatever the nearest cap was, and it is bent halfway
## towards its square, which is what buys the slow end of the range a usable
## amount of travel. The air keeps the raw axis.
static func ground_input(axis: float) -> float:
	var a := clampf(axis, -1.0, 1.0)
	var span := 1.0 - Balance.RUNNER_GROUND_INPUT_DEADZONE
	var u := clampf((absf(a) - Balance.RUNNER_GROUND_INPUT_DEADZONE) / span, 0.0, 1.0)
	return signf(a) * lerpf(u, u * u, Balance.RUNNER_GROUND_INPUT_CURVE)

## What the stick is asking for on the ground. Sprint moves this ceiling and
## nothing else -- it is not a second acceleration, and it no longer needs the
## axis past a threshold before it counts.
static func ground_target(axis: float, sprint: bool) -> float:
	var top := Balance.RUNNER_RUN_SPEED
	if sprint:
		top *= Balance.RUNNER_SPRINT_MULTIPLIER
	return ground_input(axis) * top

## One tick of ordinary running. Pushing, easing off and turning round are three
## separate answers, and a reversal spends only the part of the frame it needs
## to reach zero before the rest of it accelerates the other way -- so the hard
## brake never carries on into the new direction.
static func ground_step(vx: float, axis: float, sprint: bool, delta: float) -> float:
	var target := ground_target(axis, sprint)
	if target == 0.0:
		return move_toward(vx, 0.0, Balance.RUNNER_GROUND_DECEL * delta)
	if vx * target < 0.0:
		var to_zero := absf(vx) / Balance.RUNNER_GROUND_REVERSE_DECEL
		if to_zero >= delta:
			return move_toward(vx, 0.0, Balance.RUNNER_GROUND_REVERSE_DECEL * delta)
		return move_toward(0.0, target,
			Balance.RUNNER_GROUND_ACCEL_START * (delta - to_zero))
	# Asking for less than the current speed is a brake, not a weaker push.
	if absf(target) < absf(vx):
		return move_toward(vx, target, Balance.RUNNER_GROUND_DECEL * delta)
	var q := clampf(absf(vx) / Balance.RUNNER_GROUND_ACCEL_BLEND_SPEED, 0.0, 1.0)
	var smooth := q * q * (3.0 - 2.0 * q)
	var accel := lerpf(Balance.RUNNER_GROUND_ACCEL_START,
		Balance.RUNNER_GROUND_ACCEL_CRUISE, smooth)
	return move_toward(vx, target, accel * delta)

## Sprint as the ground asks the question: a held modifier on the cap. The air's
## is_sprinting() keeps its own axis threshold, because up there the axis is
## also the steering.
func ground_sprint_requested() -> bool:
	if input_hub == null:
		return false
	return input_hub.dash_held or Options.auto_dash()

## Ordinary running only. Crouch slides, wall kicks and the first frame of an
## external launch keep their own rates.
func _runs_on_foot() -> bool:
	return is_on_floor() and not _crouched and _wall_kick_lock <= 0.0 \
		and not _external_takeoff_pending

func _process_normal(delta: float) -> void:
	var axis := _move_axis()
	if axis * float(_chain_direction) < -0.1:
		_reset_jump_chain()
	if absf(axis) > 0.1 and _wall_kick_lock <= 0.0:
		facing = signi(int(signf(axis)))

	var top_speed := Balance.RUNNER_RUN_SPEED
	if is_sprinting():
		top_speed *= Balance.RUNNER_SPRINT_MULTIPLIER
	var target := axis * top_speed
	if _crouched and is_on_floor():
		var rate := Balance.RUNNER_TURN_BRAKE if axis * velocity.x < 0.0 \
			else Balance.RUNNER_SLIDE_FRICTION
		velocity.x = move_toward(velocity.x, axis * Balance.RUNNER_CROUCH_SPEED, rate * delta)
		velocity.x += get_floor_normal().x * Balance.RUNNER_SLOPE_ACCEL * delta
		velocity.x = clampf(velocity.x, -Balance.RUNNER_SLIDE_MAX_SPEED, Balance.RUNNER_SLIDE_MAX_SPEED)
	elif _wall_kick_lock > 0.0:
		pass  # Brief outward kick; vertical control and jump release still work.
	elif _runs_on_foot():
		velocity.x = ground_step(velocity.x, axis, ground_sprint_requested(), delta)
	elif absf(axis) > 0.05:
		velocity.x = move_toward(velocity.x, target, _push_rate(axis) * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, _let_go_rate() * delta)

	_normal_vertical_step(delta)

	_track_wall(delta)
	var touching_wall := _wall_jump_ready
	if touching_wall:
		if axis * _wall_normal < -0.1 and velocity.y > 0.0:
			_wall_sliding = true
			velocity.y = minf(velocity.y, Balance.WALL_SLIDE_SPEED)
			_end_player_jump()
	if _try_to_catch_the_edge():
		return

	# Wall jump gets priority over coyote jump while in contact.
	if _jump_buffer > 0.0 and can_wall_jump() \
			and not _external_takeoff_pending:
		var press_sequence := _buffer_press_release_sequence
		velocity = Vector2(_wall_normal * Balance.WALL_JUMP_OUT, Balance.WALL_JUMP_UP)
		facing = signi(int(_wall_normal))
		_launched = false
		_wall_kick_lock = Balance.WALL_KICK_LOCK
		_wall_kick_visual = Balance.WALL_KICK_VISUAL_TIME
		_reset_jump_chain()
		_wall_coyote = 0.0
		_wall_jump_ready = false
		_jump_buffer = 0.0
		_begin_player_jump(press_sequence)
		Events.runner_wall_jumped.emit(global_position, int(_wall_normal))
		Events.runner_jumped.emit()
		_set_state_from_motion()
		return

	if _jump_buffer > 0.0 and _coyote > 0.0 and not _external_takeoff_pending:
		var press_sequence := _buffer_press_release_sequence
		_start_ground_jump()
		_jump_buffer = 0.0
		_coyote = 0.0
		_begin_player_jump(press_sequence)
		Events.runner_jumped.emit()

	_set_state_from_motion()

## Crouching changes both the solid body and hurtbox, anchored at the feet.
func _set_crouched(value: bool) -> void:
	_crouched = value
	if _body_shape == null or _hurt_shape == null:
		return
	var height := Balance.RUNNER_CROUCH_HEIGHT if value else Balance.RUNNER_SIZE.y
	var offset := (Balance.RUNNER_SIZE.y - height) * 0.5
	(_body_shape.shape as RectangleShape2D).size = Vector2(Balance.RUNNER_SIZE.x, height)
	_body_shape.position.y = offset
	(_hurt_shape.shape as RectangleShape2D).size = Vector2(Balance.RUNNER_SIZE.x - 4.0, height - 4.0)
	_hurt_shape.position.y = offset

func _can_stand() -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Balance.RUNNER_SIZE - Vector2(0.2, 0.4)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.0
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _update_stance() -> void:
	if state in [State.DEAD, State.HURT, State.HANG] or _pound_phase > 0:
		return
	var down := input_hub != null and input_hub.move_axis_y > 0.55
	var want := down and (is_on_floor() or _crouched)
	if want and not _crouched:
		_set_crouched(true)
	elif not want and _crouched and _can_stand():
		_set_crouched(false)

func _process_pound(delta: float) -> void:
	if _pound_phase == 1:
		# A fresh jump during preparation cancels without inventing another jump.
		if _jump_buffer > 0.0:
			_jump_buffer = 0.0
			_pound_phase = 0
			_process_normal(delta)
			return
		_pound_timer -= delta
		velocity = Vector2(move_toward(velocity.x, 0.0, Balance.RUNNER_TURN_BRAKE * delta), 0.0)
		if _pound_timer <= 0.0:
			_pound_phase = 2
	else:
		velocity.x = move_toward(velocity.x, _move_axis() * Balance.RUNNER_POUND_STEER_SPEED,
			Balance.RUNNER_POUND_STEER_ACCEL * delta)
		velocity.y = Balance.RUNNER_POUND_SPEED
	_set_state(State.FALL)

func crouching() -> bool:
	return _crouched

func pounding() -> bool:
	return _pound_phase > 0

func movement_flags() -> int:
	return (1 if _crouched else 0) | (_pound_phase << 1) \
		| (8 if _wall_sliding else 0) | (16 if _wall_kick_visual > 0.0 else 0)

## The guardian is a puppet: use the host's stance rather than local inputs.
func apply_movement_flags(flags: int) -> void:
	_set_crouched((flags & 1) != 0)
	_pound_phase = clampi((flags >> 1) & 3, 0, 2)
	_wall_sliding = (flags & 8) != 0
	_wall_kick_visual = Balance.WALL_KICK_VISUAL_TIME if (flags & 16) != 0 else 0.0

func wall_kicking() -> bool:
	return _wall_kick_visual > 0.0

## Speed bonus is sampled once, at take-off. Mid-air sprint never boosts Y.
static func ground_jump_height(horizontal_speed: float, chain: int = 1) -> float:
	var walk := Balance.RUNNER_RUN_SPEED
	var sprint := walk * Balance.RUNNER_SPRINT_MULTIPLIER
	var run_up := clampf((absf(horizontal_speed) - walk) / (sprint - walk), 0.0, 1.0)
	var height := Balance.RUNNER_JUMP_HEIGHT * (1.0 + run_up * Balance.RUNNER_SPRINT_JUMP_BONUS)
	if chain == 2:
		height *= Balance.RUNNER_DOUBLE_HEIGHT
	elif chain == 3:
		height *= Balance.RUNNER_TRIPLE_HEIGHT
	return height

func _start_ground_jump() -> void:
	var direction := signi(int(signf(velocity.x)))
	var running := ground_sprint_requested() \
		and absf(velocity.x) >= Balance.RUNNER_CHAIN_MIN_SPEED \
		and _move_axis() * velocity.x > 0.0
	if running and _chain_window > 0.0 and direction == _chain_direction:
		_jump_chain = _jump_chain + 1 if _jump_chain < 3 else 1
	else:
		_jump_chain = 1
	_chain_direction = direction
	_chain_window = 0.0
	_chain_flight = running
	velocity.y = -sqrt(2.0 * Balance.RUNNER_GRAVITY * ground_jump_height(velocity.x, _jump_chain))
	if direction != 0 and _jump_chain == 2:
		velocity.x = float(direction) * minf(
			absf(velocity.x) * Balance.RUNNER_DOUBLE_FORWARD_BOOST,
			Balance.RUNNER_RUN_SPEED * Balance.RUNNER_SPRINT_MULTIPLIER * 1.05)
	elif direction != 0 and _jump_chain == 3:
		velocity.x = float(direction) * minf(
			absf(velocity.x) * Balance.RUNNER_TRIPLE_FORWARD_BOOST,
			Balance.RUNNER_RUN_SPEED * Balance.RUNNER_SPRINT_MULTIPLIER * 1.12)

func _reset_jump_chain() -> void:
	_jump_chain = 0
	_chain_window = 0.0
	_chain_direction = 0
	_chain_flight = false

func jump_chain() -> int:
	return _jump_chain

# ------------------------------------------------------------------ the edge
var _hang_left: float = 0.0
var _last_ledge: int = 0

func _try_to_catch_the_edge() -> bool:
	if is_on_floor():
		_last_ledge = 0
		return false
	if state == State.DASH:
		return false
	if velocity.y < Balance.LEDGE_MIN_FALL_SPEED:
		return false
	var edge := _edge_ahead()
	if edge.is_empty():
		return false
	if int(edge["id"]) == _last_ledge:
		return false
	_last_ledge = int(edge["id"])
	_end_player_jump()
	_reset_jump_chain()
	_hang_left = Balance.LEDGE_HANG_TIME
	velocity = Vector2.ZERO
	global_position.y = float(edge["top"]) + Balance.RUNNER_SIZE.y * 0.5 \
		- Balance.LEDGE_HAND_HEIGHT
	_set_state(State.HANG)
	Events.runner_grabbed_ledge.emit(global_position)
	return true

func _edge_ahead() -> Dictionary:
	var space := get_world_2d().direct_space_state
	var hand := global_position \
		+ Vector2(0.0, -Balance.RUNNER_SIZE.y * 0.5 + Balance.LEDGE_HAND_HEIGHT)
	var reach := Vector2(float(facing) * Balance.LEDGE_REACH, 0.0)

	var at_hand := PhysicsRayQueryParameters2D.create(hand, hand + reach)
	at_hand.collision_mask = LAYER_TERRAIN
	at_hand.exclude = [get_rid()]
	var solid := space.intersect_ray(at_hand)
	if solid.is_empty():
		return {}

	var above := hand - Vector2(0.0, Balance.LEDGE_HEAD_ROOM)
	var over := PhysicsRayQueryParameters2D.create(above, above + reach)
	over.collision_mask = LAYER_TERRAIN
	over.exclude = [get_rid()]
	if not space.intersect_ray(over).is_empty():
		return {}

	var probe_from := Vector2(float(solid["position"].x) + float(facing) * 4.0,
		above.y)
	var down := PhysicsRayQueryParameters2D.create(probe_from,
		probe_from + Vector2(0.0, Balance.LEDGE_HEAD_ROOM + Balance.LEDGE_REACH))
	down.collision_mask = LAYER_TERRAIN
	down.exclude = [get_rid()]
	var lip := space.intersect_ray(down)
	if lip.is_empty():
		return {}
	return {
		"id": int(solid["collider_id"]) ^ int(float(lip["position"].y) * 4.0),
		"top": float(lip["position"].y),
	}

func _process_hang(delta: float) -> void:
	velocity = Vector2.ZERO
	_hang_left -= delta
	if _hang_left <= 0.0:
		_let_go()
		return
	if _jump_buffer > 0.0:
		var press_sequence := _buffer_press_release_sequence
		_jump_buffer = 0.0
		velocity = Vector2(float(facing) * Balance.RUNNER_RUN_SPEED * 0.55,
			Balance.RUNNER_JUMP_VELOCITY)
		_begin_player_jump(press_sequence)
		_set_state(State.JUMP)
		Events.runner_jumped.emit()
		return
	if input_hub != null and input_hub.move_axis_y > 0.35:
		_let_go()

func _let_go() -> void:
	_end_player_jump()
	_hang_left = 0.0
	velocity = Vector2(0.0, 40.0)
	_set_state(State.FALL)
	Events.runner_let_go.emit(global_position)

func hanging() -> bool:
	return state == State.HANG

func grip_left() -> float:
	if state != State.HANG:
		return 0.0
	return clampf(_hang_left / Balance.LEDGE_HANG_TIME, 0.0, 1.0)

## The state everything downstream reads -- the visual, the camera, the
## snapshot -- comes from where the body actually ended up, not from the floor
## contact it started the tick with. Without this a take-off spends one frame
## reported as RUN and a landing one frame as FALL.
##
## Only the four ordinary states are re-decided here. DASH, HURT, DEAD, HANG and
## a ground pound own theirs, and contact resolution runs after this, so a hit
## or a launch still has the last word.
func _settle_normal_state() -> void:
	if _pound_phase > 0:
		return
	if state not in [State.IDLE, State.RUN, State.JUMP, State.FALL]:
		return
	_set_state_from_motion()

func _set_state_from_motion() -> void:
	var next: State
	if not is_on_floor():
		next = State.JUMP if velocity.y < 0.0 else State.FALL
	elif absf(velocity.x) > 12.0:
		next = State.RUN
	else:
		next = State.IDLE
	_set_state(next)

## Reserved burst ability for explicit scripted use. Normal sprint input never
## calls this; State.DASH stays in the wire enum for compatibility.
func _try_dash() -> void:
	if state == State.DASH or state == State.HURT or state == State.DEAD:
		return
	if is_on_floor():
		return
	if _dash_cooldown > 0.0:
		return
	if _air_dashes <= 0:
		return
	_end_player_jump()
	_air_dashes -= 1
	_launched = false
	_dash_timer = Balance.RUNNER_DASH_TIME
	_dash_cooldown = Balance.RUNNER_DASH_COOLDOWN
	var axis := _move_axis()
	if absf(axis) > 0.1:
		facing = signi(int(signf(axis)))
	_set_state(State.DASH)

func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity.x = float(facing) * Balance.RUNNER_DASH_SPEED
	velocity.y = 0.0
	if _dash_timer <= 0.0:
		velocity.x *= 0.55
		_set_state_from_motion()

func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	var g := Balance.RUNNER_GRAVITY if velocity.y < 0.0 else Balance.RUNNER_FALL_GRAVITY
	velocity.y = minf(velocity.y + g * delta, Balance.RUNNER_TERMINAL_VELOCITY)
	velocity.x = move_toward(velocity.x, 0.0, Balance.RUNNER_FRICTION * 0.4 * delta)
	if _hurt_timer <= 0.0:
		_set_state_from_motion()

func _after_move(was_airborne: bool) -> void:
	if is_on_floor() and was_airborne:
		_check_hologram_landing()
	_was_on_floor = is_on_floor()

func _check_hologram_landing() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is Node2D and (collider as Node).is_in_group("hologram"):
			if _hologram_credit != collider:
				_hologram_credit = collider
				Events.runner_landed_on_hologram.emit(collider)
			return
	_hologram_credit = null

func _resolve_contacts() -> void:
	if state == State.DEAD:
		return
	for body in _hurtbox.get_overlapping_bodies():
		_resolve_hazard(body)
		if state == State.DEAD:
			return
	for area in _hurtbox.get_overlapping_areas():
		_resolve_hazard(area)
		if state == State.DEAD:
			return

## Legacy helpers kept for compatibility with older isolated movement probes.
## Normal enemy contact no longer routes through these functions.
func _is_stomping(node: Node) -> bool:
	if velocity.y <= 0.0:
		return false
	var target := node as Node2D
	if target == null:
		return false
	var feet := global_position.y + Balance.RUNNER_SIZE.y * 0.5
	return feet <= target.global_position.y + 10.0

func _do_stomp(node: Node) -> void:
	if _pound_phase == 2:
		Events.runner_stomped_enemy.emit(node)
		if node.has_method("take_damage"):
			node.take_damage(99, "stomp")
		return
	var high := _jump_held() or _jump_buffer > 0.0
	var height := Balance.RUNNER_STOMP_HIGH_HEIGHT if high else Balance.RUNNER_STOMP_HEIGHT
	bounce(sqrt(2.0 * Balance.RUNNER_GRAVITY * height))
	_wall_coyote = 0.0
	Events.runner_stomped_enemy.emit(node)
	if node.has_method("take_damage"):
		node.take_damage(99, "stomp")

func _resolve_hazard(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.is_in_group("instant_death"):
		die("hazard")
		return
	# Enemies are never defeated by landing on them. Top-down contact is damage.
	take_damage(1)
	if node.has_method("on_hit_runner"):
		node.on_hit_runner(self)

func take_damage(amount: int) -> void:
	if _invuln > 0.0 or state == State.DEAD:
		return
	hp = maxi(0, hp - amount)
	Events.runner_damaged.emit(hp, Balance.RUNNER_MAX_HP)
	if hp <= 0:
		die("damage")
		return
	_end_player_jump()
	_jump_buffer = 0.0
	_reset_jump_chain()
	_pound_phase = 0
	_invuln = Balance.RUNNER_HURT_INVULN
	_hurt_timer = 0.25
	velocity = Vector2(-float(facing) * Balance.RUNNER_HURT_KNOCKBACK.x, Balance.RUNNER_HURT_KNOCKBACK.y)
	_set_state(State.HURT)

func die(cause: String) -> void:
	if state == State.DEAD:
		return
	_end_player_jump()
	_jump_buffer = 0.0
	_reset_jump_chain()
	_pound_phase = 0
	_external_takeoff_pending = false
	_set_state(State.DEAD)
	velocity = Vector2.ZERO
	Events.runner_died.emit(cause)

## Thrown by something that is not the runner's own legs. Player jump shaping
## is explicitly disabled so held/released input cannot change this trajectory.
func launch(velocity_out: Vector2) -> void:
	if state == State.DEAD:
		return
	_end_player_jump()
	_jump_buffer = 0.0
	_reset_jump_chain()
	_pound_phase = 0
	_wall_coyote = 0.0
	_wall_kick_lock = 0.0
	_wall_kick_visual = 0.0
	_wall_jump_ready = false
	velocity = velocity_out
	if absf(velocity_out.x) > 1.0:
		facing = signi(int(signf(velocity_out.x)))
	_coyote = 0.0
	_left_floor_at = -999.0
	_air_dashes = Balance.RUNNER_AIR_DASHES
	_launched = true
	_begin_external_takeoff()
	_set_state(State.JUMP)
	Events.runner_launched.emit(global_position)

static func launch_velocity(face: int) -> Vector2:
	return Vector2(Balance.LAUNCH_FORWARD * float(signi(face)), -Balance.LAUNCH_UP)

func respawn(at: Vector2) -> void:
	_end_player_jump()
	_pound_phase = 0
	_pound_timer = 0.0
	_down_was_held = false
	_wall_sliding = false
	_set_crouched(false)
	_reset_jump_chain()
	_wall_coyote = 0.0
	_wall_kick_lock = 0.0
	_wall_kick_visual = 0.0
	_wall_jump_ready = false
	_coyote = 0.0
	_jump_buffer = 0.0
	_hang_left = 0.0
	_last_ledge = 0
	_launched = false
	_external_takeoff_pending = false
	if input_hub != null:
		# A press edge from before death/focus loss must never jump after respawn.
		input_hub.take_jump()
		_buffer_press_release_sequence = input_hub.jump_release_sequence
	global_position = at
	velocity = Vector2.ZERO
	hp = Balance.RUNNER_MAX_HP
	_invuln = Balance.RUNNER_HURT_INVULN
	_dash_cooldown = 0.0
	_air_dashes = Balance.RUNNER_AIR_DASHES
	_hologram_credit = null
	_set_state(State.IDLE)
	Events.runner_damaged.emit(hp, Balance.RUNNER_MAX_HP)

func impact_speed() -> float:
	return _impact_speed

func is_invulnerable() -> bool:
	return _invuln > 0.0

var grounded: bool = true

func on_ground() -> bool:
	return grounded

func _process(delta: float) -> void:
	if not is_physics_processing():
		_invuln = maxf(0.0, _invuln - delta)

func airborne_time() -> float:
	return _airborne_time

## If focus disappears while a jump is active, treat that as an irreversible
## release and throw away any buffered press already handed to Runner.
func _notification(what: int) -> void:
	var lost := [NOTIFICATION_APPLICATION_FOCUS_OUT,
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]
	if what in lost:
		_jump_buffer = 0.0
		if _player_jump_active:
			_jump_release_latched = true
			_apex_finished = true

func _set_state(next: State) -> void:
	if next == state:
		return
	state = next
	state_changed.emit(state)
