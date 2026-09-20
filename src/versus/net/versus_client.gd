class_name VersusClient
extends RefCounted

signal diagnostic(message: String)
## A machine that is not the host: the other runner, or either guardian.
##
## It simulates exactly one thing -- its own runner, if it has one -- and
## believes the host about everything else. That is the trade this mode is
## built on: your own controls answer instantly because nothing is asked of the
## network before you move, and the score is never in dispute because you do
## not compute it.
##
## What arrives is applied rather than replayed. The cooperative client
## interpolates the host's runner between snapshots (src/net/client_session.gd
## :287-337) and that is right there, where the runner is somebody else's
## character entirely. Here the remote runner is the opponent, 30Hz of position
## is what there is, and the scene smooths it.

var transport: VersusTransport = null
var seat: int = -1
var seed_value: int = 0
var connected: bool = false
var refused: bool = false
var refusal_reason: String = ""
var room_mode: int = VersusRoster.RoomMode.TEAM_SPLIT

## The last world the host described. Everything the scene draws that is not
## the local runner comes from here.
var world_tick: int = 0
var phase: int = VersusMatch.Phase.PLAYING
var winner: int = -1
var coins: Array = []
var runners: Array = []
var builds: Array = []
var world_revision: int = -1
## True once a snapshot has ever arrived. Before that there is nothing to draw
## and the scene should say "waiting" rather than draw an empty world.
var seen_world: bool = false
## How many snapshots arrived older than the one already held. Counted rather
## than merely dropped, so a probe can prove the reordering it is testing for
## actually happened -- a guard that is never exercised is not tested.
var stale_dropped: int = 0

var _hello_every: int = 0

func start(link: VersusTransport, wanted_seat: int = -1,
		selected_mode: int = VersusRoster.RoomMode.TEAM_SPLIT) -> void:
	room_mode = selected_mode
	transport = link
	seat = -1
	connected = false
	refused = false
	refusal_reason = ""
	seen_world = false
	world_revision = -1
	world_tick = 0
	builds.clear()
	coins.clear()
	runners.clear()
	stale_dropped = 0
	_hello_every = 0
	diagnostic.emit("CLIENT start mode=%d wanted_seat=%d" % [room_mode, wanted_seat])
	_say_hello(wanted_seat)

func _say_hello(wanted_seat: int) -> void:
	diagnostic.emit("SEND HELLO version=%d mode=%d seat=%d" % [
		VersusProtocol.VERSION, room_mode, wanted_seat])
	transport.send_to(VersusTransport.HOST_PEER,
		VersusTransport.Channel.CONTROL,
		VersusTransport.Reliability.RELIABLE,
		VersusProtocol.hello(wanted_seat, room_mode))

## One tick. `local` is this machine's own runner as its own scene sees it, or
## null for a guardian.
func step(local, wanted_seat: int = -1) -> void:
	_take_post()

	if not connected:
		# Keep asking. A HELLO sent before the host was listening is the
		# ordinary case when four people press start at slightly different
		# moments, and a client that asked once would sit out the match.
		_hello_every += 1
		if _hello_every >= 30 and not refused:
			_hello_every = 0
			_say_hello(wanted_seat)
		return

	if local != null and VersusRoster.role_of(seat) == VersusRoster.Role.RUNNER:
		var s: VersusMatch.Seat = local
		transport.send_to(VersusTransport.HOST_PEER,
			VersusTransport.Channel.INPUT,
			VersusTransport.Reliability.UNRELIABLE,
			VersusProtocol.input(seat, world_tick, s.position, Vector2.ZERO,
				s.facing, s.alive, s.can_act, s.invulnerable, false, 0,
				s.strike_seq))

