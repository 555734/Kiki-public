extends Node
## Whole-world captures of the production LevelBuilder, without gameplay UI.
const STAGES := [Stage.Which.GREENFIELD, Stage.Which.HORROR, Stage.Which.SKYWARD_RUINS,
	Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.DESERT, Stage.Which.TOWER, Stage.Which.CAVE]
const MAX_EDGE := 12288
const MAX_PIXELS := 32_000_000
var output := "res://build/stage-maps"
var selection := "all"
var scale_factor := 0.5
var background := true
var failed := false

func _ready() -> void:
	call_deferred("run")

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is Timer: node.stop()
	if node is CanvasItem: node.queue_redraw()
	for child in node.get_children(): freeze(child)

func world_bounds() -> Rect2:
	var bounds := Rect2(Stage.start(), Vector2.ONE)
	for rect in Stage.ground() + Stage.solid_decor(): bounds = bounds.merge(rect)
	for points in [Stage.coins(), Stage.crystals(), Stage.springs(), Stage.checkpoints(), [Stage.goal()]]:
		for point in points: bounds = bounds.expand(point)
	for specs in [Stage.decor(), Stage.enemies(), Stage.gimmicks(), Stage.hazards()]:
		for spec in specs:
			if spec.has("rect"): bounds = bounds.merge(spec["rect"])
			if spec.has("pos"):
				var point: Vector2 = spec["pos"]
				var span: Vector2 = spec.get("span", spec.get("size", Vector2.ONE))
				bounds = bounds.merge(Rect2(point - span * 0.5, span))
				if spec.get("travel") is Vector2:
					bounds = bounds.merge(Rect2(point + spec["travel"] - span * 0.5, span))
	# Room for painted silhouettes above their authored feet and end markers.
	return bounds.grow(256.0)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--stage="): selection = arg.trim_prefix("--stage=")
		elif arg.begins_with("--scale="):
			var value := arg.trim_prefix("--scale=")
			if not value.is_valid_float(): failed = true
			else: scale_factor = value.to_float()
		elif arg == "--no-background": background = false
		elif arg == "--help":
			print("export_stage_maps: --stage=all|1-1..1-8 --output=PATH --scale=0.5 --no-background")
			get_tree().quit(0)
			return
		elif arg != "--ci-skip-eos": failed = true
	if failed or not is_finite(scale_factor) or scale_factor <= 0 \
		or (selection != "all" and selection not in ["1-1", "1-2", "1-3", "1-4", "1-5", "1-6", "1-7", "1-8"]):
		push_error("Invalid map options; use --help.")
		get_tree().quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("PNG rendering needs a display; use xvfb-run on Linux, not --headless.")
		get_tree().quit(1)
		return
	output = ProjectSettings.globalize_path(output)
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create output directory: " + output)
		get_tree().quit(1)
		return
	TranslationServer.set_locale("en")
	Clock.set_physics_process(false)
	var records: Array[Dictionary] = []
	for which in STAGES:
		Stage.use(which)
		if selection != "all" and selection != Stage.stage_number(): continue
		seed(42)
		Clock.reset()
		var bounds := world_bounds()
		var zoom := minf(scale_factor, float(MAX_EDGE) / maxf(bounds.size.x, bounds.size.y))
		zoom = minf(zoom, sqrt(float(MAX_PIXELS) / (bounds.size.x * bounds.size.y)))
		var dimensions := Vector2i(ceil(bounds.size.x * zoom), ceil(bounds.size.y * zoom))
		var viewport := SubViewport.new()
		viewport.size = dimensions
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
		var world := Node2D.new()
		viewport.add_child(world)
		var hub := InputHub.new()
		hub.scripted = true
		world.add_child(hub)
		var runner := Runner.new()
		runner.input_hub = hub
		runner.position = Stage.start()
		world.add_child(runner)
		runner.hide()
		var level := LevelBuilder.new()
		level.runner = runner
		level.input_hub = hub
		world.add_child(level)
		level.build()
		var camera := Camera2D.new()
		camera.position = bounds.position + Vector2(dimensions) / zoom * 0.5
		camera.zoom = Vector2.ONE * zoom
		world.add_child(camera)
		camera.make_current()
		if background:
			var sky := preload("res://src/render/sky.gd").new()
			sky.camera = camera
			world.add_child(sky)
		freeze(world)
		camera.force_update_scroll()
		await get_tree().process_frame
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var path := output.path_join("stage-" + Stage.stage_number() + ".png")
		if image == null or image.is_empty() or image.get_size() != dimensions or image.save_png(path) != OK:
			push_error("Failed to save map: " + path)
			failed = true
		else:
			print("map ", Stage.stage_number(), " ", dimensions, " scale=", zoom, " -> ", path)
			records.append({"stage": Stage.stage_number(), "name": Stage.stage_name(),
				"png": path.get_file(), "width": dimensions.x, "height": dimensions.y,
				"scale": zoom, "world_origin": [bounds.position.x, bounds.position.y],
				"world_size": [bounds.size.x, bounds.size.y], "clock_tick": Clock.tick})
		viewport.free()
		await get_tree().process_frame
	var manifest := FileAccess.open(output.path_join("maps.json"), FileAccess.WRITE)
	if manifest == null: failed = true
	else:
		manifest.store_string(JSON.stringify({"version": ProjectSettings.get_setting("application/config/version"),
			"background": background, "seed": 42, "maps": records}, "\t") + "\n")
		manifest.close()
	Stage.use(Stage.Which.GREENFIELD)
	get_tree().quit(1 if failed else 0)
