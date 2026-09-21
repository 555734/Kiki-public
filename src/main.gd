extends Node2D
## Assembles the stage and owns the run loop: camera, respawn, restart, roles.
##
## Everything is constructed in code rather than saved as a scene tree. With no
## image assets and a data-driven level there is nothing to arrange visually in
## the editor, and building here keeps the whole wiring readable in one place --
## which of the two players owns which node, and who talks to whom.

var runner: Runner = null
var guardian: Guardian = null
var input_hub: InputHub = null
var level: LevelBuilder = null
var camera: Camera2D = null
var scope: Scope = null
var hud: Hud = null
var sky: CanvasLayer = null
var preview: Node2D = null
var fx: Node2D = null

var _respawn_timer: float = -1.0
var _shake: float = 0.0

## Online play. OFFLINE is two players on one screen, which is what the game
## has always been; the other two split them across devices with the runner's
## machine holding the simulation (docs/netcode.md section 1).
enum Net { OFFLINE, HOST, CLIENT }
var net_mode: Net = Net.OFFLINE
var host_session: HostSession = null
var client_session: ClientSession = null
## Where the current connection attempt has got to, and how it got there.
## One owner for the question, so the panel, the sessions and the diagnostic
## cannot disagree about it. See NetLink.
var link: NetLink = null

func _ready() -> void:
	link = NetLink.new()
	link.name = "NetLink"
	add_child(link)

	input_hub = InputHub.new()
	input_hub.name = "InputHub"
	add_child(input_hub)

	level = LevelBuilder.new()
	level.name = "Level"
	add_child(level)

	runner = Runner.new()
	runner.name = "Runner"
	runner.input_hub = input_hub
	runner.global_position = Stage.start()
	add_child(runner)
	level.runner = runner
	# Which player this screen belongs to, before the level is built: on an
	# asymmetric stage it decides what gets painted.
	level.input_hub = input_hub
	level.build()

	guardian = Guardian.new()
	guardian.name = "Guardian"
	guardian.runner = runner
	guardian.input_hub = input_hub
	guardian.world_root = self
	add_child(guardian)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = false   # smoothed by hand, see _process
	camera.zoom = Vector2.ONE * Balance.CAMERA_ZOOM
	camera.global_position = runner.global_position
	add_child(camera)
	camera.make_current()

	# 2D bloom. The holograms, the laser, the scope ring and the HUD accents are
	# all emissive by design, and without glow they read as flat cyan shapes
	# rather than as light -- which is most of what separates the painted look
	# from the vector one.
	if Balance.ENABLE_BLOOM and not Balance.USE_3D:
		var env_node := WorldEnvironment.new()
		env_node.name = "Bloom"
		var env := Environment.new()
		env.background_mode = Environment.BG_CANVAS
		env.glow_enabled = true
		env.glow_intensity = 0.60
		env.glow_strength = 1.05
		env.glow_bloom = 0.0            # a separate blur pass; the levels below do the work
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		env.glow_hdr_threshold = 0.94
		env.glow_hdr_scale = 2.0
		# Only two mip levels instead of the default spread. Each level is another
		# downsample and blur, and at this art scale the wide ones contribute
		# almost nothing visible while costing the most on a mobile GPU.
		for level in range(1, 8):
			env.set("glow_levels/%d" % level, 1.0 if level in [3, 4] else 0.0)
		env_node.environment = env
		add_child(env_node)

	fx = preload("res://src/render/fx.gd").new()
	fx.name = "Fx"
	add_child(fx)

	sky = preload("res://src/render/sky.gd").new()
	sky.name = "Sky"
	sky.camera = camera
	add_child(sky)

	preview = preload("res://src/ui/placement_preview.gd").new()
	preview.name = "PlacementPreview"
	preview.guardian = guardian
	add_child(preview)

	scope = Scope.new()
	scope.name = "Scope"
	scope.guardian = guardian
	add_child(scope)

	hud = Hud.new()
	hud.name = "Hud"
	hud.guardian = guardian
	hud.input_hub = input_hub
	add_child(hud)

	# One stage's HUD, built only for that stage. A boss bar that existed
	# everywhere would be an empty rectangle over five stages that do not have
	# a boss, and the alternative -- a bar that hides itself -- is a thing that
	# can be wrong rather than a thing that cannot exist.
	if Stage.is_keeper():
		var boss_bar := BossBar.new()
		boss_bar.name = "BossBar"
		add_child(boss_bar)

	Events.runner_died.connect(_on_runner_died)
	Events.checkpoint_reached.connect(_on_checkpoint)
	Events.ability_used.connect(_on_ability_used)

	GameState.reset_run(Stage.start())
	Clock.reset(0)

	# Offline until someone chooses otherwise, so nothing about the existing
	# shared-screen game changes for anyone who ignores this.
	var panel := NetPanel.new()
	panel.name = "NetPanel"
	panel.main = self
	add_child(panel)
	if Balance.USE_3D:
		add_child(preload("res://src/render/three/world_view.gd").new())

