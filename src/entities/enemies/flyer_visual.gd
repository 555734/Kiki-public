extends Node2D
## Same family as the walker -- so the runner reads it as "one of those" -- but
## winged, and out of stomping reach. Wings beat on the enemy's own phase so a
## row of them does not flap in lockstep.

var flyer: Flyer = null

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if flyer == null:
		return
	if Balance.USE_TEXTURES:
		# The wing beat is a vertical scale on the painted sprite: the wings are
		# the widest part, so squeezing the sprite reads as a flap.
		var beat := sin(flyer.phase() * 3.4)
		draw_set_transform(Vector2(0.0, Balance.FLYER_SIZE.y * 0.5 + beat * 2.0), 0.0,
			Vector2(1.0, 1.0 - absf(beat) * 0.12))
		if Art.draw_sprite(self, "flyer", Vector2.ZERO, Balance.FLYER_SPRITE_H,
				flyer.direction > 0):
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var face := float(flyer.direction)
	var beat := sin(flyer.phase() * 3.4)
	var s := Balance.FLYER_SIZE

	# Wings, drawn behind the body but well clear of it -- at the first pass
	# they only reached the body's own silhouette and the thing read as a brown
	# box with eyes. The runner has to recognise this as airborne instantly,
	# because it is the one enemy they cannot stomp.
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var tip := Vector2(side * (32.0 + beat * 5.0), -16.0 - beat * 11.0)
		var trail := Vector2(side * 24.0, 8.0 + beat * 3.0)
		var wing := PackedVector2Array([
			Vector2(side * 6.0, -6.0), tip,
			Vector2(side * 30.0, -2.0 - beat * 3.0), trail, Vector2(side * 10.0, 3.0),
		])
		draw_colored_polygon(wing, Color(0.97, 0.97, 1.0, 0.96))
		var outline := PackedVector2Array(wing)
		outline.append(wing[0])
		draw_polyline(outline, Color(0.70, 0.77, 0.88), 1.8)
		# Feather split
		draw_line(Vector2(side * 8.0, -3.0), Vector2(side * 27.0, -1.0 - beat * 2.0),
			Color(0.78, 0.84, 0.92), 1.4)

	# Body
	DrawUtil.rounded_rect(self, Rect2(-s.x * 0.34, -s.y * 0.42, s.x * 0.68, s.y * 0.84), 9.0,
		Balance.C_ENEMY_BODY)
	DrawUtil.rounded_rect(self, Rect2(-s.x * 0.30, s.y * 0.10, s.x * 0.60, s.y * 0.26), 5.0,
		Balance.C_ENEMY_DARK)

	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var eye := Vector2(side * 5.0, -3.0)
		draw_circle(eye, 4.6, Color.WHITE)
		draw_circle(eye + Vector2(face * 1.3, 0.4), 2.3, Color("241a12"))
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(side * 1.4, -8.5), Vector2(side * 10.0, -5.6), Vector2(side * 10.0, -9.2),
		]), Balance.C_ENEMY_DARK)
