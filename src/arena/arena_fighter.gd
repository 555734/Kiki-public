class_name ArenaFighter
## One of the four. Position, motor, combat and a respawn booking.
##
## docs/coin-battle-plan.md 8. Kept as plain state rather than a Node because
## the host has to be able to save it, hand it to a re-simulation and compare
## the result (9.3). A Node drags in `is_on_floor()` caches, signals and a
## scene tree, none of which survive being rewound.
##
## The plan's identity contract is `player_id != peer_id != actor_id !=
## team_id`. Only actor and team matter locally; the other two arrive with the
## networking in P2, and keeping them apart now is what stops that from being a
## rewrite.

var actor_id: int = 0
var team_id: int = 0
## Bumped on every respawn, so input and hits belonging to the previous life
## can be rejected (5).
var spawn_epoch: int = 0

var motor := ArenaMotor.MotorState.new()
var combat := ArenaCombat.CombatState.new()

## Ticks until this fighter comes back, or 0 when alive.
var respawn_in: int = 0
var alive: bool = true
## How long a respawn has been waiting for a safe point, so it cannot wait for
## ever (5).
var respawn_waited: int = 0

## The last place this fighter stood that coins could safely be dropped at.
## Updated every tick while grounded and in bounds; used when a blast-out has
## to return a hand of coins without scattering them past the blast line (3.4).
var last_safe_drop := Vector2.ZERO

var kos: int = 0
var deaths: int = 0

func duplicate_fighter() -> ArenaFighter:
	var f := ArenaFighter.new()
	f.actor_id = actor_id
	f.team_id = team_id
	f.spawn_epoch = spawn_epoch
	f.motor = motor.duplicate_state()
	f.combat = combat.duplicate_state()
	f.respawn_in = respawn_in
	f.alive = alive
	f.respawn_waited = respawn_waited
	f.last_safe_drop = last_safe_drop
	f.kos = kos
	f.deaths = deaths
	return f

func body() -> Rect2:
	return ArenaMotor.body_rect(motor)

func centre() -> Vector2:
	return motor.position

## Alive, out of hitstun and not freshly respawned. Being able to act is what
## gates attacking and taking coins (5).
func can_act() -> bool:
	return alive and combat.can_act()

## Put this fighter into play at a point, with nothing carried over.
func spawn_at(at: Vector2, facing: int) -> void:
	spawn_epoch += 1
	alive = true
	respawn_in = 0
	respawn_waited = 0
	ArenaMotor.reset_at(motor, at, facing)
	ArenaCombat.reset_for_respawn(combat)
	last_safe_drop = at

## Taken out. The caller returns the coins; this only stops the body.
func begin_respawn() -> void:
	alive = false
	deaths += 1
	respawn_in = ArenaRules.RESPAWN_TICKS
	respawn_waited = 0
	motor.velocity = Vector2.ZERO
	ArenaCombat.reset_for_respawn(combat)
	# Not invulnerable while dead; it is granted again on the way back in.
	combat.respawn_invuln = 0

## Remember somewhere coins could be dropped, if here is such a place.
##
## Standing on a floor inside the arena is the whole test: the plan's "a point
## inside, clear of terrain, with a floor within 80px below" is exactly what
## being grounded in bounds already proves (3.4).
func note_safe_drop() -> void:
	if not alive or not motor.grounded:
		return
	if not ArenaStageData.in_bounds(motor.position):
		return
	last_safe_drop = motor.position
