extends Node
## Two devices, one relay, one game, played from the buttons.
##
## Everything else in the suite runs in one process. That is the right shape for
## almost all of it -- record the host, replay into a guest, compare -- but it
## cannot answer the question the whole project rests on: if two people press
## their own buttons on their own machines, does the same game happen.
##
## So this scene is run TWICE, as two processes, against a real relay:
##
##   godot --headless --path . res://test/duet_probe.tscn ++ --runner  --room ABCD
##   godot --headless --path . res://test/duet_probe.tscn ++ --guardian --room ABCD
##
## tools/duet.sh starts the relay and both of them and merges the output.
##
## Neither side is told what the other is doing. They agree the way two players
## do -- by watching the world -- and each side checks only what IT can see, so
## a disagreement shows up as one side failing while the other passes rather
## than as a single process quietly agreeing with itself.
##
## The guardian's every action goes in as a TOUCH, at a screen position worked
## out from a world point, so the path under test is the real one: finger ->
## screen -> world -> packet -> the host's judgement -> back to both screens.
## Calling guardian.use_active() here would skip four of those five.

const RELAY_DEFAULT := "ws://localhost:8787"

## Where the pair meet. Far enough into 1-C's opening plateau to have room, and
## on flat ground so nothing else is happening while they work.
const MEET_X := -1000.0

var main: Node2D = null
var role := ""
var room := ""
var relay := ""
var failures: int = 0
var checks: int = 0
var _deadline_ms: int = 0

## The last thing the host refused, and why. Set from Events.ability_refused.
var _last_reject: String = ""

## Set by the last line of each side's script. See _ready.
var _finished: bool = false

func _ready() -> void:
	_read_arguments()
	if role.is_empty():
		print("duet: pass --runner or --guardian")
		get_tree().quit(2)
		return
	print("[%s] room %s via %s" % [role, room, relay])
	_deadline_ms = Time.get_ticks_msec() + 300000
	await _run()
	print("")
	# A runtime error inside an awaited function abandons it WITHOUT failing
	# anything: the remaining checks simply never run and the tally says all is
	# well. That has bitten this project three times now, once here -- a freed
	# wall took the runner's script out after nine checks and it reported PASS.
	if not _finished:
		failures += 1
		checks += 1
		print("[%s] FAIL  the script ran to the end (it stopped early)" % role)
	if failures == 0:
		print("[%s] PASS  %d checks" % [role, checks])
	else:
		print("[%s] FAIL  %d of %d checks" % [role, failures, checks])
	get_tree().quit(1 if failures > 0 else 0)

func _read_arguments() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		match args[i]:
			"--runner": role = "runner"
			"--guardian": role = "guardian"
			"--room":
				if i + 1 < args.size():
					room = args[i + 1]
			"--relay":
				if i + 1 < args.size():
					relay = args[i + 1]
	if relay.is_empty():
		relay = OS.get_environment("RELAY")
	if relay.is_empty():
		relay = RELAY_DEFAULT
	if room.is_empty():
		room = "DUET"

func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame

func _physics(n: int) -> void:
	for _i in range(n):
		await get_tree().physics_frame

