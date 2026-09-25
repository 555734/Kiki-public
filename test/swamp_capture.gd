extends Node
## Optional visual check of stage 1-5. Writes a start and stepping-stone shot
## to build/ so art changes can be reviewed at the actual 1280x720 viewport.

const MainScene: PackedScene = preload("res://src/main.tscn")

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	Stage.use(Stage.Which.SWAMP)
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/swamp-menu.png")
	main.get_node("NetPanel").queue_free()
	main.input_hub.scripted = true
	for _i in 4:
		await get_tree().process_frame
	await _shot(main, Vector2(-850, 340), "swamp-start.png")
	await _shot(main, Vector2(1050, 315), "swamp-stones.png")
	main.queue_free()
	get_tree().quit()

func _shot(main: Node2D, at: Vector2, name: String) -> void:
	main.runner.global_position = at
	main.runner.velocity = Vector2.ZERO
	main.camera.global_position = at + Vector2(0, -40)
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://build/" + name)
	print("captured ", name)
