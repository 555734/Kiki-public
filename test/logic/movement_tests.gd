extends "res://test/logic/logic_suite.gd"
## The runner's own movement: the jump arc, turning, dash, stomps, damage, ledges.

## Setting off, stopping, turning round, and steering in mid-air are four
## different acts, and each one is checked here against its own dial.
##
## They used to share a single acceleration. That is what makes this worth a
## test rather than a comment: with one number, making the turn-around crisp
## necessarily made a mid-air reversal instant, and a run-up stopped deciding
## anything. Nothing about the code said so.
func _test_four_ways_to_change_direction() -> void:
	_current = "four ways to change direction"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	main._respawn_timer = -1.0

	var settle := func() -> void:
		r.global_position = Vector2(-400, 300)
		r.velocity = Vector2.ZERO
		hub.move_axis = 0.0
		hub.dash_held = false
		# Teleporting preserves the previous move_and_slide floor result.
		# physics_frame fires before body callbacks; allow a complete body
		# update before testing contact at the new position.
		await _physics(2)
		for _i in range(40):
			await get_tree().physics_frame
			if r.is_on_floor():
				break

	# 1. Setting off: from a standing start to full speed.
	await settle.call()
	hub.move_axis = 1.0
	var took := 0.0
	for _i in range(60):
		await get_tree().physics_frame
		took += Clock.DT
		if absf(r.velocity.x) >= Balance.RUNNER_RUN_SPEED - 2.0:
			break
	check_range(took, 0.12, 0.20,
		"setting off reaches full speed in 0.12-0.20s (%.3fs)" % took)

	# 2. Stopping: letting go, at full speed, on the ground.
	hub.move_axis = 0.0
	var stopped := 0.0
	for _i in range(60):
		await get_tree().physics_frame
		stopped += Clock.DT
		if absf(r.velocity.x) < 2.0:
			break
	check_range(stopped, 0.08, 0.15,
		"and stopping takes 0.08-0.15s (%.3fs)" % stopped)

	# 3. Turning: pressing the other way, at full speed. Has to be quicker than
	# letting go and setting off again, or a turn feels like ice.
	await settle.call()
	hub.move_axis = 1.0
	for _i in range(30):
		await get_tree().physics_frame
		if absf(r.velocity.x) >= Balance.RUNNER_RUN_SPEED - 2.0:
			break
	hub.move_axis = -1.0
	var turned := 0.0
	for _i in range(60):
		await get_tree().physics_frame
		turned += Clock.DT
		if r.velocity.x <= 0.0:
			break
	check(turned < stopped,
		"turning kills the old direction faster than letting go does (%.3fs vs %.3fs)"
			% [turned, stopped])
	check(turned < 0.12, "and quickly enough to feel like one movement (%.3fs)" % turned)

	# 4. Opposite input must reverse before landing, not merely slow the jump.
	await settle.call()
	hub.move_axis = 1.0
	hub.dash_held = true
	await _physics(40)
	var launch_speed: float = absf(r.velocity.x)
	check(launch_speed > Balance.RUNNER_RUN_SPEED,
		"a sprint is carrying more than walking speed (%.0f)" % launch_speed)
	hub.press_jump()
	hub.jump_held = true
	await _physics(4)
	hub.dash_held = false
	hub.move_axis = -1.0
	var reversed_after := -1.0
	var air_time := 0.0
	for _i in range(120):
		await get_tree().physics_frame
		air_time += Clock.DT
		if reversed_after < 0.0 and r.velocity.x < 0.0:
			reversed_after = air_time
		if r.is_on_floor():
			break
	hub.jump_held = false
	hub.move_axis = 0.0
	check(reversed_after > 0.0 and reversed_after <= 0.20,
		"opposite input reverses sprint momentum within 0.20s (%.3fs)" % reversed_after)

	# The ceiling. A head on it must end the rise there -- no clinging to it
	# while the button is still down, nothing added sideways.
	#
	# This is provided by move_and_slide's own collision response rather than by
	# anything in Runner: an explicit "zero the rise at a ceiling" block was
	# written here and turned out to change nothing, so it was deleted. The
	# checks stay, because the property is one the game depends on and the day
	# it stops being free is the day this needs to notice.
	await settle.call()
	var roof := StaticBody2D.new()
	roof.collision_layer = 1
	roof.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(400.0, 40.0)
	shape.shape = box
	roof.add_child(shape)
	# A block above the runner's head, well inside the jump's reach.
	roof.global_position = r.global_position + Vector2(0.0, -140.0)
	main.add_child(roof)
	await _physics(2)

	hub.move_axis = 0.0
	hub.press_jump()
	hub.jump_held = true
	var bonked := false
	var sideways := 0.0
	var stuck := 0
	for _i in range(70):
		await get_tree().physics_frame
		if r.is_on_ceiling():
			bonked = true
			sideways = maxf(sideways, absf(r.velocity.x))
			if r.velocity.y < -1.0:
				stuck += 1
		if bonked and r.is_on_floor():
			break
	hub.jump_held = false
	check(bonked, "the runner's head reaches the ceiling")
	check(stuck == 0,
		"and the rise stops there rather than pushing into it (%d frames of climb)"
			% stuck)
	check(sideways < 20.0,
		"without being thrown sideways (%.0fpx/s)" % sideways)
	check(r.is_on_floor(), "and they come back down")
	roof.queue_free()
	await _physics(2)

