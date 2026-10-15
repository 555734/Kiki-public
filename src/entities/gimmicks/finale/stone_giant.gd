extends FinaleMachine
## THE STONE GIANT. It stands in the gorge, head and shoulders over the
## way, and the only way on is a long natural stone bridge across the gorge
## in front of it. It sees the runner step onto the bridge and attacks:
##
## * NOTICE: the eyes flare and the body leans toward the runner.
## * SLAM (near arm): raised high over the bridge -- its shadow gathers on
##   the stone right in front of the runner -- then driven down. The impact
##   BREAKS THE BRIDGE: every stone block of it cracks, sags and falls into
##   the gorge, nearest first (their colliders go with them). The old way
##   across is gone for good.
## * The slammed arm stays planted for PLANT seconds, straight across the
##   gorge from the wreck of the bridge toward the giant: its forearm is a
##   SOLID RAMP (the collider follows the arm's top). Up the forearm to the
##   elbow, then a leap down onto the far plateau -- the only route left,
##   and the attack made it. (The giant stands well back, behind the far
##   plateau: the way never passes over its body.)
## * SWAT (far arm): while the near arm is still planted the other fist is
##   raised and brought down on the top of the near arm, where the runner
##   must have left from. Then the near arm lifts (its ramp goes) and the
##   rhythm repeats every CYCLE seconds.
##
## A fist that lands on the runner costs a heart and throws them. The
## guardian can shoot the glowing core in its chest: everything holds still
## for STUN seconds. Every pose is a function of the clock (placed_tick of
## the notice and of the last stun), so all devices draw the same fight.
## state 1 = noticed since placed_tick. "<id>_stun|1|tick|total" = staggered.

const NOTICE := 0.5
const CYCLE := 6.4
const WIND := 0.95      # slam: raise
const DROP := 0.17      # slam: fall
const PLANT := 3.6      # slam: arm planted, a ramp
const LIFT := 0.7       # slam: back to rest
const SWAT_WIND := 2.85  # swat: raised from here...
const SWAT_AT := 3.75    # ...falls from here...
const SWAT_DROP := 0.16
const SWAT_HOLD := 0.35
const SWAT_BACK := 0.6
const STUN := 2.5
const FIST_R := 78.0
## Arm segment lengths (world) of the painted arm sprites.
const UPPER := 400.0
const FORE := 560.0
## The arm's top surface above its centre line (painted thickness).
const ARM_TOP := 56.0
## Painted arm thickness (sprite scale across the arm).
const ARM_THICK := 1.5
## Bridge blocks: crack, sag, then fall. Nearest the impact first.
const BREAK_WAVE := 1100.0
const SAG := 0.55
const FALL_G := 2000.0

const TEX_BODY := "res://assets/stage_1_10/giant_body.png"
const TEX_UPPER := "res://assets/stage_1_10/giant_upper_arm.png"
const TEX_FORE := "res://assets/stage_1_10/giant_fist_arm.png"
const TEX_ROCK := "res://assets/stage_1_10/tex_mesa.png"

var _core: Area2D
var _back: Node2D
var _ramp: AnimatableBody2D
var _blocks: Array[AnimatableBody2D] = []
## Per block: [rect (world), break delay after impact, spin]
var _block_info: Array = []
var _stun_tick := -100000
var _pause_before := 0.0
var _pause_after := 0.0
var _last_impact := -1
var _last_swat := -1
var _fell := 0

