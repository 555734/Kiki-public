extends Node2D
## The 2v2 star match: two teams of a runner and a guardian, on a small arena
## built from 1-1's pieces. Uses the game's Runner, a local following camera,
## and a host-owned star ledger (VersusMatch; the ledger calls them coins).
## Seven stars held wins. Free for every player -- nothing here reads
## Entitlement (docs/versus-2v2-stars.md).
##
## This scene is the composition root and the tick: it seats this machine,
## builds the world and the runners, steps the match each physics frame and
## answers the HUD. The separate jobs live in their own parts, under scene/:
## the connection (VersusConnection), the guardians' platforms
## (VersusPlatforms), deaths and respawns (VersusLives), the camera and sky
## (VersusView), the world-space overlay (VersusOverlay), the menu
## (VersusMenu) and the on-device log (VersusDiagnostics).

const RunnerVisualScript = preload("res://src/runner/runner_visual.gd")

enum Mode { SOLO, HOST, CLIENT }

var mode: int = Mode.SOLO
var match_rules: VersusMatch = null       ## host and solo only
var host: VersusHost = null
var client: VersusClient = null
var link: VersusTransport = null
## Over EOS (what ships) or the old WebSocket relay (editor, probes).
var use_eos: bool = false
var eos_room: EosVersusLobby = null
## The client's rematch counter last acted on.
var _seen_epoch_changes: int = 0
var room_code: String = ""
var room_mode: int = VersusRoster.RoomMode.TEAM_SPLIT
var controls: Control = null
var status: String = ""

var runners: Array[Runner] = []
var input: VersusInput = null
var hud: Control = null
var guardian: Guardian = null

## Which runner this machine drives, or -1 for a guardian. Solo drives both.
var local_team: int = 0
var level: LevelBuilder = null
## How many sides this match has: 2 for 2v2 and 1v1, 8 chairs in a
## free-for-all (a solo test on one machine is always 2).
var sides: int = 2
var _seat: int = VersusRoster.SEAT_A_RUNNER

## The scene's parts. See the note at the top.
var connection := VersusConnection.new(self)
var platforms := VersusPlatforms.new(self)
var view := VersusView.new(self)
var diagnostics: VersusDiagnostics = null
var lives: VersusLives = null
var menu: VersusMenu = null
var _overlay: VersusOverlay = null
## The やめる question (QuitConfirm); the button itself is the menu's.
var _quit: QuitConfirm = null

# Read-only views of the parts' state, for the HUD, the enemies and the probes.
var _built: Array[Rect2]:
	get: return platforms.built
var _holos: Dictionary:
	get: return platforms.holos
var _respawn_in: Array[int]:
	get: return lives.respawn_in
var bumps_felt: int:
	get: return lives.bumps_felt
var enemies_downed: int:
	get: return lives.enemies_downed
var _camera: Camera2D:
	get: return view.camera
var _sky: Node:
	get: return view.sky
var _world_view: Node:
	get: return view.world_view
var _start_button: Button:
	get: return menu.start_button if menu != null else null
var _again_button: Button:
	get: return menu.again_button if menu != null else null
var _leave_button: Button:
	get: return menu.leave_button if menu != null else null

func _ready() -> void:
	process_physics_priority = 100
	z_index = 5
	_read_command_line()
	sides = VersusRoster.sides_for(room_mode) if mode != Mode.SOLO else 2
	lives = VersusLives.new(self, sides)
	diagnostics = VersusDiagnostics.new()
	diagnostics.name = "Diagnostics"
	diagnostics.arena = self
	add_child(diagnostics)
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
	_overlay = VersusOverlay.new()
	_overlay.arena = self
	add_child(_overlay)
	view.build_camera(runners[maxi(local_team, 0)].global_position)

	# In a CanvasLayer, because the camera moves now: the scoreboard belongs to
	# the screen, not to a place on the stage.
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)
	hud = preload("res://src/versus/versus_hud.gd").new()
	hud.arena = self
	layer.add_child(hud)
	if mode != Mode.SOLO and OS.has_feature("editor"):
		diagnostics.add_copy_button(layer)
	menu = VersusMenu.new(self)
	layer.add_child(menu)
	menu.refresh()
	_quit = QuitConfirm.new()
	_quit.name = "Quit"
	_quit.with_button = false
	_quit.input_hub = input.hubs[0]
	_quit.on_quit = leave_versus
	_quit.pause_while_asking = mode == Mode.SOLO
	_quit.detail = tr("スタート画面に戻ります") if mode == Mode.SOLO \
		else tr("部屋から抜けて、スタート画面に戻ります")
	add_child(_quit)
	_layer = layer
	# The hub reads fingers before the GUI does; the menu's buttons are real
	# Buttons and would never hear a press otherwise.
	input.hubs[0].gui_passthrough = _over_button
	_build_controls()

	match mode:
		Mode.SOLO:
			match_rules = VersusMatch.new()
			match_rules.line_clear = line_clear
			_start_solo()
		Mode.HOST:
			_open_link(true)
		Mode.CLIENT:
			_open_link(false)

	_build_shooter()
	if combined() and mode != Mode.SOLO:
		for r in runners:
			r.set_physics_process(false)
	view.add_world_view()

