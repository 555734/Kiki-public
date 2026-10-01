class_name VersusMatch
## The rules of the 2v2 star match: who holds what, who hit whom, who has won.
## (The ledger calls them coins; the players see stars. See VersusRules.)
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
	## What the runner's own machine says its velocity is. Stomping is a
	## falling body landing on a head, and "falling" is this.
	var velocity := Vector2.ZERO

	func duplicate_seat() -> Seat:
		var s := Seat.new()
		s.team = team
		s.position = position
		s.facing = facing
		s.can_act = can_act
		s.invulnerable = invulnerable
		s.alive = alive
		s.strike_seq = strike_seq
		s.velocity = velocity
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

## How many sides: two teams in 2v2 and 1v1, one per chair (eight) in a
## free-for-all. An empty chair is a side whose runner is never alive, so it
## is never hit, never picks up and never wins.
var sides: int = 2
## The numbers this match plays to (VersusRules for 2v2; the FFA_ ones for a
## free-for-all, with the loose-star count set from how many are playing).
var win_at: int = VersusRules.WIN_AT
var coin_total: int = VersusRules.COIN_TOTAL
var on_field: int = VersusRules.ON_FIELD

## Ticks until the next coin is allowed to appear.
var _spawn_in: int = 0
var _next_strike_id: int = 1
var _rng := RandomNumberGenerator.new()
var _last_spawn_point := Vector2(INF, INF)

## Things the scene has to apply this tick. Cleared and refilled every tick.
## Each is {"kind": ..., ...}: "hurt" (side), "died" (side), "pickup", "drop".
var events: Array[Dictionary] = []

## The only two ways to hurt somebody: a shot (VersusMatch.shoot, asked for by
## a player's tap) and a stomp (a falling runner's feet on a head, judged
## every tick). There is no close-range strike any more.
## A hit runner cannot be hit again until this tick: one shot or one stomp
## costs one star, not one per frame of overlap.
var _immune_until: Dictionary = {}
## Per side, the first tick it may shoot again.
var _shot_ready: Dictionary = {}
## Events raised between ticks (a shot arrives whenever the tap does); they
## are reported with the next tick's.
var _carry: Array[Dictionary] = []

func setup(collision: ArenaStage, match_seed: int = 20260920,
		side_count: int = 2, numbers: Dictionary = {}) -> void:
	world = collision
	_rng.seed = match_seed
	sides = maxi(side_count, 2)
	win_at = int(numbers.get("win_at", VersusRules.WIN_AT))
	coin_total = int(numbers.get("coin_total", VersusRules.COIN_TOTAL))
	on_field = int(numbers.get("on_field", VersusRules.ON_FIELD))
	ledger = ArenaCoin.Ledger.new(coin_total)
	combat.clear()
	seats.clear()
	for i in range(sides):
		combat.append(ArenaCombat.CombatState.new())
		# No respawn invulnerability at the whistle: it also forbids acting, and
		# starting a match unable to move is not what it is for.
		combat[i].respawn_invuln = 0
		var s := Seat.new()
		s.team = i
		# Nobody is in the match until the scene says so.
		s.alive = i < 2
		seats.append(s)
	phase = Phase.PLAYING
	tick = 0
	winner = -1
	_spawn_in = 0
	_last_spawn_point = Vector2(INF, INF)
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
	events.append_array(_carry)
	_carry.clear()
	if phase != Phase.PLAYING:
		return
	var delta := 1.0 / 60.0

	# 1. adopt what the scene observed, and run the timers
	for i in range(sides):
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

	for i in range(sides):
		seats[i].velocity = incoming[i].velocity
		seats[i].strike_seq = incoming[i].strike_seq

	# 2-4. stomps, all gathered from the same instant before any is applied
	_resolve_stomps()

	# 5. anyone who left the stage
	_resolve_falls()

	# 6. coins move, appear, and are taken
	_step_coins(delta)
	_top_up()
	_resolve_pickups()

	# 7. has anybody won
	tick += 1
	_check_win()

# -------------------------------------------------------- shots and stomps
func immune(side: int) -> bool:
	return tick < int(_immune_until.get(side, -1)) or seats[side].invulnerable

## One hit: the victim loses a star (if none is loose) and is untouchable for
## a second. `by` is the attacker's side, `how` "shot" or "stomp".
func _hit(victim: int, by: int, how: String, dir: float) -> void:
	_immune_until[victim] = tick + VersusRules.HIT_IMMUNE_TICKS
	events.append({"kind": "hurt", "side": victim, "by": by, "dir": dir, "how": how})
	_drop_one(victim, dir)

