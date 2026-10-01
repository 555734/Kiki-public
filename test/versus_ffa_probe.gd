extends Node
## みんなで スターたいせん as real scenes: three people (an odd number on
## purpose -- a team mode could not seat them), each one character, each in
## its own viewport over a loopback link. Chairs handed out by the host,
## start with fewer than eight, "3, 2, 1", walking and building from the same
## screen with real touches, one person's win on every screen, and a rematch.

class TestLink extends VersusTransport:
	var bus_peer: VersusLoopback
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

class FfaScene extends "res://src/versus/versus_main.gd":
	var bus_peer: VersusLoopback
	func _read_command_line() -> void:
		mode = Mode.HOST if bus_peer.local_peer() == 0 else Mode.CLIENT
		room_mode = VersusRoster.RoomMode.FREE_FOR_ALL
		room_code = "345678"
		_seat = 0 if mode == Mode.HOST else -1
		# The host picked 1-2; the guests start in the default and must
		# follow it from the WELCOME.
		_theme = Stage.Which.HORROR if mode == Mode.HOST else Stage.Which.GREENFIELD
		_set_local_team()
	func _open_link(_as_host: bool) -> void:
		var test_link := TestLink.new()
		test_link.bus_peer = bus_peer
		link = test_link
	func _start_debug_log() -> void:
		pass

