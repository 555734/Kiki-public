extends Node
## Connects two WebSocketTransports to a locally running relay and passes a
## packet between them. Verifies the real socket, the real relay and the real
## framing rather than a mock of any of them.
var a := WebSocketTransport.new()
var b := WebSocketTransport.new()
var got: Array = []

func _ready() -> void:
	# RELAY=wss://... to point at a deployed worker; defaults to a local one.
	var relay := OS.get_environment("RELAY")
	if relay.is_empty():
		relay = "ws://localhost:8787"
	print("relay ", relay)
	var code := WebSocketTransport.new_code()
	print("room ", code)
	var e1 := a.open_room(relay, code)
	var e2 := b.open_room(relay, code)
	if e1 != "" or e2 != "":
		print("FAIL open: ", e1, " / ", e2)
		get_tree().quit(1)
		return
	var deadline := Time.get_ticks_msec() + 12000
	var sent := false
	while Time.get_ticks_msec() < deadline:
		for packet in a.poll():
			got.append(["a", packet["channel"], Array(packet["payload"])])
		for packet in b.poll():
			got.append(["b", packet["channel"], Array(packet["payload"])])
		if not sent and a.is_connected_to_peer() and b.is_connected_to_peer():
			sent = true
			print("roles: a=", a.role(), " b=", b.role())
			a.send(NetTransport.Channel.EVENT,
				NetTransport.Reliability.RELIABLE_ORDERED, PackedByteArray([20, 1, 2, 255]))
			b.send(NetTransport.Channel.SNAPSHOT,
				NetTransport.Reliability.UNRELIABLE, PackedByteArray([7, 7]))
		if got.size() >= 2:
			break
		await get_tree().process_frame
	print("received: ", got)
	var ok := got.size() >= 2
	for entry in got:
		if entry[0] == "b" and entry[1] == NetTransport.Channel.EVENT \
				and entry[2] == [20, 1, 2, 255]:
			print("PASS: event packet crossed the relay intact on its channel")
		if entry[0] == "a" and entry[1] == NetTransport.Channel.SNAPSHOT \
				and entry[2] == [7, 7]:
			print("PASS: snapshot packet crossed the other way")
	a.close(); b.close()
	get_tree().quit(0 if ok else 1)
