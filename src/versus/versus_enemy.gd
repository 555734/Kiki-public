extends Node2D
## One of the star battle's enemies on screen: where VersusEnemies says it is
## at this device's match tick, hidden while the host has it down, drawn with
## the stage's own enemy painting (the one its co-op enemy wears), and on the
## rifle's layer so co-op's shot can hit it. A hit is reported to the host,
## which decides (VersusMatch.shoot_enemy).

const LAYER_SHOOTABLE := 64

var arena = null
var id: int = 0
var spec: Dictionary = {}

var _facing: int = 1
var _phase: float = 0.0

func _ready() -> void:
	z_index = 6
	var hit := Area2D.new()
	hit.name = "Shootable"
	hit.collision_layer = LAYER_SHOOTABLE
	hit.collision_mask = 0
	hit.monitoring = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = VersusEnemies.size_of(spec)
	shape.shape = box
	hit.add_child(shape)
	hit.set_script(preload("res://src/versus/versus_enemy_target.gd"))
	hit.enemy = self
	add_child(hit)
	_place()

func _physics_process(_delta: float) -> void:
	_place()

func _process(delta: float) -> void:
	_phase += delta * 9.0
	queue_redraw()

func _place() -> void:
	if arena == null:
		return
	var tick: int = arena.enemy_tick()
	global_position = arena._near(VersusEnemies.position_of(spec, tick))
	_facing = VersusEnemies.facing_of(spec, tick)
	visible = arena.enemy_alive(id)

func is_up() -> bool:
	return visible

## The painting each stage's co-op enemy wears (Art remaps "flyer" per stage).
func _key() -> String:
	if String(spec["kind"]) == "flyer":
		return "flyer"
	match VersusStageData.theme:
		Stage.Which.HORROR: return "horror_thornmite"
		Stage.Which.SEA: return "sea_crab"
		Stage.Which.SKYWARD_RUINS, Stage.Which.SWAMP: return "walker_spiky"
		_: return "walker"

func _draw() -> void:
	var size := VersusEnemies.size_of(spec)
	var flyer := String(spec["kind"]) == "flyer"
	var bob := 0.0 if flyer else absf(sin(_phase)) * 2.0
	# Feet on the body's bottom edge, as co-op draws its walkers.
	var foot := Vector2(0.0, size.y * 0.5 - bob)
	if not flyer:
		draw_set_transform(Vector2(0, size.y * 0.5 + 2.0), 0.0, Vector2(1.0, 0.30))
		draw_circle(Vector2.ZERO, 20.0, Color(0.10, 0.08, 0.06, 0.30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var height := Balance.FLYER_SPRITE_H if flyer else Balance.WALKER_SPRITE_H
	if Art.draw_sprite(self, _key(), foot if not flyer else Vector2(0.0, height * 0.5),
			height, _facing > 0):
		return
	draw_rect(Rect2(-size * 0.5, size), Color(0.55, 0.25, 0.18))
