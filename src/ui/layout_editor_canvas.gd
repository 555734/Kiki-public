extends Control
## Draws the controls being arranged, and moves the one under a finger.
##
## Drawn from ControlLayout, which is the same table the game hit-tests and the
## HUD renders, so what is dragged here is exactly what responds in play. That
## is the whole reason the placements were pulled into one file first.

var editor: Node = null

var _dragging := ""
var _grab := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	if editor == null:
		return
	var view := size
	var places: Dictionary = ControlLayout.layout(editor.mode(), view, false)
	var accent := Color(0.31, 0.85, 1.0)
	var font := Art.font()

	# The divider, but only where it means something: on a shared screen it is
	# a real boundary between two people's hands.
	if editor.mode() == "shared":
		var x := ControlLayout.DIVIDER * view.x
		draw_line(Vector2(x, 0), Vector2(x, view.y), Color(1, 1, 1, 0.18), 2.0)
		draw_string(font, Vector2(x + 8.0, 28.0), "→ ガーディアン",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.35))

	for id in places:
		var place: Dictionary = places[id]
		var c: Vector2 = place["center"]
		var r: float = float(place["radius"])
		var held: bool = String(id) == _dragging or String(id) == String(editor.selected())
		if place["kind"] == "stick":
			# The capture circle, because that is the part that takes a thumb --
			# a stick you can see but only half of which responds is worse than
			# no stick at all.
			draw_arc(c, r * ControlLayout.STICK_CAPTURE, 0.0, TAU, 48,
				Color(1, 1, 1, 0.16), 2.0, true)
		draw_circle(c, r, Color(0.05, 0.11, 0.17, 0.85 if held else 0.65))
		draw_arc(c, r, 0.0, TAU, 48,
			Color(accent.r, accent.g, accent.b, 1.0 if held else 0.75),
			4.0 if held else 2.6, true)
		var label := ControlLayout.label(String(id))
		var text := int(clampf(r * 0.36, 12.0, 20.0))
		draw_string(font, c + Vector2(-r, float(text) * 0.36), label,
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, text, Color(1, 1, 1, 0.95))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_pick(touch.position)
		else:
			_drop()
		accept_event()
	elif event is InputEventScreenDrag:
		_move((event as InputEventScreenDrag).position)
		accept_event()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				_pick(click.position)
			else:
				_drop()
			accept_event()
	elif event is InputEventMouseMotion and _dragging != "":
		_move((event as InputEventMouseMotion).position)
		accept_event()

func _pick(at: Vector2) -> void:
	if editor == null:
		return
	# Whatever is nearest, not whatever is first: the controls are round and a
	# thumb landing between two of them should take the one it is closest to.
	var places: Dictionary = ControlLayout.layout(editor.mode(), size, false)
	var best := ""
	var best_d := INF
	for id in places:
		var d: float = at.distance_to(places[id]["center"])
		if d <= float(places[id]["radius"]) and d < best_d:
			best_d = d
			best = String(id)
	if best == "":
		return
	_dragging = best
	_grab = at - places[best]["center"]
	# Touching a control also points the size slider at it: one gesture, not a
	# separate select step on a screen where every extra step is a lost thumb.
	editor.select(best)
	queue_redraw()

func _move(at: Vector2) -> void:
	if _dragging == "" or editor == null:
		return
	var places: Dictionary = ControlLayout.layout(editor.mode(), size, false)
	var r: float = float(places[_dragging]["radius"])
	if places[_dragging]["kind"] == "stick":
		r *= ControlLayout.STICK_CAPTURE
	# Kept whole and on the screen. A control half off the edge is a control
	# with half a hit area, and nothing on screen would say so.
	var centre := Vector2(
		clampf(at.x - _grab.x, r, maxf(r, size.x - r)),
		clampf(at.y - _grab.y, r, maxf(r, size.y - r)))
	ControlLayout.set_place(editor.mode(), _dragging, centre / size)
	queue_redraw()

func _drop() -> void:
	if _dragging == "":
		return
	_dragging = ""
	if editor != null:
		editor.moved()
	queue_redraw()
