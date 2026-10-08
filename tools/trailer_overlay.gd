extends CanvasLayer
## Everything the trailer draws over the game: captions, the hand-lettered
## note, letterbox bars, flashes, fades and the end card. All of it is a
## function of shot time, set by capture_trailer.gd once per film frame, so it
## is as repeatable as the game.

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
var _bars: Array = []        # [from_sec, to_sec, from_h, to_h] in design px
var _flashes: Array = []     # [at_sec, length_sec, peak_alpha]
var _note: Dictionary = {}
## Where the note's arrow points, in design pixels. A shot moves it every
## frame to follow something in the world.
var note_target := Vector2.ZERO
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
	_bars = []
	_flashes = []
	_note = {}
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

## The closing card: icon, title and the lines under it, over a dimmed game.
func end_card(at: float, title: String, lines: Array) -> void:
	_card = {"at": at, "title": title, "lines": lines}

## Cinema bars, top and bottom, easing from one height to another.
func letterbox(from_sec: float, to_sec: float, h0: float, h1: float) -> void:
	_bars = [from_sec, to_sec, h0, h1]

## A white flash that falls off over `length` seconds.
func flash(at: float, length := 0.25, peak := 0.85) -> void:
	_flashes.append([at, length, peak])

## A small hand-lettered note that types itself out word by word, with an
## arrow to note_target -- the reference trailer's "THIS IS YOU".
func note(text: String, at: float, until: float, pos: Vector2) -> void:
	_note = {"text": text, "at": at, "until": until, "pos": pos}

## A full-screen black fade, for the very end.
func fade(from_sec: float, to_sec: float, a0: float, a1: float) -> void:
	_fade = [from_sec, to_sec, a0, a1]

func _draw_all() -> void:
	if not _bars.is_empty():
		var k := clampf(inverse_lerp(_bars[0], _bars[1], t), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		var h := lerpf(_bars[2], _bars[3], k)
		if h > 0.5:
			_canvas.draw_rect(Rect2(0, 0, 1280, h), Color.BLACK)
			_canvas.draw_rect(Rect2(0, 720 - h, 1280, h), Color.BLACK)
	for c in _captions:
		_draw_caption(c)
	if not _note.is_empty():
		_draw_note()
	if not _card.is_empty():
		_draw_card()
	for f in _flashes:
		var age := t - float(f[0])
		if age >= 0.0 and age < float(f[1]):
			var a := float(f[2]) * pow(1.0 - age / float(f[1]), 2.0)
			_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(1, 1, 1, a))
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

func _draw_note() -> void:
	var age := t - float(_note["at"])
	var left := float(_note["until"]) - t
	if age < 0.0 or left < 0.0:
		return
	var alpha := clampf(left / 0.15, 0.0, 1.0)
	# Word by word, the way the reference trailer lets "THIS" sit a beat
	# before "IS YOU" arrives.
	var words := String(_note["text"]).split(" ")
	var shown := clampi(1 + int(age / 0.35), 1, words.size())
	var text := " ".join(words.slice(0, shown))
	var size := 40
	var pos: Vector2 = _note["pos"]
	var ci := _canvas.get_canvas_item()
	# A slight forward lean reads as lettering rather than a UI label.
	_canvas.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.18, 1), pos))
	BODY_FONT.draw_string_outline(ci, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, size, 9, Color(INK, 0.85 * alpha))
	BODY_FONT.draw_string(ci, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, size, Color(WHITE, alpha))
	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	if shown < words.size():
		return
	# The arrow grows out of the last word towards the target.
	var full_w := BODY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var from := pos + Vector2(full_w + 14.0, -size * 0.45)
	var grow := clampf((age - 0.35 * (words.size() - 1)) / 0.25, 0.0, 1.0)
	var to := from.lerp(note_target, 0.82 * grow)
	if from.distance_to(to) < 4.0:
		return
	var dir := (to - from).normalized()
	var side := dir.orthogonal()
	for pass_i in 2:
		var col := Color(INK, 0.85 * alpha) if pass_i == 0 else Color(WHITE, alpha)
		var w := 11.0 if pass_i == 0 else 5.0
		_canvas.draw_line(from, to, col, w, true)
		_canvas.draw_line(to, to - dir * 22.0 + side * 13.0, col, w, true)
		_canvas.draw_line(to, to - dir * 22.0 - side * 13.0, col, w, true)

