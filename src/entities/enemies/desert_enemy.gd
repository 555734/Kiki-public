class_name DesertEnemy
extends Enemy
## Four silhouettes from the 1-6 board, each with its own movement rhythm.

@export_enum("scarab", "cactus", "jelly", "fin") var kind: String = "scarab"
@export var patrol_half_width: float = 150.0

var direction: int = -1
var phase: float = 0.0
var _origin: Vector2

func _ready() -> void:
	hp = 2 if kind == "scarab" else 1
	super._ready()
	_origin = global_position
	# The floating and sand-swimming creatures are not bound to the ledge.
	if kind == "jelly" or kind == "fin":
		collision_mask = 0

func is_flickable() -> bool:
	return kind == "scarab" or kind == "cactus"

func is_swipeable() -> bool:
	return kind == "jelly"

func _build_body() -> void:
	match kind:
		"cactus": _add_box(Vector2(43, 66))
		"jelly": _add_box(Vector2(50, 48))
		"fin": _add_box(Vector2(54, 36))
		_: _add_box(Vector2(54, 54))
	visual = preload("res://src/entities/enemies/desert_enemy_visual.gd").new()
	visual.enemy = self
	add_child(visual)

func _physics_process(delta: float) -> void:
	phase += delta
	if kind == "jelly":
		var x := _origin.x + sin(phase * 1.1) * patrol_half_width
		global_position = Vector2(x, _origin.y + sin(phase * 2.3) * 18.0)
		return
	if kind == "fin":
		# A quick sweep followed by a pause; the fin rises visibly before contact.
		var sweep := sin(phase * 1.9)
		global_position = Vector2(_origin.x + sweep * patrol_half_width,
			_origin.y - maxf(0.0, sin(phase * 3.8)) * 18.0)
		direction = 1 if cos(phase * 1.9) > 0.0 else -1
		return
	var speed := 180.0 if kind == "scarab" else 82.0
	velocity.x = float(direction) * speed
	velocity.y = minf(velocity.y + Balance.RUNNER_GRAVITY * delta,
		Balance.RUNNER_TERMINAL_VELOCITY)
	move_and_slide()
	if is_on_wall() or absf(global_position.x - _origin.x) > patrol_half_width \
			or (is_on_floor() and not _ground_ahead()):
		direction = -direction

func _ground_ahead() -> bool:
	var half_width := 27.0 if kind == "scarab" else 22.0
	var half_height := 27.0 if kind == "scarab" else 33.0
	var from := global_position + Vector2(float(direction) * half_width, half_height - 2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 18.0),
		1 | 8, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()
