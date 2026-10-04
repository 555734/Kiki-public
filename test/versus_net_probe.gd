extends Node
## Do four machines agree about one match?
##
## Built on the cooperative agreement_probe's method, which is the repo's
## answer to testing a network without one: no sockets, no relay, no second
## process -- four worlds in one process, joined by a loopback mesh with a
## latency, jitter and loss model, driven deterministically so a failure fails
## every time.
##
## The claim under test is the one the whole design rests on: the host decides
## the contest, and the other three believe it. If that holds, four screens
## cannot show four different scores. So the assertion is not "the packets
## arrived" -- it is "every peer's derived score equals the host's, on every
## tick, while packets are being dropped".

var failures: Array[String] = []
var _current: String = ""

func check(ok: bool, label: String) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		failures.append("%s: %s" % [_current, label])
		print("  FAIL  %s" % label)

func _ready() -> void:
	_test_the_wire()
	_test_waiting_transition()
	_test_seating()
	_test_agreement()
	_test_reordering()
	_test_a_lost_peer()
	_test_the_guardian()
	_test_duel_combined()
	_test_duel_ready_requires_first_input()
	_test_input_isolation()
	_test_build_revisions()
	_test_start_and_rematch()
	_test_eos_peer_ids()
	_test_free_for_all()
	_test_enemies_on_the_wire()

	print("versus net probe: %d checks failed" % failures.size())
	if failures.is_empty():
		print("four machines agree about one match")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("versus net probe: " + f)
		get_tree().quit(1)

# ------------------------------------------------------------------ enemies
## Where an enemy is never travels (it is a function of the tick); whether it
## is down does, in every snapshot. A guest's rifle hit is a request, and the
## host decides.
func _test_enemies_on_the_wire() -> void:
	_current = "enemies on the wire"
	var back := VersusProtocol.read_snapshot(VersusProtocol.snapshot(9, 0, -1, [], [], [],
		0, 0, 0, 0, 0b1010_0000_0000_0000_0000_0000_0000_0101))
	check(int(back["enemy_mask"]) == 0b1010_0000_0000_0000_0000_0000_0000_0101,
		"a snapshot carries all 32 enemy bits")
	var mesh := VersusLoopback.mesh(2, 0.02, 0.0, 0.0, 99)
	var host := VersusHost.new()
	host.start(mesh[0], _world(), 2024)
	var guest := VersusClient.new()
	guest.start(mesh[1], VersusRoster.SEAT_B_RUNNER)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var delta := 1.0 / 60.0
	var tick := 0
	var step := func() -> void:
		for m in mesh:
			m.advance(delta)
		var seat := VersusMatch.Seat.new()
		seat.team = 0
		seat.position = VersusStageData.start_positions()[0]
		seat.alive = true
		seat.can_act = true
		host.step(seat)
		host.request_start(0)
		var mine := VersusMatch.Seat.new()
		mine.team = 1
		mine.position = VersusStageData.start_positions()[1]
		mine.alive = true
		mine.can_act = true
		guest.step(mine)
	for t in range(300):
		step.call()
	check(host.playing and guest.connected, "the match is on (playing=%s)" % host.playing)
	check(guest.enemy_mask == 0, "every enemy starts up on the guest's screen too")
	guest.request_enemy_shot(1)
	for t in range(20):
		step.call()
	check(not host.match_rules.enemy_alive(1), "a guest's shot at enemy 1 downs it on the host")
	check((guest.enemy_mask >> 1) & 1 == 1 and guest.enemy_mask & ~0b10 == 0,
		"and the guest sees that one down, and only that one (mask %d)" % guest.enemy_mask)
	for t in range(VersusRules.ENEMY_DOWN_TICKS + 30):
		step.call()
	check(guest.enemy_mask == 0, "and back up again when the host says so")

