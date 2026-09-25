extends Control
## Small interactive/readability layer above the painted HUD.
##
## hud_canvas.gd stays the single big painter for the game HUD. This layer only
## owns the post-clear button, which needs a real Control node.

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

func _return_to_start() -> void:
	if not is_instance_valid(hud):
		return
	var main := hud.get_parent()
	# Explicitly close a live relay/session before reloading the scene. Reloading
	# itself gives us the exact same start state as a fresh app launch.
	if main != null and main.has_method("_end_any_session"):
		main.call("_end_any_session")
	get_tree().reload_current_scene()
