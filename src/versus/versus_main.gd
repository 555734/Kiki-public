extends Node2D
## The 2v2 star match: two teams of a runner and a guardian, on a small arena
## built from 1-1's pieces. Uses the game's Runner, a local following camera,
## and a host-owned star ledger (VersusMatch; the ledger calls them coins).
## Seven stars held wins. Free for every player -- nothing here reads
## Entitlement (docs/versus-2v2-stars.md).

const RunnerVisualScript = preload("res://src/runner/runner_visual.gd")

enum Mode { SOLO, HOST, CLIENT }

const COL_COIN := Color(1.0, 0.82, 0.29)
const COL_COIN_EDGE := Color(0.62, 0.45, 0.10)
## A loose star's drawn radius. Big enough to read across a phone screen.
const STAR_RADIUS: float = 44.0
## A guardian's construct, in its own team's colour. Read off the shared team
## palette rather than restated, so a platform is unmistakably one side's.
## Drawn nearly solid: the first version was translucent and vanished against
## 1-1's bright grass, which made a platform something you found by walking
## into it.
func build_fill(team: int) -> Color:
	var c: Color = colour_of(team)
	return Color(c.r, c.g, c.b, 0.80)

func build_edge(team: int) -> Color:
	var c: Color = colour_of(team)
	return Color(minf(1.0, c.r + 0.35), minf(1.0, c.g + 0.35),
		minf(1.0, c.b + 0.35), 1.0)

var mode: int = Mode.SOLO
var match_rules: VersusMatch = null       ## host and solo only
var host: VersusHost = null
var client: VersusClient = null
var link: VersusTransport = null
## Over EOS (what ships) or the old WebSocket relay (editor, probes).
var use_eos: bool = false
var eos_room: EosVersusLobby = null
## Set once the EOS lobby has been told the match began.
var _marked_started: bool = false
## The client's rematch counter last acted on.
var _seen_epoch_changes: int = 0
var _menu: Control = null
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
## How many sides this match has: 2 for 2v2 and 1v1, 8 chairs in a
## free-for-all (a solo test on one machine is always 2).
var sides: int = 2
var _respawn_in: Array[int] = []
## Where each runner was when it died, so it comes back at the checkpoint
## behind THAT rather than behind wherever its corpse drifted to.
var _died_at: Array[Vector2] = []
var _seat: int = VersusRoster.SEAT_A_RUNNER

func _ready() -> void:
	process_physics_priority = 100
	z_index = 5
	_read_command_line()
	sides = VersusRoster.sides_for(room_mode) if mode != Mode.SOLO else 2
	for i in range(sides):
		_respawn_in.append(0)
		_died_at.append(Vector2.ZERO)
	if OS.has_feature("editor"):
		_start_debug_log()
	_build_world()

	input = VersusInput.new()
	input.name = "VersusInput"
	add_child(input)
	# A one-device test on a phone is one player with touch controls against
	# a standing practice partner; on a desktop it stays two players on one
	# keyboard (WASD+F and the arrows).
	touch_solo = mode == Mode.SOLO and _wants_touch()
	input.make_hubs(self, mode == Mode.SOLO and not touch_solo)

	_build_runners()
	_finish_world()
	_overlay = Node2D.new()
	_overlay.name = "Overlay"
	_overlay.z_index = 20
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
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
	_build_menu(layer)
	_layer = layer
	_build_controls()

	match mode:
		Mode.SOLO:
			match_rules = VersusMatch.new()
			_start_solo()
		Mode.HOST:
			_open_link(true)
		Mode.CLIENT:
			_open_link(false)

	_build_shooter()
	if combined() and mode != Mode.SOLO:
		for r in runners:
			r.set_physics_process(false)
	_add_world_view()

var _layer: CanvasLayer = null
var _overlay: Node2D = null
## The solo test on a touch screen: P1 on touch, P2 stands still.
var touch_solo: bool = false

func _wants_touch() -> bool:
	return _touch_device()

static func _touch_device() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") \
		or DisplayServer.is_touchscreen_available()

## The on-screen buttons, where co-op 1-1 puts them. Made when this machine
## knows what it plays, which in a free-for-all is only once the host has
## seated it.
func _build_controls() -> void:
	if controls != null or _seat < 0:
		return
	if mode == Mode.SOLO and not touch_solo:
		return
	controls = preload("res://src/versus/versus_controls.gd").new()
	controls.arena = self
	controls.hub = input.hubs[0]
	_layer.add_child(controls)

