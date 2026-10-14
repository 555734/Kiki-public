extends FinaleMachine
## A fossil pillar that gives way: 0.35s after the runner lands on it, it
## shudders and drops into the canyon. state 1 = loaded at placed_tick.

const HOLD := 0.35
var _top: AnimatableBody2D
var _width := 120.0

func _build() -> void:
	z_index = 3
	reach = Vector2(1400, 1500)
	_width = float(data.get("width", 120.0))
	_top = make_body(Vector2(_width, 40.0))
	_top.position = Vector2(_width * 0.5, 20.0)

func drop(tick: int = Clock.tick) -> float:
	if state == 0:
		return 0.0
	var t := since(tick) - HOLD
	return 0.0 if t <= 0.0 else 0.5 * 1800.0 * t * t

func _pose(tick: int) -> void:
	var d := drop(tick)
	_top.position = Vector2(_width * 0.5, 20.0 + d)
	set_solid(_top, d < 60.0)

func _on_state() -> void:
	sound("land", -12.0, 1.1)

func _host_step(_delta: float) -> void:
	if state == 0 and runner_on(_top):
		set_state(1)

func _draw() -> void:
	var d := drop()
	if d > 1800.0:
		return
	var shake := 0.0
	if state == 1 and since() < HOLD:
		shake = sin(since() * 80.0) * 3.0
	var t := FinaleArt.tex("bone_tile")
	var h := 1750.0 - global_position.y
	var r := Rect2(shake, d, _width, h)
	draw_texture_rect(t, r, true, Color(0.95, 0.9, 0.8))
	draw_rect(r, Color("6b5642"), false, 4.0)
	draw_line(r.position + Vector2(0, 2), r.position + Vector2(_width, 2), Color("fff7e4"), 5.0)
	for k in 3:
		var y := d + 60.0 + k * 140.0
		draw_rect(Rect2(shake - 8, y, _width + 16, 26), Color("d9cbaa"))
		draw_rect(Rect2(shake - 8, y, _width + 16, 26), Color("6b5642"), false, 3.0)
	if state == 1:
		draw_line(Vector2(shake + 20, d + 6), Vector2(shake + 50, d + 40), Color("6b5642"), 3.0)
