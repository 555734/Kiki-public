extends Node
## Drive real touch events through two independent online scene viewports.
## Calling InputHub._touch_down directly misses input stolen by another hub.

class TestLink extends VersusWsTransport:
	var bus_peer: VersusLoopback
	func poll_socket() -> void:
		pass
	func is_open() -> bool:
		return true
	func local_peer() -> int:
		return bus_peer.local_peer()
	func send_to(peer: int, channel: int, reliability: int, payload: PackedByteArray) -> void:
		bus_peer.send_to(peer, channel, reliability, payload)
	func broadcast(channel: int, reliability: int, payload: PackedByteArray) -> void:
		bus_peer.broadcast(channel, reliability, payload)
	func poll() -> Array[Dictionary]:
		return bus_peer.poll()
	func close() -> void:
		bus_peer.close()

class DuelScene extends "res://src/versus/versus_main.gd":
	var bus_peer: VersusLoopback
	func _read_command_line() -> void:
		local_team = bus_peer.local_peer()
		mode = Mode.HOST if local_team == 0 else Mode.CLIENT
		_seat = VersusRoster.runner_seat(local_team)
		room_mode = VersusRoster.RoomMode.DUEL_COMBINED
		room_code = "234567"
	func _open_link(_as_host: bool) -> void:
		var test_link := TestLink.new()
		test_link.bus_peer = bus_peer
		link = test_link
	func _start_debug_log() -> void:
		pass

var failures: Array[String] = []
var links: Array = []
var views: Array[SubViewport] = []
var scenes: Array = []

