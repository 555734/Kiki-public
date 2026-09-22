class_name ClientSession
extends Node
## The guardian's device. Shows the host's world and sends intentions.
##
## It simulates nothing that the host owns. The runner is a puppet driven by
## interpolation between snapshots, enemies are placed from snapshots, and the
## gimmicks that are pure functions of the tick (moving platforms, lasers) run
## locally for free. What stays fully local and instant is everything the
## guardian touches: the reticle, the ability selection, the gauge readout and a
## ghost of a construct the moment they ask for it. That is what keeps the UI
## from ever feeling like it is waiting -- docs/netcode.md section 6.

## How far behind the newest snapshot to render, in ticks. Widened when arrivals
## get jittery so the buffer does not run dry mid-jump.
const INTERP_MIN: int = 3
const INTERP_MAX: int = 8
const BUFFER_MAX: int = 20

var main: Node2D = null
var transport: NetTransport = null
var local_role: String = "guardian"

var _buffer: Array[Snapshot] = []
var _interp_ticks: int = INTERP_MIN
var _seq: int = 1
var _pending: Dictionary = {}      ## seq -> ghost Node2D
var _aim_history: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
## -1 until a pong has actually come back. Zero is a measurement, "never
## measured" is not, and a diagnostic that prints 0ms for both is lying about
## one of them.
## Who is playing, by the three names that can mean "who". See Party.
var party := Party.new()

var _rtt: float = -1.0
var _last_ping_ms: int = 0
var _ping_accumulator: float = 0.0
var _enemies: Array[Node2D] = []
## Enemies by the name the host uses for them. An Array indexed by position was
## what tied the guardian's screen to the host's list ORDER, and that order
## changes the first time anything dies.
var _by_net_id: Dictionary = {}
## HELLO can be sent before the socket is actually open on a relayed link, so it
## is repeated with the ping until the host answers. A lost one is not fatal --
## the ping's reply carries the tick too -- but retrying costs nothing.
var _welcomed: bool = false
## A jump between two consecutive snapshots larger than this cannot be running:
## the sprint tops out near 440 px/s and snapshots are 33ms apart, so anything
## past ~15px is already suspicious. 300 leaves a wide margin for a dropped
## snapshot or two and still cannot be reached by any legal movement.
const TELEPORT_PX: float = 300.0
var _warp_seen: bool = false
var _last_state: int = -1
var _last_on_floor: bool = true

## Reconnection.
##
## A phone WILL drop this link -- the app goes into a pocket, Wi-Fi hands over
## to LTE, a call arrives. Ending the session on the first of those is not a
## difficulty setting, it is the end of the playtest, and it is what the game
## did. So a drop now freezes the picture and dials back instead.
##
## The host does not have to cooperate: it owns the simulation and keeps
## running whether anyone is watching. Everything the returning client needs is
## either in the next snapshot (the runner, the enemies, the gauge) or replayed
## by the host on the new handshake (the constructs, the gates).
const RETRY_EVERY: float = 2.0
const GIVE_UP_AFTER: float = 90.0
## Packets stop before the socket admits it, especially on a backgrounded app.
## A mobile link stalls for a second or two and comes back; that is normal and
## it is not a drop. Four seconds caught those stalls and put an alarming
## banner over a game that was still running. Seven is still well inside the
## time it takes anyone to wonder what is happening, and a false positive costs
## nothing now that a healthy socket is never thrown away.
const SILENCE_IS_A_DROP: float = 7.0
## How often the guardian's reticle is sent. Twenty a second is smoother than
## the runner can react to and a third of what a 60Hz frame loop was sending.
const AIM_EVERY: float = 1.0 / 20.0
var _aim_accumulator: float = 0.0
## Has anything ever arrived on this link? Until it has, there is nothing to
## reconnect TO, and silence means "not yet" rather than "gone".
var _ever_heard: bool = false

var _silence: float = 0.0
var _down_for: float = -1.0
var _retry_in: float = 0.0
var _tries: int = 0
var _runner_input_accumulator: float = 0.0
var _runner_input_sequence: int = 0
var _migration_parts: Dictionary = {}
var _latest_migration: Dictionary = {}
var _latest_migration_received_ms: int = -1

