extends Node
## Stage 1-10: registration, data validity, and a scripted playthrough of the
## real game -- Runner physics, Guardian abilities, every machine live -- from
## the start to the goal, area by area. Enemies stay live too; the scripted
## guardian shoots the ones in the way, which is the co-op design.
##
##   godot --headless --path . --fixed-fps 60 res://test/finale_stage_probe.tscn
##   FINALE_ONLY=rail,hive   ... to run some areas only (each starts at its checkpoint)
const Main = preload("res://src/main.tscn")
var failures: Array[String] = []
var checks := 0
var main: Node2D
var r: Runner
var hub: InputHub
var log_moves := OS.get_environment("FINALE_LOG") != ""
var _sprint := false
var _axis := 0.0
var _jump := false
var _crouch := false

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("%s %s" % ["ok  " if ok else "FAIL", message])
	if not ok:
		failures.append(message)

# ------------------------------------------------------------ input helpers
func _apply() -> void:
	hub.drive_runner(_axis, 1.0 if _crouch else 0.0, _jump, _sprint)

func frames(n: int) -> void:
	for i in n:
		_apply()
		await get_tree().physics_frame

func hold(axis: float, sprint: bool = false) -> void:
	_axis = axis
	_sprint = sprint
	_apply()

func release() -> void:
	_axis = 0.0
	_sprint = false
	_jump = false
	_crouch = false
	_apply()

## Press jump for `held` frames (a full jump is ~18).
func jump(held: int = 18) -> void:
	_jump = true
	await frames(held)
	_jump = false
	await frames(1)

## Jump and steer so the feet come down on `feet` (world). `double` adds an
## air jump at the apex. Returns once landed (or after `limit` frames).
func hop_to(feet: Variant, double: bool = false, held: int = 18, limit: int = 120) -> bool:
	var pressed := 0
	var doubled := not double
	var target := func() -> Vector2: return feet.call() if feet is Callable else feet
	_jump = true
	for i in limit:
		var dx: float = target.call().x - r.global_position.x
		_axis = clampf(dx / 28.0, -1.0, 1.0)
		_sprint = absf(dx) > 160.0
		pressed += 1
		if pressed == held:
			_jump = false
		if not doubled and pressed > held + 2 and r.velocity.y > -60.0:
			doubled = true
			_jump = true
			pressed = held - 10
		await frames(1)
		if r.state == Runner.State.HANG:
			# Caught the lip: release and press again to climb up from the hang.
			_jump = false
			await frames(1)
			_jump = true
			pressed = 0
			continue
		if i > 4 and r.is_on_floor():
			break
		if r.state == Runner.State.DEAD:
			break
	_jump = false
	_axis = 0.0
	_sprint = false
	await frames(1)
	return r.is_on_floor() and absf(r.global_position.y + 23.0 - target.call().y) < 12.0

## Run (toward axis) until `cond` holds, up to `limit` frames.
func run_until(cond: Callable, axis: float, sprint: bool = false, limit: int = 600) -> bool:
	hold(axis, sprint)
	for i in limit:
		if cond.call():
			return true
		if r.state == Runner.State.DEAD:
			return false
		await frames(1)
	return cond.call()

## Hold right and hop over whatever blocks the way, until `cond`.
func advance_until(cond: Callable, sprint: bool = false, limit: int = 900) -> bool:
	for i in limit:
		if cond.call():
			return true
		if r.state == Runner.State.DEAD:
			return false
		hold(1.0, sprint)
		if r.is_on_floor() and r.is_on_wall():
			await jump(16)
		else:
			await frames(1)
	return cond.call()

func wait_until(cond: Callable, limit: int = 600) -> bool:
	for i in limit:
		if cond.call():
			return true
		if r.state == Runner.State.DEAD:
			return false
		await frames(1)
	return cond.call()

func x_past(x: float) -> Callable:
	return func() -> bool: return r.global_position.x >= x

func x_before(x: float) -> Callable:
	return func() -> bool: return r.global_position.x <= x

func grounded() -> Callable:
	return func() -> bool: return r.is_on_floor()

func standing_on(rect: Rect2) -> bool:
	var feet := r.global_position + Vector2(0, Balance.RUNNER_SIZE.y * 0.5)
	return r.is_on_floor() and feet.x >= rect.position.x - 4 and feet.x <= rect.end.x + 4 \
		and absf(feet.y - rect.position.y) < 8.0

func at(label: String) -> void:
	if log_moves:
		print("    %s at %s v=%s state=%d hp=%d refusal=%s" % [label, r.global_position.round(), r.velocity.round(), r.state, r.hp, main.guardian._last_refusal])

func place_platform(world: Vector2, path := PackedVector2Array()) -> bool:
	main.guardian.select_slot(1)
	main.guardian.place_path = path
	var before: int = main.guardian.holograms_of(Hologram.Kind.PLATFORM).size()
	main.guardian.use_active(world)
	main.guardian.place_path = PackedVector2Array()
	return main.guardian.holograms_of(Hologram.Kind.PLATFORM).size() > before or main.guardian._last_refusal == ""

