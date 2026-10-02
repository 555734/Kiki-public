extends Node
## Optional visual review of four tower rooms; writes only under build/.

const MainScene: PackedScene = preload("res://src/main.tscn")
const SHOTS := [
	["entrance", 14000.0],
	["wind", 12900.0], ["piston", 12220.0],
	["portal", 11650.0], ["gate", 10900.0],
]

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	get_window().size = Vector2i(1280, 720)
	Stage.use(Stage.Which.TOWER)
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
			main.camera.global_position = Vector2(0, shot[1])
		await get_tree().process_frame
		main.camera.global_position = Vector2(0, shot[1])
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://build/tower_review_%s.png" % shot[0])
		print("captured tower_review_%s.png" % shot[0])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
