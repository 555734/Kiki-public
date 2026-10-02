extends Node
## Review 1-6 at the actual game viewport and render its menu card.

const MainScene: PackedScene = preload("res://src/main.tscn")

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	Stage.use(Stage.Which.DESERT)
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	for _i in 5:
		await get_tree().process_frame
	main.get_node("NetPanel").queue_free()
	main.input_hub.scripted = true
	await get_tree().process_frame
	await _shot(main, Vector2(2650, 120), "res://build/desert-crumble.png")
	await _shot(main, Vector2(3900, 130), "res://build/desert-gap.png")
	await _shot(main, Vector2(4900, 120), "res://build/desert-lift.png")
	await _shot(main, Vector2(5800, -10), "res://build/desert-blink.png")
	await _shot(main, Vector2(7130, 125), "res://build/desert-oracle.png")
	await _shot(main, Vector2(9000, 265), "res://build/desert-finale.png")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _shot(main: Node2D, at: Vector2, file: String) -> void:
	main.runner.global_position = at
	main.runner.velocity = Vector2.ZERO
	main.camera.global_position = at
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(file)
	print("captured ", file)
