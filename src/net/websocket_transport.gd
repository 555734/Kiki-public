class_name WebSocketTransport
extends NetTransport
## Plays over the internet by relaying through a tiny Cloudflare Worker.
##
## EnetTransport connects two devices directly, which works on one Wi-Fi and
## nowhere else: a direct connection needs one side to have a reachable address,
## and two people in different houses behind ordinary routers do not have one.
## This goes around that instead of through it -- both peers dial out to a relay,
## which is a connection every network allows.
##
## Relaying is normally the expensive answer, and for most games it would be the
## wrong one. It is affordable here because of who is on each end. The runner's
## device holds the simulation, so their input never crosses the network at all;
## the extra hop lands entirely on the guardian, who is reading seconds ahead and
## whose commands are lag-compensated when they arrive (docs/netcode.md 1 and 8).
##
## The honest limitation: WebSockets are TCP, so a lost packet holds up the ones
## behind it -- there is no unreliable channel to be had. Snapshots are sent on
## one anyway and the receiver drops stale ones by tick, which is the same
## outcome by a slower road. EOS P2P has real unreliable delivery and is the
## upgrade path; it plugs in here as another NetTransport.

## Six decimal digits are fast to type on a phone and still provide one million
## possible room ids. Leading zeroes are valid and preserved as text.
const CODE_LENGTH := 6

var _socket := WebSocketPeer.new()
## Deliberately not STATE_CLOSED, which is a real state a socket can be in.
## Seeded with it, a dial that failed before the first poll looked like "no
## change" and the failure was never announced: the connect screen sat on
## "connecting to room XXXXXX..." with nothing behind it and no way out but
## restarting the app.
const STATE_UNKNOWN: int = -1
var _state: int = STATE_UNKNOWN
var _room_code: String = ""
## Kept so the link can be rebuilt without the panel, which is long gone by the
## time a phone goes into a pocket and the socket dies.
var _url: String = ""
var _role: String = ""
## Sent to the relay so a returning player can be recognised. See NetLink.
var _client_id: String = ""
var _desired_role: String = ""
## The last close the socket reported, kept for the diagnostic. -1 means the
## socket has not closed, which is a different fact from "closed with code 0".
var last_close_code: int = -1
var last_close_reason: String = ""
## Plain counters, for the live probe and for the on-device diagnostic. Cheap
## enough to leave in: "is anything arriving at all" is the first question in
## every connection problem and the hardest one to answer from the outside.
## Peers that have been told to close and are still shutting down.
var _closing: Array[WebSocketPeer] = []
var packets_in: int = 0
var packets_out: int = 0
var _peer_present: bool = false

signal joined(role: String)
signal peer_connected
signal peer_disconnected
signal failed(reason: String)

## A six-digit room number. The value stays a String so leading zeroes survive.
static func new_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%06d" % rng.randi_range(0, 999999)

static func valid_code(code: String) -> bool:
	if code.length() != CODE_LENGTH:
		return false
	for i in range(code.length()):
		var c := code.unicode_at(i)
		if c < 48 or c > 57:
			return false
	return true

## `relay` is the worker's base URL, e.g. https://side-sky.<name>.workers.dev
##
## `client_id` and `role` ride on the query string. The relay uses the id to
## recognise a device that is coming BACK -- closing the socket it left behind
## instead of refusing the room as full -- and the role to hand the returning
## player the seat they had. Neither is a secret; both are meaningless outside
## this room.
func open_room(relay: String, code: String, client_id: String = "",
		role: String = "") -> String:
	_room_code = code
	_client_id = client_id
	_desired_role = role
	var base := relay.strip_edges().rstrip("/")
	if base.begins_with("https://"):
		base = "wss://" + base.substr(8)
	elif base.begins_with("http://"):
		base = "ws://" + base.substr(7)
	elif not base.begins_with("ws"):
		base = "wss://" + base
	_url = "%s/room/%s" % [base, _room_code]
	var query := PackedStringArray()
	if not _client_id.is_empty():
		query.append("cid=" + _client_id.uri_encode())
	if not _desired_role.is_empty():
		query.append("role=" + _desired_role.uri_encode())
	if not query.is_empty():
		_url += "?" + "&".join(query)
	return _dial()

