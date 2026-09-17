class_name Keeper
extends Enemy
## The boss of stage 1-B. See docs/stage-keeper.md.
##
## Everything this thing does is one loop:
##
##   walk in -> BRACE (a visible wind-up) -> CHARGE -> hit something -> STAGGER,
##   and while it is staggered the core on its back is open for exactly one shot.
##
## The only two ways to make it hit something are a stone pillar the stage
## provides and a wall the guardian pays 25 gauge for, which is the whole reason
## the fight exists: balance.gd has said "Wall: blocks shots and charges" since
## the first commit and nothing in the game has ever charged.
##
## It charges at whoever is in front of it, every time, and that is what makes
## the runner's job a job: the charge only ends on something if the runner was
## standing with something BEHIND them when it committed. So the runner chooses
## the ground, takes the charge on purpose, and gets over it -- a jump, or the
## guardian's slab, because the one thing the runner has that this does not is
## air. What each act takes away is the cover, not the reaction.
##
## The first version of this had a line-of-sight rule ("it will not charge at a
## runner it cannot see") to stop the pair hiding behind a pillar while the boss
## beat itself to death. It was the wrong answer to a real problem: it needed
## pillars the runner could cross, and a pillar the runner can cross is a pillar
## a charge goes past. Barricades solved both -- they stop a charge, the runner
## hops them, and a WALKING Keeper steps over one, so hiding behind one is not
## hiding. See Barricade.
##
## HOST-ONLY STATE MACHINE. On the guardian's device _physics_process is
## switched off (ClientSession._take_over_local_world) and the state arrives in
## Protocol.Msg.BOSS instead. Nothing decided in _physics_process may be
## something the other device has to guess at.

## The one thing on this enemy both players must agree about at all times: the
## guardian is aiming at a core that is open in exactly one of these.
enum State { WALK, BRACE, CHARGE, STAGGER, SLAM, RECOVER, DYING }

const DYING_TIME: float = 1.6
const SLAM_WINDUP: float = 0.45

## Terrain and the guardian's constructs. A walking Keeper steps over a
## barricade; only the charge below adds it.
const WALK_MASK: int = 1 | 8
const CHARGE_MASK: int = 1 | 8 | Balance.LAYER_BARRICADE

var runner: Runner = null
## The arena's edges, already allowing for this body's width. The Keeper never
## leaves; a boss you can walk away from is an obstacle, not a boss.
var home_min: float = -100000.0
var home_max: float = 100000.0
## Which switch to throw when it falls. The gate at the far end is listening.
var opens_gate: String = ""

var state: int = State.WALK
var facing: int = -1
## Set when a stagger begins, cleared by the one shot it allows. That is the
## whole of "one opening, one wound": without it a guardian sitting on a full
## gauge empties four shots into a 2.6s window and the fight is two cycles long.
var wounded_this_stagger: bool = false

var _timer: float = 0.0
var _charge_from: float = 0.0
var _core: Core = null
var _shock_spent: bool = false
## What the last BOSS packet said, so the host only sends when something moves.
var _sent: Array = []

func _ready() -> void:
	# Six wounds, unless this is a respawn part-way through the fight.
	#
	# -1 is "the fight has not started", a positive number is "this many wounds
	# left", and 0 is "already dead" -- which never reaches here, because
	# LevelBuilder does not build a Keeper for it. See GameState.boss_hp and
	# docs/stage-keeper.md section 8.
	hp = GameState.boss_hp if GameState.boss_hp > 0 else Balance.KEEPER_HP
	super._ready()
	add_to_group("keeper")
	# Terrain and the guardian's constructs, which is what Enemy already sets.
	# Barricades are added on top of it for the length of a charge and taken
	# away again; see _enter.
	collision_mask = WALK_MASK
	_timer = Balance.KEEPER_BEAT

func _build_body() -> void:
	_add_box(Balance.KEEPER_HITBOX)
	_core = Core.new()
	_core.name = "Core"
	_core.keeper = self
	add_child(_core)
	visual = preload("res://src/entities/enemies/keeper_visual.gd").new()
	visual.keeper = self
	add_child(visual)

# ------------------------------------------------------------------- the act

## Which act the fight is in: 1, 2 or 3. Two wounds each.
func act() -> int:
	return clampi(1 + int(floor(float(Balance.KEEPER_HP - hp) / 2.0)), 1, 3)

