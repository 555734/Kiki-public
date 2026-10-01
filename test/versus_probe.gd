extends Node
## Do the 2v2 star match's rules hold? (The ledger calls stars coins.)
##
## The rules are a pure function of observations (VersusMatch.step), so they can
## be driven here with no runners, no physics server and no window -- which is
## the point of keeping them out of the scene, and what the four-device host
## will rely on.
##
## Two things are checked that nothing else can check: that the coin ledger is
## conserved on every tick of a long match, and that the arena built from
## 1-1's pieces is actually a fair one.

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
	_test_the_rules()
	_test_free_for_everyone()
	_test_many_sides()
	_test_themes()
	await _test_the_map()
	_test_conservation()
	_test_stealing()
	_test_winning()

	print("versus probe: %d checks failed" % failures.size())
	if failures.is_empty():
		print("the 2v2 star match holds")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("versus probe: " + f)
		get_tree().quit(1)

# ------------------------------------------------------------------ the stage
## The arena is a competition map, so what has to hold is fairness: the two
## halves mirror each other, every star point is over floor, the starts face
## each other half a lap apart, and the two ends join without a seam.
func _test_the_stage() -> void:
	_current = "the stage"
	Stage.use(Stage.Which.GREENFIELD)
	var world := _world()
	var w := VersusStageData.WIDTH

	check(w >= 2400.0 and w <= 4000.0,
		"the arena is a few screens wide, not a course (%.0fpx)" % w)
	check(Level01Data.ground()[-1].end.x == 16700.0,
		"cooperative 1-1 still has its complete original ground")

	# Mirror symmetry of every solid thing: floors, walls, blocks, conduits.
	var solids: Array[Rect2] = VersusStageData.collision_rects()
	var unmatched := 0
	for r in solids:
		var twin := Rect2(w - r.end.x, r.position.y, r.size.x, r.size.y)
		var found := false
		for o in solids:
			if o.position.is_equal_approx(twin.position) and o.size.is_equal_approx(twin.size):
				found = true
				break
		if not found:
			unmatched += 1
	check(unmatched == 0, "the arena is left-right symmetric (%d unmatched)" % unmatched)

	var points := VersusStageData.coin_points()
	check(points.size() >= 12, "stars have many places to appear (%d points)" % points.size())
	var homeless: Array[Vector2] = []
	for p in points:
		if world.floor_below(p, 120.0) == INF \
				or world.overlaps(Rect2(p - Vector2(12, 12), Vector2(24, 24))):
			homeless.append(p)
	check(homeless.is_empty(),
		"every star point is clear of solids with floor under it (%d bad)" % homeless.size())
	var closest := INF
	for i in range(points.size()):
		for k in range(i + 1, points.size()):
			closest = minf(closest, points[i].distance_to(points[k]))
	check(closest >= 50.0, "and no two share a spot (closest %.0f)" % closest)
	var left := 0
	var right := 0
	for p in points:
		if p.x < w * 0.5 - 1.0:
			left += 1
		elif p.x > w * 0.5 + 1.0:
			right += 1
	check(left == right, "as many star points on each half (%d / %d)" % [left, right])

	var starts := VersusStageData.start_positions()
	var facings := VersusStageData.start_facing()
	check(is_equal_approx(starts[0].x, w - starts[1].x) and starts[0].y == starts[1].y,
		"the two teams start at mirrored places")
	check(is_equal_approx(absf(starts[1].x - starts[0].x), w * 0.5),
		"exactly half a lap apart, the same distance either way round")
	check(facings[0] == 1 and facings[1] == -1, "facing each other")
	for i in range(2):
		check(world.floor_below(starts[i], 60.0) < INF,
			"team %s starts on the ground" % ["A", "B"][i])
		check(VersusStageData.respawn_for(i, Vector2(1600.0, 0.0)) == starts[i],
			"and comes back at its own start")

	# The join: x=WIDTH is x=0, and it is one continuous floor.
	var join_l := world.floor_below(Vector2(w - 20.0, 300.0), 200.0)
	var join_r := world.floor_below(Vector2(w + 20.0, 300.0), 200.0)
	var join_0 := world.floor_below(Vector2(-20.0, 300.0), 200.0)
	check(join_l == join_r and join_r == join_0 and join_l < INF,
		"the two ends meet in one level floor, with collision on both sides of the join")
	check(VersusStageData.extra_enemies().is_empty(), "the arena has no enemies")
	check(is_equal_approx(VersusStageData.wrap_x(-500.0), w - 500.0)
			and is_equal_approx(VersusStageData.wrap_x(w + 500.0), 500.0),
		"walking off either end comes back in at the other")
	var across := VersusStageData.nearest_image(Vector2(10.0, 0.0), Vector2(w - 10.0, 0.0))
	check(is_equal_approx(across.x, w + 10.0),
		"and two runners either side of the join are 20px apart, not a field apart")
	# A strike across the join lands, and a star across it can be taken.
	var m := _fresh()
	var seats := _seats()
	_park(seats, 0, Vector2(w - 20.0, 377.0))
	_park(seats, 1, Vector2(20.0, 377.0))
	_give(m, 1, [0])
	m.step(seats)
	_clear_field(m)
	check(m.shoot(0, Vector2(w + 20.0, 377.0)) == 1 and _held_of(m, 1, [0]) == 0,
		"a shot across the join hits")
	var star := m.ledger.get_coin(5)
	ArenaCoin.to_world(star, Vector2(8.0, 377.0), m.tick, Vector2.ZERO, 0)
	seats[0].position = Vector2(w - 8.0, 377.0)
	seats[1].position = Vector2(1600.0, 377.0)
	m.step(seats)
	check(star.state == ArenaCoin.State.HELD and star.owner == 0,
		"and a star just across it is picked up")

	# Everything is reachable: every block top is within a held jump of
	# something below it (the runner's measured held jump is ~133px).
	var tops: Array[Rect2] = VersusStageData.floors()
	var blocks: Array[Rect2] = VersusStageData.solid_decor()
	var unreachable := 0
	for b in blocks:
		var best := INF
		for s in tops + blocks:
			if s == b:
				continue
			if s.position.y <= b.position.y:
				continue
			var horizontal := maxf(0.0, maxf(s.position.x - b.end.x, b.position.x - s.end.x))
			if horizontal > 220.0:
				continue
			best = minf(best, s.position.y - b.position.y)
		if best > 125.0:
			unreachable += 1
	check(unreachable == 0, "every block row is one jump above something (%d not)" % unreachable)

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
	var heights: Dictionary = {}
	var previous := Vector2(INF, INF)
	var safe := true
	var repeats := 0
	for i in range(100):
		var p: Vector2 = first._free_point()
		same = same and p == replay._free_point()
		if p != other._free_point():
			different += 1
		regions[int(p.x / (VersusStageData.WIDTH / 4.0))] = true
		heights[int(p.y / 100.0)] = true
		if p.distance_to(previous) < 48.0:
			repeats += 1
		previous = p
		safe = safe and VersusStageData.in_bounds(p) \
			and world.floor_below(p, 80.0) != INF \
			and not world.overlaps(Rect2(p - Vector2(12, 12), Vector2(24, 24)))
	check(same, "same host seed reproduces the spawn sequence")
	check(different > 80, "different match seeds change actual spawn positions (%d)" % different)
	check(regions.size() == 4, "random stars reach all four quarters of the arena")
	check(heights.size() >= 3, "and several heights, block tops included (%d)" % heights.size())
	check(repeats == 0, "successive stars do not repeat the same spot")
	check(safe, "all random stars are clear of solids and above floor")
	var actors := _seats()
	for actor in actors:
		actor.alive = false
	for i in range(150):
		first.step(actors)
	var loose: Array[Vector2] = []
	for coin in first.ledger.coins:
		if coin.state == ArenaCoin.State.WORLD:
			loose.append(coin.position)
	check(loose.size() == VersusRules.ON_FIELD,
		"random top-up keeps %d stars loose" % VersusRules.ON_FIELD)
	check(first.ledger.conserved(),
		"random top-up preserves the %d-star ledger" % VersusRules.COIN_TOTAL)

