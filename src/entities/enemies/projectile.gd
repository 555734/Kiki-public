class_name Projectile
extends Area2D
## Turret fire. Stopped by terrain and by the guardian's wall -- blocking one is
## counted, because "I ate that shot for you" is one of the moments chapter 1
## wants the team to notice out loud.

const LAYER_PROJECTILE := 16

var direction: Vector2 = Vector2.LEFT
var speed: float = Balance.PROJECTILE_SPEED
var _life: float = Balance.PROJECTILE_LIFETIME
var _spin: float = 0.0

func _ready() -> void:
	add_to_group("projectile")
	collision_layer = LAYER_PROJECTILE
	collision_mask = 1 | 8   # terrain | hologram
	z_index = 6

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Balance.PROJECTILE_RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_spin += delta * 9.0
	_life -= delta
	position += direction * speed * delta
	queue_redraw()
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("hologram"):
		GameState.shots_blocked += 1
		Events.notice.emit("blocked")
	queue_free()

func _draw() -> void:
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
