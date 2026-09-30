extends LevelBuilder
## Builds the 2v2 star arena out of 1-1's pieces: its terrain painter, its
## decor painter and its kill plane, fed VersusStageData instead of
## Level01Data. Nothing of 1-1's course is built -- no enemies, no hazards, no
## checkpoints, no goal -- so every machine's world is exactly the data, with
## nothing simulated locally that the other three would have to agree about.
##
## The cooperative builder and Level01Data are unchanged.

func _init() -> void:
	co_op_extras = false

func build() -> void:
	_static_root = Node2D.new()
	_static_root.name = "Static"
	add_child(_static_root)

	_terrain = preload("res://src/render/terrain.gd").new()
	_terrain.slabs = VersusStageData.painted_slabs()
	_static_root.add_child(_terrain)
	_build_ground_bodies()

	_decor = preload("res://src/render/decor.gd").new()
	_decor.items = VersusStageData.decor()
	_static_root.add_child(_decor)

	_build_kill_plane()
	# Kept, empty, so code that looks for the Dynamic node finds one.
	_dynamic = Node2D.new()
	_dynamic.name = "Dynamic"
	add_child(_dynamic)

func _build_ground_bodies() -> void:
	var body := StaticBody2D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	for rect in VersusStageData.collision_rects():
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)
	_static_root.add_child(body)

func _build_kill_plane() -> void:
	var pit := Hazard.new()
	pit.draw_spikes = false
	pit.span = Vector2(VersusStageData.WIDTH + 2.0 * VersusStageData.WALL_THICKNESS + 800.0, 200)
	pit.global_position = Vector2(VersusStageData.WIDTH * 0.5,
		VersusStageData.kill_y() + 100.0)
	_static_root.add_child(pit)

func rebuild_dynamic() -> void:
	pass # The arena has nothing dynamic of its own.

func reset_to_checkpoint() -> void:
	pass
