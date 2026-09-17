extends Node
## Can two people actually beat 1-B?
##
## Same standard as stage_probe: not "does it build" and not "are the numbers
## plausible", but -- does the fight work when it is fought. Every rule in
## docs/stage-keeper.md is played here, and a rule that stops holding fails by
## name.
##
## The arithmetic claims are checked against arcs THIS FILE MEASURES rather than
## against constants, and that distinction has already paid for itself twice in
## this repository. Once in stage_probe, where a launch modelled with a closed
## form came out 561px against a measured 665. And once here: the first version
## of this stage gave the runner floor-to-sky pillars to hide behind, and the
## check below is what noticed the runner sprinting INTO one.
##
##   godot --headless --path . --fixed-fps 60 res://test/keeper_probe.tscn

const Data = preload("res://src/levels/level_keeper_data.gd")

var main: Node2D = null
var failures: int = 0
var checks: int = 0

var _runner: Runner = null
var _guardian: Guardian = null
var _hub: InputHub = null
var _jump_up: float = 0.0
## Seconds a standing jump keeps the runner's feet above the Keeper's hitbox --
## the dodge window, measured.
var _clear_time: float = 0.0

func _ready() -> void:
	Stage.use(Stage.Which.KEEPER)
	GameState.boss_hp = -1
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
	# The Keeper walks at the runner from the moment the stage starts, and a
	# boss shoving the subject of a measurement around produces arcs that
	# describe nothing. Parked for the measuring, woken up for the playing.
	_park_the_keeper()
	await _physics(4)

	print("== what the runner can do in here ==")
	await _measure()

	print("")
	print("== the arena's own claims ==")
	_check_geometry()

	print("")
	print("== the rules ==")
	await _rules()

	print("")
	print("== playing it ==")
	await _play()

	print("")
	if failures == 0:
		print("1-B is playable (%d checks)" % checks)
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

func _boss() -> Keeper:
	for e in get_tree().get_nodes_in_group("keeper"):
		if e is Keeper:
			return e
	return null

func _park_the_keeper() -> void:
	var k := _boss()
	if k != null:
		k.set_physics_process(false)
		k.global_position = Vector2(4000.0, Data.FLOOR - Balance.KEEPER_HITBOX.y * 0.5)

func _wake_the_keeper(at_x: float) -> Keeper:
	var k := _boss()
	if k == null:
		return null
	k.global_position = Vector2(at_x, Data.FLOOR - Balance.KEEPER_HITBOX.y * 0.5)
	k.velocity = Vector2.ZERO
	k.set_physics_process(true)
	k._enter(Keeper.State.WALK)
	return k

# -------------------------------------------------------------- measurement

func _measure() -> void:
	main._respawn_timer = -1.0
	_jump_up = await _jump_height()
	_clear_time = await _time_above(Balance.KEEPER_HITBOX.y)
	print("  a standing jump reaches %.0fpx up" % _jump_up)
	print("  and keeps the feet above %.0fpx (the Keeper's hitbox) for %.3fs"
		% [Balance.KEEPER_HITBOX.y, _clear_time])
	print("  the Keeper needs %.3fs to pass through a runner at %.0fpx/s"
		% [(Balance.KEEPER_HITBOX.x + Balance.RUNNER_SIZE.x) / Balance.KEEPER_CHARGE_SPEED,
			Balance.KEEPER_CHARGE_SPEED])

func _reset_runner(at_x: float) -> void:
	_hub.release_jump()
	_hub.move_axis = 0.0
	_hub.dash_held = false
	_runner.global_position = Vector2(at_x, Data.FLOOR - 60.0)
	_runner.velocity = Vector2.ZERO

func _jump_height() -> float:
	_reset_runner(-600.0)
	await _physics(30)
	var start := _runner.global_position.y
	var apex := start
	_hub.press_jump()
	for i in range(140):
		await get_tree().physics_frame
		apex = minf(apex, _runner.global_position.y)
		if i > 6 and _runner.is_on_floor():
			break
	_hub.release_jump()
	return start - apex

