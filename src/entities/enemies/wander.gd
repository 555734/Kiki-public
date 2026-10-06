class_name Wander
extends RefCounted
## An irregular flight that is still the same on every device.
##
## The enemy darts between points picked by hash inside a box around its home,
## one dart every `dart` seconds: some darts are quick and leave it hanging
## still, some drift the whole way, and where it goes next cannot be read off
## where it went last. It is a pure function of the stage clock and a seed, so
## the guest's copy agrees with the host's without a byte on the wire, the way
## every clock-driven piece in the stage does.

## Offset from home at `seconds`.
static func offset(seconds: float, seed: int, box: Vector2, dart: float) -> Vector2:
	if box == Vector2.ZERO or dart <= 0.0:
		return Vector2.ZERO
	var hop := int(floorf(maxf(seconds, 0.0) / dart))
	var into := (maxf(seconds, 0.0) - float(hop) * dart) / dart
	# How much of this dart is spent moving: the rest is a pause, and the
	# pause is what reads as the thing deciding where to go next.
	var moving := 0.35 + 0.55 * _h(seed * 31 + hop * 977 + 5)
	var u := clampf(into / moving, 0.0, 1.0)
	var s := u * u * (3.0 - 2.0 * u)
	return point(seed, hop, box).lerp(point(seed, hop + 1, box), s)

## The k-th point it darts to, inside +/- box.
static func point(seed: int, k: int, box: Vector2) -> Vector2:
	return Vector2(_h(seed * 7919 + k * 131 + 3) * 2.0 - 1.0,
		_h(seed * 104729 + k * 313 + 17) * 2.0 - 1.0) * box

## A stable seed from where something was placed.
static func seed_of(at: Vector2) -> int:
	return posmod(int(roundf(at.x)) * 7919 + int(roundf(at.y)) * 104729, 65521)

## 0..1 from an int. Every step stays inside 32 bits, so an hour of darting
## (a large `k`) never overflows into something platform-dependent.
static func _h(n: int) -> float:
	var x := n & 0xffffffff
	x = (((x >> 16) ^ x) * 0x45d9f3b) & 0xffffffff
	x = (((x >> 16) ^ x) * 0x45d9f3b) & 0xffffffff
	x = (x >> 16) ^ x
	return float(x & 0x7fffffff) / 2147483647.0
