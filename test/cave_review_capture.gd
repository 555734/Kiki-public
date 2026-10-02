extends Node
## Optional visual review. Screenshots go under ignored build/ only.

const MainScene: PackedScene = preload("res://src/main.tscn")
const SHOTS := [
	["cart", 1210.0, 310.0], ["vent", 3000.0, 240.0],
	["boulder", 3800.0, 200.0], ["bridge", 5500.0, 180.0],
	["gate", 6150.0, 180.0], ["first_finale", 9150.0, 225.0],
	["deep_cart", 12845.0, 230.0], ["deep_bridge", 13650.0, 200.0],
	["last_bridge", 18700.0, 175.0], ["last_cart", 20385.0, 215.0],
	["key_run", 22300.0, 180.0], ["goal", 23130.0, 230.0],
]

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	get_window().size = Vector2i(1280, 720)
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
	main.runner.visible = false
	main.set_process(false)
	main.set_physics_process(false)
	main.camera.zoom = Vector2.ONE * 1.5
	for shot in SHOTS:
		for _i in 5:
			await get_tree().physics_frame
			main.camera.global_position = Vector2(shot[1], shot[2])
		await get_tree().process_frame
		main.camera.global_position = Vector2(shot[1], shot[2])
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://build/cave_review_%s.png" % shot[0])
		print("captured cave_review_%s.png" % shot[0])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
