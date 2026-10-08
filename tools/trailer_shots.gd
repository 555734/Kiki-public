extends Node
## The trailer's cut list and what happens in each shot. See capture_trailer.gd.
##
## A shot is a dictionary in list() plus a setup_<name>(ctx) function. Setup
## positions things and returns a per-tick callable; ctx["t"] is the tick
## (60 Hz) since the shot started recording, negative during the pre-roll.

const W := Stage.Which

var cap: Node = null

## Shot for shot, the reference trailer, cut where it cuts (film seconds):
##    0.0  one runner, caught                 4.0  pull back: everyone, at once
##    8.96 THIS IS YOU -- the guardian        11.29 the wide: a card, DRAW THE WAY
##   ~17.2 SAVE YOUR RUNNER, then a wall      22.21 the drop: the digest
##   35.88 black                              36.05 the title, where to get it
## Times inside a shot are film times too (film()), so the overlay, the cues
## and the action line up with the reference's.
func list() -> Array:
	return [
		{"name": "r01_caught", "stage": W.HORROR, "until": 4.0, "preroll": 30},
		{"name": "r02_crowd", "ffa": true, "until": 8.958, "preroll": 90 + 180 + 60},
		{"name": "r03_you", "stage": W.DESERT, "until": 22.833, "preroll": 60},
		{"name": "d01_cave", "stage": W.CAVE, "until": 24.792, "preroll": 30},
		{"name": "d02_menu", "stage": W.GREENFIELD, "menu": true, "until": 25.792, "preroll": 30},
		{"name": "d03_draw", "stage": W.GREENFIELD, "until": 26.75, "preroll": 30},
		{"name": "d04_spikes", "stage": W.SKYWARD_RUINS, "until": 27.5, "preroll": 30},
		{"name": "d05_brawl", "ffa": true, "until": 28.792, "preroll": 90 + 180 + 300},
		{"name": "d06_tower", "stage": W.TOWER, "until": 29.542, "preroll": 30},
		{"name": "d07_tower", "stage": W.TOWER, "until": 30.583, "preroll": 150},
		{"name": "d08_golem", "stage": W.SKYWARD_RUINS, "until": 31.875, "preroll": 30},
		{"name": "d09_cliff", "stage": W.SEA, "until": 33.9, "preroll": 30},
		{"name": "d10_lava", "stage": W.SWAMP, "until": 36.05, "preroll": 30},
		{"name": "e01_title", "stage": W.GREENFIELD, "until": 40.5, "preroll": 30},
	]

# --------------------------------------------------------------------- helpers

