extends FinaleMachine
## SWINGING MASS. A chained stone block sweeps the ruin hall. At the bottom
## of its arc it clears the floor by 36px: crouch (28px tall) and it passes
## overhead; stand, and it throws you across the hall. The upper ledges are
## inside the ends of the arc, so the high route needs timing too.

var _angle := 0.0
var _last_sign := 0.0

func _build() -> void:
	z_index = 5
	reach = Vector2(1300, 1000)

func angle_at(tick: int) -> float:
	var period := float(data.get("period", 3.4))
	return float(data.get("amp", 1.0)) * sin(TAU * Clock.seconds_at(tick) / period)

func centre_at(tick: int) -> Vector2:
	var a := angle_at(tick)
	return Vector2(sin(a), cos(a)) * float(data.get("length", 459.0))

func _pose(tick: int) -> void:
	_angle = angle_at(tick)
	var s := signf(_angle)
	if s != _last_sign and _last_sign != 0.0:
		sound("dash", -9.0, 0.9)
		FinaleFx.kick(2.0)
	_last_sign = s

func _host_step(_delta: float) -> void:
	var size: Vector2 = data.get("size", Vector2(160, 130))
	var c := global_position + centre_at(Clock.tick)
	# The block's hit box rotates with it; a circle-per-corner test is enough
	# at this size and keeps the bottom clearance exact when hanging straight.
	var a := _angle
	var box := Rect2(-size * 0.5, size)
	var local := (runner.global_position - c).rotated(a)
	var half := Balance.RUNNER_SIZE * 0.5
	if runner.crouching():
		half.y = Balance.RUNNER_CROUCH_HEIGHT * 0.5
		local.y += (Balance.RUNNER_SIZE.y - Balance.RUNNER_CROUCH_HEIGHT) * 0.5
	if box.grow_individual(half.x, half.y, half.x, half.y).has_point(local):
		var swing := cos(TAU * seconds() / float(data.get("period", 3.4)))
		hurt_runner(Vector2(signf(swing + 0.001) * 560.0, -380.0))

func _draw() -> void:
	var size: Vector2 = data.get("size", Vector2(160, 130))
	var c := centre_at(Clock.tick)
	# Chain: links along the rope, the 1-7 chain painting.
	var t := FinaleArt.tex("chain")
	var length := c.length() - size.y * 0.5
	draw_set_transform(Vector2.ZERO, -_angle, Vector2.ONE)
	if t != null:
		var link := 34.0 * float(t.get_height()) / float(t.get_width())
		var y := 0.0
		while y < length:
			var h := minf(link, length - y)
			draw_texture_rect_region(t, Rect2(-17, y, 34, h), Rect2(0, 0, t.get_width(), t.get_height() * h / link))
			y += h
	draw_set_transform(c, -_angle, Vector2.ONE)
	FinaleArt.slab_on(self, Rect2(-size * 0.5, size), "sand")
	draw_rect(Rect2(-size.x * 0.5, -size.y * 0.5 + 18, size.x, 14), Color("6b4a2c"))
	draw_rect(Rect2(-size.x * 0.5, size.y * 0.5 - 30, size.x, 14), Color("6b4a2c"))
	draw_rect(Rect2(-size * 0.5, size), Color("4a2e1e"), false, 5.0)
	draw_circle(Vector2(0, -size.y * 0.5 - 6), 14.0, Color("5b4637"))
	draw_set_transform(Vector2.ZERO)
	# Motion smear at speed.
	var speed := absf(cos(TAU * seconds() / float(data.get("period", 3.4))))
	if speed > 0.6:
		var r := float(data.get("length", 459.0))
		draw_arc(Vector2.ZERO, r, PI * 0.5 - _angle - 0.35, PI * 0.5 - _angle + 0.35, 20,
			Color(1, 0.95, 0.8, 0.25 * speed), size.y * 0.8)
