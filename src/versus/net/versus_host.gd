class_name VersusHost
extends RefCounted
## The machine that decides. One of the two runners' devices.
##
## It owns exactly one thing: VersusMatch -- the ledger, whose strike landed,
## what the score is. It does NOT own where the runners are. Each runner
## simulates itself and reports, and the host adopts that, because the
## alternative puts a round trip between pressing right and moving right, and
## the mode is unplayable that way.
##
## That split is only possible because VersusMatch was written to take
## observations rather than to hold bodies. The host hands it four numbers per
## runner and gets back a list of things that happened; a rules engine that
## reached into a CharacterBody2D could not be driven from a packet.
##
## What this buys: every coin, every steal and every point is decided in one
## place, so the four screens cannot disagree about the score even when they
## disagree about a pixel.

var transport: VersusTransport = null
var roster := VersusRoster.new()
var match_rules: VersusMatch = null
var world: ArenaStage = null

var seed_value: int = 0
var tick: int = 0

## The newest thing each runner said about itself, by SEAT. Kept rather than
## consumed, so a dropped input packet leaves the last one standing instead of
## teleporting a runner to the origin.
var _reported: Dictionary = {}
## Platforms the guardians have built, shared by everyone.
var builds: Array[Dictionary] = []
## Raised for the scene: things that want a noise or a flash.
var out_events: Array[Dictionary] = []

const SNAPSHOT_EVERY: int = 2       ## 30Hz over 60Hz physics, as the co-op does
## How many guardian constructs can exist at once, across both teams.
const MAX_BUILDS: int = 12
var _since_snapshot: int = 0

func start(link: VersusTransport, collision: ArenaStage,
		match_seed: int = 0) -> void:
	transport = link
	world = collision
	seed_value = match_seed if match_seed != 0 \
		else int(Time.get_ticks_usec() & 0x7fffffff)
	match_rules = VersusMatch.new()
	match_rules.setup(world, seed_value)
	roster = VersusRoster.new()
	# The host takes the first runner's chair. It is a runner's device by
	# definition: the guardian has no body to simulate, so hosting from one
	# would mean both runners were remote and neither felt right.
	roster.seat_peer(transport.local_peer(), VersusRoster.SEAT_A_RUNNER)
	tick = 0
	builds.clear()
	out_events.clear()

## One tick. `local` is the host's own runner, observed by its own scene.
func step(local: VersusMatch.Seat) -> void:
	_take_post()

	_reported[VersusRoster.SEAT_A_RUNNER] = local

	var observed: Array = []
	for team in range(2):
		var seat := VersusRoster.runner_seat(team)
		observed.append(_seat_for(seat, team))

	match_rules.step(observed)
	out_events = match_rules.events.duplicate()
	tick += 1

	_since_snapshot += 1
	if _since_snapshot >= SNAPSHOT_EVERY:
		_since_snapshot = 0
		_broadcast_snapshot()

## An absent or silent runner stands still rather than vanishing. A match with
## a missing seat is a handicap, not a crash.
func _seat_for(seat: int, team: int) -> VersusMatch.Seat:
	if _reported.has(seat):
		var s: VersusMatch.Seat = _reported[seat]
		s.team = team
		return s
	var idle := VersusMatch.Seat.new()
	idle.team = team
	idle.position = VersusStageData.start_positions()[team]
	idle.facing = VersusStageData.start_facing()[team]
	idle.alive = false
	idle.can_act = false
	return idle

func _take_post() -> void:
	for packet in transport.poll():
		var payload: PackedByteArray = packet["payload"]
		var from: int = packet["from"]
		match VersusProtocol.kind_of(payload):
			VersusProtocol.Msg.HELLO:
				_on_hello(from, payload)
			VersusProtocol.Msg.INPUT:
				_on_input(from, payload)
			VersusProtocol.Msg.COMMAND:
				_on_command(from, payload)
			VersusProtocol.Msg.BYE:
				roster.vacate(from)

func _on_hello(from: int, payload: PackedByteArray) -> void:
	var hello := VersusProtocol.read_hello(payload)
	if int(hello["version"]) != VersusProtocol.VERSION:
		# Refused by name rather than left to desynchronise. The co-op
		# handshake does the same and it is the reason a mismatched build is a
		# message instead of a mystery.
		transport.send_to(from, VersusTransport.Channel.CONTROL,
			VersusTransport.Reliability.RELIABLE, VersusProtocol.full())
		return
	var seat := roster.seat_peer(from, int(hello["wanted_seat"]))
	if seat < 0:
		transport.send_to(from, VersusTransport.Channel.CONTROL,
			VersusTransport.Reliability.RELIABLE, VersusProtocol.full())
		return
	transport.send_to(from, VersusTransport.Channel.CONTROL,
		VersusTransport.Reliability.RELIABLE,
		VersusProtocol.welcome(seat, seed_value))
	out_events.append({"kind": "seated", "seat": seat, "peer": from})

