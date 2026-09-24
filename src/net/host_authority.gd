class_name HostAuthority
extends Node
## The host half of the netcode: records the runner every tick and decides what
## to do with construct requests that arrive late.
##
## Offline play is a host with no client, so this runs in single player too and
## the rewind path is exercised by ordinary testing rather than only by network
## tests. See docs/netcode.md sections 3 and 8.

var runner: Node2D = null
var guardian: Node = null
var rewind := Rewind.new()

## Measured by the ping exchange on the control channel. Offline this stays 0,
## which makes allowed_rewind() return 0 and the whole path a no-op.
var measured_one_way: float = 0.0
var client_interp_buffer: float = 0.0

## Counters the tests assert on, and a useful thing to show in a debug overlay.
var rescues_backdated: int = 0
var rescues_declined: int = 0

func _physics_process(_delta: float) -> void:
	if runner == null or not is_instance_valid(runner):
		return
	var hub = runner.input_hub
	rewind.record(Clock.tick, runner,
		hub.move_axis if hub != null else 0.0,
		hub.jump_held if hub != null else false)

## A construct request from the guardian, possibly describing a world the host
## has already moved past.
##
## `view_tick` is the tick the guardian was rendering when they tapped. Returns
## the tick the construct should be stamped with, having already applied any
## rescue that the backdating justifies.
func accept_placement(world_pos: Vector2, size: Vector2, view_tick: int,
		can_catch: bool = true) -> int:
	var now := Clock.tick
	var back := rewind.allowed_rewind(now, view_tick, measured_one_way, client_interp_buffer)
	if back <= 0:
		return now

	var birth := now - back
	if not can_catch:
		return birth
	var rect := Rect2(world_pos - size * 0.5, size)
	if not rewind.path_crosses(birth, rect):
		# The runner was never near it. Nothing to compensate for; this is the
		# common case, and it costs one cheap sweep of at most 15 points.
		return birth

	if _try_capture(birth, world_pos, size):
		rescues_backdated += 1
	else:
		rescues_declined += 1
	return birth

## Puts the runner on top of the construct if their recorded path fell through
## where its surface now is -- and only if that leaves them better off.
func _try_capture(birth_tick: int, world_pos: Vector2, size: Vector2) -> bool:
	var top := world_pos.y - size.y * 0.5 - Balance.RUNNER_SIZE.y * 0.5
	var half := size.x * 0.5
	var landing := rewind.sweep_capture(birth_tick, top,
		world_pos.x - half - Balance.RUNNER_SIZE.x * 0.5,
		world_pos.x + half + Balance.RUNNER_SIZE.x * 0.5)
	if landing == Vector2.INF:
		return false

	var live: Vector2 = runner.global_position
	var alive: bool = runner.state != 6   # Runner.State.DEAD
	if not Rewind.is_improvement(alive, landing, live, false):
		# Replaying would not help -- they already landed somewhere, or they are
		# above it anyway. Leave the live state alone. The platform still
		# appears; it is just late.
		return false

	runner.global_position = landing
	runner.velocity.y = 0.0
	# A rewind rescue is a catch, not a synthetic apex. End only player-jump
	# shaping; preserve horizontal speed, jump buffer and chain state.
	if runner.has_method("end_player_jump_control"):
		runner.end_player_jump_control()
	return true