func _test_runner_arc() -> void:
	# The level's gaps are sized against these two numbers, so if the jump ever
	# drifts the stage silently becomes unfair. This is the guard on that.
	_current = "jump arc"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	# Well left of the spawn: flat, and clear of the pipe and block row, which
	# are solid now and would otherwise be measured instead of the jump.
	r.global_position = Vector2(-400, 300)
	r.velocity = Vector2.ZERO
	hub.move_axis = 0.0
	await _physics(30)
	check(r.is_on_floor(), "the runner settles on the ground")

	var start := r.global_position
	var apex := start.y
	var rose_for := 0.0
	var time_to_apex := 0.0
	hub.move_axis = 1.0
	hub.press_jump()
	for i in range(90):
		await get_tree().physics_frame
		rose_for += Clock.DT
		if r.global_position.y < apex:
			apex = r.global_position.y
			time_to_apex = rose_for
		if i > 4 and r.is_on_floor():
			break
	var height := start.y - apex
	var reach := r.global_position.x - start.x
	hub.move_axis = 0.0
	hub.release_jump()

	# The DESIGN is a height and a duration -- see the block at the top of
	# balance.gd -- so this checks a height and a duration. It used to check a
	# band of pixels somebody had written down after a previous tuning pass,
	# which is a record of what the jump was, not of what it is meant to be.
	check_range(height / Balance.B, 3.0, 3.5,
		"a held jump goes 3 to 3.5 blocks up (%.2fB)" % (height / Balance.B))
	# The band the apex easing actually produces. RUNNER_TIME_TO_APEX is still
	# 0.33 and is not what moved; the easing near the top is the difference,
	# and a test still asking for the pre-easing number would be asking for the
	# gravity to be put back.
	check_range(time_to_apex, 0.34, 0.39,
		"and gets there in 0.34-0.39s (%.3fs)" % time_to_apex)
	check(absf(height - Balance.RUNNER_JUMP_HEIGHT) < Balance.B * 0.35,
		"which is the height the dial asks for (%.0f asked, %.0f measured)"
			% [Balance.RUNNER_JUMP_HEIGHT, height])
	# Every gap in the stage is sized against this figure.
	check(reach < 380.0, "a plain jump cannot clear a platform-width gap")

	# A tap has to be a real jump. The cut used to compound every frame the
	# button was up, so a 40ms press -- what a thumb actually does -- produced a
	# 31px hop against a 46px-tall runner. Now the opening window cannot be cut.
	await _physics(30)
	r.global_position = Vector2(-1000, 300)
	r.velocity = Vector2.ZERO
	hub.move_axis = 0.0
	await _physics(30)
	var floor_y := r.global_position.y
	var tap_apex := floor_y
	hub.press_jump()
	await _physics(3)          # ~50ms, then let go
	hub.release_jump()
	for i in range(90):
		await get_tree().physics_frame
		tap_apex = minf(tap_apex, r.global_position.y)
		if i > 4 and r.is_on_floor():
			break
	var tap_height := floor_y - tap_apex
	check(tap_height > Balance.RUNNER_SIZE.y * 1.5,
		"a 50ms tap clears more than the runner's own height (%.0fpx)" % tap_height)
	# The point of a variable jump is that the thumb picks the height. Too close
	# to the held one and there is no choice being made: at one tuning the two
	# came out 79% alike, because the uncuttable opening window covered half the
	# rise.
	check_range(tap_height / height, 0.45, 0.60,
		"and is 45-60%% of a held one, so the press chooses the height (%d%%)"
			% int(100.0 * tap_height / height))
	# Printed because these two numbers are quoted in the docs, and a doc that
	# quotes a number nothing measures goes stale without anyone noticing.
	print("  jump apex: 50ms tap %.0fpx, held %.0fpx (runner is %.0fpx tall), reach %.0fpx"
		% [tap_height, height, Balance.RUNNER_SIZE.y, reach])

	# The stage audit needs the sprinting arcs too, and it needs them measured.
	var sprint_arc := await _measure_arc(true, false)
	var repeat_arc := await _measure_arc(true, true)
	_reach = {
		"plain": reach,
		"apex": height,
		"sprint": sprint_arc["reach"],
		"unaided": maxf(sprint_arc["reach"], repeat_arc["reach"]),
	}
	check(float(_reach["sprint"]) > reach,
		"sprinting jumps further than walking (%.0f vs %.0f)" % [_reach["sprint"], reach])
	print("  jump reach: walk %.0fpx, sprint %.0fpx, sprint re-pressed in air %.0fpx"
		% [reach, sprint_arc["reach"], repeat_arc["reach"]])
	var double_arc := await _measure_arc(true, false, true)
	_reach["double"] = double_arc["reach"]
	_reach["double_apex"] = double_arc["apex"]
	check(float(double_arc["reach"]) > float(sprint_arc["reach"]),
		"a second jump at the apex carries further (%.0f vs %.0f)"
			% [double_arc["reach"], sprint_arc["reach"]])
	print("  double jump: sprint reach %.0fpx, apex %.0fpx"
		% [double_arc["reach"], double_arc["apex"]])
	# The same after a run-up long enough for second gear: the furthest a
	# runner gets alone, given about two seconds of flat ground to build it.
	var top_arc := await _measure_arc(true, false, true, 150)
	_reach["double_top"] = top_arc["reach"]
	check(float(top_arc["reach"]) > float(double_arc["reach"]),
		"second gear carries a double jump further (%.0f vs %.0f)"
			% [top_arc["reach"], double_arc["reach"]])
	print("  double jump in second gear: reach %.0fpx, apex %.0fpx"
		% [top_arc["reach"], top_arc["apex"]])