# -------------------------------------------------------------------- format
## Everything that goes on the wire has to come back off it unchanged. Checked
## first because every later failure would otherwise have two possible causes.
func _test_the_wire() -> void:
	_current = "the wire"
	var at := Vector2(7361.0, 238.0)
	var vel := Vector2(-412.5, 97.25)
	var packed := VersusProtocol.input(2, 1234, at, vel, -1, true, false, true,
		true, 2, 77)
	var back := VersusProtocol.read_input(packed)
	check(back["seat"] == 2 and back["tick"] == 1234, "an input keeps its seat and tick")
	check(back["position"] == at, "and its position to the pixel")
	check(back["velocity"].distance_to(vel) < 0.2,
		"and its velocity to an eighth of a pixel")
	check(back["facing"] == -1 and back["alive"] and not back["can_act"]
			and back["invulnerable"] and back["on_floor"],
		"and all five of its yes/no answers")
	check(back["hp"] == 2 and back["strike_seq"] == 77,
		"and the health and the strike count")
	var w := VersusProtocol.read_welcome(VersusProtocol.welcome(5, 99, 2,
		Stage.Which.SKYWARD_RUINS))
	check(w["seat"] == 5 and w["seed"] == 99 and w["room_mode"] == 2
			and w["stage"] == Stage.Which.SKYWARD_RUINS,
		"a welcome carries the chair, the seed, the mode and the host's stage")
	var path := PackedVector2Array([Vector2(-80, 4), Vector2(0, -6), Vector2(80, 3)])
	var h := VersusProtocol.read_holo(VersusProtocol.holo(6, 513,
		Hologram.Kind.PLATFORM, Vector2(2100.5, 240.25), path))
	check(h["seat"] == 6 and h["holo_id"] == 513 and h["kind"] == Hologram.Kind.PLATFORM
			and Vector2(h["at"]).distance_to(Vector2(2100.5, 240.25)) < 0.5
			and h["path"].size() == 3
			and Vector2(h["path"][2]).distance_to(Vector2(80, 3)) < 0.5,
		"a platform travels with its owner, id, kind, place and traced shape")
	var u := VersusProtocol.read_unholo(VersusProtocol.unholo(3, 70))
	check(u["seat"] == 3 and u["holo_id"] == 70, "and so does its end")

	var runners: Array = []
	for i in range(2):
		runners.append({"position": Vector2(6500 + i * 900, 200),
			"velocity": Vector2(10, -20), "facing": 1, "alive": true,
			"can_act": true, "invulnerable": false, "on_floor": true, "hp": 2,
			"combat_phase": 2, "combat_dir": -1})
	var coins: Array = []
	for i in range(VersusRules.COIN_TOTAL):
		coins.append({"id": i, "state": i % 4, "owner": (i % 3) - 1,
			"position": Vector2(7000 + i, 300 - i)})
	var builds := [{"build_id": 99, "seat": 1, "position": Vector2(7100, 120),
		"size": Balance.PLATFORM_SIZE}]
	var snap := VersusProtocol.snapshot(999, 0, -1, runners, coins, builds, 42,
		3, 125, 0b0101)
	var s := VersusProtocol.read_snapshot(snap)
	check(s["epoch"] == 3 and s["countdown"] == 125 and s["seat_mask"] == 0b0101,
		"and the rematch epoch, the countdown and who is seated")
	check(s["tick"] == 999 and s["winner"] == -1, "a snapshot keeps its clock")
	check(s["coins"].size() == VersusRules.COIN_TOTAL,
		"and all %d coins" % VersusRules.COIN_TOTAL)
	var same := true
	for i in range(coins.size()):
		if int(s["coins"][i]["owner"]) != int(coins[i]["owner"]) \
				or int(s["coins"][i]["state"]) != int(coins[i]["state"]):
			same = false
	check(same, "with every state and owner intact")
	check(s["builds"].size() == 1 and s["builds"][0]["size"] == Balance.PLATFORM_SIZE,
		"and the guardian's platform")

	check(s["world_revision"] == 42 and s["builds"][0]["build_id"] == 99,
		"and the world revision and stable build identity")

	# The budget the plan set. A full match has to fit the relay's packet cap
	# with room to spare, or the mode does not work on the internet at all.
	print("    a full snapshot is %d bytes (cap %d)"
		% [snap.size(), VersusTransport.MAX_PACKET_BYTES])
	check(snap.size() <= 768,
		"a full snapshot fits the 768-byte budget (%d)" % snap.size())
	check(snap.size() < VersusEosTransport.PAYLOAD_LIMIT,
		"and the EOS packet cap (%d)" % VersusEosTransport.PAYLOAD_LIMIT)

# --------------------------------------------------------- waiting transition
## The host intentionally freezes the match tick while waiting. START at tick
## zero still has to replace a previous waiting snapshot at tick zero.
func _test_waiting_transition() -> void:
	_current = "wait -> start at the same host tick"
	var c := VersusClient.new()
	var runners: Array = []
	for i in range(2):
		runners.append({"position": Vector2.ZERO, "velocity": Vector2.ZERO,
			"facing": 1, "alive": false, "can_act": false,
			"invulnerable": false, "on_floor": false, "hp": 2,
			"combat_phase": 0, "combat_dir": 0})
	c._absorb(VersusProtocol.snapshot(0, 2, -1, runners, [], []))
	check(c.seen_world and c.phase == 2, "initial waiting state is received")
	c._absorb(VersusProtocol.snapshot(0, VersusMatch.Phase.PLAYING,
		-1, runners, [], []))
	check(c.phase == VersusMatch.Phase.PLAYING,
		"START at tick zero clears the waiting overlay")
	c._absorb(VersusProtocol.snapshot(0, 2, -1, runners, [], []))
	check(c.phase == VersusMatch.Phase.PLAYING,
		"a delayed waiting packet cannot re-freeze a started match")
	check(VersusProtocol.read_full_reason(VersusProtocol.full("version mismatch"))
		== "version mismatch", "joining failure explains the reason")
	check(VersusProtocol.read_full_reason(VersusProtocol.full()).is_empty(),
		"legacy one-byte refusal remains decodable")