const PEOPLE := 3

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
	# The menu: みんなで is the first choice and asks for no chair; 2対2 does.
	var panel: Control = load("res://src/ui/versus_panel.gd").new()
	add_child(panel)
	await get_tree().process_frame
	check(panel._room_mode() == VersusRoster.RoomMode.FREE_FOR_ALL and not panel._seat.visible,
		"the menu opens on みんなで, with no chair to pick")
	panel._mode.select(1)
	panel._update_mode()
	check(panel._room_mode() == VersusRoster.RoomMode.TEAM_SPLIT and panel._seat.visible,
		"and 2対2 still asks which chair")
	check(panel._stage.item_count == 5, "and offers 1-1 to 1-5")
	panel.queue_free()
	links = VersusLoopback.mesh(PEOPLE, 0.04)
	for i in range(PEOPLE):
		var view := SubViewport.new()
		view.size = Vector2i(1280, 720)
		view.world_2d = World2D.new()
		add_child(view)
		views.append(view)
		var scene := FfaScene.new()
		scene.bus_peer = links[i]
		view.add_child(scene)
		scenes.append(scene)
	await _ticks(90)
	var host = scenes[0]

	# ---------------------------------------------------------- the room
	var seats: Dictionary = {}
	for s in scenes:
		seats[s._seat] = true
	check(seats.size() == PEOPLE and seats.has(0) and seats.has(1) and seats.has(2),
		"the host is P1 and the others were handed P2 and P3")
	var ready := true
	for s in scenes:
		ready = ready and s.waiting() and s.local_team == s._seat and s.controls != null \
			and s.guardian != null and s.runners.size() == 8
	check(ready, "each person drives their own one of eight runners, with the rifle")
	check(host.can_start(), "three people is enough to start")
	var followed := true
	for sc in scenes:
		followed = followed and sc.theme() == Stage.Which.HORROR
	check(followed and Stage.current() == Stage.Which.HORROR,
		"every guest repainted the arena as the host's 1-2")
	var hidden := true
	for i in range(PEOPLE, 8):
		hidden = hidden and not scenes[1].runners[i].visible
	check(hidden, "empty chairs show no runner")

	host._start_button.pressed.emit()
	await _ticks(20)
	check(scenes[1].countdown_ticks() > 0 and scenes[2].countdown_ticks() > 0,
		"the countdown reaches everyone")
	await _ticks(VersusRules.COUNTDOWN_TICKS + 10)
	var on := true
	for s in scenes:
		on = on and s.can_move() and s.phase() == VersusMatch.Phase.PLAYING
	check(on, "then everyone can move")
	check(host.match_rules.on_field == 1, "with one star on the field")

	# ----------------------------------------- walking and shooting, one person
	var p3 = scenes[2]
	var body: Runner = p3.runners[2]
	var before := body.global_position
	_touch(2, 0, _stick_at(1.0), true)
	await _ticks(30)
	_touch(2, 0, _stick_at(1.0), false)
	await _ticks(10)
	check(body.global_position.distance_to(before) > 20.0,
		"P3 walks with a real touch (%.0fpx)" % body.global_position.distance_to(before))
	# Compared round the loop: P2's camera is half a lap away, so it draws P3
	# in the copy just across the join -- the near one, which is the point.
	check(_loop_distance(host.runners[2].global_position, body.global_position) < 40.0
			and _loop_distance(scenes[1].runners[2].global_position, body.global_position) < 40.0,
		"and both other screens see P3 there")
	# P3 shoots P1 by tapping them on P3's own screen.
	var hm: VersusMatch = host.match_rules
	for c in hm.ledger.coins:
		if c.state == ArenaCoin.State.WORLD:
			ArenaCoin.to_recycle(c, hm.tick)
	hm._spawn_in = 100000
	var star := hm.ledger.get_coin(3)
	ArenaCoin.to_held(star, 0)
	var held_before := hm.ledger.held_by(0).size()
	# P1 stands in the open (no block row overhead: that would be cover).
	var target_pos := _open_spot(host, body.global_position.x + 320.0)
	host.runners[0].global_position = target_pos
	host.runners[0].velocity = Vector2.ZERO
	await _ticks(30)
	var on_screen: Vector2 = views[2].get_canvas_transform() * p3._near(p3.runners[0].global_position)
	var slot_3: Vector2 = ControlLayout.layout("versus", Vector2(1280, 720), false)["slot_3"]["center"]
	_touch(2, 2, slot_3, true)
	_touch(2, 2, slot_3, false)
	await _ticks(3)
	_touch(2, 3, on_screen, true)
	_touch(2, 3, on_screen, false)
	await _ticks(20)
	check(hm.ledger.held_by(0).size() == held_before - 1,
		"P3 shoots P1 by tapping them, and P1's star comes loose")
	var none := true
	for s in scenes:
		none = none and s._built.is_empty()
	check(none, "and nobody can build")

	# ------------------------------------------- bodies are solid; bumps
	# P2 walks into P3, both on guests' machines: neither passes through,
	# and the host takes a star off each.
	await _ticks(VersusRules.HIT_IMMUNE_TICKS + 10)
	for c in hm.ledger.coins:
		if c.state == ArenaCoin.State.WORLD or c.state == ArenaCoin.State.HELD:
			ArenaCoin.to_recycle(c, hm.tick)
	ArenaCoin.to_held(hm.ledger.get_coin(1), 1)
	ArenaCoin.to_held(hm.ledger.get_coin(2), 2)
	var p2 = scenes[1]
	var p3_body: Runner = p3.runners[2]
	# Both on 1-1's middle hill (x 1360..1600), clear of its block stack.
	p3_body.global_position = Vector2(1500.0, VersusStageData.top_at(1500.0) - 26.0)
	p3_body.velocity = Vector2.ZERO
	p2.runners[1].global_position = Vector2(1410.0, VersusStageData.top_at(1410.0) - 26.0)
	p2.runners[1].velocity = Vector2.ZERO
	host.runners[0].global_position = Vector2(400.0, VersusStageData.top_at(400.0) - 26.0)
	await _ticks(30)
	var felt: int = p2.bumps_felt + p3.bumps_felt
	var closest := INF
	var dropped := {}
	_touch(1, 0, _stick_at(1.0), true)
	for k in range(60):
		await get_tree().physics_frame
		for e in hm.events:
			if String(e["kind"]) == "drop":
				dropped[int(e["side"])] = int(e["coin"])
		closest = minf(closest, _loop_distance(p2.runners[1].global_position,
			p2.runners[2].global_position))
	_touch(1, 0, _stick_at(1.0), false)
	await _ticks(20)
	check(closest >= Balance.RUNNER_SIZE.x - 3.0,
		"P2 walking into P3 stops at P3's body (closest %.0fpx)" % closest)
	# Read off the host's events: a star knocked loose may be picked
	# straight back up afterwards, which is fair.
	check(dropped.get(1, -1) == 1 and dropped.get(2, -1) == 2,
		"and the bump knocks a star out of both of them")
	check(p2.bumps_felt + p3.bumps_felt > felt, "and they are thrown apart")

	# ------------------------------------------------------------- the end
	for id in range(VersusRules.FFA_WIN_AT):
		ArenaCoin.to_held(host.match_rules.ledger.get_coin(id), 2)
	await _ticks(20)
	var over := true
	for s in scenes:
		over = over and s.phase() == VersusMatch.Phase.OVER and s.winner() == 2
	check(over, "seven stars held by P3 end it on every screen, with P3 the winner")
	host._again_button.pressed.emit()
	await _ticks(VersusRules.COUNTDOWN_TICKS + 20)
	var again := true
	for s in scenes:
		again = again and s.phase() == VersusMatch.Phase.PLAYING \
			and s.score(2) == 0 and s._built.is_empty()
	check(again, "a rematch starts everyone over")

	for view in views:
		view.queue_free()
	await get_tree().process_frame
	for bus_peer in links:
		bus_peer._bus.clear()
	links.clear()
	scenes.clear()
	views.clear()
	print("versus ffa probe: %d checks failed" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

static func _loop_distance(a: Vector2, b: Vector2) -> float:
	return VersusStageData.nearest_image(a, b).distance_to(b)

## Floor near x with open sky over it (nothing a shot from above would hit).
func _open_spot(scene, x: float) -> Vector2:
	for dx in [0.0, -40.0, 40.0, -80.0, 80.0, -120.0, 120.0]:
		var top := VersusStageData.top_at(x + dx)
		if top == INF:
			continue
		var p := Vector2(VersusStageData.wrap_x(x + dx), top - 26.0)
		if scene.line_clear(p + VersusRules.SHOT_FROM, p):
			return p
	return Vector2(VersusStageData.wrap_x(x), VersusStageData.top_at(x) - 26.0)

func _stick_at(dir: float) -> Vector2:
	var layout := ControlLayout.layout("versus", Vector2(1280, 720), false)
	var stick: Dictionary = layout["stick"]
	return stick["center"] + Vector2(float(stick["radius"]) * 0.7 * dir, 0)

func _touch(peer: int, finger: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = pressed
	views[peer].push_input(event, true)

func _ticks(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
