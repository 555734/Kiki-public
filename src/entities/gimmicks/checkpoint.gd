class_name Checkpoint
extends Area2D
## Chapter 3 wants the rollback on death to be short and the retry to be fast,
## so checkpoints are frequent and cost nothing to pass. Reaching one is also
## the moment chapter 7 offers a role swap.

@export var index: int = 1

var reached: bool = false
var _pulse: float = 0.0
var _flash: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # runner
	z_index = 3
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 150)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if reached or not (body is Runner):
		return
	reached = true
	_flash = 1.0
	Events.checkpoint_reached.emit(index)
	GameState.checkpoint_position = global_position + Vector2(0, -40)

func _process(delta: float) -> void:
	_pulse += delta
	_flash = maxf(0.0, _flash - delta * 1.4)
	queue_redraw()

func _draw() -> void:
	var col := Balance.C_HOLO if reached else Color("8b93a1")
	var base := Vector2(0, 74.0)
	if Balance.USE_TEXTURES and Art.tex("checkpoint_off") != null:
		var wave := sin(_pulse * 2.6) * 0.03
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + wave, 1.0 - wave))
		Art.draw_sprite(self, "checkpoint_on" if reached else "checkpoint_off",
			Vector2(0.0, 76.0), 152.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if reached and _flash > 0.0:
			draw_circle(Vector2(0, -60.0), 10.0 + _flash * 34.0,
				Color(col.r, col.g, col.b, 0.35 * _flash))
		return
	# Post
	draw_rect(Rect2(-4, -70, 8, 144), Color("55606e"))
	DrawUtil.rounded_rect(self, Rect2(-22, base.y - 10, 44, 12), 5.0, Color("444e5a"))
	# Banner
	var wave := sin(_pulse * 2.6) * 5.0
	var flag := PackedVector2Array([
		Vector2(4, -66), Vector2(46, -60 + wave), Vector2(46, -26 + wave), Vector2(4, -20),
	])
	draw_colored_polygon(flag, Color(col.r, col.g, col.b, 0.9))
	draw_polyline(flag, Color(col.r, col.g, col.b), 2.0)
	if reached:
		draw_circle(Vector2(0, -70), 7.0 + _flash * 22.0, Color(col.r, col.g, col.b, 0.35 * (0.4 + _flash)))
	draw_circle(Vector2(0, -70), 6.0, col)