# ------------------------------------------------------------------- seating
func _test_seating() -> void:
	_current = "seating"
	var r := VersusRoster.new()
	check(r.seat_peer(10, VersusRoster.SEAT_A_RUNNER) == 0, "the host takes seat A-runner")
	check(r.seat_peer(11, VersusRoster.SEAT_B_RUNNER) == 2, "the other runner takes B")
	check(r.seat_peer(12, VersusRoster.SEAT_A_GUARDIAN) == 1, "a guardian sits with its team")
	check(r.seat_peer(13, VersusRoster.SEAT_B_GUARDIAN) == 3, "and so does the other")
	check(r.is_full() and r.can_play(), "four seats is a match")
	check(r.seat_peer(14) == -1, "and a fifth is turned away")

	# The point of keeping peer and seat apart: a reconnect is a new peer id
	# and the same chair.
	check(r.seat_peer(11) == 2, "a peer already seated keeps its chair")
	r.vacate(11)
	check(not r.can_play(), "losing a runner stops the match being playable")
	check(r.seat_peer(99, VersusRoster.SEAT_B_RUNNER) == 2,
		"and the seat is there for whoever comes back to it")

	check(VersusRoster.team_of(VersusRoster.SEAT_B_GUARDIAN) == 1
			and VersusRoster.role_of(VersusRoster.SEAT_B_GUARDIAN)
				== VersusRoster.Role.GUARDIAN,
		"seat 3 is team B's guardian")

# ----------------------------------------------------------------- agreement
## The whole claim, under a link that is losing packets.
func _test_agreement() -> void:
	_current = "agreement"
	var mesh := VersusLoopback.mesh(4, 0.045, 0.06, 0.012, 777)
	var world := _world()
	var host := VersusHost.new()
	host.start(mesh[0], world, 31337)

	var clients: Array[VersusClient] = []
	for i in range(1, 4):
		var c := VersusClient.new()
		# 1 -> B runner, 2 and 3 -> the two guardians.
		var want := VersusRoster.SEAT_B_RUNNER if i == 1 \
			else (VersusRoster.SEAT_A_GUARDIAN if i == 2
				else VersusRoster.SEAT_B_GUARDIAN)
		c.start(mesh[i], want)
		clients.append(c)

	var rng := RandomNumberGenerator.new()
	rng.seed = 24680
	var delta := 1.0 / 60.0
	var disagreed := -1
	var compared := 0
	var best := 0
	# What the host's score WAS at each of its ticks. A client is always a few
	# ticks behind -- 30Hz snapshots plus a 45ms link -- so its numbers can
	# never be compared against the host's numbers right now. This is the
	# agreement_probe's method: record the truth as it happens, and hold the
	# client against the truth at the tick it was actually told about.
	var truth: Dictionary = {}

	for t in range(2400):
		for m in mesh:
			m.advance(delta)

		host.step(_moving_seat(0, t, rng))
		host.request_start(0)
		truth[host.match_rules.tick] = [host.match_rules.score(0),
			host.match_rules.score(1)]
		best = maxi(best, maxi(host.match_rules.score(0),
			host.match_rules.score(1)))
		for i in range(clients.size()):
			var local = _moving_seat(1, t, rng) if i == 0 else null
			clients[i].step(local)

		for c in clients:
			if not c.seen_world:
				continue
			if c.world_tick > host.match_rules.tick and disagreed < 0:
				disagreed = t
			if c.coins.size() != VersusRules.COIN_TOTAL and disagreed < 0:
				disagreed = t
			if not truth.has(c.world_tick):
				continue
			var was: Array = truth[c.world_tick]
			compared += 1
			if c.score(0) != int(was[0]) or c.score(1) != int(was[1]):
				if disagreed < 0:
					disagreed = t

	print("    %d score comparisons, highest score reached %d" % [compared, best])

	check(clients[0].connected and clients[1].connected and clients[2].connected,
		"all three clients are seated through 6% packet loss")
	check(clients[0].seat == VersusRoster.SEAT_B_RUNNER,
		"the second runner got the runner's chair")
	check(best > 0 and compared > 1000,
		"coins changed hands and the comparison ran %d times" % compared)
	check(disagreed < 0,
		"and on every tick the two shared, every client derived the host's score")

	# The real assertion: the derived score matches, everywhere.
	# Let the wire go quiet, then everyone should be looking at the same world.
	for t in range(60):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, 2400 + t, rng))
		for i in range(clients.size()):
			clients[i].step(_moving_seat(1, 2400 + t, rng) if i == 0 else null)
	var host_a := host.match_rules.score(0)
	var host_b := host.match_rules.score(1)
	var all_agree := true
	for c in clients:
		if c.score(0) != host_a or c.score(1) != host_b:
			all_agree = false
	print("    final score %d - %d, seen by %d clients" % [host_a, host_b, clients.size()])
	check(all_agree,
		"and once the wire is quiet every client has the host's score exactly")

	# And a negative control on the comparison itself: if it could not tell two
	# scores apart it would pass for the wrong reason.
	# Every coin in one team's hand, which no real match can produce while the
	# other team is also scoring. The first version flipped two coins to team A
	# and the match had already given team A those two, so the tampering was a
	# no-op and the control passed for the wrong reason.
	for c in clients[0].coins:
		c["state"] = ArenaCoin.State.HELD
		c["owner"] = 1
	check(clients[0].score(1) != host_b,
		"and the comparison notices when a client's coins are wrong (%d vs %d)"
			% [clients[0].score(1), host_b])

