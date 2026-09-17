extends Node
## Can two people actually get across 1-S?
##
## The stage claims the runner cannot walk to the goal and that a launch is the
## road. Both halves of that are arcs, and arcs are MEASURED here rather than
## taken from Balance -- the habit this repository keeps because it has been
## burned twice: stage_probe's first launch model said 561px against a real
## 665, and the first 1-B put the runner's cover somewhere they physically
## could not reach.
##
## The one genuinely new claim is that a launch is a MAXIMUM rather than a fixed
## arc, because pushing back kills the momentum. Nothing in the code says so --
## it falls out of AIR_MOMENTUM_DRAG and RUNNER_AIR_TURN -- so it is flown here,
## and section 2 of the stage is sized against what comes back.
##
##   godot --headless --path . --fixed-fps 60 res://test/sky_probe.tscn

const Data = preload("res://src/levels/level_sky_data.gd")

var main: Node2D = null
var failures: int = 0
var checks: int = 0

var _runner: Runner = null
var _guardian: Guardian = null
var _hub: InputHub = null

## Everything the stage is sized against, flown by the real runner.
##   flat / up120 / up200   how far a launch carries, landing that much higher
##   braked                 the shortest a launch can be cut to by pushing back
##   solo                   one player's sprint jump, for "is this worth asking"
var arc: Dictionary = {}
var _trace: bool = false

func _ready() -> void:
	Stage.use(Stage.Which.SKY)
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(6)
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
		await _frames(2)
	main.input_hub.scripted = true
	_runner = main.runner
	_guardian = main.guardian
	_hub = main.input_hub
	main._respawn_timer = -1.0

	print("== what a launch actually does ==")
	await _measure()

	print("")
	print("== the stage's own claims ==")
	_check_geometry()

	print("")
	print("== the column ==")
	await _the_column()

	print("")
	print("== the gates ==")
	await _the_gates()

	print("")
	print("== playing it ==")
	await _play()

	print("")
	if failures == 0:
		print("1-S is crossable (%d checks)" % checks)
	else:
		print("%d of %d checks FAILED" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)

func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame

func _physics(n: int) -> void:
	for _i in range(n):
		await get_tree().physics_frame

