class_name HostSession
extends Node
## The runner's device. Owns the simulation and tells the guardian what happened.
##
## Everything here is deliberately one-directional: the host never waits for the
## client. A guardian on a bad connection can be late, but they can never stall
## the runner -- which is the whole reason authority sits on this side
## (docs/netcode.md section 1).

## 30Hz. Physics is 60, so every other tick.
const SNAPSHOT_EVERY: int = 2
## Enemies further than this from the runner are not worth bytes.
const ENEMY_RADIUS: float = 1400.0

var main: Node2D = null
var transport: NetTransport = null
var authority: HostAuthority = null
## Gameplay role and network authority are independent after EOS host migration.
var local_role: String = "runner"
var remote_role: String = "guardian"
var _migration_generation: int = 0
var _remote_runner_silence: float = 0.0

## Who is playing, by the three names that can mean "who". See Party.
var party := Party.new()

var _next_holo_id: int = 1
var _seen_seq: Dictionary = {}      ## client seq -> true, so a resend is a no-op
var _sent_dead: Dictionary = {}

func _ready() -> void:
	Clock.is_host = true
	process_physics_priority = -100
	authority = HostAuthority.new()
	authority.runner = main.runner
	authority.guardian = main.guardian
	add_child(authority)

	Events.runner_died.connect(func(cause: String) -> void:
		_send_event(Protocol.simple(Protocol.Msg.RUNNER_DIE, Clock.tick)))
	Events.runner_respawned.connect(func(index: int) -> void:
		_send_event(Protocol.simple(Protocol.Msg.RESPAWN, index)))
	Events.checkpoint_reached.connect(func(index: int) -> void:
		_send_event(Protocol.simple(Protocol.Msg.CHECKPOINT, index)))
	_relay_world_events()

## Everything the host does on its own event bus that the guardian's device
## cannot work out for itself. Without this the guardian sees no tracer when
## they shoot, no enemy falling over, and a gate that never opens -- all of it
## happening on the runner's screen only. See Protocol.World.
func _relay_world_events() -> void:
	Events.shot_fired.connect(func(from: Vector2, to: Vector2, hit: bool) -> void:
		_world(Protocol.World.SHOT, from, to, 1 if hit else 0))
	Events.enemy_killed.connect(func(enemy: Node2D, _by: String) -> void:
		if is_instance_valid(enemy):
			# By name, not by where it happened to be standing. The position is
			# still sent, because that is where the burst of particles goes.
			var id: int = int(enemy.get("net_id")) if enemy.get("net_id") != null else -1
			_world(Protocol.World.ENEMY_DIE, enemy.global_position, Vector2.ZERO, id))
	Events.runner_damaged.connect(func(hp: int, _max: int) -> void:
		_world(Protocol.World.RUNNER_HURT, main.runner.global_position,
			Vector2.ZERO, hp))
	Events.switch_activated.connect(func(id: String) -> void:
		_world(Protocol.World.SWITCH, Vector2.ZERO, Vector2.ZERO, 0, id))
	Events.coin_collected.connect(func(at: Vector2) -> void:
		_world(Protocol.World.COIN, at, Vector2.ZERO))
	Events.crystal_taken.connect(func(id: int, at: Vector2, _amount: float) -> void:
		_world(Protocol.World.CRYSTAL, at, Vector2.ZERO, id))
	Events.pinged.connect(func(at: Vector2, kind: int, _from_runner: bool) -> void:
		_world(Protocol.World.MARK, at, Vector2.ZERO, kind))
	Events.hologram_revoked.connect(func(net_id: int) -> void:
		_send_event(Protocol.simple(Protocol.Msg.HOLO_KILL, net_id)))
	Events.spring_bounced.connect(func(at: Vector2) -> void:
		_world(Protocol.World.SPRING, at, Vector2.ZERO))
	# The guardian asked for this one, so of all the world events it is the one
	# they most need to see land on their own screen.
	Events.runner_launched.connect(func(at: Vector2) -> void:
		_world(Protocol.World.LAUNCH, at, Vector2.ZERO))
	# The guardian is the one who needs these two most, and both are decided
	# here: a refused shot is the difference between "aim at the other side"
	# and "I missed", and a wall kick is the runner answering the wall they
	# were given.
	# The soft spot's window, which the guardian cannot work out for themselves
	# -- and must not, because they are the one shooting at it.
	Events.weak_point_opened.connect(func(enemy: Node2D, until_tick: int) -> void:
		var id = enemy.get("net_id")
		if id != null and int(id) >= 0:
			_send_event(Protocol.weak_window(int(id), until_tick)))
	Events.shot_blocked.connect(func(at: Vector2) -> void:
		_world(Protocol.World.SHOT_BLOCKED, at, Vector2.ZERO))
	Events.runner_wall_jumped.connect(func(at: Vector2, away: int) -> void:
		_world(Protocol.World.WALL_JUMP, at, Vector2.ZERO, away))
	Events.rescue_scored.connect(func(tier: int, at: Vector2) -> void:
		_world(Protocol.World.RESCUE, at, Vector2.ZERO, tier))
	Events.stage_cleared.connect(func(_stats: Dictionary) -> void:
		_world(Protocol.World.STAGE_CLEAR, Vector2.ZERO, Vector2.ZERO))
	Events.hologram_expired.connect(func(kind: int) -> void:
		_world(Protocol.World.HOLO_EXPIRED, Vector2.ZERO, Vector2.ZERO, kind))

