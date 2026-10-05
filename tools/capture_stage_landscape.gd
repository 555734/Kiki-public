extends Node
## Capture the normal gameplay viewport, including HUD and touch controls.
const MainScene: PackedScene = preload("res://src/main.tscn")

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	assert(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	assert(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280)
	assert(ProjectSettings.get_setting("display/window/size/viewport_height") == 720)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/landscape"))
	for stage in [Stage.Which.HORROR, Stage.Which.SKYWARD_RUINS, Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.DESERT, Stage.Which.TOWER, Stage.Which.CAVE]:
		Stage.use(stage)
		var main: Node2D = MainScene.instantiate()
		add_child(main)
		await get_tree().process_frame
		main.input_hub.scripted = true
		main.input_hub.assume_touch()
		main.get_node("NetPanel").queue_free()
		await get_tree().process_frame
		for _i in 12:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		assert(frame.get_width() == 1280 and frame.get_height() == 720)
		frame.save_png("res://build/landscape/stage-" + Stage.stage_number() + ".png")
		print("landscape ", Stage.stage_number(), " ", frame.get_size())
		if Art.late_pack() != "":
			var checkpoints := Stage.checkpoints()
			var cp: Vector2 = checkpoints[mini(2, checkpoints.size() - 1)]
			main.runner.global_position = cp + Vector2(0, 10)
			main.runner.velocity = Vector2.ZERO
			main.camera.global_position = cp + Vector2(0, -110)
			for _i in 8: await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/landscape/stage-" + Stage.stage_number() + "-detail.png")
		# A still-frame art inspection: bring the existing chaser into camera view.
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy.get_script() == preload("res://src/entities/enemies/sky_pursuer.gd"):
				enemy.set_physics_process(false)
				enemy.global_position = main.runner.global_position + Vector2(-175, -15)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/landscape/stage-" + Stage.stage_number() + "-chaser.png")
		main.queue_free()
		await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	get_tree().quit()
