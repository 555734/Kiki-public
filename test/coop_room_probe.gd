extends Node
## An online co-op room outlives its stage (CoopRoom). Each side is a real
## world on one end of a loopback link; the probe plays the partner on the
## other end by hand.
##
##   host:  quit to the stage screen -> the link stays up and the partner is
##          told; the host picks the next stage -> the partner is told which,
##          and the reloaded stage answers the partner's HELLO.
##   guest: told to go to the stage screen -> goes, cannot pick; told the
##          stage -> loads it and says HELLO for it on the same link.
##   接続を切る closes the link.

const MainScene: PackedScene = preload("res://src/main.tscn")

var failures: Array[String] = []
var world: Node2D = null
var links: Array = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func _physics_process(delta: float) -> void:
	for t in links:
		t.advance(delta)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## What CoopRoom does instead of reloading this probe's own scene.
func _swap_world() -> void:
	if world != null and is_instance_valid(world):
		remove_child(world)
		world.free()
	world = MainScene.instantiate()
	add_child(world)

func _start(which: int) -> void:
	Stage.use(which)
	_swap_world()
	await _frames(4)
	var panel := world.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
	await _frames(2)
	world.input_hub.scripted = true

func _kinds(t: LoopbackTransport) -> Array:
	var out: Array = []
	for packet in t.poll():
		var parsed := Protocol.reader(packet["payload"])
		out.append([int(parsed[0]), parsed[1]])
	return out

func _has(received: Array, kind: int) -> Variant:
	for r in received:
		if r[0] == kind:
			return r[1]
	return null

func _button_named(root: Node, text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).text == TranslationServer.translate(text):
			return n
	return null

func run() -> void:
	CoopRoom.reload_scene = _swap_world
	await _host_side()
	await _guest_side()
	CoopRoom.reload_scene = Callable()
	if world != null and is_instance_valid(world):
		world.queue_free()
	Stage.use(Stage.Which.GREENFIELD)
	await get_tree().process_frame
	if failures.is_empty():
		print("coop room probe: all checks passed")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("coop room probe: " + f)
		get_tree().quit(1)

func _host_side() -> void:
	await _start(Stage.Which.GREENFIELD)
	var pair := LoopbackTransport.pair(0.0)
	links = pair
	var mine: LoopbackTransport = pair[0]
	var partner: LoopbackTransport = pair[1]
	world._become_host(mine, "runner")
	partner.send(NetTransport.Channel.CONTROL, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.hello("guest-1", Stage.current(), "guardian"))
	await _frames(6)
	check(_has(_kinds(partner), Protocol.Msg.WELCOME) != null, "host: the partner is welcomed")

	world.quit_stage()
	await _frames(6)
	check(CoopRoom.state == CoopRoom.State.AT_MENU and CoopRoom.is_host,
		"host: quitting online keeps the room, at the stage screen")
	check(mine.is_connected_to_peer(), "host: and the link stays up")
	check(_has(_kinds(partner), Protocol.Msg.ROOM_MENU) != null,
		"host: the partner is told to come to the stage screen")
	var panel := world.get_node_or_null("NetPanel")
	check(panel != null and _button_named(panel, "接続を切る") != null,
		"host: the stage screen shows the room and a way to leave it")
	check(world.host_session == null, "host: no stage owns the link between stages")

	CoopRoom.start_stage(Stage.Which.SEA)
	await _frames(8)
	var go = _has(_kinds(partner), Protocol.Msg.STAGE_GO)
	check(go != null and int(go.get_u8()) == Stage.Which.SEA,
		"host: choosing a stage tells the partner which")
	check(Stage.current() == Stage.Which.SEA and world.get_node_or_null("NetPanel") == null,
		"host: and goes straight into it")
	check(world.host_session != null and world.host_session.transport == mine
		and CoopRoom.state == CoopRoom.State.NONE,
		"host: the new stage hosts on the same link")
	partner.send(NetTransport.Channel.CONTROL, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.hello("guest-1", Stage.Which.SEA, "guardian"))
	await _frames(6)
	check(_has(_kinds(partner), Protocol.Msg.WELCOME) != null,
		"host: and welcomes the partner into it")
	world._end_any_session()

func _guest_side() -> void:
	await _start(Stage.Which.GREENFIELD)
	var pair := LoopbackTransport.pair(0.0)
	links = pair
	var mine: LoopbackTransport = pair[0]
	var host: LoopbackTransport = pair[1]
	world._become_client(mine, "guardian")
	await _frames(4)
	check(_has(_kinds(host), Protocol.Msg.HELLO) != null, "guest: says HELLO")
	host.send(NetTransport.Channel.CONTROL, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.welcome(Clock.tick, "host-1"))
	await _frames(4)

	host.send(NetTransport.Channel.CONTROL, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.room_menu())
	await _frames(8)
	check(CoopRoom.state == CoopRoom.State.AT_MENU and not CoopRoom.is_host,
		"guest: follows the host to the stage screen, keeping the room")
	var panel := world.get_node_or_null("NetPanel")
	var cards_locked := panel != null
	if panel != null:
		for b in [panel._stage_1_1, panel._stage_1_2, panel._stage_1_3]:
			if b != null:
				cards_locked = cards_locked and (b as Button).disabled
	check(cards_locked, "guest: and cannot pick the stage itself")

	host.send(NetTransport.Channel.CONTROL, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.stage_go(Stage.Which.SWAMP))
	await _frames(8)
	check(Stage.current() == Stage.Which.SWAMP and world.client_session != null
		and world.client_session.transport == mine,
		"guest: the host's choice loads that stage on the same link")
	var hello = _has(_kinds(host), Protocol.Msg.HELLO)
	var stage_said := -1
	if hello != null:
		hello.get_u8()
		stage_said = hello.get_u8()
	check(stage_said == Stage.Which.SWAMP, "guest: and says HELLO for the new stage")

	# Back to the stage screen, then 接続を切る.
	world.quit_stage()
	await _frames(6)
	check(CoopRoom.state == CoopRoom.State.AT_MENU, "guest: can bring both back to the stage screen")
	check(_has(_kinds(host), Protocol.Msg.ROOM_MENU) != null, "guest: and the host is told")
	panel = world.get_node_or_null("NetPanel")
	var leave: Button = _button_named(panel, "接続を切る") if panel != null else null
	if leave != null:
		leave.pressed.emit()
	await _frames(3)
	check(CoopRoom.state == CoopRoom.State.NONE and not mine.is_connected_to_peer(),
		"接続を切る closes the room and the link")
	panel = world.get_node_or_null("NetPanel")
	check(panel != null and _button_named(panel, "接続を切る") == null,
		"and the stage screen is the ordinary one again")