## How long a held standing jump keeps the runner's FEET above `height`.
##
## The dodge, measured rather than integrated. The runner's feet are what the
## Keeper's hitbox has to pass under, and the gravity that brings them back down
## is 1.4x the one that sent them up -- a closed form that forgets that gives an
## answer about a third too generous, which for a dodge is the difference
## between comfortable and frame-perfect.
func _time_above(height: float) -> float:
	_reset_runner(-600.0)
	await _physics(30)
	var floor_y := _runner.global_position.y + Balance.RUNNER_SIZE.y * 0.5
	var ticks := 0
	_hub.press_jump()
	for i in range(140):
		await get_tree().physics_frame
		var feet := _runner.global_position.y + Balance.RUNNER_SIZE.y * 0.5
		if floor_y - feet >= height:
			ticks += 1
		if i > 6 and _runner.is_on_floor():
			break
	_hub.release_jump()
	await _physics(10)
	return float(ticks) * Clock.DT

# ----------------------------------------------------------------- geometry

func _check_geometry() -> void:
	_ok("the stage is numbered 1-B", Stage.stage_number() == "1-B")
	_ok("and it is the Keeper's", Stage.stage_name() == "THE KEEPER")
	_ok("there is exactly one enemy in it", Stage.enemies().size() == 1)
	_ok("and it is the Keeper",
		Stage.enemies().size() > 0
			and String(Stage.enemies()[0].get("type", "")) == "keeper")
	_ok("nothing in the arena kills outright", Stage.hazards().is_empty(),
		"a boss fight with a pit in it is two fights")

	# The premise: running away is not an answer, so the answer has to be air.
	var sprint := Balance.RUNNER_RUN_SPEED * Balance.RUNNER_SPRINT_MULTIPLIER
	_ok("the charge is faster than a sprint (%.0f against %.0f)"
			% [Balance.KEEPER_CHARGE_SPEED, sprint],
		Balance.KEEPER_CHARGE_SPEED > sprint)

	# THE dodge, both halves measured. A jump has to keep the runner clear for
	# meaningfully longer than the Keeper takes to go past, or the fight is a
	# frame-perfect input and this game is not that.
	var pass_time := (Balance.KEEPER_HITBOX.x + Balance.RUNNER_SIZE.x) \
		/ Balance.KEEPER_CHARGE_SPEED
	_ok("a jump clears the charge with room (%.3fs of air against %.3fs of Keeper)"
			% [_clear_time, pass_time],
		_clear_time > pass_time * 1.35,
		"the dodge is frame-perfect, which this game does not ask for anywhere else")

	# The other dodge: standing on the guardian's slab.
	_ok("the Keeper is lower than a jump, so there is somewhere to be (%.0f < %.0f)"
			% [Balance.KEEPER_HITBOX.y, _jump_up],
		Balance.KEEPER_HITBOX.y < _jump_up)

	# Barricades: cover that stops a charge and that the runner can cross.
	_ok("a barricade is taller than the Keeper's hitbox (%.0f > %.0f)"
			% [Balance.BARRICADE_SIZE.y, Balance.KEEPER_HITBOX.y],
		Balance.BARRICADE_SIZE.y > Balance.KEEPER_HITBOX.y,
		"a charge would ride over it")
	_ok("and lower than a jump, so it is cover rather than a wall (%.0f < %.0f)"
			% [Balance.BARRICADE_SIZE.y, _jump_up],
		Balance.BARRICADE_SIZE.y < _jump_up,
		"this is the check that caught the floor-to-sky pillars")
	_ok("barricades are not on the terrain layer",
		Balance.LAYER_BARRICADE != 1,
		"a walking Keeper would be shut out of half its own arena")

	var barricades := 0
	for g in Stage.gimmicks():
		if String(g.get("type", "")) == "barricade":
			barricades += 1
	_ok("the arena is built with 2 barricades", barricades == 2)
	_ok("act one has two, act two has one, act three has none",
		Keeper.barricades_for_act(1) == 2 and Keeper.barricades_for_act(2) == 1
			and Keeper.barricades_for_act(3) == 0)

	# Sealed. A guardian who can lift the runner over the gate can skip the boss.
	var lintel_found := false
	for r in Stage.solid_decor():
		if r.position.x > Data.ARENA_RIGHT - 100.0 and r.position.y < 0.0:
			lintel_found = true
	_ok("there is a lintel over the gate, so nothing can be built above it",
		lintel_found)

	_ok("six wounds, two per act", Balance.KEEPER_HP == 6)

	# The art is registered even though it has not been drawn, so the stage
	# cannot be shipped with the manifest half-written.
	var registered := 0
	var wanted := ["keeper_stand", "keeper_brace", "keeper_charge", "keeper_reel",
		"keeper_core", "keeper_barricade", "keeper_barricade_rubble",
		"keeper_shockwave", "keeper_panorama"]
	for key in wanted:
		if Art.MANIFEST.has(key):
			registered += 1
	_ok("every painting the stage asks for has a manifest key (%d/%d)"
			% [registered, wanted.size()],
		registered == wanted.size())