## A free-for-all guest learns its chair from the WELCOME. From here on it
## drives that runner exactly as if it had asked for it.
func _take_seat(seat: int) -> void:
	_seat = seat
	_set_local_team()
	if local_team < 0 or local_team >= sides:
		return
	var r := runners[local_team]
	r.input_hub = input.hubs[0]
	r.global_position = VersusStageData.start_positions()[local_team]
	r.facing = VersusStageData.start_facing()[local_team]
	level.runner = r
	_camera.global_position = r.global_position
	_build_shooter()
	_build_controls()
	_debug("SEATED as P%d" % (seat + 1))

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
		use_eos = VersusLaunch.link == VersusLaunch.Link.EOS
		_theme = VersusLaunch.stage
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
				_seat = clampi(int(arg.split("=", true, 1)[1]), 0, 7)
			elif arg == "--versus-duel":
				room_mode = VersusRoster.RoomMode.DUEL_COMBINED
			elif arg == "--versus-ffa":
				room_mode = VersusRoster.RoomMode.FREE_FOR_ALL
			elif arg.begins_with("--versus-stage="):
				_theme = int(arg.split("=", true, 1)[1])
			elif arg.begins_with("--versus-relay="):
				_relay = arg.split("=", true, 1)[1]
	if mode == Mode.HOST:
		_seat = VersusRoster.SEAT_A_RUNNER
	elif mode == Mode.CLIENT and room_mode == VersusRoster.RoomMode.DUEL_COMBINED:
		_seat = VersusRoster.SEAT_B_RUNNER
	elif mode == Mode.CLIENT and room_mode == VersusRoster.RoomMode.FREE_FOR_ALL:
		# The host hands out chairs in a free-for-all; until it does, this
		# machine drives nobody. _on_seated fills it in from the WELCOME.
		_seat = -1
	_set_local_team()

func _set_local_team() -> void:
	if _seat < 0:
		local_team = -1
		return
	local_team = VersusRoster.side_of_in(room_mode, _seat) \
		if VersusRoster.is_runner_in(room_mode, _seat) else -1

## One person, one character: the runner and the builder are the same player
## (1v1 and the free-for-all), as opposed to the 2v2 split.
func combined() -> bool:
	return room_mode == VersusRoster.RoomMode.DUEL_COMBINED \
		or room_mode == VersusRoster.RoomMode.FREE_FOR_ALL

## A side's colour: a team's in 2v2/1v1, a person's in a free-for-all.
func colour_of(side: int) -> Color:
	return VersusRules.colour_of(room_mode, side)

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

## The arena, painted and collided by 1-1's own terrain and decor painters.
## See VersusLevelBuilder: nothing of 1-1's course -- no enemy, no hazard --
## is built, so there is nothing each machine would simulate on its own.
func _build_world() -> void:
	if VersusLaunch.previous_stage < 0:
		VersusLaunch.previous_stage = Stage.current()
	VersusStageData.use_theme(_theme)
	level = preload("res://src/versus/versus_level_builder.gd").new()
	level.name = "Level"
	add_child(level)

## Which stage's art this arena is painted in. A guest starts in the default
## and switches when the host's WELCOME says otherwise.
var _theme: int = Stage.Which.GREENFIELD
var _sky: Node = null
var _world_view: Node = null

## Repaint the arena as another stage. Only pictures change: every collision
## rectangle, star point and start is the same in every theme, so the runners,
## the match and the network carry on untouched.
func _apply_theme(which: int) -> void:
	if which == _theme and which == Stage.current():
		return
	_theme = which
	VersusStageData.use_theme(which)
	_debug("THEME stage=%d" % which)
	var old_level := level
	remove_child(old_level)
	old_level.queue_free()
	level = preload("res://src/versus/versus_level_builder.gd").new()
	level.name = "Level"
	add_child(level)
	move_child(level, 0)
	level.runner = runners[maxi(local_team, 0)]
	level.input_hub = input.hubs[0]
	level.build()
	if _sky != null:
		_sky.queue_free()
	_sky = preload("res://src/render/sky.gd").new()
	_sky.name = "Sky"
	_sky.camera = _camera
	add_child(_sky)
	if _world_view != null:
		_world_view.queue_free()
		_world_view = null
	_add_world_view()

## The 3D view, for the stages co-op draws in 3D (1-3) and only those: 1-1,
## 1-2, 1-4 and 1-5 are painted 2D stages, here exactly as in co-op.
func _add_world_view() -> void:
	if Balance.USE_3D and Stage.world_3d() and _world_view == null:
		_world_view = load("res://src/render/three/world_view.gd").new()
		add_child(_world_view)

func theme() -> int:
	return _theme