signal disconnected
## The host has answered the handshake. Not the same event as the transport
## saying the other player is present: the relay reports that as soon as two
## devices are in the room, and the host can still refuse -- a build mismatch,
## most obviously. The connect screen waits for THIS, so a refusal is read on
## the screen that was asking rather than flashed over a game that never began.
signal handshaken

func _ready() -> void:
	Clock.is_host = false
	Clock.follow_target = -1
	_take_over_local_world()
	# A respawn throws every enemy in the stage away and builds new ones, on
	# this device as well as the host's. Taking the world over exactly once, at
	# the handshake, meant that from the first death onwards this device was
	# steering twenty freed objects: nothing the host said about an enemy
	# landed on anything, and the new enemies -- never switched off -- ran
	# their own simulation and drifted. Measured at up to 330px of daylight
	# between the two devices on an enemy standing in the middle of the
	# guardian's screen. That is what "the enemies are floating" was, and why
	# shooting one did nothing: the host was asked to hit a place it had left.
	Events.level_rebuilt.connect(_take_over_local_world)
	transport.send(NetTransport.Channel.CONTROL,
		NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.hello(NetLink.client_id(), Stage.current(), local_role))

## Switch off everything the host owns. Leaving these running would not just
## waste frames -- a locally simulated runner would visibly disagree with the
## authoritative one, which is the exact confusion this design exists to avoid.
func _take_over_local_world() -> void:
	if not is_instance_valid(main):
		return
	var r: Runner = main.runner
	r.set_physics_process(false)
	# Not set_process: the puppet still has to run down the timers that decide
	# how it is DRAWN, and the hurt blink is one of them.
	_enemies.clear()
	_by_net_id.clear()
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node2D:
			_enemies.append(e)
			var id = e.get("net_id")
			if id != null and int(id) >= 0:
				_by_net_id[int(id)] = e
			(e as Node).set_physics_process(false)

func _process(delta: float) -> void:
	# A freed node is a dangling reference, not null, so `main == null` does not
	# catch a torn-down world. Without this the session keeps driving a puppet
	# that no longer exists for the rest of the frame.
	if transport == null or not is_instance_valid(main):
		return
	var packets := transport.poll()
	for packet in packets:
		_handle(packet)
	_watch_link(delta, not packets.is_empty())
	_render_interpolated()
	# Rate-limited, not per-frame. This used to send once per rendered frame,
	# which is 60 messages a second on one phone and 120 on another -- two to
	# four times the snapshot rate, for a thumb that does not move that fast.
	# Every one of them is a frame on a TCP socket and a wake-up for the relay,
	# and the relay forwards strictly in order: the guardian's own flood was in
	# front of the snapshots they were waiting for.
	_aim_accumulator += delta
	if local_role == "guardian" and _down_for < 0.0 and _aim_accumulator >= AIM_EVERY:
		_aim_accumulator = 0.0
		_send_aim()
	_ping_accumulator += delta
	if _ping_accumulator >= 1.0:
		_ping_accumulator = 0.0
		_last_ping_ms = Time.get_ticks_msec()
		transport.send(NetTransport.Channel.CONTROL,
			NetTransport.Reliability.RELIABLE_ORDERED, Protocol.ping(_last_ping_ms))
		if not _welcomed:
			transport.send(NetTransport.Channel.CONTROL,
				NetTransport.Reliability.RELIABLE_ORDERED,
				Protocol.hello(NetLink.client_id(), Stage.current(), local_role))
	if local_role == "runner" and _down_for < 0.0:
		_runner_input_accumulator += delta
		if _runner_input_accumulator >= 1.0 / 30.0:
			_runner_input_accumulator = 0.0
			_runner_input_sequence = (_runner_input_sequence + 1) & 0xFFFF
			transport.send(NetTransport.Channel.AIM, NetTransport.Reliability.UNRELIABLE,
				Protocol.runner_input(main.input_hub.move_axis, main.input_hub.move_axis_y,
					main.input_hub.jump_held, main.input_hub.dash_held,
					_runner_input_sequence))

