extends Node
## Does the coin battle obey its own ledger?
##
## docs/coin-battle-plan.md 13.2 items 1-5. P0's gate is this file passing:
## "保存則、同tick処理、短押し、接触再実行が自動試験で成立".
##
## The centre of it is item 1. Seven coin IDs exist for a whole match; being
## dropped, blasted out of the arena, going stale and being recycled all move a
## coin between states and none of them may create or destroy one. That is
## checked EVERY TICK of a randomised match rather than at the end, because a
## ledger that is wrong for two hundred ticks and right again by the whistle is
## still a ledger that showed somebody the wrong score.
##
## Everything here drives ArenaMatchState directly. There is no scene, no
## rendering and no input device -- which is the point of P0 being a pure
## model, and why ten thousand ticks cost a second.

var failures: Array[String] = []
var _current: String = ""

func check(ok: bool, label: String) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		failures.append("%s: %s" % [_current, label])
		print("  FAIL  %s" % label)

func _ready() -> void:
	_test_conservation_under_noise()
	_test_damage_and_drops()
	_test_simultaneous()
	_test_endgame()
	_test_respawn()

	print("arena rules probe: %d checks failed" % failures.size())
	if failures.is_empty():
		print("the coin ledger holds (P0)")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("arena rules probe: " + f)
		get_tree().quit(1)

func _fresh(match_seed: int = 4242) -> ArenaMatchState:
	var m := ArenaMatchState.new()
	m.setup(ArenaStage.from_data(), match_seed)
	m.begin_playing()
	return m

func _idle_inputs() -> Array:
	var out: Array = []
	for i in range(4):
		out.append({"axis": 0.0, "jump_held": false, "jump_seq": 0, "attack_seq": 0})
	return out

# ---------------------------------------------------------------- 13.2 item 1
## A whole match of nonsense input, with the invariant asserted every tick.
func _test_conservation_under_noise() -> void:
	_current = "conservation"
	var m := _fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var jump_seq := [0, 0, 0, 0]
	var attack_seq := [0, 0, 0, 0]

	var broke_at := -1
	var ids_seen := {}
	for t in range(ArenaRules.MATCH_TICKS):
		var inputs: Array = []
		for i in range(4):
			if rng.randf() < 0.05:
				jump_seq[i] += 1
			if rng.randf() < 0.05:
				attack_seq[i] += 1
			inputs.append({
				"axis": rng.randf_range(-1.0, 1.0),
				"jump_held": rng.randf() < 0.5,
				"jump_seq": jump_seq[i],
				"attack_seq": attack_seq[i],
			})
		m.tick_match(inputs)
		if not m.ledger.conserved() and broke_at < 0:
			broke_at = t
		for c in m.ledger.coins:
			ids_seen[c.coin_id] = true
		if m.phase == ArenaMatchState.Phase.RESULTS:
			break

	check(broke_at < 0,
		"7 coins are conserved on every tick of a full random match"
			+ ("" if broke_at < 0 else " (broke at tick %d)" % broke_at))
	check(ids_seen.size() == ArenaRules.COIN_COUNT,
		"exactly %d coin ids ever existed (saw %d)"
			% [ArenaRules.COIN_COUNT, ids_seen.size()])
	check(m.ledger.coins.size() == ArenaRules.COIN_COUNT,
		"and the ledger is still %d records long" % ArenaRules.COIN_COUNT)

	# Recycling is the transition most likely to mint a coin, so it is counted
	# rather than assumed to have happened.
	var recycles := 0
	for e in m.events:
		if String(e.get("kind", "")) == "recycle":
			recycles += 1
	check(recycles > 0, "the match actually exercised recycling (%d times)" % recycles)

