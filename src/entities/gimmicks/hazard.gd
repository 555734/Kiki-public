class_name Hazard
extends Area2D
## Spikes and the invisible plane under the level. Both kill outright: chapter 3
## wants the runner's mistakes to resolve instantly and the retry to be near
## zero, not to whittle away hit points.

const LAYER_HAZARD := 32

@export var span: Vector2 = Vector2(200, 40)
@export var draw_spikes: bool = true

func _ready() -> void:
	add_to_group("instant_death")
	collision_layer = LAYER_HAZARD
	collision_mask = 0
	z_index = 3
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = span
	shape.shape = rect
	add_child(shape)

func _draw() -> void:
	if not draw_spikes:
		return
	var strip := Art.tex("spikes")
	if Balance.USE_TEXTURES and strip != null:
		# Repeat the painted spike plate across the strip, stretched to a whole
		# number of copies so nothing is drawn outside the collider. Drawing at
		# the art's natural width instead overhung the ends of a short hazard by
		# 30px each side, which is spikes the runner can see but not be killed
		# by -- the same false-affordance problem the decor comment warns about,
		# pointed the other way.
		var natural := span.y * (float(strip.get_width()) / maxf(float(strip.get_height()), 1.0))
		var n := maxi(1, int(round(span.x / maxf(natural, 1.0))))
		var step := span.x / float(n)
		for i in range(n):
			Art.draw_stretched(self, "spikes",
				Rect2(-span.x * 0.5 + step * float(i), -span.y * 0.5, step, span.y))
		return
	# The grey spike row from the mockups: a plated base with triangular teeth.
	var w := span.x
	var h := span.y
	var base_y := h * 0.5
	DrawUtil.rounded_rect(self, Rect2(-w * 0.5, base_y - 9.0, w, 9.0), 2.0, Balance.C_SPIKE_DARK)
	var tooth := 26.0
	var count := maxi(1, int(round(w / tooth)))
	var step := w / float(count)
	for i in range(count):
		var x := -w * 0.5 + float(i) * step
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, base_y - 8.0),
			Vector2(x + step, base_y - 8.0),
			Vector2(x + step * 0.5, base_y - 8.0 - h * 0.66),
		]), Balance.C_SPIKE)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + step * 0.5, base_y - 8.0),
			Vector2(x + step, base_y - 8.0),
			Vector2(x + step * 0.5, base_y - 8.0 - h * 0.66),
		]), Balance.C_SPIKE_DARK)