func _finish_world() -> void:
	level.runner = runners[maxi(local_team, 0)]
	level.input_hub = input.hubs[0]
	level.build()

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.position_smoothing_enabled = false   # smoothed by hand, below
	_camera.zoom = Vector2.ONE * VersusRules.CAMERA_ZOOM
	_camera.global_position = runners[maxi(local_team, 0)].global_position
	add_child(_camera)
	_camera.make_current()

	_sky = preload("res://src/render/sky.gd").new()
	_sky.name = "Sky"
	_sky.camera = _camera
	add_child(_sky)

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
	return VersusRoster.team_of(maxi(_seat, 0))

func _process(delta: float) -> void:
	if _camera != null:
		_update_camera(delta)
	for t in _tracers:
		t["ttl"] = float(t["ttl"]) - delta
	_tracers = _tracers.filter(func(t): return float(t["ttl"]) > 0.0)
	_refresh_menu()
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
	# One lap either side as well, so a platform on the join is solid from
	# whichever side it is reached.
	for rect in _built_laps():
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.position + rect.size * 0.5
		_built_body.add_child(shape)

func _built_laps() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for lap in VersusStageData.LAPS:
		for r in _built:
			out.append(Rect2(r.position + Vector2(VersusStageData.WIDTH * float(lap), 0.0), r.size))
	return out

## Where to draw something canonical (in lap 0): the copy nearest the camera.
func _near(at: Vector2) -> Vector2:
	return VersusStageData.nearest_image(at, _camera.global_position) \
		if _camera != null else at

## Bring this machine's own runners back into the middle lap when they run
## off one end. The world is periodic, so moving a runner by exactly one lap
## puts it somewhere identical; the camera moves by the same amount in the
## same frame, so nothing on screen jumps. Velocity, the jump in progress and
## the stars in hand all carry straight through.
func _wrap_bodies() -> void:
	for i in range(sides):
		if not _owns(i):
			continue
		var r := runners[i]
		var was := r.global_position.x
		var now := VersusStageData.wrap_x(was)
		if is_equal_approx(was, now):
			continue
		r.global_position.x = now
		if i == _view_team() and _camera != null:
			_camera.global_position.x += now - was

func _build_runners() -> void:
	runners.clear()
	var starts := VersusStageData.start_positions()
	var facings := VersusStageData.start_facing()
	for i in range(sides):
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
		if r.visual != null and i == 1 and room_mode != VersusRoster.RoomMode.FREE_FOR_ALL:
			r.visual.modulate = Color(0.46, 0.78, 1.35)
		elif r.visual != null and i > 0:
			# Eight people need eight looks: player 1 is Lira as she is, the
			# rest are washed towards their own colour.
			r.visual.modulate = Color.WHITE.lerp(colour_of(i), 0.6) * Color(1.25, 1.25, 1.25)
		runners.append(r)
	_apply_puppets()

func _apply_puppets() -> void:
	for i in range(sides):
		var mine := mode == Mode.SOLO or i == local_team
		runners[i].set_physics_process(mine)

## Every player's way to attack from a distance: the co-op rifle, through the
## co-op Guardian node, exactly as one-device 1-1 has it -- the right of the
## screen is where you tap, the shot button is on the right. The rifle is the
## only tool (no building in versus), and every shot goes to the router, so
## the host decides what it hit. A 2v2 guardian seat is the rifle alone; every
## other seat is the runner and the rifle on one screen ("shared" layout).
func _build_shooter() -> void:
	if guardian != null or _seat < 0:
		return
	if mode == Mode.SOLO and not touch_solo:
		return
	var hub: InputHub = input.hubs[0]
	var guardian_seat := room_mode == VersusRoster.RoomMode.TEAM_SPLIT \
		and VersusRoster.role_of(_seat) == VersusRoster.Role.GUARDIAN \
		and mode != Mode.SOLO
	hub.scripted = false
	hub.solo_role = "guardian" if guardian_seat else ""
	guardian = Guardian.new()
	guardian.name = "Guardian"
	guardian.runner = runners[clampi(VersusRoster.side_of_in(room_mode, _seat), 0, sides - 1)] \
		if not guardian_seat else runners[VersusRoster.team_of(_seat)]
	guardian.input_hub = hub
	guardian.world_root = self
	var router := preload("res://src/versus/versus_command_router.gd").new()
	router.arena = self
	add_child(router)
	guardian.command_router = router
	add_child(guardian)
	# The rifle and nothing else, already chosen: a tap on the world shoots.
	var rifle = guardian.abilities[3]
	guardian.abilities = {3: rifle}
	guardian.active_slot = 3

## The shot, from this machine's player. The host and the one-device test
## judge it here; a guest sends it. The tracer is drawn at once either way.
var _tracers: Array[Dictionary] = []

