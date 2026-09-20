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
	links = VersusLoopback.mesh(2, 0.025)
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
	for i in range(2):
		var scene = scenes[i]
		check(not scene.waiting(), "peer %d leaves waiting" % i)
		check(scene.runners[i].is_physics_processing(), "peer %d local physics enabled" % i)
		check(not scene.input.hubs[1].is_processing_unhandled_input(),
			"peer %d unused hub cannot consume touch" % i)
		var layout := ControlLayout.layout("runner", Vector2(1280, 720), false)
		var stick: Dictionary = layout["stick"]
		var at: Vector2 = stick["center"] + Vector2(float(stick["radius"]) * 0.7, 0)
		var before: Vector2 = scene.runners[i].global_position
		_touch(i, 0, at, true)
		await _ticks(30)
		check(scene.input.hubs[0].move_axis > 0.2, "peer %d touch reaches its own hub" % i)
		check(scene.runners[i].global_position.x > before.x + 20,
			"peer %d actually walks from viewport touch" % i)
		_touch(i, 0, at, false)
		await _ticks(30)
		check(is_zero_approx(scene.input.hubs[0].move_axis), "peer %d releases stick" % i)
		check(scenes[1 - i].runners[i].global_position.distance_to(
			scene.runners[i].global_position) < 3.0,
			"peer %d movement reaches the other screen" % i)
		var jump_at: Vector2 = layout["jump"]["center"]
		var y: float = scene.runners[i].global_position.y
		_touch(i, 1, jump_at, true)
		await _ticks(8)
		check(scene.runners[i].global_position.y < y - 10, "peer %d touch jump works" % i)
		_touch(i, 1, jump_at, false)
		await _ticks(50)
		# Keep the left thumb down while the other thumb opens the build palette.
		_touch(i, 0, at, true)
		var build_at: Vector2 = scene.controls._circles()["build"]
		_touch(i, 2, build_at, true)
		_touch(i, 2, build_at, false)
		await _ticks(2)
		check(scene.controls.palette_open and scene.input.hubs[0].move_axis > 0.2,
			"peer %d can open building while holding movement" % i)
		_touch(i, 0, at, false)
		var world_at := Vector2(640, 180)
		_touch(i, 3, world_at, true)
		_touch(i, 3, world_at, false)
		await _ticks(20)
		check(scenes[0].host.builds.size() == i + 1 and scenes[1].client.builds.size() == i + 1,
			"peer %d touch construction reaches both screens" % i)
		_touch(i, 2, build_at, true)
		_touch(i, 2, build_at, false)
	# This subscription belongs to _ready, not the first role swap.
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
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = pressed
	views[peer].push_input(event, true)

func _ticks(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