func _ok(label: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("  ok    ", label)
	else:
		failures += 1
		print("  FAIL  ", label, "" if detail.is_empty() else "  -- " + detail)

# -------------------------------------------------------------- measurement

const VOID := Vector2(0.0, -3000.0)   ## well above the stage, nothing to hit

func _idle() -> void:
	_hub.release_jump()
	_hub.move_axis = 0.0
	_hub.dash_held = false

func _measure() -> void:
	arc["solo"] = await _solo_arc()
	arc["flat"] = await _launch_arc(0.0, false)
	arc["up120"] = await _launch_arc(120.0, false)
	arc["up200"] = await _launch_arc(200.0, false)
	arc["up300"] = await _launch_arc(300.0, false)
	arc["braked"] = await _launch_arc(0.0, true)
	arc["apex"] = await _launch_apex()
	print("  one player, sprint jump:   %.0fpx across" % arc["solo"])
	print("  a launch:                  %.0f flat, %.0f landing 120 up, %.0f landing 200 up, %.0f landing 300 up"
		% [arc["flat"], arc["up120"], arc["up200"], arc["up300"]])
	print("  a launch's apex:           %.0fpx up" % arc["apex"])
	print("  a launch, pushing back:    %.0fpx  (the runner's own brake)"
		% arc["braked"])
	var at180 := await _arc_height(180.0)
	var at380 := await _arc_height(380.0)
	arc["at180"] = at180
	arc["at380"] = at380
	print("  ...and it is %.0fpx up at 180 across, %.0fpx up at 380"
		% [at180, at380])

## How high a launch is when it has gone `across` pixels -- where a crystal has
## to hang if flying the line is to pay for the next one.
func _arc_height(across: float) -> float:
	_idle()
	_runner.global_position = VOID
	_runner.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var start := _runner.global_position
	_runner.facing = 1
	_runner.launch(Runner.launch_velocity(1))
	_hub.move_axis = 1.0
	var out := 0.0
	for _i in range(400):
		await get_tree().physics_frame
		if _runner.global_position.x - start.x >= across:
			out = start.y - _runner.global_position.y
			break
	_idle()
	return out

## The highest a launch ever gets, whatever it does afterwards.
func _launch_apex() -> float:
	_idle()
	_runner.global_position = VOID
	_runner.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var start := _runner.global_position.y
	_runner.facing = 1
	_runner.launch(Runner.launch_velocity(1))
	_hub.move_axis = 1.0
	var apex := start
	for _i in range(200):
		await get_tree().physics_frame
		apex = minf(apex, _runner.global_position.y)
		if _runner.velocity.y > 0.0 and _runner.global_position.y >= start:
			break
	_idle()
	return start - apex

## A full-speed sprint jump, for "is a launch worth asking for at all".
##
## Measured at the far left of the opening ground, with room to land. The first
## version started 300px from the cliff, so the runner sprinted off the edge and
## the 431px it reported was a fall rather than a jump.
func _solo_arc() -> float:
	_idle()
	_runner.global_position = Vector2(-1200.0, Data.EDGE - 60.0)
	_runner.velocity = Vector2.ZERO
	await _physics(30)
	_hub.move_axis = 1.0
	_hub.dash_held = true
	await _physics(70)                       # up to sprint speed
	var start := _runner.global_position.x
	_hub.press_jump()
	for i in range(150):
		await get_tree().physics_frame
		if i > 6 and _runner.is_on_floor():
			break
	var across := _runner.global_position.x - start
	_idle()
	await _physics(10)
	return across

## How far a launch carries before it comes back down to `lift` above where it
## started. `brake` pushes the stick the other way the moment the runner is
## airborne, which is the runner's own way of landing short.
func _launch_arc(lift: float, brake: bool) -> float:
	_idle()
	_runner.global_position = VOID
	_runner.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var start := _runner.global_position
	_runner.facing = 1
	_runner.launch(Runner.launch_velocity(1))
	# Coasting only holds while the stick agrees with the launch; pushing the
	# other way hands the runner RUNNER_AIR_TURN instead of AIR_MOMENTUM_DRAG.
	_hub.move_axis = -1.0 if brake else 1.0
	for _i in range(400):
		await get_tree().physics_frame
		if _runner.velocity.y > 0.0 and _runner.global_position.y >= start.y - lift:
			break
	var across := _runner.global_position.x - start.x
	_idle()
	return across

# ----------------------------------------------------------------- geometry

## Every gap in the stage, measured off the level data rather than typed out.
func _gaps() -> Array:
	var isles: Array = []
	for r in Stage.ground():
		if r.position.y < Data.LOWER - 1.0:      # the islands, not the lower road
			isles.append(r)
	isles.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		return a.position.x < b.position.x)
	var out: Array = []
	for i in range(isles.size() - 1):
		var here: Rect2 = isles[i]
		var next: Rect2 = isles[i + 1]
		out.append({
			"from": here.position.x + here.size.x,
			"gap": next.position.x - (here.position.x + here.size.x),
			"rise": here.position.y - next.position.y,
			"landing": next.size.x,
		})
	return out

