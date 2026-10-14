extends FinaleMachine
## Stones dropping down the collapse shaft on a cycle: a 0.5s glint at the
## top, then a fall of `fall` px in about a second. A hit costs a heart.

func _build() -> void:
	z_index = 6
	reach = Vector2(800, 1900)

func head_at(tick: int) -> Vector2:
	var period := float(data.get("period", 2.4))
	var beat := fposmod(Clock.seconds_at(tick, float(data.get("phase", 0.0))), period)
	var t := beat - 0.5
	if t < 0.0:
		return Vector2(0, -INF)
	var y := 0.5 * 2400.0 * t * t
	return Vector2(0, y) if y < float(data.get("fall", 1440.0)) else Vector2(0, -INF)

func _host_step(_delta: float) -> void:
	var h := head_at(Clock.tick)
	if h.y > -INF and runner_hits_circle(global_position + h, 26.0):
		hurt_runner(Vector2(signf(runner.velocity.x + 0.01) * 160.0, 200.0))

func _draw() -> void:
	var h := head_at(Clock.tick)
	var period := float(data.get("period", 2.4))
	var beat := fposmod(Clock.seconds_at(Clock.tick, float(data.get("phase", 0.0))), period)
	if beat < 0.5:
		draw_circle(Vector2.ZERO, 6.0 + beat * 10.0, Color(1, 0.9, 0.6, 0.6))
	if h.y > -INF:
		draw_line(h + Vector2(0, -60), h, Color(0.95, 0.85, 0.6, 0.35), 18.0)
		FinaleArt.centred(self, "stone", h, 58.0, beat * 6.0)
