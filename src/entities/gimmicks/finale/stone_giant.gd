extends FinaleMachine
## SOMETHING HUGE WAKES. A stone giant sleeps in the gorge between the two
## plateaus. Reaching the trigger wakes it: it rises and blocks the way, then
## fights with both fists on a fixed rhythm (every CYCLE seconds):
##
## * SLAM (near arm): the fist is raised high over the plateau's end -- its
##   shadow grows on the ground where it will land -- then driven down. The
##   impact cracks the plateau and throws debris; the first impact knocks
##   the standing stone pillar over the gorge: the only bridge across.
## * SWIPE (far arm): drawn back, then swept flat across the bridge at body
##   height. Jump it.
##
## A fist that lands on the runner costs a heart and throws them back. The
## guardian can shoot the glowing core in its chest: both fists freeze for
## STUN seconds.
##
## Every pose is a function of the clock (placed_tick of the wake and of the
## last stun), so all devices draw the same fight.
## state 1 = awake since placed_tick. "<id>_stun|1|tick|total" = staggered.

const RISE := 1.3
const CYCLE := 3.0
const WIND := 0.9       # slam: raise
const DROP := 0.18      # slam: fall
const PLANT := 0.72     # slam: fist on the ground
const LIFT := 0.6       # slam: back to rest
const SWIPE_WIND := 2.0  # swipe: drawn back from here...
const SWIPE_AT := 2.6    # ...swept across from here...
const SWIPE_END := 2.95  # ...to here, then back.
const TOPPLE := 0.6
const STUN := 2.5
const SUNK := 760.0
const FIST_R := 78.0
## Arm segment lengths (world) of the painted arm sprites.
const UPPER := 280.0
const FORE := 376.0

const TEX_BODY := "res://assets/stage_1_10/giant_body.png"
const TEX_UPPER := "res://assets/stage_1_10/giant_upper_arm.png"
const TEX_FORE := "res://assets/stage_1_10/giant_fist_arm.png"

var _slab: AnimatableBody2D
var _slab_pivot := Vector2.ZERO
var _core: Area2D
var _back: Node2D
var _stun_tick := -100000
var _pause_before := 0.0
var _pause_after := 0.0
var _last_impact := -1

func _build() -> void:
	z_index = 6
	reach = Vector2(2200, 1600)
	var slab: Rect2 = data.get("slab", Rect2(18500, -100, 60, 400))
	_slab = make_body(slab.size)
	# It only ever falls over once: no rider to carry, so no physics sync
	# (which would also fight the per-tick rotation).
	_slab.sync_to_physics = false
	_slab_pivot = Vector2(slab.end.x, slab.end.y) - global_position
	_slab.position = _slab_pivot
	(_slab.get_child(0) as Node2D).position = -slab.size * 0.5
	_core = make_target(Vector2(0, -620), 34.0)
	_back = Back.new()
	_back.giant = self
	# Behind the plateaus' rock faces: it stands in the gorge between them.
	_back.z_as_relative = false
	_back.z_index = 1
	_back.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_back)

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
	if state == 1 and since() > RISE + 0.5 and Clock.tick - _stun_tick > Clock.ticks_for(STUN):
		Events.switch_activated.emit("%s_stun|1|%d|%.3f" % [switch_id, Clock.tick, _pause_after + STUN])

# ------------------------------------------------------------------- timing
func rise() -> float:
	if state == 0:
		return SUNK
	var k := clampf(since() / RISE, 0.0, 1.0)
	return SUNK * (1.0 - k) * (1.0 - k)

## Fight time: seconds since the wake, with any stun windows held still.
func fight_time(tick: int = Clock.tick) -> float:
	if state == 0:
		return 0.0
	var t := since(tick)
	var stun_at := float(_stun_tick - placed_tick) / float(Clock.HZ)
	if t >= stun_at and t < stun_at + STUN:
		return stun_at - _pause_before
	return t - (_pause_after if t >= stun_at + STUN else _pause_before)

