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
	Stage.use(Stage.Which.GREENFIELD)
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	main.get_node("NetPanel").queue_free()
	for _i in 35:
		await get_tree().process_frame

	var view = main.get_node_or_null("World3D")
	check(Balance.USE_3D and not Balance.USE_3D_RUNNER,
		"Astra's complete 3D presentation is enabled")
	check(view != null, "main game creates World3D")
	if view != null:
		check(view.bindings.size() > 5, "actors, enemies and props have 3D models")
		check(view.surfaces.size() > 0, "stage terrain is built as 3D geometry")
		check(main.level._terrain.self_modulate.a < 0.01, "2D terrain is hidden behind World3D")
		var binding: Dictionary = view.bindings[main.runner.get_instance_id()]
		var rig = binding.model
		check(rig.animation_player != null, "LIRA imports its AnimationPlayer")
		rig.animate(.2, Vector2(220, 0), true, Runner.State.RUN, 1)
		check(rig.rig_root.rotation.y > 0.0, "rightward runner faces screen-right")
		rig.animate(.2, Vector2(-220, 0), true, Runner.State.RUN, -1)
		check(rig.rig_root.rotation.y < 0.0, "leftward runner faces screen-left")

	main.queue_free()
	await get_tree().process_frame
	print("three view probe: %d failed" % failures)
	get_tree().quit(0 if failures == 0 else 1)