## A shot at `at` from `side`'s player. Hits the nearest other runner within
## the aim assist of the point, measured the short way round the loop -- the
## same reach the co-op rifle has. Returns the side hit, or -1.
func shoot(side: int, at: Vector2) -> int:
	if phase != Phase.PLAYING or side < 0 or side >= sides:
		return -1
	if tick < int(_shot_ready.get(side, 0)):
		return -1
	_shot_ready[side] = tick + VersusRules.SHOT_COOLDOWN_TICKS
	var best := -1
	var best_d := INF
	for v in range(sides):
		if v == side or not seats[v].alive or immune(v):
			continue
		var d := VersusStageData.nearest_image(seats[v].position, at).distance_to(at)
		if d <= VersusRules.SHOT_ASSIST_RADIUS and d < best_d:
			best = v
			best_d = d
	_carry.append({"kind": "shot", "side": side, "at": at, "hit": best})
	if best >= 0:
		var from := seats[side].position
		var dir := signf(VersusStageData.nearest_image(seats[best].position, from).x - from.x)
		var before := events.size()
		_hit(best, side, "shot", dir if dir != 0.0 else 1.0)
		# _hit reports into this tick's list; a shot belongs to the next.
		while events.size() > before:
			_carry.append(events.pop_back())
	return best

## Is `a` landing on `v`'s head this tick? Falling, feet within a band around
## the top of v's body, and horizontally over it -- all measured to v's
## nearest image, so a stomp across the join counts.
static func is_stomp(a_pos: Vector2, a_vel: Vector2, v_pos: Vector2) -> bool:
	if a_vel.y < VersusRules.STOMP_MIN_FALL:
		return false
	var v := VersusStageData.nearest_image(v_pos, a_pos)
	var half := Balance.RUNNER_SIZE * 0.5
	var feet := a_pos.y + half.y
	var head := v.y - half.y
	return absf(a_pos.x - v.x) <= half.x + 6.0 \
		and feet >= head - 14.0 and feet <= head + 20.0

func _resolve_stomps() -> void:
	var hits: Array = []
	for a in range(sides):
		if not seats[a].alive or not seats[a].can_act:
			continue
		for v in range(sides):
			if v == a or not seats[v].alive or immune(v):
				continue
			if is_stomp(seats[a].position, seats[a].velocity, seats[v].position):
				hits.append([v, a])
	for h in hits:
		if not immune(h[0]):
			_hit(h[0], h[1], "stomp", 0.0)
			events.append({"kind": "bounce", "side": h[1]})
	# Bumps: two runners side by side, touching, neither on the other's head.
	# Both lose a star -- and both stars land, even if one is already loose.
	for a in range(sides):
		for v in range(a + 1, sides):
			if not seats[a].alive or not seats[v].alive or immune(a) or immune(v):
				continue
			if is_bump(seats[a].position, seats[v].position):
				_bump(a, v)

## Side by side and touching (the bodies are solid to each other now, so
## "touching" is within a few pixels), not one above the other.
static func is_bump(a_pos: Vector2, v_pos: Vector2) -> bool:
	var v := VersusStageData.nearest_image(v_pos, a_pos)
	var size := Balance.RUNNER_SIZE
	return absf(a_pos.x - v.x) <= size.x + VersusRules.BUMP_REACH \
		and absf(a_pos.y - v.y) < size.y * 0.5

func _bump(a: int, v: int) -> void:
	var va := VersusStageData.nearest_image(seats[v].position, seats[a].position)
	var dir := signf(va.x - seats[a].position.x)
	if dir == 0.0:
		dir = 1.0
	for pair in [[a, -dir], [v, dir]]:
		var side: int = pair[0]
		_immune_until[side] = tick + VersusRules.HIT_IMMUNE_TICKS
		events.append({"kind": "bump", "side": side, "dir": pair[1]})
		_drop_one(side, pair[1], true)

# --------------------------------------------------------------------- hits
func _gather_hits() -> Array:
	var out: Array = []
	for a in range(sides):
		if not seats[a].alive:
			continue
		var box := _strike_box(a)
		if box.size == Vector2.ZERO:
			continue
		for v in range(sides):
			if v != a:
				_try_hit(out, a, v, box)
	return out

