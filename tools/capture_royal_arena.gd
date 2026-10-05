extends Node
func _ready() -> void:
	call_deferred("capture")
func capture() -> void:
	get_window().size = Vector2i(1280, 720)
	VersusLaunch.clear()
	VersusLaunch.how = VersusLaunch.How.SOLO
	var arena := preload("res://src/versus/versus_main.tscn").instantiate()
	add_child(arena)
	for i in 100: await get_tree().physics_frame
	arena.touch_solo = true
	arena.input.hubs[0].assume_touch()
	arena._build_controls()
	arena.set_physics_process(false)
	for runner in arena.runners: runner.set_physics_process(false)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/royal-review"))
	get_viewport().get_texture().get_image().save_png("res://build/royal-review/gameplay.png")
	arena._camera.zoom = Vector2.ONE * 0.38
	arena._camera.global_position = Vector2(1600, 190)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/royal-review/overview.png")
	get_tree().quit()
