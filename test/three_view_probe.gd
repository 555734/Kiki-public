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
	# 1-3: the world is 3D (painted quads); LIRA stays the painted 2D figure.
	var main = await _open(Stage.Which.SKYWARD_RUINS)
	var view = main.get_node_or_null("World3D")
	check(view != null and Stage.world_3d(), "1-3 creates a World3D")
	if view != null:
		check(view.bindings.size() > 5, "1-3 enemies and props have 3D models")
		check(view.surfaces.size() > 0, "1-3 terrain is built in 3D")
		check(main.level._terrain.self_modulate.a < 0.01, "1-3's 2D terrain is hidden")
		check(not view.bindings.has(main.runner.get_instance_id()), "1-3 has no 3D runner")
	check(main.runner.visual.self_modulate.a > 0.99 and main.runner.visual.is_processing(),
		"1-3 draws the painted 2D LIRA")
	await _close(main)

	# 1-1 and 1-2: everything is the original 2D art, runner included.
	for which in [Stage.Which.GREENFIELD, Stage.Which.HORROR]:
		main = await _open(which)
		var label: String = Stage.stage_number()
		check(not Stage.world_3d(), "%s is a painted 2D stage" % label)
		check(main.get_node_or_null("World3D") == null, "%s has no 3D view at all" % label)
		check(main.level._terrain.self_modulate.a > 0.99, "%s: 2D terrain is visible" % label)
		check(main.runner.visual.self_modulate.a > 0.99, "%s: the painted 2D LIRA is visible" % label)
		for enemy in get_tree().get_nodes_in_group("enemy"):
			check((enemy as CanvasItem).self_modulate.a > 0.99, "%s: enemies stay 2D" % label)
			break
		if which == Stage.Which.GREENFIELD:
			await _poses(main)
		await _close(main)
	check(Art.MANIFEST["flyer"] == "entities/flyer_bird.png" and Art.tex("flyer") != null,
		"the flyer is the painted bird, not the old winged chestnut")
	Stage.use(Stage.Which.GREENFIELD)
	print("three view probe: %d failed" % failures)
	get_tree().quit(0 if failures == 0 else 1)

## Each signature move has a pose of its own.
func _poses(main: Node) -> void:
	var r: Runner = main.runner
	var v = r.visual
	r.set("_wall_sliding", true)
	check(v._pose_key() == "runner_reach", "a wall slide presses against the wall")
	r.set("_wall_sliding", false)
	r.set("_wall_kick_visual", 0.2)
	check(v._pose_key() == "runner_dash", "a wall kick launches sideways")
	r.set("_wall_kick_visual", 0.0)
	r.set("state", Runner.State.HANG)
	check(v._pose_key() == "runner_reach", "hanging from a ledge reaches up")
	r.set("state", Runner.State.IDLE)
	# The third jump of a chain somersaults.
	r.global_position += Vector2(0, -300)
	r.set("_jump_chain", 3)
	r.set("state", Runner.State.JUMP)
	r.velocity = Vector2(200, -400)
	r.grounded = false
	v._was_airborne = true
	v._spin = 0.0
	v._spin_active = false
	v._process(0.05)
	check(v._spin > 0.0 and v._spin < TAU, "the third jump turns a somersault")
	r.set("_jump_chain", 0)

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
