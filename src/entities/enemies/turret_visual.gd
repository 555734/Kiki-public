extends Node2D
## A fixed gun emplacement. The muzzle brightens as the next shot charges --
## that glow is the guardian's cue to raise a wall, so it is the most important
## piece of readability on the enemy side.

var turret: Turret = null

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if turret == null:
		return
	var dir: Vector2 = turret.aim_direction.normalized()
	if Balance.USE_TEXTURES and _draw_painted(dir):
		return
	var s := Balance.TURRET_SIZE
	var recoil := turret.recoil()
	var charge := turret.charge()

	# Base
	DrawUtil.rounded_rect(self, Rect2(-s.x * 0.5, -s.y * 0.5, s.x, s.y), 10.0, Color("39414d"))
	DrawUtil.rounded_rect(self, Rect2(-s.x * 0.5 + 4.0, -s.y * 0.5 + 4.0, s.x - 8.0, s.y * 0.42), 7.0,
		Color("4b5563"))
	# Bolts
	for i in range(4):
		var x := -s.x * 0.32 + float(i % 2) * s.x * 0.64
		var y := -s.y * 0.32 + float(i / 2) * s.y * 0.64
		draw_circle(Vector2(x, y), 2.6, Color("2a313b"))

	# Barrel, pushed back by recoil.
	var back := dir * (-4.0 * recoil)
	var muzzle := dir * (s.x * 0.5 + 16.0) + back
	var perp := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		back + perp * 9.0, back - perp * 9.0,
		muzzle - perp * 7.5, muzzle + perp * 7.5,
	]), Color("2f3742"))
	draw_circle(muzzle, 8.0, Color("222932"))

	# Charge glow: dim while reloading, hot just before the shot.
	var hot := pow(charge, 3.0)
	if hot > 0.02:
		draw_circle(muzzle, 5.0 + hot * 5.0, Color(1.0, 0.55, 0.15, 0.25 + hot * 0.5))
		draw_circle(muzzle, 2.5 + hot * 3.0, Color(1.0, 0.85, 0.45, 0.4 + hot * 0.6))

	# Damage read-out: chips appear as it loses HP, so the guardian knows whether
	# one more shot will finish it.
	var lost: int = Balance.TURRET_HP - turret.hp
	for i in range(lost):
		var a := float(i) * 2.2
		draw_circle(Vector2(cos(a) * s.x * 0.28, sin(a) * s.y * 0.28), 4.0, Color("1d232b"))

## The painted turret. The artwork points right, so the sprite is rotated to the
## emplacement's aim direction and the charge glow is layered on top -- that
## glow is the guardian's cue to raise a wall, so it stays procedural and bright.
func _draw_painted(dir: Vector2) -> bool:
	var recoil := turret.recoil()
	var charge := turret.charge()
	var angle := dir.angle()
	# Keep the base upright: only flip for left-facing, rotate for up/down.
	var flip := absf(angle) > PI * 0.5
	var rot := 0.0
	if absf(dir.y) > 0.7:
		rot = PI * 0.5 * signf(dir.y)
		flip = false
	draw_set_transform(-dir * 4.0 * recoil, rot, Vector2.ONE)
	var ok := Art.draw_sprite(self, "turret", Vector2(0.0, Balance.TURRET_SIZE.y * 0.5),
		Balance.TURRET_SPRITE_H, flip)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not ok:
		return false
	var muzzle := dir * (Balance.TURRET_SIZE.x * 0.5 + 18.0) - dir * 4.0 * recoil
	var hot := pow(charge, 3.0)
	if hot > 0.02:
		draw_circle(muzzle, 6.0 + hot * 7.0, Color(1.0, 0.55, 0.15, 0.28 + hot * 0.5))
		draw_circle(muzzle, 3.0 + hot * 4.0, Color(1.0, 0.88, 0.5, 0.45 + hot * 0.55))
	var lost: int = Balance.TURRET_HP - turret.hp
	for i in range(lost):
		var a := float(i) * 2.2
		draw_circle(Vector2(cos(a) * 14.0, sin(a) * 14.0), 4.5, Color(0.10, 0.12, 0.15, 0.75))
	return true
