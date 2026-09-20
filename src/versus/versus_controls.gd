extends Control
## Screen-space controls for the coin match. The ordinary Runner InputHub owns
## movement/jump/sprint touches; only attack/build touches are intercepted here.
## A finger's ownership never moves to a different button while dragging.
var arena = null
var duel: bool = false
var palette_open: bool = false
var selected_slot: int = 1
var _owners: Dictionary = {}
var _world_start: Dictionary = {}
var _preview: Vector2 = Vector2(INF, INF)
var _real_touch: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func _size() -> Vector2:
	return get_viewport_rect().size

func _circles() -> Dictionary:
	var view := _size()
	var h := view.y
	var circles := {
		"attack": Vector2(view.x - 0.20 * h, 0.56 * h),
		"back": Vector2(0.14 * h, 0.20 * h),
	}
	if duel:
		circles["build"] = Vector2(view.x - 0.18 * h, 0.25 * h)
		if palette_open:
			circles["floor"] = Vector2(view.x - 0.18 * h, 0.39 * h)
			circles["wall"] = Vector2(view.x - 0.34 * h, 0.39 * h)
			circles["undo"] = Vector2(view.x - 0.50 * h, 0.39 * h)
			circles["close"] = Vector2(view.x - 0.66 * h, 0.39 * h)
	return circles

func _radius(id: String) -> float:
	return _size().y * (0.068 if id in ["attack", "build"] else 0.062)

func _button_at(pos: Vector2) -> String:
	var circles := _circles()
	# Palette buttons win their shared edge over the toggle.
	for id in ["floor", "wall", "undo", "close", "attack", "build", "back"]:
		if circles.has(id) and pos.distance_to(circles[id]) <= _radius(id):
			return id
	return ""

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_real_touch = true
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		_real_touch = true
		_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not _real_touch:
		if event.pressed:
			_down(InputHub.MOUSE_FINGER, event.position)
		else:
			_up(InputHub.MOUSE_FINGER, event.position)
	elif event is InputEventMouseMotion and not _real_touch:
		_drag(InputHub.MOUSE_FINGER, event.position)

func _down(index: int, pos: Vector2) -> void:
	var button := _button_at(pos)
	if button != "":
		_owners[index] = button
		get_viewport().set_input_as_handled()
		if button == "attack" and not arena.waiting() and arena.phase() != VersusMatch.Phase.OVER:
			arena.input.press_strike()
		return
	if not duel or not palette_open or arena.waiting() \
			or arena.phase() == VersusMatch.Phase.OVER:
		return
	# Runner touch areas remain exclusively owned by InputHub.
	if ControlLayout.hit("runner", _size(), false, pos) != "":
		return
	if pos.y <= _size().y * 0.17:
		return
	_owners[index] = "world"
	_world_start[index] = pos
	_preview = pos
	get_viewport().set_input_as_handled()

func _drag(index: int, pos: Vector2) -> void:
	if _owners.get(index, "") == "world":
		_preview = pos
		get_viewport().set_input_as_handled()

func _up(index: int, pos: Vector2) -> void:
	if not _owners.has(index):
		return
	var action: String = _owners[index]
	_owners.erase(index)
	get_viewport().set_input_as_handled()
	match action:
		"build":
			palette_open = not palette_open
		"close":
			palette_open = false
		"floor":
			selected_slot = 1
		"wall":
			selected_slot = 2
		"undo":
			if not arena.waiting():
				arena.request_construct_undo()
		"back":
			arena.leave_versus()
		"world":
			# Releasing over any button or the Runner control cluster cancels.
			if _button_at(pos) == "" and ControlLayout.hit("runner",
					_size(), false, pos) == "":
				var at: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * pos
				arena.request_construct(selected_slot, at)
			_world_start.erase(index)
			_preview = Vector2(INF, INF)
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,
			NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_owners.clear()
		_world_start.clear()
		_preview = Vector2(INF, INF)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if arena == null:
		return
	var h := _size().y
	var font := Art.font()
	var places := ControlLayout.layout("runner", _size(), false)
	for id in ["stick", "jump", "sprint"]:
		if not places.has(id):
			continue
		var p: Dictionary = places[id]
		var c: Vector2 = p["center"]
		var r: float = p["radius"]
		draw_circle(c, r, Color(0.08, 0.12, 0.21, 0.40))
		draw_arc(c, r, 0.0, TAU, 40, Color(0.87, 0.91, 0.98, 0.64), 2.0)
		var label := "移動" if id == "stick" else ("ジャンプ" if id == "jump" else "ダッシュ")
		draw_string(font, c + Vector2(-r, 6.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 17, Color.WHITE)
	var names := {"attack": "攻撃", "build": "建築", "floor": "足場",
		"wall": "壁", "undo": "取消", "close": "閉じる", "back": "戻る"}
	for id in _circles():
		var center: Vector2 = _circles()[id]
		var radius := _radius(id)
		var active := (id == "floor" and selected_slot == 1) \
			or (id == "wall" and selected_slot == 2)
		draw_circle(center, radius, Color(0.13, 0.31, 0.45, 0.86) if active
			else Color(0.08, 0.12, 0.23, 0.75))
		draw_arc(center, radius, 0.0, TAU, 36, Color(0.93, 0.95, 0.99), 2.0)
		draw_string(font, center + Vector2(-radius, 6.0), names[id],
			HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 17, Color.WHITE)
	if duel and palette_open:
		var note := "足場" if selected_slot == 1 else "壁"
		draw_string(font, Vector2(_size().x - h * 0.75, h * 0.49),
			"選択：" + note + "  ／  画面をタップして設置",
			HORIZONTAL_ALIGNMENT_LEFT, h * 0.73, 15, Color.WHITE)
	if _preview.x != INF:
		draw_circle(_preview, 12.0, Color(0.80, 0.94, 1.0, 0.55))
