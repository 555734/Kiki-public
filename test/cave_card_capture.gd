extends Node
## Capture the implemented 1-8 stage in the portrait stage-card viewport.

const MainScene: PackedScene = preload("res://src/main.tscn")

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_size(Vector2i(432, 840))
	get_window().size = Vector2i(432, 840)
	Stage.use(Stage.Which.CAVE)
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
	main.runner.set_physics_process(false)
	main.runner.global_position = Vector2(280, 1157)
	main.runner.velocity = Vector2.ZERO
	main.camera.zoom = Vector2.ONE * 1.45
	for _i in 6:
		await get_tree().physics_frame
		main.camera.global_position = Vector2(0, 1140)
	for _i in 4:
		await get_tree().process_frame
	main.camera.global_position = Vector2(0, 1140)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://assets/menu/card_1_8.png")
	print("captured card_1_8.png ", image.get_size())
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
