extends Node
## Optional visual review of 1-9, one shot per obstacle and one of each place
## whole. Screenshots go under ignored build/ only.

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
	var shots: Array = []
	for section in LevelCastleData.sections():
		var x := float(section["focus"])
		shots.append([section["name"], Vector2(x, 240.0 if x < LevelCastleData.KEEP_X else -160.0), 1.0])
	# Each of the three places whole, as a wide still camera holds it.
	shots.append(["the gorge", Vector2(1500, 230), 0.62])
	shots.append(["the gatehouse", Vector2(3600, 230), 0.62])
	shots.append(["the keep", Vector2(5500, 0), 0.55])
	var k := 0
	for shot in shots:
		main.camera.zoom = Vector2.ONE * float(shot[2])
		for _i in 5:
			await get_tree().physics_frame
			main.camera.global_position = shot[1]
		await get_tree().process_frame
		main.camera.global_position = shot[1]
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://build/castle_review_%d.png" % k)
		print("captured castle_review_%d.png %s" % [k, shot[0]])
		k += 1
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
