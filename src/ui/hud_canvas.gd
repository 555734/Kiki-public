extends Control
## All HUD painting. Kept in one _draw() so the whole overlay is a single
## CanvasItem -- on mobile, a dozen separate Control nodes each with their own
## draw call is a real cost for something that changes every frame anyway.

## Typed loosely on purpose: Hud preloads this script, so naming the Hud class
## here would close a compile-time cycle and knock out type inference in both.
var hud: Node = null

const NAVY := Color(0.05, 0.10, 0.16, 0.82)

## How long the stage banner stays at full strength, and how long it takes to
## settle back. See _stage_plate.
const INTRO_HOLD := 5.0
const INTRO_FADE := 1.5

func _draw() -> void:
	# See placement_preview.gd: a redraw queued on the frame the world is freed
	# arrives with a dangling reference, which is not null.
	if not is_instance_valid(hud):
		return
	var view := size
	var hub: InputHub = hud.input_hub if is_instance_valid(hud.input_hub) else null
	_stage_plate(view)
	# The ability bar is the guardian's control, not a readout: on the runner's
	# device none of it responds, so it is not drawn there.
	# The controls themselves are ControlPainter's, shared with the star
	# battle so the two screens show exactly the same buttons.
	ControlPainter.draw_controls(self, hud, view)
	_messages(view)
	if hud.countdown() > 0.0:
		_countdown(view)
	if hud.rescue_flash() > 0.0:
		_rescue_pop(view)
	if not hud.link_text().is_empty():
		_link_banner(view)
	if hud.game_over() > 0.0:
		_game_over_panel(view)
	if not hud.cleared().is_empty():
		_clear_panel(view)

func _gauge_bar(at: Vector2, w: float, h: float) -> void:
	var level: float = hud.gauge()
	var frac := clampf(level / Balance.GAUGE_MAX, 0.0, 1.0)
	DrawUtil.rounded_rect(self, Rect2(at, Vector2(w, h)), h * 0.5, Color(0.06, 0.12, 0.2, 0.9))
	if frac > 0.001:
		var col := Balance.C_ACCENT if frac > 0.3 else Color("ff9b4a")
		DrawUtil.rounded_rect(self, Rect2(at + Vector2(2, 2), Vector2((w - 4.0) * frac, h - 4.0)),
			(h - 4.0) * 0.5, col)
	# Cost ticks, so the guardian can see at a glance what they can still afford.
	for cost: float in [Balance.COST_SNIPE, Balance.COST_WALL, Balance.COST_PLATFORM]:
		var x: float = at.x + w * (cost / Balance.GAUGE_MAX)
		draw_line(Vector2(x, at.y + 1.0), Vector2(x, at.y + h - 1.0), Color(0, 0, 0, 0.35), 1.5)
	draw_rect(Rect2(at, Vector2(w, h)), Color(0.31, 0.85, 1.0, 0.45), false, 1.2)

# -------------------------------------------------------------- stage plate

func _stage_plate(view: Vector2) -> void:
	var font := Art.font()
	# The banner sits over the top-right of the play field, which is exactly
	# where sky-level turrets and flyers are. It reads at full strength while
	# the player is getting their bearings, then drops back so the guardian can
	# still see -- and shoot -- whatever is behind it.
	var fade := 1.0 - 0.58 * clampf((hud.time() - INTRO_HOLD) / INTRO_FADE, 0.0, 1.0)
	var w := 316.0
	var origin := Vector2(view.x - w - 16.0, 14.0)
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(Hud.SKEW, 0), origin + Vector2(w, 0),
		origin + Vector2(w, 34), origin + Vector2(0, 34),
	]), _dim(NAVY, fade))
	# Right-aligned inside an explicit box. Passing width 0 here silently clips
	# the string to the anchor instead of laying it out, which is what ate the
	# stage name the first time round.
	draw_string(font, origin + Vector2(Hud.SKEW + 6.0, 24.0),
		"%s   %s" % [Stage.stage_number(), tr(Stage.stage_name())],
		HORIZONTAL_ALIGNMENT_RIGHT, w - Hud.SKEW - 20.0, 18, _dim(Color(1, 1, 1, 0.95), fade))

	var obj_w := w - 14.0
	var obj := Vector2(view.x - obj_w - 16.0, 52.0)
	draw_colored_polygon(PackedVector2Array([
		obj + Vector2(Hud.SKEW, 0), obj + Vector2(obj_w, 0),
		obj + Vector2(obj_w, 30), obj + Vector2(0, 30),
	]), _dim(Color(0.05, 0.10, 0.16, 0.7), fade))
	draw_string(font, obj + Vector2(Hud.SKEW + 6.0, 21.0), Stage.objective(),
		HORIZONTAL_ALIGNMENT_RIGHT, obj_w - Hud.SKEW - 44.0, 15,
		_dim(Color(0.88, 0.94, 1.0), fade))
	# The diamond marker from the mockup. It keeps pulsing at full strength --
	# it is the objective pointer, and it is small enough to hide nothing.
	var d := obj + Vector2(obj_w - 20.0, 15.0)
	var now: float = hud.time()
	var pulse := 0.7 + 0.3 * sin(now * 2.4)
	draw_colored_polygon(PackedVector2Array([
		d + Vector2(0, -9), d + Vector2(9, 0), d + Vector2(0, 9), d + Vector2(-9, 0),
	]), Color(0.31, 0.85, 1.0, pulse))
	draw_colored_polygon(PackedVector2Array([
		d + Vector2(0, -4.5), d + Vector2(4.5, 0), d + Vector2(0, 4.5), d + Vector2(-4.5, 0),
	]), Color(0.02, 0.06, 0.12))
	if Stage.needs_key():
		_key_chip(Vector2(view.x - 16.0 - 150.0, 88.0))