## Position in the attack cycle (seconds), or -1 while still rising.
func cycle_time(tick: int = Clock.tick) -> float:
	var t := fight_time(tick) - RISE
	return -1.0 if t < 0.0 else fposmod(t, CYCLE)

## Time of the first slam's impact, in fight time.
func first_impact() -> float:
	return RISE + WIND + DROP

func slab_angle(tick: int = Clock.tick) -> float:
	if state == 0:
		return 0.0
	var k := clampf((fight_time(tick) - first_impact()) / TOPPLE, 0.0, 1.0)
	return PI * 0.5 * k * k

func stunned() -> bool:
	return Clock.tick - _stun_tick < Clock.ticks_for(STUN)

## 0..1 how far the slam fist is through its wind-up (the telegraph).
func windup(tick: int = Clock.tick) -> float:
	var c := cycle_time(tick)
	return clampf(c / WIND, 0.0, 1.0) if c >= 0.0 and c < WIND else 0.0

func slam_target() -> Vector2:
	return data.get("slam_at", Vector2(18420, 300))

func slam_planted(tick: int = Clock.tick) -> bool:
	var c := cycle_time(tick)
	return c >= WIND + DROP and c < WIND + DROP + PLANT

func swiping(tick: int = Clock.tick) -> bool:
	var c := cycle_time(tick)
	return c >= SWIPE_AT and c < SWIPE_END

# --------------------------------------------------------------- the arms
func shoulder(side: int, lift: float) -> Vector2:
	return global_position + Vector2(250.0 * float(side), -830.0 + lift)

## Where the near (slam) fist is, world.
func slam_fist(tick: int = Clock.tick) -> Vector2:
	var lift := rise()
	var rest := global_position + Vector2(-330, -330 + lift)
	var target := slam_target() + Vector2(0, -FIST_R + 6.0)
	var high := Vector2(target.x - 40.0, global_position.y - 1320.0 + lift)
	var c := cycle_time(tick)
	if c < 0.0:
		return rest
	if c < WIND:
		var k := smoothstep(0.0, 1.0, c / WIND)
		return rest.lerp(high, k)
	if c < WIND + DROP:
		var k := (c - WIND) / DROP
		return high.lerp(target, k * k)
	if c < WIND + DROP + PLANT:
		return target
	var k := clampf((c - WIND - DROP - PLANT) / LIFT, 0.0, 1.0)
	return target.lerp(rest, smoothstep(0.0, 1.0, k))

## Where the far (swipe) fist is, world.
func swipe_fist(tick: int = Clock.tick) -> Vector2:
	var lift := rise()
	var rest := global_position + Vector2(330, -360 + lift)
	var back := global_position + Vector2(520, -700 + lift)
	var y := float(data.get("swipe_y", 196.0))
	var from := Vector2(global_position.x + 360.0, y)
	# Across the bridge only: it stops short of the plateau's edge.
	var to := Vector2(global_position.x - 200.0, y)
	var c := cycle_time(tick)
	if c < SWIPE_WIND:
		return rest
	if c < SWIPE_AT:
		var k := smoothstep(0.0, 1.0, (c - SWIPE_WIND) / (SWIPE_AT - SWIPE_WIND))
		return rest.lerp(back, k)
	if c < SWIPE_AT + 0.08:
		return back.lerp(from, (c - SWIPE_AT) / 0.08)
	if c < SWIPE_END:
		var k := (c - SWIPE_AT - 0.08) / (SWIPE_END - SWIPE_AT - 0.08)
		return from.lerp(to, k * (2.0 - k))
	var k := clampf((c - SWIPE_END) / 0.05, 0.0, 1.0)
	return to.lerp(rest, smoothstep(0.0, 1.0, k))

