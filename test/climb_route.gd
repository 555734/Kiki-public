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

## Walks the stage's `route()`: every "jump" step is jumped by a real runner,
## every "assist" step is climbed over a real guardian platform placed where
## the route says, and "ride" steps (gimmicks) are left to the probes.
## Returns the list of failed steps as "via from -> to" strings.
static func climb_all(tree: SceneTree, main: Node2D, _max_rise: float = 0.0) -> Array[String]:
	var failed: Array[String] = []
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	hub.scripted = true
	# The route, not its residents: nothing patrols or chases during this.
	for e in tree.get_nodes_in_group("enemy"):
		(e as Node).queue_free()
	await tree.physics_frame
	for step in Stage.route():
		# Each step on its own: no platform left over from the one before.
		for h in main.guardian.holograms_of(Hologram.Kind.PLATFORM):
			h.queue_free()
		await tree.physics_frame
		var via := String(step["via"])
		var a: Rect2 = step["from"]
		var b: Rect2 = step["to"]
		var ok := true
		if via == "jump":
			ok = await _climb(tree, main, r, hub, a, b) or await _climb(tree, main, r, hub, a, b)
		elif via == "assist":
			ok = await _assisted(tree, main, r, hub, a, b, step["platform"])
		else:
			continue
		if not ok:
			failed.append("%s %s -> %s" % [via, str(a.get_center().round()), str(b.get_center().round())])
	hub.drive_runner(0.0, 0.0, false, false)
	return failed

## Out of reach alone: the guardian builds the platform, the runner uses it.
static func _assisted(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		a: Rect2, b: Rect2, plat: Rect2) -> bool:
	for attempt in 2:
		# Without the platform the step really is out of reach.
		var g = main.guardian
		g.gauge = Balance.GAUGE_MAX
		g.select_slot(1)
		g.place_path = PackedVector2Array()
		r.respawn(Vector2(a.get_center().x, a.position.y - 26.0))
		main._snap_camera_to_runner()
		await tree.physics_frame
		g._last_refusal = ""
		g.use_active(plat.get_center())
		await tree.physics_frame
		if OS.get_environment("CLIMB_DEBUG") != "":
			print("assist ", plat, " refusal=", g._last_refusal, " holos=",
				g.holograms_of(Hologram.Kind.PLATFORM).map(func(h): return [h.global_position, h.size, h.is_inside_tree()]))
		var p := Rect2(plat.position, plat.size)
		if await _climb(tree, main, r, hub, a, p, false) \
				and await _climb(tree, main, r, hub, p, b, false):
			return true
		for h in g.holograms_of(Hologram.Kind.PLATFORM):
			h.queue_free()
		await tree.physics_frame
	return false

static func _climb(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		a: Rect2, b: Rect2, place: bool = true) -> bool:
	# A death on the previous step: let the respawn play out first.
	for _i in 240:
		if r.state != Runner.State.DEAD:
			break
		await tree.physics_frame
	if place:
		# Start from the near half of the lower ledge, as a player would.
		var dir := signf(b.get_center().x - a.get_center().x)
		var start_x := a.get_center().x - dir * minf(40.0, a.size.x * 0.25)
		r.respawn(Vector2(start_x, a.position.y - 26.0))
		r.velocity = Vector2.ZERO
		main._snap_camera_to_runner()
	hub.drive_runner(0.0, 0.0, false, false)
	for _i in 12:
		await tree.physics_frame
	var target_x := b.get_center().x
	var dir2 := signf(target_x - a.get_center().x)
	var near_edge := a.end.x if dir2 > 0.0 else a.position.x
	var far_edge := b.position.x if dir2 > 0.0 else b.end.x
	# Run towards the target before jumping; a low step wants a short hop.
	var run_up := true
	var hold := 22 if a.position.y - b.position.y > 105.0 else 17
	var jump_at := -1 if run_up else 0
	var pull := 0
	var above := {}
	if OS.get_environment("CLIMB_DEBUG") != "":
		var q := PhysicsPointQueryParameters2D.new()
		for dy in range(40, 160, 10):
			for dx2 in [0, 40, 80]:
				q.position = r.global_position + Vector2(dx2 * dir2, -dy)
				for hit in r.get_world_2d().direct_space_state.intersect_point(q):
					above[str(hit.collider.get_parent().name) + ":" + str(hit.collider.global_position.round())] = true
	for f in 160:
		# Take off at the edge, or once the target's edge is a short hop away.
		if jump_at < 0 and ((near_edge - r.global_position.x) * dir2 < 22.0
				or (far_edge - r.global_position.x) * dir2 < 80.0 or f > 80):
			jump_at = f
		# Ease off ahead of the target, as a player does: the air carries on.
		var dx := target_x - r.global_position.x - r.velocity.x * 0.3
		var axis := 0.0 if absf(dx) < 18.0 else signf(dx)
		if jump_at < 0:
			axis = dir2
		# Caught the ledge's edge: pull up with a fresh jump, as a player does.
		if r.state == Runner.State.HANG and pull == 0:
			pull = 12
		var jump := (jump_at >= 0 and f >= jump_at and f < jump_at + hold
				and r.state != Runner.State.HANG) \
			or (pull > 0 and pull < 9)
		pull = maxi(0, pull - 1)
		hub.drive_runner(axis, 0.0, jump, false)
		await tree.physics_frame
		if OS.get_environment("CLIMB_TRACE") != "" and f % 6 == 0:
			print("   f=%d pos=%s v=%s floor=%s st=%d jump=%s ax=%d" % [f, r.global_position.round(), r.velocity.round(), r.is_on_floor(), r.state, jump, axis])
		if jump_at >= 0 and f > jump_at + 8 and _on(r, b):
			return true
	if OS.get_environment("CLIMB_DEBUG") != "":
		print("climb miss: ", a, " -> ", b, " ended at ", r.global_position, " floor=", r.is_on_floor(), " state=", r.state, " hp=", r.hp, " above=", above.keys())
	return _on(r, b)

static func _on(r: Runner, b: Rect2) -> bool:
	return r.is_on_floor() and r.global_position.y < b.position.y \
		and r.global_position.y > b.position.y - 40.0 \
		and r.global_position.x > b.position.x - 10.0 and r.global_position.x < b.end.x + 10.0