## Whether the gate's key has been found yet, under the objective plate.
##
## The HUD redraws every rendered frame (Hud._process calls queue_redraw), so
## everything in here is paid for at the display's rate. Two things were worth
## fixing: draw_string re-shapes its text on every single call, and an
## antialiased draw_arc builds a feathered ring's worth of geometry for a
## fourteen-segment circle. The two labels never change, so they are shaped
## once and kept; the ring is not antialiased, at this size against a rounded
## plate nobody can tell.
static var _key_text: Dictionary = {}

static func _key_line(have: bool) -> TextLine:
	if not _key_text.has(have):
		var line := TextLine.new()
		line.add_string(TranslationServer.translate("鍵 あり" if have else "鍵 さがせ"), Art.font(), 15)
		_key_text[have] = line
	return _key_text[have]

func _key_chip(at: Vector2) -> void:
	var have := GameState.has_key
	var box := Rect2(at, Vector2(150, 28))
	DrawUtil.rounded_rect(self, box, 14.0,
		Color(0.36, 0.26, 0.04, 0.85) if have else Color(0.05, 0.10, 0.16, 0.7))
	var c := at + Vector2(22, 14)
	var gold := Color("f3c334") if have else Color(0.6, 0.64, 0.7, 0.8)
	draw_arc(c + Vector2(-4, 0), 5.5, 0.0, TAU, 14, gold, 3.0, false)
	draw_rect(Rect2(c + Vector2(1, -1.5), Vector2(13, 3)), gold)
	draw_rect(Rect2(c + Vector2(9, 1.5), Vector2(2.5, 4)), gold)
	_key_line(have).draw(get_canvas_item(), at + Vector2(44, 6),
		Color(1.0, 0.93, 0.6) if have else Color(0.88, 0.94, 1.0))

func _dim(c: Color, f: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * f)

# -------------------------------------------------------------- ability bar

## The guardian's tools, as round buttons on the arc a thumb sweeps.
##
## This used to be a rectangular plate across the bottom of the screen with
## square tiles in it. Two things were wrong with that and both came back from
## the device: the plate covered the ground the guardian was trying to build
## into, and a bar across the middle is nowhere near either thumb on a phone
## held in two hands. Round, cornered and transparent is what every mobile
## shooter does, and for the same reasons.
# ---------------------------------------------------------------- messages

func _messages(view: Vector2) -> void:
	var font := Art.font()
	if hud.refusal_flash() > 0.0:
		var flash: float = hud.refusal_flash()
		var a: float = clampf(flash / 0.9, 0.0, 1.0)
		draw_string(font, Vector2(view.x * 0.5 - 200.0, view.y * 0.62), hud.refusal_text(),
			HORIZONTAL_ALIGNMENT_CENTER, 400, 18, Color(1.0, 0.65, 0.35, a))
	var notice: String = hud.notice_text()
	if notice != "":
		draw_string(font, Vector2(view.x * 0.5 - 200.0, view.y * 0.30), notice,
			HORIZONTAL_ALIGNMENT_CENTER, 400, 20, Color(0.42, 0.95, 1.0, 0.9))

