extends Node
## Can two people actually get through 1-C?
##
## Not "does it build" and not "are the numbers plausible" -- can a runner and a
## guardian, doing the things the stage is asking for, get from the start line
## to the gate. Every section is played here the way it is meant to be played,
## and a section that cannot be finished fails by name.
##
## The stage's design claims are checked first, against ARCS THIS FILE MEASURES
## rather than against arithmetic. That distinction earned its keep: the first
## version of this probe modelled a launch with one gravity constant and got
## 561px, the runner's own physics gave 349px, and the real answer -- after the
## bug that difference exposed was fixed -- is 679px. A closed form that skips
## air control is not a description of this game.
##
##   godot --headless --path . --fixed-fps 60 res://test/stage_probe.tscn

var main: Node2D = null
var failures: int = 0
var checks: int = 0

## Filled in by _measure_the_runner, consumed by everything after it.
##   solo_across / solo_up  a measured sprint jump (not an exhaustive solo-route search)
##   launch_flat            a launch landing back at the height it left
##   launch_120 / launch_200  a launch that has to land that much higher
var arc: Dictionary = {}

func _ready() -> void:
	Stage.use(Stage.Which.CROSSING)
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(6)
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
		await _frames(2)
	main.input_hub.scripted = true
	_runner = main.runner
	_guardian = main.guardian
	_hub = main.input_hub
	# Before anything is measured. The arcs at the top of this file are what
	# every claim below is compared against, and a black hole flying at the
	# runner while they are being measured shortens them: with it awake the
	# sprint jump read 269x136 instead of its real 301x193, and the stage was
	# then judged against a runner that does not exist.
	_park_the_pursuit()
	# And a frame for the physics server to notice. The black hole spawns 420px
	# behind the start, which is within a pixel or two of where the arc
	# measurement below puts the runner down -- and an Area2D's overlap list is
	# only rebuilt on the next physics step, so without this the runner was
	# teleported into a hole that had already been moved away, died on the
	# spot, and every arc after it was measured on a corpse.
	await _physics(4)

	print("== what the runner can actually do ==")
	await _measure_the_runner()

	print("")
	print("== the stage's own claims ==")
	_check_geometry()

	print("")
	print("== the thing that follows you ==")
	await _the_pursuit()

	print("")
	print("== playing it ==")
	_park_the_pursuit()
	await _play()

	print("")
	if failures == 0:
		print("1-C is playable (%d checks)" % checks)
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

# -------------------------------------------------------------- measurement

var _runner: Runner = null
var _guardian: Guardian = null
var _hub: InputHub = null

## Every arc the stage is sized against, flown by the real runner.
##
## Measured high above the level so no terrain is in the way: the question is
## what the physics allows, and a slab in the path would answer a different one.
func _measure_the_runner() -> void:
	main._respawn_timer = -1.0
	arc["solo_across"] = 0.0
	arc["solo_up"] = 0.0
	var solo := await _solo_arc()
	arc["solo_across"] = solo.x
	arc["solo_up"] = solo.y
	arc["launch_flat"] = await _launch_arc(0.0)
	arc["launch_120"] = await _launch_arc(120.0)
	arc["launch_200"] = await _launch_arc(200.0)
	print("  one player:  %.0fpx across, %.0fpx up" % [solo.x, solo.y])
	print("  a launch:    %.0fpx flat, %.0f landing 120 higher, %.0f landing 200 higher"
		% [arc["launch_flat"], arc["launch_120"], arc["launch_200"]])

## Measure a full-speed first jump. Triple-jump reach is measured separately.
func _solo_arc() -> Vector2:
	# On the ground, because a sprint needs the ground and the run-up is the
	# whole point. The opening plateau of 1-C is long and flat.
	_hub.release_jump()
	_hub.move_axis = 0.0
	_hub.dash_held = false
	_runner.global_position = Vector2(-1700.0, Level02Data.FLOOR - 80.0)
	_runner.velocity = Vector2.ZERO
	await _physics(30)
	_hub.move_axis = 1.0
	_hub.dash_held = true
	await _physics(70)                       # up to sprint speed
	var start := _runner.global_position
	var apex := start.y
	_hub.press_jump()
	for i in range(150):
		await get_tree().physics_frame
		apex = minf(apex, _runner.global_position.y)
		if i > 6 and _runner.is_on_floor():
			break
	var out := Vector2(_runner.global_position.x - start.x, start.y - apex)
	_hub.release_jump()
	_hub.move_axis = 0.0
	_hub.dash_held = false
	return out

