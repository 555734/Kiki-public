extends Node2D
## Draws LIRA, the runner, entirely from primitives -- brown tousled hair, tan
## skin, the trailing red scarf from the mockups. Animation is driven by the
## runner's state rather than by keyframes, so the guardian can read what the
## runner is doing (and about to do) from across the table.

var runner: Runner = null

var _phase: float = 0.0
var _lean: float = 0.0
var _scarf: float = 0.0
var _squash: float = 0.0
var _was_airborne: bool = false
## Whole-body turn in radians: the third jump's somersault and the ground
## pound's wind-up spin. Runs from 0 to TAU and then rests.
var _spin: float = 0.0
var _spin_active: bool = false
var _was_pounding: bool = false
var _was_kicking: bool = false
## Short trail of where the body was, for dash and wall-kick afterimages.
var _trail: Array = []
var _trail_left: float = 0.0
## Dust puffs in world space: [position, age, size].
var _dust: Array = []

func _ready() -> void:
	z_index = 10

func _process(delta: float) -> void:
	if runner == null:
		return
	var speed := absf(runner.velocity.x)
	match runner.state:
		Runner.State.RUN:
			_phase += delta * (4.0 + speed / 40.0)
		Runner.State.DASH:
			_phase += delta * 22.0
		_:
			_phase += delta * 2.5
	# The scarf trails behind the direction of travel and lags the body.
	var target_scarf := clampf(-runner.velocity.x / Balance.RUNNER_RUN_SPEED, -1.6, 1.6)
	_scarf = lerpf(_scarf, target_scarf, clampf(delta * 8.0, 0.0, 1.0))
	var target_lean := clampf(runner.velocity.x / (Balance.RUNNER_RUN_SPEED * 3.0), -0.18, 0.18)
	_lean = lerpf(_lean, target_lean, clampf(delta * 10.0, 0.0, 1.0))

	# Squash on the frame the runner lands, then spring back. With only three
	# painted poses available this secondary motion is doing most of the work of
	# making the character feel alive.
	var airborne := not runner.on_ground()
	if _was_airborne and not airborne:
		# A ground pound lands hardest; a plain drop scales with how fast it fell.
		_squash = 1.35 if _was_pounding else clampf(0.55 + _last_fall / 1400.0, 0.55, 1.0)
		_puff(2 if not _was_pounding else 6, 1.0 if not _was_pounding else 1.8)
		_spin_active = false
		_spin = 0.0
	_was_airborne = airborne
	if airborne:
		_last_fall = maxf(0.0, runner.velocity.y)
	_squash = maxf(0.0, _squash - delta * 6.0)

	# The third jump of a chain is a forward somersault, and the ground pound
	# opens with a quick spin before it drops -- the two moves a player does on
	# purpose to show off, so they get the biggest movement on screen.
	var pounding := runner.pounding()
	var pound_windup := pounding and (runner.movement_flags() >> 1 & 3) == 1
	if airborne and not _spin_active and _spin == 0.0:
		if (runner.state == Runner.State.JUMP and runner.jump_chain() == 3) or pound_windup:
			_spin_active = true
	if _spin_active:
		_spin += delta * TAU * (3.2 if pound_windup else 2.0)
		if _spin >= TAU:
			_spin = TAU
			_spin_active = false
	if not airborne:
		_spin = 0.0
	_was_pounding = pounding

	var kicking := runner.wall_kicking()
	if kicking and not _was_kicking:
		_puff(3, 1.0)
		_trail_left = 0.22
	_was_kicking = kicking
	if runner.state == Runner.State.DASH:
		_trail_left = 0.12
	if _wall_sliding() and fmod(_phase, 0.5) < delta * 2.5:
		_puff(1, 0.6, Vector2(float(runner.facing) * 14.0, 0.0))
	_trail_left = maxf(0.0, _trail_left - delta)
	if _trail_left > 0.0:
		_trail.push_front(runner.global_position)
		if _trail.size() > 6:
			_trail.pop_back()
	elif not _trail.is_empty():
		_trail.pop_back()
	for d in _dust:
		d[1] += delta
	_dust = _dust.filter(func(d: Array) -> bool: return d[1] < 0.45)
	queue_redraw()

var _last_fall: float = 0.0

func _wall_sliding() -> bool:
	return runner != null and (runner.movement_flags() & 8) != 0