# -------------------------------------------------------------------- rules

func _rules() -> void:
	var k := _wake_the_keeper(700.0)
	if k == null:
		_ok("the Keeper exists", false)
		return
	main._respawn_timer = -1.0
	_reset_runner(200.0)
	await _physics(6)

	# --- the loop: in range, it winds up ------------------------------------
	k._enter(Keeper.State.WALK)
	k._timer = 0.0
	await _physics(4)
	_ok("with the runner in range the Keeper winds up", k.state == Keeper.State.BRACE,
		"state %d" % k.state)

	# --- a walking Keeper steps over a barricade ----------------------------
	# The rule the arena depends on: cover that shuts the boss out of half the
	# room is not cover, it is a partition.
	_ok("a walking Keeper does not collide with barricades",
		(k.collision_mask & Balance.LAYER_BARRICADE) == 0)
	k._enter(Keeper.State.CHARGE)
	_ok("a charging one does", (k.collision_mask & Balance.LAYER_BARRICADE) != 0)

	# --- rule 2: the core is open in one state and shuts when it is used ----
	k._enter(Keeper.State.WALK)
	_ok("the core is shut while it is walking", not k.exposed())
	k._enter(Keeper.State.BRACE)
	_ok("shut while it is winding up", not k.exposed())
	k._enter(Keeper.State.STAGGER)
	_ok("open while it is reeling", k.exposed())
	var before := k.hp
	k.wound()
	_ok("one wound goes through", k.hp == before - 1)
	_ok("and the core shuts on the shot that took it", not k.exposed(),
		"a full gauge would otherwise empty four shots into one opening")

	# The rifle's assist must not reach a shut core, which is the hole the
	# shield-bearer shipped with, pointed the other way.
	var core: Node = k.get_node_or_null("Core")
	_ok("a shut core is not a target the rifle will snap to",
		core != null and not core.call("is_shootable_now"))
	k._enter(Keeper.State.STAGGER)
	_ok("an open one is", core != null and core.call("is_shootable_now"))

	# And a shot into a shut one says so out loud rather than reading as a miss.
	k._enter(Keeper.State.WALK)
	var blocked := [false]
	var conn := func(_at: Vector2) -> void: blocked[0] = true
	Events.shot_blocked.connect(conn)
	core.call("take_damage", Balance.SNIPE_DAMAGE, "snipe")
	Events.shot_blocked.disconnect(conn)
	_ok("shooting a shut core is refused, not silently missed", blocked[0])

	# --- rule 3: an act change takes a barricade -----------------------------
	GameState.boss_hp = -1
	k.hp = Balance.KEEPER_HP
	_ok("a fresh Keeper is in act one", k.act() == 1)
	k._enter(Keeper.State.STAGGER)
	k.wound()
	k._enter(Keeper.State.STAGGER)
	k.wound()
	await _frames(2)
	_ok("two wounds later it is act two", k.act() == 2)
	_ok("and one of the two barricades has come down (%d standing)" % _standing(),
		_standing() == 1)
	_ok("the act is remembered outside the nodes, so a respawn keeps it",
		GameState.boss_hp == k.hp)
	_ok("the shockwave starts in act two", k.throws_shockwaves())

	# And the telegraph shortens, which is most of the difficulty curve.
	_ok("the wind-up is shorter in act two than in act one",
		float(Balance.KEEPER_TELEGRAPH[1]) < float(Balance.KEEPER_TELEGRAPH[0]))
	_ok("and shorter again in act three",
		float(Balance.KEEPER_TELEGRAPH[2]) < float(Balance.KEEPER_TELEGRAPH[1]))

