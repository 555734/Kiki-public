class_name VersusHost
extends RefCounted

signal diagnostic(message: String)
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
## False until the match is under way: while people are still arriving, and
## through the countdown. Nothing is scored and no star appears before it.
var playing: bool = false
## Matches played in this room. A rematch bumps it, and every client resets
## on seeing it change (VersusProtocol.snapshot).
var epoch: int = 0
## Ticks of "3, 2, 1" left, or 0.
var countdown: int = 0

## The newest thing each runner said about itself, by SEAT. Kept rather than
## consumed, so a dropped input packet leaves the last one standing instead of
## teleporting a runner to the origin.
var _reported: Dictionary = {}
var _input_seen: Dictionary = {}
## Platforms the guardians have built, shared by everyone.
var builds: Array[Dictionary] = []
## A revision changes on EVERY add/remove, including same-count replacements.
var world_revision: int = 0
var _next_build_id: int = 1
## Raised for the scene: things that want a noise or a flash.
var out_events: Array[Dictionary] = []

const SNAPSHOT_EVERY: int = 2       ## 30Hz over 60Hz physics, as the co-op does
## How many guardian constructs can exist at once, across both teams.
const MAX_BUILDS: int = 12
## Eight builders share one arena in a free-for-all, so a few more stand.
const FFA_MAX_BUILDS: int = 16

func max_builds() -> int:
	return FFA_MAX_BUILDS if roster.room_mode == VersusRoster.RoomMode.FREE_FOR_ALL \
		else MAX_BUILDS
var _since_snapshot: int = 0

func start(link: VersusTransport, collision: ArenaStage,
		match_seed: int = 0,
		selected_mode: int = VersusRoster.RoomMode.TEAM_SPLIT) -> void:
	transport = link
	world = collision
	seed_value = match_seed if match_seed != 0 \
		else int(Time.get_ticks_usec() & 0x7fffffff)
	match_rules = VersusMatch.new()
	roster = VersusRoster.new(selected_mode)
	match_rules.setup(world, seed_value, roster.side_count(),
		VersusRules.numbers_for(selected_mode, 2))
	# Nobody plays until the host says so (TEAM_SPLIT) or the other player has
	# reported in (DUEL). Starting the moment the room opened handed the host
	# free stars while the others were still typing the code.
	playing = false
	countdown = 0
	epoch = 0
	# The host takes the first runner's chair. It is a runner's device by
	# definition: the guardian has no body to simulate, so hosting from one
	# would mean both runners were remote and neither felt right.
	roster.seat_peer(transport.local_peer(), VersusRoster.SEAT_A_RUNNER)
	tick = 0
	builds.clear()
	world_revision = 0
	_next_build_id = 1
	_reported.clear()
	_input_seen.clear()
	_since_snapshot = 0
	out_events.clear()

## The host's start button. Both runners have to be seated -- a missing
## guardian is a handicap, a missing runner is no match -- and it only works
## once. Returns whether the countdown began.
func request_start(ticks: int = VersusRules.COUNTDOWN_TICKS) -> bool:
	if playing or countdown > 0 or not roster.can_play():
		return false
	if match_rules.phase != VersusMatch.Phase.PLAYING:
		return false
	_begin_countdown(ticks)
	diagnostic.emit("START requested: roster=%s" % roster.describe())
	return true

## The same room, the same seats, a fresh match. Everything the last match
## left behind -- the ledger, the constructs, the tick -- starts over, and the
## epoch tells every client to start over with it.
func restart_match(ticks: int = VersusRules.COUNTDOWN_TICKS) -> bool:
	if not roster.can_play():
		return false
	seed_value = int(Time.get_ticks_usec() & 0x7fffffff)
	match_rules = VersusMatch.new()
	match_rules.setup(world_without_builds(), seed_value, roster.side_count(),
		VersusRules.numbers_for(roster.room_mode, roster.peers_filled()))
	builds.clear()
	world_revision += 1
	_rebuild_world()
	tick = 0
	epoch = (epoch + 1) & 0xFF
	playing = false
	_begin_countdown(ticks)
	diagnostic.emit("REMATCH epoch=%d" % epoch)
	return true

func _begin_countdown(ticks: int) -> void:
	# How many stars lie loose depends on how many are playing, which is
	# only known now.
	match_rules.on_field = int(VersusRules.numbers_for(roster.room_mode,
		roster.peers_filled())["on_field"])
	countdown = maxi(ticks, 0)
	if countdown == 0:
		playing = true
	out_events.append({"kind": "countdown", "ticks": countdown})

