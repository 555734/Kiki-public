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
