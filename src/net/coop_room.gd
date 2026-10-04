extends Node
## An online co-op room that outlives the stage.
##
## A stage is a scene, and changing stage reloads it -- deliberately (see
## NetPanel._select_stage) -- which used to take the session, and with it the
## connection, along with everything else. So a room was one stage long:
## clearing it or quitting it meant making a new room and reading out a new
## code. The transport and the EOS lobby are plain objects, so this autoload
## keeps them across the reload. Between stages the pair sits at the stage
## screen; the host picks the next stage, the guest follows, and the stage's
## own sessions pick the same connection back up. The guest re-introduces
## itself with an ordinary HELLO and the host answers it the way it answers a
## reconnect, so nothing new has to be synchronised.
##
## The room ends only when someone presses 接続を切る (or the link itself goes).

enum State {
	NONE,       ## no room held here; a stage's main owns any connection
	AT_MENU,    ## between stages, at the stage screen
	STARTING,   ## a stage is loading and will take the room when it is up
}

var state: int = State.NONE
var transport: NetTransport = null
var eos_room: EosCoopLobby = null
var is_host: bool = false
var local_role: String = ""
var room_code: String = ""
var link_kind: String = ""
## Said once on the stage screen after the room ended by itself.
var parting_words: String = ""
## How a stage change happens. The game reloads the scene; a probe that holds
## the world as a child of its own scene swaps the world instead.
var reload_scene: Callable = Callable()

signal changed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func holding() -> bool:
	return state != State.NONE

## Leave the stage for the stage screen, keeping the room. `tell_partner` is
## false when this is the answer to the partner's own ROOM_MENU.
func go_to_menu(main: Node, tell_partner: bool = true) -> bool:
	if not _take(main):
		return false
	if tell_partner:
		transport.send(NetTransport.Channel.CONTROL,
			NetTransport.Reliability.RELIABLE_ORDERED, Protocol.room_menu())
	state = State.AT_MENU
	changed.emit()
	_reload.call_deferred()
	return true

## The host, at the stage screen, chose the next stage.
func start_stage(which: int) -> void:
	if state != State.AT_MENU or not is_host or transport == null:
		return
	transport.send(NetTransport.Channel.CONTROL,
		NetTransport.Reliability.RELIABLE_ORDERED, Protocol.stage_go(which))
	_begin(which)

## A guest still in the old stage was told to start the next one (its
## ROOM_MENU went missing, or arrived together with this).
func follow_into(main: Node, which: int) -> void:
	if _take(main):
		_begin(which)

func _begin(which: int) -> void:
	Stage.use(which)
	state = State.STARTING
	changed.emit()
	_reload.call_deferred()

func _reload() -> void:
	if reload_scene.is_valid():
		reload_scene.call()
	else:
		get_tree().reload_current_scene()

## Called by the freshly loaded stage: the room is its again.
func attach(main: Node) -> void:
	if state != State.STARTING or transport == null:
		return
	_unhook()
	var t := transport
	var room := eos_room
	transport = null
	eos_room = null
	state = State.NONE
	main.eos_room = room
	main.link.begin(room_code, "host" if is_host else "guest")
	main.link.enter(NetLink.Phase.WAITING_PEER if is_host else NetLink.Phase.HANDSHAKING)
	if t is EosTransport:
		main._watch_eos(t)
	elif t is WebSocketTransport:
		main._watch_transport(t)
	if is_host:
		main._start_host_session(t, local_role)
	else:
		main._start_client_session(t, local_role)
	changed.emit()

## 接続を切る.
func close(reason: String = "") -> void:
	_unhook()
	if transport != null:
		transport.close()
	if eos_room != null:
		eos_room.leave()
	transport = null
	eos_room = null
	state = State.NONE
	parting_words = reason
	Entitlement.revoke_guest()
	changed.emit()

## Take the connection out of a running stage without closing it.
func _take(main: Node) -> bool:
	var session: Node = main.host_session if main.host_session != null else main.client_session
	if session == null or not is_instance_valid(session) or session.get("transport") == null:
		return false
	transport = session.transport
	is_host = main.host_session != null
	local_role = String(session.local_role)
	eos_room = main.eos_room
	room_code = main.link.room_code
	link_kind = "eos" if transport is EosTransport else (
		"relay" if transport is WebSocketTransport else "lan")
	# Before the sessions go: their _exit_tree asks whether a room is being
	# kept, and if one is, the borrowed unlock stays.
	state = State.AT_MENU
	main._detach_sessions_keep_transport()
	main.eos_room = null
	_hook()
	return true

## The old stage's handlers are bound to a world that is about to be freed.
func _hook() -> void:
	_unhook()
	for sig in ["peer_disconnected", "failed"]:
		if transport.has_signal(sig):
			transport.connect(sig, _on_lost.bind(sig))
	if transport.has_signal("authority_changed"):
		transport.connect("authority_changed", _on_authority_changed)

## The transport's own signals only -- not the ones every Object has.
const LINK_SIGNALS := ["joined", "peer_connected", "peer_disconnected", "failed",
	"authority_changed"]

func _unhook() -> void:
	if transport == null:
		return
	for sig in LINK_SIGNALS:
		if not transport.has_signal(sig):
			continue
		for connection in transport.get_signal_connection_list(sig):
			transport.disconnect(sig, connection["callable"])

func _on_lost(_a = null, _b = null) -> void:
	if state == State.AT_MENU:
		close("相手との接続が切れました")

func _on_authority_changed(local_owner: bool, _epoch: int) -> void:
	is_host = local_owner

## Between stages nobody else is reading the link: keep it drained, and
## listen for the host's choice.
func _process(_delta: float) -> void:
	if state != State.AT_MENU or transport == null:
		return
	if transport.has_method("poll_socket"):
		transport.call("poll_socket")
	for packet in transport.poll():
		var parsed := Protocol.reader(packet["payload"])
		match int(parsed[0]):
			Protocol.Msg.STAGE_GO:
				if not is_host:
					var b: StreamPeerBuffer = parsed[1]
					_begin(int(b.get_u8()))
					return
			Protocol.Msg.NOTICE:
				pass
