extends Node
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _ready() -> void:
	VersusLaunch.clear()
	check(VersusLaunch.stage == Stage.Which.ROYAL_ARENA, "launch resets to Royal Arena")
	var welcome := VersusProtocol.read_welcome(VersusProtocol.welcome(2, 991))
	check(welcome.stage == Stage.Which.ROYAL_ARENA, "default welcome transmits Royal Arena")
	var panel: Control = preload("res://src/ui/versus_panel.gd").new()
	add_child(panel)
	check(panel._stage_id == Stage.Which.ROYAL_ARENA, "menu selects Royal Arena")
	panel._choose_mode(VersusRoster.RoomMode.FREE_FOR_ALL)
	await get_tree().process_frame
	check(panel._stage_cards.size() == 1 and int(panel._stage_cards[0].get_meta("which")) == Stage.Which.ROYAL_ARENA, "Royal is the only visible arena")
	check(VersusStageData.THEMES.size() == 6 and VersusStageData.SELECTABLE_THEMES == [Stage.Which.ROYAL_ARENA], "all five postponed arena layouts remain internally")
	panel.queue_free()
	VersusStageData.use_theme(Stage.Which.ROYAL_ARENA)
	var assets := 0
	for key in Art.MANIFEST:
		if String(key).begins_with("royal_"):
			assets += 1
			check(Art.tex(key) != null, "missing " + str(key))
	check(assets == 50, "all supplied assets load")
	check(Art.tex("parallax") == Art.tex("royal_royal_sky_kingdom"), "Royal background alias")
	VersusLaunch.how = VersusLaunch.How.SOLO
	var arena := preload("res://src/versus/versus_main.tscn").instantiate()
	add_child(arena)
	for i in 100: await get_tree().physics_frame
	check(arena.theme() == Stage.Which.ROYAL_ARENA, "default scene builds Royal Arena")
	check(not Stage.world_3d() and arena._world_view == null, "Royal uses supplied 2D painting")
	check(arena.level._terrain.get_script() == preload("res://src/versus/royal_arena_painter.gd"), "terrain uses Royal assets")
	for runner in arena.runners:
		check(runner.on_ground(), "starting runner lands")
	arena._apply_theme(Stage.Which.GREENFIELD)
	for i in 30: await get_tree().physics_frame
	check(Art.tex("parallax") != Art.tex("royal_royal_sky_kingdom"), "previous stage art restored")
	arena._apply_theme(Stage.Which.ROYAL_ARENA)
	for i in 60: await get_tree().physics_frame
	check(arena.runners[0].on_ground(), "stage handoff rebuilds Royal collision")
	arena.queue_free()
	await get_tree().process_frame
	for message in failures: push_error(message)
	print("royal arena probe: %d checks failed" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
