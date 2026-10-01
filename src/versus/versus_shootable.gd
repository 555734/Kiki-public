extends Area2D
class_name VersusShootable
## What makes another player's runner something the co-op rifle can hit.
##
## SniperAbility looks for areas on the enemy/shootable layers with a
## take_damage method (sniper_ability.gd). This is that, on every runner, so
## the shot is the co-op shot exactly -- the same aim assist, the same tracer,
## the same sound -- and only the consequence is versus: take_damage tells the
## arena "my shot hit this player", and the host takes a star.

const LAYER_SHOOTABLE := 64

var arena = null
var side: int = 0

func _ready() -> void:
	collision_layer = LAYER_SHOOTABLE
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Balance.RUNNER_SIZE
	shape.shape = box
	add_child(shape)

## Your own runner, a teammate, an empty chair, someone out of play, or
## someone under cover (a platform or the ground between them and the sky
## the shot falls from) cannot be the rifle's target; the assist skips them
## and the shot lands on nothing.
func is_shootable_now() -> bool:
	return arena != null and arena.can_shoot_at(side) and arena.shot_clear(side)

func take_damage(_amount: int = 1, _source: String = "") -> void:
	if arena != null:
		arena.report_shot_hit(side)
