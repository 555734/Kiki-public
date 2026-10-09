extends CanvasLayer
## Everything the trailer draws over the game: captions, the hand-lettered
## note, letterbox bars, flashes, fades and the end card. All of it is a
## function of shot time, set by capture_trailer.gd once per film frame, so it
## is as repeatable as the game.

const TITLE_FONT := preload("res://assets/fonts/Baloo2-Bold.ttf")
const BODY_FONT := preload("res://assets/fonts/Nunito-ExtraBold.ttf")
const ICON := preload("res://assets/ui/appicon_1024.png")
## The reference trailer's two lettering styles: a tall condensed sans for the
## aside ("THIS IS YOU"), a chunky pixel face for the headline.
const TAG_FONT := preload("res://tools/trailer_assets/fonts/BebasNeue-Regular.ttf")
const PIXEL_FONT := preload("res://tools/trailer_assets/fonts/Silkscreen-Bold.ttf")
const ICONS := {
	"platform": preload("res://assets/ui/icon_platform.png"),
	"snipe": preload("res://assets/ui/icon_snipe.png"),
	"wall": preload("res://assets/ui/icon_wall.png"),
}
const PAPER := Color(0.09, 0.39, 0.85)
const PAPER_LINE := Color(0.86, 0.94, 1.0)
const CARD_SIZE := Vector2(840, 540)
const CARD_CENTRE := Vector2(505, 372)
## The headline is sized so the reference's own line would be this wide.
const HEADLINE_WIDTH := 750.0

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
var _tags: Array = []
var _titles: Array = []
var _cards: Array = []
var _grids: Array = []
## Where a blueprint settles, in design pixels: the screen rect of the thing
## being placed. A shot moves it every frame, as the camera may.
var blueprint_rect := Rect2(560, 300, 200, 120)
## A voice call, the way a chat app shows one: {"at", "answer"} -- the banner
## rings from `at`, is answered at `answer` and becomes the in-call bar.
var _call: Dictionary = {}
## The name tag that rides next to the guardian's finger: "" for none, and
## where the fingertip is on the screen this frame (design px).
var finger_name := ""
var finger_at := Vector2(INF, INF)
## A finger tapping the screen itself (the call's answer button): [at_sec, pos].
var _taps: Array = []

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
	_tags = []
	_titles = []
	for c in _cards:
		(c["sub"] as Node).queue_free()
	_cards = []
	_grids = []
	_call = {}
	_taps = []
	finger_name = ""
	finger_at = Vector2(INF, INF)
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
func end_card(at: float, title: String, lines: Array, credit := "") -> void:
	_card = {"at": at, "title": title, "lines": lines, "credit": credit}

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
	for c in _cards:
		_draw_paper(c)
		_draw_card_grid(c)
	for g in _grids:
		_draw_blueprint(g)
	for g in _tags:
		_draw_tag(g)
	for g in _titles:
		_draw_title(g)
	if finger_name != "" and finger_at.x != INF:
		_draw_finger_tag()
	if not _call.is_empty():
		_draw_call()
	for tap in _taps:
		_draw_tap(tap)
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

	# Last, who made it: one quiet line under the stores.
	var credit := String(_card.get("credit", ""))
	var ca := age - 1.3
	if credit != "" and ca >= 0.0:
		var cfa := clampf(ca / 0.3, 0.0, 1.0)
		var cw := BODY_FONT.get_string_size(credit, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var at := Vector2(640 - cw * 0.5, 640.0)
		BODY_FONT.draw_string_outline(ci, at, credit, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 7, Color(INK, cfa))
		BODY_FONT.draw_string(ci, at, credit, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(WHITE, 0.92 * cfa))

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

# ------------------------------------------------- the reference trailer's set

## The aside: plain tall white letters that arrive a word or two at a time --
## `steps` is [[sec, text], ...] -- and a short arrow up and to the right once
## the line is complete. `pos` is the left end of the baseline.
func tag(steps: Array, until: float, pos: Vector2, size := 72) -> void:
	_tags.append({"steps": steps, "until": until, "pos": pos, "size": size})

## The headline: pixel letters, white on a black outline and a black extruded
## edge, building up word by word in place, then fading as the next thing
## arrives. `centre` is the centre of the complete line.
func title(steps: Array, until: float, centre: Vector2) -> void:
	_titles.append({"steps": steps, "until": until, "pos": centre})

## A blueprint card for one of the guardian's tools. It lands like a sheet of
## paper -- bent and tilted, settling flat -- and at `dissolve` turns into the
## glowing grid that shrinks onto blueprint_rect, where the tool goes.
func card(kind: String, at: float, dissolve: float) -> void:
	var sub := SubViewport.new()
	sub.size = Vector2i(CARD_SIZE * 2.0)
	sub.size_2d_override = Vector2i(CARD_SIZE)
	sub.size_2d_override_stretch = true
	sub.transparent_bg = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var face := Control.new()
	face.size = CARD_SIZE
	face.draw.connect(_draw_face.bind(face, kind))
	sub.add_child(face)
	add_child(sub)
	_cards.append({"kind": kind, "at": at, "dissolve": dissolve, "sub": sub})

## The grid alone, without the card: on blueprint_rect from `at` to `until`.
func blueprint(kind: String, at: float, until: float) -> void:
	_grids.append({"kind": kind, "at": at, "until": until})

static func _step_text(steps: Array, age_t: float) -> String:
	var text := ""
	for st in steps:
		if age_t >= float(st[0]):
			text = String(st[1])
	return text

func _draw_tag(g: Dictionary) -> void:
	var steps: Array = g["steps"]
	var text := _step_text(steps, t)
	var left := float(g["until"]) - t
	if text == "" or left < 0.0:
		return
	var a := clampf(left / 0.12, 0.0, 1.0)
	var size := int(g["size"])
	var pos: Vector2 = g["pos"]
	var ci := _canvas.get_canvas_item()
	TAG_FONT.draw_string(ci, pos + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0, 0, 0, 0.22 * a))
	TAG_FONT.draw_string(ci, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, a))
	if text != String(steps[steps.size() - 1][1]):
		return
	var w := TAG_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var k := size / 72.0
	var from := pos + Vector2(w + 12.0 * k, -size * 0.12)
	var to := from + Vector2(38, -38) * k
	for pass_i in 2:
		var off := Vector2(0, 3) if pass_i == 0 else Vector2.ZERO
		var col := Color(0, 0, 0, 0.22 * a) if pass_i == 0 else Color(1, 1, 1, a)
		_canvas.draw_line(from + off, to + off, col, 4.0 * k, true)
		_canvas.draw_line(to + off, to + off + Vector2(-17, 0) * k, col, 4.0 * k, true)
		_canvas.draw_line(to + off, to + off + Vector2(0, 17) * k, col, 4.0 * k, true)