## How far a launch carries, landing `lift` pixels above where it started.
func _launch_arc(lift: float) -> float:
	_hub.release_jump()
	_hub.move_axis = 0.0
	_hub.dash_held = false
	# Well above the stage, where there is nothing to hit.
	_runner.global_position = Vector2(0.0, -2400.0)
	_runner.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var start := _runner.global_position
	_runner.facing = 1
	_runner.launch(Runner.launch_velocity(1))
	_hub.move_axis = 1.0
	for _i in range(400):
		await get_tree().physics_frame
		if _runner.velocity.y > 0.0 and _runner.global_position.y >= start.y - lift:
			break
	var across := _runner.global_position.x - start.x
	_hub.move_axis = 0.0
	return across

# ------------------------------------------------------------------- geometry

## The design claims, as arithmetic on the level data against those arcs.
func _check_geometry() -> void:
	var slabs := Stage.ground()
	_ok("the stage is built out of %d pieces of ground" % slabs.size(), slabs.size() > 8)

	var solo_across: float = arc["solo_across"]
	var solo_up: float = arc["solo_up"]

	# A launch has to be worth asking for. It costs the guardian a platform and
	# a shot and it costs the runner the time to get aboard; if one player with
	# two buttons goes further, the whole section is theatre. This check exists
	# because that is exactly what was happening: 349px against 507.
	_ok("a launch goes further than a single sprint jump (%.0f vs %.0f)"
			% [arc["launch_flat"], solo_across], arc["launch_flat"] > solo_across + 100.0)

	# Section 1: a 200px gap with a 220px rise. Either alone is survivable; the
	# combination is the first thing that needs a second player.
	var rise: float = Level02Data.FLOOR - Level02Data.SHELF
	_ok("1: the step is past a jump (%.0fpx against %.0f)" % [rise, solo_up],
		rise > solo_up)

	# Section 2: compare the gap against the measured first sprint jump.
	var gap_two := 1700.0 - 1100.0
	_ok("2: the gap is past a single sprint jump (%.0fpx against %.0f)"
			% [gap_two, solo_across], gap_two > solo_across)

	# Section 3: the shelf the wall exists for. One kick off a guardian wall is
	# a jump plus WALL_JUMP_UP, and it has to be enough -- and a plain jump has
	# to not be.
	var shelf_rise: float = Level02Data.MID - Level02Data.SHELF_TOP
	var kick_up: float = (Balance.WALL_JUMP_UP * Balance.WALL_JUMP_UP) \
		/ (2.0 * Balance.RUNNER_GRAVITY)
	_ok("3: the shelf is past a jump (%.0fpx against %.0f)" % [shelf_rise, solo_up],
		shelf_rise > solo_up)
	var top_out: float = solo_up + kick_up + Balance.LEDGE_HEAD_ROOM
	_ok("3: the shelf remains reachable with a guardian kick (%.0f)" % top_out,
		shelf_rise < top_out)
	# Ordinary walls and timed triple jumps are now legitimate alternatives.
	# This teaching section no longer claims that solo climbing is impossible.

	# Section 4: the crossing. Past two players' unaided best, inside a launch.
	var crossing := 6300.0 - 5700.0
	_ok("4: the crossing is past a single sprint jump (%.0fpx against %.0f)"
			% [crossing, solo_across], crossing > solo_across)
	_ok("4: ...and inside a launch (%.0fpx)" % arc["launch_flat"],
		crossing < arc["launch_flat"] - 40.0)

	# Section 5 has no gap: what is in the way is the pair of shield-bearers.
	var shields := 0
	for e in Stage.enemies():
		if String(e.get("type", "")) == "shieldbearer":
			shields += 1
	_ok("5: the corridor is guarded by %d shield-bearers" % shields, shields >= 2)

	# Section 6: not a width problem but a height one. 200px up is out of reach
	# of any jump the runner has, so the gap's width does not have to carry the
	# argument -- and a launch, which loses reach as it climbs, still makes it.
	var last_gap := 9780.0 - 9300.0
	var last_rise: float = Level02Data.MID - Level02Data.HIGH
	_ok("6: the last ledge is above a single sprint jump (%.0f against %.0f)"
			% [last_rise, solo_up], last_rise > solo_up)
	_ok("6: and the gap under it is inside a climbing launch (%.0f against %.0f)"
			% [last_gap, arc["launch_200"]], last_gap < arc["launch_200"] - 40.0)

	# Crystals: some on the route, some off it.
	_ok("there are %d crystals to fetch" % Stage.crystals().size(),
		Stage.crystals().size() >= 8)
	_ok("and %d checkpoints, so a failure costs one section"
			% Stage.checkpoints().size(), Stage.checkpoints().size() >= 4)