## A link whose jitter is bigger than the gap between snapshots delivers them
## out of order, and an older world must never replace a newer one.
##
## Its own scenario because the ordinary one cannot test it: snapshots go out
## every 33ms and the agreement test's jitter is 12ms, so nothing ever arrives
## late enough to overtake. A negative control that removed the guard passed
## the whole probe, which is how that was found.
func _test_reordering() -> void:
	_current = "reordering"
	var mesh := VersusLoopback.mesh(4, 0.05, 0.0, 0.08, 3141)
	var host := VersusHost.new()
	host.start(mesh[0], _world(), 2718)
	var other := VersusClient.new()
	other.start(mesh[1], VersusRoster.SEAT_B_RUNNER)

	var rng := RandomNumberGenerator.new()
	rng.seed = 161803
	var delta := 1.0 / 60.0
	var went_backwards := false
	var last := -1
	for t in range(1200):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t, rng))
		host.request_start(0)
		other.step(_moving_seat(1, t, rng))
		if other.seen_world:
			if other.world_tick < last:
				went_backwards = true
			last = other.world_tick

	check(other.stale_dropped > 0,
		"80ms of jitter really did reorder the snapshots (%d arrived late)"
			% other.stale_dropped)
	check(not went_backwards,
		"and the client's world never ran backwards")

## One runner losing its link mid-match must not take the match with it.
func _test_a_lost_peer() -> void:
	_current = "a lost peer"
	var mesh := VersusLoopback.mesh(4, 0.03, 0.0, 0.0, 99)
	var host := VersusHost.new()
	host.start(mesh[0], _world(), 555)
	var other := VersusClient.new()
	other.start(mesh[1], VersusRoster.SEAT_B_RUNNER)

	var rng := RandomNumberGenerator.new()
	rng.seed = 13579
	var delta := 1.0 / 60.0
	for t in range(240):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t, rng))
		host.request_start(0)
		other.step(_moving_seat(1, t, rng))
	check(other.connected, "the second runner is in the match")
	check(host.playing, "and the host started it")
	var where: Vector2 = host.match_rules.seats[1].position

	mesh[1].close()
	# Closing a link does not recall what is already flying: the host keeps
	# receiving for one more latency's worth of ticks. Let that land before
	# asking where the runner came to rest, or the test is measuring the tail
	# of the connection rather than the loss of it.
	for t in range(30):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t + 240, rng))
	where = host.match_rules.seats[1].position
	for t in range(240):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t + 270, rng))
	check(host.match_rules.seats[1].position == where,
		"a runner that goes quiet stays where it was rather than teleporting")
	check(host.match_rules.ledger.conserved(),
		"and the ledger is unharmed by losing them")

# ------------------------------------------------------------- the guardian
## A guardian's platform has to become real ground for BOTH teams, decided by
## the host, not a picture on the guardian's own screen.
func _test_the_guardian() -> void:
	_current = "the guardian"
	var mesh := VersusLoopback.mesh(4, 0.02, 0.0, 0.0, 4242)
	var host := VersusHost.new()
	host.start(mesh[0], _world(), 31337)
	var guard := VersusClient.new()
	guard.start(mesh[2], VersusRoster.SEAT_A_GUARDIAN)

	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	var delta := 1.0 / 60.0
	for t in range(120):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t, rng))
		guard.step(null)
	check(guard.connected and guard.seat == VersusRoster.SEAT_A_GUARDIAN,
		"the guardian is seated")

	# Over 1-1's windy pit (x 1000..1140), where there is no floor at all.
	var over_the_gap := Vector2(1070.0, 260.0)
	# Asked from above the platform: floor_below finds surfaces BELOW the point,
	# and a point inside the slab it just built sees nothing under it.
	# Below the row over the pit (y 30..76).
	var looking_down := Vector2(1070.0, 200.0)
	check(host.world.floor_below(looking_down, 500.0) == INF,
		"there is no floor over the gap to begin with")
	guard.request_build(over_the_gap)
	for t in range(120):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t + 120, rng))
		guard.step(null)

	check(host.builds.size() == 1, "the host built what the guardian asked for")
	check(host.world.floor_below(looking_down, 500.0) < INF,
		"and it is real ground in the host's world")
	check(guard.builds.size() == 1,
		"the guardian is told the platform exists")
	check(guard.collision().floor_below(looking_down, 500.0) < INF,
		"and it is ground on their screen too")

	# A runner may not build. The seat is checked against what the HOST handed
	# out, not against what the packet claims.
	var before := host.builds.size()
	mesh[1].send_to(0, VersusTransport.Channel.COMMAND,
		VersusTransport.Reliability.RELIABLE,
		VersusProtocol.command(VersusRoster.SEAT_A_GUARDIAN, 0,
			1, Vector2(1970.0, 150.0)))
	for t in range(60):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t + 240, rng))
	check(host.builds.size() == before,
		"and a peer claiming somebody else's seat is ignored")