func _standing() -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group("barricade"):
		if b is Barricade and (b as Barricade).standing():
			n += 1
	return n

# ------------------------------------------------------------------ playing

func _play() -> void:
	GameState.boss_hp = -1
	main.level.rebuild_dynamic()
	await _physics(4)
	var k := _wake_the_keeper(900.0)
	if k == null:
		_ok("the Keeper is rebuilt", false)
		return
	main._respawn_timer = -1.0
	_runner.hp = Balance.RUNNER_MAX_HP

	# --- the runner can get onto a barricade and off it again ---------------
	_reset_runner(Data.BARRICADE_A - 120.0)
	await _physics(20)
	_hub.move_axis = 1.0
	_hub.press_jump()
	var on_top := false
	for _i in range(90):
		await get_tree().physics_frame
		var feet := _runner.global_position.y + Balance.RUNNER_SIZE.y * 0.5
		if _runner.is_on_floor() and feet < Data.FLOOR - 40.0:
			on_top = true
			break
	_hub.release_jump()
	_hub.move_axis = 0.0
	_ok("1: the runner can get onto a barricade", on_top,
		"a barricade the runner cannot cross is a wall, not cover")
	# ...and back down without being stuck on it.
	_hub.move_axis = 1.0
	await _physics(45)
	_hub.move_axis = 0.0
	await _physics(20)
	_ok("1: and off the other side", _runner.is_on_floor()
		and _runner.global_position.x > Data.BARRICADE_A)

	# --- the bait, played: stand in front of a barricade and take the charge --
	#
	# The runner is between the Keeper and the barricade, which is the whole
	# skill of this fight. Then they jump, and the charge goes under them and
	# into the stone.
	# Both of these are inside the lane BETWEEN the two barricades, and that is
	# not decoration. The first attempt at this put the Keeper at
	# BARRICADE_A + 700, which is 5px from barricade B -- so the charge ended
	# before it ever reached the runner and the stagger check passed for
	# completely the wrong reason, with the dodge never tested at all.
	_reset_runner(Data.BARRICADE_A + 250.0)
	k = _wake_the_keeper(Data.BARRICADE_A + 500.0)
	_runner.hp = Balance.RUNNER_MAX_HP
	await _physics(10)
	k._enter(Keeper.State.WALK)
	k._timer = 0.0
	await _physics(4)
	_ok("1: the Keeper commits", k.state == Keeper.State.BRACE)
	_ok("1: and there is something behind the runner for it to end on",
		k.cover_ahead(),
		"the runner picked ground with no barricade behind it")

	# Wait for the charge, then jump when it is close enough that the arc and
	# the body overlap -- which is what a player does by eye.
	var jumped := false
	var hp_at_start := _runner.hp
	for _i in range(240):
		await get_tree().physics_frame
		if not is_instance_valid(k):
			break
		if not jumped and k.state == Keeper.State.CHARGE:
			var gap := absf(k.global_position.x - _runner.global_position.x)
			# Jump when contact is about 0.3s away, which is what a player does
			# by eye: the feet need ~0.13s to get above 110px and the body then
			# takes 0.197s to pass through, so the press has to lead the hit.
			if gap / Balance.KEEPER_CHARGE_SPEED <= 0.30:
				_hub.press_jump()
				jumped = true
		if k.state == Keeper.State.STAGGER:
			break
	_hub.release_jump()
	_ok("1: the runner jumps the charge", jumped)
	_ok("1: and is not hit by it (hp %d)" % _runner.hp, _runner.hp == hp_at_start,
		"the dodge window is not what it was measured to be")
	_ok("1: the charge ends on the barricade and the Keeper reels",
		is_instance_valid(k) and k.state == Keeper.State.STAGGER,
		"state %d at x=%.0f" % [k.state if is_instance_valid(k) else -1,
			k.global_position.x if is_instance_valid(k) else 0.0])
	_ok("1: which is what opens the core", is_instance_valid(k) and k.exposed())

	# --- and the guardian takes the shot, through the rifle -----------------
	var hp_before := k.hp
	var core: Node2D = k.get_node_or_null("Core")
	if core != null:
		await _shoot(core.global_position)
	_ok("1: the guardian's shot takes a wound (%d -> %d)" % [hp_before, k.hp],
		k.hp == hp_before - 1)
	_ok("1: and the opening is spent", not k.exposed())

	# --- the headline: the guardian's WALL does the barricade's job ---------
	#
	# balance.gd has promised "Wall: blocks shots and charges" since the first
	# commit and nothing in this game has ever charged. This is that line,
	# finally doing something.
	await _clear_constructs()
	GameState.boss_hp = 2                # act three: no barricades, only the wall
	main.level.rebuild_dynamic()
	await _physics(4)
	k = _wake_the_keeper(760.0)
	_runner.hp = Balance.RUNNER_MAX_HP
	_ok("3: act three has no barricades left (%d standing)" % _standing(),
		_standing() == 0)
	_ok("3: and the Keeper is back at the wounds it had", k.hp == 2)

	_reset_runner(200.0)
	await _physics(6)
	_ok("3: with nothing in the lane, a charge would end on nothing",
		not k.cover_ahead())
	k._enter(Keeper.State.WALK)
	k._timer = 0.0
	await _physics(4)
	_ok("3: it winds up anyway", k.state == Keeper.State.BRACE)

	# The wall goes down during the wind-up, behind the runner. Both players are
	# acting inside the same second, which is the moment the whole game is
	# built around.
	var refusal := await _build(2, Vector2(60.0, Data.FLOOR - Balance.WALL_SIZE.y * 0.5))
	_ok("3: the guardian can put a wall behind the runner", refusal.is_empty(), refusal)
	_ok("3: and now there is something for the charge to end on", k.cover_ahead())

	var walled := await _wait_for(k, Keeper.State.STAGGER, 240)
	_ok("3: the charge stops on the guardian's wall", walled,
		"state %d at x=%.0f -- 'Wall: blocks shots and charges' is not true"
			% [k.state, k.global_position.x])
	_ok("3: and the wall opens the core exactly as a barricade does", k.exposed())
	_ok("3: the wall is still standing afterwards",
		_guardian.holograms_of(Hologram.Kind.WALL).size() == 1,
		"25 gauge and four seconds is already the price; breaking it charges twice")

	# --- the last two wounds, and the gate ---------------------------------
	var opened := [false]
	var watch := func(id: String) -> void:
		if id == Data.GATE_ID:
			opened[0] = true
	Events.switch_activated.connect(watch)
	core = k.get_node_or_null("Core")
	if core != null:
		await _shoot(core.global_position)
	_ok("3: the shot lands (hp %d)" % k.hp, k.hp == 1)
	k._enter(Keeper.State.STAGGER)
	if core != null and is_instance_valid(core):
		await _shoot(core.global_position)
	_ok("3: the sixth wound finishes it", k.hp == 0)
	_ok("3: and it takes a moment to fall rather than vanishing",
		k.state == Keeper.State.DYING)
	for _i in range(180):
		await get_tree().physics_frame
		if not is_instance_valid(k):
			break
	_ok("3: the Keeper is gone", not is_instance_valid(k))
	Events.switch_activated.disconnect(watch)
	_ok("3: and the gate it was guarding opens", opened[0])

	await _shockwave_checks()

	# --- and a rebuild after it is dead does not resurrect it ---------------
	#
	# A shockwave still travelling when the Keeper falls can take the runner's
	# last heart, and a respawn rebuilds the whole dynamic layer -- so without a
	# sentinel this is where a beaten boss comes back on full health in front of
	# a gate that has shut again.
	var reopened := [false]
	var watch_again := func(id: String) -> void:
		if id == Data.GATE_ID:
			reopened[0] = true
	Events.switch_activated.connect(watch_again)
	main.level.rebuild_dynamic()
	await _physics(4)
	Events.switch_activated.disconnect(watch_again)
	_ok("3: rebuilding after the kill does not bring the Keeper back",
		_boss() == null, "a beaten boss came back at full health")
	_ok("3: and the gate is rebuilt open", reopened[0])

	# --- respawning does not undo the act ----------------------------------
	GameState.boss_hp = 4
	main.level.rebuild_dynamic()
	await _physics(4)
	var again := _boss()
	_ok("a respawn mid-fight brings the Keeper back where it was (hp %s)"
			% (str(again.hp) if again != null else "gone"),
		again != null and again.hp == 4,
		"a boss that heals throws away every cycle before the mistake")
	_ok("and the barricades come back matching the act, not full (%d standing)"
			% _standing(),
		_standing() == 1)