## Jumping again in mid-air: once per jump, slightly lower than a jump from the
## ground, refilled by landing -- and never handed to a runner who only walked
## off an edge or was thrown by a spring.
func _test_double_jump() -> void:
	_current = "double jump"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	r.global_position = Vector2(-400, 300)
	r.velocity = Vector2.ZERO
	hub.move_axis = 0.0
	hub.release_jump()
	await _physics(30)
	check(r.is_on_floor() and r.air_jumps_left() == 0, "standing, there is no air jump to spend")
	var floor_y := r.global_position.y
	hub.press_jump()
	await _physics(2)
	check(r.air_jumps_left() == Balance.RUNNER_AIR_JUMPS, "a jump from the ground grants one air jump")
	# Ride the first jump to its top, then jump again.
	while r.velocity.y < 0.0:
		await get_tree().physics_frame
	var first_top := r.global_position.y
	hub.release_jump()
	await _physics(1)
	hub.press_jump()
	await _physics(2)
	check(r.velocity.y < 0.0 and r.air_jumps_left() == 0, "pressing again in mid-air jumps again")
	var top := r.global_position.y
	for i in range(90):
		await get_tree().physics_frame
		top = minf(top, r.global_position.y)
		if r.velocity.y >= 0.0:
			break
	var second_rise := first_top - top
	check_range(second_rise / Balance.RUNNER_AIR_JUMP_HEIGHT, 0.85, 1.15,
		"and the second jump rises about RUNNER_AIR_JUMP_HEIGHT (%.0fpx)" % second_rise)
	check(floor_y - top > Balance.RUNNER_JUMP_HEIGHT * 1.5,
		"two jumps go well above one (%.0fpx)" % (floor_y - top))
	# A third press does nothing.
	hub.release_jump()
	await _physics(1)
	var falling_before := r.velocity.y
	hub.press_jump()
	await _physics(2)
	check(r.velocity.y >= falling_before, "a third press in mid-air does nothing")
	hub.release_jump()
	for i in range(180):
		await get_tree().physics_frame
		if r.is_on_floor():
			break
	await _physics(2)
	check(r.is_on_floor() and r.air_jumps_left() == 0, "landing takes the unspent air jump away")
	hub.press_jump()
	await _physics(2)
	check(r.air_jumps_left() == Balance.RUNNER_AIR_JUMPS, "and the next jump grants it again")
	hub.release_jump()
	await _physics(90)
	# Thrown by a spring: no air jump of the runner's own.
	r.launch(Runner.launch_velocity(1))
	await _physics(3)
	var thrown := r.velocity.y
	hub.press_jump()
	await _physics(2)
	check(r.air_jumps_left() == 0 and r.velocity.y >= thrown, "a launch does not grant an air jump")
	hub.release_jump()
	await _physics(120)