func _build() -> void:
	z_index = 6
	reach = Vector2(2400, 1700)
	_core = make_target(Vector2(0, -620), 34.0)
	_back = Back.new()
	_back.giant = self
	# Behind the plateaus' rock faces: it stands in the gorge between them.
	_back.z_as_relative = false
	_back.z_index = 1
	_back.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_back)
	# The stone bridge: blocks of uneven width, each its own body.
	var bridge: Rect2 = data.get("bridge", Rect2(18000, 300, 1100, 70))
	var widths: Array = data.get("blocks", [110, 90, 130, 80, 120, 100, 140, 90, 120, 120])
	var x := bridge.position.x
	var hit := slam_target().x
	for i in widths.size():
		var w := float(widths[i]) if i < widths.size() - 1 else bridge.end.x - x
		var rect := Rect2(x, bridge.position.y, w, bridge.size.y)
		var b := make_body(rect.size)
		# Posed straight from the clock each tick (crack, sag, fall).
		b.sync_to_physics = false
		_blocks.append(b)
		var d := absf(rect.get_center().x - hit)
		# Blocks under the fist go at once; the rest crack and sag first.
		var under := rect.end.x > hit - FIST_R and rect.position.x < hit + FIST_R
		_block_info.append([rect, 0.0 if under else SAG + d / BREAK_WAVE, (FinaleGround.h(i * 7) - 0.5) * 3.0])
		x += w
	_ramp = make_body(Vector2(10, 30))
	_ramp.sync_to_physics = false
	set_solid(_ramp, false)

func _receive(id: String) -> void:
	var fields := id.split("|")
	if fields.size() == 4 and fields[0] == switch_id + "_stun":
		_stun_tick = int(fields[2])
		_pause_before = _pause_after
		_pause_after = float(fields[3])
		sound("hit", -6.0, 1.4)
		FinaleFx.kick(6.0)
		return
	super._receive(id)

func _on_shot() -> void:
	if state == 1 and since() > NOTICE and Clock.tick - _stun_tick > Clock.ticks_for(STUN):
		Events.switch_activated.emit("%s_stun|1|%d|%.3f" % [switch_id, Clock.tick, _pause_after + STUN])

# ------------------------------------------------------------------- timing
## Fight time: seconds since the notice, with any stun window held still.
func fight_time(tick: int = Clock.tick) -> float:
	if state == 0:
		return 0.0
	var t := since(tick)
	var stun_at := float(_stun_tick - placed_tick) / float(Clock.HZ)
	if t >= stun_at and t < stun_at + STUN:
		return stun_at - _pause_before
	return t - (_pause_after if t >= stun_at + STUN else _pause_before)

## Position in the attack cycle (seconds), or -1 before the first wind-up.
func cycle_time(tick: int = Clock.tick) -> float:
	var t := fight_time(tick) - NOTICE
	return -1.0 if state == 0 or t < 0.0 else fposmod(t, CYCLE)

## Fight time of the first slam's impact.
func first_impact() -> float:
	return NOTICE + WIND + DROP

## Seconds since the first impact (the bridge's clock), or -1.
func since_break(tick: int = Clock.tick) -> float:
	var t := fight_time(tick) - first_impact()
	return t if state == 1 and t >= 0.0 else -1.0

func stunned() -> bool:
	return Clock.tick - _stun_tick < Clock.ticks_for(STUN)

## 0..1 how far the slam fist is through its wind-up (the telegraph).
func windup(tick: int = Clock.tick) -> float:
	var c := cycle_time(tick)
	return clampf(c / WIND, 0.0, 1.0) if c >= 0.0 and c < WIND else 0.0

## 0..1 how far the notice is through (eyes flare, body leans).
func notice(tick: int = Clock.tick) -> float:
	return clampf(fight_time(tick) / NOTICE, 0.0, 1.0) if state == 1 else 0.0

func slam_target() -> Vector2:
	return data.get("slam_at", Vector2(18190, 262))

func swat_target() -> Vector2:
	return data.get("swat_at", Vector2(18640, -150))

func planted(tick: int = Clock.tick) -> bool:
	var c := cycle_time(tick)
	return c >= WIND + DROP and c < WIND + DROP + PLANT

func swat_falling(tick: int = Clock.tick) -> bool:
	var c := cycle_time(tick)
	return c >= SWAT_AT and c < SWAT_AT + SWAT_DROP + 0.05

## Block i: 0 whole, 1 cracked and sagging, 2 falling.
func block_phase(i: int, tick: int = Clock.tick) -> int:
	var t := since_break(tick)
	if t < 0.0:
		return 0
	return 1 if t < float(_block_info[i][1]) else 2

func block_count() -> int:
	return _blocks.size()

func block_rect(i: int) -> Rect2:
	return _block_info[i][0]

