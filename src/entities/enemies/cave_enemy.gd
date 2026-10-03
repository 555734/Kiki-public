class_name CaveEnemy
extends Enemy
## Five simple silhouettes for the underground course. Ground enemies turn at
## ledges; fliers patrol around their authored centre and stay network-owned.

@export_enum("burrower", "slime", "bat", "beetle", "mushroom") var kind := "burrower"
@export var patrol_half_width := 100.0

var direction := -1
var phase := 0.0
var _origin := Vector2.ZERO
var runner: Runner = null
const ACTIVE_RANGE_X := 1350.0
const ACTIVE_RANGE_Y := 800.0

func _ready() -> void:
	hp = 2 if kind == "burrower" else 1
	super._ready()
	_origin = global_position
	if kind == "bat" or kind == "beetle":
		collision_mask = 0
	z_index = 5

func _build_body() -> void:
	match kind:
		"bat": _add_box(Vector2(48, 32))
		"beetle": _add_box(Vector2(43, 40))
		"slime": _add_box(Vector2(47, 37))
		"mushroom": _add_box(Vector2(43, 45))
		_: _add_box(Vector2(58, 45))

func _physics_process(delta: float) -> void:
	phase += delta
	# Only enemies near the shared runner can be seen, hit or block progress.
	# The cave is 24,000 px long; simulating every distant ground patrol would
	# otherwise run dozens of move_and_slide calls and raycasts on every tick.
	if not _near_runner():
		return
	if kind == "bat" or kind == "beetle":
		var rate := 1.55 if kind == "bat" else 1.05
		global_position = _origin + Vector2(
			sin(phase * rate) * patrol_half_width,
			sin(phase * (3.1 if kind == "bat" else 2.0)) * 21.0)
		direction = 1 if cos(phase * rate) >= 0.0 else -1
		_redraw_if_near()
		return
	if kind == "mushroom" and is_on_floor() and sin(phase * 4.0) > 0.98:
		velocity.y = -330.0
	velocity.x = float(direction) * (115.0 if kind == "burrower" else 86.0)
	velocity.y = minf(velocity.y + Balance.RUNNER_GRAVITY * delta,
		Balance.RUNNER_TERMINAL_VELOCITY)
	move_and_slide()
	if is_on_wall() or absf(global_position.x - _origin.x) > patrol_half_width \
			or (is_on_floor() and not _ground_ahead()):
		direction = -direction
	_redraw_if_near()

func _redraw_if_near() -> void:
	if _near_runner():
		queue_redraw()

func _near_runner() -> bool:
	if runner == null or not is_instance_valid(runner):
		return true
	var gap := global_position - runner.global_position
	return absf(gap.x) <= ACTIVE_RANGE_X and absf(gap.y) <= ACTIVE_RANGE_Y

func _ground_ahead() -> bool:
	var from := global_position + Vector2(float(direction) * 26.0, 20.0)
	var query := PhysicsRayQueryParameters2D.create(from,
		from + Vector2(0, 22.0), 1 | 8, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _eyes(left: Vector2, right: Vector2) -> void:
	for at in [left, right]:
		draw_circle(at, 5.0, Color("f5eee1"))
		draw_circle(at + Vector2(float(direction), 1), 2.3, Color("253044"))

func _draw() -> void:
	match kind:
		"burrower":
			draw_circle(Vector2(0, 5), 24, Color("a27858"))
			draw_circle(Vector2(-6, 0), 23, Color("6e7080"))
			draw_arc(Vector2(-6, 0), 21, PI * 0.85, TAU * 0.94, 18,
				Color("afb2ae"), 4.0)
			draw_circle(Vector2(17, 9), 14, Color("d4b48b"))
			_eyes(Vector2(14, 4), Vector2(23, 4))
		"slime":
			var bounce := sin(phase * 5.0) * 2.0
			draw_circle(Vector2(0, 8 + bounce), 22, Color("409c99"))
			draw_circle(Vector2(-6, 0 + bounce), 13, Color("7cc4ba"))
			_eyes(Vector2(-8, 5 + bounce), Vector2(8, 5 + bounce))
		"bat":
			var flap := sin(phase * 12.0) * 8.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(-6, -2), Vector2(-31, -16 - flap),
				Vector2(-24, 11), Vector2(-10, 7)]), Color("747293"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(6, -2), Vector2(31, -16 - flap),
				Vector2(24, 11), Vector2(10, 7)]), Color("747293"))
			draw_circle(Vector2.ZERO, 15, Color("504c70"))
			_eyes(Vector2(-6, -2), Vector2(6, -2))
		"beetle":
			draw_circle(Vector2(0, 3), 21, Color("735d4b"))
			draw_circle(Vector2(0, 6), 14, Color("c69850"))
			draw_circle(Vector2(0, 6), 7, Color("f0cf75"))
			draw_line(Vector2(-10, -10), Vector2(-16, -23),
				Color("705d55"), 3.0)
			draw_line(Vector2(10, -10), Vector2(16, -23),
				Color("705d55"), 3.0)
			_eyes(Vector2(-7, -4), Vector2(7, -4))
		"mushroom":
			draw_rect(Rect2(-10, -2, 20, 24), Color("e5d2ad"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-25, -4), Vector2(-19, -24), Vector2(0, -33),
				Vector2(19, -24), Vector2(25, -4)]), Color("b96261"))
			for x in [-12.0, 3.0, 14.0]:
				draw_circle(Vector2(x, -16), 3.0, Color("efe0c4"))
			_eyes(Vector2(-5, 5), Vector2(5, 5))
