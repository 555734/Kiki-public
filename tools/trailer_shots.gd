extends Node
## The trailer's cut list and what happens in each shot. See capture_trailer.gd.
##
## A shot is a dictionary in list() plus a setup_<name>(ctx) function. Setup
## positions things and returns a per-tick callable; ctx["t"] is the tick
## (60 Hz) since the shot started recording, negative during the pre-roll.

const W := Stage.Which

var cap: Node = null

## The reference trailer's shape, in this game's terms:
##   cold open (no music)  -- the runner caught; a fall saved by a platform out
##                            of nowhere; the camera pulls back and stops on
##                            the hand drawing it: THIS IS YOU.
##   music in              -- what the guardian does: draw, shoot, save.
##   drive layer in        -- the digest: every stage, the star battle, and
##                            the runs that do not make it.
##   title                 -- available now.
func list() -> Array:
	return [
		{"name": "01_caught", "stage": W.HORROR, "sec": 3.3, "preroll": 30},
		{"name": "02_drawn", "stage": W.SWAMP, "sec": 7.9, "preroll": 30},
		# BUILD: four bars.
		{"name": "03_desert", "stage": W.DESERT, "beats": 4, "preroll": 30, "music_in": true, "zoom": 1.15},
		{"name": "04_chase", "stage": W.HORROR, "beats": 4, "preroll": 30, "zoom": 1.35},
		{"name": "05_cliff", "stage": W.SEA, "beats": 4, "preroll": 30, "zoom": 1.2},
		{"name": "06_golem", "stage": W.SKYWARD_RUINS, "beats": 4, "preroll": 30, "zoom": 1.3},
		# DROP: eight bars.
		{"name": "07_climb", "stage": W.TOWER, "beats": 4, "preroll": 30, "zoom": 1.35},
		{"name": "08_arena", "arena": true, "beats": 4, "preroll": 300},
		{"name": "09a_lava", "stage": W.SWAMP, "beats": 2, "preroll": 75, "zoom": 1.3},
		{"name": "09b_spikes", "stage": W.SKYWARD_RUINS, "beats": 2, "preroll": 30, "zoom": 1.15},
		{"name": "09c_golem", "stage": W.SKYWARD_RUINS, "beats": 2, "preroll": 60, "zoom": 1.3},
		{"name": "09d_walker", "stage": W.GREENFIELD, "beats": 2, "preroll": 30, "zoom": 1.1},
		{"name": "10_cave", "stage": W.CAVE, "beats": 4, "preroll": 30, "zoom": 1.4},
		{"name": "11_arena", "arena": true, "beats": 4, "preroll": 600},
		{"name": "12_coast", "stage": W.SEA, "beats": 2, "preroll": 30, "zoom": 1.4},
		{"name": "13_hero", "stage": W.SEA, "beats": 6, "preroll": 30, "zoom": 1.15},
		# STING.
		{"name": "14_title", "stage": W.GREENFIELD, "beats": 12, "preroll": 30},
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

# ----------------------------------------------------------------------- shots

## Cold open. 1-2, close in and letterboxed: one runner, running. The
## pursuer comes up behind and catches them -- in slow motion at the end.
func setup_01_caught(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	place_runner(ctx, Vector2(-760, 300))
	var pursuer := pursuer_of(ctx)
	var r := rig(ctx)
	r.zoom_from = 1.9
	r.zoom_to = 1.75
	r.zoom_ticks = T(3.0)
	r.lead = 30.0
	r.offset = Vector2(-90, -20)
	r.dead_y = 20.0
	ov().letterbox(0.0, 0.01, 84.0, 84.0)
	# Smash to black on the way out.
	ov().fade(3.05, 3.25, 0.0, 1.0)
	var run := autorun(ctx)
	run.sprint = false
	var state := {"dead_at": -1}
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		if t == -20 and pursuer != null:
			pursuer.global_position = m.runner.global_position + Vector2(-470, -24)
			pursuer._wake_left = 0.0
			pursuer._activated = true
			pursuer.cruise_speed = 480.0
		if t < -12:
			drive(c, 0.0)
			return
		if m.runner.state == Runner.State.DEAD:
			if int(state["dead_at"]) < 0:
				state["dead_at"] = t
				impact(c, 6, 0.75)
			drive(c, 0.0)
		else:
			run.tick()
		# Slow down as it closes the last stretch, and stay slow through the catch.
		var gap: float = m.runner.global_position.x - pursuer.global_position.x if pursuer != null else 999.0
		var dead_for := t - int(state["dead_at"]) if int(state["dead_at"]) >= 0 else -1
		c["speed"] = 0.25 if (gap < 120.0 and dead_for < 0) or (dead_for >= 0 and dead_for < 30) else 1.0

## Cold open, continued. 1-5's lava gap. The ground shakes. The runner goes
## for a jump that cannot be made -- and in slow motion a line is drawn under
## them and becomes a platform. The camera pulls back as the next one is drawn,
## the interface appears, and the world stops on the hand that is drawing it.
func setup_02_drawn(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var step: Dictionary = route_steps("cold_rock_rescue")[1]
	var a: Rect2 = step["from"]
	var b: Rect2 = step["to"]
	var plats: Array = step["platforms"]
	place_runner(ctx, on_ledge(a, 0.3))
	var r := rig(ctx)
	r.zoom_from = 1.45
	r.zoom_to = 1.3
	r.zoom_ticks = T(2.0)
	r.offset = Vector2(110, -70)
	r.lead = 60.0
	# Hold the horizon through the jump: the lava gap and the line being drawn
	# over it are the picture, not the top of the runner's arc.
	r.dead_y = 120.0
	ov().letterbox(0.0, 0.01, 84.0, 84.0)
	var lines := [hand_line(plats[0]), hand_line(plats[1])]
	var strokes := [stroke(ctx), stroke(ctx)]
	var go := pilot(ctx, [{"from": a, "to": plats[0], "sprint": true},
		{"from": plats[0], "to": plats[1], "sprint": true},
		{"from": plats[1], "to": b, "sprint": true}])
	var tremor := T(1.7)
	var s := {"jump": -1, "built1": -1, "land": -1, "frozen": false}
	cap.cue("rumble")
	ctx["on_freeze"] = func(c: Dictionary, k: int) -> void:
		# Only the reveal; a hit-stop's short hold is not this.
		if not s["frozen"]:
			return
		if k == 0:
			# Push in on the hand and the runner it is drawing for.
			r.zoom_go(r.factor * 1.5, 70)
			r.point = (m.runner.global_position + (strokes[1] as Stroke).head()) * 0.5 + Vector2(0, -30)
			r.follow = null
			ov().note("THIS IS YOU", cap.shot_time() + 0.25, cap.shot_time() + 2.4,
				Vector2(250, 250))
		var head: Vector2 = (strokes[1] as Stroke).head()
		ov().note_target = m.get_viewport().get_canvas_transform() * head
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		c["speed"] = 1.0
		if s["frozen"] and r.follow == null:
			r.follow = m.runner
		# The tremor: shake builds, then stops dead as the runner sets off.
		r.shake = clampf(float(t) / float(tremor), 0.0, 1.0) * 7.0 if t < tremor else 0.0
		if t < tremor:
			drive(c, 0.0)
			return
		if t == tremor:
			cap.cue("rumble_stop")
		go.tick()
		var rn: Runner = m.runner
		if int(s["jump"]) < 0 and not rn.is_on_floor():
			s["jump"] = t
		# Stroke one: drawn while the runner is in the air over the lava.
		var j: int = s["jump"]
		if j >= 0:
			var t0 := j + 10
			var grow := clampf(float(t - t0) / 22.0, 0.0, 1.0)
			_paint(strokes[0], lines[0], t >= t0, grow, t - t0 - 22)
			if t == t0 + 22:
				build(c, lines[0])
				s["built1"] = t
				impact(c, 3, 0.3)
			if t >= t0 - 4 and (int(s["built1"]) < 0 or t < int(s["built1"]) + 8):
				c["speed"] = 0.25
		# Landed on it: pull back, the interface appears, stroke two begins.
		if int(s["built1"]) >= 0 and int(s["land"]) < 0 and rn.is_on_floor():
			s["land"] = t
			r.zoom_go(0.85, T(0.5))
			ov().letterbox(cap.shot_time(), cap.shot_time() + 0.6, 84.0, 0.0)
			show_hud(c)
		var l: int = s["land"]
		if l >= 0:
			var t1 := l + 4
			var grow2 := clampf(float(t - t1) / 40.0, 0.0, 1.0)
			_paint(strokes[1], lines[1], t >= t1, grow2, t - t1 - 40)
			m.input_hub.aim_at_world((strokes[1] as Stroke).head())
			if t == t1 + 40:
				build(c, lines[1])
			if t == t1 + 22 and not s["frozen"]:
				s["frozen"] = true
				c["freeze"] = 78
				cap.cue("silence")

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

func setup_08_arena(ctx: Dictionary) -> Callable:
	return arena_play(ctx, 1.1)

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

## 1-2's pursuer at the runner's back; the guardian's shot knocks it away.
func setup_04_chase(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	place_runner(ctx, Vector2(-760, 300))
	var pursuer := pursuer_of(ctx)
	var r := rig(ctx)
	r.zoom_from = 1.25
	r.zoom_to = 1.12
	r.zoom_ticks = T(3.6)
	r.lead = 40.0
	r.offset = Vector2(-170, -50)
	var run := autorun(ctx)
	run.sprint = false
	var fired := [false]
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		if t == -20 and pursuer != null:
			# Already awake and close behind.
			pursuer.global_position = m.runner.global_position + Vector2(-330, -30)
			pursuer._wake_left = 0.0
			pursuer._activated = true
		if t < -12:
			drive(c, 0.0)
			return
		run.tick()
		# Fire as it is about to close: the shot is the save, not a warning.
		if pursuer != null and not pursuer.stunned() and t > T(0.9) \
				and m.runner.global_position.x - pursuer.global_position.x < 150.0 \
				and t - int(c.get("last_shot", -999)) > T(0.8):
			shoot(c, pursuer.global_position)
			impact(c, 4, 0.35)
			c["last_shot"] = t

## 1-4: along the first island, lighthouse behind.
func setup_12_coast(ctx: Dictionary) -> Callable:
	place_runner(ctx, Vector2(-760, 300))
	var run := autorun(ctx)
	var r := rig(ctx)
	r.zoom_from = 1.35
	r.zoom_to = 1.2
	r.zoom_ticks = T(1.8)
	r.lead = 160.0
	return func(c: Dictionary) -> void:
		if int(c["t"]) < -16:
			drive(c, 0.0)
		else:
			run.tick()

## 1-6: the mirage crossing. The guardian bridges the whole gap in two long
## strokes, each drawn just ahead of the runner, who never breaks stride.
func setup_03_desert(ctx: Dictionary) -> Callable:
	var step: Dictionary = route_steps("mirage_crossing")[0]
	var a: Rect2 = step["from"]
	var b: Rect2 = step["to"]
	place_runner(ctx, on_ledge(a, 0.15))
	clear_enemies(ctx, Rect2(a.position - Vector2(300, 600), Vector2(1700, 1000)))
	var r := rig(ctx)
	r.zoom_from = 1.0
	r.zoom_to = 0.92
	r.zoom_ticks = T(2.2)
	r.offset = Vector2(170, -40)
	r.dead_y = 80.0
	# Each stroke's ends sit level with the ground it meets: the platform's top
	# is 13px above the line drawn.
	var mid := (a.end.x + b.position.x) * 0.5
	var lines := [
		arc_line(Vector2(a.end.x + 18, a.position.y + 13), Vector2(mid - 10, lerpf(a.position.y, b.position.y, 0.5) + 13), -14.0),
		arc_line(Vector2(mid + 14, lerpf(a.position.y, b.position.y, 0.5) + 15), Vector2(b.position.x - 16, b.position.y + 13), -12.0),
	]
	var strokes := [stroke(ctx), stroke(ctx)]
	var draw_at := [T(0.05), T(0.62)]
	var draw_len := T(0.38)
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		for k in 2:
			var t0: int = draw_at[k]
			_paint(strokes[k], lines[k], t >= t0, clampf(float(t - t0) / float(draw_len), 0.0, 1.0),
				t - t0 - draw_len)
			if t == t0 + draw_len:
				build(c, lines[k])
		# Off the mark as the first stroke lands, so it is there when needed.
		# Flat out and never a jump: the bridge is the whole point.
		drive(c, 1.0 if t >= 8 else 0.0, false, true)

## A drawn line from `from` to `to`, bowed by `bulge` (negative is upwards) --
## a stroke a finger makes in one sweep.
static func arc_line(from: Vector2, to: Vector2, bulge: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 24:
		var u := float(k) / 23.0
		out.append(from.lerp(to, u) + Vector2(0, sin(u * PI) * bulge))
	return out

## 1-3: the pursuer rises out of the clouds at the first island, and the
## guardian's shot knocks it back down before it reaches the runner.
func setup_06_golem(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var island := Rect2(-520, 6380, 760, 150)
	place_runner(ctx, on_ledge(island, 0.3))
	var pursuer := pursuer_of(ctx)
	var r := rig(ctx)
	r.zoom_from = 1.0
	r.zoom_to = 1.12
	r.zoom_ticks = T(1.8)
	r.offset = Vector2(110, 70)
	r.dead_y = 40.0
	r.lead = 0.0
	return func(c: Dictionary) -> void:
		var t: int = c["t"]
		if t == -20 and pursuer != null:
			pursuer.global_position = m.runner.global_position + Vector2(230, 420)
		if t == -1:
			m.runner.facing = 1
		# Stand, face it, and hop as the shot lands.
		drive(c, 0.0, t >= T(0.95) and t < T(1.25))
		if pursuer != null and t == T(0.85):
			shoot(c, pursuer.global_position)
			impact(c, 4, 0.35)

## 1-7: the first flight of the clockwork tower, zig-zag. It opens the
## digest, and the drive layer comes in with it.
func setup_07_climb(ctx: Dictionary) -> Callable:
	cap.cue("drive_in")
	var go := hops(ctx, route_slice(0, 5), 0.6)
	var r := rig(ctx)
	r.zoom_from = 1.25
	r.zoom_to = 1.15
	r.zoom_ticks = T(1.8)
	r.offset = Vector2(0, -100)
	r.dead_y = 30.0
	r.lead = 0.0
	return func(c: Dictionary) -> void:
		if int(c["t"]) < -16:
			drive(c, 0.0)
		else:
			go.tick()

## 1-4's cliff: two platforms drawn up a sheer face, climbed as they appear.
func setup_05_cliff(ctx: Dictionary) -> Callable:
	var step: Dictionary = route_steps("cliff_rescue")[0]
	place_runner(ctx, on_ledge(step["from"], 0.35))
	clear_enemies(ctx, Rect2((step["from"] as Rect2).position - Vector2(600, 900), Vector2(1500, 1400)))
	var r := rig(ctx)
	r.zoom_from = 1.05
	r.zoom_to = 1.15
	r.zoom_ticks = T(2.7)
	r.offset = Vector2(60, -150)
	r.dead_y = 40.0
	r.lead = 0.0
	return assisted(ctx, step, [-0.05, 0.6], 0.15, false)

## 1-8: up the mine mouth, ledge to ledge.
func setup_10_cave(ctx: Dictionary) -> Callable:
	var go := hops(ctx, route_slice(0, 5), 0.5)
	var r := rig(ctx)
	r.zoom_from = 0.95
	r.zoom_to = 1.05
	r.zoom_ticks = T(2.7)
	r.offset = Vector2(0, 50)
	r.dead_y = 30.0
	r.lead = 0.0
	return func(c: Dictionary) -> void:
		if int(c["t"]) < -12:
			drive(c, 0.0)
		else:
			go.tick()

## The title over 1-1's opening field, the music's last bar under it.
func setup_14_title(ctx: Dictionary) -> Callable:
	place_runner(ctx, Vector2(-200, 374))
	var r := rig(ctx)
	r.zoom_from = 1.15
	r.zoom_to = 1.0
	r.zoom_ticks = T(5.4)
	r.offset = Vector2(120, -60)
	r.smooth = 2.0
	cap.cue("drive_out")
	cap.cue("hit")
	ov().flash(0.0, 0.35, 0.9)
	ov().end_card(0.15, "MELOS GAME", ["AVAILABLE NOW", "GOOGLE PLAY", "APP STORE"])
	ov().fade(5.0, 5.45, 0.0, 1.0)
	return func(c: Dictionary) -> void:
		drive(c, 1.0 if int(c["t"]) > -12 else 0.0)

# ----------------------------------------------------------------- the digest

func setup_11_arena(ctx: Dictionary) -> Callable:
	return arena_play(ctx, 1.9, [5, 77])

## A death, as the digest shows it: a flash and a jolt as it lands.
func dies(ctx: Dictionary, inner: Callable) -> Callable:
	var m: Node2D = ctx["main"]
	var s := {"at": -1}
	return func(c: Dictionary) -> void:
		inner.call(c)
		if m.runner.state == Runner.State.DEAD and int(s["at"]) < 0 and int(c["t"]) >= 0:
			s["at"] = c["t"]
			impact(c, 5, 0.7)

## 1-5: the same jump as the cold open, with nobody drawing.
func setup_09a_lava(ctx: Dictionary) -> Callable:
	var step: Dictionary = route_steps("cold_rock_rescue")[1]
	place_runner(ctx, on_ledge(step["from"], 0.15))
	var r := rig(ctx)
	r.zoom_from = 1.3
	r.zoom_to = 1.4
	r.zoom_ticks = T(0.9)
	r.offset = Vector2(60, 40)
	r.dead_y = 40.0
	r.smooth_y = 6.0
	var go := pilot(ctx, [{"from": step["from"], "to": step["platforms"][0], "sprint": true}])
	return dies(ctx, func(c: Dictionary) -> void: go.tick())

## 1-3: straight into the spikes on the first island, on the last heart.
func setup_09b_spikes(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var island := Rect2(-520, 6380, 760, 150)
	place_runner(ctx, on_ledge(island, 0.05))
	var r := rig(ctx)
	r.zoom_from = 1.5
	r.zoom_to = 1.65
	r.zoom_ticks = T(0.9)
	r.offset = Vector2(40, -20)
	r.dead_y = 40.0
	return dies(ctx, func(c: Dictionary) -> void:
		m.runner.hp = 1
		drive(c, 1.0 if int(c["t"]) > -40 else 0.0, false, true))

## 1-3: nobody shoots the golem this time.
func setup_09c_golem(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	var island := Rect2(-520, 6380, 760, 150)
	place_runner(ctx, on_ledge(island, 0.3))
	var pursuer := pursuer_of(ctx)
	var r := rig(ctx)
	r.zoom_from = 1.25
	r.zoom_to = 1.35
	r.zoom_ticks = T(0.9)
	r.offset = Vector2(60, 40)
	r.dead_y = 60.0
	r.lead = 0.0
	return dies(ctx, func(c: Dictionary) -> void:
		if int(c["t"]) == -38 and pursuer != null:
			pursuer.global_position = m.runner.global_position + Vector2(150, 330)
		drive(c, 0.0))

## 1-1: head first into a walker, on the last heart.
func setup_09d_walker(ctx: Dictionary) -> Callable:
	var m: Node2D = ctx["main"]
	place_runner(ctx, Vector2(960, 374))
	var r := rig(ctx)
	r.zoom_from = 1.6
	r.zoom_to = 1.75
	r.zoom_ticks = T(0.9)
	r.offset = Vector2(60, -20)
	return dies(ctx, func(c: Dictionary) -> void:
		m.runner.hp = 1
		drive(c, 1.0 if int(c["t"]) > -17 else 0.0, false, true))

## 1-4's last lighthouse rescue: two platforms drawn up the cliff, climbed as
## they appear, the last landing slowed down -- the digest's last word.
func setup_13_hero(ctx: Dictionary) -> Callable:
	var step: Dictionary = route_steps("last_lighthouse_rescue")[0]
	place_runner(ctx, on_ledge(step["from"], 0.35))
	clear_enemies(ctx, Rect2((step["from"] as Rect2).position - Vector2(700, 900), Vector2(1600, 1400)))
	var r := rig(ctx)
	r.zoom_from = 1.05
	r.zoom_to = 1.3
	r.zoom_ticks = T(2.7)
	r.offset = Vector2(60, -140)
	r.dead_y = 40.0
	r.lead = 0.0
	var inner := assisted(ctx, step, [-0.05, 0.55], 0.1, false)
	var b: Rect2 = step["to"]
	return func(c: Dictionary) -> void:
		inner.call(c)
		var rn: Runner = ctx["main"].runner
		# Slow over the last ledge: from the moment the runner is above it.
		c["speed"] = 0.4 if rn.global_position.y < b.position.y + 10.0 \
			and not rn.is_on_floor() else 1.0

func drive(ctx: Dictionary, axis: float, jump := false, sprint := false) -> void:
	(ctx["main"].input_hub as InputHub).drive_runner(axis, 0.0, jump, sprint)
