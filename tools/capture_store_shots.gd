extends Node
## Renders the App Store / Google Play screenshots from the real game.
##
##   godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --resolution 2868x1320 \
##       tools/capture_store_shots.tscn --fixed-fps 60 -- --ci-skip-eos
##
## The resolution on the command line IS the screenshot size, because both
## stores reject an image that is not exactly one of their sizes and resizing
## a 1280x720 render to 2868x1320 gives a soft picture with the wrong aspect.
## docs/store-listing.md lists which sizes each store wants.
##
## Unlike tools/capture_stage_cards.gd this keeps the HUD and the guardian's
## ability rings. A store screenshot is meant to show the game as it is
## played; a card is meant to show the place.
##
## Files land in user://store/<width>x<height>/.

const MainScene: PackedScene = preload("res://src/main.tscn")

## Where the runner is put, and how long to let the camera settle. The camera
## is NOT overridden: it frames the runner the way it does in play, which is
## the framing a player will recognise from the screenshot.
const SHOTS := [
	{"which": Stage.Which.GREENFIELD, "file": "01_greenfield.png",
		"runner": Vector2(1700, 300)},
	{"which": Stage.Which.HORROR, "file": "02_hollow_outskirts.png",
		"runner": Vector2(5900, 240)},
	{"which": Stage.Which.SKYWARD_RUINS, "file": "03_skyward_ruins.png",
		"runner": Vector2(-260, 5600)},
	{"which": Stage.Which.SEA, "file": "04_sunlit_coast.png",
		"runner": Vector2(1940, 290)},
	{"which": Stage.Which.SWAMP, "file": "05_poison_marsh.png",
		"runner": Vector2(1024, 330)},
]

## The project's own design size. Every Control is laid out against this and
## then scaled up, which is what the game does on a device.
const DESIGN := Vector2i(1280, 720)

var _dir := ""
var _view: SubViewport = null

func _ready() -> void:
	call_deferred("run")

func _flag(name: String) -> bool:
	return OS.get_cmdline_user_args().has(name)

func _shot_size() -> Vector2i:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot-size" and i + 1 < args.size():
			var parts: PackedStringArray = String(args[i + 1]).split("x")
			if parts.size() == 2:
				return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i(2868, 1320)

func run() -> void:
	var size := _shot_size()
	_view = SubViewport.new()
	_view.size = size
	# Lay out at the design size, rasterise at the store's size.
	_view.size_2d_override = DESIGN
	_view.size_2d_override_stretch = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.transparent_bg = false
	add_child(_view)
	_dir = "user://store/%dx%d%s" % [size.x, size.y, "-nohud" if _flag("--no-hud") else ""]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	await _start_screen()
	for shot in SHOTS:
		await _capture(shot)
	print("store shots written to ", ProjectSettings.globalize_path(_dir))
	get_tree().quit()

## The screen a player sees first: five stage cards, three of them locked.
## It is the one shot that explains the price without a word of copy.
func _start_screen() -> void:
	var main: Node2D = MainScene.instantiate()
	_view.add_child(main)
	for _i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("00_stage_select.png")
	main.queue_free()
	await get_tree().process_frame

func _capture(shot: Dictionary) -> void:
	Stage.use(int(shot["which"]))
	var main: Node2D = MainScene.instantiate()
	_view.add_child(main)
	await get_tree().process_frame
	# The home screen covers the game, and the placement ghost is a dashed
	# outline that follows a finger nobody is holding here -- in a still it
	# reads as an unfinished overlay rather than as aiming. Everything else on
	# screen belongs in the picture.
	var strip := ["NetPanel", "PlacementPreview"]
	# --no-hud strips the interface as well. That is not a screenshot -- a
	# store screenshot must show the real thing -- it is for the Play feature
	# graphic, which is a banner the title is set over.
	if _flag("--no-hud"):
		strip.append_array(["Hud", "Scope"])
	for name in strip:
		var node := main.get_node_or_null(name)
		if node != null:
			node.queue_free()
	main.input_hub.scripted = true
	await get_tree().process_frame
	main.runner.global_position = shot["runner"]
	main.runner.velocity = Vector2.ZERO
	# Let the camera catch up to the runner the way it does in play, then let
	# the parallax and the HUD settle on top of it.
	for _i in 30:
		await get_tree().physics_frame
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(String(shot["file"]))
	main.queue_free()
	await get_tree().process_frame

func _save(file: String) -> void:
	var image := _view.get_texture().get_image()
	image.save_png(_dir + "/" + file)
	print("captured ", file, " ", image.get_size())