func _headline_size() -> int:
	var w := PIXEL_FONT.get_string_size("BUILD YOUR LEVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	return int(round(100.0 * HEADLINE_WIDTH / w))

func _draw_title(g: Dictionary) -> void:
	var steps: Array = g["steps"]
	var text := _step_text(steps, t)
	var left := float(g["until"]) - t
	if text == "" or left < 0.0:
		return
	var a := clampf(left / 0.35, 0.0, 1.0)
	var size := _headline_size()
	var full := String(steps[steps.size() - 1][1])
	var w := PIXEL_FONT.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var centre: Vector2 = g["pos"]
	var base := centre + Vector2(-w * 0.5, size * 0.36)
	var ci := _canvas.get_canvas_item()
	# A hard black outline stamped all the way round, and a black extruded
	# edge below it: a pixel face wants square edges, not a soft stroke.
	var ink := Color(0.04, 0.04, 0.06, a)
	var o := maxf(2.0, size * 0.075)
	var depth := int(size * 0.11)
	for dy in range(depth, -1, -2):
		for k in 16:
			var off := Vector2.from_angle(TAU * k / 16.0) * o + Vector2(0, dy)
			PIXEL_FONT.draw_string(ci, base + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	PIXEL_FONT.draw_string(ci, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, a))

static func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## One point of the card sheet, u and v across it from 0 to 1.
func _paper_pt(u: float, v: float, wave: float, tilt: float, persp: float, grow: float) -> Vector2:
	var p := Vector2((u - 0.5) * CARD_SIZE.x, (v - 0.5) * CARD_SIZE.y * (1.0 + persp * (0.5 - u) * 2.0))
	# Bent along its length, the way a sheet is when it has just been thrown.
	p.y += wave * sin(u * PI * 1.3 - 0.35)
	p.x *= 1.0 - absf(wave) * 0.0012
	return CARD_CENTRE + (p * grow).rotated(tilt)

func _draw_paper(c: Dictionary) -> void:
	var age := t - float(c["at"])
	if age < 0.0:
		return
	var d := t - float(c["dissolve"])
	var alpha := clampf(age / 0.07, 0.0, 1.0)
	if d >= 0.0:
		alpha *= 1.0 - clampf(d / 0.5, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var settle := exp(-age * 4.2)
	var wave := 46.0 * settle * cos(age * 9.0)
	var tilt := -0.13 * settle - 0.018
	var persp := 0.11 * settle + 0.03
	var grow := 1.0 + 0.05 * settle + (0.1 * _smooth(d / 0.45) if d > 0.0 else 0.0)
	var tex := (c["sub"] as SubViewport).get_texture()
	var cols := 24
	for pass_i in 2:
		for i in cols:
			var u0 := float(i) / cols
			var u1 := float(i + 1) / cols
			var pts := PackedVector2Array([_paper_pt(u0, 0, wave, tilt, persp, grow),
				_paper_pt(u1, 0, wave, tilt, persp, grow), _paper_pt(u1, 1, wave, tilt, persp, grow),
				_paper_pt(u0, 1, wave, tilt, persp, grow)])
			if pass_i == 0:
				for k in 4:
					pts[k] += Vector2(5, 8)
				_canvas.draw_colored_polygon(pts, Color(0, 0, 0, 0.18 * alpha))
			else:
				var uvs := PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)])
				_canvas.draw_polygon(pts, PackedColorArray([Color(1, 1, 1, alpha)]), uvs, tex)