## Is the link up, and if not, keep trying.
##
## Silence is the signal, not the socket's own state: a WebSocket that has lost
## its peer can sit in OPEN for a long time, and the game should not go on
## pretending for that long. Four seconds is comfortably longer than any gap
## between snapshots (they arrive 30 times a second) and short enough that the
## guardian is told before they start wondering.
##
## None of which applies before the FIRST packet ever arrives. That silence is
## not a dropped link, it is the other player still reading a six-letter code
## out loud -- which takes longer than four seconds every single time. Treating
## it as a drop made the game unjoinable: the waiting device declared the link
## dead before it had ever been alive and began re-dialling, and on the relay a
## re-dial claims the SECOND slot of a two-slot room while the first is still
## open, so the retries could not succeed either. A connection that has never
## been made cannot be re-made; it can only be waited for.
func _watch_link(delta: float, heard_something: bool) -> void:
	if heard_something:
		_silence = 0.0
		_ever_heard = true
		if _down_for >= 0.0:
			_recovered()
		return
	# Silence before the first packet ever arrives is the other player still
	# reading the code out -- but ONLY while this device's own link is up. A
	# socket that never opened, or one the relay hung up before anyone had said
	# anything, is not waiting for anybody: it is down, and this is the only
	# thing that would ever re-dial it. Skipping it here is what left a device
	# sitting in a dead room with 0 packets in, 0 out and no way back except
	# force-quitting the game.
	if not _ever_heard and _link_is_up():
		return

	_silence += delta
	if _down_for < 0.0:
		if _silence < SILENCE_IS_A_DROP:
			return
		_down_for = 0.0
		_retry_in = 0.0
		_tries = 0
		_link().enter(NetLink.Phase.RECONNECTING,
			"" if _ever_heard else "一度も届いていません")
		Events.link_state.emit("接続が切れました。つなぎ直しています…" if _ever_heard
			else "中継サーバーにつながりません。つなぎ直しています…")
		return

	_down_for += delta
	if _down_for > GIVE_UP_AFTER:
		_link().enter(NetLink.Phase.FAILED, "%.0f秒つなぎ直せませんでした" % GIVE_UP_AFTER)
		Events.link_state.emit("つなぎ直せませんでした。もう一度部屋に入ってください")
		disconnected.emit()
		set_process(false)
		return

	_retry_in -= delta
	if _retry_in > 0.0:
		return
	_retry_in = RETRY_EVERY
	_tries += 1
	_link().reconnects += 1
	Events.link_state.emit("つなぎ直しています… (%d)" % _tries)
	# Only re-dial a link that is actually down. A silent but OPEN socket means
	# the other side has gone quiet, not that this side has lost its connection,
	# and throwing the socket away there was making things permanently worse:
	# the relay's rooms hold two peers, the discarded socket keeps its slot
	# until its close completes, and the replacement is refused as "room full".
	# That is what turned one four-second gap into "reconnecting" forever.
	if transport.has_method("is_link_open") and bool(transport.call("is_link_open")):
		_send_hello()
		return
	if transport.has_method("reconnect"):
		transport.call("reconnect")
	_send_hello()

## The one owner of "where has this connection got to". Never null in the real
## game; a bare NetLink is handed back in tests that build a session without a
## world, so no caller has to guard.
var _standalone_link: NetLink = null

func _link() -> NetLink:
	if is_instance_valid(main) and main.get("link") != null:
		return main.link
	if _standalone_link == null:
		_standalone_link = NetLink.new()
	return _standalone_link

## Whether this device's own connection to the relay is up. Not whether the
## other player is there -- those are different questions and only this one
## says whether re-dialling would help.
func _link_is_up() -> bool:
	if transport == null:
		return false
	if transport.has_method("is_link_open"):
		return bool(transport.call("is_link_open"))
	return transport.is_connected_to_peer()

## HELLO is the whole recovery: the host answers it with a fresh WELCOME and a
## replay of everything this device missed.
func _send_hello() -> void:
	_welcomed = false
	_restoring = true
	transport.send(NetTransport.Channel.CONTROL,
		NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.hello(NetLink.client_id(), Stage.current(), local_role))

func migration_state_is_fresh() -> bool:
	return not _latest_migration.is_empty() and _latest_migration_received_ms >= 0 \
		and Time.get_ticks_msec() - _latest_migration_received_ms <= MigrationState.MAX_AGE_MS

func latest_migration_state() -> Dictionary:
	return _latest_migration.duplicate(true) if migration_state_is_fresh() else {}

func _recovered() -> void:
	_down_for = -1.0
	_tries = 0
	_link().enter(NetLink.Phase.PLAYING, "復帰")
	# The buffer is full of snapshots from before the gap. Interpolating out of
	# them would drag the runner backwards across the stage before catching up.
	_buffer.clear()
	# Not clear yet: the link is up but the world has not been handed back.
	# Saying "connected" here and then refusing the first thing the guardian
	# builds is worse than saying what is actually happening.
	Events.link_state.emit("" if not _restoring else "世界を取り戻しています…")
	Events.notice.emit("reconnected")

