class_name VersusMatch
## The rules of the 1-1 coin match: who holds what, who hit whom, who has won.
##
## Deliberately NOT a Node and deliberately holding no Runner. It is handed two
## "seats" -- a small description of where each runner is, which way it faces,
## whether it can act -- and it answers with a list of things to DO to them
## (hurt this one, it dropped that coin). The scene applies those.
##
## That split is what lets a probe run a whole match with no physics server, no
## art and no window, and it is what the four-device version will need: the host
## runs exactly this function and the result is what goes on the wire. A rules
## engine that reaches into a CharacterBody2D cannot be run twice on the same
## tick, and being run twice is the whole job of a host.
##
## The ledger is reused from the arena work unchanged (ArenaCoin). Its one idea
## is the one that matters here too: coins are neither created nor destroyed,
## and the score is DERIVED from who holds what rather than counted in a
## separate variable that can drift from the coins on screen.

## What the scene tells the rules about one runner, each tick.
##
## Named Seat rather than Side because `Side` is a built-in Godot enum
## (SIDE_LEFT, SIDE_TOP, ...). An inner class of that name parses, and then
## `Array[Side]` silently binds to the ENUM: every element becomes an int, and
## every field access on one fails with "cannot get property from enum value".
class Seat:
	var team: int = 0
	var position := Vector2.ZERO
	var facing: int = 1
	## False while dead or in the hurt state. A runner who cannot act cannot
	## strike and cannot pick a coin up.
	var can_act: bool = true
	## Separate from can_act, and it has to be: the game's invulnerability window
	## is what a runner gets for a full second after ANY hit, and it refuses the
	## next one. If it also stopped them acting, one hit would take a runner out
	## of the match for a second -- and worse, the rules would keep taking a coin
	## off a victim whose take_damage had already been refused. So this gates
	## being HIT and nothing else.
	var invulnerable: bool = false
	var alive: bool = true
	## Monotonic count of strike presses, so a tap that is over before the tick
	## runs is still a strike.
	var strike_seq: int = 0

	func duplicate_seat() -> Seat:
		var s := Seat.new()
		s.team = team
		s.position = position
		s.facing = facing
		s.can_act = can_act
		s.invulnerable = invulnerable
		s.alive = alive
		s.strike_seq = strike_seq
		return s

enum Phase { PLAYING, OVER }

var phase: int = Phase.PLAYING
var tick: int = 0
var winner: int = -1

var ledger: ArenaCoin.Ledger = null
var world: ArenaStage = null
## One ArenaCombat.CombatState per side: the 8/4/14 strike and its timers.
var combat: Array[ArenaCombat.CombatState] = []
var seats: Array[Seat] = []

## Ticks until the next coin is allowed to appear.
var _spawn_in: int = 0
var _next_strike_id: int = 1
var _rng := RandomNumberGenerator.new()

## Things the scene has to apply this tick. Cleared and refilled every tick.
## Each is {"kind": ..., ...}: "hurt" (side), "died" (side), "pickup", "drop".
var events: Array[Dictionary] = []

func setup(collision: ArenaStage, match_seed: int = 20260920) -> void:
	world = collision
	_rng.seed = match_seed
	ledger = ArenaCoin.Ledger.new(VersusRules.COIN_TOTAL)
	combat.clear()
	seats.clear()
	for i in range(2):
		combat.append(ArenaCombat.CombatState.new())
		# No respawn invulnerability at the whistle: it also forbids acting, and
		# starting a match unable to move is not what it is for.
		combat[i].respawn_invuln = 0
		var s := Seat.new()
		s.team = i
		seats.append(s)
	phase = Phase.PLAYING
	tick = 0
	winner = -1
	_spawn_in = 0
	events.clear()

## The score, derived. There is no counter to increment (3.4).
func score(team: int) -> int:
	return ledger.team_score(team, func(actor): return actor)