func request_shot(at: Vector2) -> void:
	if waiting() or countdown_ticks() > 0 or phase() != VersusMatch.Phase.PLAYING:
		return
	var from_side := 0 if mode == Mode.SOLO else _view_team()
	_tracers.append({"from": runners[from_side].global_position, "to": at, "ttl": 0.18})
	match mode:
		Mode.SOLO:
			match_rules.shoot(0, at)
		Mode.HOST:
			if host != null:
				host.shoot(_seat, at)
		Mode.CLIENT:
			if client != null:
				client.request_shot(at)

# ------------------------------------------------------------------ the menu
## Real buttons for what the keyboard did before: start, play again, leave.
## A phone has no R and no Esc, and a mode you cannot start or leave from the
## screen is not a mode a phone can play.
var _start_button: Button = null
var _again_button: Button = null
var _leave_button: Button = null

func _build_menu(layer: CanvasLayer) -> void:
	_menu = VBoxContainer.new()
	_menu.name = "VersusMenu"
	_menu.add_theme_constant_override("separation", 10)
	_menu.custom_minimum_size = Vector2(300, 0)
	layer.add_child(_menu)
	_start_button = _menu_button("スタート", start_match)
	_again_button = _menu_button("もういちど", rematch)
	_leave_button = _menu_button("やめる", leave_versus)
	_refresh_menu()

func _menu_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(handler)
	_menu.add_child(b)
	return b

func _refresh_menu() -> void:
	if _menu == null:
		return
	var over := phase() == VersusMatch.Phase.OVER
	var pre := waiting()
	_start_button.visible = pre and is_host()
	_start_button.disabled = not can_start()
	_again_button.visible = over and (mode == Mode.HOST or mode == Mode.SOLO)
	# Runners have their own 戻る circle during play; a guardian has none.
	var broken := not link_error().is_empty()
	# Always there: the old 戻る circle went with the attack and build buttons.
	_leave_button.visible = true
	var view := get_viewport_rect().size
	var shown := 0
	for b in [_start_button, _again_button, _leave_button]:
		if b.visible:
			shown += 1
	_menu.size = Vector2(300, shown * 66)
	if pre or over or broken:
		_menu.custom_minimum_size = Vector2(300, 0)
		_leave_button.custom_minimum_size = Vector2(300, 56)
		_menu.position = Vector2(view.x * 0.5 - 150.0, view.y * 0.5 + 90.0)
	else:
		# Top left during play, clear of the stick and of the scoreboard.
		_menu.custom_minimum_size = Vector2(130, 0)
		_leave_button.custom_minimum_size = Vector2(130, 44)
		_menu.size = Vector2(130, 44)
		_menu.position = Vector2(16.0, 12.0)
	_menu.visible = shown > 0

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
	if use_eos:
		_open_eos(as_host)
		return
	var ws := VersusWsTransport.new()
	ws.diagnostic.connect(_debug)
	link = ws
	if as_host and room_code.is_empty():
		room_code = VersusWsTransport.new_code()
	_probe_relay_route()
	var err := ws.open_room(_relay, room_code, "versus-%d" % (Time.get_ticks_usec() & 0xffff))
	if not err.is_empty():
		status = err
		_debug("open_room failed: " + err)
		return
	status = "room %s - waiting" % room_code

## EOS sign-in, then the four-person lobby, then P2P -- the same path co-op
## rooms take, in a bucket of their own. Asynchronous: the arena is already up
## and says what it is doing while this runs.
var _link_error: String = ""

func _open_eos(as_host: bool) -> void:
	var room := EosVersusLobby.new(room_mode)
	eos_room = room
	if as_host:
		room.room_code = room_code if EosVersusLobby.valid_code(room_code) \
			else EosVersusLobby.new_code()
		room_code = room.room_code
		room.room_code_chosen.connect(func(code: String) -> void:
			if room == eos_room:
				room_code = code)
	status = "EOSに接続中"
	_debug("EOS versus %s room=%s" % ["host" if as_host else "join", room_code])
	if not await EosRuntime.ensure_ready():
		_link_failed(room, EosRuntime.last_error)
		return
	if room != eos_room:
		room.leave()
		return
	var ok := false
	if as_host:
		ok = await room.create_room()
	else:
		ok = await room.join_room(room_code)
	if room != eos_room:
		room.leave()
		return
	if not ok:
		_link_failed(room, room.last_error)
		return
	var t := VersusEosTransport.new()
	t.diagnostic.connect(_debug)
	var err := t.open(room)
	if not err.is_empty():
		_link_failed(room, err)
		return
	link = t
	status = "room %s" % room_code

func _link_failed(room: EosVersusLobby, reason: String) -> void:
	if room != eos_room:
		return
	_link_error = reason
	status = reason
	_debug("EOS failed: " + reason)