# ---------------------------------------------------------------- playing it

func _play() -> void:
	_guardian.gauge = Balance.GAUGE_MAX
	main._respawn_timer = -1.0
	await _section_one()
	await _section_two()
	await _section_three()
	await _section_four()
	await _section_five()
	await _section_six()

## Puts the runner where a pair would be starting this section from -- which is
## a checkpoint, because that is what checkpoints are. Sections are played
## independently so that one that cannot be finished names itself instead of
## hiding behind the one before it.
func _stand_at(x: float, y: float) -> void:
	main._respawn_timer = -1.0
	_hub.move_axis = 0.0
	_hub.dash_held = false
	_hub.release_jump()
	# A retry, not a teleport. "Played independently" has to include the
	# runner's own state: respawn() is what a checkpoint actually does, and
	# without it a section that killed the runner fails every section after it
	# instead of naming itself -- a corpse has no physics, so it stands on
	# nothing, boards nothing and is thrown by nothing.
	_runner.respawn(Vector2(x, y))
	for _i in range(60):
		await get_tree().physics_frame
		if _runner.is_on_floor():
			break

## How far ahead of the take-off point the runner's jump reaches its apex.
## Walking speed times the time to the top: this is where a step-up has to be
## if the runner is going to land on it rather than head-butt its edge.
const APEX_AHEAD := 115.0

## Walks right until `to_x`, jumping the way a player does: at the lip of a
## hole, and a stride EARLY for a step up.
##
## The early jump is the whole point of this helper. An autopilot that jumps at
## the last possible moment arrives at a raised ledge on the way up and hits its
## side, which fails a section that a person clears without thinking about it --
## the first run of this probe failed sections 1 and 2 for exactly that reason
## and the stage was fine. It walks rather than sprints for the same kind of
## reason: a sprinting autopilot sails over whatever the guardian just built.
func _walk_to(to_x: float, seconds: float, trace: bool = false) -> bool:
	_hub.move_axis = 1.0
	_hub.dash_held = false
	if trace:
		print("      walking from %s" % _where())
	var frames := int(seconds * 60.0)
	for _i in range(frames):
		await get_tree().physics_frame
		_guardian.gauge = Balance.GAUGE_MAX      # the gauge is not what is under test
		if _runner.global_position.x >= to_x:
			break
		if _runner.is_on_floor() and _should_jump():
			if trace:
				print("      jump at %s step=%.0f t=%.2f" % [_where(),
					_step_up_ahead(), float(_i) / 60.0])
			_hub.press_jump()
			await _hold_to_the_apex(to_x)
		if _runner.global_position.y > Level02Data.KILL_Y - 300.0:
			break
	_hub.move_axis = 0.0
	_hub.release_jump()
	return _runner.global_position.x >= to_x

## Holds the jump button until the runner starts coming down.
##
## Letting go early is a real control -- RUNNER_JUMP_CUT is what makes a tap a
## small hop -- and an autopilot that let go after nine frames was taking a
## two-thirds-height jump to every gap in the stage. Sections 1 and 2 failed on
## that and nothing was wrong with either of them.
func _hold_to_the_apex(stop_at: float) -> void:
	for _i in range(40):
		await get_tree().physics_frame
		if _runner.velocity.y >= 0.0 or _runner.global_position.x >= stop_at:
			break
	_hub.release_jump()