## Camera that follows a node (or holds a point) with its own framing and a
## zoom that eases across the shot. Runs after the runner's physics tick.
class Rig extends Node:
	var main: Node2D
	var follow: Node2D = null
	var offset := Vector2(0, -40)
	var lead := 120.0
	var smooth := 7.0
	## Vertical follow is lazier, with a dead band, as in play: a jump should
	## move the runner on the screen, not the screen with the runner.
	var smooth_y := 3.0
	var dead_y := 60.0
	var _anchor_y := 0.0
	var zoom_from := 1.0
	var zoom_to := 1.0
	var zoom_ticks := 1
	var point := Vector2.ZERO
	## Camera shake, in world pixels. Applied as the camera's offset so it
	## never feeds back into the follow.
	var shake := 0.0
	## An impact's jolt: added to the shake and dying away by itself.
	var kick := 0.0
	## The shot's framing multiplier, on top of the zoom it animates.
	var scale := 1.0
	var tick := 0
	var factor := 1.0
	var _snapped := false
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		process_priority = 300
		_rng.seed = 1234

	## A hard cut inside the shot: hold `at`, at zoom `z`, from the next frame.
	func cut_to(at: Vector2, z: float) -> void:
		follow = null
		point = at
		zoom_from = z
		zoom_to = z
		factor = z
		_snapped = false

	## Ease from the current zoom to `z` over `ticks` from now.
	func zoom_go(z: float, ticks: int) -> void:
		zoom_from = factor
		zoom_to = z
		zoom_ticks = ticks
		tick = 0

	func _process(delta: float) -> void:
		tick += 1
		var cam: Camera2D = main.camera
		var k := clampf(float(tick) / float(maxi(zoom_ticks, 1)), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		factor = lerpf(zoom_from, zoom_to, k)
		cam.zoom = Vector2.ONE * Balance.CAMERA_ZOOM * factor * scale
		kick *= 0.82
		cam.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * (shake + kick)
		var target := point
		if follow != null and is_instance_valid(follow):
			var y := follow.global_position.y
			if not _snapped:
				_anchor_y = y
			_anchor_y = clampf(_anchor_y, y - dead_y, y + dead_y)
			# Inside the band it still settles, slowly, on the runner's height.
			_anchor_y = lerpf(_anchor_y, y, clampf(delta * 1.2, 0.0, 1.0))
			target = Vector2(follow.global_position.x, _anchor_y) + offset
			if follow is CharacterBody2D:
				target.x += clampf((follow as CharacterBody2D).velocity.x
					/ Balance.RUNNER_RUN_SPEED, -1.0, 1.0) * lead
		if not _snapped:
			cam.global_position = target
			_snapped = true
		else:
			var p := cam.global_position
			p.x = lerpf(p.x, target.x, clampf(delta * smooth, 0.0, 1.0))
			p.y = lerpf(p.y, target.y, clampf(delta * smooth_y, 0.0, 1.0))
			cam.global_position = p

## Ledge to ledge along a stage's route, steered the way test/climb_route.gd
## steers it, one tick at a time so it can be filmed.
class Pilot extends RefCounted:
	var r: Runner
	var hub: InputHub
	var steps: Array = []   # {"from": Rect2, "to": Rect2, "double", "sprint", "hold"}
	var i := 0
	var f := 0
	var jump_at := -1
	var second_at := -1
	var pull := 0
	var wait := 0

	func done() -> bool:
		return i >= steps.size()

	func tick() -> void:
		if wait > 0:
			wait -= 1
			hub.drive_runner(0.0, 0.0, false, false)
			return
		if done():
			hub.drive_runner(0.0, 0.0, false, false)
			return
		var s: Dictionary = steps[i]
		var a: Rect2 = s["from"]
		var b: Rect2 = s["to"]
		var sprint := bool(s.get("sprint", false))
		var dir := signf(b.get_center().x - a.get_center().x)
		if dir == 0.0:
			dir = 1.0
		var near_edge := a.end.x if dir > 0.0 else a.position.x
		var far_edge := b.position.x if dir > 0.0 else b.end.x
		var overhead := b.position.x < r.global_position.x and b.end.x > r.global_position.x
		var hold := int(s.get("hold", 22 if a.position.y - b.position.y > 105.0 else 17))
		if f == 0 and overhead:
			jump_at = 0
		if jump_at < 0 and ((near_edge - r.global_position.x) * dir < 22.0
				or (far_edge - r.global_position.x) * dir < float(s.get("reach", 80.0))):
			jump_at = f
		if bool(s.get("double", false)) and jump_at >= 0 and second_at < 0 \
				and f > jump_at + 6 and r.velocity.y >= -40.0 and not r.is_on_floor():
			second_at = f + 1
		var dx := b.get_center().x - r.global_position.x - r.velocity.x * 0.3
		var axis := 0.0 if absf(dx) < 18.0 else signf(dx)
		if jump_at < 0:
			axis = dir
		if r.state == Runner.State.HANG and pull == 0:
			pull = 12
		var first := jump_at >= 0 and f >= jump_at and f < jump_at + hold \
			and (second_at < 0 or f < second_at - 1)
		var second := second_at >= 0 and f >= second_at and f < second_at + 20
		var jump := ((first or second) and r.state != Runner.State.HANG) \
			or (pull > 0 and pull < 9)
		pull = maxi(0, pull - 1)
		hub.drive_runner(axis, 0.0, jump, sprint)
		f += 1
		if jump_at >= 0 and f > jump_at + 8 and _on(b):
			i += 1
			f = 0
			jump_at = -1
			second_at = -1
			pull = 0
			# Let go between hops, or the next jump has no press edge.
			wait = maxi(2, int(s.get("wait", 0)))

	func _on(b: Rect2) -> bool:
		return r.is_on_floor() and r.global_position.y < b.position.y \
			and r.global_position.y > b.position.y - 40.0 \
			and r.global_position.x > b.position.x - 10.0 and r.global_position.x < b.end.x + 10.0

## Flat-out to the right, hopping whatever is in the way: a wall, a gap, an
## enemy. For the open stages, where there is no route to follow.
class AutoRun extends RefCounted:
	var r: Runner
	var hub: InputHub
	var sprint := true
	var hold := 18
	var _left := 0
	var _cool := 0
	var _hang := 0
	var _air_used := false

	func tick() -> void:
		# Caught a ledge: pull up with a fresh press, as a player does.
		if r.state == Runner.State.HANG:
			_hang += 1
			hub.drive_runner(1.0, 0.0, _hang % 12 >= 3 and _hang % 12 < 10, false)
			return
		_hang = 0
		var space := r.get_world_2d().direct_space_state
		var p := r.global_position
		var reach := 95.0 + absf(r.velocity.x) * 0.22
		var want := false
		if r.is_on_floor() and _cool <= 0:
			# Something solid ahead at body height.
			var wall := PhysicsRayQueryParameters2D.create(p + Vector2(0, -20), p + Vector2(reach, -20), 1 | 8)
			wall.exclude = [r.get_rid()]
			if not space.intersect_ray(wall).is_empty():
				want = true
			# No floor a stride ahead.
			var gap := PhysicsRayQueryParameters2D.create(p + Vector2(85, -10), p + Vector2(85, 160), 1 | 8)
			gap.exclude = [r.get_rid()]
			if space.intersect_ray(gap).is_empty():
				want = true
			# An enemy coming up.
			var q := PhysicsShapeQueryParameters2D.new()
			var c := CircleShape2D.new()
			c.radius = 70.0
			q.shape = c
			q.transform = Transform2D(0.0, p + Vector2(150, -20))
			q.collision_mask = 4
			if not space.intersect_shape(q, 1).is_empty():
				want = true
		if r.is_on_floor():
			_air_used = false
		elif not _air_used and _left <= -2 and r.velocity.y > 60.0:
			# Falling with nothing underneath: the second jump.
			var below := PhysicsRayQueryParameters2D.create(p + Vector2(70, 0), p + Vector2(110, 420), 1 | 8)
			below.exclude = [r.get_rid()]
			if space.intersect_ray(below).is_empty():
				want = true
				_air_used = true
		if want:
			_left = hold
			_cool = hold + 8
		_cool -= 1
		hub.drive_runner(1.0, 0.0, _left > 0, sprint)
		_left -= 1

## The guardian's finger drawing a platform: a bright stroke that grows from
## its first point to its last, then fades as the real hologram takes over.
class Stroke extends Node2D:
	const COLOR := Color(0.45, 0.92, 1.0)
	var points := PackedVector2Array()
	var grow := 0.0      # 0..1 of the stroke drawn
	var alpha := 1.0

	func _ready() -> void:
		z_index = 40

	## Where the finger is now: the growing end of the stroke.
	func head() -> Vector2:
		if points.size() < 2:
			return global_position
		var n := points.size()
		var upto := grow * float(n - 1)
		var k := mini(int(upto), n - 1)
		return points[k].lerp(points[mini(k + 1, n - 1)], fmod(upto, 1.0))

	func _draw() -> void:
		if points.size() < 2 or alpha <= 0.0:
			return
		var n := points.size()
		var upto := grow * float(n - 1)
		var drawn := PackedVector2Array()
		for k in n:
			if float(k) <= upto:
				drawn.append(points[k])
		var head := points[mini(int(upto), n - 1)].lerp(points[mini(int(upto) + 1, n - 1)], fmod(upto, 1.0))
		drawn.append(head)
		if drawn.size() >= 2:
			draw_polyline(drawn, Color(COLOR, 0.25 * alpha), 26.0, true)
			draw_polyline(drawn, Color(COLOR, 0.65 * alpha), 12.0, true)
			draw_polyline(drawn, Color(1, 1, 1, 0.95 * alpha), 4.5, true)
		if grow < 1.0:
			draw_circle(head, 22.0, Color(COLOR, 0.25 * alpha))
			draw_circle(head, 12.0, Color(1, 1, 1, 0.9 * alpha))

func rig(ctx: Dictionary) -> Rig:
	var r := Rig.new()
	r.main = ctx["main"]
	r.follow = r.main.runner
	r.main.add_child(r)
	r.scale = float((ctx["shot"] as Dictionary).get("zoom", 1.0))
	ctx["rig"] = r
	return r

## Hit-stop: the world holds for a few frames on an impact, with a flash and
## a jolt -- the beat that makes a hit read as a hit.
func impact(c: Dictionary, frames := 4, flash := 0.45) -> void:
	if c.has("main"):
		c["freeze"] = frames
	ov().flash(cap.shot_time(), 0.16, flash)
	if c.has("rig"):
		(c["rig"] as Rig).kick = 14.0

func pilot(ctx: Dictionary, steps: Array) -> Pilot:
	var p := Pilot.new()
	p.r = ctx["main"].runner
	p.hub = ctx["main"].input_hub
	p.steps = steps
	return p

func autorun(ctx: Dictionary) -> AutoRun:
	var a := AutoRun.new()
	a.r = ctx["main"].runner
	a.hub = ctx["main"].input_hub
	return a

## Staging: take the enemies out of a stretch a shot does not want them in.
func clear_enemies(ctx: Dictionary, area: Rect2) -> void:
	var m: Node2D = ctx["main"]
	for e in m.level.find_children("*", "Enemy", true, false):
		if area.has_point((e as Node2D).global_position):
			e.free()

func place_runner(ctx: Dictionary, at: Vector2) -> void:
	var m: Node2D = ctx["main"]
	m.runner.respawn(at)
	m.runner.velocity = Vector2.ZERO
	# No post-respawn blink: this is not a respawn, it is the shot's first frame.
	m.runner._invuln = 0.0

## Standing on a ledge: the runner's origin sits 26px above its top.
static func on_ledge(r: Rect2, along := 0.5) -> Vector2:
	return Vector2(lerpf(r.position.x + 20.0, r.end.x - 20.0, along), r.position.y - 26.0)

func stroke(ctx: Dictionary) -> Stroke:
	var s := Stroke.new()
	ctx["main"].add_child(s)
	return s

## A hand-drawn line across a platform's slot: a little wobble, as a finger has.
static func hand_line(rect: Rect2, wobble := 5.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var y := rect.position.y + 6.0
	for k in 16:
		var u := float(k) / 15.0
		out.append(Vector2(lerpf(rect.position.x, rect.end.x, u), y + sin(u * PI * 1.6) * wobble))
	return out

## Commit a drawn stroke as a real platform, exactly as a guardian's release
## does: the stroke becomes the platform's shape.
func build(ctx: Dictionary, points: PackedVector2Array) -> void:
	var g: Guardian = ctx["main"].guardian
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	var center := ((lo + hi) * 0.5).round()
	var shape := PackedVector2Array()
	for p in points:
		shape.append((p - center).round())
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(1)
	g.place_path = shape
	g._last_refusal = ""
	g.use_active(center)
	g.place_path = PackedVector2Array()
	if g._last_refusal != "":
		push_warning("trailer: platform at %s refused: %s" % [center, g._last_refusal])

func shoot(ctx: Dictionary, at: Vector2) -> void:
	var g: Guardian = ctx["main"].guardian
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(3)
	g.use_active(at)

## Route steps of the current stage, by section name.
static func route_steps(section: String) -> Array:
	var out: Array = []
	for s in Stage.route():
		if String(s.get("section", "")) == section:
			out.append(s)
	return out

func ov() -> Node:
	return cap.overlay

## Seconds to ticks.
static func T(sec: float) -> int:
	return int(round(sec * 60.0))

# ----------------------------------------------------------------- play

## The star battle: both seats played by the game's own practice partner
## (VersusCpu), each with its own seed, so the match is a real one.
func arena_play(ctx: Dictionary, zoom: float, seeds := [11, 29]) -> Callable:
	var a: Node = ctx["arena"]
	var cpus := [VersusCpu.new(seeds[0]), VersusCpu.new(seeds[1])]
	return func(c: Dictionary) -> void:
		a.menu.visible = false
		a._layer.visible = false
		var stars: Array[Vector2] = []
		for coin in a.coins():
			if int(coin["state"]) == ArenaCoin.State.WORLD:
				stars.append(coin["position"])
		for i in 2:
			(cpus[i] as VersusCpu).think(a.runners[i], a.input.hubs[i],
				a.runners[1 - i].global_position, stars, a.match_rules, i)
		var cam: Camera2D = a.view.camera
		cam.zoom = Vector2.ONE * VersusRules.CAMERA_ZOOM * zoom
		# Frame the two of them, not just P1: the camera follows P1, and the
		# offset moves the picture to their midpoint.
		var p0: Vector2 = a.runners[0].global_position
		var p1: Vector2 = VersusStageData.nearest_image(a.runners[1].global_position, p0)
		var want := (p0 + p1) * 0.5 + Vector2(0, -40) - cam.global_position
		cam.offset = cam.offset.lerp(want, 0.12)

## みんなで スターたいせん: eight seats, every one played by VersusCpu. The
## pre-roll seats everyone, presses start and sits out the countdown; `fit`
## frames all eight (zooming to hold them), otherwise P1 at `zoom`. With
## `open_zoom` the shot opens that tight and pulls back from there.
func ffa_play(ctx: Dictionary, zoom: float, fit: bool, open_zoom := 0.0) -> Callable:
	var host: Node = ctx["arena"]
	var scenes: Array = ctx["ffa"]
	var cpus: Array = []
	for i in scenes.size():
		cpus.append(VersusCpu.new(100 + i * 37))
	var preroll := int((ctx["shot"] as Dictionary).get("preroll", 0))
	var state := {"started": false, "zoom": zoom, "lined_up": false}
	# Everyone starts on the widest platform and goes for each other there:
	# one brawl in one place, rather than eight people spread over the arena.
	var stage_floor := Rect2()
	for r in VersusStageData.floors():
		if r.size.x > stage_floor.size.x:
			stage_floor = r
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		for sc in scenes:
			if sc.menu != null:
				sc.menu.visible = false
		host._layer.visible = false
		if not state["started"] and t >= -preroll + 90 and host.can_start():
			host._start_button.pressed.emit()
			state["started"] = true
		var all_moving := true
		for sc in scenes:
			all_moving = all_moving and sc.can_move()
		if all_moving and not state["lined_up"]:
			state["lined_up"] = true
			for i in scenes.size():
				var sc = scenes[i]
				var me: Runner = sc.runners[sc.local_team]
				var x := lerpf(stage_floor.position.x + 60.0, stage_floor.end.x - 60.0,
					float(i) / float(scenes.size() - 1))
				me.global_position = Vector2(x, stage_floor.position.y - 26.0)
				me.velocity = Vector2.ZERO
			host.host.forget_positions()
		var none: Array[Vector2] = []
		for i in scenes.size():
			var sc = scenes[i]
			if not sc.can_move():
				continue
			var me: Runner = sc.runners[sc.local_team]
			(cpus[i] as VersusCpu).think(me, sc.input.hubs[0],
				host.runners[(i + 3) % scenes.size()].global_position, none,
				host.match_rules, sc.local_team)
		var cam: Camera2D = host.view.camera
		if t == 0 and open_zoom > 0.0:
			# Open tight on one of them, and let the framing pull back.
			state["zoom"] = open_zoom
		var p0: Vector2 = host.runners[0].global_position
		var want_zoom: float = state["zoom"]
		var centre := p0
		if fit:
			# Frame the bunch: everyone near the median runner, so one who
			# has fallen away does not pull the whole shot wide.
			var pts: Array[Vector2] = []
			for r in host.runners:
				if r.visible:
					pts.append(VersusStageData.nearest_image(r.global_position, p0))
			var xs := pts.map(func(v: Vector2) -> float: return v.x)
			var ys := pts.map(func(v: Vector2) -> float: return v.y)
			xs.sort()
			ys.sort()
			var mid := Vector2(xs[xs.size() / 2], ys[ys.size() / 2])
			var box := Rect2(mid, Vector2.ZERO)
			for v in pts:
				if v.distance_to(mid) < 520.0:
					box = box.expand(v)
			centre = box.get_center()
			var view := Vector2(1280, 720) / Balance.CAMERA_ZOOM
			want_zoom = clampf(minf(view.x / (box.size.x + 300.0), view.y / (box.size.y + 260.0)), 0.95, zoom)
		state["zoom"] = lerpf(float(state["zoom"]), want_zoom, 0.08)
		cam.zoom = Vector2.ONE * VersusRules.CAMERA_ZOOM * float(state["zoom"])
		cam.offset = cam.offset.lerp(centre + Vector2(0, -40) - cam.global_position, 0.12)

## Draw a stroke's state for this tick: visible, how much of it is drawn, and
## fading out once it has become a platform (`after` ticks past completion).
func _paint(s: Stroke, points: PackedVector2Array, on: bool, grow: float, after: int) -> void:
	s.points = points
	s.visible = on
	s.grow = grow
	s.alpha = 1.0 - clampf(float(after) / 12.0, 0.0, 1.0)
	s.queue_redraw()

## The co-op interface, as a player sees it: both players' controls.
func show_hud(ctx: Dictionary) -> void:
	var m: Node2D = ctx["main"]
	var hud: CanvasLayer = m.get_node("Hud")
	hud.visible = true
	hud.process_mode = Node.PROCESS_MODE_INHERIT
	m.input_hub.solo_role = ""

## A guardian-assisted crossing from a stage's route: the guardian draws each
## platform just ahead of the runner, who crosses on them. `draw_at` is when
## each stroke starts, in seconds; the runner sets off at `go_at`.
func assisted(ctx: Dictionary, step: Dictionary, draw_at: Array, go_at: float,
		sprint: bool) -> Callable:
	var a: Rect2 = step["from"]
	var b: Rect2 = step["to"]
	var plats: Array = step["platforms"]
	var lines: Array = []
	var strokes: Array = []
	for p in plats:
		lines.append(hand_line(p))
		strokes.append(stroke(ctx))
	var chain: Array = [a]
	chain.append_array(plats)
	chain.append(b)
	var hops: Array = []
	for k in chain.size() - 1:
		hops.append({"from": chain[k], "to": chain[k + 1], "sprint": sprint})
	var go := pilot(ctx, hops)
	var draw_len := T(0.40)
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		for k in strokes.size():
			var s: Stroke = strokes[k]
			var t0 := T(float(draw_at[k]))
			s.points = lines[k]
			s.grow = clampf(float(t - t0) / float(draw_len), 0.0, 1.0)
			s.alpha = 1.0 - clampf(float(t - t0 - draw_len) / 12.0, 0.0, 1.0)
			s.visible = t >= t0
			s.queue_redraw()
			if t == t0 + draw_len:
				build(c, lines[k])
		if t < T(go_at):
			drive(c, 0.0)
		else:
			go.tick()

## Ledge to ledge along the given route steps.
func hops(ctx: Dictionary, steps: Array, start_along := 0.3) -> Pilot:
	place_runner(ctx, on_ledge(steps[0]["from"], start_along))
	return pilot(ctx, steps)

func route_slice(from_index: int, count: int) -> Array:
	return Stage.route().slice(from_index, from_index + count)

## The stage's pursuer, if it has one.
func pursuer_of(ctx: Dictionary) -> Node2D:
	var m: Node2D = ctx["main"]
	for e in get_tree().get_nodes_in_group("instant_death"):
		if e.has_method("stunned") and m.is_ancestor_of(e):
			return e
	return null

## A drawn line from `from` to `to`, bowed by `bulge` (negative is upwards) --
## a stroke a finger makes in one sweep.
static func arc_line(from: Vector2, to: Vector2, bulge: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 24:
		var u := float(k) / 23.0
		out.append(from.lerp(to, u) + Vector2(0, sin(u * PI) * bulge))
	return out

## A death, as the digest shows it: a flash and a jolt as it lands.
func dies(ctx: Dictionary, inner: Callable) -> Callable:
	var m: Node2D = ctx["main"]
	var s := {"at": -1}
	return func(c: Dictionary) -> void:
		inner.call(c)
		if m.runner.state == Runner.State.DEAD and int(s["at"]) < 0 and int(c["t"]) >= 0:
			s["at"] = c["t"]
			impact(c, 5, 0.7)

func drive(ctx: Dictionary, axis: float, jump := false, sprint := false) -> void:
	(ctx["main"].input_hub as InputHub).drive_runner(axis, 0.0, jump, sprint)

## Film seconds, as ticks of the current shot: the reference's timings.
static func film(ctx: Dictionary, sec: float) -> int:
	return T(sec - float(ctx["film_start"]))

## Film seconds, as the overlay's shot seconds.
static func film_s(ctx: Dictionary, sec: float) -> float:
	return sec - float(ctx["film_start"])

## Where a world rect is on the screen, in design pixels.
static func on_screen(ctx: Dictionary, world: Rect2) -> Rect2:
	var xf: Transform2D = (ctx["main"] as Node).get_viewport().get_canvas_transform()
	var a := xf * world.position
	var b := xf * world.end
	return Rect2(a, b - a).abs()

## The 1-6 creature of `kind` nearest to `near`.
func desert_enemy(ctx: Dictionary, kind: String, near: Vector2) -> DesertEnemy:
	var best: DesertEnemy = null
	for n in (ctx["main"] as Node).level.find_children("*", "", true, false):
		if n is DesertEnemy and (n as DesertEnemy).kind == kind:
			if best == null or (n as Node2D).global_position.distance_to(near) \
					< best.global_position.distance_to(near):
				best = n
	return best

## Steer a jelly along a straight line between film times: its own drift
## stays, small, on top.
static func glide(j: DesertEnemy, from: Vector2, to: Vector2, k: float) -> void:
	if not is_instance_valid(j):
		return
	j.patrol_half_width = 14.0
	j._origin = from.lerp(to, clampf(k, 0.0, 1.0))

func place_wall(ctx: Dictionary, at: Vector2) -> void:
	var g: Guardian = ctx["main"].guardian
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(2)
	g._last_refusal = ""
	g.use_active(at)
	if g._last_refusal != "":
		push_warning("trailer: wall at %s refused: %s" % [at, g._last_refusal])

# ----------------------------------------------------------------------- shots

## 0.0-4.0. 1-2: one runner, running, the camera alongside. The pursuer
## comes up from behind and takes them. The camera stops where it is and the
## empty frame holds -- until the ground starts to shake.
func setup_r01_caught(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	place_runner(ctx, Vector2(-760, 300))
	# Held weakly: the stage frees its pursuer once it has made the catch.
	var hold := weakref(pursuer_of(ctx))
	var r := rig(ctx)
	r.zoom_from = 1.0
	r.zoom_to = 1.0
	r.lead = 0.0
	r.offset = Vector2(190, -70)
	r.smooth = 9.0
	r.dead_y = 40.0
	var run := autorun(ctx)
	run.sprint = false
	var s := {"dead": -1}
	var shake_at := film(ctx, 3.3)
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		var pursuer: Node2D = hold.get_ref()
		if t == -20 and pursuer != null:
			pursuer.global_position = m.runner.global_position + Vector2(-660, -24)
			pursuer._wake_left = 0.0
			pursuer._activated = true
			pursuer.cruise_speed = 470.0
		if t < -12:
			drive(c, 0.0)
			return
		if m.runner.state == Runner.State.DEAD:
			if int(s["dead"]) < 0:
				s["dead"] = t
				r.cut_to(m.camera.global_position, r.factor)
			drive(c, 0.0)
		else:
			run.tick()
		if t == shake_at:
			cap.cue("rumble")
		r.shake = clampf(float(t - shake_at) / float(T(0.7)), 0.0, 1.0) * 6.0 if t >= shake_at else 0.0

## 4.0-8.96. みんなで スターたいせん: the cut lands tight, the ground still
## shaking, and pulls straight back to all eight of them going at it.
func setup_r02_crowd(ctx: Dictionary) -> Callable:
	var inner := ffa_play(ctx, 1.15, true, 2.6)
	var stop := T(0.9)
	return func(c: Dictionary) -> void:
		inner.call(c)
		var t: int = c["t"]
		var cam: Camera2D = (ctx["arena"] as Node).view.camera
		var shake := clampf(1.0 - float(t) / float(stop), 0.0, 1.0) * 6.0
		cam.offset += Vector2(sin(t * 2.7), cos(t * 3.1)) * shake
		if t == stop:
			cap.cue("rumble_stop")

## 8.96-22.83. 1-6, one continuous take on the mirage crossing.
##   8.96   tight on the guardian's light: THIS IS YOU. 10.0 everything stops.
##  11.29   the wide. The platform card lands, and turns into the grid over
##          the gap; the music comes in; the bridge is drawn as the runner
##          arrives and crosses it. DRAW THE WAY.
##  ~17.2   the rifle's grid: the stage's pursuer comes for the runner and is
##          shot back, twice. SAVE YOUR RUNNER.
##  ~21.3   the wall's grid; the wall goes up.
##  22.21   the drop: hard in on the wall and the runner.
func setup_r03_you(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var g: Guardian = m.guardian
	var hub: InputHub = m.input_hub
	var step: Dictionary = route_steps("mirage_crossing")[0]
	var a: Rect2 = step["from"]
	var b: Rect2 = step["to"]
	place_runner(ctx, Vector2(3085, a.position.y - 26.0))
	m.runner.facing = 1
	for e in [desert_enemy(ctx, "scarab", Vector2(3390, 103)), desert_enemy(ctx, "cactus", Vector2(4550, 187))]:
		if e != null:
			e.free()
	# The jellies stay out of it; the stage's pursuer is held back until it is
	# wanted, then comes for the runner across the gap.
	for near in [Vector2(3890, 45), Vector2(4870, 45)]:
		glide(desert_enemy(ctx, "jelly", near), Vector2(near.x, -2400), Vector2(near.x, -2400), 0.0)
	var pursuer := pursuer_of(ctx)
	if pursuer != null:
		pursuer.global_position = Vector2(1500, 300)
		pursuer._activated = true
		pursuer._wake_left = 9999.0
	# The guardian's light, hovering over the gap, the reticle up.
	hub.solo_role = ""
	g.select_slot(3)
	(m.get_node("GuardianWisp") as Node).set("_awake", true)
	var light := Vector2(3700, 30)
	var r := rig(ctx)
	var close_z := 2.4
	var light_at := Vector2(930, 372)
	var cam_z := Balance.CAMERA_ZOOM * close_z
	# The light hovers 22px over the aim.
	r.cut_to(light + Vector2(0, -22) - (light_at - Vector2(640, 360)) / cam_z, close_z)
	var wide := Vector2(4035, -64)
	var wide_z := 0.52
	var tag_size := 110
	var tag_k := tag_size / 72.0
	var tag_w: float = ov().TAG_FONT.get_string_size("THIS IS YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x
	var arrow_tip := light_at + Vector2(-34, 52)
	var arrow_from := arrow_tip - Vector2(38, -38) * tag_k
	ov().tag([[film_s(ctx, 9.0), "THIS"], [film_s(ctx, 9.5), "THIS IS YOU"]], film_s(ctx, 11.0),
		Vector2(arrow_from.x - 12.0 * tag_k - tag_w, arrow_from.y + tag_size * 0.12), tag_size)
	ov().card("platform", film_s(ctx, 11.29), film_s(ctx, 12.87))
	ov().title([[film_s(ctx, 15.5), "DRAW"], [film_s(ctx, 15.9), "DRAW THE WAY"]],
		film_s(ctx, 17.3), Vector2(640, 238))
	ov().blueprint("snipe", film_s(ctx, 17.2), film_s(ctx, 18.2))
	ov().title([[film_s(ctx, 20.0), "SAVE"], [film_s(ctx, 20.4), "SAVE YOUR RUNNER"]],
		film_s(ctx, 21.45), Vector2(640, 238))
	ov().blueprint("wall", film_s(ctx, 21.3), film_s(ctx, 22.21))
	# The bridge: two strokes, each ending level with the ground it meets.
	var mid := (a.end.x + b.position.x) * 0.5
	var mid_y := lerpf(a.position.y, b.position.y, 0.5)
	var lines := [
		arc_line(Vector2(a.end.x + 18, a.position.y + 13), Vector2(mid - 10, mid_y + 13), -14.0),
		arc_line(Vector2(mid + 14, mid_y + 15), Vector2(b.position.x - 16, b.position.y + 13), -12.0),
	]
	var strokes := [stroke(ctx), stroke(ctx)]
	var draw_at := [film(ctx, 13.4), film(ctx, 14.2)]
	var draw_len := T(0.4)
	var gap_rect := Rect2(a.end.x - 20, a.position.y - 90, b.position.x - a.end.x + 40, 200)
	var wall_at := Vector2(b.position.x + 128, b.position.y - Balance.WALL_SIZE.y * 0.5 - 2.0)
	var stand_x := b.position.x + 40.0
	# The pursuer: woken over the gap, shot back twice.
	var chase_from := Vector2(a.end.x - 20, a.position.y - 70)
	var t_chase := film(ctx, 17.35)
	var shots := [film(ctx, 18.3), film(ctx, 19.95)]
	var t_wide := film(ctx, 11.29)
	var t_drop := film(ctx, 22.21)
	var t_run := film(ctx, 13.3)
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		var rn: Runner = m.runner
		# The light idles over the gap until the wide; then it is the hand.
		var drift := Vector2(sin(t * 0.03) * 16.0, cos(t * 0.041) * 10.0)
		var aim := light + drift
		if t == film(ctx, 10.0):
			cap.cue("silence")
		if t == t_wide:
			r.cut_to(wide, wide_z)
			r.zoom_go(wide_z * 0.97, film(ctx, 22.21) - t_wide)
			cap.cue("card")
		if t == film(ctx, 12.87) or t == film(ctx, 17.2) or t == film(ctx, 21.3):
			cap.cue("grid")
		if t == film(ctx, 13.3):
			cap.cue("music_in")
		# The bridge.
		for k in 2:
			var t0: int = draw_at[k]
			_paint(strokes[k], lines[k], t >= t0, clampf(float(t - t0) / float(draw_len), 0.0, 1.0),
				t - t0 - draw_len)
			if t >= t0 and t <= t0 + draw_len:
				aim = (strokes[k] as Stroke).head()
			if t == t0 + draw_len:
				build(c, lines[k])
				g.select_slot(3)
		# The runner: in from the left as the music comes in, across, and stops.
		if t < t_run:
			drive(c, 0.0)
		elif rn.global_position.x < stand_x and rn.global_position.y < b.position.y + 40.0:
			drive(c, 1.0, false, true)
		else:
			var hop := t >= t_drop + 2 and t < t_drop + 16
			drive(c, 0.0, hop)
		# The pursuer comes for the runner; the guardian knocks it back, twice,
		# the second time for good.
		if pursuer != null:
			if t == t_chase:
				pursuer.global_position = chase_from
				pursuer._wake_left = 0.0
			for k in shots.size():
				var ts: int = shots[k]
				if t > ts - 24 and t <= ts:
					aim = aim.lerp(pursuer.global_position, 0.5)
				if t == ts:
					if k == shots.size() - 1:
						pursuer.stun_duration = 30.0
					shoot(c, pursuer.global_position)
		# The wall.
		if t > film(ctx, 21.4) and t < film(ctx, 22.0):
			aim = aim.lerp(wall_at, 0.25)
		if t == film(ctx, 22.0):
			place_wall(c, wall_at)
			g.select_slot(3)
		if t >= film(ctx, 21.3):
			ov().blueprint_rect = on_screen(c, Rect2(wall_at - Vector2(70, 120), Vector2(140, 240)))
		elif t >= film(ctx, 17.2):
			ov().blueprint_rect = on_screen(c, Rect2(chase_from - Vector2(100, 90), Vector2(200, 180)))
		else:
			ov().blueprint_rect = on_screen(c, gap_rect)
		# The drop: hard in on the wall and the runner.
		if t == t_drop:
			r.cut_to(Vector2((stand_x + wall_at.x) * 0.5 - 10.0, b.position.y - 110.0), 1.45)
			cap.cue("drive_in")
		hub.aim_at_world(aim)

# ------------------------------------------------------------------ the digest

## 22.83-24.79. 1-8: up the mine mouth, ledge to ledge.
func setup_d01_cave(ctx: Dictionary) -> Callable:
	var go := hops(ctx, route_slice(0, 5), 0.5)
	var r := rig(ctx)
	r.zoom_from = 1.25
	r.zoom_to = 1.4
	r.zoom_ticks = T(2.0)
	r.offset = Vector2(0, 40)
	r.dead_y = 30.0
	r.lead = 0.0
	return func(c: Dictionary) -> void:
		if int(c["t"]) < -12:
			drive(c, 0.0)
		else:
			go.tick()

## 24.79-25.79. The start screen, as a player first sees it.
func setup_d02_menu(_ctx: Dictionary) -> Callable:
	return func(_c: Dictionary) -> void:
		pass

## 25.79-26.75. 1-1: the grid, a stroke, the platform pops in -- and the
## camera jumps in on it.
func setup_d03_draw(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var start := Stage.start()
	place_runner(ctx, start)
	m.input_hub.solo_role = ""
	var line := arc_line(start + Vector2(150, -60), start + Vector2(330, -78), -10.0)
	var st := stroke(ctx)
	var r := rig(ctx)
	var centre := start + Vector2(240, -80)
	r.cut_to(centre + Vector2(-40, 30), 1.25)
	ov().blueprint("platform", 0.0, 0.42)
	var t0 := T(0.1)
	var len := T(0.3)
	var snap := film(ctx, 26.25)
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		ov().blueprint_rect = on_screen(c, Rect2(centre - Vector2(140, 70), Vector2(280, 140)))
		_paint(st, line, t >= t0, clampf(float(t - t0) / float(len), 0.0, 1.0), t - t0 - len)
		m.input_hub.aim_at_world(st.head() if t >= t0 else line[0])
		if t == t0 + len:
			build(c, line)
		if t == snap:
			r.cut_to(centre + Vector2(0, 10), 2.1)
		drive(c, 0.0)

## 26.75-27.5. 1-3, as close as it goes: straight into the spikes.
func setup_d04_spikes(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var island := Rect2(-520, 6380, 760, 150)
	place_runner(ctx, on_ledge(island, 0.05))
	var r := rig(ctx)
	r.zoom_from = 3.0
	r.zoom_to = 2.4
	r.zoom_ticks = T(0.75)
	r.offset = Vector2(30, -20)
	r.dead_y = 40.0
	r.lead = 40.0
	return func(c: Dictionary) -> void:
		m.runner.hp = 1
		if m.runner.state == Runner.State.DEAD and r.follow != null:
			r.cut_to(m.camera.global_position, r.factor)
			r.zoom_go(r.factor * 0.85, T(0.5))
		drive(c, 1.0 if int(c["t"]) > -46 else 0.0, false, true)

## 27.5-28.79. The star battle, eight of them, wide.
func setup_d05_brawl(ctx: Dictionary) -> Callable:
	return ffa_play(ctx, 1.0, true)

func _tower(ctx: Dictionary, z: float) -> Callable:
	var go := hops(ctx, route_slice(0, 6), 0.6)
	var r := rig(ctx)
	r.zoom_from = z
	r.zoom_to = z * 1.06
	r.zoom_ticks = T(1.0)
	r.offset = Vector2(0, -90)
	r.dead_y = 30.0
	r.lead = 0.0
	return func(c: Dictionary) -> void:
		if int(c["t"]) < 14 - int((ctx["shot"] as Dictionary)["preroll"]):
			drive(c, 0.0)
		else:
			go.tick()

## 28.79-29.54 and 29.54-30.58. 1-7: the clockwork tower, wide, then close.
func setup_d06_tower(ctx: Dictionary) -> Callable:
	return _tower(ctx, 0.8)

func setup_d07_tower(ctx: Dictionary) -> Callable:
	return _tower(ctx, 1.45)

## 30.58-31.88. 1-3: the pursuer rises out of the clouds; the shot knocks it
## back down.
func setup_d08_golem(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var island := Rect2(-520, 6380, 760, 150)
	place_runner(ctx, on_ledge(island, 0.3))
	var pursuer := pursuer_of(ctx)
	var r := rig(ctx)
	r.zoom_from = 1.05
	r.zoom_to = 1.2
	r.zoom_ticks = T(1.3)
	r.offset = Vector2(110, 70)
	r.dead_y = 40.0
	r.lead = 0.0
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		if t == -20 and pursuer != null:
			pursuer.global_position = m.runner.global_position + Vector2(230, 380)
		if t == -1:
			m.runner.facing = 1
		drive(c, 0.0, t >= T(0.6) and t < T(0.9))
		if pursuer != null and t == T(0.5):
			shoot(c, pursuer.global_position)
			impact(c, 4, 0.35)

## 31.88-33.9. 1-4's cliff: two platforms drawn up a sheer face, climbed as
## they appear.
func setup_d09_cliff(ctx: Dictionary) -> Callable:
	var step: Dictionary = route_steps("cliff_rescue")[0]
	place_runner(ctx, on_ledge(step["from"], 0.35))
	clear_enemies(ctx, Rect2((step["from"] as Rect2).position - Vector2(600, 900), Vector2(1500, 1400)))
	ctx["main"].input_hub.solo_role = ""
	var r := rig(ctx)
	r.zoom_from = 1.0
	r.zoom_to = 1.1
	r.zoom_ticks = T(2.0)
	r.offset = Vector2(60, -150)
	r.dead_y = 40.0
	r.lead = 0.0
	return assisted(ctx, step, [-0.05, 0.6], 0.15, false)

## 33.9-35.88, then black. 1-5: across the lava on drawn platforms, wide.
func setup_d10_lava(ctx: Dictionary) -> Callable:
	var step: Dictionary = route_steps("cold_rock_rescue")[1]
	place_runner(ctx, on_ledge(step["from"], 0.3))
	ctx["main"].input_hub.solo_role = ""
	var r := rig(ctx)
	r.zoom_from = 0.8
	r.zoom_to = 0.86
	r.zoom_ticks = T(2.0)
	r.offset = Vector2(160, -60)
	r.dead_y = 120.0
	r.lead = 40.0
	var black := film_s(ctx, 35.875)
	ov().fade(black, black + 0.001, 0.0, 1.0)
	return assisted(ctx, step, [0.0, 0.5], 0.1, true)

## 36.05-40.5. The title over 1-1's opening field.
func setup_e01_title(ctx: Dictionary) -> Callable:
	place_runner(ctx, Vector2(-200, 374))
	var r := rig(ctx)
	r.zoom_from = 1.15
	r.zoom_to = 1.0
	r.zoom_ticks = T(4.4)
	r.offset = Vector2(120, -60)
	r.smooth = 2.0
	cap.cue("drive_out")
	cap.cue("hit")
	ov().flash(0.0, 0.35, 0.9)
	ov().end_card(0.15, "MELOS GAME", ["AVAILABLE NOW", "GOOGLE PLAY", "APP STORE"])
	ov().fade(4.0, 4.45, 0.0, 1.0)
	return func(c: Dictionary) -> void:
		drive(c, 1.0 if int(c["t"]) > -12 else 0.0)
