extends Node
## Does the guardian's device show the world the runner's device is simulating?
##
## Every fault the playtest found on the guardian's side -- enemies standing in
## mid-air, a shot that passes through something plainly there, a partner who
## blinks -- is one claim failing: that the second device is showing THIS world
## rather than an approximation of it. Nothing in the logic suite could catch
## any of them. Each is perfectly true of one device in isolation and only
## wrong when the two are put side by side, and the suite never put them side
## by side. That gap, not the difficulty of netcode, is why these reached a
## phone before they reached a test.
##
## So put them side by side. A phase runs the real stage as the host and writes
## down both what it SENT and what was actually TRUE at every tick. Then it
## throws that world away, builds a fresh one, hands it a real ClientSession
## and replays exactly those packets through a link model. At every frame the
## guardian's device is asked which tick it believes it is drawing, and
## everything it is drawing is compared with what was really true at that tick.
##
##   godot --headless --path . --fixed-fps 60 res://test/agreement_probe.tscn
##
## Positions only, so it needs no display.

## The runner is carried along the stage rather than left to run it, because a
## test that only ever exercises the two enemies near the start line is a test
## that passes for the wrong reason. Every position here is one the screenshot
## pass already stands the runner on, so none of them is a pit.
const WAYPOINTS: Array = [
	Vector2(430, 300), Vector2(1100, 330), Vector2(1830, 240),
	Vector2(2600, 300), Vector2(3050, 266), Vector2(3600, 300),
	Vector2(4400, 290), Vector2(6250, 146), Vector2(7100, 190),
	Vector2(8350, 186), Vector2(9700, 190), Vector2(10600, 186),
	Vector2(11450, 110), Vector2(12700, -34), Vector2(14450, 110),
	Vector2(15800, 120),
]

## How long the runner stays at each one. A second is long enough for the
## guardian's device to be told about everything that just came into view and
## for the walkers to cover a good part of a patrol leg.
const HOLD_TICKS: int = 70

## A jump between waypoints is a teleport, which is the one thing the guest is
## meant to SNAP through rather than interpolate -- and it snaps as soon as a
## snapshot PAIR straddles the jump, which is a tick or two before the drawn
## tick reaches it. So the frames on both sides of a jump say nothing about
## agreement, and neither do the ones before the first snapshot has arrived.
const JUMP_BLACKOUT: int = 24
const PRE_JUMP_BLACKOUT: int = 12
const WARMUP_TICKS: int = 40

## How many of the stage's enemies each sweep has to actually bring on screen.
## Without this the enemy check can quietly become vacuous -- which is exactly
## what it was before the sweep existed, at one enemy out of twenty. These are
## floors a little under what the sweeps currently reach, so ordinary drift
## does not fail the run but a collapse in coverage does.
const MUST_WATCH: int = 15
const MUST_WATCH_AFTER_DEATH: int = 7

## The runner is interpolated through the real samples with the real velocities,
## so agreement should be tight. Anything looser is a rendering bug rather than
## the cost of the link.
##
## DERIVED, not chosen. The guest interpolates between snapshots, and Hermite
## reproduces steady motion exactly -- what it cannot reproduce is the change of
## speed WITHIN a gap. So the error is the second-order term, half the
## acceleration times the gap squared, and the acceleration that matters is the
## one the runner spends most of a fall under.
##
## Written as 12px it was a number somebody measured once. When the jump was
## retuned the fall got heavier, the same interpolation produced 21.5px, and
## this probe failed for a reason that had nothing to do with agreement. The
## factor allows for a couple of gaps stacking up and for the lossy run below.
## How far back in time the guest draws: one interpolation buffer plus the gap
## between the two snapshots it is drawing between. That whole span is the
## window over which a change of speed goes unseen.
const INTERP_BUFFER: float = 0.060
const SNAPSHOT_GAP: float = float(HostSession.SNAPSHOT_EVERY) * Clock.DT
const DRAW_WINDOW: float = INTERP_BUFFER + SNAPSHOT_GAP
const INTERPOLATION_RESIDUAL: float = 0.5 * Balance.RUNNER_FALL_GRAVITY \
	* DRAW_WINDOW * DRAW_WINDOW