func _ok(label: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("[%s] ok    %s" % [role, label])
	else:
		failures += 1
		print("[%s] FAIL  %s%s" % [role, label,
			"" if detail.is_empty() else "  -- " + detail])

## Waits for something to become true, or gives up. Everything in a two-process
## test is a wait for the other side, and a wait without a deadline is a hang
## that looks like a slow test.
func _until(what: Callable, seconds: float, label: String) -> bool:
	var stop := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < stop:
		await get_tree().physics_frame
		if bool(what.call()):
			return true
		if Time.get_ticks_msec() > _deadline_ms:
			print("[%s] .. overall deadline passed while waiting for %s" % [role, label])
			return false
	return false

# ----------------------------------------------------------------- the game

func _run() -> void:
	Stage.use(Stage.Which.CROSSING)
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(6)
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
		await _frames(2)
	main.input_hub.scripted = true

	var err := ""
	if role == "runner":
		err = main.host_relay(relay, room)
	else:
		# The guest waits a moment so the room exists: a guardian who dials an
		# empty room is told they are the host, which is a real situation the
		# link reports rather than an error, but it is not the one under test.
		await _physics(90)
		err = main.join_relay(relay, room)
	_ok("dialled the relay", err == "", err)
	if err != "":
		return

	var linked := await _until(func() -> bool:
		return main.link.phase == NetLink.Phase.PLAYING, 40.0, "the handshake")
	_ok("the link reaches プレイ中", linked,
		"stopped at %s" % NetLink.LABELS.get(main.link.phase, "?"))
	if not linked:
		return
	_ok("and this device knows which side it is on",
		(role == "runner") == Clock.is_host, "is_host=%s" % str(Clock.is_host))

	if role == "runner":
		await _as_the_runner()
	else:
		await _as_the_guardian()

	# Both sides say how it ended, so a log that stops early is visible as such.
	print("[%s] .. finished at tick %d" % [role, Clock.tick])

# ------------------------------------------------------------------ the runner

func _as_the_runner() -> void:
	var r: Runner = main.runner
	main._respawn_timer = -1.0
	r.global_position = Vector2(MEET_X, Level02Data.FLOOR - 60.0)
	r.velocity = Vector2.ZERO
	await _physics(40)
	_ok("the runner is standing on the opening plateau", r.is_on_floor())

	# The gauge lives on this device. Every drop it takes is recorded, so the
	# cost of what the guardian does is checked against the authority rather
	# than against the other device's prediction of it.
	#
	# The baseline is the FIRST value actually seen, not GAUGE_MAX. Assuming the
	# starting value made this read a 27-point charge for a 30-point platform
	# and look like a bug: the guardian's first processed frame after the link
	# comes up carries a long delta, so a third of a second of regeneration
	# lands in the same step as the charge. Nothing was wrong except the
	# measurement.
	var gauge_trail := {"last": -1.0, "worst": 0.0}
	var watch_gauge := func(now: float, _max: float) -> void:
		if gauge_trail["last"] >= 0.0:
			gauge_trail["worst"] = maxf(gauge_trail["worst"],
				float(gauge_trail["last"]) - now)
		gauge_trail["last"] = now
	Events.gauge_changed.connect(watch_gauge)

	# 1. A PLATFORM. The guardian puts one down; the host is the one that
	#    decides whether it may exist, so seeing it here is the decision.
	var slab := await _until(func() -> bool:
		return main.guardian.holograms_of(Hologram.Kind.PLATFORM).size() > 0,
		30.0, "the guardian's platform")
	_ok("a platform the guardian asked for exists on the host", slab)
	if not slab:
		return
	var deck: Hologram = main.guardian.holograms_of(Hologram.Kind.PLATFORM).back()
	print("[runner] .. platform at %s" % str(deck.global_position.round()))

	# 2. THE LAUNCH. Get aboard, face forward, and wait to be shot off it. The
	#    runner does not fire it and cannot; that is the point of the move.
	r.global_position = deck.global_position + Vector2(0.0, -60.0)
	r.velocity = Vector2.ZERO
	r.facing = 1
	await _until(func() -> bool: return r.is_on_floor(), 4.0, "landing on the slab")
	_ok("the runner boards it", deck.trigger != null and deck.trigger.loaded(),
		"on_floor=%s" % str(r.is_on_floor()))
	var shots := [0, 0, Vector2.ZERO]
	var watch_shot := func(_from: Vector2, to: Vector2, hit: bool) -> void:
		shots[0] += 1
		shots[2] = to
		if hit:
			shots[1] += 1
	Events.shot_fired.connect(watch_shot)
	var before := r.global_position
	var thrown := await _until(func() -> bool: return r.velocity.y < -200.0,
		30.0, "the guardian's shot")
	Events.shot_fired.disconnect(watch_shot)
	print("[runner] .. host saw %d shots, %d of them hit something; gauge %.0f, cooldown %.2f"
		% [shots[0], shots[1], main.guardian.gauge,
			(main.guardian.abilities[3] as SniperAbility).cooldown])
	if is_instance_valid(deck) and deck.trigger != null:
		print("[runner] .. shot landed at %s; trigger at %s armed=%s loaded=%s; runner %s"
			% [str((shots[2] as Vector2).round()),
				str(deck.trigger.global_position.round()), str(deck.trigger.armed),
				str(deck.trigger.loaded()), str(r.global_position.round())])
	else:
		print("[runner] .. the slab was gone by then (lifetime %.0fs); shot landed at %s"
			% [Balance.PLATFORM_LIFETIME, str((shots[2] as Vector2).round())])
	_ok("the guardian's shot throws the runner", thrown,
		"velocity %s" % str(r.velocity.round()))
	if thrown:
		main.input_hub.move_axis = 1.0
		await _physics(80)
		main.input_hub.move_axis = 0.0
		var flew := r.global_position.x - before.x
		_ok("and carries them further than they could jump (%.0fpx)" % flew, flew > 400.0)

	# 3. A WALL, and a kick off it. Same shape: the guardian builds, the runner
	#    uses. A wall is the one construct the runner can push against.
	main._respawn_timer = -1.0
	r.global_position = Vector2(MEET_X + 400.0, Level02Data.FLOOR - 60.0)
	r.velocity = Vector2.ZERO
	await _physics(30)
	var walled := await _until(func() -> bool:
		return main.guardian.holograms_of(Hologram.Kind.WALL).size() > 0,
		30.0, "the guardian's wall")
	_ok("a wall the guardian asked for exists on the host", walled)
	if walled:
		# By VALUE. A wall lives four seconds and the guardian rebuilds it while
		# this runs, so the node under any reference held here is liable to be
		# freed between attempts -- and reading a freed node does not fail a
		# check, it abandons the whole function.
		var wall_at: Vector2 = (main.guardian.holograms_of(Hologram.Kind.WALL).back()
			as Node2D).global_position
		var kicked := [false]
		var watch := func(_at: Vector2, _away: int) -> void: kicked[0] = true
		Events.runner_wall_jumped.connect(watch)
		for _attempt in range(10):
			if kicked[0]:
				break
			var live: Array = main.guardian.holograms_of(Hologram.Kind.WALL)
			if not live.is_empty():
				wall_at = (live.back() as Node2D).global_position
			r.global_position = wall_at + Vector2(60.0, 40.0)
			r.velocity = Vector2.ZERO
			await _physics(10)
			main.input_hub.move_axis = 0.0
			main.input_hub.press_jump()
			main.input_hub.jump_held = true
			await _physics(18)
			main.input_hub.jump_held = false
			main.input_hub.move_axis = -1.0
			for _i in range(24):
				await get_tree().physics_frame
				if r.can_wall_jump():
					main.input_hub.press_jump()
					break
			await _physics(10)
			main.input_hub.move_axis = 0.0
		Events.runner_wall_jumped.disconnect(watch)
		_ok("the runner can kick off the guardian's wall", kicked[0])

	# 4. A CRYSTAL. The runner fetches it; the GUARDIAN's gauge is what it pays,
	#    and the guardian is the one who checks that. Here we only confirm the
	#    host counted it once.
	var crystals := get_tree().get_nodes_in_group("crystal")
	_ok("there are crystals on the stage (%d)" % crystals.size(), crystals.size() > 0)
	if not crystals.is_empty():
		var taken := [0]
		var watch := func(_c: Node2D) -> void: taken[0] += 1
		Events.crystal_reached.connect(watch)
		var c: Node2D = crystals[0]
		main._respawn_timer = -1.0
		r.global_position = c.global_position
		r.velocity = Vector2.ZERO
		await _physics(20)
		Events.crystal_reached.disconnect(watch)
		_ok("the host counts a crystal exactly once (%d)" % taken[0], taken[0] == 1)

	# 5. A SHIELD-BEARER. The runner's whole contribution is standing somewhere:
	#    the thing turns to face whoever is nearest, and its soft spot is on the
	#    other side. Neither player can do this alone -- the runner cannot hurt
	#    it and the guardian cannot see a way in until the runner makes one.
	var bearers := get_tree().get_nodes_in_group("shieldbearer")
	_ok("the corridor has shield-bearers (%d)" % bearers.size(), bearers.size() >= 2)
	if not bearers.is_empty():
		var bearer = bearers[0]
		main._respawn_timer = -1.0
		# Settle on one side, then CROSS. Standing near it does nothing: the
		# soft spot opens when the runner drags it round, which is the one
		# thing in this fight the guardian cannot do for themselves.
		r.global_position = Vector2(bearer.global_position.x + 220.0,
			Level02Data.MID - 60.0)
		r.velocity = Vector2.ZERO
		await _physics(20)
		# Arriving on the far side is itself a crossing, so the window opens
		# and that is right. What must not happen is it staying open while
		# the runner stands still.
		await _physics(int((Balance.SHIELDBEARER_TURN_TIME
			+ Balance.SHIELDBEARER_OPEN_TIME + 0.5) * 60.0))
		_ok("standing still does not keep the soft spot open",
			is_instance_valid(bearer) and not bearer.exposed())
		r.global_position = Vector2(bearer.global_position.x - 220.0,
			Level02Data.MID - 60.0)
		r.velocity = Vector2.ZERO
		var turned := await _until(func() -> bool:
			return is_instance_valid(bearer) and bearer.facing_now() == -1, 6.0, "the turn")
		_ok("crossing it turns it toward the runner", turned)
		# Facing flips when the turn STARTS; the window opens when it finishes.
		# The shield sweeps across the back on the way round, which is the whole
		# reason there is a delay to wait out.
		var opened := await _until(func() -> bool:
			return is_instance_valid(bearer) and bearer.exposed(), 6.0, "the opening")
		_ok("and finishing the turn is what opens the soft spot", opened)
		# Keep crossing while the guardian works. The window shuts on its own,
		# so a pair who stop moving stop making openings -- which is the whole
		# argument for this enemy existing.
		_cross_while_they_work(bearer, r)
		# What is checked here is the MECHANIC, not the kill. Two shots at 20
		# gauge against 8/s of regeneration means whether the second one lands
		# inside any particular window is a question about the economy and about
		# how fast two processes happen to be running -- it came out differently
		# on different runs and proved nothing either way. The two facts the
		# whole co-op idea rests on are sharper than that: the plate stops a
		# shot, and the opening the runner made does not. Both are decided on
		# THIS device, which owns the enemy and its hp -- the guardian's copy
		# never sees an hp number at all, because enemy hp is not in the
		# snapshot.
		var blocked := [0]
		var stopped := func(_at: Vector2) -> void: blocked[0] += 1
		Events.shot_blocked.connect(stopped)
		var life: int = bearer.hp
		var hurt := await _until(func() -> bool:
			return not is_instance_valid(bearer) or bearer.is_queued_for_deletion() \
				or bearer.hp < life, 70.0, "the guardian's shot into its back")
		Events.shot_blocked.disconnect(stopped)
		_ok("the plate stopped at least one of the guardian's shots (%d)" % blocked[0],
			blocked[0] > 0)
		_ok("and a shot through the opening the runner made got in", hurt,
			"hp %d" % (bearer.hp if is_instance_valid(bearer) else -1))

	# Stay alive while the guardian finishes, and in particular sit through
	# their disconnect.
	#
	# A host that quits takes the room with it, and the guardian's last check is
	# that a dropped link comes BACK -- which it cannot do to an empty room. So
	# this cannot end when the peer goes away: the peer going away is the test.
	# An earlier version broke out on exactly that and the guardian spent its
	# whole 90-second budget re-dialling a room nobody was in.
	#
	# Long enough for the silence to be noticed (7s), the retries to land (every
	# 2s), and the world to be handed back afterwards.
	await _physics(int(60.0 * 60.0))
	Events.gauge_changed.disconnect(watch_gauge)
	_ok("the host charged the guardian the full price of a platform (%.1f)"
			% gauge_trail["worst"],
		float(gauge_trail["worst"]) >= Balance.COST_PLATFORM - 0.5)
	_finished = true

## Keep the runner crossing the enemy while the guardian works on it.
##
## Runs alongside rather than blocking: the window shuts on its own, so a pair
## who stop moving stop making openings. One shot is never enough, which means
## the runner's job here does not finish when the guardian starts theirs.
func _cross_while_they_work(bearer: Node2D, r: Runner) -> void:
	var side := -1.0
	for _i in range(40):
		if not is_instance_valid(bearer) or bearer.is_queued_for_deletion():
			return
		if not bearer.exposed():
			side = -side
			r.global_position = Vector2(bearer.global_position.x + 220.0 * side,
				Level02Data.MID - 60.0)
			r.velocity = Vector2.ZERO
		await _physics(24)

# ---------------------------------------------------------------- the guardian

func _as_the_guardian() -> void:
	var g: Guardian = main.guardian
	var r: Runner = main.runner
	# What the host says when it says no. A reject arrives as ability_refused
	# rather than through guardian.refusal(), which only ever holds a refusal
	# this device decided for itself.
	Events.ability_refused.connect(func(slot: int, reason: String) -> void:
		_last_reject = "slot %d: %s" % [slot, reason])
	var here := await _until(func() -> bool:
		return absf(r.global_position.x - MEET_X) < 400.0, 30.0, "the runner")
	_ok("the runner shows up where the host put them", here,
		"saw x=%.0f" % r.global_position.x)

	# 1. A PLATFORM, placed the way a thumb places one: choose the tool, then
	#    tap the ground. The button alone must not build anything.
	var before := g.holograms_of(Hologram.Kind.PLATFORM).size()
	await _press_slot(1)
	await _physics(12)
	_ok("choosing the tool does not build anything",
		g.holograms_of(Hologram.Kind.PLATFORM).size() == before)

	var want := r.global_position + Vector2(140.0, -70.0)
	await _tap_world(want)
	var built := await _until(func() -> bool:
		return g.holograms_of(Hologram.Kind.PLATFORM).size() > before,
		20.0, "the host's answer")
	_ok("tapping the ground builds one", built, g.refusal())
	if not built:
		return
	var deck: Hologram = g.holograms_of(Hologram.Kind.PLATFORM).back()
	var off := deck.global_position.distance_to(want)
	# The host owns the coordinate and quantises it into the snapshot; a quarter
	# of a pixel is the wire's resolution, the rest would be somebody moving it.
	_ok("and it lands where the finger pointed (%.2fpx away)" % off, off < 8.0,
		"asked %s, got %s" % [str(want.round()), str(deck.global_position.round())])

	# 2. THE LAUNCH, fired with the rifle at the marker on the slab. Wait for
	#    the runner to be aboard -- both devices can see that, which is what
	#    makes the timing shareable without a word.
	var aboard := await _until(func() -> bool:
		return deck.trigger != null and deck.trigger.loaded(), 30.0, "the runner boarding")
	_ok("the guardian can see the runner is aboard", aboard)
	if aboard:
		g.gauge = Balance.GAUGE_MAX
		await _press_slot(3)
		await _tap_world(deck.trigger.global_position)
		var went := await _until(func() -> bool:
			return r.velocity.y < -200.0 or r.global_position.x > deck.global_position.x + 200.0,
			20.0, "the launch")
		print("[guardian] .. aimed at %s, refusal %s, gauge %.0f" % [
			str(deck.trigger.global_position.round()),
			"(none)" if g.refusal().is_empty() else g.refusal(), g.gauge])
		_ok("and shooting the marker launches them, seen from here", went,
			"velocity %s" % str(r.velocity.round()))
		var spent := await _until(func() -> bool:
			return deck.trigger == null or not deck.trigger.armed, 10.0, "the trigger")
		_ok("the trigger reads as spent on the guardian's screen too", spent)

	# 3. A WALL, again through the buttons.
	await _until(func() -> bool:
		return absf(r.global_position.x - (MEET_X + 400.0)) < 300.0, 25.0, "the runner")
	var walls := g.holograms_of(Hologram.Kind.WALL).size()
	await _press_slot(2)
	# Standing ON the ground: a wall whose bottom is buried in the terrain is
	# refused as blocked, and rightly so.
	var foot: float = r.global_position.y + Balance.RUNNER_SIZE.y * 0.5
	await _tap_world(Vector2(r.global_position.x - 90.0,
		foot - Balance.WALL_SIZE.y * 0.5))
	var wall_up := await _until(func() -> bool:
		return g.holograms_of(Hologram.Kind.WALL).size() > walls, 20.0, "the wall")
	_ok("a wall goes up where the finger pointed", wall_up, g.refusal())
	# And keep one standing. A wall lasts four seconds, which is right for the
	# game -- it is a moment of cover, not a building -- and it means a guardian
	# whose runner is still lining the kick up puts down another. So does this.
	for _again in range(4):
		await _physics(200)
		await _press_slot(2)
		await _tap_world(Vector2(r.global_position.x - 90.0,
			r.global_position.y + Balance.RUNNER_SIZE.y * 0.5
				- Balance.WALL_SIZE.y * 0.5))

	# 4. THE GAUGE. A crystal the runner fetches has to arrive here as gauge,
	#    because the guardian is the only one who can spend it.
	# NOT set from here: on this device the gauge is the host's number arriving
	# in snapshots, so a local assignment is overwritten within a frame and
	# would make this check a test of nothing.
	var low := g.gauge
	var paid := await _until(func() -> bool: return g.gauge > low + 1.0,
		40.0, "a crystal")
	_ok("a crystal the runner picked up arrives here as gauge", paid,
		"%.0f -> %.0f" % [low, g.gauge])

	# 5. UNDO. The guardian's own control, and it must not refund -- otherwise
	#    build-and-undo is a free look at the world.
	# Let it fill first. The gauge regenerates at 8/s, so a check that starts
	# from a half-full bar is racing the refill rather than measuring the cost.
	await _until(func() -> bool: return g.gauge >= Balance.GAUGE_MAX - 1.0,
		20.0, "a full gauge")
	var spent_before := g.gauge
	var count := g.holograms_of(Hologram.Kind.PLATFORM).size()
	await _press_slot(1)
	await _tap_world(r.global_position + Vector2(220.0, -70.0))
	# What the guardian sees the instant they commit, before anything has had
	# time to come back: the local prediction. This is the number on the bar.
	var predicted := g.gauge
	_ok("committing takes the cost off the bar at once", predicted < spent_before - 1.0,
		"%.0f -> %.0f" % [spent_before, predicted])
	var landed := await _until(func() -> bool:
		return g.holograms_of(Hologram.Kind.PLATFORM).size() > count, 15.0, "one more slab")
	_ok("and the host lets it exist", landed)
	# Whether the HOST charged is not a question this device can answer: the bar
	# here is a local prediction that a snapshot then confirms or corrects, and
	# the two are indistinguishable from this side. The runner's device owns the
	# gauge, so it is the one that checks the charge.
	# 5. THE SHIELD-BEARER. Wait for the runner to draw it, then shoot what the
	#    runner opened. The plate must eat a shot and the back must not.
	var bearers := get_tree().get_nodes_in_group("shieldbearer")
	if not bearers.is_empty():
		var bearer = bearers[0]
		var open_now := await _until(func() -> bool:
			return is_instance_valid(bearer) and bearer.exposed(), 30.0, "the opening")
		_ok("the guardian can see when the soft spot is open", open_now)
		if open_now:
			print("[guardian] .. bearer %s plate %s weak %s facing %d exposed=%s"
				% [str(bearer.global_position.round()),
					str(bearer._shield.global_position.round()),
					str(bearer._weak.global_position.round()),
					bearer.facing_now(), str(bearer.exposed())])
			# Aim at the plate first, then at the back. Whether either landed
			# is the runner's device to say: an enemy's hp is not in the
			# snapshot, so the number on this side never moves however many
			# shots go off. What this device is for is the AIMING -- that the
			# two halves are in the right places on this screen, which is the
			# thing that was broken.
			await _shoot_at(bearer._shield.global_position)
			for _i in range(5):
				if not is_instance_valid(bearer) or bearer.is_queued_for_deletion():
					break
				await _shoot_at(bearer._weak.global_position)
			_ok("the plate and the soft spot are on opposite sides here too",
				absf(bearer._shield.global_position.x - bearer._weak.global_position.x)
					> Shieldbearer.REACH if is_instance_valid(bearer) else true)

	var before_undo := g.gauge
	await _press("undo")
	await _physics(30)
	_ok("undo takes the last one back",
		g.holograms_of(Hologram.Kind.PLATFORM).size() <= count)
	# No refund: this is for a wall across the wrong doorway, not for changing
	# your mind about the price. The gauge regenerates at 8/s, so half a cost is
	# the margin that tells a refund apart from half a second of refilling.
	_ok("and does not refund it",
		g.gauge < before_undo + Balance.COST_PLATFORM * 0.5,
		"%.0f -> %.0f" % [before_undo, g.gauge])

	# 6. A DROPPED LINK. Not a nicety: a phone that locks its screen or changes
	#    network does this, and the guardian must come back to the same world
	#    rather than to an empty one. The socket is closed from under the
	#    session, which is what a dropped connection looks like from in here.
	var crystals_before := 0
	for c in get_tree().get_nodes_in_group("crystal"):
		if not c.taken():
			crystals_before += 1
	var runner_before := r.global_position
	main.client_session.transport.close()
	var noticed := await _until(func() -> bool:
		return main.link.phase == NetLink.Phase.RECONNECTING \
			or main.link.phase == NetLink.Phase.FAILED, 20.0, "the drop")
	_ok("a dropped link is noticed and says so", noticed,
		NetLink.LABELS.get(main.link.phase, "?"))
	var back := await _until(func() -> bool:
		return main.link.phase == NetLink.Phase.PLAYING, 45.0, "the link coming back")
	_ok("and it comes back on its own", back,
		"stopped at %s after %d tries" % [NetLink.LABELS.get(main.link.phase, "?"),
			main.link.reconnects])
	if back:
		await _physics(60)
		var crystals_after := 0
		for c in get_tree().get_nodes_in_group("crystal"):
			if not c.taken():
				crystals_after += 1
		_ok("the world came back with it, not a fresh one (%d crystals, was %d)"
				% [crystals_after, crystals_before], crystals_after == crystals_before)
		_ok("and the runner is where the host has them, not where they were left",
			r.global_position.distance_to(runner_before) < 4000.0,
			"%s vs %s" % [str(r.global_position.round()), str(runner_before.round())])
	_finished = true

# ------------------------------------------------------------------- the thumb

## Waits until the rifle is affordable, then fires it at a world point.
## Returns whether the gauge actually went down, which is the only evidence from
## this side that a shot happened at all.
##
## The waiting is not padding. The gauge regenerates at 8/s and the rifle costs
## 20, so late in a run the guardian genuinely cannot fire on demand -- and a
## test that ignored that was firing into a refusal and reading the silence as
## "the shield held".
func _shoot_at(point: Vector2) -> bool:
	await _until(func() -> bool:
		return main.guardian.gauge >= Balance.COST_SNIPE + 4.0, 12.0, "gauge for a shot")
	var before: float = main.guardian.gauge
	await _press_slot(3)
	await _tap_world(point)
	await _physics(50)
	var spent := float(main.guardian.gauge) < before - Balance.COST_SNIPE * 0.5
	print("[guardian] .. fired at %s: gauge %.0f -> %.0f (%s, host said %s, slot %d)"
		% [str(point.round()), before, main.guardian.gauge,
			"spent" if spent else "nothing happened",
			"(nothing)" if _last_reject.is_empty() else _last_reject,
			main.guardian.active_slot])
	_last_reject = ""
	return spent

## Presses a control. Down and up on the button itself, which for a tool button
## chooses the tool and -- because the finger never left it -- must not place
## anything.
func _press(id: String) -> void:
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	var places := ControlLayout.layout("guardian", view, false)
	if not places.has(id):
		_ok("the guardian has a %s button" % id, false)
		return
	var at: Vector2 = places[id]["center"]
	main.input_hub._touch_down(31, at)
	await _frames(2)
	main.input_hub._touch_up(31)
	await _frames(3)

func _press_slot(slot: int) -> void:
	await _press("slot_%d" % slot)

## A tap on a WORLD point, converted to the screen the way a finger finds it.
## Copied in spirit from run_tests._tap_world, and for the same reason: poking
## a world coordinate directly would skip the half of the path that has been
## wrong before.
func _tap_world(point: Vector2) -> void:
	var rect: Rect2 = main.get_viewport().get_visible_rect()
	var screen: Vector2 = main.get_viewport().get_canvas_transform() * point
	if _unreachable(screen, rect):
		# Bring the view round, which is what a guardian does. The ability bar
		# lives along the bottom of the screen and so does the ground, so a
		# target low in the view sits UNDER a button -- and a touch there is a
		# tool being chosen, not a place being picked.
		#
		# That is not a hypothetical. Every shot after the first at a
		# shield-bearer's soft spot was landing on the warp button: the tool
		# quietly changed to slot 4 and five "shots" in a row did nothing while
		# this test reported that the rifle had been refused.
		main.camera.global_position = point
		await _physics(3)
		screen = main.get_viewport().get_canvas_transform() * point
	main.input_hub._touch_down(21, screen)
	main.input_hub._touch_up(21)
	await _frames(5)

## Is this screen point one a guardian could not simply tap -- off the view, on
## the runner's half of a shared screen, or underneath one of their own controls?
func _unreachable(screen: Vector2, rect: Rect2) -> bool:
	if not rect.grow(-40.0).has_point(screen):
		return true
	if not TouchLayout.hit_rect(screen, TouchLayout.AIM_ZONE, rect.size, false):
		return true
	return ControlLayout.hit("guardian", rect.size, false, screen) != ""
