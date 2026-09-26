extends Node2D
## Coin match on the shortened A-D circuit of 1-1. Uses the game's Runner,
## a local following camera, and a host-owned coin ledger.

const RunnerVisualScript = preload("res://src/runner/runner_visual.gd")

enum Mode { SOLO, HOST, CLIENT }

const COL_COIN := Color(1.0, 0.82, 0.29)
const COL_COIN_EDGE := Color(0.62, 0.45, 0.10)
## A guardian's construct, in its own team's colour. Read off the shared team
## palette rather than restated, so a platform is unmistakably one side's.
## Drawn nearly solid: the first version was translucent and vanished against
## 1-1's bright grass, which made a platform something you found by walking
## into it.
static func build_fill(team: int) -> Color:
	var c: Color = ArenaRules.TEAM_COLOURS[team]
	return Color(c.r, c.g, c.b, 0.80)

static func build_edge(team: int) -> Color:
	var c: Color = ArenaRules.TEAM_COLOURS[team]
	return Color(minf(1.0, c.r + 0.35), minf(1.0, c.g + 0.35),
		minf(1.0, c.b + 0.35), 1.0)

var mode: int = Mode.SOLO
var match_rules: VersusMatch = null       ## host and solo only
var host: VersusHost = null
var client: VersusClient = null
var link: VersusWsTransport = null
var room_code: String = ""
var room_mode: int = VersusRoster.RoomMode.TEAM_SPLIT
var controls: Control = null
var status: String = ""
var _debug_lines: Array[String] = []
var _debug_file: FileAccess = null
var _debug_copy_button: Button = null
var _relay_probe: HTTPRequest = null
var _relay_probe_detail: String = ""
var _last_match_state: String = ""
var _last_input_direction: int = 0
var _input_trace_ticks: int = 0

var runners: Array[Runner] = []
var input: VersusInput = null
var hud: Control = null
var guardian: Guardian = null

## Which runner this machine drives, or -1 for a guardian. Solo drives both.
var local_team: int = 0
var level: LevelBuilder = null
var _camera: Camera2D = null
var _built_body: StaticBody2D = null
var _built: Array[Rect2] = []
var _built_revision: int = -1
var _build_owner: Array[int] = []
var _respawn_in := [0, 0]
## Where each runner was when it died, so it comes back at the checkpoint
## behind THAT rather than behind wherever its corpse drifted to.
var _died_at := [Vector2.ZERO, Vector2.ZERO]
var _seat: int = VersusRoster.SEAT_A_RUNNER

func _ready() -> void:
	process_physics_priority = 100
	z_index = 5
	_read_command_line()
	if OS.has_feature("editor"):
		_start_debug_log()
	_build_world()

	input = VersusInput.new()
	input.name = "VersusInput"
	add_child(input)
	input.make_hubs(self, mode == Mode.SOLO)

	_build_runners()
	_finish_world()
	_build_camera()

	# In a CanvasLayer, because the camera moves now: the scoreboard belongs to
	# the screen, not to a place on the stage.
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)
	hud = preload("res://src/versus/versus_hud.gd").new()
	hud.arena = self
	layer.add_child(hud)
	if mode != Mode.SOLO and OS.has_feature("editor"):
		_debug_copy_button = Button.new()
		_debug_copy_button.text = "接続ログをコピー"
		_debug_copy_button.custom_minimum_size = Vector2(200, 44)
		_debug_copy_button.size = Vector2(200, 44)
		_debug_copy_button.pressed.connect(_copy_debug_log)
		layer.add_child(_debug_copy_button)
	if mode != Mode.SOLO and local_team >= 0:
		controls = preload("res://src/versus/versus_controls.gd").new()
		controls.arena = self
		controls.duel = room_mode == VersusRoster.RoomMode.DUEL_COMBINED
		layer.add_child(controls)

	match mode:
		Mode.SOLO:
			match_rules = VersusMatch.new()
			_start_solo()
		Mode.HOST:
			_open_link(true)
		Mode.CLIENT:
			_open_link(false)

	if room_mode != VersusRoster.RoomMode.DUEL_COMBINED \
			and VersusRoster.role_of(_seat) == VersusRoster.Role.GUARDIAN:
		_build_guardian()
	if room_mode == VersusRoster.RoomMode.DUEL_COMBINED and mode != Mode.SOLO:
		for r in runners:
			r.set_physics_process(false)
	if Balance.USE_3D:
		add_child(load("res://src/render/three/world_view.gd").new())

