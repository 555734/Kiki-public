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
	_test_seating()
	_test_agreement()
	_test_reordering()
	_test_a_lost_peer()
	_test_the_guardian()

	print("versus net probe: %d checks failed" % failures.size())
	if failures.is_empty():
		print("four machines agree about one match")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("versus net probe: " + f)
		get_tree().quit(1)

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
	var builds := [{"seat": 1, "position": Vector2(7100, 120),
		"size": Balance.PLATFORM_SIZE}]
	var snap := VersusProtocol.snapshot(999, 0, -1, runners, coins, builds)
	var s := VersusProtocol.read_snapshot(snap)
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

	# The budget the plan set. A full match has to fit the relay's packet cap
	# with room to spare, or the mode does not work on the internet at all.
	print("    a full snapshot is %d bytes (cap %d)"
		% [snap.size(), VersusTransport.MAX_PACKET_BYTES])
	check(snap.size() <= 768,
		"a full snapshot fits the 768-byte budget (%d)" % snap.size())

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
		other.step(_moving_seat(1, t, rng))
	check(other.connected, "the second runner is in the match")
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

	# Over the gap between the first two stepping stones, where 1-1 has nothing.
	# 1-1's own gap between the first two stepping stones of the wall lesson.
	var over_the_gap := Vector2(7220.0, 150.0)
	# Asked from above the platform: floor_below finds surfaces BELOW the point,
	# and a point inside the slab it just built sees nothing under it.
	var looking_down := Vector2(7220.0, 60.0)
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
			1, Vector2(7500.0, 150.0)))
	for t in range(60):
		for m in mesh:
			m.advance(delta)
		host.step(_moving_seat(0, t + 240, rng))
	check(host.builds.size() == before,
		"and a peer claiming somebody else's seat is ignored")

# ------------------------------------------------------------------ helpers
func _world() -> ArenaStage:
	Stage.use(Stage.Which.GREENFIELD)
	var rects: Array[Rect2] = Stage.ground()
	rects.append_array(Stage.solid_decor())
	return ArenaStage.new(rects)

## A runner touring 1-1's coin points, so coins actually change hands.
##
## Written as "stand where a coin appears" rather than as a wander: the stage is
## 16,700px long and a runner sweeping a thousand pixels of it never met one,
## which left the score at zero and made the agreement check compare nothing to
## nothing. What this probe is about is whether four peers agree, not whether a
## path is realistic.
func _moving_seat(team: int, t: int, rng: RandomNumberGenerator) -> VersusMatch.Seat:
	var s := VersusMatch.Seat.new()
	s.team = team
	var points := VersusStageData.coin_points()
	var i := (int(t / 90) + team * 3) % points.size()
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