const RUNNER_TOLERANCE: float = INTERPOLATION_RESIDUAL * 1.5

## Enemies are snapped to the newer bracketing snapshot rather than interpolated,
## which can put them up to one snapshot (2 ticks) ahead of the drawn tick. A
## walker covers about this much in that time, and this is generous to the
## snapping while still nowhere near "standing in the wrong place".
const ENEMY_TOLERANCE: float = 24.0

## The same two numbers for a wire that loses packets. Both are measured,
## because they answer different questions: on a clean wire any disagreement is
## the code being wrong, and the gap between the two is the price of the link.
const LOSSY_RUNNER_TOLERANCE: float = RUNNER_TOLERANCE * 2.2
const LOSSY_ENEMY_TOLERANCE: float = 40.0

## How far outside the drawn view an enemy still has to be correct. One that
## only becomes right as it crosses the edge of the screen is one the guardian
## watches teleport.
const VIEW_MARGIN: float = 160.0

var _shown: int = 0
var failures: int = 0
var checks: int = 0

func _ready() -> void:
	await _run()
	print("")
	if failures == 0:
		print("host and guest agree (%d checks)" % checks)
	else:
		print("DISAGREEMENT: %d of %d checks" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)

func _run() -> void:
	print("== the stage, swept past the guardian ==")
	var swept := await _record(_sweep_the_stage)
	print("  %d packets, %d ticks of truth, %d not counted"
		% [swept["wire"].size(), swept["truth"].size(), swept["blackout"].size()])
	print("")
	print("-- over a clean wire --")
	await _replay(swept, 0.060, 0.0, 0.0, RUNNER_TOLERANCE, ENEMY_TOLERANCE, MUST_WATCH)
	print("")
	print("-- over a wire that loses packets --")
	await _replay(swept, 0.060, 0.03, 0.015,
		LOSSY_RUNNER_TOLERANCE, LOSSY_ENEMY_TOLERANCE, MUST_WATCH)

	print("")
	print("== and again after the runner has died once ==")
	var died := await _record(_die_and_carry_on)
	print("  %d packets, %d ticks of truth, %d not counted"
		% [died["wire"].size(), died["truth"].size(), died["blackout"].size()])
	await _replay(died, 0.060, 0.0, 0.0, RUNNER_TOLERANCE, ENEMY_TOLERANCE,
		MUST_WATCH_AFTER_DEATH)

	print("")
	print("== the ground the two of them run on ==")
	var ran := await _record(_run_and_land)
	print("  %d packets, %d ticks of truth, %d not counted"
		% [ran["wire"].size(), ran["truth"].size(), ran["blackout"].size()])
	await _replay(ran, 0.060, 0.0, 0.0, RUNNER_TOLERANCE, ENEMY_TOLERANCE, 1)

	print("")
	print("== what a take-off and a landing put on the wire ==")
	await _the_wire_carries_the_settled_state()

	print("")
	print("== a stage where the two of them are shown different things ==")
	var dark := await _record(_through_the_quiet, Stage.Which.QUIET)
	print("  %d packets, %d ticks of truth, %d not counted"
		% [dark["wire"].size(), dark["truth"].size(), dark["blackout"].size()])
	await _replay(dark, 0.060, 0.0, 0.0, RUNNER_TOLERANCE, ENEMY_TOLERANCE, 0,
		Stage.Which.QUIET)

	print("")
	print("== the guardian's own copy of the runner ==")
	await _invulnerability_expires()

	print("")
	print("== does the guardian's copy know it is standing on something ==")
	await _the_puppet_knows_the_ground()

	print("")
	print("== a shot names the enemy, not the patch of grass ==")
	await _shot_follows_its_target()

	print("")
	print("== the ghost and the thing it becomes ==")
	await _ghost_is_where_it_lands()

# --------------------------------------------------------------------- harness

func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame

func _ok(label: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("  ok    ", label)
	else:
		failures += 1
		print("  FAIL  ", label, "" if detail.is_empty() else "  -- " + detail)

## The real stage, with the connect screen taken off the top of it.
func _build(which: int = Stage.Which.GREENFIELD) -> Node2D:
	Stage.use(which)
	var world: Node2D = load("res://src/main.tscn").instantiate()
	add_child(world)
	await _frames(6)
	var panel := world.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
		await _frames(2)
	world.input_hub.scripted = true
	return world

## Everything that is true right now, for every enemy -- not only the ones the
## host decided were worth sending. The difference between those two sets is
## where a floating enemy would hide.
func _truth(world: Node2D) -> Dictionary:
	var enemies := {}
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D):
			continue
		var id = e.get("net_id")
		if id != null and int(id) >= 0:
			enemies[int(id)] = (e as Node2D).global_position
	return {"runner": world.runner.global_position, "enemies": enemies}

# ------------------------------------------------------------------- recording

## Runs the stage as the host under `script`, a callable given (world, tick)
## every physics frame that returns true while the frame should not be counted.
func _record(script: Callable, which: int = Stage.Which.GREENFIELD) -> Dictionary:
	var link := LoopbackTransport.pair(0.0)
	var tap: LoopbackTransport = link[1]

	Clock.reset(0)
	var world := await _build(which)
	world._become_host(link[0])
	await _frames(2)

	# The recording's own zero. Packets and truth are both stamped with the
	# host's tick, and the replay has to line its frames up with the same
	# numbers or it compares the guardian against a moment that never was.
	var start_tick := Clock.tick
	var wire: Array = []
	var truth := {}
	var blackout := {}
	var frame := 0
	while true:
		var skip: Variant = script.call(world, frame)
		if skip == null:
			break
		await get_tree().physics_frame
		tap.advance(Clock.DT)
		for p in tap.poll():
			wire.append({
				"tick": Clock.tick,
				"channel": int(p["channel"]),
				"payload": p["payload"],
			})
		truth[Clock.tick] = _truth(world)
		if bool(skip) or Clock.tick < WARMUP_TICKS:
			blackout[Clock.tick] = true
		frame += 1

	world.free()
	await _frames(3)
	return {"wire": wire, "truth": truth, "blackout": blackout,
		"frames": frame, "start_tick": start_tick}

## Stand the runner in front of each cluster of enemies in turn, pacing rather
## than travelling so it cannot walk off the ledge it was put on, and let
## nothing kill it: this half is about agreement in the steady state.
func _sweep_the_stage(world: Node2D, frame: int) -> Variant:
	if frame >= WAYPOINTS.size() * HOLD_TICKS:
		return null
	world.runner.hp = Balance.RUNNER_MAX_HP
	world.runner._invuln = 10.0
	return _stand_at(world, WAYPOINTS, frame)

## Puts the runner at waypoint `frame / HOLD_TICKS` and paces it there. Returns
## true while the frame is too close to a jump to mean anything.
func _stand_at(world: Node2D, stops: Array, frame: int) -> bool:
	var index := frame / HOLD_TICKS
	var into := frame % HOLD_TICKS
	if into == 0:
		# A respawn is on a timer, so one left pending at a waypoint fires in
		# the middle of the next and teleports the runner back to a checkpoint
		# with nothing in the recording to explain it.
		world._respawn_timer = -1.0
		world.runner.global_position = stops[index]
		world.runner.velocity = Vector2.ZERO
	world.input_hub.move_axis = 1.0 if (into / 20) % 2 == 0 else -1.0
	return into < JUMP_BLACKOUT or into >= HOLD_TICKS - PRE_JUMP_BLACKOUT

## A death, a respawn, and then ordinary play across the stage. The respawn
## rebuilds every enemy in the level on BOTH devices, which is the moment the
## guardian's device is most likely to lose track of which enemy is which --
## and the sweep afterwards is what makes that visible instead of theoretical.
const DEATH_AT: int = 60

