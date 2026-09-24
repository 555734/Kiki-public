extends Control
## All HUD painting. Kept in one _draw() so the whole overlay is a single
## CanvasItem -- on mobile, a dozen separate Control nodes each with their own
## draw call is a real cost for something that changes every frame anyway.

## Typed loosely on purpose: Hud preloads this script, so naming the Hud class
## here would close a compile-time cycle and knock out type inference in both.
var hud: Node = null

const NAVY := Color(0.05, 0.10, 0.16, 0.82)
const NAVY_EDGE := Color(0.31, 0.85, 1.0, 0.85)

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
	_player_panels()
	_stage_plate(view)
	# The ability bar is the guardian's control, not a readout: on the runner's
	# device none of it responds, so it is not drawn there. The shared gauge the
	# runner does need is already on the P2 panel above.
	if hub == null or hub.owns_guardian_controls():
		_ability_bar(view)
	if hub != null and hub.stick_visual().get("touch_mode", false):
		_touch_controls(view)
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

# ------------------------------------------------------------------- panels

## The angled plate from the mockups: a parallelogram with a portrait inset.
func _plate(origin: Vector2, w: float, h: float, accent: bool) -> PackedVector2Array:
	var skew := Hud.SKEW
	var pts := PackedVector2Array([
		origin,
		origin + Vector2(w, 0),
		origin + Vector2(w - skew, h),
		origin + Vector2(0, h),
	])
	draw_colored_polygon(pts, NAVY)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, NAVY_EDGE if accent else Color(0.55, 0.68, 0.8, 0.5),
		2.0 if accent else 1.4)
	return pts

func _player_panels() -> void:
	var font := Art.font()
	var w := Hud.PANEL_W
	var h := Hud.PANEL_H

	# --- P1: LIRA, hearts ---
	var p1 := Vector2(16, 14)
	_plate(p1, w, h, false)
	_portrait(p1 + Vector2(5, 5), h - 10.0, true)
	draw_string(font, p1 + Vector2(h + 6, 22), "P1", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.42, 0.82, 1.0))
	draw_string(font, p1 + Vector2(h + 30, 22), "LIRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
		Color(1, 1, 1, 0.95))
	for i in range(Balance.RUNNER_MAX_HP):
		var current_hp: int = hud.hp()
		_heart(p1 + Vector2(h + 10.0 + float(i) * 26.0, 38.0), 9.0, i < current_hp)

	# --- P2: ORION, support gauge (see the class comment for why not hearts) ---
	var p2 := Vector2(30, 14 + h + 8.0)
	_plate(p2, w, h, true)
	_portrait(p2 + Vector2(5, 5), h - 10.0, false)
	draw_string(font, p2 + Vector2(h + 6, 22), "P2", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.42, 0.82, 1.0))
	draw_string(font, p2 + Vector2(h + 30, 22), "ORION", HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
		Color(1, 1, 1, 0.95))
	_platform_pips(p2 + Vector2(h + 10, 32.0))

## The points gauge is gone; what the guardian needs to know instead is how
## many of their two platforms are still to place before the oldest is taken.
func _platform_pips(at: Vector2) -> void:
	var font := Art.font()
	var alive := 0
	if hud.guardian != null and is_instance_valid(hud.guardian):
		alive = hud.guardian.holograms_of(Hologram.Kind.PLATFORM).size()
	draw_string(font, at + Vector2(0, 11), "足場", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.75, 0.9, 1.0, 0.9))
	for i in Balance.PLATFORM_MAX_ALIVE:
		var c := at + Vector2(46.0 + float(i) * 26.0, 6.0)
		var ready := i < Balance.PLATFORM_MAX_ALIVE - alive
		DrawUtil.rounded_rect(self, Rect2(c - Vector2(10, 5), Vector2(20, 10)), 3.0,
			Color(0.42, 0.85, 1.0, 0.95) if ready else Color(0.2, 0.3, 0.4, 0.8))