## A stage number a player can check against their own screen. The refusal has
## to name both sides or it is just "no".
func _stage_label(which: int) -> String:
	match which:
		Stage.Which.GREENFIELD: return "1-1"
		Stage.Which.CROSSING: return "1-C"
		Stage.Which.WORKSHOP: return "1-T"
		Stage.Which.HORROR: return "1-2"
		Stage.Which.QUIET: return "1-V"
		Stage.Which.KEEPER: return "1-B"
		Stage.Which.SKY: return "1-S"
		Stage.Which.SKYWARD_RUINS: return "1-3"
	return "?"

func _world(kind: int, a: Vector2, b: Vector2, value: int = 0,
		text: String = "") -> void:
	_send_event(Protocol.world(kind, a, b, value, text))

func _physics_process(delta: float) -> void:
	# See ClientSession: a freed world is a dangling reference, not null.
	if transport == null or not is_instance_valid(main):
		return
	for packet in transport.poll():
		_handle(packet)
	if remote_role == "runner":
		_remote_runner_silence += delta
		if _remote_runner_silence >= 0.25:
			# A lost unreliable release packet must never leave the runner walking,
			# jumping or dashing forever on the new authority.
			main.input_hub.drive_runner(0.0, 0.0, false, false)
	if Clock.tick % SNAPSHOT_EVERY == 0:
		transport.send(NetTransport.Channel.SNAPSHOT,
			NetTransport.Reliability.UNRELIABLE, _snapshot().encode())
	if Clock.tick % MigrationState.SEND_EVERY_TICKS == 0:
		_send_migration_frame()
	_send_boss()
	_reap_holograms()

func _send_migration_frame() -> void:
	if transport == null or not transport.is_connected_to_peer():
		return
	_migration_generation += 1
	var payload := MigrationState.capture(main)
	for chunk in MigrationState.chunks(payload, _migration_generation, Clock.tick):
		transport.send(NetTransport.Channel.MIGRATION,
			NetTransport.Reliability.RELIABLE_ORDERED, chunk)

## How often the boss repeats itself when nothing has changed, in ticks.
##
## Not because the state drifts -- it does not -- but because the packet also
## carries the shot clock on an open core, and a guardian whose only update
## arrived at the top of a 1.8s stagger would be aiming at a ring that had
## stopped moving. Half a second is well inside the shortest stagger.
const BOSS_HEARTBEAT: int = 30

var _boss_next: int = 0

