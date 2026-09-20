class_name VersusWsTransport
extends VersusTransport

## One event per state change, not one log line per frame.
signal diagnostic(message: String)
## Four peers over the same Cloudflare relay the cooperative game uses, at a
## different door.
##
## `/room4/<code>` rather than `/room/<code>`: a separate route, a separate
## Durable Object namespace and a cap of four. The cooperative room still holds
## two and still refuses a third, which its own test asserts -- raising
## MAX_PEERS would have changed the meaning of every room that already exists.
##
## The addressing that makes four peers possible is one byte. A frame leaves as
##
##     [destination][channel][payload...]
##
## and arrives as
##
##     [sender][channel][payload...]
##
## The relay rewrites that first byte and reads nothing else. Without it the
## relay is a broadcast bus: every peer receives every packet and none of them
## can tell who sent it, which is the shape the cooperative transport is stuck
## in (src/net/transport.gd:40, no sender in the poll result).

const BROADCAST: int = 0xff
const CODE_LENGTH: int = 6

var _socket := WebSocketPeer.new()
var _url: String = ""
var _index: int = -1
var _present: Array[int] = []
var _inbox: Array[Dictionary] = []
var _last_error: String = ""
var _last_state: int = -1
var _started_ms: int = 0
var _timed_out: bool = false

static func state_name(state: int) -> String:
	match state:
		WebSocketPeer.STATE_CONNECTING: return "CONNECTING"
		WebSocketPeer.STATE_OPEN: return "OPEN"
		WebSocketPeer.STATE_CLOSING: return "CLOSING"
		WebSocketPeer.STATE_CLOSED: return "CLOSED"
	return "UNKNOWN(%d)" % state

func socket_state() -> String:
	return state_name(_socket.get_ready_state())

func endpoint() -> String:
	# Exclude the random client identifier query from copied debug reports.
	return _url.split("?")[0]

## Six characters from the relay's alphabet. Not the co-op's six digits: a
## versus code and a co-op code are different rooms even when they read the
## same, and making them look different is cheaper than explaining that.
static func new_code() -> String:
	const ALPHABET := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := ""
	for i in range(CODE_LENGTH):
		out += ALPHABET[rng.randi_range(0, ALPHABET.length() - 1)]
	return out

static func valid_code(code: String) -> bool:
	if code.length() != CODE_LENGTH:
		return false
	const ALPHABET := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
	for i in range(code.length()):
		if not ALPHABET.contains(code[i]):
			return false
	return true

func open_room(relay: String, code: String, client_id: String = "") -> String:
	var base := relay.strip_edges().rstrip("/")
	if base.begins_with("https://"):
		base = "wss://" + base.substr(8)
	elif base.begins_with("http://"):
		base = "ws://" + base.substr(7)
	elif not base.begins_with("ws"):
		base = "wss://" + base
	_url = "%s/room4/%s" % [base, code.to_upper()]
	if not client_id.is_empty():
		_url += "?cid=" + client_id.uri_encode()
	_last_error = ""
	_timed_out = false
	_started_ms = Time.get_ticks_msec()
	diagnostic.emit("DIAL " + endpoint())
	var err := _socket.connect_to_url(_url)
	if err != OK:
		_last_error = "connect_to_url error %d" % err
		diagnostic.emit(_last_error)
		return _last_error
	return ""

## Drive the socket. Called every frame; the relay's control JSON and the
## peers' binary frames arrive on the same wire and are told apart by type.
func poll_socket() -> void:
	_socket.poll()
	var state := _socket.get_ready_state()
	if state != _last_state:
		_last_state = state
		diagnostic.emit("WebSocket " + state_name(state))
		if state == WebSocketPeer.STATE_CLOSED and _last_error.is_empty():
			_last_error = "WebSocket CLOSED (code=%d reason=%s)" % [
				_socket.get_close_code(), _socket.get_close_reason()]
			diagnostic.emit(_last_error)
	if state == WebSocketPeer.STATE_CONNECTING and not _timed_out \
			and Time.get_ticks_msec() - _started_ms > 15000:
		_timed_out = true
		_last_error = "WebSocket CONNECTING 15秒超過 (DNS/TLS/サーバーを確認)"
		diagnostic.emit(_last_error)
	while _socket.get_ready_state() == WebSocketPeer.STATE_OPEN \
			and _socket.get_available_packet_count() > 0:
		# get_packet() FIRST: was_string_packet() reports on the packet already
		# taken, not the one still queued. The cooperative transport records the
		# same trap (src/net/websocket_transport.gd:164-166) -- reading it the
		# other way round makes every control message arrive as binary, and here
		# that meant the "joined" reply never assigned this peer its index, so
		# the link was open and the transport said it was not.
		var packet := _socket.get_packet()
		if _socket.was_string_packet():
			_control(packet.get_string_from_utf8())
			continue
		if packet.size() < 2:
			continue
		_inbox.append({
			"from": packet[0],
			"channel": packet[1],
			"payload": packet.slice(2),
		})

func _control(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		diagnostic.emit("invalid relay control JSON")
		return
	match String(parsed.get("t", "")):
		"joined":
			_index = int(parsed.get("index", -1))
			diagnostic.emit("RELAY joined index=%d peers=%d cap=%d" % [
				_index, int(parsed.get("peers", -1)), int(parsed.get("cap", -1))])
		"peer-joined", "peer-left":
			diagnostic.emit("RELAY %s peers=%d" % [
				String(parsed.get("t", "")), int(parsed.get("peers", -1))])
		"error":
			_last_error = String(parsed.get("reason", "relay error"))
			diagnostic.emit("RELAY error: " + _last_error)

func local_peer() -> int:
	return _index

func peers() -> Array[int]:
	# Everyone else the room could hold. The relay does not enumerate them, and
	# a packet to an empty index is simply dropped there -- which is the same
	# outcome as not sending it.
	var out: Array[int] = []
	for i in range(4):
		if i != _index:
			out.append(i)
	return out

func send_to(peer_id: int, channel: int, _reliability: int,
		payload: PackedByteArray) -> void:
	_send(peer_id, channel, payload)

func broadcast(channel: int, _reliability: int,
		payload: PackedByteArray) -> void:
	_send(BROADCAST, channel, payload)

## Reliability is not honoured, and saying so is better than implying it: the
## relay is a WebSocket over TCP, so everything arrives, in order, and a lost
## snapshot is really a delayed one. The same honest limitation the cooperative
## transport records (src/net/websocket_transport.gd:17-21), and the same
## upgrade path out of it.
func _send(dest: int, channel: int, payload: PackedByteArray) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var frame := PackedByteArray()
	frame.resize(2)
	frame[0] = dest
	frame[1] = channel
	frame.append_array(payload)
	if frame.size() > MAX_PACKET_BYTES:
		_last_error = "packet of %d bytes is over the relay's limit" % frame.size()
		diagnostic.emit(_last_error)
		return
	var err := _socket.send(frame)
	if err != OK:
		_last_error = "WebSocket.send error %d" % err
		diagnostic.emit(_last_error)

func poll() -> Array[Dictionary]:
	var out := _inbox
	_inbox = []
	return out

func is_open() -> bool:
	return _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and _index >= 0

func last_error() -> String:
	return _last_error

func close() -> void:
	_socket.close()
	_inbox.clear()
	_index = -1
