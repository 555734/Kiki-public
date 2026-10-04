class_name VersusLives
extends RefCounted
## Deaths, respawns and the knocks a runner takes, for the runners this machine
## moves. The stars are the host's; what happens to a body here is this
## machine's, so it reacts at once instead of a round trip later.

var arena = null

## Ticks until each side's runner is back, or 0.
var respawn_in: Array[int] = []
## Where each runner was when it died, so it comes back at the checkpoint
## behind THAT rather than behind wherever its corpse drifted to.
var died_at: Array[Vector2] = []
## For the probes: enemies this machine has seen go down (host and solo).
var enemies_downed: int = 0
## For the probes: bumps this machine's own runner has been thrown by.
var bumps_felt: int = 0

var _last_vy: Array[float] = []
var _bump_quiet: int = 0
var _enemy_quiet: int = 0

func _init(owner_arena, sides: int) -> void:
	arena = owner_arena
	for i in range(sides):
		respawn_in.append(0)
		died_at.append(Vector2.ZERO)

func _runners() -> Array[Runner]:
	return arena.runners

## How fast `i` is coming down. Bodies are solid now, so the frame a runner
## lands on a head its fall has already been stopped by that head; the speed
## it arrived with is last frame's.
func fall_speed(i: int) -> float:
	return maxf(_runners()[i].velocity.y, _last_vy[i] if i < _last_vy.size() else 0.0)

func remember_fall() -> void:
	_last_vy.resize(arena.sides)
	for i in range(arena.sides):
		_last_vy[i] = _runners()[i].velocity.y

## Everyone back at their starts, alive, for a new match or a new stage.
func reset_bodies() -> void:
	var starts := VersusStageData.start_positions()
	var facings := VersusStageData.start_facing()
	var runners := _runners()
	for i in range(arena.sides):
		runners[i].respawn(starts[i])
		runners[i].facing = facings[i]
		runners[i].velocity = Vector2.ZERO
		respawn_in[i] = 0

func apply_events(events: Array) -> void:
	var runners := _runners()
	for e in events:
		match String(e.get("kind", "")):
			"hurt":
				var side: int = e["side"]
				if not arena._owns(side):
					continue
				runners[side].facing = -int(e["dir"])
				runners[side].take_damage(1)
				if runners[side].state == Runner.State.DEAD:
					begin_respawn(side)
			"bounce":
				# The host's verdict on a stomp. The stomper's own machine has
				# usually bounced already (stomp_bounce); doing it again is
				# harmless, a fresh bounce from the same height.
				if arena._owns(e["side"]) and runners[e["side"]].velocity.y > 0.0:
					runners[e["side"]].velocity.y = VersusRules.STOMP_BOUNCE
			"bump":
				# Both are thrown apart on their own machines; the stars are
				# the host's (VersusMatch._bump).
				var side: int = e["side"]
				if arena._owns(side) and runners[side].state != Runner.State.DEAD:
					runners[side].launch(Vector2(
						VersusRules.BUMP_KNOCK.x * float(e["dir"]), VersusRules.BUMP_KNOCK.y))
					Audio.play("hurt", 4.0, 0.0, 0.7)
					bumps_felt += 1
			"enemy_down":
				Audio.play("hurt", 7.0, 0.0, 0.8)
				enemies_downed += 1
			"fell":
				if arena._owns(e["side"]):
					runners[e["side"]].die("fell")
					begin_respawn(e["side"])

## A stomp feels like a stomp only if the bounce is immediate, so the
## stomper's own machine bounces as soon as its feet meet a head; the host
## judges the hit from the same observation and takes the star.
func stomp_bounce(i: int) -> void:
	var runners := _runners()
	var me := runners[i]
	if not me.is_physics_processing() or respawn_in[i] > 0:
		return
	for j in range(arena.sides):
		if j == i or not runners[j].visible or respawn_in[j] > 0:
			continue
		if VersusMatch.is_stomp(me.global_position,
				Vector2(me.velocity.x, fall_speed(i)), runners[j].global_position) \
				and arena.line_clear(me.global_position, VersusStageData.nearest_image(
					runners[j].global_position, me.global_position)):
			me.velocity.y = VersusRules.STOMP_BOUNCE
			if i < _last_vy.size():
				_last_vy[i] = VersusRules.STOMP_BOUNCE
			return

