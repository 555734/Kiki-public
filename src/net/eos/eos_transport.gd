class_name EosTransport
extends NetTransport
## NetTransport adapter over EOSGMultiplayerPeer. The leading byte is our
## application channel; EOSG's internal channel remains an implementation
## detail and the existing HostSession/ClientSession need no EOS branch.

signal peer_connected
signal peer_disconnected
signal authority_changed(local_is_owner: bool, epoch: int)
signal failed(reason: String)

const PAYLOAD_LIMIT := 1100

var room: EosCoopLobby = null
var _peer: MultiplayerPeer = null
var _connected := false
var _closed := false
var _authority_epoch := 0
var packets_in: int = 0
var packets_out: int = 0
## Reliable packets sent before the P2P link finished opening. They used to be
## dropped -- including the guest's HELLO, the one message that starts the
## game -- so nothing happened until the seven-second silence timer re-sent
## it. They go out the moment the link opens instead.
var _early: Array[PackedByteArray] = []
const EARLY_MAX := 32
## Connection requests from a player the lobby has not told us about yet.
## The request usually beats the lobby update; refusing it made the guest wait
## for EOS to retry. Held here, and answered as soon as the lobby catches up.
var _pending_since: Dictionary = {}
const UNKNOWN_REQUEST_GRACE_MS := 6000

## The real answer: both halves read off the lobby, never off a packet.
func peer_identity() -> Dictionary:
	if room == null:
		return {"puid": "", "room_kind": ""}
	return {"puid": room.remote_puid(), "room_kind": room.room_kind()}

func open(p_room: EosCoopLobby) -> String:
	room = p_room
	if room == null or room.lobby == null:
		return "EOSルームがありません"
	room.peer_joined.connect(_on_lobby_peer_joined)
	room.peer_left.connect(_on_lobby_peer_left)
	room.owner_changed.connect(_on_owner_changed)
	return _create_peer()

func _create_peer() -> String:
	if not ClassDB.can_instantiate("EOSGMultiplayerPeer"):
		return "EOS P2Pライブラリがありません"
	if _peer != null:
		_peer.close()
	_peer = ClassDB.instantiate("EOSGMultiplayerPeer")
	_peer.set("refuse_new_connections", false)
	_peer.call("set_auto_accept_connection_requests", false)
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	var err: int
	if room.local_is_owner():
		err = int(_peer.call("create_server", room.socket_id()))
	else:
		var owner := room.owner_puid()
		if owner.is_empty():
			return "EOSルームのホストが見つかりません"
		err = int(_peer.call("create_client", room.socket_id(), owner))
	if err != OK:
		_peer = null
		return "EOS P2Pを開始できません（error %d）" % err
	_closed = false
	return ""

func send(channel: int, reliability: int, payload: PackedByteArray) -> void:
	if _peer != null and not _connected and reliability != Reliability.UNRELIABLE:
		if _early.size() < EARLY_MAX:
			var framed_early := PackedByteArray([channel])
			framed_early.append_array(payload)
			_early.append(framed_early)
		return
	if _peer == null or not _connected:
		return
	if payload.size() + 1 > PAYLOAD_LIMIT:
		push_error("EOS packet of %d bytes exceeds the game cap %d" % [payload.size() + 1, PAYLOAD_LIMIT])
		return
	_peer.set_transfer_channel(0)
	_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE \
		if reliability != Reliability.UNRELIABLE else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	_peer.set_target_peer(0 if room.local_is_owner() else 1)
	var framed := PackedByteArray([channel])
	framed.append_array(payload)
	var err := _peer.put_packet(framed)
	if err != OK:
		failed.emit("EOSパケットを送信できません（error %d）" % err)
	else:
		packets_out += 1

func poll() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _peer == null:
		return out
	_peer.poll()
	# Only accept requests from the other current lobby member. Guessed socket
	# IDs and stale members never reach the game protocol.
	for request in _peer.call("get_all_connection_requests"):
		var puid := String(request)
		if puid == room.local_puid():
			_peer.call("deny_connection_request", puid)
		elif room.contains_puid(puid):
			_pending_since.erase(puid)
			_peer.call("accept_connection_request", puid)
		else:
			# Not in our copy of the lobby yet: ask EOS for a fresh copy and
			# wait, refusing only if they never show up.
			var now := Time.get_ticks_msec()
			if not _pending_since.has(puid):
				_pending_since[puid] = now
				room.refresh()
			elif now - int(_pending_since[puid]) > UNKNOWN_REQUEST_GRACE_MS:
				_pending_since.erase(puid)
				_peer.call("deny_connection_request", puid)
	while _peer.get_available_packet_count() > 0:
		var packet := _peer.get_packet()
		if packet.size() < 1 or packet.size() > PAYLOAD_LIMIT:
			continue
		packets_in += 1
		out.append({"channel": int(packet[0]), "payload": packet.slice(1)})
	return out

func is_link_open() -> bool:
	return _peer != null and not _closed \
		and _peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED

func is_connected_to_peer() -> bool:
	return _connected

func reconnect() -> String:
	_connected = false
	return _create_peer()

func authority_epoch() -> int:
	return _authority_epoch

func room_code() -> String:
	return room.room_code if room != null else ""

func close() -> void:
	_closed = true
	_connected = false
	_early.clear()
	if _peer != null:
		_peer.close()
		_peer = null
	if room != null:
		room.leave()

func _on_peer_connected(_id: int) -> void:
	if not _connected:
		_connected = true
		_flush_early()
		peer_connected.emit()

func _flush_early() -> void:
	var queued := _early
	_early = []
	for framed in queued:
		_peer.set_transfer_channel(0)
		_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		_peer.set_target_peer(0 if room.local_is_owner() else 1)
		if _peer.put_packet(framed) == OK:
			packets_out += 1

func _on_peer_disconnected(_id: int) -> void:
	if _connected:
		_connected = false
		peer_disconnected.emit()

func _on_lobby_peer_joined() -> void:
	# The server receives a connection request during poll. A client may have
	# been created while alone only after owner migration, so rebuild it here.
	if _peer == null:
		var err := _create_peer()
		if not err.is_empty():
			failed.emit(err)

func _on_lobby_peer_left() -> void:
	_on_peer_disconnected(0)

func _on_owner_changed(_owner: String, local_owner: bool) -> void:
	_authority_epoch += 1
	_connected = false
	var err := _create_peer()
	if not err.is_empty():
		failed.emit(err)
	authority_changed.emit(local_owner, _authority_epoch)