# ------------------------------------------------------------------- display

## The tick this device is currently drawing. Sent with every command so the
## host knows which past the guardian was looking at.
func view_tick() -> int:
	return maxi(0, Clock.tick - _interp_ticks)

func _render_interpolated() -> void:
	if _buffer.size() < 2:
		return
	var target := float(view_tick())
	var a: Snapshot = _buffer[0]
	var b: Snapshot = _buffer[_buffer.size() - 1]
	for i in range(_buffer.size() - 1):
		if float(_buffer[i].tick) <= target and float(_buffer[i + 1].tick) >= target:
			a = _buffer[i]
			b = _buffer[i + 1]
			break
	var span := float(b.tick - a.tick)
	var t := 0.0 if span <= 0.0 else clampf((target - float(a.tick)) / span, 0.0, 1.0)

	_derive_movement(a, b)

	var r: Runner = main.runner
	# A warp is the one thing that moves the runner further in a tick than they
	# can possibly travel, and interpolating across it draws them sliding the
	# whole way instead of arriving. Snap, and raise the same event the host did
	# so this device flashes both gates too -- derived locally, costing nothing.
	if a.runner_position.distance_to(b.runner_position) > TELEPORT_PX:
		r.global_position = b.runner_position
		r.velocity = b.runner_velocity
		if not _warp_seen:
			_warp_seen = true
			Events.runner_warped.emit(a.runner_position, b.runner_position)
		r.facing = b.facing
		r.state = b.runner_state
		r.apply_movement_flags(b.movement_flags)
		r.hp = b.hp
		r.grounded = b.on_floor
		return
	_warp_seen = false
	r.global_position = _hermite(a.runner_position, a.runner_velocity,
		b.runner_position, b.runner_velocity, t, span * Clock.DT)
	r.velocity = a.runner_velocity.lerp(b.runner_velocity, t)
	r.facing = b.facing
	r.state = b.runner_state
	r.apply_movement_flags(b.movement_flags)
	r.hp = b.hp
	# The bit was already in the snapshot and already being read -- it just
	# never reached the puppet, so everything drawn from ground contact on this
	# screen was frozen. See Runner.grounded.
	r.grounded = b.on_floor
	main.guardian.gauge = lerpf(main.guardian.gauge, b.gauge, 0.25)

	for e in b.dirty_enemies:
		var who: Node2D = _by_net_id.get(int(e["id"]))
		if who != null and is_instance_valid(who):
			who.global_position = Vector2(float(e["x"]), float(e["y"]))