## A guest hears nothing of the host's events, so its own runner is thrown
## apart the moment it touches someone, as the host's rule will see it
## (VersusMatch.is_bump); the stars are still only the host's to drop.
func predict_bump(i: int) -> void:
	if _bump_quiet > 0:
		_bump_quiet -= 1
		return
	var runners := _runners()
	if respawn_in[i] > 0 or runners[i].state == Runner.State.DEAD:
		return
	for j in range(arena.sides):
		if j == i or not runners[j].visible or respawn_in[j] > 0:
			continue
		var them := VersusStageData.nearest_image(runners[j].global_position,
			runners[i].global_position)
		if VersusMatch.is_bump(runners[i].global_position, them):
			var dir := -signf(them.x - runners[i].global_position.x)
			if dir == 0.0:
				dir = -1.0
			apply_events([{"kind": "bump", "side": i, "dir": dir}])
			_bump_quiet = VersusRules.HIT_IMMUNE_TICKS
			return

## The same for enemies: bounced off a head it lands on, knocked back by one it
## walks into. The star is still only the host's.
func predict_enemies(i: int) -> void:
	if _enemy_quiet > 0:
		_enemy_quiet -= 1
	var me := _runners()[i]
	if respawn_in[i] > 0 or me.state == Runner.State.DEAD:
		return
	var specs: Array = arena.match_rules.enemies if arena.match_rules != null \
		else VersusStageData.enemy_specs()
	for k in range(specs.size()):
		if not arena.enemy_alive(k):
			continue
		var body := VersusEnemies.body_of(specs[k], arena.enemy_tick())
		var at := VersusStageData.nearest_image(me.global_position, body.get_center())
		if VersusMatch.is_stomp_on(at, Vector2(me.velocity.x, fall_speed(i)), body):
			me.velocity.y = VersusRules.STOMP_BOUNCE
			return
		if _enemy_quiet == 0 and not me.is_invulnerable() \
				and VersusMatch.touches_enemy(at, body):
			var dir := signf(at.x - body.get_center().x)
			apply_events([{"kind": "hurt", "side": i, "by": -1,
				"dir": dir if dir != 0.0 else 1.0, "how": "enemy"}])
			_enemy_quiet = VersusRules.HIT_IMMUNE_TICKS
			return

## Every way a runner can stop being in the match, in one place. Written as "is
## it dead" rather than as a list of causes: the first version handled only the
## two this file creates and missed 1-1's spike strip, which the runner detects
## and dies to entirely on its own.
func catch_deaths() -> void:
	for i in range(arena.sides):
		if arena._owns(i):
			_catch_death(i)

func catch_death_of(i: int) -> void:
	if i >= 0:
		_catch_death(i)

func _catch_death(i: int) -> void:
	if respawn_in[i] > 0:
		return
	var r := _runners()[i]
	if r.state == Runner.State.DEAD:
		begin_respawn(i)
	elif r.global_position.y > VersusStageData.kill_y():
		r.die("pit")
		begin_respawn(i)

func begin_respawn(side: int) -> void:
	if respawn_in[side] > 0:
		return
	died_at[side] = _runners()[side].global_position
	if arena.match_rules != null:
		arena.match_rules.note_death(side)
	respawn_in[side] = VersusRules.RESPAWN_TICKS

func apply_respawns() -> void:
	var runners := _runners()
	for i in range(arena.sides):
		if respawn_in[i] <= 0:
			continue
		respawn_in[i] -= 1
		if respawn_in[i] > 0:
			continue
		# Back at their own team's start, a short run from anywhere.
		runners[i].respawn(VersusStageData.respawn_for(i, died_at[i]))
		runners[i].facing = VersusStageData.start_facing()[i]
