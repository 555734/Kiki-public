extends Node2D
## Screen-space layers of the 1-10 PV that are not gameplay: the incoming call
## (Discord mark plus decline/accept buttons, no text), the guardian's YOU
## pointer, the MELOS GAME title and the three end cards. The director owns
## one of these on a CanvasLayer above the game and one (title only) on a
## CanvasLayer between the backdrop and the world, so the runner, terrain and
## enemies pass in front of the title.
##
## Everything here is drawn from state the director sets each frame; nothing
## reads the game, and nothing here moves anything in it.

const BLURPLE := Color("5865f2")
const PANEL := Color("1e1f22")
const RED := Color("da373c")
const GREEN := Color("23a55a")

var title_only := false

## Call card: 0 hidden, 1 ringing, 2 accepted (button pressed, card leaving).
var call_state := 0
var call_t := 0.0
var call_alpha := 0.0

## YOU pointer (screen position of the fingertip); INF hides it.
var pointer := Vector2(INF, INF)
var pointer_alpha := 0.0
var pointer_pop := 0.0
## Pointer size follows the camera a little, so close-ups get a big hand.
var pointer_scale := 1.0

## Title: alpha, scale and centre in screen pixels.
var title_alpha := 0.0
var title_scale := 0.62
var title_centre := Vector2(640, 250)

## End cards: 0 none, 1 store badges, 2 COMING OCTOBER 2026, 3 Created by.
var card := 0
var card_t := 0.0
var lower_panel := false

var _tex := {}
var _baloo: FontFile = null
var _nunito: FontFile = null

func _ready() -> void:
	for key in ["title_melos_game", "badge_google_play", "badge_app_store", "discord_mark_white", "you_cursor"]:
		_tex[key] = load("res://assets/promo/%s.png" % key)
	_baloo = load("res://assets/fonts/Baloo2-Bold.ttf")
	_nunito = load("res://assets/fonts/Nunito-ExtraBold.ttf")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if has_meta("slate"):
		draw_rect(Rect2(0, 0, 1280, 720), Color(1, 0, 1))
		return
	if title_only:
		_draw_title(title_alpha, title_centre, title_scale)
		return
	if lower_panel:
		_draw_lower_panel()
	if call_alpha > 0.01:
		_draw_call()
	if pointer.x != INF and pointer_alpha > 0.01:
		_draw_pointer()

# ------------------------------------------------------------------ title
func _draw_title(alpha: float, centre: Vector2, scale: float) -> void:
	var tex: Texture2D = _tex["title_melos_game"]
	if tex == null or alpha <= 0.01:
		return
	var size := tex.get_size() * scale
	draw_texture_rect(tex, Rect2(centre - size * 0.5, size), false, Color(1, 1, 1, alpha))

