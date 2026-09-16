extends Node
## Does hiding half the stage from one player leave the game intact?
##
## The first check is the one the whole asymmetric design rests on, and it is
## worth more than all the others put together: the same input, replayed once
## through runner eyes and once through guardian eyes, has to move the runner to
## exactly the same places. If a veil can change the simulation then the two
## players are not in the same world any more, and every other guarantee in the
## netcode is worth nothing. Everything below it is detail.
##
##   godot --headless --path . --fixed-fps 60 res://test/veil_probe.tscn

## Preloaded rather than reached by class_name, the way Stage reaches it. The
## stage data scripts that came after the global class cache started biting
## deliberately do without one.
const LevelQuiet = preload("res://src/levels/level_quiet_data.gd")

var main: Node2D = null
var failures: int = 0
var checks: int = 0
var _finished: bool = false

var _runner: Runner = null
var _hub: InputHub = null
var _field: VeilField = null

func _ready() -> void:
	print("== what one player cannot see ==")
	await _the_physics_is_the_same_either_way()
	await _the_ground_is_hidden_but_still_there()
	await _the_moving_things_are_hidden()
	await _a_failure_shows_what_was_there()
	await _the_sigils_face_opposite_ways()
	await _the_stage_can_be_finished()
	_finished = true

	Veil.force_eye("")
	print("")
	if not _finished:
		failures += 1
		checks += 1
		print("  FAIL  the probe ran to the end (it stopped early)")
	if failures == 0:
		print("nothing leaks (%d checks)" % checks)
	else:
		print("%d of %d checks FAILED" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ harness

func _ok(label: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("  ok    ", label)
	else:
		failures += 1
		print("  FAIL  ", label, "" if detail.is_empty() else "  -- " + detail)

func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame

func _physics(n: int) -> void:
	for _i in range(n):
		await get_tree().physics_frame

## A fresh 1-V, seen through one player's eyes.
func _world(eye: String) -> void:
	if main != null and is_instance_valid(main):
		main.free()
		await _frames(2)
	Veil.force_eye(eye)
	Stage.use(Stage.Which.QUIET)
	GameState.reset_run(Stage.start())
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(6)
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
		await _frames(2)
	main.input_hub.scripted = true
	main._respawn_timer = -1.0
	_runner = main.runner
	_hub = main.input_hub
	_field = main.level.veil_field()

func _stand_at(x: float, y: float) -> void:
	main._respawn_timer = -1.0
	_hub.move_axis = 0.0
	_hub.dash_held = false
	_hub.release_jump()
	_runner.respawn(Vector2(x, y))
	for _i in range(60):
		await get_tree().physics_frame
		if _runner.is_on_floor():
			break
	# Again, after the settle. A fall left over from the case before can land
	# inside these frames, and a respawn timer that fires mid-case teleports the
	# runner to a checkpoint in the middle of a measurement.
	main._respawn_timer = -1.0

## Everything in the stage that a veil is meant to act on, by layer.
func _nodes_for(layer: String) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if layer == Veil.ENEMIES:
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Node2D:
				out.append(e)
	return out

# ------------------------------------------------------- the one that matters

## The same run, twice, with the veils closed to different people.
##
## Nothing here is about drawing. It is about whether `visible = false` -- which
## is all a veil ever does -- can reach the simulation. It must not, and this is
## how we keep finding out that it still does not.
func _the_physics_is_the_same_either_way() -> void:
	var blind := await _replay("runner")
	var seeing := await _replay("guardian")
	var a: Array = blind["path"]
	var b: Array = seeing["path"]
	_ok("the two points of view ran the same number of frames",
		a.size() == b.size(), "%d vs %d" % [a.size(), b.size()])
	var worst := 0.0
	var n: int = mini(a.size(), b.size())
	for i in range(n):
		worst = maxf(worst, (Vector2(a[i]) - Vector2(b[i])).length())
	_ok("and put the runner in the same place on every one of them (%.5fpx)" % worst,
		n > 0 and worst < 0.001)
	# ...and that the run was worth comparing at all. Both of them have to have
	# stood on the platform that one of them was never shown.
	_ok("and both of them stood on ground one of them could not see",
		bool(blind["stood_on_hidden"]) and bool(seeing["stood_on_hidden"]))

## A scripted crossing of beat 1: run, jump, land -- through real physics, with
## the hidden platform doing the catching.
func _replay(eye: String) -> Dictionary:
	await _world(eye)
	await _stand_at(200.0, LevelQuiet.FLOOR - 60.0)
	var path: Array = []
	var stood_on_hidden := false
	_hub.move_axis = 1.0
	_hub.dash_held = true
	for i in range(150):
		await get_tree().physics_frame
		# Pressed at a fixed FRAME and never at a place. A position trigger
		# would be circular here: if the two runs diverged, the trigger would
		# diverge with them and hide exactly what this is looking for. The
		# frame is chosen so the jump leaves the lip and lands on ground the
		# runner cannot see, which is the collision that matters most.
		if i == 61:
			_hub.press_jump()
		if i == 81:
			_hub.release_jump()
		path.append(_runner.global_position)
		if _runner.is_on_floor() and _runner.global_position.x > 760.0 \
				and _runner.global_position.x < 940.0 \
				and _runner.global_position.y < 320.0:
			stood_on_hidden = true
	_hub.move_axis = 0.0
	_hub.dash_held = false
	_hub.release_jump()
	return {"path": path, "stood_on_hidden": stood_on_hidden}

# ----------------------------------------------------------------- the ground

func _the_ground_is_hidden_but_still_there() -> void:
	await _world("runner")
	var all_slabs := Stage.ground().size()
	var painted := _field.drawn_slabs().size()
	_ok("the runner is not painted every slab (%d of %d)" % [painted, all_slabs],
		painted < all_slabs)
	# The collision bodies are built from Stage.ground() and never from the
	# filtered list. If that ever stops being true, this is where it shows.
	_ok("but the stage still has all of them to collide with",
		Stage.ground().size() == all_slabs)

	# The hidden platform in beat 1, by the numbers in the stage data.
	var hidden_top := Vector2(850.0, 330.0)
	_ok("the first step is hidden from the runner",
		_field.hides(Veil.TERRAIN, hidden_top))
	_ok("and the ledge under it is not",
		not _field.hides(Veil.TERRAIN, Vector2(850.0, LevelQuiet.LEDGE)))
	_ok("and neither is the ground they are standing on",
		not _field.hides(Veil.TERRAIN, Vector2(200.0, LevelQuiet.FLOOR)))

	# Landing on something you cannot see is the whole beat, so it has to work.
	await _stand_at(200.0, LevelQuiet.FLOOR - 60.0)
	var landed_on_air := await _cross(560.0, 760.0, 340.0)
	_ok("and a runner who cannot see it still lands on it", landed_on_air, _where())

	await _world("guardian")
	_ok("the guardian is painted every slab",
		_field.drawn_slabs().size() == Stage.ground().size())
	_ok("and nothing is hidden from them",
		not _field.hides(Veil.TERRAIN, Vector2(850.0, 330.0)))

# --------------------------------------------------------- the moving things

func _the_moving_things_are_hidden() -> void:
	await _world("runner")
	await _physics(4)
	var enemies := _nodes_for(Veil.ENEMIES)
	_ok("the stage has patrols in it (%d)" % enemies.size(), enemies.size() >= 2)
	var seen := 0
	for e in enemies:
		if e.is_visible_in_tree():
			seen += 1
	_ok("and the runner is shown none of them (%d visible)" % seen, seen == 0)

	# They are still there. Standing in one is still a hit.
	var walker: Node2D = enemies[0]
	await _stand_at(walker.global_position.x - 60.0, walker.global_position.y - 80.0)
	# respawn() hands out RUNNER_HURT_INVULN of mercy, which would absorb the
	# very thing being measured.
	_runner._invuln = 0.0
	var before := _runner.hp
	_runner.global_position = walker.global_position
	for _i in range(20):
		await get_tree().physics_frame
		if _runner.hp < before:
			break
	_ok("but standing in one still hurts (%d -> %d)" % [before, _runner.hp],
		_runner.hp < before)

	await _world("guardian")
	await _physics(4)
	var shown := 0
	for e in _nodes_for(Veil.ENEMIES):
		if e.is_visible_in_tree():
			shown += 1
	_ok("the guardian is shown all of them (%d)" % shown, shown >= 2)

# ---------------------------------------------------------------- the reveal

func _a_failure_shows_what_was_there() -> void:
	await _world("runner")
	_ok("nothing is revealed to begin with", not _field.revealing())
	_ok("and the first step is hidden",
		_field.hides(Veil.TERRAIN, Vector2(850.0, 330.0)))
	_runner.die("probe")
	await _frames(2)
	_ok("dying lifts the veil", _field.revealing())
	_ok("and the step is there to be seen",
		not _field.hides(Veil.TERRAIN, Vector2(850.0, 330.0)))
	_ok("and the ground is painted again while it lasts",
		_field.drawn_slabs().size() == Stage.ground().size())
	# It is a moment, not a mode.
	for _i in range(int((VeilField.REVEAL_TIME + 0.4) * 60.0)):
		await get_tree().process_frame
	_ok("and then it closes again", not _field.revealing())
	_ok("with the step hidden once more",
		_field.hides(Veil.TERRAIN, Vector2(850.0, 330.0)))

# ---------------------------------------------------------------- the sigils

func _the_sigils_face_opposite_ways() -> void:
	await _world("runner")
	var switches := get_tree().get_nodes_in_group("switch")
	var gates := get_tree().get_nodes_in_group("gate")
	_ok("the gate has switches to choose between (%d)" % switches.size(),
		switches.size() >= 3)
	_ok("and the gate asks for one of them", gates.size() >= 1 \
		and (gates[0] as Gate).wants > 0)
	_ok("the runner may read the marks on the switches",
		Sigil.shown_to(Veil.RUNNER))
	_ok("and may not read what the gate wants",
		not Sigil.shown_to(Veil.GUARDIAN))

	# Wrong one: nothing opens, and everything goes quiet for a moment.
	var gate: Gate = gates[0]
	var wrong: ShootableSwitch = null
	var right: ShootableSwitch = null
	for sw in switches:
		if sw is ShootableSwitch:
			if (sw as ShootableSwitch).sigil == gate.wants:
				right = sw
			else:
				wrong = sw
	_ok("there is a right switch and a wrong one",
		right != null and wrong != null)
	if right == null or wrong == null:
		return
	wrong.take_damage(2, "snipe")
	await _frames(2)
	_ok("shooting the wrong mark does not open the gate", not wrong.active)
	_ok("and locks the right one out for a moment", right.locked())
	right.take_damage(2, "snipe")
	await _frames(2)
	_ok("so the right one does nothing while the lockout runs", not right.active)
	for _i in range(int((ShootableSwitch.WRONG_LOCKOUT + 0.3) * 60.0)):
		await get_tree().process_frame
	_ok("and works once it has passed", not right.locked())
	right.take_damage(2, "snipe")
	await _frames(2)
	_ok("opening the gate", right.active)

	await _world("guardian")
	_ok("the guardian may read what the gate wants",
		Sigil.shown_to(Veil.GUARDIAN))
	_ok("and may not read the marks on the switches",
		not Sigil.shown_to(Veil.RUNNER))

# ------------------------------------------------------------- is it possible

## An autopilot that knows everything gets to the gate. Not a claim that the
## stage is fun -- only that it is not impossible, which no amount of playtesting
## should have to discover for us.
func _the_stage_can_be_finished() -> void:
	await _world("guardian")
	# Watched across the whole run rather than at the end, because the last jump
	# lands more or less on the gate: the stage finishes itself as the runner
	# arrives, and a check that waited until afterwards to go looking for the
	# gate would be looking for something that had already happened.
	#
	# In a one-element array because a lambda captures a bool by value, which is
	# what stage_probe's own watchers do and for the same reason.
	var reached := [false]
	var watch := func(_stats: Dictionary) -> void: reached[0] = true
	Events.stage_cleared.connect(watch)
	await _stand_at(200.0, LevelQuiet.FLOOR - 60.0)
	var crossed := await _cross(560.0, 760.0, 340.0)
	_ok("the first gap can be crossed", crossed, _where())
	# And from there, on to the far side.
	# And off the far end of it. The platform stops 180px short of the far
	# floor, which is another jump and not a walk.
	var over := await _cross(890.0, 1100.0, 360.0)
	_ok("and left on the far side of it", over, _where())

	# Past the gate, because the gate is beat 3's problem and this is beat 4's.
	await _stand_at(2540.0, LevelQuiet.MID - 60.0)
	var onto := await _cross(2650.0, 2860.0, 300.0)
	_ok("the last gap has something to land on", onto, _where())
	var last := await _cross(2950.0, 3120.0, 360.0)
	_ok("and it carries on to the far side", last, _where())

	# And if the last jump happened to stop short of it, the rest is a walk.
	if not reached[0]:
		_hub.move_axis = 1.0
		for _i in range(180):
			await get_tree().physics_frame
			if reached[0] or _runner.global_position.x > Stage.goal().x + 120.0:
				break
		_hub.move_axis = 0.0
	Events.stage_cleared.disconnect(watch)
	_ok("and the gate at the end is reached", bool(reached[0]), _where())

## Sprint right, take off once past `jump_x` (or never, for -1), and report
## whether the runner came to rest past `past_x` and above `above_y`.
##
## By position rather than by frame, unlike the identity replay above: here the
## question is whether the stage can be finished at all, and an autopilot that
## has to be told the frame number is answering a different one.
func _cross(jump_x: float, past_x: float, above_y: float) -> bool:
	_hub.move_axis = 1.0
	_hub.dash_held = true
	var made_it := false
	var jumped := jump_x < 0.0
	var airborne := jumped
	for _i in range(200):
		await get_tree().physics_frame
		if not jumped and _runner.is_on_floor() \
				and _runner.global_position.x >= jump_x:
			_hub.press_jump()
			jumped = true
		airborne = airborne or (jumped and not _runner.is_on_floor())
		if airborne and _runner.is_on_floor() \
				and _runner.global_position.x > past_x \
				and _runner.global_position.y < above_y:
			made_it = true
			break
	_hub.move_axis = 0.0
	_hub.dash_held = false
	_hub.release_jump()
	return made_it

func _where() -> String:
	return "x=%.0f y=%.0f" % [_runner.global_position.x, _runner.global_position.y]