## Would a's live strike box land on v this tick? Appends the hit if so.
func _try_hit(out: Array, a: int, v: int, box: Rect2) -> void:
	if not seats[v].alive:
		return
	# Measured to the nearest lap: across the join the victim is a few pixels
	# away, not a whole field.
	var victim_at := VersusStageData.nearest_image(seats[v].position, seats[a].position)
	# The victim's own invulnerability, as the game reports it. Asking the
	# combat state instead would be asking a second opinion: Runner is the
	# one that will refuse the damage, so it has to be the one that decides
	# whether the coin comes off.
	if seats[v].invulnerable or combat[v].invulnerable():
		return
	if combat[a].hit_this_attack.has(v):
		return
	if not box.intersects(_body_at(victim_at), false):
		return
	# Not through a floor. A strike from one ledge at a runner standing on
	# the next has to actually reach.
	if not world.line_clear(seats[a].position, victim_at):
		return
	out.append({"attacker": a, "victim": v, "dir": combat[a].attack_dir})

func _resolve_hits(hits: Array) -> void:
	# One hit per victim per tick: two swings landing on the same runner in
	# the same instant cost one star, not two. Both attackers still spend the
	# swing on that victim.
	var struck: Dictionary = {}
	for h in hits:
		var v: int = h["victim"]
		var a: int = h["attacker"]
		combat[a].hit_this_attack.append(v)
		if struck.has(v):
			continue
		struck[v] = true
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
func _drop_one(side: int, dir: float, force: bool = false) -> void:
	var held := ledger.held_by(side)
	if held.is_empty():
		return
	# One star on the field at a time: while one is loose, a hit costs the
	# victim nothing but the second of being stunned. A bump is the exception
	# (`force`): both runners drop, whatever is already on the ground.
	if not force and ledger.count_in(ArenaCoin.State.WORLD) >= on_field:
		return
	var r := ledger.get_coin(held[0])
	# Kept inside the walls, so a star knocked loose against one is not left
	# somewhere nobody can reach.
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
		var spread := 0.0
		var at := seats[side].position + Vector2(spread, -20.0)
		# One star on the field at a time: the first goes back into play where
		# they fell (if the field has room), the rest go back to the pool.
		var room := ledger.count_in(ArenaCoin.State.WORLD) < on_field
		if room and VersusStageData.in_bounds(at):
			ArenaCoin.to_world(r, Vector2(VersusStageData.wrap_x(at.x), at.y), tick,
				Vector2(spread * 2.0, -260.0), VersusRules.DROP_LOCKOUT_TICKS)
		else:
			ArenaCoin.to_recycle(r, tick)
		events.append({"kind": "return", "coin": r.coin_id, "side": side})

func _resolve_falls() -> void:
	for i in range(sides):
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
			# A star bouncing over the join stays in lap 0.
			c.position.x = VersusStageData.wrap_x(c.position.x)
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

## Keep ON_FIELD stars loose. This is what makes seven reachable: the supply is a
## flow, not a fixed seven.
func _top_up() -> void:
	if _spawn_in > 0:
		_spawn_in -= 1
		return
	if ledger.count_in(ArenaCoin.State.WORLD) >= on_field:
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

## Host-seeded random selection, not the first empty point in stage order.
## Keep a small displacement within the safe ledge so even one candidate does
## not always mean exactly the same pixel. Never repeat the last spawn region.
func _free_point() -> Variant:
	var available: Array[Vector2] = []
	for p in VersusStageData.coin_points():
		if p.distance_to(_last_spawn_point) < 96.0:
			continue
		var taken := false
		for c in ledger.coins:
			if c.state == ArenaCoin.State.WORLD and c.position.distance_to(p) < 96.0:
				taken = true
				break
		if not taken:
			available.append(p)
	while not available.is_empty():
		var index := _rng.randi_range(0, available.size() - 1)
		var p := available[index]
		available.remove_at(index)
		var shifted := p + Vector2(_rng.randf_range(-24.0, 24.0), 0)
		# Include constructed walls in the check; never spawn inside a solid.
		if world.overlaps(Rect2(shifted - Vector2(12, 12), Vector2(24, 24))) \
				or world.floor_below(shifted, 80.0) == INF:
			continue
		_last_spawn_point = p
		return shifted
	return null

## Nearest body wins; inside a pixel it is drawn from the match seed, so that
## neither side is quietly favoured by being index 0.
func _resolve_pickups() -> void:
	for c in ledger.coins:
		if c.state != ArenaCoin.State.WORLD:
			continue
		var best := -1
		var best_d := INF
		for i in range(sides):
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
	for team in range(sides):
		if score(team) >= win_at:
			phase = Phase.OVER
			winner = team
			events.append({"kind": "win", "team": team})
			return