func _should_jump() -> bool:
	if _runner.is_on_wall():
		return true
	var step := _step_up_ahead()
	if step >= 0.0:
		return step <= APEX_AHEAD
	return _nothing_ahead()

## The distance to the near edge of the next thing standing above the runner's
## feet, or -1 when there is nothing within a jump's worth of ground.
func _step_up_ahead() -> float:
	var space := _runner.get_world_2d().direct_space_state
	var feet: float = _runner.global_position.y + Balance.RUNNER_SIZE.y * 0.5
	var d := 20.0
	while d <= 400.0:
		var at := Vector2(_runner.global_position.x + float(_runner.facing) * d, 0.0)
		var query := PhysicsRayQueryParameters2D.create(
			Vector2(at.x, feet - 300.0), Vector2(at.x, feet - 26.0))
		query.collision_mask = 1 | 8
		query.exclude = [_runner.get_rid()]
		if not space.intersect_ray(query).is_empty():
			return d
		d += 5.0
	return -1.0

## Is there floor just in front of the runner's feet? Probed close in, so the
## jump goes off at the lip rather than a stride early.
##
## The ray starts ABOVE the feet, not below them. A ray that begins inside a
## collider reports nothing -- Godot does not hit shapes from the inside unless
## asked to -- so a probe starting four pixels into the floor said "no ground"
## on every frame of the stage, and the autopilot jumped its way off both of
## section 2's stepping stones.
func _nothing_ahead() -> bool:
	var space := _runner.get_world_2d().direct_space_state
	var x: float = _runner.global_position.x + float(_runner.facing) * 26.0
	var feet: float = _runner.global_position.y + Balance.RUNNER_SIZE.y * 0.5
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(x, feet - 10.0), Vector2(x, feet + 40.0))
	query.collision_mask = 1 | 8
	query.exclude = [_runner.get_rid()]
	return space.intersect_ray(query).is_empty()

## The guardian puts something down, the way a player does: choose, then tap.
## Returns the refusal reason, empty when it went down.
func _build(slot: int, at: Vector2) -> String:
	_guardian.gauge = Balance.GAUGE_MAX
	# Cleared first. Guardian only ever WRITES this field on a refusal -- its
	# public refusal() hides that behind a 0.8s timer -- so reading it straight
	# after a build that SUCCEEDED hands back whatever was last refused. That
	# is not hypothetical: the wall rebuilds in section 3 are refused while the
	# previous wall is still standing, and sections 4 and 6 then reported
	# "blocked" for slabs that had gone down perfectly well.
	_guardian._last_refusal = ""
	_guardian.select_slot(slot)
	_guardian.use_active(at)
	await _physics(3)
	return _guardian._last_refusal

## Shoot something. The guardian's own path: pick the rifle, tap the target.
func _shoot(at: Vector2) -> void:
	_guardian.gauge = Balance.GAUGE_MAX
	(_guardian.abilities[3] as SniperAbility).cooldown = 0.0
	_guardian.select_slot(3)
	_guardian.use_active(at)
	await _physics(4)

## Shoot whatever is standing between the runner and `to_x`.
##
## Not a convenience. The runner has no answer to a patrol -- landing on one is
## a hit, not a stomp -- so an autopilot that walks into one takes two hits and
## a knockback into whatever it just crossed, and which of those it gets
## depends on where the patrol happened to be. Removing it is the guardian's
## job, the rifle is already in their hand, and that is the pair playing rather
## than the probe getting lucky.
func _clear_the_way(to_x: float) -> void:
	for _i in range(8):
		var target: Node2D = null
		for e in get_tree().get_nodes_in_group("enemy"):
			if not (e is Node2D) or e is BlackHoleChaser:
				continue
			if (e as Node).is_queued_for_deletion():
				continue
			var at: Vector2 = (e as Node2D).global_position
			if at.x >= _runner.global_position.x - 60.0 and at.x <= to_x + 200.0:
				target = e
				break
		if target == null:
			return
		await _shoot(target.global_position)
		await _physics(4)