func place_wall(world: Vector2) -> void:
	main.guardian.select_slot(2)
	main.guardian.use_active(world)

func shoot(world: Vector2) -> void:
	main.guardian.select_slot(3)
	main.input_hub.aim_at_world(world)
	main.guardian.use_active(world)

## The guardian's ordinary job: snipe enemies close ahead of the runner.
var _cover := true
func _physics_process(_delta: float) -> void:
	if main == null or not is_instance_valid(main) or not _cover or r == null:
		return
	if Clock.tick % 4 != 0:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or e.is_queued_for_deletion():
			continue
		var d: Vector2 = (e as Node2D).global_position - r.global_position
		var reach := 900.0 if e.get("kind") == "rail_gunner" else (700.0 if e is Turret else 330.0)
		if d.length() < reach and (e as Node2D).visible:
			shoot((e as Node2D).global_position)
			return

## Respawn at a checkpoint (index from 1) as a real checkpoint restart.
func from_checkpoint(index: int) -> void:
	release()
	main._respawn_timer = -1.0
	main.guardian.clear_constructs()
	var cp: Vector2 = Stage.checkpoints()[index - 1]
	# As if the flag had just been touched (flags already passed stay lit).
	GameState.checkpoint_index = index
	GameState.checkpoint_position = cp + Vector2(0, 26)
	main.runner.respawn(cp + Vector2(0, 26))
	await frames(2)
	main._do_respawn()
	await frames(4)

# -------------------------------------------------------------------- run
func run() -> void:
	Stage.use(Stage.Which.FINALE)
	if log_moves:
		Events.runner_damaged.connect(func(hp: int, _m: int) -> void:
			if r != null:
				print("    damaged hp=%d at %s" % [hp, r.global_position.round()]))
	_static_checks()
	main = Main.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("NetPanel").queue_free()
	hub = main.input_hub
	hub.scripted = true
	r = main.runner
	await frames(4)
	var only: Array = []
	if OS.get_environment("FINALE_ONLY") != "":
		only = OS.get_environment("FINALE_ONLY").split(",")
	# The goal run goes last: reaching the goal clears the run for good
	# (invulnerable runner, frozen enemies), as it does in the game.
	var areas := ["grass", "storm", "sand", "lava", "geyser", "rail", "hive", "giant", "bone",
		"solo", "mechanics", "enemies", "title"]
	for name in areas:
		if not only.is_empty() and not only.has(name):
			continue
		print("--- area ", name)
		var ok: bool = await call("area_" + name)
		check(ok and r.state != Runner.State.DEAD, "area %s traversed (runner at %s)" % [name, r.global_position.round()])
		release()
	if only.is_empty() or only.has("restart"):
		await _restart_checks()
	main.free()
	Stage.use(Stage.Which.GREENFIELD)
	print("finale stage probe: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAILED: ", f)
	get_tree().quit(0 if failures.is_empty() else 1)

func _static_checks() -> void:
	check(Stage.Which.FINALE == 15 and Stage.Which.PARADE == 14 and Stage.Which.ROYAL_ARENA == 13,
		"handshake stage values preserved; FINALE appended as 15")
	check(Stage.stage_number() == "1-10" and Stage.stage_name() == "THE LAST RUN", "1-10 is THE LAST RUN")
	for f in Stage.REQUIRED:
		check(Stage.data().has_method(f), "data answers " + f)
	var errs := StageSpecSchema.errors(Stage.enemies(), Stage.gimmicks())
	check(errs.is_empty(), "every enemy/gimmick spec is valid: %s" % [errs])
	check(LevelBuilder.unknown_types(Stage.enemies(), Stage.gimmicks()).is_empty(), "builder knows every type")
	check(not StageCards.for_which(Stage.Which.FINALE).is_empty(), "1-10 has a stage-select card")
	check(not Stage.is_free(Stage.Which.FINALE), "1-10 follows the paid range (free list unchanged)")
	var zones: Array[Dictionary] = Stage.data().zones()
	check(zones.size() == 9, "nine areas")
	# Network range: everything the runner can stand on fits the snapshot.
	var lo := INF
	var hi := -INF
	for g in Stage.ground():
		lo = minf(lo, g.position.y)
		hi = maxf(hi, g.position.x + g.size.x)
	check(lo > Snapshot.Y_ORIGIN + 300.0, "highest ground %d stays inside snapshot y range" % lo)
	check(Stage.goal().x < Snapshot.X_ORIGIN + 65535.0 / Snapshot.X_SCALE - 400.0, "goal inside snapshot x range")
	for cp in Stage.checkpoints():
		var supported := false
		for slab in Stage.ground():
			if cp.x > slab.position.x + 18 and cp.x < slab.end.x - 18 and absf(cp.y + 50 - slab.position.y) <= 2:
				supported = true
		check(supported, "checkpoint %s stands on permanent ground" % cp)
	var cps := Stage.checkpoints()
	for i in range(1, cps.size()):
		check(cps[i].x > cps[i - 1].x, "checkpoints ordered along the course (%d)" % i)
	var shots: Array[Dictionary] = Stage.data().shots()
	check(shots.size() == 49, "49 storyboard cuts are mapped (%d)" % shots.size())

