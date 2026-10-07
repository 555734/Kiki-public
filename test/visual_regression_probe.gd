extends Node
## Frozen real scenes, not a reimplementation of their drawing code.
const BASE := "res://test/visual_baselines/"
const ACTUAL := "res://build/visual-regression/"
const TILE := 64
const CHANNEL_TOLERANCE := 48
const TILE_RATIO := 0.04
var failures := 0

func _ready() -> void:
	call_deferred("run")

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is Timer:
		node.stop()
	if node is CanvasItem:
		node.queue_redraw()
	for child in node.get_children():
		freeze(child)

func different_tiles(reference: Image, actual: Image) -> int:
	if reference.get_size() != actual.get_size():
		return 999
	reference.convert(Image.FORMAT_RGBA8)
	actual.convert(Image.FORMAT_RGBA8)
	var a := reference.get_data()
	var b := actual.get_data()
	var bad := 0
	for ty in range(0, actual.get_height(), TILE):
		for tx in range(0, actual.get_width(), TILE):
			var changed := 0
			var count := 0
			for y in range(ty, mini(ty + TILE, actual.get_height())):
				for x in range(tx, mini(tx + TILE, actual.get_width())):
					var offset := (y * actual.get_width() + x) * 4
					count += 1
					if absi(a[offset] - b[offset]) > CHANNEL_TOLERANCE or \
						absi(a[offset + 1] - b[offset + 1]) > CHANNEL_TOLERANCE or \
						absi(a[offset + 2] - b[offset + 2]) > CHANNEL_TOLERANCE:
						changed += 1
			if float(changed) / count > TILE_RATIO:
				bad += 1
	return bad

func run() -> void:
	# No dependence on the runner machine's locale or Japanese system fonts.
	TranslationServer.set_locale("en")
	get_window().size = Vector2i(1280, 720)
	Clock.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ACTUAL))
	var update := OS.get_cmdline_user_args().has("--write-baseline")
	var selection := "all"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): selection = arg.trim_prefix("--stage=")
	if selection not in ["all", "1-1", "1-2", "1-3", "1-4", "1-5", "1-6", "1-7", "1-8", "royal-arena"]:
		push_error("Invalid visual stage selection")
		get_tree().quit(1)
		return
	for which in [Stage.Which.GREENFIELD, Stage.Which.HORROR, Stage.Which.SKYWARD_RUINS,
		Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.DESERT, Stage.Which.TOWER, Stage.Which.CAVE,
		Stage.Which.ROYAL_ARENA]:
		seed(42)
		Clock.reset()
		Stage.use(which)
		var key := "royal-arena" if which == Stage.Which.ROYAL_ARENA else Stage.stage_number()
		if selection != "all" and key != selection: continue
		var scene: Node
		var name: String
		if which == Stage.Which.ROYAL_ARENA:
			VersusLaunch.clear()
			VersusLaunch.how = VersusLaunch.How.SOLO
			scene = preload("res://src/versus/versus_main.tscn").instantiate()
			add_child(scene)
			scene.touch_solo = true
			scene.input.hubs[0].assume_touch()
			scene._build_controls()
			name = "royal-arena"
		else:
			scene = preload("res://src/main.tscn").instantiate()
			add_child(scene)
			scene.input_hub.scripted = true
			scene.input_hub.assume_touch()
			scene.get_node("NetPanel").free()
			name = "stage-" + Stage.stage_number()
		await capture(scene, name, update)
		if which in [Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.DESERT, Stage.Which.TOWER, Stage.Which.CAVE]:
			if which in [Stage.Which.DESERT, Stage.Which.SWAMP]:
				# The added upper-tier views review geometry and machinery. Keep
				# controls out of the way, as in the whole-stage map; the start
				# view and dedicated UI probes still cover the interactive HUD.
				scene.hud.visible = false
			# Teleporting the frozen runner must not fire checkpoint/goal areas,
			# which would make the reference contain a transient screen flash.
			for area in scene.find_children("*", "Area2D", true, false):
				area.set_deferred("monitoring", false)
			await get_tree().process_frame
			var rooms: Array[Dictionary] = Stage.data().rooms()
			var last_view := "end" if which in [Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.DESERT] else "top"
			for view in [["middle", rooms[rooms.size() / 2]], [last_view, rooms[-1]]]:
				var exit: Rect2 = view[1]["exit"]
				scene.runner.global_position = Vector2(exit.get_center().x, exit.position.y - 26)
				scene._snap_camera_to_runner()
				scene.camera.reset_smoothing()
				await capture(scene, name + "-" + view[0], update)
			if which == Stage.Which.SWAMP:
				# At tick zero these authored phases expose both new active
				# sprites, rather than comparing only harmless cooldown poses.
				for kind in ["geyser", "meteor"]:
					var phase := 2.0 if kind == "geyser" else 1.7
					var hazard: Dictionary = Stage.gimmicks().filter(func(s: Dictionary) -> bool:
						return s["type"] == "volcanic_hazard" and s["kind"] == kind and s["phase"] == phase)[0]
					scene.runner.position = hazard["pos"] + hazard["travel"] * 0.5 + Vector2(-140, 0)
					scene._snap_camera_to_runner(); scene.camera.reset_smoothing()
					await capture(scene, name + "-" + kind, update)
		scene.free()
		await get_tree().process_frame
	print("visual regression: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func capture(scene: Node, name: String, update: bool) -> void:
	freeze(scene)
	# Main enables the global clock when it starts a stage. Freezing only the
	# scene leaves that autoload ticking while we await rendering frames.
	Clock.set_physics_process(false)
	Clock.reset()
	for _i in 3:
		await get_tree().process_frame
		freeze(scene)
	await RenderingServer.frame_post_draw
	if Clock.tick != 0:
		print("FAIL visual clock advanced during frozen capture: ", Clock.tick)
		failures += 1
	var frame := get_viewport().get_texture().get_image()
	if frame.get_size() != Vector2i(1280, 720):
		push_error("Visual probe needs a 1280x720 viewport")
		get_tree().quit(1)
		return
	frame.save_png(ACTUAL + name + ".png")
	if update:
		frame.save_png(BASE + name + ".png")
	elif not FileAccess.file_exists(BASE + name + ".png"):
		print("FAIL visual baseline missing: ", name)
		failures += 1
	else:
		var expected := Image.load_from_file(BASE + name + ".png")
		var bad := different_tiles(expected, frame)
		print("visual ", name, ": ", bad, " changed tiles")
		if bad > 0:
			print("FAIL visual ", name)
			failures += 1
	# Prove the comparator rejects a visible missing/covered patch.
	var changed: Image = frame.duplicate()
	changed.fill_rect(Rect2i(128, 128, 40, 40), Color.MAGENTA)
	if different_tiles(frame, changed) == 0:
		print("FAIL visual comparator missed a visible mutation")
		failures += 1
