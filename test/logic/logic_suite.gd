extends Node
## What every logic suite shares: the checks, the frame waits, booting a real
## main.tscn, and the helpers more than one suite drives the game through.
##
## The tally, the booted game and the runner's measured reach live on one
## LogicRun that run_tests.gd hands every suite, so the suites behave as the
## single file did: one count, one game, in one order.

const LogicRun = preload("res://test/logic/logic_run.gd")

var run: LogicRun = null
var _current: String = ""

## The game under test, shared by every suite.
var main: Node2D:
	get: return run.main
	set(value): run.main = value

## Filled in by _test_runner_arc and consumed by _test_level_reachability, so
## the stage audit is measured against what the runner can actually do rather
## than against a number somebody typed once. They had drifted 13px apart.
var _reach: Dictionary:
	get: return run.reach
	set(value): run.reach = value

func check(condition: bool, message: String) -> void:
	run.checks += 1
	if not condition:
		run.failures.append("%s: %s" % [_current, message])

func check_near(got: float, want: float, tol: float, message: String) -> void:
	run.checks += 1
	if absf(got - want) > tol:
		run.failures.append("%s: %s (got %.3f, want %.3f +/- %.3f)"
			% [_current, message, got, want, tol])

func check_range(got: float, low: float, high: float, message: String) -> void:
	run.checks += 1
	if got < low or got > high:
		run.failures.append("%s: %s (got %.2f, expected %.2f..%.2f)"
			% [_current, message, got, low, high])

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _physics(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

## Waits real seconds. Frame counts are useless for anything time-based here:
## headless runs uncapped, so a "frame" can be a fraction of a millisecond and
## 30 of them are nowhere near half a second.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

## Every test below measures against 1-1's geometry -- its gaps, its ledges, the
## coordinates its checkpoints sit at. The game opens on the co-op stage, so the
## stage is pinned here rather than left to whatever the game's default happens
## to be: a default that moves would silently re-aim two hundred checks at
## terrain that is not there.
func _boot(dismiss_home: bool = true) -> void:
	Stage.use(Stage.Which.GREENFIELD)
	# These legacy coordinate fixtures exercise the supported custom fixed stick.
	# Default floating ownership and drift have their own 90-check probe.
	for mode in ["shared", "runner"]:
		var size := Vector2(get_viewport().get_visible_rect().size)
		var place: Dictionary = ControlLayout.layout(mode, size, false)["stick"]
		ControlLayout.set_place(mode, "stick", Vector2(place["center"]) / size)
	if main != null:
		main.free()
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(4)
	# Production deliberately freezes the world behind the home screen. Logic
	# probes are already choosing their stage above, so dismiss home before they
	# begin driving the runner.
	var panel := main.get_node_or_null("NetPanel")
	if dismiss_home and panel != null:
		panel.queue_free()
		await _frames(2)
	main.input_hub.scripted = true

## Stands in for an EOSG HLobby returned by a lobby search.
class LobbyAttrs extends RefCounted:
	var attributes: Array = []

func _stompable_positions() -> Dictionary:
	var out: Dictionary = {}
	for n in get_tree().get_nodes_in_group("stompable"):
		if n is Node2D:
			out[int((n as Node2D).global_position.x)] = (n as Node2D).global_position.y
	return out

func _walkers_in_data() -> int:
	var count := 0
	for e in Level01Data.enemies():
		if String(e.get("type", "")) == "walker":
			count += 1
	return count

## Runs frames while moving packets along the simulated link.
func _pump(pair: Array, frames: int) -> void:
	for i in range(frames):
		for t in pair:
			(t as LoopbackTransport).advance(Clock.DT)
		await get_tree().physics_frame
		await get_tree().process_frame

func _find_button(root: Node, contains: String) -> Button:
	if root is Button and String((root as Button).text).contains(contains):
		return root
	for child in root.get_children():
		var found := _find_button(child, contains)
		if found != null:
			return found
	return null

## One jump from a standing start on the opening plateau, run to landing.
## Returns how far it travelled and how high it got.
func _measure_arc(sprint: bool, repress_sprint: bool) -> Dictionary:
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	hub.release_jump()
	hub.dash_held = false
	hub.move_axis = 0.0
	r.global_position = Vector2(-1450, 300)
	r.velocity = Vector2.ZERO
	await _physics(30)
	# Let it get up to speed first: these are running jumps, which is how the
	# stage's gaps are meant to be taken.
	hub.move_axis = 1.0
	hub.dash_held = sprint
	await _physics(70)
	var start := r.global_position
	var apex := start.y
	hub.press_jump()
	var dashed := false
	for i in range(120):
		await get_tree().physics_frame
		apex = minf(apex, r.global_position.y)
		# Re-pressing sprint at the apex must not replace the jump with a burst.
		if repress_sprint and not dashed and not r.is_on_floor() and r.velocity.y >= 0.0:
			hub.press_dash()
			dashed = true
		if i > 4 and r.is_on_floor():
			break
	var out := {"reach": r.global_position.x - start.x, "apex": start.y - apex}
	hub.release_jump()
	hub.dash_held = false
	hub.move_axis = 0.0
	await _physics(20)
	return out

## No control off the screen, none overlapping another, and every one of them
## inside a thumb's reach of the corner it belongs to.
func _audit_layout(mode: String, view: Vector2, tag: String) -> void:
	var places := ControlLayout.layout(mode, view, false)
	check(not places.is_empty(), "%s: has controls at all" % tag)
	var ids: Array = places.keys()
	for i in ids.size():
		var a: Dictionary = places[ids[i]]
		var ar: float = float(a["radius"]) \
			* (ControlLayout.STICK_CAPTURE if a["kind"] == "stick" else 1.0)
		var c: Vector2 = a["center"]
		check(c.x - ar >= -1.0 and c.x + ar <= view.x + 1.0
				and c.y - ar >= -1.0 and c.y + ar <= view.y + 1.0,
			"%s: %s is fully on the screen (%s r=%.0f)" % [tag, ids[i], c, ar])
		# Reachable without moving the hand: a thumb sweeps roughly the screen's
		# height from the corner it rests in.
		var corner := Vector2(0.0 if c.x < view.x * 0.5 else view.x, view.y)
		check(c.distance_to(corner) < view.y * 1.05,
			"%s: %s is within a thumb's reach of its corner (%.0fpx of %.0f)"
				% [tag, ids[i], c.distance_to(corner), view.y * 1.05])
		for j in range(i + 1, ids.size()):
			var b: Dictionary = places[ids[j]]
			var br: float = float(b["radius"]) \
				* (ControlLayout.STICK_CAPTURE if b["kind"] == "stick" else 1.0)
			check(c.distance_to(b["center"]) > ar + br,
				"%s: %s and %s do not overlap (%.0fpx apart, need %.0f)"
					% [tag, ids[i], ids[j], c.distance_to(b["center"]), ar + br])

## Where a control actually is, from the same table the game uses.
func _place(id: String, view: Vector2, mode: String = "guardian") -> Vector2:
	return ControlLayout.layout(mode, view, false)[id]["center"]

## Drops the runner down the 600px gap between the slabs at 1900 and 2500, has
## the guardian build `drop` pixels beneath them `fall_for` seconds into the
## fall, and reports what the catch was worth.
##
## `age_it` holds the construct in place for that many seconds first, by parking
## the runner back on solid ground; `backdate` moves its birth tick into the past
## the way a laggy placement does on the host.
func _catch(from_y: float, fall_for: float, drop: float,
		age_it: float = 0.0, backdate: int = 0) -> Dictionary:
	var r: Runner = main.runner
	var g: Guardian = main.guardian
	for old in g.holograms_of(Hologram.Kind.PLATFORM):
		old.expire()
	await _physics(2)

	var out := {"tier": 0, "age": 0.0, "refund": 0.0, "impact": 0.0,
		"landed": false, "birth_age_ticks": 0, "gauge_before": 0.0}
	# Through the dictionary rather than through a local: a GDScript lambda
	# captures by VALUE, so a plain `var before` would be frozen at whatever it
	# held when the lambda was made -- which is how the first run of this test
	# reported the entire gauge as the refund.
	var seen := func(tier: int, _at: Vector2) -> void:
		out["tier"] = tier
		out["refund"] = g.gauge - float(out["gauge_before"])
	Events.rescue_scored.connect(seen)

	r.global_position = Vector2(2100.0, from_y)
	r.velocity = Vector2.ZERO
	main.input_hub.move_axis = 0.0
	await _physics(1)
	await _physics(int(fall_for / Clock.DT))

	# Room for the refund without hitting the ceiling of the gauge, which would
	# hide the difference between the tiers.
	g.gauge = 50.0
	g.select_slot(1)
	var at := r.global_position + Vector2(0.0, drop)
	g.use_active(at)
	var live: Array = g.holograms_of(Hologram.Kind.PLATFORM)
	if live.is_empty():
		Events.rescue_scored.disconnect(seen)
		return out
	var holo: Hologram = live[live.size() - 1]
	if backdate > 0:
		# Exactly what HostSession._do_place does: the life is shortened, the
		# placement stamp is left alone.
		holo.birth_tick = Clock.tick - backdate
		holo.death_tick = holo.birth_tick + Clock.ticks_for(holo.lifetime)
	if age_it > 0.0:
		# Park the runner on the start plateau while the slab gets old, so the
		# waiting is not itself a fall.
		var parked := r.global_position
		r.global_position = Vector2(-400.0, 300.0)
		await _wait(age_it)
		r.global_position = parked
		r.velocity = Vector2(0.0, maxf(0.0, r.velocity.y))
		await _physics(1)

	var placed_at: int = holo.placed_tick
	out["birth_age_ticks"] = placed_at - holo.birth_tick
	for i in range(240):
		# Read after the frame, not before it: impact_speed() is set from the
		# velocity the runner had going into move_and_slide, so on the frame
		# they touch down it holds exactly the number the grader saw.
		out["gauge_before"] = g.gauge
		await _physics(1)
		out["impact"] = r.impact_speed()
		if r.is_on_floor():
			out["landed"] = true
			break
	out["age"] = float(Clock.tick - placed_at) * Clock.DT
	Events.rescue_scored.disconnect(seen)
	return out

## Drops the runner beside the block, moving into it, and waits for a grab.
func _fall_past_the_edge(r: Runner, hub: InputHub, block: Node2D, lip: float) -> bool:
	# Beside the block with their hands just above its lip, not above the block
	# -- start them higher and they simply land on top of it, which is what the
	# first version of this did.
	r.global_position = Vector2(block.global_position.x - 120.0, lip - 20.0)
	r.velocity = Vector2(0.0, Balance.LEDGE_MIN_FALL_SPEED + 40.0)
	r.facing = 1
	hub.move_axis = 1.0
	for _i in range(120):
		await get_tree().physics_frame
		if r.hanging():
			return true
		if r.is_on_floor():
			return false
	return false

## Jumps, then holds a direction until the runner is airborne and against one of
## the guardian's walls. Returns whether it got there.
func _press_into_the_wall(r: Runner, hub: InputHub, direction: float) -> bool:
	hub.move_axis = direction
	if r.is_on_floor():
		hub.press_jump()
		hub.jump_held = true
		await _physics(6)
		hub.jump_held = false
	for _i in range(50):
		await get_tree().physics_frame
		if r.can_wall_jump():
			return true
		if r.is_on_floor():
			hub.press_jump()
			hub.jump_held = true
			await _physics(6)
			hub.jump_held = false
	return false

## A tap on a WORLD point: converted to the screen the way a finger would find
## it, so the whole screen-to-world path is exercised rather than bypassed.
##
## The camera is brought to the point first when it would otherwise be off the
## edge. A finger cannot touch what is not on the screen, so a test that pokes
## an off-screen coordinate is testing nothing -- and the camera lags the runner
## by design, so simply moving the runner is not enough to bring it into view.
func _tap_world(point: Vector2) -> void:
	var rect: Rect2 = main.get_viewport().get_visible_rect()
	var screen: Vector2 = main.get_viewport().get_canvas_transform() * point
	# On screen is not enough: on a shared screen the left of it belongs to the
	# runner, and a guardian's touch there is ignored by design. Bring the
	# camera round until the point is somewhere a guardian could actually put a
	# thumb, which is what a guardian would do.
	if not rect.grow(-40.0).has_point(screen) \
			or not TouchLayout.hit_rect(screen, TouchLayout.AIM_ZONE, rect.size, false) \
			or ControlLayout.hit(main.input_hub.layout_mode(), rect.size, false, screen) != "":
		main.camera.global_position = point + Vector2(-120, 100)
		main.camera.force_update_scroll()
		screen = main.get_viewport().get_canvas_transform() * point
	main.input_hub._touch_down(21, screen)
	main.input_hub._touch_up(21)
	await _frames(4)

## A transport that dials and never comes up. Two lines of behaviour, which is
## all the watchdog reads: the link is not open, and re-dialling is counted.
class DeadLink extends NetTransport:
	var redials: int = 0

	func poll() -> Array[Dictionary]:
		return []

	func send(_channel: int, _reliability: int, _payload: PackedByteArray) -> void:
		pass

	func is_connected_to_peer() -> bool:
		return false

	func is_link_open() -> bool:
		return false

	func reconnect() -> String:
		redials += 1
		return ""
