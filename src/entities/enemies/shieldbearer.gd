class_name Shieldbearer
extends Enemy
## The enemy neither player can beat on their own.
##
## It carries a shield on the side it is facing, and it faces whoever is closest
## -- which in practice is the runner, because the runner is the one down there.
## Shots into the shield stop dead. The soft spot is on its back, so the only
## way to open it is for the RUNNER to draw it round: stand on one side and the
## far side becomes the guardian's shot.
##
## That is the whole design brief in one enemy. The runner cannot hurt it (there
## is no stomping this one) and the guardian cannot hit anything that matters
## until the runner has moved it, so the two of them have to agree on a moment
## rather than on a plan. And because turning takes time, agreeing on the moment
## is a real timing problem rather than a formality: the shield sweeps across
## the back on the way round and the soft spot is shut while it does.

## Where the shield and the soft spot sit, measured out from the middle.
const REACH: float = 22.0

var _facing: int = -1
var _turn_left: float = 0.0

## The tick this enemy's soft spot shuts again. Set by the host when a turn
## completes, and sent to the guardian's device so both are working from one
## answer rather than two that happen to agree.
var _open_until: int = -1
var _shield: ShieldPlate = null
var _weak: WeakPoint = null
var runner: Runner = null

func _ready() -> void:
	hp = Balance.SHIELDBEARER_HP
	super._ready()
	# Deliberately NOT stompable. The runner's answer to this one is footwork,
	# not damage -- if they could simply jump on it the guardian would have
	# nothing to do and the enemy would teach nothing.
	collision_mask = 1
	add_to_group("shieldbearer")

func _build_body() -> void:
	_add_box(Balance.SHIELDBEARER_SIZE)

	_shield = ShieldPlate.new()
	_shield.name = "Shield"
	_shield.owner_enemy = self
	add_child(_shield)

	_weak = WeakPoint.new()
	_weak.name = "WeakPoint"
	_weak.owner_enemy = self
	add_child(_weak)

	visual = preload("res://src/entities/enemies/shieldbearer_visual.gd").new()
	visual.bearer = self
	add_child(visual)

func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = minf(velocity.y + Balance.RUNNER_GRAVITY * delta,
		Balance.RUNNER_TERMINAL_VELOCITY)
	move_and_slide()

## Which way it is holding the shield, and where its two halves are. Worked out
## on BOTH devices, from the one fact they already share: where the runner is.
##
## This lived in _physics_process, which on the guardian's device is switched
## off -- the enemy there is a puppet whose position arrives in snapshots. So on
## the screen of the player whose entire job is to shoot the soft spot, the soft
## spot and the plate sat on top of each other in the middle of the enemy while
## the drawing showed them correctly on either side. Every shot the guardian
## aimed into the opening the runner had just made resolved to the plate and
## stopped dead. The mechanic could not be played at all from that side, and it
## looked like the shield simply never came off.
##
## The rule needs only the runner's position, so both devices can run it. The
## guardian's copy of the runner is about 60ms behind, which makes the guardian
## see the opening a fraction LATE rather than early -- the safe direction for a
## shot that must not go off while the shield is still coming round.
func _process(delta: float) -> void:
	var was_turning := _turn_left > 0.0
	_turn_left = maxf(0.0, _turn_left - delta)
	if runner != null and is_instance_valid(runner):
		var want := -1 if runner.global_position.x < global_position.x else 1
		if want != _facing and _turn_left <= 0.0:
			_facing = want
			_turn_left = Balance.SHIELDBEARER_TURN_TIME
			was_turning = true
	# Settling after a turn is what opens the soft spot, and only the HOST says
	# so. The guardian's device runs this same code to place the shield and draw
	# it, but a window it opened for itself would be a window the two players
	# disagree about -- and the one who is holding the rifle would be the one
	# who is wrong. See Events.weak_point_opened.
	if Clock.is_host and was_turning and _turn_left <= 0.0:
		_open_until = Clock.tick + Clock.ticks_for(Balance.SHIELDBEARER_OPEN_TIME)
		Events.weak_point_opened.emit(self, _open_until)
	if _shield != null:
		_shield.position = Vector2(float(_facing) * REACH, 0.0)
	if _weak != null:
		_weak.position = Vector2(float(-_facing) * REACH, 0.0)

