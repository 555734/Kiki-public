extends Control
## Small interactive/readability layer above the painted HUD.
##
## hud_canvas.gd stays the single big painter for the game HUD. This layer only
## owns the two things that need either a real Control node (the post-clear
## button) or a deliberately stronger readout (the support gauge).

var hud: Node = null
var _return_button: Button = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_return_button = Button.new()
	_return_button.name = "ReturnToStart"
	_return_button.text = "スタート画面へ戻る"
	_return_button.set_anchors_preset(Control.PRESET_CENTER)
	_return_button.offset_left = -140.0
	_return_button.offset_top = 88.0
	_return_button.offset_right = 140.0
	_return_button.offset_bottom = 136.0
	_return_button.add_theme_font_size_override("font_size", 18)
	_return_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_return_button.visible = false
	_return_button.pressed.connect(_return_to_start)
	add_child(_return_button)

func _process(_delta: float) -> void:
	if not is_instance_valid(hud):
		return
	_return_button.visible = not hud.cleared().is_empty()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(hud):
		return
	if not hud.cleared().is_empty():
		# Cover the old keyboard-only hint. The real button above is usable on
		# touch, mouse and controller-emulated pointer input.
		pass

## Ten blocks plus an explicit number. The previous 12px continuous line made
## 35 and 55 gauge look almost identical on a phone; this makes both the amount
## and the rough number of remaining actions readable without measuring pixels.
func _draw_readable_gauge() -> void:
	var level: float = clampf(float(hud.gauge()), 0.0, Balance.GAUGE_MAX)
	var frac := level / maxf(Balance.GAUGE_MAX, 0.001)
	# Same P2 panel as hud_canvas.gd: origin (30, 76), lower-right readout area.
	var box := Rect2(92.0, 103.0, 212.0, 24.0)
	DrawUtil.rounded_rect(self, box, 7.0, Color(0.025, 0.065, 0.11, 0.98))
	draw_rect(box, Color(0.31, 0.85, 1.0, 0.72), false, 1.5)

	var inside := Rect2(box.position + Vector2(4.0, 4.0), box.size - Vector2(8.0, 8.0))
	var gap := 2.0
	var seg_w := (inside.size.x - gap * 9.0) / 10.0
	var lit := frac * 10.0
	var active_col := Balance.C_ACCENT if frac > 0.30 else Color("ff9b4a")
	for i in 10:
		var r := Rect2(inside.position.x + float(i) * (seg_w + gap), inside.position.y,
			seg_w, inside.size.y)
		var amount := clampf(lit - float(i), 0.0, 1.0)
		draw_rect(r, Color(0.11, 0.18, 0.25, 0.95))
		if amount > 0.0:
			draw_rect(Rect2(r.position, Vector2(r.size.x * amount, r.size.y)), active_col)

	# A dark strip behind the number keeps it legible over both filled and empty blocks.
	var number_box := Rect2(box.position.x + 63.0, box.position.y + 3.0, 86.0, 18.0)
	DrawUtil.rounded_rect(self, number_box, 6.0, Color(0.02, 0.04, 0.07, 0.82))
	var text := "%d / %d" % [int(round(level)), int(round(Balance.GAUGE_MAX))]
	draw_string(Art.font(), number_box.position + Vector2(0.0, 14.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, number_box.size.x, 13, Color(1, 1, 1, 0.98))

func _return_to_start() -> void:
	if not is_instance_valid(hud):
		return
	var main := hud.get_parent()
	# Explicitly close a live relay/session before reloading the scene. Reloading
	# itself gives us the exact same start state as a fresh app launch.
	if main != null and main.has_method("_end_any_session"):
		main.call("_end_any_session")
	get_tree().reload_current_scene()
