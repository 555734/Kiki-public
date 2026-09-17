extends Node
## Boots the real game, drives it into a handful of set pieces, and writes PNGs.
##
## This is the visual half of verification: the logic tests say the rules hold,
## these say the game actually looks like the mockups. Run it under a display
## (xvfb is fine) with the compatibility renderer:
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --resolution 1280x720 res://test/capture_shots.tscn

const OUT_DIR := "user://shots"
## Preloaded rather than named: the stage data scripts added after 1-1 carry no
## class_name on purpose, so that a freshly pulled checkout does not need
## Godot's global class cache to have been regenerated first.
const LevelKeeperData = preload("res://src/levels/level_keeper_data.gd")
const LevelSkyData = preload("res://src/levels/level_sky_data.gd")

var main: Node2D = null

func _ready() -> void:
	Stage.use(Stage.Which.GREENFIELD)
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(8)
	# Dismiss the connect screen: these shots are of the game, and it covers it.
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
		await _frames(2)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	main.input_hub.scripted = true
	await _run()
	print("shots written to ", ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _place(runner_at: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
	# Cancel any pending respawn first. It is on a timer, so a shot that drops
	# the runner into a pit used to fire mid-way through the *next* setup and
	# silently teleport it back to the start -- which is exactly how the
	# section C shot ended up being a second picture of the start line.
	main._respawn_timer = -1.0
	main.runner.global_position = runner_at
	main.runner.velocity = velocity
	main.camera.global_position = runner_at + Vector2(0, -40)
	await _frames(3)

func _aim(world: Vector2) -> void:
	main.input_hub.aim_at_world(world)
	await _frames(2)

func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR.path_join(name + ".png"))
	print("  captured ", name)

## The stompable nearest the runner. Taking the first one in the group put the
## scope on a walker 1900px off-screen, so the "scope engaged" shots came out
## with the ring parked outside the viewport and nothing to see.
func _walker() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var from: Vector2 = main.runner.global_position
	for n in get_tree().get_nodes_in_group("stompable"):
		if n is Node2D:
			var d: float = from.distance_to((n as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = n
	return best

func _run() -> void:
	# One frame from each section of the stage, plus the touch layout.
	await _place(Vector2(1830, 240), Vector2(340, -240))
	await _aim(Vector2(2100, 320))
	await _shot("01_A_platform_gap")

	await _place(Vector2(1100, 330))
	main.guardian.select_slot(1)
	main.guardian.use_active(Vector2(1330, 280))
	main.guardian.select_slot(2)
	main.guardian.use_active(Vector2(1470, 250))
	main.guardian.select_slot(3)
	# A fixed point a little ahead of the runner. Aiming at "the nearest
	# stompable" put the reticle 1900px off-screen whenever section A's walker
	# happened to be mid-respawn, and the scope furniture clamps itself to the
	# viewport edge rather than disappearing -- so the shot came out looking
	# like the scope simply did not render.
	await _aim(Vector2(1310, 300))
	await _shot("02_constructs_and_scope")

	await _frames(22)
	var walker := _walker()
	if walker != null and absf(walker.global_position.x - main.runner.global_position.x) < 380.0:
		await _aim(walker.global_position)
	await _shot("03_scope_engaged")

	main.guardian.select_slot(1)
	# On the last of the section B ledges, looking across the moving crossing at
	# the turret that covers it. 3820 is inside the gap itself.
	await _place(Vector2(3600, 300))
	await _aim(Vector2(3900, 95))
	await _shot("04_B_turret_over_the_crossing")

	await _place(Vector2(7100, 190))
	main.guardian.select_slot(2)
	main.guardian.use_active(Vector2(7500, 150))
	await _aim(Vector2(7500, 150))
	await _shot("05_C_wall_and_ledges")

	main.guardian.select_slot(3)
	await _place(Vector2(9700, 190))
	await _aim(Vector2(10380, 60))
	await _shot("06_D_collapse_beam_gate")

	main.guardian.select_slot(1)
	await _place(Vector2(11450, 110))
	await _aim(Vector2(11800, 120))
	await _shot("07_E_the_climb")

	await _place(Vector2(14450, 110))
	await _aim(Vector2(14760, -20))
	await _shot("08_F_climax")

	await _place(Level01Data.START)
	await _aim(Vector2(470, 300))
	await _shot("09_stage_start")

	# The warp pair, mid-placement: one gate linked and one being aimed.
	await _place(Vector2(2600, 300))
	main.guardian.gauge = Balance.GAUGE_MAX
	main.guardian.select_slot(4)
	main.guardian.use_active(Vector2(2380, 280))
	main.guardian.use_active(Vector2(2880, 200))
	await _aim(Vector2(2880, 200))
	await _shot("13_warp_gates")

	# A bounce pad with its coin arc overhead.
	main.guardian.clear_constructs()
	main.guardian.select_slot(1)
	await _place(Vector2(1660, 300))
	await _aim(Vector2(1900, 220))
	await _shot("14_spring_and_coins")

	# Two hits and the run is over.
	main.guardian.clear_constructs()
	await _place(Vector2(2700, 300))
	main.runner.hp = 1
	main.runner._invuln = 0.0
	main.runner.take_damage(1)
	# Only a couple of frames: under llvmpipe a frame here is ~60ms, so twenty
	# of them outlast RESPAWN_DELAY and the shot catches the stage AFTER the
	# retry, with the runner back at the start line and the plate already gone.
	await _frames(2)
	await _shot("15_game_over")
	main._respawn_timer = -1.0
	main.runner.respawn(Vector2(2600, 300))
	# Clears the GAME OVER plate. Calling Runner.respawn directly skips the
	# event main._do_respawn would have raised, so the plate went on fading into
	# the next three shots.
	Events.runner_respawned.emit(0)
	await _frames(4)

	# A catch, graded. The runner is dropped down the 600px gap with a real
	# fall speed and the guardian slides a slab under them, so the PERFECT that
	# appears is the grader's answer rather than a pasted-on label.
	main.guardian.clear_constructs()
	await _place(Vector2(2100, 40), Vector2(0, 820))
	# The game-over shot above left the runner with respawn invulnerability, and
	# that blinks the sprite. The first version of this shot caught the blink on
	# its off phase: a graded catch with nobody standing on the platform.
	main.runner._invuln = 0.0
	main.guardian.gauge = 60.0
	main.guardian.select_slot(1)
	main.guardian.use_active(Vector2(2100, 300))
	for i in range(40):
		await get_tree().physics_frame
		if main.runner.is_on_floor():
			break
	await _aim(Vector2(2100, 300))
	await _shot("16_perfect_catch")

	# What a dropped connection looks like now: a banner across the top rather
	# than a session that has simply stopped.
	Events.link_state.emit("つなぎ直しています… (2)")
	# Long enough for the rescue pop above to finish fading. Three frames left
	# a PERFECT! sitting in the middle of a shot that is about the banner.
	await _frames(24)
	await _shot("17_reconnecting")
	Events.link_state.emit("")
	await _frames(2)

	# The layout editor, which is how anyone moves these anywhere else.
	var editor := LayoutEditor.new()
	add_child(editor)
	await _frames(6)
	await _shot("18_layout_editor")
	editor.free()
	await _frames(3)

	# The touch layout as the players actually see it, stick pushed up-right so
	# the jump zone is engaged -- the thing that makes running and jumping with
	# one thumb possible.
	main.input_hub._has_touch = true
	var view := Vector2(main.get_viewport().get_visible_rect().size)
	var cluster := ControlLayout.layout("shared", view, false)
	var anchor: Vector2 = cluster["stick"]["center"]
	var travel: float = ControlLayout.stick_travel(cluster["stick"])
	main.input_hub._touch_down(0, anchor + Vector2(travel * 0.95, -travel * 0.7))
	main.input_hub._touch_down(1, cluster["sprint"]["center"])
	main.input_hub.scripted = true
	await _place(Vector2(430, 300))
	await _aim(Vector2(700, 280))
	await _shot("10_touch_controls")

	# And the online runner's layout: the stick alone on the left, the actions
	# on the far thumb, and none of the guardian's furniture -- it is on the
	# other device.
	main.input_hub._touch_up(0)
	main.input_hub._touch_up(1)
	main.input_hub.solo_role = "runner"
	main.input_hub.remote_aim = false
	var solo: Dictionary = main.input_hub.cluster(view)
	var solo_anchor: Vector2 = solo["stick"]["center"]
	var solo_travel: float = ControlLayout.stick_travel(solo["stick"])
	main.input_hub._touch_down(0, solo_anchor + Vector2(solo_travel * 0.95, -solo_travel * 0.7))
	main.input_hub._touch_down(1, solo["jump"]["center"])
	main.input_hub.scripted = true
	await _place(Vector2(430, 300))
	await _shot("11_runner_online_layout")

	# The guardian's device: their tools, no stick.
	main.input_hub._touch_up(0)
	main.input_hub._touch_up(1)
	main.input_hub.solo_role = "guardian"
	main.guardian.select_slot(1)
	await _place(Vector2(430, 300))
	await _aim(Vector2(760, 200))
	await _shot("12_guardian_online_layout")
	main.input_hub.solo_role = ""

	await _the_keeper()
	await _the_open_sky()

## Stage 1-B, which needs its own world: Stage is read when the level is BUILT,
## so switching stages means throwing this one away and building another. Four
## shots, and they are the four states the fight asks the players to tell apart.
##
## This is also the only place the boss's drawing runs at all. Everything else in
## the suite is headless, and headless never calls _draw -- so a boss bar that
## divides by zero, a barricade whose rubble is drawn off the bottom of the
## world, or a core drawn behind the body are all invisible to 1,500 passing
## checks. They are visible here.
func _the_keeper() -> void:
	main.queue_free()
	await _frames(3)
	Stage.use(Stage.Which.KEEPER)
	GameState.boss_hp = -1
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(8)
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
		await _frames(2)
	main.input_hub.scripted = true
	main._respawn_timer = -1.0

	var boss: Node2D = null
	for e in get_tree().get_nodes_in_group("keeper"):
		if e is Node2D:
			boss = e
	if boss == null:
		print("  the Keeper is missing; no boss shots")
		return

	var floor_y: float = LevelKeeperData.FLOOR

	# Its own state machine, switched off. These are stills of four poses, and a
	# Keeper that is still running is a Keeper that charges into the nearest
	# barricade between the pose being set and the shutter opening -- which is
	# what the first attempt captured: a "mid-charge" shot of something already
	# reeling, twice.
	boss.set_physics_process(false)

	# The wind-up, with the charge lane drawn on the floor. The runner has a
	# barricade behind them, which is the whole skill of the fight.
	_seat(boss, 480.0, 760.0)
	boss.set("facing", -1)
	boss.call("_enter", Keeper.State.BRACE)
	boss.set("_timer", 0.22)        # nearly out of wind-up, so the lane is lit
	await _frames(4)
	await _shot("19_keeper_brace")

	# Mid-charge.
	_seat(boss, 480.0, 660.0)
	boss.set("facing", -1)
	boss.call("_enter", Keeper.State.CHARGE)
	await _frames(4)
	await _shot("20_keeper_charge")

	# Reeling, core open, shot clock running: the one second the guardian has.
	_seat(boss, 520.0, 260.0)
	boss.set("facing", 1)
	boss.call("_enter", Keeper.State.STAGGER)
	boss.set("_timer", 1.5)
	main.guardian.select_slot(3)
	await _aim(Vector2(boss.global_position.x + Balance.KEEPER_CORE_OFFSET.x,
		boss.global_position.y + Balance.KEEPER_CORE_OFFSET.y))
	await _frames(4)
	await _shot("21_keeper_core_open")

	# Act three: no barricades, the guardian's wall doing their job, and the
	# ground wave that a spent charge throws.
	GameState.boss_hp = 2
	main.level.rebuild_dynamic()
	await _frames(4)
	for e in get_tree().get_nodes_in_group("keeper"):
		if e is Node2D:
			boss = e
	boss.set_physics_process(false)
	_seat(boss, 420.0, 820.0)
	boss.set("facing", -1)
	boss.call("_enter", Keeper.State.SLAM)
	main.guardian.gauge = Balance.GAUGE_MAX
	main.guardian.select_slot(2)
	main.guardian.use_active(Vector2(250.0, floor_y - Balance.WALL_SIZE.y * 0.5))
	# The runner up on the guardian's slab with the wave going under it: the
	# whole of act three in one frame, and the platform doing the job this
	# stage invented for it.
	#
	# The first version of this shot simply threw a wave at a runner standing on
	# the floor, and under llvmpipe a "frame" is ~100ms, so by the time the
	# shutter opened the wave had hit them twice and the shot was of an empty
	# arena with a respawn pending. Which was a fair report of what the wave
	# does, and a useless picture.
	main.guardian.select_slot(1)
	var deck := Vector2(420.0, floor_y - 96.0 + Balance.PLATFORM_SIZE.y * 0.5)
	main.guardian.use_active(deck)
	await _frames(3)
	main.runner.global_position = Vector2(deck.x,
		deck.y - Balance.PLATFORM_SIZE.y * 0.5 - Balance.RUNNER_SIZE.y * 0.5)
	main.runner.velocity = Vector2.ZERO
	# Placed by hand rather than thrown by the boss, so the wave is where the
	# picture needs it however slow the software renderer is being today.
	var wave := Shockwave.new()
	wave.direction = -1
	wave.global_position = Vector2(620.0, floor_y - Balance.SHOCKWAVE_SIZE.y * 0.5)
	main.level.add_child(wave)
	await _frames(3)
	await _aim(Vector2(820.0, floor_y - 120.0))
	await _shot("22_keeper_act_three")

## Put the two of them where the shot wants them.
##
## A plain function rather than the lambda this started as. rebuild_dynamic()
## frees the Keeper and makes a new one, and a lambda that captured the old one
## kept a freed reference -- which Godot reports as "Lambda capture at index 1
## was freed" and then assigns global_position on Nil. Passing the boss in means
## the caller always hands over the one that exists now.
func _seat(boss: Node2D, runner_x: float, boss_x: float) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var floor_y: float = LevelKeeperData.FLOOR
	main._respawn_timer = -1.0
	main.runner.global_position = Vector2(runner_x, floor_y - 40.0)
	main.runner.velocity = Vector2.ZERO
	boss.global_position = Vector2(boss_x, floor_y - Balance.KEEPER_HITBOX.y * 0.5)
	boss.set("velocity", Vector2.ZERO)
	main.camera.global_position = Vector2((runner_x + boss_x) * 0.5, floor_y - 150.0)

## Stage 1-S, which needs its own world for the same reason 1-B does.
##
## And it needs these pictures more than any other stage does, because almost
## everything it added draws and does not otherwise run: a column is an Area-less
## Node2D whose whole contribution is _draw, the keels under the islands are
## decor, and headless never calls _draw at all. Sixty checks can pass on a
## stage that renders as a blue screen.
func _the_open_sky() -> void:
	main.queue_free()
	await _frames(3)
	Stage.use(Stage.Which.SKY)
	GameState.crystals_taken.clear()
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(8)
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
		await _frames(2)
	main.input_hub.scripted = true
	main._respawn_timer = -1.0

	# The edge, with the first gap in front of it and a slab on the lip: the
	# picture of what this stage asks for.
	await _place(Vector2(-460.0, LevelSkyData.EDGE - 60.0))
	main.guardian.gauge = Balance.GAUGE_MAX
	main.guardian.select_slot(1)
	main.guardian.use_active(Vector2(-320.0,
		LevelSkyData.EDGE + Balance.PLATFORM_SIZE.y * 0.5))
	await _aim(Vector2(-320.0, LevelSkyData.EDGE - 30.0))
	await _shot("23_sky_the_edge")

	# Mid-flight, on the line the crystals hang along.
	await _place(Vector2(10.0, LevelSkyData.A - 308.0),
		Vector2(760.0, -180.0))
	await _aim(Vector2(300.0, LevelSkyData.A - 260.0))
	await _shot("24_sky_in_the_air")

	# The column, with the runner in it. This is the stage's one new thing and
	# the only frame that shows what it looks like.
	await _place(Vector2(3500.0, 240.0), Vector2(520.0, -200.0))
	main.camera.global_position = Vector2(3480.0, 180.0)
	await _aim(Vector2(3620.0, 120.0))
	await _shot("25_sky_the_column")

	# The gates, open across the last gap, with nothing underneath.
	main.guardian.clear_constructs()
	await _place(Vector2(7080.0, LevelSkyData.E - 60.0))
	main.guardian.gauge = Balance.GAUGE_MAX
	main.guardian.select_slot(4)
	main.guardian.use_active(Vector2(7220.0, LevelSkyData.E - 70.0))
	main.guardian.use_active(Vector2(8440.0, LevelSkyData.GOAL_TOP - 70.0))
	await _frames(4)
	main.camera.global_position = Vector2(7400.0, LevelSkyData.E - 120.0)
	await _aim(Vector2(7700.0, LevelSkyData.E - 150.0))
	await _shot("26_sky_the_gates")
