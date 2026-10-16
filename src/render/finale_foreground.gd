extends Node2D
## 1-10's nearest layer: dark, out-of-focus silhouettes (grass, rocks, ribs,
## comb) that slide along the bottom edge of the screen faster than the world
## (parallax 1.45), only where the camera is looking at ground. It gives the
## flat side view a foreground plane -- foreground, play, middle distance,
## backdrop -- without ever reaching the runner's height on screen.
##
## Lives on its own CanvasLayer above the world. Draws screen space from the
## camera; nothing here collides or is part of the simulation.

const RATE := 1.45
const SPACING := 760.0

var camera: Camera2D

func _process(_delta: float) -> void:
	queue_redraw()

func _ground_below(world: Vector2) -> bool:
	for r in FinaleGround._all_ground():
		if r.has_point(world) or r.has_point(world + Vector2(0, -60)):
			return true
	return false

func _draw() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var view := get_viewport_rect().size
	var z := camera.zoom.x
	var cam := camera.get_screen_center_position()
	# Only over ground: the bottom of the screen must be inside terrain.
	var bottom := cam + Vector2(0, view.y * 0.5 / z - 10.0)
	if not _ground_below(bottom):
		return
	var zone: Dictionary = Stage.data().zone_at(cam.x)
	var skin := String(zone["skin"])
	var shift := cam.x * RATE * z
	var first := floori((shift - view.x) / SPACING)
	for i in range(first, first + int(view.x * 3.0 / SPACING) + 3):
		var x := float(i) * SPACING - shift + view.x * 0.5 + (FinaleGround.h(i * 31) - 0.5) * 260.0
		if x < -400.0 or x > view.x + 400.0:
			continue
		if FinaleGround.h(i * 17 + 3) < 0.3:
			continue
		var h := view.y * (0.16 + 0.08 * FinaleGround.h(i * 7))
		var tint := Color(0.06, 0.07, 0.10, 0.92)
		match skin:
			"grass", "cliff":
				FinaleArt.sprite(self, "bush" if i % 2 == 0 else "tuft", Vector2(x, view.y + h * 0.12), h, i % 3 == 0, Color(0.08, 0.16, 0.10, 0.94))
			"sand":
				FinaleArt.sprite(self, "rocks", Vector2(x, view.y + h * 0.1), h * 0.7, i % 2 == 0, Color(0.20, 0.10, 0.05, 0.94))
			"lava", "storm":
				var c := Color(0.05, 0.02, 0.04, 0.95) if skin == "lava" else tint
				var w := h * 1.3
				draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.5, view.y + 4), Vector2(x - w * 0.2, view.y - h * 0.8),
					Vector2(x, view.y - h * 0.55), Vector2(x + w * 0.15, view.y - h), Vector2(x + w * 0.5, view.y + 4)]), c)
			"bone":
				FinaleGround.bone_on(self, [Vector2(x - h * 0.6, view.y + 10), Vector2(x, view.y - h * 0.7), Vector2(x + h * 0.4, view.y - h * 0.9)],
					h * 0.18, i)
				draw_polyline(PackedVector2Array([Vector2(x - h * 0.6, view.y + 10), Vector2(x, view.y - h * 0.7), Vector2(x + h * 0.4, view.y - h * 0.9)]),
					Color(0.22, 0.10, 0.04, 0.6), h * 0.18 + 14.0, true)
			"hive":
				for k in 3:
					FinaleGround.honey_drip(self, Vector2(x + float(k) * 40.0 - 40.0, view.y - h * (0.5 + 0.2 * float(k))), h * 0.6, 14.0)

