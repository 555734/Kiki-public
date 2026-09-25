class_name StageKey
extends Node2D
## The key that opens the goal on the side-scrolling stages.
##
## It sits on the ground part-way along, so a team that tries to reach the
## goal entirely on guardian platforms has to come down for it. Picked up by
## the runner on each device from the runner's own (host-driven) position, so
## both screens agree without a packet; the goal itself is still decided on
## the host.

const RADIUS := 42.0
var runner: Node2D = null
var _t: float = 0.0

func _ready() -> void:
	z_index = 6
	if GameState.has_key:
		queue_free()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if GameState.has_key:
		queue_free()
		return
	if runner != null and is_instance_valid(runner) \
			and runner.global_position.distance_to(global_position) <= RADIUS:
		GameState.has_key = true
		Events.notice.emit("鍵を手に入れた！ ゴールの門が開きます")
		Events.coin_collected.emit(global_position)
		queue_free()

func _draw() -> void:
	var bob := sin(_t * 3.0) * 5.0
	var c := Vector2(0, -24 + bob)
	draw_circle(c, 26.0, Color(1.0, 0.85, 0.3, 0.18 + 0.08 * sin(_t * 5.0)))
	var gold := Color("f3c334")
	var dark := Color("9a6a12")
	# Ring.
	draw_arc(c + Vector2(-10, 0), 9.0, 0.0, TAU, 20, dark, 7.0, true)
	draw_arc(c + Vector2(-10, 0), 9.0, 0.0, TAU, 20, gold, 4.5, true)
	# Shaft and teeth.
	draw_rect(Rect2(c + Vector2(-2, -3), Vector2(24, 6)), gold)
	draw_rect(Rect2(c + Vector2(12, 3), Vector2(4, 7)), gold)
	draw_rect(Rect2(c + Vector2(18, 3), Vector2(4, 5)), gold)
	draw_circle(c + Vector2(-13, -4), 2.0, Color(1, 1, 1, 0.8))
