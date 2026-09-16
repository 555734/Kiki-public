class_name Snapshot
extends RefCounted
## The only thing sent continuously: the host's 30Hz picture of the world.
##
## Everything else is either an event (rare, reliable) or derivable from the
## tick (free). See the three-way split in docs/netcode.md section 4. This class
## exists so the byte budget in that document is measured by a test rather than
## added up by hand.
##
## Quantisation is split by axis, because the two axes do not need the same
## thing. Sixteen bits cannot span an 18,300px stage at 1/8px, so:
##
##   x  1/2 px over [-2048, 30719]  -- 0.25px of error, invisible after
##                                     interpolation against ~6px of travel per tick
##   y  1/8 px over [-1024,  7167]  -- 0.06px of error, and y is the axis that
##                                     decides whether a landing looks right
##
## Precision goes where the platform rescue needs it, and the packet is the same
## size either way.

const X_SCALE: float = 2.0
const X_ORIGIN: float = -2048.0
const Y_SCALE: float = 8.0
const Y_ORIGIN: float = -1024.0
## Velocity in 1/8 px/s over +/-4095 px/s. Terminal velocity is 1100, so there
## is headroom and the resolution is far below anything visible.
const VEL_SCALE: float = 8.0

var tick: int = 0
var runner_position: Vector2 = Vector2.ZERO
var runner_velocity: Vector2 = Vector2.ZERO
var runner_state: int = 0
var movement_flags: int = 0
var facing: int = 1
var on_floor: bool = false
var invulnerable: bool = false
var hp: int = 0
var gauge: float = 0.0
## Only enemies that have left their deterministic patrol. Normally empty, which
## is the point: an untouched walker is a pure function of the tick.
var dirty_enemies: Array[Dictionary] = []

func encode() -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	b.put_u16(tick & 0xFFFF)
	b.put_u16(_q_x(runner_position.x))
	b.put_u16(_q_y(runner_position.y))
	b.put_16(_q_vel(runner_velocity.x))
	b.put_16(_q_vel(runner_velocity.y))
	# state(3) facing(1) on_floor(1) invuln(1) hp(2) packed into one byte.
	var flags := (runner_state & 0x07) \
		| ((1 if facing > 0 else 0) << 3) \
		| ((1 if on_floor else 0) << 4) \
		| ((1 if invulnerable else 0) << 5) \
		| ((clampi(hp, 0, 3) & 0x03) << 6)
	b.put_u8(flags)
	b.put_u8(movement_flags & 0x0F)
	b.put_u8(clampi(int(round(gauge)), 0, 255))
	b.put_u8(dirty_enemies.size())
	for e in dirty_enemies:
		b.put_u8(int(e["id"]))
		b.put_u16(_q_x(float(e["x"])))
		b.put_u16(_q_y(float(e["y"])))
		b.put_u8(int(e.get("hp", 1)))
	return b.data_array

static func decode(bytes: PackedByteArray) -> Snapshot:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	b.data_array = bytes
	var s := Snapshot.new()
	s.tick = b.get_u16()
	s.runner_position = Vector2(_u_x(b.get_u16()), _u_y(b.get_u16()))
	s.runner_velocity = Vector2(_u_vel(b.get_16()), _u_vel(b.get_16()))
	var flags := b.get_u8()
	s.runner_state = flags & 0x07
	s.facing = 1 if (flags >> 3) & 1 else -1
	s.on_floor = ((flags >> 4) & 1) == 1
	s.invulnerable = ((flags >> 5) & 1) == 1
	s.hp = (flags >> 6) & 0x03
	s.movement_flags = b.get_u8() & 0x0F
	s.gauge = float(b.get_u8())
	var count := b.get_u8()
	for i in range(count):
		s.dirty_enemies.append({
			"id": b.get_u8(),
			"x": _u_x(b.get_u16()),
			"y": _u_y(b.get_u16()),
			"hp": b.get_u8(),
		})
	return s

## Bytes for a snapshot with no divergent enemies -- the steady state, and the
## number the bandwidth budget is written against.
static func quiet_size() -> int:
	return Snapshot.new().encode().size()

## Clamped, never wrapped. A wrap would put an entity on the far side of the
## stage, which is exactly the kind of bug that looks like a teleport hack.
static func _q_x(v: float) -> int:
	return clampi(int(round((v - X_ORIGIN) * X_SCALE)), 0, 65535)

static func _u_x(q: int) -> float:
	return float(q) / X_SCALE + X_ORIGIN

static func _q_y(v: float) -> int:
	return clampi(int(round((v - Y_ORIGIN) * Y_SCALE)), 0, 65535)

static func _u_y(q: int) -> float:
	return float(q) / Y_SCALE + Y_ORIGIN

static func _q_vel(v: float) -> int:
	return clampi(int(round(v * VEL_SCALE)), -32768, 32767)

static func _u_vel(q: int) -> float:
	return float(q) / VEL_SCALE

