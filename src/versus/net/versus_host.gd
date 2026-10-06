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
## Which stage's art the arena is painted in; told to every guest.
var stage: int = VersusStageData.DEFAULT_THEME
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

## Each runner moves itself and reports where it is; the host does not
## re-simulate it, but it does refuse a report no runner could have made. The
## fastest anything in the arena throws a runner is a spring (about 1,100px/s),
## so twice that plus a little slack is never a real move. A report past it
## keeps the runner where it last was (for scoring and for everybody else's
## screen) -- unless it keeps happening for longer than a hiccup, which is a
## real jump the host did not foresee rather than a lie, and is then believed.
const MAX_REPORT_SPEED: float = 2400.0
## The limit in force; a scripted probe whose runners hop from point to point
## by design sets it to INF.
var max_report_speed: float = MAX_REPORT_SPEED
const REPORT_SLACK: float = 48.0
const REPORT_REJECT_LIMIT: int = 45
## How long a guest whose connection dropped keeps their seat and their
## stars: ten seconds, enough for a phone that went to its home screen or lost
## signal for a moment. Their runner stands where it was meanwhile.
const GRACE_FRAMES: int = 600
## Peer -> the token it said hello with (VersusProtocol.hello).
var _tokens: Dictionary = {}
## Peer -> the frame its seat is given up at, for guests whose link dropped.
var _away: Dictionary = {}

## Reports refused so far (for the probes and the diagnostic log).
var implausible_reports: int = 0
var _frame: int = 0
var _last_good: Dictionary = {}     ## seat -> {"at": Vector2, "frame": int}
var _rejected_run: Dictionary = {}  ## seat -> refusals in a row
var _trust_until: int = 0
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
	_last_good.clear()
	_rejected_run.clear()
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
	_frame += 1
	_take_post()
	_expire_away()

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
		if _away.has(roster.peer_at(seat)):
			# Waiting for someone whose link dropped: they stand where they
			# were, and nobody can take their stars off them meanwhile --
			# nor can they pick one up.
			var held := s.duplicate_seat()
			held.invulnerable = true
			held.can_act = false
			held.velocity = Vector2.ZERO
			return held
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
			VersusProtocol.Msg.HOLO, VersusProtocol.Msg.UNHOLO:
				_on_holo(from, payload)
			VersusProtocol.Msg.BYE:
				_on_bye(from, payload)

## A guest leaving. A goodbye frees the seat now; a dropped link in the
## middle of a match holds it for GRACE_FRAMES, in case they come back.
func _on_bye(from: int, payload: PackedByteArray) -> void:
	var said := int(payload[1]) if payload.size() > 1 else VersusProtocol.DROPPED
	diagnostic.emit("BYE peer=%d seat=%d" % [from, said])
	if said == VersusProtocol.DROPPED and (playing or countdown > 0) \
			and roster.seat_of(from) >= 0:
		_away[from] = _frame + GRACE_FRAMES
		diagnostic.emit("AWAY peer=%d seat=%d: holding it for %d frames" % [
			from, roster.seat_of(from), GRACE_FRAMES])
		return
	_vacate(from)

func _expire_away() -> void:
	for peer in _away.keys():
		if _frame >= int(_away[peer]):
			diagnostic.emit("AWAY peer=%d did not come back" % peer)
			_vacate(peer)

func _vacate(peer: int) -> void:
	_away.erase(peer)
	_tokens.erase(peer)
	var vacated := roster.vacate(peer)
	_reported.erase(vacated)
	_last_good.erase(vacated)
	# Whatever the leaver was holding goes back into play rather than staying
	# in an empty chair's hand for the rest of the match.
	if vacated >= 0 and roster.is_runner(vacated):
		var side := roster.side_of(vacated)
		if side < match_rules.sides:
			match_rules.return_hand(side)
			match_rules.seats[side].alive = false
	if roster.room_mode == VersusRoster.RoomMode.DUEL_COMBINED:
		playing = false