func _portrait(at: Vector2, s: float, is_runner: bool) -> void:
	var r := Rect2(at, Vector2(s, s))
	DrawUtil.rounded_rect(self, r, 6.0, Color(0.09, 0.16, 0.24, 0.95))
	if Art.draw_stretched(self, "portrait_lira" if is_runner else "portrait_orion", r):
		draw_rect(r, Color(0.31, 0.85, 1.0, 0.5), false, 1.5)
		return
	var c := r.get_center()
	if is_runner:
		draw_circle(c + Vector2(0, 2), s * 0.30, Balance.C_SKIN)
		draw_circle(c + Vector2(0, -3), s * 0.30, Balance.C_HAIR)
		draw_rect(Rect2(c.x - s * 0.30, c.y - 4.0, s * 0.60, 4.0), Balance.C_HAIR)
		draw_circle(c + Vector2(-s * 0.10, s * 0.04), 2.0, Color("2a1f18"))
		draw_circle(c + Vector2(s * 0.10, s * 0.04), 2.0, Color("2a1f18"))
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-s * 0.34, s * 0.20), c + Vector2(s * 0.34, s * 0.20),
			c + Vector2(s * 0.30, s * 0.42), c + Vector2(-s * 0.30, s * 0.42),
		]), Balance.C_SCARF)
	else:
		# ORION: a hood with two cold points of light, as in the mockups.
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -s * 0.38), c + Vector2(s * 0.34, s * 0.06),
			c + Vector2(s * 0.26, s * 0.42), c + Vector2(-s * 0.26, s * 0.42),
			c + Vector2(-s * 0.34, s * 0.06),
		]), Color("2c3a63"))
		draw_circle(c + Vector2(0, s * 0.04), s * 0.22, Color("101828"))
		draw_circle(c + Vector2(-s * 0.09, s * 0.02), 2.6, Balance.C_ACCENT)
		draw_circle(c + Vector2(s * 0.09, s * 0.02), 2.6, Balance.C_ACCENT)
	draw_rect(r, Color(0.31, 0.85, 1.0, 0.5), false, 1.5)

func _heart(at: Vector2, r: float, filled: bool) -> void:
	if Art.tex("heart") != null:
		var tint := Color(1, 1, 1, 1) if filled else Color(0.30, 0.33, 0.40, 0.85)
		if Art.draw_sprite(self, "heart", at + Vector2(0.0, r * 1.15), r * 2.4, false, tint):
			return
	var col := Balance.C_HEART if filled else Color(0.25, 0.28, 0.34, 0.75)
	draw_circle(at + Vector2(-r * 0.42, -r * 0.22), r * 0.58, col)
	draw_circle(at + Vector2(r * 0.42, -r * 0.22), r * 0.58, col)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-r * 0.96, -r * 0.02), at + Vector2(r * 0.96, -r * 0.02),
		at + Vector2(0, r * 1.05),
	]), col)
	if filled:
		draw_circle(at + Vector2(-r * 0.45, -r * 0.38), r * 0.20, Color(1, 1, 1, 0.55))

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
		"%s   %s" % [Stage.stage_number(), Stage.stage_name()],
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

## Scales a colour's alpha only, so a panel fades without shifting hue.
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
func _ability_bar(view: Vector2) -> void:
	var hub: InputHub = hud.input_hub
	var mirrored := hub != null and not hub.runner_on_left
	var mode := hub.layout_mode() if hub != null else "shared"
	var places := ControlLayout.layout(mode, view, mirrored)
	var meta := {
		1: {"name": "足場", "cost": Balance.COST_PLATFORM, "icon": "icon_platform"},
		3: {"name": "狙撃", "cost": Balance.COST_SNIPE, "icon": "icon_snipe"},
	}
	for slot in meta:
		var place: Dictionary = places.get("slot_%d" % slot, {})
		if place.is_empty():
			continue
		var item: Dictionary = meta[slot]
		# The chosen tool stays lit: it decides what a finger on the world does
		# (draw a platform, or shoot).
		var held: bool = (hub != null and hub.held_slot() == slot) \
			or (hud.guardian != null and is_instance_valid(hud.guardian) and hud.guardian.active_slot == slot)
		_ability_button(place["center"], float(place["radius"]), slot,
			String(item["name"]), float(item["cost"]), String(item["icon"]), held)

	# The two that are not tools: take one back, and point at something. Drawn
	# smaller and plainer, because neither costs anything and neither should
	# compete for the thumb with the things that do.
	var undo: Dictionary = places.get("undo", {})
	if not undo.is_empty():
		_round_button(undo["center"], float(undo["radius"]), "取消", false)
	var ping: Dictionary = places.get("ping", {})
	if not ping.is_empty():
		_round_button(ping["center"], float(ping["radius"]), "ここ", false)

	var axis: float = hub.pan_axis if hub != null else 0.0
	for id in ["pan_left", "pan_right"]:
		var look: Dictionary = places.get(id, {})
		if look.is_empty():
			continue
		var forward: bool = String(id) == "pan_right"
		_look_button(look["center"], float(look["radius"]), forward,
			axis > 0.1 if forward else axis < -0.1)