## Gets the runner standing on a freshly built slab, facing right. Returns the
## slab, or null if they never settled on it.
func _board(deck: Vector2) -> Hologram:
	var live: Array = _guardian.holograms_of(Hologram.Kind.PLATFORM)
	if live.is_empty():
		return null
	var slab: Hologram = live.back()
	_runner.global_position = Vector2(deck.x, deck.y - 70.0)
	_runner.velocity = Vector2.ZERO
	_runner.facing = 1
	for _i in range(120):
		await get_tree().physics_frame
		if _runner.is_on_floor():
			break
	return slab

func _where() -> String:
	return "x=%.0f y=%.0f" % [_runner.global_position.x, _runner.global_position.y]

# ---------------------------------------------------------------- the pursuit
#
# The black hole is the one thing in 1-C that is not a shape or a construct: it
# ignores terrain, it cannot be shot, and it is faster than a walk. So it is
# checked here, once, on its own terms -- and then taken out of the world for
# the sections below.
#
# Not because it is inconvenient. Because this probe teleports the runner to a
# checkpoint at the start of every section and then plays at walking pace, and
# a chase carried across those teleports measures the teleport: the distance
# behind the runner it starts a section with is whatever the last teleport
# happened to leave, and every _walk_to here runs longer than the five seconds
# the black hole needs to close its head start on a walk. Left running, it
# killed the runner in sections 1 and 3 and -- because a dead runner never
# moves again -- failed sections 4, 5 and 6 without ever reaching them, and it
# corrupted the arc measurements at the top of this file as well.

func _chaser() -> BlackHoleChaser:
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is BlackHoleChaser:
			return node
	return null

## Does the chase say what the stage needs it to say? It has to leave a player
## alone until they have actually started, and it has to make sprinting the
## answer -- a pursuer slower than a walk is scenery, one faster than a sprint
## is a timer.
func _the_pursuit() -> void:
	var hole := _chaser()
	_ok("there is something following the runner", hole != null)
	if hole == null:
		return
	_ok("and touching it is fatal rather than a hit",
		hole.is_in_group("instant_death"))

	# Dormant while the runner has not left the start. A pursuer that starts
	# moving during the title card eats the opening screen.
	await _stand_at(Level02Data.START.x, Level02Data.START.y)
	hole.global_position = _runner.global_position + Vector2(-hole.spawn_distance, 0.0)
	hole._runner_origin_x = _runner.global_position.x
	hole._active = false
	hole.set_physics_process(true)
	var parked := hole.global_position
	await _physics(30)
	hole.set_physics_process(false)
	_ok("it waits while the runner has not moved",
		hole.global_position.distance_to(parked) < 1.0,
		"drifted %.1fpx" % hole.global_position.distance_to(parked))

	# Walking away from it loses ground. This is the fact that makes the
	# section autopilot below impossible, so it is stated rather than implied.
	var walk_gap := await _gap_after(hole, 90, false)
	_ok("a walk loses ground to it (%.0fpx of head start becomes %.0f)"
			% [hole.spawn_distance, walk_gap], walk_gap < hole.spawn_distance)

	# And sprinting gains it, so the stage is asking for a sprint rather than
	# running a clock the runner cannot beat.
	var sprint_gap := await _gap_after(hole, 90, true)
	_ok("and a sprint pulls away from it (%.0fpx)" % sprint_gap,
		sprint_gap > hole.spawn_distance)

## Put the runner back at the start with the black hole its full head start
## behind, awake, then move for `frames` and report the gap that is left.
func _gap_after(hole: BlackHoleChaser, frames: int, sprint: bool) -> float:
	# Asleep until the runner is in place. Letting it fly during the settle
	# would put it on top of a stationary runner, and a death here rebuilds
	# every enemy in the level -- including this one, which the next line then
	# reads off a freed object.
	hole.set_physics_process(false)
	await _stand_at(Level02Data.START.x, Level02Data.START.y)
	hole.global_position = _runner.global_position + Vector2(-hole.spawn_distance, 0.0)
	hole._runner_origin_x = _runner.global_position.x - hole.activation_distance - 1.0
	hole._active = true
	hole.set_physics_process(true)
	_hub.move_axis = 1.0
	_hub.dash_held = sprint
	await _physics(frames)
	_hub.move_axis = 0.0
	_hub.dash_held = false
	hole.set_physics_process(false)
	return _runner.global_position.x - hole.global_position.x