func _test_the_rules() -> void:
	_current = "the rules"
	check(VersusRules.WIN_AT == 7, "seven stars held wins")
	check(VersusRules.COIN_TOTAL > VersusRules.WIN_AT,
		"there are more stars than it takes to win (%d)" % VersusRules.COIN_TOTAL)

## みんなで: eight sides, most of them empty or far away. A strike reaches
## everyone in front of it, two strikes on one runner cost one star, the first
## PERSON to seven wins, and an empty chair never takes part.
func _test_many_sides() -> void:
	_current = "free-for-all"
	var starts := VersusStageData.start_positions()
	check(starts.size() == 8, "there are eight starts")
	var world := _world()
	var mirrored := true
	var grounded := true
	var closest := INF
	for i in range(starts.size()):
		grounded = grounded and world.floor_below(starts[i], 60.0) < INF \
			and not world.overlaps(Rect2(starts[i] - Balance.RUNNER_SIZE * 0.5, Balance.RUNNER_SIZE))
		if i % 2 == 0:
			mirrored = mirrored and is_equal_approx(starts[i].x, VersusStageData.WIDTH - starts[i + 1].x) \
				and starts[i].y == starts[i + 1].y
		for k in range(i + 1, starts.size()):
			closest = minf(closest, starts[i].distance_to(starts[k]))
	check(grounded, "every start stands on floor, inside nothing")
	check(mirrored, "and they come in mirrored pairs")
	check(closest > 200.0, "and nobody starts on top of anybody (closest %.0f)" % closest)

	var numbers := VersusRules.numbers_for(VersusRoster.RoomMode.FREE_FOR_ALL, 8)
	check(int(numbers["on_field"]) == 1 and VersusRules.ON_FIELD == 1,
		"one star on the field at a time, whatever the head count")
	var m := VersusMatch.new()
	m.setup(world, 777, 8, numbers)
	var seats: Array = []
	for i in range(8):
		var seat := VersusMatch.Seat.new()
		seat.team = i
		seat.position = starts[i]
		seat.alive = i < 3       # three people in an eight-chair room
		seat.can_act = seat.alive
		seats.append(seat)
	# A shot hits the one runner nearest the aim point, not everybody near it.
	seats[1].position = Vector2(1500.0, 377.0)
	seats[2].position = Vector2(1580.0, 377.0)
	_give(m, 1, [0, 1])
	_give(m, 2, [2, 3])
	m.step(seats)
	_clear_field(m)
	check(m.shoot(0, Vector2(1590.0, 377.0)) == 2, "a shot hits the runner nearest the aim")
	check(_held_of(m, 2, [2, 3]) == 1 and _held_of(m, 1, [0, 1]) == 2,
		"that one runner drops one star, nobody else")
	check(m.ledger.conserved(), "with the twenty-star ledger balanced")
	check(m.shoot(0, Vector2(1500.0, 377.0)) == -1,
		"and the same player cannot fire again straight away")

	# Two stompers landing on one head in the same instant: one star.
	m = VersusMatch.new()
	m.setup(world, 778, 8, numbers)
	var victim := Vector2(1500.0, 377.0)
	seats[2].position = victim
	seats[2].velocity = Vector2.ZERO
	for k in [0, 1]:
		seats[k].position = victim + Vector2(-8.0 + 16.0 * float(k), -Balance.RUNNER_SIZE.y)
		seats[k].velocity = Vector2(0.0, 400.0)
	_give(m, 2, [0, 1, 2])
	_clear_field(m)
	m.step(seats)
	check(_held_of(m, 2, [0, 1, 2]) == 2, "two stomps landing together cost one star")
	for k in [0, 1]:
		seats[k].velocity = Vector2.ZERO
		seats[k].position = starts[k]

	# Seven held by one person wins; an empty chair never picks anything up.
	m = VersusMatch.new()
	m.setup(world, 779, 8, numbers)
	var empty_took := false
	for t in range(400):
		m.step(seats)
		for c in m.ledger.coins:
			if c.state == ArenaCoin.State.HELD and c.owner >= 3:
				empty_took = true
	check(not empty_took, "empty chairs never pick a star up")
	var ids: Array = []
	for i in range(VersusRules.FFA_WIN_AT):
		ids.append(10 + i)
	_give(m, 2, ids)
	m.step(seats)
	check(m.phase == VersusMatch.Phase.OVER and m.winner == 2,
		"seven held by one person wins it for that person")

