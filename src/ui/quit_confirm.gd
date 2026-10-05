class_name QuitConfirm
extends CanvasLayer
## The way out of a game screen: a やめる button top left and the question
## behind it -- "really quit?" with a box to stop asking. Ticked and confirmed
## once, later presses quit straight away (UiPrefs).
##
## Real Controls over the play field, so the screen's InputHub must leave
## presses here to the GUI: hand it claims() as its gui_passthrough. While the
## question is up every press is the question's.

## What quitting does. Called once, after the answer (or straight away).
var on_quit: Callable = Callable()
## The line under the question: what happens to the run, or the room.
var detail: String = ""
## Freeze the game while asking. Only a game nobody else is playing in.
var pause_while_asking: bool = false
## False when the screen has its own button and only wants the question
## (the star battle's menu); request() still asks.
var with_button: bool = true
## Asked every frame whether the button belongs on screen now (not under a
## menu or a result panel). Unset: always.
var shown_when: Callable = Callable()
## Fingers to let go of when the question opens, so a held stick does not
## keep walking behind it.
var input_hub: InputHub = null

var _button: Button = null
var _popup: Control = null
var _panel: PanelContainer = null
var _check: Button = null
var _paused_by_us: bool = false

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button = Button.new()
	_button.name = "QuitButton"
	_button.text = tr("やめる", "quit")
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_size_override("font_size", 20)
	_button.size = Vector2(130, 44)
	_button.pressed.connect(request)
	_button.visible = with_button
	add_child(_button)
	_build_popup()
	_place()
	get_viewport().size_changed.connect(_place)

func _build_popup() -> void:
	_popup = Control.new()
	_popup.name = "QuitQuestion"
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.visible = false
	add_child(_popup)
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.05, 0.10, 0.62)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.add_child(scrim)
	_panel = PanelContainer.new()
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.06, 0.12, 0.21, 0.97)
	plate.border_color = Color(0.31, 0.85, 1.0, 0.55)
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(18)
	plate.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", plate)
	_popup.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	var title := Label.new()
	title.name = "Question"
	title.text = tr("ゲームをやめますか？")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var line := Label.new()
	line.name = "Detail"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(380, 0)
	line.add_theme_font_size_override("font_size", 17)
	box.add_child(line)
	# A toggle with its own square: the theme's checkbox icon was a few
	# pixels on a phone, under a stray hover plate.
	_check = Button.new()
	_check.name = "DontAsk"
	_check.toggle_mode = true
	_check.focus_mode = Control.FOCUS_NONE
	_check.flat = true
	_check.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_check.custom_minimum_size = Vector2(0, 48)
	_check.add_theme_font_size_override("font_size", 19)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_check.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for colour in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_check.add_theme_color_override(colour, Color(0.88, 0.94, 1.0))
	_check.toggled.connect(func(_on: bool) -> void: _check.queue_redraw())
	_check.draw.connect(_draw_tick)
	_check.text = "        " + tr("次回から確認しない")
	box.add_child(_check)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var stay := _answer(tr("続ける"), cancel)
	stay.name = "Stay"
	row.add_child(stay)
	var leave := _answer(tr("やめる", "quit"), confirm)
	leave.name = "Leave"
	row.add_child(leave)

func _draw_tick() -> void:
	var r := Rect2(Vector2(4, (_check.size.y - 28.0) * 0.5), Vector2(28, 28))
	_check.draw_rect(r, Color(0.02, 0.06, 0.12, 0.9))
	_check.draw_rect(r, Color(0.31, 0.85, 1.0), false, 2.5)
	if _check.button_pressed:
		_check.draw_polyline(PackedVector2Array([
			r.position + Vector2(6, 14), r.position + Vector2(12, 21),
			r.position + Vector2(23, 7)]), Color(0.31, 0.85, 1.0), 4.0)

func _answer(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 54)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(handler)
	return b

## Top left, inside the notch-safe area, clear of the stick (bottom left) and
## the stage plate (top right).
func _place() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := ControlLayout._ios_safe_rect(view) if OS.has_feature("ios") \
		else Rect2(Vector2.ZERO, view)
	_button.position = safe.position + Vector2(16, 12)
	_panel.reset_size()
	_panel.position = (view - _panel.get_combined_minimum_size()) * 0.5

func _process(_delta: float) -> void:
	if shown_when.is_valid():
		set_button_visible(bool(shown_when.call()))

## The button was pressed (or the screen's own one was).
func request() -> void:
	if asking():
		return
	if UiPrefs.skip_quit_confirm():
		_quit()
		return
	var line := _panel.find_child("Detail", true, false) as Label
	line.text = detail
	line.visible = not detail.is_empty()
	_check.button_pressed = false
	_popup.visible = true
	_place()
	if input_hub != null and is_instance_valid(input_hub):
		input_hub.release_everything()
	if pause_while_asking and not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true

func confirm() -> void:
	if _check.button_pressed:
		UiPrefs.set_skip_quit_confirm(true)
	_close()
	_quit()

func cancel() -> void:
	_close()

func asking() -> bool:
	return _popup != null and _popup.visible

func _close() -> void:
	_popup.visible = false
	if _paused_by_us:
		_paused_by_us = false
		get_tree().paused = false

func _quit() -> void:
	if on_quit.is_valid():
		on_quit.call()

## Show or hide the button itself (a menu or a result panel is up).
func set_button_visible(value: bool) -> void:
	if _button != null:
		_button.visible = value and with_button

## For the screen's InputHub: is this press ours?
func claims(at: Vector2) -> bool:
	if asking():
		return true
	return _button != null and _button.is_visible_in_tree() \
		and _button.get_global_rect().has_point(at)

func _exit_tree() -> void:
	if _paused_by_us and is_inside_tree():
		get_tree().paused = false
