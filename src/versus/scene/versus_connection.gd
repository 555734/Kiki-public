class_name VersusConnection
extends RefCounted
## Getting a versus room online: the WebSocket relay (editor, probes) or EOS
## (what ships), and then a VersusHost or VersusClient once the link is open.
##
## The link, host, client and room live on the arena, which everything else
## reads; this is only the procedure that fills them in.

var arena = null
## Why the room could not be reached, or "".
var error: String = ""

func _init(owner_arena) -> void:
	arena = owner_arena

func open(as_host: bool) -> void:
	if arena.use_eos:
		_open_eos(as_host)
		return
	var ws := VersusWsTransport.new()
	ws.diagnostic.connect(arena._debug)
	arena.link = ws
	if as_host and arena.room_code.is_empty():
		arena.room_code = VersusWsTransport.new_code()
	arena.diagnostics.probe_relay_route(arena.relay(), arena.room_code)
	var err := ws.open_room(arena.relay(), arena.room_code,
		"versus-%d" % (Time.get_ticks_usec() & 0xffff))
	if not err.is_empty():
		arena.status = err
		arena._debug("open_room failed: " + err)
		return
	arena.status = "room %s - waiting" % arena.room_code

## EOS sign-in, then the four-person lobby, then P2P -- the same path co-op
## rooms take, in a bucket of their own. Asynchronous: the arena is already up
## and says what it is doing while this runs.
func _open_eos(as_host: bool) -> void:
	var room := EosVersusLobby.new(arena.room_mode)
	arena.eos_room = room
	if as_host:
		room.room_code = arena.room_code if EosVersusLobby.valid_code(arena.room_code) \
			else EosVersusLobby.new_code()
		arena.room_code = room.room_code
		room.room_code_chosen.connect(func(code: String) -> void:
			if room == arena.eos_room:
				arena.room_code = code)
	arena.status = "EOSに接続中"
	arena._debug("EOS versus %s room=%s" % ["host" if as_host else "join", arena.room_code])
	if not await EosRuntime.ensure_ready():
		_failed(room, EosRuntime.last_error)
		return
	if room != arena.eos_room:
		room.leave()
		return
	var ok := false
	if as_host:
		ok = await room.create_room()
	else:
		ok = await room.join_room(arena.room_code)
	if room != arena.eos_room:
		room.leave()
		return
	if not ok:
		_failed(room, room.last_error)
		return
	var t := VersusEosTransport.new()
	t.diagnostic.connect(arena._debug)
	var err := t.open(room)
	if not err.is_empty():
		_failed(room, err)
		return
	arena.link = t
	arena.status = "room %s" % arena.room_code

func _failed(room: EosVersusLobby, reason: String) -> void:
	if room != arena.eos_room:
		return
	error = reason
	arena.status = reason
	arena._debug("EOS failed: " + reason)

## Once the link is open: this machine becomes the host or a guest.
func poll() -> void:
	var link: VersusTransport = arena.link
	if link == null:
		return
	link.poll_socket()
	if arena.host != null or arena.client != null or not link.is_open():
		return
	if arena.is_host():
		if link.local_peer() != VersusTransport.HOST_PEER:
			arena.status = "room %s is already hosted elsewhere" % arena.room_code
			arena._debug("HOST rejected: relay assigned index=%d (expected 0)" % link.local_peer())
			return
		var host := VersusHost.new()
		host.diagnostic.connect(arena._debug)
		host.start(link, ArenaStage.new(arena._collision_rects()), 0, arena.room_mode)
		host.stage = arena.theme()
		arena.host = host
		arena.match_rules = host.match_rules
		arena._debug("HOST ready: peer=%d roster=%s" % [
			link.local_peer(), host.roster.describe()])
	else:
		var client := VersusClient.new()
		client.diagnostic.connect(arena._debug)
		client.start(link, arena._seat, arena.room_mode)
		arena.client = client
		arena._debug("JOIN ready: peer=%d" % link.local_peer())
	arena.status = "room %s" % arena.room_code

## Why the room stopped working, or "".
func link_error() -> String:
	if not error.is_empty():
		return error
	if arena.link != null:
		return arena.link.last_error()
	return ""

## The lobby stops advertising the room once the countdown starts.
var _marked_started: bool = false

func mark_started() -> void:
	if _marked_started or arena.eos_room == null or arena.host == null:
		return
	if arena.host.playing or arena.host.counting():
		_marked_started = true
		arena.eos_room.mark_started()

func close() -> void:
	if arena.link != null:
		arena.link.close()
	elif arena.eos_room != null:
		arena.eos_room.leave()
	arena.eos_room = null
