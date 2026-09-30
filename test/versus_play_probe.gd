extends Node
## Does the 2v2 star match work as a SCENE, not just as rules?
##
## versus_probe drives VersusMatch with made-up observations, which proves the
## rules and proves nothing about the thing you actually launch. This one builds
## the real scene -- real Runner nodes, the real arena collision, real physics -- and
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

## Both runners have to end up standing on the arena's ground, not falling through it.
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

	await _test_the_pit()
	await _test_the_walls()
	_test_no_enemies()

## The arena is built from 1-1's pieces but not from its course: no enemy of
## 1-1's is in the scene, so no machine simulates one the others do not see.
func _test_no_enemies() -> void:
	_current = "no enemies"
	var found := 0
	for node in arena.find_children("*", "", true, false):
		if node is Enemy:
			found += 1
	check(found == 0, "the arena has no enemies in it (%d)" % found)
	var goal := 0
	for node in arena.find_children("*", "", true, false):
		if node is Goal or node is Checkpoint:
			goal += 1
	check(goal == 0, "and no 1-1 goal or checkpoints")

## The pits between the steps and the middle are real: fall in and the whole
## hand goes back into play, and the runner comes back at its own start.
func _test_the_pit() -> void:
	_current = "the pit"
	var m: VersusMatch = arena.match_rules
	var r: Runner = arena.runners[0]
	_give_to(m, 0, [1, 2])
	check(_held_of(m, 0, [1, 2]) == 2, "the runner is carrying the two stars")
	r.global_position = Vector2(1230.0, 500.0)
	r.velocity = Vector2.ZERO
	await _tick(60)
	check(m.ledger.count_held_by(0) == 0, "falling into a pit costs the whole hand")
	check(m.ledger.conserved(), "and every star is still accounted for")
	await _tick(VersusRules.RESPAWN_TICKS + 8)
	check(r.state != Runner.State.DEAD, "and the runner comes back")
	check(r.global_position.distance_to(VersusStageData.start_positions()[0]) < 80.0,
		"at its own team's start")

## Nobody leaves the field sideways: running into an end wall stops you.
func _test_the_walls() -> void:
	_current = "the walls"
	var r: Runner = arena.runners[0]
	r.global_position = Vector2(120.0, 360.0)
	r.velocity = Vector2.ZERO
	for i in range(90):
		arena.input.hubs[0].drive_runner(-1.0, 0.0, i % 20 < 10, true)
		await get_tree().physics_frame
	arena.input.hubs[0].drive_runner(0.0, 0.0, false, false)
	await _tick(30)
	check(r.global_position.x > VersusStageData.LEFT,
		"running and jumping at the left wall stays inside (x=%.0f)" % r.global_position.x)
	check(r.global_position.y < VersusStageData.kill_y(), "and on the ground")

	# A block row is one held jump up: a jump from the floor beside the first
	# row rises clear of its top. The scene's own keyboard poll is paused for
	# this, or it would release the jump between the probe's frames and a
	# held jump would measure as a string of taps.
	var row: Rect2 = VersusStageData.solid_decor()[0]
	r.global_position = Vector2(row.position.x - 90.0, VersusStageData.FLOOR_TOP - 24.0)
	r.velocity = Vector2.ZERO
	await _tick(6)
	arena.set_physics_process(false)
	var peak := INF
	for i in range(30):
		arena.input.hubs[0].drive_runner(0.0, 0.0, i < 20, false)
		await get_tree().physics_frame
		peak = minf(peak, r.global_position.y + Balance.RUNNER_SIZE.y * 0.5)
	arena.input.hubs[0].drive_runner(0.0, 0.0, false, false)
	arena.set_physics_process(true)
	await _tick(30)
	check(peak < row.position.y - 10.0,
		"a jump from the floor clears the lowest block row (feet %.0f, top %.0f)"
			% [peak, row.position.y])

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