## Two-bone reach from shoulder `s` to `f`: the elbow, bent outward/down.
static func elbow(s: Vector2, f: Vector2, bend: float) -> Vector2:
	var d := clampf(s.distance_to(f), absf(UPPER - FORE) + 1.0, UPPER + FORE - 1.0)
	var a := (UPPER * UPPER - FORE * FORE + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, UPPER * UPPER - a * a))
	var dir := (f - s).normalized()
	return s + dir * a + dir.orthogonal() * h * bend

# ------------------------------------------------------------------ the sim
func _pose(tick: int) -> void:
	_slab.position = _slab_pivot
	_slab.rotation = slab_angle(tick)
	_core.position = Vector2(0, -620 + rise())
	if state != 1:
		return
	# The slam's impact: once per cycle, on every device.
	var c := cycle_time(tick)
	var n := int(floorf((fight_time(tick) - RISE) / CYCLE))
	if c >= WIND + DROP and c < WIND + DROP + PLANT and n != _last_impact:
		_last_impact = n
		if c < WIND + DROP + 0.2:
			sound("boom", -1.0 if n == 0 else 1.0, 1.8)
			sound("thud", -4.0, 1.4)
			FinaleFx.kick(20.0 if n == 0 else 12.0)
			if n == 0:
				sound("crumble", -3.0, 1.4)
	if c >= SWIPE_AT and c < SWIPE_AT + 1.0 / 60.0:
		sound("whoosh", -6.0, 1.3)

func _on_state() -> void:
	_last_impact = -1
	sound("rumble", -3.0, 1.6)
	FinaleFx.kick(9.0)

func _host_step(_delta: float) -> void:
	if state == 0:
		if runner.global_position.x >= float(data.get("trigger", 18150.0)):
			set_state(1)
		return
	if stunned():
		return
	var c := cycle_time()
	if c >= WIND and c < WIND + DROP + PLANT and runner_hits_circle(slam_fist(), FIST_R):
		hurt_runner(Vector2(-420.0, -380.0))
	if swiping() and runner_hits_circle(swipe_fist(), FIST_R):
		hurt_runner(Vector2(-520.0, -320.0))
	# The falling pillar knocks anyone standing in its arc.
	var a := slab_angle()
	if a > 0.05 and a < PI * 0.5 - 0.05:
		var slab: Rect2 = data.get("slab", Rect2())
		var pivot := Vector2(slab.end.x, slab.end.y)
		var tip := pivot + Vector2(-slab.size.x * 0.5, -slab.size.y).rotated(a)
		if runner_hits_circle(pivot.lerp(tip, 0.6), 60.0):
			hurt_runner(Vector2(300, -300))

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var base := global_position
	var slab: Rect2 = data.get("slab", Rect2())
	# The pillar (local to its own pivot), then the impact marks on the plateau.
	draw_set_transform(_slab_pivot, _slab.rotation, Vector2.ONE)
	FinaleArt.slab_on(self, Rect2(-slab.size, slab.size), "cliff")
	draw_set_transform(Vector2.ZERO)
	if state == 0:
		return
	var lift := rise()
	var c := cycle_time()
	var target := slam_target() - base
	# Telegraph: the fist's shadow gathering where it will land.
	var w := windup()
	if w > 0.0 or (c >= WIND and c < WIND + DROP):
		var k := 1.0 if w <= 0.0 else w
		draw_set_transform(target + Vector2(0, -2), 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, FIST_R * (0.6 + 0.8 * k), Color(0.1, 0.05, 0.1, 0.18 + 0.32 * k))
		draw_set_transform(Vector2.ZERO)
	# The crater once the first slam has landed: cracks radiating out.
	var ft := fight_time()
	if ft >= first_impact():
		var cracks := TriBatch.new()
		for i in 7:
			var a := PI + PI * (float(i) + 0.5) / 7.0
			var p := target
			var line := PackedVector2Array([p])
			for k in 3:
				p += Vector2(cos(a), sin(a) * 0.25) * (30.0 + 22.0 * FinaleGround.h(i * 5 + k)) + Vector2(0, 2)
				line.append(p)
			cracks.polyline(line, 5.0, Color(0.16, 0.07, 0.04, 0.85))
		cracks.flush(self)
		# Debris thrown up by the latest impact, and a shock ring.
		var since_hit := c - (WIND + DROP)
		if since_hit >= 0.0 and since_hit < 1.1:
			for i in 9:
				var v := Vector2((FinaleGround.h(i * 3) - 0.5) * 700.0, -380.0 - 420.0 * FinaleGround.h(i * 7))
				var p := target + v * since_hit + Vector2(0, 0.5 * 1800.0 * since_hit * since_hit)
				FinaleArt.centred(self, "stone", p, 26.0 + 18.0 * FinaleGround.h(i), since_hit * 6.0 + float(i), Color(0.75, 0.5, 0.4))
			if since_hit < 0.45:
				var k := since_hit / 0.45
				draw_set_transform(target, 0.0, Vector2(1.0, 0.3))
				draw_arc(Vector2.ZERO, 60.0 + 260.0 * k, 0.0, TAU, 40, Color(1, 0.95, 0.8, 0.8 * (1.0 - k)), 10.0 * (1.0 - k) + 2.0)
				draw_set_transform(Vector2.ZERO)
				for i in 10:
					var a := PI + PI * float(i) / 9.0
					draw_circle(target + Vector2(cos(a) * (40.0 + 140.0 * k), -10.0 - 50.0 * k * absf(sin(a))), 18.0 + 26.0 * k,
						Color(0.92, 0.82, 0.66, 0.55 * (1.0 - k)))
	# The arms, far one first.
	_draw_arm(shoulder(1, lift), swipe_fist(), 1.0, true)
	if swiping():
		var f := swipe_fist() - base
		for i in 4:
			draw_line(f + Vector2(40.0 + 50.0 * float(i), -50.0 + 33.0 * float(i)), f + Vector2(160.0 + 80.0 * float(i), -50.0 + 33.0 * float(i)),
				Color(1, 1, 1, 0.55 - 0.1 * float(i)), 6.0)
	_draw_arm(shoulder(-1, lift), slam_fist(), -1.0, false)

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
	draw_set_transform(a, (b - a).angle(), Vector2(sx, 2.0 * (-1.0 if mirror else 1.0)))
	draw_texture(tex, -from)
	draw_set_transform(Vector2.ZERO)

