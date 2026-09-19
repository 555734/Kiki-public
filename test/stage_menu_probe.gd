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
			var seen := {}
			for node in panel.find_children("*", "Button", true, false):
				var text := String((node as Button).text)
				for label in ["1-1", "1-2", "1-V", "1-B", "1-S"]:
					if text.contains(label):
						seen[label] = true
			for label in ["1-1", "1-2", "1-V"]:
				check(seen.has(label), "start screen has a %s stage button" % label)
			# And the other half of the same claim. Without this, restoring the
			# two buttons would pass every check in the suite and nobody would
			# find out until they were on a screenshot.
			for label in ["1-B", "1-S"]:
				check(not seen.has(label),
					"start screen does NOT offer %s (hidden on purpose)" % label)
		main.queue_free()
		await get_tree().process_frame

	if failures.is_empty():
		print("stage menu probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("stage menu probe: " + failure)
		get_tree().quit(1)
