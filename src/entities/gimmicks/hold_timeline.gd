class_name HoldTimeline
extends RefCounted
## When the guardian's hand held something still, as shared-clock intervals.
##
## The boulders and gates the hand can hold are pure functions of Clock.tick on
## both devices -- nothing about where they are is ever sent. Holding one still
## must not break that, so the hold is not a pause applied locally: it is a list
## of [start_tick, end_tick] intervals the HOST decides and sends, and the
## thing's position becomes a pure function of the tick AND the list. Both
## devices then agree at every tick, including past ones (lag compensation asks
## about those), and a late packet only moves the answer for ticks the device
## has not shown yet.

## [[start, end], ...] in order; end is -1 while still held.
var intervals: Array = []
## A hold ends by itself after this many ticks.
var max_ticks: int = 150

func _init(max_seconds: float = 2.5) -> void:
	max_ticks = maxi(1, int(round(max_seconds * Clock.HZ)))

## The guardian took hold at `tick`. Ignored while already held.
func begin(tick: int) -> void:
	if held_at(tick):
		return
	intervals.append([tick, -1])

## The guardian let go at `tick`.
func end(tick: int) -> void:
	if intervals.is_empty():
		return
	var last: Array = intervals[intervals.size() - 1]
	if int(last[1]) < 0:
		last[1] = maxi(int(last[0]), mini(tick, int(last[0]) + max_ticks))

## Whether the hand is holding it at `tick`.
func held_at(tick: int) -> bool:
	for iv in intervals:
		if tick >= int(iv[0]) and tick < _end_of(iv):
			return true
	return false

## Whether a hold is open: begun and not yet let go of (nor timed out by now).
func open_at(tick: int) -> bool:
	if intervals.is_empty():
		return false
	var last: Array = intervals[intervals.size() - 1]
	return int(last[1]) < 0 and tick < _end_of(last)

## Ticks spent held before `tick`: how far behind the shared clock it now runs.
func held_before(tick: int) -> int:
	var total := 0
	for iv in intervals:
		var s: int = iv[0]
		if tick <= s:
			break
		total += mini(tick, _end_of(iv)) - s
	return total

## The shared clock as the held thing sees it.
func local_tick(tick: int) -> int:
	return tick - held_before(tick)

## 0..1 for a thing that rises while held and falls when let go: how far up
## it is at `tick`, rising over `rise_ticks` and falling over `drop_ticks`.
func lift_at(tick: int, rise_ticks: int, drop_ticks: int) -> float:
	var rise := 1.0 / float(maxi(1, rise_ticks))
	var drop := 1.0 / float(maxi(1, drop_ticks))
	var value := 0.0
	var at := -1
	for iv in intervals:
		var s: int = iv[0]
		if tick <= s:
			break
		if at >= 0:
			value = maxf(0.0, value - float(s - at) * drop)
		var until := mini(_end_of(iv), tick)
		value = minf(1.0, value + float(until - s) * rise)
		at = until
	if at >= 0 and tick > at:
		value = maxf(0.0, value - float(tick - at) * drop)
	return value

func _end_of(iv: Array) -> int:
	var s: int = iv[0]
	var e: int = iv[1]
	return s + max_ticks if e < 0 else mini(e, s + max_ticks)
