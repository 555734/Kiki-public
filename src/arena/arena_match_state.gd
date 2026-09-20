class_name ArenaMatchState
## The match: the four fighters, the ledger, the clock, and the fixed order the
## tick is resolved in.
##
## This is the whole of P0. It draws nothing, sends nothing and reads no input
## device -- `tick(inputs)` takes four intents and advances the world, which is
## what lets the probe drive ten thousand ticks of it in a second and what will
## let the host in P2 call exactly the same function.
##
## The order in `tick()` is docs/coin-battle-plan.md 3.5, unchanged. It is not
## arbitrary: gathering every hitbox BEFORE resolving any of them is what makes
## two fighters who swing at each other on the same tick trade rather than the
## lower actor id winning, and resolving coins after blast-outs is what stops a
## coin returned by a death from being caught by the same tick that caused it.

enum Phase { LOBBY, COUNTDOWN, PLAYING, OVERTIME, RESULTS }

const TEAM_A: int = 0
const TEAM_B: int = 1

var phase: int = Phase.LOBBY
var tick: int = 0
## Counts only while the match is being played, so the spawn schedule and the
## clock cannot drift apart during a countdown.
var match_tick: int = 0
var phase_end_tick: int = 0

var fighters: Array[ArenaFighter] = []
var ledger := ArenaCoin.Ledger.new()
var world: ArenaStage = null

## Every random decision comes from here, so a match is reproducible and no
## fixed actor id is favoured (3.5).
var _rng := RandomNumberGenerator.new()
var seed_value: int = 0

## Issued once, so a result cannot be announced twice (3.1).
var result_id: int = -1
var winner: int = -1
var draw: bool = false

## Which schedule entries have fired.
var _spawn_index: int = 0
## Overtime: how long one team has held a sole lead.
var _lead_team: int = -1
var _lead_ticks: int = 0

var _next_attack_id: int = 1
## Purely for the probe and the HUD; not part of the rules.
var events: Array[Dictionary] = []

func setup(stage: ArenaStage, match_seed: int = 12345) -> void:
	world = stage
	seed_value = match_seed
	_rng.seed = match_seed
	fighters.clear()
	var starts := ArenaStageData.start_positions()
	for i in range(4):
		var f := ArenaFighter.new()
		f.actor_id = i
		f.team_id = TEAM_A if i < 2 else TEAM_B
		f.spawn_at(starts[i], 1 if i < 2 else -1)
		# spawn_at grants respawn invulnerability, which also forbids acting
		# (5). That is right coming back from a blast-out and wrong at the
		# whistle: it would leave everyone unable to attack or take a coin for
		# the first 1.2 seconds. The countdown already covers the start.
		f.combat.respawn_invuln = 0
		fighters.append(f)
	ledger = ArenaCoin.Ledger.new()
	tick = 0
	match_tick = 0
	_spawn_index = 0
	_lead_team = -1
	_lead_ticks = 0
	result_id = -1
	winner = -1
	draw = false
	events.clear()

func begin_playing() -> void:
	phase = Phase.PLAYING
	match_tick = 0
	phase_end_tick = ArenaRules.MATCH_TICKS

## Three seconds before the whistle, with the fighters already standing on
## their marks.
##
## The countdown lives in the model rather than in the scene on purpose. It is
## the reason the whistle can be the same instant on four machines in P2: the
## clock that decides when PLAYING starts is the one the host ticks, not one
## each client runs off its own frame timer.
func begin_countdown() -> void:
	phase = Phase.COUNTDOWN
	match_tick = 0
	phase_end_tick = ArenaRules.COUNTDOWN_TICKS

## Ticks left in whatever the current phase is counting down, or 0 when nothing
## is. The HUD reads this rather than doing the subtraction itself, so there is
## one place the clock can be wrong.
func ticks_left() -> int:
	if phase == Phase.COUNTDOWN:
		return maxi(0, ArenaRules.COUNTDOWN_TICKS - match_tick)
	if phase == Phase.PLAYING:
		return maxi(0, ArenaRules.MATCH_TICKS - match_tick)
	if phase == Phase.OVERTIME:
		return maxi(0, ArenaRules.OVERTIME_TICKS - match_tick)
	return 0

