extends FinaleMachine
## SWARM AND PADDLES. A slow honey wheel whose paddles stay level: ride one
## up the comb cliff while the wax wisps close in.

var _paddles: Array[AnimatableBody2D] = []

func _build() -> void:
	z_index = 4
	for i in int(data.get("arms", 4)):
		_paddles.append(make_body(Vector2(float(data.get("plat_w", 110.0)), 22.0), true))

func angle_at(i: int, tick: int) -> float:
	var n := float(_paddles.size())
	return Clock.seconds_at(tick) * float(data.get("speed", 0.55)) + float(i) * TAU / n

func _pose(tick: int) -> void:
	var r := float(data.get("radius", 150.0))
	for i in _paddles.size():
		var a := angle_at(i, tick)
		_paddles[i].position = Vector2(cos(a), sin(a)) * r

func _draw() -> void:
	var r := float(data.get("radius", 150.0))
	var w := float(data.get("plat_w", 110.0))
	for i in _paddles.size():
		var p := _paddles[i].position
		draw_line(Vector2.ZERO, p, Color("7a4a1c"), 12.0)
		draw_line(Vector2.ZERO, p, Color("c98a3a"), 6.0)
	draw_circle(Vector2.ZERO, 30.0, Color("8a5420"))
	draw_circle(Vector2.ZERO, 18.0, Color("ffc23a"))
	for i in _paddles.size():
		var p := _paddles[i].position
		FinaleArt.centred(self, "plank", p + Vector2(0, 4), w + 10.0, 0.0, Color(1.0, 0.8, 0.45))
		draw_rect(Rect2(p.x - w * 0.5, p.y - 13, w, 7), Color("f5a81c"))
		var drip := 8.0 + 6.0 * sin(seconds() * 2.0 + i)
		draw_line(p + Vector2(w * 0.3, 6), p + Vector2(w * 0.3, 6 + drip), Color("f5a81c"), 5.0)
