extends LevelBuilder
## Reuse 1-1's objects and art, but build only the shorter versus circuit.
## The cooperative builder and Level01Data retain the complete original map.

func build() -> void:
	super.build()
	_veils.take_terrain(_terrain, VersusStageData.ground())
	_decor.items = VersusStageData.decor()

func _build_ground_bodies() -> void:
	var body := StaticBody2D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	var solids := VersusStageData.ground()
	solids.append_array(VersusStageData.solid_decor())
	for rect in solids:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)
	_static_root.add_child(body)

func _build_checkpoints() -> void:
	for i in Stage.checkpoints().size():
		var point := Stage.checkpoints()[i]
		if point.x >= VersusStageData.STEP_FROM:
			continue
		var cp := Checkpoint.new()
		cp.index = i + 1
		cp.position = point
		_static_root.add_child(cp)

func _build_goal() -> void:
	pass # A circuit is won by coins, not by crossing the co-op goal.

func rebuild_dynamic() -> void:
	super.rebuild_dynamic()
	for node in _dynamic.get_children():
		# Co-op coins are fixed gauge pickups, not match ledger coins. Keeping
		# them here makes the field look fixed even when match coins are random.
		if node is Coin or (node is Node2D and node.position.x >= VersusStageData.STEP_FROM):
			node.free()