## Ticks until the next scheduled coin, or -1 once all seven are out. Used for
## the warning everyone gets in advance (3.2).
func next_spawn_in() -> int:
	if _spawn_index >= ArenaRules.SPAWN_SCHEDULE.size():
		return -1
	return int(ArenaRules.SPAWN_SCHEDULE[_spawn_index]["tick"]) - match_tick

## How long the overtime leader has held their lead, for the HUD (3.1).
func lead_progress() -> float:
	if phase != Phase.OVERTIME or _lead_team < 0:
		return 0.0
	return clampf(float(_lead_ticks) / float(ArenaRules.OVERTIME_LEAD_TICKS),
		0.0, 1.0)

func lead_team() -> int:
	return _lead_team

func team_of(actor: int) -> int:
	if actor < 0 or actor >= fighters.size():
		return -1
	return fighters[actor].team_id

func score(team: int) -> int:
	return ledger.team_score(team, team_of)

## One fixed tick. `inputs` is four MotorInput-plus-attack intents.
func tick_match(inputs: Array) -> void:
	if phase == Phase.COUNTDOWN:
		# Nobody moves and no coin appears; only the clock runs. Running the
		# whole tick with the inputs ignored would have been the other option,
		# and it is worse: the spawn schedule is keyed to match_tick, so the
		# first coin would land before the whistle.
		tick += 1
		match_tick += 1
		if match_tick >= ArenaRules.COUNTDOWN_TICKS:
			begin_playing()
		return
	if phase != Phase.PLAYING and phase != Phase.OVERTIME:
		return
	var delta := 1.0 / 60.0

	# 1. timers, respawns, scheduled coins
	for f in fighters:
		ArenaCombat.advance(f.combat)
	_advance_respawns()
	_advance_spawn_schedule()

	# 2. movement and attack phases
	for i in range(fighters.size()):
		var f: ArenaFighter = fighters[i]
		if not f.alive:
			continue
		var intent: Dictionary = inputs[i] if i < inputs.size() else {}
		var mi := ArenaMotor.MotorInput.new(
			float(intent.get("axis", 0.0)),
			bool(intent.get("jump_held", false)),
			int(intent.get("jump_seq", 0)))
		ArenaMotor.step(f.motor, mi, world, delta, f.combat.stunned())
		if f.can_act():
			if ArenaCombat.try_attack(f.combat, int(intent.get("attack_seq", 0)),
					mi.axis, f.motor.facing, _next_attack_id):
				_next_attack_id += 1
		f.note_safe_drop()

	# 3. gather every hitbox from the same instant, before resolving any
	var candidates := _gather_hits()

	# 4. one hit per victim, then damage, drop and knockback
	_resolve_hits(candidates)

	# 5. blast-outs: return the hand, book the respawn
	_resolve_blastouts()

	# 6. coins move, then are picked up
	_step_coins(delta)
	_resolve_pickups()

	# 7. score, and whether the match is over
	tick += 1
	match_tick += 1
	_advance_phase()

# --------------------------------------------------------------------- step 1
func _advance_respawns() -> void:
	for f in fighters:
		if f.alive:
			continue
		if f.respawn_in > 0:
			f.respawn_in -= 1
			continue
		var at: Variant = _pick_respawn(f)
		if at == null:
			# Crowded. Wait, but not for ever (5).
			f.respawn_waited += 1
			if f.respawn_waited < ArenaRules.RESPAWN_MAX_WAIT_TICKS:
				continue
			at = _furthest_respawn(f)
		f.spawn_at(at as Vector2, 1 if f.team_id == TEAM_A else -1)
		_note({"kind": "respawn", "actor": f.actor_id, "tick": tick})

