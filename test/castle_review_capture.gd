extends Node
## Optional visual review of 1-9, one shot per obstacle. Screenshots go under
## ignored build/ only.

const MainScene: PackedScene = preload("res://src/main.tscn")

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	get_window().size = Vector2i(1280, 720)
	Stage.use(Stage.Which.CASTLE)
	await get_tree().process_frame
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	for name in ["NetPanel", "Hud", "PlacementPreview", "Scope"]:
		var node := main.get_node_or_null(name)
		if node != null:
			node.queue_free()
	main.input_hub.scripted = true
	main.set_process(false)
	main.set_physics_process(false)
	main.camera.zoom = Vector2.ONE
	var k := 0
	for section in LevelCastleData.sections():
		var x := float(section["focus"])
		var y := 240.0 if x < 7500.0 else -160.0
		for _i in 5:
			await get_tree().physics_frame
			main.camera.global_position = Vector2(x, y)
		await get_tree().process_frame
		main.camera.global_position = Vector2(x, y)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://build/castle_review_%d.png" % k)
		print("captured castle_review_%d.png %s" % [k, section["name"]])
		k += 1
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