# -------------------------------------- two-player start and real touch input
func _test_duel_ready_requires_first_input() -> void:
	_current = "duel startup with no phantom dead runner"
	var mesh := VersusLoopback.mesh(2)
	var host := VersusHost.new()
	host.start(mesh[0], _world(), 8401, VersusRoster.RoomMode.DUEL_COMBINED)
	var guest := VersusClient.new()
	guest.start(mesh[1], VersusRoster.SEAT_B_RUNNER,
		VersusRoster.RoomMode.DUEL_COMBINED)
	var rng := RandomNumberGenerator.new()
	for t in range(18):
		for m in mesh:
			m.advance(1.0 / 60.0)
		host.step(_moving_seat(0, t, rng))
		guest.step(null, VersusRoster.SEAT_B_RUNNER)
	check(host.roster.can_play() and guest.connected,
		"both runner seats are authenticated")
	check(not host.playing and host.match_rules.tick == 0,
		"authenticated HELLO alone does not start without runner input")
	check(guest.seen_world and guest.phase == 2,
		"the joiner still sees waiting before its first position is sent")
	var initial := _moving_seat(1, 0, rng)
	initial.position = VersusStageData.start_positions()[1]
	initial.can_act = false
	initial.strike_seq = 0
	for t in range(12):
		for m in mesh:
			m.advance(1.0 / 60.0)
		guest.step(initial, VersusRoster.SEAT_B_RUNNER)
		host.step(_moving_seat(0, t, rng))
	check(host.playing and host.match_rules.tick > 0,
		"host starts after actual initial runner position is received")
	check(host.match_rules.seats[1].alive and \
		host.match_rules.seats[1].position.distance_to(initial.position) < 2.0,
		"first active host snapshot has a living guest at its actual spawn")
	check(guest.phase == VersusMatch.Phase.PLAYING,
		"guest leaves the waiting overlay after first runner input")

# ------------------------------------------------------------- input ownership
func _test_input_isolation() -> void:
	_current = "input ownership"
	var adapter := VersusInput.new()
	add_child(adapter)
	adapter.make_hubs(adapter, false)
	check(not adapter.hubs[0].scripted and adapter.hubs[1].scripted,
		"only the local online hub reads real keyboard and touch")
	adapter.hubs[0].move_axis = 0.75
	adapter.poll()
	check(is_equal_approx(adapter.hubs[0].move_axis, 0.75),
		"versus poll cannot erase a phone's held virtual stick")
	var h: InputHub = adapter.hubs[0]
	h._on_roles_swapped(false)
	check(h.runner_on_left, "co-op role swaps cannot mirror versus joystick")
	var size := h._screen_size()
	var place: Dictionary = h.stick_place(size)
	var center: Vector2 = place["center"]
	var radius: float = float(place["radius"])
	h._touch_down(91, center)
	h._touch_move(91, center + Vector2(radius * 0.65, 0.0))
	check(h.move_axis > 0.2, "dragging virtual stick right moves right")
	h._touch_move(91, center - Vector2(radius * 0.65, 0.0))
	check(h.move_axis < -0.2, "dragging virtual stick left moves left")
	h._touch_up(91)
	check(is_zero_approx(h.move_axis), "releasing stick cancels input")
	adapter.queue_free()

# ---------------------------------------------------------- build revisions
## Replacing the oldest of twelve creates one new build without changing the
## array size. The original renderer compared size only and kept a ghost floor.
func _test_build_revisions() -> void:
	_current = "build revisions"
	Stage.use(Stage.Which.GREENFIELD)
	var arena := VersusStageData.collision_rects()
	var connector := ArenaStage.new(arena)
	check(connector.floor_below(Vector2(-20, 300), 200.0) < INF
			and connector.floor_below(Vector2(VersusStageData.WIDTH + 20, 300), 200.0) < INF,
		"the host and client collision factory has floor on both sides of the join")
	check(connector.floor_below(Vector2(VersusStageData.WIDTH * 0.5, 40), 500.0) < INF,
		"and the block stack in the middle")
	var mesh := VersusLoopback.mesh(2)
	var host := VersusHost.new()
	host.start(mesh[0], connector, 5150)
	var guard := VersusClient.new()
	guard.start(mesh[1], VersusRoster.SEAT_A_GUARDIAN)
	var rng := RandomNumberGenerator.new()
	for t in range(8):
		for m in mesh:
			m.advance(1.0 / 60.0)
		host.step(_moving_seat(0, t, rng))
		guard.step(null)
	check(guard.connected, "guardian connected for world-revision trial")
	for i in range(VersusHost.MAX_BUILDS):
		check(host.place_build(VersusRoster.SEAT_A_GUARDIAN,
			Vector2(700 + i * 40, 100)), "construct %d accepted" % i)
	var previous_id := int(host.builds[0]["build_id"])
	for m in mesh:
		m.advance(1.0 / 60.0)
	host.step(_moving_seat(0, 9, rng))
	# Snapshot cadence is 30Hz: tick nine is not broadcast.
	host.step(_moving_seat(0, 10, rng))
	for m in mesh:
		m.advance(1.0 / 60.0)
	guard.step(null)
	check(guard.builds.size() == VersusHost.MAX_BUILDS
		and guard.world_revision == VersusHost.MAX_BUILDS,
		"twelve constructs reach the remote side with revision twelve")
	check(host.place_build(VersusRoster.SEAT_A_GUARDIAN,
		Vector2(1700, 100)), "thirteenth construct accepted")
	for m in mesh:
		m.advance(1.0 / 60.0)
	host.step(_moving_seat(0, 11, rng))
	host.step(_moving_seat(0, 12, rng))
	for m in mesh:
		m.advance(1.0 / 60.0)
	guard.step(null)
	check(host.builds.size() == VersusHost.MAX_BUILDS
		and guard.builds.size() == VersusHost.MAX_BUILDS,
		"FIFO replacement preserves the twelve-build cap")
	check(guard.world_revision == host.world_revision
		and host.world_revision == VersusHost.MAX_BUILDS + 1,
		"same-size replacement increments the transmitted world revision")
	check(int(host.builds[0]["build_id"]) != previous_id
		and int(guard.builds[0]["build_id"]) == int(host.builds[0]["build_id"]),
		"same-count replacement removes the old id from both peers")
	var target: Rect2 = host.builds[host.builds.size() - 1]["rect"]
	var look := target.position + Vector2(target.size.x * 0.5, -20)
	check(guard.collision().floor_below(look, 500.0) < INF
		and host.world.floor_below(look, 500.0) < INF,
		"newly replaced platform collides on both sides")
	check(host.undo_build(VersusRoster.SEAT_A_GUARDIAN),
		"guardian can undo the most recent construct")
	check(host.world_revision == VersusHost.MAX_BUILDS + 2,
		"undo also increments the revision")
	check(not host.place_build(VersusRoster.SEAT_A_GUARDIAN,
		Vector2(INF, 100)), "infinite coordinates cannot create constructs")

