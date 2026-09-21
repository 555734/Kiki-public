extends Node
## godot --headless --path . res://tools/export_three_assets.tscn
## Writes editable, standalone rest-pose prefabs from the same recipes used at
## runtime. Animation remains in lira.gd / enemy_model.gd, not baked into physics.
const Lira=preload("res://src/render/three/lira.gd")
const EnemyModel=preload("res://src/render/three/enemy_model.gd")
const Assets=preload("res://src/render/three/assets.gd")
var manifest: Dictionary={}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/models")
	for path in ["res://src/render/three/assets.gd","res://src/render/three/lira.gd",
		"res://src/render/three/enemy_model.gd","res://src/render/three/mesh_recipe.gd",
		"res://src/render/three/world_view.gd","res://test/three_view_probe.gd",
		"res://test/three_gallery.gd","res://tools/export_three_assets.gd"]:
		if not FileAccess.file_exists(path+".uid"):
			var uid := ResourceUID.create_id()
			var identity := FileAccess.open(path+".uid",FileAccess.WRITE)
			identity.store_string(ResourceUID.id_to_text(uid)+"\n")
			ResourceUID.add_id(uid,path)
	Stage.use(Stage.Which.GREENFIELD)
	_save("lira",Lira.new())
	for spec in [["walker",Balance.WALKER_SIZE],["walker_spiky",Balance.WALKER_SIZE],["flyer",Balance.FLYER_SIZE],
		["thornmite",Vector2(76,46)],["wisp",Balance.FLYER_SIZE],
		["turret",Balance.TURRET_SIZE],["shieldbearer",Balance.SHIELDBEARER_SIZE],
		["keeper",Balance.KEEPER_HITBOX],["pursuer",Vector2(106,92)],["black_hole",Vector2.ONE*BlackHoleChaser.HIT_RADIUS*2]]:
		_save(spec[0],EnemyModel.new(spec[0],spec[1]))
	for spec in [["coin",Vector2(22,22)],["crystal",Vector2(20,32)],["goal",Vector2(40,40)],
		["ruin_blocks",Vector2(48,48)],
		["checkpoint",Vector2(40,40)],["platform",Vector2(150,26)],["tree",Vector2(40,40)],
		["fence",Vector2(180,40)],["spring",Vector2(Spring.WIDTH,Spring.PAD_Y)]]:
		_save(spec[0],Assets.instance(spec[0],spec[1]))
	var terrain := MeshInstance3D.new()
	terrain.mesh=Assets.terrain(Vector2(512,300))
	_save("grass_terrain",terrain)
	var file := FileAccess.open("res://assets/models/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t")+"\n")
	print("exported ",manifest.size()," original 3D prefabs")
	get_tree().quit()

func _save(label: String, model: Node3D) -> void:
	var root := Node3D.new()
	root.name=label
	var counts := {"triangles":0,"mesh_parts":0}
	_copy(model,root,root,counts)
	var scene := PackedScene.new()
	assert(scene.pack(root)==OK)
	assert(ResourceSaver.save(scene,"res://assets/models/%s.scn"%label,ResourceSaver.FLAG_COMPRESS)==OK)
	manifest[label]=counts
	print(label,": ",counts)
	root.free()
	model.free()

func _copy(node: Node3D, parent: Node3D, root: Node3D, counts: Dictionary) -> void:
	var copy: Node3D
	if node is MeshInstance3D:
		copy=MeshInstance3D.new()
		copy.mesh=node.mesh
		copy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		counts.mesh_parts+=1
		for i in node.mesh.get_surface_count():
			counts.triangles+=node.mesh.surface_get_array_len(i)/3
	else: copy=Node3D.new()
	copy.name=node.name if not String(node.name).is_empty() else "Part"
	copy.transform=node.transform
	parent.add_child(copy)
	copy.owner=root
	for child in node.get_children():
		if child is Node3D: _copy(child,copy,root,counts)
