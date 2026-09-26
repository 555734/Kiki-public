extends Node

const BootScene: PackedScene = preload("res://src/boot.tscn")
var failures: Array[String] = []

func _ready() -> void:
	var boot := BootScene.instantiate()
	add_child(boot)
	await get_tree().process_frame
	check(boot.get("_start") != null, "title screen has a Start button")
	var publisher_found := false
	for node in boot.find_children("*", "Label", true, false):
		if String((node as Label).text).contains("PRESENT SOFT"):
			publisher_found = true
	check(not publisher_found, "publisher splash is absent")
	for frame in 600:
		if boot.get("_main_scene") != null or boot.get("_load_failed"):
			break
		await get_tree().process_frame
	check(boot.get("_main_scene") != null, "playable scene loads behind title screen")
	var start: Button = boot.get("_start")
	check(start != null and not start.disabled, "Start becomes available after loading")
	check(get_tree().current_scene == null or get_tree().current_scene == self,
		"loading does not leave the title screen automatically")
	boot.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("start screen probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("start screen probe: " + failure)
		get_tree().quit(1)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
