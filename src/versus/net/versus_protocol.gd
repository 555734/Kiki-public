class_name VersusProtocol
## What four peers say to each other.
##
## A NEW format, not a widened Snapshot. The cooperative one cannot carry this:
## its flags byte is full (three bits of state, two of HP -- src/net/snapshot.gd
## :52-56) and, more fundamentally, NO message in the co-op protocol carries an
## actor id, because there has only ever been one runner. Adding one would mean
## touching every encoder and every decode branch and bumping a VERSION that a
## working game depends on.
##
## Encoded by hand into a StreamPeerBuffer, little-endian, like the co-op
## protocol -- the house style, and it keeps the packets small enough that the
## relay's 1170-byte cap is never in question. Every message begins with a kind
## byte, and every message about a person carries their SEAT.
##
## Budget, against the 1170-byte cap: a snapshot is 12 bytes of header, 14 per
## runner and 6 per coin, so a full 18-coin match is 12 + 28 + 108 = 148 bytes.
## The plan allowed 768 (docs/coin-battle-plan.md:315).

enum Msg {
	HELLO = 1,       ## client -> host: I am here, I would like a seat
	WELCOME = 2,     ## host -> client: you are seat N, the match seed is S
	FULL = 3,        ## host -> client: there is no chair for you
	INPUT = 10,      ## runner -> host: this is where I am and what I pressed
	COMMAND = 11,    ## guardian -> host: build this here
	SNAPSHOT = 20,   ## host -> everyone: the world
	EVENT = 21,      ## host -> everyone: something worth a noise happened
	BYE = 30,
}

## Bumped whenever the layout below changes. Checked at HELLO, so two different
## builds refuse each other by name instead of desynchronising silently.
const VERSION: int = 4 # Shorter versus circuit; reject peers using the old map.

## Velocity is stored in eighths of a pixel per second, as the co-op snapshot
## does. A runner tops out around 1000px/s, so 8000 fits an i16 with room.
const VEL_SCALE: float = 8.0

# ------------------------------------------------------------------- helpers
static func _buf(kind: int) -> StreamPeerBuffer:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	b.put_u8(kind)
	return b

static func reader(payload: PackedByteArray) -> StreamPeerBuffer:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	b.data_array = payload
	return b

static func kind_of(payload: PackedByteArray) -> int:
	return payload[0] if payload.size() > 0 else 0

## Positions are whole pixels. 1-1 runs to x=16700 and y=1020, both inside an
## i16, so there is no fixed-point scheme to get wrong here -- and a pixel is
## already finer than anything the eye can see at this zoom.
static func _put_pos(b: StreamPeerBuffer, at: Vector2) -> void:
	b.put_16(clampi(int(round(at.x)), -32768, 32767))
	b.put_16(clampi(int(round(at.y)), -32768, 32767))

static func _get_pos(b: StreamPeerBuffer) -> Vector2:
	return Vector2(float(b.get_16()), float(b.get_16()))

static func _put_vel(b: StreamPeerBuffer, v: Vector2) -> void:
	b.put_16(clampi(int(round(v.x * VEL_SCALE)), -32768, 32767))
	b.put_16(clampi(int(round(v.y * VEL_SCALE)), -32768, 32767))

static func _get_vel(b: StreamPeerBuffer) -> Vector2:
	return Vector2(float(b.get_16()) / VEL_SCALE, float(b.get_16()) / VEL_SCALE)

# ----------------------------------------------------------------- handshake
static func hello(wanted_seat: int,
		room_mode: int = VersusRoster.RoomMode.TEAM_SPLIT) -> PackedByteArray:
	var b := _buf(Msg.HELLO)
	b.put_u16(VERSION)
	b.put_8(wanted_seat)
	b.put_u8(room_mode)
	return b.data_array

static func read_hello(payload: PackedByteArray) -> Dictionary:
	var b := reader(payload)
	b.get_u8()
	return {"version": b.get_u16(), "wanted_seat": b.get_8(),
		"room_mode": b.get_u8()}

static func welcome(seat: int, match_seed: int,
		room_mode: int = VersusRoster.RoomMode.TEAM_SPLIT) -> PackedByteArray:
	var b := _buf(Msg.WELCOME)
	b.put_u8(seat)
	b.put_u32(match_seed)
	b.put_u8(room_mode)
	return b.data_array

static func read_welcome(payload: PackedByteArray) -> Dictionary:
	var b := reader(payload)
	b.get_u8()
	return {"seat": b.get_u8(), "seed": b.get_u32(),
		"room_mode": b.get_u8()}

static func full(reason: String = "") -> PackedByteArray:
	var out := _buf(Msg.FULL).data_array
	out.append_array(reason.to_utf8_buffer())
	return out

static func read_full_reason(payload: PackedByteArray) -> String:
	return payload.slice(1).get_string_from_utf8() if payload.size() > 1 else ""

static func bye(seat: int) -> PackedByteArray:
	var b := _buf(Msg.BYE)
	b.put_u8(seat)
	return b.data_array

