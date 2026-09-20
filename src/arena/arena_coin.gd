class_name ArenaCoin
## The seven coins, as a ledger.
##
## docs/coin-battle-plan.md 3.4 states the invariant this file exists to keep:
##
##     UNSPAWNED + WORLD + HELD + RECYCLE_PENDING = the ledger's total
##     every coin_id is in exactly one of those states
##     a HELD coin's owner is exactly one valid player
##     team_score = HELD coins grouped by their owner's team
##
## The last line is the important one. The score is DERIVED from the ledger
## every time it is asked for; there is no counter to increment. A separate
## counter is how a dropped packet, a re-sent event or two players touching the
## same coin turns into a score that does not match what is on screen, and no
## amount of care at the call sites removes that class of bug -- only not having
## the counter does.
##
## Nothing here draws or sends. It is the model the host runs and the probe
## hammers.

enum State { UNSPAWNED, WORLD, HELD, RECYCLE_PENDING }

class Record:
	var coin_id: int = 0
	var state: int = State.UNSPAWNED
	var owner: int = -1
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	## Bumped on every ownership change, so a late event cannot undo a newer
	## snapshot (9.4).
	var revision: int = 0
	## Nobody may take it before this tick.
	var pickup_tick: int = 0
	## ...and the fighter who just lost it, not before this one.
	var former_owner: int = -1
	var former_owner_tick: int = 0
	## When it entered the world, for the stale timer.
	var world_since: int = 0
	var recycle_at: int = 0
	var bounces: int = 0

	func duplicate_record() -> Record:
		var r := Record.new()
		r.coin_id = coin_id
		r.state = state
		r.owner = owner
		r.position = position
		r.velocity = velocity
		r.revision = revision
		r.pickup_tick = pickup_tick
		r.former_owner = former_owner
		r.former_owner_tick = former_owner_tick
		r.world_since = world_since
		r.recycle_at = recycle_at
		r.bounces = bounces
		return r

## The whole ledger.
class Ledger:
	var coins: Array[Record] = []
	## How many of the schedule's entries have been issued.
	var spawned_count: int = 0
	## How many coin IDs this ledger was opened with. The invariant is stated
	## against THIS rather than against a constant, because the two modes want
	## different supplies: the fixed seven of the plan's arena, and the larger
	## pool a first-to-ten match needs so that ten can actually be reached.
	var total: int = 0

	func _init(coin_total: int = ArenaRules.COIN_COUNT) -> void:
		total = coin_total
		for i in range(total):
			var r := Record.new()
			r.coin_id = i
			coins.append(r)

	func count_in(state: int) -> int:
		var n := 0
		for c in coins:
			if c.state == state:
				n += 1
		return n

	## The invariant, as a yes/no. The probe asserts this every tick.
	func conserved() -> bool:
		if coins.size() != total:
			return false
		var accounted := count_in(State.UNSPAWNED) + count_in(State.WORLD) \
			+ count_in(State.HELD) + count_in(State.RECYCLE_PENDING)
		if accounted != total:
			return false
		var seen := {}
		for c in coins:
			if seen.has(c.coin_id):
				return false
			seen[c.coin_id] = true
			if c.state == State.HELD and c.owner < 0:
				return false
			if c.state != State.HELD and c.owner != -1:
				return false
		return true

	func held_by(actor: int) -> Array[int]:
		var out: Array[int] = []
		for c in coins:
			if c.state == State.HELD and c.owner == actor:
				out.append(c.coin_id)
		out.sort()
		return out

	func count_held_by(actor: int) -> int:
		return held_by(actor).size()

	## The score, derived. `team_of` maps an actor to its team id.
	func team_score(team: int, team_of: Callable) -> int:
		var n := 0
		for c in coins:
			if c.state == State.HELD and int(team_of.call(c.owner)) == team:
				n += 1
		return n

	func get_coin(coin_id: int) -> Record:
		return coins[coin_id]

	## The next coin that has never been in play, or null once all seven are out.
	func next_unspawned() -> Record:
		for c in coins:
			if c.state == State.UNSPAWNED:
				return c
		return null

# ---------------------------------------------------------------- transitions
#
# Every state change goes through one of these, so the invariant has a small
# number of places it could be broken rather than being everyone's problem.

static func to_world(r: Record, at: Vector2, tick: int, velocity := Vector2.ZERO,
		lockout: int = ArenaRules.PICKUP_LOCKOUT_TICKS) -> void:
	r.state = State.WORLD
	r.owner = -1
	r.position = at
	r.velocity = velocity
	r.revision += 1
	r.pickup_tick = tick + lockout
	r.world_since = tick
	r.bounces = 0

static func to_held(r: Record, actor: int) -> void:
	r.state = State.HELD
	r.owner = actor
	r.velocity = Vector2.ZERO
	r.revision += 1
	r.former_owner = -1
	r.former_owner_tick = 0

## A hit knocks one coin loose. It goes to the world, not to the attacker:
## either side can pick it up, which is what makes a team-mate's retrieval a
## real choice (3.3).
static func to_dropped(r: Record, from: Vector2, attacker_dir: float,
		tick: int) -> void:
	var owner := r.owner
	to_world(r, from + Vector2(0.0, -12.0), tick,
		Vector2(attacker_dir * ArenaRules.DROP_SPEED_X, -ArenaRules.DROP_SPEED_Y),
		ArenaRules.DROP_LOCKOUT_TICKS)
	r.former_owner = owner
	r.former_owner_tick = tick + ArenaRules.DROP_OWNER_LOCKOUT_TICKS

static func to_recycle(r: Record, tick: int) -> void:
	r.state = State.RECYCLE_PENDING
	r.owner = -1
	r.velocity = Vector2.ZERO
	r.revision += 1
	r.recycle_at = tick + ArenaRules.RECYCLE_TICKS

## May this actor take this coin right now?
static func can_take(r: Record, actor: int, tick: int) -> bool:
	if r.state != State.WORLD:
		return false
	if tick < r.pickup_tick:
		return false
	if actor == r.former_owner and tick < r.former_owner_tick:
		return false
	return true

## One tick of falling, for coins loose in the world (3.3).
static func step_physics(r: Record, world: ArenaStage, delta: float) -> void:
	if r.state != State.WORLD:
		return
	r.velocity.y = minf(r.velocity.y + ArenaRules.COIN_GRAVITY * delta,
		ArenaRules.COIN_TERMINAL)
	var size := Vector2(10.0, 10.0)
	var result := world.sweep(r.position, size, r.velocity * delta)
	r.position = result["position"]
	if bool(result["hit_wall"]):
		r.velocity.x = -r.velocity.x * ArenaRules.COIN_BOUNCE
	if bool(result["grounded"]):
		r.bounces += 1
		if r.bounces >= ArenaRules.COIN_MAX_BOUNCES:
			r.velocity = Vector2.ZERO
		else:
			r.velocity.y = -r.velocity.y * ArenaRules.COIN_BOUNCE
			r.velocity.x *= 0.8
	elif bool(result["hit_ceiling"]):
		r.velocity.y = 0.0