func _check_geometry() -> void:
	_ok("the stage is numbered 1-S", Stage.stage_number() == "1-S")
	_ok("and it is the open sky", Stage.stage_name() == "THE OPEN SKY")
	_ok("nothing in it kills by touch", Stage.hazards().is_empty(),
		"this stage's only death is the fall")

	# The premise. If one player with two buttons goes as far as a launch, the
	# whole stage is theatre.
	_ok("a launch goes much further than a sprint jump (%.0f vs %.0f)"
			% [arc["flat"], arc["solo"]],
		arc["flat"] > arc["solo"] + 250.0)

	# The claim section 2 is built on, and the reason it needed no new code.
	_ok("pushing back really does cut a launch short (%.0f against %.0f)"
			% [arc["braked"], arc["flat"]],
		arc["braked"] < arc["flat"] * 0.45,
		"then the launch is a fixed arc and section 2 is asking for nothing")

	var gaps := _gaps()
	_ok("the stage is a chain of %d crossings" % gaps.size(), gaps.size() >= 8)

	# Every crossing except the last is inside a launch, allowing for the rise.
	# The margin is deliberately small: a gap far inside a launch is a gap the
	# runner coasts over without thinking, and this stage is asking them to aim.
	# `rise` is positive when the landing is HIGHER, and a climbing launch does
	# not carry as far. The first version had this comparison the wrong way
	# round and cheerfully passed a 520px climb against the flat reach.
	var set_pieces := 0
	for i in range(gaps.size()):
		var g: Dictionary = gaps[i]
		var reach: float = arc["flat"]
		if g["rise"] > 40.0:
			if g["rise"] > 260.0:
				reach = arc["up300"]
			elif g["rise"] > 160.0:
				reach = arc["up200"]
			else:
				reach = arc["up120"]
		if g["gap"] > reach:
			set_pieces += 1
			print("  (crossing %d: %.0fpx, rise %.0f -- beyond a launch's %.0f)"
				% [i + 1, g["gap"], g["rise"], reach])
			continue
		_ok("crossing %d: %.0fpx (rise %.0f) is inside a launch of %.0f"
				% [i + 1, g["gap"], g["rise"], reach],
			g["gap"] <= reach - 30.0,
			"nothing crosses this")

	# The two set pieces, and they are different problems on purpose: one is
	# crossed by CHAINING slabs and one by a warp pair. If this is zero, every
	# crossing in the stage is one launch and the stage has one idea in it.
	_ok("three crossings are beyond any single launch (%d)" % set_pieces,
		set_pieces == 3,
		"the column (3), the chain of slabs (4) and the warp (5) are the stage's "
			+ "three set pieces, and each one is beyond a launch on its own")

	# Section 2's landings are narrow ON PURPOSE: a full launch must overshoot
	# them, or the brake is never required.
	var narrow := 0
	for g in gaps:
		if float(g["landing"]) <= 200.0 and float(g["gap"]) < arc["flat"] - 120.0:
			narrow += 1
	_ok("there are narrow landings closer than a full launch (%d)" % narrow,
		narrow >= 2,
		"nothing in the stage punishes coasting, so the brake is never learned")

	# The lower road: four stretches, disconnected, so falling is never a route.
	var lower: Array = []
	for r in Stage.ground():
		if r.position.y >= Data.LOWER - 1.0:
			lower.append(r)
	_ok("the lower road is broken into %d stretches" % lower.size(),
		lower.size() >= 4)
	lower.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		return a.position.x < b.position.x)
	var joined := false
	for i in range(lower.size() - 1):
		if lower[i + 1].position.x - (lower[i].position.x + lower[i].size.x) < 60.0:
			joined = true
	_ok("and no two stretches are walkable between", not joined,
		"falling would become a quieter way across the stage")

	# Section 5 has none, which is where the stage grows teeth.
	var last_isle_x := 0.0
	for r in Stage.ground():
		if r.position.y < Data.LOWER - 1.0:
			last_isle_x = maxf(last_isle_x, r.position.x)
	var covered := false
	for r in lower:
		if r.position.x + r.size.x > last_isle_x - 600.0:
			covered = true
	_ok("the last crossing has nothing underneath it", not covered,
		"then the one real death in the stage is not a death")

	# Every column is reachable from the lower road it rescues.
	var rescues := 0
	for g in Stage.gimmicks():
		if String(g.get("type", "")) == "updraft" \
				and absf(float(g["pos"].y) - Data.LOWER) < 1.0:
			rescues += 1
	_ok("every stretch of lower road has a column to leave by (%d)" % rescues,
		rescues >= lower.size())

	# Fuel. One hop is a platform (30) and the shot that fires it (20).
	var hop_cost: float = Balance.COST_PLATFORM + Balance.COST_SNIPE
	var crystals := Stage.crystals().size()
	_ok("a hop costs %.0f and there are %d crystals at %.0f each"
			% [hop_cost, crystals, Balance.CRYSTAL_GAUGE],
		float(crystals) * Balance.CRYSTAL_GAUGE >= float(gaps.size()) * hop_cost * 0.8,
		"the arcs cannot pay for the stage")

	# The art is registered even though none of it has been drawn.
	var wanted := ["sky_panorama", "sky_island_tile", "sky_island_cap",
		"sky_keel", "sky_updraft", "sky_streamer", "sky_arch", "sky_beacon",
		"sky_flyer"]
	var registered := 0
	for key in wanted:
		if Art.MANIFEST.has(key):
			registered += 1
	_ok("every painting the stage asks for has a manifest key (%d/%d)"
			% [registered, wanted.size()],
		registered == wanted.size())

# ------------------------------------------------------------------- column

func _column_at(x: float) -> Updraft:
	var best: Updraft = null
	var closest := INF
	for u in get_tree().get_nodes_in_group("updraft"):
		if not (u is Updraft):
			continue
		var d: float = absf((u as Updraft).global_position.x - x)
		if d < closest:
			closest = d
			best = u
	return best