func check(ok: bool, label: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		failures.append(label)

func _physics_process(delta: float) -> void:
	for bus_peer in links:
		bus_peer.advance(delta)

func _ready() -> void:
	process_physics_priority = -200
	# The やめる button asks before it leaves; a saved "don't ask" would make
	# the button check below really leave.
	UiPrefs.set_skip_quit_confirm(false)
	links = VersusLoopback.mesh(2, 0.1) # 200ms RTT must not re-kill a respawn.
	for i in range(2):
		var view := SubViewport.new()
		view.size = Vector2i(1280, 720)
		view.world_2d = World2D.new()
		add_child(view)
		views.append(view)
		var scene := DuelScene.new()
		scene.bus_peer = links[i]
		view.add_child(scene)
		scenes.append(scene)
	await _ticks(100)
	# The stage's enemies stay down here: this probe is about touch.
	var hm: VersusMatch = scenes[0].host.match_rules
	for i in range(hm._enemy_up_at.size()):
		hm._enemy_up_at[i] = 1 << 30
	for i in range(2):
		var scene = scenes[i]
		check(not scene.waiting(), "peer %d leaves waiting" % i)
		check(scene.runners[i].is_physics_processing(), "peer %d local physics enabled" % i)
		check(not scene.input.hubs[1].is_processing_input() and not scene.input.hubs[1].is_processing_unhandled_input(),
			"peer %d unused hub cannot consume touch" % i)
		# The やめる button is a real Button: the hub reads fingers before the
		# GUI and must leave a press on it alone, or it can never be pressed.
		# (It opens the やめる question, which is closed again below, so the
		# probe never leaves.)
		var leave: Button = scene._leave_button
		var leave_pressed := [0]
		var count := func() -> void: leave_pressed[0] += 1
		leave.pressed.connect(count)
		var on_leave: Vector2 = leave.get_global_rect().get_center()
		_touch(i, 9, on_leave, true)
		await _ticks(2)
		check(scene.input.hubs[0]._gui_fingers.has(9)
				and not scene.input.hubs[0]._touch_owner.has(9),
			"peer %d hub leaves a press on the menu button to the GUI" % i)
		_touch(i, 9, on_leave, false)
		await _ticks(2)
		check(not scene.input.hubs[0]._gui_fingers.has(9),
			"peer %d and forgets it on release" % i)
		check(leave_pressed[0] == 1 and scene._quit.asking(),
			"peer %d the menu button is pressed by touch, and asks first" % i)
		leave.pressed.disconnect(count)
		scene._quit.cancel()
		check(scene.level._dynamic.get_child_count() == 0,
			"peer %d builds the arena without 1-1's pickups or enemies" % i)
		var layout := ControlLayout.layout("shared", Vector2(1280, 720), false)
		var stick: Dictionary = layout["stick"]
		var at: Vector2 = stick["center"] + Vector2(float(stick["radius"]) * 0.7, 0)
		# From the flat home ground, where a walk right meets no step.
		var start_x := 60.0 if i == 0 else VersusStageData.WIDTH - 60.0
		scene.runners[i].global_position = Vector2(start_x, VersusStageData.top_at(start_x) - 26.0)
		scene.runners[i].velocity = Vector2.ZERO
		await _ticks(10)
		var before: Vector2 = scene.runners[i].global_position
		_touch(i, 0, at, true)
		await _ticks(30)
		check(scene.input.hubs[0].move_axis > 0.2, "peer %d touch reaches its own hub" % i)
		# Round the loop: peer 1 starts just short of the join and crosses it.
		var walked := fposmod(scene.runners[i].global_position.x - before.x, VersusStageData.WIDTH)
		check(walked > 20.0 and walked < VersusStageData.WIDTH * 0.5,
			"peer %d actually walks from viewport touch (%.0fpx)" % [i, walked])
		_touch(i, 0, at, false)
		await _ticks(30)
		check(is_zero_approx(scene.input.hubs[0].move_axis), "peer %d releases stick" % i)
		check(VersusStageData.nearest_image(scenes[1 - i].runners[i].global_position,
			scene.runners[i].global_position).distance_to(
			scene.runners[i].global_position) < 3.0,
			"peer %d movement reaches the other screen" % i)
		# Jump from open floor: the start is on the steps, and a walk to the
		# right ends under a block row.
		# Open sky over the home ground (further in, a block row is overhead).
		var home_x := 60.0 if i == 0 else VersusStageData.WIDTH - 60.0
		scene.runners[i].global_position = Vector2(home_x, VersusStageData.top_at(home_x) - 26.0)
		scene.runners[i].velocity = Vector2.ZERO
		await _ticks(20)
		var jump_at: Vector2 = layout["jump"]["center"]
		var y: float = scene.runners[i].global_position.y
		_touch(i, 1, jump_at, true)
		await _ticks(8)
		check(scene.runners[i].global_position.y < y - 10, "peer %d touch jump works" % i)
		_touch(i, 1, jump_at, false)
		await _ticks(50)
		# Keep the left thumb down and shoot the other player with the right:
		# a tap on them, on the right of the screen.
		_touch(i, 0, at, true)
		var other: Runner = scene.runners[1 - i]
		var m: VersusMatch = scenes[0].host.match_rules
		for c in m.ledger.coins:
			if c.state == ArenaCoin.State.WORLD:
				ArenaCoin.to_recycle(c, m.tick)
		m._spawn_in = 100000
		var star := m.ledger.get_coin(5 + i)
		ArenaCoin.to_held(star, 1 - i)
		await _ticks(8)
		# Bring them on screen, standing in the open: a shot is aimed at what
		# you can see, and a block row overhead would be cover.
		var pos := _open_spot(scene, scene.runners[i].global_position.x + 300.0)
		other.global_position = pos
		scenes[1 - i].runners[1 - i].global_position = VersusStageData.nearest_image(pos,
			scenes[1 - i].runners[1 - i].global_position)
		await _ticks(20)
		var on_screen: Vector2 = views[i].get_canvas_transform() * scene._near(other.global_position)
		var held_before := m.ledger.held_by(1 - i).size()
		# 1-1's way: the 射撃 button chooses the rifle, a tap fires it.
		_touch(i, 2, layout["slot_3"]["center"], true)
		_touch(i, 2, layout["slot_3"]["center"], false)
		await _ticks(3)
		check(scene.guardian.active_slot == 3, "peer %d chooses the rifle with its button" % i)
		_touch(i, 3, on_screen, true)
		_touch(i, 3, on_screen, false)
		await _ticks(20)
		check(scene.input.hubs[0].move_axis > 0.2,
			"peer %d keeps moving while the other thumb shoots" % i)
		# Counted, not by id: a hit knocks loose the victim's lowest-numbered
		# star, which may be one they picked up earlier rather than this one.
		check(m.ledger.held_by(1 - i).size() == held_before - 1,
			"peer %d shoots the other player by tapping them, and the host takes a star" % i)
		_touch(i, 0, at, false)
		await _ticks(10)
	# A platform traced on peer 1's screen is on peer 0's too, solid, and
	# goes when it expires on peer 1.
	var shared := ControlLayout.layout("shared", Vector2(1280, 720), false)
	var b_scene = scenes[1]
	_touch(1, 2, shared["slot_1"]["center"], true)
	_touch(1, 2, shared["slot_1"]["center"], false)
	await _ticks(3)
	check(b_scene.guardian.active_slot == 1, "peer 1 chooses the platform with its button")
	# In open air ahead of and above peer 1's runner, wherever that is.
	var trace_from: Vector2 = views[1].get_canvas_transform() \
		* (b_scene.runners[1].global_position + Vector2(150.0, -170.0))
	await _drag(1, 4, trace_from, trace_from + Vector2(160.0, 0.0))
	await _ticks(20)
	var theirs: Array = b_scene.guardian.holograms_of(Hologram.Kind.PLATFORM)
	check(theirs.size() == 1, "peer 1 traces a platform")
	var seen_on_a: Hologram = null
	for key in scenes[0]._holos:
		if String(key).begins_with("%d:" % b_scene._seat):
			seen_on_a = scenes[0]._holos[key]["main"]
	check(seen_on_a != null and theirs.size() == 1
			and seen_on_a.global_position.distance_to(_near_to(theirs[0].global_position,
				seen_on_a.global_position)) < 2.0
			and seen_on_a.path == theirs[0].path,
		"and the same platform, in the same place and shape, is on peer 0's screen")
	if seen_on_a != null:
		var a_runner: Runner = scenes[0].runners[0]
		var top := seen_on_a.global_position
		a_runner.global_position = Vector2(top.x, top.y - 90.0)
		a_runner.velocity = Vector2.ZERO
		await _ticks(40)
		check(a_runner.global_position.y < top.y and a_runner.is_on_floor(),
			"peer 0's runner can stand on peer 1's platform")
	await _ticks(int(Balance.PLATFORM_LIFETIME * 60.0) + 40)
	check(b_scene.guardian.holograms_of(Hologram.Kind.PLATFORM).is_empty()
			and scenes[0]._holos.is_empty(),
		"and when it runs out on peer 1 it is gone from peer 0 as well")
	# The moving platforms and the enemies run on the match's clock: both
	# devices show them in the same place (a guest a tick or two behind).
	var worst_mover := 0.0
	var lifts_a: Array = scenes[0].level.find_children("*", "MovingPlatform", true, false)
	var lifts_b: Array = scenes[1].level.find_children("*", "MovingPlatform", true, false)
	for k in range(mini(lifts_a.size(), lifts_b.size())):
		worst_mover = maxf(worst_mover, (lifts_a[k] as Node2D).global_position.distance_to(
			(lifts_b[k] as Node2D).global_position))
	check(not lifts_a.is_empty() and lifts_a.size() == lifts_b.size() and worst_mover < 12.0,
		"the moving platforms agree on both screens (worst %.1fpx)" % worst_mover)
	var worst_enemy := 0.0
	for k in range(VersusStageData.enemy_specs().size()):
		var a: Vector2 = VersusEnemies.position_of(VersusStageData.enemy_specs()[k], scenes[0].enemy_tick())
		var b: Vector2 = VersusEnemies.position_of(VersusStageData.enemy_specs()[k], scenes[1].enemy_tick())
		worst_enemy = maxf(worst_enemy, a.distance_to(b))
	check(worst_enemy < 12.0, "and so do the enemies (worst %.1fpx)" % worst_enemy)
	check(scenes[1].enemy_alive(0) == scenes[0].enemy_alive(0),
		"and whether one is down")
	# This subscription belongs to _ready, not the first role swap.
	for i in range(2):
		for attempt in range(2):
			var runner: Runner = scenes[i].runners[i]
			ArenaCoin.to_held(scenes[0].host.match_rules.ledger.get_coin(0), i)
			runner.die("probe")
			await _ticks(15)
			check(scenes[0].host.match_rules.ledger.held_by(i).is_empty(),
				"peer %d death %d returns its coins" % [i, attempt])
			await _ticks(VersusRules.RESPAWN_TICKS + 100)
			check(runner.state != Runner.State.DEAD and scenes[i]._respawn_in[i] == 0,
				"peer %d death %d respawns without a death echo loop" % [i, attempt])
			check(not runner.is_invulnerable(), "peer %d respawn blinking expires" % i)
			var layout := ControlLayout.layout("shared", Vector2(1280, 720), false)
			var at: Vector2 = layout["stick"]["center"] + Vector2(40, 0)
			var before: float = runner.global_position.x
			_touch(i, 0, at, true)
			await _ticks(20)
			_touch(i, 0, at, false)
			check(runner.global_position.x > before + 10, "peer %d moves after respawn" % i)
			await _ticks(25)
	Events.scope_state_changed.emit(true, 1.0)
	check(scenes[0].input.hubs[0].scope_engaged, "scope state is subscribed before any role swap")
	Events.scope_state_changed.emit(false, 1.0)
	Events.roles_swapped.emit(false)
	Events.roles_swapped.emit(true)
	check(scenes[0].input.hubs[0].runner_on_left, "role swaps preserve versus input layout")
	for view in views:
		view.queue_free()
	await get_tree().process_frame
	for bus_peer in links:
		bus_peer._bus.clear()
	links.clear()
	scenes.clear()
	views.clear()
	print("versus touch probe: %d checks failed" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _touch(peer: int, finger: int, at: Vector2, pressed: bool) -> void:
	var start := at
	var stick: Dictionary = ControlLayout.layout("shared", Vector2(1280, 720), false)["stick"]
	var steering := pressed and finger == 0 and at.distance_to(stick["center"]) < float(stick["radius"])
	if steering:
		start = stick["center"]
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = start
	event.pressed = pressed
	views[peer].push_input(event, true)
	if steering:
		var drag := InputEventScreenDrag.new()
		drag.index = finger
		drag.position = at
		drag.relative = at - start
		views[peer].push_input(drag, true)

func _drag(peer: int, finger: int, from: Vector2, to: Vector2) -> void:
	_touch(peer, finger, from, true)
	for k in range(1, 9):
		var e := InputEventScreenDrag.new()
		e.index = finger
		e.position = from.lerp(to, float(k) / 8.0)
		e.relative = (to - from) / 8.0
		views[peer].push_input(e, true)
		await get_tree().physics_frame
	_touch(peer, finger, to, false)

## Floor near x with open sky over it (nothing a shot from above would hit).
func _open_spot(scene, x: float) -> Vector2:
	for dx in [0.0, -40.0, 40.0, -80.0, 80.0, -120.0, 120.0]:
		var top := VersusStageData.top_at(x + dx)
		if top == INF:
			continue
		var p := Vector2(x + dx, top - 26.0)
		if scene.line_clear(p + VersusRules.SHOT_FROM, p):
			return p
	return Vector2(x, VersusStageData.top_at(x) - 26.0)

func _near_to(at: Vector2, to: Vector2) -> Vector2:
	return VersusStageData.nearest_image(at, to)

func _ticks(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