## The one enemy whose state has to be told rather than shown.
##
## Everything else in the world is either in the snapshot (positions) or a pure
## function of the tick (platforms, lasers). The Keeper is neither: it decides
## things about the runner, and on the guardian's device its physics is switched
## off, so without this the player holding the rifle cannot tell a wind-up from
## a stagger -- which is the only thing they need to know. It is the same hole
## the shield-bearer shipped with, closed before it could be found by a player.
func _send_boss() -> void:
	for e in get_tree().get_nodes_in_group("keeper"):
		if not (e is Keeper):
			continue
		var boss: Keeper = e
		var id: int = boss.net_id
		if id < 0:
			continue
		if not boss.net_dirty() and Clock.tick < _boss_next:
			continue
		_boss_next = Clock.tick + BOSS_HEARTBEAT
		_send_event(Protocol.boss(id, boss.state, boss.hp, boss.timer_left(),
			boss.facing, boss.wounded_this_stagger))

# ------------------------------------------------------------------ outgoing

func _snapshot() -> Snapshot:
	var s := Snapshot.new()
	var r: Runner = main.runner
	s.tick = Clock.tick
	s.runner_position = r.global_position
	s.runner_velocity = r.velocity
	s.runner_state = int(r.state)
	s.movement_flags = r.movement_flags()
	s.facing = r.facing
	s.on_floor = r.is_on_floor()
	s.hp = r.hp
	s.gauge = main.guardian.gauge
	# Only what is near enough to matter, and only entities the client cannot
	# derive for itself. Lasers and moving platforms are tick functions and cost
	# nothing here -- that is what the determinism work bought.
	var here := r.global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or here.distance_to((e as Node2D).global_position) >= ENEMY_RADIUS:
			continue
		var id: int = int(e.get("net_id")) if e.get("net_id") != null else -1
		if id < 0:
			continue    # unnumbered is unaddressable; better absent than wrong
		s.dirty_enemies.append({
			"id": id, "x": (e as Node2D).global_position.x,
			"y": (e as Node2D).global_position.y,
			"hp": int(e.get("hp")) if e.has_method("get") and "hp" in e else 1,
		})
	return s

## Everything a client cannot work out for itself, replayed on the handshake.
##
## This is what makes reconnecting work, and it is deliberately not a new
## message: a HELLO is answered the same way whether it is the first one or the
## fifth, so the recovery path is the path that is exercised every single time
## anybody connects. A separate "resync" branch would be a branch that only runs
## when something has already gone wrong.
##
## Nothing else needs replaying. The runner, the enemies, the gauge and the hit
## points are all in the next snapshot, which is 33ms away; the moving platforms
## and lasers are functions of the tick and were never sent.
func _resync() -> void:
	# The whole set, as one list, rather than one spawn per construct.
	#
	# Replaying spawns could only ever ADD. A guardian whose link dropped for
	# four seconds still had every construct on their screen, so the replay gave
	# them a second copy of each -- and a second reconnect a third. Nothing in
	# the stream could remove the extras, correct a position, or say that a
	# launcher had already been fired while they were away. So this is state and
	# not history: what is in the list is what exists.
	var rows: Array = []
	for kind in [Hologram.Kind.PLATFORM, Hologram.Kind.WALL, Hologram.Kind.WARP]:
		for h in main.guardian.holograms_of(kind):
			if not is_instance_valid(h):
				continue
			rows.append({
				"net_id": h.net_id,
				"kind": int(h.kind),
				"at": h.global_position,
				"birth": h.birth_tick,
				"death": h.death_tick,
				"armed": h.trigger == null or h.trigger.armed,
			})
	_send_event(Protocol.holo_list(rows))
	# Which crystals are gone. One mask rather than one message each: a guardian
	# reconnecting near the end of a stage would otherwise get a burst, and a
	# mask is state rather than a list of events, so replaying it is harmless.
	_send_event(Protocol.crystals(GameState.crystal_mask()))
	# An open gate is the one piece of world state with no other route across.
	# A client that missed the switch being shot sees a wall it cannot pass and
	# a partner insisting it is open.
	for node in get_tree().get_nodes_in_group("switch"):
		if node.get("active"):
			_world(Protocol.World.SWITCH, Vector2.ZERO, Vector2.ZERO, 0,
				String(node.get("switch_id")))

