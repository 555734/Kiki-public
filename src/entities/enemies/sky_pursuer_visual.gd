extends Node2D
## Visual for the 1-2 pursuer. Typed loosely so this newly-added script does not
## depend on Godot's generated global class cache immediately after git pull.

var pursuer: Node = null

func _process(_delta: float) -> void:
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

	if Art.draw_sprite(self, "horror_pursuer", Vector2(0, 58.0 - bob), 154.0, false, tint):
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