func _network_ready() -> void:
	if host != null or client != null:
		return
	if link == null or not link.is_open():
		return
	if mode == Mode.HOST:
		if link.local_peer() != VersusTransport.HOST_PEER:
			status = "room %s is already hosted elsewhere" % room_code
			_debug("HOST rejected: relay assigned index=%d (expected 0)" % link.local_peer())
			return
		host = VersusHost.new()
		host.diagnostic.connect(_debug)
		host.start(link, ArenaStage.new(_collision_rects()), 0, room_mode)
		host.stage = _theme
		match_rules = host.match_rules
		_debug("HOST ready: peer=%d roster=%s" % [
			link.local_peer(), host.roster.describe()])
		status = "room %s" % room_code
	else:
		client = VersusClient.new()
		client.diagnostic.connect(_debug)
		client.start(link, _seat, room_mode)
		_debug("JOIN ready: peer=%d" % link.local_peer())
		status = "room %s" % room_code

# --------------------------------------------------------------------- the tick
func _physics_process(_delta: float) -> void:
	if link != null:
		link.poll_socket()
		_network_ready()

	var seqs := input.poll()
	_trace_local_input()

	if phase() == VersusMatch.Phase.OVER and mode != Mode.CLIENT \
			and Input.is_physical_key_pressed(KEY_R):
		rematch()

	match mode:
		Mode.SOLO:
			_tick_solo(seqs)
		Mode.HOST:
			_tick_host(seqs)
		Mode.CLIENT:
			_tick_client(seqs)
	_update_activity()
	_mark_started()
	_record_match_state()
	_redraw()

## Runners move only while the match is on: not while the room is filling, not
## through "3, 2, 1", not after someone has won. The other team's runners are
## hidden until the room has them, rather than standing at their starts
## looking like players.
func _update_activity() -> void:
	if mode == Mode.SOLO:
		return
	var active := can_move()
	if local_team >= 0 and runners[local_team].is_physics_processing() != active:
		runners[local_team].set_physics_process(active)
	for i in range(sides):
		if i != local_team:
			runners[i].visible = not waiting() \
				and _seat_taken(VersusRoster.runner_seat_in(room_mode, i))

func can_move() -> bool:
	if mode == Mode.SOLO:
		return phase() != VersusMatch.Phase.OVER
	return not waiting() and countdown_ticks() == 0 \
		and phase() == VersusMatch.Phase.PLAYING

## The lobby stops advertising the room once the countdown starts.
func _mark_started() -> void:
	if _marked_started or eos_room == null or host == null:
		return
	if host.playing or host.counting():
		_marked_started = true
		eos_room.mark_started()

func _redraw() -> void:
	if _overlay != null:
		_overlay.queue_redraw()
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
	s.velocity = runners[i].velocity
	return s

## Before and after play: where the runner stands, alive, and not acting.
func _idle(i: int, seq: int) -> VersusMatch.Seat:
	var s := _observe(i, seq)
	s.alive = true
	s.can_act = false
	return s

## A stomp feels like a stomp only if the bounce is immediate, so the
## stomper's own machine bounces as soon as its feet meet a head; the host
## judges the hit from the same observation and takes the star.
func _stomp_bounce(i: int) -> void:
	var me := runners[i]
	if not me.is_physics_processing() or _respawn_in[i] > 0:
		return
	for j in range(sides):
		if j == i or not runners[j].visible or _respawn_in[j] > 0:
			continue
		if VersusMatch.is_stomp(me.global_position, me.velocity, runners[j].global_position):
			me.velocity.y = VersusRules.STOMP_BOUNCE
			return

func _tick_solo(seqs: Array[int]) -> void:
	_wrap_bodies()
	if phase() == VersusMatch.Phase.OVER:
		return
	_apply_respawns()
	_catch_deaths()
	# The touch test's partner never swings: one strike count drives both
	# hubs' sequences on a phone, and it must not be P2's.
	match_rules.step([_observe(0, seqs[0]), _observe(1, 0 if touch_solo else seqs[1])])
	_apply_events(match_rules.events)
	for i in range(sides):
		_stomp_bounce(i)

func _tick_host(seqs: Array[int]) -> void:
	if host == null:
		return
	# The host keeps stepping in every phase: it is also the post office, and
	# a host that stopped at the result screen stopped answering everyone.
	var live := host.playing and phase() == VersusMatch.Phase.PLAYING
	_wrap_bodies()
	if live:
		_apply_respawns()
		_catch_deaths()
	host.step(_observe(0, seqs[0]) if live else _idle(0, seqs[0]))
	if live:
		_stomp_bounce(0)
	match_rules = host.match_rules
	_sync_builds(host.builds, host.world_revision)
	# Everyone else is wherever their own machine says they are.
	for i in range(1, sides):
		var other := host.reported_runner(i)
		_place_puppet(i, other.position, other.facing)
	_apply_events(host.out_events)

