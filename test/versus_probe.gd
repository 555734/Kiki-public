extends Node
## Do the 1-1 coin match's rules hold?
##
## The rules are a pure function of observations (VersusMatch.step), so they can
## be driven here with no runners, no physics server and no window -- which is
## the point of keeping them out of the scene, and what the four-device host
## will rely on.
##
## Two things are checked that nothing else can check: that the coin ledger is
## conserved on every tick of a long match, and that the slice of 1-1 the mode
## is played on is actually a fair arena.

var failures: Array[String] = []
var _current: String = ""

func check(ok: bool, label: String) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		failures.append("%s: %s" % [_current, label])
		print("  FAIL  %s" % label)

func _ready() -> void:
	_test_the_stage()
	_test_random_spawns()
	_test_the_loop()
	await _test_the_map()
	_test_conservation()
	_test_stealing()
	_test_winning()

	print("versus probe: %d checks failed" % failures.size())
	if failures.is_empty():
		print("the 1-1 coin match holds")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("versus probe: " + f)
		get_tree().quit(1)

# ------------------------------------------------------------------ the stage
## The match is played on 1-1 itself, so what has to be checked is not the
## shape of an arena -- it is that the coins, the starts and the respawns
## landed somewhere sensible ON that stage, and that they were DERIVED from it
## rather than written down beside it.
func _test_the_stage() -> void:
	_current = "the stage"
	Stage.use(Stage.Which.GREENFIELD)
	var world := _world()

	var points := VersusStageData.coin_points()
	check(points.size() >= 20,
		"coins are spread the length of 1-1 (%d points)" % points.size())

	# Every one has to be over ground. A coin generated above a gap falls into
	# the pit the moment it appears and the match quietly loses it.
	var homeless: Array[Vector2] = []
	for p in points:
		if world.floor_below(p, 260.0) == INF:
			homeless.append(p)
	check(homeless.is_empty(),
		"every coin point has 1-1's floor under it (%d without)" % homeless.size())

	# And spread out: a dozen coins on top of each other is one coin.
	var closest := INF
	for i in range(points.size()):
		for k in range(i + 1, points.size()):
			closest = minf(closest, points[i].distance_to(points[k]))
	check(closest > 120.0,
		"and no two are within 120px of each other (closest %.0f)" % closest)

	var span := 0.0
	for p in points:
		span = maxf(span, p.x)
	print("    %d coin points, reaching x=%.0f of 1-1's %.0f"
		% [points.size(), span, Level01Data.goal().x])
	check(span > VersusStageData.STEP_FROM * 0.8 and span < VersusStageData.STEP_FROM,
		"they reach the far end of the stage, not just the start")
	check(VersusStageData.LOOP_SPAN == 13000.0,
		"versus circuit is shortened from 19000px to 13000px")
	check(Level01Data.ground()[-1].end.x == 16700.0,
		"cooperative 1-1 still has its complete original ground")

	# Both runners start together, on the ground, at 1-1's own start. Neither
	# gets a head start: the whole stage is ahead of both of them.
	var starts := VersusStageData.start_positions()
	check(absf(starts[0].x - starts[1].x) < 80.0
			and starts[0].y == starts[1].y,
		"the two runners start side by side")
	for i in range(2):
		check(world.floor_below(starts[i], 400.0) < INF,
			"runner %d starts over ground" % (i + 1))

	# Respawn is 1-1's own checkpoint behind you, not the start of the stage.
	var late := Vector2(11000.0, 0.0)
	var back := VersusStageData.respawn_for(0, late)
	check(back.x > 8000.0 and back.x < late.x,
		"dying at x=11000 sends you to the checkpoint behind you (%.0f)" % back.x)
	check(VersusStageData.respawn_for(0, Vector2(100.0, 0.0)) == Stage.start(),
		"and dying before the first one sends you to the start")