# ------------------------------------------------------------------- areas
## 0-10s: downhill, jump the burrbug, leap the cliff, fall, the guardian
## draws a platform in the air, the runner lands on it and makes the bank.
func area_grass() -> bool:
	release()
	main.runner.respawn(Stage.start())
	await frames(10)
	_cover = false
	var bug: Node2D = null
	for e in get_tree().get_nodes_in_group("finale_enemy"):
		if e.kind == "burrbug" and absf(e.global_position.x - 1400) < 400:
			bug = e
	check(bug != null, "one enemy waits on the run-up")
	var start_x: float = bug.global_position.x
	await run_until(func() -> bool: return bug.global_position.x - r.global_position.x < 125.0, 1.0, true, 400)
	at("bug %s" % bug.global_position.round())
	check(bug.global_position.x < start_x - 20.0, "the burrbug walked toward the runner")
	await jump(16)
	hold(1.0, true)
	await run_until(func() -> bool: return r.global_position.x > bug.global_position.x + 40 and r.is_on_floor(), 1.0, true, 120)
	check(r.hp == Balance.RUNNER_MAX_HP, "jumped the enemy cleanly")
	# The cliff leap: full sprint jump from the lip, double jump at the top.
	# The lip of the near cliff breaks away under the take-off.
	await run_until(x_past(1525), 1.0, true, 200)
	await jump(18)
	await wait_until(func() -> bool: return r.velocity.y > -60.0, 30)
	await jump(14)
	# Not reaching for the edge (a held direction would catch it from a
	# perfect jump): this is the fall the guardian has to answer.
	hold(0.0)
	check(machine("cliff_lip").state == 1, "the overhanging lip broke away under the take-off")
	# The jump ends against the far wall, under its top.
	await wait_until(func() -> bool: return r.global_position.y > 1040.0 and r.velocity.y > 0.0, 90)
	at("short")
	check(r.global_position.x < 2000 and not r.is_on_floor() and r.global_position.y + 23.0 > 1000.0,
		"short of the high bank: the runner drops below the top of the far wall")
	# The guardian draws a ledge out from the wall under the runner, and
	# fires its launch ring: thrown up the wall and over the top.
	var fy := r.global_position.y + 23.0 + 60.0
	check(place_platform(Vector2(1915, fy), PackedVector2Array([Vector2(83, 0), Vector2(-83, 0)])), "guardian places a platform in mid-air")
	hold(0.0)
	await wait_until(grounded(), 90)
	at("caught")
	check(r.is_on_floor() and r.global_position.y < 1200, "the runner lands on the guardian's platform")
	hold(0.3)
	await frames(3)
	hold(0.0)
	var ring: LaunchTrigger = null
	for t in get_tree().get_nodes_in_group("launch_trigger"):
		if t is LaunchTrigger and (t as LaunchTrigger).armed:
			ring = t
	await wait_until(func() -> bool: return ring != null and ring.loaded(), 30)
	shoot(ring.global_position)
	await frames(2)
	check(r.velocity.y < -300.0, "the launch ring throws the runner up the wall")
	hold(1.0)
	await run_until(func() -> bool: return r.is_on_floor() and r.global_position.y < 960.0, 1.0, false, 150)
	at("bank")
	check(r.global_position.y < 960 and r.global_position.x > 2000, "safe on the far bank")
	_cover = true
	await run_until(x_past(2720), 1.0, true, 200)
	check(GameState.checkpoint_index >= 1, "checkpoint 1 reached")
	return r.global_position.x > 2700

func machine(id: String) -> FinaleMachine:
	for m in get_tree().get_nodes_in_group("finale_machine"):
		if m.switch_id == id:
			return m
	return null

## 10-13s: strikes break the deck ahead; the guardian earths the rod; the
## runner vaults the broken spans above the double gap.
func area_storm() -> bool:
	await from_checkpoint(1)
	var storm := machine("storm")
	await run_until(x_past(3630), 1.0, true, 300)
	at("before first gap")
	check(storm.state & 1 != 0, "lightning has been called on the deck ahead")
	await wait_until(func() -> bool: return storm.broken_at(Clock.tick).has(3), 60)
	# The span's collider follows on the machine's next pose.
	await frames(2)
	check(storm.broken_at(Clock.tick).has(3) and storm._spans[3].collision_layer == 0, "the strike broke span 3 out of the deck")
	await hop_to(Vector2(3930, 1040))
	await run_until(x_past(4120), 1.0, true, 200)
	check(storm.state & 2 != 0, "the second strike is called")
	shoot(storm.global_position + storm._rod)
	await frames(2)
	check(Clock.tick < storm._rod_until, "guardian's shot earths the lightning rod")
	for feet in [Vector2(4175, 920), Vector2(4385, 800), Vector2(4575, 860), Vector2(4755, 760)]:
		if not await hop_to(feet):
			at("missed span %s" % feet)
			return false
	at("high spans")
	check(storm._spans[7].collision_layer == 0 and storm._spans[8].collision_layer == 0, "the double gap is open below")
	await hop_to(Vector2(4900, 1040))
	await run_until(x_past(5070), 1.0, true, 200)
	await hop_to(Vector2(5340, 1040), true)
	await run_until(x_past(5460), 1.0, false, 200)
	return GameState.checkpoint_index >= 2