func _draw_card() -> void:
	var age := t - float(_card["at"])
	if age < 0.0:
		return
	var ci := _canvas.get_canvas_item()
	var dim := clampf(age / 0.4, 0.0, 1.0)
	# A deep wash over the game, darker at the foot, and slow sunburst rays
	# behind the title: the end card should read as a poster, not a pause.
	_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(INK, 0.55 * dim))
	_canvas.draw_polygon(PackedVector2Array([Vector2(0, 360), Vector2(1280, 360),
		Vector2(1280, 720), Vector2(0, 720)]), PackedColorArray([Color(INK, 0.0),
		Color(INK, 0.0), Color(INK, 0.6 * dim), Color(INK, 0.6 * dim)]))
	var spin := age * 0.18
	for i in 16:
		var a0 := spin + TAU * i / 16.0
		var a1 := a0 + TAU / 32.0
		_canvas.draw_colored_polygon(PackedVector2Array([Vector2(640, 300),
			Vector2(640, 300) + Vector2.from_angle(a0) * 1100.0,
			Vector2(640, 300) + Vector2.from_angle(a1) * 1100.0]),
			Color(ACCENT, 0.07 * dim))
	# The icon drops in, rounded, on a soft shadow.
	var k := clampf(age / 0.35, 0.0, 1.0)
	var s := 168.0 * lerpf(0.5, 1.0, _ease_out_back(k))
	var c := Vector2(640, 168 + (1.0 - k) * -40.0)
	var a := clampf(age / 0.1, 0.0, 1.0)
	_rounded(Rect2(c - Vector2(s, s) * 0.5 + Vector2(0, 10), Vector2(s, s)).grow(4), s * 0.22,
		Color(0, 0, 0, 0.35 * a), null)
	_rounded(Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)).grow(6), s * 0.24, Color(1, 1, 1, a), null)
	_rounded(Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), s * 0.22, Color(1, 1, 1, a), ICON)
	# The title punches in with an extruded edge under it.
	var title_age := age - 0.25
	if title_age >= 0.0:
		var tk := clampf(title_age / 0.22, 0.0, 1.0)
		var sc := lerpf(0.4, 1.0, _ease_out_back(tk))
		var text := String(_card["title"])
		var size := 132
		var w := TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var ta := clampf(title_age / 0.06, 0.0, 1.0)
		_canvas.draw_set_transform_matrix(Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(640, 368)))
		var base := Vector2(-w * 0.5, size * 0.33)
		for d in range(12, 0, -2):
			TITLE_FONT.draw_string_outline(ci, base + Vector2(0, d), text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, size, 16, Color(0.10, 0.36, 0.55, ta))
		TITLE_FONT.draw_string_outline(ci, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 16, Color(INK, ta))
		TITLE_FONT.draw_string(ci, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(WHITE, ta))
		_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	# Then where to get it: a line, and a pill for each store.
	var lines: Array = _card["lines"]
	var line_age := age - 0.75
	if line_age >= 0.0 and lines.size() > 0:
		var la := clampf(line_age / 0.25, 0.0, 1.0)
		var head := String(lines[0])
		var hw := BODY_FONT.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var hy := 478.0 + (1.0 - la) * 10.0
		BODY_FONT.draw_string_outline(ci, Vector2(640 - hw * 0.5, hy), head,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color(INK, la))
		BODY_FONT.draw_string(ci, Vector2(640 - hw * 0.5, hy), head,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(ACCENT, la))
	var pills: Array = lines.slice(1)
	for i in pills.size():
		var pa := age - 0.95 - 0.12 * i
		if pa < 0.0:
			continue
		var pk := clampf(pa / 0.25, 0.0, 1.0)
		var label := String(pills[i])
		var size := 34
		var w := BODY_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 64.0
		var gap := 28.0
		var total := 0.0
		for p in pills:
			total += BODY_FONT.get_string_size(String(p), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 64.0
		total += gap * (pills.size() - 1)
		var x := 640.0 - total * 0.5
		for j in i:
			x += BODY_FONT.get_string_size(String(pills[j]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 64.0 + gap
		var r := Rect2(x, 512.0 + (1.0 - _ease_out_back(pk)) * 24.0, w, 62.0)
		var pa_alpha := clampf(pa / 0.08, 0.0, 1.0)
		_rounded(r.grow(3), 34.0, Color(1, 1, 1, 0.9 * pa_alpha), null)
		_rounded(r, 31.0, Color(0.05, 0.06, 0.10, 0.95 * pa_alpha), null)
		BODY_FONT.draw_string(ci, Vector2(r.position.x + 32.0, r.position.y + 43.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(WHITE, pa_alpha))

## A filled rounded rectangle, optionally textured edge to edge.
func _rounded(r: Rect2, radius: float, color: Color, tex: Texture2D) -> void:
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [Vector2(r.end.x - radius, r.position.y + radius),
		Vector2(r.end.x - radius, r.end.y - radius),
		Vector2(r.position.x + radius, r.end.y - radius),
		Vector2(r.position.x + radius, r.position.y + radius)]
	for ci in 4:
		for k in 7:
			var ang := -PI * 0.5 + PI * 0.5 * ci + PI * 0.5 * k / 6.0
			pts.append(corners[ci] + Vector2.from_angle(ang) * radius)
	if tex == null:
		_canvas.draw_colored_polygon(pts, color)
		return
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append((p - r.position) / r.size)
	_canvas.draw_polygon(pts, PackedColorArray([color]), uvs, tex)
