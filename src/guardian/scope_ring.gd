extends Control
## The optic furniture drawn on top of the magnified circle: rim, graduated
## crosshair, red centre dot, zoom readout and the gauge-derived ammo strip.
## Straight from mockup 3, minus the full-screen blackout.

## Typed loosely for the same reason as HudCanvas: Scope preloads this script.
var scope: Node = null

func _draw() -> void:
	if scope == null:
		return
	var a: float = scope.amount()
	if a <= 0.01:
		return
	var c: Vector2 = scope.centre()
	var r: float = Balance.SCOPE_RADIUS * a
	var accent := Balance.C_ACCENT

	if not _painted_optic(c, r, a):
		_vector_optic(c, r, a, accent)

	# Zoom readout, hung off the upper right of the rim.
	var font := Art.font()
	var zoom_level: float = scope.zoom()
	var label := "%.1fx" % zoom_level
	# Clamped so the readout does not walk off the edge when the guardian aims
	# into a corner.
	# Hung off the bezel's outer edge on the diagonal, not off the glass: with a
	# painted rim 1.45 radii wide, the old offset put the readout inside the
	# magnified circle, on top of whatever the guardian was aiming at.
	var furniture := r * BEZEL_SCALE * 0.5
	var label_pos := _clamp_to_screen(
		c + Vector2(furniture * 0.80, -furniture * 0.80), Vector2(34, 20))
	var box := Rect2(label_pos - Vector2(31, 18), Vector2(62, 32))
	DrawUtil.rounded_rect(self, box, 9.0, Color(0.04, 0.08, 0.12, 0.85 * a))
	draw_arc(box.get_center(), 17.0, 0.0, TAU, 28,
		Color(accent.r, accent.g, accent.b, 0.55 * a), 2.0, true)
	draw_string(font, label_pos + Vector2(-24, 6), label, HORIZONTAL_ALIGNMENT_CENTER, 48, 17,
		Color(1, 1, 1, a))

	# Ammo strip: how many shots the current gauge affords (see SniperAbility).
	var owner_guardian: Guardian = scope.guardian
	if owner_guardian != null:
		_draw_ammo(c, r, a, font)

## The supplied optic: a glowing rim around the magnified circle and the reticle
## inside it. Both are drawn centred rather than stretched -- they are round, and
## squashing a reticle is immediately obvious.
##
## The rim is drawn larger than the magnified circle so its inner glow overlaps
## the edge of the glass, which is what hides the hard cut the mask shader
## leaves there. The factor is set by the art, not by taste: see the note on
## Balance.SCOPE_RADIUS.
const BEZEL_SCALE := 2.90
func _painted_optic(c: Vector2, r: float, a: float) -> bool:
	var rim := Art.tex("scope_ring")
	if not Balance.USE_TEXTURES or rim == null:
		return false
	var d := r * BEZEL_SCALE
	var tint := Color(1, 1, 1, a)
	draw_texture_rect(rim, Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), false, tint)
	var cross := Art.tex("crosshair")
	if cross != null:
		# Sized off the rim rather than fixed, so it stays proportional while
		# the scope is still opening.
		var cd := r * 1.15
		draw_texture_rect(cross, Rect2(c - Vector2(cd, cd) * 0.5, Vector2(cd, cd)), false, tint)
	return true

## The original vector optic, kept as the fallback for USE_TEXTURES off.
func _vector_optic(c: Vector2, r: float, a: float, accent: Color) -> void:
	draw_arc(c, r + 7.0, 0.0, TAU, 96, Color(0.04, 0.07, 0.10, 0.85 * a), 14.0, true)
	draw_arc(c, r, 0.0, TAU, 96, Color(accent.r, accent.g, accent.b, 0.95 * a), 2.5, true)
	draw_arc(c, r + 15.0, 0.0, TAU, 96, Color(accent.r, accent.g, accent.b, 0.25 * a), 1.5, true)

	# Crosshair with a gap at the centre so the target stays visible.
	var gap := 16.0
	var line := Color(0.06, 0.09, 0.12, 0.9 * a)
	draw_line(c + Vector2(-r, 0), c + Vector2(-gap, 0), line, 2.0)
	draw_line(c + Vector2(gap, 0), c + Vector2(r, 0), line, 2.0)
	draw_line(c + Vector2(0, -r), c + Vector2(0, -gap), line, 2.0)
	draw_line(c + Vector2(0, gap), c + Vector2(0, r), line, 2.0)

	# Graduations along the vertical stadia, as in the mockup.
	for i in range(1, 7):
		var t := float(i) / 7.0
		var y := t * r
		var w := 9.0 if i % 2 == 0 else 5.0
		draw_line(c + Vector2(-w, y), c + Vector2(w, y), line, 1.6)
		draw_line(c + Vector2(-w, -y), c + Vector2(w, -y), line, 1.6)
		var x := t * r
		draw_line(c + Vector2(x, -w * 0.6), c + Vector2(x, w * 0.6), line, 1.4)
		draw_line(c + Vector2(-x, -w * 0.6), c + Vector2(-x, w * 0.6), line, 1.4)

	draw_circle(c, 3.2, Color(0.9, 0.16, 0.2, a))

## Keeps a piece of optic furniture inside the viewport, with `pad` of margin.
func _clamp_to_screen(point: Vector2, pad: Vector2) -> Vector2:
	var view := size
	return Vector2(
		clampf(point.x, pad.x + 12.0, view.x - pad.x - 150.0),
		clampf(point.y, pad.y + 12.0, view.y - pad.y - 24.0))

func _draw_ammo(c: Vector2, r: float, a: float, font: Font) -> void:
	var rounds: int = (scope.guardian as Guardian).ammo()
	var cap: int = Balance.SNIPE_AMMO_DISPLAY_CAP
	# Below the rim by default, above it when below would drop the strip into the
	# ability bar along the bottom of the screen -- the guardian's own ammo count
	# should not be the thing their own HUD hides.
	var rim := r * BEZEL_SCALE * 0.5
	var below := c + Vector2(-58.0, rim + 26.0)
	if below.y > size.y * 0.72:
		below = c + Vector2(-58.0, -rim - 32.0)
	var origin := _clamp_to_screen(below, Vector2(14, 22))
	var box := Rect2(origin - Vector2(12, 18), Vector2(156, 36))
	DrawUtil.rounded_rect(self, box, 9.0, Color(0.04, 0.08, 0.12, 0.82 * a))
	for i in range(cap):
		var x := origin.x + 8.0 + float(i) * 20.0
		var lit := i < rounds
		var tint := Color(1, 1, 1, a) if lit else Color(1, 1, 1, 0.20 * a)
		# The painted cartridge is the piece that actually varies with the gauge.
		if Art.draw_sprite(self, "cartridge", Vector2(x, origin.y + 9.0), 26.0, false, tint):
			continue
		DrawUtil.rounded_rect(self, Rect2(x - 4.0, origin.y - 9.0, 8.0, 15.0), 2.5, tint)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 4.0, origin.y - 9.0), Vector2(x + 4.0, origin.y - 9.0),
			Vector2(x, origin.y - 16.0),
		]), tint)
	draw_string(font, origin + Vector2(78.0, 6.0), "%d/%d" % [rounds, cap],
		HORIZONTAL_ALIGNMENT_LEFT, 64, 17, Color(1, 1, 1, a))
