extends Node
## Regression probe: integrating 1-2 must not replace 1-1.

const MainScene: PackedScene = preload("res://src/main.tscn")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _ready() -> void:
	# A fresh process must still boot the original first stage.
	check(Stage.current() == Stage.Which.GREENFIELD, "fresh launch defaults to GREENFIELD")
	check(Stage.stage_number() == "1-1", "default stage is numbered 1-1")

	# Both stages remain addressable through the same Stage facade.
	Stage.use(Stage.Which.HORROR)
	check(Stage.stage_number() == "1-2", "horror stage remains selectable as 1-2")
	Stage.use(Stage.Which.GREENFIELD)
	check(Stage.stage_number() == "1-1", "1-1 remains selectable after 1-2")

	var main: Node2D = MainScene.instantiate() as Node2D
	check(main != null, "main scene instantiates")
	if main != null:
		add_child(main)
		await get_tree().process_frame
		var panel := main.get_node_or_null("NetPanel")
		check(panel != null, "start screen exists")
		if panel != null:
			var has_1_1 := false
			var has_1_2 := false
			for node in panel.find_children("*", "Button", true, false):
				var text := String((node as Button).text)
				if text.contains("1-1"):
					has_1_1 = true
				if text.contains("1-2"):
					has_1_2 = true
			check(has_1_1, "start screen has a 1-1 stage button")
			check(has_1_2, "start screen has a 1-2 stage button")
		main.queue_free()
		await get_tree().process_frame

	if failures.is_empty():
		print("stage menu probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("stage menu probe: " + failure)
		get_tree().quit(1)