var _layer: CanvasLayer = null
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
	if level != null:
		level.set_riders(_riders())
	if local_team < 0 or local_team >= sides:
		return
	var r := runners[local_team]
	r.visible = true
	r.input_hub = input.hubs[0]
	r.global_position = VersusStageData.start_positions()[local_team]
	r.facing = VersusStageData.start_facing()[local_team]
	level.runner = r
	view.camera.global_position = r.global_position
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

func relay() -> String:
	return _relay

func is_solo() -> bool:
	return mode == Mode.SOLO

## For the log: what this machine is in the room.
func role_name() -> String:
	return "HOST" if mode == Mode.HOST else ("JOIN" if mode == Mode.CLIENT else "SOLO")

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
	return VersusStageData.collision_rects(platforms.built)

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

## Rebuild the arena as another stage: its ground (each stage has its own
## shape), its art and its sky. A guest does this on the host's WELCOME,
## before anyone can move, and then stands at that stage's start.
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
	level.add_actors(self)
	level.set_riders(_riders())
	view.replace_sky()
	# A new stage is new ground: everyone goes to its starts. Online this is
	# the lobby (a guest repaints on the WELCOME, before anyone can move).
	if mode == Mode.SOLO or not can_move():
		_reset_bodies()
		if view.camera != null:
			view.camera.global_position = runners[maxi(_view_team(), 0)].global_position
	view.drop_world_view()
	view.add_world_view()

func theme() -> int:
	return _theme

func _finish_world() -> void:
	level.runner = runners[maxi(local_team, 0)]
	level.input_hub = input.hubs[0]
	level.build()
	level.add_actors(self)
	level.set_riders(_riders())

## The runners this device moves itself: both on the keyboard test, its own
## online. Springs and columns of air throw only these; everyone else's are
## thrown by their own device.
func _riders() -> Array:
	if mode == Mode.SOLO:
		return runners.duplicate()
	return [runners[local_team]] if local_team >= 0 and local_team < runners.size() else []

# ---------------------------------------------------------------- the clock
## Co-op's moving platforms, blinking slabs and conveyors read Clock.tick, and
## so do the enemies here: kept on the match's tick, every device shows them
## in the same place. A guest runs its own count forward and is steered to
## the host's, so they move smoothly between snapshots.
var _clock: int = 0

func enemy_tick() -> int:
	return _clock

func _sync_clock() -> void:
	if match_rules != null:
		_clock = match_rules.tick
	elif client != null:
		_clock += 1
		if absi(client.world_tick - _clock) > 6:
			_clock = client.world_tick
	Clock.tick = _clock

## Whether enemy `i` is up: the match's word (host, solo) or the snapshot's.
func enemy_alive(i: int) -> bool:
	if match_rules != null:
		return match_rules.enemy_alive(i)
	if client != null:
		return (client.enemy_mask >> i) & 1 == 0
	return true

## The co-op rifle hit enemy `id` on this screen; the host decides.
func report_enemy_hit(id: int) -> void:
	match mode:
		Mode.SOLO:
			if match_rules != null:
				match_rules.shoot_enemy(0, id)
		Mode.HOST:
			if host != null:
				host.shoot_enemy(_seat, id)
		Mode.CLIENT:
			if client != null:
				client.request_enemy_shot(id)

## Whose runner the camera follows: your own, or a guardian's team's.
func _view_team() -> int:
	if local_team >= 0:
		return local_team
	# A guardian watches their own team's runner.
	return VersusRoster.team_of(maxi(_seat, 0))

func _process(delta: float) -> void:
	view.follow(runners[maxi(_view_team(), 0)], delta)
	if menu != null:
		menu.refresh()
	diagnostics.place_copy_button(waiting(), get_viewport_rect().size)

