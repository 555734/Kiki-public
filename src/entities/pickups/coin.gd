class_name Coin
extends Node2D
## A gauge pickup, and the only thing in the stage the runner can do FOR the
## guardian.
##
## Everything else flows one way: the guardian spends gauge to help the runner.
## A coin the runner has to go slightly out of their way for is the return leg,
## and it is why they are placed above the springs and off the critical path
## rather than along it -- a coin on the main route is just a slower regen rate.
##
## Costs nothing on the wire. Both devices run the same check against the runner
## they already have, so the coin disappears on both; only the host applies the
## gauge, because the gauge is the host's number and arrives in every snapshot.

const RADIUS := 34.0
const SIZE := 40.0

var runner: Runner = null

var _taken: bool = false
var _bob: float = 0.0

func _ready() -> void:
	z_index = 4
	add_to_group("coin")
	_bob = float(int(global_position.x)) * 0.01   # so a row does not bob in lockstep

func _process(delta: float) -> void:
	_bob += delta * 3.0
	queue_redraw()
	if _taken or runner == null or not is_instance_valid(runner):
		return
	if runner.global_position.distance_to(global_position) > RADIUS:
		return
	_taken = true
	visible = false
	set_process(false)
	Events.coin_collected.emit(global_position)

func _draw() -> void:
	var lift := sin(_bob) * 5.0
	if Art.draw_sprite(self, "coin", Vector2(0.0, SIZE * 0.5 + lift), SIZE):
		return
	draw_circle(Vector2(0.0, lift), SIZE * 0.5, Color("f6c945"))
	draw_arc(Vector2(0.0, lift), SIZE * 0.5, 0.0, TAU, 24, Color("c98f1c"), 3.0, true)
