class_name ArenaCombat
## One attack, "はじき", and what being hit by it does.
##
## docs/coin-battle-plan.md 4.2. Deliberately a single move with no charge, no
## combo and no aerial variant: the question the prototype asks is whether
## fighting over seven coins is fun, and a move list makes that unanswerable.
##
## Runner.take_damage() is NOT reused. It is built around HP, cooperative
## contact and a facing-derived knockback, and the arena wants none of those --
## here a hit costs a coin rather than health, and the knockback grows with
## accumulated pressure. Sharing the function would have meant one of the two
## modes bending to the other.

## Phases of the one attack.
enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY }

class CombatState:
	## 0..100, up on every hit, back to 0 on respawn. Not HP, and not the coin
	## count -- they are independent on purpose (4.2).
	var pressure: float = 0.0
	var phase: int = Phase.IDLE
	var phase_ticks: int = 0
	## Fixed when the attack starts; the stick cannot steer it afterwards.
	var attack_dir: int = 1
	## Identifies one swing, so two overlapping active frames cannot hit the
	## same fighter twice (4.2).
	var attack_id: int = 0
	var hit_this_attack: Array[int] = []
	var hitstun: int = 0
	var hit_invuln: int = 0
	var respawn_invuln: int = 0
	## Presses already spent. A press that arrives during hitstun is consumed
	## and discarded rather than firing when the stun ends.
	##
	## 0, not -1, for the same reason as MotorState.jump_press_seq: an untouched
	## controller reports 0, and -1 made that look like a press. Every fighter
	## swung on the first tick of the match.
	var attack_seq: int = 0

	func copy_from(o: CombatState) -> void:
		pressure = o.pressure
		phase = o.phase
		phase_ticks = o.phase_ticks
		attack_dir = o.attack_dir
		attack_id = o.attack_id
		hit_this_attack = o.hit_this_attack.duplicate()
		hitstun = o.hitstun
		hit_invuln = o.hit_invuln
		respawn_invuln = o.respawn_invuln
		attack_seq = o.attack_seq

	func duplicate_state() -> CombatState:
		var s := CombatState.new()
		s.copy_from(self)
		return s

	func busy() -> bool:
		return phase != Phase.IDLE

	func stunned() -> bool:
		return hitstun > 0

	## Any invulnerability at all. Kept as two counters because they mean
	## different things to a player and are drawn differently (4.2).
	func invulnerable() -> bool:
		return hit_invuln > 0 or respawn_invuln > 0

	## Respawn invulnerability also forbids acting, which hit invulnerability
	## does not: you may not attack or take coins while untouchable (5).
	func can_act() -> bool:
		return respawn_invuln <= 0 and hitstun <= 0

## Count the timers down. Called once per tick, before anything reads them.
static func advance(c: CombatState) -> void:
	c.hitstun = maxi(0, c.hitstun - 1)
	c.hit_invuln = maxi(0, c.hit_invuln - 1)
	c.respawn_invuln = maxi(0, c.respawn_invuln - 1)
	if c.phase == Phase.IDLE:
		return
	c.phase_ticks += 1
	if c.phase == Phase.STARTUP and c.phase_ticks >= ArenaRules.ATTACK_STARTUP_TICKS:
		c.phase = Phase.ACTIVE
		c.phase_ticks = 0
	elif c.phase == Phase.ACTIVE and c.phase_ticks >= ArenaRules.ATTACK_ACTIVE_TICKS:
		c.phase = Phase.RECOVERY
		c.phase_ticks = 0
	elif c.phase == Phase.RECOVERY and c.phase_ticks >= ArenaRules.ATTACK_RECOVERY_TICKS:
		c.phase = Phase.IDLE
		c.phase_ticks = 0
		c.hit_this_attack.clear()

## Try to start a swing. Returns true if one began.
##
## `axis` picks the direction once, at the press; `facing` is the fallback when
## the stick is near centre.
static func try_attack(c: CombatState, seq: int, axis: float, facing: int,
		next_attack_id: int) -> bool:
	if seq <= c.attack_seq:
		return false
	# Spent whatever happens, so it cannot be saved up through hitstun.
	c.attack_seq = seq
	if c.busy() or not c.can_act():
		return false
	c.phase = Phase.STARTUP
	c.phase_ticks = 0
	c.attack_dir = facing
	if absf(axis) > ArenaRules.ATTACK_AIM_DEADZONE:
		c.attack_dir = 1 if axis > 0.0 else -1
	c.attack_id = next_attack_id
	c.hit_this_attack.clear()
	return true

## The live hitbox this tick, or an empty rect when there is none.
static func hitbox(c: CombatState, centre: Vector2) -> Rect2:
	if c.phase != Phase.ACTIVE:
		return Rect2()
	var mid := Vector2(
		centre.x + float(c.attack_dir) * ArenaRules.ATTACK_REACH,
		centre.y - ArenaRules.ATTACK_RISE)
	return Rect2(mid - ArenaRules.ATTACK_SIZE * 0.5, ArenaRules.ATTACK_SIZE)

## Apply a confirmed hit to the victim. Returns the knockback to set.
##
## Velocity is SET rather than added, so being caught by two attackers in the
## same tick cannot accelerate anyone without limit (4.2).
static func take_hit(c: CombatState, attack_dir: int) -> Vector2:
	c.pressure = minf(ArenaRules.PRESSURE_MAX,
		c.pressure + ArenaRules.PRESSURE_PER_HIT)
	c.hitstun = ArenaRules.HITSTUN_TICKS
	c.hit_invuln = ArenaRules.HIT_INVULN_TICKS
	# The swing is interrupted.
	c.phase = Phase.IDLE
	c.phase_ticks = 0
	c.hit_this_attack.clear()
	return knockback(c.pressure, attack_dir)

static func knockback(pressure: float, attack_dir: float) -> Vector2:
	return Vector2(
		attack_dir * (ArenaRules.KNOCKBACK_BASE_X
			+ ArenaRules.KNOCKBACK_PER_PRESSURE_X * pressure),
		-(ArenaRules.KNOCKBACK_BASE_Y
			+ ArenaRules.KNOCKBACK_PER_PRESSURE_Y * pressure))

## Everything a fresh life starts with (5).
static func reset_for_respawn(c: CombatState) -> void:
	c.pressure = 0.0
	c.phase = Phase.IDLE
	c.phase_ticks = 0
	c.hitstun = 0
	c.hit_invuln = 0
	c.respawn_invuln = ArenaRules.RESPAWN_INVULN_TICKS
	c.hit_this_attack.clear()