func world_without_builds() -> ArenaStage:
	return ArenaStage.new(VersusStageData.collision_rects())

## True between the start button and the first tick of play.
func counting() -> bool:
	return countdown > 0

## One tick. `local` is the host's own runner, observed by its own scene.
func step(local: VersusMatch.Seat) -> void:
	_take_post()

	_reported[VersusRoster.SEAT_A_RUNNER] = local
	# A HELLO only proves a socket joined. The guest must report their
	# own runner once before the host can simulate either side. Otherwise
	# the first live snapshot marks the guest dead at an uninitialised pose.
	if not playing and countdown == 0 and roster.can_play() \
			and roster.room_mode == VersusRoster.RoomMode.DUEL_COMBINED \
			and _reported.has(VersusRoster.SEAT_B_RUNNER) \
			and match_rules.phase == VersusMatch.Phase.PLAYING:
		playing = true
		diagnostic.emit("START: guest first runner input received; host match begins")
	if countdown > 0:
		countdown -= 1
		if countdown == 0:
			playing = true
			diagnostic.emit("START: countdown over; match begins epoch=%d" % epoch)
	if not playing:
		out_events.clear()
		_since_snapshot += 1
		if _since_snapshot >= SNAPSHOT_EVERY:
			_since_snapshot = 0
			_broadcast_snapshot()
		return

	var observed: Array = []
	for team in range(match_rules.sides):
		var seat := roster.side_runner_seat(team)
		observed.append(_seat_for(seat, team))

	match_rules.step(observed)
	out_events = match_rules.events.duplicate()
	tick += 1

	_since_snapshot += 1
	if _since_snapshot >= SNAPSHOT_EVERY:
		_since_snapshot = 0
		_broadcast_snapshot()

## Where a team's runner is, as far as the host knows: its last report, or
## its start if it has not reported yet.
func reported_runner(team: int) -> VersusMatch.Seat:
	return _seat_for(roster.side_runner_seat(team), team)

## Bit N set when seat N is taken.
func seat_mask() -> int:
	var mask := 0
	for seat in range(roster.seat_count()):
		if roster.peer_at(seat) != -1:
			mask |= 1 << seat
	return mask

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
				diagnostic.emit("BYE peer=%d" % from)
				var vacated := roster.vacate(from)
				_reported.erase(vacated)
				# Whatever the leaver was holding goes back into play rather
				# than staying in an empty chair's hand for the rest of the
				# match.
				if vacated >= 0 and roster.is_runner(vacated):
					var side := roster.side_of(vacated)
					if side < match_rules.sides:
						match_rules.return_hand(side)
						match_rules.seats[side].alive = false
				if roster.room_mode == VersusRoster.RoomMode.DUEL_COMBINED:
					playing = false

func _on_hello(from: int, payload: PackedByteArray) -> void:
	diagnostic.emit("HELLO peer=%d bytes=%d" % [from, payload.size()])
	if payload.size() != 5:
		diagnostic.emit("REJECT HELLO: size != 5")
		transport.send_to(from, VersusTransport.Channel.CONTROL,
			VersusTransport.Reliability.RELIABLE, VersusProtocol.full("接続情報が不正です。両端末を更新してください"))
		return
	var hello := VersusProtocol.read_hello(payload)
	diagnostic.emit("HELLO version=%d mode=%d requested_seat=%d; expected v%d mode=%d" % [
		int(hello["version"]), int(hello["room_mode"]), int(hello["wanted_seat"]),
		VersusProtocol.VERSION, roster.room_mode])
	if int(hello["version"]) != VersusProtocol.VERSION \
			or int(hello["room_mode"]) != roster.room_mode:
		diagnostic.emit("REJECT HELLO: version or mode mismatch")
		# Refused by name rather than left to desynchronise. The co-op
		# handshake does the same and it is the reason a mismatched build is a
		# message instead of a mystery.
		transport.send_to(from, VersusTransport.Channel.CONTROL,
			VersusTransport.Reliability.RELIABLE, VersusProtocol.full("ゲームのバージョンまたは対戦モードが違います。両端末を同じAPKにしてください"))
		return
	var seat := roster.seat_peer(from, int(hello["wanted_seat"]))
	if seat < 0:
		diagnostic.emit("REJECT HELLO: requested seat occupied/unavailable")
		transport.send_to(from, VersusTransport.Channel.CONTROL,
			VersusTransport.Reliability.RELIABLE, VersusProtocol.full("席が埋まっています。部屋番号と対戦モードを確認してください"))
		return
	diagnostic.emit("WELCOME peer=%d seat=%d unique_players=%d roster=%s (awaiting first runner INPUT)" % [
		from, seat, roster.peers_filled(), roster.describe()])
	transport.send_to(from, VersusTransport.Channel.CONTROL,
		VersusTransport.Reliability.RELIABLE,
		VersusProtocol.welcome(seat, seed_value, roster.room_mode))
	out_events.append({"kind": "seated", "seat": seat, "peer": from})