## Where the runner goes once it is back on its feet.
const AFTER_DEATH: Array = [
	Vector2(1100, 330), Vector2(3600, 300), Vector2(7100, 190),
	Vector2(9700, 190), Vector2(12700, -34),
]

func _die_and_carry_on(world: Node2D, frame: int) -> Variant:
	var settle := DEATH_AT + int(Balance.RESPAWN_DELAY * 60.0) + JUMP_BLACKOUT
	if frame < settle:
		if frame == DEATH_AT:
			world.runner._invuln = 0.0
			world.runner.hp = 1
			world.runner.take_damage(1)
		world.input_hub.move_axis = 1.0
		return true      # everything up to the respawn is setup, not evidence
	if frame - settle >= AFTER_DEATH.size() * HOLD_TICKS:
		return null
	world.runner.hp = Balance.RUNNER_MAX_HP
	world.runner._invuln = 10.0
	return _stand_at(world, AFTER_DEATH, frame - settle)

## Ordinary ground play on one flat stretch, which the waypoint sweep never
## does: it teleports the runner about and paces it at a constant full lean.
## Starting from a standstill, turning round, a half lean, taking off while
## running and jumping again out of the landing are the five things the ground
## model actually changed, so they are the five the two devices have to agree
## about.
const GROUND_AT := Vector2(1100, 330)
const GROUND_SCRIPT: Array = [
	# [frames, axis, jump]
	[30, 0.0, false],     # settle
	[40, 1.0, false],     # start running
	[40, -1.0, false],    # and turn round
	[40, 0.45, false],    # a half lean, which now has its own speed
	[8, 1.0, false],      # back up to speed
	[45, 1.0, true],      # take off while running
	[30, 1.0, false],     # land
	[40, 1.0, true],      # and go again out of the landing
	[40, 0.0, false],     # let go and stop
]

func _run_and_land(world: Node2D, frame: int) -> Variant:
	if frame == 0:
		world._respawn_timer = -1.0
		world.runner.global_position = GROUND_AT
		world.runner.velocity = Vector2.ZERO
	world.runner.hp = Balance.RUNNER_MAX_HP
	world.runner._invuln = 10.0
	var at := frame
	for leg in GROUND_SCRIPT:
		var length: int = int(leg[0])
		if at < length:
			world.input_hub.move_axis = float(leg[1])
			if bool(leg[2]):
				if at == 0:
					world.input_hub.press_jump()
			elif world.input_hub.jump_held:
				world.input_hub.release_jump()
			# The settling leg is setup rather than evidence; so is the first
			# tick of each jump, which is the teleport-like edge the guest
			# snaps through rather than interpolates.
			return frame < WARMUP_TICKS or at < 2
		at -= length
	world.input_hub.move_axis = 0.0
	world.input_hub.release_jump()
	return null

## The snapshot is taken after the move, so a take-off frame has to go on the
## wire as a jump and a landing frame as a run. Sending the floor contact the
## frame STARTED with is how the guardian's copy ends up a frame behind on
## every take-off and every landing.
func _the_wire_carries_the_settled_state() -> void:
	Clock.reset(0)
	var world := await _build()
	world._become_host(LoopbackTransport.pair(0.0)[0])
	await _frames(2)
	world._respawn_timer = -1.0
	var r: Runner = world.runner
	r.global_position = GROUND_AT
	r.velocity = Vector2.ZERO
	world.input_hub.move_axis = 1.0
	for _i in range(40):
		await get_tree().physics_frame

	_ok("the packet is still the size the budget says (%d B)"
			% Snapshot.quiet_size(), Snapshot.quiet_size() == 14)

	world.input_hub.press_jump()
	await get_tree().physics_frame
	var leaving := _wire_state(world)
	_ok("the take-off frame goes out as a jump",
		int(leaving["state"]) == int(Runner.State.JUMP) and not bool(leaving["floor"]),
		"state=%d floor=%s" % [int(leaving["state"]), str(leaving["floor"])])
	world.input_hub.release_jump()

	var arriving := {}
	for _i in range(180):
		await get_tree().physics_frame
		if r.is_on_floor():
			arriving = _wire_state(world)
			break
	_ok("and the landing frame goes out as a run",
		int(arriving.get("state", -1)) == int(Runner.State.RUN)
			and bool(arriving.get("floor", false)),
		"state=%d floor=%s"
			% [int(arriving.get("state", -1)), str(arriving.get("floor", false))])
	world.input_hub.move_axis = 0.0
	world.free()
	await _frames(3)

