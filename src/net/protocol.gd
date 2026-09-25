class_name Protocol
extends RefCounted
## Wire format for everything that is not a snapshot.
##
## Snapshots are continuous and live in snapshot.gd. These are the discrete
## events -- placements, shots, deaths, gates -- that go on the reliable
## channels. See the three-way split in docs/netcode.md section 4.

enum Msg {
	HELLO = 1,        ## client -> host, once: protocol version
	WELCOME = 2,      ## host -> client: accepted, here is the tick
	PING = 3,
	PONG = 4,
	AIM = 10,         ## client -> host, 30Hz, unreliable
	PLACE = 11,       ## client -> host: put a construct here, at my view tick
	FIRE = 12,        ## client -> host: shoot here, at my view tick
	SLOT = 13,        ## client -> host: selected ability (display only)
	UNDO = 15,        ## client -> host: take back the construct I just placed
	## Pointing at a place on the map. Named MARK rather than PING because PING
	## is already the latency probe above, and two different things under one
	## name in the same enum is how this file failed to parse.
	MARK = 16,
	HOLO_SPAWN = 20,  ## host -> client: a construct exists, with its lifetime
	HOLO_KILL = 21,
	REJECT = 22,      ## host -> client: your command did not happen
	ENEMY_DIE = 23,
	RUNNER_HURT = 24,
	RUNNER_DIE = 25,
	RESPAWN = 26,
	CRYSTALS = 19,    ## host -> client: which crystals are already gone
	CHECKPOINT = 27,
	NOTICE = 28,
	STAGE_CLEAR = 29,
	WORLD = 30,       ## host -> client: something happened that both must see
	## host -> client: EVERY construct the host has, as one list.
	##
	## Not an optimisation of HOLO_SPAWN -- a different kind of message. A spawn
	## is an event ("this came into being"), and replaying events to recover a
	## connection cannot remove anything or correct anything: reconnecting used
	## to send one spawn per live construct and the client, which had never
	## thrown its own away, ended up with two of each. This is STATE. What is in
	## it is what exists; what is not in it does not.
	HOLO_LIST = 31,
	## host -> client: this enemy's soft spot is open until tick N. The one
	## piece of enemy state neither device can work out on its own, because
	## opening it is a judgement the host makes about what the runner did.
	WEAK_WINDOW = 32,
	## host -> client: the boss's state machine. The one enemy whose behaviour
	## the guardian's device cannot derive, because the guardian's enemies are
	## puppets with their physics switched off and this one's whole contribution
	## is WHICH STATE IT IS IN. See Keeper, and docs/stage-keeper.md section 8.
	BOSS = 33,
	MIGRATION_CHUNK = 40, ## authority -> standby: chunked complete checkpoint
	RUNNER_INPUT = 41,    ## remote runner -> authority after host migration
	AUTHORITY_READY = 42, ## new authority -> returning peer
}

## The things the host does that the guardian's device cannot derive for itself.
##
## This exists because of a gap that only became obvious once the game had a
## voice: the host raised shot_fired, enemy_killed, switch_activated and the
## rest on its OWN event bus and sent none of them, so online the guardian could
## not see their own tracer, watch an enemy die, or see the gate they had just
## shot open. Half the game was happening on one device.
##
## One message with a kind byte rather than one message per event: these are
## rare (a few a second at the very most), and a single relay is one place to
## get the host-to-client direction right instead of eight.
enum World {
	SHOT = 1,         ## a, b = the tracer; value = 1 when it connected
	ENEMY_DIE = 2,
	RUNNER_HURT = 3,  ## value = hp remaining
	SWITCH = 4,       ## text = the switch id
	COIN = 5,
	SPRING = 6,
	RESCUE = 7,       ## value = tier
	STAGE_CLEAR = 8,
	HOLO_EXPIRED = 9, ## value = kind
	LAUNCH = 10,      ## the guardian threw the runner off a construct
	SHOT_BLOCKED = 11,## the shot landed on a shield, or a soft spot that is shut
	WALL_JUMP = 12,   ## the runner kicked off one of the guardian's walls
	CRYSTAL = 13,     ## value = net_id; a crystal has been collected
	MARK = 14,        ## value = kind; a = where somebody is pointing
}

## Bumped for the stage in the handshake. Mismatched builds already refuse
## each other at the handshake, which is what makes changing this safe -- and
## the refusal names both versions, so "one of you needs to update" is what the
## screen says rather than a game that half works.
## 15: sky crows add enemies after each stage's own, and the goal needs a key.
const VERSION: int = 15

## Fixed-point helpers shared with Snapshot, so a position means the same thing
## on both channels.
static func put_pos(b: StreamPeerBuffer, p: Vector2) -> void:
	b.put_u16(Snapshot._q_x(p.x))
	b.put_u16(Snapshot._q_y(p.y))

static func get_pos(b: StreamPeerBuffer) -> Vector2:
	return Vector2(Snapshot._u_x(b.get_u16()), Snapshot._u_y(b.get_u16()))