func _countdown(view: Vector2) -> void:
	var remaining: float = hud.countdown()
	var n := int(ceil(remaining))
	if n <= 0:
		return
	var frac: float = remaining - floor(remaining)
	var scale: float = 1.0 + (1.0 - frac) * 0.5
	var text := str(mini(n, 3)) if n <= 3 else "3"
	var font := Art.font()
	draw_set_transform(Vector2(view.x * 0.5, view.y * 0.34), 0.0, Vector2.ONE * scale)
	draw_string(font, Vector2(-100, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 200, 64,
		Color(1, 1, 1, 0.35 + frac * 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The catch. The one thing in this game worth interrupting the screen for.
##
## Placed high and centre rather than over the runner: both players have to see
## it, and on the guardian's device the runner may be anywhere. It rises and
## fades, and the size is the grade -- a PERFECT should feel physically bigger
## than a NICE before anyone has read the word.
func _rescue_pop(view: Vector2) -> void:
	var tier: int = clampi(hud.rescue_tier(), 1, 3)
	var life: float = clampf(hud.rescue_flash() / 1.3, 0.0, 1.0)
	var rise := (1.0 - life) * 34.0
	var fade := clampf(life * 2.4, 0.0, 1.0)
	# Overshoot on the way in, so it lands rather than appears.
	var pop := 1.0 + maxf(0.0, (life - 0.82)) * 2.2
	var size := (26 + tier * 9) * pop
	var colours := [Color("9fe8ff"), Color("ffe07a"), Color("ff9de0")]
	var tint: Color = colours[tier - 1]
	var at := Vector2(0.0, view.y * 0.30 - rise)
	var font := Art.font(Art.FONT_DISPLAY)
	var text: String = Balance.RESCUE_NAMES[tier]
	# Drawn twice: a dark pass behind, so it survives a bright sky.
	draw_string(font, at + Vector2(0.0, 3.0), text, HORIZONTAL_ALIGNMENT_CENTER,
		view.x, int(size), Color(0.04, 0.06, 0.10, 0.55 * fade))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, view.x, int(size),
		Color(tint.r, tint.g, tint.b, fade))
	if tier >= 2:
		draw_string(Art.font(), at + Vector2(0.0, size * 0.72), "+%d GAUGE"
			% int(Balance.RESCUE_REFUND[tier]), HORIZONTAL_ALIGNMENT_CENTER,
			view.x, 15, Color(1, 1, 1, 0.75 * fade))

## The link. Drawn across the top rather than over the middle: the game has not
## stopped -- the runner is still playing on their own device -- so this must
## not cover the picture the guardian is waiting to see come back.
func _link_banner(view: Vector2) -> void:
	var font := Art.font()
	var text: String = hud.link_text()
	var pulse := 0.72 + 0.28 * sin(hud.time() * 4.0)
	var box := Rect2(view.x * 0.5 - 230.0, 96.0, 460.0, 42.0)
	DrawUtil.rounded_rect(self, box, 10.0, Color(0.10, 0.06, 0.02, 0.88))
	draw_rect(box, Color(1.0, 0.72, 0.25, 0.85 * pulse), false, 2.0)
	draw_string(font, Vector2(box.position.x, box.position.y + 27.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 16, Color(1.0, 0.92, 0.78))

## The run ending. Two hits does it, and so does a pit, so this is drawn often
## enough that it must not be a wall the player waits behind: it holds for
## RESPAWN_DELAY and lifts by itself when the retry begins.
##
## Deliberately not a full-screen blackout. Both players are still looking at
## the same stage a second and a half later, and taking the picture away from
## them means the guardian cannot see where the runner is about to be put back.
func _game_over_panel(view: Vector2) -> void:
	var font := Art.font(Art.FONT_DISPLAY)
	var t: float = hud.game_over() / maxf(Balance.RESPAWN_DELAY, 0.001)
	# Slam in, hold, then lift with the retry.
	var rise := clampf((1.0 - t) * 6.0, 0.0, 1.0)
	var fade := clampf(t * 3.0, 0.0, 1.0) * rise
	var box := Rect2(view.x * 0.5 - 210.0, view.y * 0.40 - 54.0, 420.0, 108.0)
	draw_rect(Rect2(0.0, box.position.y - 10.0, view.x, box.size.y + 20.0),
		Color(0.06, 0.02, 0.04, 0.42 * fade))
	DrawUtil.rounded_rect(self, box, 14.0, Color(0.10, 0.02, 0.05, 0.88 * fade))
	draw_rect(box, Color(0.92, 0.28, 0.30, 0.85 * fade), false, 2.5)
	# Overshoots on the way in, so it lands rather than appears.
	var scale := 1.0 + (1.0 - rise) * 0.25
	var centre := box.get_center()
	draw_set_transform(centre - centre * scale, 0.0, Vector2(scale, scale))
	draw_string(font, Vector2(box.position.x, box.position.y + 54.0), "GAME OVER",
		HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 40, Color(1, 0.92, 0.92, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var where := "checkpoint %d" % GameState.checkpoint_index \
		if GameState.checkpoint_index > 0 else "the start"
	draw_string(Art.font(), Vector2(box.position.x, box.position.y + 86.0),
		"retrying from %s" % where, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 15,
		Color(1, 0.78, 0.78, 0.85 * fade))

## The goal: a celebration rather than a scoresheet. Light rays turn behind a
## title that bounces in, confetti falls, and stars burst out once. All of it
## is driven by hud.clear_age, so it is the same on both screens.
func _clear_panel(view: Vector2) -> void:
	var font := Art.font()
	var t: float = hud.clear_age
	var c := Vector2(view.x * 0.5, view.y * 0.36)

	# A white flash on the frame of the clear, fading fast.
	if t < 0.35:
		draw_rect(Rect2(Vector2.ZERO, view), Color(1, 1, 1, 0.55 * (1.0 - t / 0.35)))
	# Soft golden wash so the celebration reads over any stage.
	draw_rect(Rect2(Vector2.ZERO, view), Color(1.0, 0.86, 0.45, minf(0.18, t * 0.4)))

	# Rotating light rays.
	var rays := 14
	var reach := view.length() * 0.6
	for i in rays:
		var a := t * 0.35 + TAU * float(i) / float(rays)
		var w := 0.11
		draw_colored_polygon(PackedVector2Array([
			c, c + Vector2(cos(a - w), sin(a - w)) * reach,
			c + Vector2(cos(a + w), sin(a + w)) * reach]),
			Color(1.0, 0.93, 0.6, 0.10 * minf(1.0, t * 2.0)))

	# Star burst, once.
	if t < 1.6:
		var k := t / 1.6
		for i in 12:
			var a := TAU * float(i) / 12.0 + 0.2
			var p := c + Vector2(cos(a), sin(a)) * (60.0 + k * 360.0)
			_star(p, 14.0 * (1.0 - k) + 4.0, Color(1.0, 0.9, 0.35, 1.0 - k))

	# Confetti, falling and swaying.
	var colours := [Color("ff5d73"), Color("ffd23f"), Color("3bceac"), Color("5fa8ff"),
		Color("b784ff"), Color("ffffff")]
	for i in 90:
		var h1 := DrawUtil.hash01(i * 7 + 3)
		var h2 := DrawUtil.hash01(i * 13 + 11)
		var speed := 110.0 + h2 * 140.0
		var y := fposmod(-40.0 - h1 * view.y + t * speed, view.y + 60.0) - 30.0
		var x := h1 * view.x + sin(t * (1.5 + h2 * 2.0) + float(i)) * 26.0
		var spin := t * (3.0 + h2 * 5.0) + float(i)
		draw_set_transform(Vector2(x, y), spin, Vector2(1.0, absf(cos(spin * 1.3)) * 0.8 + 0.2))
		draw_rect(Rect2(-5, -3, 10, 6), colours[i % colours.size()])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The title bounces in with a little overshoot, then breathes.
	var pop := 0.0
	if t < 0.5:
		pop = _ease_out_back(t / 0.5)
	else:
		pop = 1.0 + sin((t - 0.5) * 3.0) * 0.03
	var text := "STAGE CLEAR!"
	var size := 64
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_set_transform(c, sin(t * 2.0) * 0.02, Vector2(pop, pop))
	for off in [Vector2(4, 5), Vector2(0, 0)]:
		var col := Color(0.12, 0.10, 0.30, 0.6) if off != Vector2.ZERO else Color("ffe45c")
		draw_string_outline(font, Vector2(-width * 0.5, 22) + off, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(0.55, 0.22, 0.05, 0.95 if off == Vector2.ZERO else 0.0))
		draw_string(font, Vector2(-width * 0.5, 22) + off, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if t > 0.6:
		var a := clampf((t - 0.6) * 2.0, 0.0, 1.0)
		draw_string(font, Vector2(0, c.y + 70.0), tr("やったね！ ふたりでゴール！"),
			HORIZONTAL_ALIGNMENT_CENTER, view.x, 24, Color(1, 1, 1, a))

func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

func _star(at: Vector2, r: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + TAU * float(i) / 10.0
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, colour)