func _puff(count: int, strength: float, offset: Vector2 = Vector2.ZERO) -> void:
	var feet := runner.global_position + Vector2(0.0, Balance.RUNNER_SIZE.y * 0.5) + offset
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		_dust.append([feet + Vector2(side * (6.0 + float(i) * 5.0), 0.0), 0.0,
			(5.0 + float(i % 3) * 2.0) * strength, side])

func _draw() -> void:
	if runner == null:
		return

	# Invulnerability blink. Skipping the draw entirely (rather than fading) is
	# the readable version at this size.
	if runner.is_invulnerable() and fmod(_phase * 3.0, 1.0) < 0.4:
		return

	_draw_shadow()
	_draw_dust()
	_draw_trail()
	if _draw_painted():
		return

	var facing := float(runner.facing)
	var compact := Balance.RUNNER_CROUCH_HEIGHT / Balance.RUNNER_SIZE.y if runner.crouching() else 1.0
	draw_set_transform(Vector2(0, Balance.RUNNER_SIZE.y * 0.5 * (1.0 - compact)),
		_lean * facing, Vector2(1, compact))

	var dashing := runner.state == Runner.State.DASH
	var airborne := runner.state == Runner.State.JUMP or runner.state == Runner.State.FALL
	var stride := sin(_phase * TAU) if runner.state == Runner.State.RUN else 0.0

	_draw_scarf(facing, dashing)
	_draw_legs(facing, stride, airborne, dashing)
	_draw_torso(facing)
	_draw_arms(facing, stride, airborne, dashing)
	_draw_head(facing)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if dashing:
		_draw_dash_streaks(facing)

