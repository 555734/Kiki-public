extends "res://tools/promotion/capture_promo_v3.gd"
## Short native runs through stages 1-1 to 1-8 for the PV v3 montage.
## The runner is driven with real inputs and the camera follows; nothing is staged.
const OUT_MONTAGE := "res://build/promotion/stage-1-9/pv-v3/"
const STAGES := [
	["1-1", Stage.Which.GREENFIELD], ["1-2", Stage.Which.HORROR],
	["1-3", Stage.Which.SKYWARD_RUINS], ["1-4", Stage.Which.SEA],
	["1-5", Stage.Which.SWAMP], ["1-6", Stage.Which.DESERT],
	["1-7", Stage.Which.TOWER], ["1-8", Stage.Which.CAVE]]

func _ready() -> void:
	process_priority = 250
	TranslationServer.set_locale("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_MONTAGE))
	call_deferred("run")

func run() -> void:
	for entry in STAGES:
		await new_stage(entry[1])
		for e in get_tree().get_nodes_in_group("enemy"): e.set_physics_process(true)
		Clock.set_physics_process(true)
		Clock.reset(0)
		zoom = 1.25
		follow = true
		focus = main.runner.global_position + Vector2(110, -60)
		await seconds(0.4)
		start_take(entry[0])
		for i in 120:
			drive(1, i % 40 < 8)
			await frames(1)
		drive(0)
		mark("run", {"stage": entry[0], "alive": main.runner.state != Runner.State.DEAD,
			"x": main.runner.global_position.x})
		finish_take()
	var f := FileAccess.open(OUT_MONTAGE + "montage-takes.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": FPS, "segments": segments, "events": marks}, "\t"))
	f.close()
	main.free()
	await frames(2)
	get_tree().quit()