## A tapped jump into a column of rising air. The release gravity that cuts a
## tapped jump short stops at zero rather than pushing down, so if it outlived
## the jump the column and the release would cancel out every tick and leave
## the runner hanging in the air instead of rising.
func _test_updraft_after_tapped_jump() -> void:
	_current = "updraft after a tapped jump"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	r.global_position = Vector2(-400, 300)
	r.velocity = Vector2.ZERO
	hub.move_axis = 0.0
	hub.release_jump()
	await _physics(30)
	var floor_y := r.global_position.y
	var column := Updraft.new()
	column.runner = r
	column.span = Vector2(180.0, 700.0)
	column.global_position = Vector2(r.global_position.x, floor_y - 60.0)
	main.level.add_child(column)
	await _physics(2)
	hub.press_jump()
	await _physics(4)
	hub.release_jump()
	await _physics(70)
	check(floor_y - r.global_position.y > Balance.RUNNER_JUMP_HEIGHT * 2.0,
		"the column carries a tapped jump up (%.0fpx)" % (floor_y - r.global_position.y))
	check(r.velocity.y < -Balance.UPDRAFT_RISE * 0.5,
		"and is still lifting it (%.0f px/s)" % r.velocity.y)
	column.queue_free()
	await _physics(90)

func _test_dash() -> void:
	_current = "sprint"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	# Far left of the start plateau: a held sprint covers well over a thousand
	# pixels during this test, and from nearer the middle it runs off the edge.
	r.global_position = Vector2(-1450, 300)
	r.velocity = Vector2.ZERO
	await _physics(30)

	# Walking speed first, so the sprint has something to be measured against.
	hub.move_axis = 1.0
	hub.dash_held = false
	await _physics(40)
	var walk := absf(r.velocity.x)
	check_near(walk, Balance.RUNNER_RUN_SPEED, 40.0, "walking tops out at the run speed")

	# Sprint is a held modifier: it must keep going for as long as it is held,
	# with no cooldown and no time limit. The old burst dash lasted 0.16s, so a
	# long hold is the thing worth checking.
	hub.dash_held = true
	await _physics(50)
	var sprint := absf(r.velocity.x)
	var expected := Balance.RUNNER_RUN_SPEED * Balance.RUNNER_SPRINT_MULTIPLIER
	check_near(sprint, expected, 45.0, "sprint reaches the multiplied speed")
	# Not long enough for second gear (_test_top_gear), which is a separate step.
	await _physics(40)
	check_near(absf(r.velocity.x), expected, 45.0, "sprint does not expire while held")
	check(r.is_on_floor(), "still grounded, so this is the sustained sprint path")

	# Releasing eases back to the walk rather than snapping.
	hub.dash_held = false
	await _physics(60)
	check_near(absf(r.velocity.x), Balance.RUNNER_RUN_SPEED, 40.0, "releasing returns to walk")
	hub.move_axis = 0.0

	# Re-pressing sprint in the air accelerates horizontally without stopping Y.
	await _wait(0.3)
	r.global_position = Vector2(-400, 60)
	r.velocity = Vector2(0.0, 100.0)
	hub.move_axis = 1.0
	await _physics(2)
	check(not r.is_on_floor(), "airborne for the sprint check")
	hub.press_dash()
	await _physics(2)
	check(r.state != Runner.State.DASH, "airborne sprint is not a burst state")
	check(r.velocity.y > 100.0, "sprint never zeros the fall")

	# Holding sprint on the ground is the same sustained modifier.
	hub.dash_held = true
	r.global_position = Vector2(-400, 300)
	r.velocity = Vector2.ZERO
	await _physics(40)
	check(r.state != Runner.State.DASH, "a held sprint on the ground is not a dash state")
	hub.dash_held = false
	hub.move_axis = 0.0