## How many barricades the arena has in a given act.
##
## A function of the ACT rather than of what the Keeper has smashed, and that is
## deliberate: a respawn throws the whole dynamic layer away and builds it again
## (LevelBuilder.rebuild_dynamic), so anything the barricades remembered for
## themselves comes back with them. Dying would hand act three its cover back,
## and act three is the act that has none.
static func barricades_for_act(which_act: int) -> int:
	return maxi(0, 3 - clampi(which_act, 1, 3))

func telegraph_time() -> float:
	return float(Balance.KEEPER_TELEGRAPH[act() - 1])

func stagger_time() -> float:
	return float(Balance.KEEPER_STAGGER[act() - 1])

## The ground wave only exists from act two. Act one is the lesson, and the pair
## has enough to learn without something else to jump.
func throws_shockwaves() -> bool:
	return act() >= 2

# --------------------------------------------------------------------- state

## Open, in one state only, and only until it is used.
func exposed() -> bool:
	return state == State.STAGGER and not wounded_this_stagger

## Seconds of opening left, for the bar both devices draw.
func open_for() -> float:
	return maxf(0.0, _timer) if exposed() else 0.0

func timer_left() -> float:
	return maxf(0.0, _timer)

## The body is not a target. Damage reaches this thing through the core and
## nowhere else -- the same promise the shield-bearer makes, for the same
## reason: a rifle that can hit the boss anywhere makes the runner optional.
func is_shootable_now() -> bool:
	return false

## One wound, whatever the rifle was carrying.
##
## The amount is the rifle's business (SNIPE_DAMAGE is 2, a stomp sends 99). The
## wound is this fight's, and the fight is six of them. Routed through its own
## name rather than through Enemy.take_damage so those two numbers can never
## drift into each other.
##
## The stagger is NOT cut short by it. Two reasons, and the second one is why
## this was rewritten: being shot should not help the thing get up, so the
## runner's reward for a clean bait is the whole window whether the shot lands
## early or late. And it puts the weight of "one opening, one wound" onto
## wounded_this_stagger, where the rule can actually be tested -- the first
## version ended the stagger here, which meant the flag was decoration and the
## check guarding it passed with the flag deleted. keeper_probe's negative
## control is what said so.
func wound() -> void:
	if hp <= 0 or state == State.DYING:
		return
	wounded_this_stagger = true
	var before := act()
	hp -= 1
	if hp <= 0:
		_enter(State.DYING)
		return
	# The act owns the barricades, so crossing into a new one is the moment the
	# arena loses one. They are listening; see Barricade.
	if act() != before:
		GameState.boss_hp = hp
		Events.keeper_act_changed.emit(act())

## Shot, stomped, or anything else that reaches the body: refused. Damage comes
## through the core, so nothing can kill this by accident.
func take_damage(_amount: int, _by: String = "snipe") -> void:
	pass

func die(by: String) -> void:
	if opens_gate != "":
		Events.switch_activated.emit(opens_gate)
	GameState.boss_hp = 0
	super.die(by)

## Extra shove on contact. Runner.take_damage has already taken the heart and
## applied its own knockback; this is the part that says the thing that hit you
## weighed several tons.
func on_hit_runner(who: Runner) -> void:
	if who == null or not is_instance_valid(who):
		return
	var away := signf(who.global_position.x - global_position.x)
	if away == 0.0:
		away = float(-facing)
	who.velocity = Vector2(away * Balance.KEEPER_CONTACT_KNOCKBACK.x,
		Balance.KEEPER_CONTACT_KNOCKBACK.y)

# ------------------------------------------------------------------- physics
#
# HOST ONLY. The guardian's device has this switched off and is told the answers.

func _physics_process(delta: float) -> void:
	if not is_instance_valid(runner):
		return
	velocity.y = minf(velocity.y + Balance.RUNNER_GRAVITY * delta,
		Balance.RUNNER_TERMINAL_VELOCITY)
	_timer -= delta

	match state:
		State.WALK:
			_do_walk()
		State.BRACE:
			_do_brace()
		State.CHARGE:
			_do_charge()
		State.STAGGER:
			velocity.x = 0.0
			if _timer <= 0.0:
				_enter(State.WALK)
		State.SLAM:
			velocity.x = 0.0
			if _timer <= 0.0 and not _shock_spent:
				_throw_shockwave()
				_enter(State.RECOVER)
		State.RECOVER:
			velocity.x = 0.0
			if _timer <= 0.0:
				_enter(State.WALK)
		State.DYING:
			velocity.x = 0.0
			if _timer <= 0.0:
				die("keeper")
				return

	move_and_slide()
	global_position.x = clampf(global_position.x, home_min, home_max)

	if state == State.CHARGE:
		_check_impact()