# -------------------------------------------------------------------- the loop
func _test_random_spawns() -> void:
	_current = "random spawns"
	var world := ArenaStage.new(VersusStageData.collision_rects())
	var first := VersusMatch.new()
	var replay := VersusMatch.new()
	var other := VersusMatch.new()
	first.setup(world, 4815)
	replay.setup(world, 4815)
	other.setup(world, 9281)
	var same := true
	var different := 0
	var regions: Dictionary = {}
	var previous := Vector2(INF, INF)
	var safe := true
	var repeats := 0
	for i in range(100):
		var p: Vector2 = first._free_point()
		same = same and p == replay._free_point()
		if p != other._free_point():
			different += 1
		regions[int(p.x / (VersusStageData.STEP_FROM / 4.0))] = true
		if p.distance_to(previous) < 48.0:
			repeats += 1
		previous = p
		safe = safe and p.x < VersusStageData.STEP_FROM \
			and world.floor_below(p, 80.0) != INF \
			and not world.overlaps(Rect2(p - Vector2(12, 12), Vector2(24, 24)))
	check(same, "same host seed reproduces the spawn sequence")
	check(different > 90, "different match seeds change actual spawn positions")
	check(regions.size() == 4, "random spawns reach all four quarters of the course")
	check(repeats == 0, "successive spawns do not repeat the same region")
	check(safe, "all random spawns are clear of solids and above retained ground")
	# Exercise actual top-up, not only the selector, with existing loose coins.
	var actors := _seats()
	for actor in actors:
		actor.alive = false
	for i in range(150):
		first.step(actors)
	var loose: Array[Vector2] = []
	for coin in first.ledger.coins:
		if coin.state == ArenaCoin.State.WORLD:
			loose.append(coin.position)
	check(loose.size() == VersusRules.ON_FIELD, "random top-up keeps three loose coins")
	check(first.ledger.conserved(), "random top-up preserves the 18-coin ledger")

## Is the circuit actually seamless, and does the match measure around it?
func _test_the_loop() -> void:
	_current = "the loop"
	Stage.use(Stage.Which.GREENFIELD)
	# TWO laps, which is what the game builds either side of the join. One lap
	# alone stops at LOOP_TO and the plateau you walk onto belongs to the next
	# one -- the first version of this check asked a one-lap world what was
	# under x=17425 and was told, correctly, nothing.
	var two: Array[Rect2] = []
	for lap in [0, 1]:
		for r in VersusStageData.lap_ground():
			two.append(Rect2(r.position
				+ Vector2(VersusStageData.LOOP_SPAN * float(lap), 0.0), r.size))
	var world := ArenaStage.new(two)

	# The join has to be FLAT. Walk the surface from 1-1's last ledge, across
	# the steps this mode adds, onto the next lap's plateau, and measure every
	# change in height along the way.
	var surface: Array[float] = []
	var gaps := 0
	var x := VersusStageData.STEP_FROM - 100.0
	while x <= VersusStageData.LOOP_TO + 400.0:
		var top := world.floor_below(Vector2(x, -200.0), 1400.0)
		if top == INF:
			gaps += 1
		else:
			surface.append(top)
		x += 25.0
	check(gaps == 0, "there is ground the whole way across the join (%d holes)" % gaps)
	if surface.size() < 2:
		return
	var worst := 0.0
	for i in range(1, surface.size()):
		worst = maxf(worst, absf(surface[i] - surface[i - 1]))
	print("    biggest step across the join: %.0fpx" % worst)
	check(worst <= 60.0,
		"nothing on the join is more than a 60px step (worst %.0f)" % worst)

	# And the last step meets the next lap's plateau at exactly the same
	# height, so wrapping happens on level ground.
	var before := world.floor_below(
		Vector2(VersusStageData.LOOP_TO - 40.0, -200.0), 1400.0)
	var after := world.floor_below(
		Vector2(VersusStageData.LOOP_TO + 40.0, -200.0), 1400.0)
	check(is_equal_approx(before, after),
		"the two ends of the lap are the same height (%.0f and %.0f)"
			% [before, after])

	# Wrapping is idempotent and lands inside one lap.
	for probe_x in [-40000.0, -1600.1, 0.0, 17399.9, 17400.0, 40000.0]:
		var once := VersusStageData.wrap_x(probe_x)
		check(once >= VersusStageData.LOOP_FROM and once < VersusStageData.LOOP_TO,
			"wrap_x(%.0f) lands inside the lap (%.0f)" % [probe_x, once])
		check(is_equal_approx(VersusStageData.wrap_x(once), once),
			"and wrapping it again changes nothing")

	# The point of a loop: two runners either side of the join are next to each
	# other, not eighteen thousand pixels apart.
	var east := Vector2(VersusStageData.LOOP_TO - 10.0, 200.0)
	var west := Vector2(VersusStageData.LOOP_FROM + 10.0, 200.0)
	var seen := VersusStageData.nearest_image(west, east)
	check(absf(seen.x - east.x) < 40.0,
		"across the join, 20px apart reads as 20px (%.0f)" % absf(seen.x - east.x))
	check(is_equal_approx(seen.y, west.y), "and the height is untouched")
	# ...and it still gets ordinary distances right.
	var near := Vector2(5000.0, 200.0)
	check(VersusStageData.nearest_image(near, Vector2(5100.0, 200.0)) == near,
		"a pair in the middle of the lap is left alone")

	# A strike across the join has to land.
	var m := _fresh()
	var seats := _seats()
	_park(seats, 0, east)
	_park(seats, 1, west)
	seats[0].facing = 1
	_give(m, 1, [0])
	m.step(seats)
	seats[0].strike_seq += 1
	for t in range(VersusRules.STRIKE_STARTUP_TICKS + 6):
		m.step(seats)
	check(_held_of(m, 1, [0]) == 0,
		"and a strike across the join takes the coin")

