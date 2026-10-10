extends Node2D
## Tumbled painted masks and brass confetti are feedback for real enemy kills.
## The cap bounds the cost even when a hammer catches thirty actors at once.
var pieces: Array[Dictionary] = []

func _ready() -> void:
	z_index = 12
	Events.enemy_killed.connect(_killed)

func _killed(enemy: Node2D, _by: String) -> void:
	if not enemy is ParadeGremlin or pieces.size() >= 40: return
	var id: int = (enemy as ParadeGremlin).net_id
	pieces.append({"at": enemy.global_position, "born": Clock.tick, "id": id,
		"velocity": Vector2((DrawUtil.hash01(id * 7) - 0.5) * 900,
			-360 - DrawUtil.hash01(id * 13) * 460)})

func _process(_delta: float) -> void:
	var had_pieces := not pieces.is_empty()
	for i in range(pieces.size() - 1, -1, -1):
		if Clock.tick - int(pieces[i].born) > 100: pieces.remove_at(i)
	if had_pieces: queue_redraw()

func _draw() -> void:
	for piece in pieces:
		var t := (Clock.tick - int(piece.born)) / 60.0
		var at: Vector2 = piece.at + piece.velocity * t + Vector2(0, 650 * t * t)
		var fade := clampf((1.6 - t) * 2, 0, 1)
		draw_set_transform(at, t * (6 if int(piece.id) % 2 == 0 else -6), Vector2.ONE * 0.8)
		draw_texture_rect_region(ParadeArt.painting("gremlin"), Rect2(-28, -35, 56, 70),
			Rect2(543 * (int(piece.id) % 4), 60, 543, 600), Color(1, 1, 1, fade))
		for i in 3:
			draw_rect(Rect2(Vector2(i * 13 - 20, -48 - i * 11), Vector2(5, 9)),
				Color(1, 0.78, 0.3, fade))
	draw_set_transform(Vector2.ZERO)
