extends Node
## Focused smoke test for the integrated 1-2 horror stage.

const MainScene: PackedScene = preload("res://src/main.tscn")

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _ready() -> void:
	Stage.use(Stage.Which.HORROR)
	check(Stage.is_horror(), "horror stage can be selected")
	check(Stage.stage_number() == "1-2", "horror stage is numbered 1-2")
	check(Stage.stage_name() == "THE HOLLOW OUTSKIRTS", "horror stage name is wired")
	check(Stage.enemies().size() == 1, "horror stage has one pursuer")
	if Stage.enemies().size() > 0:
		check(String(Stage.enemies()[0].get("type", "")) == "sky_pursuer",
			"the stage enemy is the horror pursuer")

	# Direct --headless scene runs do not perform an editor import pass for newly
	# added SVGs. ResourceLoader.exists() therefore reports false until Godot has
	# imported them even though the source files are present. The Android/iOS
	# build scripts perform that import step explicitly; this probe verifies the
	# integrated source assets themselves are actually in the repository.
	for path in [
		"res://assets/bg/horror_stage_1_2.svg",
		"res://assets/horror/pursuer.svg",
		"res://assets/horror/platform.svg",
		"res://assets/horror/checkpoint_off.svg",
		"res://assets/horror/checkpoint_on.svg",
		"res://assets/horror/gate.svg",
		"res://assets/horror/fence.svg",
		"res://assets/horror/thorns.svg",
		"res://assets/horror/mud_tile.svg",
		"res://assets/horror/moss_cap.svg",
	]:
		check(FileAccess.file_exists(path), "horror asset source exists: %s" % path)

	var main: Node2D = MainScene.instantiate() as Node2D
	check(main != null, "main scene instantiates")
	if main == null:
		_finish()
		return
	add_child(main)

	# add_child() runs Main._ready() synchronously. Check the authored spawn now,
	# before gravity/ground recovery is allowed to move the CharacterBody2D.
	check(main.runner != null, "main creates runner")
	if main.runner != null:
		check(main.runner.global_position.distance_to(Stage.start()) < 1.0,
			"runner is authored at the horror stage start")

	await get_tree().process_frame
	await get_tree().process_frame
	var pursuer: Node = null
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.get_script() != null and String(enemy.get_script().resource_path).ends_with("sky_pursuer.gd"):
			pursuer = enemy
			break
	check(pursuer != null, "level builder creates the horror pursuer")
	if pursuer != null:
		check(pursuer.is_in_group("instant_death"), "pursuer contact is instant death")
		pursuer.call("take_damage", 1, "snipe")
		check(bool(pursuer.call("stunned")), "guardian shot stuns instead of killing pursuer")

	# The integration must not delete the existing current co-op stage.
	Stage.use(Stage.Which.CROSSING)
	check(Stage.stage_number() == "1-C", "existing crossing stage still exists")

	main.queue_free()
	await get_tree().process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("horror stage probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("horror stage probe: " + failure)
		get_tree().quit(1)