## Where to draw something canonical (in lap 0): the copy nearest the camera.
func _near(at: Vector2) -> Vector2:
	return view.near(at)

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
		if i == _view_team():
			view.shift(now - was)

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
		# Bodies are solid to each other: walking into someone stops you
		# (and is a bump, VersusMatch._bump). Only this machine's runner
		# moves itself, so only its mask matters; the others are puppets.
		r.collision_mask |= Runner.LAYER_RUNNER
		# What the co-op rifle looks for (versus_shootable.gd).
		var target := VersusShootable.new()
		target.name = "Shootable"
		target.arena = self
		target.side = i
		r.add_child(target)
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

## Every player's platform and rifle: the co-op Guardian itself, run
## exactly as one-device 1-1 runs it -- the same gauge, costs, range checks,
## traced platforms (6s, two at a time), launch triggers, aim assist, tracer
## and sounds -- with the same two tools 1-1's shared layout has (platform and
## shot). Nothing is routed: the Guardian acts locally, and what the others
## need is passed on afterwards (VersusPlatforms.sync_holograms, report_shot_hit).
## A 2v2 guardian seat has the guardian layout; every other seat is one
## person playing both on 1-1's one-device screen (ControlLayout "shared"),
## drawn by the same painter (ControlPainter).
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
	guardian.runner = runners[VersusRoster.team_of(_seat)] if guardian_seat \
		else runners[clampi(VersusRoster.side_of_in(room_mode, _seat), 0, sides - 1)]
	guardian.input_hub = hub
	guardian.world_root = self
	add_child(guardian)
	# 1-1's shared layout has these two: the platform and the shot.
	guardian.abilities = {1: guardian.abilities[1], 3: guardian.abilities[3]}
	# And co-op's world-space cursor: the traced platform's ghost while the
	# finger is down, the rifle's reticle and lock, and the shot's tracer.
	var preview := preload("res://src/versus/versus_preview.gd").new()
	preview.name = "PlacementPreview"
	preview.guardian = guardian
	add_child(preview)

## The side whose player this machine's rifle fires for.
func _my_side() -> int:
	if mode == Mode.SOLO:
		return 0
	return VersusRoster.side_of_in(room_mode, maxi(_seat, 0))

## Whether this machine's rifle may lock onto `side`'s runner.
func can_shoot_at(side: int) -> bool:
	if side == _my_side() or side < 0 or side >= sides:
		return false
	if not runners[side].visible or lives.respawn_in[side] > 0:
		return false
	return not waiting() and countdown_ticks() == 0 \
		and phase() == VersusMatch.Phase.PLAYING

## Nothing solid between two points: no ground and no platform. A platform
## over your head is cover -- the shot comes down from above
## (VersusRules.SHOT_FROM) and a stomp comes down from the stomper -- so the
## rifle, the host's ruling and the stomp all ask this. Platforms are
## everyone's here (VersusPlatforms.sync_holograms), so every machine agrees.
func line_clear(from: Vector2, to: Vector2) -> bool:
	if not is_inside_tree():
		return true
	var query := PhysicsRayQueryParameters2D.create(from, to,
		Runner.LAYER_TERRAIN | Hologram.LAYER_HOLOGRAM)
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

## Whether a shot could reach `side`'s runner from above right now.
func shot_clear(side: int) -> bool:
	var at := runners[side].global_position
	return line_clear(at + VersusRules.SHOT_FROM, at)

## The co-op rifle hit `side`'s runner on this screen. The host confirms it
## against where it has that runner (VersusMatch.shoot) and takes the star.
func report_shot_hit(side: int) -> void:
	if not can_shoot_at(side):
		return
	var at: Vector2 = VersusStageData.wrap_x(runners[side].global_position.x) * Vector2.RIGHT \
		+ Vector2(0.0, runners[side].global_position.y)
	match mode:
		Mode.SOLO:
			match_rules.shoot(0, at)
		Mode.HOST:
			if host != null:
				host.shoot(_seat, at)
		Mode.CLIENT:
			if client != null:
				client.request_shot(at)

# ----------------------------------------------------------- parts' hooks
## Kept here, not in the parts, because tests replace them to stand in a
## loopback link or to keep the log quiet.
func _start_debug_log() -> void:
	diagnostics.start_log()

func _open_link(as_host: bool) -> void:
	connection.open(as_host)

## The log's entry point; links, hosts and guests are wired to it directly.
func _debug(message: String) -> void:
	if diagnostics != null:
		diagnostics.debug(message)

func debug_lines() -> Array[String]:
	return diagnostics.lines()