## Starts hosting for a guardian on the same network. Returns "" or a reason.
func host_online(port: int) -> String:
	var t := EnetTransport.new()
	var err := t.listen(port)
	if err != "":
		return err
	_become_host(t)
	return ""

## Joins a runner on the same network as the guardian.
func join_online(address: String, port: int) -> String:
	var t := EnetTransport.new()
	var err := t.connect_to(address, port)
	if err != "":
		return err
	_become_client(t)
	return ""

## The same two roles, over the internet. A direct connection needs one side to
## have a reachable address; two people in different houses do not have one, so
## both dial out to a relay instead. Everything above the transport is unchanged
## -- that is the whole reason NetTransport exists.
func host_relay(relay: String, code: String) -> String:
	return _dial_relay(relay, code, "host")

func join_relay(relay: String, code: String) -> String:
	return _dial_relay(relay, code, "guest")

## One door for both roles, so neither can forget to start the attempt, tear
## down the previous one, or record why it failed.
func _dial_relay(relay: String, code: String, role: String) -> String:
	if link.busy():
		# Two taps on the same button used to build two sessions. The second
		# one took the room's other slot from its own partner.
		return "すでに接続中です（%s）" % NetLink.LABELS.get(link.phase, "?")
	_end_any_session()
	link.begin(code, role)
	var t := WebSocketTransport.new()
	var err := t.open_room(relay, code, NetLink.client_id(), role)
	if err != "":
		link.last_error = err
		link.enter(NetLink.Phase.FAILED, err)
		return err
	if role == "host":
		_become_host(t)
	else:
		_become_client(t)
	_watch_transport(t)
	return ""

## The relay's own reports, written into the one place that owns the answer.
func _watch_transport(t: WebSocketTransport) -> void:
	t.joined.connect(func(role: String) -> void:
		link.relay_role = role
		link.note("中継が役割を割り当て: %s" % role)
		# Being told "host" when we asked to be the guest means the room was
		# empty. That is not a broken relay, and saying so is the difference
		# between a fixable problem and a mysterious one.
		if link.desired_role == "guest" and role == "host":
			link.enter(NetLink.Phase.WAITING_PEER, "部屋が空でした")
		else:
			link.enter(NetLink.Phase.WAITING_PEER))
	t.peer_connected.connect(func() -> void:
		link.note("相手が部屋に入りました")
		if link.phase != NetLink.Phase.PLAYING:
			link.enter(NetLink.Phase.HANDSHAKING))
	t.peer_disconnected.connect(func() -> void:
		link.close_code = t.last_close_code
		link.close_reason = t.last_close_reason
		link.note("相手の接続が切れました"))
	t.failed.connect(func(reason: String) -> void:
		link.close_code = t.last_close_code
		link.close_reason = t.last_close_reason
		link.last_error = reason
		link.enter(NetLink.Phase.FAILED, reason))

## Everything from a previous attempt, gone before a new one starts.
##
## Neither of the two functions below used to do this, and nothing else did
## either. So a join that failed -- a dead socket, a wrong code, a room with
## nobody in it -- left its ClientSession alive, still polling its dead
## transport, still holding guardian.command_router; and then pressing "make a
## room" on the same screen added a HostSession next to it. Two sessions, two
## transports, and Clock.is_host decided by whichever _ready ran last. The only
## way out was to force-quit the game, which is exactly what happened.
func _end_any_session() -> void:
	var ended := false
	for session in [host_session, client_session]:
		if session == null or not is_instance_valid(session):
			continue
		var t = session.get("transport")
		if t != null and t.has_method("close"):
			t.call("close")
		session.set_process(false)
		session.set_physics_process(false)
		remove_child(session)
		session.queue_free()
		ended = true
	host_session = null
	client_session = null
	guardian.command_router = null
	# Only when something was actually ended. _become_host and _become_client
	# call this too, so an attempt that has just been started -- torn down,
	# then begun, then handed to _become_* -- would otherwise reset its own
	# phase to IDLE on the way in and report itself as not running.
	if ended and link != null and is_instance_valid(link):
		link.finish()
	net_mode = Net.OFFLINE
	Clock.is_host = true
	Clock.follow_target = -1
	# The puppet's physics was switched off by whoever took the world over.
	runner.set_physics_process(true)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node:
			(e as Node).set_physics_process(true)

func _become_host(t: NetTransport) -> void:
	_end_any_session()
	net_mode = Net.HOST
	host_session = HostSession.new()
	host_session.name = "HostSession"
	host_session.main = self
	host_session.transport = t
	add_child(host_session)
	# One device, one role: the local player is the runner and owns the whole
	# screen, rather than the left third of a shared one.
	input_hub.solo_role = "runner"

func _become_client(t: NetTransport) -> void:
	_end_any_session()
	net_mode = Net.CLIENT
	client_session = ClientSession.new()
	client_session.name = "ClientSession"
	client_session.main = self
	client_session.transport = t
	add_child(client_session)
	input_hub.solo_role = "guardian"
	guardian.command_router = client_session
	# Giving up must not be a dead end. Ninety seconds of failed reconnection
	# used to leave a banner on a frozen world with nothing to press; the
	# connect screen is where the room code and the diagnostic live, so that is
	# where a player who has lost the link needs to be.
	client_session.disconnected.connect(_offer_reconnect)