## 1-1, 1-2 and 1-3 are the same arena painted three ways. Nothing anybody
## collides with, no star point and no start may differ between them, or the
## stage choice would change the match and the guests (who repaint when the
## WELCOME arrives) would briefly disagree with the host about the world.
func _test_themes() -> void:
	_current = "stage themes"
	VersusStageData.use_theme(Stage.Which.GREENFIELD)
	var solids := VersusStageData.collision_rects()
	var points := VersusStageData.coin_points()
	var starts := VersusStageData.start_positions()
	for which in VersusStageData.THEMES:
		VersusStageData.use_theme(which)
		var name := VersusStageData.theme_label(which)
		check(Stage.current() == which, "%s: the stage art switches with it" % name)
		check(VersusStageData.collision_rects() == solids
				and VersusStageData.coin_points() == points
				and VersusStageData.start_positions() == starts,
			"%s: every collision rectangle, star point and start is the same" % name)
		# Every floor's walkable top is painted, at exactly its height.
		var painted := VersusStageData.painted_slabs()
		var bare := 0
		for f in VersusStageData.floors():
			var covered := false
			for p in painted:
				for lap in VersusStageData.LAPS:
					var q := Rect2(p.position + Vector2(VersusStageData.WIDTH * float(lap), 0.0), p.size)
					if is_equal_approx(q.position.y, f.position.y) \
							and q.position.x <= f.position.x + 0.5 and q.end.x >= f.end.x - 0.5:
						covered = true
			if not covered:
				bare += 1
		check(bare == 0, "%s: every floor is painted at its own height (%d bare)" % [name, bare])
		# Every solid block row and conduit is drawn as something.
		var hidden := 0
		for r in VersusStageData.solid_decor():
			var drawn := false
			for p in painted:
				if p.encloses(r):
					drawn = true
			for d in VersusStageData.decor():
				var kind := String(d["type"])
				var at: Vector2 = d["pos"]
				if kind in ["blocks", "ruin_blocks"]:
					var cell := float(d.get("cell", 46.0))
					if Rect2(at, Vector2(cell * float(d.get("count", 1)), cell)).intersects(r):
						drawn = true
				elif kind == "conduit" and r.has_point(at - Vector2(0, 2)):
					drawn = true
				elif d.has("rect") and Rect2(d["rect"]).encloses(r):
					drawn = true
			if not drawn:
				hidden += 1
		check(hidden == 0, "%s: every solid piece is visible (%d invisible)" % [name, hidden])
		check(VersusStageData.decor().size() >= 8, "%s: and it has its own scenery" % name)
		if Stage.water_y() != INF:
			check(Stage.water_y() > VersusStageData.FLOOR_TOP + 40.0
					and Stage.water_y() < VersusStageData.kill_y(),
				"%s: its water lies below every floor and above the kill line" % name)
	VersusStageData.use_theme(Stage.Which.GREENFIELD)

