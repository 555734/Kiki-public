extends Node
## The trailer's cut list and what happens in each shot. See capture_trailer.gd.
##
## A shot is a dictionary in list() plus a setup_<name>(ctx) function. Setup
## positions things and returns a per-tick callable; ctx["t"] is the tick
## (60 Hz) since the shot started recording, negative during the pre-roll.

const W := Stage.Which

var cap: Node = null

## The call, all of it on 1-9 -- the stage built for it. Shot the way the
## reference is: the camera holds still on a frame that has the whole of a
## moment in it -- the setup, the act, the result -- and only moves between
## moments, either fast in to a face and held, or slowly back. Nothing is
## zoomed on the hit itself, and the result is never left off the frame.
## Film seconds:
##    0.0  locked on the stair and the spike block: the runner hops the stair,
##         stops under the block, looks up -- and is crushed.
##    2.4  one take at the gatehouse. The gate is shut; the hound comes and
##         waits. The phone rings -- in close on the face -- the finger comes
##         -- THIS IS YOU -- and holds the gate up; the hound gets the bars.
##    9.6  the drop: each trick in one locked frame, start to finish -- the
##         hound shot off their heels, the spiked ball held still, the
##         cannonball sent home, the bridge drawn over the moat, the spike block
##         held up, the slingshot, the giant flicked away.
##   28.0  in close at the castle door, slowly back to the whole castle and
##         the title.
func list() -> Array:
	return [
		{"name": "a1_crush", "stage": W.CASTLE, "until": 2.4, "preroll": 30},
		{"name": "a2_gate", "stage": W.CASTLE, "until": 9.6, "preroll": 30},
		{"name": "d1b_snipe", "stage": W.CASTLE, "until": 12.0, "preroll": 30},
		{"name": "d2_ball", "stage": W.CASTLE, "until": 14.4, "preroll": 30},
		{"name": "d3_cannon", "stage": W.CASTLE, "until": 17.2, "preroll": 30},
		{"name": "d1_bridge", "stage": W.CASTLE, "until": 19.6, "preroll": 30},
		{"name": "d4_block", "stage": W.CASTLE, "until": 22.0, "preroll": 30},
		{"name": "d6_sling", "stage": W.CASTLE, "until": 24.4, "preroll": 30},
		{"name": "d7_golem", "stage": W.CASTLE, "until": 28.0, "preroll": 30},
		{"name": "e1_title", "stage": W.CASTLE, "until": 33.4, "preroll": 30},
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
	## A camera move between two held points (dolly_to), eased in and out --
	## or, for the slow pull back, fast away and settling (ease_out).
	var _dolly_from := Vector2.ZERO
	var _dolly_to := Vector2.ZERO
	var _dolly_ticks := 0
	var _dolly_t := 0
	var ease_out := false

	func _ready() -> void:
		process_priority = 300
		_rng.seed = 1234
		# The game's own jolts (Events.screen_kick) shake the trailer's camera
		# too: this camera owns the offset while filming. Only a jolt -- the
		# lens never moves on a hit, or the hit reads smaller, not bigger.
		# A method, not a lambda: it is let go of with the rig, between shots.
		Events.screen_kick.connect(_on_kick)

	func _on_kick(s: float) -> void:
		kick = maxf(kick, s * 0.5)

	## Move the held point from where the camera is to `at` over `ticks`.
	func dolly_to(at: Vector2, ticks: int) -> void:
		follow = null
		_dolly_from = main.camera.global_position
		_dolly_to = at
		_dolly_ticks = maxi(ticks, 1)
		_dolly_t = 0
		point = _dolly_from

	## A hard cut inside the shot: hold `at`, at zoom `z`, from the next frame.
	func cut_to(at: Vector2, z: float) -> void:
		follow = null
		_dolly_ticks = 0
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

	## The camera's one move between held frames: to `at`, at zoom `z`. Fast
	## (a few ticks) to go in on a face; slow, with `settle`, to pull back.
	func move(at: Vector2, z: float, ticks: int, settle := false) -> void:
		ease_out = settle
		dolly_to(at, ticks)
		zoom_go(z, ticks)

	func _ease(u: float) -> float:
		if ease_out:
			return 1.0 - pow(1.0 - u, 3.0)
		return u * u * (3.0 - 2.0 * u)

	func _process(delta: float) -> void:
		tick += 1
		var cam: Camera2D = main.camera
		var k := clampf(float(tick) / float(maxi(zoom_ticks, 1)), 0.0, 1.0)
		factor = lerpf(zoom_from, zoom_to, _ease(k))
		cam.zoom = Vector2.ONE * Balance.CAMERA_ZOOM * factor * scale
		if _dolly_ticks > 0 and follow == null:
			_dolly_t = mini(_dolly_t + 1, _dolly_ticks)
			var u := float(_dolly_t) / float(_dolly_ticks)
			point = _dolly_from.lerp(_dolly_to, _ease(u))
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
func impact(c: Dictionary, frames := 4, flash := 0.3) -> void:
	if c.has("main"):
		c["freeze"] = frames
	ov().flash(cap.shot_time(), 0.12, flash)
	if c.has("rig"):
		(c["rig"] as Rig).kick = 8.0

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
			impact(c, 5, 0.3)

func drive(ctx: Dictionary, axis: float, jump := false, sprint := false) -> void:
	(ctx["main"].input_hub as InputHub).drive_runner(axis, 0.0, jump, sprint)

## Film seconds, as ticks of the current shot: the reference's timings.
static func film(ctx: Dictionary, sec: float) -> int:
	return T(sec - float(ctx["film_start"]))

## Film seconds, as the overlay's shot seconds.
static func film_s(ctx: Dictionary, sec: float) -> float:
	return sec - float(ctx["film_start"])

## Where a world rect is on the screen, in design pixels.
##
## A locked frame has to leave the finger room: on the shared screen the lower
## left quarter is the runner's stick and the tools sit low on the right, so a
## touch that starts there is not the hand's. The frames below keep the road
## in the upper half where the finger lands on it, or the act on the right.
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

# ------------------------------------------------------------------ the hand

const CALLER := "ORION"

## The guardian's finger on the screen, at a world point -- through the real
## touch path, so the hand, the cursor and the act are the game's own.
func _screen(ctx: Dictionary, world: Vector2) -> Vector2:
	return (ctx["main"] as Node).get_viewport().get_canvas_transform() * world

func finger_down(ctx: Dictionary, world: Vector2) -> void:
	(ctx["main"].input_hub as InputHub)._touch_down(31, _screen(ctx, world))

func finger_move(ctx: Dictionary, world: Vector2) -> void:
	(ctx["main"].input_hub as InputHub)._touch_move(31, _screen(ctx, world))

func finger_up(ctx: Dictionary, world: Vector2) -> void:
	(ctx["main"].input_hub as InputHub)._touch_up(31, _screen(ctx, world))

## The guardian is here: their cursor is drawn (a shared screen), awake from
## the first frame, with their name riding on it.
func guardian_on(ctx: Dictionary, drawing := false) -> void:
	var m: Node2D = ctx["main"]
	m.input_hub.solo_role = ""
	(m.get_node("GuardianWisp") as Node).set("_awake", true)
	# The build ghost under the cursor is the tool's, not the hand's: only the
	# shot that draws with the finger keeps it (it draws the stroke too).
	(m.get_node("PlacementPreview") as CanvasItem).visible = drawing
	if not drawing:
		m.guardian.select_slot(3)

## Take every enemy but the chaser out of a stretch the shot keeps clear.
func clear_area(ctx: Dictionary, area: Rect2) -> void:
	var m: Node2D = ctx["main"]
	for e in m.get_tree().get_nodes_in_group("enemy"):
		if m.is_ancestor_of(e) and area.has_point((e as Node2D).global_position) \
				and not e.is_in_group("instant_death"):
			e.free()

## Every tick: the name tag follows the fingertip.
func tag_finger(ctx: Dictionary) -> void:
	var wisp: Node2D = ctx["main"].get_node("GuardianWisp")
	ov().finger_name = CALLER
	ov().finger_at = _screen(ctx, wisp.get("_pos"))

## The call bar in the corner, for a shot after the call was answered.
func on_call(_ctx: Dictionary) -> void:
	ov().voice_call(CALLER, -2.0, -1.0, INF, ["LIRA", CALLER])

## A stroke drawn by the finger along `points`, over ticks [t0, t0 + len).
func draw_stroke(ctx: Dictionary, t: int, t0: int, length: int, points: PackedVector2Array) -> void:
	if t < t0 or t > t0 + length:
		return
	var k := float(t - t0) / float(length)
	var at := points[mini(int(k * float(points.size() - 1)), points.size() - 1)]
	if t == t0:
		finger_down(ctx, at)
	elif t == t0 + length:
		finger_up(ctx, points[points.size() - 1])
	else:
		finger_move(ctx, at)

# ------------------------------------------------------------------ 1-9 staging

const ROAD_Y := 374.0

## The hound, put to sleep well out of the way: every shot past the gatehouse
## would otherwise have it running the runner down.
func hound_off(ctx: Dictionary) -> void:
	var p := pursuer_of(ctx)
	if p != null:
		p.set_physics_process(false)
		p.global_position = Vector2(-3000, 335)

## 1-9's holdable trap of `kind` ("piston": the spike block, "pendulum": the
## spiked ball).
func castle_trap(ctx: Dictionary, kind: String) -> HoldableTowerTrap:
	for n in (ctx["main"] as Node).get_tree().get_nodes_in_group("hand_holdable"):
		if n is HoldableTowerTrap and (n as HoldableTowerTrap).kind == kind:
			return n
	return null

## The ground slab of 1-9 that holds `x` on the road.
static func road_at(x: float) -> Rect2:
	for g in Stage.ground():
		if g.position.y >= LevelCastleData.GROUND_TOP - 1.0 and g.position.x <= x and g.end.x >= x \
				and g.size.y > 300.0:
			return g
	return Rect2()

# ----------------------------------------------------------------------- alone

## 0.0-2.4. Locked on the stair and the spike block: the runner hops up the
## stair and down, stops right under the block -- looks up -- and it drops.
## The frame holds on it.
func setup_a1_crush(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	hound_off(ctx)
	place_runner(ctx, Vector2(LevelCastleData.STAIR_X - 230.0, ROAD_Y))
	m.runner.facing = 1
	ov().fade(0.0, 0.2, 1.0, 0.0)
	var r := rig(ctx)
	r.cut_to(Vector2(LevelCastleData.SPIKE_X - 160.0, 250), 1.2)
	var block := castle_trap(ctx, "piston")
	var go := pilot(ctx, [
		{"from": road_at(LevelCastleData.STAIR_X - 230.0), "to": LevelCastleData.stair()[2], "reach": 70.0,
			"double": true},
		{"from": LevelCastleData.stair()[2], "to": road_at(LevelCastleData.SPIKE_X)}])
	var state := {"under": -1}
	var inner := func(c: Dictionary) -> void:
		var t: int = c["t"]
		var rn: Runner = m.runner
		if rn.state == Runner.State.DEAD:
			drive(c, 0.0)
			return
		var under := rn.global_position.x >= LevelCastleData.SPIKE_X - 8.0 and rn.is_on_floor()
		if under and int(state["under"]) < 0:
			state["under"] = t
			rn.visual.react(2, 1.0)
			# It is waiting at the top: set its beat so it starts down now.
			if block != null:
				block.phase_offset = 0.30 * block.period - Clock.seconds_at(Clock.tick)
		if int(state["under"]) >= 0:
			drive(c, 0.0)
		elif t > -10:
			go.tick()
		else:
			drive(c, 0.0)
	return dies(ctx, inner)

## 2.4-9.6. One take at the gatehouse, the camera still between its moves.
## Wide: the runner comes up against the shut gate and looks back; the hound
## comes over the moat behind them and stops there, barking.
## The phone rings: fast in on the face, held through the call. The finger
## comes: fast back out to hold the runner, the gate and the hound together --
## THIS IS YOU -- and in that one frame the finger lifts the gate, the runner
## goes under, the hound charges, and gets the bars.
func setup_a2_gate(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var hub: InputHub = m.input_hub
	var gx := LevelCastleData.GATE_X
	place_runner(ctx, Vector2(gx - 330.0, ROAD_Y))
	m.runner.facing = 1
	var hold: WeakRef = weakref(pursuer_of(ctx))
	var gate: LiftGate = null
	for n in m.get_tree().get_nodes_in_group("lift_gate"):
		gate = n
	var r := rig(ctx)
	r.cut_to(Vector2(gx - 300.0, 280), 1.0)
	var t_hound := T(0.9)
	# Up the road from the moat, and it waits there.
	var hound_stop := gx - 560.0
	var t_ring := T(1.8)
	var t_answer := T(2.9)
	var t_finger := T(3.2)
	var t_tag := T(3.7)
	var t_press := T(4.55)
	var t_run := T(4.8)
	var t_drop := T(5.6)
	# Late enough that the bars are down before it gets there.
	var t_charge := T(5.45)
	ov().voice_call(CALLER, 1.8, 2.9, INF, ["LIRA", CALLER])
	ov().tap(2.9, ov().call_answer_point())
	var hello := Vector2(gx + 40.0, 250)
	var state := {"stopped": -1, "pressed": false, "released": false, "lift": Vector2.ZERO}
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		var rn: Runner = m.runner
		var p: Node2D = hold.get_ref()
		if t == -20 and p != null:
			p.global_position = Vector2(-3000, 335)
			p.set("_wake_left", 9999.0)
			p.set("_activated", true)
		# Up to the bars, and stopped dead.
		var at_bars := rn.global_position.x >= gx - 95.0
		if at_bars and int(state["stopped"]) < 0:
			state["stopped"] = t
			rn.visual.react(1, 0.3)
		if int(state["stopped"]) >= 0 and t == int(state["stopped"]) + T(0.3):
			rn.visual.react(0, 1.2)
		# The hound: in from the left, and it waits there, barking.
		if t == t_hound and p != null:
			p.global_position = Vector2(gx - 960.0, ROAD_Y - 40.0)
			p.set("_wake_left", 0.0)
			p.set("cruise_speed", 520.0)
			p.set("catchup_speed", 520.0)
		# It waits where it stopped, barking: held still, not slowed -- even at
		# its slowest it would creep up on a runner standing at the bars.
		if p != null and t > t_hound and t < t_charge and p.global_position.x >= hound_stop:
			p.set_physics_process(false)
		if t == t_charge and p != null:
			p.set_physics_process(true)
			p.set("cruise_speed", 440.0)
			p.set("catchup_speed", 440.0)
		if t == t_ring:
			cap.cue("ring")
			r.move(rn.global_position + Vector2(10, -55), 2.4, T(0.35))
		if t == t_answer:
			cap.cue("answer")
			cap.cue("music_in")
		if t == t_finger:
			guardian_on(c)
			hub.aim_at_world(hello)
			rn.visual.react(2, 1.4)
			r.move(Vector2(gx - 215.0, 262), 1.15, T(0.45))
		if t >= t_finger:
			tag_finger(c)
		if t == t_tag:
			var at := _screen(c, hello)
			ov().tag([[float(t) / 60.0, "THIS IS"], [float(t) / 60.0 + 0.3, "THIS IS YOU"]],
				float(t) / 60.0 + 1.0, at + Vector2(-380, 14), 76)
		# Hello: the finger waves where it appeared, then goes to the gate.
		if gate != null and t > t_finger and t < t_press - 6:
			var k := float(t - t_finger) / 60.0
			var go_k := clampf((float(t - t_finger) - 52.0) / 24.0, 0.0, 1.0)
			hub.aim_at_world(hello.lerp(gate.hand_point() + Vector2(0, -30), go_k)
				+ Vector2(sin(k * 9.0) * 18.0 * (1.0 - go_k), 0.0))
		var lift_from: Vector2 = state["lift"]
		if gate != null and t == t_press:
			lift_from = gate.hand_point()
			state["lift"] = lift_from
			finger_down(c, lift_from)
			state["pressed"] = true
		if bool(state["pressed"]) and not bool(state["released"]) and t > t_press and t < t_drop:
			finger_move(c, lift_from + Vector2(0, -minf(70.0, float(t - t_press) * 3.0)))
		if t == t_drop and gate != null:
			finger_up(c, lift_from + Vector2(0, -70))
			state["released"] = true
			cap.cue("slam")
		var go_in := t < t_ring and not at_bars
		var go_out := t >= t_run and rn.global_position.x < gx + 110.0
		if rn.state != Runner.State.DEAD and (go_in or go_out):
			drive(c, 1.0, false, go_out)
		else:
			drive(c, 0.0)
		if t == t_drop + T(0.75):
			rn.visual.react(4, 0.7)

# ------------------------------------------------------------------ the digest
#
# One trick a shot, each in one locked frame that holds the obstacle, the
# finger's act and what it does -- and holds on that a beat before the cut.

## 17.2-19.6. The whole moat in the frame: two strokes over it, and the
## runner crosses on them without breaking stride.
func setup_d1_bridge(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var c0 := LevelCastleData.CHASM
	var top := LevelCastleData.GROUND_TOP
	place_runner(ctx, Vector2(c0.x - 300.0, ROAD_Y))
	m.runner.facing = 1
	hound_off(ctx)
	guardian_on(ctx, true)
	on_call(ctx)
	var r := rig(ctx)
	r.cut_to(Vector2((c0.x + c0.y) * 0.5 - 70.0, 430), 0.92)
	var mid := (c0.x + c0.y) * 0.5
	var lines := [
		arc_line(Vector2(c0.x + 18, top + 13), Vector2(mid - 10, top + 13), -14.0),
		arc_line(Vector2(mid + 14, top + 15), Vector2(c0.y - 16, top + 13), -12.0),
	]
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		tag_finger(c)
		draw_stroke(c, t, T(0.05), T(0.4), lines[0])
		draw_stroke(c, t, T(0.75), T(0.4), lines[1])
		drive(c, 1.0 if t >= 6 else 0.0, false, true)

## 9.6-12.0. Locked: the runner runs through the frame with the hound on
## their heels. Two taps -- BANG, BANG -- it flashes white, is thrown back and
## sees stars, still in the frame as the runner runs out of it.
func setup_d1b_snipe(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	place_runner(ctx, Vector2(LevelCastleData.CHASM.y + 120.0, ROAD_Y))
	m.runner.facing = 1
	# This road is the cannon's: here it is not loaded.
	for n in m.get_tree().get_nodes_in_group("enemy"):
		if n is Turret:
			n.free()
	var hold: WeakRef = weakref(pursuer_of(ctx))
	guardian_on(ctx)
	on_call(ctx)
	cap.cue("drive_in")
	var r := rig(ctx)
	r.cut_to(Vector2(LevelCastleData.CHASM.y + 120.0, 350), 0.95)
	var shots := [T(0.5), T(0.95)]
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		var rn: Runner = m.runner
		var p: Node2D = hold.get_ref()
		tag_finger(c)
		if t == -20 and p != null:
			p.global_position = rn.global_position + Vector2(-300, -40)
			p.set("_wake_left", 0.0)
			p.set("_activated", true)
			p.set("cruise_speed", 330.0)
			p.set("catchup_speed", 420.0)
		if t == T(0.15):
			rn.visual.react(0, 0.4)
		drive(c, 1.0 if rn.state != Runner.State.DEAD else 0.0)
		if p == null:
			return
		if t < int(shots[0]) - 8:
			m.input_hub.aim_at_world(p.global_position.lerp(rn.global_position, 0.5) + Vector2(0, -90))
		else:
			m.input_hub.aim_at_world(p.global_position + Vector2(0, -30))
		# The guardian's own shot, fired where the finger taps. Through the
		# shot itself, not the touch path: in this frame the hound runs
		# through the left of the screen, which the shared screen keeps for
		# the runner's thumb.
		for at in shots:
			if t == int(at):
				ov().tap(cap.shot_time(), _screen(c, p.global_position + Vector2(0, -30)))
				shoot(c, p.global_position)

## 12.0-14.4. Locked on the spiked ball swinging across the road: the finger
## catches it at the top of its swing and holds it there; the runner runs on
## under it.
func setup_d2_ball(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var px := LevelCastleData.BALL_PIVOT.x
	place_runner(ctx, Vector2(px - 210.0, ROAD_Y))
	m.runner.facing = 1
	hound_off(ctx)
	guardian_on(ctx)
	on_call(ctx)
	var r := rig(ctx)
	r.cut_to(Vector2(px, 200), 1.0)
	var ball := castle_trap(ctx, "pendulum")
	var state := {"held": -1}
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		var rn: Runner = m.runner
		tag_finger(c)
		if ball == null:
			drive(c, 0.0)
			return
		var head := ball.hand_point()
		if int(state["held"]) < 0:
			m.input_hub.aim_at_world(head + Vector2(20, -60))
			# At the top of its swing out over the right, slowest there.
			if t >= T(0.3) and head.x > px + 270.0:
				finger_down(c, head)
				state["held"] = t
			drive(c, 0.0)
			return
		var since := t - int(state["held"])
		if since == T(1.6):
			finger_up(c, head)
		# On under it, and a stop short of the moat.
		var on: bool = since > T(0.2) and m.runner.global_position.x < px + 200.0
		drive(c, 1.0 if on else 0.0, false, true)

## 14.4-17.2. The cannon fires; the finger pinches the ball out of the air --
## fast in on the catch, slowed -- and lets it go. The camera is already back
## on the cannon, held, when the ball gets home. BOOM.
func setup_d3_cannon(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var cx := LevelCastleData.CANNON_X
	place_runner(ctx, Vector2(LevelCastleData.CHASM.y + 30.0, ROAD_Y))
	m.runner.facing = 1
	hound_off(ctx)
	guardian_on(ctx)
	on_call(ctx)
	var cannon: Turret = null
	for n in m.get_tree().get_nodes_in_group("enemy"):
		if n is Turret:
			cannon = n
	if cannon != null:
		cannon.burst = 1
		# Fires a moment into the shot, not in the pre-roll: seen and heard.
		cannon._cooldown = 0.75
	var r := rig(ctx)
	r.cut_to(Vector2(cx - 170.0, 300), 1.35)
	var spot := Vector2(cx - 170.0, cannon.global_position.y if cannon != null else 353.0)
	var state := {"held": null, "t": -1, "done": -1}
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		tag_finger(c)
		var done := int(state["done"])
		drive(c, 1.0 if done >= 0 and t > done + T(0.45) else 0.0)
		if done >= 0:
			if t == done + T(0.35):
				c["speed"] = 1.0
			return
		var held = state["held"]
		if held == null:
			m.input_hub.aim_at_world(spot + Vector2(10, -40))
			if t < 0:
				return
			for n in m.get_tree().get_nodes_in_group("projectile"):
				var p := n as Projectile
				if p != null and p.state == Projectile.State.FLYING \
						and absf(p.global_position.x - spot.x) < 14.0:
					finger_down(c, p.global_position)
					state["held"] = p
					state["t"] = t
					# In close on the catch, the world slowed.
					c["speed"] = 0.5
					r.dolly_to(p.global_position + Vector2(0, -30), T(0.25))
					r.zoom_go(2.4, T(0.25))
					break
			return
		var since := t - int(state["t"])
		var at := spot + Vector2(-float(since) * 0.4, -float(since) * 0.9)
		# Back out, fast, to hold the cannon before the ball is home.
		if since == T(0.35):
			r.move(Vector2(cx - 120.0, 300), 1.2, T(0.15))
		if since < T(0.5):
			finger_move(c, at)
		elif since == T(0.5):
			finger_up(c, at)
			state["done"] = t

## 19.6-22.0. Locked on the spike block over the road: the finger takes it at
## the top and holds it there; the runner runs on under it and out.
func setup_d4_block(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var sx := LevelCastleData.SPIKE_X
	place_runner(ctx, Vector2(sx - 120.0, ROAD_Y))
	m.runner.facing = 1
	hound_off(ctx)
	guardian_on(ctx)
	on_call(ctx)
	var r := rig(ctx)
	r.cut_to(Vector2(sx + 60.0, 240), 1.25)
	var block := castle_trap(ctx, "piston")
	var ball := castle_trap(ctx, "pendulum")
	if ball != null:
		ball.process_mode = Node.PROCESS_MODE_DISABLED
		ball.visible = false
	var state := {"held": -1}
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		tag_finger(c)
		if block == null:
			drive(c, 0.0)
			return
		var head := block.hand_point()
		if int(state["held"]) < 0:
			m.input_hub.aim_at_world(head + Vector2(40, -50))
			# Taken at the top, before it can start down.
			if t >= T(0.3) and block.extension_at(Clock.tick) < 0.01:
				finger_down(c, head)
				state["held"] = t
			drive(c, 0.0)
			return
		var since := t - int(state["held"])
		if since == T(1.5):
			finger_up(c, head)
		var on: bool = since > T(0.25) and m.runner.global_position.x < sx + 280.0
		drive(c, 1.0 if on else 0.0)

## 22.0-24.4. The keep wall from the road: pulled back, let go, and the
## camera rises with the flight -- slowed -- to hold the top of the keep as
## the runner lands on it.
func setup_d6_sling(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	hound_off(ctx)
	place_runner(ctx, Vector2(LevelCastleData.KEEP_X - 230.0, ROAD_Y))
	m.runner.facing = 1
	guardian_on(ctx)
	on_call(ctx)
	var r := rig(ctx)
	r.cut_to(Vector2(LevelCastleData.KEEP_X - 300.0, 110), 0.8)
	var pull := Vector2(-50, 170)
	var state := {"at": Vector2.ZERO}
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		var rn: Runner = m.runner
		tag_finger(c)
		if t < T(0.3):
			m.input_hub.aim_at_world(rn.global_position + Vector2(40, -60))
		if t == T(0.3):
			state["at"] = rn.global_position
			finger_down(c, rn.global_position)
		var at: Vector2 = state["at"]
		if t > T(0.3) and t < T(0.95):
			finger_move(c, at + pull * clampf(float(t - T(0.3)) / float(T(0.5)), 0.0, 1.0))
		if t == T(0.95):
			finger_up(c, at + pull)
			c["speed"] = 0.55
			# Up with the flight, to hold the top of the keep where it lands.
			r.move(Vector2(LevelCastleData.KEEP_X + 60.0, -40.0), 1.05, T(0.7))
		if t == T(1.5):
			c["speed"] = 1.0
		drive(c, 1.0 if t > T(0.95) else 0.0)

## 24.4-28.0. The giant at the door, the runner tiny beside it, framed wide
## enough for where it goes: one flick, in slow motion, and it flies out
## across the frame. Then fast in on the runner's fist in the air, held.
func setup_d7_golem(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	hound_off(ctx)
	var top := LevelCastleData.KEEP_TOP
	var kx := LevelCastleData.KEEP_X
	place_runner(ctx, Vector2(kx + 200.0, top - 26.0))
	m.runner.facing = 1
	guardian_on(ctx)
	on_call(ctx)
	var golem: Node2D = null
	for n in m.get_tree().get_nodes_in_group("flickable"):
		if n is SkyGolem:
			golem = n
	var r := rig(ctx)
	r.cut_to(Vector2(kx + 560.0, top - 230.0), 0.85)
	var state := {"at": Vector2.ZERO}
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		var rn: Runner = m.runner
		tag_finger(c)
		drive(c, 0.0)
		if t == T(1.6):
			c["speed"] = 1.0
		if t == T(1.65):
			# In on the runner: they did it, together.
			r.move(rn.global_position + Vector2(20, -50), 2.5, T(0.3))
			rn.visual.react(4, 1.2)
		if golem == null or not is_instance_valid(golem):
			return
		if t < T(0.8):
			m.input_hub.aim_at_world(golem.global_position + Vector2(-80, -60))
		if t == T(0.8):
			state["at"] = golem.global_position
			finger_down(c, golem.global_position)
		var at: Vector2 = state["at"]
		if t == T(0.8) + 6:
			finger_move(c, at + Vector2(60, -90))
		if t == T(0.8) + 8:
			finger_move(c, at + Vector2(200, -260))
		if t == T(0.8) + 9:
			finger_up(c, at + Vector2(230, -300))
			cap.cue("slam")
			c["speed"] = 0.5

# ----------------------------------------------------------------------- end

func setup_e1_title(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	hound_off(ctx)
	var top := LevelCastleData.KEEP_TOP
	var door := LevelCastleData.goal().x
	place_runner(ctx, Vector2(door - 420.0, top - 26.0))
	m.runner.facing = 1
	for n in m.get_tree().get_nodes_in_group("flickable"):
		if n is SkyGolem:
			n.free()
	var r := rig(ctx)
	# Close on the runner at the door, then slowly back and up to the whole
	# castle as the title lands: fast away at first, settling as it goes.
	r.cut_to(Vector2(door - 340.0, top - 70.0), 2.1)
	cap.cue("drive_out")
	cap.cue("hit")
	ov().voice_call(CALLER, -2.0, -1.0, INF, ["LIRA", CALLER])
	ov().end_card(1.4, "MELOS GAME", ["AVAILABLE NOW", "GOOGLE PLAY", "APP STORE"],
		"BY INOUE & SASABE")
	ov().fade(4.9, 5.4, 0.0, 1.0)
	return func(c: Dictionary) -> void:
		if int(c["t"]) == 0:
			r.move(Vector2(door - 90.0, top - 300.0), 0.92, T(4.2), true)
		# Up to the castle door, and a stop in front of it.
		drive(c, 1.0 if int(c["t"]) > -12 and m.runner.global_position.x < door - 120.0 else 0.0)