## Bit N set when seat N's guest has dropped and is being waited for.
func away_mask() -> int:
	var mask := 0
	for peer in _away.keys():
		for seat in range(roster.seat_count()):
			if roster.peer_at(seat) == int(peer):
				mask |= 1 << seat
	return mask

## The guest who said hello with `token` before, on a connection that is
## not `from`, or -1.
func _earlier_peer(token: int, from: int) -> int:
	if token == 0:
		return -1
	for peer in _tokens.keys():
		if int(peer) != from and int(_tokens[peer]) == token and roster.seat_of(int(peer)) >= 0:
			return int(peer)
	return -1

func _on_hello(from: int, payload: PackedByteArray) -> void:
	diagnostic.emit("HELLO peer=%d bytes=%d" % [from, payload.size()])
	# The version first, whatever the size: an older build's shorter hello
	# is told to update rather than that its packet is malformed.
	if payload.size() >= 3 and payload.decode_u16(1) != VersusProtocol.VERSION:
		diagnostic.emit("REJECT HELLO: version %d" % payload.decode_u16(1))
		transport.send_to(from, VersusTransport.Channel.CONTROL,
			VersusTransport.Reliability.RELIABLE, VersusProtocol.full("ゲームのバージョンまたは対戦モードが違います。両端末を同じAPKにしてください"))
		return
	if payload.size() != VersusProtocol.HELLO_BYTES:
		diagnostic.emit("REJECT HELLO: size != %d" % VersusProtocol.HELLO_BYTES)
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
	var token := int(hello["token"])
	var earlier := _earlier_peer(token, from)
	var seat := -1
	if earlier >= 0:
		# Back on a new connection: the same chair, the same stars.
		seat = roster.rebind(earlier, from)
		_away.erase(earlier)
		_tokens.erase(earlier)
		diagnostic.emit("REJOIN peer=%d was peer=%d seat=%d" % [from, earlier, seat])
	else:
		seat = roster.seat_peer(from, int(hello["wanted_seat"]))
	if seat >= 0 and token != 0:
		_tokens[from] = token
	if seat < 0:
		diagnostic.emit("REJECT HELLO: requested seat occupied/unavailable")
		transport.send_to(from, VersusTransport.Channel.CONTROL,
			VersusTransport.Reliability.RELIABLE, VersusProtocol.full("席が埋まっています。部屋番号と対戦モードを確認してください"))
		return
	diagnostic.emit("WELCOME peer=%d seat=%d unique_players=%d roster=%s (awaiting first runner INPUT)" % [
		from, seat, roster.peers_filled(), roster.describe()])
	transport.send_to(from, VersusTransport.Channel.CONTROL,
		VersusTransport.Reliability.RELIABLE,
		VersusProtocol.welcome(seat, seed_value, roster.room_mode, stage))
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
	s.position = _plausible(seat, m["position"], bool(m["alive"]))
	s.facing = int(m["facing"])
	s.alive = bool(m["alive"])
	s.can_act = bool(m["can_act"])
	s.invulnerable = bool(m["invulnerable"])
	s.strike_seq = int(m["strike_seq"])
	s.velocity = m["velocity"]
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

## Where the host takes `seat`'s runner to be, given what it just reported.
## Measured the short way round the loop, from the last report it believed.
## A runner who is down (or just got up) may be anywhere: respawning is a
## jump back to the start.
func _plausible(seat: int, at: Vector2, alive: bool) -> Vector2:
	var last: Dictionary = _last_good.get(seat, {})
	var was_down := _reported.has(seat) and not (_reported[seat] as VersusMatch.Seat).alive
	# Only in play: before the start and through a rematch's reset everybody
	# is put back at their start, which is a jump by design.
	if last.is_empty() or not alive or was_down or not playing or _frame < _trust_until:
		_believe(seat, at)
		return at
	var frames := maxi(1, _frame - int(last["frame"]))
	var from: Vector2 = last["at"]
	var moved := VersusStageData.nearest_image(at, from).distance_to(from)
	var allowed := max_report_speed * float(frames) / 60.0 + REPORT_SLACK
	if moved <= allowed:
		_believe(seat, at)
		return at
	var run := int(_rejected_run.get(seat, 0)) + 1
	if run > REPORT_REJECT_LIMIT:
		diagnostic.emit("REPORT seat=%d believed after %d refusals" % [seat, run - 1])
		_believe(seat, at)
		return at
	_rejected_run[seat] = run
	implausible_reports += 1
	if run == 1:
		diagnostic.emit("REPORT seat=%d refused: %.0fpx in %d frames" % [seat, moved, frames])
	return from

