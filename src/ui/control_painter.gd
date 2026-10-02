extends RefCounted
class_name ControlPainter
## The touch controls as 1-1 draws them -- the stick with its knob, chevrons
## and jump arc, the JUMP button, the platform and shot buttons with their
## icons and costs -- for anything that shows them: the co-op HUD and the
## star battle's buttons. One painter, so the two cannot drift apart.
##
## `src` is whatever owns the state being drawn, loosely typed: it has
## `input_hub`, `guardian`, gauge(), slot_pulse(slot) and scope_up() (Hud
## does; so does VersusControls).

## Everything a touch player presses, in the order the HUD draws it.
static func draw_controls(ci: CanvasItem, src, view: Vector2) -> void:
	var hub: InputHub = src.input_hub if is_instance_valid(src.input_hub) else null
	if hub == null or hub.owns_guardian_controls():
		ability_bar(ci, src, view)
	if hub != null and hub.stick_visual().get("touch_mode", false):
		touch_controls(ci, src, view)

static func ability_bar(ci: CanvasItem, src, view: Vector2) -> void:
	var hub: InputHub = src.input_hub
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
			or (src.guardian != null and is_instance_valid(src.guardian) and src.guardian.active_slot == slot)
		ability_button(ci, src, place["center"], float(place["radius"]), slot,
			String(item["name"]), float(item["cost"]), String(item["icon"]), held)

	# The two that are not tools: take one back, and point at something. Drawn
	# smaller and plainer, because neither costs anything and neither should
	# compete for the thumb with the things that do.
	var undo: Dictionary = places.get("undo", {})
	if not undo.is_empty():
		round_button(ci, src, undo["center"], float(undo["radius"]), "取消", false)
	var ping: Dictionary = places.get("ping", {})
	if not ping.is_empty():
		round_button(ci, src, ping["center"], float(ping["radius"]), "ここ", false)

	var axis: float = hub.pan_axis if hub != null else 0.0
	for id in ["pan_left", "pan_right"]:
		var look: Dictionary = places.get(id, {})
		if look.is_empty():
			continue
		var forward: bool = String(id) == "pan_right"
		look_button(ci, src, look["center"], float(look["radius"]), forward,
			axis > 0.1 if forward else axis < -0.1)