func _offer_reconnect() -> void:
	if get_node_or_null("NetPanel") != null:
		return
	var panel := NetPanel.new()
	panel.name = "NetPanel"
	panel.main = self
	add_child(panel)

func _process(delta: float) -> void:
	_update_camera(delta)

	if _respawn_timer >= 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn_timer = -1.0
			_do_respawn()

	if Input.is_action_just_pressed("game_restart"):
		_restart()
	# The runner's half of the conversation. Their ping marks where THEY are,
	# which is the thing the guardian most often needs told -- and it needs no
	# aiming, which the runner has no way to do.
	if input_hub != null and input_hub.solo_role == "runner":
		var mark := input_hub.take_ping()
		if mark > 0:
			Events.pinged.emit(runner.global_position, mark, true)

	if Input.is_action_just_pressed("game_swap_roles"):
		_swap_roles()
	if input_hub.take_countdown():
		Events.countdown_started.emit()

## How far the guardian has pushed the view along, in world pixels. Read by the
## camera; written by the two "look" buttons.
var guardian_pan: float = 0.0

## The guardian asked to see further along the stage.
##
## Chapter 6 wants the guardian reading one screen ahead of the runner, and the
## camera's lead alone only buys a fraction of a screen. This is the rest of it,
## under their own hand -- but bounded, and bounded by the VIEWPORT rather than
## by a constant: the runner never leaves the screen, so looking ahead can never
## become looking away from the person you are meant to be catching.
func _pan_limit() -> float:
	var half := get_viewport().get_visible_rect().size.x * 0.5 / Balance.CAMERA_ZOOM
	return clampf(half - Balance.GUARDIAN_PAN_MARGIN, 0.0, Balance.GUARDIAN_PAN_MAX)

## The view STAYS where it was put.
##
## It used to ease back to the runner whenever the buttons were released, which
## meant holding a button down was the only way to keep looking at anything --
## reported, fairly, as tiring. The offset is a place the guardian chose; the
## camera still follows the runner, so the chosen offset travels with them and
## nothing is ever lost off the back of the screen. Getting back is the other
## arrow, or the flick that put you there in reverse, or a retry.
func _update_pan(delta: float) -> void:
	if input_hub == null:
		return
	guardian_pan += input_hub.pan_axis * Balance.GUARDIAN_PAN_SPEED * delta
	guardian_pan += input_hub.take_pan_drag()
	var limit := _pan_limit()
	guardian_pan = clampf(guardian_pan, -limit, limit)

func _update_camera(delta: float) -> void:
	if runner == null or not is_instance_valid(runner):
		return
	_update_pan(delta)
	# Lead the camera in the direction of travel so the guardian gets a little
	# more of the road ahead -- chapter 6 wants them reading one screen further
	# than the runner, and on a shared display this is the whole of that budget.
	var lead := clampf(runner.velocity.x / Balance.RUNNER_RUN_SPEED, -1.0, 1.0) \
		* Balance.CAMERA_LOOKAHEAD
	var target := runner.global_position + Vector2(lead + guardian_pan, -40.0)
	var t := clampf(delta * Balance.CAMERA_SMOOTH, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(target, t)

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		camera.offset = Vector2(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 7.0
	else:
		camera.offset = Vector2.ZERO

func _on_ability_used(slot: int, _pos: Vector2) -> void:
	if slot == 3:
		_shake = 0.55

func _on_runner_died(_cause: String) -> void:
	_shake = 1.0
	_respawn_timer = Balance.RESPAWN_DELAY

func _do_respawn() -> void:
	# Constructs do not survive the reset: otherwise the guardian could pre-build
	# the retry and the section would stop being a question.
	guardian.clear_constructs()
	level.reset_to_checkpoint()
	runner.respawn(GameState.respawn_position())
	# Back to the runner. Whatever the guardian was looking at, the retry is the
	# thing that matters now.
	guardian_pan = 0.0
	camera.global_position = runner.global_position
	Events.runner_respawned.emit(GameState.checkpoint_index)

func _restart() -> void:
	GameState.reset_run(Stage.start())
	Clock.reset(0)

	# Offline until someone chooses otherwise, so nothing about the existing
	# shared-screen game changes for anyone who ignores this.
	var panel := NetPanel.new()
	panel.name = "NetPanel"
	panel.main = self
	add_child(panel)
	guardian.clear_constructs()
	level.reset_to_checkpoint()
	runner.respawn(Stage.start())
	camera.global_position = runner.global_position

func _on_checkpoint(index: int) -> void:
	Events.notice.emit("checkpoint %d" % index)

## Chapter 7 wants the pair to be able to trade roles so neither gets stuck in
## one seat. On a shared tablet that is physically just swapping sides, so all
## the game has to do is mirror the touch layout.
func _swap_roles() -> void:
	input_hub.runner_on_left = not input_hub.runner_on_left
	Events.roles_swapped.emit(input_hub.runner_on_left)
	Events.notice.emit("roles swapped")
