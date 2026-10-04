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
	check(Stage.stage_name() == "THE POISON MARSH", "and it is the one it says it is")
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
			var seen := _visible_stages(panel)
			for label in ["1-1", "1-2", "1-3"]:
				check(seen.has(label), "first page has a %s stage button" % label)
			for label in ["1-4", "1-5", "1-6"]:
				check(not seen.has(label), "first page does not show %s" % label)
			check(panel._stage_view.get_child_count() == 3,
				"first page fits exactly three stage slots")
			panel._change_stage_page(1)
			await get_tree().process_frame
			seen = _visible_stages(panel)
			for label in ["1-4", "1-5", "1-6"]:
				check(seen.has(label), "second page has a %s stage button" % label)
			check(not _card_unlocked(panel._stage_1_4) and not _card_unlocked(panel._stage_1_5)
				and not _card_unlocked(panel._stage_1_6),
				"1-4, 1-5 and 1-6 cards carry the purchase lock for a free player")
			for label in ["1-1", "1-2", "1-3"]:
				check(not seen.has(label), "second page does not show %s" % label)
			check(panel._stage_view.get_child_count() == 3,
				"second page keeps the three-column layout")
			var centre: Vector2 = panel._stage_view.get_global_rect().get_center()
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.pressed = true
			touch.position = centre
			panel._input(touch)
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = centre + Vector2(180, 0)
			panel._input(drag)
			check(panel._stage_page == 0, "swipe right returns to the first page")
			await get_tree().process_frame
			seen = _visible_stages(panel)
			check(seen.has("1-1") and seen.has("1-2") and seen.has("1-3"),
				"swipe restores the first three stage cards")
			panel._change_stage_page(2)
			await get_tree().process_frame
			seen = _visible_stages(panel)
			check(seen.has("1-7") and seen.has("1-8"),
				"third page shows the tower and cave")
			check(not _card_unlocked(panel._stage_1_7) and not _card_unlocked(panel._stage_1_8),
				"1-7 and 1-8 cards carry the purchase lock for a free player")
			check(panel._stage_view.get_child_count() == 3,
				"third page keeps the three-column layout")
			for label in ["1-V", "1-B", "1-S"]:
				check(not seen.has(label),
					"start screen does NOT offer %s (hidden on purpose)" % label)

			# Difficulty belongs to the stage that has been chosen, so it is
			# not offered before one has been.
			check(_speeds(panel).is_empty(),
				"the stage screen does not ask about difficulty yet")
			var versus_door := false
			for node in panel.find_children("*", "Button", true, false):
				var label := String((node as Button).text)
				if label.contains("2対2") or label.contains("2v2"):
					versus_door = true
			check(versus_door, "2対2 たいせん entry remains available")

			panel._show_play_screen()
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
			panel.queue_free()
			await get_tree().process_frame
			check(main.process_mode == Node.PROCESS_MODE_INHERIT,
				"choosing play resumes the gameplay subtree")
			check(GameState.running and Clock.tick <= 5,
				"a local run starts after leaving home (running=%s, tick=%d)" \
					% [str(GameState.running), Clock.tick])
		main.queue_free()
		await get_tree().process_frame

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
