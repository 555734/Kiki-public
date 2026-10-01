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
			and s.controls.duel and s.runners.size() == 8
	check(ready, "each person drives their own one of eight runners, build palette included")
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
	check(host.match_rules.on_field == VersusRules.ffa_on_field(PEOPLE),
		"with loose stars set for three people (%d)" % host.match_rules.on_field)

	# ----------------------------------------- walking and building, one person
	var p3 = scenes[2]
	var body: Runner = p3.runners[2]
	var before := body.global_position
	_touch(2, 0, _stick_at(1.0), true)
	await _ticks(30)
	_touch(2, 0, _stick_at(1.0), false)
	await _ticks(10)
	check(body.global_position.distance_to(before) > 20.0,
		"P3 walks with a real touch (%.0fpx)" % body.global_position.distance_to(before))
	check(host.runners[2].global_position.distance_to(body.global_position) < 40.0
			and scenes[1].runners[2].global_position.distance_to(body.global_position) < 40.0,
		"and both other screens see P3 there")
	var build_at: Vector2 = p3.controls._circles()["build"]
	_touch(2, 1, build_at, true)
	_touch(2, 1, build_at, false)
	await _ticks(2)
	check(p3.controls.palette_open, "the same person opens the build palette")
	_touch(2, 2, Vector2(640, 200), true)
	_touch(2, 2, Vector2(640, 200), false)
	await _ticks(20)
	var built := true
	for s in scenes:
		built = built and s._built.size() == 1 and s._build_owner[0] == 2
	check(built, "and P3's platform appears on every screen, in P3's name")

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

func _stick_at(dir: float) -> Vector2:
	var layout := ControlLayout.layout("runner", Vector2(1280, 720), false)
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
