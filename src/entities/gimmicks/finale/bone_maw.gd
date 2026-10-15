extends FinaleMachine
## THE MAW. The way through the bone canyon runs over the fossil itself: up
## a huge rib that arcs out over the canyon (three spans: A B C), down onto a
## tilted thigh bone below it (upper part, lower part), across a curved rib
## (P2) and with one long jump onto the slope out by the jaw gate. Something
## still lives down there.
##
## state 1 (the runner climbs the rib, x >= trigger):
##   rise   the skull comes up out of the canyon under the rib
##   open   it tilts up at the span the runner is on, jaws wide (wind-up)
##   bite   it lunges and snaps shut on span B -- the span the runner has
##          just run off: B SHATTERS (its collider goes), and span C, the
##          rib's tip with the runner on it, loses its hold and drops away:
##          the runner rides the collapse down onto the thigh bone below
##   recover it shakes the bone from its teeth and sinks
## state 2 (the runner slides down the thigh bone, x >= trigger2):
##   it comes up again behind them, chases along under the bone, bites the
##   bone's lower end off as they jump from it, chases under the curved rib
##   and bites that too, a moment after their last jump.
##
## A bite closing on the runner is fatal. Every pose is a function of the
## clock (placed_tick of each state), the same on every device.

## Phases of the first attack (seconds since state 1).
const RISE := 0.55
const OPEN := 1.05
const BITE := 1.2
const HOLD := 1.75
const SINK := 2.5
## Span C, unsupported after the bite: sags, then falls.
const C_SAG := 0.22
## Second attack (seconds since state 2): bites at BITE2 and BITE3.
const RISE2 := 0.45
const BITE2 := 1.4
const BITE3 := 2.75
const LUNGE := 0.15
const FALL_G := 2100.0
const KILL_R := 100.0

const TEX_SHAFT := "res://assets/stage_1_10/bone_shaft.png"
const TEX_KNOB := "res://assets/stage_1_10/bone_knob.png"
const TEX_SKULL := "res://assets/stage_1_10/beast_skull.png"
const TEX_JAW := "res://assets/stage_1_10/beast_jaw.png"
const TEX_VERT := "res://assets/stage_1_10/beast_vertebra.png"
const SKULL_SCALE := 0.85
const SKULL_HINGE := Vector2(150, 230)
const JAW_HINGE := Vector2(40, 90)

## name -> {"a": top-left end, "b": top-right end (world, walkable top),
## "thick": drawn thickness, "u": stretch of the shaft painting, "body"}
var _pieces := {}
var _order := ["A", "B", "C", "L1a", "L1b", "P2", "G"]
## Second state's clock (state 2 replaces state 1's placed_tick).
var _t1_tick := -1
var _t2_tick := -1
var _bites_heard := 0

func _build() -> void:
	z_index = 7
	reach = Vector2(2600, 1800)
	var spans: Dictionary = data.get("spans", {})
	var u := 0.0
	for name in _order:
		var s: Array = spans.get(name, [])
		if s.size() < 2:
			continue
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var thick := float(s[2]) if s.size() > 2 else 60.0
		var body := make_body(Vector2(a.distance_to(b), 30.0))
		body.sync_to_physics = false
		var len := a.distance_to(b)
		# Polished by ages of sand: the tilted thigh bone carries whoever is
		# on it down its length -- a slide.
		if name.begins_with("L1"):
			body.constant_linear_velocity = (b - a).normalized() * float(data.get("slide", 300.0))
		_pieces[name] = {"a": a, "b": b, "thick": thick, "u": u, "body": body}
		u = fposmod(u + len * 1.3 + 170.0, 900.0)
	_pose(Clock.tick)

func _receive(id: String) -> void:
	var fields := id.split("|")
	if fields.size() == 4 and fields[0] == switch_id:
		var s := int(fields[1])
		if s == 1:
			_t1_tick = int(fields[2])
		elif s == 2:
			_t2_tick = int(fields[2])
			if _t1_tick < 0:
				_t1_tick = int(fields[2]) - Clock.ticks_for(SINK)
	super._receive(id)