## What this frame's snapshot says about the runner, after a real encode and
## decode, so quantisation and the 3-bit state field are both in the answer.
func _wire_state(world: Node2D) -> Dictionary:
	var sent: Snapshot = world.host_session._snapshot()
	var got := Snapshot.decode(sent.encode())
	return {"state": got.runner_state, "floor": got.on_floor,
		"x": got.runner_position.x, "vx": got.runner_velocity.x}

## 1-V, driven across the ground that only one of the two devices paints.
##
## The recording device is the host and therefore the RUNNER, with the veils
## closed to it; the replay device is the client and therefore the GUARDIAN,
## with everything drawn. So this is the asymmetry as it actually ships, and the
## thing it is asking is whether a screen that is missing half its scenery still
## simulates the same world the other screen is watching. It should, because
## hiding is only ever `visible = false` -- but "should" is what a probe is for.
const QUIET_AT := Vector2(200.0, 360.0)

func _through_the_quiet(world: Node2D, frame: int) -> Variant:
	if frame == 0:
		world._respawn_timer = -1.0
		world.runner.global_position = QUIET_AT
		world.runner.velocity = Vector2.ZERO
	if frame >= 260:
		return null
	world.runner.hp = Balance.RUNNER_MAX_HP
	world.runner._invuln = 10.0
	world.input_hub.dash_held = true
	world.input_hub.move_axis = 1.0
	# Over the first hidden platform, at the frame the veil probe measured.
	if frame == 61:
		world.input_hub.press_jump()
	if frame == 81:
		world.input_hub.release_jump()
	# Settling, and the two frames either side of a take-off, say nothing about
	# agreement: a jump is the one edge the guest snaps through.
	return frame < WARMUP_TICKS or (frame >= 59 and frame <= 63)

# -------------------------------------------------------------------- replaying