## Ask the host to build. Sent reliably: a lost platform is a guardian who
## spent their gauge on nothing.
func request_build(at: Vector2, slot: int = 1) -> void:
	if not connected:
		return
	var guardian_seat := seat + 1 if room_mode == VersusRoster.RoomMode.DUEL_COMBINED else seat
	if VersusRoster.role_of(guardian_seat) != VersusRoster.Role.GUARDIAN:
		return
	transport.send_to(VersusTransport.HOST_PEER,
		VersusTransport.Channel.COMMAND,
		VersusTransport.Reliability.RELIABLE,
		VersusProtocol.command(guardian_seat, world_tick, slot, at))

## Take the last one back. Slot 0 is the undo, which keeps it to one message
## kind rather than two that differ by a bool.
func request_undo() -> void:
	if not connected:
		return
	var guardian_seat := seat + 1 if room_mode == VersusRoster.RoomMode.DUEL_COMBINED else seat
	if VersusRoster.role_of(guardian_seat) != VersusRoster.Role.GUARDIAN:
		return
	transport.send_to(VersusTransport.HOST_PEER,
		VersusTransport.Channel.COMMAND,
		VersusTransport.Reliability.RELIABLE,
		VersusProtocol.command(guardian_seat, world_tick, 0, Vector2.ZERO))

func _take_post() -> void:
	for packet in transport.poll():
		if int(packet["from"]) != VersusTransport.HOST_PEER:
			continue
		var payload: PackedByteArray = packet["payload"]
		match VersusProtocol.kind_of(payload):
			VersusProtocol.Msg.WELCOME:
				if payload.size() != 7:
					diagnostic.emit("WELCOME unexpected bytes=%d" % payload.size())
					continue
				var w := VersusProtocol.read_welcome(payload)
				if int(w["room_mode"]) != room_mode:
					refused = true
					refusal_reason = "対戦モードが一致しません"
					diagnostic.emit("WELCOME room mode mismatch")
					continue
				seat = int(w["seat"])
				seed_value = int(w["seed"])
				connected = true
				diagnostic.emit("WELCOME confirmed seat=%d seed=%d mode=%d" % [
					seat, seed_value, room_mode])
			VersusProtocol.Msg.FULL:
				refused = true
				refusal_reason = VersusProtocol.read_full_reason(payload)
				diagnostic.emit("REFUSED: " + refusal_reason)
			VersusProtocol.Msg.SNAPSHOT:
				_absorb(payload)

func _absorb(payload: PackedByteArray) -> void:
	var s := VersusProtocol.read_snapshot(payload)
	# Older than what we already have. Snapshots are unreliable and jitter
	# reorders them, so a late one must not undo a newer one.
	var next_tick := int(s["tick"])
	var next_phase := int(s["phase"])
	if not seen_world or next_phase != phase:
		diagnostic.emit("SNAPSHOT tick=%d phase=%d (was=%d) coins=%d" % [
			next_tick, next_phase, phase, s["coins"].size()])
	# START may follow a waiting snapshot at the same game tick (zero), because
	# the match clock is intentionally stopped while waiting. Never suppress
	# that transition; equally, do not let a delayed waiting packet undo START.
	if seen_world and (next_tick < world_tick or (next_tick == world_tick \
			and (next_phase == phase or (phase != 2 and next_phase == 2)))):
		stale_dropped += 1
		return
	world_tick = int(s["tick"])
	phase = int(s["phase"])
	winner = int(s["winner"])
	runners = s["runners"]
	coins = s["coins"]
	builds = s["builds"]
	world_revision = int(s["world_revision"])
	seen_world = true

## The collision world the host says exists, including whatever the guardians
## have built. A client needs it so its own runner stands on the same platforms
## everyone else can see.
func collision() -> ArenaStage:
	var rects: Array[Rect2] = []
	for g in builds:
		rects.append(Rect2(g["position"], g["size"]))
	return ArenaStage.new(VersusStageData.collision_rects(rects))

## The score, derived from the host's coins exactly as the host derives it. Not
## a number sent over the wire: if it were, a lost packet could leave a screen
## showing a total that its own coins do not add up to.
func score(team: int) -> int:
	var n := 0
	for c in coins:
		if int(c["state"]) == ArenaCoin.State.HELD and int(c["owner"]) == team:
			n += 1
	return n
