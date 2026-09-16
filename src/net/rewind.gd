class_name Rewind
extends RefCounted
## Lag compensation for the guardian's constructs -- the one place where network
## delay can destroy the core experience, so it gets its own object and its own
## tests.
##
## The problem (docs/netcode.md section 8). The runner's device is the host, so
## the runner never sees "I landed but the host says I fell". What is left is
## the mirror image: the guardian is looking at a picture of the world that is
## 100-200ms old, drops a platform under the runner they can see, and by the
## time that request reaches the host the real runner has fallen past it.
##
## The fix is to let the host put the platform in the past. It keeps a short
## history of the runner, rebuilds the world as it would have been at the tick
## the guardian was actually looking at, and replays forward.
##
## The rule that makes this safe:
##
##     A rewind may only ever help the runner.
##
## If replaying with the platform present leaves the runner dead, lower, or in a
## hazard, the replay is thrown away and the platform simply spawns late. A
## guardian on a terrible connection can therefore never get the runner killed --
## and since the runner is the host, being yanked around by someone else's
## latency would be the worst possible feeling.

## 250ms. Past this a rescue is not late, it is a different decision.
const MAX_REWIND_TICKS: int = 15

## History depth. A little more than MAX_REWIND so a request that arrives on the
## boundary still finds its frame.
const HISTORY_TICKS: int = 24

## For its first 200ms a fresh platform's top surface is treated as reaching
## this much higher, so a runner passing just below is still caught. This is the
## cheapest of the three layers and the one players feel most.
const CAPTURE_MARGIN_PX: float = 24.0
const CAPTURE_WINDOW: float = 0.2

## One frame of the runner, enough to put it back exactly as it was.
class Frame extends RefCounted:
	var tick: int = 0
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var state: int = 0
	var on_floor: bool = false
	var hp: int = 0
	var move_axis: float = 0.0
	var jump_held: bool = false

var _frames: Array[Frame] = []

## Called once per physics tick on the host, before the runner moves.
func record(tick: int, runner: Node2D, move_axis: float, jump_held: bool) -> void:
	var f := Frame.new()
	f.tick = tick
	f.position = runner.global_position
	f.velocity = runner.velocity
	f.state = runner.state
	f.on_floor = runner.is_on_floor()
	f.hp = runner.hp
	f.move_axis = move_axis
	f.jump_held = jump_held
	_frames.append(f)
	while _frames.size() > HISTORY_TICKS:
		_frames.pop_front()

func clear() -> void:
	_frames.clear()

func frame_at(tick: int) -> Frame:
	for i in range(_frames.size() - 1, -1, -1):
		if _frames[i].tick <= tick:
			return _frames[i]
	return _frames[0] if not _frames.is_empty() else null

## How far back a request is allowed to reach. Two clamps, and the second is the
## anti-cheat one: a client cannot claim 250ms of rewind on a 20ms connection,
## because the host measures the round trip itself and will not accept a view
## tick older than that measurement can justify.
func allowed_rewind(now_tick: int, claimed_view_tick: int,
		measured_one_way: float, interp_buffer: float) -> int:
	var asked := now_tick - claimed_view_tick
	if asked <= 0:
		return 0
	var justified := Clock.ticks_for(measured_one_way + interp_buffer) + 2
	return clampi(asked, 0, mini(MAX_REWIND_TICKS, justified))

## The cheap filter. Did the runner's recent path go anywhere near where this
## construct is about to appear? Almost every placement answers no -- the
## guardian is usually building ahead of the runner, not under them -- and those
## skip the resimulation entirely.
func path_crosses(from_tick: int, rect: Rect2) -> bool:
	var grown := rect.grow(CAPTURE_MARGIN_PX)
	# Seeded with the frame at or before the window start, so the segment that
	# straddles the boundary is considered too. Without this a request whose
	# view tick lands between two recorded frames loses the very crossing it is
	# asking about.
	var seed_frame := frame_at(from_tick)
	var previous: Vector2 = seed_frame.position if seed_frame != null else Vector2.INF
	for f in _frames:
		if f.tick < from_tick:
			continue
		if grown.has_point(f.position):
			return true
		if previous != Vector2.INF and _segment_hits_rect(previous, f.position, grown):
			return true
		previous = f.position
	return false

## The cheap rescue. If the runner's recorded path came down through the
## construct's top surface during the rewind window, put them on it. This alone
## covers the headline case -- falling past a platform that appeared a moment
## too late -- without resimulating anything.
##
## The surface is treated as a band of +/-CAPTURE_MARGIN_PX rather than a line.
## That is the landing magnet from docs/netcode.md 8.4, and it is doing real
## work: at terminal velocity the runner covers 18px in a single tick, so a
## hairline test would miss rescues by less than one frame of fall. Being caught
## from up to 24px below is generous on purpose, and it is safe because
## is_improvement() still refuses anything that would not help.
##
## Returns the landing position, or Vector2.INF when the path never crossed.
func sweep_capture(from_tick: int, top_y: float, left: float, right: float) -> Vector2:
	var band_top := top_y - CAPTURE_MARGIN_PX
	var band_bottom := top_y + CAPTURE_MARGIN_PX
	var previous := frame_at(from_tick)
	for f in _frames:
		if f.tick < from_tick:
			continue
		if previous != null and f.velocity.y > 0.0 and f.position.y >= previous.position.y:
			# Does the descending segment touch the capture band at all?
			if previous.position.y <= band_bottom and f.position.y >= band_top:
				var span := f.position.y - previous.position.y
				var t := 0.0 if span <= 0.001 else (top_y - previous.position.y) / span
				var x := lerpf(previous.position.x, f.position.x, clampf(t, 0.0, 1.0))
				if x >= left and x <= right:
					return Vector2(x, top_y)
		previous = f
	return Vector2.INF

## Whether a replayed state is allowed to replace the live one.
##
## This is the asymmetry the whole design rests on. "No worse" is measured
## generously: alive, not below where they already are, and not inside a hazard.
static func is_improvement(alive: bool, replayed: Vector2, live: Vector2,
		in_hazard: bool) -> bool:
	if not alive or in_hazard:
		return false
	# Screen space: smaller y is higher up.
	return replayed.y <= live.y + 0.5

static func _segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	]
	for i in range(4):
		if _segments_cross(a, b, corners[i], corners[(i + 1) % 4]):
			return true
	return false

static func _segments_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var d1 := (b - a).cross(c - a)
	var d2 := (b - a).cross(d - a)
	var d3 := (d - c).cross(a - c)
	var d4 := (d - c).cross(b - c)
	return ((d1 > 0.0) != (d2 > 0.0)) and ((d3 > 0.0) != (d4 > 0.0))
