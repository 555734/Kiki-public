extends Control
## Native guardian buttons, with the cinematic's stage banners hidden.
var hud: Hud
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	if is_instance_valid(hud): ControlPainter.draw_controls(self, hud, size)