## Which way it is holding the shield.
func facing_now() -> int:
	return _facing

## Still swinging round. The soft spot is shut while this holds -- the shield
## passes across it on the way -- so the guardian has to wait out the turn the
## runner just caused rather than firing the instant it starts.
func turning() -> bool:
	return _turn_left > 0.0

## Open for business -- and only because the runner just made it turn.
##
## This used to be "not turning()", which is open by default: an enemy standing
## still with nobody near it was a free kill for the guardian, so the one enemy
## in the game built to need two players needed neither. Now the window is
## opened by a completed turn, the runner is the only thing that can cause one
## (it faces whoever is nearest), and it shuts on its own.
func exposed() -> bool:
	if turning():
		return false
	return _open_until >= 0 and Clock.tick <= _open_until

## How much longer the soft spot has, in seconds, or 0. Both players are shown
## this: the runner needs to know their work landed, and the guardian needs to
## know how long they have to take the shot.
func open_for() -> float:
	if not exposed():
		return 0.0
	return float(_open_until - Clock.tick) * Clock.DT

## The host's answer, arriving on the guardian's device.
func open_until(tick: int) -> void:
	_open_until = tick

## The body itself is not a target.
##
## Without this the rifle's assist finds the body -- it is on the enemy layer
## like every other enemy -- and a shot anywhere near the thing kills it, shield
## and soft spot and all. The plate would be scenery and the runner would have
## nothing to do. Damage reaches this enemy through the soft spot and nowhere
## else; the soft spot calls take_damage below directly.
func is_shootable_now() -> bool:
	return false

func take_damage(amount: int, by: String = "snipe") -> void:
	super.take_damage(amount, by)


## The plate. A real thing in the way: the rifle can lock onto it, and doing so
## is how the guardian learns which side is which.
class ShieldPlate extends Area2D:
	var owner_enemy: Shieldbearer = null

	func _ready() -> void:
		collision_layer = 64        # the layer the rifle looks at
		collision_mask = 0
		monitoring = false
		monitorable = true
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Balance.SHIELD_PLATE_SIZE
		shape.shape = rect
		add_child(shape)

	## Shots stop here. Loudly, so the guardian knows the shot landed and was
	## refused rather than missing -- those feel identical otherwise, and one of
	## them means "aim at the other side".
	func take_damage(_amount: int, _by: String = "snipe") -> void:
		Events.shot_blocked.emit(global_position)

	func is_shootable_now() -> bool:
		return true


## The soft spot on its back.
class WeakPoint extends Area2D:
	var owner_enemy: Shieldbearer = null

	func _ready() -> void:
		collision_layer = 64
		collision_mask = 0
		monitoring = false
		monitorable = true
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = Balance.WEAK_POINT_RADIUS
		shape.shape = circle
		add_child(shape)

	func take_damage(amount: int, by: String = "snipe") -> void:
		if owner_enemy == null or not is_instance_valid(owner_enemy) \
				or owner_enemy.is_queued_for_deletion():
			return
		if not owner_enemy.exposed():
			# Shut. Not a miss and not a hit: the shield is across it.
			Events.shot_blocked.emit(global_position)
			return
		owner_enemy.take_damage(amount, by)

	## The rifle's assist must not reach into a shut one. Letting it would take
	## the aim off whatever the guardian actually meant and spend the shot on a
	## target that was never going to give.
	func is_shootable_now() -> bool:
		return owner_enemy != null and is_instance_valid(owner_enemy) \
			and not owner_enemy.is_queued_for_deletion() and owner_enemy.exposed()