## One fixed tick.
##
## The order is the arena plan's 3.5, kept because the reasons for it survive
## the change of stage: every strike shape is gathered from the same instant
## BEFORE any of them is resolved, so two runners who swing at each other trade
## instead of the lower index winning; and coins move after the deaths, so a
## coin returned by a death cannot be caught by the tick that caused it.
func step(incoming: Array) -> void:
	events.clear()
	if phase != Phase.PLAYING:
		return
	var delta := 1.0 / 60.0

	# 1. adopt what the scene observed, and run the timers
	for i in range(2):
		seats[i].position = incoming[i].position
		seats[i].facing = incoming[i].facing
		seats[i].can_act = incoming[i].can_act
		seats[i].invulnerable = incoming[i].invulnerable
		seats[i].alive = incoming[i].alive
		ArenaCombat.advance(combat[i])
		# Mirror the scene's "cannot act" into the combat state rather than
		# branching on it below. ArenaCombat already knows what to do with a
		# press that arrives while stunned -- it spends it and throws it away --
		# and going through that path is what stops a button mashed during
		# hitstun from firing the instant the runner recovers.
		combat[i].hitstun = 0 if seats[i].can_act else 2

	# 2. strikes begin
	for i in range(2):
		if not seats[i].alive:
			continue
		if ArenaCombat.try_attack(combat[i], incoming[i].strike_seq, 0.0,
				seats[i].facing, _next_strike_id):
			_next_strike_id += 1
			events.append({"kind": "strike", "side": i})
		seats[i].strike_seq = incoming[i].strike_seq

	# 3. every live shape, from the same instant
	var hits := _gather_hits()

	# 4. one hit per victim
	_resolve_hits(hits)

	# 5. anyone who left the stage
	_resolve_falls()

	# 6. coins move, appear, and are taken
	_step_coins(delta)
	_top_up()
	_resolve_pickups()

	# 7. has anybody won
	tick += 1
	_check_win()

# --------------------------------------------------------------------- hits
func _gather_hits() -> Array:
	var out: Array = []
	for a in range(2):
		if not seats[a].alive:
			continue
		var box := _strike_box(a)
		if box.size == Vector2.ZERO:
			continue
		var v := 1 - a
		if not seats[v].alive:
			continue
		# The stage is a loop, so the victim may be a few pixels away across the
		# join and eighteen thousand away in a straight line. Everything below
		# measures against the nearest lap.
		var victim_at := VersusStageData.nearest_image(
			seats[v].position, seats[a].position)
		# The victim's own invulnerability, as the game reports it. Asking the
		# combat state instead would be asking a second opinion: Runner is the
		# one that will refuse the damage, so it has to be the one that decides
		# whether the coin comes off.
		if seats[v].invulnerable or combat[v].invulnerable():
			continue
		if combat[a].hit_this_attack.has(v):
			continue
		if not box.intersects(_body_at(victim_at), false):
			continue
		# Not through a floor. A strike from one ledge at a runner standing on
		# the next has to actually reach.
		if not world.line_clear(seats[a].position, victim_at):
			continue
		out.append({"attacker": a, "victim": v, "dir": combat[a].attack_dir})
	return out

func _resolve_hits(hits: Array) -> void:
	for h in hits:
		var v: int = h["victim"]
		var a: int = h["attacker"]
		combat[a].hit_this_attack.append(v)
		# The victim's swing is interrupted, so its remaining active frames do
		# not land on a later tick. A trade is deliberately still a trade: both
		# shapes were gathered above, from the same instant, before either was
		# resolved, so two runners who swing at each other on the same tick both
		# connect. That is the whole reason for the gather/resolve split.
		combat[v].phase = ArenaCombat.Phase.IDLE
		combat[v].phase_ticks = 0
		combat[v].hit_this_attack.clear()
		# The victim's own invulnerability is the game's, not ours: the scene
		# calls Runner.take_damage, which sets it. We only note the strike so
		# the same swing cannot land twice.
		events.append({"kind": "hurt", "side": v, "by": a, "dir": h["dir"]})
		_drop_one(v, float(h["dir"]))

## A hit costs exactly one coin, the lowest id held, and it goes to the world
## rather than to the attacker: either side can go and get it, which is what
## makes chasing it a decision.
func _drop_one(side: int, dir: float) -> void:
	var held := ledger.held_by(side)
	if held.is_empty():
		return
	var r := ledger.get_coin(held[0])
	# Wrapped, so a coin knocked loose at the far end of the join is not left
	# sitting in a lap nobody will ever walk through.
	ArenaCoin.to_dropped(r, Vector2(
		VersusStageData.wrap_x(seats[side].position.x),
		seats[side].position.y), dir, tick)
	events.append({"kind": "drop", "coin": r.coin_id, "side": side})

## Everything a runner was carrying when they went off the stage or ran out of
## HP. Never destroyed, never awarded to the other side.
func return_hand(side: int) -> void:
	var held := ledger.held_by(side)
	for i in range(held.size()):
		var r := ledger.get_coin(held[i])
		var spread := (float(i) - float(held.size() - 1) * 0.5) * 30.0
		var at := seats[side].position + Vector2(spread, -20.0)
		if VersusStageData.in_bounds(at):
			ArenaCoin.to_world(r, Vector2(VersusStageData.wrap_x(at.x), at.y), tick,
				Vector2(spread * 2.0, -260.0), VersusRules.DROP_LOCKOUT_TICKS)
		else:
			ArenaCoin.to_recycle(r, tick)
		events.append({"kind": "return", "coin": r.coin_id, "side": side})

func _resolve_falls() -> void:
	for i in range(2):
		if not seats[i].alive:
			continue
		if VersusStageData.in_bounds(seats[i].position):
			continue
		return_hand(i)
		events.append({"kind": "fell", "side": i})