## Second gear: a long flat-out run on the ground earns one more step of speed,
## and anything that breaks the run takes it away again.
func _test_top_gear() -> void:
	_current = "second gear"
	var sprint := Runner.sprint_cap()
	var top := Runner.sprint_cap(1.0)
	check_near(top / sprint, Balance.RUNNER_TOP_GEAR_MULTIPLIER, 0.001,
		"second gear raises the sprint cap by its multiplier")
	check_near(Runner.ground_target(1.0, false, 1.0), Balance.RUNNER_RUN_SPEED, 0.01,
		"walking never gets second gear")
	var vx := sprint
	for i in range(60):
		vx = Runner.ground_step(vx, 1.0, true, 1.0 / 60.0, 1.0)
	check_near(vx, top, 1.0, "in second gear the ground step reaches the higher cap")
	check(absf(Runner.ground_jump_height(top) - Runner.ground_jump_height(sprint)) < 0.01,
		"second gear adds no jump height, only distance")

	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	r.global_position = Vector2(-1450, 300)
	r.velocity = Vector2.ZERO
	await _physics(30)
	hub.move_axis = 1.0
	hub.dash_held = true
	var engaged_at := -1
	var peak := 0.0
	for i in range(150):
		await get_tree().physics_frame
		if engaged_at < 0 and r.gear > 0.0:
			engaged_at = i
		peak = maxf(peak, absf(r.velocity.x))
		if not r.is_on_floor():
			break
	print("  second gear: engaged at frame %d, peak %.0f, x=%.0f, floor=%s" % [
		engaged_at, peak, r.global_position.x, r.is_on_floor()])
	var delay_frames := int(Balance.RUNNER_TOP_GEAR_DELAY * 60.0)
	check(engaged_at >= delay_frames, "no second gear before %.1fs at full sprint (frame %d)"
		% [Balance.RUNNER_TOP_GEAR_DELAY, engaged_at])
	check(engaged_at > 0 and engaged_at <= delay_frames + 30,
		"second gear arrives soon after the delay")
	check_near(peak, top, 20.0, "the runner reaches the second-gear speed")
	# A jump keeps it; a turn drops it.
	hub.press_jump()
	await _physics(10)
	check(not r.is_on_floor() and r.gear > 0.9, "a jump keeps second gear")
	check(absf(r.velocity.x) > sprint + 30.0, "and carries the extra speed into the air")
	hub.release_jump()
	hub.move_axis = -1.0
	await _physics(2)
	check(r.gear == 0.0, "turning round drops second gear")
	hub.move_axis = 0.0
	hub.dash_held = false

func _test_stomp_and_damage() -> void:
	_current = "contact"
	await _boot()
	var r: Runner = main.runner
	check(r.hp == Balance.RUNNER_MAX_HP, "the runner starts at full health")

	# Landing on a walker is not an attack. Every enemy contact is a hit, from
	# directly above as much as from the side -- see Runner._resolve_hazard. The
	# rifle is what kills things, and a runner who can clear a patrol by falling
	# on it does not need to ask anybody for one.
	var walker := Walker.new()
	walker.global_position = Vector2(-400, 300)
	main.add_child(walker)
	await _physics(20)
	r.global_position = walker.global_position + Vector2(0, -46)
	r.velocity = Vector2(0, 260)
	await _physics(20)
	check(is_instance_valid(walker), "landing on a walker does not kill it")
	check(r.hp == Balance.RUNNER_MAX_HP - 1, "and costs the runner health")
	check(r.is_invulnerable(), "so it reads as a hit, with the usual mercy window")
	walker.queue_free()

	# A flyer is not stompable either, and never was: chapter 2 keeps one threat
	# the runner cannot answer alone, and this is it.
	var flyer := Flyer.new()
	check(not flyer.is_in_group("stompable"), "the flyer is not stompable")
	flyer.free()

	# Damage and the mercy window on their own. The contact above leaves the
	# runner invulnerable for RUNNER_HURT_INVULN, so this waits that out rather
	# than measuring it through the tail of the hit before it.
	await _wait(Balance.RUNNER_HURT_INVULN + 0.1)
	r.hp = Balance.RUNNER_MAX_HP
	var before := r.hp
	r.take_damage(1)
	check(r.hp == before - 1, "damage lands")
	r.take_damage(1)
	check(r.hp == before - 1, "invulnerability absorbs the follow-up")

