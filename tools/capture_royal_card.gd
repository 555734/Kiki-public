extends Node
## Renders the Royal Arena's stage tile on the スターたいせん room screen from
## the real arena: the whole sky kingdom with its floating platforms, banners,
## the star and the runners. Run with:
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 tools/capture_royal_card.tscn
##
## and commit the PNG it writes to assets/menu/.

const SHOT := Vector2i(1040, 600)
const FILE := "res://assets/menu/card_royal.png"
const CENTRE := Vector2(1600.0, 215.0)
const ZOOM := 0.62

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_size(SHOT)
	get_window().size = SHOT
	await get_tree().process_frame
	VersusLaunch.clear()
	VersusLaunch.how = VersusLaunch.How.SOLO
	var arena: Node = load("res://src/versus/versus_main.tscn").instantiate()
	add_child(arena)
	for _i in 100:
		await get_tree().physics_frame
	# The picture is the arena, not its interface.
	var hud := arena.get_node_or_null("Hud")
	if hud != null:
		hud.queue_free()
	arena.set_physics_process(false)
	for runner in arena.runners:
		runner.set_physics_process(false)
	arena._camera.zoom = Vector2.ONE * ZOOM
	arena._camera.global_position = CENTRE
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(FILE)
	print("captured ", FILE, " ", image.get_size())
	VersusLaunch.clear()
	get_tree().quit()