func block_body(i: int) -> AnimatableBody2D:
	return _blocks[i]

func bridge_broken(tick: int = Clock.tick) -> bool:
	return since_break(tick) >= 0.0

func ramp_body() -> AnimatableBody2D:
	return _ramp

# --------------------------------------------------------------- the arms
func shoulder(side: int) -> Vector2:
	return global_position + Vector2(250.0 * float(side), -830.0)

## Where the near (slam) fist is, world.
func slam_fist(tick: int = Clock.tick) -> Vector2:
	var rest := global_position + Vector2(-300, -560)
	var drawn := rest + Vector2(40, -120)
	var target := slam_target()
	# Raised high over the bridge -- but within sight of the runner.
	var high := Vector2(target.x + 80.0, target.y - 440.0)
	var c := cycle_time(tick)
	if c < 0.0:
		# Noticing: the near fist draws in toward the chest.
		return rest.lerp(drawn, smoothstep(0.0, 1.0, notice(tick)))
	if c < WIND:
		return drawn.lerp(high, smoothstep(0.0, 1.0, c / WIND))
	if c < WIND + DROP:
		var k := (c - WIND) / DROP
		return high.lerp(target, k * k)
	if c < WIND + DROP + PLANT:
		return target
	var k := clampf((c - WIND - DROP - PLANT) / LIFT, 0.0, 1.0)
	return target.lerp(drawn, smoothstep(0.0, 1.0, k))

## Where the far (swat) fist is, world.
func swat_fist(tick: int = Clock.tick) -> Vector2:
	var rest := global_position + Vector2(300, -560)
	var target := swat_target()
	# From above and behind the arm's top: clear of a runner leaping off it.
	var high := target + Vector2(-170.0, -620.0)
	var c := cycle_time(tick)
	if c < SWAT_WIND:
		return rest
	if c < SWAT_AT:
		return rest.lerp(high, smoothstep(0.0, 1.0, (c - SWAT_WIND) / (SWAT_AT - SWAT_WIND)))
	if c < SWAT_AT + SWAT_DROP:
		var k := (c - SWAT_AT) / SWAT_DROP
		return high.lerp(target, k * k)
	if c < SWAT_AT + SWAT_DROP + SWAT_HOLD:
		return target
	var k := clampf((c - SWAT_AT - SWAT_DROP - SWAT_HOLD) / SWAT_BACK, 0.0, 1.0)
	return target.lerp(rest, smoothstep(0.0, 1.0, k))

## Two-bone reach from shoulder `s` to `f`: the elbow, bent outward/down.
static func elbow(s: Vector2, f: Vector2, bend: float) -> Vector2:
	var d := clampf(s.distance_to(f), absf(UPPER - FORE) + 1.0, UPPER + FORE - 1.0)
	var a := (UPPER * UPPER - FORE * FORE + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, UPPER * UPPER - a * a))
	var dir := (f - s).normalized()
	return s + dir * a + dir.orthogonal() * h * bend

## The planted arm's walkable top: the forearm, from just over the fist up
## to the elbow (world points). The upper arm and the body stay out of the
## way: the runner leaves from the elbow.
func ramp_line() -> PackedVector2Array:
	var f := slam_target()
	var e := elbow(shoulder(-1), f, -1.0)
	var u := (e - f).normalized()
	var n := Vector2(u.y, -u.x)
	if n.y > 0.0:
		n = -n
	return PackedVector2Array([f + u * 30.0 + n * ARM_TOP, e + n * ARM_TOP])