# ------------------------------------------------------------------- timing
func t1(tick: int = Clock.tick) -> float:
	return -1.0 if _t1_tick < 0 else float(tick - _t1_tick) / float(Clock.HZ)

func t2(tick: int = Clock.tick) -> float:
	return -1.0 if _t2_tick < 0 else float(tick - _t2_tick) / float(Clock.HZ)

## Seconds since `name` was bitten (or -1 if it has not been).
func since_bitten(name: String, tick: int = Clock.tick) -> float:
	var t := -1.0
	match name:
		"B":
			t = t1(tick) - BITE if t1(tick) >= 0.0 else -1.0
		"C":
			t = t1(tick) - BITE - C_SAG if t1(tick) >= 0.0 else -1.0
		"L1b":
			t = t2(tick) - BITE2 if t2(tick) >= 0.0 else -1.0
		"P2":
			t = t2(tick) - BITE3 if t2(tick) >= 0.0 else -1.0
	return t if t >= 0.0 else -1.0

func destroyed(name: String, tick: int = Clock.tick) -> bool:
	return since_bitten(name, tick) >= 0.0

func piece(name: String) -> Dictionary:
	return _pieces.get(name, {})

func piece_body(name: String) -> AnimatableBody2D:
	return _pieces[name]["body"] if _pieces.has(name) else null

## Walkable top of a piece at x (for scripts and probes).
func top_at(name: String, x: float) -> float:
	var p: Dictionary = _pieces[name]
	var a: Vector2 = p["a"]
	var b: Vector2 = p["b"]
	return lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))

func centre(name: String) -> Vector2:
	var p: Dictionary = _pieces[name]
	return (Vector2(p["a"]) + Vector2(p["b"])) * 0.5

# ------------------------------------------------------------- the skull
## Skull centre (world), its angle and how open the jaws are, now.
func head(tick: int = Clock.tick) -> Array:
	var s2 := t2(tick)
	if s2 >= 0.0:
		return _head2(s2)
	var s1 := t1(tick)
	if s1 < 0.0:
		return [Vector2(centre("B").x, 1500.0), -1.2, 0.0]
	return _head1(s1)

func _head1(t: float) -> Array:
	var bite_at := centre("B") + Vector2(0, 40)
	var low := Vector2(bite_at.x - 80.0, 1250.0)
	var ready := Vector2(bite_at.x - 60.0, bite_at.y + 300.0)
	if t < RISE:
		var k := t / RISE
		return [low.lerp(ready, 1.0 - (1.0 - k) * (1.0 - k)), -1.25, 0.2 * k]
	if t < OPEN:
		# Wind-up: the head draws back a little and the jaws gape.
		var k := (t - RISE) / (OPEN - RISE)
		return [ready + Vector2(-20.0, 30.0) * smoothstep(0.0, 1.0, k), -1.25 + 0.15 * k, 0.2 + 0.8 * smoothstep(0.0, 1.0, k)]
	if t < BITE:
		var k := (t - OPEN) / (BITE - OPEN)
		return [(ready + Vector2(-20, 30)).lerp(bite_at, k * k), -1.1 + 0.1 * k, 1.0 - k]
	if t < HOLD:
		# Recover: bone in its teeth, it shakes its head.
		var k := t - BITE
		return [bite_at + Vector2(sin(k * 30.0) * 14.0 * (1.0 - k), 30.0 * k), -1.0 + sin(k * 26.0) * 0.08, 0.05]
	var k := clampf((t - HOLD) / (SINK - HOLD), 0.0, 1.0)
	return [(bite_at + Vector2(0, 30.0 * (HOLD - BITE))).lerp(low + Vector2(300, 0), k * k), -1.0 - 0.3 * k, 0.15]

## Under a piece, jaws open toward its top.
func _under(name: String, depth: float) -> Vector2:
	return centre(name) + Vector2(-40.0, depth)

