class_name TrickPad
extends Node2D
## A sideways bounce. Some pads reverse their arrow on the shared stage clock.

@export var start_direction := 1
@export var flip_every := 0.0
@export var phase_offset := 0.0
@export var forward_speed := 460.0
@export var rise_speed := 830.0

const WIDTH := 76.0
const REARM := 0.75
const WARN := 0.65

var runner: Runner
var _cooldown := 0.0
var _flash := 0.0

## Builds this piece from a stage's gimmick spec ("trick_pad"). The spec is
## parsed here, next to the fields it fills, so a default lives in one place.
static func from_spec(spec: Dictionary, runner: Runner) -> Node2D:
	var pad := TrickPad.new()
	pad.runner = runner
	pad.start_direction = int(spec.get("dir", 1))
	pad.flip_every = float(spec.get("flip", 0.0))
	pad.phase_offset = float(spec.get("phase", 0.0))
	pad.forward_speed = float(spec.get("forward", 460.0))
	pad.rise_speed = float(spec.get("rise", 830.0))
	return pad

func _ready() -> void:
	Art.bind_style(self)
	z_index = 4
	process_priority = 10

func direction_at(at_tick: int) -> int:
	if flip_every <= 0.0:
		return start_direction
	var n := int(floor(Clock.seconds_at(at_tick, phase_offset) / flip_every))
	return start_direction if n % 2 == 0 else -start_direction

func warning_at(at_tick: int) -> bool:
	if flip_every <= 0.0:
		return false
	return fposmod(Clock.seconds_at(at_tick, phase_offset), flip_every) > flip_every - WARN

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	var was_flashing := _flash > 0.0
	_flash = maxf(0.0, _flash - delta * 3.0)
	if flip_every > 0.0 or was_flashing:
		var camera := get_viewport().get_camera_2d()
		if camera == null or absf(global_position.x - camera.global_position.x) < 1100.0:
			queue_redraw()
	if runner == null or not is_instance_valid(runner):
		return
	if absf(runner.global_position.x - global_position.x) > (WIDTH + Balance.RUNNER_SIZE.x) * 0.5:
		return
	var feet := runner.global_position.y + Balance.RUNNER_SIZE.y * 0.5
	if feet < global_position.y - 48.0 or feet > global_position.y + 12.0:
		return
	if not Clock.is_host or _cooldown > 0.0 or runner.velocity.y < -80.0:
		return
	runner.launch(Vector2(float(direction_at(Clock.tick)) * forward_speed, -rise_speed))
	_cooldown = REARM
	_flash = 1.0
	queue_redraw()

func _draw() -> void:
	var cave := (Art.style(self) == "cave")
	var base := Color("59666d") if cave else Color("a16d4e")
	var rim := Color("b1c6bf") if cave else Color("f3cd89")
	if warning_at(Clock.tick):
		rim = Color("d7b583")
	var d := float(direction_at(Clock.tick))
	var rise := _flash * 8.0
	draw_rect(Rect2(-WIDTH * 0.5, -20.0 - rise, WIDTH, 20.0), base)
	draw_rect(Rect2(-WIDTH * 0.5, -22.0 - rise, WIDTH, 6.0), rim)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16.0 * d, -13.0 - rise), Vector2(7.0 * d, -13.0 - rise),
		Vector2(7.0 * d, -19.0 - rise), Vector2(23.0 * d, -10.0 - rise),
		Vector2(7.0 * d, -1.0 - rise), Vector2(7.0 * d, -7.0 - rise),
		Vector2(-16.0 * d, -7.0 - rise)]), rim)
	for x in [-27.0, 27.0]:
		draw_circle(Vector2(x, -3.0), 3.0, Color("393f44") if cave else Color("6b463d"))