func _the_column() -> void:
	var column := _column_at(3500.0)
	_ok("3: there is a column between the two islands", column != null)
	if column == null:
		return
	var rise: float = Data.C1 - Data.C2
	var gap := 3690.0 - 3260.0

	# Three flights that differ by ONE thing each, all in clear air so no piece
	# of the stage is in the way. A test column rather than the stage's own,
	# because the first version launched the runner from a point that turned out
	# to be inside island C1 and reported 1,119px across for a 665px launch.
	var plain := await _fly(false, false)
	var through := await _fly(true, false)
	var ridden := await _fly(true, true)
	# Where the arc comes back DOWN through the height section 3 asks for. This
	# is what the landing is placed against; everything else here is context.
	var lands := await _fly_down_to(rise)
	print("  a launch, plain:                 %.0f up, %.0f across" % [plain.y, plain.x])
	print("  ...straight through a column:    %.0f up, %.0f across" % [through.y, through.x])
	print("  ...braking inside one:           %.0f up, %.0f across" % [ridden.y, ridden.x])
	print("  ...and it is still %.0fpx up at %.0fpx across" % [rise, lands])

	# The finding that reshaped this stage. A runner crossing a column at
	# 780px/s is inside it for a quarter of a second, and a quarter of a second
	# of lift is nothing. So a column is not a ramp you fly through -- which is
	# exactly why section 3 can ask for the brake section 2 taught.
	_ok("3: a column is worth real height to fly through (%.0f over a plain %.0f)"
			% [through.y - plain.y, plain.y],
		through.y - plain.y > 150.0,
		"a column narrow or gentle enough to cross in a quarter of a second is "
			+ "worth nothing, which is what the first tuning did")
	_ok("3: flying through one is worth the whole climb (%.0f up against %.0f)"
			% [through.y, rise],
		through.y >= rise,
		"section 3 is not crossable even by doing the right thing")

	# The trade. Without it a column would be a free extension of every launch.
	_ok("3: and it is a different landing rather than a strictly better one "
			+ "(%.0f across against %.0f)" % [through.x, plain.x],
		absf(through.x - plain.x) > 30.0,
		"through the column and over the top of it land in the same place")

	# Section 3's own numbers, against the arc that would have to make it.
	_ok("3: the climb is %.0fpx over %.0f across, and a launch that climbs that high only carries %.0f"
			% [rise, gap, arc["up300"]],
		gap > arc["up300"] + 30.0,
		"a plain launch lands up there and the column is decoration")

	# Host authority. The guardian's device draws the same column and must not
	# apply it: the runner there is a puppet whose position already has the lift
	# in it, and a second copy would fight the interpolation.
	_idle()
	_runner.global_position = Vector2(column.global_position.x,
		column.global_position.y - column.span.y * 0.5)
	_runner.velocity = Vector2(0.0, 300.0)
	Clock.is_host = false
	await _physics(10)
	var drifted := _runner.velocity.y
	Clock.is_host = true
	_ok("3: the column does nothing on the guardian's device (%.0f, still falling)"
			% drifted,
		drifted > 0.0,
		"the two devices would disagree about where the runner is")

## How far across a launch through a column is when it comes back down to
## `lift` above where it started -- which is where a landing can be put.
func _fly_down_to(lift: float) -> float:
	var column := Updraft.new()
	column.runner = _runner
	column.span = Vector2(240.0, 720.0)
	column.global_position = VOID + Vector2(300.0, 260.0)
	main.level.add_child(column)
	await _physics(2)
	_idle()
	_runner.global_position = VOID
	_runner.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var start := _runner.global_position
	_runner.facing = 1
	_runner.launch(Runner.launch_velocity(1))
	_hub.move_axis = 1.0
	var out := 0.0
	for _i in range(400):
		await get_tree().physics_frame
		if _runner.velocity.y > 0.0 \
				and _runner.global_position.y >= start.y - lift:
			out = _runner.global_position.x - start.x
			break
	_idle()
	column.queue_free()
	await _physics(2)
	return out