# --------------------------------------------------------------------- the tick
func _physics_process(_delta: float) -> void:
	connection.poll()

	var seqs := input.poll()
	diagnostics.trace_local_input()
	_sync_clock()

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
	_solid_bodies()
	platforms.sync_holograms()
	_star_sounds()
	lives.remember_fall()
	_update_activity()
	connection.mark_started()
	diagnostics.record_match_state()
	_redraw()

## Only a runner who is in the match is something to bump into: an empty
## chair's body (hidden at its start) or one waiting to respawn is not.
func _solid_bodies() -> void:
	for i in range(sides):
		var solid := runners[i].visible and lives.respawn_in[i] <= 0 \
			and runners[i].state != Runner.State.DEAD
		runners[i].collision_layer = Runner.LAYER_RUNNER if solid else 0

## The coin sound when a star is picked up: full for this player's own side,
## quieter for everyone else's, so you hear the race without mistaking it.
var _held_seen: Array[int] = []

func _star_sounds() -> void:
	_held_seen.resize(sides)
	for i in range(sides):
		var now := held_by(i)
		if now > _held_seen[i] and phase() == VersusMatch.Phase.PLAYING:
			Audio.play("coin", 0.0, 0.0, 1.0 if i == _my_side() else 0.45)
			star_sounds_played += 1
		_held_seen[i] = now

## For the probes: how many times the pickup sound has played.
var star_sounds_played: int = 0

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
		if i == local_team:
			# Your own runner is always drawn. A free-for-all guest has no
			# chair until the WELCOME, and until then this loop treated their
			# runner as an empty chair and hid it -- then, once seated, skipped
			# it as their own and never showed it again: a ring with nobody in it.
			runners[i].visible = true
		else:
			runners[i].visible = not waiting() \
				and _seat_taken(VersusRoster.runner_seat_in(room_mode, i))

func can_move() -> bool:
	if mode == Mode.SOLO:
		return phase() != VersusMatch.Phase.OVER
	return not waiting() and countdown_ticks() == 0 \
		and phase() == VersusMatch.Phase.PLAYING

## The overlay (stars, rings) moves with the world and is redrawn every tick.
## The HUD -- scoreboard, map, edge arrows, banners -- at most 20 times a
## second, and at once when something it states changes (a star taken, the
## phase, the countdown): nobody reads a map dot at 60Hz, and on a phone the
## HUD was a sixth of the frame.
var _hud_said: Array = []

func _redraw() -> void:
	if _overlay != null:
		_overlay.queue_redraw()
	var said: Array = [phase(), countdown_ticks(), waiting(), status, connection.error]
	for i in range(sides):
		said.append(held_by(i))
	if said != _hud_said or Engine.get_physics_frames() % 3 == 0:
		_hud_said = said
		hud.queue_redraw()

func _observe(i: int, seq: int) -> VersusMatch.Seat:
	var s := VersusMatch.Seat.new()
	s.team = i
	s.position = runners[i].global_position
	s.facing = runners[i].facing
	s.alive = runners[i].state != Runner.State.DEAD and lives.respawn_in[i] <= 0
	# Being untouchable does not stop you acting: Runner.respawn grants a
	# second of it, and folding that into can_act meant nobody could take a
	# coin for the first second of the match.
	s.can_act = s.alive and runners[i].state != Runner.State.HURT
	s.invulnerable = runners[i].is_invulnerable()
	s.strike_seq = seq
	s.velocity = Vector2(runners[i].velocity.x, fall_speed(i))
	return s

## How fast `i` is coming down; see VersusLives.fall_speed.
func fall_speed(i: int) -> float:
	return lives.fall_speed(i)

## Before and after play: where the runner stands, alive, and not acting.
func _idle(i: int, seq: int) -> VersusMatch.Seat:
	var s := _observe(i, seq)
	s.alive = true
	s.can_act = false
	return s

func _tick_solo(seqs: Array[int]) -> void:
	_wrap_bodies()
	if phase() == VersusMatch.Phase.OVER:
		return
	lives.apply_respawns()
	lives.catch_deaths()
	# The touch test's partner never swings: one strike count drives both
	# hubs' sequences on a phone, and it must not be P2's.
	match_rules.step([_observe(0, seqs[0]), _observe(1, 0 if touch_solo else seqs[1])])
	lives.apply_events(match_rules.events)
	for i in range(sides):
		lives.stomp_bounce(i)