## 13-16s: the pendulum hall (crouch under it), the floor that collapses
## into a 1,500px shaft with falling stones, the volcano chamber below.
func area_sand() -> bool:
	await from_checkpoint(2)
	# The block's arc reaches the terrace edge at its left extreme: go in as
	# it swings away to the right.
	var pend0 := machine("ruin_pendulum")
	await run_until(x_past(6200), 1.0, false, 200)
	hold(0.0)
	await wait_until(func() -> bool: return pend0.angle_at(Clock.tick) > 0.2 and pend0.angle_at(Clock.tick + 1) > pend0.angle_at(Clock.tick), 300)
	await run_until(x_past(6440), 1.0, true, 400)
	await run_until(func() -> bool: return r.is_on_floor(), 1.0, false, 60)
	at("hall")
	var pend := machine("ruin_pendulum")
	var hp := r.hp
	_crouch = true
	await run_until(x_past(7020), 1.0, false, 600)
	_crouch = false
	at("past pendulum")
	check(r.hp == hp, "crouched under the swinging block untouched")
	var floor := machine("ruin_floor")
	await run_until(x_past(7280), 1.0, false, 120)
	hold(0.0)
	await wait_until(func() -> bool: return floor.state == 1, 60)
	check(floor.state == 1, "standing on the last floor cracks it")
	await wait_until(func() -> bool: return r.global_position.y > 1400.0, 120)
	check(r.global_position.y > 1400.0, "the floor gave way: falling down the shaft")
	# Steer down the clear lane between the rockfalls.
	for i in 300:
		if r.is_on_floor() and r.global_position.y > 2600.0:
			break
		hold(clampf((7238.0 - r.global_position.x) / 40.0, -1.0, 1.0))
		await frames(1)
	hold(0.0)
	at("shaft bottom")
	await run_until(x_past(7720), 1.0, false, 300)
	return GameState.checkpoint_index >= 3

## 16-20s: lava platforms, the magma sphere chase and the escape ledge,
## the crust it smashes, the chain swings.
func area_lava() -> bool:
	await from_checkpoint(3)
	for step in [[8030.0, Vector2(8145, 2660)], [8180.0, Vector2(8360, 2560)], [8395.0, Vector2(8565, 2620)],
			[8600.0, Vector2(8790, 2520)]]:
		var feet: Vector2 = step[1]
		await run_until(x_past(step[0]), 1.0, false, 200)
		if not await hop_to(feet):
			at("missed %s" % feet)
			return false
	var ball := machine("magma")
	check(ball.state == 0, "the magma sphere waits in its lava tube")
	await run_until(x_past(9040), 1.0, true, 200)
	check(ball.state == 1, "crossing the trigger frees the sphere behind the runner")
	await run_until(x_past(9330), 1.0, true, 200)
	await hop_to(Vector2(9480, 2420), true)
	at("escape ledge")
	check(standing_on(Rect2(9400, 2420, 200, 36)), "made the escape ledge")
	await wait_until(func() -> bool: return ball.sunk(), 400)
	check(ball.sunk() and ball._crust.collision_layer == 0, "the sphere passed below, smashed the crust and sank")
	check(r.state != Runner.State.DEAD, "the sphere did not touch the runner on the ledge")
	# Swings: board A at its left extreme, transfer to B, step off right.
	var a := machine("swing_a")
	var b := machine("swing_b")
	var deck_a := func() -> Vector2: return a._deck.global_position + Vector2(0, -12)
	var deck_b := func() -> Vector2: return b._deck.global_position + Vector2(0, -12)
	var moving_left := func(m: FinaleMachine) -> bool: return m.offset_at(Clock.tick + 1).x < m.offset_at(Clock.tick).x
	await wait_until(func() -> bool: return a._deck.global_position.x < 9960.0 and moving_left.call(a), 400)
	await frames(8)
	await hop_to(deck_a)
	at("on swing a")
	check(r.is_on_floor() and absf(r.global_position.x - a._deck.global_position.x) < 80.0, "rode swing A over the lava")
	await wait_until(func() -> bool: return b._deck.global_position.x < 10300.0 and moving_left.call(b) and a._deck.global_position.x > 10000.0, 400)
	await hop_to(deck_b)
	at("on swing b")
	check(r.is_on_floor() and absf(r.global_position.x - b._deck.global_position.x) < 80.0, "transferred to swing B")
	await wait_until(func() -> bool: return b._deck.global_position.x > 10560.0, 300)
	await hop_to(Vector2(10800, 2420))
	await run_until(x_past(10830), 1.0, false, 100)
	return GameState.checkpoint_index >= 5

## Ride a geyser lift: board at rest, ride the eruption, step off at the top.
func ride_lift(lift: FinaleMachine, ledge: Vector2) -> bool:
	var base := lift.global_position
	await wait_until(func() -> bool: return lift.lift_at(Clock.tick) < 0.5 and lift.warning_at(Clock.tick), 400)
	await hop_to(Vector2(base.x, base.y))
	await wait_until(func() -> bool: return lift.lift_at(Clock.tick) >= float(lift.data["rise"]) - 0.5, 200)
	at("lift top %s" % lift.switch_id)
	return await hop_to(ledge)