## One launch in clear air, optionally into a column, optionally braking once
## inside it. Returns (across, highest) relative to where the launch started.
func _fly(with_column: bool, brake_inside: bool) -> Vector2:
	var column: Updraft = null
	if with_column:
		column = Updraft.new()
		column.runner = _runner
		# Wide and tall, like the one section 3 uses. Its foot is below the
		# launch height so the arc enters it from the side.
		column.span = Vector2(240.0, 720.0)
		column.global_position = VOID + Vector2(300.0, 260.0)
		main.level.add_child(column)
		await _physics(2)

	_idle()
	_runner.global_position = VOID
	_runner.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var start := _runner.global_position
	_runner.facing = 1
	_runner.launch(Runner.launch_velocity(1))
	_hub.move_axis = 1.0
	var apex := start.y
	var braked := false
	for _i in range(400):
		await get_tree().physics_frame
		apex = minf(apex, _runner.global_position.y)
		if brake_inside and not braked and column != null \
				and column.holds(_runner.global_position):
			braked = true
			_hub.move_axis = -1.0
		# A ridden column eventually tops out and the runner falls again; stop
		# when they are back at the height they left, as every other arc does.
		if _runner.velocity.y > 0.0 and _runner.global_position.y >= start.y:
			break
	var out := Vector2(_runner.global_position.x - start.x, start.y - apex)
	_idle()
	if column != null:
		column.queue_free()
		await _physics(2)
	return out

# -------------------------------------------------------------------- gates

func _the_gates() -> void:
	# The property the last crossing is built on, and the reason a warp is not
	# simply a shorter walk: a trip keeps the runner's velocity exactly.
	_idle()
	_guardian.clear_constructs()
	# Next to the gates. WarpAbility.check refuses anything further than
	# PLACE_MAX_RANGE from the RUNNER, and the first version of this test left
	# the runner wherever the column measurements had put them -- 3,400px away.
	_runner.global_position = Vector2(-60.0, -2600.0)
	_runner.velocity = Vector2.ZERO
	await _physics(2)
	_guardian.gauge = Balance.GAUGE_MAX
	_guardian.select_slot(4)
	_guardian.use_active(Vector2(0.0, -2600.0))
	_guardian.use_active(Vector2(900.0, -2600.0))
	await _physics(2)
	var gates: Array = _guardian.holograms_of(Hologram.Kind.WARP)
	_ok("the guardian can open a pair of gates", gates.size() == 2)
	if gates.size() != 2:
		return

	# Flown at the gate rather than launched at it. A launch's arc rises 296px
	# and a gate is 136 tall, so the first version of this sailed clean over the
	# thing it was meant to go through.
	_runner.velocity = Vector2(600.0, 0.0)
	_hub.move_axis = 1.0
	var before := Vector2.ZERO
	var after := Vector2.ZERO
	var jumped := false
	var last_x := _runner.global_position.x
	for _i in range(200):
		before = _runner.velocity
		await get_tree().physics_frame
		# A trip is the one thing that moves the runner further in a frame than
		# any speed could.
		if not jumped and _runner.global_position.x - last_x > 300.0:
			jumped = true
			after = _runner.velocity
			break
		last_x = _runner.global_position.x
	_idle()
	_ok("the runner goes through a gate in mid-flight", jumped)
	if jumped:
		# Horizontal exactly, vertical to within the gravity of the one frame
		# the trip happened in. The first version compared both to 30px/s and
		# failed on 66 -- which is 4165 px/s^2 for a sixtieth of a second, i.e.
		# the frame itself rather than anything the gate did.
		var one_frame: float = Balance.RUNNER_FALL_GRAVITY * Clock.DT + 4.0
		_ok("and comes out with the same speed (%.0f,%.0f -> %.0f,%.0f)"
				% [before.x, before.y, after.x, after.y],
			absf(after.x - before.x) < 2.0 and absf(after.y - before.y) < one_frame,
			"then a warp cannot continue an arc, and the last crossing is unsolvable")
	_guardian.clear_constructs()
	await _physics(2)

	# The last crossing: beyond any launch, and inside the guardian's reach from
	# the splinter the launch lands on.
	var gaps := _gaps()
	var last: Dictionary = gaps[gaps.size() - 1]
	_ok("5: the last crossing is beyond a launch (%.0f against %.0f)"
			% [last["gap"], arc["flat"]],
		float(last["gap"]) > arc["flat"])
	_ok("5: ...and inside the guardian's placement range (%.0f against %.0f)"
			% [last["gap"], Balance.PLACE_MAX_RANGE],
		float(last["gap"]) < Balance.PLACE_MAX_RANGE,
		"a gate cannot be put on the far side, so nothing crosses it")