func _draw_card_grid(c: Dictionary) -> void:
	var d := t - float(c["dissolve"])
	if d < 0.04:
		return
	var k := _smooth((d - 0.12) / 0.55)
	var from := Rect2(CARD_CENTRE - CARD_SIZE * 0.55, CARD_SIZE * 1.1)
	var r := Rect2(from.position.lerp(blueprint_rect.position, k), from.size.lerp(blueprint_rect.size, k))
	var a := clampf((d - 0.04) / 0.2, 0.0, 1.0) * (1.0 - clampf((d - 0.85) / 0.5, 0.0, 1.0))
	_grid_panel(r, a, String(c["kind"]))

func _draw_blueprint(g: Dictionary) -> void:
	var age := t - float(g["at"])
	var left := float(g["until"]) - t
	if age < 0.0 or left < 0.0:
		return
	var a := clampf(age / 0.15, 0.0, 1.0) * clampf(left / 0.35, 0.0, 1.0)
	var s := lerpf(1.25, 1.0, _smooth(age / 0.25))
	var r := blueprint_rect
	r = Rect2(r.get_center() - r.size * s * 0.5, r.size * s)
	_grid_panel(r, a, String(g["kind"]))

## The glowing grid of a blueprint laid over the world.
func _grid_panel(r: Rect2, a: float, kind: String) -> void:
	if a <= 0.01:
		return
	for g in 6:
		_canvas.draw_rect(r.grow(5.0 + g * 8.0), Color(0.6, 0.86, 1.0, 0.045 * a))
	_canvas.draw_rect(r, Color(0.62, 0.85, 1.0, 0.30 * a))
	var step := 26.0
	var i := 0
	var x := r.position.x
	while x <= r.end.x + 0.5:
		var major := i % 4 == 0
		_canvas.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y),
			Color(1, 1, 1, (0.55 if major else 0.28) * a), 2.0 if major else 1.0)
		x += step
		i += 1
	i = 0
	var y := r.position.y
	while y <= r.end.y + 0.5:
		var major := i % 4 == 0
		_canvas.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y),
			Color(1, 1, 1, (0.55 if major else 0.28) * a), 2.0 if major else 1.0)
		y += step
		i += 1
	_canvas.draw_rect(r, Color(1, 1, 1, 0.75 * a), false, 2.0)
	var sc := clampf(minf(r.size.x, r.size.y) / 330.0, 0.25, 1.6)
	_schematic(_canvas, kind, r.get_center(), sc, a)

static func _dash(c: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 2.0, on := 8.0, off := 6.0) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / maxf(len, 0.001)
	var s := 0.0
	while s < len:
		c.draw_line(a + dir * s, a + dir * minf(s + on, len), col, w)
		s += on + off