func _read_command_line() -> void:
	# The start screen first: on a phone there is no command line, and needing
	# one to reach a mode is the same as not shipping it.
	if VersusLaunch.chosen():
		match VersusLaunch.how:
			VersusLaunch.How.HOST:
				mode = Mode.HOST
			VersusLaunch.How.JOIN:
				mode = Mode.CLIENT
			_:
				mode = Mode.SOLO
		room_code = VersusLaunch.code
		_seat = clampi(VersusLaunch.seat, 0, 3)
		room_mode = VersusLaunch.room_mode
		if not VersusLaunch.relay.is_empty():
			_relay = VersusLaunch.relay
	else:
		for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
			if arg == "--versus-host":
				mode = Mode.HOST
				_seat = VersusRoster.SEAT_A_RUNNER
			elif arg.begins_with("--versus-join="):
				mode = Mode.CLIENT
				room_code = arg.split("=", true, 1)[1].to_upper()
			elif arg.begins_with("--versus-seat="):
				_seat = clampi(int(arg.split("=", true, 1)[1]), 0, 3)
			elif arg == "--versus-duel":
				room_mode = VersusRoster.RoomMode.DUEL_COMBINED
			elif arg.begins_with("--versus-relay="):
				_relay = arg.split("=", true, 1)[1]
	if mode == Mode.HOST:
		_seat = VersusRoster.SEAT_A_RUNNER
	elif mode == Mode.CLIENT and room_mode == VersusRoster.RoomMode.DUEL_COMBINED:
		_seat = VersusRoster.SEAT_B_RUNNER
	local_team = VersusRoster.team_of(_seat) \
		if VersusRoster.role_of(_seat) == VersusRoster.Role.RUNNER else -1

var _relay: String = Balance.DEFAULT_RELAY

# ------------------------------------------------------------------- the world
## The collision world the COINS fall through. The runners use the real
## StaticBody2D that LevelBuilder made; coins are not characters and do not
## need one, so they sweep against the same rectangles directly.
## The collision world the COINS fall through, three laps wide.
##
## Three, not one: a runner standing on the join needs real floor on both sides
## of it, or the lap they are about to enter is a hole until the instant they
## wrap into it.
func _collision_rects() -> Array[Rect2]:
	return VersusStageData.collision_rects(_built)

## 1-1, built the way the cooperative game builds it. Terrain, decor, hazards,
## enemies, checkpoints and the goal all come from LevelBuilder, so the stage
## in this mode is the stage -- not a copy of it that can drift.
func _build_world() -> void:
	Stage.use(Stage.Which.GREENFIELD)
	level = preload("res://src/versus/versus_level_builder.gd").new()
	level.name = "Level"
	add_child(level)

## The laps either side of the one 1-1 was built in: the steps that close the
## circuit, and a copy of the terrain and the scenery to each side.
##
## Painted and collided, but NOT populated. The enemies, the spikes and the
## gimmicks stay in the middle lap. They would be a second set of the same
## creatures if they were repeated. The connector closes the shortened lap.
func _build_laps() -> void:
	var one: Array[Rect2] = VersusStageData.lap_ground()
	var scenery := VersusStageData.decor()
	var body := StaticBody2D.new()
	body.name = "Laps"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	for lap in [-1, 0, 1]:
		var shift := VersusStageData.LOOP_SPAN * float(lap)
		# The middle lap's own terrain is LevelBuilder's; only the steps are
		# added to it, so 1-1 is painted exactly once by the thing that paints
		# it everywhere else.
		var slabs: Array[Rect2] = one if lap != 0 \
			else VersusStageData.connector()
		var painted: Array[Rect2] = []
		for r in slabs:
			painted.append(Rect2(r.position + Vector2(shift, 0.0), r.size))
		var terrain := preload("res://src/render/terrain.gd").new()
		terrain.slabs = painted
		add_child(terrain)
		for r in painted:
			var shape := CollisionShape2D.new()
			var box := RectangleShape2D.new()
			box.size = r.size
			shape.shape = box
			shape.position = r.position + r.size * 0.5
			body.add_child(shape)
		if lap == 0:
			continue
		var decor := preload("res://src/render/decor.gd").new()
		var moved: Array[Dictionary] = []
		for d in scenery:
			var copy := d.duplicate()
			copy["pos"] = Vector2(d["pos"]) + Vector2(shift, 0.0)
			moved.append(copy)
		decor.items = moved
		add_child(decor)

## The enemies this mode adds on top of 1-1's own.
##
## Built through LevelBuilder's own _make_enemy, so they are the same classes
## configured the same way -- there is no second kind of walker here. They go
## into the same Dynamic node, so a rebuild frees them with everything else.
##
## Middle lap only, which IS the whole circuit: a runner is always wrapped back
## into it, and the laps either side exist to make the join look continuous
## rather than to be played in.
func _build_extra_enemies() -> void:
	var extra := VersusStageData.extra_enemies()
	if extra.is_empty():
		return
	var into: Node = level.get_node_or_null("Dynamic")
	if into == null:
		into = level
	# Past 1-1's own, so the two sets cannot collide on an id. Nothing in this
	# mode sends enemies over the wire -- every machine builds the same list
	# from the same data -- but an id that means two things is a trap for
	# whoever adds that later.
	var id := Stage.enemies().size()
	for spec in extra:
		var node := level._make_enemy(spec)
		if node == null:
			continue
		node.global_position = spec["pos"]
		node.net_id = id
		into.add_child(node)
		id += 1

## 1-1's goal is a place to arrive at. On a circuit you arrive at it every lap,
## and it would announce the stage cleared every time round.
func _remove_the_goal() -> void:
	for node in level.find_children("*", "", true, false):
		if node.name.to_lower().contains("goal"):
			node.queue_free()