func _head2(t: float) -> Array:
	var start := _under("L1a", 500.0)
	var under_b := _under("L1b", 300.0)
	var bite_b := centre("L1b") + Vector2(0, 40)
	var under_p := _under("P2", 320.0)
	var bite_p := centre("P2") + Vector2(60, 40)
	if t < RISE2:
		var k := t / RISE2
		return [start + Vector2(0, 600.0 * (1.0 - k) * (1.0 - k)), -1.2, 0.3 * k]
	if t < BITE2 - LUNGE:
		var k := (t - RISE2) / (BITE2 - LUNGE - RISE2)
		return [start.lerp(under_b, smoothstep(0.0, 1.0, k)), -1.2, 0.3 + 0.7 * k]
	if t < BITE2:
		var k := (t - BITE2 + LUNGE) / LUNGE
		return [under_b.lerp(bite_b, k * k), -1.1, 1.0 - k]
	if t < BITE2 + 0.35:
		var k := t - BITE2
		return [bite_b + Vector2(sin(k * 30.0) * 12.0, 0), -1.0, 0.05]
	if t < BITE3 - LUNGE:
		var k := (t - BITE2 - 0.35) / (BITE3 - LUNGE - BITE2 - 0.35)
		return [bite_b.lerp(under_p, smoothstep(0.0, 1.0, k)), -1.1 - 0.1 * k, smoothstep(0.0, 1.0, k)]
	if t < BITE3:
		var k := (t - BITE3 + LUNGE) / LUNGE
		return [under_p.lerp(bite_p, k * k), -1.0, 1.0 - k]
	if t < BITE3 + 0.5:
		var k := t - BITE3
		return [bite_p + Vector2(sin(k * 28.0) * 12.0, 20.0 * k), -0.9, 0.05]
	var k := clampf((t - BITE3 - 0.5) / 0.9, 0.0, 1.0)
	return [(bite_p + Vector2(0, 10)).lerp(bite_p + Vector2(200, 1100), k * k), -0.9 - 0.4 * k, 0.4 * k]

## The bite closing right now (world point), or INF.
func biting(tick: int = Clock.tick) -> Vector2:
	var s1 := t1(tick)
	var s2 := t2(tick)
	if s2 >= 0.0:
		if (s2 > BITE2 - LUNGE and s2 < BITE2 + 0.05):
			return centre("L1b") + Vector2(0, -10)
		if (s2 > BITE3 - LUNGE and s2 < BITE3 + 0.05):
			return centre("P2") + Vector2(60, -10)
	elif s1 > OPEN and s1 < BITE + 0.05:
		return centre("B") + Vector2(0, -10)
	return Vector2(INF, INF)

# ------------------------------------------------------------------ the sim
func _pose(tick: int) -> void:
	for name in _pieces:
		var p: Dictionary = _pieces[name]
		var a: Vector2 = p["a"]
		var b: Vector2 = p["b"]
		var body: AnimatableBody2D = p["body"]
		var xf := piece_xform(name, tick)
		var mid := (a + b) * 0.5
		var u := (b - a).normalized()
		var n := Vector2(-u.y, u.x)
		if n.y < 0.0:
			n = -n
		var local := mid + n * 15.0
		body.position = xf * local - global_position
		body.rotation = xf.get_rotation() + u.angle()
		var gone := destroyed(name, tick)
		set_solid(body, not gone)
		body.visible = (xf * mid).y < 2600.0

## Where a piece is (as a transform on its rest pose), after any bite.
func piece_xform(name: String, tick: int = Clock.tick) -> Transform2D:
	var p: Dictionary = _pieces[name]
	var a: Vector2 = p["a"]
	var b: Vector2 = p["b"]
	var mid := (a + b) * 0.5
	if name == "C":
		# Loses its hold: the root end drops first -- it tips and falls.
		var s1 := t1(tick)
		if s1 < BITE:
			return Transform2D.IDENTITY
		var k := clampf((s1 - BITE) / C_SAG, 0.0, 1.0)
		var t := maxf(0.0, s1 - BITE - C_SAG)
		var rot := 0.18 * k + 0.9 * t
		var drop := Vector2(30.0 * t, 22.0 * k + 0.5 * FALL_G * t * t)
		return Transform2D(0.0, mid + drop) * Transform2D(rot, Vector2.ZERO) * Transform2D(0.0, -mid)
	var t := since_bitten(name, tick)
	if t < 0.0 or name == "B":
		return Transform2D.IDENTITY
	var spin := 1.6 if name == "L1b" else -1.2
	return Transform2D(0.0, mid + Vector2(40.0 * t, 0.5 * FALL_G * t * t)) * Transform2D(spin * t, Vector2.ZERO) * Transform2D(0.0, -mid)