## "Look along the stage." Held, not tapped, and drawn as a plain arrow: it
## moves the camera and nothing else, which is the one guardian control that
## costs no gauge and changes nothing in the world.
func _look_button(centre: Vector2, radius: float, forward: bool, lit: bool) -> void:
	var accent := Balance.C_ACCENT
	draw_circle(centre, radius, Color(0.04, 0.09, 0.14, 0.52))
	if lit:
		draw_circle(centre, radius, Color(accent.r, accent.g, accent.b, 0.22))
	draw_arc(centre, radius, 0.0, TAU, 40,
		Color(accent.r, accent.g, accent.b, 0.95 if lit else 0.60),
		3.0 if lit else 2.2, true)
	var d := 1.0 if forward else -1.0
	var w := radius * 0.42
	for i in range(2):
		if Stage.is_skyward_ruins():
			# Positive pan is forward; in this stage forward is visually up.
			var up := -d
			var y := centre.y + up * (w * 0.30 + float(i) * w * 0.58) - up * w * 0.30
			draw_colored_polygon(PackedVector2Array([
				Vector2(centre.x, y + up * w * 0.55),
				Vector2(centre.x - w * 0.62, y - up * w * 0.20),
				Vector2(centre.x + w * 0.62, y - up * w * 0.20),
			]), Color(1, 1, 1, 0.92 if lit else 0.72))
		else:
			var x := centre.x + d * (w * 0.30 + float(i) * w * 0.58) - d * w * 0.30
			draw_colored_polygon(PackedVector2Array([
				Vector2(x + d * w * 0.55, centre.y),
				Vector2(x - d * w * 0.20, centre.y - w * 0.62),
				Vector2(x - d * w * 0.20, centre.y + w * 0.62),
			]), Color(1, 1, 1, 0.92 if lit else 0.72))

## One tool. Lit while a thumb is holding it, because holding it is aiming with
## it and the player needs to see which one they have.
##
## Icon inside, cost inside, nothing outside. The first version wrote the name
## above and the cost below, and on the right-hand arc both ran off the edge of
## the screen and into each other -- the buttons nearest the edge are exactly
## the ones with no room beside them. The reference layouts this follows have
## no text on the buttons at all; the names live in the layout editor, where
## there is room and where you are looking for them.
func _ability_button(centre: Vector2, radius: float, slot: int, label: String,
		cost: float, icon: String, held: bool) -> void:
	var font := Art.font()
	var accent := Balance.C_ACCENT
	var affordable: bool = hud.gauge() >= cost
	var dim := 1.0 if affordable else 0.40
	var pulse: float = hud.slot_pulse(slot)

	# The rifle is not a fourth tool, it is the FIRE button, and it should not
	# take a moment's reading to find among three identical circles. Bigger and
	# warm, where every shooter puts it. "Which one shoots" should be answerable
	# from the corner of the eye.
	var fire := slot == 3
	if fire:
		accent = Color(1.0, 0.46, 0.34)
	if held or pulse > 0.0:
		draw_circle(centre, radius * (1.14 + pulse * 0.10),
			Color(accent.r, accent.g, accent.b, 0.20 + pulse * 0.25))
	draw_circle(centre, radius,
		Color(0.16, 0.06, 0.05, 0.58) if fire else Color(0.04, 0.09, 0.14, 0.52))
	draw_arc(centre, radius, 0.0, TAU, 44,
		Color(accent.r, accent.g, accent.b, (0.95 if held else 0.78) * dim),
		3.6 if (held or fire) else 2.4, true)

	# Fitted, not sized by height: a wide icon sized by height spills out of a
	# circle. Lifted slightly so the cost has the bottom of the button.
	if not Art.draw_sprite_fit(self, icon, centre - Vector2(0.0, radius * 0.12),
			radius * 1.18, Color(1, 1, 1, dim)):
		draw_string(font, centre + Vector2(-radius, radius * 0.18), label,
			HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, int(radius * 0.5),
			Color(1, 1, 1, dim))

	# The cost, inside the ring along the bottom. It is the constraint the whole
	# design rests on, so it stays on screen even when the name does not.
	var text := int(clampf(radius * 0.40, 11.0, 18.0))
	draw_string(font, centre + Vector2(-radius, radius * 0.74),
		"%d" % int(cost) if cost > 0.0 else label,
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, text,
		Color(accent.r, accent.g, accent.b, 0.95 if affordable else 0.45))