## LevelBuilder wants the runner and the hub before it builds, because an
## asymmetric stage decides what to paint from who is watching. 1-1 hides
## nothing, but it is given the local player's hub anyway rather than null --
## the same call the cooperative game makes.
func _finish_world() -> void:
	level.runner = runners[maxi(local_team, 0)]
	level.input_hub = input.hubs[0]
	level.build()
	_remove_the_goal()
	_build_extra_enemies()
	_build_laps()

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.position_smoothing_enabled = false   # smoothed by hand, below
	_camera.zoom = Vector2.ONE * Balance.CAMERA_ZOOM
	_camera.global_position = runners[maxi(local_team, 0)].global_position
	add_child(_camera)
	_camera.make_current()

	var sky := preload("res://src/render/sky.gd").new()
	sky.name = "Sky"
	sky.camera = _camera
	add_child(sky)

## Follows YOUR runner, with the same lead and the same smoothing the
## cooperative camera uses -- a guardian is reading the road ahead of their own
## runner here exactly as they do there. A guardian's view follows the runner
## on their own team.
func _update_camera(delta: float) -> void:
	var who := runners[maxi(_view_team(), 0)]
	if who == null or not is_instance_valid(who):
		return
	var lead := clampf(who.velocity.x / Balance.RUNNER_RUN_SPEED, -1.0, 1.0) \
		* Balance.CAMERA_LOOKAHEAD
	var target := who.global_position + Vector2(lead, -40.0)
	var t := clampf(delta * Balance.CAMERA_SMOOTH, 0.0, 1.0)
	_camera.global_position = _camera.global_position.lerp(target, t)

func _view_team() -> int:
	if local_team >= 0:
		return local_team
	# A guardian watches their own team's runner.
	return VersusRoster.team_of(_seat)

func _process(delta: float) -> void:
	if _camera != null:
		_update_camera(delta)
	if _debug_copy_button != null:
		_debug_copy_button.visible = waiting()
		var viewport_size := get_viewport_rect().size
		_debug_copy_button.position = Vector2(viewport_size.x * 0.5 - 100.0,
			viewport_size.y * 0.5 + 214.0)

## The guardians' constructs are ordinary ground for both teams. Rebuilt as one
## body whenever the list changes rather than added one at a time, so the shape
## of the world is always exactly the list.
func _refresh_ground() -> void:
	if _built_body == null:
		_built_body = StaticBody2D.new()
		_built_body.name = "Built"
		_built_body.collision_layer = 1
		_built_body.collision_mask = 0
		add_child(_built_body)
	for child in _built_body.get_children():
		child.queue_free()
	for rect in _built:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.position + rect.size * 0.5
		_built_body.add_child(shape)

func _build_runners() -> void:
	runners.clear()
	var starts := VersusStageData.start_positions()
	var facings := VersusStageData.start_facing()
	for i in range(2):
		var r := Runner.new()
		r.name = "Runner%d" % i
		r.global_position = starts[i]
		r.facing = facings[i]
		# Only the runner this machine drives has a hub and its own physics.
		# The other is a puppet: its position arrives from the network, and
		# simulating it here would be two machines disagreeing about one body.
		if mode == Mode.SOLO or i == local_team:
			r.input_hub = input.hubs[i if mode == Mode.SOLO else 0]
		add_child(r)
		# Team A is Lira exactly as she is. Only the second runner is
		# recoloured -- the request was the characters already in the game, and
		# tinting both would have made neither of them the one people know.
		# Which team you are is told by the ring at your feet, not by a wash
		# over the art.
		if r.visual != null and i == 1:
			r.visual.modulate = Color(0.46, 0.78, 1.35)
		runners.append(r)
	_apply_puppets()

func _apply_puppets() -> void:
	for i in range(2):
		var mine := mode == Mode.SOLO or i == local_team
		runners[i].set_physics_process(mine)

## The guardian's own node, with all four tools, aiming with the mouse. Its
## presses go to the host through the router rather than changing the world
## here -- the seam Guardian already has for exactly this.
func _build_guardian() -> void:
	var hub: InputHub = input.hubs[0]
	hub.scripted = false
	hub.solo_role = "guardian"
	guardian = Guardian.new()
	guardian.name = "Guardian"
	guardian.runner = runners[VersusRoster.team_of(_seat)]
	guardian.input_hub = hub
	guardian.world_root = self
	if client != null:
		var router := preload("res://src/versus/versus_command_router.gd").new()
		router.client = client
		add_child(router)
		guardian.command_router = router
	add_child(guardian)

# ----------------------- on-device diagnostic log (also in user://)
func _start_debug_log() -> void:
	_debug_lines.clear()
	_debug_file = FileAccess.open("user://versus-debug.log", FileAccess.WRITE)
	_debug("build=versus diag-v1 role=%s room=%s mode=%d protocol=%d" % [
		"HOST" if mode == Mode.HOST else ("JOIN" if mode == Mode.CLIENT else "SOLO"),
		room_code, room_mode, VersusProtocol.VERSION])
	_debug("relay=%s (WebSocket uses /room4/<code>)" % _relay.strip_edges().rstrip("/"))
	if _debug_file == null:
		_debug("user://versus-debug.log could not be opened: %d" % FileAccess.get_open_error())

