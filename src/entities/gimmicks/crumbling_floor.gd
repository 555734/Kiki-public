class_name CrumblingFloor
extends StaticBody2D
## Ground that gives way shortly after it is stood on. Chapter 5 uses collapse
## in the final section to compress the runner's decision time, which is the
## lever chapter 5 prefers over raising enemy health.

@export var span: Vector2 = Vector2(120, 40)

var _armed: bool = false
var _timer: float = 0.0
var _gone: bool = false
var _respawn: float = 0.0
var _shake: float = 0.0
var _shape: CollisionShape2D = null

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 4
	# draw_tiled repeats the terrain tiles, which needs repeat on this node too.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = span
	_shape.shape = rect
	add_child(_shape)

	# A thin sensor across the top surface tells us the runner has arrived.
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 2   # runner
	var sensor_shape := CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = Vector2(span.x, 10.0)
	sensor_shape.shape = sensor_rect
	sensor_shape.position = Vector2(0, -span.y * 0.5 - 5.0)
	sensor.add_child(sensor_shape)
	add_child(sensor)
	sensor.body_entered.connect(func(_b: Node2D) -> void: _armed = true)

func _process(delta: float) -> void:
	if _gone:
		_respawn -= delta
		if _respawn <= 0.0:
			_gone = false
			_armed = false
			_shake = 0.0
			_shape.set_deferred("disabled", false)
			queue_redraw()
		return
	if _armed:
		_timer += delta
		_shake = minf(1.0, _timer / maxf(Balance.CRUMBLE_DELAY, 0.001))
		queue_redraw()
		if _timer >= Balance.CRUMBLE_DELAY:
			_gone = true
			_timer = 0.0
			_respawn = Balance.CRUMBLE_RESPAWN
			_shape.set_deferred("disabled", true)

func reset_state() -> void:
	_gone = false
	_armed = false
	_timer = 0.0
	_shake = 0.0
	if _shape != null:
		_shape.set_deferred("disabled", false)
	queue_redraw()

func _draw() -> void:
	if _gone:
		# Leave a faint outline so the guardian can still see where it will
		# return, and plan a platform for the gap in the meantime.
		draw_rect(Rect2(-span * 0.5, span), Color(0.5, 0.4, 0.3, 0.22), false, 2.0)
		return
	var jitter := Vector2(
		sin(Time.get_ticks_msec() * 0.05) * _shake * 2.5,
		cos(Time.get_ticks_msec() * 0.07) * _shake * 1.5)
	var r := Rect2(-span * 0.5 + jitter, span)
	if has_meta("model_3d"):
		_draw_cracks(r)
		return
	if not _draw_painted(r):
		_draw_flat(r)
	_draw_cracks(r)

## The same grass-over-dirt material as the permanent ground, so the runner
## reads it as floor -- with a warm tint and a pair of standing cracks that say
## it will not stay floor. Without this it drew as a flat brown rectangle next
## to fully painted terrain, which was the one thing on screen that still
## looked like a placeholder.
func _draw_painted(r: Rect2) -> bool:
	# The supplied ground block, whose ends are already broken rather than
	# squared off -- which is exactly what a slab that has snapped away from the
	# ground either side of it should look like. Tiling the seamless terrain
	# textures here instead gave a slab with no ends at all, so the sides had to
	# be faked with two dark bars.
	if Art.draw_stretched(self, "ground_block", r):
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.55,
			r.size.x, r.size.y * 0.45), Color(0.20, 0.10, 0.04, 0.18))
		return true
	var cap := minf(r.size.y * 0.45, 20.0)
	if not Art.draw_tiled(self, "dirt_tile", r, Balance.DIRT_TILE_H * 0.7):
		return false
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.5,
		r.size.x, r.size.y * 0.5), Color(0.20, 0.10, 0.04, 0.22))
	Art.draw_tiled(self, "grass_tile", Rect2(r.position, Vector2(r.size.x, cap)), cap)
	draw_rect(Rect2(r.position.x, r.position.y, 4.0, r.size.y), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(r.position.x + r.size.x - 4.0, r.position.y, 4.0, r.size.y),
		Color(0, 0, 0, 0.28))
	# Warms up as it is about to go, so the tell is visible without reading the
	# cracks -- the guardian is looking at the whole stage, not at one slab.
	if _shake > 0.0:
		draw_rect(r, Color(0.85, 0.32, 0.12, 0.10 + _shake * 0.28))
	return true

func _draw_flat(r: Rect2) -> void:
	draw_rect(r, Balance.C_DIRT)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 7.0)), Balance.C_DIRT_LIGHT)
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y - 6.0, r.size.x, 6.0), Balance.C_DIRT_DARK)

func _draw_cracks(r: Rect2) -> void:
	# Two hairlines are always there -- the warning has to precede the step, not
	# follow it -- and two more open up once the timer is running.
	var cracks := 2 + int(_shake * 2.0)
	for i in range(cracks):
		var x := r.position.x + r.size.x * (0.2 + 0.2 * float(i))
		draw_line(Vector2(x, r.position.y), Vector2(x + 6.0, r.position.y + r.size.y),
			Color(0.25, 0.15, 0.08, 0.5 + _shake * 0.4), 1.0 + _shake * 1.6)