func _tick_client(seqs: Array[int]) -> void:
	if client == null:
		return
	if client.connected and client.stage >= 0 and client.stage != _theme:
		_apply_theme(client.stage)
	if _seat < 0 and client.connected and client.seat >= 0:
		_take_seat(client.seat)
	if client.epoch_changes != _seen_epoch_changes:
		# A rematch: the host has started over, so this machine's own runner
		# goes back to its start too, and whatever was built is gone.
		_seen_epoch_changes = client.epoch_changes
		_reset_bodies()
		_built_revision = -1
	var mine = null
	if local_team >= 0:
		_wrap_bodies()
		if can_move():
			_apply_respawns()
			_catch_deaths_local()
			mine = _observe(local_team, seqs[0])
		elif client.connected:
			# The host needs this runner's start and ALIVE state before the
			# match can begin; a HELLO alone says nothing about the body.
			mine = _idle(local_team, seqs[0])
	client.step(mine, _seat)
	if local_team >= 0 and can_move():
		_stomp_bounce(local_team)
	_sync_builds_from_snapshot(client.builds, client.world_revision)
	# Everyone the host describes and this machine does not own.
	for i in range(sides):
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
	var here := _near(at)
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

## What the map shows: all four players' runners and every loose star, each as
## a position across the whole arena (x01) and up it (y01, 0 = top).
##
## Data, not drawing. The HUD renders whatever this returns, which is what lets
## a headless probe check the map's CONTENTS -- that the other team is on it,
## that the stars are -- without looking at a single pixel.
func map_marks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in coins():
		if int(c["state"]) != ArenaCoin.State.WORLD:
			continue
		var at: Vector2 = c["position"]
		out.append({"kind": "star", "team": -1, "world": at,
			"x01": VersusStageData.lap_fraction(at.x),
			"y01": VersusStageData.height_fraction(at.y)})
	for i in range(sides):
		if not runners[i].visible:
			continue
		var at: Vector2 = runners[i].global_position
		out.append({
			"kind": "you" if i == _view_team() else "them",
			"team": i,
			"world": at,
			"held": held_by(i),
			"x01": VersusStageData.lap_fraction(at.x),
			"y01": VersusStageData.height_fraction(at.y),
		})
	return out

## The world rectangle currently on screen, for the HUD's edge arrows.
func view_rect() -> Rect2:
	if _camera == null:
		return Rect2()
	var size := get_viewport_rect().size / _camera.zoom
	return Rect2(_camera.get_screen_center_position() - size * 0.5, size)

## Everything on the map that is NOT on screen, with where on the screen's edge
## to point at it: the other team's runner, your own when a guardian has lost
## it, and loose stars. Also data, for the same reason as map_marks.
func offscreen_marks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var view := view_rect()
	if view.size == Vector2.ZERO:
		return out
	var inner := view.grow(-24.0)
	for mark in map_marks():
		var at: Vector2 = _near(mark["world"])
		if inner.has_point(at):
			continue
		var centre := view.get_center()
		var dir := (at - centre).normalized()
		out.append({"kind": mark["kind"], "team": mark["team"], "dir": dir,
			"distance": centre.distance_to(at)})
	return out

## Is seat N taken? The host knows its roster; a client knows the mask the
## host sends in every snapshot.
func _seat_taken(seat: int) -> bool:
	if mode == Mode.SOLO:
		return true
	return (seat_mask() & (1 << seat)) != 0

func seat_mask() -> int:
	if mode == Mode.SOLO:
		return 0x0F
	if host != null:
		return host.seat_mask()
	return client.seat_mask if client != null else 0

## Ticks of "3, 2, 1" left, or 0.
func countdown_ticks() -> int:
	if host != null:
		return host.countdown
	if client != null and client.phase == VersusProtocol.PHASE_COUNTDOWN:
		return client.countdown
	return 0

## The machine that decides: the host, or the one machine of a solo test.
func is_host() -> bool:
	return mode != Mode.CLIENT

## Show the room's state, not the two locally spawned avatars.
func waiting_detail() -> String:
	var code := room_code if not room_code.is_empty() else "------"
	if not _link_error.is_empty():
		return _link_error
	if link != null and not link.last_error().is_empty():
		return TranslationServer.translate("通信エラー: %s") % link.last_error()
	if not _relay_probe_detail.is_empty():
		return "room %s · %s" % [code, _relay_probe_detail]
	if link == null:
		return TranslationServer.translate("オンラインに接続中…")
	if mode == Mode.HOST:
		if host == null:
			return TranslationServer.translate("部屋を準備中…")
		if not host.roster.can_play():
			if room_mode == VersusRoster.RoomMode.FREE_FOR_ALL:
				return TranslationServer.translate("2人以上そろうと始められます（最大8人）")
			return TranslationServer.translate("両チームのランナーがそろうと始められます")
		return TranslationServer.translate("そろったら「スタート」を押してください")
	if mode == Mode.CLIENT:
		if client == null:
			return TranslationServer.translate("部屋に接続中…")
		if client.refused:
			return client.refusal_reason if not client.refusal_reason.is_empty() \
				else TranslationServer.translate("入室できませんでした")
		if not client.connected:
			return TranslationServer.translate("ホストの確認を待っています")
		if not client.seen_world:
			return TranslationServer.translate("認証済み、状態の受信待ち")
		return TranslationServer.translate("ホストのスタートを待っています")
	return ""

