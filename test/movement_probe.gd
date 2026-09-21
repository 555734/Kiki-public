extends Node2D
## Real CharacterBody2D movement on isolated terrain, through InputHub intents.
## No main-stage enemies, camera, save files or teleports inside measured arcs.
## godot --headless --path . --fixed-fps 60 res://test/movement_probe.tscn

var runner: Runner
var hub: InputHub
var wall: StaticBody2D
var checks := 0
var failures := 0
var completed := false

func _ready() -> void:
	Options.forget()
	hub = InputHub.new()
	hub.scripted = true
	add_child(hub)
	_body(Rect2(-10000, 400, 20000, 100))
	wall = _body(Rect2(1500, -1000, 48, 1400))
	runner = Runner.new()
	runner.input_hub = hub
	add_child(runner)
	# Exactly one manual physics tick per physics frame. Godot still resolves
	# real contacts; this removes scene-tree callback ordering from the probe.
	runner.set_physics_process(false)
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		if not completed:
			push_error("movement probe did not reach its last assertion")
			get_tree().quit(1))
	await _jumps()
	await _held_jumps()
	await _air_control()
	await _sprint_leaves_the_rise_alone()
	await _external_takeoffs()
	await _state_edges()
	await _chains()
	await _walls()
	await _stomps()
	await _stances()
	await _pounds()
	completed = true
	print("movement: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

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
	else:
		print("  ok: ", label)

func _reset() -> void:
	hub.move_axis = 0.0
	hub.move_axis_y = 0.0
	hub.release_jump()
	hub.release_dash()
	hub.take_jump()
	hub.take_dash()
	runner.respawn(Vector2(-5000, 300))
	await _tick(40)
	_ok(runner.is_on_floor(), "fixture starts grounded")

func _run_up(sprint: bool) -> void:
	hub.move_axis = 1.0
	hub.dash_held = sprint
	await _tick(35)

## Begins the jump now and returns height/reach only after a real landing.
func _arc(release_after: int = -1) -> Vector2:
	var start := runner.position
	var top := start.y
	var airborne := false
	hub.press_jump()
	for i in range(180):
		if i == release_after:
			hub.release_jump()
		await _tick()
		top = minf(top, runner.position.y)
		airborne = airborne or not runner.is_on_floor()
		if airborne and runner.is_on_floor():
			_ok(true, "jump returns to the floor")
			return Vector2(start.y - top, runner.position.x - start.x)
	_ok(false, "jump must land within 180 frames")
	return Vector2.ZERO

func _release_repress_height() -> float:
	var start_y := runner.position.y
	var top := start_y
	var airborne := false
	hub.press_jump()
	for i in range(180):
		if i == 2:
			hub.release_jump()
		if i == 3:
			hub.press_jump()
		await _tick()
		top = minf(top, runner.position.y)
		airborne = airborne or not runner.is_on_floor()
		if airborne and runner.is_on_floor():
			hub.release_jump()
			return start_y - top
	_ok(false, "release/repress jump must land")
	return 0.0

func _jumps() -> void:
	await _reset()
	var standing := await _arc()
	_ok(absf(standing.x - 161.4) < 4.5,
		"held base jump stays near the designed height")
	await _reset()
	await _run_up(false)
	var walking := await _arc()
	await _reset()
	await _run_up(true)
	var sprint := await _arc()
	_ok(sprint.x > walking.x * 1.15, "real run-up adds jump height")
	_ok(sprint.y > walking.y * 1.3, "real run-up adds jump distance")
	_ok(absf(walking.x - standing.x) < 3.0, "walking and standing retain the base jump")
	await _reset()
	hub.dash_held = true
	var stationary_sprint := await _arc()
	_ok(absf(stationary_sprint.x - standing.x) < 3.0, "sprint button alone gives no height bonus")
	await _reset()
	await _run_up(true)
	var short := await _arc(3)
	_ok(short.x > sprint.x * 0.45 and short.x < sprint.x * 0.60,
		"release gravity gives a useful short jump without a velocity snap")
	await _reset()
	var release_repress := await _release_repress_height()
	_ok(release_repress > Balance.RUNNER_SIZE.y + 20.0 \
		and release_repress < standing.x * 0.65,
		"release then repress inside the protected window stays a short jump")
	print("  height/reach px: standing=%s walk=%s sprint=%s short=%s repress=%.2f"
		% [standing, walking, sprint, short, release_repress])

func _air_control() -> void:
	# Early rise, near apex, and early descent. Braking must reverse promptly;
	# same-direction reacceleration is intentionally slower than before.
	for delay in [4, 20, 25]:
		await _reset()
		await _run_up(true)
		hub.press_jump()
		await _tick(delay)
		_ok(not runner.is_on_floor(), "air steering fixture is airborne")
		hub.move_axis = -1.0
		var reversed_in := -1
		for i in range(11):
			await _tick()
			if runner.velocity.x < -1.0 and not runner.is_on_floor():
				reversed_in = i + 1
				break
		_ok(reversed_in > 0, "opposite input reverses within 11 air frames at delay %d" % delay)
		if delay == 4:
			var sprint_speed := Balance.RUNNER_RUN_SPEED * Balance.RUNNER_SPRINT_MULTIPLIER
			for _i in range(22):
				if runner.velocity.x <= -sprint_speed * 0.95 or runner.is_on_floor():
					break
				await _tick()
			_ok(runner.velocity.x <= -sprint_speed * 0.95 and not runner.is_on_floor(),
				"reversed flight reaccelerates to sprint speed before landing")
	await _reset()
	await _run_up(true)
	hub.press_jump()
	await _tick(5)
	var old_speed := runner.velocity.x
	hub.move_axis = 0.0
	await _tick(8)
	var release_ratio := runner.velocity.x / old_speed
	_ok(release_ratio >= 0.55 and release_ratio <= 0.70,
		"eight neutral air frames retain 55-70 percent horizontal speed")
	# Sprint input changes only the horizontal target. Compare one tick with and
	# without toggling sprint rather than assuming a particular vertical gravity
	# branch (the same assertion remains valid at the apex).
	var before_y := runner.velocity.y
	hub.move_axis = 1.0
	hub.press_dash()
	await _tick()
	var after_with_sprint := runner.velocity.y
	_ok(runner.state != Runner.State.DASH, "air sprint never enters burst state")
	hub.release_dash()
	_ok(after_with_sprint != before_y, "vertical physics continues while air sprint is pressed")

func _chains() -> void:
	await _reset()
	await _run_up(true)
	var first := await _arc()
	hub.release_jump()
	var second := await _arc()
	_ok(runner.jump_chain() == 2 and second.x > first.x * 1.10,
		"fresh jump at landing makes a higher second jump")
	hub.release_jump()
	var third := await _arc()
	_ok(runner.jump_chain() == 3 and third.x > second.x * 1.10,
		"third timed landing makes the highest jump")
	_ok(third.y > second.y * 1.05,
		"third jump is also the farthest forward-running jump")
	_ok(third.y + Balance.RUNNER_SIZE.x < 600.0,
		"600px crossings still require help even with a triple jump")
	_ok(third.y + Balance.RUNNER_SIZE.x < 480.0,
		"final 480px rising crossing exceeds even flat triple-jump reach")
	hub.release_jump()
	var fourth := await _arc()
	_ok(runner.jump_chain() == 1 and absf(fourth.x - first.x) < 4.0,
		"chain cycles after three, never increases without limit")
	hub.release_jump()
	await _tick(12)
	await _arc()
	_ok(runner.jump_chain() == 1, "missing the landing window resets the chain")
	hub.release_jump()
	hub.move_axis = -1.0
	await _tick(2)
	var turned := await _arc()
	_ok(runner.jump_chain() <= 1 and turned.x <= first.x + 3.0, "turning around removes the consecutive-jump bonus")
	await _tick(20)
	_ok(runner.is_on_floor(), "held jump never triggers another jump after landing")
	runner.launch(Vector2(500, -500))
	_ok(runner.jump_chain() == 0, "guardian launch resets chain eligibility")
	runner.respawn(Vector2(-5000, 300))
	_ok(runner.jump_chain() == 0 and not runner.can_wall_jump(), "respawn clears movement history")
	print("  consecutive height/reach px: %s / %s / %s" % [first, second, third])

func _walls() -> void:
	await _reset()
	for attempt in range(4):
		runner.position = Vector2(1484, -500)
		runner.velocity = Vector2(0, 200)
		hub.move_axis = 1.0
		hub.release_jump()
		await _tick(2) # first tick also syncs a direct fixture teleport into PhysicsServer
		_ok(runner.can_wall_jump(),
			"near-wall probe arms kick %d immediately after contact" % (attempt + 1))
		_ok(runner.velocity.y <= Balance.WALL_SLIDE_SPEED + 1.0,
			"pressing into a wall slows the fall")
		hub.press_jump()
		await _tick(2)
		_ok(runner.velocity.x < 0.0 and runner.velocity.y < 0.0,
			"kick moves up and away despite held direction")
		_ok(absf(runner.velocity.x) >= Balance.RUNNER_RUN_SPEED * 1.25,
			"wall kick leaves with a strong near-sprint outward burst")
		_ok(runner.wall_kicking(), "wall kick exposes a short presentation pose window")
		_ok(not runner.can_wall_jump(), "old contact cannot immediately provide a second kick")
		hub.release_jump()
		await _tick(8)
	runner.position = Vector2(-3000, -500)
	runner.velocity = Vector2.ZERO
	hub.move_axis = 0.0
	await _tick(12)
	hub.press_jump()
	await _tick()
	_ok(runner.velocity.y > 0.0, "wall kick cannot become a free mid-air jump")

func _stomps() -> void:
	await _reset()
	var enemy := Node2D.new()
	add_child(enemy)
	hub.release_jump()
	runner._do_stomp(enemy)
	var low := absf(runner.velocity.y)
	hub.press_jump()
	runner._read_input(Clock.DT)
	runner._do_stomp(enemy)
	var high := absf(runner.velocity.y)
	_ok(high > low * 1.5, "jump at enemy contact selects a higher bounce")
	_ok(runner._jump_buffer == 0.0,
		"stomp consumes the request before the external bounce")
	var external_v := runner.velocity.y
	hub.release_jump()
	await _tick()
	_ok(absf(runner.velocity.y - (external_v + Balance.RUNNER_GRAVITY * Clock.DT)) < 1.0,
		"releasing jump cannot shorten an external bounce")
	_ok(runner.jump_chain() == 0, "stomps cannot secretly advance the landing chain")
	enemy.queue_free()

func _stances() -> void:
	await _reset()
	await _run_up(true)
	var speed := runner.velocity.x
	var soles := runner.position.y + Balance.RUNNER_SIZE.y * 0.5
	hub.move_axis_y = 1.0
	await _tick()
	_ok(runner.crouching() and runner.velocity.x > speed * 0.8,
		"down while running keeps momentum in a crouch slide")
	_ok(absf(runner.position.y + runner._body_shape.position.y
		+ (runner._body_shape.shape as RectangleShape2D).size.y * 0.5 - soles) < 0.2,
		"changing stance keeps the soles on the floor")
	hub.move_axis = 0.0
	await _tick(40)
	var roof := _body(Rect2(runner.position.x - 50.0, 330.0, 100.0, 36.0))
	await _tick(2)
	hub.move_axis_y = 0.0
	await _tick(3)
	_ok(runner.crouching(), "releasing down under a low ceiling cannot expand into it")
	hub.move_axis = 1.0
	await _tick(70)
	_ok(not runner.crouching(), "leaving the low ceiling restores standing automatically")
	roof.queue_free()
	await _tick()
	await _reset()
	hub.move_axis_y = 1.0
	await _tick()
	hub.press_jump()
	await _tick(5)
	_ok(runner.crouching() and not runner.is_on_floor() and runner.velocity.y < 0.0,
		"a held crouch can jump without becoming a ground pound")
	hub.move_axis_y = 0.0
	await _tick()
	_ok(not runner.crouching(), "crouch jump can unfold in open air")

func _pounds() -> void:
	await _reset()
	hub.press_jump()
	await _tick(10)
	hub.move_axis_y = 1.0
	await _tick()
	_ok(runner.pounding() and absf(runner.velocity.y) < 0.1,
		"fresh down in flight begins a brief ground-pound wind-up")
	hub.release_jump()
	hub.press_jump()
	await _tick()
	_ok(not runner.pounding(), "a fresh jump can cancel the wind-up")
	hub.move_axis_y = 0.0
	await _tick()
	hub.move_axis_y = 1.0
	await _tick(8)
	_ok(runner.pounding() and runner.velocity.y >= Balance.RUNNER_POUND_SPEED,
		"held down commits to a fast ground pound")
	for _i in range(40):
		await _tick()
		if runner.is_on_floor():
			break
	_ok(runner.is_on_floor() and not runner.pounding(), "ground pound ends at the floor")
	hub.move_axis_y = 0.0
	hub.release_jump()
	hub.press_jump()
	await _tick(2)
	_ok(not runner.is_on_floor() and runner.velocity.y < 0.0,
		"landing a ground pound allows an immediate new jump")
	runner.apply_movement_flags(1)
	_ok(runner.crouching() and runner.movement_flags() == 1,
		"remote crouch updates both pose and collider")
	runner.apply_movement_flags(4)
	_ok(runner.pounding() and not runner.crouching(), "remote ground-pound pose decodes")
	runner.respawn(Vector2(-5000, 300))
	_ok(runner.movement_flags() == 0, "respawn clears every added movement flag")

# --------------------------------------------------- holding the jump button
#
# The button has two pieces of information in it -- a press and a hold -- and
# they have to be tested as two, through the same API the game uses. Writing
# jump_held directly says "held" without ever saying "pressed", which is a state
# a thumb cannot produce and a test that cannot fail on the thing it is for.

## Press, hold for `held` ticks, release, and report the height of the arc.
func _tap_height(held: int) -> float:
	var start_y := runner.position.y
	var top := start_y
	var airborne := false
	hub.press_jump()
	for i in range(180):
		if i == held:
			hub.release_jump()
		await _tick()
		top = minf(top, runner.position.y)
		airborne = airborne or not runner.is_on_floor()
		if airborne and runner.is_on_floor():
			hub.release_jump()
			return start_y - top
	_ok(false, "a %d-frame tap must land" % held)
	return 0.0

func _held_jumps() -> void:
	# Longer presses buy more height, and the button stops mattering once the
	# jump is over: nine frames is not nine times one.
	var heights: Array[float] = []
	for held in [1, 3, 6, 9]:
		await _reset()
		heights.append(await _tap_height(held))
	await _reset()
	var full := await _tap_height(400)
	var rising := true
	for i in range(1, heights.size()):
		if heights[i] < heights[i - 1] - 0.5:
			rising = false
	_ok(rising, "1/3/6/9-frame presses give heights that only grow: %s" % [heights])
	_ok(heights[0] > Balance.RUNNER_SIZE.y * 0.5,
		"even a single frame is a real hop (%.1fpx)" % heights[0])
	_ok(heights[3] < full - 1.0,
		"and nine frames is still short of a held jump (%.1f of %.1f)"
			% [heights[3], full])

	# The apex easing has a time limit, so a held jump cannot hang there.
	await _reset()
	var rose := 0.0
	var to_apex := 0.0
	var apex_y := runner.position.y
	hub.press_jump()
	for i in range(120):
		await _tick()
		rose += Clock.DT
		if runner.position.y < apex_y:
			apex_y = runner.position.y
			to_apex = rose
		if i > 4 and runner.is_on_floor():
			break
	hub.release_jump()
	_ok(to_apex >= 0.34 and to_apex <= 0.39,
		"a held jump reaches its apex in %.3fs" % to_apex)
	_ok(to_apex <= Balance.RUNNER_TIME_TO_APEX + Balance.RUNNER_APEX_MAX_TIME,
		"which is inside the rise plus the apex easing's own time limit")

	# A press that arrives before the landing and is let go before it lands has
	# to be remembered as the short press it was.
	await _reset()
	await _run_up(false)
	hub.press_jump()
	await _tick(2)
	hub.release_jump()
	for _i in range(180):
		await _tick()
		if runner.is_on_floor():
			break
	hub.press_jump()
	await _tick()
	hub.release_jump()          # let go while still on the way up
	var buffered_top := runner.position.y
	var buffered_from := runner.position.y
	for _i in range(180):
		await _tick()
		buffered_top = minf(buffered_top, runner.position.y)
		if runner.is_on_floor():
			break
	_ok(buffered_from - buffered_top < full - 1.0,
		"a press let go on the way up stays a short jump (%.1f of %.1f)"
			% [buffered_from - buffered_top, full])

	# Losing focus mid-rise is an irreversible release, and the button coming
	# back cannot undo it.
	await _reset()
	var focus_from := runner.position.y
	var focus_top := focus_from
	hub.press_jump()
	await _tick(2)
	runner._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	for _i in range(180):
		await _tick()
		focus_top = minf(focus_top, runner.position.y)
		if runner.is_on_floor():
			break
	hub.release_jump()
	_ok(focus_from - focus_top < full - 1.0,
		"losing focus cuts the jump like a release (%.1f of %.1f)"
			% [focus_from - focus_top, full])

	# The ceiling ends the rise. Nothing here is Runner's own code -- it is
	# move_and_slide's collision response -- which is exactly why it is checked.
	await _reset()
	var roof := _body(Rect2(runner.position.x - 200.0, runner.position.y - 140.0,
		400.0, 40.0))
	await _tick(2)
	var bonked := false
	var climbed := 0
	var sideways := 0.0
	hub.press_jump()
	for _i in range(90):
		await _tick()
		if runner.is_on_ceiling():
			bonked = true
			sideways = maxf(sideways, absf(runner.velocity.x))
			if runner.velocity.y < -1.0:
				climbed += 1
		if bonked and runner.is_on_floor():
			break
	hub.release_jump()
	_ok(bonked, "a held jump reaches a ceiling 140px up")
	_ok(climbed == 0, "and the rise ends there (%d frames of climb)" % climbed)
	_ok(sideways < 20.0, "with nothing added sideways (%.0fpx/s)" % sideways)
	_ok(runner.is_on_floor(), "and the runner comes back down")
	roof.queue_free()
	await _tick()

## Sprint moves the horizontal target and nothing else. Two flights from the
## same standing take-off, the same press and release, the same number of ticks:
## every vertical speed and every height has to line up frame for frame.
func _air_trial(sprint: bool) -> Array:
	await _reset()
	hub.dash_held = sprint
	var floor_y := runner.position.y
	hub.press_jump()
	await _tick()                        # take-off, from a standstill either way
	hub.move_axis = 1.0
	var trace: Array = []
	for i in range(40):
		if i == 20:
			hub.release_jump()
		await _tick()
		trace.append([runner.velocity.y, floor_y - runner.position.y])
	hub.release_jump()
	hub.dash_held = false
	hub.move_axis = 0.0
	return trace

func _sprint_leaves_the_rise_alone() -> void:
	var plain := await _air_trial(false)
	var sprinted := await _air_trial(true)
	var worst_vy := 0.0
	var worst_y := 0.0
	for i in range(plain.size()):
		worst_vy = maxf(worst_vy, absf(float(plain[i][0]) - float(sprinted[i][0])))
		worst_y = maxf(worst_y, absf(float(plain[i][1]) - float(sprinted[i][1])))
	_ok(worst_vy <= 0.1,
		"sprint changes no vertical speed over 40 matched frames (%.4f)" % worst_vy)
	_ok(worst_y <= 0.1,
		"and no height, through the apex and past the release (%.4f)" % worst_y)
	# The trial has to actually cover the apex and the release, or it proves
	# nothing about either.
	var rose := false
	var fell := false
	for step in plain:
		if float(step[0]) < -1.0:
			rose = true
		if float(step[0]) > 1.0:
			fell = true
	_ok(rose and fell, "and the matched frames span the rise, the apex and the fall")

# ----------------------------------------------- thrown by something else
#
# A spring or a guardian launch owns the take-off. A jump press that happens to
# be in flight at that moment must not be spent on top of it: the runner leaves
# at the speed the thing that threw them chose, whoever is holding what.

## `press` is when a jump press arrives relative to the throw:
##   none / before / after / buffered / held / released.
func _thrown(kind: String, press: String, airborne: bool = false) -> Dictionary:
	await _reset()
	hub.move_axis = 0.0
	if press == "held" or press == "released":
		# A real hold: jump, land, and still have the button down. There is no
		# other way for a grounded runner to be holding jump without a press
		# waiting to be spent.
		hub.press_jump()
		for _i in range(180):
			await _tick()
			if runner.is_on_floor() and runner.velocity.y >= 0.0:
				break
		await _tick(4)
		if press == "released":
			hub.release_jump()
			await _tick()
	if airborne:
		hub.press_jump()
		await _tick(8)
		hub.release_jump()
		await _tick()
	if press == "buffered":
		hub.press_jump()
		runner._read_input(Clock.DT)      # the press is already Runner's
	elif press == "before":
		hub.press_jump()                  # still sitting unconsumed in the hub
	_throw(kind)
	if press == "after":
		hub.press_jump()                  # arrives after the throw, before the tick
	await _tick()
	var out := {
		"vx": runner.velocity.x, "vy": runner.velocity.y,
		"active": runner._player_jump_active, "chain": runner.jump_chain(),
	}
	hub.release_jump()
	return out

func _throw(kind: String) -> void:
	if kind == "launch":
		runner.launch(Runner.launch_velocity(1))
	else:
		runner.bounce(Balance.SPRING_VELOCITY)

func _thrown_pair(kind: String, press: String, airborne: bool = false) -> void:
	var clean := await _thrown(kind, "none", airborne)
	var pressed := await _thrown(kind, press, airborne)
	var where := " in the air" if airborne else ""
	_ok(absf(float(pressed["vy"]) - float(clean["vy"])) <= 0.1 \
			and absf(float(pressed["vx"]) - float(clean["vx"])) <= 0.1,
		"a %s%s leaves at its own speed with a %s press (%.2f vs %.2f)"
			% [kind, where, press, float(pressed["vy"]), float(clean["vy"])])
	_ok(not bool(pressed["active"]) and int(pressed["chain"]) == 0,
		"and the press starts no player jump and no chain (%s, %s press)"
			% [kind, press])

func _external_takeoffs() -> void:
	for kind in ["launch", "bounce"]:
		for press in ["before", "after", "buffered", "held", "released"]:
			await _thrown_pair(kind, press)
	# Thrown while already in the air, which is the other half of the case.
	await _thrown_pair("launch", "before", true)
	await _thrown_pair("bounce", "before", true)

	# Not a permanent ban: the flight is still the runner's to steer, and the
	# jump button works again as soon as the throw is over.
	await _reset()
	runner.launch(Runner.launch_velocity(1))
	await _tick(2)
	hub.move_axis = -1.0
	await _tick(6)
	_ok(runner.velocity.x < Balance.LAUNCH_FORWARD,
		"air steering still works during a launch (%.0fpx/s)" % runner.velocity.x)
	hub.move_axis = 0.0
	for _i in range(240):
		await _tick()
		if runner.is_on_floor():
			break
	_ok(runner.is_on_floor(), "the launch ends on the ground")
	hub.press_jump()
	await _tick()
	_ok(runner.velocity.y < 0.0 and runner._player_jump_active,
		"and the next press after landing is an ordinary jump again")

	# The real spring, fired from its own physics callback rather than by a
	# direct call, and met the way a spring is actually met: falling onto it
	# with a jump already asked for.
	var with_press := await _real_spring(true)
	var without := await _real_spring(false)
	_ok(absf(with_press - without) <= 0.1,
		"a real spring throws the same with a jump in flight (%.2f vs %.2f)"
			% [with_press, without])
	# And the real launch trigger, shot the way the guardian shoots it.
	var pad_press := await _real_launch_pad(true)
	var pad_clean := await _real_launch_pad(false)
	_ok(absf(pad_press - pad_clean) <= 0.1,
		"a shot launch pad throws the same with a press in flight (%.2f vs %.2f)"
			% [pad_press, pad_clean])

func _real_spring(press: bool) -> float:
	await _reset()
	var resting := runner.position.y
	var spring := Spring.new()
	spring.runner = runner
	spring.position = Vector2(runner.position.x,
		resting + Balance.RUNNER_SIZE.y * 0.5 + Spring.PAD_Y)
	add_child(spring)
	runner.position.y = resting - 140.0
	runner.velocity = Vector2.ZERO
	var asked := false
	var out := 0.0
	for _i in range(90):
		# Pressed on the way down and still held at contact, which is the case
		# that used to turn a spring into a much smaller jump.
		if press and not asked and runner.position.y > resting - 40.0:
			hub.press_jump()
			asked = true
		await _tick()
		if runner.velocity.y < -1.0:
			out = runner.velocity.y
			break
	_ok(out < 0.0, "the spring fires when the runner lands on it")
	hub.release_jump()
	spring.queue_free()
	await _tick()
	return out

func _real_launch_pad(press: bool) -> float:
	await _reset()
	var feet := runner.position.y + Balance.RUNNER_SIZE.y * 0.5
	var slab := Hologram.new()
	slab.kind = Hologram.Kind.PLATFORM
	slab.position = Vector2(runner.position.x, feet + Balance.PLATFORM_SIZE.y * 0.5)
	add_child(slab)
	await _tick(2)
	slab.trigger.runner = runner
	_ok(slab.trigger.loaded(), "the launch pad reads the runner as aboard")
	if press:
		hub.press_jump()
	slab.trigger.take_damage(1)
	await _tick()
	var out := runner.velocity.y
	hub.release_jump()
	slab.queue_free()
	await _tick()
	return out

# ------------------------------------------- what the rest of the frame sees
#
# The visual, the camera and the snapshot all read `state` and `on_ground()`
# after the move. Both have to describe where the body ended up, not the floor
# contact it started the tick with.

func _state_edges() -> void:
	await _reset()
	await _run_up(false)
	_ok(runner.state == Runner.State.RUN and runner.on_ground(),
		"running on the ground reads as running")
	hub.press_jump()
	await _tick()
	_ok(not runner.is_on_floor() and not runner.on_ground(),
		"the take-off frame has actually left the floor")
	_ok(runner.state == Runner.State.JUMP,
		"and is reported as a jump on that same frame, not still running")
	hub.release_jump()
	var landing_state := Runner.State.DEAD
	var landing_grounded := false
	for _i in range(180):
		await _tick()
		if runner.is_on_floor():
			landing_state = runner.state
			landing_grounded = runner.on_ground()
			break
	_ok(landing_grounded, "the landing frame is on the ground")
	_ok(landing_state == Runner.State.RUN,
		"and is reported as running on that same frame, not still falling")

	# Everything that owns its own state keeps it.
	await _reset()
	runner.take_damage(1)
	_ok(runner.state == Runner.State.HURT, "a hit puts the runner in HURT")
	await _tick()
	_ok(runner.state == Runner.State.HURT, "and the move does not overwrite it")
	await _reset()
	hub.press_jump()
	await _tick(10)
	hub.move_axis_y = 1.0
	await _tick(3)
	_ok(runner.pounding(), "a ground pound is under way")
	await _tick()
	_ok(runner.pounding() and runner.state == Runner.State.FALL,
		"and the move leaves the pound's own state alone")
	hub.move_axis_y = 0.0
	hub.release_jump()