func _on_state() -> void:
	if state == 1:
		sound("rumble", -2.0, 1.5)
		FinaleFx.kick(8.0)
	elif state == 2:
		sound("rumble", 1.0, 1.4)

func _host_step(_delta: float) -> void:
	var x := runner.global_position.x
	if state == 0 and x >= float(data.get("trigger", 21560.0)):
		set_state(1)
	elif state == 1 and x >= float(data.get("trigger2", 22180.0)) and runner.global_position.y > 250.0:
		set_state(2)
	var bite := biting()
	if bite.x != INF and runner_hits_circle(bite, KILL_R):
		kill_runner("jaws")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _near:
		return
	# Sounds of the bites, on every device, once each.
	var n := 0
	for name in ["B", "L1b", "P2"]:
		if destroyed(name):
			n += 1
	if n > _bites_heard:
		_bites_heard = n
		sound("boom", 2.0 - float(n), 1.6)
		sound("crumble", 0.0, 1.5)
		FinaleFx.kick(14.0)
	elif n < _bites_heard:
		_bites_heard = n
	var s1 := t1()
	if s1 >= RISE and s1 < RISE + 1.0 / 60.0:
		sound("rumble", 4.0, 1.5)

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	# Bones first (the skull rises in front of them only when biting).
	var h: Array = head()
	var hp: Vector2 = h[0]
	var behind := hp.y > 900.0
	if not behind:
		_neck(hp, float(h[1]))
	for name in _order:
		if not _pieces.has(name) or name == "B" and destroyed("B"):
			continue
		_bone(name)
	_shards()
	if not behind:
		_skull(hp - global_position, float(h[2]), float(h[1]))
	# The wind-up telegraph: grit raining off the span about to be bitten.
	var s1 := t1()
	if s1 >= RISE and s1 < BITE and t2() < 0.0:
		var c := centre("B") - global_position
		for i in 8:
			var f := fposmod(s1 * 1.6 + float(i) * 0.13, 1.0)
			draw_circle(c + Vector2((DrawUtil.hash01(i) - 0.5) * 160.0, 20.0 + f * 160.0), 4.0, Color(0.85, 0.75, 0.6, 0.8 * (1.0 - f)))

## A piece of bone: a stretch of the painted shaft along its walkable top,
## knuckle ends where the bone ends.
func _bone(name: String) -> void:
	var tex := FinaleArt._load(TEX_SHAFT)
	if tex == null:
		return
	var p: Dictionary = _pieces[name]
	var a: Vector2 = p["a"]
	var b: Vector2 = p["b"]
	var thick := float(p["thick"])
	var xf := piece_xform(name)
	var u := (b - a).normalized()
	var n := Vector2(-u.y, u.x)
	if n.y < 0.0:
		n = -n
	# The painting's shaft is ~100px thick about y=80: its top at ~30.
	var k := thick / 100.0
	var len := a.distance_to(b)
	var src_w := len / k
	var u0 := clampf(float(p["u"]), 0.0, maxf(0.0, 1400.0 - src_w - 12.0))
	var origin := xf * a - global_position
	var ang := xf.get_rotation() + u.angle()
	draw_set_transform(origin, ang, Vector2(k, k))
	# Slight overlap at the joints so a whole rib reads as one bone.
	draw_texture_rect_region(tex, Rect2(-6, -30, src_w + 12, 110), Rect2(u0, 0, minf(src_w + 12.0, 1400.0 - u0), 110))
	draw_set_transform(Vector2.ZERO)
	var knob := FinaleArt._load(TEX_KNOB)
	if knob == null:
		return
	var ends: Array = data.get("knobs", {}).get(name, [])
	for e in ends:
		var at: Vector2 = a if int(e) == 0 else b
		var dir := -u if int(e) == 0 else u
		var c := xf * (at + n * thick * 0.5) - global_position
		draw_set_transform(c, xf.get_rotation() + dir.angle(), Vector2(k, k) * 1.05)
		draw_texture(knob, -Vector2(70, 120))
		draw_set_transform(Vector2.ZERO)

