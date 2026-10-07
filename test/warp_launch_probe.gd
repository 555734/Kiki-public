extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	print("%s %s" % ["ok" if ok else "FAIL", message])
	if not ok: failures += 1
func _ready() -> void: call_deferred("run")
func run() -> void:
	var r := preload("res://src/runner/runner.gd").new()
	add_child(r)
	r.set_physics_process(false)
	var mouth := Vector2(100, 50)
	var exit := Vector2(750, -300)
	var impulse := Vector2(150, -400)
	var spec := {"type": "warp", "pos": mouth, "exit": exit, "exit_velocity": impulse, "mark": 1}
	check(StageSpecSchema.errors([], [spec]).is_empty(), "launching warp has valid finite vector properties")
	var invalid := spec.duplicate(); invalid["exit_velocity"] = Vector2(NAN, 0)
	check(not StageSpecSchema.errors([], [invalid]).is_empty(), "invalid warp impulse is rejected")
	var warp := WarpGate.from_spec(spec, r)
	add_child(warp); warp.global_position = mouth; warp.set_physics_process(false)
	r.global_position = mouth; r.velocity = Vector2(30, 70)
	Clock.is_host = false
	warp._physics_process(Clock.DT)
	check(r.global_position == mouth and r.velocity == Vector2(30, 70), "guest neither teleports nor launches")
	Clock.is_host = true
	warp._physics_process(Clock.DT)
	check(r.global_position == exit and r.velocity == impulse and r._external_takeoff_pending,
		"host applies teleport and actual Runner launch together")
	r.global_position = mouth
	warp._physics_process(Clock.DT)
	check(r.global_position == mouth, "cooldown prevents another launch")
	warp.free()
	var ordinary := WarpGate.from_spec({"type": "warp", "exit": exit}, r)
	add_child(ordinary); ordinary.global_position = mouth; ordinary.set_physics_process(false)
	r.velocity = Vector2(35, 120); ordinary._physics_process(Clock.DT)
	check(r.global_position == exit and r.velocity == Vector2(35, 120), "ordinary portals preserve their previous velocity behavior")
	ordinary.free(); r.free()
	print("warp launch probe: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
