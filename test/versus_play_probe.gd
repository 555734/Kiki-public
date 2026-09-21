extends Node
## Does the 1-1 coin match work as a SCENE, not just as rules?
##
## versus_probe drives VersusMatch with made-up observations, which proves the
## rules and proves nothing about the thing you actually launch. This one builds
## the real scene -- real Runner nodes, real 1-1 collision, real physics -- and
## drives it through the input hubs the way a player's keyboard does.
##
## It is the check that would have caught every wiring mistake the rules probe
## cannot see: a runner that falls through the floor, a strike that never
## reaches, an input hub connected to the wrong runner, a coin that can be
## picked up from across the map.

var failures: Array[String] = []
var _current: String = ""
var arena: Node2D = null

func check(ok: bool, label: String) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		failures.append("%s: %s" % [_current, label])
		print("  FAIL  %s" % label)

func _ready() -> void:
	arena = load("res://src/versus/versus_main.tscn").instantiate()
	add_child(arena)
	# The scene polls the keyboard itself; nothing is pressed in a probe, so the
	# hubs are driven directly below instead.
	# Both runners start ABOVE their ledge and fall onto it, so give them long
	# enough to land before asking whether they are standing.
	for i in range(40):
		await get_tree().physics_frame
	_run()

func _run() -> void:
	_test_standing()
	await _test_walking()
	await _test_taking_a_coin()
	await _test_striking()

	print("versus play probe: %d checks failed" % failures.size())
	if failures.is_empty():
		print("the match plays")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("versus play probe: " + f)
		get_tree().quit(1)