static func _dash_rect(c: CanvasItem, r: Rect2, col: Color, w := 2.0) -> void:
	_dash(c, r.position, Vector2(r.end.x, r.position.y), col, w)
	_dash(c, Vector2(r.end.x, r.position.y), r.end, col, w)
	_dash(c, r.end, Vector2(r.position.x, r.end.y), col, w)
	_dash(c, Vector2(r.position.x, r.end.y), r.position, col, w)

## The tool, drawn the way a blueprint draws it, around `at`.
static func _schematic(c: CanvasItem, kind: String, at: Vector2, s: float, a: float) -> void:
	var line := Color(1, 1, 1, 0.9 * a)
	var faint := Color(1, 1, 1, 0.35 * a)
	match kind:
		"platform":
			# A finger's stroke, its sample points, and the slab it becomes.
			var pts := PackedVector2Array()
			for k in 9:
				var u := float(k) / 8.0
				pts.append(at + Vector2(lerpf(-115, 115, u), sin(u * PI * 1.6) * -16.0 - 10.0) * s)
			for k in pts.size():
				c.draw_arc(pts[k], 7.0 * s, 0, TAU, 14, line, 2.0)
				if k > 0:
					var dir := (pts[k] - pts[k - 1]).normalized()
					c.draw_line(pts[k - 1] + dir * 7.0 * s, pts[k] - dir * 7.0 * s, line, 2.0)
			c.draw_rect(Rect2(pts[0] - Vector2(11, 11) * s, Vector2(22, 22) * s), line, false, 2.0)
			_dash_rect(c, Rect2(at + Vector2(-125, 18) * s, Vector2(250, 30) * s), faint, 2.0)
		"snipe":
			var aim := at + Vector2(40, -30) * s
			c.draw_arc(aim, 44.0 * s, 0, TAU, 40, line, 2.0)
			c.draw_arc(aim, 16.0 * s, 0, TAU, 24, line, 2.0)
			for k in 4:
				var dir := Vector2.from_angle(k * PI * 0.5)
				c.draw_line(aim + dir * 26.0 * s, aim + dir * 60.0 * s, line, 2.0)
			for k in 6:
				var u := float(k) / 6.0
				c.draw_arc(at + Vector2(lerpf(-120, 0, u), lerpf(90, 10, u)) * s, 5.0 * s, 0, TAU, 12, line, 2.0)
			c.draw_rect(Rect2(at + Vector2(-131, 79) * s, Vector2(22, 22) * s), line, false, 2.0)
		"wall":
			var r := Rect2(at + Vector2(-26, -105) * s, Vector2(52, 210) * s)
			c.draw_rect(r, line, false, 2.0)
			for k in range(1, 6):
				var y := r.position.y + r.size.y * k / 6.0
				c.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), faint, 2.0)
			for k in 3:
				var y := at.y + (k - 1) * 60.0 * s
				_dash(c, Vector2(at.x + 150 * s, y), Vector2(r.end.x + 10 * s, y), line, 2.0)
				c.draw_line(Vector2(r.end.x + 10 * s, y), Vector2(r.end.x + 22 * s, y - 9 * s), line, 2.0)
				c.draw_line(Vector2(r.end.x + 10 * s, y), Vector2(r.end.x + 22 * s, y + 9 * s), line, 2.0)

