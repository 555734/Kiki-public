class_name FxBlast
extends Node2D
## A drawn effect that lives for a fraction of a second: the flash, the ring,
## the streaks and the smoke a hit is made of. Particles (Fx._burst) are the
## debris; this is the light and the force -- the part that makes a shot go
## BANG rather than tick.
##
## Purely visual: nothing here touches the stage clock, the physics or the
## wire, so it is free to be as loud as it likes on each device.

enum Kind { MUZZLE, BEAM, IMPACT, SHOCK, STREAKS, SMOKE, FIREBALL, BANG, SLAM, STAR }

var kind: int = Kind.IMPACT
var life: float = 0.3
var age: float = 0.0
var size: float = 1.0
var colour: Color = Color(1.0, 0.86, 0.45)
var to: Vector2 = Vector2.ZERO          ## BEAM: the far end, in world space
var dir: Vector2 = Vector2.RIGHT        ## MUZZLE, STREAKS, SMOKE: which way it goes
var text: String = ""
var _seed: int = 0
var _drift: Vector2 = Vector2.ZERO

const INK := Color(0.16, 0.10, 0.07)

static func make(k: int, at: Vector2, lifetime: float, scale: float = 1.0) -> FxBlast:
	var b := FxBlast.new()
	b.kind = k
	b.life = lifetime
	b.size = scale
	b.global_position = at
	b._seed = int(absf(at.x * 13.0 + at.y * 7.0)) % 9973
	return b

func _ready() -> void:
	z_index = 45
	if kind == Kind.SMOKE:
		_drift = dir * 40.0 * size + Vector2(0, -28.0)

func _process(delta: float) -> void:
	age += delta
	if kind == Kind.SMOKE:
		position += _drift * delta
		_drift *= 0.93
	if age >= life:
		queue_free()
		return
	queue_redraw()

func _r(i: int) -> float:
	return DrawUtil.hash01(_seed * 31 + i)

func _draw() -> void:
	var k := clampf(age / life, 0.0, 1.0)
	match kind:
		Kind.MUZZLE: _muzzle(k)
		Kind.BEAM: _beam(k)
		Kind.IMPACT: _impact(k)
		Kind.SHOCK: _shock(k)
		Kind.STREAKS: _streaks(k)
		Kind.SMOKE: _smoke(k)
		Kind.FIREBALL: _fireball(k)
		Kind.BANG: _bang(k)
		Kind.SLAM: _slam(k)
		Kind.STAR: _star_pop(k)

## A star of light at the barrel, longest along the shot.
func _muzzle(k: float) -> void:
	var a := 1.0 - k
	var r := 34.0 * size * (0.7 + 0.6 * k)
	var pts := PackedVector2Array()
	var n := 10
	for i in n * 2:
		var ang := dir.angle() + TAU * float(i) / float(n * 2)
		var along := absf(cos(ang - dir.angle()))
		var rad := r * (1.0 + along * 1.4) if i % 2 == 0 else r * 0.38
		pts.append(Vector2.from_angle(ang) * rad)
	draw_colored_polygon(pts, Color(1.0, 0.72, 0.25, 0.85 * a))
	draw_circle(Vector2.ZERO, r * 0.55, Color(1.0, 0.95, 0.75, a))
	draw_circle(Vector2.ZERO, r * 0.28, Color(1, 1, 1, a))

## The round's path: a white-hot core in a coloured glow, gone in a blink.
func _beam(k: float) -> void:
	var a := 1.0 - k
	var end := to - global_position
	var w := 1.0 - k * 0.6
	draw_line(Vector2.ZERO, end, Color(colour, 0.25 * a), 26.0 * size * w, true)
	draw_line(Vector2.ZERO, end, Color(colour, 0.7 * a), 11.0 * size * w, true)
	draw_line(Vector2.ZERO, end, Color(1, 1, 1, a), 4.0 * size * w, true)

## The hit itself: a white flash that swells and dies in a few frames, under
## a jagged starburst.
func _impact(k: float) -> void:
	var a := 1.0 - k
	var r := 30.0 * size * (0.6 + k * 0.9)
	draw_circle(Vector2.ZERO, r * 1.7, Color(colour, 0.22 * a))
	var pts := PackedVector2Array()
	var n := 12
	for i in n * 2:
		var ang := TAU * float(i) / float(n * 2) + _r(1) * TAU
		var rad := r * (1.25 + _r(i + 3) * 0.6) if i % 2 == 0 else r * 0.55
		pts.append(Vector2.from_angle(ang) * rad)
	draw_colored_polygon(pts, Color(colour, 0.9 * a))
	draw_circle(Vector2.ZERO, r * 0.6, Color(1, 1, 1, a))

## A ring of force running outward.
func _shock(k: float) -> void:
	var e := 1.0 - pow(1.0 - k, 3.0)
	var r := lerpf(10.0, 110.0, e) * size
	var a := (1.0 - k)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1, 1, 1, 0.9 * a), lerpf(14.0, 2.0, k) * size, true)
	draw_arc(Vector2.ZERO, r * 0.86, 0.0, TAU, 48, Color(colour, 0.5 * a), lerpf(8.0, 1.0, k) * size, true)