## Believe every seat's reports for the next half second, wherever they are:
## for whatever puts runners somewhere on purpose (a probe setting up a
## scene). A window rather than one report, because reports from before the
## move may still be on their way.
func forget_positions() -> void:
	_trust_until = _frame + 30
	_last_good.clear()
	_rejected_run.clear()

func _believe(seat: int, at: Vector2) -> void:
	_last_good[seat] = {"at": at, "frame": _frame}
	_rejected_run.erase(seat)

func _on_command(from: int, payload: PackedByteArray) -> void:
	if payload.size() != 11:
		return
	var c := VersusProtocol.read_command(payload)
	var seat := int(c["seat"])
	if not roster.owns_seat(from, seat):
		return
	var slot := int(c["slot"])
	if slot == 3:
		shoot(seat, c["at"])
		return
	if slot == 4:
		shoot_enemy(seat, int(round(Vector2(c["at"]).x)))
		return
	if not roster.can_build(seat):
		return
	if slot == 0:
		undo_build(seat)
		return
	place_build(seat, c["at"], slot)

## Platforms are each player's own co-op Guardian's; the host only passes
## them on, to everybody but the one who built it, and to its own scene.
## `holo_inbox` is what the host's scene has yet to build or remove.
var holo_inbox: Array[PackedByteArray] = []

func _on_holo(from: int, payload: PackedByteArray) -> void:
	if payload.size() < 4:
		return
	if not roster.owns_seat(from, int(payload[1])):
		return
	holo_inbox.append(payload)
	_relay(from, payload)

## The host's own platform, out to everybody.
func send_holo(payload: PackedByteArray) -> void:
	_relay(transport.local_peer(), payload)

func _relay(from: int, payload: PackedByteArray) -> void:
	var sent: Dictionary = {}
	for seat in range(roster.seat_count()):
		var peer := roster.peer_at(seat)
		if peer < 0 or peer == from or peer == transport.local_peer() or sent.has(peer):
			continue
		sent[peer] = true
		transport.send_to(peer, VersusTransport.Channel.COMMAND,
			VersusTransport.Reliability.RELIABLE, payload)

## A player's shot at `at`, from whichever seat fired it: a runner shoots for
## their own side, a 2v2 guardian for their team. Only while playing.
## `seat`'s rifle hit enemy `id` on their screen (COMMAND slot 4).
func shoot_enemy(seat: int, id: int) -> bool:
	if not playing or match_rules.phase != VersusMatch.Phase.PLAYING:
		return false
	return match_rules.shoot_enemy(roster.side_of(seat), id)

func shoot(seat: int, at: Vector2) -> int:
	if not playing or match_rules.phase != VersusMatch.Phase.PLAYING:
		return -1
	if is_nan(at.x) or is_nan(at.y) or is_inf(at.x) or is_inf(at.y):
		return -1
	return match_rules.shoot(roster.side_of(seat), at)

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
	# Stored in lap 0; every machine draws and collides it in all three.
	at = Vector2(VersusStageData.wrap_x(at.x), at.y)
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
			"position": s.position, "velocity": s.velocity,
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
		world_revision, epoch, countdown, seat_mask(), match_rules.enemy_down_mask(),
		away_mask(), match_rules.hit_log,
		match_rules.stats if match_rules.phase == VersusMatch.Phase.OVER else [])
	transport.broadcast(VersusTransport.Channel.SNAPSHOT,
		VersusTransport.Reliability.UNRELIABLE, payload)
