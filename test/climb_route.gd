extends RefCounted
## Shared by the climbing stages' probes: every pair of consecutive solid
## ledges, climbed by a real runner with real input. Placed on the lower one,
## it jumps, steers towards the upper one like a player would, and has to end
## up standing on it. A layout rule that says "125px is under the jump" is a
## number; this is the physics agreeing with it.

## Which ground rectangles are climbing ledges (not the starting bank).
static func ledges(start_y: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in Stage.ground():
		if r.position.y < start_y:
			out.append(r)
	return out

## Returns the list of failed climbs as "from -> to" strings.
static func climb_all(tree: SceneTree, main: Node2D, max_rise: float) -> Array[String]:
	var failed: Array[String] = []
	var rects := ledges(Stage.start().y)
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	hub.scripted = true
	# The route, not its residents: nothing patrols or chases during this.
	for e in tree.get_nodes_in_group("enemy"):
		(e as Node).queue_free()
	await tree.physics_frame
	for i in range(rects.size() - 1):
		var a: Rect2 = rects[i]
		var b: Rect2 = rects[i + 1]
		var rise := a.position.y - b.position.y
		# Only neighbours: a gimmick ledge in between is not on this list.
		if rise <= 0.0 or rise > max_rise:
			continue
		# One retry: the previous climb can leave the runner mid-bounce (a
		# spring on its landing), and a player gets another go as well.
		if not await _climb(tree, main, r, hub, a, b) \
				and not await _climb(tree, main, r, hub, a, b):
			failed.append("%s -> %s" % [str(a.get_center().round()), str(b.get_center().round())])
	hub.drive_runner(0.0, 0.0, false, false)
	return failed

static func _climb(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		a: Rect2, b: Rect2) -> bool:
	# Start from the near half of the lower ledge, as a player would.
	var dir := signf(b.get_center().x - a.get_center().x)
	var start_x := a.get_center().x - dir * minf(40.0, a.size.x * 0.25)
	r.respawn(Vector2(start_x, a.position.y - 26.0))
	r.velocity = Vector2.ZERO
	hub.drive_runner(0.0, 0.0, false, false)
	main._snap_camera_to_runner()
	for _i in 12:
		await tree.physics_frame
	var target_x := b.get_center().x
	var pull := 0
	for f in 140:
		var dx := target_x - r.global_position.x
		var axis := 0.0 if absf(dx) < 18.0 else signf(dx)
		# Caught the ledge's edge: pull up with a fresh jump, as a player does.
		if r.state == Runner.State.HANG and pull == 0:
			pull = 12
		var jump := f < 22 or (pull > 0 and pull < 9)
		pull = maxi(0, pull - 1)
		hub.drive_runner(axis, 0.0, jump, false)
		await tree.physics_frame
		if f > 30 and _on(r, b):
			return true
	if OS.get_environment("CLIMB_DEBUG") != "":
		print("climb miss: ", a, " -> ", b, " ended at ", r.global_position, " floor=", r.is_on_floor(), " state=", r.state, " hp=", r.hp)
	return _on(r, b)

static func _on(r: Runner, b: Rect2) -> bool:
	return r.is_on_floor() and r.global_position.y < b.position.y \
		and r.global_position.y > b.position.y - 40.0 \
		and r.global_position.x > b.position.x - 10.0 and r.global_position.x < b.end.x + 10.0
