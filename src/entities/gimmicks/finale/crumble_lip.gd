extends FinaleMachine
## The overhanging lip of the grassland cliff. It hangs past the edge the
## runner jumps from, and it gives way under the take-off: the chunks tumble
## into the gorge and fade into its haze, which is how the drop shows its
## depth. Purely the picture of the lip -- the walkable edge is the slab's.
##
## state 1 = broken at placed_tick. data: rect (the hanging lip, world),
## trigger_x (take-off past this x breaks it).

const CHUNKS := 7
const GRAVITY := 1500.0

var _rect := Rect2()

func _build() -> void:
	z_index = 3
	reach = Vector2(1400, 1600)
	_rect = data.get("rect", Rect2(1490, 1160, 90, 70))

func _host_step(_delta: float) -> void:
	if state == 0 and not runner.is_on_floor() and runner.velocity.y < 0.0 \
			and runner.global_position.x > float(data.get("trigger_x", 1450.0)) \
			and runner.global_position.x < _rect.end.x + 60.0:
		set_state(1)

func _on_state() -> void:
	if state == 1:
		sound("crumble", 2.0, 1.2)
		FinaleFx.kick(4.0)

## One chunk of the lip: a jagged rock polygon (local, centred).
func _chunk_poly(i: int, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 7:
		var a := TAU * float(k) / 7.0 + FinaleGround.h(i * 5) * 0.8
		pts.append(Vector2(cos(a), sin(a)) * size * (0.7 + 0.45 * FinaleGround.h(i * 13 + k)))
	return pts

func _draw() -> void:
	var local := Rect2(_rect.position - global_position, _rect.size)
	var tex := FinaleArt._load("res://assets/stage_1_10/tex_earth.png")
	var faces := TriBatch.new()
	var flat := TriBatch.new()
	var t := since() if state == 1 else 0.0
	for i in CHUNKS:
		var size := local.size.x * (0.22 + 0.12 * FinaleGround.h(i * 3))
		var home := local.position + Vector2(local.size.x * (float(i % 4) + 0.5) / 4.0,
			local.size.y * (0.3 + 0.45 * float(i / 4)))
		var at := home
		var rot := 0.0
		var alpha := 1.0
		if state == 1:
			var delay := 0.05 * float(i)
			var tt := maxf(0.0, t - delay)
			var vx := (FinaleGround.h(i * 7) - 0.3) * 140.0
			at = home + Vector2(vx * tt, 0.5 * GRAVITY * tt * tt)
			rot = tt * (2.0 + 4.0 * FinaleGround.h(i * 11)) * (1.0 if i % 2 == 0 else -1.0)
			# Swallowed by the gorge's haze as it falls.
			alpha = clampf(1.0 - (at.y - home.y) / 820.0, 0.0, 1.0)
			if alpha <= 0.0:
				continue
		var poly := _chunk_poly(i, size)
		var world := PackedVector2Array()
		var uvs := PackedVector2Array()
		for p in poly:
			var q := at + p.rotated(rot)
			world.append(q)
			uvs.append((q + global_position) / 360.0)
		var shade := Color(1, 1, 1, alpha).lerp(Color(0.55, 0.6, 0.8, alpha), 1.0 - alpha)
		faces.poly_uv(world, uvs, shade)
		var rim := PackedVector2Array(world)
		rim.append(world[0])
		flat.polyline(rim, 4.0, Color(0.29, 0.15, 0.07, alpha))
	faces.flush(self, tex)
	flat.flush(self)
	if state == 0:
		# The grass on top of the lip, hanging over the edge.
		var s: Dictionary = FinaleArt.SKINS["grass"]
		FinaleArt._cap_strip(self, s, [local.position, Vector2(local.end.x, local.position.y)])
	elif t < 0.8:
		# Dust burst where it broke away.
		for k in 8:
			var a := TAU * float(k) / 8.0
			var r := 20.0 + t * 160.0
			draw_circle(local.position + Vector2(local.size.x * 0.4, 10) + Vector2(cos(a), sin(a) * 0.5) * r,
				14.0 + t * 30.0, Color(0.85, 0.75, 0.6, 0.5 * (1.0 - t / 0.8)))