## Out of the world for the rest of the run. See the note above this block.
func _park_the_pursuit() -> void:
	var hole := _chaser()
	if hole == null:
		return
	hole.set_physics_process(false)
	hole.velocity = Vector2.ZERO
	hole.global_position = Vector2(Level02Data.START.x - 6000.0,
		Level02Data.KILL_Y + 4000.0)

# --------------------------------------------------------------- the sections

func _section_one() -> void:
	await _stand_at(Level02Data.START.x, Level02Data.START.y)
	await _walk_to(-480.0, 12.0)
	# A step halfway up the rise and hard against the near lip, so the runner
	# takes off from solid ground rather than from the far side of a hole. Half
	# of 220 either way, and both halves are inside a jump.
	var why := await _build(1, Vector2(-222.0, 323.0))
	_ok("1: the guardian can bridge the first step", why == "", why)
	var over := await _walk_to(60.0, 16.0)
	_ok("1: and the runner gets up onto the shelf", over, _where())

func _section_two() -> void:
	await _stand_at(Stage.checkpoints()[0].x, Stage.checkpoints()[0].y)
	await _walk_to(1040.0, 14.0)
	# Two slabs, which is exactly as many as the guardian may have alive
	# (Balance.PLATFORM_MAX_ALIVE). 600px is three walking hops, and the pair
	# have the two stepping stones that makes it.
	var why := await _build(1, Vector2(1280.0, Level02Data.SHELF + 4.0))
	_ok("2: a platform goes into the 600px gap", why == "", why)
	var why_two := await _build(1, Vector2(1590.0, Level02Data.SHELF + 4.0))
	_ok("2: and a second one, which is all the guardian gets", why_two == "", why_two)
	var over := await _walk_to(1760.0, 18.0)
	_ok("2: and the runner crosses them", over, _where())

func _section_three() -> void:
	await _stand_at(Stage.checkpoints()[1].x, Stage.checkpoints()[1].y)
	var reached := await _walk_to(3650.0, 22.0)
	_ok("3: the runner reaches the shelf's foot", reached, _where())
	if not reached:
		return
	# Settled, then asked: a check taken mid-jump would be reading the apex.
	await _physics(45)
	_ok("3: the runner is settled before the guardian-wall demonstration",
		_runner.is_on_floor() and _runner.global_position.y > 150.0, _where())
	# The wall goes BEHIND the runner, which is the only way a kick can send
	# them forward: a wall jump pushes away from the wall, so a wall between the
	# runner and the ledge would throw them back down the way they came. What
	# the pair learn here is "stop at the edge, and I will put one behind you".
	var foot: float = _runner.global_position.y + Balance.RUNNER_SIZE.y * 0.5
	var why := await _build(2, Vector2(3600.0, foot - Balance.WALL_SIZE.y * 0.5))
	_ok("3: the guardian puts a wall behind the runner", why == "", why)
	if why != "":
		return

	var kicked := [false]
	var watch := func(_at: Vector2, _away: int) -> void: kicked[0] = true
	Events.runner_wall_jumped.connect(watch)
	var up := await _kick_up_onto_the_shelf()
	Events.runner_wall_jumped.disconnect(watch)
	_ok("3: the runner kicks off it", kicked[0])
	_ok("3: and gets onto the shelf", up, _where())

