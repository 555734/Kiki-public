extends Node
## Review stills from the production scenes; no replacement art or colliders.
const OUT := "res://build/review-20261018/"
const MAIN := preload("res://src/main.tscn")

func _ready() -> void:
	call_deferred("run")

func save(name_: String) -> void:
	for i in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name_ + ".png")
	print("REVIEW_CAPTURE ", name_)

func run() -> void:
	TranslationServer.set_locale("en" if "--english" in OS.get_cmdline_user_args() else "ja")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Stage.use(Stage.Which.GREENFIELD)
	var menu := MAIN.instantiate()
	add_child(menu)
	await get_tree().process_frame
	var panel: NetPanel = menu.get_node("NetPanel")
	for i in StageSelectView.page_count():
		panel._change_stage_page(i - panel._stage_page)
		await save("menu-%d" % (i+1))
	menu.free()
	await get_tree().process_frame
	Stage.use(Stage.Which.PARADE)
	var main := MAIN.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("NetPanel").free()
	main.resume_from_home(true)
	# The menu resumes the stage on a deferred call. Let it finish before
	# freezing the review clock, just as the real performance probe does.
	await get_tree().process_frame
	await get_tree().process_frame
	main.input_hub.scripted = true
	main.set_process(false)
	main.set_physics_process(false)
	Clock.set_physics_process(false)
	Clock.reset(60)
	for e in get_tree().get_nodes_in_group("enemy"): e.set_physics_process(false)
	for i in Stage.data().acts().size():
		var act: Dictionary = Stage.data().acts()[i]
		main.runner.global_position = Stage.start() if i == 0 else Stage.checkpoints()[i-1]
		main.runner.velocity = Vector2.ZERO
		Clock.reset(60)
		main.runner.set_physics_process(false)
		main.camera.set_process(false)
		main.camera.set_physics_process(false)
		main.camera.position_smoothing_enabled = false
		main.camera.global_position = Vector2(float(act.from) + 500, 300)
		main.camera.zoom = Vector2.ONE
		main.camera.reset_smoothing()
		for device in get_tree().get_nodes_in_group("parade_device"):
			device.pose_at(Clock.tick)
			device.queue_redraw()
		await save("parade-act-%d" % (i+1))
	main.free()
	await get_tree().process_frame
	get_tree().quit()