# ----------------------------------------------------------- two-peer combined
func _test_duel_combined() -> void:
	_current = "two peers, four roles"
	var mesh := VersusLoopback.mesh(3)
	var host := VersusHost.new()
	host.start(mesh[0], _world(), 31337, VersusRoster.RoomMode.DUEL_COMBINED)
	check(host.roster.owns_seat(0, VersusRoster.SEAT_A_RUNNER)
		and host.roster.owns_seat(0, VersusRoster.SEAT_A_GUARDIAN),
		"host atomically owns runner A and guardian A")
	check(not host.roster.can_play(), "host alone does not start a 1v1")
	for t in range(20):
		for m in mesh:
			m.advance(1.0 / 60.0)
		host.step(VersusMatch.Seat.new())
	check(host.match_rules.tick == 0 and not host.playing
		and host.match_rules.score(0) == 0,
		"waiting cannot advance the match or grant a coin")
	var guest := VersusClient.new()
	guest.start(mesh[1], VersusRoster.SEAT_B_RUNNER,
		VersusRoster.RoomMode.DUEL_COMBINED)
	for t in range(20):
		for m in mesh:
			m.advance(1.0 / 60.0)
		host.step(_moving_seat(0, t, RandomNumberGenerator.new()))
		guest.step(_moving_seat(1, t, RandomNumberGenerator.new()))
	check(guest.connected and guest.seat == VersusRoster.SEAT_B_RUNNER
		and guest.room_mode == VersusRoster.RoomMode.DUEL_COMBINED,
		"joiner is assigned runner B in the combined room")
	check(host.playing and host.roster.can_play()
		and host.roster.owns_seat(1, VersusRoster.SEAT_B_GUARDIAN)
		and host.roster.peers_filled() == 2,
		"the joiner also owns guardian B; two peers start")
	var extra := VersusClient.new()
	extra.start(mesh[2], VersusRoster.SEAT_B_RUNNER,
		VersusRoster.RoomMode.DUEL_COMBINED)
	for t in range(4):
		for m in mesh:
			m.advance(1.0 / 60.0)
		host.step(_moving_seat(0, t, RandomNumberGenerator.new()))
		guest.step(null)
		extra.step(null, VersusRoster.SEAT_B_RUNNER)
	check(extra.refused and not extra.connected,
		"third peer is refused instead of taking a different seat")
	check(host.place_build(VersusRoster.SEAT_A_GUARDIAN,
		Vector2(1210, 100), 1), "host player can place through guardian A")
	guest.request_build(Vector2(1350, 100), 2)
	for m in mesh:
		m.advance(1.0 / 60.0)
	host.step(_moving_seat(0, 0, RandomNumberGenerator.new()))
	check(host.builds.size() == 2
		and int(host.builds[1]["seat"]) == VersusRoster.SEAT_B_GUARDIAN,
		"joiner's guardian builds over its runner's one socket")
	var before := host.builds.size()
	mesh[2].send_to(0, VersusTransport.Channel.COMMAND,
		VersusTransport.Reliability.RELIABLE,
		VersusProtocol.command(VersusRoster.SEAT_B_GUARDIAN,
			0, 1, Vector2(1700, 100)))
	for m in mesh:
		m.advance(1.0 / 60.0)
	host.step(_moving_seat(0, 1, RandomNumberGenerator.new()))
	check(host.builds.size() == before,
		"unseated third peer cannot forge guardian B's seat")

# ------------------------------------------------------------------ helpers
func _world() -> ArenaStage:
	Stage.use(Stage.Which.GREENFIELD)
	return ArenaStage.new(VersusStageData.collision_rects())