## "Look along the stage." Held, not tapped, and drawn as a plain arrow: it
## moves the camera and nothing else, which is the one guardian control that
## costs no gauge and changes nothing in the world.
static func look_button(ci: CanvasItem, src, centre: Vector2, radius: float, forward: bool, lit: bool) -> void:
	var accent := Balance.C_ACCENT
	ci.draw_circle(centre, radius, Color(0.04, 0.09, 0.14, 0.52))
	if lit:
		ci.draw_circle(centre, radius, Color(accent.r, accent.g, accent.b, 0.22))
	ci.draw_arc(centre, radius, 0.0, TAU, 40,
		Color(accent.r, accent.g, accent.b, 0.95 if lit else 0.60),
		3.0 if lit else 2.2, true)
	var d := 1.0 if forward else -1.0
	var w := radius * 0.42
	for i in range(2):
		if Stage.progress_direction() == Vector2.UP:
			# Positive pan is forward; in this stage forward is visually up.
			var up := -d
			var y := centre.y + up * (w * 0.30 + float(i) * w * 0.58) - up * w * 0.30
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(centre.x, y + up * w * 0.55),
				Vector2(centre.x - w * 0.62, y - up * w * 0.20),
				Vector2(centre.x + w * 0.62, y - up * w * 0.20),
			]), Color(1, 1, 1, 0.92 if lit else 0.72))
		else:
			var x := centre.x + d * (w * 0.30 + float(i) * w * 0.58) - d * w * 0.30
			ci.draw_colored_polygon(PackedVector2Array([
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
static func ability_button(ci: CanvasItem, src, centre: Vector2, radius: float, slot: int, label: String,
		cost: float, icon: String, held: bool) -> void:
	var font := Art.font()
	var accent := Balance.C_ACCENT
	var affordable: bool = src.gauge() >= cost
	var dim := 1.0 if affordable else 0.40
	var pulse: float = src.slot_pulse(slot)

	# The rifle is not a fourth tool, it is the FIRE button, and it should not
	# take a moment's reading to find among three identical circles. Bigger and
	# warm, where every shooter puts it. "Which one shoots" should be answerable
	# from the corner of the eye.
	var fire := slot == 3
	if fire:
		accent = Color(1.0, 0.46, 0.34)
	if held or pulse > 0.0:
		ci.draw_circle(centre, radius * (1.14 + pulse * 0.10),
			Color(accent.r, accent.g, accent.b, 0.20 + pulse * 0.25))
	ci.draw_circle(centre, radius,
		Color(0.16, 0.06, 0.05, 0.58) if fire else Color(0.04, 0.09, 0.14, 0.52))
	ci.draw_arc(centre, radius, 0.0, TAU, 44,
		Color(accent.r, accent.g, accent.b, (0.95 if held else 0.78) * dim),
		3.6 if (held or fire) else 2.4, true)

	# Fitted, not sized by height: a wide icon sized by height spills out of a
	# circle. Lifted slightly so the cost has the bottom of the button.
	if not Art.draw_sprite_fit(ci, icon, centre - Vector2(0.0, radius * 0.12),
			radius * 1.18, Color(1, 1, 1, dim)):
		ci.draw_string(font, centre + Vector2(-radius, radius * 0.18), label,
			HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, int(radius * 0.5),
			Color(1, 1, 1, dim))

	# The cost, inside the ring along the bottom. It is the constraint the whole
	# design rests on, so it stays on screen even when the name does not.
	var text := int(clampf(radius * 0.40, 11.0, 18.0))
	ci.draw_string(font, centre + Vector2(-radius, radius * 0.74),
		"%d" % int(cost) if cost > 0.0 else label,
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, text,
		Color(accent.r, accent.g, accent.b, 0.95 if affordable else 0.45))

# ------------------------------------------------------------ touch controls

static func touch_controls(ci: CanvasItem, src, view: Vector2) -> void:
	var hub: InputHub = src.input_hub
	var mirrored := not hub.runner_on_left
	if hub.owns_guardian_controls():
		scope_button(ci, src, view, mirrored)
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
	ci.draw_circle(anchor, ring, Color(0.04, 0.09, 0.14, 0.42 * alpha))
	ci.draw_arc(anchor, ring, 0.0, TAU, 48, Color(1, 1, 1, 0.40 * alpha), 3.0, true)
	# Direction chevrons: this is a side-scroller, so back and forward are the
	# whole vocabulary and they should be readable without looking down.
	for side in [-1.0, 1.0]:
		var d := anchor + Vector2(side * ring * 0.66, 0.0)
		ci.draw_colored_polygon(PackedVector2Array([
			d + Vector2(side * ring * 0.20, 0.0),
			d + Vector2(-side * ring * 0.10, -ring * 0.20),
			d + Vector2(-side * ring * 0.10, ring * 0.20),
		]), Color(1, 1, 1, 0.62 * alpha))
	ci.draw_arc(anchor, ring * 0.16, 0.0, TAU, 20, Color(1, 1, 1, 0.34 * alpha), 2.0, true)

	# The upper arc is the jump zone: push the thumb up past it and the runner
	# jumps, so one thumb can hold a direction and jump at the same time.
	if Options.stick_jump():
		var jumping: bool = stick.get("jumping", false)
		var jump_y := anchor.y - travel * ControlLayout.STICK_JUMP_FRACTION
		var jump_col := Color(accent.r, accent.g, accent.b, (0.95 if jumping else 0.55) * alpha)
		ci.draw_arc(anchor, travel * ControlLayout.STICK_JUMP_FRACTION, PI * 1.18, PI * 1.82, 24,
			jump_col, 3.5 if jumping else 2.2, true)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(anchor.x, jump_y - ring * 0.20),
			Vector2(anchor.x - ring * 0.13, jump_y - ring * 0.04),
			Vector2(anchor.x + ring * 0.13, jump_y - ring * 0.04),
		]), jump_col)
		if jumping:
			ci.draw_circle(anchor + Vector2(0, -travel * 0.75), ring * 0.10,
				Color(accent.r, accent.g, accent.b, 0.55))

	# Knob, following the thumb in both axes so the jump zone is aimable.
	var knob := anchor + Vector2(axis * (-1.0 if mirrored else 1.0) * travel, 0.0)
	if live:
		var thumb: Vector2 = stick["thumb"]
		knob.y = clampf(thumb.y, anchor.y - travel, anchor.y + travel * 0.4)
	var knob_r := ring * 0.40
	ci.draw_circle(knob, knob_r, Color(1, 1, 1, 0.32 * alpha))
	ci.draw_arc(knob, knob_r, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.9 * alpha), 3.5, true)
	if live:
		ci.draw_circle(knob, knob_r * 0.34, Color(accent.r, accent.g, accent.b, 0.8))

	# The one action button. There is no SPRINT button: on a touch screen the
	# runner always runs at full speed (Options.auto_dash).
	var button: Dictionary = cluster.get("jump", {})
	if not button.is_empty():
		round_button(ci, src, button["center"], float(button["radius"]), "JUMP", hub.jump_held)
	# The runner's one way of saying something. Marks where they are.
	var say: Dictionary = cluster.get("ping", {})
	if not say.is_empty():
		round_button(ci, src, say["center"], float(say["radius"]), "ここ", false)

