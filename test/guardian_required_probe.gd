extends Node
## Authored mandatory platform crossings, attacked by the actual Runner.
## Conservative: grant full legal second-gear speed even on short approaches.
## Sweep second-jump timing, coyote takeoff and wall/ledge recovery. Enemies
## and lethal areas are disabled so danger cannot hide a bypass in the geometry.
## This is a bounded adversarial search, not a proof of all possible inputs.
const MainScene = preload("res://src/main.tscn")
const Route = preload("res://test/climb_route.gd")
var failures: Array[String] = []
var main: Node2D

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	for which in [Stage.Which.GREENFIELD, Stage.Which.HORROR, Stage.Which.SKYWARD_RUINS,
		Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.DESERT, Stage.Which.TOWER, Stage.Which.CAVE]:
		Stage.use(which)
		if OS.get_environment("GUARDIAN_STAGE") != "" and Stage.stage_number() != OS.get_environment("GUARDIAN_STAGE"):
			continue
		main = MainScene.instantiate()
		add_child(main)
		main.get_node("NetPanel").queue_free()
		main.input_hub.scripted = true
		Route._quiet(get_tree())
		for danger in get_tree().get_nodes_in_group("instant_death"):
			if danger is Area2D:
				danger.collision_mask = 0
				danger.set_deferred("monitoring", false)
		await get_tree().physics_frame
		var cases := crossings()
		for step in cases:
			var reached := false
			var offsets: Array = [] if OS.get_cmdline_user_args().has("--assist-only") else [-8.0, 16.0, 32.0]
			for offset in offsets:
				for second in [-1, 12, 20, 28, 36, 44, 52, 64]:
					if await attack(step["from"], step["to"], offset, second):
						print("BYPASS ", step["name"], " takeoff=", offset, " second=", second)
						reached = true
						break
				if reached: break
			print("%s %s solo rejection" % ["FAIL" if reached else "ok", step["name"]])
			if reached: failures.append(String(step["name"]))
			# Positive control: the real guardian's recorded platforms work.
			if not await assisted(step):
				print("FAIL ", step["name"], " guardian route")
				failures.append(String(step["name"]) + " assisted")
			else:
				print("ok ", step["name"], " guardian route")
		main.free()
		await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	print("guardian required probe: ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func crossing(name: String, a: Rect2, b: Rect2) -> Dictionary:
	var platforms: Array[Rect2] = []
	var gap := b.position.x - a.end.x
	var count := maxi(1, ceili(gap / 240.0) - 1)
	for i in range(1, count + 1):
		var t := float(i) / (count + 1)
		var x := lerpf(a.end.x, b.position.x, t)
		var y := lerpf(a.position.y, b.position.y, t)
		platforms.append(Rect2(x - 75.0, y, 150.0, 20.0))
	return {"name": Stage.stage_number() + " " + name, "from": a, "to": b, "platforms": platforms}

func crossings() -> Array[Dictionary]:
	var ground := Stage.ground()
	match Stage.current():
		Stage.Which.GREENFIELD:
			return [crossing("first platform lesson", ground[2], ground[3]),
				crossing("final platform", ground[21], ground[22])]
		Stage.Which.HORROR:
			var out: Array[Dictionary] = []
			for i in [2, 6, 11, 17]: out.append(crossing("crossing %d" % i, ground[i], ground[i + 1]))
			return out
		Stage.Which.SKYWARD_RUINS:
			var relay := crossing("two-slab relay", ground[6], ground[7])
			# Approach the solid island vertically instead of driving into its
			# underside while the second jump is still rising.
			relay["platforms"] = [Rect2(-400, 4040, 150, 26), Rect2(-200, 3960, 150, 26),
				Rect2(0, 3880, 150, 26), Rect2(200, 3800, 150, 26)]
			return [relay]
		Stage.Which.DESERT:
			var out: Array[Dictionary] = [crossing("causeway", ground[6], ground[7])]
			for step in Stage.route():
				if step["via"] == "assist" and step["section"] == "rescue_wall":
					var copy := step.duplicate()
					copy["name"] = "1-6 rescue_wall"
					out.append(copy)
			return out
		Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.TOWER, Stage.Which.CAVE:
			var out: Array[Dictionary] = []
			for step in Stage.route():
				if step["via"] == "assist":
					var copy := step.duplicate()
					copy["name"] = Stage.stage_number() + " " + String(step["section"])
					out.append(copy)
			return out
	return []

func assisted(step: Dictionary) -> bool:
	main.guardian.clear_constructs()
	main._respawn_timer = -1.0
	if Stage.current() in [Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.TOWER, Stage.Which.CAVE] or step.get("section", "") == "rescue_wall":
		return await Route._assisted(get_tree(), main, main.runner, main.input_hub,
			step["from"], step["to"], step["platforms"], bool(step.get("sprint", false)))
	var chain: Array[Rect2] = [step["from"]]
	chain.append_array(step["platforms"])
	chain.append(step["to"])
	# Build just before each jump: real range/lifetime/recycling still apply.
	for i in chain.size() - 1:
		main._respawn_timer = -1.0
		var dir := signf(chain[i + 1].get_center().x - chain[i].get_center().x)
		var edge := chain[i].end.x if dir > 0 else chain[i].position.x
		main.runner.respawn(Vector2(edge - dir * minf(65.0, chain[i].size.x * 0.5), chain[i].position.y - 26))
		await get_tree().physics_frame
		if i < chain.size() - 2:
			main.guardian.gauge = Balance.GAUGE_MAX
			main.guardian.select_slot(1)
			main.guardian.place_path = PackedVector2Array()
			for _try in 4:
				if main.guardian.abilities[1].check(main.guardian, chain[i + 1].get_center()) != "blocked": break
				chain[i + 1].position.y -= 40
			main.guardian.use_active(chain[i + 1].get_center())
			await get_tree().physics_frame
		var ok := await Route._climb(get_tree(), main, main.runner, main.input_hub, chain[i], chain[i + 1], false, true)
		if not ok and not reached(main.runner, chain[i + 1]):
			print("assist miss ", chain[i], " -> ", chain[i + 1], " at ", main.runner.global_position,
				" refusal=", main.guardian._last_refusal)
			return false
	return true

func reached(r: Runner, b: Rect2) -> bool:
	# Standing on solid decor above the destination is also a successful bypass.
	return r.is_on_floor() and r.global_position.y < b.position.y \
		and r.global_position.x > b.position.x - 10 and r.global_position.x < b.end.x + 10

func attack(a: Rect2, b: Rect2, offset: float, second: int, keep: bool = false) -> bool:
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	if not keep: main.guardian.clear_constructs()
	main._respawn_timer = -1.0
	hub.drive_runner(0, 0, false, false)
	var dir := signf(b.get_center().x - a.get_center().x)
	var edge := a.end.x if dir > 0 else a.position.x
	r.respawn(Vector2(edge - dir * minf(100.0, a.size.x - 25.0), a.position.y - 26.0))
	main._snap_camera_to_runner()
	for _i in 12: await get_tree().physics_frame
	# A stronger approach than some rooms permit: rejection with this envelope
	# also rejects their slower actual approach. Never refresh it during flight.
	r.velocity.x = dir * Runner.sprint_cap(1.0)
	r.gear = 1.0
	var jumped := -1
	var recovery := 0
	for f in 210:
		if jumped < 0 and (edge - r.global_position.x) * dir <= 16.0 - offset:
			jumped = f
		var jump := jumped >= 0 and f < jumped + 22
		if second >= 0 and jumped >= 0:
			jump = jump or (f >= jumped + second and f < jumped + second + 22)
			if f == jumped + second - 1: jump = false
		if r.can_wall_jump() or r.hanging(): recovery += 1
		else: recovery = 0
		if recovery > 0: jump = recovery % 8 >= 2
		hub.drive_runner(dir, 0, jump, true)
		await get_tree().physics_frame
		if reached(r, b): return true
		if r.state == Runner.State.DEAD: return false
	return false