## A drawn platform's shape, relative to its position: a count, then whole-pixel
## offsets. An empty shape (count 0) is the standard slab a tap places.
static func put_shape(b: StreamPeerBuffer, path: PackedVector2Array) -> void:
	var n := mini(path.size(), 255)
	b.put_u8(n)
	for i in range(n):
		b.put_16(clampi(int(round(path[i].x)), -32768, 32767))
		b.put_16(clampi(int(round(path[i].y)), -32768, 32767))

static func get_shape(b: StreamPeerBuffer) -> PackedVector2Array:
	var out := PackedVector2Array()
	if b.get_available_bytes() < 1:
		return out
	var n := b.get_u8()
	for _i in range(n):
		if b.get_available_bytes() < 4:
			break
		var x := float(b.get_16())
		out.append(Vector2(x, float(b.get_16())))
	return out

static func _buf(kind: int) -> StreamPeerBuffer:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	b.put_u8(kind)
	return b

## The handshake carries WHO, WHAT VERSION and WHICH STAGE, because they are
## three separate questions. See Party, and Stage.needs_two_devices.
##
## The stage is here for the asymmetric ones. Two players on different stages
## used to be perfectly possible -- the selection is local, each device builds
## its own level -- and on a stage where one of them is meant not to see things,
## the symptom of that mistake is "my partner is describing a place that does
## not exist". There is no way to debug that from inside the game, so it is
## refused at the door instead.
static func hello(player_id: String, stage: int, role: String = "guardian") -> PackedByteArray:
	var b := _buf(Msg.HELLO)
	b.put_u8(VERSION)
	b.put_u8(stage)
	b.put_u8(1 if role == "runner" else 2)
	b.put_utf8_string(player_id)
	return b.data_array

static func runner_input(axis: float, axis_y: float, jump: bool, dash: bool,
		sequence: int) -> PackedByteArray:
	var b := _buf(Msg.RUNNER_INPUT)
	b.put_8(clampi(int(round(axis * 127.0)), -127, 127))
	b.put_8(clampi(int(round(axis_y * 127.0)), -127, 127))
	b.put_u8((1 if jump else 0) | ((1 if dash else 0) << 1))
	b.put_u16(sequence & 0xFFFF)
	return b.data_array

static func authority_ready(epoch: int, tick: int) -> PackedByteArray:
	var b := _buf(Msg.AUTHORITY_READY)
	b.put_u32(epoch)
	b.put_u32(tick)
	return b.data_array

static func welcome(tick: int, player_id: String) -> PackedByteArray:
	var b := _buf(Msg.WELCOME)
	b.put_u32(tick)
	b.put_utf8_string(player_id)
	return b.data_array

static func ping(client_ms: int) -> PackedByteArray:
	var b := _buf(Msg.PING)
	b.put_u32(client_ms)
	return b.data_array

static func pong(client_ms: int, host_tick: int) -> PackedByteArray:
	var b := _buf(Msg.PONG)
	b.put_u32(client_ms)
	b.put_u32(host_tick)
	return b.data_array

## Three aim samples per packet. The channel is unreliable, and carrying the
## last two costs 8 bytes and makes a single lost packet invisible.
static func aim(now: Vector2, prev: Vector2, prev2: Vector2) -> PackedByteArray:
	var b := _buf(Msg.AIM)
	for p in [now, prev, prev2]:
		put_pos(b, p)
	return b.data_array

## `path` is a traced platform's shape relative to `at`; empty is the standard slab.
static func place(slot: int, at: Vector2, view_tick: int, seq: int,
		path: PackedVector2Array = PackedVector2Array()) -> PackedByteArray:
	var b := _buf(Msg.PLACE)
	b.put_u8(slot)
	put_pos(b, at)
	b.put_u32(view_tick)
	b.put_u16(seq)
	put_shape(b, path)
	return b.data_array

## No particular enemy -- shoot at the point and let the host find what is there.
const NO_TARGET: int = 0xFFFF

## A shot names its TARGET, not just a place.
##
## It used to carry only a position, which the host then resolved against its
## own enemies within 26px (110 with assist). But the position came from the
## guardian's copy of the world, and the host's enemies had moved on since --
## so the guardian put the crosshair on a walker, and the host was asked to
## shoot an empty patch of grass a walker had been standing on. Nothing died.
## The device that decides WHICH enemy is the one with the crosshair on it, so
## it sends that decision; the point is still here for the fallback, for a
## target that died on the way, and for the tracer when nothing is hit.
static func fire(at: Vector2, view_tick: int, seq: int,
		target_id: int = NO_TARGET) -> PackedByteArray:
	var b := _buf(Msg.FIRE)
	put_pos(b, at)
	b.put_u32(view_tick)
	b.put_u16(seq)
	b.put_u16(NO_TARGET if target_id < 0 else target_id)
	return b.data_array