## Why the room stopped working, or "". Shown over play as well as over the
## waiting screen: a host who leaves mid-match ends it for everyone.
func link_error() -> String:
	if not _link_error.is_empty():
		return _link_error
	if link != null:
		return link.last_error()
	return ""

## One line per chair, for the waiting screen: who the room has and who it is
## still waiting for.
func seat_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for seat in range(VersusRoster.seats_for(room_mode)):
		out.append({"seat": seat, "team": VersusRoster.side_of_in(room_mode, seat),
			"runner": VersusRoster.is_runner_in(room_mode, seat),
			"taken": _seat_taken(seat), "you": seat == _seat})
	return out

func waiting() -> bool:
	if mode == Mode.SOLO:
		return false
	if mode == Mode.HOST:
		return host == null or (not host.playing and not host.counting())
	return client == null or not client.connected or not client.seen_world \
		or client.phase == VersusProtocol.PHASE_WAITING

## The host's start button: can it be pressed now?
func can_start() -> bool:
	return mode == Mode.HOST and host != null and not host.playing \
		and not host.counting() and host.roster.can_play()

func start_match() -> void:
	if can_start():
		host.request_start()

## After a result: same room, same seats, a fresh match. Host (and solo) only;
## everyone else follows the host's new epoch.
func rematch() -> void:
	if phase() != VersusMatch.Phase.OVER:
		return
	if mode == Mode.SOLO:
		_start_solo()
	elif mode == Mode.HOST and host != null:
		if not host.restart_match():
			return
		match_rules = host.match_rules
		_built.clear()
		_build_owner.clear()
		_built_revision = -1
		_refresh_ground()
		_reset_bodies()

# ---------------------------------------------------------------- lives, deaths
func _start_solo() -> void:
	_built.clear()
	_build_owner.clear()
	_refresh_ground()
	match_rules.setup(ArenaStage.new(_collision_rects()),
		int(Time.get_ticks_usec() & 0x7fffffff))
	_reset_bodies()

func _reset_bodies() -> void:
	var starts := VersusStageData.start_positions()
	var facings := VersusStageData.start_facing()
	for i in range(sides):
		runners[i].respawn(starts[i])
		runners[i].facing = facings[i]
		runners[i].velocity = Vector2.ZERO
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
			"bounce":
				# The host's verdict on a stomp. The stomper's own machine has
				# usually bounced already (_stomp_bounce); doing it again is
				# harmless, a fresh bounce from the same height.
				if _owns(e["side"]) and runners[e["side"]].velocity.y > 0.0:
					runners[e["side"]].velocity.y = VersusRules.STOMP_BOUNCE
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
	for i in range(sides):
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
	for i in range(sides):
		if _respawn_in[i] <= 0:
			continue
		_respawn_in[i] -= 1
		if _respawn_in[i] > 0:
			continue
		# Back at their own team's start, a short run from anywhere.
		runners[i].respawn(VersusStageData.respawn_for(i, _died_at[i]))
		runners[i].facing = VersusStageData.start_facing()[i]