# --------------------------------------------------------------------- the map
## The map is data the HUD draws, so its CONTENTS can be checked here without
## looking at a pixel.
func _test_the_map() -> void:
	_current = "the map"
	# Driven through the scene, because map_marks reads the runners.
	var arena: Node2D = load("res://src/versus/versus_main.tscn").instantiate()
	add_child(arena)
	for i in range(40):
		await get_tree().physics_frame
	var m: VersusMatch = arena.match_rules
	ArenaCoin.to_world(m.ledger.get_coin(0), Vector2(9000.0, 200.0), m.tick,
		Vector2.ZERO, 0)
	ArenaCoin.to_world(m.ledger.get_coin(1), Vector2(200.0, 300.0), m.tick,
		Vector2.ZERO, 0)
	await get_tree().physics_frame

	var marks: Array = arena.map_marks()
	var kinds := {}
	var outside := 0
	for mark in marks:
		kinds[String(mark["kind"])] = int(kinds.get(String(mark["kind"]), 0)) + 1
		var f := float(mark["x01"])
		if f < 0.0 or f > 1.0:
			outside += 1
	check(kinds.has("you") and int(kinds["you"]) == 1, "the map shows you, once")
	check(kinds.has("them") and int(kinds["them"]) == 1, "and the other runner")
	check(int(kinds.get("coin", 0)) >= 2,
		"and every coin on the ground (%d)" % int(kinds.get("coin", 0)))
	check(outside == 0, "with everything placed inside the bar (%d outside)" % outside)

	# A coin at the far end of the lap must not read as being at the near end.
	var far := VersusStageData.lap_fraction(VersusStageData.STEP_FROM - 200.0)
	var near := VersusStageData.lap_fraction(200.0)
	check(far > near + 0.5,
		"the far end of the lap is drawn far along the bar (%.2f vs %.2f)"
			% [far, near])
	arena.queue_free()
	await get_tree().physics_frame