func _send_event(payload: PackedByteArray) -> void:
	if transport != null:
		transport.send(NetTransport.Channel.EVENT,
			NetTransport.Reliability.RELIABLE_ORDERED, payload)

func announce_authority(epoch: int) -> void:
	_send_event(Protocol.authority_ready(epoch, Clock.tick))

## Constructs that expired on their own need no packet -- both sides know the
## death tick. This only catches the ones the cap recycled early.
func _reap_holograms() -> void:
	for kind in [Hologram.Kind.PLATFORM, Hologram.Kind.WALL, Hologram.Kind.WARP]:
		for h in main.guardian.holograms_of(kind):
			if h.net_id == 0:
				h.net_id = _next_holo_id
				_next_holo_id += 1

# ------------------------------------------------------------------ incoming

func _handle(packet: Dictionary) -> void:
	var parsed := Protocol.reader(packet["payload"])
	var kind: int = parsed[0]
	var b: StreamPeerBuffer = parsed[1]
	match kind:
		Protocol.Msg.HELLO:
			# Both devices have to be running the same build. The version was
			# being sent and never read, so two mismatched clients would connect,
			# misread each other's packets and fail in ways that look like
			# anything except "one of you needs to update".
			var their_version := b.get_u8()
			if their_version != Protocol.VERSION:
				_send_event(Protocol.notice(
					"バージョンが違います（相手 %d / こちら %d）。同じビルドを使ってください"
						% [their_version, Protocol.VERSION]))
				return
			# The client names itself in the same message that names its
			# version: one is "can we talk", the other is "who are you", and
			# a handshake that only answered the first could not tell a
			# returning player from a new one. See Party.
			# Which stage they built. Read before the name, in the order the
			# message puts them.
			var their_stage := b.get_u8()
			if their_stage != Stage.current():
				_send_event(Protocol.notice(
					"ステージが違います（相手 %s / こちら %s）。同じステージを選んでください"
						% [_stage_label(their_stage), _stage_label(Stage.current())]))
				return
			var role_code := b.get_u8()
			remote_role = "runner" if role_code == 1 else "guardian"
			if remote_role == local_role:
				_send_event(Protocol.notice("同じ役割では接続できません。片方ずつランナーとガーディアンを選んでください"))
				return
			var their_id := b.get_utf8_string()
			party.clear()
			party.seat(NetLink.client_id(), Party.ROLE_RUNNER \
				if local_role == "runner" else Party.ROLE_GUARDIAN)
			party.seat(their_id, Party.ROLE_RUNNER \
				if remote_role == "runner" else Party.ROLE_GUARDIAN)
			_send_event(Protocol.welcome(Clock.tick, NetLink.client_id()))
			_resync()
			if transport is EosTransport and transport.room != null:
				transport.room.call_deferred("mark_started")
			if is_instance_valid(main) and main.get("link") != null:
				main.link.enter(NetLink.Phase.PLAYING)
		Protocol.Msg.PING:
			transport.send(NetTransport.Channel.CONTROL,
				NetTransport.Reliability.RELIABLE_ORDERED,
				Protocol.pong(b.get_u32(), Clock.tick))
		Protocol.Msg.AIM:
			# Three samples per packet; the newest is first and the rest are
			# redundancy for a lost one, so only the newest is used.
			# A world point, because that is what the guardian sent and what the
			# runner's camera has to be able to move under without dragging the
			# ghost with it.
			main.input_hub.aim_at_world(Protocol.get_pos(b))
			# From here the runner's screen may draw the guardian's ghost: it is
			# now a live reading of where they are looking, not the place the
			# reticle happened to start.
			main.input_hub.remote_aim = true
		Protocol.Msg.RUNNER_INPUT:
			if remote_role != "runner":
				return
			_remote_runner_silence = 0.0
			var axis := float(b.get_8()) / 127.0
			var axis_y := float(b.get_8()) / 127.0
			var flags := b.get_u8()
			b.get_u16() # sequence is carried for tracing/redundancy evolution
			main.input_hub.drive_runner(axis, axis_y,
				(flags & 1) != 0, (flags & 2) != 0)
		Protocol.Msg.SLOT:
			main.guardian.select_slot(b.get_u8())
		Protocol.Msg.PLACE:
			_do_place(b)
		Protocol.Msg.FIRE:
			_do_fire(b)
		Protocol.Msg.UNDO:
			var undo_seq := b.get_u16()
			if not _seen_seq.has(undo_seq):
				_seen_seq[undo_seq] = true
				main.guardian.undo_last()
		Protocol.Msg.MARK:
			var at := Protocol.get_pos(b)
			# Raised locally so the runner sees it, and echoed so the guardian
			# sees their own mark land rather than guessing it arrived.
			Events.pinged.emit(at, int(b.get_u8()), false)