## The giant's body, behind the terrain.
class Back extends Node2D:
	var giant
	func _draw() -> void:
		var lift: float = giant.rise()
		var tex := FinaleArt._load(giant.TEX_BODY)
		if tex != null:
			# Painted at half size: origin (360, 620) is the giant's base.
			draw_set_transform(Vector2(0, lift), 0.0, Vector2(2, 2))
			draw_texture(tex, -Vector2(360, 620))
			draw_set_transform(Vector2.ZERO)
		var glow := 0.6 + 0.4 * sin(Clock.seconds_at(Clock.tick) * 3.0)
		var angry: bool = giant.state == 1
		var w: float = giant.windup()
		for ex in [-62.0, 62.0]:
			var eye := Vector2(ex, -1002 + lift)
			if angry:
				draw_circle(eye, 40.0 + 20.0 * w, Color(0.3, 0.95, 1.0, (0.25 + 0.35 * w) * glow))
				draw_circle(eye, 14.0 + 4.0 * w, Color(0.6, 1.0, 1.0))
				draw_circle(eye, 6.0, Color.WHITE)
			else:
				draw_circle(eye, 8.0, Color(0.3, 0.5, 0.6))
		var core := Vector2(0, -620 + lift)
		draw_circle(core, 62.0, Color(1.0, 0.6, 0.2, 0.25 if giant.stunned() else 0.45 * glow))
		FinaleArt.centred(self, "golem_eye", core, 92.0)
		draw_arc(core, 36.0, 0, TAU, 28, Color("ffd34a"), 5.0, true)
	func _process(_delta: float) -> void:
		if giant._near:
			queue_redraw()