func _tick_host(seqs: Array[int]) -> void:
	if host == null:
		return
	# The host keeps stepping in every phase: it is also the post office, and
	# a host that stopped at the result screen stopped answering everyone.
	var live := host.playing and phase() == VersusMatch.Phase.PLAYING
	_wrap_bodies()
	if live:
		lives.apply_respawns()
		lives.catch_deaths()
	host.step(_observe(0, seqs[0]) if live else _idle(0, seqs[0]))
	if live:
		lives.stomp_bounce(0)
	match_rules = host.match_rules
	if match_rules != null and not match_rules.line_clear.is_valid():
		match_rules.line_clear = line_clear
	platforms.sync_builds(host.builds, host.world_revision)
	# Everyone else is wherever their own machine says they are.
	for i in range(1, sides):
		var other := host.reported_runner(i)
		_place_puppet(i, other.position, other.facing)
	lives.apply_events(host.out_events)

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
		platforms.forget_revision()
	var mine = null
	if local_team >= 0:
		_wrap_bodies()
		if can_move():
			lives.apply_respawns()
			lives.catch_death_of(local_team)
			mine = _observe(local_team, seqs[0])
		elif client.connected:
			# The host needs this runner's start and ALIVE state before the
			# match can begin; a HELLO alone says nothing about the body.
			mine = _idle(local_team, seqs[0])
	client.step(mine, _seat)
	if local_team >= 0 and can_move():
		lives.stomp_bounce(local_team)
		lives.predict_bump(local_team)
		lives.predict_enemies(local_team)
	platforms.sync_builds_from_snapshot(client.builds, client.world_revision)
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

# ------------------------------------------------------------------- readouts
## One place the HUD asks, whichever side of the network this machine is on.
## Built once per change rather than on every call: the HUD, the map, the
## overlay and the pickup sound all ask several times a frame, and twenty new
## dictionaries each time was steady garbage on a phone.
var _coins_cache: Array = []
var _coins_key: Array = []

func coins() -> Array:
	if match_rules != null:
		var revisions := 0
		for c in match_rules.ledger.coins:
			revisions += c.revision
		var key := [match_rules, match_rules.tick, revisions, Engine.get_physics_frames()]
		if key == _coins_key:
			return _coins_cache
		_coins_key = key
		_coins_cache = []
		for c in match_rules.ledger.coins:
			_coins_cache.append({"id": c.coin_id, "state": c.state, "owner": c.owner,
				"position": c.position, "world_since": c.world_since,
				"pickup_tick": c.pickup_tick})
		return _coins_cache
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
	if match_rules != null:
		for c in match_rules.ledger.coins:
			if c.state == ArenaCoin.State.HELD and c.owner == team:
				n += 1
		return n
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
	return view.rect()

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
	if not connection.error.is_empty():
		return connection.error
	if link != null and not link.last_error().is_empty():
		return TranslationServer.translate("通信エラー: %s") % link.last_error()
	if not diagnostics.relay_probe_detail.is_empty():
		return "room %s · %s" % [code, diagnostics.relay_probe_detail]
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
	return connection.link_error()

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
		platforms.clear_builds()
		_reset_bodies()

# ---------------------------------------------------------------- lives, deaths
func _start_solo() -> void:
	platforms.clear_builds()
	match_rules.setup(ArenaStage.new(_collision_rects()),
		int(Time.get_ticks_usec() & 0x7fffffff))
	_reset_bodies()

func _reset_bodies() -> void:
	lives.reset_bodies()
	platforms.clear_holograms()

func _owns(side: int) -> bool:
	return mode == Mode.SOLO or side == local_team

## やめる: asks first (QuitConfirm), then leave_versus.
func request_leave() -> void:
	_quit.request()

## Whether a screen point is on one of the real buttons shown right now. The
## hub reads fingers before the GUI does, so it leaves presses here alone.
func _over_button(at: Vector2) -> bool:
	if _quit != null and _quit.claims(at):
		return true
	var buttons: Array = [diagnostics.copy_button]
	if menu != null:
		buttons.append_array([menu.start_button, menu.again_button, menu.leave_button])
	for b in buttons:
		if b != null and b.is_visible_in_tree() and b.get_global_rect().has_point(at):
			return true
	return false

func leave_versus() -> void:
	connection.close()
	# Back to the co-op stage that was selected before versus.
	if VersusLaunch.previous_stage >= 0:
		Stage.use(VersusLaunch.previous_stage)
	VersusLaunch.clear()
	VersusLaunch.previous_stage = -1
	get_tree().change_scene_to_file("res://src/main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		request_leave()