## Span B bursting into fragments when the jaws close on it.
func _shards() -> void:
	var tex := FinaleArt._load(TEX_SHAFT)
	for name in ["B", "L1b", "P2"]:
		var t := since_bitten(name)
		if t < 0.0 or t > 1.6 or tex == null or not _pieces.has(name):
			continue
		var c := centre(name) - global_position
		for i in 7:
			var v := Vector2((DrawUtil.hash01(i * 3 + name.length()) - 0.5) * 760.0, -260.0 - 420.0 * DrawUtil.hash01(i * 7))
			var p := c + v * t + Vector2(0, 0.5 * FALL_G * t * t)
			var w := 40.0 + 34.0 * DrawUtil.hash01(i * 11)
			draw_set_transform(p, t * (4.0 + float(i)), Vector2.ONE)
			draw_texture_rect_region(tex, Rect2(-w * 0.5, -w * 0.3, w, w * 0.6), Rect2(200.0 + float(i) * 140.0, 40, w * 1.6, w))
			draw_set_transform(Vector2.ZERO)
		# Dust burst where the teeth met.
		if t < 0.45:
			var k := t / 0.45
			for i in 10:
				var a := TAU * float(i) / 10.0
				draw_circle(c + Vector2(cos(a), sin(a) * 0.6) * (30.0 + 140.0 * k), 16.0 + 22.0 * k, Color(0.93, 0.86, 0.72, 0.55 * (1.0 - k)))

## Neck: vertebrae trailing from the skull down into the canyon.
func _neck(hp: Vector2, angle: float) -> void:
	var tex := FinaleArt._load(TEX_VERT)
	if tex == null:
		return
	var back := Vector2(cos(angle + PI), sin(angle + PI))
	var t := seconds()
	for k in range(8, -1, -1):
		var p := hp + back * (110.0 + float(k) * 70.0) + Vector2(-float(k * k) * 9.0, float(k) * 30.0) + Vector2(sin(t * 4.0 + float(k)) * 6.0, 0)
		draw_set_transform(p - global_position, angle + 0.1 * float(k), Vector2(1.1, 1.1) * (1.0 - 0.03 * float(k)))
		draw_texture(tex, -Vector2(100, 110))
	draw_set_transform(Vector2.ZERO)

## The painted skull, facing along `angle`; `open` 0..1 drops the jaw.
func _skull(c: Vector2, open: float, angle: float) -> void:
	var base := Transform2D(angle, c)
	var hinge := Vector2(-150, 40)
	var k := SKULL_SCALE
	var jaw := FinaleArt._load(TEX_JAW)
	var skull := FinaleArt._load(TEX_SKULL)
	if jaw != null:
		draw_set_transform_matrix(base * Transform2D(open * 0.7, hinge) * Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO))
		draw_texture(jaw, -JAW_HINGE)
	if skull != null:
		draw_set_transform_matrix(base * Transform2D(0.0, hinge) * Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO))
		draw_texture(skull, -SKULL_HINGE)
	draw_set_transform_matrix(base)
	var eye := hinge + (Vector2(268, 140) - SKULL_HINGE) * k
	var glow := 0.65 + 0.35 * sin(seconds() * 7.0)
	draw_circle(eye, 40.0, Color(1.0, 0.25, 0.05, 0.30 * glow))
	draw_circle(eye, 20.0, Color(1.0, 0.45, 0.08, glow))
	draw_circle(eye, 8.0, Color(1.0, 0.95, 0.6))
	draw_set_transform(Vector2.ZERO)
