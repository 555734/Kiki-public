class_name Projectile
extends Area2D
## Turret fire. Stopped by terrain and by the guardian's wall -- blocking one is
## counted, because "I ate that shot for you" is one of the moments chapter 1
## wants the team to notice out loud.
##
## The guardian's hand can also pinch one out of the air and send it home
## (GuardianHand): it goes back at its own turret faster than it came, and
## nothing survives it. So a bullet is no longer the host's private business --
## the guardian has to see it to catch it. Each one has a net_id and moves as
## a pure function of the shared clock from where and when it was last sent
## (origin, velocity, stamp), on both devices; the host sends a line whenever
## that changes (spawned, caught, thrown) and when it is gone.

const LAYER_PROJECTILE := 16

enum State { FLYING, HELD, THROWN }

var direction: Vector2 = Vector2.LEFT
var speed: float = Balance.PROJECTILE_SPEED
var net_id: int = -1
var state: int = State.FLYING
## Whoever fired it, on the host: where a thrown-back shot goes.
var source: Node2D = null
## Where it was at `stamp` and how it has moved since.
var origin: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var stamp: int = 0
## A copy on the device that does not own the world: drawn and catchable,
## never hits anything.
var replica: bool = false
var _life: float = Balance.PROJECTILE_LIFETIME
var _held_for: float = 0.0
var _spin: float = 0.0

## Hands out bullet names on the host. Wraps; there are never many alive.
static var _next_id: int = 0

func _ready() -> void:
	add_to_group("projectile")
	z_index = 6
	if not replica:
		if net_id < 0:
			net_id = _next_id
			_next_id = (_next_id + 1) % 65536
		origin = global_position
		velocity = direction.normalized() * speed
		stamp = Clock.tick
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Balance.PROJECTILE_RADIUS
	shape.shape = circle
	add_child(shape)
	_set_layers()
	body_entered.connect(_on_body_entered)
	if not replica:
		Events.projectile_spawned.emit(self)
		tree_exiting.connect(func() -> void: Events.projectile_gone.emit(net_id))

func _set_layers() -> void:
	if replica:
		collision_layer = 0
		collision_mask = 0
		monitoring = false
	elif state == State.THROWN:
		# Going home: it no longer hurts the runner, and it hits enemies.
		collision_layer = 0
		collision_mask = 1 | 4
	elif state == State.HELD:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = LAYER_PROJECTILE
		collision_mask = 1 | 8   # terrain | hologram

## Where it is at `tick`, from the last thing the host said about it.
func position_at(tick: int) -> Vector2:
	if state == State.HELD:
		var at := GuardianHand.finger_point(get_tree()) if is_inside_tree() else Vector2(INF, INF)
		return origin if at.x == INF else at
	return origin + velocity * float(tick - stamp) / float(Clock.HZ)

## Restate where it is: from here, at this speed, from this tick. The host does
## this on a catch and a throw; the other device on hearing about it.
func restate(new_state: int, at: Vector2, new_velocity: Vector2, tick: int) -> void:
	state = new_state
	origin = at
	velocity = new_velocity
	stamp = tick
	if velocity.length_squared() > 0.01:
		direction = velocity.normalized()
	_held_for = 0.0
	_set_layers()
	global_position = position_at(Clock.tick)

## Pinched by the guardian's finger. HOST only.
func catch() -> void:
	if state != State.FLYING:
		return
	restate(State.HELD, global_position, Vector2.ZERO, Clock.tick)
	Events.projectile_changed.emit(self)

## Let go of: back at whoever fired it, or along the flick if they are gone.
## HOST only.
func throw_back(flick: Vector2) -> void:
	if state != State.HELD:
		return
	var aim := flick
	if source != null and is_instance_valid(source):
		aim = source.global_position - global_position
	if aim.length_squared() < 1.0:
		aim = -direction
	restate(State.THROWN, global_position,
		aim.normalized() * Balance.PROJECTILE_SPEED * Balance.THROW_SPEED_SCALE, Clock.tick)
	_life = Balance.PROJECTILE_LIFETIME
	Events.projectile_changed.emit(self)

func _physics_process(delta: float) -> void:
	_spin += delta * 9.0
	global_position = position_at(Clock.tick)
	queue_redraw()
	if replica:
		return
	if state == State.HELD:
		_held_for += delta
		if _held_for >= Balance.CATCH_MAX_SECONDS:
			throw_back(Vector2.ZERO)
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if replica or state == State.HELD:
		return
	if state == State.THROWN:
		if body is Enemy:
			(body as Enemy).take_damage(Balance.THROWN_DAMAGE, "returned")
		queue_free()
		return
	if body.is_in_group("hologram"):
		GameState.shots_blocked += 1
		Events.notice.emit("blocked")
	queue_free()

func _draw() -> void:
	if state == State.THROWN:
		draw_circle(Vector2.ZERO, Balance.PROJECTILE_RADIUS * 2.6, Color(Balance.C_HOLO, 0.35))
	if Balance.USE_TEXTURES:
		var flare := 1.0 + sin(_spin * 2.0) * 0.08
		draw_line(Vector2.ZERO, -direction * 22.0, Color(1.0, 0.62, 0.22, 0.45), 6.0)
		if Art.draw_sprite(self, "projectile",
				Vector2(0.0, Balance.PROJECTILE_RADIUS * 2.6 * flare),
				Balance.PROJECTILE_RADIUS * 5.2 * flare):
			return
	var r := Balance.PROJECTILE_RADIUS
	draw_circle(Vector2.ZERO, r * 1.9, Color(1.0, 0.55, 0.2, 0.22))
	draw_circle(Vector2.ZERO, r * 1.25, Color(1.0, 0.68, 0.25, 0.5))
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.86, 0.45))
	draw_circle(Vector2(-cos(_spin) * r * 0.3, -sin(_spin) * r * 0.3), r * 0.42, Color(1, 1, 1, 0.9))
	# A short trail so the runner can tell which way it is going at a glance.
	draw_line(Vector2.ZERO, -direction * 18.0, Color(1.0, 0.6, 0.2, 0.45), 5.0)