func leave_versus() -> void:
	if link != null:
		link.close()
	elif eos_room != null:
		eos_room.leave()
	eos_room = null
	# Back to the co-op stage that was selected before versus.
	if VersusLaunch.previous_stage >= 0:
		Stage.use(VersusLaunch.previous_stage)
	VersusLaunch.clear()
	VersusLaunch.previous_stage = -1
	get_tree().change_scene_to_file("res://src/main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		leave_versus()

# ---------------------------------------------------------------------- paint
## Stars, platforms, rings and strikes go on an overlay above the scenery:
## drawn on the arena itself they sat underneath its children -- the level's
## ground, trees and signposts -- and a star behind a tree was a star nobody
## could see.
func _draw_overlay() -> void:
	for t in _tracers:
		var a: Vector2 = _near(t["from"])
		var b: Vector2 = VersusStageData.nearest_image(t["to"], a)
		_overlay.draw_line(a, b, Color(1.0, 0.95, 0.6, clampf(float(t["ttl"]) * 5.0, 0.0, 1.0)), 4.0)
		_overlay.draw_circle(b, 10.0, Color(1.0, 0.85, 0.3, 0.6))
	_builds()
	_markers()
	_coins()
	_heads()

## How many stars each runner is carrying, over their head. Pips, not a number: what
## you need at a glance is "more than them". World space, which is why it lives
## here and not in the HUD.
func _heads() -> void:
	for i in range(sides):
		var held := held_by(i)
		if held <= 0:
			continue
		var centre: Vector2 = runners[i].global_position
		var y := centre.y - Balance.RUNNER_SIZE.y * 0.5 - 18.0
		var pitch := 18.0
		var x0 := centre.x - pitch * float(held - 1) * 0.5
		for k in range(held):
			_star_shape(Vector2(x0 + pitch * float(k), y), 9.0, COL_COIN)

func _star_shape(at: Vector2, r: float, fill: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(10):
		var rr := r if k % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + float(k) * TAU / 10.0
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	_overlay.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	_overlay.draw_polyline(pts, COL_COIN_EDGE, maxf(1.5, r * 0.12))

func _builds() -> void:
	for i in range(_built.size()):
		var team := VersusRoster.side_of_in(room_mode, _build_owner[i]) \
			if i < _build_owner.size() else 0
		# A dark outline under the bright one. Team A's colour is a sky blue and
		# 1-1's sky is behind half the arena, so a platform drawn in it alone
		# disappeared into the background -- something you found by walking into
		# it rather than by looking.
		var box := Rect2(_near(_built[i].position), _built[i].size)
		_overlay.draw_rect(box.grow(2.0), Color(0.06, 0.07, 0.10, 0.85), false, 5.0)
		_overlay.draw_rect(box, build_fill(team))
		_overlay.draw_rect(box, build_edge(team), false, 3.0)
		# A highlight along the top, so which side of it you can stand on is
		# obvious from across the arena.
		_overlay.draw_line(box.position + Vector2(0.0, 1.5),
			box.position + Vector2(box.size.x, 1.5),
			Color(1, 1, 1, 0.75), 3.0)

func _markers() -> void:
	for i in range(sides):
		if _respawn_in[i] > 0:
			continue
		var at: Vector2 = runners[i].global_position \
			+ Vector2(0.0, Balance.RUNNER_SIZE.y * 0.5)
		_overlay.draw_arc(at, 17.0, 0.0, TAU, 20, build_edge(i), 3.0)

func _coins() -> void:
	for c in coins():
		if int(c["state"]) != ArenaCoin.State.WORLD:
			continue
		var at: Vector2 = _near(c["position"])
		var fill := COL_COIN
		if c.has("world_since"):
			var left := VersusRules.STALE_TICKS - (world_tick() - int(c["world_since"]))
			if left <= 90:
				fill.a = 0.35 + 0.65 * absf(sin(float(left) * 0.25))
		if _world_view == null:
			_star_shape(at, STAR_RADIUS, fill)
		if c.has("pickup_tick") and world_tick() < int(c["pickup_tick"]):
			_overlay.draw_arc(at, STAR_RADIUS + 4.0, 0.0, TAU, 20, Color(1, 1, 1, 0.45), 2.0)

## The strike while it is live, and the wind-up before it. Both shown: the whole
## fight is about whether eight frames was enough warning.
func _strikes() -> void:
	if match_rules == null:
		for i in range(sides):
			if client == null or client.runners.size() <= i:
				continue
			var r: Dictionary = client.runners[i]
			if int(r["combat_phase"]) == ArenaCombat.Phase.ACTIVE:
				_strike_box_at(_near(r["position"]), int(r["combat_dir"]))
		return
	for i in range(sides):
		var c := match_rules.combat[i]
		var at: Vector2 = runners[i].global_position
		if c.phase == ArenaCombat.Phase.STARTUP:
			_overlay.draw_arc(at + Vector2(float(c.attack_dir) * 22.0, 0.0), 7.0,
				0.0, TAU, 12, Color(1, 1, 1, 0.45), 2.0)
		elif c.phase == ArenaCombat.Phase.ACTIVE:
			_strike_box_at(at, c.attack_dir)

func _strike_box_at(at: Vector2, dir: int) -> void:
	var mid := Vector2(at.x + float(dir) * VersusRules.STRIKE_REACH, at.y)
	var box := Rect2(mid - VersusRules.STRIKE_SIZE * 0.5, VersusRules.STRIKE_SIZE)
	_overlay.draw_rect(box, Color(1.0, 0.95, 0.70, 0.30))
	_overlay.draw_rect(box, Color(1.0, 0.95, 0.70, 0.85), false, 2.0)
