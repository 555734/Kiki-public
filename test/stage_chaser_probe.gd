extends Node
## Every stage from 1-4 on has the chaser 1-2 and 1-3 have: one sky_pursuer,
## first in the enemy list (so net ids stay put), starting behind the runner
## along the way the stage goes, and closing in once it wakes.

const MainScene: PackedScene = preload("res://src/main.tscn")
const STAGES := {
	Stage.Which.SEA: "1-4", Stage.Which.SWAMP: "1-5", Stage.Which.DESERT: "1-6",
	Stage.Which.TOWER: "1-7", Stage.Which.CAVE: "1-8",
}

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	for which in STAGES:
		await _stage(which, STAGES[which])
	Stage.use(Stage.Which.GREENFIELD)
	if failures.is_empty():
		print("stage chaser probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("stage chaser probe: " + failure)
		get_tree().quit(1)

func _stage(which: int, label: String) -> void:
	Stage.use(which)
	var specs := Stage.enemies().filter(func(e: Dictionary) -> bool:
		return String(e.get("type", "")) == "sky_pursuer")
	check(specs.size() == 1, "%s authors one chaser" % label)
	if specs.is_empty():
		return
	check(String(Stage.enemies()[0].get("type", "")) == "sky_pursuer",
		"%s lists it first" % label)
	var forward := Stage.progress_direction()
	var behind := (Stage.start() - Vector2(specs[0]["pos"])).dot(forward)
	check(behind > 300.0, "%s starts it behind the runner (%.0fpx)" % [label, behind])
	var wanted: Vector2 = specs[0].get("direction", Vector2.RIGHT)
	check(wanted.normalized().is_equal_approx(forward),
		"%s chases the way the stage goes" % label)

	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
	if main.has_method("resume_from_home"):
		main.resume_from_home(true)
	main.input_hub.scripted = true
	var pursuer: Node2D = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get_script() != null and String(e.get_script().resource_path).ends_with("sky_pursuer.gd"):
			pursuer = e
	check(pursuer != null and pursuer.is_in_group("instant_death"),
		"%s builds a deadly chaser" % label)
	if pursuer != null:
		main.runner.set_physics_process(false)
		# New mobile pacing keeps the chaser asleep until the player advances.
		main.runner.global_position += forward * (float(specs[0].get("activation", 0.0)) + 1.0)
		var gap_before: float = (main.runner.global_position - pursuer.global_position).dot(forward)
		var delay := float(specs[0].get("delay", 2.25))
		for _i in int((delay + 1.0) * 60.0):
			await get_tree().physics_frame
		var gap_after: float = (main.runner.global_position - pursuer.global_position).dot(forward)
		check(gap_after < gap_before - 100.0,
			"%s chaser closes in once awake (%.0f -> %.0f px)" % [label, gap_before, gap_after])
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