## Speed lines thrown out from the hit, heavier along `dir`.
func _streaks(k: float) -> void:
	var a := 1.0 - k
	var e := 1.0 - pow(1.0 - k, 2.0)
	for i in 14:
		var ang := TAU * float(i) / 14.0 + (_r(i) - 0.5) * 0.4
		var along := maxf(0.0, cos(ang - dir.angle()))
		var reach := (60.0 + 90.0 * along + 40.0 * _r(i + 20)) * size
		var p0 := Vector2.from_angle(ang) * reach * (0.25 + e * 0.75)
		var p1 := Vector2.from_angle(ang) * reach * (0.55 + e * 0.9)
		draw_line(p0, p1, Color(1, 1, 1, a), (3.0 + 3.0 * along) * size * (1.0 - k * 0.5), true)

## A cloud of grey puffs that swells, rises and thins.
func _smoke(k: float) -> void:
	var a := (1.0 - k) * 0.75
	for i in 7:
		var off := Vector2((_r(i) - 0.5) * 70.0, (_r(i + 7) - 0.5) * 40.0) * size \
			+ dir * float(i) * 9.0 * size
		var r := (16.0 + 18.0 * _r(i + 14)) * size * (0.6 + k * 1.1)
		var shade := lerpf(0.92, 0.72, _r(i + 21))
		draw_circle(off, r + 2.0, Color(0.35, 0.33, 0.33, a * 0.5))
		draw_circle(off, r, Color(shade, shade, shade * 0.98, a))

## An explosion: a fireball that blooms orange to red, then goes to smoke.
func _fireball(k: float) -> void:
	var e := 1.0 - pow(1.0 - k, 2.0)
	for i in 9:
		var ang := TAU * float(i) / 9.0 + _r(i) * 0.6
		var off := Vector2.from_angle(ang) * (18.0 + 40.0 * e) * size * (0.6 + _r(i + 9) * 0.6)
		var r := (26.0 + 16.0 * _r(i + 18)) * size * (1.0 - k * 0.55)
		var hot := Color(1.0, 0.95, 0.6).lerp(Color(1.0, 0.45, 0.12), clampf(k * 2.0, 0.0, 1.0))
		hot = hot.lerp(Color(0.4, 0.36, 0.34), clampf(k * 1.6 - 0.6, 0.0, 1.0))
		draw_circle(off, r, Color(hot, 1.0 - k * 0.8))
	draw_circle(Vector2.ZERO, 30.0 * size * (1.0 - k), Color(1, 1, 0.9, 1.0 - k))

## Comic lettering over the hit, popped in big and settled: BANG!
func _bang(k: float) -> void:
	var font := Art.font(Art.FONT_DISPLAY)
	if font == null:
		return
	var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - k * 6.0)
	var a := 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
	var fs := int(46.0 * size)
	var tilt := (_r(5) - 0.5) * 0.4
	draw_set_transform(Vector2(0, -30.0 * size), tilt, Vector2.ONE * pop)
	# A burst behind the word, as the comics do.
	var pts := PackedVector2Array()
	for i in 24:
		var ang := TAU * float(i) / 24.0
		var rad := (82.0 if i % 2 == 0 else 52.0) * size * (0.9 + 0.2 * _r(i + 40))
		pts.append(Vector2.from_angle(ang) * Vector2(rad * 1.25, rad * 0.8))
	draw_colored_polygon(pts, Color(1.0, 0.86, 0.2, a))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(INK, a), 4.0, true)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(-w * 0.5, fs * 0.36)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(INK, a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.18, 0.12, a))
	draw_set_transform(Vector2.ZERO)

## Something heavy hitting the ground: a flat burst of dust along it.
func _slam(k: float) -> void:
	var a := 1.0 - k
	var e := 1.0 - pow(1.0 - k, 3.0)
	for side: float in [-1.0, 1.0]:
		for i in 5:
			var x := side * (20.0 + 90.0 * e * (0.5 + float(i) * 0.18)) * size
			var r := (14.0 + 6.0 * float(i)) * size * (0.7 + 0.5 * e)
			draw_circle(Vector2(x, -r * 0.4 - float(i) * 4.0 * e), r, Color(0.86, 0.78, 0.64, 0.8 * a))
	draw_line(Vector2(-130.0 * e * size, 0), Vector2(130.0 * e * size, 0), Color(1, 1, 1, 0.8 * a), 5.0 * size)

## Little stars knocked out of something: the cartoon "ow".
func _star_pop(k: float) -> void:
	var a := 1.0 - k
	for i in 5:
		var ang := -PI * 0.5 + (float(i) - 2.0) * 0.55
		var p := Vector2.from_angle(ang) * (30.0 + 70.0 * k) * size + Vector2(0, 120.0 * k * k)
		_star(p, 9.0 * size, Color(1.0, 0.9, 0.3, a))

func _star(at: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 10.0) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, c)
