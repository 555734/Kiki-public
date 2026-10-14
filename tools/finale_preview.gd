extends Node
## Renders 1-10 at a list of world points (runner placed there, live world).
## Needs a display:
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 res://tools/finale_preview.tscn -- [out_dir] [x,y,name,ticks ...]
## Without points, one frame per area at its checkpoint.
const MainScene: PackedScene = preload("res://src/main.tscn")

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	get_window().size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var out := "res://build/stage-1-10/preview/"
	if args.size() > 0 and not args[0].contains(","):
		out = args[0]
		args = args.slice(1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
	Stage.use(Stage.Which.FINALE)
	var points: Array = []
	for a in args:
		var f: PackedStringArray = a.split(",")
		points.append([Vector2(float(f[0]), float(f[1])), f[2] if f.size() > 2 else "%s_%s" % [f[0], f[1]],
			int(f[3]) if f.size() > 3 else 20])
	if points.is_empty():
		var i := 0
		points.append([Stage.start(), "00_start", 20])
		for cp in Stage.checkpoints():
			i += 1
			points.append([cp + Vector2(0, 26), "%02d_cp" % i, 20])
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.input_hub.scripted = true
	main.get_node("NetPanel").queue_free()
	for name in ["Hud", "Quit", "PlacementPreview", "Scope"]:
		var n := main.get_node_or_null(name)
		if n != null: n.queue_free()
	await get_tree().process_frame
	for p in points:
		main.runner.respawn(p[0])
		main._snap_camera_to_runner()
		for _i in int(p[2]):
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var path: String = out.path_join(String(p[1]) + ".png")
		get_viewport().get_texture().get_image().save_png(path)
		print("preview ", p[1], " runner=", main.runner.global_position)
	get_tree().quit()