# ---------------------------------------------------------------- 13.2 item 2
func _test_damage_and_drops() -> void:
	_current = "damage"
	# 0 coins: the hit still lands, nothing is dropped.
	var m := _fresh()
	_park(m, 0, Vector2(-40.0, 100.0))
	_park(m, 2, Vector2(0.0, 100.0))
	_swing(m, 0)
	_run(m, 20)
	check(m.fighters[2].combat.pressure > 0.0, "a hit lands on an empty-handed victim")
	# Asserted against the victim rather than against a world-coin count: the
	# schedule puts its first coin out on tick 0, so a global count moves for
	# reasons that have nothing to do with this hit.
	var dropped_by_victim := false
	for e in m.events:
		if String(e.get("kind", "")) == "drop" and int(e.get("actor", -1)) == 2:
			dropped_by_victim = true
	check(not dropped_by_victim, "and drops nothing they did not have")

	# 1 coin: exactly one leaves, and it goes to the world rather than the
	# attacker (3.3).
	m = _fresh()
	_park(m, 0, Vector2(-40.0, 100.0))
	_park(m, 2, Vector2(0.0, 100.0))
	_give(m, 2, [0])
	_swing(m, 0)
	_run(m, 20)
	check(m.ledger.count_held_by(2) == 0, "a hit costs the victim one coin")
	check(m.ledger.count_held_by(0) == 0, "and the attacker is not handed it")
	check(m.ledger.get_coin(0).state == ArenaCoin.State.WORLD,
		"the coin is in the world, for either side to take")

	# Many coins, one hit: still exactly one.
	m = _fresh()
	_park(m, 0, Vector2(-40.0, 100.0))
	_park(m, 2, Vector2(0.0, 100.0))
	_give(m, 2, [0, 1, 2, 3])
	_swing(m, 0)
	_run(m, 20)
	check(m.ledger.count_held_by(2) == 3, "four coins minus one hit is three")

	# Friendly fire does nothing (3.3).
	m = _fresh()
	_park(m, 0, Vector2(-40.0, 100.0))
	_park(m, 1, Vector2(0.0, 100.0))
	_give(m, 1, [0])
	_swing(m, 0)
	_run(m, 20)
	check(m.fighters[1].combat.pressure == 0.0, "a team-mate's attack does nothing")
	check(m.ledger.get_coin(0).state == ArenaCoin.State.HELD
			and m.ledger.get_coin(0).owner == 1,
		"and costs them the coin they were holding")

	# Invulnerability refuses the hit, so it cannot drop anything (3.3).
	m = _fresh()
	_park(m, 0, Vector2(-40.0, 100.0))
	_park(m, 2, Vector2(0.0, 100.0))
	_give(m, 2, [0])
	m.fighters[2].combat.hit_invuln = 30
	_swing(m, 0)
	_run(m, 20)
	check(_held_of(m, 2, [0]) == 1,
		"an attack refused by invulnerability drops nothing")

	# A blast-out returns the WHOLE hand, and destroys none of it (3.4).
	m = _fresh()
	_park(m, 2, Vector2(0.0, 100.0))
	_run(m, 2)
	_give(m, 2, [0, 1, 2, 3])
	m.fighters[2].motor.position = Vector2(0.0, ArenaStageData.BLAST_BOTTOM + 40.0)
	_run(m, 2)
	check(not m.fighters[2].alive, "crossing the bottom is a blast-out")
	check(m.ledger.count_held_by(2) == 0, "which empties the hand")
	var loose := m.ledger.count_in(ArenaCoin.State.WORLD) \
		+ m.ledger.count_in(ArenaCoin.State.RECYCLE_PENDING)
	check(loose >= 4, "and returns all four coins rather than destroying them (%d loose)" % loose)
	check(m.ledger.conserved(), "the ledger survives a blast-out with a full hand")

	# The same, with nowhere safe to put them. A fighter blasted out before
	# ever standing anywhere in bounds has no last safe drop, so the hand goes
	# to RECYCLE_PENDING instead of to the floor (3.4).
	#
	# Checked explicitly because the randomised match never reaches this branch:
	# every fighter starts on the main floor, so last_safe_drop is always valid.
	# A negative control that broke the owner-clearing in to_recycle passed the
	# whole probe, which is how the gap was found -- an unreached branch is a
	# branch nothing is asserting about.
	m = _fresh()
	_park(m, 2, Vector2(0.0, 100.0))
	_run(m, 2)
	_give(m, 2, [0, 1, 2])
	m.fighters[2].last_safe_drop = Vector2(0.0, ArenaStageData.BLAST_BOTTOM + 500.0)
	m.fighters[2].motor.position = Vector2(0.0, ArenaStageData.BLAST_BOTTOM + 40.0)
	_run(m, 1)
	check(not m.fighters[2].alive, "a fighter with nowhere safe to drop is still out")
	check(m.ledger.count_held_by(2) == 0, "and still loses the hand")
	for id in [0, 1, 2]:
		var r := m.ledger.get_coin(id)
		check(r.state != ArenaCoin.State.HELD and r.owner == -1,
			"coin %d is recycled and owned by nobody" % id)
	check(m.ledger.conserved(), "and the ledger balances with no safe drop point")