func _ability_labels(box: Rect2, c: Vector2, slot: int, label: String, cost: float,
		affordable: bool, accent: Color, dim: float) -> void:
	var font := Art.font()
	# Key badge
	var badge := Rect2(c.x - 9.0, box.position.y + box.size.y + 4.0, 18.0, 17.0)
	DrawUtil.rounded_rect(self, badge, 4.0, Color(0.09, 0.17, 0.25, 0.95))
	draw_rect(badge, Color(accent.r, accent.g, accent.b, 0.55), false, 1.2)
	draw_string(font, badge.position + Vector2(5.0, 13.0), str(slot),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.9))
	draw_string(font, Vector2(c.x - 44.0, badge.position.y + 33.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, 88, 14, Color(1, 1, 1, 0.9 * dim))
	# Cost, in place of the mockups' infinity symbol: it is the constraint the
	# whole design rests on, so it belongs on screen.
	draw_string(font, Vector2(c.x - 44.0, badge.position.y + 49.0), "%d" % int(cost),
		HORIZONTAL_ALIGNMENT_CENTER, 88, 13,
		Color(accent.r, accent.g, accent.b, 0.95 if affordable else 0.4))

# ------------------------------------------------------------ touch controls

func _touch_controls(view: Vector2) -> void:
	var hub: InputHub = hud.input_hub
	var mirrored := not hub.runner_on_left
	if hub.owns_guardian_controls():
		_scope_button(view, mirrored)
	if not hub.owns_runner_controls():
		return
	var stick: Dictionary = hub.stick_visual()

	# Drawn from ControlLayout, the same geometry the router hit-tests and the
	# layout editor moves, so what the player sees is exactly what responds.
	var cluster := hub.cluster(view)
	var place: Dictionary = cluster.get("stick", {})
	if place.is_empty():
		return
	var anchor: Vector2 = place["center"]
	var ring: float = place["radius"]
	var travel: float = ControlLayout.stick_travel(place)
	var axis: float = stick["axis"]
	var live: bool = stick["active"]
	# The idle pad used to sit at 0.58 and nearly vanished over bright grass and
	# brickwork, which is half of what "I cannot tell what to press" means.
	var alpha := 1.0 if live else 0.78
	var accent := Color(0.31, 0.85, 1.0)

	# Ring
	draw_circle(anchor, ring, Color(0.04, 0.09, 0.14, 0.42 * alpha))
	draw_arc(anchor, ring, 0.0, TAU, 48, Color(1, 1, 1, 0.40 * alpha), 3.0, true)
	# Direction chevrons: this is a side-scroller, so back and forward are the
	# whole vocabulary and they should be readable without looking down.
	for side in [-1.0, 1.0]:
		var d := anchor + Vector2(side * ring * 0.66, 0.0)
		draw_colored_polygon(PackedVector2Array([
			d + Vector2(side * ring * 0.20, 0.0),
			d + Vector2(-side * ring * 0.10, -ring * 0.20),
			d + Vector2(-side * ring * 0.10, ring * 0.20),
		]), Color(1, 1, 1, 0.62 * alpha))
	draw_arc(anchor, ring * 0.16, 0.0, TAU, 20, Color(1, 1, 1, 0.34 * alpha), 2.0, true)

	# The upper arc is the jump zone: push the thumb up past it and the runner
	# jumps, so one thumb can hold a direction and jump at the same time.
	if Options.stick_jump():
		var jumping: bool = stick.get("jumping", false)
		var jump_y := anchor.y - travel * ControlLayout.STICK_JUMP_FRACTION
		var jump_col := Color(accent.r, accent.g, accent.b, (0.95 if jumping else 0.55) * alpha)
		draw_arc(anchor, travel * ControlLayout.STICK_JUMP_FRACTION, PI * 1.18, PI * 1.82, 24,
			jump_col, 3.5 if jumping else 2.2, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(anchor.x, jump_y - ring * 0.20),
			Vector2(anchor.x - ring * 0.13, jump_y - ring * 0.04),
			Vector2(anchor.x + ring * 0.13, jump_y - ring * 0.04),
		]), jump_col)
		if jumping:
			draw_circle(anchor + Vector2(0, -travel * 0.75), ring * 0.10,
				Color(accent.r, accent.g, accent.b, 0.55))

	# Knob, following the thumb in both axes so the jump zone is aimable.
	var knob := anchor + Vector2(axis * (-1.0 if mirrored else 1.0) * travel, 0.0)
	if live:
		var thumb: Vector2 = stick["thumb"]
		knob.y = clampf(thumb.y, anchor.y - travel, anchor.y + travel * 0.4)
	var knob_r := ring * 0.40
	draw_circle(knob, knob_r, Color(1, 1, 1, 0.32 * alpha))
	draw_arc(knob, knob_r, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.9 * alpha), 3.5, true)
	if live:
		draw_circle(knob, knob_r * 0.34, Color(accent.r, accent.g, accent.b, 0.8))

	# The one action button. There is no SPRINT button: on a touch screen the
	# runner always runs at full speed (Options.auto_dash).
	var button: Dictionary = cluster.get("jump", {})
	if not button.is_empty():
		_round_button(button["center"], float(button["radius"]), "JUMP", false)
	# The runner's one way of saying something. Marks where they are.
	var say: Dictionary = cluster.get("ping", {})
	if not say.is_empty():
		_round_button(say["center"], float(say["radius"]), "ここ", false)

