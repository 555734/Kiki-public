extends Node
## Renders the stage-select card art from the real stages.
##
## The menu cards are tall, so the shots are taken through a portrait window
## rather than cropped out of a 16:9 screenshot -- a centre crop of a
## side-scrolling screenshot is a narrow column of sky, which is what the old
## cards were. Run with:
##
##   xvfb-run -a godot --path . tools/capture_stage_cards.tscn --fixed-fps 60
##
## and commit the PNGs it writes to assets/menu/.

const MainScene: PackedScene = preload("res://src/main.tscn")
## Twice the on-screen card, at the card's own 0.514 aspect, so the menu
## shows the whole shot instead of cover-cropping the sides off it.
const SHOT := Vector2i(432, 840)

## Where each card looks from, and how tight. `at` is the camera's world
## position; `zoom` trades sky for detail.
const SHOTS := [
	# The spring on the step-up ledge, with its coin arc overhead.
	{"which": Stage.Which.GREENFIELD, "file": "card_1_1.png",
		"at": Vector2(1790, 140), "zoom": 2.6, "runner": Vector2(1700, 300)},
	# The village ledge: a lantern, a wisp and a crow under the church spire,
	# which is as much warmth and as much silhouette as 1-2 owns.
	{"which": Stage.Which.HORROR, "file": "card_1_2.png",
		"at": Vector2(5990, 210), "zoom": 3.6, "runner": Vector2(5900, 240)},
	# The one stage that is already a tall picture: islands stacked to the top.
	{"which": Stage.Which.SKYWARD_RUINS, "file": "card_1_3.png",
		"at": Vector2(0, 5250), "zoom": 1.8, "runner": Vector2(-260, 5600)},
	# The sea stacks, with the breeze off the highest one. The old card was a
	# beach, and the stage stopped being a beach when it was rebuilt.
	{"which": Stage.Which.SEA, "file": "card_1_4.png",
		"at": Vector2(4720, -180), "zoom": 2.5, "runner": Vector2(4800, -220)},
	# Two stepping stones and the gap between them, which is the whole stage.
	{"which": Stage.Which.SWAMP, "file": "card_1_5.png",
		"at": Vector2(1120, 300), "zoom": 2.9, "runner": Vector2(1024, 330)},
]

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_size(SHOT)
	get_window().size = SHOT
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/menu"))
	for shot in SHOTS:
		await _capture(shot)
	get_tree().quit()

func _capture(shot: Dictionary) -> void:
	Stage.use(int(shot["which"]))
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	# The card is the stage, not the interface: the home screen, the HUD and
	# the guardian's two ability rings all belong to the live game.
	for name in ["NetPanel", "Hud", "PlacementPreview", "Scope"]:
		var node := main.get_node_or_null(name)
		if node != null:
			node.queue_free()
	main.input_hub.scripted = true
	await get_tree().process_frame
	main.runner.global_position = shot["runner"]
	main.runner.velocity = Vector2.ZERO
	main.camera.zoom = Vector2.ONE * float(shot["zoom"])
	for _i in 6:
		await get_tree().physics_frame
		main.camera.global_position = shot["at"]
	for _i in 4:
		await get_tree().process_frame
	main.camera.global_position = shot["at"]
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://assets/menu/" + String(shot["file"]))
	print("captured ", shot["file"], " ", image.get_size())
	main.queue_free()
	await get_tree().process_frame
