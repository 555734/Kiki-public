extends FinaleMachine
## A sand waterfall pouring through the ruin roof. It pushes anyone inside it
## down (gently), which matters on the high route over the pendulum.

func _build() -> void:
	z_index = 6
	reach = Vector2(1200, 1200)

func _host_step(delta: float) -> void:
	var w := float(data.get("width", 70.0))
	var h := float(data.get("height", 600.0))
	var p := runner.global_position - global_position
	if absf(p.x) < w * 0.5 + 10 and p.y > 0 and p.y < h and not runner.is_on_floor():
		runner.velocity.y = minf(runner.velocity.y + 1400.0 * delta, 900.0)

func _draw() -> void:
	var t := FinaleArt.tex("sand_stream")
	var w := float(data.get("width", 70.0))
	var h := float(data.get("height", 600.0))
	if t == null:
		return
	var scroll := fposmod(seconds() * 420.0, float(t.get_height()))
	var y := -scroll
	while y < h:
		var top := maxf(y, 0.0)
		var bottom := minf(y + float(t.get_height()), h)
		draw_texture_rect_region(t, Rect2(-w * 0.5, top, w, bottom - top),
			Rect2(0, top - y, t.get_width(), bottom - top))
		y += float(t.get_height())
	for k in 6:
		var a := seconds() * 3.0 + k
		draw_circle(Vector2(sin(a) * w * 0.6, h - 4 + cos(a * 1.3) * 4), 9.0, Color("e8c27a", 0.7))