# ---------------------------------------------------------------- 13.2 item 3
func _test_simultaneous() -> void:
	_current = "simultaneous"
	# Two enemies swing at one victim on the same tick: one hit, one coin.
	var m := _fresh()
	_park(m, 2, Vector2(0.0, 100.0))
	_park(m, 0, Vector2(-40.0, 100.0))
	_park(m, 1, Vector2(40.0, 100.0))
	_give(m, 2, [0, 1])
	_swing(m, 0)
	_swing(m, 1)
	_run(m, 20)
	check(_held_of(m, 2, [0, 1]) == 1,
		"two attackers in one tick still cost the victim exactly one coin")

	# Two fighters equidistant from a coin: exactly one gets it.
	m = _fresh()
	_park(m, 0, Vector2(-30.0, 100.0))
	_park(m, 2, Vector2(30.0, 100.0))
	_run(m, 2)
	ArenaCoin.to_world(m.ledger.get_coin(0), Vector2(0.0, 100.0), m.tick, Vector2.ZERO, 0)
	_run(m, 2)
	var holders := 0
	for i in range(4):
		holders += m.ledger.count_held_by(i)
	check(holders <= 1, "a contested coin goes to at most one fighter (%d)" % holders)
	check(m.ledger.conserved(), "and the ledger still balances")

	# A coin may not be taken before its lockout expires (3.2).
	m = _fresh()
	_park(m, 0, Vector2(0.0, 100.0))
	_run(m, 2)
	ArenaCoin.to_world(m.ledger.get_coin(0), Vector2(0.0, 100.0), m.tick)
	_run(m, ArenaRules.PICKUP_LOCKOUT_TICKS - 2)
	check(m.ledger.count_held_by(0) == 0,
		"a just-spawned coin cannot be taken during its %d-tick lockout"
			% ArenaRules.PICKUP_LOCKOUT_TICKS)
	# Run on until it is taken rather than for a fixed count. The fixed version
	# passed only because the fighter happened to be standing still on the
	# right tick, and a one-frame change elsewhere in the motor moved it.
	var taken := false
	for i in range(30):
		_run(m, 1)
		if m.ledger.count_held_by(0) == 1:
			taken = true
			break
	check(taken, "and can be taken once it expires")

	# The fighter who just lost a coin cannot immediately vacuum it back (3.3).
	m = _fresh()
	_park(m, 0, Vector2(-40.0, 100.0))
	_park(m, 2, Vector2(0.0, 100.0))
	_give(m, 2, [0])
	_swing(m, 0)
	_run(m, ArenaRules.DROP_LOCKOUT_TICKS + 4)
	check(m.ledger.count_held_by(2) == 0,
		"the victim cannot re-take their own dropped coin straight away")

	# An unspawned coin cannot be picked up.
	m = _fresh()
	_park(m, 0, Vector2(0.0, 100.0))
	m.ledger.get_coin(6).position = Vector2(0.0, 100.0)
	_run(m, 10)
	check(m.ledger.get_coin(6).state == ArenaCoin.State.UNSPAWNED
			or m.ledger.get_coin(6).state == ArenaCoin.State.WORLD,
		"a coin that has not entered play cannot be held")