func _do_place(b: StreamPeerBuffer) -> void:
	var slot := b.get_u8()
	var at := Protocol.get_pos(b)
	var view_tick := int(b.get_u32())
	var seq := b.get_u16()
	if _seen_seq.has(seq):
		return
	_seen_seq[seq] = true

	var g: Guardian = main.guardian
	g.select_slot(slot)
	var ability: GuardianAbility = g.abilities[g.active_slot]
	var reason: String = ability.check(g, at)
	if reason != "":
		_send_event(Protocol.reject(seq, reason))
		return

	# The rescue. If the runner already fell past where this is going, put it
	# where the guardian saw it and let them have caught them -- but only if that
	# leaves the runner better off. Rewind.is_improvement enforces that.
	#
	# A warp gate is never backdated. The rewind exists to decide whether a
	# falling runner should have landed on a slab, and a gate is not something
	# you land on: replaying one into the past would teleport the runner from a
	# position they have already left.
	var birth := Clock.tick
	if slot != 4:
		var size: Vector2 = Balance.PLATFORM_SIZE if slot == 1 else Balance.WALL_SIZE
		birth = authority.accept_placement(at, size, view_tick)

	g.use_active(at)
	var made: Hologram = _newest(slot)
	if made == null:
		_send_event(Protocol.reject(seq, "refused"))
		return
	made.net_id = _next_holo_id
	_next_holo_id += 1
	# Backdating shortens the life rather than shifting it: the guardian spends
	# the same construct either way.
	made.birth_tick = birth
	made.death_tick = birth + Clock.ticks_for(made.lifetime)
	# NOT the backdated tick: the rescue grade is how late the guardian left it,
	# and they left it exactly as late as this packet arrived.
	made.placed_tick = Clock.tick
	_send_event(Protocol.holo_spawn(made.net_id, int(made.kind), at,
		made.birth_tick, made.death_tick, seq))

func _do_fire(b: StreamPeerBuffer) -> void:
	var at := Protocol.get_pos(b)
	var _view_tick := int(b.get_u32())
	var seq := b.get_u16()
	var target_id := int(b.get_u16())
	if _seen_seq.has(seq):
		return
	_seen_seq[seq] = true
	# The guardian named an enemy, so shoot THAT enemy, wherever it has got to
	# since. The point in the packet is where it stood on their screen, which
	# is a place this device left behind two snapshots ago -- resolving the
	# shot against it is how a shot that was plainly on target hit nothing.
	# If the named one is already dead the point still stands: something else
	# may be there, and if not the tracer needs somewhere to go.
	if target_id != Protocol.NO_TARGET:
		var named := _enemy_named(target_id)
		if named != null:
			at = named.global_position
	var g: Guardian = main.guardian
	g.select_slot(3)
	var reason: String = g.abilities[3].check(g, at)
	if reason != "":
		_send_event(Protocol.reject(seq, reason))
		return
	g.use_active(at)

func _enemy_named(id: int) -> Node2D:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node2D and e.get("net_id") != null and int(e.get("net_id")) == id:
			return e
	return null

func _newest(slot: int) -> Hologram:
	var list: Array = main.guardian.holograms_of(Hologram.kind_for_slot(slot))
	return list.back() if not list.is_empty() else null