## What the card says about each tool. The numbers are the game's own.
static func _spec(kind: String) -> Dictionary:
	match kind:
		"snipe":
			return {"title": "Snipe", "id": "GD_SNP_03", "rows": [
				["FUNCTION", "STUN / KNOCKBACK"], ["INPUT", "ONE TAP"],
				["DAMAGE", str(Balance.SNIPE_DAMAGE)], ["COOLDOWN", "%.1f S" % Balance.SNIPE_COOLDOWN],
				["AMMO", "UNLIMITED"], ["RANGE", "WHOLE SCREEN"], ["TARGET", "ANY ENEMY"],
				["COST", "FREE"]],
				"parts": ["1x RETICLE  [AIM_01]", "1x BOLT  [PRJ_SNP_2]", "1x TRACER  [FX_LINE]"]}
		"wall":
			return {"title": "Wall", "id": "GD_WAL_02", "rows": [
				["FUNCTION", "BLOCKS SHOTS + CHARGES"], ["INPUT", "ONE TAP"],
				["SIZE", "%d x %d PX" % [Balance.WALL_SIZE.x, Balance.WALL_SIZE.y]],
				["LIFETIME", "%.1f S" % Balance.WALL_LIFETIME], ["MAX_ALIVE", str(Balance.WALL_MAX_ALIVE)],
				["COST", "%d GAUGE" % Balance.COST_WALL], ["REGEN", "%d / S" % Balance.GAUGE_REGEN_PER_SEC],
				["MATERIAL", "HARD LIGHT"]],
				"parts": ["6x PANEL  [WAL_SEG_6]", "1x EMITTER  [HOLO_CORE]", "1x TIMER  [CLK_4S]"]}
		_:
			return {"title": "Platform", "id": "GD_PLT_01", "rows": [
				["FUNCTION", "DRAWN WALKWAY"], ["INPUT", "ONE STROKE"],
				["MAX_LENGTH", "%d PX" % Balance.TRACE_MAX_LENGTH],
				["LIFETIME", "%.1f S" % Balance.PLATFORM_LIFETIME],
				["MAX_ALIVE", str(Balance.PLATFORM_MAX_ALIVE)], ["SHAPE", "FOLLOWS THE STROKE"],
				["WARNING", "FLASHES LAST 1 S"], ["COST", "FREE"]],
				"parts": ["1x STROKE  [TRC_IN_01]", "16x NODE  [PTH_SMP]", "1x SLAB  [HOLO_PLT]"]}