# ------------------------------------------------------------------ the sim
func _pose(tick: int) -> void:
	_core.position = Vector2(0, -620)
	var sb := since_break(tick)
	for i in _blocks.size():
		var rect: Rect2 = _block_info[i][0]
		var delay: float = _block_info[i][1]
		var b := _blocks[i]
		var at := rect.get_center()
		var rot := 0.0
		var solid := true
		if sb >= 0.0:
			if sb < delay:
				# Cracked: sags and trembles under whoever is on it.
				var k := sb / maxf(delay, 0.01)
				at.y += 14.0 * k * k
				rot = sin(sb * 40.0 + float(i)) * 0.012 * k
			else:
				var t := sb - delay
				at.y += 14.0 + 0.5 * FALL_G * t * t
				at.x += (rect.get_center().x - slam_target().x) * 0.25 * t
				rot = float(_block_info[i][2]) * t
				solid = false
		b.position = at - global_position
		b.rotation = rot
		set_solid(b, solid)
		b.visible = at.y < rect.position.y + 1600.0
	# The ramp: solid only while the slam arm is planted.
	var line := ramp_line()
	var u := line[1] - line[0]
	var n := Vector2(-u.normalized().y, u.normalized().x)
	if n.y < 0.0:
		n = -n
	var shape := (_ramp.get_child(0) as CollisionShape2D).shape as RectangleShape2D
	shape.size = Vector2(u.length(), 30.0)
	_ramp.rotation = u.angle()
	# Its top face on the line: the box hangs 15px under it.
	_ramp.position = (line[0] + line[1]) * 0.5 + n * 15.0 - global_position
	set_solid(_ramp, planted(tick))
	if state != 1:
		return
	var c := cycle_time(tick)
	var cyc := int(floorf((fight_time(tick) - NOTICE) / CYCLE))
	if c >= WIND + DROP and c < WIND + DROP + PLANT and cyc != _last_impact:
		_last_impact = cyc
		if c < WIND + DROP + 0.2:
			sound("boom", -1.0 if cyc == 0 else 1.0, 1.8)
			sound("thud", -4.0, 1.4)
			FinaleFx.kick(20.0 if cyc == 0 else 12.0)
			if cyc == 0:
				sound("crumble", -3.0, 1.6)
	if c >= SWAT_AT + SWAT_DROP and c < SWAT_AT + SWAT_DROP + SWAT_HOLD and cyc != _last_swat:
		_last_swat = cyc
		if c < SWAT_AT + SWAT_DROP + 0.2:
			sound("boom", 3.0, 1.4)
			FinaleFx.kick(12.0)
	if c >= SWAT_AT and c < SWAT_AT + 1.0 / 60.0:
		sound("whoosh", -6.0, 1.3)
	# The bridge's blocks letting go, one after another.
	if sb >= 0.0:
		var gone := 0
		for i in _blocks.size():
			if sb >= float(_block_info[i][1]):
				gone += 1
		if gone > _fell:
			_fell = gone
			if gone > 1:
				sound("crumble", 2.0 - float(gone) * 0.4, 0.9)

func _on_state() -> void:
	_last_impact = -1
	_last_swat = -1
	_fell = 0
	sound("rumble", -3.0, 1.6)
	FinaleFx.kick(6.0)

func _host_step(_delta: float) -> void:
	if state == 0:
		if runner.global_position.x >= float(data.get("trigger", 17860.0)):
			set_state(1)
		return
	if stunned():
		return
	var c := cycle_time()
	if c >= WIND and c < WIND + DROP + 0.1 and runner_hits_circle(slam_fist(), FIST_R):
		hurt_runner(Vector2(-420.0, -380.0))
	if c >= SWAT_AT and c < SWAT_AT + SWAT_DROP + 0.1 and runner_hits_circle(swat_fist(), FIST_R):
		hurt_runner(Vector2(380.0, -260.0))

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var base := global_position
	_draw_bridge()
	var c := cycle_time()
	var target := slam_target() - base
	var deck := Vector2(target.x, 300.0 - base.y)
	# Telegraph: the fist's shadow gathering on the stone where it will land.
	var w := windup()
	if w > 0.0 or (c >= WIND and c < WIND + DROP):
		var k := 1.0 if w <= 0.0 else w
		draw_set_transform(deck + Vector2(0, -2), 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, FIST_R * (0.6 + 0.9 * k), Color(0.1, 0.05, 0.1, 0.2 + 0.35 * k))
		draw_set_transform(Vector2.ZERO)
	# Dust and a shock ring at each slam.
	if c >= WIND + DROP and c < WIND + DROP + 0.5:
		var k := (c - WIND - DROP) / 0.5
		draw_set_transform(deck, 0.0, Vector2(1.0, 0.3))
		draw_arc(Vector2.ZERO, 70.0 + 300.0 * k, 0.0, TAU, 40, Color(1, 0.95, 0.8, 0.8 * (1.0 - k)), 10.0 * (1.0 - k) + 2.0)
		draw_set_transform(Vector2.ZERO)
		for i in 10:
			var a := PI + PI * float(i) / 9.0
			draw_circle(deck + Vector2(cos(a) * (50.0 + 160.0 * k), -10.0 - 60.0 * k * absf(sin(a))),
				20.0 + 28.0 * k, Color(0.92, 0.82, 0.66, 0.5 * (1.0 - k)))
	# The arms: far one first (behind), the planted near arm in front.
	_draw_arm(shoulder(1), swat_fist(), 1.0, true)
	_draw_arm(shoulder(-1), slam_fist(), -1.0, false)
	# Grit bursting off the arm where the swat lands.
	var sc := c - SWAT_AT - SWAT_DROP
	if sc >= 0.0 and sc < 0.45:
		var k := sc / 0.45
		var at := swat_target() - base + Vector2(0, FIST_R * 0.7)
		for i in 9:
			var a := TAU * float(i) / 9.0
			draw_circle(at + Vector2(cos(a), sin(a) * 0.5) * (40.0 + 130.0 * k), 14.0 + 20.0 * k, Color(0.92, 0.82, 0.66, 0.55 * (1.0 - k)))

