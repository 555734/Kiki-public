extends Node
## Focused regression probe for Astra's complete 3D world.

var failures := 0

func check(ok: bool, label: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		failures += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	check(Balance.USE_3D and not Balance.USE_3D_RUNNER, "the 3D view is enabled")
	# 1-3: the whole world is 3D (painted quads).
	var main = await _open(Stage.Which.SKYWARD_RUINS)
	var view = main.get_node_or_null("World3D")
	check(view != null and Stage.world_3d(), "1-3 creates a full World3D")
	if view != null:
		check(not view.characters_only, "1-3's World3D draws the world")
		check(view.bindings.size() > 5, "1-3 actors, enemies and props have 3D models")
		check(view.surfaces.size() > 0, "1-3 terrain is built in 3D")
		check(main.level._terrain.self_modulate.a < 0.01, "1-3's 2D terrain is hidden")
	await _close(main)

	# 1-1 and 1-2: original 2D art, with only the runner in 3D.
	for which in [Stage.Which.GREENFIELD, Stage.Which.HORROR]:
		main = await _open(which)
		var label: String = Stage.stage_number()
		view = main.get_node_or_null("World3D")
		check(not Stage.world_3d(), "%s is a painted 2D stage" % label)
		check(view != null and view.characters_only, "%s's World3D carries characters only" % label)
		if view != null:
			check(view.bindings.size() == 1 and view.bindings.has(main.runner.get_instance_id()),
				"%s: the runner is the only 3D model" % label)
			check(view.surfaces.is_empty(), "%s: no 3D terrain or decor" % label)
			check(view.layer > 0, "%s: the 3D runner draws above the 2D world" % label)
			check(main.level._terrain.self_modulate.a > 0.99, "%s: 2D terrain is visible" % label)
			var binding: Dictionary = view.bindings.get(main.runner.get_instance_id(), {})
			var rig = binding.get("model")
			check(rig != null and rig.animation_player != null, "%s: LIRA imports its AnimationPlayer" % label)
			if rig != null:
				rig.animate(.2, Vector2(220, 0), true, Runner.State.RUN, 1)
				check(rig.rig_root.rotation.y > 0.0, "%s: rightward runner faces screen-right" % label)
				rig.animate(.2, Vector2(-220, 0), true, Runner.State.RUN, -1)
				check(rig.rig_root.rotation.y < 0.0, "%s: leftward runner faces screen-left" % label)
		for enemy in get_tree().get_nodes_in_group("enemy"):
			check((enemy as CanvasItem).self_modulate.a > 0.99, "%s: enemies stay 2D" % label)
			break
		await _close(main)
	Stage.use(Stage.Which.GREENFIELD)
	print("three view probe: %d failed" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _open(which: int) -> Node:
	Stage.use(which)
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	main.get_node("NetPanel").queue_free()
	for _i in 35:
		await get_tree().process_frame
	return main

func _close(main: Node) -> void:
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