## Contact shadow. Cheap, and it is most of what stops a painted sprite from
## looking pasted on top of the level rather than standing in it.
func _draw_shadow() -> void:
	if not Balance.USE_TEXTURES:
		return
	var airborne := not runner.on_ground()
	var w := 30.0 * (0.7 if airborne else 1.0 + _squash * 0.25)
	var a := 0.16 if airborne else 0.30
	draw_set_transform(Vector2(0, Balance.RUNNER_SIZE.y * 0.5 + 2.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, w * 0.5, Color(0.10, 0.08, 0.06, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The painted runner: eight poses, chosen from the runner's own state, with the
## lean, squash and stretch still procedural on top.
##
## It used to be two poses for seven states, so a runner standing still, running,
## dashing and dying all looked the same. What the pose set buys is not
## smoothness -- there is still no in-between frame -- but LEGIBILITY, which is
## the thing this game actually needs: the guardian is reading the runner from
## the other side of a network connection and has to know what they are doing.
func _pose_key() -> String:
	if runner.cleared and runner.on_ground():
		return "runner_cheer"
	if runner.pounding():
		# Tucked while it spins, then the braced landing pose on the way down.
		return "runner_jump" if _spin_active else "runner_land"
	if runner.crouching():
		return "runner_land"
	if runner.state == Runner.State.HANG:
		return "runner_reach"
	if _wall_sliding():
		return "runner_reach"
	if runner.wall_kicking():
		return "runner_dash"
	# The landing crouch wins over the state. It lasts a fraction of a second
	# and it is the frame that sells the weight of the drop; without it the
	# runner snaps from falling straight back to standing.
	if _squash > 0.45 and runner.on_ground():
		return "runner_land"
	match runner.state:
		Runner.State.RUN:
			return "runner_run"
		Runner.State.JUMP:
			return "runner_jump"
		Runner.State.FALL:
			return "runner_fall"
		Runner.State.DASH:
			return "runner_dash"
		Runner.State.HURT:
			# Arms out, mouth open. The one pose that reads as "something just
			# happened to me" rather than as something the player chose.
			return "runner_reach"
		Runner.State.DEAD:
			return "runner_fall"
		_:
			return "runner_idle"

func _draw_painted() -> bool:
	var key := _pose_key()
	# The canvas carries headroom above the figure, so it is drawn taller than
	# the figure is meant to be. See Balance.RUNNER_POSE_HEADROOM.
	var h := Balance.RUNNER_SPRITE_H * Balance.RUNNER_POSE_HEADROOM
	var stretch := 1.0
	if runner.state == Runner.State.FALL or runner.state == Runner.State.JUMP:
		stretch = 1.0 + clampf(absf(runner.velocity.y) / 1600.0, 0.0, 0.10)
	var sy := stretch * (1.0 - _squash * 0.22)
	if runner.crouching():
		sy *= Balance.RUNNER_CROUCH_HEIGHT / Balance.RUNNER_SIZE.y
	elif runner.pounding():
		sy *= 0.8
	var sx := minf(1.20, (1.0 / maxf(sy, 0.01)) * (1.0 + _squash * 0.06))

	# A bob while running, so a single painted stride does not read as a slide.
	var bob := 0.0
	if runner.state == Runner.State.RUN:
		bob = absf(sin(_phase * TAU)) * -3.0
	if runner.cleared and runner.on_ground():
		# Little victory hops.
		bob = -absf(sin(_phase * 2.4)) * 14.0

	# Flip in the same transform as lean, squash and the feet anchor. Asking
	# Art.draw_sprite() to flip installs a new canvas transform and used to throw
	# away this origin, making the left-facing pose float above its shadow.
	if runner.wall_kicking():
		# Launched sideways off the wall: long and low for a moment.
		sx *= 1.12
		sy *= 0.92
	var tilt := _lean * float(runner.facing)
	if _wall_sliding():
		# Pressed against the wall, leaning into it.
		tilt = -0.22 * float(runner.facing)
	var paint_scale := _paint_scale(sx, sy)
	var ok := false
	if _spin > 0.0 and _spin < TAU:
		# Turn about the middle of the body rather than the feet.
		var centre := Vector2(0.0, 0.0)
		draw_set_transform(centre, _spin * float(runner.facing), paint_scale)
		ok = Art.draw_sprite(self, key, Vector2(0.0, h * 0.5), h)
	else:
		draw_set_transform(_paint_origin(bob), tilt, paint_scale)
		ok = Art.draw_sprite(self, key, Vector2.ZERO, h)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return ok

## Faded copies of the current pose where the body just was: dash and wall
## kick read as speed instead of as a teleport.
func _draw_trail() -> void:
	if _trail.is_empty() or not Balance.USE_TEXTURES:
		return
	var key := _pose_key()
	var h := Balance.RUNNER_SPRITE_H * Balance.RUNNER_POSE_HEADROOM
	for i in range(_trail.size() - 1, 0, -1):
		var at: Vector2 = to_local(_trail[i])
		var a := 0.30 * (1.0 - float(i) / float(_trail.size()))
		draw_set_transform(at + _paint_origin(0.0), _lean * float(runner.facing), _paint_scale(1.0, 1.0))
		Art.draw_sprite(self, key, Vector2.ZERO, h, false, Color(0.75, 0.9, 1.0, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_dust() -> void:
	for d in _dust:
		var t: float = d[1] / 0.45
		var at: Vector2 = to_local(d[0]) + Vector2(float(d[3]) * t * 16.0, -t * 10.0)
		draw_circle(at, float(d[2]) * (0.6 + t * 0.8), Color(0.96, 0.93, 0.86, 0.55 * (1.0 - t)))

func _paint_origin(bob: float) -> Vector2:
	return Vector2(0.0, Balance.RUNNER_SIZE.y * 0.5 + bob)

func _paint_scale(sx: float, sy: float) -> Vector2:
	return Vector2(-sx if runner != null and runner.facing < 0 else sx, sy)

func _draw_scarf(facing: float, dashing: bool) -> void:
	var back := -facing
	var flow := _scarf * facing
	var length := 26.0 + (10.0 if dashing else 0.0)
	var tip := Vector2(back * length, -4.0 + sin(_phase * 5.0) * 4.0 - flow * 3.0)
	var mid := Vector2(back * length * 0.45, -7.0 + sin(_phase * 5.0 + 1.0) * 2.5)
	var points := PackedVector2Array([
		Vector2(facing * 2.0, -10.0),
		mid + Vector2(0, -4.0),
		tip,
		tip + Vector2(back * 2.0, 7.0),
		mid + Vector2(0, 3.0),
		Vector2(facing * 2.0, -3.0),
	])
	draw_colored_polygon(points, Balance.C_SCARF)
	# Collar
	draw_circle(Vector2(0, -8.0), 6.5, Balance.C_SCARF)

func _draw_legs(facing: float, stride: float, airborne: bool, dashing: bool) -> void:
	var hip := Vector2(0, 8.0)
	var boot := Color("6b4a2a")
	var leg := Color("2c3550")
	var front_x: float
	var back_x: float
	var front_y := 21.0
	var back_y := 21.0
	if airborne:
		front_x = facing * 7.0
		back_x = -facing * 6.0
		front_y = 17.0
		back_y = 20.0
	elif dashing:
		front_x = facing * 11.0
		back_x = -facing * 9.0
		front_y = 20.0
		back_y = 16.0
	else:
		front_x = stride * 9.0
		back_x = -stride * 9.0
		front_y = 21.0 - maxf(0.0, stride) * 4.0
		back_y = 21.0 - maxf(0.0, -stride) * 4.0

	DrawUtil.limb(self, hip, Vector2(back_x, back_y), 8.0, leg.darkened(0.25))
	draw_circle(Vector2(back_x + facing * 2.0, back_y + 2.0), 4.5, boot.darkened(0.2))
	DrawUtil.limb(self, hip, Vector2(front_x, front_y), 8.5, leg)
	draw_circle(Vector2(front_x + facing * 2.0, front_y + 2.0), 5.0, boot)

func _draw_torso(facing: float) -> void:
	var body := Color("3a4870")
	DrawUtil.rounded_rect(self, Rect2(-8.0, -9.0, 16.0, 20.0), 6.0, body)
	# Belt
	draw_rect(Rect2(-8.0, 5.0, 16.0, 4.0), Color("7a5433"))
	draw_rect(Rect2(facing * 1.0 - 2.0, 5.0, 4.0, 4.0), Color("d9a441"))

func _draw_arms(facing: float, stride: float, airborne: bool, dashing: bool) -> void:
	var shoulder := Vector2(0, -5.0)
	var sleeve := Color("4a5a88")
	var glove := Color("efe4d2")
	var front: Vector2
	var back: Vector2
	if dashing:
		front = Vector2(facing * 13.0, -8.0)
		back = Vector2(-facing * 12.0, 2.0)
	elif airborne:
		front = Vector2(facing * 9.0, -12.0)
		back = Vector2(-facing * 9.0, -2.0)
	else:
		front = Vector2(-stride * 9.0 + facing * 3.0, 2.0)
		back = Vector2(stride * 9.0 + facing * 1.0, 2.0)

	DrawUtil.limb(self, shoulder, back, 6.0, sleeve.darkened(0.25))
	draw_circle(back, 3.4, glove.darkened(0.15))
	DrawUtil.limb(self, shoulder, front, 6.5, sleeve)
	draw_circle(front, 3.8, glove)

func _draw_head(facing: float) -> void:
	var head := Vector2(facing * 1.5, -17.0)
	draw_circle(head, 10.5, Balance.C_SKIN)
	# Hair sits as a cap on the upper half only -- covering the whole skull the
	# way it did first time round turned the head into a featureless brown blob
	# at play scale.
	var hair := Balance.C_HAIR
	draw_circle(head + Vector2(0, -4.6), 9.8, hair)
	draw_rect(Rect2(head.x - 9.8, head.y - 5.0, 19.6, 4.0), hair)
	for i in range(4):
		var t := float(i) / 3.0
		var base := head + Vector2(lerpf(-8.0, 7.0, t), -9.0)
		var spike := base + Vector2(-facing * 3.0 - 2.0 + t * 4.0, -5.0 - sin(_phase * 4.0 + float(i)) * 1.5)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-2.5, 1.0), base + Vector2(2.5, 1.0), spike,
		]), hair)
	# Sideburn / fringe on the facing side
	draw_circle(head + Vector2(facing * 8.0, -3.5), 3.4, hair)
	# Eyes, large enough to read at the framing the mockups use.
	var eye := Vector2(head.x + facing * 3.6, head.y + 1.6)
	draw_circle(eye, 2.7, Color("2a1f18"))
	draw_circle(eye + Vector2(facing * 0.8, -0.8), 1.0, Color(1, 1, 1, 0.85))
	var far_eye := eye + Vector2(facing * -6.4, 0)
	draw_circle(far_eye, 2.3, Color("2a1f18"))
	draw_circle(far_eye + Vector2(facing * 0.7, -0.7), 0.9, Color(1, 1, 1, 0.7))

func _draw_dash_streaks(facing: float) -> void:
	var back := -facing
	for i in range(3):
		var y := -8.0 + float(i) * 9.0
		var length := 18.0 + float(i % 2) * 8.0
		draw_line(Vector2(back * 10.0, y), Vector2(back * (10.0 + length), y),
			Color(1, 1, 1, 0.35 - float(i) * 0.07), 2.5)