## Jump straight up, reach back for the wall near the top, kick forward.
##
## Reaching back at the TOP rather than straight away is not a trick: a kick
## carries a fixed 112px and the shelf is 220 up, so the jump has to supply the
## rest. Touching the wall on the way up spends the kick from too low down.
## Several attempts, because a player gets several too.
func _kick_up_onto_the_shelf() -> bool:
	var wall_face: float = 3600.0 + Balance.WALL_SIZE.x * 0.5
	for _attempt in range(6):
		# Standing against the wall rather than a stride away from it. The
		# reach-across has to finish before the apex does: with a 0.33s rise,
		# starting 40px clear meant contact came a quarter of a second after
		# the top, on the way back down, and a kick from there arrives under
		# the shelf rather than on it.
		await _stand_at(wall_face + Balance.RUNNER_SIZE.x * 0.5 + 1.0,
			Level02Data.MID - 30.0)
		# A wall lives WALL_LIFETIME seconds and an attempt takes longer than
		# that, so the one the section built before the first try is gone by
		# the third. Six attempts against one wall is one attempt and five
		# jumps next to nothing; a guardian rebuilds it, and so does this.
		var foot: float = _runner.global_position.y + Balance.RUNNER_SIZE.y * 0.5
		# Refused while the previous one is still standing, which is the answer
		# this wants: either there is a wall to kick off or there is about to
		# be one.
		await _build(2, Vector2(3600.0, foot - Balance.WALL_SIZE.y * 0.5))
		_hub.move_axis = -1.0                    # leaning on the wall
		_hub.press_jump()
		var kicked := false
		for _i in range(40):
			await get_tree().physics_frame
			# At the top of the rise, which is where a kick buys the most.
			if _runner.can_wall_jump() and _runner.velocity.y > -60.0:
				_hub.release_jump()
				_hub.press_jump()
				await get_tree().physics_frame
				_hub.move_axis = 1.0             # and on to the shelf
				kicked = true
				break
		if not kicked:
			_hub.release_jump()
			continue
		for _i in range(150):
			await get_tree().physics_frame
			# Catching the lip is how a kick that only just reaches finishes:
			# the kick tops out about 20px under the shelf, and the hands make
			# up the rest. Hanging there is not arriving, so climb.
			if _runner.hanging():
				_hub.move_axis = 1.0
				_hub.press_jump()
				await _physics(10)
				_hub.release_jump()
			elif _runner.is_on_wall() and not _runner.is_on_floor():
				# Against the shelf's own face now, so let go of the direction.
				# Holding into a wall is a wall SLIDE, and a slide pins the
				# fall to WALL_SLIDE_SPEED -- which is below the speed a ledge
				# catch needs. Pressing towards a lip is the one input that
				# guarantees never grabbing it; letting go falls the last few
				# pixels fast enough for the hands to find the edge.
				_hub.move_axis = 0.0
			if _runner.is_on_floor() and _runner.global_position.x > 3700.0 \
					and _runner.global_position.y < Level02Data.SHELF_TOP + 60.0:
				_hub.move_axis = 0.0
				return true
		_hub.release_jump()
		_hub.move_axis = 0.0
	return false

func _section_four() -> void:
	await _stand_at(Stage.checkpoints()[2].x, Stage.checkpoints()[2].y)
	await _walk_to(5620.0, 12.0)
	# A slab on the lip. The runner gets on it, points across, and is shot off.
	var deck := Vector2(5680.0, Level02Data.MID - 60.0)
	var why := await _build(1, deck)
	_ok("4: a slab goes on the lip of the crossing", why == "", why)
	if why != "":
		return
	var slab := await _board(deck)
	_ok("4: the runner stands on it", slab != null and slab.trigger.loaded(),
		"on_floor=%s %s" % [str(_runner.is_on_floor()), _where()])
	if slab == null:
		return

	await _shoot(slab.trigger.global_position)
	_ok("4: shooting the trigger throws them", _runner.velocity.y < -100.0,
		"velocity %s" % str(_runner.velocity.round()))
	_ok("4: and the trigger is spent, so one slab is one launch", not slab.trigger.armed)

	_hub.move_axis = 1.0
	var landed := false
	for _i in range(300):
		await get_tree().physics_frame
		if _runner.is_on_floor() and _runner.global_position.x > 6300.0:
			landed = true
			break
	_hub.move_axis = 0.0
	_ok("4: and they clear the crossing", landed, _where())