func _test_checkpoint_respawn() -> void:
	_current = "checkpoint"
	await _boot()
	var r: Runner = main.runner
	var points := Level01Data.checkpoints()
	check(points.size() >= 5, "the stage has at least five checkpoints")

	GameState.checkpoint_index = 2
	GameState.checkpoint_position = points[1]
	r.hp = 1
	r.die("test")
	await _frames(2)
	check(r.state == Runner.State.DEAD, "death is registered")

	# Retry must be quick -- chapter 3 asks for under three seconds.
	check(Balance.RESPAWN_DELAY < 3.0, "respawn delay is inside the design budget")
	await _wait(Balance.RESPAWN_DELAY + 0.25)
	check(r.hp == Balance.RUNNER_MAX_HP, "respawn restores health")
	check(r.global_position.distance_to(points[1]) < 60.0, "respawn lands at the checkpoint")
	check(main.guardian.holograms_of(Hologram.Kind.PLATFORM).is_empty(),
		"constructs do not survive a reset")

## Two hits and the run is over.
##
## The number itself is one line of balance, but it only means anything if the
## hit actually lands both times and the second one ends the run -- and the
## invulnerability window after the first is exactly the thing that can quietly
## swallow the second. So this drives real damage through the runner rather
## than asserting the constant.
func _test_two_hits_end_the_run() -> void:
	_current = "two hits"
	await _boot()
	var r: Runner = main.runner
	check(Balance.RUNNER_MAX_HP == 2, "the runner has two hits in them")

	r.global_position = Vector2(2600, 300)
	await _frames(3)
	var died := [0]
	var watch := func(_cause: String) -> void: died[0] += 1
	Events.runner_died.connect(watch)

	r.take_damage(1)
	check(r.hp == 1, "the first hit leaves one (%d)" % r.hp)
	check(died[0] == 0, "and does not end the run")
	check(r.is_invulnerable(), "it opens the mercy window")

	# Inside the window a second hit must NOT count -- otherwise a turret burst
	# kills on the frame it touches and the window may as well not exist.
	r.take_damage(1)
	check(r.hp == 1, "a hit inside the mercy window is ignored (%d)" % r.hp)

	await _wait(Balance.RUNNER_HURT_INVULN + 0.1)
	check(not r.is_invulnerable(), "the window closes")
	r.take_damage(1)
	check(r.hp == 0, "the second real hit takes the last of it")
	check(died[0] == 1, "and ends the run")
	check(r.state == Runner.State.DEAD, "the runner is dead, not merely hurt")

	# The plate has to be up while the retry is waiting, and gone after it.
	check(main.hud.game_over() > 0.0, "GAME OVER is on screen")
	check(Balance.RESPAWN_DELAY < 3.0,
		"and the retry still lands inside the three-second budget (%.2fs)"
			% Balance.RESPAWN_DELAY)
	await _wait(Balance.RESPAWN_DELAY + 0.35)
	check(main.hud.game_over() <= 0.0, "the plate lifts when the retry begins")
	check(r.hp == Balance.RUNNER_MAX_HP,
		"and the runner comes back with both hits again (%d)" % r.hp)
	Events.runner_died.disconnect(watch)

