class_name ParadeGremlin
extends Enemy
## A dormant parade wakes when the runner crosses its cue. Movement belongs
## to the host; animation reads Clock on both devices. No enemy/enemy collision.
var runner: Runner
var speed := 245.0
var direction := 1
var wake_x := 200.0
var bounds := Vector2(-1200, 1550)
var active := false
var large := false
var kill_y := 1080.0
var _impulse_until := 0
var _impulse_x := 0.0

func parade_impulse(v: Vector2, ticks: int = 45) -> void:
	velocity = v
	_impulse_x = v.x
	_impulse_until = Clock.tick + ticks
var _last_visual_x := INF

func _build_body() -> void:
	_add_box(Vector2(34, 44) if not large else Vector2(52, 62))
	z_index = 6

func _physics_process(delta: float) -> void:
	if not Clock.is_host: return
	if not active and is_instance_valid(runner) and runner.global_position.x >= wake_x:
		active = true
	velocity.x = _impulse_x if Clock.tick < _impulse_until else (direction * speed if active else 0.0)
	velocity.y = minf(velocity.y + Balance.RUNNER_GRAVITY * delta, 1100)
	move_and_slide()
	if global_position.x >= bounds.y: direction = -1
	elif global_position.x <= bounds.x: direction = 1
	if global_position.y > kill_y + 50:
		take_damage(99, "pit")

func _process(_delta: float) -> void:
	if not Clock.is_host and _last_visual_x != INF:
		var moved := global_position.x - _last_visual_x
		if absf(moved) > 0.1:
			active = true
			direction = 1 if moved > 0 else -1
	_last_visual_x = global_position.x
	# Visibility notification avoids redrawing every distant actor.
	var camera := get_viewport().get_camera_2d()
	if camera == null or absf(global_position.x - camera.global_position.x) < 1600:
		queue_redraw()

func _draw() -> void:
	var frame := int(Clock.seconds() * 11 + net_id * 0.7) % 4 if active else 0
	ParadeArt.gremlin_on(self, frame, 88 if large else 66, direction,
		Color("ffd9b5") if large else Color.WHITE)
