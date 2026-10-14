extends FinaleMachine
## SWING OVER LAVA. A platform hung from one pivot by two chains, swinging
## level over the lake. Two of them, half a period apart, meet in the middle.

var _deck: AnimatableBody2D

func _build() -> void:
	z_index = 4
	_deck = make_body(Vector2(float(data.get("width", 140.0)), 24.0))

func offset_at(tick: int) -> Vector2:
	var period := float(data.get("period", 3.0))
	var a := float(data.get("amp", 0.75)) * sin(TAU * Clock.seconds_at(tick, float(data.get("phase", 0.0))) / period)
	return Vector2(sin(a), cos(a)) * float(data.get("length", 300.0))

func _pose(tick: int) -> void:
	_deck.position = offset_at(tick) + Vector2(0, 12)

func _draw() -> void:
	var w := float(data.get("width", 140.0))
	var p := _deck.position
	draw_circle(Vector2.ZERO, 12.0, Color("3a2a2a"))
	for side in [-1.0, 1.0]:
		var end := p + Vector2(side * (w * 0.5 - 10.0), -12)
		_chain(Vector2.ZERO, end)
	FinaleArt.centred(self, "lava_platform", p + Vector2(0, 14), w + 30.0)

func _chain(a: Vector2, b: Vector2) -> void:
	var n := int(a.distance_to(b) / 18.0)
	for i in n:
		var c := a.lerp(b, (float(i) + 0.5) / float(n))
		draw_circle(c, 6.0, Color("2b2326"))
		draw_circle(c, 3.5, Color("8a7a70"))