## 19-20s: three geyser lifts climb 940px between lava jets.
func area_geyser() -> bool:
	await from_checkpoint(5)
	if not await ride_lift(machine("lift_2440"), Vector2(11150, 2100)):
		return false
	if not await ride_lift(machine("lift_2100"), Vector2(11200, 1800)):
		return false
	if not await ride_lift(machine("lift_1800"), Vector2(11120, 1500)):
		return false
	await run_until(x_past(11260), 1.0, false, 200)
	return GameState.checkpoint_index >= 6

## 20-24s: board the parked train, run its roofs, leap to the lead train,
## get off onto the footbridge before the low bridge.
func area_rail() -> bool:
	await from_checkpoint(6)
	var line := machine("rail")
	await wait_until(func() -> bool: return line.beat() > 4.3 and line.beat() < 5.0, 1700)
	at("train parked")
	await run_until(func() -> bool: return r.is_on_floor() and r.global_position.x > 11560.0 and r.global_position.y > 1520.0, 1.0, false, 200)
	at("on roof")
	check(r.global_position.y > 1520.0, "boarded the train roof")
	# Ride; walk forward along the roofs as it departs, over the cargo.
	var loco_end := func() -> float: return line.car_x(0, 3, line.beat()) + 320.0
	await advance_until(func() -> bool: return r.is_on_floor() and r.global_position.x > loco_end.call() - 300.0, false, 1200)
	hold(0.0)
	at("on the loco")
	await wait_until(func() -> bool: return line.beat() > 11.0, 600)
	var b_rear := func() -> float: return line.car_x(1, 0, line.beat())
	var gap: float = b_rear.call() - loco_end.call()
	check(gap > 280.0, "a wide gap to the lead train (%d px), both moving" % int(gap))
	await run_until(func() -> bool: return r.global_position.x > loco_end.call() - 26.0, 1.0, true, 120)
	at("leap")
	await hop_to(func() -> Vector2: return Vector2(b_rear.call() + 120.0, line.roof_y(1, 0)), true)
	at("train 1")
	check(r.global_position.y < 1530.0 and r.global_position.x > b_rear.call(), "train-to-train leap landed")
	hold(0.0)
	await wait_until(func() -> bool: return r.global_position.x > 15020.0, 1200)
	at("under the footbridge")
	await hop_to(Vector2(15200.0, 1420.0))
	at("footbridge")
	check(standing_on(Rect2(15000, 1420, 380, 36)), "off the roof onto the footbridge")
	check(line._carry == 0.0, "train momentum ends on landing")
	await hop_to(Vector2(15460, 1290))
	await run_until(x_past(15480), 1.0, false, 200)
	return GameState.checkpoint_index >= 7

## 24-30s: honey floor, inverted tiers, bubble slingshot, shaft current,
## burst membrane.
func area_hive() -> bool:
	await from_checkpoint(7)
	await run_until(x_past(15790), 1.0, false, 200)
	await frames(10)
	at("in honey")
	check(absf(r.velocity.x) <= 130.0, "honey holds the runner's boots (vx %d)" % int(r.velocity.x))
	await run_until(x_past(15990), 1.0, false, 300)
	for feet in [Vector2(16030, 1120), Vector2(16195, 990), Vector2(16380, 1000)]:
		var ok := await hop_to(feet, true)
		at("tier %s %s" % [feet, ok])
		if not ok:
			return false
	at("comb cliff")
	await run_until(x_past(16620), 1.0, false, 200)
	await wait_until(grounded(), 60)
	await run_until(x_past(16880), 1.0, false, 600)
	hold(0.0)
	var shaft := machine("hive_shaft")
	await wait_until(func() -> bool: return r.global_position.y < 900.0, 200)
	at("in the shaft")
	check(r.global_position.y < 900.0, "the bubble flung the runner into the shaft")
	await wait_until(func() -> bool: return shaft.state == 1, 200)
	check(shaft.state == 1, "the runner burst the wax membrane")
	hold(1.0)
	await wait_until(func() -> bool: return r.is_on_floor(), 200)
	await run_until(x_past(17160), 1.0, false, 200)
	return GameState.checkpoint_index >= 8

