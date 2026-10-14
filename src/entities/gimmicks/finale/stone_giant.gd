extends FinaleMachine
## SOMETHING HUGE WAKES. A monumental automaton of ruin stone sleeps in the
## gorge below the plateau. Reaching the trigger wakes it: it rises over two
## seconds, swats the standing slab that blocks the way -- the slab topples
## into a bridge across the gorge -- and then swings a spiked mace on a chain
## low across that bridge every 3.4s. Jump it. The guardian can shoot the
## glowing core in its chest to stagger it: the mace hangs still for 2.5s.
##
## state 1 = awake since placed_tick. "<id>_stun|1|tick|total" = staggered.

const RISE := 2.0
const SWAT := 2.4
const TOPPLE := 0.6
const SWING := 3.2
const STUN := 2.5
const SUNK := 760.0
const MACE_R := 58.0

var _slab: AnimatableBody2D
var _slab_pivot := Vector2.ZERO
var _core: Area2D
var _back: Node2D
var _stun_tick := -100000
var _pause_before := 0.0
var _pause_after := 0.0
var _swatted := false

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
	_back.z_index = -2
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
	if state == 1 and since() > SWING and Clock.tick - _stun_tick > Clock.ticks_for(STUN):
		Events.switch_activated.emit("%s_stun|1|%d|%.3f" % [switch_id, Clock.tick, _pause_after + STUN])

func rise() -> float:
	if state == 0:
		return SUNK
	var k := clampf(since() / RISE, 0.0, 1.0)
	return SUNK * (1.0 - k) * (1.0 - k)

func slab_angle(tick: int = Clock.tick) -> float:
	if state == 0:
		return 0.0
	var k := clampf((since(tick) - SWAT) / TOPPLE, 0.0, 1.0)
	return PI * 0.5 * k * k

func mace_angle(tick: int = Clock.tick) -> float:
	if state == 0 or since(tick) < SWING:
		return -1.15
	var t := since(tick) - SWING
	var stun_at := float(_stun_tick - placed_tick) / 60.0 - SWING
	var amp := float(data.get("amp", 1.0))
	var w := TAU / float(data.get("period", 3.4))
	if t >= stun_at and t < stun_at + STUN:
		return amp * sin(w * (stun_at - _pause_before) - PI * 0.5)
	var pause := _pause_after if t >= stun_at + STUN else _pause_before
	# Ease the very first swing in from the raised position.
	var a := amp * sin(w * (t - pause) - PI * 0.5)
	return lerpf(-1.15, a, clampf(t / 0.8, 0.0, 1.0))

func mace_centre(tick: int = Clock.tick) -> Vector2:
	var a := mace_angle(tick)
	var pivot: Vector2 = data.get("pivot", Vector2(18760, -420))
	return pivot + Vector2(sin(a), cos(a)) * float(data.get("length", 597.0))

func stunned() -> bool:
	return Clock.tick - _stun_tick < Clock.ticks_for(STUN)

func _pose(tick: int) -> void:
	_slab.position = _slab_pivot
	_slab.rotation = slab_angle(tick)
	_core.position = Vector2(0, -620 + rise())
	if state == 1 and since(tick) >= SWAT and not _swatted:
		_swatted = true
		if since(tick) < SWAT + 0.3:
			sound("boom", 0.0, 1.7)
			FinaleFx.kick(16.0)

func _on_state() -> void:
	_swatted = false
	sound("boom", -3.0, 1.4)
	FinaleFx.kick(9.0)

func _host_step(_delta: float) -> void:
	if state == 0:
		if runner.global_position.x >= float(data.get("trigger", 18150.0)):
			set_state(1)
		return
	if since() >= SWING and runner_hits_circle(mace_centre(), MACE_R):
		var dir := signf(mace_angle() - mace_angle(Clock.tick - 1) + 0.0001)
		hurt_runner(Vector2(dir * 600.0, -420.0))
	# The falling slab knocks anyone standing in its arc.
	var a := slab_angle()
	if a > 0.05 and a < PI * 0.5 - 0.05:
		var slab: Rect2 = data.get("slab", Rect2())
		var pivot := Vector2(slab.end.x, slab.end.y)
		var tip := pivot + Vector2(-slab.size.x * 0.5, -slab.size.y).rotated(a)
		if runner_hits_circle(pivot.lerp(tip, 0.6), 60.0):
			hurt_runner(Vector2(300, -300))

