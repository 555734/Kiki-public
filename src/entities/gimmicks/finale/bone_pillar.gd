extends FinaleMachine
## A fossil pillar that gives way: 0.35s after the runner lands on it, it
## shudders and drops into the canyon. state 1 = loaded at placed_tick.

const HOLD := 0.35
var _top: AnimatableBody2D
var _width := 120.0
var _height := 1400.0

func _build() -> void:
	z_index = 3
	reach = Vector2(1400, 1500)
	_width = float(data.get("width", 120.0))
	# The whole column is solid down to the canyon floor.
	_height = maxf(60.0, 1750.0 - global_position.y)
	_top = make_body(Vector2(_width, _height))
	_top.position = Vector2(_width * 0.5, _height * 0.5)

func drop(tick: int = Clock.tick) -> float:
	if state == 0:
		return 0.0
	var t := since(tick) - HOLD
	return 0.0 if t <= 0.0 else 0.5 * 1800.0 * t * t

func _pose(tick: int) -> void:
	var d := drop(tick)
	_top.position = Vector2(_width * 0.5, _height * 0.5 + d)
	set_solid(_top, d < 60.0)

func _on_state() -> void:
	sound("crumble", -6.0, 1.0)

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
	# A colossal fossil leg bone standing in the canyon: the walk line is
	# the top of its joint head.
	var h := 1750.0 - global_position.y
	var x := _width * 0.5 + shake
	FinaleGround.bone_on(self, [Vector2(x, d + _width * 0.5), Vector2(x, d + h)], _width * 0.78, int(global_position.x))
	# The flat of the joint, where the runner lands.
	draw_line(Vector2(shake + 6, d + 3), Vector2(shake + _width - 6, d + 3), Color("fff7e4"), 5.0)
	if state == 1:
		draw_line(Vector2(x - 10, d + 10), Vector2(x + 18, d + 60), FinaleGround.BONE_RIM, 4.0)
		draw_line(Vector2(x + 18, d + 60), Vector2(x - 4, d + 110), FinaleGround.BONE_RIM, 4.0)
