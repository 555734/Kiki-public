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
	# A sculpted stone limb: upper arm and forearm as tapered slabs of the
	# giant's own rock, a heavy fist at the end.
	var elbow := from.lerp(to, 0.5) + (to - from).orthogonal().normalized() * width * 0.35
	var tex := FinaleArt._load(Giant.TEX)
	Giant.limb(self, from, elbow, width * 1.05, width * 0.9, tex)
	Giant.limb(self, elbow, to, width * 0.9, width * 0.75, tex)
	Giant.blob(self, to, width * 0.72, tex, 7)
	Giant.blob(self, elbow, width * 0.5, tex, 3)

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
		# A sculpted automaton of grey-blue ruin rock: stout legs, a broad
		# chest with heavy shoulder boulders, a blocky head with a brow and
		# two burning eyes; dark rims, moss, cracks. Reads apart from the
		# red mesa it rises out of.
		var tex := FinaleArt._load(Giant.TEX)
		var o := Vector2(0, lift)
		for side in [-1.0, 1.0]:
			Giant.limb(self, o + Vector2(side * 120.0, -470.0), o + Vector2(side * 140.0, 40.0), 150.0, 175.0, tex)
		var torso := PackedVector2Array()
		for p in [Vector2(-170, -400), Vector2(-250, -560), Vector2(-280, -760), Vector2(-230, -880), Vector2(-90, -920),
				Vector2(90, -920), Vector2(230, -880), Vector2(280, -760), Vector2(250, -560), Vector2(170, -400), Vector2(0, -360)]:
			torso.append(o + p)
		Giant.mass(self, torso, tex)
		# Belt of stone and a chest plate.
		Giant.mass(self, PackedVector2Array([o + Vector2(-190, -470), o + Vector2(190, -470), o + Vector2(175, -400), o + Vector2(-175, -400)]), tex, 0.8)
		for side in [-1.0, 1.0]:
			Giant.blob(self, o + Vector2(side * 250.0, -840.0), 115.0, tex, 11 if side > 0 else 5)
		var head := PackedVector2Array()
		for p in [Vector2(-140, -930), Vector2(-150, -1060), Vector2(-110, -1140), Vector2(0, -1165), Vector2(110, -1140),
				Vector2(150, -1060), Vector2(140, -930), Vector2(60, -900), Vector2(-60, -900)]:
			head.append(o + p)
		Giant.mass(self, head, tex)
		# Moss on the crown and the shoulders.
		for m in [[Vector2(-90, -1150), 180.0], [Vector2(-310, -930), 120.0], [Vector2(210, -935), 110.0]]:
			var at: Vector2 = o + m[0]
			var w: float = m[1]
			var moss := PackedVector2Array()
			for k in 9:
				var t := float(k) / 8.0
				moss.append(at + Vector2(w * t, -10.0 + sin(t * PI) * -14.0))
			for k in range(8, -1, -1):
				var t := float(k) / 8.0
				moss.append(at + Vector2(w * t, 14.0 + (FinaleGround.h(k * 7 + int(w)) * 22.0) * sin(t * PI)))
			draw_colored_polygon(moss, Color("4f8f30"))
		# Cracks.
		for c in [[Vector2(-120, -800), Vector2(-60, -700), Vector2(-90, -620)], [Vector2(140, -560), Vector2(90, -500)],
				[Vector2(40, -1120), Vector2(70, -1060)]]:
			var line := PackedVector2Array()
			for q in c:
				line.append(o + q)
			draw_polyline(line, Color(0.1, 0.1, 0.15, 0.8), 5.0, true)
		# Brow, eyes, mouth slit.
		var glow := 0.6 + 0.4 * sin(Clock.seconds_at(Clock.tick) * 3.0)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-130, -1060), o + Vector2(130, -1060), o + Vector2(120, -1020), o + Vector2(-120, -1020)]), Color(0.1, 0.1, 0.16))
		for ex in [-62.0, 62.0]:
			var eye := o + Vector2(ex, -1000)
			draw_circle(eye, 30.0, Color(0.05, 0.05, 0.09))
			if giant.state == 1:
				draw_circle(eye, 46.0, Color(0.3, 0.95, 1.0, 0.30 * glow))
				draw_circle(eye, 20.0, Color(0.55, 1.0, 1.0))
				draw_circle(eye, 8.0, Color.WHITE)
			else:
				draw_circle(eye, 10.0, Color(0.3, 0.5, 0.6))
		draw_line(o + Vector2(-70, -935), o + Vector2(70, -935), Color(0.08, 0.08, 0.12), 8.0)
		# Chest core (the shot target).
		var core := o + Vector2(0, -620)
		draw_circle(core, 70.0, Color(0.08, 0.08, 0.12))
		draw_circle(core, 62.0, Color(1.0, 0.6, 0.2, 0.25 if giant.stunned() else 0.45 * glow))
		FinaleArt.centred(self, "golem_eye", core, 96.0)
		draw_arc(core, 36.0, 0, TAU, 28, Color("ffd34a"), 5.0, true)
	func _process(_delta: float) -> void:
		if giant._near:
			queue_redraw()


## Shared painting for the giant's rock masses (body and arms).
class Giant:
	const TEX := "res://assets/stage_1_10/tex_giant.png"
	const RIM := Color(0.10, 0.10, 0.15)

	## A filled rock mass: textured, shaded darker toward its bottom and
	## right (light from the upper left), dark rim, lit upper-left edge.
	static func mass(ci: CanvasItem, poly: PackedVector2Array, tex: Texture2D, light: float = 1.0) -> void:
		var lo := Vector2(INF, INF)
		var hi := -lo
		for p in poly:
			lo = lo.min(p)
			hi = hi.max(p)
		var cols := PackedColorArray()
		var uvs := PackedVector2Array()
		for p in poly:
			var k := clampf(((p.x - lo.x) / maxf(hi.x - lo.x, 1.0)) * 0.4 + ((p.y - lo.y) / maxf(hi.y - lo.y, 1.0)) * 0.6, 0.0, 1.0)
			var v := lerpf(1.12, 0.62, k) * light
			cols.append(Color(v, v, v * 1.04))
			uvs.append(p / 360.0)
		if tex != null:
			ci.draw_polygon(poly, cols, uvs, tex)
		else:
			ci.draw_polygon(poly, cols)
		var line := PackedVector2Array(poly)
		line.append(poly[0])
		ci.draw_polyline(line, RIM, 7.0, true)

	## A tapered limb from a to b.
	static func limb(ci: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, tex: Texture2D) -> void:
		var n := (b - a).orthogonal().normalized()
		mass(ci, PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5]), tex)

	## A rounded boulder (shoulder, fist, joint), lumpy by `seed`.
	static func blob(ci: CanvasItem, c: Vector2, r: float, tex: Texture2D, seed: int) -> void:
		var poly := PackedVector2Array()
		for k in 10:
			var a := TAU * float(k) / 10.0
			poly.append(c + Vector2(cos(a), sin(a)) * r * (0.86 + 0.18 * FinaleGround.h(seed * 11 + k)))
		mass(ci, poly, tex)