func _draw_face(c: Control, kind: String) -> void:
	var spec := _spec(kind)
	var w := CARD_SIZE.x
	var h := CARD_SIZE.y
	var line := PAPER_LINE
	var thin := Color(PAPER_LINE, 0.55)
	c.draw_rect(Rect2(Vector2.ZERO, CARD_SIZE), PAPER)
	# Faint paper grid.
	for x in range(0, int(w), 30):
		c.draw_line(Vector2(x, 0), Vector2(x, h), Color(1, 1, 1, 0.05), 1.0)
	for y in range(0, int(h), 30):
		c.draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.05), 1.0)
	var frame := Rect2(16, 16, w - 32, h - 32)
	c.draw_rect(frame, line, false, 3.0)
	# Header: kind and level, the name, the icon.
	c.draw_line(Vector2(16, 120), Vector2(w - 16, 120), line, 3.0)
	c.draw_line(Vector2(176, 16), Vector2(176, 120), line, 3.0)
	c.draw_line(Vector2(w - 134, 16), Vector2(w - 134, 120), line, 3.0)
	c.draw_line(Vector2(16, 68), Vector2(176, 68), line, 2.0)
	var ci := c.get_canvas_item()
	for row in [["ABILITY", 54.0], ["LEVEL 1", 104.0]]:
		var tw := BODY_FONT.get_string_size(String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		BODY_FONT.draw_string(ci, Vector2(96 - tw * 0.5, float(row[1])), String(row[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, line)
	BODY_FONT.draw_string(ci, Vector2(204, 90), String(spec["title"]), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 54, Color.WHITE)
	var icon: Texture2D = ICONS.get(kind, ICONS["platform"])
	var box := Rect2(w - 134, 16, 118, 104)
	var isz := icon.get_size() * (74.0 / icon.get_size().y)
	c.draw_texture_rect(icon, Rect2(box.get_center() - isz * 0.5, isz), false)
	# Left: the drawing.
	var draw_box := Rect2(44, 150, 370, 350)
	var dc := draw_box.get_center()
	var steps := PackedVector2Array([Vector2(-150, -120), Vector2(-110, -120), Vector2(-110, -160),
		Vector2(110, -160), Vector2(110, -120), Vector2(150, -120), Vector2(150, 120),
		Vector2(110, 120), Vector2(110, 160), Vector2(-110, 160), Vector2(-110, 120),
		Vector2(-150, 120), Vector2(-150, -120)])
	for k in steps.size() - 1:
		_dash(c, dc + steps[k], dc + steps[k + 1], thin, 2.0, 6.0, 5.0)
	c.draw_arc(dc, 150.0, 0, TAU, 64, Color(1, 1, 1, 0.18), 2.0)
	c.draw_rect(Rect2(dc - Vector2(150, 160), Vector2(300, 320)), Color(1, 1, 1, 0.06))
	_schematic(c, kind, dc, 1.0, 1.0)
	BODY_FONT.draw_string(ci, dc + Vector2(-70, -100), "DRAW_ASSEMBLY", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 11, Color(1, 1, 1, 0.5))
	BODY_FONT.draw_string(ci, dc + Vector2(-40, 130), String(spec["id"]), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 11, Color(1, 1, 1, 0.5))
	# Right: the specification table and the part list.
	var tb := Rect2(440, 150, 368, 268)
	c.draw_rect(tb, line, false, 2.0)
	var head := "SPECIFICATIONS: " + String(spec["id"])
	var hw := BODY_FONT.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	BODY_FONT.draw_string(ci, Vector2(tb.get_center().x - hw * 0.5, tb.position.y + 22), head,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, line)
	var rows: Array = spec["rows"]
	var y0 := tb.position.y + 32.0
	var rh := (tb.end.y - y0) / rows.size()
	c.draw_line(Vector2(tb.position.x + 128, y0), Vector2(tb.position.x + 128, tb.end.y), thin, 1.5)
	for k in rows.size():
		var y := y0 + rh * k
		c.draw_line(Vector2(tb.position.x, y), Vector2(tb.end.x, y), thin, 1.5)
		var key := String(rows[k][0])
		var kw := BODY_FONT.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		BODY_FONT.draw_string(ci, Vector2(tb.position.x + 64 - kw * 0.5, y + rh * 0.65), key,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, line)
		var val := String(rows[k][1])
		var vw := BODY_FONT.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		BODY_FONT.draw_string(ci, Vector2(tb.position.x + 248 - vw * 0.5, y + rh * 0.65), val,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	BODY_FONT.draw_string(ci, Vector2(560, 446), "PART LIST: PRIMARY COMPONENTS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, line)
	var parts: Array = spec["parts"]
	for k in parts.size():
		BODY_FONT.draw_string(ci, Vector2(560, 464 + k * 15), String(parts[k]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))

# ------------------------------------------------------------------ the call

const PORTRAITS := {
	"ORION": preload("res://assets/ui/portrait_orion.png"),
	"LIRA": preload("res://assets/ui/portrait_lira.png"),
}
const CALL_BG := Color(0.12, 0.13, 0.16, 0.96)
const CALL_LINE := Color(1, 1, 1, 0.08)
const CALL_GREEN := Color(0.18, 0.80, 0.44)
const CALL_RED := Color(0.93, 0.27, 0.27)

## A voice call from `caller`: rings from `at`, answered at `answer`. Until
## `until` the in-call bar stays up in the corner (INF: to the end of the shot).
func voice_call(caller: String, at: float, answer: float, until: float = INF,
		people: Array = []) -> void:
	_call = {"caller": caller, "at": at, "answer": answer, "until": until,
		"people": people if not people.is_empty() else [caller]}

## A fingertip tapping the screen at `pos` (design px) at `at`.
func tap(at: float, pos: Vector2) -> void:
	_taps.append([at, pos])

func _avatar(centre: Vector2, radius: float, who: String, alpha: float, ring := 0.0) -> void:
	if ring > 0.0:
		_canvas.draw_arc(centre, radius + 4.0, 0, TAU, 40, Color(CALL_GREEN, ring * alpha), 3.5, true)
	var tex: Texture2D = PORTRAITS.get(who)
	_canvas.draw_circle(centre, radius, Color(0.2, 0.22, 0.28, alpha))
	if tex != null:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for k in 32:
			var d := Vector2.from_angle(TAU * k / 32.0)
			pts.append(centre + d * radius)
			uvs.append(Vector2(0.5, 0.5) + d * 0.5 * 0.86)
		_canvas.draw_polygon(pts, PackedColorArray([Color(1, 1, 1, alpha)]), uvs, tex)

func _draw_call() -> void:
	var age := t - float(_call["at"])
	if age < 0.0 or t > float(_call["until"]):
		return
	var ci := _canvas.get_canvas_item()
	var answered := t >= float(_call["answer"])
	if not answered:
		# The incoming banner, sliding down from the top, ringing.
		var k := _ease_out_back(clampf(age / 0.35, 0.0, 1.0))
		var w := 560.0
		var h := 120.0
		var ring := sin(age * TAU * 2.0)
		var shake := ring * 3.0 if fmod(age, 1.2) < 0.6 else 0.0
		var r := Rect2(640.0 - w * 0.5 + shake, lerpf(-h - 10.0, 26.0, k), w, h)
		_rounded(r.grow(2), 26.0, CALL_LINE, null)
		_rounded(r, 24.0, CALL_BG, null)
		var who := String(_call["caller"])
		var pulse := 0.5 + 0.5 * absf(ring)
		_avatar(r.position + Vector2(66, h * 0.5), 38.0, who, 1.0, pulse)
		BODY_FONT.draw_string(ci, r.position + Vector2(122, 54), who, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 30, Color.WHITE)
		BODY_FONT.draw_string(ci, r.position + Vector2(122, 88), "Incoming voice call...",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.65))
		for b in 2:
			var c := r.position + Vector2(w - 150.0 + 76.0 * b, h * 0.5)
			var col := CALL_RED if b == 0 else CALL_GREEN
			var grow := 1.0 + (0.08 * pulse if b == 1 else 0.0)
			_canvas.draw_circle(c, 28.0 * grow, col)
			_draw_phone(c, 0.9 * grow, b == 0)
		return
	# Answered: the bar in the corner, with whoever is on the call.
	var since := t - float(_call["answer"])
	var k2 := clampf(since / 0.3, 0.0, 1.0)
	var people: Array = _call["people"]
	var w2 := 214.0 + 58.0 * people.size()
	var bar := Rect2(lerpf(640.0 - w2 * 0.5, 22.0, _smooth(k2)), lerpf(26.0, 20.0, k2), w2, 64)
	_rounded(bar.grow(2), 34.0, CALL_LINE, null)
	_rounded(bar, 32.0, CALL_BG, null)
	_canvas.draw_circle(bar.position + Vector2(30, 32), 8.0, CALL_GREEN)
	BODY_FONT.draw_string(ci, bar.position + Vector2(48, 30), "Voice connected",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CALL_GREEN)
	BODY_FONT.draw_string(ci, bar.position + Vector2(48, 50), "%d in call" % people.size(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.6))
	for i in people.size():
		var c := bar.position + Vector2(214.0 + 58.0 * i, 32)
		# Talking: the green ring comes and goes, a little out of step per person.
		var talk := clampf(sin(t * 7.0 + i * 2.1) * 0.8 + sin(t * 3.3 + i) * 0.6, 0.0, 1.0)
		_avatar(c, 22.0, String(people[i]), 1.0, talk)

func _draw_phone(c: Vector2, s: float, hang_up: bool) -> void:
	# A handset: two ear pieces and the bar between them.
	var rot := 2.35 if hang_up else 0.0
	_canvas.draw_set_transform(c, rot, Vector2(s, s))
	_canvas.draw_line(Vector2(-9, -6), Vector2(9, -6), Color.WHITE, 6.0, true)
	_canvas.draw_circle(Vector2(-10, -2), 5.0, Color.WHITE)
	_canvas.draw_circle(Vector2(10, -2), 5.0, Color.WHITE)
	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_tap(tap: Array) -> void:
	var age := t - float(tap[0])
	if age < -0.4 or age > 0.5:
		return
	var at: Vector2 = tap[1]
	if age < 0.0:
		# The finger coming in to press.
		var k := 1.0 + age / 0.4
		_canvas.draw_circle(at, 26.0, Color(1, 1, 1, 0.18 * k))
		_canvas.draw_circle(at, 13.0, Color(1, 1, 1, 0.5 * k))
		return
	var k2 := age / 0.5
	_canvas.draw_arc(at, lerpf(14.0, 48.0, k2), 0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - k2)), 4.0, true)
	_canvas.draw_circle(at, 13.0 * (1.0 - k2), Color(1, 1, 1, 0.7))

## Where on the screen the answer button sits, for the tap that presses it.
func call_answer_point() -> Vector2:
	return Vector2(640.0 - 280.0 + 560.0 - 150.0 + 76.0, 26.0 + 60.0)

func _draw_finger_tag() -> void:
	var ci := _canvas.get_canvas_item()
	var size := 20
	var w := BODY_FONT.get_string_size(finger_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 22.0
	var r := Rect2(finger_at + Vector2(30, 34), Vector2(w, 30))
	_rounded(r, 15.0, Color(0.21, 0.84, 1.0, 0.95), null)
	BODY_FONT.draw_string(ci, r.position + Vector2(11, 22), finger_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.03, 0.10, 0.16))
