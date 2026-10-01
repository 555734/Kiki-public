extends Node
## Every stage's ground, crossed by a real runner. For every climb and every
## pit in every stage, both ways: a run-up as long as the floor allows, a
## jump at the edge (or at the wall, or to climb off a ledge), and the
## runner must end up standing past it. The layout rules in versus_probe are
## numbers; this is the physics agreeing with them.
##
## Found, when the stages first got hills: rows of blocks over a take-off
## (the jump hits them and drops into the pit) and pits that were also climbs.

func _ready() -> void:
	var fails := 0
	var springs_tried := 0
	for which in VersusStageData.THEMES:
		VersusLaunch.clear()
		VersusLaunch.how = VersusLaunch.How.SOLO
		VersusLaunch.stage = which
		var arena: Node = load("res://src/versus/versus_main.tscn").instantiate()
		add_child(arena)
		for i in range(30):
			await get_tree().physics_frame
		var floors := VersusStageData.floors()
		floors.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
		var r: Runner = arena.runners[0]
		arena.runners[1].visible = false   # not solid, not in the way
		for i in range(floors.size() - 1):
			for dir in [1, -1]:
				var a: Rect2 = floors[i] if dir > 0 else floors[i + 1]
				var b: Rect2 = floors[i + 1] if dir > 0 else floors[i]
				if is_equal_approx(a.end.x, b.position.x) and a.position.y <= b.position.y and dir > 0:
					continue  # walking down/flat
				var edge: float = a.end.x if dir > 0 else a.position.x
				var gap: bool = not is_equal_approx(a.end.x if dir > 0 else a.position.x,
					b.position.x if dir > 0 else b.end.x)
				var climb: bool = b.position.y < a.position.y - 1.0
				if not gap and not climb:
					continue   # walking down a step needs nothing
				# A run-up like a player's: as long as the floor allows, and not
				# starting inside a pipe.
				var run := minf(200.0, a.size.x - 20.0)
				var start_x: float = edge - run * float(dir)
				for tries in range(20):
					var box := Rect2(Vector2(start_x - 16.0, a.position.y - 47.0), Vector2(32.0, 46.0))
					var blocked := false
					var solids := VersusStageData.solid_decor()
					for g in VersusStageData.belts() + VersusStageData.movers():
						solids.append(Rect2(g["centre"] - g["span"] * 0.5, g["span"]))
					for pad in VersusStageData.springs():
						solids.append(Rect2(pad - Vector2(45.0, 70.0), Vector2(90.0, 70.0)))
					for solid in solids:
						if solid.intersects(box):
							blocked = true
					if not blocked:
						break
					start_x += 12.0 * float(dir)
				r.respawn(Vector2(start_x, a.position.y - 26.0))
				r.facing = dir
				for k in range(70):
					await get_tree().physics_frame
				var landed := false
				arena.set_physics_process(false)
				var held := 0
				var rest := 0
				for k in range(180):
					var front: float = r.global_position.x + 15.0 * float(dir)
					# On a, or on something standing on it (a belt, a step).
					var on_a: bool = r.global_position.y + 23.0 <= a.position.y + 4.0
					var at_edge: bool = r.is_on_floor() and on_a and (front - edge) * float(dir) > -4.0
					var stuck: bool = (r.is_on_floor() and absf(r.velocity.x) < 40.0 and k > 15) \
						or r.state == Runner.State.HANG
					var want: bool = at_edge or stuck or (held > 0 and not r.is_on_floor())
					if rest > 0:
						rest -= 1
						want = false
					elif held > 24 and (r.is_on_floor() or r.state == Runner.State.HANG):
						want = false
						rest = 2
					held = held + 1 if want else 0
					# Over a narrow target and above it: stop steering and drop
					# onto it, as a player would, rather than sail past.
					var over_b: bool = r.global_position.x > b.position.x + 10.0 \
						and r.global_position.x < b.end.x - 10.0 \
						and r.global_position.y + 23.0 < b.position.y and b.size.x < 200.0
					arena.input.hubs[0].drive_runner(0.0 if over_b else float(dir), 0.0, want, false)
					await get_tree().physics_frame
					if r.is_on_floor() and (r.global_position.x - edge) * float(dir) > 20.0 \
							and r.global_position.y + 23.0 <= b.position.y + 4.0:
						landed = true
						break
					# Landed on a spring over there and thrown up: across.
					if over_b and r.velocity.y < -Balance.SPRING_VELOCITY * 0.5:
						landed = true
						break
				arena.input.hubs[0].drive_runner(0.0, 0.0, false, false)
				arena.set_physics_process(true)
				if not landed:
					fails += 1
					print("CANNOT %s: %s(top %.0f) -> %s(top %.0f) dir %d, ended %s" % [VersusStageData.theme_label(which), a, a.position.y, b, b.position.y, dir, r.global_position])
		# Every spring gets a runner up to the high row it is beside.
		for pad in VersusStageData.springs():
			var target := Rect2()
			var best := INF
			for row in VersusStageData.solid_decor():
				if row.position.y > pad.y - 150.0:
					continue   # not the upper tier
				var d := maxf(0.0, maxf(row.position.x - pad.x, pad.x - row.end.x))
				if d < best:
					best = d
					target = row
			if best > 250.0:
				continue
			springs_tried += 1
			r.respawn(Vector2(pad.x, pad.y - 26.0))
			arena.set_physics_process(false)
			var up := false
			for k in range(150):
				var steer := 0.0
				if r.velocity.y < 0.0 or r.global_position.y + 23.0 < target.position.y:
					var centre := target.get_center().x
					if absf(r.global_position.x - centre) > 20.0:
						steer = signf(centre - r.global_position.x)
				arena.input.hubs[0].drive_runner(steer, 0.0, false, false)
				await get_tree().physics_frame
				if r.is_on_floor() and absf(r.global_position.y + 23.0 - target.position.y) < 4.0:
					up = true
					break
			arena.input.hubs[0].drive_runner(0.0, 0.0, false, false)
			arena.set_physics_process(true)
			if not up:
				fails += 1
				print("CANNOT %s: the spring at %s does not reach %s (ended %s)" % [
					VersusStageData.theme_label(which), pad, target, r.global_position])
		arena.queue_free()
		await get_tree().process_frame
	print("versus reach probe: %d crossings failed (%d springs to the upper tier tried)" % [fails, springs_tried])
	get_tree().quit(0 if fails == 0 else 1)