## The host's whole set of constructs, for a client that has to be put back in
## step. Sixteen bytes each plus the shape, and never more than a handful alive, so the entire
## world of constructs fits in one packet well inside the relay's frame limit.
static func holo_list(rows: Array) -> PackedByteArray:
	var b := _buf(Msg.HOLO_LIST)
	b.put_u8(rows.size())
	for row in rows:
		b.put_u16(int(row["net_id"]))
		b.put_u8(int(row["kind"]))
		put_pos(b, row["at"])
		b.put_u32(int(row["birth"]))
		b.put_u32(int(row["death"]))
		# Whether its launcher has already been used. A platform restored
		# without this reads as ready to fire on the guardian's screen and does
		# nothing when they shoot it.
		b.put_u8(1 if bool(row["armed"]) else 0)
		put_shape(b, row.get("path", PackedVector2Array()))
	return b.data_array

## How long an enemy's soft spot stays open, decided by the host.
static func weak_window(net_id: int, until_tick: int) -> PackedByteArray:
	var b := _buf(Msg.WEAK_WINDOW)
	b.put_u16(net_id)
	b.put_u32(until_tick)
	return b.data_array

## What the boss is doing. Ten bytes, sent on a state change and twice a second
## otherwise, so a dropped packet costs half a second of a stale pose rather
## than a guardian aiming at a core that shut a second ago.
##
## The timer is in here for one reason: the ring that empties around the open
## core is the guardian's shot clock, and a client counting down its own guess
## would be showing a different clock from the one the host is enforcing.
static func boss(net_id: int, state: int, hp: int, timer: float, facing: int,
		spent: bool) -> PackedByteArray:
	var b := _buf(Msg.BOSS)
	b.put_u16(net_id)
	b.put_u8(state)
	b.put_u8(clampi(hp, 0, 255))
	b.put_u16(clampi(int(round(timer * 1000.0)), 0, 65535))
	b.put_8(signi(facing))
	b.put_u8(1 if spent else 0)
	return b.data_array

## Every crystal already collected, as one bitmask.
##
## Sent on the handshake rather than as one message per crystal: a guardian
## reconnecting late in a stage would otherwise get a burst of them, and each
## would have to be idempotent on its own. A mask is the state, not a list of
## things that happened, so replaying it twice changes nothing.
static func undo(seq: int) -> PackedByteArray:
	var b := _buf(Msg.UNDO)
	b.put_u16(seq)
	return b.data_array

static func mark(at: Vector2, kind: int) -> PackedByteArray:
	var b := _buf(Msg.MARK)
	put_pos(b, at)
	b.put_u8(kind)
	return b.data_array

static func crystals(mask: int) -> PackedByteArray:
	var b := _buf(Msg.CRYSTALS)
	b.put_u32(mask)
	return b.data_array

static func slot(n: int) -> PackedByteArray:
	var b := _buf(Msg.SLOT)
	b.put_u8(n)
	return b.data_array

## The lifetime travels with the spawn, so nothing has to be sent when it ends:
## both devices expire it at the same tick. docs/netcode.md 4.
static func holo_spawn(id: int, kind: int, at: Vector2, birth: int, death: int,
		client_seq: int, path: PackedVector2Array = PackedVector2Array()) -> PackedByteArray:
	var b := _buf(Msg.HOLO_SPAWN)
	b.put_u16(id)
	b.put_u8(kind)
	put_pos(b, at)
	b.put_u32(birth)
	b.put_u32(death)
	b.put_u16(client_seq)
	put_shape(b, path)
	return b.data_array

static func holo_kill(id: int) -> PackedByteArray:
	var b := _buf(Msg.HOLO_KILL)
	b.put_u16(id)
	return b.data_array

static func reject(seq: int, reason: String) -> PackedByteArray:
	var b := _buf(Msg.REJECT)
	b.put_u16(seq)
	b.put_utf8_string(reason)
	return b.data_array

static func enemy_die(id: int, cause: int) -> PackedByteArray:
	var b := _buf(Msg.ENEMY_DIE)
	b.put_u16(id)
	b.put_u8(cause)
	return b.data_array

static func simple(kind: int, value: int = 0) -> PackedByteArray:
	var b := _buf(kind)
	b.put_u32(value)
	return b.data_array

static func notice(text: String) -> PackedByteArray:
	var b := _buf(Msg.NOTICE)
	b.put_utf8_string(text)
	return b.data_array

## Every decoder starts by reading the kind byte, so this hands back a buffer
## positioned just after it.
## `text` is almost always empty; it costs four bytes and saves a second message
## shape for the one event (a switch) that is identified by name.
static func world(kind: int, a: Vector2, b: Vector2, value: int = 0,
		text: String = "") -> PackedByteArray:
	var buf := _buf(Msg.WORLD)
	buf.put_u8(kind)
	put_pos(buf, a)
	put_pos(buf, b)
	buf.put_u8(value)
	buf.put_utf8_string(text)
	return buf.data_array

static func reader(payload: PackedByteArray) -> Array:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	b.data_array = payload
	if payload.is_empty():
		return [0, b]
	return [b.get_u8(), b]