func _replay(recorded: Dictionary, latency: float, loss: float, jitter: float,
		runner_tolerance: float, enemy_tolerance: float,
		want_watched: int, which: int = Stage.Which.GREENFIELD) -> void:
	var wire: Array = recorded["wire"]
	var truth: Dictionary = recorded["truth"]
	var blackout: Dictionary = recorded["blackout"]

	var link := LoopbackTransport.pair(latency, loss, jitter)
	var client_side: LoopbackTransport = link[0]
	var feed: LoopbackTransport = link[1]

	Clock.reset(0)
	Clock.follow_target = -1
	var world := await _build(which)
	world._become_client(client_side)
	# Start the guardian's clock where the recording starts. Everything below
	# is stated in the host's ticks.
	var start_tick: int = int(recorded["start_tick"])
	Clock.reset(start_tick)
	# Look as far off the runner as the guardian is allowed to. Everything in
	# this view is something they can put a crosshair on, so everything in it
	# has to be where the host says it is.
	world.guardian_pan = world._pan_limit()
	await _frames(2)

	var cursor := 0
	var runner_worst := 0.0
	var runner_worst_tick := -1
	var worst := {}          ## net_id -> worst error while on screen
	var worst_off := {}      ## net_id -> worst error while off screen
	var on_screen := {}      ## net_id -> frames compared while on screen
	var vanished := {}       ## net_id -> frames the guest had no node for it
	var how_far := {}        ## net_id -> distance from the runner at its worst
	var compared := 0
	_shown = 0

	for f in range(int(recorded["frames"])):
		# Released on the recording's timeline, NOT on the guardian's clock.
		# Gating on its clock is a ratchet: the newest snapshot it is allowed
		# to hear is then always at or behind its own tick, so the steering
		# never tells it to run fast, so it falls further behind and hears
		# less -- and the whole replay slides a second into the past.
		var due := start_tick + f
		while cursor < wire.size() and int(wire[cursor]["tick"]) <= due:
			var p: Dictionary = wire[cursor]
			var channel: int = int(p["channel"])
			var reliability := NetTransport.Reliability.UNRELIABLE \
				if channel == NetTransport.Channel.SNAPSHOT \
				else NetTransport.Reliability.RELIABLE_ORDERED
			feed.send(channel, reliability, p["payload"])
			cursor += 1
		client_side.advance(Clock.DT)
		await get_tree().physics_frame
		# Drain whatever the guardian sent back so the link does not silt up.
		feed.advance(Clock.DT)
		feed.poll()

		var drawn: int = world.client_session.view_tick()
		if not truth.has(drawn) or blackout.has(drawn):
			continue
		compared += 1
		var want: Dictionary = truth[drawn]
		var error: float = world.runner.global_position.distance_to(want["runner"])
		if error > runner_worst:
			runner_worst = error
			runner_worst_tick = drawn
		if error > runner_tolerance and _shown < 6:
			_shown += 1
			print("    tick %d drawn %d: guest %s vs host %s (buffer %d, interp %d)"
				% [Clock.tick, drawn, str(world.runner.global_position.round()),
					str(Vector2(want["runner"]).round()),
					world.client_session._buffer.size(),
					world.client_session._interp_ticks])
		var view := _guardian_view(world)
		for id in want["enemies"]:
			var node := _guest_enemy(int(id))
			if node == null:
				vanished[id] = int(vanished.get(id, 0)) + 1
				continue
			var e: float = node.global_position.distance_to(want["enemies"][id])
			# Judge it where the guardian is looking. An enemy four screens away
			# is allowed to be a stale dot; one on their screen is not.
			if view.has_point(node.global_position) \
					or view.has_point(want["enemies"][id]):
				on_screen[id] = int(on_screen.get(id, 0)) + 1
				if e > float(worst.get(id, 0.0)):
					worst[id] = e
					how_far[id] = world.runner.global_position.distance_to(
						want["enemies"][id])
			else:
				worst_off[id] = maxf(float(worst_off.get(id, 0.0)), e)

	print("  compared %d frames" % compared)
	_ok("the guardian's runner is where the host's runner was (%.1fpx worst, tick %d)"
			% [runner_worst, runner_worst_tick],
		compared > 0 and runner_worst <= runner_tolerance,
		"tolerance %.0fpx" % runner_tolerance)

	var ids := _unique_sorted(worst.keys() + worst_off.keys() + vanished.keys())
	var wrong: Array = []
	var watched := 0
	for id in ids:
		if int(on_screen.get(id, 0)) > 0:
			watched += 1
		if float(worst.get(id, 0.0)) > enemy_tolerance or int(vanished.get(id, 0)) > 0:
			wrong.append(id)
	if not wrong.is_empty():
		print("  the ones that disagree:")
		for id in wrong:
			print("    #%-3d on screen %4d frames, worst %7.1fpx at %6.0fpx from the runner, missing %4d"
				% [id, int(on_screen.get(id, 0)), float(worst.get(id, 0.0)),
					float(how_far.get(id, -1.0)), int(vanished.get(id, 0))])
	_ok("every enemy the guardian can see is where the host has it (%d of %d wrong)"
			% [wrong.size(), watched],
		compared > 0 and watched > 0 and wrong.is_empty(),
		"tolerance %.0fpx, ids %s" % [enemy_tolerance, str(wrong)])
	# Or the check above is a check on an empty set that passes forever.
	_ok("the sweep put %d enemies in front of the guardian" % watched,
		watched >= want_watched, "wanted at least %d" % want_watched)

	world.free()
	await _frames(3)

## What the guardian's screen covers, in world coordinates, widened by the
## margin an enemy has to be correct within before it arrives.
func _guardian_view(world: Node2D) -> Rect2:
	var size: Vector2 = world.get_viewport().get_visible_rect().size \
		/ world.camera.zoom
	return Rect2(world.camera.global_position - size * 0.5, size).grow(VIEW_MARGIN)

