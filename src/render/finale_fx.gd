class_name FinaleFx
extends Node
## Screen-level feedback for 1-10's machines: a camera shake that decays and
## the storm's lightning flash (read by the backdrop). Machines call the
## static kick()/flash(); main adds one of these nodes on this stage only.

static var _shake := 0.0
static var _flash := 0.0

static func kick(amount: float) -> void:
	_shake = maxf(_shake, amount)

static func flash(amount: float = 1.0) -> void:
	_flash = maxf(_flash, amount)

static func flash_level() -> float:
	return _flash

static func reset() -> void:
	_shake = 0.0
	_flash = 0.0

func _ready() -> void:
	# After main's camera update (priority 100) so the offset survives.
	process_priority = 210
	reset()

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		if _shake > 0.05:
			var f := float(Engine.get_process_frames())
			camera.offset = Vector2(sin(f * 1.9), cos(f * 2.3)) * _shake
		elif camera.offset != Vector2.ZERO and _shake <= 0.05 and _shake > 0.0:
			camera.offset = Vector2.ZERO
	_shake = maxf(0.0, _shake - delta * 30.0)
	_flash = maxf(0.0, _flash - delta * 2.6)