## Called by the scene when the game's own rules killed a runner (HP reached
## zero, or 1-1's kill plane did it first). The coins come back either way.
func note_death(side: int) -> void:
	return_hand(side)
	ArenaCombat.reset_for_respawn(combat[side])
	events.append({"kind": "died", "side": side})

# -------------------------------------------------------------------- coins
func _step_coins(delta: float) -> void:
	for c in ledger.coins:
		if c.state == ArenaCoin.State.WORLD:
			ArenaCoin.step_physics(c, world, delta)
			if not VersusStageData.in_bounds(c.position):
				ArenaCoin.to_recycle(c, tick)
			elif tick - c.world_since >= VersusRules.STALE_TICKS:
				ArenaCoin.to_recycle(c, tick)
		elif c.state == ArenaCoin.State.RECYCLE_PENDING and tick >= c.recycle_at:
			# Back to UNSPAWNED rather than straight into the world, so the
			# top-up below decides where and when. Two places choosing a point
			# is how two coins end up on the same stone.
			c.state = ArenaCoin.State.UNSPAWNED
			c.owner = -1
			c.revision += 1

## Keep ON_FIELD coins loose. This is what makes ten reachable: the supply is a
## flow, not a fixed seven.
func _top_up() -> void:
	if _spawn_in > 0:
		_spawn_in -= 1
		return
	if ledger.count_in(ArenaCoin.State.WORLD) >= VersusRules.ON_FIELD:
		return
	var r := ledger.next_unspawned()
	if r == null:
		return
	# Variant, not Vector2: "there is nowhere free" has to be distinguishable
	# from a point, and Vector2.ZERO is a perfectly good place on some maps.
	var at: Variant = _free_point()
	if at == null:
		return
	ArenaCoin.to_world(r, at as Vector2, tick, Vector2.ZERO,
		VersusRules.PICKUP_LOCKOUT_TICKS)
	ledger.spawned_count += 1
	_spawn_in = VersusRules.SPAWN_GAP_TICKS
	events.append({"kind": "spawn", "coin": r.coin_id})

## The first point from the middle outwards that has no coin on it. Middle
## first, so the contested stones fill before the safe ledges.
func _free_point() -> Variant:
	for p in VersusStageData.coin_points():
		var taken := false
		for c in ledger.coins:
			if c.state == ArenaCoin.State.WORLD and c.position.distance_to(p) < 48.0:
				taken = true
				break
		if not taken:
			return p
	return null

## Nearest body wins; inside a pixel it is drawn from the match seed, so that
## neither side is quietly favoured by being index 0.
func _resolve_pickups() -> void:
	for c in ledger.coins:
		if c.state != ArenaCoin.State.WORLD:
			continue
		var best := -1
		var best_d := INF
		for i in range(2):
			if not seats[i].alive or not seats[i].can_act:
				continue
			if not ArenaCoin.can_take(c, i, tick):
				continue
			var d := _distance_to_body(c.position, i)
			if d > VersusRules.PICKUP_RADIUS:
				continue
			if best < 0 or d < best_d - 1.0:
				best = i
				best_d = d
			elif absf(d - best_d) <= 1.0 and _rng.randf() < 0.5:
				best = i
				best_d = d
		if best >= 0:
			ArenaCoin.to_held(c, best)
			events.append({"kind": "pickup", "coin": c.coin_id, "side": best})

# --------------------------------------------------------------------- shapes
static func _body_at(centre: Vector2) -> Rect2:
	return Rect2(centre - Balance.RUNNER_SIZE * 0.5, Balance.RUNNER_SIZE)

func _strike_box(side: int) -> Rect2:
	var c := combat[side]
	if c.phase != ArenaCombat.Phase.ACTIVE:
		return Rect2()
	var mid := Vector2(
		seats[side].position.x + float(c.attack_dir) * VersusRules.STRIKE_REACH,
		seats[side].position.y)
	return Rect2(mid - VersusRules.STRIKE_SIZE * 0.5, VersusRules.STRIKE_SIZE)

## To the body, not to the centre: the rule is "within 20px of the runner".
## Measured to the nearest lap, so a coin just past the join is just past it.
func _distance_to_body(at: Vector2, side: int) -> float:
	var b := _body_at(VersusStageData.nearest_image(seats[side].position, at))
	var nearest := Vector2(
		clampf(at.x, b.position.x, b.position.x + b.size.x),
		clampf(at.y, b.position.y, b.position.y + b.size.y))
	return at.distance_to(nearest)

# ----------------------------------------------------------------------- end
func _check_win() -> void:
	if phase != Phase.PLAYING:
		return
	for team in range(2):
		if score(team) >= VersusRules.WIN_AT:
			phase = Phase.OVER
			winner = team
			events.append({"kind": "win", "team": team})
			return
