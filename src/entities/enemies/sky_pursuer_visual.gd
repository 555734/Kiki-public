extends Node2D
## Visual for the 1-2 pursuer. Typed loosely so this newly-added script does not
## depend on Godot's generated global class cache immediately after git pull.

var pursuer: Node = null
## How fast it is going, measured here rather than asked: on the guest's
## device the host moves it and its own chase state never runs.
var _speed: float = 0.0
var _last: Vector2 = Vector2.INF
## Has been seen running: standing still after that is being held back.
var _woke := false

func _process(delta: float) -> void:
	var at := global_position
	if _last != Vector2.INF and delta > 0.0:
		_speed = lerpf(_speed, at.distance_to(_last) / delta, clampf(delta * 10.0, 0.0, 1.0))
	_last = at
	_woke = _woke or _speed > 60.0
	queue_redraw()

func _draw() -> void:
	var p: float = pursuer.phase() if pursuer != null else 0.0
	var is_stunned: bool = pursuer != null and pursuer.stunned()
	var flash: float = pursuer.hit_flash() if pursuer != null else 0.0
	var bob := absf(sin(p)) * 2.2

	draw_set_transform(Vector2(0, 48), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 54.0, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var tint := Color.WHITE
	if is_stunned:
		tint = Color("b8d9e8")
	if flash > 0.0:
		tint = Color.WHITE
		draw_circle(Vector2(18, -22), 62.0, Color(1.0, 0.75, 0.38, 0.13))

	var frame := Art.pursuer_frame(is_stunned, p)
	if Art.late_pack() != "" and Art.draw_sprite_fit(self, frame, Vector2(0, -bob), 130.0, tint):
		return
	if Art.pursuer_faces_left():
		# The hound: asleep until it wakes, then a gallop; barking at a gate
		# dropped in its face, seeing stars when knocked back.
		var hound := "castle_hound_%d" % (int(p * 5.0) % 4)
		if is_stunned:
			hound = "castle_hound_6"
		elif _speed < 15.0:
			hound = "castle_hound_%d" % (4 + int(p * 2.5) % 2) if _woke else "castle_hound_7"
		if Art.draw_sprite(self, hound, Vector2(-6, 50.0), 128.0, true, Color.WHITE if is_stunned else tint):
			return
	if Art.draw_sprite(self, frame, Vector2(0, 58.0 - bob), 154.0, false, tint):
		var glow := 0.55 + 0.45 * sin(p * 1.4)
		draw_circle(Vector2(30, -39 - bob), 5.0 + glow * 2.0,
			Color(1.0, 0.48, 0.14, 0.42 + glow * 0.28))
		return

	draw_colored_polygon(PackedVector2Array([
		Vector2(-66, 44), Vector2(-55, -35), Vector2(-25, -72),
		Vector2(26, -68), Vector2(65, -26), Vector2(58, 29), Vector2(21, 48),
	]), Color("49302f"))
	draw_circle(Vector2(28, -32), 7.0, Color("f28e36"))
	draw_line(Vector2(-48, 20), Vector2(-82, 51), Color("2b2322"), 14.0, true)
	draw_line(Vector2(42, 20), Vector2(82, 49), Color("2b2322"), 14.0, true)