func _guest_enemy(id: int) -> Node2D:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node2D and e.get("net_id") != null and int(e.get("net_id")) == id:
			return e
	return null

func _unique_sorted(values: Array) -> Array:
	var seen := {}
	for v in values:
		seen[int(v)] = true
	var out: Array = seen.keys()
	out.sort()
	return out

# --------------------------------------------------------- the blinking partner

## The guardian's runner is a puppet with its physics switched off, and the
## invulnerability timer that drives the hurt blink is ticked by that physics.
## Nothing else ticks it. So a respawn on the guardian's screen starts a blink
## with nothing left in the world to end it.
func _invulnerability_expires() -> void:
	Clock.reset(0)
	var link := LoopbackTransport.pair(0.0)
	var world := await _build()
	world._become_client(link[0])
	await _frames(2)
	world.runner.respawn(world.runner.global_position)
	_ok("the runner is invulnerable the moment they respawn",
		world.runner.is_invulnerable())
	var waited := 0.0
	while waited < Balance.RUNNER_HURT_INVULN * 2.0 + 0.5:
		await get_tree().physics_frame
		waited += Clock.DT
	_ok("...and is not still invulnerable %.1fs later (the blink ends)" % waited,
		not world.runner.is_invulnerable())
	world.free()
	await _frames(3)

# ----------------------------------------------------------- shooting by name

## The guardian fires at what their screen shows, and their screen is always a
## little behind. So the host is handed a position that is out of date by the
## time it reads the packet, and it used to resolve the shot against it -- 26px
## exactly, 110 with the assist. Anything that had walked further than that in
## the meantime simply was not hit, which is "even when I hit an enemy I cannot
## kill it". The packet now names the enemy as well, and the second half of
## this checks that the NAME is what does the work: the same shot with the same
## stale position and no name has to miss.
func _shot_follows_its_target() -> void:
	Clock.reset(0)
	var link := LoopbackTransport.pair(0.0)
	var guardian_side: LoopbackTransport = link[1]
	var world := await _build()
	world._become_host(link[0])
	await _frames(2)

	var walker := _a_walking_enemy()
	if walker == null:
		_ok("there is a walking enemy to shoot at", false)
		world.free()
		await _frames(3)
		return
	var net_id := int(walker.get("net_id"))
	var stale := walker.global_position
	# Let it walk out from under the guardian's old reading of it. A walker
	# turns at the end of its patrol, so this waits for the far end of the leg
	# rather than for a fixed number of ticks.
	var moved := 0.0
	for _i in range(420):
		await get_tree().physics_frame
		moved = walker.global_position.distance_to(stale)
		if moved > SniperAbility.ASSIST_RADIUS * 1.3:
			break
	_ok("the enemy walked %.0fpx out of the shot's reach while it was in flight"
			% moved,
		moved > SniperAbility.ASSIST_RADIUS,
		"needs to be past the %.0fpx assist for this to prove anything"
			% SniperAbility.ASSIST_RADIUS)

	walker.hp = 1
	await _fire_at(world, guardian_side, stale, Protocol.NO_TARGET, 1)
	_ok("...and an unnamed shot at where it USED to be misses it",
		is_instance_valid(walker) and int(walker.hp) > 0)

	await _fire_at(world, guardian_side, stale, net_id, 2)
	_ok("...but a shot that names it kills it, stale position and all",
		not is_instance_valid(walker) or int(walker.hp) <= 0)

	world.free()
	await _frames(3)

func _a_walking_enemy() -> Node2D:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Walker and int(e.get("net_id")) >= 0:
			return e
	return null

func _fire_at(world: Node2D, from: LoopbackTransport, at: Vector2,
		target_id: int, seq: int) -> void:
	world.guardian.gauge = Balance.GAUGE_MAX
	world.guardian.abilities[3].cooldown = 0.0
	from.send(NetTransport.Channel.COMMAND,
		NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.fire(at, Clock.tick, seq, target_id))
	for _i in range(6):
		from.peer.advance(Clock.DT)
		await get_tree().physics_frame