# ------------------------------------------------------------- the ledger
## A long match of nonsense, with the invariant asserted every tick.
func _test_conservation() -> void:
	_current = "conservation"
	var m := _fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654
	var seats := _seats()
	var broke := -1
	var ids := {}
	for t in range(4000):
		for i in range(2):
			seats[i].position = Vector2(
				rng.randf_range(0.0, 16000.0),
				rng.randf_range(-100.0, 400.0))
			seats[i].facing = 1 if rng.randf() < 0.5 else -1
			seats[i].alive = rng.randf() > 0.02
			seats[i].can_act = seats[i].alive and rng.randf() > 0.1
			if rng.randf() < 0.05:
				seats[i].strike_seq += 1
		m.step(seats)
		if rng.randf() < 0.01:
			m.note_death(0 if rng.randf() < 0.5 else 1)
		for c in m.ledger.coins:
			ids[c.coin_id] = true
		if not m.ledger.conserved() and broke < 0:
			broke = t
		if m.phase == VersusMatch.Phase.OVER:
			m = _fresh()
			seats = _seats()
	check(broke < 0,
		"%d coins are conserved on every tick of a long match%s"
			% [VersusRules.COIN_TOTAL,
				"" if broke < 0 else " (broke at tick %d)" % broke])
	check(ids.size() == VersusRules.COIN_TOTAL,
		"and no recycle ever minted an extra id (%d)" % ids.size())

	# Coins have to keep coming, or ten is unreachable and the match never ends.
	var m2 := _fresh()
	var seats2 := _seats()
	_park(seats2, 0, Vector2(9999.0, 0.0))
	_park(seats2, 1, Vector2(9998.0, 0.0))
	for t in range(600):
		m2.step(seats2)
	check(m2.ledger.count_in(ArenaCoin.State.WORLD) == VersusRules.ON_FIELD,
		"the ground is kept topped up to %d coins" % VersusRules.ON_FIELD)

# -------------------------------------------------------------- the stealing
func _test_stealing() -> void:
	_current = "stealing"
	# A strike costs the victim exactly one coin, and it goes to the ground
	# rather than to the attacker.
	var m := _fresh()
	var seats := _seats()
	# On 1-1's ledge at x=7840..8500, clear of any generated coin point so the
	# spawner does not hand these runners coins the test did not.
	_park(seats, 0, Vector2(8000.0, 200.0))
	_park(seats, 1, Vector2(8045.0, 200.0))
	seats[0].facing = 1
	_give(m, 1, [0, 1, 2])
	m.step(seats)
	seats[0].strike_seq += 1
	var loose_before := m.ledger.count_in(ArenaCoin.State.WORLD)
	for t in range(VersusRules.STRIKE_STARTUP_TICKS + 3):
		m.step(seats)
	# Asserted against the three coins the test handed out, not against a global
	# count: the spawner legitimately adds coins while this runs.
	check(_held_of(m, 1, [0, 1, 2]) == 2, "a strike costs the victim one coin")
	check(_held_of(m, 0, [0, 1, 2]) == 0, "and the attacker is not handed it")
	check(m.ledger.count_in(ArenaCoin.State.WORLD) > loose_before,
		"it is on the ground for either of them")

	# Nothing to take from an empty-handed victim, and no crash.
	m = _fresh()
	seats = _seats()
	# On 1-1's ledge at x=7840..8500, clear of any generated coin point so the
	# spawner does not hand these runners coins the test did not.
	_park(seats, 0, Vector2(8000.0, 200.0))
	_park(seats, 1, Vector2(8045.0, 200.0))
	m.step(seats)
	seats[0].strike_seq += 1
	for t in range(VersusRules.STRIKE_STARTUP_TICKS + 3):
		m.step(seats)
	check(m.ledger.conserved(), "striking an empty-handed runner is legal")

	# A runner who cannot act cannot strike, and the press is spent rather than
	# saved up for the moment they recover.
	m = _fresh()
	seats = _seats()
	# On 1-1's ledge at x=7840..8500, clear of any generated coin point so the
	# spawner does not hand these runners coins the test did not.
	_park(seats, 0, Vector2(8000.0, 200.0))
	_park(seats, 1, Vector2(8045.0, 200.0))
	_give(m, 1, [0])
	seats[0].can_act = false
	seats[0].strike_seq += 1
	for t in range(6):
		m.step(seats)
	seats[0].can_act = true
	for t in range(VersusRules.STRIKE_STARTUP_TICKS + 6):
		m.step(seats)
	check(_held_of(m, 1, [0]) == 1,
		"a strike pressed while stunned does not fire on recovery")

	# Death returns the whole hand and destroys none of it.
	m = _fresh()
	seats = _seats()
	_park(seats, 0, Vector2(7360.0, 200.0))
	_park(seats, 1, Vector2(8200.0, 200.0))
	m.step(seats)
	_give(m, 0, [0, 1, 2, 3])
	m.note_death(0)
	check(_held_of(m, 0, [0, 1, 2, 3]) == 0, "dying empties the hand")
	# Where they WENT, not just that the hand is empty. Conservation alone does
	# not catch a hand that was quietly left in the dead runner's name -- a
	# negative control that skipped the return passed that check.
	var back := 0
	for id in [0, 1, 2, 3]:
		var c := m.ledger.get_coin(id)
		if c.owner == -1 and (c.state == ArenaCoin.State.WORLD
				or c.state == ArenaCoin.State.RECYCLE_PENDING):
			back += 1
	check(back == 4, "and all four are back in play, owned by nobody (%d)" % back)
	check(m.ledger.conserved(), "with the ledger still balanced")

	# Invulnerability refuses the hit, so it cannot cost a coin either. The
	# game grants a second of it after every hit and after every respawn, so
	# without this a runner could be stripped while they were untouchable.
	m = _fresh()
	seats = _seats()
	# On 1-1's ledge at x=7840..8500, clear of any generated coin point so the
	# spawner does not hand these runners coins the test did not.
	_park(seats, 0, Vector2(8000.0, 200.0))
	_park(seats, 1, Vector2(8045.0, 200.0))
	seats[0].facing = 1
	seats[1].invulnerable = true
	_give(m, 1, [0])
	m.step(seats)
	seats[0].strike_seq += 1
	for t in range(VersusRules.STRIKE_STARTUP_TICKS + 6):
		m.step(seats)
	check(_held_of(m, 1, [0]) == 1,
		"a strike refused by invulnerability costs no coin")

