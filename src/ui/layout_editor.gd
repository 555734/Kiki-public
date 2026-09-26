class_name LayoutEditor
extends CanvasLayer
## Move the controls to wherever your thumbs actually are.
##
## Hands differ, phones differ, and people hold them differently. A default
## layout is a guess; this is the answer to the guess being wrong. Drag any
## control, let go, and that is where it lives -- for this device, for this
## mode, permanently.
##
## It edits one MODE at a time, because the three are genuinely different
## screens: two people sharing a tablet do not get the same layout as one person
## holding a phone. The three tabs at the top pick which.

var _canvas: Control = null
var _mode := "guardian"
var _status: Label = null
var _tabs: Array[Button] = []
var _size: HSlider = null
var _size_label: Label = null
var _auto_dash: CheckButton = null
var _touch_options: Array[CheckButton] = []
var _movement_help: Label = null
## The control the size slider is pointed at. Whatever was touched last.
var _selected := ""

func _ready() -> void:
	layer = 25
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.05, 0.09, 0.88)
	root.add_child(dim)

	_canvas = preload("res://src/ui/layout_editor_canvas.gd").new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.editor = self
	root.add_child(_canvas)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.position = Vector2(14, 12)
	root.add_child(top)
	for pair in [["guardian", "ガーディアン"], ["runner", "ランナー"], ["shared", "1台で2人"]]:
		var b := _button(String(pair[1]), func() -> void: _choose(String(pair[0])))
		b.custom_minimum_size = Vector2(160, 44)
		top.add_child(b)
		_tabs.append(b)

	# Along the TOP, not the bottom. The controls being arranged live in the
	# bottom corners -- that is the whole point of them -- so a toolbar down
	# there sits underneath the things it is meant to help you move.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	actions.position = Vector2(-14, 12)
	root.add_child(actions)
	actions.add_child(_button("この配置をリセット", _reset))
	actions.add_child(_button("保存して閉じる", _close))

	# Size lives on a slider rather than on a pinch: a pinch is two fingers on a
	# control that is smaller than two fingers, and there is no way to show that
	# it is available. Touch the control, then drag the slider.
	var sizer := HBoxContainer.new()
	sizer.add_theme_constant_override("separation", 10)
	sizer.position = Vector2(14, 96)
	sizer.custom_minimum_size = Vector2(520, 40)
	root.add_child(sizer)
	_size_label = Label.new()
	_size_label.custom_minimum_size = Vector2(210, 0)
	_size_label.add_theme_font_size_override("font_size", 15)
	var sf := Art.font()
	if sf != null:
		_size_label.add_theme_font_override("font", sf)
	sizer.add_child(_size_label)
	_size = HSlider.new()
	_size.custom_minimum_size = Vector2(300, 40)
	_size.min_value = ControlLayout.SIZE_MIN
	_size.max_value = ControlLayout.SIZE_MAX
	_size.step = 0.05
	_size.value = 1.0
	_size.value_changed.connect(_resize)
	sizer.add_child(_size)

	_auto_dash = CheckButton.new()
	_auto_dash.text = "自動ダッシュ（移動とジャンプを2本指で操作）"
	_auto_dash.position = Vector2(14, 146)
	_auto_dash.custom_minimum_size = Vector2(440, 44)
	_auto_dash.add_theme_font_size_override("font_size", 16)
	if sf != null:
		_auto_dash.add_theme_font_override("font", sf)
	_auto_dash.set_pressed_no_signal(Options.auto_dash())
	_auto_dash.toggled.connect(Options.set_auto_dash)
	root.add_child(_auto_dash)
	# Upward stick travel is not a jump source anymore.  Keep only the touch
	# sensitivity choice; jump itself is always the dedicated JUMP button.
	for item in [["短い指の移動で走る", Options.responsive_touch(), Options.set_responsive_touch]]:
		var toggle := CheckButton.new()
		toggle.text = String(item[0])
		toggle.position = Vector2(14, 192 + _touch_options.size() * 42)
		toggle.custom_minimum_size = Vector2(440, 40)
		toggle.add_theme_font_size_override("font_size", 16)
		if sf != null:
			toggle.add_theme_font_override("font", sf)
		toggle.set_pressed_no_signal(bool(item[1]))
		toggle.toggled.connect(item[2])
		root.add_child(toggle)
		_touch_options.append(toggle)
	_movement_help = Label.new()
	_movement_help.text = "スティック下：しゃがむ・滑る　／　空中で下：ヒップドロップ\nジャンプ長押し：高く跳ぶ　／　壁に向かってジャンプ：壁キック"
	_movement_help.position = Vector2(14, 238)
	_movement_help.add_theme_font_size_override("font_size", 15)
	if sf != null:
		_movement_help.add_theme_font_override("font", sf)
	_movement_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_movement_help)

	_status = Label.new()
	_status.position = Vector2(14, 62)
	_status.add_theme_font_size_override("font_size", 15)
	var f := Art.font()
	if f != null:
		_status.add_theme_font_override("font", f)
	root.add_child(_status)
	_choose(_mode)

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = tr(text)
	b.custom_minimum_size = Vector2(190, 48)
	b.add_theme_font_size_override("font_size", 16)
	var f := Art.font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.pressed.connect(handler)
	return b

func mode() -> String:
	return _mode

func _choose(to: String) -> void:
	_mode = to
	_selected = ""
	for i in _tabs.size():
		var names := ["guardian", "runner", "shared"]
		_tabs[i].disabled = names[i] == to
	_refresh()
	_canvas.queue_redraw()

func _refresh() -> void:
	if _auto_dash != null:
		_auto_dash.visible = _mode != "guardian" and not Options.touch_device()
	for toggle in _touch_options:
		toggle.visible = _mode != "guardian"
	if _movement_help != null:
		_movement_help.visible = _mode != "guardian"
	var custom := tr("（自分で変えた配置です）") if ControlLayout.has_custom(_mode) \
		else tr("（はじめの配置です）")
	_status.text = tr("ボタンを指でドラッグすると動きます。%s") % custom
	if _size_label != null:
		_size_label.text = tr("大きさ：%s") % (tr(ControlLayout.label(_selected))
			if _selected != "" else tr("（ボタンを選んでください）"))
	if _size != null:
		_size.editable = _selected != ""

## The canvas tells us which control a finger is on, so the slider follows the
## hand instead of needing a separate "select" step.
func select(id: String) -> void:
	_selected = id
	if _size != null:
		_size.set_value_no_signal(ControlLayout.size_of(_mode, id))
	_refresh()

func _resize(value: float) -> void:
	if _selected == "":
		return
	ControlLayout.set_size(_mode, _selected, value)
	_refresh()
	_canvas.queue_redraw()

func selected() -> String:
	return _selected

func moved() -> void:
	_refresh()

func _reset() -> void:
	ControlLayout.reset(_mode)
	ControlLayout.save()
	_refresh()
	_canvas.queue_redraw()

func _close() -> void:
	ControlLayout.save()
	queue_free()