## Depth of the bridge's underside at world x: one natural rock span,
## thick where it springs from the cliffs, thinner mid-gorge, ragged.
func _under(x: float) -> float:
	var bridge: Rect2 = data.get("bridge", Rect2(18000, 300, 1100, 70))
	var k := clampf((x - bridge.position.x) / bridge.size.x, 0.0, 1.0)
	return 46.0 + 110.0 * pow(absf(k - 0.5) * 2.0, 2.0) + 16.0 * sin(x * 0.031) + 10.0 * sin(x * 0.083 + 1.0)

## The stone bridge: one rock span until it is struck, then the blocks it
## breaks into crack apart, sag and fall one by one.
func _draw_bridge() -> void:
	var tex := FinaleArt._load(TEX_ROCK)
	var sb := since_break()
	for i in _blocks.size():
		var b := _blocks[i]
		if not b.visible:
			continue
		var rect: Rect2 = _block_info[i][0]
		var c := rect.get_center()
		var hw := rect.size.x * 0.5
		var top := rect.position.y
		# Local outline (around the block's centre): flat top, the span's
		# ragged underside.
		var pts := PackedVector2Array([Vector2(-hw, top - c.y), Vector2(hw, top - c.y)])
		for k in 5:
			var x := rect.end.x - rect.size.x * float(k) / 4.0
			pts.append(Vector2(x - c.x, top + _under(x) - c.y))
		var xf := Transform2D(b.rotation, b.position)
		var world := PackedVector2Array()
		var uv := PackedVector2Array()
		var cols := PackedColorArray()
		for p in pts:
			world.append(xf * p)
			uv.append((p + c) / 320.0)
			var depth := clampf((p.y + c.y - top) / 140.0, 0.0, 1.0)
			cols.append(Color(1, 1, 1).lerp(Color(0.55, 0.45, 0.5), depth))
		if tex != null:
			draw_polygon(world, cols, uv, tex)
		else:
			draw_colored_polygon(world, Color(0.5, 0.4, 0.35))
		var loose := sb >= 0.0 and sb >= float(_block_info[i][1])
		# Outline: the top and the underside always; the sides only once
		# the block has broken loose (whole, the span reads as one rock).
		var bottom := PackedVector2Array()
		for k in range(1, pts.size()):
			bottom.append(world[k])
		draw_polyline(bottom, Color(0.2, 0.1, 0.07, 0.9), 4.0, true)
		if loose:
			draw_line(world[0], world[world.size() - 1], Color(0.2, 0.1, 0.07, 0.9), 4.0, true)
		draw_line(world[0], world[1], Color(0.26, 0.40, 0.18), 5.0, true)
		draw_line(xf * (pts[0] + Vector2(0, 4)), xf * (pts[1] + Vector2(0, 4)), Color(0.45, 0.66, 0.32), 6.0, true)
		# Struck: the joint on the far side of the block cracks open.
		if sb >= 0.0 and not loose and i < _blocks.size() - 1:
			var k := clampf(sb / maxf(float(_block_info[i][1]), 0.05), 0.0, 1.0)
			var x := rect.end.x
			var crack := PackedVector2Array([Vector2(x, top), Vector2(x - 6.0, top + 18.0), Vector2(x + 5.0, top + 34.0 * k + 8.0),
				Vector2(x - 3.0, top + _under(x) * k)])
			var wc := PackedVector2Array()
			for p in crack:
				wc.append(xf * (p - c))
			draw_polyline(wc, Color(0.1, 0.04, 0.03, 0.95), 3.0 + 3.0 * k, true)
	# Grit pouring from the breaks.
	if sb >= 0.0 and sb < 2.5:
		for i in 14:
			var t := fposmod(sb * 1.3 + float(i) * 0.37, 1.0)
			var x := slam_target().x - 300.0 + 800.0 * FinaleGround.h(i * 5)
			var y := 360.0 + t * t * 600.0
			draw_circle(Vector2(x, y) - global_position, 5.0 + 6.0 * FinaleGround.h(i), Color(0.55, 0.42, 0.36, 0.7 * (1.0 - t)))