## A candidate clear of terrain, of living enemies and of live hitboxes, or
## null when every one of them is crowded (5).
func _pick_respawn(f: ArenaFighter) -> Variant:
	var safe: Array[Vector2] = []
	for p in ArenaStageData.respawn_points():
		if not _respawn_clear(f, p):
			continue
		safe.append(p)
	if safe.is_empty():
		return null
	return safe[_rng.randi_range(0, safe.size() - 1)]

func _respawn_clear(f: ArenaFighter, p: Vector2) -> bool:
	var body := Rect2(p - ArenaRules.BODY_SIZE * 0.5, ArenaRules.BODY_SIZE)
	if world.overlaps(body):
		return false
	for other in fighters:
		if other.actor_id == f.actor_id or not other.alive:
			continue
		if other.team_id != f.team_id:
			if other.centre().distance_to(p) < ArenaRules.RESPAWN_ENEMY_CLEARANCE:
				return false
		var hb := ArenaCombat.hitbox(other.combat, other.centre())
		if hb.size != Vector2.ZERO:
			var reach := hb.get_center().distance_to(p)
			if reach < ArenaRules.RESPAWN_ATTACK_CLEARANCE:
				return false
	return true

## The fallback when every point is crowded: one of the two furthest from any
## enemy, so a waiting respawn cannot wait for ever (5).
func _furthest_respawn(f: ArenaFighter) -> Vector2:
	var scored: Array = []
	for p in ArenaStageData.respawn_points():
		var body := Rect2(p - ArenaRules.BODY_SIZE * 0.5, ArenaRules.BODY_SIZE)
		if world.overlaps(body):
			continue
		var nearest := INF
		for other in fighters:
			if other.team_id == f.team_id or not other.alive:
				continue
			nearest = minf(nearest, other.centre().distance_to(p))
		scored.append({"p": p, "d": nearest})
	if scored.is_empty():
		return ArenaStageData.start_positions()[f.actor_id]
	scored.sort_custom(func(a, b): return float(a["d"]) > float(b["d"]))
	var top: Array = scored.slice(0, mini(2, scored.size()))
	return top[_rng.randi_range(0, top.size() - 1)]["p"]

func _advance_spawn_schedule() -> void:
	while _spawn_index < ArenaRules.SPAWN_SCHEDULE.size():
		var entry: Dictionary = ArenaRules.SPAWN_SCHEDULE[_spawn_index]
		if match_tick < int(entry["tick"]):
			return
		for i in range(int(entry["count"])):
			var r := ledger.next_unspawned()
			if r == null:
				break
			var points := ArenaStageData.coin_spawn_points()
			var at: Vector2 = points[mini(ledger.spawned_count, points.size() - 1)]
			ArenaCoin.to_world(r, _clear_spawn_point(at), tick)
			ledger.spawned_count += 1
			_note({"kind": "coin_spawn", "coin": r.coin_id, "tick": tick})
		_spawn_index += 1

## If something is standing where a coin should appear, use the nearest
## pre-checked alternative instead. Fighters do not block the schedule (3.2).
func _clear_spawn_point(at: Vector2) -> Vector2:
	if not _point_blocked(at):
		return at
	for p in ArenaStageData.recycle_points():
		if not _point_blocked(p):
			return p
	return at

func _point_blocked(at: Vector2) -> bool:
	var box := Rect2(at - Vector2(8.0, 8.0), Vector2(16.0, 16.0))
	if world.overlaps(box):
		return true
	for c in ledger.coins:
		if c.state == ArenaCoin.State.WORLD and c.position.distance_to(at) < 20.0:
			return true
	return false

# ------------------------------------------------------------------ steps 3-4
func _gather_hits() -> Array:
	var out: Array = []
	for a in fighters:
		if not a.alive:
			continue
		var hb := ArenaCombat.hitbox(a.combat, a.centre())
		if hb.size == Vector2.ZERO:
			continue
		for v in fighters:
			if v.actor_id == a.actor_id or not v.alive:
				continue
			if v.team_id == a.team_id:
				continue                      # friendly fire does nothing (3.3)
			if v.combat.invulnerable():
				continue
			if a.combat.hit_this_attack.has(v.actor_id):
				continue                      # one swing, one hit per victim
			if not hb.intersects(v.body(), false):
				continue
			if not world.line_clear(a.centre(), v.centre()):
				continue                      # not through a floor (4.2)
			out.append({
				"attacker": a.actor_id, "victim": v.actor_id,
				"dir": a.combat.attack_dir, "pressure": v.combat.pressure,
				"dist": a.centre().distance_to(v.centre()),
			})
	return out