func _on_input(from: int, payload: PackedByteArray) -> void:
	if payload.size() != 18:
		return
	var m := VersusProtocol.read_input(payload)
	var seat := int(m["seat"])
	# The seat the packet claims is NOT trusted; the seat the host gave that
	# peer is. Otherwise anyone on the link can report a position for anyone.
	if not roster.owns_seat(from, seat):
		return
	if not roster.is_runner(seat):
		return
	var s := VersusMatch.Seat.new()
	s.team = roster.side_of(seat)
	s.position = m["position"]
	s.facing = int(m["facing"])
	s.alive = bool(m["alive"])
	s.can_act = bool(m["can_act"])
	s.invulnerable = bool(m["invulnerable"])
	s.strike_seq = int(m["strike_seq"])
	# The remote scene cannot call our ledger directly. Return its hand once
	# on the alive -> dead edge, using the reported death position. Repeated
	# dead observations must not restart combat/respawn state every tick.
	if not s.alive and (not _reported.has(seat) or _reported[seat].alive):
		match_rules.seats[s.team] = s.duplicate_seat()
		match_rules.note_death(s.team)
	_reported[seat] = s
	if not _input_seen.has(seat):
		_input_seen[seat] = true
		diagnostic.emit("FIRST INPUT from peer=%d runner_seat=%d" % [from, seat])

func _on_command(from: int, payload: PackedByteArray) -> void:
	if payload.size() != 11:
		return
	var c := VersusProtocol.read_command(payload)
	var seat := int(c["seat"])
	if not roster.owns_seat(from, seat):
		return
	if not roster.can_build(seat):
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
	if not roster.can_build(seat) or slot not in [1, 2]:
		return false
	if is_nan(at.x) or is_nan(at.y) or is_inf(at.x) or is_inf(at.y):
		return false
	if not VersusStageData.in_bounds(at):
		return false
	if builds.size() >= max_builds():
		# A cap, so two guardians cannot pave the arena between them. The oldest
		# goes, which also makes a platform a temporary thing to plan around
		# rather than a permanent change to the map.
		builds.pop_front()
	# The guardian's own shapes, at the sizes the cooperative game tuned them
	# to. A versus-specific size would be a second number competing with the one
	# every stage's gaps were measured against.
	var size: Vector2 = Balance.WALL_SIZE if slot == 2 else Balance.PLATFORM_SIZE
	var rect := Rect2(at - size * 0.5, size)
	builds.append({"seat": seat, "rect": rect, "build_id": _next_build_id})
	_next_build_id += 1
	world_revision += 1
	_rebuild_world()
	out_events.append({"kind": "built", "seat": seat, "rect": rect})
	return true

## The last thing THIS guardian built, and only theirs -- undo is not a way to
## remove the other team's wall.
func undo_build(seat: int) -> bool:
	for i in range(builds.size() - 1, -1, -1):
		if int(builds[i]["seat"]) == seat:
			builds.remove_at(i)
			world_revision += 1
			_rebuild_world()
			out_events.append({"kind": "unbuilt", "seat": seat})
			return true
	return false

func _rebuild_world() -> void:
	var rects: Array[Rect2] = []
	for g in builds:
		rects.append(g["rect"])
	world = ArenaStage.new(VersusStageData.collision_rects(rects))
	match_rules.world = world

func _broadcast_snapshot() -> void:
	var runners: Array = []
	for team in range(match_rules.sides):
		# Before play the rules have not adopted anyone's position yet, so
		# describe what each runner last reported (or its start).
		var s: VersusMatch.Seat = match_rules.seats[team] if playing \
			else reported_runner(team)
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
		gs.append({"seat": g["seat"], "position": r.position, "size": r.size,
			"build_id": g["build_id"]})

	var phase_to_send := match_rules.phase
	if not playing:
		phase_to_send = VersusProtocol.PHASE_COUNTDOWN if countdown > 0 \
			else VersusProtocol.PHASE_WAITING
	var payload := VersusProtocol.snapshot(match_rules.tick,
		phase_to_send, match_rules.winner, runners, coins, gs,
		world_revision, epoch, countdown, seat_mask())
	transport.broadcast(VersusTransport.Channel.SNAPSHOT,
		VersusTransport.Reliability.UNRELIABLE, payload)