func _debug(message: String) -> void:
	if not OS.has_feature("editor"):
		return
	var line := "%s %s" % [Time.get_time_string_from_system(), message]
	print("[versus] " + line)
	_debug_lines.append(line)
	if _debug_lines.size() > 9:
		_debug_lines.pop_front()
	if _debug_file != null:
		_debug_file.store_line(line)
		_debug_file.flush()

func debug_lines() -> Array[String]:
	return _debug_lines.duplicate()

func _copy_debug_log() -> void:
	var content := FileAccess.get_file_as_string("user://versus-debug.log")
	if content.is_empty():
		content = "\n".join(_debug_lines)
	DisplayServer.clipboard_set(content)
	_debug("log copied to clipboard")

## A GET without Upgrade MUST return 426 on our deployed /room4 handler.
## 404 instead means the worker serving this URL does not have /room4.
## WebSocketPeer itself does not expose HTTP handshake response status.
func _probe_relay_route() -> void:
	if not OS.has_feature("editor"):
		return
	var base := _relay.strip_edges().rstrip("/")
	if base.begins_with("wss://"):
		base = "https://" + base.substr(6)
	elif base.begins_with("ws://"):
		base = "http://" + base.substr(5)
	elif not base.begins_with("https://") and not base.begins_with("http://"):
		base = "https://" + base
	_relay_probe = HTTPRequest.new()
	_relay_probe.name = "VersusRelayProbe"
	_relay_probe.timeout = 10.0
	add_child(_relay_probe)
	_relay_probe.request_completed.connect(_on_relay_probe_complete)
	var url := "%s/room4/%s" % [base, room_code]
	_debug("PROBE GET " + url + " (expected HTTP 426; no websocket upgrade)")
	var err := _relay_probe.request(url)
	if err != OK:
		_relay_probe_detail = TranslationServer.translate("接続先のHTTP検査を開始できません (%d)") % err
		_debug("PROBE request error=%d" % err)

