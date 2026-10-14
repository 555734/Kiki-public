extends FinaleMachine
## The volcano's lava lake: an animated surface and an instant-death body.

var _area: Area2D

func _build() -> void:
	z_index = 4
	var w := float(data.get("width", 2000.0))
	_area = Area2D.new()
	_area.collision_layer = LAYER_HAZARD
	_area.collision_mask = 0
	_area.add_to_group("instant_death")
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, 300)
	s.shape = r
	s.position = Vector2(w * 0.5, 170)
	_area.add_child(s)
	add_child(_area)

func is_near() -> bool:
	if not is_instance_valid(runner):
		return true
	var x := runner.global_position.x
	var w := float(data.get("width", 2000.0))
	return x > global_position.x - 1400 and x < global_position.x + w + 1400 \
		and absf(runner.global_position.y - global_position.y) < 1100

func _draw() -> void:
	var w := float(data.get("width", 2000.0))
	var t := seconds()
	draw_rect(Rect2(0, 10, w, 500), Color("b8340e"))
	var strip := FinaleArt.tex("lava_strip")
	if strip != null:
		var h := 70.0
		var tile := h * float(strip.get_width()) / float(strip.get_height())
		var shift := fposmod(t * 30.0, tile)
		var x := -shift
		while x < w:
			var left := maxf(x, 0.0)
			var right := minf(x + tile, w)
			draw_texture_rect_region(strip, Rect2(left, -26, right - left, h),
				Rect2((left - x) / tile * strip.get_width(), 0, (right - left) / tile * strip.get_width(), strip.get_height()))
			x += tile
	for k in int(w / 160.0):
		var bx := float(k) * 160.0 + 60.0 + sin(t * 0.7 + k) * 30.0
		var life := fposmod(t * 0.8 + k * 0.37, 1.0)
		draw_circle(Vector2(bx, 14 - life * 18), 6.0 + life * 8.0, Color(1, 0.75, 0.2, 1.0 - life))
	draw_rect(Rect2(0, 60, w, 450), Color(0.55, 0.08, 0.02, 0.35))
