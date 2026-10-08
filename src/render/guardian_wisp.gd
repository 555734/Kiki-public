extends Node2D
## The guardian, on the screen: a small light that goes where they point.
##
## The guardian has no body in this game. On a shared screen that is fine for
## the person holding the device, but for the runner -- and for anyone
## watching -- platforms and shots simply appeared out of nowhere, and half of
## the pair was invisible. This gives them a presence in the world: it hovers
## over the aim, rides the tip of a stroke being drawn, and darts to wherever a
## tool was just used.
##
## Drawn only, and only where the reticle would be (InputHub.shows_guardian_cursor),
## so it follows exactly the same rules as the rest of the guardian's cursor --
## including staying away on a runner's device until the guardian's aim has
## actually arrived. It also stays asleep until the guardian first does
## something, so a stage that is only being looked at is unchanged.

var guardian: Guardian = null

const HOVER := Vector2(0.0, -22.0)
const TRAIL := 12

var _pos := Vector2.ZERO
var _trail: Array[Vector2] = []
var _alpha := 0.0
var _awake := false
var _t := 0.0
var _last_aim := Vector2(INF, INF)
var _dash_left := 0.0
var _dash_to := Vector2.ZERO

func _ready() -> void:
	z_index = 30
	Events.ability_used.connect(_on_ability_used)

func _on_ability_used(_slot: int, at: Vector2) -> void:
	_awake = true
	_dash_to = at
	_dash_left = 0.2

func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(guardian) or guardian.input_hub == null:
		return
	var hub: InputHub = guardian.input_hub
	var aim := hub.aim_world()
	# Awake once the guardian has done anything: used a tool, put a finger on
	# the world, or moved the aim. The aim parked on the runner at the start
	# does not count.
	if hub.aiming() or not hub.trace_points.is_empty():
		_awake = true
	if _last_aim.x != INF and aim.distance_to(_last_aim) > 1.0 and _t > 0.5:
		_awake = true
	_last_aim = aim
	var shown := _awake and hub.shows_guardian_cursor()
	_alpha = move_toward(_alpha, 1.0 if shown else 0.0, delta * 5.0)

	var target := aim + HOVER + Vector2(0.0, sin(_t * 3.2) * 4.0)
	if not hub.trace_points.is_empty():
		# Riding the tip of the stroke: this is the hand drawing it.
		target = hub.trace_points[hub.trace_points.size() - 1]
	var rate := 10.0
	if _dash_left > 0.0:
		_dash_left -= delta
		target = _dash_to + HOVER * 0.5
		rate = 24.0
	if _alpha <= 0.0:
		_pos = target
	else:
		_pos = _pos.lerp(target, clampf(delta * rate, 0.0, 1.0))
	_trail.push_front(_pos)
	if _trail.size() > TRAIL:
		_trail.pop_back()
	queue_redraw()

func _draw() -> void:
	if _alpha <= 0.01:
		return
	var c := Balance.C_HOLO
	for i in range(_trail.size() - 1, 0, -1):
		var k := 1.0 - float(i) / float(TRAIL)
		draw_circle(to_local(_trail[i]), 7.0 * k, Color(c, 0.22 * k * _alpha))
	var at := to_local(_pos)
	draw_circle(at, 20.0, Color(c, 0.14 * _alpha))
	draw_circle(at, 12.0, Color(c, 0.35 * _alpha))
	draw_circle(at, 6.5, Color(1.0, 1.0, 1.0, 0.95 * _alpha))
	# Four short rays turning slowly: a light, not a ball.
	for i in 4:
		var dir := Vector2.from_angle(_t * 1.6 + TAU * i / 4.0)
		draw_line(at + dir * 9.0, at + dir * 17.0, Color(1.0, 1.0, 1.0, 0.6 * _alpha), 2.0, true)
