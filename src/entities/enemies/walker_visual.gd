extends Node2D
## The scowling mushroom from the mockups: rounded brown cap, heavy brow,
## two stubby feet that alternate as it walks.

var walker: Walker = null

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if walker == null:
		return
	if Balance.USE_TEXTURES:
		var bob := absf(sin(walker.walk_phase())) * 2.0
		var squash := 1.0 + sin(walker.walk_phase() * 2.0) * 0.05
		draw_set_transform(Vector2(0, Balance.WALKER_SIZE.y * 0.5 + 2.0), 0.0, Vector2(1.0, 0.30))
		draw_circle(Vector2.ZERO, 20.0, Color(0.10, 0.08, 0.06, 0.30))
		draw_set_transform(Vector2(0.0, Balance.WALKER_SIZE.y * 0.5 - bob), 0.0,
			Vector2(1.0 / squash, squash))
		if Art.draw_sprite(self, "walker", Vector2.ZERO, Balance.WALKER_SPRITE_H,
				walker.direction > 0):
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var s := Balance.WALKER_SIZE
	var phase := walker.walk_phase()
	var face := float(walker.direction)
	var squash := 1.0 + sin(phase) * 0.04
	var h := s.y * 0.5

	# Feet, alternating.
	var foot := Balance.C_ENEMY_DARK
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var lift := maxf(0.0, sin(phase + (0.0 if i == 0 else PI))) * 3.0
		DrawUtil.rounded_rect(self,
			Rect2(side * 4.0 - 9.0 * (0.5 + 0.5), h - 9.0 - lift, 13.0, 9.0), 4.0, foot)

	# Cap: a wide dome with a slightly darker underside.
	var body_w := s.x * 0.5 * squash
	var body_h := h - 4.0
	var dome := PackedVector2Array()
	for i in range(21):
		var a := PI + PI * float(i) / 20.0
		dome.append(Vector2(cos(a) * body_w, sin(a) * body_h * 0.95 + 2.0))
	dome.append(Vector2(body_w * 0.86, body_h - 2.0))
	dome.append(Vector2(-body_w * 0.86, body_h - 2.0))
	draw_colored_polygon(dome, Balance.C_ENEMY_BODY)

	# Underside shadow
	DrawUtil.rounded_rect(self, Rect2(-body_w * 0.84, body_h - 8.0, body_w * 1.68, 7.0), 3.0,
		Balance.C_ENEMY_DARK)

	# Eyes
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var eye := Vector2(side * 8.0, -2.0)
		draw_circle(eye, 6.2, Color.WHITE)
		draw_circle(eye + Vector2(face * 1.6, 0.6), 3.0, Color("241a12"))
	# Angry brows, the detail that makes it read as hostile at thumbnail size.
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(side * 2.0, -9.0), Vector2(side * 15.0, -5.5), Vector2(side * 15.0, -9.5),
		]), Balance.C_ENEMY_DARK)
	# Fangs
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0, 7.0), Vector2(-0.5, 7.0), Vector2(-2.2, 11.0),
	]), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.5, 7.0), Vector2(4.0, 7.0), Vector2(2.2, 11.0),
	]), Color.WHITE)