## A labelled round action button, in the style a mobile shooter uses.
static func round_button(ci: CanvasItem, src, centre: Vector2, radius: float, label: String, lit: bool) -> void:
	var accent := Color(0.31, 0.85, 1.0)
	ci.draw_circle(centre, radius, Color(0.04, 0.09, 0.14, 0.62 if lit else 0.52))
	if lit:
		ci.draw_circle(centre, radius, Color(accent.r, accent.g, accent.b, 0.22))
	ci.draw_arc(centre, radius, 0.0, TAU, 44,
		Color(accent.r, accent.g, accent.b, 0.95 if lit else 0.78), 3.0, true)
	var font := Art.font()
	var size := int(clampf(radius * 0.34, 11.0, 22.0))
	ci.draw_string(font, centre + Vector2(-radius, float(size) * 0.36), label,
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size, Color(1, 1, 1, 0.92))

## The optic toggle. Lit while the scope is up, because it is the one guardian
## control that is a STATE rather than an action -- everything else happens and
## is over, and a button that latches has to say so.
static func scope_button(ci: CanvasItem, src, view: Vector2, mirrored: bool) -> void:
	var hub: InputHub = src.input_hub
	var mode := hub.layout_mode() if hub != null else "shared"
	var place: Dictionary = ControlLayout.layout(mode, view, mirrored).get("scope", {})
	if place.is_empty():
		return
	var up: bool = src.scope_up()
	var c: Vector2 = place["center"]
	var r: float = float(place["radius"])
	var accent := Balance.C_ACCENT
	ci.draw_circle(c, r, Color(0.04, 0.09, 0.14, 0.62 if up else 0.45))
	if up:
		ci.draw_circle(c, r, Color(accent.r, accent.g, accent.b, 0.26))
	ci.draw_arc(c, r, 0.0, TAU, 40,
		Color(accent.r, accent.g, accent.b, 0.95 if up else 0.6), 3.0 if up else 2.4, true)
	var glyph := Color(1, 1, 1, 0.95 if up else 0.72)
	ci.draw_arc(c, r * 0.46, 0.0, TAU, 28, glyph, 2.4, true)
	for i in range(4):
		var a := float(i) * PI * 0.5
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c + d * r * 0.62, c + d * r * 0.86, glyph, 2.2)
	ci.draw_circle(c, 2.4, Color(0.92, 0.24, 0.28, glyph.a))
	# No caption. It sits at the top of the right-hand arc where a label would
	# collide with the button below it, and the crosshair glyph says what it is.