# ------------------------------------------------------------------ playing

func _play() -> void:
	_guardian.clear_constructs()
	main._respawn_timer = -1.0
	_runner.hp = Balance.RUNNER_MAX_HP

	# --- one hop, played the way the pair plays it -------------------------
	_idle()
	_runner.global_position = Vector2(-440.0, Data.EDGE - 60.0)
	_runner.velocity = Vector2.ZERO
	await _physics(30)
	var deck_y: float = Data.EDGE + Balance.PLATFORM_SIZE.y * 0.5
	var refusal := await _build(1, Vector2(-320.0, deck_y))
	_ok("1: the guardian can put a slab off the edge", refusal.is_empty(), refusal)

	# The runner walks aboard. LAUNCH_FOOTING is 12px, so this is a real step
	# onto a real deck rather than a teleport.
	_hub.move_axis = 1.0
	var aboard := false
	for _i in range(120):
		await get_tree().physics_frame
		if _loaded_trigger() != null:
			aboard = true
			break
	_idle()
	_ok("1: and the runner can get aboard it", aboard,
		"stopped at x=%.0f" % _runner.global_position.x)

	# --- the shot, and the flight ------------------------------------------
	var trigger := _loaded_trigger()
	var start_x := _runner.global_position.x
	var on_screen := true
	var half_view: float = main.get_viewport().get_visible_rect().size.x \
		* 0.5 / Balance.CAMERA_ZOOM
	if trigger != null:
		await _shoot(trigger.global_position)
		_hub.move_axis = 1.0
		for _i in range(200):
			await get_tree().physics_frame
			if absf(_runner.global_position.x - main.camera.global_position.x) \
					> half_view:
				on_screen = false
			if _runner.is_on_floor():
				break
		_idle()
	var flew := _runner.global_position.x - start_x
	_ok("1: the shot throws the runner across the gap (%.0fpx)" % flew, flew > 400.0)
	_ok("1: and they land on the first island",
		_runner.is_on_floor() and _runner.global_position.y < Data.LOWER - 100.0,
		"came down at y=%.0f" % _runner.global_position.y)
	# The camera is horizontal-only and hand-smoothed at 6.0; a launch is the
	# fastest the runner ever moves, so this is the one stage that can outrun it.
	_ok("1: the runner never leaves the screen during a launch", on_screen,
		"the guardian cannot aim at somebody they cannot see")

	# --- the arcs have to pay for themselves -------------------------------
	#
	# A hop is 50 gauge and the gauge refills at 8 a second. The crystals are
	# what turn that into a rhythm instead of a wait, and they only do it if
	# they are ON the arc -- so the arc is flown and the crystals are counted.
	GameState.crystals_taken.clear()
	main.level.rebuild_dynamic()
	await _physics(4)
	await _revive(Vector2(-460.0, Data.EDGE - 60.0))
	var before_taken := GameState.crystals_taken.size()
	var deck1: float = Data.EDGE + Balance.PLATFORM_SIZE.y * 0.5
	await _hop(Vector2(-320.0, deck1))
	_hub.move_axis = 1.0
	for _i in range(200):
		await get_tree().physics_frame
		if _runner.is_on_floor():
			break
	_idle()
	var picked := GameState.crystals_taken.size() - before_taken
	var hop_cost: float = Balance.COST_PLATFORM + Balance.COST_SNIPE
	_ok("1: flying the line the guardian aimed collects %d crystals, worth %.0f "
			% [picked, float(picked) * Balance.CRYSTAL_GAUGE]
			+ "against a %.0f hop" % hop_cost,
		float(picked) * Balance.CRYSTAL_GAUGE >= Balance.COST_PLATFORM,
		"the crystals are not on the arc, so a good launch pays for nothing")

	# --- a fall costs seconds, not progress --------------------------------
	_idle()
	_runner.global_position = Vector2(700.0, Data.A - 40.0)
	_runner.velocity = Vector2(0.0, 200.0)
	var landed := false
	for _i in range(300):
		await get_tree().physics_frame
		if _runner.is_on_floor():
			landed = true
			break
		if _runner.state == Runner.State.DEAD:
			break
	_ok("2: falling in the middle of the stage lands on the lower road", landed,
		"y=%.0f state=%d -- a fall here is meant to cost time, not the section"
			% [_runner.global_position.y, _runner.state])

	# ...and the column is how you leave it.
	var rescue := _column_at(900.0)
	_ok("2: there is a column at the end of that stretch", rescue != null)
	if rescue != null and landed:
		_idle()
		_runner.global_position = Vector2(rescue.global_position.x,
			Data.LOWER - 40.0)
		_runner.velocity = Vector2.ZERO
		var top := _runner.global_position.y
		for _i in range(240):
			await get_tree().physics_frame
			top = minf(top, _runner.global_position.y)
		_ok("2: and riding it lifts the runner back to the islands (%.0fpx up)"
				% (Data.LOWER - top),
			top <= Data.A - 40.0,
			"a fall would be a dead end")

	# --- section 3, played: the climb no launch makes -----------------------
	#
	# The one crossing in the stage whose answer is a thing in the world rather
	# than a thing the guardian buys. It is played rather than computed because
	# the arithmetic version of this check passed on a layout where the runner
	# flew straight over the landing.
	await _revive(Vector2(3220.0, Data.C1 - 60.0))
	var deck3: float = Data.C1 + Balance.PLATFORM_SIZE.y * 0.5
	var no3 := await _build(1, Vector2(3340.0, deck3))
	_ok("3: the guardian can put a slab on the lip of the climb", no3.is_empty(), no3)
	_hub.move_axis = 1.0
	var ready3 := false
	for _i in range(120):
		await get_tree().physics_frame
		if _loaded_trigger() != null:
			ready3 = true
			break
	_idle()
	_ok("3: and the runner boards it", ready3)
	var t3 := _loaded_trigger()
	if t3 != null:
		await _shoot(t3.global_position)
		_hub.move_axis = 1.0
		for _i in range(260):
			await get_tree().physics_frame
			if _runner.is_on_floor():
				break
		_idle()
	_ok("3: the column carries the launch up onto the far island (x=%.0f y=%.0f)"
			% [_runner.global_position.x, _runner.global_position.y],
		_runner.is_on_floor() and _runner.global_position.y < Data.C1 - 100.0
			and _runner.global_position.x > 3860.0,
		"the climb is not crossable as built")

	# --- section 4, played: the chain -------------------------------------
	#
	# 1,300px with nothing in it. Two launches and a slab placed in mid-air
	# where the first one comes down, which is the only place in the stage where
	# the guardian has to put a landing somewhere the world does not mark.
	await _revive(Vector2(4760.0, Data.D - 60.0))
	var deck4: float = Data.D + Balance.PLATFORM_SIZE.y * 0.5
	_ok("4: the first launch off the lip gets the runner airborne",
		await _hop(Vector2(4920.0, deck4)))
	# The slab the runner is about to land on, placed while they are in the air.
	var no4 := await _build(1, Vector2(5560.0, deck4))
	_ok("4: the guardian can put a slab in mid-air where they will come down",
		no4.is_empty(), no4)
	_hub.move_axis = 1.0
	var caught := false
	for _i in range(200):
		await get_tree().physics_frame
		if _runner.is_on_floor():
			caught = true
			break
	_idle()
	_ok("4: and the runner lands on it (x=%.0f)" % _runner.global_position.x,
		caught and _runner.global_position.x > 5400.0
			and _runner.global_position.y < Data.LOWER - 100.0,
		"the chain breaks at the first link")
	var t4 := _loaded_trigger()
	_ok("4: that slab has a launcher of its own", t4 != null,
		"a chain needs every link to fire")
	if t4 != null:
		await _shoot(t4.global_position)
		_hub.move_axis = 1.0
		for _i in range(240):
			await get_tree().physics_frame
			if _runner.is_on_floor():
				break
		_idle()
	_ok("4: and the second launch reaches the far island (x=%.0f)"
			% _runner.global_position.x,
		_runner.is_on_floor() and _runner.global_position.x > 6140.0
			and _runner.global_position.y < Data.LOWER - 100.0,
		"the 1,300px crossing is not crossable by chaining")

	# --- section 5, played: the gates --------------------------------------
	#
	# The one crossing a launch cannot reach and a chain should not be asked to,
	# because there is nothing under it. This is the first time in the game that
	# a stage's geometry requires ability slot 4.
	await _revive(Vector2(7120.0, Data.E - 60.0))
	var reach := absf(8440.0 - _runner.global_position.x)
	_ok("5: the far lip is inside placement range from the splinter (%.0f)" % reach,
		reach < Balance.PLACE_MAX_RANGE)
	var gate_a := await _build(4, Vector2(7200.0, Data.E - 70.0))
	_ok("5: the guardian can open a gate beside the runner", gate_a.is_empty(), gate_a)
	var gate_b := await _build(4, Vector2(8440.0, Data.GOAL_TOP - 70.0))
	_ok("5: ...and its partner on the far island", gate_b.is_empty(), gate_b)
	_hub.move_axis = 1.0
	var crossed := false
	for _i in range(200):
		await get_tree().physics_frame
		if _runner.global_position.x > 8300.0:
			crossed = true
			break
	_idle()
	_ok("5: and walking into it puts the runner across the gap (x=%.0f)"
			% _runner.global_position.x,
		crossed,
		"the last crossing has no answer")
	_guardian.clear_constructs()
	await _physics(2)

	# --- the last crossing has nothing under it ----------------------------
	_idle()
	main._respawn_timer = -1.0
	_runner.hp = Balance.RUNNER_MAX_HP
	_runner.global_position = Vector2(7500.0, Data.E - 200.0)
	_runner.velocity = Vector2(0.0, 200.0)
	var died := false
	for _i in range(400):
		await get_tree().physics_frame
		if _runner.state == Runner.State.DEAD:
			died = true
			break
		if _runner.is_on_floor():
			break
	_ok("5: falling on the last crossing is a real death", died,
		"landed at y=%.0f -- section 5 has no teeth" % _runner.global_position.y)
	main._respawn_timer = -1.0