## The wave is the reason a platform has a job in a fight with no gaps in it.
func _shockwave_checks() -> void:
	var wave := Shockwave.new()
	wave.direction = -1
	wave.global_position = Vector2(600.0, Data.FLOOR - Balance.SHOCKWAVE_SIZE.y * 0.5)
	main.level.add_child(wave)
	await _physics(2)
	_ok("the wave is low enough to jump (%.0f against a %.0f jump)"
			% [Balance.SHOCKWAVE_SIZE.y, _jump_up],
		Balance.SHOCKWAVE_SIZE.y < _jump_up * 0.5,
		"it has to be noticed, not frame-timed")
	var top := wave.global_position.y - Balance.SHOCKWAVE_SIZE.y * 0.5
	var deck := Data.FLOOR - 60.0
	_ok("a platform 60px up is above it (%.0f against %.0f)" % [deck, top],
		deck < top, "then standing on the guardian's slab is not shelter")
	var travelled := wave.global_position.x
	await _physics(20)
	_ok("and it travels", wave.global_position.x < travelled - 50.0)
	wave.queue_free()
	await _physics(2)

# ------------------------------------------------------------------ helpers

func _wait_for(k: Keeper, want: int, ticks: int) -> bool:
	for _i in range(ticks):
		await get_tree().physics_frame
		if not is_instance_valid(k):
			return false
		if k.state == want:
			return true
	return false

## The guardian puts something down the way a player does: choose, then tap.
func _build(slot: int, at: Vector2) -> String:
	_guardian.gauge = Balance.GAUGE_MAX
	_guardian._last_refusal = ""
	_guardian.select_slot(slot)
	_guardian.use_active(at)
	await _physics(2)
	return _guardian._last_refusal

## And shoots the same way: the rifle, at a point, with the assist doing what it
## does for a real thumb.
func _shoot(at: Vector2) -> void:
	_guardian.gauge = Balance.GAUGE_MAX
	(_guardian.abilities[3] as SniperAbility).cooldown = 0.0
	_guardian.select_slot(3)
	_guardian.use_active(at)
	await _physics(4)

func _clear_constructs() -> void:
	_guardian.clear_constructs()
	await _physics(2)