## 30-35s: off-centre landing; the giant rises across the way, its first
## slam cracks the plateau and knocks the pillar over the gorge into a
## bridge; the guardian staggers it (both fists hold still); cross.
func area_giant() -> bool:
	await from_checkpoint(8)
	await run_until(x_past(17460), 1.0, true, 200)
	await hop_to(Vector2(17760, 300))
	at("tilted ledge")
	await hop_to(Vector2(18050, 300))
	var giant := machine("giant")
	# Past the slam point, to the edge, and wait there for the bridge.
	await run_until(x_past(18440), 1.0, false, 200)
	hold(0.0)
	check(giant.state == 1, "the stone giant woke")
	await wait_until(func() -> bool: return giant.slab_angle() >= PI * 0.5 - 0.01, 300)
	check(giant.slab_angle() >= PI * 0.5 - 0.01, "the giant's slam toppled the pillar into a bridge")
	check(r.hp == Balance.RUNNER_MAX_HP, "the slam missed a runner who got out from under it")
	await wait_until(func() -> bool: return giant.cycle_time() > 1.2 and giant.cycle_time() < 1.6, 300)
	shoot(giant._core.global_position)
	await frames(2)
	check(giant.stunned(), "the guardian's shot staggered the giant")
	var frozen: Vector2 = giant.swipe_fist()
	await run_until(x_past(18500), 1.0, true, 100)
	at("slab foot")
	await hop_to(Vector2(18700, 240))
	at("on the toppled slab")
	if log_moves:
		print("      slab body ", giant._slab.global_position, " rot ", giant._slab.rotation, " layer ", giant._slab.collision_layer)
	check(giant.swipe_fist().distance_to(frozen) < 1.0, "the fists hold still while staggered")
	await run_until(x_past(18880), 1.0, true, 100)
	await hop_to(Vector2(19050, 300))
	at("far plateau")
	await run_until(x_past(19700), 1.0, false, 300)
	await run_until(x_past(20280), 1.0, false, 300)
	await hop_to(Vector2(20360, 320))
	await run_until(x_past(21150), 1.0, false, 400)
	await wait_until(grounded(), 60)
	await run_until(x_past(21260), 1.0, false, 100)
	return GameState.checkpoint_index >= 10

## 35-39s: the beast erupts through the vertebra bridge, the gap, the jaw
## chase over collapsing pillars, the gate.
func area_bone() -> bool:
	await from_checkpoint(10)
	var beast := machine("beast")
	await run_until(x_past(21700), 1.0, false, 200)
	hold(0.0)
	check(beast.state == 1, "the skeletal beast erupts")
	await wait_until(func() -> bool: return beast.broken(), 60)
	await frames(2)
	check(beast._segments[6].collision_layer == 0, "it burst vertebrae out of the bridge")
	await frames(110)
	check(r.state != Runner.State.DEAD, "the eruption missed a runner who waited")
	await run_until(x_past(21880), 1.0, true, 100)
	await hop_to(Vector2(22400, 300), true)
	at("past gap")
	await run_until(x_past(22560), 1.0, true, 200)
	for feet in [Vector2(22710, 320), Vector2(22905, 260), Vector2(23105, 330)]:
		var ok := await hop_to(feet + Vector2(25, 0))
		at("pillar %s %s jaw front %d" % [feet, ok, int(beast.jaw_front()) if beast.state == 2 else -1])
		if not ok:
			return false
	check(beast.state == 2, "the jaws are chasing")
	var crushed := 0
	for m in get_tree().get_nodes_in_group("finale_machine"):
		if m.kind == "bone_pillar" and m.state == 2:
			crushed += 1
	check(crushed >= 1, "the jaws bit through a pillar behind the runner")
	# Into the jet, up past the rib, out of the column onto it.
	_jump = true
	hold(1.0)
	var blew := false
	for i in 160:
		if i == 18:
			_jump = false
		if machine("sandjet_23205").active():
			blew = true
		if r.global_position.y < 120.0:
			hold(1.0, true)
		if i > 20 and r.is_on_floor():
			break
		await frames(1)
	_jump = false
	at("after the jet")
	check(blew, "the jaws' impact blew the sand vent ahead")
	check(r.global_position.y < 60.0 and r.is_on_floor(), "the jet threw the runner up onto the rib path")
	await run_until(x_past(23688), 1.0, true, 120)
	await hop_to(Vector2(24140, 300), true)
	at("through the gate")
	await wait_until(func() -> bool: return beast._snapped, 200)
	check(beast._snapped, "the jaws slammed shut at the gate behind the runner")
	await run_until(x_past(24210), 1.0, false, 100)
	return GameState.checkpoint_index >= 11

