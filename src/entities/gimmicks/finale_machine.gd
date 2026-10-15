class_name FinaleMachine
extends Node2D
## Base of every 1-10 machine. Two rules make them network-safe, the same two
## 1-9's ParadeDevice follows:
##
## * Poses are pure functions of Clock.tick and of the tick a state began
##   (`placed_tick`), so guests and rebuilt worlds draw the same thing.
## * Only the host decides a state change (a trigger crossed, a shot landed)
##   and announces it as "id|state|tick|aux" through Events.switch_activated.
##   HostSession relays it, replays replay_id() on every handshake, and the
##   machine itself applies it on every device in _receive().
##
## Each kind is its own script under gimmicks/finale/; from_spec picks it.

const LAYER_HAZARD := 32
const LAYER_SHOOTABLE := 64

const KINDS := {
	"scenery": "res://src/entities/gimmicks/finale/scenery.gd",
	"storm_bridge": "res://src/entities/gimmicks/finale/storm_bridge.gd",
	"pendulum_block": "res://src/entities/gimmicks/finale/pendulum_block.gd",
	"sandfall": "res://src/entities/gimmicks/finale/sandfall.gd",
	"sand_collapse": "res://src/entities/gimmicks/finale/sand_collapse.gd",
	"rockfall": "res://src/entities/gimmicks/finale/rockfall.gd",
	"lava": "res://src/entities/gimmicks/finale/lava.gd",
	"magma_ball": "res://src/entities/gimmicks/finale/magma_ball.gd",
	"chain_swing": "res://src/entities/gimmicks/finale/chain_swing.gd",
	"geyser_lift": "res://src/entities/gimmicks/finale/geyser_lift.gd",
	"rail_line": "res://src/entities/gimmicks/finale/rail_line.gd",
	"honey": "res://src/entities/gimmicks/finale/honey.gd",
	"paddle_wheel": "res://src/entities/gimmicks/finale/paddle_wheel.gd",
	"honey_shaft": "res://src/entities/gimmicks/finale/honey_shaft.gd",
	"stone_giant": "res://src/entities/gimmicks/finale/stone_giant.gd",
	"bone_beast": "res://src/entities/gimmicks/finale/bone_beast.gd",
	"bone_pillar": "res://src/entities/gimmicks/finale/bone_pillar.gd",
	"sand_geyser": "res://src/entities/gimmicks/finale/sand_geyser.gd",
	"canyon_floor": "res://src/entities/gimmicks/finale/canyon_floor.gd",
	"saw": "res://src/entities/gimmicks/finale/saw.gd",
	"crumble_lip": "res://src/entities/gimmicks/finale/crumble_lip.gd",
}

var kind := ""
var switch_id := ""
var data: Dictionary = {}
var runner: Runner = null
## Replicated state. What `state` means is the kind's business.
var state := 0
var placed_tick := 0
var aux := 0.0
## How far from the runner this machine keeps simulating and redrawing.
var reach := Vector2(1500, 1100)
var _near := true

static func from_spec(spec: Dictionary, who: Runner) -> Node2D:
	var k := String(spec.get("kind", ""))
	var path: String = KINDS.get(k, "")
	if path == "":
		push_error("1-10: unknown machine kind '%s'" % k)
		return null
	var m: FinaleMachine = load(path).new()
	m.kind = k
	m.switch_id = String(spec.get("id", k))
	m.data = spec.get("data", {})
	m.runner = who
	return m

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_to_group("switch")
	add_to_group("finale_machine")
	Events.switch_activated.connect(_receive)
	process_physics_priority = -20
	_build()
	_pose(Clock.tick)

## Subclasses: create bodies/areas here.
func _build() -> void:
	pass

## Subclasses: place bodies for this tick (every device, every tick nearby).
func _pose(_tick: int) -> void:
	pass

## Subclasses: host-only triggers and forces on the runner.
func _host_step(_delta: float) -> void:
	pass

## Subclasses: react to a state that just arrived (all devices).
func _on_state() -> void:
	pass

func _physics_process(delta: float) -> void:
	_near = is_near()
	if not _near:
		return
	_pose(Clock.tick)
	if Clock.is_host and _runner_alive():
		_host_step(delta)
	queue_redraw()