## Versus is free: a player who has not bought the full version can make a
## room, join one and play all of it. Asserted on the code itself, so a gate
## added anywhere on the versus path later fails here by name.
func _test_free_for_everyone() -> void:
	_current = "free for everyone"
	var paths := [
		"res://src/ui/versus_panel.gd",
		"res://src/net/eos/eos_versus_lobby.gd",
		"res://src/versus/net/versus_eos_transport.gd",
		"res://src/versus/net/versus_host.gd",
		"res://src/versus/net/versus_client.gd",
		"res://src/versus/versus_main.gd",
		"res://src/versus/versus_hud.gd",
		"res://src/versus/versus_controls.gd",
	]
	var gated: Array[String] = []
	for path in paths:
		var code := FileAccess.get_file_as_string(path)
		for word in ["Entitlement.", "can_host(", "can_play(which", "is_free("]:
			if code.contains(word):
				gated.append("%s uses %s" % [path.get_file(), word])
	check(gated.is_empty(), "nothing on the versus path checks the purchase (%s)" % ", ".join(gated))
	var menu := FileAccess.get_file_as_string("res://src/ui/net_panel.gd")
	var entry := menu.find("func _on_versus()")
	check(entry >= 0, "the stage screen has a versus entry")
	var body := menu.substr(entry, menu.find("\nfunc ", entry + 1) - entry)
	check(not body.contains("Entitlement"), "and it opens without a purchase check")
	check(not menu.contains("_locked_actions.append(versus"), "and it is never locked")

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
	ArenaCoin.to_world(m.ledger.get_coin(0), Vector2(2600.0, 300.0), m.tick,
		Vector2.ZERO, 0)
	ArenaCoin.to_world(m.ledger.get_coin(1), Vector2(700.0, 300.0), m.tick,
		Vector2.ZERO, 0)
	await get_tree().physics_frame

	var marks: Array = arena.map_marks()
	var kinds := {}
	var outside := 0
	for mark in marks:
		kinds[String(mark["kind"])] = int(kinds.get(String(mark["kind"]), 0)) + 1
		var f := float(mark["x01"])
		var g := float(mark["y01"])
		if f < 0.0 or f > 1.0 or g < 0.0 or g > 1.0:
			outside += 1
	check(kinds.has("you") and int(kinds["you"]) == 1, "the map shows you, once")
	check(kinds.has("them") and int(kinds["them"]) == 1, "and the other runner")
	check(int(kinds.get("star", 0)) >= 2,
		"and every star on the ground (%d)" % int(kinds.get("star", 0)))
	check(outside == 0, "with everything placed inside the map (%d outside)" % outside)

	var far := VersusStageData.lap_fraction(VersusStageData.WIDTH - 200.0)
	var near := VersusStageData.lap_fraction(200.0)
	check(far > near + 0.8,
		"the far end is drawn at the far side of the map (%.2f vs %.2f)" % [far, near])
	check(VersusStageData.height_fraction(VersusStageData.FLOOR_TOP) >
			VersusStageData.height_fraction(180.0),
		"and a block top is drawn above the floor")

	# Off-screen things get an edge arrow pointing the SHORT way round the
	# loop: from team A's start (x=800) the star at x=2600 is 1,400px to the
	# left across the join, not 1,800px to the right. The other runner, half a
	# lap away, gets an arrow too.
	var arrows: Array = arena.offscreen_marks()
	var right_star := false
	var them := false
	for mark in arrows:
		if String(mark["kind"]) == "star" and Vector2(mark["dir"]).x < -0.5 \
				and float(mark["distance"]) < 1500.0:
			right_star = true
		if String(mark["kind"]) == "them":
			them = true
	check(right_star, "an off-screen star gets an edge arrow, the short way round")
	check(them, "and so does the other team's runner, half a lap away")
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
	_current = "shots and stomps"
	# A shot costs the victim exactly one star, and it goes to the ground
	# rather than to the shooter.
	var m := _fresh()
	var seats := _seats()
	_park(seats, 0, Vector2(1400.0, 377.0))
	_park(seats, 1, Vector2(1800.0, 377.0))
	_give(m, 1, [0, 1, 2])
	m.step(seats)
	_clear_field(m)
	check(m.shoot(0, Vector2(1790.0, 380.0)) == 1, "a shot within reach of the aim hits")
	check(_held_of(m, 1, [0, 1, 2]) == 2, "a hit costs the victim one star")
	check(_held_of(m, 0, [0, 1, 2]) == 0, "and the shooter is not handed it")
	check(m.ledger.count_in(ArenaCoin.State.WORLD) == 1, "it is the one star on the ground")
	m.step(seats)
	var hurt := false
	for e in m.events:
		if String(e["kind"]) == "hurt" and int(e["side"]) == 1:
			hurt = true
	check(hurt, "and the victim is told it was hurt")

	# Nothing else drops while a star is loose; the victim keeps theirs.
	for t in range(VersusRules.SHOT_COOLDOWN_TICKS + VersusRules.HIT_IMMUNE_TICKS + 2):
		m.step(seats)
	check(m.ledger.count_in(ArenaCoin.State.WORLD) == 1, "the star is still loose")
	m.shoot(0, Vector2(1800.0, 377.0))
	check(_held_of(m, 1, [0, 1, 2]) == 2 and m.ledger.count_in(ArenaCoin.State.WORLD) == 1,
		"so a second hit costs nothing: one star on the field at a time")

	# Out of reach misses; a hit runner is briefly untouchable.
	m = _fresh()
	seats = _seats()
	_park(seats, 0, Vector2(1400.0, 377.0))
	_park(seats, 1, Vector2(1800.0, 377.0))
	_give(m, 1, [0])
	m.step(seats)
	_clear_field(m)
	check(m.shoot(0, Vector2(1800.0 + VersusRules.SHOT_ASSIST_RADIUS + 30.0, 377.0)) == -1,
		"a shot beyond the aim assist misses")
	check(_held_of(m, 1, [0]) == 1, "and costs nothing")

	# Stomp: falling feet on a head.
	m = _fresh()
	seats = _seats()
	_park(seats, 1, Vector2(1800.0, 377.0))
	_park(seats, 0, Vector2(1800.0, 377.0 - Balance.RUNNER_SIZE.y))
	seats[0].velocity = Vector2(0.0, 300.0)
	_give(m, 1, [0])
	_clear_field(m)
	m.step(seats)
	var bounced := false
	for e in m.events:
		if String(e["kind"]) == "bounce" and int(e["side"]) == 0:
			bounced = true
	check(_held_of(m, 1, [0]) == 0, "landing on a head knocks a star loose")
	check(bounced, "and the stomper bounces")
	# Standing side by side, or rising through somebody, is not a stomp.
	m = _fresh()
	seats = _seats()
	_park(seats, 1, Vector2(1800.0, 377.0))
	_park(seats, 0, Vector2(1800.0, 377.0 - Balance.RUNNER_SIZE.y))
	seats[0].velocity = Vector2(0.0, -300.0)
	_give(m, 1, [0])
	m.step(seats)
	check(_held_of(m, 1, [0]) == 1, "jumping up through someone is not a stomp")

	# The old close-range strike does nothing now.
	m = _fresh()
	seats = _seats()
	_park(seats, 0, Vector2(1755.0, 377.0))
	_park(seats, 1, Vector2(1800.0, 377.0))
	seats[0].facing = 1
	_give(m, 1, [0])
	m.step(seats)
	seats[0].strike_seq += 1
	for t in range(20):
		m.step(seats)
	check(_held_of(m, 1, [0]) == 1, "a close-range strike no longer takes a star")

	# Death: one star back on the field (if it has room), the rest to the pool.
	m = _fresh()
	seats = _seats()
	_park(seats, 0, Vector2(1400.0, 377.0))
	_park(seats, 1, Vector2(1800.0, 377.0))
	m.step(seats)
	_clear_field(m)
	_give(m, 0, [0, 1, 2, 3])
	m.note_death(0)
	check(_held_of(m, 0, [0, 1, 2, 3]) == 0, "dying empties the hand")
	check(m.ledger.count_in(ArenaCoin.State.WORLD) == 1, "one of them is back on the field")
	check(m.ledger.conserved(), "with the ledger still balanced")

## Put every loose star back in the pool, so a test starts with none on the
## field (the spawner may have placed one).
func _clear_field(m: VersusMatch) -> void:
	for c in m.ledger.coins:
		if c.state == ArenaCoin.State.WORLD:
			ArenaCoin.to_recycle(c, m.tick)
	m._spawn_in = 100000

# --------------------------------------------------------------- the ending
func _test_winning() -> void:
	_current = "winning"
	var m := _fresh()
	var seats := _seats()
	_park(seats, 0, Vector2(200.0, 377.0))
	_park(seats, 1, Vector2(3000.0, 377.0))
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