func _test_the_catch_is_graded() -> void:
	_current = "rescue grading"
	await _boot()

	# Late: the slab arrives just above them.
	var late := await _catch(-200.0, 0.30, 120.0)
	check(late["landed"], "the runner lands on the platform placed under them")
	check_range(float(late["age"]), 0.0, float(Balance.RESCUE_TIERS[2]),
		"a slab placed 120px under a falling runner is landed on within the top window")
	check(int(late["tier"]) == 3, "the latest catch scores PERFECT (got %d)" % late["tier"])
	check_near(float(late["refund"]), float(Balance.RESCUE_REFUND[3]), 0.6,
		"a PERFECT catch refunds its tier's gauge")

	# Middling.
	var mid := await _catch(-200.0, 0.30, 560.0)
	check_range(float(mid["age"]), float(Balance.RESCUE_TIERS[2]),
		float(Balance.RESCUE_TIERS[1]),
		"a slab 560px down is reached in the middle window")
	check(int(mid["tier"]) == 2, "the middling catch scores GREAT (got %d)" % mid["tier"])
	check_near(float(mid["refund"]), float(Balance.RESCUE_REFUND[2]), 0.6,
		"a GREAT catch refunds its tier's gauge")

	# Early, but still a catch: 1250px is inside PLACE_MAX_RANGE, and at terminal
	# velocity that is over a second of falling.
	var early := await _catch(-900.0, 0.30, 1250.0)
	check_range(float(early["age"]), float(Balance.RESCUE_TIERS[1]),
		float(Balance.RESCUE_TIERS[0]),
		"a slab 1250px down is reached in the bottom window")
	check(int(early["tier"]) == 1, "the early catch still scores NICE (got %d)" % early["tier"])
	check_near(float(early["refund"]), float(Balance.RESCUE_REFUND[1]), 0.6,
		"a NICE catch refunds its tier's gauge")

	check(float(Balance.RESCUE_REFUND[3]) > float(Balance.RESCUE_REFUND[1]),
		"leaving it later is worth more gauge, or the grade rewards nothing")

	# A drop too short to be a rescue. The age here is inside the PERFECT window,
	# so the only thing keeping it from scoring is RESCUE_MIN_FALL -- which is
	# the check that stops the runner farming grades by hopping on and off a
	# slab the guardian left lying about.
	var hop := await _catch(-200.0, 0.0, 53.0)
	check(hop["landed"], "the short drop still lands on the platform")
	check(float(hop["impact"]) < Balance.RESCUE_MIN_FALL,
		"the short drop is below the rescue threshold (%.0f)" % hop["impact"])
	check_range(float(hop["age"]), 0.0, float(Balance.RESCUE_TIERS[2]),
		"...and it is not the platform's age that disqualifies it")
	check(int(hop["tier"]) == 0, "stepping onto a slab is not a rescue")
	check_near(float(hop["refund"]), 0.0, 0.6, "and it refunds nothing")

	# A slab that has been lying there is not a catch either, however hard the
	# runner hits it.
	var stale := await _catch(-200.0, 0.30, 400.0, 2.0)
	check(stale["landed"], "the runner lands on the aged platform")
	check(float(stale["impact"]) >= Balance.RESCUE_MIN_FALL,
		"the fall onto the aged platform is a real fall (%.0f)" % stale["impact"])
	check(float(stale["age"]) > float(Balance.RESCUE_TIERS[0]),
		"the platform is older than the widest window (%.2fs)" % stale["age"])
	check(int(stale["tier"]) == 0, "an old slab scores nothing")

	# The grade is read off placed_tick, not birth_tick. HostSession moves
	# birth_tick into the past to compensate for the guardian's latency; if the
	# grade followed it, a guardian on a bad line would be marked down for lag
	# the host had already forgiven. Backdated by 1.5s, this would grade NICE
	# instead of PERFECT.
	var lagged := await _catch(-200.0, 0.30, 120.0, 0.0, 90)
	check(int(lagged["birth_age_ticks"]) >= 90,
		"the construct really was backdated (%d ticks)" % lagged["birth_age_ticks"])
	check(int(lagged["tier"]) == 3,
		"a backdated construct is graded on when the guardian pressed, not on its birth tick (got %d)"
			% lagged["tier"])

	# What the clear screen reports.
	check(GameState.rescue_tiers[3] > 0 and GameState.rescue_tiers[2] > 0
			and GameState.rescue_tiers[1] > 0,
		"every grade reached the run summary")
	check(GameState.best_catch().begins_with(Balance.RESCUE_NAMES[3]),
		"the summary reports the best catch of the run (got '%s')" % GameState.best_catch())

