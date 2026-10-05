extends Node2D
## Royal PNGs are painted over the same rectangles used by host and clients.
var slabs: Array[Rect2] = []
var items: Array[Dictionary] = []
func _draw() -> void:
	for rect in slabs:
		var key := "royal_floating_platform_small"
		if rect.size.y > 46.0:
			key = "royal_main_platform" if rect.size.x >= 350.0 else "royal_side_platform_left"
		elif rect.size.x >= 200.0:
			key = "royal_floating_platform_large_left"
		var texture := Art.tex(key)
		if texture == null: continue
		var height := clampf(rect.size.x * float(texture.get_height()) / float(texture.get_width()),
			50.0, 175.0)
		draw_texture_rect(texture, Rect2(rect.position, Vector2(rect.size.x, height)), false)
		# The narrow gold lip is the exact collision top, including tiny gaps
		# between bevels in the supplied painting.
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("fff1af"), 2.0)
	for item in items:
		Art.draw_sprite(self, item["type"], item["pos"], float(item.get("height", 100.0)),
			bool(item.get("flip", false)), Color(0.9, 0.9, 0.95, 0.82))