func _do_walk() -> void:
	var want := -1 if runner.global_position.x < global_position.x else 1
	facing = want
	var gap := absf(runner.global_position.x - global_position.x)
	velocity.x = 0.0 if gap < Balance.KEEPER_HITBOX.x * 0.5 \
		else float(want) * Balance.KEEPER_WALK_SPEED
	if _timer > 0.0:
		return
	if gap > Balance.KEEPER_CHARGE_RANGE:
		return                      # too far to be worth the wind-up; keep walking
	_enter(State.BRACE)

func _do_brace() -> void:
	velocity.x = 0.0
	# The lane is chosen when the wind-up ENDS, not when it starts. Locking it
	# early would run down a runner who stepped behind a pillar during the
	# telegraph, and the telegraph would be decoration.
	if _timer <= 0.0:
		facing = -1 if runner.global_position.x < global_position.x else 1
		_charge_from = global_position.x
		_enter(State.CHARGE)

func _do_charge() -> void:
	velocity.x = float(facing) * Balance.KEEPER_CHARGE_SPEED
	if absf(global_position.x - _charge_from) >= Balance.KEEPER_CHARGE_DISTANCE:
		_spend_charge()

## Ran out of legs without hitting anything. From act two that costs the runner
## something; otherwise a bad bait is free and the fight has no clock at all.
func _spend_charge() -> void:
	if throws_shockwaves():
		_enter(State.SLAM)
	else:
		_enter(State.RECOVER)

## Did the charge end on something?
##
## Deliberately asks move_and_slide rather than asking what was hit. A barricade
## is on its own layer and a guardian wall is a hologram: different layers,
## different classes, different lifetimes, and the only thing this needs to know
## is that the Keeper's face stopped moving. A type check here is how the wall
## would quietly stop working the next time holograms change.
func _check_impact() -> void:
	for i in range(get_slide_collision_count()):
		var hit := get_slide_collision(i)
		if absf(hit.get_normal().x) < 0.5:
			continue              # the floor, not a face
		velocity.x = 0.0
		_enter(State.STAGGER)
		Events.keeper_slammed.emit(
			global_position + Vector2(float(facing) * Balance.KEEPER_HITBOX.x * 0.5, 0.0))
		return
	# Pinned against the arena edge with nothing in the way. The charge is over
	# either way, and calling that an impact would hand the pair a free stagger
	# for running the boss into the scenery.
	if global_position.x <= home_min + 0.5 or global_position.x >= home_max - 0.5:
		_spend_charge()

func _enter(next: int) -> void:
	state = next
	# Head down means barricades exist; head up means it steps over them. One
	# line, and it is the whole reason the boss can own an arena that also has
	# cover in it. See Barricade.
	collision_mask = CHARGE_MASK if next == State.CHARGE else WALK_MASK
	match next:
		State.WALK: _timer = Balance.KEEPER_BEAT
		State.BRACE: _timer = telegraph_time()
		State.CHARGE: _timer = 9.0
		State.STAGGER:
			_timer = stagger_time()
			wounded_this_stagger = false
		State.SLAM:
			_timer = SLAM_WINDUP
			_shock_spent = false
		State.RECOVER: _timer = Balance.KEEPER_RECOVER
		State.DYING: _timer = DYING_TIME
	Events.keeper_state_changed.emit(self)

## Drawing timers, on BOTH devices.
##
## The guardian's copy has no physics (it is a puppet) but it still has to empty
## the ring around the core at the same rate, and it still has to throw the same
## dust when the host says SLAM -- otherwise the player holding the rifle is
## reading a still image of a fight that is moving.
func _process(delta: float) -> void:
	if not Clock.is_host:
		_timer -= delta
		if state == State.SLAM and _timer <= 0.0 and not _shock_spent:
			_throw_shockwave()
	if _core != null:
		_core.position = Vector2(
			float(-facing) * Balance.KEEPER_CORE_OFFSET.x,
			Balance.KEEPER_CORE_OFFSET.y)

## Both devices make their own. The wave is a straight line from a known place
## at a known moment, so sending it would be sending something the receiver can
## already work out; and only the host's copy is allowed to hurt anybody,
## because only the host owns the runner. See Shockwave.
func _throw_shockwave() -> void:
	_shock_spent = true
	var root := get_parent()
	if root == null:
		return
	var floor_y := global_position.y + Balance.KEEPER_SIZE.y * 0.5
	for dir in [-1, 1]:
		var wave := Shockwave.new()
		wave.direction = dir
		wave.speed = Balance.SHOCKWAVE_FAST_SPEED if act() >= 3 \
			else Balance.SHOCKWAVE_SPEED
		wave.global_position = Vector2(global_position.x,
			floor_y - Balance.SHOCKWAVE_SIZE.y * 0.5)
		root.add_child(wave)
	Events.keeper_slammed.emit(Vector2(global_position.x, floor_y))