# ---------------------------------------------------------------- 13.2 item 4
func _test_endgame() -> void:
	_current = "endgame"
	# A decided match ends at the final tick and issues one result.
	var m := _fresh()
	_give(m, 0, [0, 1, 2])
	_give(m, 2, [3])
	m.match_tick = ArenaRules.MATCH_TICKS - 1
	_run(m, 2)
	check(m.phase == ArenaMatchState.Phase.RESULTS, "the match ends on its last tick")
	check(m.winner == ArenaMatchState.TEAM_A, "the team holding more coins wins")
	var first_id := m.result_id
	m.tick_match(_idle_inputs())
	check(m.result_id == first_id, "and the result is issued exactly once")

	# Level on coins goes to overtime, not to a draw (3.1).
	m = _fresh()
	_give(m, 0, [0, 1, 2])
	_give(m, 2, [3, 4, 5])
	m.match_tick = ArenaRules.MATCH_TICKS - 1
	_run(m, 2)
	check(m.phase == ArenaMatchState.Phase.OVERTIME,
		"3-3 with one coin loose goes to overtime")

	# 0-0 is also a tie, and also goes to overtime.
	m = _fresh()
	m.match_tick = ArenaRules.MATCH_TICKS - 1
	_run(m, 2)
	check(m.phase == ArenaMatchState.Phase.OVERTIME, "0-0 goes to overtime too")

	# Overtime is won by holding a lead, and losing the lead resets the clock.
	m = _fresh()
	m.phase = ArenaMatchState.Phase.OVERTIME
	m.match_tick = 0
	_give(m, 0, [0])
	_run(m, ArenaRules.OVERTIME_LEAD_TICKS - 20)
	check(m.phase == ArenaMatchState.Phase.OVERTIME, "a short lead does not win yet")
	_give(m, 2, [1])
	_run(m, 4)
	_take(m, 2, [1])
	_run(m, ArenaRules.OVERTIME_LEAD_TICKS - 20)
	check(m.phase == ArenaMatchState.Phase.OVERTIME,
		"levelling resets the lead clock rather than pausing it")
	_run(m, 40)
	check(m.phase == ArenaMatchState.Phase.RESULTS,
		"and an unbroken %d-tick lead wins overtime" % ArenaRules.OVERTIME_LEAD_TICKS)

	# Overtime that runs out level is a draw.
	m = _fresh()
	m.phase = ArenaMatchState.Phase.OVERTIME
	m.match_tick = ArenaRules.OVERTIME_TICKS - 1
	_run(m, 3)
	check(m.phase == ArenaMatchState.Phase.RESULTS, "overtime expires")
	check(m.draw, "level at the whistle is a draw")