## 39-49s: saws, the spike pit, the cannon, the impossible pillars, the
## dipping saw, the lift, the goal.
func area_title() -> bool:
	await from_checkpoint(11)
	at("title start")
	var saw_a := machine("saw_a")
	await run_until(x_past(25220), 1.0, false, 300)
	await run_until(grounded(), 0.0, false, 60)
	hold(0.0)
	at("saw a")
	# Let the rail saw come close, hop it, and run on while it heads back.
	await wait_until(func() -> bool: return saw_a.centre().x < 60.0 and saw_a.centre(Clock.tick + 1).x < saw_a.centre().x, 300)
	await hop_to(Vector2(25440, 520))
	check(r.state != Runner.State.DEAD, "hopped the rail saw")
	await run_until(x_past(25630), 1.0, true, 120)
	at("past saw a")
	var route := [[Vector2(25900, 460), false, 26100.0], [Vector2(26260, 560), false, 26380.0],
		[Vector2(26570, 480), true, -1.0], [Vector2(26660, 430), false, -1.0], [Vector2(26800, 420), false, 27030.0]]
	for step in route:
		var ok := await hop_to(step[0], step[1])
		at("hop %s %s" % [step[0], ok])
		if not ok:
			return false
		if step[2] > 0.0:
			await run_until(x_past(step[2]), 1.0, false, 200)
	var saw_c := machine("saw_c")
	hold(0.0)
	await wait_until(func() -> bool: return saw_c.centre().y > 95.0, 200)
	await wait_until(func() -> bool: return saw_c.centre().y < 45.0, 200)
	await run_until(x_past(27260), 1.0, true, 100)
	at("past saw c")
	var lift: MovingPlatform = null
	for node in get_tree().get_nodes_in_group("finale_machine"):
		pass
	for node in main.level.find_children("*", "", true, false):
		if node is MovingPlatform:
			lift = node
	release()
	await wait_until(func() -> bool: return lift.global_position.y > 500.0, 300)
	var on_lift := await hop_to(func() -> Vector2: return lift.global_position + Vector2(0, -13))
	at("lift %s" % on_lift)
	await wait_until(func() -> bool: return lift.global_position.y < 400.0, 300)
	await hop_to(Vector2(27720, 480))
	await run_until(x_past(28100), 1.0, false, 300)
	await hop_to(Vector2(28250, 420))
	await run_until(func() -> bool: return r.cleared, 1.0, false, 300)
	check(r.cleared, "the goal is reached")
	return r.cleared

## Put the runner somewhere and let it settle, without a respawn rebuild.
func place_runner(at: Vector2) -> void:
	release()
	main._respawn_timer = -1.0
	r.respawn(at)
	await frames(3)

## No guardian at all: a runner who falls into the opening chasm climbs the
## chimney behind the far bank. Nothing is a dead end alone.
func area_solo() -> bool:
	release()
	main.guardian.clear_constructs()
	await place_runner(Vector2(1800, 2070))
	await wait_until(grounded(), 60)
	await run_until(x_past(2440), 1.0, false, 300)
	at("chimney foot")
	var ledges := [Vector2(2565, 1980), Vector2(2435, 1860), Vector2(2565, 1740), Vector2(2435, 1620),
		Vector2(2565, 1500), Vector2(2435, 1380), Vector2(2565, 1260), Vector2(2435, 1140), Vector2(2565, 1040), Vector2(2500, 960)]
	for feet in ledges:
		if not await hop_to(feet):
			at("chimney missed %s" % feet)
			return false
	at("out of the chimney")
	check(r.global_position.y < 950.0, "climbed out of the chasm alone via the chimney")
	return true