# ------------------------------------------------------------------ helpers

## The launch trigger the runner is currently standing on, or null.
func _loaded_trigger() -> LaunchTrigger:
	for t in get_tree().get_nodes_in_group("launch_trigger"):
		if t is LaunchTrigger and (t as LaunchTrigger).loaded():
			return t
	return null

## Put the runner down somewhere alive, with nothing pending.
##
## A fall in one section leaves a respawn on a timer, and the timer fires in the
## middle of whatever is set up next -- which is how section 5 first ran with
## the runner standing on the opening checkpoint, 8,000px from the gates it was
## supposed to be testing.
func _revive(at: Vector2) -> void:
	main._respawn_timer = -1.0
	_idle()
	_guardian.clear_constructs()
	_runner.respawn(at)
	_runner.hp = Balance.RUNNER_MAX_HP
	_runner.velocity = Vector2.ZERO
	await _physics(20)

## Place a slab, walk aboard, and have it shot. True if the runner is airborne.
func _hop(deck: Vector2) -> bool:
	var refusal := await _build(1, deck)
	if not refusal.is_empty():
		print("    (the slab at %.0f,%.0f was refused: %s)"
			% [deck.x, deck.y, refusal])
		return false
	# Walk all the way ONTO the slab rather than stopping the moment
	# LaunchTrigger.loaded() first says yes. It accepts the runner anywhere
	# along a 150px deck, so stopping at the near edge starts the launch up to
	# 75px short of where the level data assumes it does.
	_hub.move_axis = 1.0
	var aboard := false
	for _i in range(140):
		await get_tree().physics_frame
		if _i % 12 == 0 and _trace:
			print("      f%d x=%.0f y=%.0f floor=%s holos=%d" % [_i,
				_runner.global_position.x, _runner.global_position.y,
				str(_runner.is_on_floor()),
				_guardian.holograms_of(Hologram.Kind.PLATFORM).size()])
		if _loaded_trigger() != null \
				and absf(_runner.global_position.x - deck.x) < 16.0:
			aboard = true
			break
	_idle()
	await _physics(4)
	if not aboard or _loaded_trigger() == null:
		print("    (never got aboard the slab at %.0f: runner ended at %.0f,%.0f)"
			% [deck.x, _runner.global_position.x, _runner.global_position.y])
		return false
	await _shoot(_loaded_trigger().global_position)
	await _physics(4)
	return not _runner.is_on_floor()

func _build(slot: int, at: Vector2) -> String:
	_guardian.gauge = Balance.GAUGE_MAX
	_guardian._last_refusal = ""
	_guardian.select_slot(slot)
	_guardian.use_active(at)
	await _physics(3)
	return _guardian._last_refusal

func _shoot(at: Vector2) -> void:
	_guardian.gauge = Balance.GAUGE_MAX
	(_guardian.abilities[3] as SniperAbility).cooldown = 0.0
	_guardian.select_slot(3)
	_guardian.use_active(at)
	await _physics(4)