## A runner touring the arena's star points, so stars actually change hands.
##
## Written as "stand where a star appears" rather than as a wander: a runner
## that never met one left the score at zero and made the agreement check
## compare nothing to nothing. What this probe is about is whether four peers agree, not whether a
## path is realistic.
func _moving_seat(team: int, t: int, rng: RandomNumberGenerator) -> VersusMatch.Seat:
	var s := VersusMatch.Seat.new()
	s.team = team
	var points := VersusStageData.coin_points()
	# Hops every 30 ticks, so in a 2400-tick match each runner stands on
	# most of the star points and meets the one loose star now and then.
	var i := (int(t / 30) + team * 3) % points.size()
	s.position = points[i]
	s.facing = 1 if team == 0 else -1
	s.alive = true
	s.can_act = true
	s.invulnerable = false
	# Only team A swings, and not often. Two runners stripping each other every
	# forty ticks kept the score at zero, which made the agreement check
	# vacuous -- it was comparing nothing to nothing.
	s.strike_seq = int(t / 240) if team == 0 else 0
	return s

# -------------------------------------------------------- start and rematch
## Nobody scores before the host presses start; "3, 2, 1" reaches every
## client; a rematch restarts the tick at zero and every client follows it
## rather than throwing the new match away as older than the old one.
func _test_start_and_rematch() -> void:
	_current = "start, countdown and rematch"
	var mesh := VersusLoopback.mesh(4, 0.02, 0.0, 0.0, 8080)
	var host := VersusHost.new()
	host.start(mesh[0], _world(), 6060)
	check(not host.playing and not host.request_start(30),
		"a room with one runner cannot be started")
	var other := VersusClient.new()
	other.start(mesh[1], VersusRoster.SEAT_B_RUNNER)
	var guard := VersusClient.new()
	guard.start(mesh[3], VersusRoster.SEAT_B_GUARDIAN)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var delta := 1.0 / 60.0
	for t in range(60):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t, rng))
		other.step(_moving_seat(1, t, rng))
		guard.step(null)
	check(host.match_rules.tick == 0 and host.match_rules.score(0) == 0
			and host.match_rules.score(1) == 0,
		"everyone seated, but nothing is scored before start")
	check(other.phase == VersusProtocol.PHASE_WAITING,
		"and the clients are shown the waiting room")
	check(other.seat_mask == 0b1101,
		"which knows seats A-runner, B-runner and B-guardian are taken (%d)" % other.seat_mask)

	check(host.request_start(30), "the host's start is accepted once both runners are in")
	check(not host.request_start(30), "and only once")
	var saw_countdown := false
	var counted_down := true
	var last_count := 1 << 16
	for t in range(20):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t, rng))
		other.step(_moving_seat(1, t, rng))
		guard.step(null)
		if other.phase == VersusProtocol.PHASE_COUNTDOWN:
			saw_countdown = true
			if other.countdown > last_count:
				counted_down = false
			last_count = other.countdown
	check(saw_countdown and counted_down, "the countdown reaches a client, counting down")
	check(host.match_rules.tick == 0, "and the match clock does not run through it")
	for t in range(40):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t, rng))
		other.step(_moving_seat(1, t, rng))
		guard.step(null)
	check(host.playing and host.match_rules.tick > 0
			and other.phase == VersusMatch.Phase.PLAYING,
		"after it, the match is on for everyone")

	# Win it outright, then play again.
	for id in range(VersusRules.WIN_AT):
		ArenaCoin.to_held(host.match_rules.ledger.get_coin(id), 0)
	for t in range(10):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t, rng))
		other.step(_moving_seat(1, t, rng))
		guard.step(null)
	check(host.match_rules.phase == VersusMatch.Phase.OVER and other.phase == VersusMatch.Phase.OVER
			and guard.winner == 0,
		"seven held stars end it on every screen")
	var old_tick := other.world_tick
	check(host.restart_match(10), "the host can start a rematch")
	for t in range(30):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t, rng))
		other.step(_moving_seat(1, t, rng))
		guard.step(null)
	check(other.epoch == 1 and other.epoch_changes == 1 and guard.epoch_changes == 1,
		"every client follows the rematch exactly once")
	check(other.world_tick < old_tick and other.phase == VersusMatch.Phase.PLAYING,
		"with the clock back from %d to %d and the match on again" % [old_tick, other.world_tick])
	check(other.score(0) + other.score(1) < VersusRules.WIN_AT,
		"and the old stars gone")
	# A late packet from the finished match must not undo the rematch.
	var stale := VersusProtocol.snapshot(old_tick + 50, VersusMatch.Phase.OVER, 0,
		other.runners, other.coins, [], 0, 0, 0, 0b1101)
	other._absorb(stale)
	check(other.epoch == 1 and other.phase == VersusMatch.Phase.PLAYING,
		"a delayed snapshot from the old match is refused")

## EOSG numbers its server 1; the game calls the host 0. Both directions.
func _test_eos_peer_ids() -> void:
	_current = "EOS peer ids"
	check(VersusEosTransport.to_game(1) == VersusTransport.HOST_PEER,
		"the EOS server is the game's host")
	check(VersusEosTransport.to_eos(VersusTransport.HOST_PEER) == 1,
		"and the host is addressed as the EOS server")
	check(VersusEosTransport.to_game(1234567) == 1234567
			and VersusEosTransport.to_eos(1234567) == 1234567,
		"client ids pass through unchanged")
	check(VersusProtocol.bye(255).size() == 2
			and VersusProtocol.kind_of(VersusProtocol.bye(255)) == VersusProtocol.Msg.BYE,
		"a dropped client is reported to the host as a BYE")