## Three seconds on the edge, which is three seconds for the other player.
func _test_the_runner_can_catch_an_edge() -> void:
	_current = "ledge"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	main._respawn_timer = -1.0
	# The block hangs in 1-1's sky, where the crows patrol: one flying into the
	# hanging runner knocks them off mid-test. Stop the stage's enemies, as the
	# game does once a stage is cleared.
	for e in get_tree().get_nodes_in_group("enemy"):
		(e as Node).process_mode = Node.PROCESS_MODE_DISABLED

	# A block with a clear top, in open air, on the terrain layer -- the only
	# layer an edge is looked for on.
	var block := StaticBody2D.new()
	block.collision_layer = 1
	block.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(180.0, 240.0)
	shape.shape = box
	block.add_child(shape)
	block.global_position = Vector2(2600.0, 120.0)
	main.add_child(block)
	await _physics(2)

	var lip: float = block.global_position.y - 120.0
	var grabs := [0]
	var watch := func(_at: Vector2) -> void: grabs[0] += 1
	Events.runner_grabbed_ledge.connect(watch)

	var caught := await _fall_past_the_edge(r, hub, block, lip)
	check(caught, "falling past the edge catches it")
	check(r.hanging(), "the runner is hanging")
	check(r.grip_left() > 0.8, "with a full grip (%.2f)" % r.grip_left())
	check(r.velocity.is_zero_approx(), "and is not moving")

	# It runs out. In physics frames, not real seconds: the grip is game time,
	# and headless runs physics uncapped, so a real second is many game ones.
	var tps := Engine.physics_ticks_per_second
	await _physics(int(Balance.LEDGE_HANG_TIME * 0.5 * tps))
	var half := r.grip_left()
	check(half < 0.7 and half > 0.2, "the grip runs down (%.2f)" % half)
	await _physics(int(Balance.LEDGE_HANG_TIME * 0.6 * tps))
	check(not r.hanging(), "and lets go when it is gone")

	# Jumping off it works, and the same edge does not give a second rest.
	r.global_position = Vector2(2600.0, 300.0)
	r.velocity = Vector2.ZERO
	await _physics(20)
	var again := await _fall_past_the_edge(r, hub, block, lip)
	check(again, "the edge can be caught again after touching the ground")
	if again:
		var height := r.global_position.y
		hub.press_jump()
		await _physics(6)
		check(not r.hanging(), "pressing jump leaves the edge")
		check(r.global_position.y < height, "upwards (%.0fpx)" % (height - r.global_position.y))

	# Letting go and catching the same lip again is not an infinite rest.
	var before: int = grabs[0]
	var third := await _fall_past_the_edge(r, hub, block, lip)
	check(not third or grabs[0] == before,
		"the same edge does not catch twice without touching down")

	Events.runner_grabbed_ledge.disconnect(watch)
	hub.move_axis = 0.0
	block.queue_free()
	await _frames(2)

## Auto-dash gives the sprint away, and the brief asks what that costs.
##
## It costs stopping distance: a runner who is always at top speed needs longer
## to stop, and the narrow places are exactly where that matters. So this checks
## both halves -- that it works, and that it does not quietly make a one-block
## perch impossible to stand on.
func _test_auto_dash_is_a_real_choice() -> void:
	_current = "auto dash"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	main._respawn_timer = -1.0
	Options.forget()

	var run_to_speed := func() -> float:
		r.global_position = Vector2(-400, 300)
		r.velocity = Vector2.ZERO
		hub.move_axis = 0.0
		hub.dash_held = false
		for _i in range(40):
			await get_tree().physics_frame
			if r.is_on_floor():
				break
		hub.move_axis = 1.0
		await _physics(60)
		return absf(r.velocity.x)

	check(not Options.auto_dash(), "it is off by default")
	var held_off: float = await run_to_speed.call()
	check(absf(held_off - Balance.RUNNER_RUN_SPEED) < 12.0,
		"and without it, holding nothing walks (%.0f)" % held_off)

	Options.set_auto_dash(true)
	var auto_on: float = await run_to_speed.call()
	check(auto_on > Balance.RUNNER_RUN_SPEED * 1.3,
		"with it on, moving is sprinting without holding anything (%.0f)" % auto_on)

	# The cost, measured: how far past letting go does the runner travel? If
	# that is more than a block, a one-block perch is not somewhere you can
	# stand, and the setting has quietly made the game harder in a place the
	# player cannot see.
	hub.move_axis = 0.0
	var from := r.global_position.x
	for _i in range(60):
		await get_tree().physics_frame
		if absf(r.velocity.x) < 1.0:
			break
	var ran_on: float = absf(r.global_position.x - from)
	check(ran_on < Balance.B,
		"and stopping still fits inside one block (%.0fpx of %.0f)"
			% [ran_on, Balance.B])

	# Survives being written and read back, which is what a setting means.
	Options.reload()
	check(Options.auto_dash(), "the setting is remembered")
	Options.set_auto_dash(false)
	Options.reload()
	check(not Options.auto_dash(), "and can be turned back off")
	hub.move_axis = 0.0