## A labelled round action button, in the style a mobile shooter uses.
func _round_button(centre: Vector2, radius: float, label: String, lit: bool) -> void:
	var accent := Color(0.31, 0.85, 1.0)
	draw_circle(centre, radius, Color(0.04, 0.09, 0.14, 0.62 if lit else 0.52))
	if lit:
		draw_circle(centre, radius, Color(accent.r, accent.g, accent.b, 0.22))
	draw_arc(centre, radius, 0.0, TAU, 44,
		Color(accent.r, accent.g, accent.b, 0.95 if lit else 0.78), 3.0, true)
	var font := Art.font()
	var size := int(clampf(radius * 0.34, 11.0, 22.0))
	draw_string(font, centre + Vector2(-radius, float(size) * 0.36), label,
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size, Color(1, 1, 1, 0.92))

## The optic toggle. Lit while the scope is up, because it is the one guardian
## control that is a STATE rather than an action -- everything else happens and
## is over, and a button that latches has to say so.
func _scope_button(view: Vector2, mirrored: bool) -> void:
	var hub: InputHub = hud.input_hub
	var mode := hub.layout_mode() if hub != null else "shared"
	var place: Dictionary = ControlLayout.layout(mode, view, mirrored).get("scope", {})
	if place.is_empty():
		return
	var up: bool = hud.scope_up()
	var c: Vector2 = place["center"]
	var r: float = float(place["radius"])
	var accent := Balance.C_ACCENT
	draw_circle(c, r, Color(0.04, 0.09, 0.14, 0.62 if up else 0.45))
	if up:
		draw_circle(c, r, Color(accent.r, accent.g, accent.b, 0.26))
	draw_arc(c, r, 0.0, TAU, 40,
		Color(accent.r, accent.g, accent.b, 0.95 if up else 0.6), 3.0 if up else 2.4, true)
	var glyph := Color(1, 1, 1, 0.95 if up else 0.72)
	draw_arc(c, r * 0.46, 0.0, TAU, 28, glyph, 2.4, true)
	for i in range(4):
		var a := float(i) * PI * 0.5
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * r * 0.62, c + d * r * 0.86, glyph, 2.2)
	draw_circle(c, 2.4, Color(0.92, 0.24, 0.28, glyph.a))
	# No caption. It sits at the top of the right-hand arc where a label would
	# collide with the button below it, and the crosshair glyph says what it is.

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
		draw_string(font, Vector2(0, c.y + 70.0), "やったね！ ふたりでゴール！",
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