## Cubic through both endpoints using the velocities as tangents. Linear
## interpolation turns a jump into a folded line and flattens the apex -- the
## one part of the arc the guardian is aiming at.
static func _hermite(p0: Vector2, v0: Vector2, p1: Vector2, v1: Vector2,
		t: float, dt: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * p0 \
		+ (t3 - 2.0 * t2 + t) * v0 * dt \
		+ (-2.0 * t3 + 3.0 * t2) * p1 \
		+ (t3 - t2) * v1 * dt

# ------------------------------------------------------------------ outgoing

func _send_aim() -> void:
	var now: Vector2 = main.input_hub.aim_world()
	transport.send(NetTransport.Channel.AIM, NetTransport.Reliability.UNRELIABLE,
		Protocol.aim(now, _aim_history[0], _aim_history[1]))
	_aim_history[1] = _aim_history[0]
	_aim_history[0] = now

## Called instead of Guardian.use_active when online. The construct appears here
## immediately as a ghost and is replaced when the host confirms it; the gauge is
## deducted optimistically for the same reason.
func request_use(slot: int, at: Vector2, target_id: int = -1) -> void:
	# Not while the world is still coming back. A command sent into a
	# half-restored world is answered against a set of constructs this device
	# cannot see yet -- and the optimistic ghost and gauge below would be
	# predicting from a picture that is about to be replaced wholesale.
	if _restoring:
		Events.ability_refused.emit(slot, "restoring")
		return
	var seq := _seq
	_seq = (_seq + 1) & 0xFFFF
	var channel := NetTransport.Channel.COMMAND
	if slot == 3:
		transport.send(channel, NetTransport.Reliability.RELIABLE_ORDERED,
			Protocol.fire(at, view_tick(), seq, target_id))
		return
	transport.send(channel, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.place(slot, at, view_tick(), seq))
	var ghost := Hologram.create(Hologram.kind_for_slot(slot), at)
	ghost.modulate = Color(1, 1, 1, 0.55)
	main.add_child(ghost)
	_pending[seq] = ghost
	var ability: GuardianAbility = main.guardian.abilities[slot]
	main.guardian.gauge = maxf(0.0, main.guardian.gauge - ability.cost)

## Taking back the construct just placed. No refund: this is for a wall across
## the wrong doorway, not for changing your mind about the cost.
func request_undo() -> void:
	if _restoring:
		return
	var seq := _seq
	_seq = (_seq + 1) & 0xFFFF
	transport.send(NetTransport.Channel.COMMAND,
		NetTransport.Reliability.RELIABLE_ORDERED, Protocol.undo(seq))

func request_mark(at: Vector2, kind: int) -> void:
	transport.send(NetTransport.Channel.COMMAND,
		NetTransport.Reliability.RELIABLE_ORDERED, Protocol.mark(at, kind))

func select_slot(slot: int) -> void:
	main.guardian.select_slot(slot)
	transport.send(NetTransport.Channel.COMMAND,
		NetTransport.Reliability.RELIABLE_ORDERED, Protocol.slot(slot))

# ------------------------------------------------------------------ incoming

func _handle(packet: Dictionary) -> void:
	if int(packet["channel"]) == NetTransport.Channel.SNAPSHOT:
		var s := Snapshot.decode(packet["payload"])
		# Sixteen bits on the wire, widened against the clock we already keep.
		s.tick = Clock.widen(s.tick, Clock.tick)
		# The freshest statement of the host's time there is: thirty a second,
		# against one a second from the pong. The clock is steered by it rather
		# than set to it, so it stays smooth between arrivals.
		Clock.follow_target = s.tick
		_absorb(s)
		return
	var parsed := Protocol.reader(packet["payload"])
	var kind: int = parsed[0]
	var b: StreamPeerBuffer = parsed[1]
	match kind:
		Protocol.Msg.MIGRATION_CHUNK:
			_absorb_migration_chunk(b)
		Protocol.Msg.WELCOME:
			_link().enter(NetLink.Phase.PLAYING)
			Clock.tick = int(b.get_u32())
			Clock.follow_target = Clock.tick
			# Now both devices can name both people. Which seat this device
			# holds is a separate fact from which device is the authority, and
			# the two are recorded separately on purpose -- see Party.
			var host_id := b.get_utf8_string()
			party.clear()
			party.seat(NetLink.client_id(), Party.ROLE_RUNNER \
				if local_role == "runner" else Party.ROLE_GUARDIAN)
			party.seat(host_id, Party.ROLE_GUARDIAN \
				if local_role == "runner" else Party.ROLE_RUNNER)
			var first := not _welcomed
			_welcomed = true
			if first:
				handshaken.emit()
		Protocol.Msg.PONG:
			var sent := int(b.get_u32())
			_rtt = float(Time.get_ticks_msec() - sent) / 1000.0
			# The pong is the only message that can measure the one-way delay,
			# so it is what sets the OFFSET. It steers the clock like a snapshot
			# rather than snapping it, for the same reason.
			Clock.follow_target = int(b.get_u32()) + Clock.ticks_for(_rtt * 0.5)
		Protocol.Msg.HOLO_SPAWN:
			_confirm_hologram(b)
		Protocol.Msg.HOLO_LIST:
			_match_the_host(b)
		Protocol.Msg.WEAK_WINDOW:
			var who := b.get_u16()
			var until_tick := int(b.get_u32())
			for e in get_tree().get_nodes_in_group("shieldbearer"):
				if e.get("net_id") != null and int(e.get("net_id")) == who \
						and e.has_method("open_until"):
					e.call("open_until", until_tick)
		Protocol.Msg.BOSS:
			var boss_id := b.get_u16()
			var boss_state := int(b.get_u8())
			var boss_hp := int(b.get_u8())
			var boss_timer := float(b.get_u16()) / 1000.0
			var boss_facing := int(b.get_8())
			var boss_spent := b.get_u8() == 1
			var boss: Node2D = _by_net_id.get(boss_id)
			# Looked up by group as well, because the boss is rebuilt on every
			# respawn and the id table is only refilled on the next
			# level_rebuilt -- a packet that lands in between must not be
			# dropped on the floor of a fight that is still going on.
			if boss == null or not is_instance_valid(boss):
				for e in get_tree().get_nodes_in_group("keeper"):
					if e is Node2D and int(e.get("net_id")) == boss_id:
						boss = e
						break
			if boss != null and is_instance_valid(boss) and boss.has_method("apply_net_state"):
				boss.call("apply_net_state", boss_state, boss_hp, boss_timer, boss_facing)
				boss.call("set_spent", boss_spent)
		Protocol.Msg.HOLO_KILL:
			_kill_hologram(int(b.get_u32()))
		Protocol.Msg.REJECT:
			var seq := b.get_u16()
			var reason := b.get_utf8_string()
			_drop_ghost(seq)
			Events.ability_refused.emit(main.guardian.active_slot, reason)
		Protocol.Msg.RUNNER_DIE:
			Events.runner_died.emit("host")
		Protocol.Msg.RESPAWN:
			Events.runner_respawned.emit(int(b.get_u32()))
		Protocol.Msg.CHECKPOINT:
			Events.checkpoint_reached.emit(int(b.get_u32()))
		Protocol.Msg.WORLD:
			_world(b)
		Protocol.Msg.CRYSTALS:
			_apply_crystal_mask(int(b.get_u32()))
		Protocol.Msg.NOTICE:
			# The host refusing the handshake arrives here. Surfaced rather than
			# swallowed: a version mismatch that says nothing is indisguishable
			# from a dead connection.
			Events.notice.emit(b.get_utf8_string())
		Protocol.Msg.AUTHORITY_READY:
			b.get_u32()
			Clock.follow_target = int(b.get_u32())

func _absorb_migration_chunk(b: StreamPeerBuffer) -> void:
	var generation := int(b.get_u32())
	var tick := int(b.get_u32())
	var index := int(b.get_u16())
	var total := int(b.get_u16())
	var payload_size := int(b.get_u16())
	var digest_result := b.get_data(8)
	if digest_result[0] != OK or total <= 0 or total > 64 or index >= total:
		return
	var data_result := b.get_data(b.get_available_bytes())
	if data_result[0] != OK:
		return
	if not _migration_parts.has(generation):
		_migration_parts = {generation: {
			"tick": tick, "total": total, "size": payload_size,
			"digest": digest_result[1], "parts": {},
		}}
	var frame: Dictionary = _migration_parts[generation]
	if frame["total"] != total or frame["size"] != payload_size \
			or frame["digest"] != digest_result[1]:
		_migration_parts.erase(generation)
		return
	frame["parts"][index] = data_result[1]
	if frame["parts"].size() != total:
		return
	var payload := PackedByteArray()
	for part_index in total:
		if not frame["parts"].has(part_index):
			return
		payload.append_array(frame["parts"][part_index])
	if payload.size() != payload_size or MigrationState.digest(payload) != frame["digest"]:
		_migration_parts.erase(generation)
		return
	var decoded := MigrationState.decode(payload)
	if not decoded.is_empty():
		_latest_migration = decoded
		_latest_migration_received_ms = Time.get_ticks_msec()
	_migration_parts.clear()

## Jump and landing, worked out rather than sent.
##
## The snapshot already says what the runner is doing and whether they are on
## the floor, so the two transitions that need a sound fall straight out of it.
## Adding them to the wire would have been two more messages for something both
## devices can already see -- the same rule the moving platforms follow.
func _derive_movement(a: Snapshot, b: Snapshot) -> void:
	if b.runner_state == Runner.State.JUMP and _last_state != Runner.State.JUMP:
		Events.runner_jumped.emit()
	if b.on_floor and not _last_on_floor:
		Events.runner_landed.emit(
			absf(a.runner_velocity.y) > Balance.RUNNER_TERMINAL_VELOCITY * 0.55)
	_last_state = b.runner_state
	_last_on_floor = b.on_floor

## The host's event bus, replayed onto this device's. Everything downstream --
## the tracers, the particles, the sound, the gate -- is already listening for
## these signals, so nothing else has to know the difference between an event
## that happened here and one that happened on the other phone.
func _world(b: StreamPeerBuffer) -> void:
	var kind := b.get_u8()
	var a := Protocol.get_pos(b)
	var second := Protocol.get_pos(b)
	var value := b.get_u8()
	var text := b.get_utf8_string()
	match kind:
		Protocol.World.SHOT:
			Events.shot_fired.emit(a, second, value == 1)
		Protocol.World.ENEMY_DIE:
			# Remove it. This used to raise the event and nothing else, so the
			# sound played and the sparks flew over an enemy that then stood
			# there, frozen, for the rest of the run -- client enemies do not
			# run their own physics, so it could not even walk away.
			var dead: Node2D = _by_net_id.get(value)
			if dead == null or not is_instance_valid(dead):
				dead = _enemy_near(a)
			Events.enemy_killed.emit(dead, "remote")
			if dead != null and is_instance_valid(dead):
				_by_net_id.erase(int(dead.get("net_id")) \
					if dead.get("net_id") != null else -1)
				_enemies.erase(dead)
				dead.queue_free()
		Protocol.World.RUNNER_HURT:
			Events.runner_damaged.emit(value, Balance.RUNNER_MAX_HP)
		Protocol.World.SWITCH:
			Events.switch_activated.emit(text)
		Protocol.World.COIN:
			Events.coin_collected.emit(a)
		Protocol.World.CRYSTAL:
			_take_crystal(value, a)
		Protocol.World.MARK:
			Events.pinged.emit(a, value, true)
		Protocol.World.SPRING:
			Events.spring_bounced.emit(a)
		Protocol.World.LAUNCH:
			# The marker goes out on this screen too. See
			# LaunchTrigger.spend_nearest for why that cannot be worked out
			# locally.
			LaunchTrigger.spend_nearest(get_tree(), a)
			Events.runner_launched.emit(a)
		Protocol.World.SHOT_BLOCKED:
			Events.shot_blocked.emit(a)
		Protocol.World.WALL_JUMP:
			Events.runner_wall_jumped.emit(a, value)
		Protocol.World.RESCUE:
			Events.rescue_scored.emit(value, a)
		Protocol.World.STAGE_CLEAR:
			Events.stage_cleared.emit(GameState.stats())
		Protocol.World.HOLO_EXPIRED:
			Events.hologram_expired.emit(value)

## A construct the host says is gone -- the guardian took it back. By name, so
## a resend removes nothing a second time.
func _kill_hologram(net_id: int) -> void:
	for kind in [Hologram.Kind.PLATFORM, Hologram.Kind.WALL, Hologram.Kind.WARP]:
		for h in main.guardian.holograms_of(kind):
			if h.net_id == net_id:
				main.guardian._list_for(kind).erase(h)
				h.queue_free()
				Events.hologram_expired.emit(int(kind))
				return

## A crystal the host says is gone. Taken by NAME rather than by proximity: this
## device's runner is a puppet a few ticks behind, so a local check here could
## disagree at the edge of the radius -- and then one screen has a crystal the
## other has spent.
func _take_crystal(id: int, at: Vector2) -> void:
	GameState.take_crystal(id)
	for c in get_tree().get_nodes_in_group("crystal"):
		if c is Crystal and c.net_id == id:
			if c.taken():
				return          # a resend; nothing to do and nothing to play twice
			c.collect()
			Events.crystal_taken.emit(id, c.global_position, c.amount)
			return
	Events.crystal_taken.emit(id, at, Balance.CRYSTAL_GAUGE)

## The whole taken set, on the handshake. Applied by rebuilding rather than by
## replaying events, so reconnecting cannot sound like ten crystals at once.
func _apply_crystal_mask(mask: int) -> void:
	GameState.apply_crystal_mask(mask)
	for c in get_tree().get_nodes_in_group("crystal"):
		if c is Crystal and GameState.crystals_taken.has(c.net_id) and not c.taken():
			c.collect()

## enemy_killed carries the node itself, which does not cross a network. The
## nearest enemy to where the host said it died is the same one in every case
## that matters, and a miss only costs one puff of particles.
func _enemy_near(at: Vector2) -> Node2D:
	var best: Node2D = null
	var closest := 120.0
	for e in _enemies:
		if is_instance_valid(e) and e.global_position.distance_to(at) < closest:
			closest = e.global_position.distance_to(at)
			best = e
	return best

func _absorb(s: Snapshot) -> void:
	_buffer.append(s)
	_buffer.sort_custom(func(x, y): return x.tick < y.tick)
	while _buffer.size() > BUFFER_MAX:
		_buffer.pop_front()
	# Keep the render point far enough back that the buffer never empties, but
	# no further: every extra tick is latency the guardian has to lead by.
	var newest := _buffer[_buffer.size() - 1].tick
	var behind := Clock.tick - newest
	if behind > _interp_ticks:
		_interp_ticks = mini(INTERP_MAX, _interp_ticks + 1)
	elif behind < _interp_ticks - 2:
		_interp_ticks = maxi(INTERP_MIN, _interp_ticks - 1)

func _confirm_hologram(b: StreamPeerBuffer) -> void:
	var net_id := b.get_u16()
	var kind := b.get_u8()
	var at := Protocol.get_pos(b)
	var birth := int(b.get_u32())
	var death := int(b.get_u32())
	var seq := b.get_u16()
	_drop_ghost(seq)
	# A construct already carrying this name is this construct. The reliable
	# channel should not deliver a spawn twice, but "should not" is not a reason
	# to build a second one if it ever does -- and the same guard makes the
	# message safe to send again deliberately.
	for existing in main.guardian.holograms_of(kind as Hologram.Kind):
		if is_instance_valid(existing) and existing.net_id == net_id:
			existing.global_position = at
			existing.birth_tick = birth
			existing.death_tick = death
			return
	var holo := Hologram.create(kind as Hologram.Kind, at)
	holo.net_id = net_id
	holo.birth_tick = birth
	holo.death_tick = death
	main.guardian.spawn_hologram(holo)

## Make this device's constructs exactly the host's set: remove what the host
## does not have, correct what it does, add what is missing.
##
## All three directions matter, and only the third one used to happen. A
## reconnect replayed a spawn for every live construct and this device, which
## had kept its own the whole time, ended up holding two of each; a platform
## whose launcher had been fired while the link was down came back looking
## ready; and a construct that expired during the gap stayed on screen forever
## because its removal was an event nobody replayed.
func _match_the_host(b: StreamPeerBuffer) -> void:
	var count := b.get_u8()
	var wanted: Dictionary = {}
	for _i in range(count):
		var row := {
			"net_id": b.get_u16(),
			"kind": b.get_u8(),
			"at": Protocol.get_pos(b),
			"birth": int(b.get_u32()),
			"death": int(b.get_u32()),
			"armed": b.get_u8() != 0,
		}
		wanted[row["net_id"]] = row

	var here: Dictionary = {}
	for kind in [Hologram.Kind.PLATFORM, Hologram.Kind.WALL, Hologram.Kind.WARP]:
		for h in main.guardian.holograms_of(kind):
			if not is_instance_valid(h):
				continue
			# A construct with no id was never confirmed by the host. It is a
			# prediction of ours, and the host's list is the answer to it.
			if h.net_id == 0 or wanted.has(h.net_id):
				here[h.net_id] = h
			else:
				h.expire()

	for id in wanted:
		var row: Dictionary = wanted[id]
		if here.has(id) and is_instance_valid(here[id]):
			var holo: Hologram = here[id]
			holo.global_position = row["at"]
			holo.birth_tick = int(row["birth"])
			holo.death_tick = int(row["death"])
			if holo.trigger != null:
				holo.trigger.armed = bool(row["armed"])
			continue
		var made := Hologram.create(int(row["kind"]) as Hologram.Kind, row["at"])
		made.net_id = int(id)
		made.birth_tick = int(row["birth"])
		made.death_tick = int(row["death"])
		main.guardian.spawn_hologram(made)
		if made.trigger != null:
			made.trigger.armed = bool(row["armed"])

	# Predictions that the host's answer did not confirm have been overtaken.
	for seq in _pending.keys():
		_drop_ghost(seq)
	_restoring = false
	Events.link_state.emit("")

## True between asking the host to put us back in step and being told what the
## world is. Commands are held while it holds: a guardian building on top of a
## half-restored world is spending gauge on a picture.
var _restoring: bool = false

func restoring() -> bool:
	return _restoring

func _drop_ghost(seq: int) -> void:
	if _pending.has(seq):
		var ghost = _pending[seq]
		if is_instance_valid(ghost):
			ghost.queue_free()
		_pending.erase(seq)

func round_trip() -> float:
	return _rtt

