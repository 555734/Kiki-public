class_name VersusEosTransport
extends VersusTransport
## The four-peer VersusTransport over EOS P2P, for the 2v2 star match.
##
## A star, not a mesh: the host is the EOSG server and everyone else connects
## to it alone, which is all VersusHost/VersusClient need -- clients only ever
## talk to the host, and the host sends each client what it needs. Framing
## follows the co-op EosTransport: one leading byte of application channel.
##
## Peer ids: EOSG numbers its server 1 and its clients with random ids.
## VersusTransport promises the host is peer 0, so the server's 1 is mapped to
## 0 on the way in and back to 1 on the way out. Client ids pass through.
##
## A client that drops is reported to the host as a BYE from that peer, the
## message the host already vacates a seat on. The host dropping is reported
## to a client as a failure: without migration there is no match left.

signal diagnostic(message: String)
signal failed(reason: String)

const PAYLOAD_LIMIT := 1100
const EOS_SERVER_PEER := 1
const EARLY_MAX := 32
const UNKNOWN_REQUEST_GRACE_MS := 6000

var room: EosVersusLobby = null
var packets_in: int = 0
var packets_out: int = 0
var _peer: MultiplayerPeer = null
var _is_host: bool = false
var _connected: Dictionary = {}   ## EOS peer id -> true
var _closed: bool = false
var _error: String = ""
## Reliable packets a client sent before its link to the host opened.
var _early: Array[PackedByteArray] = []
var _pending_since: Dictionary = {}
## Things this transport has to say itself (a synthetic BYE), delivered with
## the next poll().
var _inbox: Array[Dictionary] = []

func open(p_room: EosVersusLobby) -> String:
	room = p_room
	if room == null or room.lobby == null:
		return _set_error("EOSルームがありません")
	room.failed.connect(func(reason: String) -> void:
		_set_error(reason))
	if not ClassDB.can_instantiate("EOSGMultiplayerPeer"):
		return _set_error("EOS P2Pライブラリがありません")
	_is_host = room.local_is_owner()
	_peer = ClassDB.instantiate("EOSGMultiplayerPeer")
	_peer.set("refuse_new_connections", false)
	_peer.call("set_auto_accept_connection_requests", false)
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	var err: int
	if _is_host:
		err = int(_peer.call("create_server", room.socket_id()))
	else:
		var owner := room.owner_puid()
		if owner.is_empty():
			return _set_error("EOSルームのホストが見つかりません")
		err = int(_peer.call("create_client", room.socket_id(), owner))
	if err != OK:
		_peer = null
		return _set_error(TranslationServer.translate("EOS P2Pを開始できません（error %d）") % err)
	diagnostic.emit("EOS P2P open as %s socket=%s" % [
		"host" if _is_host else "client", room.socket_id()])
	return ""

static func to_game(eos_id: int) -> int:
	return VersusTransport.HOST_PEER if eos_id == EOS_SERVER_PEER else eos_id

static func to_eos(game_id: int) -> int:
	return EOS_SERVER_PEER if game_id == VersusTransport.HOST_PEER else game_id

func local_peer() -> int:
	if _peer == null:
		return -1
	return VersusTransport.HOST_PEER if _is_host else _peer.get_unique_id()

func is_host() -> bool:
	return _is_host

func peers() -> Array[int]:
	var out: Array[int] = []
	for id in _connected.keys():
		out.append(to_game(int(id)))
	return out

func is_open() -> bool:
	return _peer != null and not _closed and _error.is_empty()

func last_error() -> String:
	return _error

func send_to(peer_id: int, channel: int, reliability: int,
		payload: PackedByteArray) -> void:
	_send(to_eos(peer_id), channel, reliability, payload)

func broadcast(channel: int, reliability: int,
		payload: PackedByteArray) -> void:
	if _is_host:
		for id in _connected.keys():
			_send(int(id), channel, reliability, payload)
	else:
		_send(EOS_SERVER_PEER, channel, reliability, payload)

func _send(eos_id: int, channel: int, reliability: int,
		payload: PackedByteArray) -> void:
	if _peer == null or _closed:
		return
	if payload.size() + 1 > PAYLOAD_LIMIT:
		push_error("EOS packet of %d bytes exceeds the game cap %d" % [payload.size() + 1, PAYLOAD_LIMIT])
		return
	var framed := PackedByteArray([channel])
	framed.append_array(payload)
	if not _connected.has(eos_id):
		# A client's HELLO usually goes out before its link to the host has
		# opened; keep it rather than wait for the resend timer.
		if not _is_host and reliability != Reliability.UNRELIABLE \
				and _early.size() < EARLY_MAX:
			_early.append(framed)
		return
	_put(eos_id, framed, reliability)

func _put(eos_id: int, framed: PackedByteArray, reliability: int) -> void:
	_peer.set_transfer_channel(0)
	_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE \
		if reliability != Reliability.UNRELIABLE else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	_peer.set_target_peer(eos_id)
	var err := _peer.put_packet(framed)
	if err == OK:
		packets_out += 1
	elif reliability != Reliability.UNRELIABLE:
		diagnostic.emit("EOS send error %d to %d" % [err, eos_id])

## Connection requests and the socket, once a frame; poll() drains packets.
func poll_socket() -> void:
	if _peer == null or _closed:
		return
	_peer.poll()
	_answer_requests()

## Only current lobby members get a connection. Guessed socket ids and people
## who already left never reach the game protocol.
func _answer_requests() -> void:
	for request in _peer.call("get_all_connection_requests"):
		var puid := String(request)
		if puid == room.local_puid():
			_peer.call("deny_connection_request", puid)
		elif room.contains_puid(puid):
			_pending_since.erase(puid)
			_peer.call("accept_connection_request", puid)
		else:
			# The request usually beats the lobby update. Ask EOS for a fresh
			# copy and wait, refusing only if they never show up.
			var now := Time.get_ticks_msec()
			if not _pending_since.has(puid):
				_pending_since[puid] = now
				room.refresh()
			elif now - int(_pending_since[puid]) > UNKNOWN_REQUEST_GRACE_MS:
				_pending_since.erase(puid)
				_peer.call("deny_connection_request", puid)

func poll() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(_inbox)
	_inbox.clear()
	if _peer == null:
		return out
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		var from := to_game(_peer.get_packet_peer())
		var packet := _peer.get_packet()
		if packet.size() < 1 or packet.size() > PAYLOAD_LIMIT:
			continue
		packets_in += 1
		out.append({"from": from, "channel": int(packet[0]),
			"payload": packet.slice(1)})
	return out

func close() -> void:
	_closed = true
	_connected.clear()
	_early.clear()
	if _peer != null:
		_peer.close()
		_peer = null
	if room != null:
		room.leave()

func _on_peer_connected(id: int) -> void:
	_connected[id] = true
	diagnostic.emit("EOS peer connected %d" % id)
	if not _is_host and id == EOS_SERVER_PEER:
		var queued := _early
		_early = []
		for framed in queued:
			_put(EOS_SERVER_PEER, framed, Reliability.RELIABLE)

func _on_peer_disconnected(id: int) -> void:
	_connected.erase(id)
	diagnostic.emit("EOS peer disconnected %d" % id)
	if _is_host:
		_inbox.append({"from": to_game(id), "channel": Channel.CONTROL,
			"payload": VersusProtocol.bye(255)})
	elif id == EOS_SERVER_PEER:
		_set_error("ホストとの接続が切れました")

func _set_error(reason: String) -> String:
	if _error.is_empty():
		_error = reason
		failed.emit(reason)
	return reason