# ---------------------------------------------------------------- 13.2 item 5
func _test_respawn() -> void:
	_current = "respawn"
	var m := _fresh()
	_park(m, 2, Vector2(0.0, 100.0))
	_run(m, 2)
	m.fighters[2].motor.position = Vector2(0.0, ArenaStageData.BLAST_BOTTOM + 40.0)
	var epoch := m.fighters[2].spawn_epoch
	_run(m, 2)
	check(not m.fighters[2].alive, "a blasted-out fighter is out")
	_run(m, ArenaRules.RESPAWN_TICKS + 4)
	check(m.fighters[2].alive, "and comes back after %d ticks" % ArenaRules.RESPAWN_TICKS)
	check(m.fighters[2].spawn_epoch > epoch, "on a new spawn epoch")
	check(m.fighters[2].combat.respawn_invuln > 0, "briefly untouchable")
	check(m.fighters[2].combat.pressure == 0.0, "with pressure cleared")
	check(ArenaStageData.in_bounds(m.fighters[2].centre()), "and inside the arena")

	# Respawn invulnerability forbids acting, so it cannot be used to farm
	# coins or swing with impunity (5).
	m = _fresh()
	_park(m, 0, Vector2(0.0, 100.0))
	m.fighters[0].combat.respawn_invuln = 30
	_run(m, 2)
	ArenaCoin.to_world(m.ledger.get_coin(0), Vector2(0.0, 100.0), m.tick, Vector2.ZERO, 0)
	_run(m, 4)
	check(m.ledger.count_held_by(0) == 0,
		"an untouchable fighter cannot pick coins up")
	_swing(m, 0)
	_run(m, 6)
	check(m.fighters[0].combat.phase == ArenaCombat.Phase.IDLE,
		"and cannot attack either")

	# Two fighters blasted out at once both come back.
	m = _fresh()
	_run(m, 2)
	m.fighters[0].motor.position = Vector2(0.0, ArenaStageData.BLAST_BOTTOM + 40.0)
	m.fighters[2].motor.position = Vector2(0.0, ArenaStageData.BLAST_BOTTOM + 40.0)
	_run(m, ArenaRules.RESPAWN_TICKS + 8)
	check(m.fighters[0].alive and m.fighters[2].alive,
		"two simultaneous blast-outs both return")
	check(m.fighters[0].centre() != m.fighters[2].centre(),
		"and not on top of each other")

# ------------------------------------------------------------------- helpers
func _run(m: ArenaMatchState, ticks: int) -> void:
	for i in range(ticks):
		m.tick_match(_idle_inputs())

## Stand a fighter on the main floor at an x. The y is derived rather than
## written, because the plan's table is surface tops and a body centre is half
## a body above one.
func _park(m: ArenaMatchState, actor: int, at: Vector2) -> void:
	var p := Vector2(at.x, ArenaStageData.standing_on(ArenaStageData.MAIN_FLOOR_TOP))
	m.fighters[actor].motor.position = p
	m.fighters[actor].motor.velocity = Vector2.ZERO
	m.fighters[actor].motor.grounded = true
	m.fighters[actor].last_safe_drop = p

## How many of THESE coins that fighter still holds.
##
## Deliberately not `count_held_by()`: the spawn schedule legitimately puts a
## coin into the world on tick 0, and a fighter parked next to the middle spawn
## point picks it up. A global count then reads 2 where the rule under test
## only ever spoke about the coins the test handed out.
func _held_of(m: ArenaMatchState, actor: int, coin_ids: Array) -> int:
	var n := 0
	for id in coin_ids:
		var c := m.ledger.get_coin(id)
		if c.state == ArenaCoin.State.HELD and c.owner == actor:
			n += 1
	return n

func _give(m: ArenaMatchState, actor: int, coin_ids: Array) -> void:
	for id in coin_ids:
		ArenaCoin.to_held(m.ledger.get_coin(id), actor)

func _take(m: ArenaMatchState, actor: int, coin_ids: Array) -> void:
	for id in coin_ids:
		ArenaCoin.to_recycle(m.ledger.get_coin(id), m.tick)

## Press attack once. The sequence is what the rules read, so this bumps it
## rather than holding a button.
func _swing(m: ArenaMatchState, actor: int) -> void:
	var c := m.fighters[actor].combat
	ArenaCombat.try_attack(c, c.attack_seq + 1, 0.0,
		_toward_enemy(m, actor), m.tick + 1000 + actor)

func _toward_enemy(m: ArenaMatchState, actor: int) -> int:
	var me := m.fighters[actor]
	for f in m.fighters:
		if f.team_id != me.team_id and f.alive:
			return 1 if f.centre().x > me.centre().x else -1
	return me.motor.facing
