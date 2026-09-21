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
	var enemy_specs := Stage.enemies()
	check(enemy_specs.size() >= 12, "horror stage has a real enemy roster")
	if enemy_specs.size() > 0:
		check(String(enemy_specs[0].get("type", "")) == "sky_pursuer",
			"the Nightwolf pursuer remains the first network enemy")
	var thornmites := 0
	var wisps := 0
	var walkers := 0
	for spec in enemy_specs:
		match String(spec.get("type", "")):
			"thornmite": thornmites += 1
			"flyer": wisps += 1
			"walker": walkers += 1
	check(thornmites >= 6, "1-2 has multiple Thornmite ground enemies")
	check(wisps >= 4, "1-2 has multiple Wisp flyers")
	check(walkers == 0, "1-2 does not use the round walker/Goomba-like enemy")
	check(Stage.gimmicks().size() >= 8, "1-2 mixes moving, crumbling and switch gimmicks")
	check(Stage.coins().size() >= 30, "coin arcs signpost the platforming route")
	check(Stage.solid_decor().size() >= 6, "2.5D ruin blocks are part of the route")

	# Wide authored holes are the co-op contract: these are wider than an
	# unaided jump and are bridged by Orion's temporary 150px platforms.
	var ground := Stage.ground()
	var p2_gaps := 0
	for i in range(ground.size() - 1):
		var right: float = ground[i].position.x + ground[i].size.x
		var gap: float = ground[i + 1].position.x - right
		if gap >= 400.0:
			p2_gaps += 1
	check(p2_gaps >= 4, "1-2 contains four P2-platform-required gaps")

	# Every horror-skin file the registry names has to be in the repository.
	#
	# This used to be a hand-written list of ten paths, and it was WRONG from the
	# moment the painted set landed: five of the .svg files it named had been
	# replaced by .png, so this probe failed on five lines that were describing
	# an older commit rather than anything broken. A hard-coded list of asset
	# paths goes stale the first time anybody touches the art, which is the one
	# thing it exists to survive -- so it asks the registry instead.
	#
	# Direct --headless scene runs do not run an editor import pass, so
	# ResourceLoader.exists() can report false for a file that is right there.
	# FileAccess is the question this probe means to ask: is it in the repo.
	var horror_keys := 0
	for key in Art.MANIFEST.keys():
		if not String(key).begins_with("horror_"):
			continue
		horror_keys += 1
		var path: String = Art.BASE + Art.MANIFEST[key]
		check(FileAccess.file_exists(path),
			"horror asset source exists: %s -> %s" % [key, path])
	check(horror_keys >= 10,
		"the registry still has the horror skin in it (%d keys)" % horror_keys)

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
	var thornmite: Node = null
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.get_script() == null:
			continue
		var script_path := String(enemy.get_script().resource_path)
		if script_path.ends_with("sky_pursuer.gd"):
			pursuer = enemy
		elif script_path.ends_with("thornmite.gd"):
			thornmite = enemy
	check(pursuer != null, "level builder creates the horror pursuer")
	check(thornmite != null, "level builder creates Thornmite enemies")
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