func _draw_arm(s: Vector2, f: Vector2, bend: float, mirror: bool) -> void:
	var e := elbow(s, f, bend)
	var base := global_position
	_segment(TEX_UPPER, s - base, e - base, Vector2(50, 70), Vector2(190, 70), mirror)
	_segment(TEX_FORE, e - base, f - base, Vector2(44, 85), Vector2(232, 85), mirror)

## Draw a painted segment so its `from`..`to` pixels span a..b (local).
func _segment(path: String, a: Vector2, b: Vector2, from: Vector2, to: Vector2, mirror: bool) -> void:
	var tex := FinaleArt._load(path)
	if tex == null:
		return
	var span := to.x - from.x
	var sx := a.distance_to(b) / span
	draw_set_transform(a, (b - a).angle(), Vector2(sx, ARM_THICK * (-1.0 if mirror else 1.0)))
	draw_texture(tex, -from)
	draw_set_transform(Vector2.ZERO)

## The giant's body, behind the terrain.
class Back extends Node2D:
	var giant
	func _draw() -> void:
		var tex := FinaleArt._load(giant.TEX_BODY)
		var nk: float = giant.notice()
		# Noticing: the whole body leans toward the runner.
		var lean := Vector2(-30.0 * nk, 20.0 * nk)
		if tex != null:
			# Painted at half size: origin (360, 620) is the giant's base.
			draw_set_transform(lean, -0.06 * nk, Vector2(2, 2))
			draw_texture(tex, -Vector2(360, 620))
		draw_set_transform(lean, -0.06 * nk, Vector2.ONE)
		var glow := 0.6 + 0.4 * sin(Clock.seconds_at(Clock.tick) * 3.0)
		var w: float = maxf(giant.windup(), nk * 0.6)
		for ex in [-62.0, 62.0]:
			var eye := Vector2(ex, -1002)
			if giant.state == 1:
				draw_circle(eye, 40.0 + 24.0 * w, Color(0.3, 0.95, 1.0, (0.25 + 0.45 * w) * glow))
				draw_circle(eye, 14.0 + 5.0 * w, Color(0.6, 1.0, 1.0))
				draw_circle(eye, 6.0, Color.WHITE)
			else:
				draw_circle(eye, 9.0, Color(0.3, 0.5, 0.6))
		var core := Vector2(0, -620)
		draw_circle(core, 62.0, Color(1.0, 0.6, 0.2, 0.25 if giant.stunned() else 0.45 * glow))
		FinaleArt.centred(self, "golem_eye", core, 92.0)
		draw_arc(core, 36.0, 0, TAU, 28, Color("ffd34a"), 5.0, true)
		draw_set_transform(Vector2.ZERO)
	func _process(_delta: float) -> void:
		if giant._near:
			queue_redraw()