## Is there anything in the charge lane for this charge to end on?
##
## Not a rule the Keeper obeys -- it charges either way -- but the question the
## RUNNER is answering every cycle, and the HUD and the probes both need to be
## able to ask it in the same words the fight uses.
func cover_ahead() -> bool:
	if not is_instance_valid(runner):
		return false
	var reach := Balance.KEEPER_CHARGE_DISTANCE
	var from := global_position + Vector2(
		float(facing) * Balance.KEEPER_HITBOX.x * 0.5, 0.0)
	var query := PhysicsRayQueryParameters2D.create(
		from, from + Vector2(float(facing) * reach, 0.0), CHARGE_MASK)
	query.exclude = [get_rid(), runner.get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

# ---------------------------------------------------------------- networking

## Everything the guardian's device cannot work out for itself.
func net_state() -> Array:
	return [state, hp, facing]

## Has any of it changed since the last packet? The timer is sent too, but it
## moves every frame, so it is never what makes a packet worth sending.
func net_dirty() -> bool:
	var now := net_state()
	if _sent != now:
		_sent = now
		return true
	return false

## The host has spoken. Everything here is assignment: a puppet that decided
## anything would be a second opinion, and the player holding the rifle would be
## the one holding the wrong one.
func apply_net_state(new_state: int, new_hp: int, timer: float, new_facing: int) -> void:
	if new_state != state:
		state = new_state
		if state == State.SLAM:
			_shock_spent = false
		Events.keeper_state_changed.emit(self)
	# The core is open exactly while the host says STAGGER, and shut the moment
	# it says anything else, so a stagger the host has already ended cannot
	# leave a lit target on this screen.
	if state != State.STAGGER:
		wounded_this_stagger = false
	hp = new_hp
	_timer = timer
	facing = new_facing

## The host's answer to "has this opening already been spent". Sent separately
## from the state because it changes WITHIN a stagger -- the shot that takes the
## wound does not end the stagger, it only ends the target.
func set_spent(spent: bool) -> void:
	wounded_this_stagger = spent


## The furnace on its back. Open only while the Keeper is reeling, and shut by
## the shot that takes it.
class Core extends Area2D:
	var keeper: Keeper = null

	func _ready() -> void:
		collision_layer = 64      # the layer the rifle looks at
		collision_mask = 0
		monitoring = false
		monitorable = true
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = Balance.KEEPER_CORE_RADIUS
		shape.shape = circle
		add_child(shape)
		z_index = 12

	func take_damage(_amount: int, _by: String = "snipe") -> void:
		if keeper == null or not is_instance_valid(keeper):
			return
		if not keeper.exposed():
			# Shut. Said out loud, because "refused" and "missed" feel identical
			# and only one of them means "wait for the crash".
			Events.shot_blocked.emit(global_position)
			return
		# The host owns the boss for the same reason it owns the runner. A
		# client that wounded its own puppet would be corrected by the next BOSS
		# packet, which reads as a hit that did not count.
		if not Clock.is_host:
			return
		keeper.wound()

	## Keeps the rifle's 110px assist off a shut core. Letting it snap here
	## would drag the aim off whatever the guardian actually meant and spend
	## twenty gauge on a closed hatch.
	func is_shootable_now() -> bool:
		return keeper != null and is_instance_valid(keeper) and keeper.exposed()

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if keeper == null or not is_instance_valid(keeper):
			return
		var r := Balance.KEEPER_CORE_RADIUS
		if not keeper.exposed():
			# Shut: a cold seam, so the guardian can see where it WILL be.
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24,
				Color(0.45, 0.42, 0.38, 0.65), 2.0, true)
			return
		if Art.draw_stretched(self, "keeper_core",
				Rect2(-r * 1.6, -r * 1.6, r * 3.2, r * 3.2)):
			return
		draw_circle(Vector2.ZERO, r * 1.35, Color(1.0, 0.62, 0.22, 0.28))
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.86, 0.45))
		draw_circle(Vector2.ZERO, r * 0.55, Color(1.0, 1.0, 0.92))
		draw_arc(Vector2.ZERO, r + 3.0, 0.0, TAU, 28, Color(0.25, 0.20, 0.16), 3.0, true)
