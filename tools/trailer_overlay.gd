extends CanvasLayer
## Everything the trailer draws over the game: captions, the guardian's stroke
## being drawn, and the end card. All of it is a function of shot time, set by
## capture_trailer.gd once per film frame, so it is as repeatable as the game.

const TITLE_FONT := preload("res://assets/fonts/Baloo2-Bold.ttf")
const BODY_FONT := preload("res://assets/fonts/Nunito-ExtraBold.ttf")
const ICON := preload("res://assets/ui/appicon_1024.png")

const INK := Color(0.07, 0.10, 0.20)
const WHITE := Color(1, 1, 1)
const ACCENT := Color(0.36, 0.86, 1.0)

var t := 0.0
var _captions: Array = []
var _card: Dictionary = {}
var _fade: Array = []        # [from_sec, to_sec, from_alpha, to_alpha]
var _canvas: Control = null

func _ready() -> void:
	layer = 90
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_all)
	add_child(_canvas)

func begin_shot() -> void:
	_captions.clear()
	_card = {}
	_fade = []
	t = 0.0

func end_shot() -> void:
	begin_shot()
	_canvas.queue_redraw()

func set_time(sec: float, _frame: int) -> void:
	t = sec
	_canvas.queue_redraw()

## A punch-in caption. `at`/`until` are shot seconds; `pos` is the text's
## centre in design pixels (1280x720).
func caption(text: String, at: float, until: float, pos := Vector2(640, 150),
		size := 92) -> void:
	_captions.append({"text": text, "at": at, "until": until, "pos": pos, "size": size})

## The closing card: title and one line under it, over a dimmed game.
func end_card(at: float, title: String, line: String) -> void:
	_card = {"at": at, "title": title, "line": line}

## A full-screen black fade, for the very end.
func fade(from_sec: float, to_sec: float, a0: float, a1: float) -> void:
	_fade = [from_sec, to_sec, a0, a1]

func _draw_all() -> void:
	for c in _captions:
		_draw_caption(c)
	if not _card.is_empty():
		_draw_card()
	if not _fade.is_empty():
		var k := clampf(inverse_lerp(_fade[0], _fade[1], t), 0.0, 1.0)
		var a := lerpf(_fade[2], _fade[3], k)
		if a > 0.0:
			_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0, 0, 0, a))

static func _ease_out_back(x: float) -> float:
	var c1 := 1.9
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3) + c1 * pow(x - 1.0, 2)

func _draw_caption(c: Dictionary) -> void:
	var age := t - float(c["at"])
	var left := float(c["until"]) - t
	if age < 0.0 or left < 0.0:
		return
	# In: a fast overshoot from small. Out: a quick shrink-and-fade.
	var k_in := clampf(age / 0.20, 0.0, 1.0)
	var scale := lerpf(0.55, 1.0, _ease_out_back(k_in))
	var alpha := clampf(age / 0.08, 0.0, 1.0)
	if left < 0.12:
		var k := left / 0.12
		alpha *= k
		scale *= lerpf(1.08, 1.0, k)
	var size := int(c["size"])
	var text := String(c["text"])
	var font: Font = TITLE_FONT
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos: Vector2 = c["pos"]
	var xf := Transform2D(0.0, Vector2(scale, scale), 0.0, pos)
	_canvas.draw_set_transform_matrix(xf)
	var base := Vector2(-w * 0.5, size * 0.33)
	# A hard drop shadow and a thick outline: legible over any of the eight
	# stages, which run from night blue to lava orange.
	font.draw_string_outline(_canvas.get_canvas_item(), base + Vector2(0, 7), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, 18, Color(INK, 0.55 * alpha))
	font.draw_string_outline(_canvas.get_canvas_item(), base, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, 16, Color(INK, alpha))
	font.draw_string(_canvas.get_canvas_item(), base, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(WHITE, alpha))
	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_card() -> void:
	var age := t - float(_card["at"])
	if age < 0.0:
		return
	var dim := clampf(age / 0.5, 0.0, 1.0)
	_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(INK, 0.55 * dim))
	# The app icon drops in first, the title punches in under it, then the line.
	var k := clampf(age / 0.35, 0.0, 1.0)
	var s := 168.0 * lerpf(0.6, 1.0, _ease_out_back(k))
	var icon_rect := Rect2(Vector2(640, 212) - Vector2(s, s) * 0.5, Vector2(s, s))
	var a := clampf(age / 0.12, 0.0, 1.0)
	_canvas.draw_rect(icon_rect.grow(6.0), Color(1, 1, 1, a))
	_canvas.draw_texture_rect(ICON, icon_rect, false, Color(1, 1, 1, a))
	_draw_caption({"text": _card["title"], "at": _card["at"] + 0.3,
		"until": 9999.0, "pos": Vector2(640, 392), "size": 124})
	var line_age := age - 0.85
	if line_age < 0.0:
		return
	var la := clampf(line_age / 0.3, 0.0, 1.0)
	var size := 40
	var text := String(_card["line"])
	var w := BODY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var y := 492.0 + (1.0 - la) * 14.0
	var ci := _canvas.get_canvas_item()
	BODY_FONT.draw_string_outline(ci, Vector2(640 - w * 0.5, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(INK, la))
	BODY_FONT.draw_string(ci, Vector2(640 - w * 0.5, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(ACCENT, la))
