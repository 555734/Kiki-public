extends Control
## Small interactive/readability layer above the painted HUD.
##
## hud_canvas.gd stays the single big painter for the game HUD. This layer only
## owns the controls that need a real Control node: the post-clear button, and
## the menu button (pause / back to home) in the top-left corner.

var hud: Node = null
var _return_button: Button = null
var _menu_button: Button = null
var _menu: PauseMenu = null

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

	# Always on screen during play. Its geometry comes from ControlLayout so
	# InputHub can keep the same touch from also landing in the world.
	_menu_button = Button.new()
	_menu_button.name = "MenuButton"
	_menu_button.tooltip_text = TranslationServer.translate("メニュー")
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.mouse_filter = Control.MOUSE_FILTER_STOP
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.04, 0.09, 0.14, 0.62)
	flat.border_color = Color(0.31, 0.85, 1.0, 0.78)
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(12)
	for state in ["normal", "hover", "pressed", "focus"]:
		_menu_button.add_theme_stylebox_override(state, flat)
	_menu_button.draw.connect(_draw_menu_glyph)
	_menu_button.pressed.connect(open_menu)
	add_child(_menu_button)
	_place_menu_button()

func _process(_delta: float) -> void:
	if not is_instance_valid(hud):
		return
	_return_button.visible = not hud.cleared().is_empty()
	_place_menu_button()
	var main := hud.get_parent()
	var at_home: bool = main != null and bool(main.get("_home_active"))
	_menu_button.visible = not at_home and (_menu == null or not is_instance_valid(_menu))
	queue_redraw()

func _place_menu_button() -> void:
	var r := ControlLayout.menu_rect(size if size.x > 0.0 else get_viewport_rect().size)
	_menu_button.position = r.position
	_menu_button.size = r.size

## Three bars: the menu glyph every platform uses. Drawn rather than typed,
## because the game font has no ≡.
func _draw_menu_glyph() -> void:
	var s := _menu_button.size
	var w := s.x * 0.50
	var x := (s.x - w) * 0.5
	for i in 3:
		var y := s.y * (0.32 + 0.18 * float(i))
		_menu_button.draw_line(Vector2(x, y), Vector2(x + w, y), Color(1, 1, 1, 0.92), 3.5, true)

func open_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		return
	if not is_instance_valid(hud):
		return
	var main := hud.get_parent()
	if main == null or bool(main.get("_home_active")):
		return
	# Hidden here, not in _process: offline the menu stops the world, and this
	# layer with it, so _process would not run again until the menu is closed.
	_menu_button.visible = false
	_menu = PauseMenu.new()
	_menu.name = "PauseMenu"
	_menu.main = main
	main.add_child(_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE and _menu_button.visible:
		get_viewport().set_input_as_handled()
		open_menu()

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