func _tick(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

## Both runners have to end up standing on 1-1's ground, not falling through it.
func _test_standing() -> void:
	_current = "standing"
	for i in range(2):
		var r: Runner = arena.runners[i]
		check(r.on_ground(),
			"runner %d is standing on the ledge it started over" % (i + 1))
		check(r.global_position.y < VersusStageData.kill_y(),
			"and has not fallen through it")

## Walking right has to move the runner right, and only that runner. An input
## hub wired to both is the mistake this catches.
func _test_walking() -> void:
	_current = "walking"
	var before0: float = arena.runners[0].global_position.x
	var before1: float = arena.runners[1].global_position.x
	for i in range(40):
		arena.input.hubs[0].drive_runner(1.0, 0.0, false, false)
		await get_tree().physics_frame
	arena.input.hubs[0].drive_runner(0.0, 0.0, false, false)
	var moved0: float = arena.runners[0].global_position.x - before0
	var moved1: float = absf(arena.runners[1].global_position.x - before1)
	print("    runner 1 moved %.0fpx, runner 2 moved %.0fpx" % [moved0, moved1])
	check(moved0 > 100.0, "holding right walks runner 1 right (%.0fpx)" % moved0)
	check(moved1 < 2.0, "and leaves runner 2 where it was (%.0fpx)" % moved1)

## A coin on the ground next to a runner is taken; a coin across the map is not.
func _test_taking_a_coin() -> void:
	_current = "taking a coin"
	var m: VersusMatch = arena.match_rules
	var here: Vector2 = arena.runners[0].global_position
	var c := m.ledger.get_coin(VersusRules.COIN_TOTAL - 1)
	ArenaCoin.to_world(c, here, m.tick, Vector2.ZERO, 0)
	await _tick(4)
	check(c.state == ArenaCoin.State.HELD and c.owner == 0,
		"a coin at a runner's feet is picked up")

	var far := m.ledger.get_coin(VersusRules.COIN_TOTAL - 2)
	ArenaCoin.to_world(far, here + Vector2(600.0, 0.0), m.tick, Vector2.ZERO, 0)
	await _tick(4)
	check(far.state == ArenaCoin.State.WORLD,
		"and a coin 600px away is not")

## The whole point of the mode: walk up to the other runner, press strike, and
## take a coin off them.
func _test_striking() -> void:
	_current = "striking"
	var m: VersusMatch = arena.match_rules
	var victim: Runner = arena.runners[1]
	var attacker: Runner = arena.runners[0]

	# Stand the attacker next to the victim, facing it.
	attacker.global_position = victim.global_position + Vector2(-34.0, 0.0)
	attacker.velocity = Vector2.ZERO
	attacker.facing = 1
	var coin := m.ledger.get_coin(0)
	ArenaCoin.to_held(coin, 1)
	var hp_before := victim.hp
	await _tick(2)

	arena.input.pads[0].strike_seq += 1
	await _tick(VersusRules.STRIKE_STARTUP_TICKS + 4)

	check(coin.state == ArenaCoin.State.WORLD,
		"a strike knocks the coin out of the other runner")
	check(victim.hp < hp_before,
		"and costs them health as well (%d -> %d)" % [hp_before, victim.hp])
	check(m.ledger.conserved(), "the ledger survives a real strike")

	await _test_the_spikes()
	await _test_a_lap()
	_test_the_enemies()

## The extra enemies are data until something builds them. This is the check
## that they became nodes: the versus_probe can only say the list is right.
func _test_the_enemies() -> void:
	_current = "the enemies"
	var alive := 0
	for node in arena.find_children("*", "", true, false):
		if node.is_in_group("enemy"):
			alive += 1
	# 1-1's enemies that are INSIDE the circuit, not all of 1-1's: the versus
	# builder frees everything past the connecting steps, because the circuit
	# is shorter than the stage it is cut from.
	var want := VersusStageData.circuit_enemies().size() \
		+ VersusStageData.extra_enemies().size()
	print("    %d enemy nodes in the scene, expecting %d" % [alive, want])
	# 1-1 builds every one of its own, and the circuit adds its own on top.
	check(alive == want,
		"1-1's enemies and the circuit's extras are all in the scene (%d of %d)"
			% [alive, want])

## Run off the end of the stage and come out at the start, with nothing to
## show for it. The seam is the one thing in this mode that has to be
## invisible, so what is measured is the things that would give it away: a
## change in height, and a camera that has to travel.
func _test_a_lap() -> void:
	_current = "a lap"
	var r: Runner = arena.runners[0]
	var cam: Camera2D = arena._camera

	# On the last of the added steps, just short of the join.
	r.global_position = Vector2(VersusStageData.LOOP_TO - 260.0, 300.0)
	r.velocity = Vector2.ZERO
	await _tick(40)
	var height_before := r.global_position.y
	var lead_before := absf(cam.global_position.x - r.global_position.x)
	check(r.on_ground(), "standing on the steps that close the circuit")

	# The measurement is of the WRAP ITSELF, on the tick it happens -- not of
	# the run either side of it. The staircase legitimately descends 55px a
	# step, so comparing a point mid-staircase with one on the plateau says
	# nothing about the seam. The first version of this check did that and
	# reported a step it had walked down on purpose.
	var wrapped := false
	var y_before := 0.0
	var y_after := 0.0
	var jump_in_y := 0.0
	var worst_lead := 0.0
	var was := r.global_position
	for i in range(220):
		arena.input.hubs[0].drive_runner(1.0, 0.0, false, true)
		await get_tree().physics_frame
		var now := r.global_position
		if not wrapped and now.x < was.x - 4000.0:
			wrapped = true
			y_before = was.y
			y_after = now.y
			jump_in_y = absf(now.y - was.y)
		was = now
		worst_lead = maxf(worst_lead, absf(cam.global_position.x - now.x))
	arena.input.hubs[0].drive_runner(0.0, 0.0, false, false)
	await _tick(30)

	print("    on the wrap tick: y %.1f -> %.1f; camera lead %.0f -> worst %.0f"
		% [y_before, y_after, lead_before, worst_lead])
	check(wrapped, "running off the end brings you back to the start")
	check(jump_in_y < 2.0,
		"and the wrap itself moves nothing but x (y moved %.2fpx)" % jump_in_y)
	# The give-away. If the wrap moved the runner and not the camera, the
	# camera would be a whole lap behind and spend seconds catching up.
	check(worst_lead < 600.0,
		"and the camera never falls behind (worst %.0fpx)" % worst_lead)
	check(r.state != Runner.State.DEAD, "crossing the join is not fatal")

	# And back the other way: the steps have to be climbable, or the circuit
	# only runs one way round.
	r.global_position = Vector2(VersusStageData.LOOP_FROM + 120.0, 300.0)
	r.velocity = Vector2.ZERO
	await _tick(40)
	var from_x := r.global_position.x
	for i in range(240):
		# Hold left, and jump often enough to take a 55px step.
		arena.input.hubs[0].drive_runner(-1.0, 0.0, i % 24 < 10, true)
		await get_tree().physics_frame
	arena.input.hubs[0].drive_runner(0.0, 0.0, false, false)
	await _tick(20)
	var climbed := VersusStageData.wrap_x(from_x) \
		- VersusStageData.wrap_x(r.global_position.x)
	print("    going the other way, moved %.0fpx" % climbed)
	check(r.global_position.x > VersusStageData.LOOP_TO - 2000.0
			or climbed < -1000.0,
		"the circuit can be run the other way round too")

## 1-1's own spike strip kills the runner by itself, through the runner's
## contact handling -- this mode never calls for it. So the mode has to NOTICE,
## or a runner killed by the spikes lies there holding its coins for good.
func _test_the_spikes() -> void:
	_current = "the spikes"
	var m: VersusMatch = arena.match_rules
	var r: Runner = arena.runners[0]
	var spikes: Dictionary = Stage.hazards()[0]
	# Named coins, not a total: this runner already picked one up earlier in
	# the probe, and a global count would be measuring that as well.
	_give_to(m, 0, [1, 2])
	check(_held_of(m, 0, [1, 2]) == 2, "the runner is carrying the two coins")

	# Drop it onto the strip.
	r.global_position = Vector2(spikes["pos"].x, spikes["pos"].y - 60.0)
	r.velocity = Vector2.ZERO
	await _tick(30)
	check(m.ledger.count_held_by(0) == 0,
		"landing on 1-1's spikes costs the whole hand")
	check(_held_of(m, 0, [1, 2]) == 0, "including the two it was given")
	check(m.ledger.conserved(), "and every coin is still accounted for")
	await _tick(VersusRules.RESPAWN_TICKS + 8)
	check(r.state != Runner.State.DEAD, "and the runner comes back")
	check(VersusStageData.in_bounds(r.global_position),
		"inside the arena")

func _held_of(m: VersusMatch, side: int, ids: Array) -> int:
	var n := 0
	for id in ids:
		var c := m.ledger.get_coin(id)
		if c.state == ArenaCoin.State.HELD and c.owner == side:
			n += 1
	return n

func _give_to(m: VersusMatch, side: int, ids: Array) -> void:
	for id in ids:
		ArenaCoin.to_held(m.ledger.get_coin(id), side)
