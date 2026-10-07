extends Node
## Regression probe: adding a stage must never replace the ones already there.
##
## Written when 1-2 went in and extended every time since. The failure it exists
## to catch is not subtle -- it is "the new stage is the only stage" -- but it is
## invisible from inside the new stage, which is where all the attention is when
## one is being added.

const MainScene: PackedScene = preload("res://src/main.tscn")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--english"): TranslationServer.set_locale("en")
	# A fresh process must still boot the original first stage.
	check(Stage.current() == Stage.Which.GREENFIELD, "fresh launch defaults to GREENFIELD")
	check(Stage.stage_number() == "1-1", "default stage is numbered 1-1")

	# Every stage remains addressable through the same Stage facade -- INCLUDING
	# the two that the start screen no longer offers. That is the point of
	# hiding them rather than deleting them, and it is what makes putting the
	# buttons back a one-line change rather than a restoration.
	Stage.use(Stage.Which.HORROR)
	check(Stage.stage_number() == "1-2", "horror stage remains selectable as 1-2")
	Stage.use(Stage.Which.KEEPER)
	check(Stage.stage_number() == "1-B", "the boss stage is selectable as 1-B")
	check(Stage.stage_name() == "THE KEEPER", "and it is the one it says it is")
	check(not Stage.enemies().is_empty(), "the boss arena has its boss in it")
	Stage.use(Stage.Which.SKY)
	check(Stage.stage_number() == "1-S", "the flight stage is selectable as 1-S")
	check(Stage.stage_name() == "THE OPEN SKY", "and it is the one it says it is")
	check(Stage.ground().size() > 10, "the open sky has its islands in it")
	Stage.use(Stage.Which.SKYWARD_RUINS)
	check(Stage.stage_number() == "1-3", "the vertical stage is selectable as 1-3")
	check(Stage.stage_name() == "THE SKYWARD RUINS", "and it is the one it says it is")
	Stage.use(Stage.Which.SEA)
	check(Stage.stage_number() == "1-4", "the sea stage is selectable as 1-4")
	check(Stage.stage_name() == "THE SUNLIT COAST", "and it is the one it says it is")
	Stage.use(Stage.Which.SWAMP)
	check(Stage.stage_number() == "1-5", "the poison marsh is selectable as 1-5")
	check(Stage.stage_name() == "THE MOLTEN CROSSING", "and it is the one it says it is")
	Stage.use(Stage.Which.DESERT)
	check(Stage.stage_number() == "1-6", "the desert is selectable as 1-6")
	check(Stage.stage_name() == "THE SANDGLASS RUINS", "and it is the one it says it is")
	Stage.use(Stage.Which.TOWER)
	check(Stage.stage_number() == "1-7", "the tower is selectable as 1-7")
	check(Stage.stage_name() == "THE CLOCKWORK TOWER", "and it is the one it says it is")
	Stage.use(Stage.Which.CAVE)
	check(Stage.stage_number() == "1-8", "the cave is selectable as 1-8")
	check(Stage.stage_name() == "THE UNDERGROVE", "and it is the one it says it is")
	Stage.use(Stage.Which.GREENFIELD)
	check(Stage.stage_number() == "1-1", "1-1 remains selectable after the others")

	# The lock checks below are about a player who has not bought anything.
	Entitlement.clear_token()
	Entitlement.revoke_guest()
	var main: Node2D = MainScene.instantiate() as Node2D
	check(main != null, "main scene instantiates")
	if main != null:
		add_child(main)
		await get_tree().process_frame
		var panel := main.get_node_or_null("NetPanel")
		check(panel != null, "start screen exists")
		if panel != null:
			check(panel.get("_code") == null,
				"stage selection is its own first screen")
			var frozen_tick := Clock.tick
			var frozen_position: Vector2 = main.runner.global_position
			for i in 6:
				await get_tree().physics_frame
			check(Clock.tick == frozen_tick, "stage clock is stopped behind the home screen")
			check(main.runner.global_position == frozen_position,
				"runner cannot move behind the home screen")
			check(not GameState.running, "run timer has not started on the home screen")
			check(panel._stage_back.visible and not panel._stage_back.disabled, "stage selection has a usable back button")
			for i in StageCards.all().size():
				panel._change_stage_page(i - panel._stage_page)
				await get_tree().process_frame
				var seen := _visible_stages(panel)
				var info: Dictionary = StageCards.all()[i]
				check(seen.size() == 1 and seen.has(info["number"]), "exactly one stage on page %d" % (i + 1))
				check(panel._stage_view.get_child_count() == 1, "one card slot without empty placeholders")
				var card: Button = panel._select_view.cards[int(info["which"])]
				check(_card_unlocked(card) == Entitlement.can_play(int(info["which"])), "locks preserved for " + String(info["number"]))
			await _capture("coop-stage-card")
			# A different finger must not steal the swipe; vertical movement must
			# not turn a page. At the catalogue edge a swipe must not tap a card.
			var centre: Vector2 = panel._stage_view.get_global_rect().get_center()
			_touch(panel, centre, true, 0)
			_touch(panel, centre, true, 1)
			_drag(panel, centre + Vector2(180, 0), 1)
			check(panel._stage_page == 7, "second finger cannot steal stage gesture")
			_drag(panel, centre + Vector2(0, 160), 0)
			check(panel._stage_page == 7, "vertical drag does not turn the page")
			panel._stage_1_8.pressed.emit()
			check(panel._code == null, "vertical drag release is not a stage tap")
			_drag(panel, centre - Vector2(180, 0), 0)
			check(panel._stage_page == 7 and panel._select_view._swipe.consumed, "edge swipe stays on last stage and consumes card tap")
			panel._stage_1_8.pressed.emit()
			check(panel._code == null, "edge swipe release cannot open the play screen")
			_touch(panel, centre, false, 0)
			_touch(panel, centre, false, 1)
			_touch(panel, centre, true, 0)
			_drag(panel, centre + Vector2(180, 0), 0)
			_touch(panel, centre + Vector2(180, 0), false, 0)
			await get_tree().process_frame
			check(panel._stage_page == 6 and _visible_stages(panel).has("1-7"), "right swipe selects previous stage")
			centre = panel._stage_view.get_global_rect().get_center()
			_touch(panel, centre, true, 0)
			_drag(panel, centre - Vector2(180, 0), 0)
			_touch(panel, centre - Vector2(180, 0), false, 0)
			await get_tree().process_frame
			check(panel._stage_page == 7 and _visible_stages(panel).has("1-8"), "left swipe selects next stage")
			# The mouse has the same browsing gesture on desktop.
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT; mouse.pressed = true; mouse.position = centre
			panel._input(mouse)
			var motion := InputEventMouseMotion.new()
			motion.position = centre + Vector2(180, 0)
			panel._input(motion)
			await get_tree().process_frame
			check(panel._stage_page == 6, "mouse drag selects the previous stage")
			# Versus keeps the five postponed layouts, but offers only Royal.
			check(VersusStageData.THEMES.size() == 6 and VersusStageData.SELECTABLE_THEMES == [Stage.Which.ROYAL_ARENA], "postponed arenas are retained but not offered")
			panel._on_versus()
			await get_tree().process_frame
			var versus: Control = panel._versus_view
			versus._stage_id = Stage.Which.SEA
			versus._choose_mode(VersusRoster.RoomMode.FREE_FOR_ALL)
			await get_tree().process_frame
			check(versus._stage_cards.size() == 1 and versus._stage_id == Stage.Which.ROYAL_ARENA, "versus room offers and selects only Royal Arena")
			var royal: Button = versus._stage_cards[0]
			check(int(royal.get_meta("which")) == Stage.Which.ROYAL_ARENA and not royal.disabled, "Royal remains freely selectable")
			check(versus._back.visible and not versus._back.disabled, "versus room has an explicit back button")
			await _capture("royal-stage-card")
			versus._code.text = "123456"
			centre = versus._stage_row.get_global_rect().get_center()
			_touch(versus, centre, true, 0)
			_drag(versus, centre - Vector2(180, 0), 0)
			_touch(versus, centre, false, 0)
			_touch(panel, centre, true, 0)
			_drag(panel, centre + Vector2(180, 0), 0)
			check(panel._stage_page == 6, "versus gestures cannot move the co-op menu behind it")
			check(versus._stage_id == Stage.Which.ROYAL_ARENA and versus._code.text == "123456", "single-stage swipe keeps Royal and typed room code")
			versus._back.pressed.emit()
			await get_tree().process_frame
			check(versus._step == 1, "room back returns to versus mode selection")
			versus._back.pressed.emit()
			await get_tree().process_frame
			check(not is_instance_valid(versus) and panel._stage_page == 6, "mode back closes versus and preserves co-op browsing position")

			# Difficulty belongs to the stage that has been chosen, so it is
			# not offered before one has been.
			check(_speeds(panel).is_empty(),
				"the stage screen does not ask about difficulty yet")
			var versus_door := false
			for node in panel.find_children("*", "Button", true, false):
				var label := String((node as Button).text)
				if label.contains("スターたいせん") or label.to_lower().contains("star battle"):
					versus_door = true
			check(versus_door, "2対2 たいせん entry remains available")

			panel._change_stage_page(-panel._stage_page)
			await get_tree().process_frame
			centre = panel._stage_view.get_global_rect().get_center()
			_touch(panel, centre, true, 0)
			_touch(panel, centre, false, 0)
			panel._stage_1_1.pressed.emit()
			await get_tree().process_frame
			check(panel.get("_code") != null,
				"choosing a stage opens the separate play/connect screen")
			check(_speeds(panel).size() == Difficulty.LABELS.size(),
				"every 追跡者の速さ setting is offered once the stage is chosen")
			# And it still takes: the chasers read the value live, and the room
			# carries the host's, so this is the last screen that can set it.
			var before := Difficulty.current()
			var other := (before + 1) % Difficulty.LABELS.size()
			panel._on_difficulty(other)
			check(Difficulty.current() == other,
				"the play screen actually changes the difficulty")
			panel._on_difficulty(before)
			check(panel.find_children("*", "Button", true, false).all(
				func(button: Button) -> bool: return not button.text.contains("1-2")),
				"stage cards are not duplicated on the play screen")

			# The room-code strip is a UI contract. Show it with a known code so
			# this probe does not depend on EOS connectivity or timing.
			main.link.room_code = "123456"
			panel._show_banner()
			await get_tree().process_frame
			check(panel.get("_banner") != null, "creating a room shows the room-code strip")
			check(not panel._root.visible, "the menu gives way to the stage behind the strip")
			check(EosCoopLobby.valid_code(main.link.room_code),
				"the room code is known before EOS answers")
			check(panel._banner_code != null
				and String(panel._banner_code.text).replace(" ", "") == main.link.room_code,
				"the strip shows the room code")
			check(main.process_mode == Node.PROCESS_MODE_DISABLED,
				"the stage stays frozen behind the strip")
			panel._on_cancel()
			check(panel.get("_banner") == null and panel._root.visible,
				"やめる puts the menu back")
			check(not main.link.busy(), "やめる ends the attempt")
			check(panel.get("_code") != null, "and it is the play/connect screen again")
			panel.free()
			check(main.process_mode == Node.PROCESS_MODE_INHERIT,
				"choosing play resumes the gameplay subtree")
			check(GameState.running and Clock.tick == 0,
				"a local run starts after leaving home (running=%s, tick=%d)" \
					% [str(GameState.running), Clock.tick])
		main.queue_free()
		await get_tree().process_frame

	await _test_title_back()
	if failures.is_empty():
		print("stage menu probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("stage menu probe: " + failure)
		get_tree().quit(1)

## Every 追跡者の速さ button currently on screen.
func _speeds(panel: Node) -> Array:
	var found := []
	for node in panel.find_children("*", "Button", true, false):
		for label in Difficulty.LABELS:
			if String((node as Button).text) == TranslationServer.translate(label):
				found.append(node)
				break
	return found

func _visible_stages(panel: Node) -> Dictionary:
	var result := {}
	for node in panel._stage_view.get_children():
		if node is Button:
			result[String((node as Button).text)] = true
	return result

func _card_unlocked(card: Button) -> bool:
	if card == null:
		return false
	for node in card.get_meta("lock") as Array:
		if (node as CanvasItem).visible:
			return false
	return true

func _touch(target: Node, at: Vector2, pressed: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at; event.pressed = pressed; event.index = index
	target._input(event)

func _drag(target: Node, at: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = at; event.index = index
	target._input(event)

func _capture(name_: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/star-selector"))
	get_viewport().get_texture().get_image().save_png("res://build/star-selector/" + name_ + ".png")

func _test_title_back() -> void:
	Stage.use(Stage.Which.GREENFIELD)
	var main := MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var panel: NetPanel = main.get_node("NetPanel")
	# Keep this probe alive while the real button changes the current scene.
	get_tree().current_scene = null
	panel._stage_back.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var title := get_tree().current_scene
	check(title != null and title.scene_file_path == "res://src/boot.tscn", "stage back button returns to the real title screen")
	main.free()
	check(not GameState.running and not Clock.is_physics_processing(), "returning to title cannot start hidden gameplay")
	if title != null: title.free()
	get_tree().current_scene = null
