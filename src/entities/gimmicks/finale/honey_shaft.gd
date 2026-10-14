extends FinaleMachine
## BUBBLE SLINGSHOT -> HIVE SHAFT ASCENT -> BREAK THROUGH. A honey bubble at
## the foot of a narrow shaft: land on it and it bends under the runner for a
## quarter second, then flings them up. A honey current carries the launch the
## whole 1,000px; at the top a wax membrane bursts when hit from below.
##
## state 1 = membrane broken (at placed_tick).

const SQUASH := 0.22
const RADIUS := 70.0
var _membrane: AnimatableBody2D
var _squash_tick := -100000
var _launched := false

func _build() -> void:
	z_index = 4
	reach = Vector2(900, 1500)
	var left := float(data.get("left", 16830.0)) - global_position.x
	var right := float(data.get("right", 16970.0)) - global_position.x
	var top := float(data.get("top", 230.0)) - global_position.y
	_membrane = make_body(Vector2(right - left, 24.0))
	_membrane.position = Vector2((left + right) * 0.5, top)

func _pose(_tick: int) -> void:
	set_solid(_membrane, state == 0)
	# The bubble reacts on every device: it is drawn from where the runner is.
	if is_instance_valid(runner) and _on_bubble() and Clock.tick - _squash_tick > 40:
		_squash_tick = Clock.tick
		_launched = false
		sound("bubble", -3.0, 1.4)

func _on_bubble() -> bool:
	var feet := runner.global_position + Vector2(0, Balance.RUNNER_SIZE.y * 0.5)
	var c := global_position + Vector2(0, -RADIUS)
	return feet.distance_to(c) < RADIUS + 6.0 and runner.velocity.y >= -10.0

func squash() -> float:
	var age := float(Clock.tick - _squash_tick) / 60.0
	return clampf(1.0 - absf(age - SQUASH * 0.6) / (SQUASH * 0.6), 0.0, 1.0) if age < SQUASH * 1.6 else 0.0

func _on_state() -> void:
	if state == 1:
		sound("crumble", 3.0, 1.2)
		FinaleFx.kick(8.0)

func _host_step(delta: float) -> void:
	var age := float(Clock.tick - _squash_tick) / 60.0
	if age < SQUASH:
		runner.velocity = Vector2(runner.velocity.x * 0.5, 0)
	elif age < SQUASH + 0.1 and not _launched:
		_launched = true
		runner.launch(Vector2(0, -1150))
	var left := float(data.get("left", 16830.0))
	var right := float(data.get("right", 16970.0))
	var top := float(data.get("top", 230.0))
	var p := runner.global_position
	if p.x > left - 4 and p.x < right + 4 and p.y > top and p.y < global_position.y - 2.0 * RADIUS:
		runner.end_player_jump_control()
		runner.velocity.y = move_toward(runner.velocity.y, -760.0, 5200.0 * delta)
	if state == 0 and p.x > left - 10 and p.x < right + 10 and p.y - Balance.RUNNER_SIZE.y * 0.5 < top + 40.0 \
			and p.y > top - 20.0 and runner.velocity.y < -200.0:
		set_state(1)

func _draw() -> void:
	var left := float(data.get("left", 16830.0)) - global_position.x
	var right := float(data.get("right", 16970.0)) - global_position.x
	var top := float(data.get("top", 230.0)) - global_position.y
	var t := seconds()
	# The honey current up the shaft.
	var stream := FinaleArt.tex("sand_stream")
	if stream != null:
		var h := -2.0 * RADIUS - top
		var shift := fposmod(t * 520.0, float(stream.get_height()))
		var y := top + shift - float(stream.get_height())
		while y < -2.0 * RADIUS:
			var a := maxf(y, top)
			var b := minf(y + float(stream.get_height()), -2.0 * RADIUS)
			draw_texture_rect_region(stream, Rect2(left + 8, a, right - left - 16, b - a),
				Rect2(0, a - y, stream.get_width(), b - a), Color(1.0, 0.72, 0.25, 0.75))
			y += float(stream.get_height())
		for k in 10:
			var by := -2.0 * RADIUS - fposmod(t * 380.0 + k * 97.0, h)
			draw_circle(Vector2(lerpf(left + 20, right - 20, DrawUtil.hash01(k)), by), 6.0, Color(1, 0.9, 0.5, 0.8))
	# The membrane, or what is left of it.
	if state == 0:
		var shine := 0.5 + 0.2 * sin(t * 3.0)
		draw_rect(Rect2(left, top - 12, right - left, 24), Color(1.0, 0.78, 0.30, 0.9))
		for i in 4:
			var cx := left + (right - left) * (float(i) + 0.5) / 4.0
			draw_arc(Vector2(cx, top), 16, 0, TAU, 6, Color(0.6, 0.35, 0.05), 3.0)
		draw_line(Vector2(left, top - 12), Vector2(right, top - 12), Color(1, 1, 0.8, shine), 3.0)
	else:
		var age := since()
		if age < 2.0:
			for k in 12:
				var vx := (DrawUtil.hash01(k * 3) - 0.5) * 420.0
				var vy := -300.0 - DrawUtil.hash01(k * 7) * 300.0
				var p := Vector2(lerpf(left, right, DrawUtil.hash01(k)), top) + Vector2(vx * age, vy * age + 900.0 * age * age)
				draw_circle(p, 9.0, Color(1, 0.78, 0.25, 1.0 - age * 0.5))
				draw_circle(p, 4.0, Color(1, 1, 0.8, 1.0 - age * 0.5))
	# The bubble, bending under its rider.
	var sq := squash()
	var scale := Vector2(1.0 + 0.35 * sq, 1.0 - 0.4 * sq)
	var centre := Vector2(0, -RADIUS * scale.y)
	var bubble := FinaleArt.tex("honey_bubble")
	if bubble != null:
		var size := Vector2(RADIUS * 2.2, RADIUS * 2.2) * scale
		draw_texture_rect(bubble, Rect2(centre - size * 0.5, size), false)