func _on_relay_probe_complete(result: int, http_status: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	_debug("PROBE result=%d HTTP=%d body=%s" % [result, http_status,
		body.get_string_from_utf8().substr(0, 120).replace("\n", " ")])
	if result != HTTPRequest.RESULT_SUCCESS:
		_relay_probe_detail = TranslationServer.translate("中継HTTP接続失敗 result=%d (DNS/通信を確認)") % result
	elif http_status == 426:
		_relay_probe_detail = ""
		_debug("PROBE /room4 exists on deployed relay")
	elif http_status == 404:
		_relay_probe_detail = "中継に /room4 がありません (サーバーの更新が必要)"
	elif http_status == 429:
		_relay_probe_detail = "中継の接続回数制限 HTTP 429"
	else:
		_relay_probe_detail = TranslationServer.translate("中継の /room4 が HTTP %d を返しました") % http_status

## The value Runner actually reads, plus touch owner and the local actor.
## Emit on direction changes and at 3-second intervals so a stuck input can
## be diagnosed from the copyable log without recording every physics frame.
func _trace_local_input() -> void:
	if not OS.has_feature("editor"):
		return
	if mode == Mode.SOLO or local_team < 0 or input.hubs.is_empty():
		return
	var h: InputHub = input.hubs[0]
	var direction := int(signf(h.move_axis))
	_input_trace_ticks += 1
	if direction == _last_input_direction and _input_trace_ticks < 180:
		return
	_last_input_direction = direction
	_input_trace_ticks = 0
	_debug("INPUT team=%d axis=%.2f y=%.2f touch=%s fingers=%s left=%s scripted=%s physics=%s x=%.1f vx=%.1f" % [
		local_team, h.move_axis, h.move_axis_y, str(h._has_touch),
		str(h._touch_owner), str(h.runner_on_left), str(h.scripted),
		str(runners[local_team].is_physics_processing()),
		runners[local_team].global_position.x, runners[local_team].velocity.x])

func _record_match_state() -> void:
	var info := ""
	if host != null:
		info = "HOST authenticated=%d can_play=%s playing=%s" % [
			host.roster.peers_filled(), str(host.roster.can_play()), str(host.playing)]
	elif client != null:
		info = "JOIN connected=%s refused=%s seen_world=%s phase=%d seat=%d" % [
			str(client.connected), str(client.refused), str(client.seen_world),
			client.phase, client.seat]
	if not info.is_empty() and info != _last_match_state:
		_last_match_state = info
		_debug(info)

# --------------------------------------------------------------------- the link
func _open_link(as_host: bool) -> void:
	link = VersusWsTransport.new()
	link.diagnostic.connect(_debug)
	if as_host and room_code.is_empty():
		room_code = VersusWsTransport.new_code()
	_probe_relay_route()
	var err := link.open_room(_relay, room_code, "versus-%d" % (Time.get_ticks_usec() & 0xffff))
	if not err.is_empty():
		status = err
		_debug("open_room failed: " + err)
		return
	status = "room %s - waiting" % room_code

func _network_ready() -> void:
	if host != null or client != null:
		return
	if not link.is_open():
		return
	if mode == Mode.HOST:
		if link.local_peer() != VersusTransport.HOST_PEER:
			status = "room %s is already hosted elsewhere" % room_code
			_debug("HOST rejected: relay assigned index=%d (expected 0)" % link.local_peer())
			return
		host = VersusHost.new()
		host.diagnostic.connect(_debug)
		host.start(link, ArenaStage.new(_collision_rects()), 0, room_mode)
		match_rules = host.match_rules
		_debug("HOST ready: relay peer=%d roster=%s" % [
			link.local_peer(), host.roster.describe()])
		status = "room %s" % room_code
	else:
		client = VersusClient.new()
		client.diagnostic.connect(_debug)
		client.start(link, _seat, room_mode)
		if guardian != null:
			var router := preload("res://src/versus/versus_command_router.gd").new()
			router.client = client
			add_child(router)
			guardian.command_router = router
		_debug("JOIN ready: relay peer=%d" % link.local_peer())
		status = "room %s - joining" % room_code

# --------------------------------------------------------------------- the tick
func _physics_process(_delta: float) -> void:
	if link != null:
		link.poll_socket()
		_network_ready()

	if room_mode == VersusRoster.RoomMode.DUEL_COMBINED:
		_update_duel_activity()
	var seqs := input.poll()
	_trace_local_input()

	if phase() == VersusMatch.Phase.OVER and room_mode != VersusRoster.RoomMode.DUEL_COMBINED:
		if Input.is_physical_key_pressed(KEY_R) and mode != Mode.CLIENT:
			_start_solo() if mode == Mode.SOLO else _restart_host()
		_redraw()
		return

	match mode:
		Mode.SOLO:
			_tick_solo(seqs)
		Mode.HOST:
			_tick_host(seqs)
		Mode.CLIENT:
			_tick_client(seqs)
	if room_mode == VersusRoster.RoomMode.DUEL_COMBINED:
		_update_duel_activity()
	_record_match_state()
	_redraw()

func _update_duel_activity() -> void:
	if local_team < 0:
		return
	var active := not waiting() and phase() != VersusMatch.Phase.OVER
	if runners[local_team].is_physics_processing() != active:
		runners[local_team].set_physics_process(active)
	# Both Runner nodes exist before joining. Do not show a fake opponent.
	runners[1 - local_team].visible = active

## Bring a runner back into the middle lap when it walks off the end of one.
##
## The whole of "seamless". The world is periodic, so subtracting exactly one
## lap from a position puts the runner somewhere that looks identical -- same
## ground under the feet, same scenery either side. The camera is moved by the
## same amount in the same frame, or it would pan the full circuit's
## pixels back and the join would read as a catapult.
##
## Nothing else is touched: velocity, state, the jump in progress and the coins
## in hand all carry straight through, because as far as the runner is
## concerned it did not happen.
func _wrap_bodies() -> void:
	for i in range(2):
		var r := runners[i]
		var was := r.global_position.x
		var now := VersusStageData.wrap_x(was)
		if is_equal_approx(was, now):
			continue
		var shift := now - was
		r.global_position.x = now
		if i == _view_team() and _camera != null:
			_camera.global_position.x += shift

func _redraw() -> void:
	queue_redraw()
	hud.queue_redraw()

func _observe(i: int, seq: int) -> VersusMatch.Seat:
	var s := VersusMatch.Seat.new()
	s.team = i
	s.position = runners[i].global_position
	s.facing = runners[i].facing
	s.alive = runners[i].state != Runner.State.DEAD and _respawn_in[i] <= 0
	# Being untouchable does not stop you acting: Runner.respawn grants a
	# second of it, and folding that into can_act meant nobody could take a
	# coin for the first second of the match.
	s.can_act = s.alive and runners[i].state != Runner.State.HURT
	s.invulnerable = runners[i].is_invulnerable()
	s.strike_seq = seq
	return s

func _tick_solo(seqs: Array[int]) -> void:
	_wrap_bodies()
	_apply_respawns()
	_catch_deaths()
	match_rules.step([_observe(0, seqs[0]), _observe(1, seqs[1])])
	_apply_events(match_rules.events)

func _tick_host(seqs: Array[int]) -> void:
	if host == null:
		return
	if room_mode == VersusRoster.RoomMode.DUEL_COMBINED \
			and phase() == VersusMatch.Phase.OVER:
		host.step(_observe(0, seqs[0]))
		return
	if room_mode == VersusRoster.RoomMode.DUEL_COMBINED and not host.playing:
		host.step(_observe(0, seqs[0]))
		return
	_wrap_bodies()
	_apply_respawns()
	_catch_deaths()
	host.step(_observe(0, seqs[0]))
	_sync_builds(host.builds, host.world_revision)
	# The other runner is wherever its own machine says it is.
	_place_puppet(1, host.match_rules.seats[1].position,
		host.match_rules.seats[1].facing)
	_apply_events(host.out_events)

func _tick_client(seqs: Array[int]) -> void:
	if client == null:
		return
	if room_mode == VersusRoster.RoomMode.DUEL_COMBINED and waiting():
		# The guest cannot simulate movement before START, but the host needs
		# its spawn position and ALIVE state to start safely. A HELLO by itself
		# is insufficient. Report an idle, non-acting runner while waiting.
		var initial = null
		if client.connected and local_team >= 0:
			initial = _observe(local_team, 0)
			initial.can_act = false
			initial.strike_seq = 0
		client.step(initial, _seat)
		return
	if room_mode == VersusRoster.RoomMode.DUEL_COMBINED \
			and phase() == VersusMatch.Phase.OVER:
		client.step(null, _seat)
		return
	var mine = null
	if local_team >= 0:
		_wrap_bodies()
		_apply_respawns()
		_catch_deaths_local()
		mine = _observe(local_team, seqs[0])
	client.step(mine, _seat)
	_sync_builds_from_snapshot(client.builds, client.world_revision)
	# Everyone the host describes and this machine does not own.
	for i in range(2):
		if i == local_team:
			continue
		if client.runners.size() > i:
			var r: Dictionary = client.runners[i]
			_place_puppet(i, r["position"], int(r["facing"]))
	# Our runner owns its life/respawn simulation. The snapshot contains the
	# host's delayed ECHO of our observation, not a new death command. Applying
	# alive=false here killed the runner again immediately after every respawn.

## A body this machine does not simulate. Eased rather than snapped: snapshots
## arrive 30 times a second and the screen draws 60, so a hard set is visibly
## steppy. A big jump is snapped, because that is a respawn rather than a walk.
func _place_puppet(i: int, at: Vector2, facing: int) -> void:
	var r := runners[i]
	# In the lap nearest the camera. The position on the wire is wrapped into
	# one lap, and dropping it there unchanged would put the other runner a
	# whole circuit away whenever you were on the other side of the join.
	var here := VersusStageData.nearest_image(at, _camera.global_position) \
		if _camera != null else at
	if r.global_position.distance_to(here) > 240.0:
		r.global_position = here
	else:
		r.global_position = r.global_position.lerp(here, 0.35)
	r.facing = facing

func _sync_builds(from: Array, revision: int) -> void:
	if revision == _built_revision:
		return
	_built.clear()
	_build_owner.clear()
	for g in from:
		_built.append(g["rect"])
		_build_owner.append(int(g["seat"]))
	_built_revision = revision
	_refresh_ground()

func _sync_builds_from_snapshot(from: Array, revision: int) -> void:
	if revision == _built_revision:
		return
	_built.clear()
	_build_owner.clear()
	for g in from:
		_built.append(Rect2(g["position"], g["size"]))
		_build_owner.append(int(g["seat"]))
	_built_revision = revision
	_refresh_ground()

# ------------------------------------------------------------------- readouts
## One place the HUD asks, whichever side of the network this machine is on.
func coins() -> Array:
	if match_rules != null:
		var out: Array = []
		for c in match_rules.ledger.coins:
			out.append({"id": c.coin_id, "state": c.state, "owner": c.owner,
				"position": c.position, "world_since": c.world_since,
				"pickup_tick": c.pickup_tick})
		return out
	return client.coins if client != null else []

func score(team: int) -> int:
	if match_rules != null:
		return match_rules.score(team)
	return client.score(team) if client != null else 0

func phase() -> int:
	if match_rules != null:
		return match_rules.phase
	return client.phase if client != null else VersusMatch.Phase.PLAYING

func winner() -> int:
	if match_rules != null:
		return match_rules.winner
	return client.winner if client != null else -1

func world_tick() -> int:
	if match_rules != null:
		return match_rules.tick
	return client.world_tick if client != null else 0

func held_by(team: int) -> int:
	var n := 0
	for c in coins():
		if int(c["state"]) == ArenaCoin.State.HELD and int(c["owner"]) == team:
			n += 1
	return n

## What the map shows: both runners and every loose coin, each as a fraction
## around the lap.
##
## Data, not drawing. The HUD renders whatever this returns, which is what lets
## a headless probe check the map's CONTENTS -- that the other runner is on it,
## that the coins are -- without looking at a single pixel.
func map_marks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in coins():
		if int(c["state"]) != ArenaCoin.State.WORLD:
			continue
		out.append({"kind": "coin", "team": -1,
			"x01": VersusStageData.lap_fraction(Vector2(c["position"]).x)})
	for i in range(2):
		out.append({
			"kind": "you" if i == _view_team() else "them",
			"team": i,
			"x01": VersusStageData.lap_fraction(runners[i].global_position.x),
		})
	return out

## Show the authenticated peer count, not the two locally spawned avatars.
func waiting_detail() -> String:
	var code := room_code if not room_code.is_empty() else "------"
	if link != null and not link.last_error().is_empty():
		return TranslationServer.translate("room %s · 通信エラー: %s") % [code, link.last_error()]
	if not _relay_probe_detail.is_empty():
		return "room %s · %s" % [code, _relay_probe_detail]
	if mode == Mode.HOST:
		if host == null:
			return TranslationServer.translate("room %s · 中継に接続中（/room4を確認）") % code
		if room_mode == VersusRoster.RoomMode.DUEL_COMBINED and \
				host.roster.can_play() and not host._reported.has(VersusRoster.SEAT_B_RUNNER):
			return TranslationServer.translate("room %s · 2/2認証済み / 相手の初期位置を受信待ち") % code
		return TranslationServer.translate("room %s · 参加認証 %d/2") % [code, host.roster.peers_filled()]
	if mode == Mode.CLIENT:
		if client == null:
			return TranslationServer.translate("room %s · 中継に接続中（/room4を確認）") % code
		if client.refused:
			return client.refusal_reason if not client.refusal_reason.is_empty() \
				else "入室拒否：APK・対戦モード・部屋番号を確認"
		if not client.connected:
			return TranslationServer.translate("room %s · ホストからの入室認証待ち") % code
		if not client.seen_world:
			return TranslationServer.translate("room %s · 認証済み、状態の受信待ち") % code
		return TranslationServer.translate("room %s · 認証済み、ホストの開始待ち") % code
	return ""

func waiting() -> bool:
	if mode == Mode.SOLO:
		return false
	if mode == Mode.HOST:
		return host == null or not host.roster.can_play() or \
			(room_mode == VersusRoster.RoomMode.DUEL_COMBINED and not host.playing)
	return client == null or not client.connected or not client.seen_world or \
		(room_mode == VersusRoster.RoomMode.DUEL_COMBINED and client.phase == 2)

# ---------------------------------------------------------------- lives, deaths
func _start_solo() -> void:
	match_rules.setup(ArenaStage.new(_collision_rects()),
		int(Time.get_ticks_usec() & 0x7fffffff))
	_reset_bodies()

func _restart_host() -> void:
	host.start(link, ArenaStage.new(_collision_rects()), 0, room_mode)
	match_rules = host.match_rules
	_built.clear()
	_build_owner.clear()
	_built_revision = -1
	_refresh_ground()
	_reset_bodies()

func _reset_bodies() -> void:
	var starts := VersusStageData.start_positions()
	var facings := VersusStageData.start_facing()
	for i in range(2):
		runners[i].respawn(starts[i])
		runners[i].facing = facings[i]
		_respawn_in[i] = 0

func _apply_events(events: Array) -> void:
	for e in events:
		match String(e.get("kind", "")):
			"hurt":
				var side: int = e["side"]
				if not _owns(side):
					continue
				runners[side].facing = -int(e["dir"])
				runners[side].take_damage(1)
				if runners[side].state == Runner.State.DEAD:
					_begin_respawn(side)
			"fell":
				if _owns(e["side"]):
					runners[e["side"]].die("fell")
					_begin_respawn(e["side"])

func _owns(side: int) -> bool:
	return mode == Mode.SOLO or side == local_team

## Every way a runner can stop being in the match, in one place. Written as "is
## it dead" rather than as a list of causes: the first version handled only the
## two this file creates and missed 1-1's spike strip, which the runner detects
## and dies to entirely on its own.
func _catch_deaths() -> void:
	for i in range(2):
		if not _owns(i):
			continue
		_catch_death(i)

func _catch_deaths_local() -> void:
	if local_team >= 0:
		_catch_death(local_team)

func _catch_death(i: int) -> void:
	if _respawn_in[i] > 0:
		return
	if runners[i].state == Runner.State.DEAD:
		_begin_respawn(i)
	elif runners[i].global_position.y > VersusStageData.kill_y():
		runners[i].die("pit")
		_begin_respawn(i)

func _begin_respawn(side: int) -> void:
	if _respawn_in[side] > 0:
		return
	_died_at[side] = runners[side].global_position
	if match_rules != null:
		match_rules.note_death(side)
	_respawn_in[side] = VersusRules.RESPAWN_TICKS

func _apply_respawns() -> void:
	for i in range(2):
		if _respawn_in[i] <= 0:
			continue
		_respawn_in[i] -= 1
		if _respawn_in[i] > 0:
			continue
		# The checkpoint behind where they died, which is 1-1's own answer.
		# Sending someone back to the start of a sixteen-thousand-pixel stage
		# for one mistake is a forfeit, not a rule.
		runners[i].respawn(VersusStageData.respawn_for(i, _died_at[i]))
		runners[i].facing = VersusStageData.start_facing()[i]

## In combined mode the same peer owns its team's Runner and Guardian seats.
## The host's own commands take the identical place_build / undo_build path.
func request_construct(slot: int, at: Vector2) -> void:
	if room_mode != VersusRoster.RoomMode.DUEL_COMBINED or waiting() \
			or phase() == VersusMatch.Phase.OVER:
		return
	if slot not in [1, 2]:
		return
	if mode == Mode.HOST and host != null:
		host.place_build(VersusRoster.SEAT_A_GUARDIAN, at, slot)
	elif mode == Mode.CLIENT and client != null:
		client.request_build(at, slot)

func request_construct_undo() -> void:
	if room_mode != VersusRoster.RoomMode.DUEL_COMBINED or waiting():
		return
	if mode == Mode.HOST and host != null:
		host.undo_build(VersusRoster.SEAT_A_GUARDIAN)
	elif mode == Mode.CLIENT and client != null:
		client.request_undo()

func leave_versus() -> void:
	if link != null:
		link.close()
	VersusLaunch.clear()
	get_tree().change_scene_to_file("res://src/main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit(0)

# ---------------------------------------------------------------------- paint
func _draw() -> void:
	_builds()
	_markers()
	_coins()
	_heads()
	_strikes()

## How many each runner is carrying, over their head. Pips, not a number: what
## you need at a glance is "more than them". World space, which is why it lives
## here and not in the HUD.
func _heads() -> void:
	for i in range(2):
		var held := held_by(i)
		if held <= 0:
			continue
		var centre: Vector2 = runners[i].global_position
		var y := centre.y - Balance.RUNNER_SIZE.y * 0.5 - 18.0
		var pitch := 12.0
		var x0 := centre.x - pitch * float(held - 1) * 0.5
		for k in range(held):
			var at := Vector2(x0 + pitch * float(k), y)
			draw_circle(at, 4.5, COL_COIN)
			draw_arc(at, 4.5, 0.0, TAU, 10, Color(0.25, 0.18, 0.04, 0.9), 1.2)

func _builds() -> void:
	for i in range(_built.size()):
		var team := VersusRoster.team_of(_build_owner[i]) \
			if i < _build_owner.size() else 0
		# A dark outline under the bright one. Team A's colour is a sky blue and
		# 1-1's sky is behind half the arena, so a platform drawn in it alone
		# disappeared into the background -- something you found by walking into
		# it rather than by looking.
		draw_rect(_built[i].grow(2.0), Color(0.06, 0.07, 0.10, 0.85), false, 5.0)
		draw_rect(_built[i], build_fill(team))
		draw_rect(_built[i], build_edge(team), false, 3.0)
		# A highlight along the top, so which side of it you can stand on is
		# obvious from across the arena.
		draw_line(_built[i].position + Vector2(0.0, 1.5),
			_built[i].position + Vector2(_built[i].size.x, 1.5),
			Color(1, 1, 1, 0.75), 3.0)

func _markers() -> void:
	for i in range(2):
		if _respawn_in[i] > 0:
			continue
		var at: Vector2 = runners[i].global_position \
			+ Vector2(0.0, Balance.RUNNER_SIZE.y * 0.5)
		draw_arc(at, 17.0, 0.0, TAU, 20, build_edge(i), 3.0)

func _coins() -> void:
	for c in coins():
		if int(c["state"]) != ArenaCoin.State.WORLD:
			continue
		var at: Vector2 = c["position"]
		var fill := COL_COIN
		if c.has("world_since"):
			var left := VersusRules.STALE_TICKS - (world_tick() - int(c["world_since"]))
			if left <= 90:
				fill.a = 0.35 + 0.65 * absf(sin(float(left) * 0.25))
		if not Balance.USE_3D:
			draw_circle(at, 11.0, fill)
			draw_arc(at, 11.0, 0.0, TAU, 16, COL_COIN_EDGE, 2.0)
		if c.has("pickup_tick") and world_tick() < int(c["pickup_tick"]):
			draw_arc(at, 15.0, 0.0, TAU, 16, Color(1, 1, 1, 0.35), 1.0)

## The strike while it is live, and the wind-up before it. Both shown: the whole
## fight is about whether eight frames was enough warning.
func _strikes() -> void:
	if match_rules == null:
		for i in range(2):
			if client == null or client.runners.size() <= i:
				continue
			var r: Dictionary = client.runners[i]
			if int(r["combat_phase"]) == ArenaCombat.Phase.ACTIVE:
				_strike_box_at(r["position"], int(r["combat_dir"]))
		return
	for i in range(2):
		var c := match_rules.combat[i]
		var at: Vector2 = runners[i].global_position
		if c.phase == ArenaCombat.Phase.STARTUP:
			draw_arc(at + Vector2(float(c.attack_dir) * 22.0, 0.0), 7.0,
				0.0, TAU, 12, Color(1, 1, 1, 0.45), 2.0)
		elif c.phase == ArenaCombat.Phase.ACTIVE:
			_strike_box_at(at, c.attack_dir)

func _strike_box_at(at: Vector2, dir: int) -> void:
	var mid := Vector2(at.x + float(dir) * VersusRules.STRIKE_REACH, at.y)
	var box := Rect2(mid - VersusRules.STRIKE_SIZE * 0.5, VersusRules.STRIKE_SIZE)
	draw_rect(box, Color(1.0, 0.95, 0.70, 0.30))
	draw_rect(box, Color(1.0, 0.95, 0.70, 0.85), false, 2.0)
