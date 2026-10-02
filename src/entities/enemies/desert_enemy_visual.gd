extends Node2D
## Rounded, flat-shaded cartoon shapes consistent with the coast and marsh.

var enemy: DesertEnemy

const INK := Color("3a2924")
const SAND := Color("ffd66f")
const ROCK := Color("ca813b")
const TEAL := Color("26c8dd")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if enemy == null:
		return
	match enemy.kind:
		"scarab": _scarab()
		"cactus": _cactus()
		"jelly": _jelly()
		"fin": _fin()

func _eyes(left: Vector2, right: Vector2, radius: float = 5.0) -> void:
	for p in [left, right]:
		draw_circle(p, radius + 2.0, Color.WHITE)
		draw_circle(p + Vector2(float(enemy.direction) * 1.3, 0.8), radius * 0.55, INK)

func _scarab() -> void:
	var wobble := sin(enemy.phase * 12.0) * 2.0
	draw_circle(Vector2(0, 2), 28, ROCK)
	draw_circle(Vector2(0, -1 + wobble), 24, SAND)
	draw_arc(Vector2(0, -1 + wobble), 22, 0, TAU, 24, Color("9c5a32"), 3.0)
	for a in [0.3, 2.4, 4.5]:
		var p := Vector2(cos(a + enemy.phase * 3.0), sin(a + enemy.phase * 3.0)) * 17.0
		draw_circle(p, 7, TEAL)
	draw_circle(Vector2(float(enemy.direction) * 17.0, 7), 15, Color("ffe69e"))
	_eyes(Vector2(float(enemy.direction) * 13.0, 4),
		Vector2(float(enemy.direction) * 22.0, 4), 3.7)

func _cactus() -> void:
	var sway := sin(enemy.phase * 5.0) * 3.0
	for side in [-1.0, 1.0]:
		var foot := Vector2(side * 13.0 + sway, 29.0)
		draw_line(Vector2(side * 10.0, 6.0), foot, Color("467d36"), 12.0, true)
		draw_circle(foot, 7, Color("79ad3c"))
	draw_line(Vector2(-13 + sway, -13), Vector2(-28 + sway, 4), Color("4d913c"), 11, true)
	draw_line(Vector2(13 + sway, -13), Vector2(28 + sway, 4), Color("4d913c"), 11, true)
	draw_circle(Vector2(sway, -10), 23, Color("5ca846"))
	draw_circle(Vector2(sway - 5, -16), 16, Color("8bd054"))
	for p in [Vector2(-7, -35), Vector2(18, -24), Vector2(-24, 2)]:
		draw_circle(p + Vector2(sway, 0), 5, Color("f45e47"))
		draw_circle(p + Vector2(sway, 0), 2.5, SAND)
	_eyes(Vector2(-7 + sway, -12), Vector2(7 + sway, -12), 4.0)

func _jelly() -> void:
	for i in 5:
		var x := (float(i) - 2.0) * 10.0
		var swing := sin(enemy.phase * 5.0 + float(i)) * 5.0
		draw_line(Vector2(x, 8), Vector2(x + swing, 31), Color("e9a940"), 5, true)
		draw_circle(Vector2(x + swing, 31), 3, SAND)
	draw_circle(Vector2.ZERO, 27, Color("a5efff", 0.78))
	draw_circle(Vector2(0, 7), 19, Color("f6b848"))
	draw_circle(Vector2(-8, -13), 7, Color(1, 1, 1, 0.55))
	draw_arc(Vector2.ZERO, 27, PI, TAU, 20, Color("49ccec"), 3)
	_eyes(Vector2(-8, 2), Vector2(8, 2), 4.0)

func _fin() -> void:
	var face := float(enemy.direction)
	draw_circle(Vector2(0, 15), 30, Color("f4bd56", 0.8))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-27 * face, 13), Vector2(13 * face, -29),
		Vector2(29 * face, 9), Vector2(20 * face, 20)]), Color("dc8e32"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17 * face, 12), Vector2(12 * face, -20),
		Vector2(23 * face, 10)]), Color("45d1de"))
	draw_circle(Vector2(14 * face, 7), 10, SAND)
	draw_circle(Vector2(17 * face, 6), 4, INK)
