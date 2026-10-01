extends Node
## The 2v2 star match as four real scenes: two runners and two guardians, each
## in its own viewport, talking over a loopback link. What only this can show:
## the waiting room, the host's start button, "3, 2, 1" on every screen, a
## guardian's platform reaching all four, a win on all four, and a rematch
## that every screen follows.

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

class TeamScene extends "res://src/versus/versus_main.gd":
	var bus_peer: VersusLoopback
	var wanted_seat: int = 0
	func _read_command_line() -> void:
		mode = Mode.HOST if bus_peer.local_peer() == 0 else Mode.CLIENT
		_seat = wanted_seat
		room_mode = VersusRoster.RoomMode.TEAM_SPLIT
		room_code = "123456"
		local_team = VersusRoster.team_of(_seat) \
			if VersusRoster.role_of(_seat) == VersusRoster.Role.RUNNER else -1
	func _open_link(_as_host: bool) -> void:
		var test_link := TestLink.new()
		test_link.bus_peer = bus_peer
		link = test_link
	func _start_debug_log() -> void:
		pass

## peer index -> seat. The host is always team A's runner.
const SEATS := [VersusRoster.SEAT_A_RUNNER, VersusRoster.SEAT_B_RUNNER,
	VersusRoster.SEAT_A_GUARDIAN, VersusRoster.SEAT_B_GUARDIAN]

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
	links = VersusLoopback.mesh(4, 0.04)
	for i in range(4):
		var view := SubViewport.new()
		view.size = Vector2i(1280, 720)
		view.world_2d = World2D.new()
		add_child(view)
		views.append(view)
		var scene := TeamScene.new()
		scene.bus_peer = links[i]
		scene.wanted_seat = SEATS[i]
		view.add_child(scene)
		scenes.append(scene)
	await _ticks(90)
	var host = scenes[0]
	var b_runner = scenes[1]
	var a_guard = scenes[2]

	# ----------------------------------------------------------- waiting room
	var all_waiting := true
	var all_seen := true
	for s in scenes:
		all_waiting = all_waiting and s.waiting()
		all_seen = all_seen and s.seat_mask() == 0x0F
	check(all_waiting, "everyone waits for the host's start")
	check(all_seen, "and every screen shows all four seats taken")
	check(host.can_start() and not b_runner.can_start(),
		"only the host can start")
	check(host._start_button.visible and not host._start_button.disabled
			and not b_runner._start_button.visible,
		"the host sees an enabled スタート button; nobody else sees one")
	var before: Vector2 = b_runner.runners[1].global_position
	_touch_stick(1, true)
	await _ticks(20)
	_touch_stick(1, false)
	check(b_runner.runners[1].global_position.distance_to(before) < 2.0,
		"a runner cannot move before the start")
	check(host.match_rules.tick == 0 and host.score(0) + host.score(1) == 0,
		"and nothing is scored")

	# ------------------------------------------------------------ countdown
	host._start_button.pressed.emit()
	await _ticks(30)
	check(host.countdown_ticks() > 0 and b_runner.countdown_ticks() > 0
			and a_guard.countdown_ticks() > 0,
		"pressing start shows 3, 2, 1 on every screen")
	check(not b_runner.can_move(), "and runners stay put through it")
	await _ticks(VersusRules.COUNTDOWN_TICKS)
	var all_on := true
	for s in scenes:
		all_on = all_on and not s.waiting() and s.countdown_ticks() == 0 \
			and s.phase() == VersusMatch.Phase.PLAYING
	check(all_on, "then the match is on for all four")
	check(b_runner.can_move() and b_runner.runners[1].is_physics_processing(),
		"and runners can move")
	check(a_guard.runners[1].visible and a_guard.runners[0].visible,
		"a guardian sees both teams' runners")

	before = b_runner.runners[1].global_position
	_touch_stick(1, true)
	await _ticks(30)
	_touch_stick(1, false)
	await _ticks(10)
	var moved: float = b_runner.runners[1].global_position.distance_to(before)
	check(moved > 20.0, "team B's runner walks from a real touch (%.0fpx)" % moved)
	# The walk can end off the edge of 1-1's hilltop; compare once landed,
	# not mid-fall with the host a few frames behind.
	await _ticks(40)
	check(host.runners[1].global_position.distance_to(
			b_runner.runners[1].global_position) < 40.0,
		"and the host sees it there")

	# ---------------------------------------------------------- the guardian
	var tools: Array = a_guard.guardian.abilities.keys() if a_guard.guardian != null else []
	tools.sort()
	check(a_guard.guardian != null and a_guard.guardian.command_router == null
			and tools == [1, 3] and a_guard.input.hubs[0].solo_role == "guardian",
		"team A's guardian has 1-1's platform and rifle, on the guardian layout")
	check(a_guard.guardian.runner == a_guard.runners[0],
		"and builds for team A's runner")
	var hm: VersusMatch = host.match_rules
	for c in hm.ledger.coins:
		if c.state == ArenaCoin.State.WORLD:
			ArenaCoin.to_recycle(c, hm.tick)
	hm._spawn_in = 100000
	var star := hm.ledger.get_coin(4)
	ArenaCoin.to_held(star, 1)
	var held_before := hm.ledger.held_by(1).size()
	# What the co-op rifle does when it hits: the target's take_damage.
	a_guard.runners[1].get_node("Shootable").take_damage(1, "snipe")
	await _ticks(20)
	check(hm.ledger.held_by(1).size() == held_before - 1,
		"team A's guardian shoots team B's runner and the star comes loose")
	check(not a_guard.runners[0].get_node("Shootable").is_shootable_now(),
		"but cannot shoot its own team's runner")
	var none_built := true
	for s in scenes:
		none_built = none_built and s._built.is_empty()
	check(none_built, "and nothing is ever built")

	# -------------------------------------------------------------- the end
	for id in range(VersusRules.WIN_AT):
		ArenaCoin.to_held(host.match_rules.ledger.get_coin(id), 1)
	await _ticks(20)
	var all_over := true
	for s in scenes:
		all_over = all_over and s.phase() == VersusMatch.Phase.OVER and s.winner() == 1
	check(all_over, "seven stars held by team B ends it on every screen")
	check(host._again_button.visible and not b_runner._again_button.visible,
		"the host can call a rematch; the others wait for it")
	check(b_runner._leave_button.visible and a_guard._leave_button.visible,
		"everyone can leave from the result")

	# ------------------------------------------------------------- rematch
	b_runner.runners[1].global_position += Vector2(-300.0, 0.0)
	host._again_button.pressed.emit()
	await _ticks(20)
	var fresh := true
	for s in scenes:
		fresh = fresh and s.countdown_ticks() > 0 and s.score(0) + s.score(1) == 0 \
			and s._built.is_empty()
	check(fresh, "a rematch clears the stars and the platforms, and counts down again")
	check(b_runner.runners[1].global_position.distance_to(
			VersusStageData.start_positions()[1]) < 30.0,
		"and team B's runner is back at its start")
	await _ticks(VersusRules.COUNTDOWN_TICKS + 10)
	var again := true
	for s in scenes:
		again = again and s.phase() == VersusMatch.Phase.PLAYING and s.can_move()
	check(again and host.match_rules.tick > 0, "and the second match is on")
	check(a_guard._leave_button.visible and b_runner._leave_button.visible,
		"during play everyone has a leave button")

	for view in views:
		view.queue_free()
	await get_tree().process_frame
	for bus_peer in links:
		bus_peer._bus.clear()
	links.clear()
	scenes.clear()
	views.clear()
	print("versus team probe: %d checks failed" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _touch_stick(peer: int, pressed: bool) -> void:
	var layout := ControlLayout.layout("versus", Vector2(1280, 720), false)
	var stick: Dictionary = layout["stick"]
	# Team B starts at the right wall facing left, so it walks left.
	var at: Vector2 = stick["center"] - Vector2(float(stick["radius"]) * 0.7, 0)
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	views[peer].push_input(event, true)

func _ticks(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