func _draw() -> void:
	var pivot: Vector2 = data.get("pivot", Vector2(18760, -420))
	var base := global_position
	var lift := rise()
	# Slab (local to its own body).
	var slab: Rect2 = data.get("slab", Rect2())
	draw_set_transform(_slab_pivot, _slab.rotation, Vector2.ONE)
	FinaleArt.slab_on(self, Rect2(-slab.size, slab.size), "sand")
	draw_rect(Rect2(-slab.size, slab.size), Color("4a2e1e"), false, 4.0)
	draw_set_transform(Vector2.ZERO)
	if state == 0:
		return
	# Swatting arm: shoulder to fist, a run of stone blocks.
	var shoulder := Vector2(-200, -780 + lift)
	var t := since()
	var fist := Vector2(330, -450 + lift)
	if t < SWAT:
		var k := clampf((t - 1.6) / 0.6, 0.0, 1.0)
		fist = Vector2(330, -450 + lift).lerp(Vector2(-560, -1400 + lift), k)
	elif t < SWAT + 0.5:
		var k := clampf((t - SWAT) / 0.12, 0.0, 1.0)
		var hit := Vector2(slab.position.x - base.x - 40, slab.position.y - base.y + 40)
		fist = Vector2(-560, -1400).lerp(hit, k)
	else:
		var k := clampf((t - SWAT - 0.5) / 0.8, 0.0, 1.0)
		var hit := Vector2(slab.position.x - base.x - 40, slab.position.y - base.y + 40)
		fist = hit.lerp(Vector2(-330, -500 + lift), k)
	_arm(shoulder, fist, 96.0)
	# Mace arm holds the chain's pivot high overhead.
	var hand := pivot - base
	_arm(Vector2(200, -800 + lift), hand, 90.0)
	var c := mace_centre() - base
	var links := int(hand.distance_to(c) / 30.0)
	for i in links:
		var p := hand.lerp(c, (float(i) + 0.5) / float(links))
		draw_circle(p, 9.0, Color("2b2326"))
		draw_circle(p, 5.0, Color("8a8a96"))
	var swing := absf(cos(TAU / float(data.get("period", 3.4)) * t))
	if since() >= SWING and not stunned() and swing > 0.5:
		var r := float(data.get("length", 597.0))
		var a := mace_angle()
		draw_arc(hand, r, PI * 0.5 - a - 0.3, PI * 0.5 - a + 0.3, 16, Color(1, 1, 1, 0.22 * swing), MACE_R * 1.6)
	FinaleArt.centred(self, "mace", c, MACE_R * 2.6, t * 2.0)

func _arm(from: Vector2, to: Vector2, width: float) -> void:
	var n := maxi(2, int(from.distance_to(to) / (width * 0.8)))
	# Two passes (all rims, then all stones) so the rims batch together.
	for i in n + 1:
		var size := width * (1.15 if i == n else 0.95)
		draw_circle(from.lerp(to, float(i) / float(n)), size * 0.56, Color(0.13, 0.12, 0.18, 0.9))
	for i in n + 1:
		var size := width * (1.15 if i == n else 0.95)
		FinaleArt.centred(self, "stone", from.lerp(to, float(i) / float(n)), size, float(i) * 0.4, Color(0.66, 0.69, 0.78))

## The giant's body, behind the terrain.
class Back extends Node2D:
	var giant
	func _draw() -> void:
		if giant.state == 0:
			# Asleep: only the crown of its head above the gorge floor mist.
			_body(giant.SUNK)
			return
		_body(giant.rise())
	func _body(lift: float) -> void:
		# Grey-blue ruin stone, so the automaton reads apart from the
		# sandstone plateau it rises out of; every block gets a dark rim.
		var stone := Color(0.66, 0.69, 0.78)
		var rim := Color(0.13, 0.12, 0.18, 0.92)
		var blocks: Array = []
		# Legs.
		for side in [-1.0, 1.0]:
			for k in 4:
				blocks.append([Vector2(side * 110.0, -60.0 - k * 95.0 + lift), 130.0])
		# Torso: a wall of ruin blocks, wider at the shoulders.
		for row in 5:
			var w := 3 + (1 if row >= 2 else 0)
			for col in w:
				var x := (float(col) - float(w - 1) * 0.5) * 110.0
				blocks.append([Vector2(x, -430.0 - row * 95.0 + lift), 122.0])
		# Head.
		for col in 3:
			for row in 2:
				blocks.append([Vector2((col - 1) * 100.0, -950.0 - row * 90.0 + lift), 112.0])
		for b in blocks:
			draw_rect(Rect2(b[0] - Vector2.ONE * float(b[1]) * 0.56, Vector2.ONE * float(b[1]) * 1.12), rim)
		# Upright blocks need no transform, so they batch into one draw.
		var t := FinaleArt.tex("stone")
		if t != null:
			var aspect := float(t.get_height()) / float(t.get_width())
			for b in blocks:
				var w := float(b[1])
				draw_texture_rect(t, Rect2(b[0] - Vector2(w, w * aspect) * 0.5, Vector2(w, w * aspect)), false, stone)
		# Moss on the shoulders and the crown.
		draw_rect(Rect2(-240, -880 + lift, 480, 22), Color("4f9a34"))
		draw_rect(Rect2(-150, -1088 + lift, 300, 18), Color("5fa83a"))
		# A dark brow band and two glowing eyes.
		var glow := 0.6 + 0.4 * sin(Clock.seconds_at(Clock.tick) * 3.0)
		draw_rect(Rect2(-150, -1000 + lift, 300, 70), Color(0.08, 0.08, 0.12, 0.95))
		for ex in [-60.0, 60.0]:
			var eye := Vector2(ex, -965 + lift)
			if giant.state == 1:
				draw_circle(eye, 34.0, Color(0.3, 0.95, 1.0, 0.35 * glow))
				draw_circle(eye, 15.0, Color(0.75, 1.0, 1.0))
			else:
				draw_circle(eye, 10.0, Color(0.3, 0.5, 0.6))
		# Chest core (the shot target).
		var core := Vector2(0, -620 + lift)
		draw_circle(core, 52.0, Color(1.0, 0.6, 0.2, 0.25 if giant.stunned() else 0.4 * glow))
		FinaleArt.centred(self, "golem_eye", core, 84.0)
		draw_arc(core, 30.0, 0, TAU, 28, Color("ffd34a"), 4.0, true)
	func _process(_delta: float) -> void:
		if giant._near:
			queue_redraw()
