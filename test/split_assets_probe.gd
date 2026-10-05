extends Node
## Verify both packs, completeness and stage isolation across one process (Art caches).
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _ready() -> void:
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR_LANDSCAPE, "phone orientation is landscape in either direction")
	check(ProjectSettings.get_setting("display/window/size/viewport_width") > ProjectSettings.get_setting("display/window/size/viewport_height"), "game viewport is landscape")
	var count := 0
	for key in Art.MANIFEST:
		if String(key).begins_with("s1"):
			count += 1
			check(Art.tex(key) != null, "imported: " + String(key))
	check(count == 236, "all 236 supplied assets are registered")
	for stage in [Stage.Which.HORROR, Stage.Which.SKYWARD_RUINS,
			Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.DESERT, Stage.Which.TOWER, Stage.Which.CAVE]:
		Stage.use(stage)
		check(not Stage.world_3d(), "stage uses the new painted world")
		var texture := Art.tex("parallax")
		check(texture != null and texture.resource_path.contains("split/" + Stage.stage_number()),
			"backdrop matches " + Stage.stage_number())
	for stage in [Stage.Which.DESERT, Stage.Which.TOWER, Stage.Which.CAVE]:
		Stage.use(stage)
		for key in ["parallax", "moving_platform", "ground_block", "spring", "switch_off", "goal"]:
			check(Art.tex(key).resource_path.contains("split/" + Stage.stage_number()), "late-stage skin: " + key)
		for key in ["lift", "crumble", "conveyor", "updraft"]:
			check(Art.tex(Art.late_pack() + key) != null, "late-stage machinery: " + key)
	Stage.use(Stage.Which.GREENFIELD)
	check(Art.tex("parallax").resource_path == "res://assets/bg/parallax.png",
		"switching back to 1-1 restores its original backdrop")
	Stage.use(Stage.Which.SEA)
	var puffers := Stage.enemies().filter(func(e: Dictionary) -> bool:
		return e.get("type") == "mine")
	check(puffers.size() == 2, "two timed puffers guard coast approaches")
	var mine := SkyMine.new()
	add_child(mine)
	for mode in 3:
		Clock.tick = int((mine.period - 1.4 + float(mode) * 0.6) * 60.0)
		mine._physics_process(0.0)
		check(mine._rect.size.x == SkyMine.SIZE.x * (1.8 if mine.mode() == 2 else 1.0),
			"puffer warning and attack keep their matching hurt area")
	mine.free()
	Stage.use(Stage.Which.SWAMP)
	check(Stage.stage_name() == "THE MOLTEN CROSSING", "volcano identity")
	for spec in Stage.enemies():
		if spec.get("type") != "golem":
			continue
		var pos: Vector2 = spec["pos"]
		var patrol: float = spec["patrol"]
		var supported := false
		for slab in Stage.ground():
			if slab.position.x <= pos.x - patrol - 31.0 and slab.end.x >= pos.x + patrol + 31.0:
				supported = true
		check(supported, "golem patrol stays over solid ground")
	Stage.use(Stage.Which.GREENFIELD)
	Clock.tick = 0
	for failure in failures:
		push_error(failure)
	print("split assets probe: %d assets, %d failures" % [count, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
