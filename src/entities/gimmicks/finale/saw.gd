extends FinaleMachine
## A spinning saw blade on a rail (or a fixed post). Lethal to touch.

func _build() -> void:
	z_index = 5
	reach = Vector2(1300, 900)

func centre(tick: int = Clock.tick) -> Vector2:
	var travel: Vector2 = data.get("travel", Vector2.ZERO)
	var k := 0.5 - 0.5 * cos(TAU * Clock.seconds_at(tick) / float(data.get("period", 3.0)))
	return travel * k

func _host_step(_delta: float) -> void:
	if runner_hits_circle(global_position + centre(), float(data.get("radius", 46.0)) - 6.0):
		kill_runner("saw")

func _draw() -> void:
	var travel: Vector2 = data.get("travel", Vector2.ZERO)
	var r := float(data.get("radius", 46.0))
	if travel.length() > 1.0:
		draw_line(Vector2.ZERO, travel, Color("3d3f4a"), 8.0)
		draw_line(Vector2.ZERO, travel, Color("8f96a6"), 3.0)
	else:
		draw_rect(Rect2(-8, 0, 16, 120), Color("4a4c58"))
	var c := centre()
	FinaleArt.centred(self, "saw", c, r * 2.0, seconds() * 14.0)
	draw_arc(c, r + 6.0, seconds() * 14.0, seconds() * 14.0 + 1.2, 10, Color(1, 1, 1, 0.35), 4.0)
