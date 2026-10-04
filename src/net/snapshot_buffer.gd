class_name SnapshotBuffer
extends RefCounted
## The host's snapshots as they arrive on a guest, and the point between two
## of them that the guest is drawing.
##
## The render point sits a few ticks behind the newest snapshot so the buffer
## never runs dry mid-jump. It is widened when arrivals get jittery and pulled
## back in when they settle: every extra tick is latency the guardian has to
## lead by.

## How far behind the newest snapshot to render, in ticks.
const INTERP_MIN: int = 3
const INTERP_MAX: int = 8
const BUFFER_MAX: int = 20

var snapshots: Array[Snapshot] = []
var interp_ticks: int = INTERP_MIN

func absorb(s: Snapshot) -> void:
	snapshots.append(s)
	snapshots.sort_custom(func(x, y): return x.tick < y.tick)
	while snapshots.size() > BUFFER_MAX:
		snapshots.pop_front()
	var newest := snapshots[snapshots.size() - 1].tick
	var behind := Clock.tick - newest
	if behind > interp_ticks:
		interp_ticks = mini(INTERP_MAX, interp_ticks + 1)
	elif behind < interp_ticks - 2:
		interp_ticks = maxi(INTERP_MIN, interp_ticks - 1)

## Snapshots from before a gap: interpolating out of them would drag the
## runner backwards across the stage before catching up.
func clear() -> void:
	snapshots.clear()

## The tick being drawn now.
func view_tick() -> int:
	return maxi(0, Clock.tick - interp_ticks)

## The two snapshots either side of the render point and how far between them
## it is: [a, b, t, span_ticks], or [] with fewer than two snapshots.
func bracket() -> Array:
	if snapshots.size() < 2:
		return []
	var target := float(view_tick())
	var a: Snapshot = snapshots[0]
	var b: Snapshot = snapshots[snapshots.size() - 1]
	for i in range(snapshots.size() - 1):
		if float(snapshots[i].tick) <= target and float(snapshots[i + 1].tick) >= target:
			a = snapshots[i]
			b = snapshots[i + 1]
			break
	var span := float(b.tick - a.tick)
	var t := 0.0 if span <= 0.0 else clampf((target - float(a.tick)) / span, 0.0, 1.0)
	return [a, b, t, span]

## Cubic through both endpoints using the velocities as tangents. Linear
## interpolation turns a jump into a folded line and flattens the apex -- the
## one part of the arc the guardian is aiming at.
static func hermite(p0: Vector2, v0: Vector2, p1: Vector2, v1: Vector2,
		t: float, dt: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * p0 \
		+ (t3 - 2.0 * t2 + t) * v0 * dt \
		+ (-2.0 * t3 + 3.0 * t2) * p1 \
		+ (t3 - t2) * v1 * dt
