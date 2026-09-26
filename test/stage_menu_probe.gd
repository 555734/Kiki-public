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
	Stage.use(Stage.Which.GREENFIELD)
	check(Stage.stage_number() == "1-1", "1-1 remains selectable after the others")

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
			var seen := {}
			for node in panel.find_children("*", "Button", true, false):
				var text := String((node as Button).text)
				for label in ["1-1", "1-2", "1-3", "1-4", "1-5", "1-V", "1-B", "1-S"]:
					if text.contains(label):
						seen[label] = true
			for label in ["1-1", "1-2", "1-3", "1-4", "1-5"]:
				check(seen.has(label), "start screen has a %s stage button" % label)
			# And the other half of the same claim. Without this, restoring the
			# two buttons would pass every check in the suite and nobody would
			# find out until they were on a screenshot.
			for label in ["1-V", "1-B", "1-S"]:
				check(not seen.has(label),
					"start screen does NOT offer %s (hidden on purpose)" % label)

			# Difficulty belongs to the stage that has been chosen, so it is
			# not offered before one has been.
			check(_speeds(panel).is_empty(),
				"the stage screen does not ask about difficulty yet")

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

			# "部屋を作る" swaps the menu for the stage at once, with the room
			# code on a strip across it, before any EOS round trip finishes.
			panel._on_host_eos()
			await get_tree().process_frame
			await get_tree().process_frame
			check(panel.get("_banner") != null, "creating a room shows the room-code strip")
			check(not panel._root.visible, "the menu gives way to the stage behind the strip")
			check(EosCoopLobby.valid_code(main.link.room_code),
				"the room code is known before EOS answers")
			check(String(panel._banner_code.text).replace(" ", "") == main.link.room_code,
				"the strip shows the room code")
			check(main.process_mode == Node.PROCESS_MODE_DISABLED,
				"the stage stays frozen behind the strip")
			panel._on_cancel()
			check(panel.get("_banner") == null and panel._root.visible,
				"やめる puts the menu back")
			check(not main.link.busy(), "やめる ends the attempt")
			check(panel.get("_code") != null, "and it is the play/connect screen again")
			# Let the abandoned attempt's EOS call return before tearing down.
			for i in 600:
				if EosRuntime.state != EosRuntime.State.STARTING:
					break
				await get_tree().process_frame
			await get_tree().process_frame

			# Internet versus still depends on the retired relay and is deliberately
			# absent from the release menu until its EOS migration is complete.
			var door := false
			for node in panel.find_children("*", "Button", true, false):
				var text := String((node as Button).text)
				if text.contains("たいせん") or text.contains("対戦"):
					door = true
			check(not door, "retired-relay たいせん entry remains hidden")
			panel.queue_free()
			await get_tree().process_frame
			check(main.process_mode == Node.PROCESS_MODE_INHERIT,
				"choosing play resumes the gameplay subtree")
			check(GameState.running and Clock.tick <= 1,
				"a local run starts from time zero after leaving home")
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