# ------------------------------------------------------------- free-for-all
## みんなで: eight people in one room, each their own side, through a lossy
## link. Chairs are handed out by the host, a ninth person is turned away,
## every screen derives every person's stars exactly as the host does, each
## builds from their own chair and nobody else's, and someone leaving gives
## their stars back.
func _test_free_for_all() -> void:
	_current = "free-for-all"
	var ffa := VersusRoster.RoomMode.FREE_FOR_ALL
	var mesh := VersusLoopback.mesh(9, 0.03, 0.04, 0.01, 8888)
	var host := VersusHost.new()
	host.start(mesh[0], _world(), 1357, ffa)
	check(not host.request_start(0), "one person cannot start a free-for-all")
	var clients: Array[VersusClient] = []
	for i in range(1, 9):
		var c := VersusClient.new()
		c.start(mesh[i], -1, ffa)
		clients.append(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 97531
	var delta := 1.0 / 60.0
	for t in range(90):
		for m in mesh:
			m.advance(delta)
		host.step(_ffa_seat(0, t))
		for i in range(clients.size()):
			var c := clients[i]
			clients[i].step(_ffa_seat(c.seat, t) if c.connected else null)
	var seated: Dictionary = {}
	var refused := 0
	for c in clients:
		if c.connected:
			seated[c.seat] = true
		elif c.refused:
			refused += 1
	check(seated.size() == 7 and not seated.has(0),
		"seven guests get chairs 1-7 of their own (%d)" % seated.size())
	check(refused == 1, "and a ninth person is told the room is full")
	check(host.roster.can_play() and host.seat_mask() == 0xFF,
		"eight chairs taken, and the room can start")
	check(host.request_start(0), "the host starts it")

	var truth: Dictionary = {}
	var compared := 0
	var disagreed := false
	var best := 0
	for t in range(1500):
		for m in mesh:
			m.advance(delta)
		host.step(_ffa_seat(0, t))
		var row: Array = []
		for side in range(8):
			row.append(host.match_rules.score(side))
			best = maxi(best, host.match_rules.score(side))
		truth[host.match_rules.tick] = row
		for c in clients:
			c.step(_ffa_seat(c.seat, t) if c.connected else null)
			if not c.connected or not c.seen_world or not truth.has(c.world_tick):
				continue
			var was: Array = truth[c.world_tick]
			compared += 1
			for side in range(8):
				if c.score(side) != int(was[side]):
					disagreed = true
		if host.match_rules.phase != VersusMatch.Phase.PLAYING:
			break
	print("    %d comparisons, most stars held by anyone %d" % [compared, best])
	check(best > 0 and compared > 1000, "stars changed hands among eight people")
	check(not disagreed, "and every screen derived every person's stars as the host did")
	check(host.match_rules.sides == 8 and host.match_rules.coin_total == VersusRules.FFA_COIN_TOTAL
			and host.match_rules.on_field == VersusRules.ffa_on_field(8),
		"the match was set up for eight sides and eight people's stars")
	check(host.match_rules.ledger.conserved(), "with the ledger balanced")

	# Building: each person from their own chair, never somebody else's.
	var builder: VersusClient = null
	for c in clients:
		if c.connected:
			builder = c
			break
	var before := host.builds.size()
	builder.request_build(Vector2(1290.0, 260.0), 1)
	var other_seat := (builder.seat % 7) + 1
	mesh[clients.find(builder) + 1].send_to(0, VersusTransport.Channel.COMMAND,
		VersusTransport.Reliability.RELIABLE,
		VersusProtocol.command(other_seat, 0, 1, Vector2(1970.0, 150.0)))
	for t in range(20):
		for m in mesh:
			m.advance(delta)
		host.step(_ffa_seat(0, t))
		for c in clients:
			c.step(null)
	check(host.builds.size() == before + 1
			and int(host.builds[host.builds.size() - 1]["seat"]) == builder.seat,
		"a person builds from their own chair, and a forged chair is ignored")
	check(host.place_build(0, Vector2(1600.0, 120.0), 2),
		"the host player builds too")

	# Leaving hands the stars back.
	var leaver := builder.seat
	ArenaCoin.to_held(host.match_rules.ledger.get_coin(19), leaver)
	mesh[clients.find(builder) + 1].send_to(0, VersusTransport.Channel.CONTROL,
		VersusTransport.Reliability.RELIABLE, VersusProtocol.bye(255))
	for t in range(10):
		for m in mesh:
			m.advance(delta)
		host.step(_ffa_seat(0, t))
	check(host.roster.peer_at(leaver) == -1, "someone who leaves frees their chair")
	check(host.match_rules.ledger.held_by(leaver).is_empty(),
		"and the stars they held go back into play")

## A person in a free-for-all standing on the star points in turn, offset by
## their chair so eight of them are not all in one place.
func _ffa_seat(seat: int, t: int) -> VersusMatch.Seat:
	var s := VersusMatch.Seat.new()
	s.team = seat
	var points := VersusStageData.coin_points()
	s.position = points[(int(t / 70) + seat * 3) % points.size()]
	s.facing = 1 if seat % 2 == 0 else -1
	s.alive = true
	s.can_act = true
	s.strike_seq = int(t / 300) if seat == 1 else 0
	return s
