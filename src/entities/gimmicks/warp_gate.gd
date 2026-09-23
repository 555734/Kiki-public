class_name WarpGate
extends Node2D
## A painted stone portal that sends the runner to its partner.
##
## Only the host moves the runner, exactly like the guardian's hologram warp
## (Guardian._service_warp): the guest sees the jump in the next snapshot, and
## client_session already snaps rather than interpolates any runner move longer
## than TELEPORT_PX, so the exit must be further away than that.

@export var size: Vector2 = Vector2(90, 120)
## Where this mouth delivers the runner, in world space.
@export var exit: Vector2 = Vector2.ZERO
## A one-way gate still draws its exit mouth; only the entry is live.
@export var is_exit: bool = false

var runner: Node2D = null
var _cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if is_exit or not Clock.is_host or _cooldown > 0.0:
		return
	if runner == null or not is_instance_valid(runner):
		return
	if not Rect2(global_position - size * 0.5, size).has_point(runner.global_position):
		return
	var from := runner.global_position
	runner.global_position = exit
	_cooldown = Balance.WARP_COOLDOWN
	Events.runner_warped.emit(from, exit)

func _draw() -> void:
	if has_meta("model_3d"):
		return
	var c := Color("7fb8ff") if not is_exit else Color("ffd46b")
	draw_rect(Rect2(-size * 0.5, size), Color(c.r, c.g, c.b, 0.35))
	draw_rect(Rect2(-size * 0.5, size), c, false, 3.0)
