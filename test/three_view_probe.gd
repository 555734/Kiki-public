extends Node
## Character-only 2.5D regression probe. The old version asserted that terrain,
## enemies and props were 3D; this one asserts the opposite.

var failures := 0

func check(ok: bool, label: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", label])
	if not ok: failures += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	main.get_node("NetPanel").queue_free()
	GameState.running = true
	for i in 40: await get_tree().process_frame
	var view = main.get_node("Character3D")
	check(view.bindings.size() == 1, "only the controllable Runner receives a 3D model")
	check(view.viewport3d.gui_disable_input and view.display.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"character composition never intercepts touch input")
	check(view.viewport3d.msaa_3d == Viewport.MSAA_DISABLED and view.viewport3d.size.x <= 720,
		"mobile viewport is capped at 720px with MSAA disabled")
	check(main.level._terrain.self_modulate.a > 0.99, "original 2D terrain remains visible")
	check(not Balance.USE_3D and Balance.USE_3D_RUNNER, "full-world 3D is disabled")
	var binding: Dictionary = view.bindings[main.runner.get_instance_id()]
	check(binding.model.get_child_count() > 0, "Blender GLB contains a model hierarchy")
	for animation in ["idle", "run", "jump", "fall", "land", "dash", "hurt", "dead"]:
		check(binding.animations.has(animation), "Blender action imported: " + animation)

	for zoom in [0.8, 1.5, 2.4]:
		main.camera.zoom = Vector2.ONE * zoom
		main.camera.force_update_scroll()
		view._sync_camera()
		var feet: Vector2 = main.runner.global_position + Vector2(0, Balance.RUNNER_SIZE.y * 0.5)
		var screen: Vector2 = get_viewport().get_canvas_transform() * feet
		var model_feet: Vector3 = binding.model.position - Vector3(0, view.MODEL_FOOT_OFFSET, 0)
		var projected: Vector2 = view.camera3d.unproject_position(model_feet)
		projected *= view.display.size / Vector2(view.viewport3d.size)
		check(screen.distance_to(projected) < 1.0, "2D/3D feet align at zoom %.1f" % zoom)
	main.camera.zoom = Vector2.ONE * 1.5
	for i in 5: await get_tree().process_frame

	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/character-only-greenfield.png")
		print("render driver: ", RenderingServer.get_current_rendering_method(),
			"; adapter: ", RenderingServer.get_video_adapter_name())
		print("draw calls: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"; primitives: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))

	main.input_hub.scripted = true
	main.input_hub.set_process(true)
	main.input_hub.move_axis = 1.0
	var start_x: float = main.runner.position.x
	for i in 24: await get_tree().physics_frame
	check(main.runner.position.x > start_x + 20.0 and binding.current == "run",
		"actual Runner movement selects the imported Run action")
	main.input_hub.move_axis = 0.0
	main.input_hub.press_jump()
	var observed := {}
	for i in 100:
		if i == 18: main.input_hub.release_jump()
		await get_tree().physics_frame
		observed[binding.current] = true
	check(observed.has("jump") and observed.has("fall") and observed.has("land"),
		"physical jump selects Jump, Fall and Land actions")
	check(main.runner.on_ground(), "character presentation preserves ground contact")

	for window_size in [Vector2i(1600, 720), Vector2i(960, 720)]:
		get_tree().root.size = window_size
		for i in 4: await get_tree().process_frame
		view._sync_camera()
		var feet: Vector2 = main.runner.global_position + Vector2(0, Balance.RUNNER_SIZE.y * 0.5)
		var screen: Vector2 = get_viewport().get_canvas_transform() * feet
		var model_feet: Vector3 = binding.model.position - Vector3(0, view.MODEL_FOOT_OFFSET, 0)
		var projected: Vector2 = view.camera3d.unproject_position(model_feet)
		projected *= view.display.size / Vector2(view.viewport3d.size)
		check(screen.distance_to(projected) < 1.0, "resize %s keeps character aligned" % window_size)
		check(view.viewport3d.size.x <= 720, "resize %s respects render cap" % window_size)
	get_tree().root.size = Vector2i(1280, 720)

	var samples: Array[float] = []
	var stamp := Time.get_ticks_usec()
	for i in 100:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if i > 20: samples.append(float(now - stamp) / 1000.0)
		stamp = now
	samples.sort()
	if DisplayServer.get_name() != "headless":
		print("desktop character frame ms median=%.2f p95=%.2f" % [
			samples[samples.size() / 2], samples[int(samples.size() * .95)]])

	main.queue_free()
	await get_tree().process_frame
	for stage_id in range(1, 7):
		Stage.use(stage_id)
		main = load("res://src/main.tscn").instantiate()
		add_child(main)
		main.get_node("NetPanel").queue_free()
		GameState.running = true
		if stage_id == Stage.Which.KEEPER: main.runner.respawn(Vector2(250, 340))
		for i in 8: await get_tree().process_frame
		view = main.get_node("Character3D")
		check(view.bindings.size() == 1, "stage %d keeps 3D limited to Runner" % stage_id)
		check(main.level._terrain.self_modulate.a > 0.99,
			"stage %d keeps original 2D terrain visible" % stage_id)
		main.queue_free()
		await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	print("character-only view probe: %d failed" % failures)
	get_tree().quit(0 if failures == 0 else 1)