# --------------------------------------------------------------- the call
func _draw_call() -> void:
	var a := call_alpha
	# A phone-style call card on the right third, sliding in from the edge.
	var w := 300.0
	var h := 420.0
	var slide := (1.0 - a) * 120.0
	var rect := Rect2(1280 - w - 70 + slide, 360 - h * 0.5, w, h)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.28 * a))
	_round_rect(rect.grow(6), 34, Color(1, 1, 1, 0.16 * a))
	_round_rect(rect, 30, Color(PANEL, 0.96 * a))
	var centre := rect.position + Vector2(w * 0.5, 150)
	# Ringing pulses around the mark (stop once accepted).
	if call_state == 1:
		for i in 3:
			var k := fposmod(call_t * 1.4 + float(i) / 3.0, 1.0)
			draw_arc(centre, 70.0 + k * 70.0, 0, TAU, 64, Color(BLURPLE, (1.0 - k) * 0.7 * a), 5.0, true)
	draw_circle(centre, 72, Color(BLURPLE, a))
	var mark: Texture2D = _tex["discord_mark_white"]
	if mark != null:
		var ms := mark.get_size() * (84.0 / mark.get_size().x)
		var wob := sin(call_t * 26.0) * 0.08 if call_state == 1 else 0.0
		draw_set_transform(centre, wob, Vector2.ONE)
		draw_texture_rect(mark, Rect2(-ms * 0.5, ms), false, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Decline and accept: the only controls, no words.
	var y := rect.position.y + h - 92
	var decline := Vector2(rect.position.x + w * 0.27, y)
	var accept := Vector2(rect.position.x + w * 0.73, y)
	var press := clampf(call_t * 6.0, 0.0, 1.0) if call_state == 2 else 0.0
	_button(decline, RED, true, a * (1.0 - 0.6 * press), 1.0)
	_button(accept, GREEN, false, a, 1.0 - 0.18 * sin(press * PI) + (0.06 * sin(call_t * 9.0) if call_state == 1 else 0.0))
	if call_state == 2:
		draw_arc(accept, 44.0 + press * 40.0, 0, TAU, 48, Color(GREEN.lightened(0.4), (1.0 - press) * a), 6.0, true)

func _button(at: Vector2, color: Color, down: bool, a: float, scale: float) -> void:
	draw_circle(at, 40.0 * scale, Color(color, a))
	# A handset: two ear/mouth pieces joined by an arc. Hung up = rotated 135.
	draw_set_transform(at, deg_to_rad(135.0 if down else -20.0), Vector2.ONE * scale)
	var col := Color(1, 1, 1, a)
	draw_arc(Vector2(0, 6), 17.0, PI * 1.15, PI * 1.85, 16, col, 9.0, true)
	draw_circle(Vector2(-15, 0), 7.0, col)
	draw_circle(Vector2(15, 0), 7.0, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- pointer
func _draw_pointer() -> void:
	var tex: Texture2D = _tex["you_cursor"]
	var a := pointer_alpha
	var s := (0.78 + pointer_pop * 0.35) * pointer_scale
	var hot := Vector2(47, 8) * s
	var p := pointer
	draw_circle(p, 30.0 + pointer_pop * 26.0, Color(0.2, 0.6, 1.0, 0.22 * a))
	if tex != null:
		draw_texture_rect(tex, Rect2(p - hot, tex.get_size() * s), false, Color(1, 1, 1, a))
	var label := "YOU"
	var fs := int(30 * s + 4)
	var lp := p + Vector2(-58, -18) * s
	draw_string_outline(_baloo, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 9, Color(1, 1, 1, a))
	draw_string(_baloo, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("1f7bff", a))

# -------------------------------------------------------------- end cards
func _draw_lower_panel() -> void:
	var top := 372.0
	draw_rect(Rect2(0, top, 1280, 720 - top), Color("0a1222"))
	draw_rect(Rect2(0, top, 1280, 4), Color("2f8cff"))
	var k := clampf(card_t * 7.0, 0.0, 1.0)
	var a := k
	var cy := top + (720 - top) * 0.5
	match card:
		1:
			var gp: Texture2D = _tex["badge_google_play"]
			var ap: Texture2D = _tex["badge_app_store"]
			var h := 96.0
			var gw := gp.get_size().x * h / gp.get_size().y
			var aw := ap.get_size().x * h / ap.get_size().y
			var gap := 56.0
			var x0 := 640.0 - (gw + aw + gap) * 0.5
			draw_texture_rect(gp, Rect2(x0, cy - h * 0.5, gw, h), false, Color(1, 1, 1, a))
			draw_texture_rect(ap, Rect2(x0 + gw + gap, cy - h * 0.5, aw, h), false, Color(1, 1, 1, a))
		2:
			_centred("COMING", cy - 38, 62, Color(1, 1, 1, a))
			_centred("OCTOBER 2026", cy + 52, 86, Color("ffb21e", a))
		3:
			_centred("Created by", cy - 34, 50, Color(1, 1, 1, a))
			_centred("Takumi & TyoRo", cy + 50, 78, Color(1, 1, 1, a))

func _centred(text: String, baseline: float, size: int, color: Color) -> void:
	var w := _baloo.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(640.0 - w * 0.5, baseline)
	draw_string_outline(_baloo, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(0, 0, 0, color.a * 0.6))
	draw_string(_baloo, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _round_rect(r: Rect2, radius: float, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
