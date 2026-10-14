extends FinaleMachine
## STUCK! A pool of thick honey on the hive floor. Landing in it stalls the
## runner almost dead; walking through it is slow and a jump out of it only
## gets 60% of its height. Honey climbs the boots while you stand in it.

var _in := false
var _jump_cut := false

func _build() -> void:
	z_index = 7
	reach = Vector2(1200, 900)

func covers() -> bool:
	var w := float(data.get("width", 160.0))
	var p := runner.global_position - global_position
	return p.x > -8 and p.x < w + 8 and absf(p.y + Balance.RUNNER_SIZE.y * 0.5) < 10.0

func _host_step(_delta: float) -> void:
	var inside := runner.is_on_floor() and covers()
	if inside:
		if not _in:
			runner.velocity.x *= 0.15
			sound("bubble", -14.0, 1.4)
			sound("land", -9.0, 1.0)
		runner.velocity.x = clampf(runner.velocity.x, -95.0, 95.0)
		_jump_cut = false
	elif _in and runner.velocity.y < -250.0 and not _jump_cut:
		runner.velocity.y *= 0.6
		_jump_cut = true
	_in = inside

func _draw() -> void:
	var w := float(data.get("width", 160.0))
	var t := seconds()
	var surface := PackedVector2Array()
	for i in 13:
		var x := w * float(i) / 12.0
		surface.append(Vector2(x, -10 + sin(t * 2.0 + i * 0.9) * 3.0))
	surface.append(Vector2(w, 14))
	surface.append(Vector2(0, 14))
	draw_colored_polygon(surface, Color("f39a12"))
	draw_polyline(surface.slice(0, 13), Color("ffe08a"), 3.0, true)
	for k in 4:
		var x := w * (0.15 + k * 0.23)
		var life := fposmod(t * 0.7 + k * 0.31, 1.0)
		draw_circle(Vector2(x, -8 - life * 10), 4.0 + life * 5.0, Color(1, 0.86, 0.45, 1.0 - life))
	# Honey on the boots.
	if is_instance_valid(runner) and _near and runner.is_on_floor() and covers():
		var feet := runner.global_position - global_position + Vector2(0, Balance.RUNNER_SIZE.y * 0.5)
		draw_circle(feet + Vector2(-7, -6), 11.0, Color("f7a51c"))
		draw_circle(feet + Vector2(8, -5), 10.0, Color("f7a51c"))
		draw_line(feet + Vector2(-12, -14), feet + Vector2(-12, 0), Color("ffe08a"), 2.0)
