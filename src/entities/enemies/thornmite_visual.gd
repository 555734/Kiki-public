extends Node2D
## 2.5D presentation for Thornmite: a low rock quadruped with a readable horn.
## The painting is the primary path; the vector fallback keeps it playable when
## textures are disabled or an asset is missing.

var thornmite: Node = null

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if thornmite == null or not is_instance_valid(thornmite):
		return
	var mode: int = thornmite.mode()
	var p: float = thornmite.phase()
	var face_right: bool = thornmite.direction > 0
	var bob := absf(sin(p)) * (1.2 if mode != 2 else 2.5)
	if has_meta("model_3d"):
		if mode == 1:
			draw_arc(Vector2(28.0 if face_right else -28.0, -10.0),
				18.0, 0.0, TAU, 20, Color(1.0, 0.52, 0.20, 0.75), 2.0)
		return

	# Contact shadow gives the side-on sprite a little depth without changing
	# gameplay collision or camera projection.
	draw_set_transform(Vector2(0.0, 27.0), 0.0, Vector2(1.0, 0.27))
	draw_circle(Vector2.ZERO, 42.0, Color(0.0, 0.0, 0.0, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var tint := Color.WHITE
	if mode == 1:
		tint = Color(1.0, 0.90, 0.72)
	elif mode == 2:
		tint = Color(1.0, 0.78, 0.62)

	if Art.draw_sprite(self, "horror_thornmite",
			Vector2(0.0, 28.0 - bob), 92.0, face_right, tint):
		if mode == 1:
			draw_arc(Vector2(-28.0 if not face_right else 28.0, -10.0 - bob),
				18.0, 0.0, TAU, 20, Color(1.0, 0.52, 0.20, 0.55), 2.0)
		return

	var d := 1.0 if face_right else -1.0
	var body := PackedVector2Array([
		Vector2(-34*d, 14), Vector2(-29*d, -15), Vector2(-10*d, -27),
		Vector2(18*d, -24), Vector2(35*d, -8), Vector2(31*d, 15),
	])
	draw_colored_polygon(body, Color("7a3f33"))
	draw_polyline(PackedVector2Array([body[0],body[1],body[2],body[3],body[4],body[5],body[0]]),
		Color("3f2928"), 2.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-25*d,-15), Vector2(-6*d,-34), Vector2(1*d,-12)
	]), Color("d29a70"))
	for x in [-24.0, 23.0]:
		draw_circle(Vector2(x*d, 17), 9.0, Color("3f302e"))
	var eye := Vector2(-20*d, -8)
	draw_circle(eye, 5.5, Color("f2eee6"))
	draw_circle(eye + Vector2(-2*d,0), 2.6, Color("251d1b"))