## One hit per victim per tick, even when two enemies connect at once. The
## bigger knockback wins; a tie is drawn from the match seed so that a fixed
## actor id is never quietly favoured (3.5).
func _resolve_hits(candidates: Array) -> void:
	var by_victim := {}
	for c in candidates:
		var v: int = c["victim"]
		if not by_victim.has(v):
			by_victim[v] = c
			continue
		var best: Dictionary = by_victim[v]
		var mine := absf(ArenaCombat.knockback(c["pressure"], c["dir"]).x)
		var theirs := absf(ArenaCombat.knockback(best["pressure"], best["dir"]).x)
		if mine > theirs or (is_equal_approx(mine, theirs) and _rng.randf() < 0.5):
			by_victim[v] = c

	for v in by_victim.keys():
		var c: Dictionary = by_victim[v]
		var victim: ArenaFighter = fighters[v]
		var attacker: ArenaFighter = fighters[c["attacker"]]
		attacker.combat.hit_this_attack.append(v)
		# An attacker only hits its nearest target (4.2); with one hitbox and
		# one victim resolved here, that falls out of the per-victim pick.
		victim.motor.velocity = ArenaCombat.take_hit(victim.combat, c["dir"])
		_drop_one(victim, float(c["dir"]))
		_note({"kind": "hit", "actor": v, "by": c["attacker"], "tick": tick})

## A hit costs exactly one coin, the lowest id held, and it goes to the world
## rather than to the attacker (3.3).
func _drop_one(victim: ArenaFighter, dir: float) -> void:
	var held := ledger.held_by(victim.actor_id)
	if held.is_empty():
		return
	var r := ledger.get_coin(held[0])
	ArenaCoin.to_dropped(r, victim.centre(), dir, tick)
	_note({"kind": "drop", "coin": r.coin_id, "actor": victim.actor_id, "tick": tick})

# --------------------------------------------------------------------- step 5
func _resolve_blastouts() -> void:
	for f in fighters:
		if not f.alive:
			continue
		if ArenaStageData.in_bounds(f.centre()):
			continue
		_return_hand(f)
		f.begin_respawn()
		# No credit is assigned. A blast-out is usually the end of a chain of
		# knockbacks rather than one attacker's doing, and KOs are a statistic
		# that the result does not use anyway (3.1, 5).
		_note({"kind": "ko", "actor": f.actor_id, "tick": tick})

## Everything a blasted-out fighter was holding comes back into play. It is
## never destroyed and never awarded to the other side (3.4).
func _return_hand(f: ArenaFighter) -> void:
	var held := ledger.held_by(f.actor_id)
	if held.is_empty():
		return
	var base := f.last_safe_drop
	if not ArenaStageData.in_bounds(base) or base == Vector2.ZERO:
		for i in range(held.size()):
			ArenaCoin.to_recycle(ledger.get_coin(held[i]), tick)
		return
	# Fanned out, so a hand of four does not land as one unreachable stack.
	for i in range(held.size()):
		var spread := (float(i) - float(held.size() - 1) * 0.5) * 26.0
		var r := ledger.get_coin(held[i])
		ArenaCoin.to_world(r, base + Vector2(spread, -20.0), tick,
			Vector2(spread * 2.0, -ArenaRules.DROP_SPEED_Y * 0.6))
		_note({"kind": "return", "coin": r.coin_id, "tick": tick})