func is_near() -> bool:
	if not is_instance_valid(runner):
		return true
	var d := (runner.global_position - global_position).abs()
	return d.x < reach.x and d.y < reach.y

func _runner_alive() -> bool:
	return is_instance_valid(runner) and runner.state != Runner.State.DEAD and not runner.cleared

# ---------------------------------------------------------------- state sync
func replay_id() -> String:
	return "%s|%d|%d|%.3f" % [switch_id, state, placed_tick, aux]

## Host only: announce a new state. Applied locally by _receive like everyone.
func set_state(value: int, extra: float = 0.0) -> void:
	if not Clock.is_host:
		return
	Events.switch_activated.emit("%s|%d|%d|%.3f" % [switch_id, value, Clock.tick, extra])

func _receive(id: String) -> void:
	var fields := id.split("|")
	if fields.size() != 4 or fields[0] != switch_id:
		return
	state = int(fields[1])
	placed_tick = int(fields[2])
	aux = float(fields[3])
	_on_state()
	_pose(Clock.tick)
	queue_redraw()

func seconds() -> float:
	return Clock.seconds_at(Clock.tick)

## Seconds since the current state began (never negative).
func since(tick: int = Clock.tick) -> float:
	return maxf(0.0, float(tick - placed_tick) / float(Clock.HZ))

# ------------------------------------------------------------------ helpers
## A solid the runner can stand on and be carried by.
func make_body(size: Vector2, one_way: bool = false) -> AnimatableBody2D:
	var b := AnimatableBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.sync_to_physics = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.one_way_collision = one_way
	b.add_child(shape)
	add_child(b)
	return b

func body_size(b: AnimatableBody2D) -> Vector2:
	return ((b.get_child(0) as CollisionShape2D).shape as RectangleShape2D).size

func set_solid(b: AnimatableBody2D, on: bool) -> void:
	b.collision_layer = 1 if on else 0

## A shootable ring the guardian can snipe; calls _on_shot().
func make_target(at: Vector2, radius: float = 24.0) -> Area2D:
	var t := Target.new()
	t.machine = self
	t.collision_layer = LAYER_SHOOTABLE
	t.collision_mask = 0
	var s := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	s.shape = c
	t.add_child(s)
	t.position = at
	add_child(t)
	return t

func _on_shot() -> void:
	pass

class Target extends Area2D:
	var machine: FinaleMachine
	func shot_position() -> Vector2:
		return global_position
	func take_damage(_amount: int, _by: String = "snipe") -> void:
		if is_instance_valid(machine) and Clock.is_host:
			machine._on_shot()

## The runner's hurtbox, world space.
func runner_box() -> Rect2:
	var size := Balance.RUNNER_SIZE
	return Rect2(runner.global_position - size * 0.5, size)

func runner_hits_circle(centre: Vector2, radius: float) -> bool:
	var box := runner_box()
	var nearest := Vector2(clampf(centre.x, box.position.x, box.end.x), clampf(centre.y, box.position.y, box.end.y))
	return nearest.distance_to(centre) < radius

func hurt_runner(knock: Vector2) -> void:
	if runner.is_invulnerable():
		return
	runner.take_damage(1)
	if runner.state == Runner.State.HURT:
		runner.velocity = knock
	FinaleFx.kick(10.0)

func kill_runner(cause: String) -> void:
	runner.die(cause)
	FinaleFx.kick(14.0)

## The runner stands on `b` (feet within a few px of its top, inside its span).
func runner_on(b: AnimatableBody2D) -> bool:
	if b.collision_layer == 0 or not runner.is_on_floor():
		return false
	var size := body_size(b)
	var feet := runner.global_position.y + Balance.RUNNER_SIZE.y * 0.5
	var top := b.global_position.y - size.y * 0.5
	return absf(feet - top) < 6.0 and absf(runner.global_position.x - b.global_position.x) < size.x * 0.5 + 12.0

## Speaks only when the event is near enough for the runner to see it.
func sound(key: String, semitones: float = 0.0, volume: float = 1.0) -> void:
	if _near:
		Audio.play(key, semitones, 0.6, volume)