## Re-dial the same room. The relay hands out roles by arrival order and the
## host never left, so the returning guest is a guest again and the host is told
## "peer-joined" exactly as it was the first time. Nothing else has to know a
## reconnection is different from a connection.
func reconnect() -> String:
	if _url.is_empty():
		return "no room to return to"
	# Hang up before dialling again, and keep the old peer alive long enough to
	# finish doing it. The relay's rooms hold exactly two peers, so a second
	# socket opened while the first still holds a slot is refused as "room is
	# full" -- and a WebSocketPeer that is dropped on the floor never completes
	# its close, because nothing polls it any more. _closing is polled until it
	# is really shut.
	_socket.close()
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_closing.append(_socket)
	_socket = WebSocketPeer.new()
	_state = STATE_UNKNOWN
	_peer_present = false
	return _dial()

func _dial() -> String:
	var err := _socket.connect_to_url(_url)
	if err != OK:
		return "could not open %s (error %d)" % [_url, err]
	return ""

func room_code() -> String:
	return _room_code

func role() -> String:
	return _role

## Must be pumped every frame: WebSocketPeer does nothing on its own.
func poll() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Sockets on their way out still need pumping, or their close never lands
	# and the relay goes on counting them against the room.
	for i in range(_closing.size() - 1, -1, -1):
		_closing[i].poll()
		if _closing[i].get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_closing.remove_at(i)
	_socket.poll()
	var now := _socket.get_ready_state()
	if now != _state:
		_state = now
		if now == WebSocketPeer.STATE_CLOSED:
			var code := _socket.get_close_code()
			last_close_code = code
			last_close_reason = _socket.get_close_reason()
			if _peer_present:
				_peer_present = false
				peer_disconnected.emit()
			else:
				failed.emit("relay closed the connection (%d)" % code)
	if now != WebSocketPeer.STATE_OPEN:
		return out

	while _socket.get_available_packet_count() > 0:
		# get_packet() first: was_string_packet() reports on the packet already
		# taken, not the one still queued. Reading it the other way round made
		# every control message arrive as binary with "{" as its channel byte.
		var packet := _socket.get_packet()
		if _socket.was_string_packet():
			_handle_control(packet.get_string_from_utf8())
			continue
		if packet.size() < 1:
			continue
		# One leading byte carries the channel. The relay does not read it.
		packets_in += 1
		out.append({"channel": int(packet[0]), "payload": packet.slice(1)})
	return out

## The relay's own bookkeeping, which is JSON and never binary.
func _handle_control(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	match String(parsed.get("t", "")):
		"joined":
			_role = String(parsed.get("role", ""))
			joined.emit(_role)
			# The guest arrives second, so the room is already full for them.
			if int(parsed.get("peers", 1)) >= 2:
				_peer_present = true
				peer_connected.emit()
		"peer-joined":
			_peer_present = true
			peer_connected.emit()
		"peer-left":
			_peer_present = false
			peer_disconnected.emit()
		"expired":
			failed.emit("the room expired")
		"error":
			failed.emit(String(parsed.get("reason", "relay error")))

func send(channel: int, _reliability: int, payload: PackedByteArray) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if payload.size() + 1 > MAX_PACKET_BYTES:
		push_error("packet of %d bytes exceeds the relay's cap" % (payload.size() + 1))
		return
	# Reliability is ignored on purpose: TCP gives one behaviour and pretending
	# otherwise would be a lie the rest of the netcode might act on.
	var framed := PackedByteArray([channel])
	framed.append_array(payload)
	packets_out += 1
	_socket.put_packet(framed)

## Is this side's own connection to the relay up? Distinct from
## is_connected_to_peer, which also asks whether the OTHER player is there.
## The difference decides whether silence is worth re-dialling for.
func is_link_open() -> bool:
	return _socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func is_connected_to_peer() -> bool:
	return _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and _peer_present

func close() -> void:
	_socket.close()
	_peer_present = false