# --------------------------------------------------------------------- step 6
func _step_coins(delta: float) -> void:
	for c in ledger.coins:
		if c.state == ArenaCoin.State.WORLD:
			ArenaCoin.step_physics(c, world, delta)
			if not ArenaStageData.in_bounds(c.position):
				ArenaCoin.to_recycle(c, tick)
			elif tick - c.world_since >= ArenaRules.COIN_STALE_TICKS:
				ArenaCoin.to_recycle(c, tick)
		elif c.state == ArenaCoin.State.RECYCLE_PENDING and tick >= c.recycle_at:
			ArenaCoin.to_world(c, _recycle_point(), tick)
			_note({"kind": "recycle", "coin": c.coin_id, "tick": tick})

## Prefer a central point that is not already occupied (3.4).
func _recycle_point() -> Vector2:
	for p in ArenaStageData.recycle_points():
		if not _point_blocked(p):
			return p
	return ArenaStageData.recycle_points()[0]

## Nearest centre wins; inside a pixel it is drawn from the seed. A client
## saying "I got there first" is never consulted (3.5).
func _resolve_pickups() -> void:
	for c in ledger.coins:
		if c.state != ArenaCoin.State.WORLD:
			continue
		var best: ArenaFighter = null
		var best_d := INF
		for f in fighters:
			if not f.can_act():
				continue
			if not ArenaCoin.can_take(c, f.actor_id, tick):
				continue
			var d := _coin_distance(c.position, f)
			if d > ArenaRules.PICKUP_RADIUS:
				continue
			if not world.line_clear(c.position, f.centre()):
				continue
			if best == null or d < best_d - 1.0:
				best = f
				best_d = d
			elif absf(d - best_d) <= 1.0 and _rng.randf() < 0.5:
				best = f
				best_d = d
		if best != null:
			ArenaCoin.to_held(c, best.actor_id)
			_note({"kind": "pickup", "coin": c.coin_id, "actor": best.actor_id,
				"tick": tick})

## Distance from a coin's centre to the fighter's body, not to its centre --
## the rule is "within 18px of the body" (3.2).
func _coin_distance(at: Vector2, f: ArenaFighter) -> float:
	var b := f.body()
	var nearest := Vector2(
		clampf(at.x, b.position.x, b.position.x + b.size.x),
		clampf(at.y, b.position.y, b.position.y + b.size.y))
	return at.distance_to(nearest)

# --------------------------------------------------------------------- step 7
func _advance_phase() -> void:
	if phase == Phase.PLAYING:
		if match_tick < ArenaRules.MATCH_TICKS:
			return
		if score(TEAM_A) == score(TEAM_B):
			phase = Phase.OVERTIME
			match_tick = 0
			_lead_team = -1
			_lead_ticks = 0
			_note({"kind": "overtime", "tick": tick})
		else:
			_finish(TEAM_A if score(TEAM_A) > score(TEAM_B) else TEAM_B, false)
		return

	if phase != Phase.OVERTIME:
		return
	var a := score(TEAM_A)
	var b := score(TEAM_B)
	var leader := -1
	if a > b:
		leader = TEAM_A
	elif b > a:
		leader = TEAM_B
	# A lead only counts while it is unbroken; losing or levelling it resets
	# the clock rather than pausing it (3.1).
	if leader == -1 or leader != _lead_team:
		_lead_team = leader
		_lead_ticks = 0
	else:
		_lead_ticks += 1
		if _lead_ticks >= ArenaRules.OVERTIME_LEAD_TICKS:
			_finish(leader, false)
			return
	if match_tick >= ArenaRules.OVERTIME_TICKS:
		if a == b:
			_finish(-1, true)
		else:
			_finish(TEAM_A if a > b else TEAM_B, false)

## Issued once. A second call cannot change a decided match (3.1).
func _finish(team: int, is_draw: bool) -> void:
	if result_id >= 0:
		return
	phase = Phase.RESULTS
	winner = team
	draw = is_draw
	result_id = tick
	_note({"kind": "result", "team": team, "draw": is_draw, "tick": tick})

func _note(e: Dictionary) -> void:
	events.append(e)
	if events.size() > 512:
		events = events.slice(events.size() - 256)