func area_mechanics() -> bool:
	_cover = false
	# Standing under the swinging block is a hit; crouching was not (above).
	var pend := machine("ruin_pendulum")
	await from_checkpoint(2)
	await place_runner(Vector2(6780, 1137))
	var hp := r.hp
	await wait_until(func() -> bool: return r.hp < hp, 300)
	check(r.hp < hp, "the swinging block hits a runner who stands in its path")
	# Electrified spans hurt when live.
	await from_checkpoint(1)
	await place_runner(Vector2(4385, 777))
	hp = r.hp
	await wait_until(func() -> bool: return r.hp < hp, 240)
	check(r.hp < hp, "an electrified span hurts while it is live")
	# The guardian's wall stops the magma sphere; it rolls on once the wall fades.
	await from_checkpoint(4)
	var ball := machine("magma")
	await place_runner(Vector2(9480, 2397))
	ball.set_state(1, 0.0)
	await frames(1)
	main.guardian.select_slot(2)
	main.guardian.use_active(Vector2(9180, 2380))
	await wait_until(func() -> bool: return ball.state == 2, 200)
	check(ball.state == 2, "a guardian wall holds the magma sphere")
	var held: float = ball.distance_at(Clock.tick)
	await frames(60)
	check(absf(ball.distance_at(Clock.tick) - held) < 0.1, "...and it stays held while the wall stands")
	await wait_until(func() -> bool: return ball.state == 1, 400)
	check(ball.state == 1 and ball.distance_at(Clock.tick) >= held, "it rolls on when the wall expires")
	# The sphere is lethal.
	await from_checkpoint(4)
	ball = machine("magma")
	await place_runner(Vector2(9100, 2470))
	ball.set_state(1, 0.0)
	await wait_until(func() -> bool: return r.state == Runner.State.DEAD, 240)
	check(r.state == Runner.State.DEAD, "the magma sphere kills a runner in its path")
	await frames(100)
	at("after death")
	check(r.state != Runner.State.DEAD and r.global_position.distance_to(Stage.checkpoints()[3]) < 60.0,
		"respawned at the checkpoint before the chase")
	ball = machine("magma")
	check(ball.state == 0 and ball._crust.collision_layer == 1, "the chase is rebuilt for the retry (sphere parked, crust whole)")
	# Trains: crates land on cars and ride them; the low bridge sweeps the roof.
	await from_checkpoint(6)
	var line := machine("rail")
	var crate_ok := false
	for b in range(0, int(line.period * 10.0)):
		var at: Array = line.crate_at(0, float(b) / 10.0)
		if at[1] == 2:
			crate_ok = absf(at[0].y - (line.roof_y(int(line._drops[0]["train"]), int(line._drops[0]["car"])) - line.CRATE.y * 0.5)) < 1.0
			break
	check(crate_ok, "the crane's crate lands on a car roof and rides it")
	check(line._drops[0]["t"] < line.period and line._drops[1]["t"] < line.period, "both cranes drop once per timetable")
	await place_runner(Vector2(15280, 1500))
	r.global_position = Vector2(15310, 1520)
	await frames(2)
	r.global_position = Vector2(15355, 1520)
	await frames(3)
	check(r.state == Runner.State.DEAD, "the low bridge sweeps a runner still on the roof")
	await frames(100)
	# Sand geyser lifts.
	await from_checkpoint(10)
	var jet := machine("sandjet_23205")
	await wait_until(func() -> bool: return not jet.active(), 400)
	await wait_until(func() -> bool: return jet.active(), 400)
	await place_runner(Vector2(23205, 700))
	r.global_position = Vector2(23205, 700)
	var y0 := r.global_position.y
	for i in 6:
		await frames(5)
		at("jet %d active=%s" % [i, jet.active()])
	check(r.global_position.y < y0 - 150.0, "a sand geyser throws the runner upward")
	# The jaws kill a runner who stops.
	await from_checkpoint(10)
	var beast := machine("beast")
	await place_runner(Vector2(22710, 297))
	await frames(3)
	check(beast.state == 2, "the chase starts past the bridge")
	r.global_position = Vector2(22540, 277)
	for i in 12:
		await frames(20)
		at("jaws %d front=%d" % [i, int(beast.jaw_front())])
		if r.state == Runner.State.DEAD:
			break
	check(r.state == Runner.State.DEAD, "the jaws catch a runner who stands still")
	await frames(100)
	# Giant's sweep hits.
	await from_checkpoint(9)
	var giant := machine("giant")
	giant.set_state(1)
	await wait_until(func() -> bool: return giant.since() > 4.0, 400)
	await place_runner(Vector2(18760, 217))
	hp = r.hp
	await wait_until(func() -> bool: return r.hp < hp, 300)
	check(r.hp < hp, "the giant's sweep hits a runner standing on the bridge")
	# Honey cuts a jump.
	await from_checkpoint(7)
	await place_runner(Vector2(16690, 1277))
	await frames(10)
	var floor_y := r.global_position.y
	var top := floor_y
	_jump = true
	for i in 40:
		await frames(1)
		top = minf(top, r.global_position.y)
	_jump = false
	check(floor_y - top < Balance.RUNNER_JUMP_HEIGHT * 0.75, "honey cuts the jump (%d px of %d)" % [int(floor_y - top), int(Balance.RUNNER_JUMP_HEIGHT)])
	await frames(30)
	# Awkward guardian blocks on the title run still work as ground.
	await from_checkpoint(12)
	await place_runner(Vector2(26300, 537))
	place_platform(Vector2(26360, 470), PackedVector2Array([Vector2(-60, 20), Vector2(60, -20)]))
	await frames(24)
	check(main.guardian.holograms_of(Hologram.Kind.PLATFORM).size() == 1, "a slanted drawn block can be placed on the title run")
	_cover = true
	return true

func area_enemies() -> bool:
	_cover = false
	var kinds := {}
	for e in get_tree().get_nodes_in_group("finale_enemy"):
		kinds[e.kind] = true
	check(kinds.size() == FinaleEnemy.KINDS.size(), "all %d enemy kinds are in the course (%s)" % [FinaleEnemy.KINDS.size(), kinds.keys()])
	# Each acts near the runner, and each dies to a guardian shot.
	for kind in FinaleEnemy.KINDS:
		var enemy: FinaleEnemy = null
		for e in get_tree().get_nodes_in_group("finale_enemy"):
			if e.kind == kind and not e.is_queued_for_deletion():
				enemy = e
				break
		if enemy == null:
			check(false, "an enemy of kind %s exists" % kind)
			continue
		if kind == "rail_gunner":
			var line := machine("rail")
			await place_runner(Vector2(11250, 1477))
			await wait_until(func() -> bool: return line.beat() > 6.0 and line.beat() < 7.0, 1600)
		else:
			await place_runner(enemy.global_position + Vector2(-240, -40))
		var from := enemy.global_position
		var moved := 0.0
		for i in 150:
			await frames(1)
			moved = maxf(moved, enemy.global_position.distance_to(from))
		check(moved > 4.0 or kind == "rail_gunner", "%s moves on its own (%d px)" % [kind, int(moved)])
		shoot(enemy.global_position)
		await frames(3)
		check(not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.hp < 2, "%s is hit by the guardian's shot" % kind)
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			shoot(enemy.global_position)
			await frames(3)
		check(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "%s is defeated" % kind)
	_cover = true
	return true

func _restart_checks() -> void:
	# Pressing restart returns the whole run to the start.
	await from_checkpoint(8)
	main._restart()
	await frames(5)
	check(r.global_position.distance_to(Stage.start()) < 4.0 and GameState.checkpoint_index == 0, "restart returns to the start of 1-10")
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
