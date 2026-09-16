extends Node2D
## Somebody pointing at a place, for a couple of seconds.
##
## The smallest possible piece of communication, and the one this game needed
## most: the guardian can see a gap the runner cannot, and the runner knows
## which way they want to go before the guardian does. Saying it out loud works
## when you are sitting together; across a network it is the difference between
## playing together and playing near each other.

## 1 = "here", 2 = "wait".
var kind: int = 1
var from_runner: bool = false

const LIFE := 2.4
const HERE := Color(0.62, 0.95, 1.0)
const WAIT := Color(1.0, 0.80, 0.35)

var _age: float = 0.0

func _ready() -> void:
	z_index = 38

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := _age / LIFE
	var fade: float = 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0)
	var colour := WAIT if kind == 2 else HERE
	# Two rings travelling outwards, so it catches the eye on a screen where
	# something else is always moving.
	for i in range(2):
		var phase: float = fmod(t * 2.0 + float(i) * 0.5, 1.0)
		draw_arc(Vector2.ZERO, 12.0 + phase * 34.0, 0.0, TAU, 26,
			Color(colour, fade * (1.0 - phase) * 0.9), 3.0, true)
	draw_circle(Vector2.ZERO, 6.0, Color(colour, fade))
	# Which of them said it. The runner's is a spike pointing down at their own
	# feet; the guardian's is a cross on the ground they are indicating.
	if from_runner:
		draw_line(Vector2(0.0, -30.0), Vector2(0.0, -10.0), Color(colour, fade), 3.0, true)
	else:
		draw_line(Vector2(-14.0, 0.0), Vector2(14.0, 0.0), Color(colour, fade * 0.8), 2.0, true)
		draw_line(Vector2(0.0, -14.0), Vector2(0.0, 14.0), Color(colour, fade * 0.8), 2.0, true)
