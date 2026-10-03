extends Node2D
## A single cave bank with a local bounding box, so off-screen banks are culled.

var span: Vector2 = Vector2.ZERO
var seed_index: int = 0

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, span)
	var surface := global_position.y <= 1080.0
	# Broad, low-detail stone masses keep enemies and cracks readable.
	draw_rect(rect, Color("645347") if surface else Color("5a4844"))
	for row in 2:
		var y := rect.position.y + 24.0 + float(row) * 85.0
		if y > rect.end.y:
			break
		var x := rect.position.x + float((seed_index + row) % 2) * 65.0
		while x < rect.end.x:
			var width := minf(126.0, rect.end.x - x)
			draw_rect(Rect2(x, y, width - 3.0, 78.0),
				Color("7b6150") if surface else (
					Color("725548") if row == 0 else Color("654e45")))
			x += 130.0
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 24),
		Color("8ca889") if surface else Color("bd8e65"))
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 7),
		Color("bed2ab") if surface else Color("d7ad7d"))
	draw_rect(Rect2(rect.position.x, rect.position.y + 24,
		rect.size.x, 5), Color("4e3e3c"))