# --------------------------------------------------------------------- input
## A runner telling the host where it is.
##
## Position, not buttons. Each runner simulates ITSELF -- that is the whole
## reason your own controls never feel laggy in this mode -- so what the host
## needs is the result, and what the host arbitrates is the contest: who
## touched which coin, whose strike landed, what the score is. The plan's
## alternative, sending buttons and re-simulating on the host, puts a round trip
## between pressing right and moving right.
static func input(seat: int, tick: int, at: Vector2, vel: Vector2, facing: int,
		alive: bool, can_act: bool, invulnerable: bool, on_floor: bool,
		hp: int, strike_seq: int) -> PackedByteArray:
	var b := _buf(Msg.INPUT)
	b.put_u8(seat)
	b.put_u32(tick)
	_put_pos(b, at)
	_put_vel(b, vel)
	b.put_u8(_flags(facing, alive, can_act, invulnerable, on_floor))
	b.put_u8(clampi(hp, 0, 255))
	b.put_u16(strike_seq & 0xFFFF)
	return b.data_array

static func read_input(payload: PackedByteArray) -> Dictionary:
	var b := reader(payload)
	b.get_u8()
	var out := {"seat": b.get_u8(), "tick": b.get_u32()}
	out["position"] = _get_pos(b)
	out["velocity"] = _get_vel(b)
	_read_flags(b.get_u8(), out)
	out["hp"] = b.get_u8()
	out["strike_seq"] = b.get_u16()
	return out

## Five independent yes/no answers about a runner, in one byte. There is room
## for three more, which is the difference between this and the co-op's flags
## byte -- that one is full, and a sixth question there costs a wire break.
static func _flags(facing: int, alive: bool, can_act: bool,
		invulnerable: bool, on_floor: bool) -> int:
	return (1 if facing > 0 else 0) \
		| ((1 if alive else 0) << 1) \
		| ((1 if can_act else 0) << 2) \
		| ((1 if invulnerable else 0) << 3) \
		| ((1 if on_floor else 0) << 4)

static func _read_flags(f: int, into: Dictionary) -> void:
	into["facing"] = 1 if (f & 1) != 0 else -1
	into["alive"] = (f & 2) != 0
	into["can_act"] = (f & 4) != 0
	into["invulnerable"] = (f & 8) != 0
	into["on_floor"] = (f & 16) != 0

# ------------------------------------------------------------------- command
## A guardian asking for something to be built. The host decides whether it
## happens; the guardian's own screen may show it early and be corrected, which
## is exactly what the cooperative client already does with its ghost.
static func command(seat: int, tick: int, slot: int, at: Vector2) -> PackedByteArray:
	var b := _buf(Msg.COMMAND)
	b.put_u8(seat)
	b.put_u32(tick)
	b.put_u8(slot)
	_put_pos(b, at)
	return b.data_array

static func read_command(payload: PackedByteArray) -> Dictionary:
	var b := reader(payload)
	b.get_u8()
	var out := {"seat": b.get_u8(), "tick": b.get_u32(), "slot": b.get_u8()}
	out["at"] = _get_pos(b)
	return out

# ------------------------------------------------------------------ snapshot
## The world, as the host sees it. Sent unreliably and often.
static func snapshot(tick: int, phase: int, winner: int, runners: Array,
		coins: Array, builds: Array, world_revision: int = 0) -> PackedByteArray:
	var b := _buf(Msg.SNAPSHOT)
	b.put_u32(tick)
	b.put_u8(phase)
	b.put_8(winner)
	b.put_u32(world_revision)

	b.put_u8(runners.size())
	for r in runners:
		_put_pos(b, r["position"])
		_put_vel(b, r["velocity"])
		b.put_u8(_flags(int(r["facing"]), bool(r["alive"]), bool(r["can_act"]),
			bool(r["invulnerable"]), bool(r.get("on_floor", false))))
		b.put_u8(clampi(int(r["hp"]), 0, 255))
		b.put_u8(int(r["combat_phase"]))
		b.put_u8(clampi(int(r["combat_dir"]) + 1, 0, 2))

	b.put_u8(coins.size())
	for c in coins:
		b.put_u8(int(c["id"]))
		# state in the low two bits, owner+1 in the next three. A coin is in
		# exactly one state and has at most one owner, so they share a byte.
		b.put_u8((int(c["state"]) & 0x03) | ((int(c["owner"]) + 1) << 2))
		_put_pos(b, c["position"])

	b.put_u8(builds.size())
	for g in builds:
		b.put_u32(int(g.get("build_id", 0)))
		b.put_u8(int(g["seat"]))
		_put_pos(b, g["position"])
		_put_pos(b, g["size"])
	return b.data_array

static func read_snapshot(payload: PackedByteArray) -> Dictionary:
	var b := reader(payload)
	b.get_u8()
	var out := {"tick": b.get_u32(), "phase": b.get_u8(), "winner": b.get_8(),
		"world_revision": b.get_u32()}

	var runners: Array = []
	var n := b.get_u8()
	for i in range(n):
		var r := {"position": _get_pos(b), "velocity": _get_vel(b)}
		_read_flags(b.get_u8(), r)
		r["hp"] = b.get_u8()
		r["combat_phase"] = b.get_u8()
		r["combat_dir"] = b.get_u8() - 1
		runners.append(r)
	out["runners"] = runners

	var coins: Array = []
	var m := b.get_u8()
	for i in range(m):
		var id := b.get_u8()
		var packed := b.get_u8()
		coins.append({
			"id": id,
			"state": packed & 0x03,
			"owner": (packed >> 2) - 1,
			"position": _get_pos(b),
		})
	out["coins"] = coins

	var builds: Array = []
	var k := b.get_u8()
	for i in range(k):
		var build_id := b.get_u32()
		var seat := b.get_u8()
		var at := _get_pos(b)
		var size := _get_pos(b)
		builds.append({"build_id": build_id, "seat": seat,
			"position": at, "size": size})
	out["builds"] = builds
	return out