# ------------------------------------------------------- the ghost and the wall

## The ghost is a promise, and it is the same promise however the button was
## pressed: whatever the guardian pointed at. A tap used to break it twice over
## -- the commit resolved through a set of placement rules while the preview was
## drawn at the reticle, so a tap both ignored the chosen place AND built
## somewhere the ghost had never been.
func _ghost_is_where_it_lands() -> void:
	Clock.reset(0)
	var world := await _build()
	await _frames(2)
	var guardian: Guardian = world.guardian
	var hub: InputHub = world.input_hub

	for slot in [1, 2]:
		# Somewhere no placement rule would ever have chosen, which is exactly
		# the case a tap used to overwrite.
		hub.aim_at_world(world.runner.global_position + Vector2(700, -400))
		# The guardian reads the reticle once a frame; ask it after it has.
		await _frames(2)
		var ghost: Dictionary = guardian.preview_of(slot, false)
		var lands: Vector2 = guardian.target_for(slot, false)
		_ok("tool %d: the ghost is drawn where a tap would put it" % slot,
			ghost.has("rect") and (ghost["rect"] as Rect2).get_center()
				.distance_to(lands) < 1.0,
			"ghost %s, lands at %s" % [str(ghost.get("rect", "-")), str(lands)])
		_ok("tool %d: a tap lands on the reticle, not on a rule's idea" % slot,
			lands.distance_to(hub.aim_world()) < 1.0,
			"lands at %s, reticle is %s" % [str(lands), str(hub.aim_world())])
		var dragged: Vector2 = guardian.target_for(slot, true)
		_ok("tool %d: and a drag lands in the same place a tap would" % slot,
			dragged.distance_to(lands) < 1.0,
			"dragged %s, tapped %s" % [str(dragged), str(lands)])
	world.free()
	await _frames(3)

# --------------------------------------------------- standing, on the far screen

## Ground contact is DRAWN -- the contact shadow shrinks and fades in the air,
## and landing plays a crouch. All of it read is_on_floor(), which on this
## device is the leftover answer from the last move_and_slide() the puppet ever
## ran. Frozen, it made a runner who had plainly landed go on wearing the
## airborne shadow: "after landing the character sometimes looks like it is
## floating", on the screen where nothing is simulated.
func _the_puppet_knows_the_ground() -> void:
	Clock.reset(0)
	var link := LoopbackTransport.pair(0.0)
	var feed: LoopbackTransport = link[1]
	var world := await _build()
	world._become_client(link[0])
	await _frames(2)

	var r: Runner = world.runner
	r.grounded = false
	await _feed_snapshots(world, feed, true, 12)
	_ok("told the runner is standing, the puppet agrees", r.on_ground())

	await _feed_snapshots(world, feed, false, 12)
	_ok("...and told it is in the air, it agrees with that too", not r.on_ground())

	await _feed_snapshots(world, feed, true, 12)
	_ok("...and back again, so a landing is visible at all", r.on_ground())

	world.free()
	await _frames(3)

## Two snapshots a tick apart saying the same thing, so the client has a pair to
## interpolate between and actually renders.
func _feed_snapshots(world: Node2D, feed: LoopbackTransport,
		on_floor: bool, frames: int) -> void:
	for _i in range(frames):
		var s := Snapshot.new()
		s.tick = Clock.tick
		s.runner_position = world.runner.global_position
		s.runner_velocity = Vector2.ZERO
		s.runner_state = int(Runner.State.IDLE)
		s.facing = 1
		s.on_floor = on_floor
		s.hp = Balance.RUNNER_MAX_HP
		s.gauge = Balance.GAUGE_MAX
		feed.send(NetTransport.Channel.SNAPSHOT,
			NetTransport.Reliability.UNRELIABLE, s.encode())
		link_advance(feed)
		await get_tree().physics_frame

func link_advance(feed: LoopbackTransport) -> void:
	if feed.peer != null:
		feed.peer.advance(Clock.DT)
	feed.advance(Clock.DT)
	feed.poll()
