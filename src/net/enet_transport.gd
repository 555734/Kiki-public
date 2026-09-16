class_name EnetTransport
extends NetTransport
## The transport that actually carries a game today.
##
## ENet is built into Godot: no SDK, no GDExtension, no account, no service in
## the middle, and nothing to pay for. It is packet-based with channels and
## per-packet reliability, which is exactly the shape NetTransport describes, so
## the netcode above it needs no special case.
##
## What it does not do is traverse NAT. Two phones on the same Wi-Fi connect
## directly; over the internet the host needs a reachable address. That is the
## one thing EOS was going to add (docs/netcode.md section 2), and it plugs in
## here as a second implementation rather than as a rewrite.

const CHANNELS: int = 8

var _host: ENetConnection = null
var _peer: ENetPacketPeer = null
var _is_server: bool = false
var _connected: bool = false
var _address: String = ""
var _port: int = 0

signal peer_connected
signal peer_disconnected

## Listen for the guardian. Returns "" on success or a reason to show.
func listen(port: int, bind_address: String = "*") -> String:
	_host = ENetConnection.new()
	var err := _host.create_host_bound(bind_address, port, 1, CHANNELS)
	if err != OK:
		_host = null
		return "could not listen on port %d (error %d)" % [port, err]
	_is_server = true
	return ""

func connect_to(address: String, port: int) -> String:
	_host = ENetConnection.new()
	var err := _host.create_host(1, CHANNELS)
	if err != OK:
		_host = null
		return "could not create a client socket (error %d)" % err
	_peer = _host.connect_to_host(address, port, CHANNELS)
	if _peer == null:
		_host = null
		return "could not reach %s:%d" % [address, port]
	_is_server = false
	_address = address
	_port = port
	return ""

## Same idea as the relay's: dial the address again. Only the client ever does
## this -- the listening side keeps its socket and simply waits.
func reconnect() -> String:
	if _is_server or _address.is_empty():
		return "nothing to reconnect to"
	close()
	return connect_to(_address, _port)

func send(channel: int, reliability: int, payload: PackedByteArray) -> void:
	if _peer == null or not _connected:
		return
	if payload.size() > MAX_PACKET_BYTES:
		push_error("packet of %d bytes exceeds the %d cap" % [payload.size(), MAX_PACKET_BYTES])
		return
	var flags := 0
	match reliability:
		Reliability.RELIABLE_ORDERED, Reliability.RELIABLE_UNORDERED:
			flags = ENetPacketPeer.FLAG_RELIABLE
		_:
			# Unsequenced as well as unreliable: a snapshot that arrives after a
			# newer one is worse than useless, and ENet would otherwise hold it
			# back to preserve order.
			flags = ENetPacketPeer.FLAG_UNSEQUENCED
	_peer.send(channel, payload, flags)

func poll() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _host == null:
		return out
	while true:
		var e := _host.service(0)
		var type: int = e[0]
		if type == ENetConnection.EVENT_NONE:
			break
		match type:
			ENetConnection.EVENT_CONNECT:
				_peer = e[1]
				_connected = true
				peer_connected.emit()
			ENetConnection.EVENT_DISCONNECT:
				_connected = false
				_peer = null
				peer_disconnected.emit()
			ENetConnection.EVENT_RECEIVE:
				var p: ENetPacketPeer = e[1]
				out.append({"channel": int(e[3]), "payload": p.get_packet()})
	return out

func is_connected_to_peer() -> bool:
	return _connected

## Round trip as ENet measures it, in seconds. Used to bound how far a client
## may ask the host to rewind -- see Rewind.allowed_rewind.
func round_trip() -> float:
	if _peer == null:
		return 0.0
	return float(_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) / 1000.0

func close() -> void:
	if _peer != null:
		_peer.peer_disconnect_now(0)
	if _host != null:
		_host.destroy()
	_host = null
	_peer = null
	_connected = false
