extends RefCounted
## Shared by the climbing stages' probes: the stage's `route()`, climbed by a
## real runner with real input. Placed on the lower ledge, it jumps, steers
## towards the upper one like a player would, and has to end up standing on
## it. A layout rule that says "125px is under the jump" is a number; this is
## the physics agreeing with it.
##
## Steps (see SectionBuilder):
##   jump    -- one jump, held
##   double  -- a jump, then the mid-air second jump at its top
##   assist  -- the guardian builds the step's platforms, the runner climbs them
##   ride    -- a gimmick does the carrying: springs, pads, warps and updrafts
##              are flown as they are; timed pieces (lifts, gears, hands,
##              blinks, belts, crumbles) are tried from several points of the
##              stage clock, since every one of them is a function of it, and
##              the step passes if a patient player could make it

## CLIMB_TRACE prints the runner frame by frame; CLIMB_TRACE_ROOM keeps that
## to one room.
static var _tracing := false

## Which ground rectangles are climbing ledges (not the starting bank).
static func ledges(start_y: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in Stage.ground():
		if r.position.y < start_y:
			out.append(r)
	return out

## Walks every step of the route. Returns the failed ones as
## "section: via from -> to" strings.
static func climb_all(tree: SceneTree, main: Node2D, _max_rise: float = 0.0,
		only: Array = []) -> Array[String]:
	var failed: Array[String] = []
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	hub.scripted = true
	_quiet(tree)
	await tree.physics_frame
	if OS.get_environment("CLIMB_TICK") != "":
		Clock.tick = int(OS.get_environment("CLIMB_TICK"))
	for step in Stage.route():
		if not only.is_empty() and not only.has(String(step.get("section", ""))):
			continue
		if OS.get_environment("CLIMB_DEBUG") != "":
			print("step %s %s at tick %d" % [step.get("section", "?"), step["via"], Clock.tick])
		var room_filter := OS.get_environment("CLIMB_TRACE_ROOM")
		_tracing = OS.get_environment("CLIMB_TRACE") != "" \
			and (room_filter == "" or room_filter == String(step.get("section", "")))
		# Each step on its own: no platform left over from the one before.
		for h in main.guardian.holograms_of(Hologram.Kind.PLATFORM):
			h.queue_free()
		await tree.physics_frame
		var via := String(step["via"])
		var a: Rect2 = step["from"]
		var b: Rect2 = step["to"]
		var ok := true
		match via:
			"jump":
				if step.has("tries"):
					ok = await _timed_jump(tree, main, r, hub, a, b, step)
				else:
					ok = await _climb(tree, main, r, hub, a, b) or await _climb(tree, main, r, hub, a, b)
			"double":
				ok = await _climb(tree, main, r, hub, a, b, true, true) \
					or await _climb(tree, main, r, hub, a, b, true, true)
			"assist":
				ok = await _assisted(tree, main, r, hub, a, b, step["platforms"])
			"ride":
				ok = await _ride(tree, main, r, hub, step)
		if not ok:
			failed.append("%s: %s%s %s -> %s" % [step.get("section", "?"), via,
				(" " + String(step["how"])) if step.has("how") else "",
				str(a.get_center().round()), str(b.get_center().round())])
	hub.drive_runner(0.0, 0.0, false, false)
	return failed

## The route, not its residents: nothing patrols, chases or swings while it is
## walked. The timed traps are checked for their safe beats by the probes.
static func _quiet(tree: SceneTree) -> void:
	for e in tree.get_nodes_in_group("enemy"):
		(e as Node).queue_free()
	for t in tree.get_nodes_in_group("instant_death"):
		if t is Area2D:
			(t as Area2D).collision_layer = 0
			(t as Area2D).set_deferred("monitorable", false)

## Out of reach alone: the guardian builds the platforms, the runner uses them.
static func _assisted(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		a: Rect2, b: Rect2, plats: Array) -> bool:
	for attempt in 2:
		var g = main.guardian
		for h in g.holograms_of(Hologram.Kind.PLATFORM):
			h.queue_free()
		await tree.physics_frame
		r.respawn(Vector2(a.get_center().x, a.position.y - 26.0))
		main._snap_camera_to_runner()
		await tree.physics_frame
		for p in plats:
			g.gauge = Balance.GAUGE_MAX
			g.select_slot(1)
			g.place_path = PackedVector2Array()
			g._last_refusal = ""
			g.use_active((p as Rect2).get_center())
			await tree.physics_frame
			if OS.get_environment("CLIMB_DEBUG") != "":
				print("assist ", p, " refusal=", g._last_refusal)
		var chain: Array[Rect2] = [a]
		for p in plats:
			chain.append(p)
		chain.append(b)
		var ok := true
		for i in chain.size() - 1:
			if not await _climb(tree, main, r, hub, chain[i], chain[i + 1], i == 0):
				ok = false
				break
		if ok:
			return true
	return false

static func _climb(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		a: Rect2, b: Rect2, place: bool = true, double: bool = false) -> bool:
	# A death on the previous step: let the respawn play out first.
	for _i in 240:
		if r.state != Runner.State.DEAD:
			break
		await tree.physics_frame
	if place:
		# Start from the back of the lower ledge, as a player taking a run-up
		# would -- or right under a ledge that is overhead.
		var dir := signf(b.get_center().x - a.get_center().x)
		var start_x := a.get_center().x - dir * maxf(0.0, minf(a.size.x * 0.5 - 30.0, 110.0))
		if b.position.x < a.get_center().x and b.end.x > a.get_center().x \
				and a.position.y - b.position.y > 60.0:
			start_x = clampf(b.get_center().x, a.position.x + 20.0, a.end.x - 20.0)
		r.respawn(Vector2(start_x, a.position.y - 26.0))
		r.velocity = Vector2.ZERO
		main._snap_camera_to_runner()
	hub.drive_runner(0.0, 0.0, false, false)
	for _i in 12:
		await tree.physics_frame
	var target_x := b.get_center().x
	var dir2 := signf(target_x - a.get_center().x)
	if dir2 == 0.0:
		dir2 = 1.0
	var near_edge := a.end.x if dir2 > 0.0 else a.position.x
	var far_edge := b.position.x if dir2 > 0.0 else b.end.x
	# Directly overhead (a jump-through ledge): no run-up, just go up.
	var overhead := b.position.x < r.global_position.x and b.end.x > r.global_position.x
	var hold := 22 if a.position.y - b.position.y > 105.0 else 17
	var jump_at := 0 if overhead else -1
	var second_at := -1
	var pull := 0
	for f in 200:
		# Take off at the edge, or once the target's edge is a short hop away.
		if jump_at < 0 and ((near_edge - r.global_position.x) * dir2 < 22.0
				or (far_edge - r.global_position.x) * dir2 < 80.0 or f > 80):
			jump_at = f
		# The second jump goes at the top of the first.
		if double and jump_at >= 0 and second_at < 0 and f > jump_at + 6 \
				and r.velocity.y >= -40.0 and not r.is_on_floor():
			second_at = f + 1
		# Ease off ahead of the target, as a player does: the air carries on.
		var dx := target_x - r.global_position.x - r.velocity.x * 0.3
		var axis := 0.0 if absf(dx) < 18.0 else signf(dx)
		if jump_at < 0:
			axis = dir2
		# Caught the ledge's edge: pull up with a fresh jump, as a player does.
		if r.state == Runner.State.HANG and pull == 0:
			pull = 12
		var first := jump_at >= 0 and f >= jump_at and f < jump_at + hold \
			and (second_at < 0 or f < second_at - 1)
		var second := second_at >= 0 and f >= second_at and f < second_at + 20
		var jump := ((first or second) and r.state != Runner.State.HANG) \
			or (pull > 0 and pull < 9)
		pull = maxi(0, pull - 1)
		hub.drive_runner(axis, 0.0, jump, false)
		await tree.physics_frame
		if _tracing and f % 6 == 0:
			print("   f=%d pos=%s v=%s floor=%s st=%d jump=%s ax=%d" % [f, r.global_position.round(), r.velocity.round(), r.is_on_floor(), r.state, jump, axis])
		if jump_at >= 0 and f > jump_at + 8 and _on(r, b):
			return true
	if OS.get_environment("CLIMB_DEBUG") != "":
		print("climb miss: ", a, " -> ", b, " ended at ", r.global_position, " floor=", r.is_on_floor(), " state=", r.state)
	return _on(r, b)

static func _on(r: Runner, b: Rect2) -> bool:
	return r.is_on_floor() and r.global_position.y < b.position.y \
		and r.global_position.y > b.position.y - 40.0 \
		and r.global_position.x > b.position.x - 10.0 and r.global_position.x < b.end.x + 10.0

# --------------------------------------------------------------------- rides
static func _ride(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		step: Dictionary) -> bool:
	match String(step["how"]):
		"spring", "pad":
			return await _thrown(tree, main, r, hub, step)
		"warp":
			return await _warped(tree, main, r, hub, step)
		"updraft":
			return await _lifted(tree, main, r, hub, step)
		"timed":
			return await _timed(tree, main, r, hub, step)
		"gate", "echo":
			return await _opened(tree, main, r, hub, step)
	return false

## A jump that only works at some point of the stage clock (off a belt while it
## runs the right way): tried from several starting ticks.
static func _timed_jump(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		a: Rect2, b: Rect2, step: Dictionary) -> bool:
	var start_tick := Clock.tick
	for k in int(step["tries"]):
		await _set_clock(tree, r, a, start_tick + k * int(step.get("spacing", 20)))
		if await _climb(tree, main, r, hub, a, b):
			return true
	return false

## Moves the stage clock for the next try. The runner is put down on solid
## ground first: a lift jumped across the shaft in one tick would fling
## anyone standing on it.
static func _set_clock(tree: SceneTree, r: Runner, on: Rect2, to_tick: int) -> void:
	r.respawn(Vector2(on.get_center().x, on.position.y - 26.0))
	r.velocity = Vector2.ZERO
	await tree.physics_frame
	await tree.physics_frame
	Clock.tick = to_tick
	await tree.physics_frame

## The guardian shoots the right target first: a gate opens, or a hidden
## bridge rises. Then the runner goes on through.
static func _opened(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		step: Dictionary) -> bool:
	var id := String(step["id"])
	var want := int(step.get("sigil", 0))
	r.respawn(Vector2((step["from"] as Rect2).get_center().x, (step["from"] as Rect2).position.y - 26.0))
	main._snap_camera_to_runner()
	await tree.physics_frame
	var shot := false
	for node in tree.get_nodes_in_group("switch"):
		if node is ShootableSwitch and node.switch_id == id and (want == 0 or node.sigil == want):
			node.take_damage(1)
			shot = true
			break
	if not shot:
		if OS.get_environment("CLIMB_DEBUG") != "":
			print("no switch ", id, " sigil ", want)
		return false
	for _i in 30:
		await tree.physics_frame
	return await _climb(tree, main, r, hub, step["from"], step["to"], false)

## Dropped onto a spring or a pad and steered at the landing.
static func _thrown(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		step: Dictionary) -> bool:
	var b: Rect2 = step["to"]
	var at: Vector2 = step["at"]
	if String(step["how"]) == "pad":
		# A pad that turns round: start from a tick it points the right way.
		var want := int(step.get("dir", 0))
		for node in main.level._dynamic.get_children():
			if node is TrickPad and node.global_position.distance_to(at) < 2.0 and want != 0:
				var t := Clock.tick
				for _i in 600:
					if node.direction_at(t) == want and not node.warning_at(t) \
							and node.direction_at(t + 60) == want:
						break
					t += 5
				Clock.tick = t
	for attempt in 2:
		r.respawn(at + Vector2(0, -60.0))
		r.velocity = Vector2.ZERO
		main._snap_camera_to_runner()
		hub.drive_runner(0.0, 0.0, false, false)
		var launched := false
		for f in 300:
			if r.velocity.y < -300.0:
				launched = true
			var axis := 0.0
			if launched:
				var dx := b.get_center().x - r.global_position.x - r.velocity.x * 0.35
				axis = 0.0 if absf(dx) < 16.0 else signf(dx)
				# Rising past something solid: hold off, or the arc is pulled
				# into its edge. A ledge that can be jumped through is fine.
				if not Stage.ground_is_one_way(b) and r.global_position.y > b.position.y + 10.0 \
						and r.velocity.y < 0.0 \
						and absf(r.global_position.x - b.get_center().x) < b.size.x * 0.5 + 30.0:
					axis = 0.0
			hub.drive_runner(axis, 0.0, false, false)
			await tree.physics_frame
			if _tracing and f % 6 == 0:
				print("   s f=%d pos=%s v=%s floor=%s ceil=%s st=%d ax=%d" % [f, r.global_position.round(), r.velocity.round(), r.is_on_floor(), r.is_on_ceiling(), r.state, axis])
			if launched and f > 10 and _on(r, b):
				return true
	return false

## Stepped into a warp's mouth: comes out at its exit and lands on the step's
## ledge.
static func _warped(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		step: Dictionary) -> bool:
	var b: Rect2 = step["to"]
	var at: Vector2 = step["at"]
	r.respawn(at)
	r.velocity = Vector2.ZERO
	main._snap_camera_to_runner()
	hub.drive_runner(0.0, 0.0, false, false)
	for f in 240:
		var dx := b.get_center().x - r.global_position.x
		var axis := 0.0 if absf(dx) < 20.0 or f < 20 else signf(dx)
		hub.drive_runner(axis, 0.0, false, false)
		await tree.physics_frame
		if f > 20 and _on(r, b):
			return true
	if OS.get_environment("CLIMB_DEBUG") != "":
		print("warp miss: at ", at, " ended at ", r.global_position)
	return false

## Up a column of air: into it from the lower ledge, then off at the top.
static func _lifted(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		step: Dictionary) -> bool:
	var a: Rect2 = step["from"]
	var b: Rect2 = step["to"]
	var col: Vector2 = step["at"]
	for attempt in 2:
		var dir := signf(col.x - a.get_center().x)
		r.respawn(Vector2(a.get_center().x - dir * minf(40.0, a.size.x * 0.25), a.position.y - 26.0))
		r.velocity = Vector2.ZERO
		main._snap_camera_to_runner()
		hub.drive_runner(0.0, 0.0, false, false)
		for _i in 10:
			await tree.physics_frame
		var jumped := -1
		for f in 420:
			var high := r.global_position.y < b.position.y - 20.0
			var tx := b.get_center().x if high else col.x
			var dx := tx - r.global_position.x - r.velocity.x * 0.25
			var axis := 0.0 if absf(dx) < 14.0 else signf(dx)
			var jump := false
			if jumped < 0 and r.is_on_floor() and absf(r.global_position.x - col.x) < 120.0:
				jumped = f
			if jumped >= 0 and f < jumped + 18:
				jump = true
			hub.drive_runner(axis, 0.0, jump, false)
			await tree.physics_frame
			if _tracing and f % 6 == 0:
				print("   u f=%d pos=%s v=%s floor=%s ceil=%s st=%d jump=%s ax=%d" % [f, r.global_position.round(), r.velocity.round(), r.is_on_floor(), r.is_on_ceiling(), r.state, jump, axis])
				var ups := []
				for u in tree.get_nodes_in_group("updraft"):
					ups.append([u.global_position.round(), u.span, u.holds(r.global_position), u.runner == r])
				print("      phys=%s ts=%s real=%s motion=%s ups=%s" % [r.is_physics_processing(), Engine.time_scale, r.get_real_velocity().round(), r.get_last_motion().round(), ups])
				for ci in r.get_slide_collision_count():
					var hit := r.get_slide_collision(ci)
					print("      hit ", hit.get_collider(), " at ", hit.get_position().round(), " n=", hit.get_normal())
			if f > 20 and _on(r, b):
				return true
	return false

## A piece that moves with the stage clock. Tried from several starting ticks;
## each time the runner waits on the ledge until the next piece is in reach,
## hops on, rides it, and hops off at the landing when that comes in reach.
static func _timed(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		step: Dictionary) -> bool:
	var a: Rect2 = step["from"]
	var b: Rect2 = step["to"]
	var pieces: Array[Node2D] = []
	for p in step.get("pieces", []):
		var node := _find_piece(main, p)
		if node == null:
			if OS.get_environment("CLIMB_DEBUG") != "":
				print("timed: no piece at ", p)
			return false
		pieces.append(node)
	var start_tick := Clock.tick
	var tries := int(step.get("tries", 12))
	var spacing := int(step.get("spacing", 23))
	for k in tries:
		await _set_clock(tree, r, a, start_tick + k * spacing)
		if await _timed_once(tree, main, r, hub, a, b, pieces, step):
			return true
		if OS.get_environment("CLIMB_DEBUG") != "":
			print("  timed try %d: ended at %s v=%s floor=%s state=%d" % [k, r.global_position.round(), r.velocity.round(), r.is_on_floor(), r.state])
	return false

static func _timed_once(tree: SceneTree, main: Node2D, r: Runner, hub: InputHub,
		a: Rect2, b: Rect2, pieces: Array[Node2D], step: Dictionary) -> bool:
	var first_x := b.get_center().x
	if not pieces.is_empty():
		first_x = _surface(pieces[0], r).get_center().x
	var dir := signf(first_x - a.get_center().x)
	r.respawn(Vector2(a.get_center().x + dir * minf(30.0, a.size.x * 0.25), a.position.y - 26.0))
	r.velocity = Vector2.ZERO
	main._snap_camera_to_runner()
	hub.drive_runner(0.0, 0.0, false, false)
	for _i in 6:
		await tree.physics_frame
	var index := 0
	var hold := 0
	var limit := int(step.get("frames", 900))
	for f in limit:
		if r.state == Runner.State.DEAD or r.global_position.y > a.position.y + 500.0:
			return false
		var aim: Rect2 = b if index >= pieces.size() else _surface(pieces[index], r)
		if index < pieces.size() and r.is_on_floor() and _standing_on(r, pieces[index]):
			index += 1
			hold = 0
			continue
		if index >= pieces.size() and _on(r, b):
			return true
		var axis := 0.0
		var jump := false
		if hold > 0:
			hold -= 1
			jump = true
			var dx := aim.get_center().x - r.global_position.x - r.velocity.x * 0.3
			axis = 0.0 if absf(dx) < 14.0 else signf(dx)
		elif r.is_on_floor():
			if _reachable(r, aim, step):
				hold = 20
				jump = true
				axis = signf(aim.get_center().x - r.global_position.x)
			elif index == 0:
				# Still on the ledge: wait at its edge nearest the piece, as a
				# player does, rather than in the middle.
				var wait_x := clampf(aim.get_center().x, a.position.x + 24.0, a.end.x - 24.0)
				if aim.size.x <= 0.0:
					wait_x = clampf(b.get_center().x, a.position.x + 24.0, a.end.x - 24.0)
				var dw := wait_x - r.global_position.x
				axis = 0.0 if absf(dw) < 10.0 else signf(dw)
			else:
				# Riding: walk towards what comes next -- up a clock hand, to
				# the near edge of a lift -- but never off what is carrying us.
				var under := _surface(pieces[index - 1], r)
				var toward := aim.get_center().x if aim.size.x > 0.0 else b.get_center().x
				if under.size.x > 0.0:
					var stay_x := clampf(toward, under.position.x + 20.0, under.end.x - 20.0)
					var ds := stay_x - r.global_position.x
					axis = 0.0 if absf(ds) < 10.0 else signf(ds)
		else:
			var dx2 := aim.get_center().x - r.global_position.x - r.velocity.x * 0.3
			axis = 0.0 if absf(dx2) < 14.0 else signf(dx2)
		hub.drive_runner(axis, 0.0, jump, false)
		await tree.physics_frame
		if _tracing and (f % 5 == 0 or OS.get_environment("CLIMB_TRACE") == "all"):
			print("   t ceil=%s f=%d i=%d pos=%s v=%s floor=%s st=%d coy=%.2f buf=%.2f ext=%s aim=%s jump=%s ax=%d" % [r.is_on_ceiling(), f, index, r.global_position.round(), r.velocity.round(), r.is_on_floor(), r.state, r._coyote, r._jump_buffer, r._external_takeoff_pending, aim, jump, axis])
	return false

## Close enough for a jump from here: no higher than a held jump goes, and
## near enough across for one -- with room to spare, since a player jumping
## off something that moves does not get a run-up.
static func _reachable(r: Runner, aim: Rect2, step: Dictionary) -> bool:
	if aim.size.x <= 0.0:
		return false
	var feet := r.global_position.y + Balance.RUNNER_SIZE.y * 0.5
	var rise := feet - aim.position.y
	var gap := maxf(0.0, maxf(aim.position.x - r.global_position.x, r.global_position.x - aim.end.x))
	if rise > float(step.get("max_rise", 125.0)) or rise < -420.0:
		return false
	return gap <= air_reach(rise) * 0.7

## How far across a held jump carries the runner by the time it is back down
## to `rise` above where it left.
static func air_reach(rise: float) -> float:
	var up := absf(Balance.RUNNER_JUMP_VELOCITY) / Balance.RUNNER_GRAVITY
	var down := sqrt(2.0 * maxf(0.0, Balance.RUNNER_JUMP_HEIGHT - rise) / Balance.RUNNER_FALL_GRAVITY)
	return Balance.RUNNER_RUN_SPEED * (up + down)

## The top of what a piece offers to stand on right now, in world space: its
## highest live, roughly level collision box.
static func _surface(node: Node2D, r: Runner) -> Rect2:
	var best := Rect2()
	var best_score := INF
	for child in node.get_children():
		if not child is CollisionShape2D:
			continue
		var cs := child as CollisionShape2D
		if cs.disabled or not cs.shape is RectangleShape2D:
			continue
		var tilt := absf(wrapf(cs.global_rotation, -PI, PI))
		if tilt > 0.55 and absf(tilt - PI) > 0.55:
			continue
		var size := (cs.shape as RectangleShape2D).size
		var box := Rect2(cs.global_position - size * 0.5, size)
		var score := box.get_center().distance_to(r.global_position)
		if score < best_score:
			best_score = score
			best = box
	return best

static func _standing_on(r: Runner, node: Node2D) -> bool:
	for i in r.get_slide_collision_count():
		if r.get_slide_collision(i).get_collider() == node:
			return true
	return false

## The built node a route step names by its spec position.
static func _find_piece(main: Node2D, at: Vector2) -> Node2D:
	for node in main.level._dynamic.get_children():
		if not node is Node2D:
			continue
		var origin: Vector2 = node.get("_origin") if node.get("_origin") != null else (node as Node2D).global_position
		if origin.distance_to(at) < 2.0 or (node as Node2D).global_position.distance_to(at) < 2.0:
			return node
	return null