func _on_input(from: int, payload: PackedByteArray) -> void:
	var m := VersusProtocol.read_input(payload)
	var seat := roster.seat_of(from)
	# The seat the packet claims is NOT trusted; the seat the host gave that
	# peer is. Otherwise anyone on the link can report a position for anyone.
	if seat < 0 or seat != int(m["seat"]):
		return
	if VersusRoster.role_of(seat) != VersusRoster.Role.RUNNER:
		return
	var s := VersusMatch.Seat.new()
	s.team = VersusRoster.team_of(seat)
	s.position = m["position"]
	s.facing = int(m["facing"])
	s.alive = bool(m["alive"])
	s.can_act = bool(m["can_act"])
	s.invulnerable = bool(m["invulnerable"])
	s.strike_seq = int(m["strike_seq"])
	_reported[seat] = s

func _on_command(from: int, payload: PackedByteArray) -> void:
	var c := VersusProtocol.read_command(payload)
	var seat := roster.seat_of(from)
	if seat < 0 or seat != int(c["seat"]):
		return
	if VersusRoster.role_of(seat) != VersusRoster.Role.GUARDIAN:
		return
	var slot := int(c["slot"])
	if slot == 0:
		undo_build(seat)
		return
	place_build(seat, c["at"], slot)

## A guardian's platform. The host is the one that decides it exists, and the
## collision world everyone's coins and runners use is updated here -- so a
## platform is a real floor for both teams the moment it appears, not a picture
## on one screen.
func place_build(seat: int, at: Vector2, slot: int = 1) -> bool:
	if not VersusStageData.in_bounds(at):
		return false
	if builds.size() >= MAX_BUILDS:
		# A cap, so two guardians cannot pave the arena between them. The oldest
		# goes, which also makes a platform a temporary thing to plan around
		# rather than a permanent change to the map.
		builds.pop_front()
	# The guardian's own shapes, at the sizes the cooperative game tuned them
	# to. A versus-specific size would be a second number competing with the one
	# every stage's gaps were measured against.
	var size: Vector2 = Balance.WALL_SIZE if slot == 2 else Balance.PLATFORM_SIZE
	var rect := Rect2(at - size * 0.5, size)
	builds.append({"seat": seat, "rect": rect})
	_rebuild_world()
	out_events.append({"kind": "built", "seat": seat, "rect": rect})
	return true

## The last thing THIS guardian built, and only theirs -- undo is not a way to
## remove the other team's wall.
func undo_build(seat: int) -> bool:
	for i in range(builds.size() - 1, -1, -1):
		if int(builds[i]["seat"]) == seat:
			builds.remove_at(i)
			_rebuild_world()
			out_events.append({"kind": "unbuilt", "seat": seat})
			return true
	return false

func _rebuild_world() -> void:
	# Stage.ground() answers for whichever stage is selected, and the coin match
	# is played on 1-1. Said here rather than assumed, because a host that had
	# just been in a different stage would otherwise build the wrong floor.
	Stage.use(Stage.Which.GREENFIELD)
	var rects: Array[Rect2] = Stage.ground()
	rects.append_array(Stage.solid_decor())
	for g in builds:
		rects.append(g["rect"])
	world = ArenaStage.new(rects)
	match_rules.world = world

func _broadcast_snapshot() -> void:
	var runners: Array = []
	for team in range(2):
		var s: VersusMatch.Seat = match_rules.seats[team]
		var c: ArenaCombat.CombatState = match_rules.combat[team]
		runners.append({
			"position": s.position, "velocity": Vector2.ZERO,
			"facing": s.facing, "alive": s.alive, "can_act": s.can_act,
			"invulnerable": s.invulnerable, "on_floor": false, "hp": 0,
			"combat_phase": c.phase, "combat_dir": c.attack_dir,
		})
	var coins: Array = []
	for c in match_rules.ledger.coins:
		coins.append({"id": c.coin_id, "state": c.state, "owner": c.owner,
			"position": c.position})
	var gs: Array = []
	for g in builds:
		var r: Rect2 = g["rect"]
		gs.append({"seat": g["seat"], "position": r.position, "size": r.size})

	var payload := VersusProtocol.snapshot(match_rules.tick,
		match_rules.phase, match_rules.winner, runners, coins, gs)
	transport.broadcast(VersusTransport.Channel.SNAPSHOT,
		VersusTransport.Reliability.UNRELIABLE, payload)