# --------------------------------------------------------------- the ending
func _test_winning() -> void:
	_current = "winning"
	var m := _fresh()
	var seats := _seats()
	_park(seats, 0, Vector2(6650.0, 160.0))
	_park(seats, 1, Vector2(8170.0, 200.0))
	m.step(seats)
	var ids: Array = []
	for i in range(VersusRules.WIN_AT - 1):
		ids.append(i)
	_give(m, 0, ids)
	m.step(seats)
	check(m.phase == VersusMatch.Phase.PLAYING,
		"%d coins is not yet a win" % (VersusRules.WIN_AT - 1))
	_give(m, 0, [VersusRules.WIN_AT - 1])
	m.step(seats)
	check(m.phase == VersusMatch.Phase.OVER and m.winner == 0,
		"%d wins it" % VersusRules.WIN_AT)

	# And it stays won: a decided match cannot be re-decided.
	var was := m.winner
	_give(m, 1, [VersusRules.WIN_AT, VersusRules.WIN_AT + 1])
	m.step(seats)
	check(m.winner == was, "and a decided match is not re-decided")

# ------------------------------------------------------------------- helpers
func _world() -> ArenaStage:
	Stage.use(Stage.Which.GREENFIELD)
	return ArenaStage.new(VersusStageData.collision_rects())

func _fresh() -> VersusMatch:
	var m := VersusMatch.new()
	m.setup(_world(), 4242)
	return m

func _seats() -> Array:
	var out: Array = []
	for i in range(2):
		var s := VersusMatch.Seat.new()
		s.team = i
		s.position = VersusStageData.start_positions()[i]
		s.facing = VersusStageData.start_facing()[i]
		out.append(s)
	return out

func _park(seats: Array, i: int, at: Vector2) -> void:
	seats[i].position = at
	seats[i].alive = true
	seats[i].can_act = true

## How many of THESE coins that side still holds. Never a global count: the
## spawner tops the ground up while any of these tests runs, and a runner
## standing near a spawn point picks one up without being asked.
func _held_of(m: VersusMatch, side: int, coin_ids: Array) -> int:
	var n := 0
	for id in coin_ids:
		var c := m.ledger.get_coin(id)
		if c.state == ArenaCoin.State.HELD and c.owner == side:
			n += 1
	return n

func _give(m: VersusMatch, side: int, coin_ids: Array) -> void:
	for id in coin_ids:
		ArenaCoin.to_held(m.ledger.get_coin(id), side)