func _section_five() -> void:
	await _stand_at(Stage.checkpoints()[3].x, Stage.checkpoints()[3].y)
	var bearers := get_tree().get_nodes_in_group("shieldbearer")
	_ok("5: the corridor has shield-bearers in it (%d)" % bearers.size(),
		bearers.size() >= 2)
	if bearers.is_empty():
		return
	var bearer = bearers[0]

	# Standing near it is not enough, and that is the section. The soft spot
	# opens when the runner MAKES IT TURN -- so the runner has to get to the far
	# side of a thing whose shield is pointed at them, which is work only they
	# can do. Settle on one side first, so crossing to the other is a crossing.
	await _stand_at(bearer.global_position.x + 220.0, Level02Data.MID - 60.0)
	await _wait(Balance.SHIELDBEARER_TURN_TIME + 0.3)
	_ok("5: it faces whichever side the runner is on", bearer.facing_now() == 1,
		"facing %d" % bearer.facing_now())
	# Arriving on the far side IS a crossing -- it started facing the other way
	# -- so the window is open right now and that is correct. What must not
	# happen is it STAYING open while the runner stands there.
	await _wait(Balance.SHIELDBEARER_OPEN_TIME + 0.3)
	_ok("5: and standing still does not keep it open", not bearer.exposed())

	await _stand_at(bearer.global_position.x - 220.0, Level02Data.MID - 60.0)
	_ok("5: crossing it starts it turning", bearer.turning())
	await _wait(Balance.SHIELDBEARER_TURN_TIME + 0.3)
	_ok("5: it comes round to face the runner", bearer.facing_now() == -1,
		"facing %d" % bearer.facing_now())
	_ok("5: and the crossing is what opens the soft spot", bearer.exposed())

	var life: int = bearer.hp
	await _shoot(bearer._shield.global_position)
	_ok("5: a shot into the plate does nothing", bearer.hp == life,
		"hp %d -> %d" % [life, bearer.hp])

	# Finishing it takes more than one shot, and the window shuts on its own --
	# so the runner keeps crossing while the guardian keeps firing. That is the
	# section played the way it is meant to be played, and it is the reason this
	# enemy is here.
	var killed := false
	var side := 1.0
	for _i in range(8):
		if not is_instance_valid(bearer) or bearer.is_queued_for_deletion():
			killed = true
			break
		if not bearer.exposed():
			side = -side
			await _stand_at(bearer.global_position.x + 220.0 * side,
				Level02Data.MID - 60.0)
			await _wait(Balance.SHIELDBEARER_TURN_TIME + 0.25)
		if is_instance_valid(bearer):
			await _shoot(bearer._weak.global_position)
	if not killed:
		killed = not is_instance_valid(bearer) or bearer.is_queued_for_deletion()
	_ok("5: the two of them together finish it", killed)

func _section_six() -> void:
	await _stand_at(Stage.checkpoints()[4].x, Stage.checkpoints()[4].y)
	await _walk_to(9220.0, 14.0)
	var deck := Vector2(9260.0, Level02Data.MID - 60.0)
	var why := await _build(1, deck)
	_ok("6: the last slab goes down", why == "", why)
	if why != "":
		return
	var slab := await _board(deck)
	_ok("6: the runner boards it", slab != null and slab.trigger.loaded(), _where())
	if slab == null:
		return
	await _shoot(slab.trigger.global_position)

	_hub.move_axis = 1.0
	var across := false
	for _i in range(300):
		await get_tree().physics_frame
		if _runner.is_on_floor() and _runner.global_position.x > 9780.0:
			across = true
			break
	_hub.move_axis = 0.0
	_ok("6: the launch clears the last gap and the 200px rise", across, _where())
	if not across:
		return

	# The last stretch is patrolled, and this is the section where everything
	# the pair have learned is used at once. The rifle is the half of it the
	# runner cannot do.
	await _clear_the_way(Stage.goal().x)

	var cleared := [false]
	var watch := func(_stats: Dictionary) -> void: cleared[0] = true
	Events.stage_cleared.connect(watch)
	await _walk_to(Stage.goal().x + 20.0, 24.0)
	await _physics(20)
	Events.stage_cleared.disconnect(watch)
	_ok("6: the runner reaches the gate", cleared[0],
		"%s, goal at %.0f" % [_where(), Stage.goal().x])

func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= Clock.DT

