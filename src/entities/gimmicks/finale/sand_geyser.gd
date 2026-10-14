extends FinaleMachine
## SAND GOES VERTICAL. A column of sand blasting up out of the canyon on a
## cycle (0.8s of rising dust, then 1.4s of jet). Anyone in the jet is thrown
## upward to its top -- the way up to the high rib path.

const WARN := 0.8
const JET := 1.4

func _build() -> void:
	z_index = 6
	reach = Vector2(1300, 2100)

func beat() -> float:
	return fposmod(Clock.seconds_at(Clock.tick, float(data.get("phase", 0.0))), float(data.get("period", 4.0)))

func active() -> bool:
	var b := beat()
	return b >= WARN and b < WARN + JET

func _host_step(delta: float) -> void:
	if not active():
		return
	var w := float(data.get("width", 90.0))
	var top := float(data.get("top", -60.0))
	var p := runner.global_position
	if absf(p.x - global_position.x) < w * 0.5 + 8 and p.y > top and p.y < global_position.y:
		runner.end_player_jump_control()
		runner.velocity.y = move_toward(runner.velocity.y, -980.0, 6400.0 * delta)
		runner.velocity.x = move_toward(runner.velocity.x, 0.0, 400.0 * delta)

func _draw() -> void:
	var w := float(data.get("width", 90.0))
	var top := float(data.get("top", -60.0)) - global_position.y
	var b := beat()
	var t := seconds()
	var stream := FinaleArt.tex("sand_stream")
	if b < WARN:
		var k := b / WARN
		var reach_y := lerpf(0.0, top * 0.35, k)
		draw_rect(Rect2(-w * 0.3, reach_y, w * 0.6, -reach_y), Color(0.95, 0.8, 0.5, 0.25 * k))
		for i in 6:
			var life := fposmod(t * 2.0 + i * 0.17, 1.0)
			draw_circle(Vector2((i - 2.5) * 14.0, top * 0.35 * k - life * 40.0), 10.0 + life * 10.0, Color(0.95, 0.85, 0.6, 0.6 * (1 - life)))
		return
	if b >= WARN + JET:
		return
	var grow := clampf((b - WARN) / 0.2, 0.0, 1.0)
	var y_top := top * grow
	if stream != null:
		var tile := float(stream.get_height())
		var shift := fposmod(t * 900.0, tile)
		var y := y_top - shift
		while y < 0.0:
			var a := maxf(y, y_top)
			var c := minf(y + tile, 0.0)
			draw_texture_rect_region(stream, Rect2(-w * 0.5, a, w, c - a), Rect2(0, a - y, stream.get_width(), c - a))
			y += tile
	for i in 10:
		var a := t * 6.0 + i
		draw_circle(Vector2(sin(a) * w * 0.7, y_top + cos(a * 1.4) * 14.0), 14.0, Color(0.98, 0.86, 0.55, 0.85))
