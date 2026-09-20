extends Node
## Four real sockets, one real relay.
##
## The cooperative ws_probe does this for two, and its value is the same here:
## the loopback probe proves the DESIGN, and this proves the design survives
## contact with a socket, a URL, a routing byte and a server written in another
## language. Everything between the two is where four devices fail to meet.
##
## Needs a relay. `cd server/signaling && npm run dev`, then
##   GODOT=... godot --headless --path . res://test/versus_ws_probe.tscn
## Override the address with the VERSUS_RELAY environment variable. Skipped,
## loudly, when nothing is listening -- a probe that cannot run says so rather
## than passing.

var failures: Array[String] = []
var _links: Array[VersusWsTransport] = []

func check(ok: bool, label: String) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		failures.append(label)
		print("  FAIL  %s" % label)

func _ready() -> void:
	var relay := OS.get_environment("VERSUS_RELAY")
	if relay.is_empty():
		relay = "ws://localhost:8787"
	var code := VersusWsTransport.new_code()
	print("versus ws probe: room %s at %s" % [code, relay])

	for i in range(4):
		var t := VersusWsTransport.new()
		var err := t.open_room(relay, code, "probe-%d" % i)
		if not err.is_empty():
			_give_up("could not dial: " + err)
			return
		_links.append(t)

	if not await _wait_for(func() -> bool:
			for t in _links:
				if not t.is_open():
					return false
			return true, 8.0):
		_give_up("no relay answered at %s" % relay)
		return

	var indices: Array[int] = []
	for t in _links:
		indices.append(t.local_peer())
	indices.sort()
	check(indices == [0, 1, 2, 3],
		"four sockets were given the indices 0,1,2,3 (%s)" % str(indices))

	# A real protocol packet, addressed to one peer.
	var hello := VersusProtocol.hello(VersusRoster.SEAT_B_RUNNER)
	_links[1].send_to(0, VersusTransport.Channel.CONTROL,
		VersusTransport.Reliability.RELIABLE, hello)
	var got := await _next_packet(_links[0], 4.0)
	check(not got.is_empty(), "a HELLO reaches the host")
	if not got.is_empty():
		check(int(got["from"]) == _links[1].local_peer(),
			"stamped with the sender's index, not the destination")
		check(int(got["channel"]) == VersusTransport.Channel.CONTROL,
			"on the channel it was sent on")
		var read := VersusProtocol.read_hello(got["payload"])
		check(int(read["wanted_seat"]) == VersusRoster.SEAT_B_RUNNER
				and int(read["version"]) == VersusProtocol.VERSION,
			"and decodes to the seat it asked for")
	# Nobody else got it.
	await _settle(0.4)
	check(_links[2].poll().is_empty() and _links[3].poll().is_empty(),
		"and the other two received nothing")

	# A full snapshot, broadcast, over the wire the game will really use.
	var runners: Array = []
	for i in range(2):
		runners.append({"position": Vector2(6500 + i * 900, 200),
			"velocity": Vector2.ZERO, "facing": 1, "alive": true,
			"can_act": true, "invulnerable": false, "on_floor": true,
			"hp": 2, "combat_phase": 0, "combat_dir": 1})
	var coins: Array = []
	for i in range(VersusRules.COIN_TOTAL):
		coins.append({"id": i, "state": ArenaCoin.State.WORLD, "owner": -1,
			"position": Vector2(7000 + i * 5, 260)})
	var snap := VersusProtocol.snapshot(1234, 0, -1, runners, coins, [])
	_links[0].broadcast(VersusTransport.Channel.SNAPSHOT,
		VersusTransport.Reliability.UNRELIABLE, snap)

	var heard := 0
	for i in range(1, 4):
		var p := await _next_packet(_links[i], 4.0)
		if p.is_empty():
			continue
		var back := VersusProtocol.read_snapshot(p["payload"])
		if int(back["tick"]) == 1234 \
				and back["coins"].size() == VersusRules.COIN_TOTAL:
			heard += 1
	check(heard == 3,
		"a broadcast snapshot reaches all three others intact (%d/3)" % heard)

	_finish()

# ------------------------------------------------------------------ plumbing
func _pump() -> void:
	for t in _links:
		t.poll_socket()

func _wait_for(cond: Callable, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		_pump()
		if bool(cond.call()):
			return true
		await get_tree().process_frame
		waited += 1.0 / 60.0
	return false

func _next_packet(link: VersusWsTransport, seconds: float) -> Dictionary:
	var waited := 0.0
	while waited < seconds:
		_pump()
		var got := link.poll()
		if not got.is_empty():
			return got[0]
		await get_tree().process_frame
		waited += 1.0 / 60.0
	return {}

func _settle(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		_pump()
		await get_tree().process_frame
		waited += 1.0 / 60.0

func _give_up(why: String) -> void:
	print("versus ws probe: SKIPPED -- %s" % why)
	print("  (start one with: cd server/signaling && npm run dev)")
	for t in _links:
		t.close()
	get_tree().quit(0)

func _finish() -> void:
	for t in _links:
		t.close()
	print("versus ws probe: %d checks failed" % failures.size())
	if failures.is_empty():
		print("four sockets, one relay, one room")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("versus ws probe: " + f)
		get_tree().quit(1)
