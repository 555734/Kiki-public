class_name ControlLayout
extends RefCounted
## Where every on-screen control is, and where the player has decided it should
## be instead.
##
## One source of truth for three things that used to disagree: what the input
## router hit-tests, what the HUD draws, and what the layout editor moves. If
## they are computed in different places they drift, and a control you can see
## but cannot press is the worst kind of bug to be told about.
##
## Everything is ROUND and everything is placed relative to the corner the thumb
## pivots around, in units of the screen HEIGHT. Fractions of the width were the
## old way and they put a button half off the edge as soon as the aspect ratio
## changed -- at 4:3 an x of 0.945 is past the right edge with a 0.075 radius,
## which is exactly the kind of thing that only shows up on somebody else's
## phone. Hugging the corner in height-units holds at every shape of screen.
##
## The reference is how a mobile shooter does it: a stick under the left thumb,
## and the actions on an arc the right thumb sweeps without the hand moving.

const PATH := "user://controls.cfg"

## Which set of controls this device is showing.
##   shared   -- two people, one screen: runner keeps the left edge
##   runner   -- the runner alone, both thumbs
##   guardian -- the guardian alone, both thumbs
const MODES := ["shared", "runner", "guardian"]

## Fraction of the width reserved for the runner when the screen is shared.
const DIVIDER: float = 0.30

static var _overrides: Dictionary = {}
static var _loaded: bool = false

# --------------------------------------------------------------- the defaults
#
# Offsets from the bottom-RIGHT corner, in units of the screen height, as
# (dx, dy, radius). The arc runs from the corner up the right-hand edge, which
# is the path a right thumb takes.
## Sharing one screen, the guardian only has the right-hand side of it -- the
## other player's hands are on the left -- so everything stays on one arc.
##
## There are no buttons for moving the view. There were, and holding one down
## was the only way to look at anything, which is tiring in exactly the way a
## button held down is always tiring. Swiping the world scrolls it instead --
## the gesture a finger on a map already makes -- so the two buttons are gone
## and the screen is quieter for it. The keyboard keys still exist for desktop.
const GUARDIAN_ARC := {
	"slot_1": Vector3(0.26, 0.24, 0.080),
	"slot_2": Vector3(0.09, 0.40, 0.070),
	"slot_4": Vector3(0.46, 0.115, 0.070),
	"slot_3": Vector3(0.225, 0.52, 0.100),
	"scope":  Vector3(0.09, 0.72, 0.072),
}

## Alone on a device the guardian has TWO thumbs, so the controls belong under
## both of them rather than stacked up one edge. Building goes to the left hand
## and looking goes to the right, which also means the hand that scrolls the
## view is not the hand holding a tool.
const GUARDIAN_LEFT := {
	"slot_1":   Vector3(0.26, 0.24, 0.082),
	"slot_2":   Vector3(0.145, 0.46, 0.072),
	"undo":     Vector3(0.40, 0.10, 0.058),
}
const GUARDIAN_RIGHT := {
	"slot_3":    Vector3(0.255, 0.235, 0.108),
	"slot_4":    Vector3(0.145, 0.46, 0.072),
	"scope":     Vector3(0.30, 0.60, 0.074),
	"ping":      Vector3(0.42, 0.10, 0.058),
}

## The runner alone has the whole screen, so their actions go to the far corner
## and are held with the other thumb.
const RUNNER_SOLO := {
	"jump":   Vector3(0.22, 0.20, 0.105),
	"sprint": Vector3(0.47, 0.42, 0.085),
	"ping":   Vector3(0.44, 0.12, 0.058),
}

## Sharing a screen, the runner's actions cannot go to the far corner -- that is
## the guardian's arc -- so they stand beside the stick, and the WHOLE cluster
## has to fit left of the divider. Everything below is in units of the stick's
## own radius, so the cluster scales as one piece: mixing width-relative
## positions with height-relative radii looked right at 16:9 and had the stick
## and the jump button fighting for the same pixels at 4:3.
const SHARED_MARGIN := 0.25
const SHARED_GAP := 0.30
const JUMP_R := 0.58
const SPRINT_R := 0.48

## The stick, as a fraction of the height from the bottom-LEFT corner.
const STICK := Vector3(0.21, 0.24, 0.150)
const STICK_CAPTURE := 1.15
const STICK_TRAVEL_FRACTION := 0.80
const STICK_DEADZONE_FRACTION := 0.11
const STICK_JUMP_FRACTION := 0.52

## A tiny visual/touch buffer inside Apple's reported safe rectangle. The safe
## area is already conservative; this just keeps anti-aliased rings off its edge.
const SAFE_PAD := 4.0

# ------------------------------------------------------------------- the API

## Every control for `mode`, as id -> {center, radius, kind}.
##
## `mirrored` swaps the two halves when the players trade seats.
static func layout(mode: String, view: Vector2, mirrored: bool = false) -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	var u := view.y
	var right := Vector2(view.x, view.y)
	var left := Vector2(0.0, view.y)

	if mode != "guardian":
		if mode == "runner":
			out["stick"] = {
				"center": Vector2(left.x + STICK.x * u, left.y - STICK.y * u),
				"radius": STICK.z * u,
				"kind": "stick",
			}
			for id in RUNNER_SOLO:
				var d: Vector3 = RUNNER_SOLO[id]
				out[id] = {"center": Vector2(right.x - d.x * u, right.y - d.y * u),
					"radius": d.z * u, "kind": "button"}
		else:
			out.merge(_shared_runner(view))

	if mode == "guardian":
		for id in GUARDIAN_LEFT:
			var d: Vector3 = GUARDIAN_LEFT[id]
			out[id] = {"center": Vector2(left.x + d.x * u, left.y - d.y * u),
				"radius": d.z * u, "kind": "button"}
		for id in GUARDIAN_RIGHT:
			var d: Vector3 = GUARDIAN_RIGHT[id]
			out[id] = {"center": Vector2(right.x - d.x * u, right.y - d.y * u),
				"radius": d.z * u, "kind": "button"}
	elif mode == "shared":
		for id in GUARDIAN_ARC:
			var d: Vector3 = GUARDIAN_ARC[id]
			out[id] = {"center": Vector2(right.x - d.x * u, right.y - d.y * u),
				"radius": d.z * u, "kind": "button"}

	# The player's own positions and sizes win over every default above.
	for id in out.keys():
		var saved: Vector3 = saved_place(mode, String(id))
		if saved.x >= 0.0:
			out[id]["center"] = Vector2(saved.x * view.x, saved.y * view.y)
		if saved.z > 0.0:
			out[id]["radius"] = float(out[id]["radius"]) * saved.z
		if mirrored:
			out[id]["center"].x = view.x - out[id]["center"].x

	# iPhone screens can have a Dynamic Island/notch on a side in landscape and
	# the home indicator along the bottom. Apple/Godot report the unobscured
	# rectangle in display pixels; convert that rectangle into this viewport's
	# coordinate system, then keep the complete touch target inside it. Doing it
	# here keeps drawing, hit-testing and the layout editor in perfect agreement.
	if OS.get_name() == "iOS":
		_clamp_layout_to_safe_area(out, _ios_safe_rect(view))
	return out

## Convert Godot's display-pixel safe rectangle to the current canvas/view size.
## `aspect=expand` preserves the same aspect ratio, so independent x/y fractions
## correctly account for Retina resolution and different iPhone dimensions.
static func _ios_safe_rect(view: Vector2) -> Rect2:
	var safe_i := DisplayServer.get_display_safe_area()
	var screen_i := DisplayServer.screen_get_size()
	if safe_i.size.x <= 0 or safe_i.size.y <= 0 or screen_i.x <= 0 or screen_i.y <= 0:
		return Rect2(Vector2.ZERO, view)
	var sx := view.x / float(screen_i.x)
	var sy := view.y / float(screen_i.y)
	return Rect2(Vector2(float(safe_i.position.x) * sx, float(safe_i.position.y) * sy),
		Vector2(float(safe_i.size.x) * sx, float(safe_i.size.y) * sy))

## Keep an entire circular control inside the safe rectangle. The virtual stick
## captures touches beyond its visible ring, so its larger capture radius is the
## extent that matters, not the painted radius.
static func _clamp_layout_to_safe_area(places: Dictionary, safe: Rect2) -> void:
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return
	for id in places.keys():
		var place: Dictionary = places[id]
		var radius := float(place["radius"])
		var extent := radius * (STICK_CAPTURE if place["kind"] == "stick" else 1.0) + SAFE_PAD
		var lo := safe.position + Vector2(extent, extent)
		var hi := safe.end - Vector2(extent, extent)
		# This should never happen on a phone, but a huge user-resized control on
		# an extremely narrow view should still land somewhere deterministic.
		if lo.x > hi.x:
			lo.x = safe.get_center().x
			hi.x = lo.x
		if lo.y > hi.y:
			lo.y = safe.get_center().y
			hi.y = lo.y
		var c: Vector2 = place["center"]
		place["center"] = Vector2(clampf(c.x, lo.x, hi.x), clampf(c.y, lo.y, hi.y))
		places[id] = place

## The runner's half of a shared screen, sized from the space it has rather than
## from the screen height. At 4:3 the divider is only 288px from the left edge,
## and a stick sized off the height alone does not leave room for a button.
static func _shared_runner(view: Vector2) -> Dictionary:
	var span := SHARED_MARGIN + STICK_CAPTURE + 1.0 + SHARED_GAP \
		+ 2.0 * JUMP_R + SHARED_MARGIN
	var r := minf(view.y * STICK.z, (DIVIDER * view.x) / span)
	var anchor := Vector2(r * (SHARED_MARGIN + STICK_CAPTURE),
		view.y - r * (SHARED_MARGIN + STICK_CAPTURE))
	var button_x := anchor.x + r * (STICK_CAPTURE + SHARED_GAP + JUMP_R)
	var jump_y := view.y - r * SHARED_MARGIN - r * JUMP_R
	var sprint_y := jump_y - r * JUMP_R - r * SPRINT_R - r * SHARED_GAP
	return {
		"stick": {"center": anchor, "radius": r, "kind": "stick"},
		"jump": {"center": Vector2(button_x, jump_y),
			"radius": r * JUMP_R, "kind": "button"},
		"sprint": {"center": Vector2(button_x, sprint_y),
			"radius": r * SPRINT_R, "kind": "button"},
	}

## Ordered so the router resolves the small, deliberate targets before the big
## catch-all ones. A thumb inside the stick's capture circle that is also on a
## button is pressing the button.
static func hit(mode: String, view: Vector2, mirrored: bool, at: Vector2) -> String:
	var places := layout(mode, view, mirrored)
	var best := ""
	var best_kind := ""
	for id in places:
		var place: Dictionary = places[id]
		if at.distance_to(place["center"]) > float(place["radius"]) \
				* (STICK_CAPTURE if place["kind"] == "stick" else 1.0):
			continue
		if best == "" or (best_kind == "stick" and place["kind"] == "button"):
			best = String(id)
			best_kind = String(place["kind"])
	return best

## (x, y) as fractions of the viewport, and z as a multiplier on the default
## size. x < 0 means "never moved"; z <= 0 means "never resized".
static func saved_place(mode: String, id: String) -> Vector3:
	_ensure_loaded()
	return _overrides.get("%s/%s" % [mode, id], Vector3(-1.0, -1.0, 0.0))

## How much smaller or larger than the default a control may be made. Below the
## floor a thumb misses it; above the ceiling it swallows its neighbours, and
## the layout audit refuses the result anyway.
const SIZE_MIN := 0.60
const SIZE_MAX := 1.80

## `centre` is in fractions of the viewport, so a layout set on one screen is
## the same layout on another.
static func set_place(mode: String, id: String, centre: Vector2) -> void:
	_ensure_loaded()
	var kept: Vector3 = saved_place(mode, id)
	_overrides["%s/%s" % [mode, id]] = Vector3(
		clampf(centre.x, 0.0, 1.0), clampf(centre.y, 0.0, 1.0),
		kept.z if kept.z > 0.0 else 1.0)

static func set_size(mode: String, id: String, scale: float) -> void:
	_ensure_loaded()
	var now: Vector3 = saved_place(mode, id)
	_overrides["%s/%s" % [mode, id]] = Vector3(now.x, now.y,
		clampf(scale, SIZE_MIN, SIZE_MAX))

static func size_of(mode: String, id: String) -> float:
	var now: Vector3 = saved_place(mode, id)
	return now.z if now.z > 0.0 else 1.0

static func reset(mode: String) -> void:
	_ensure_loaded()
	for key in _overrides.keys():
		if String(key).begins_with(mode + "/"):
			_overrides.erase(key)

static func has_custom(mode: String) -> bool:
	_ensure_loaded()
	for key in _overrides.keys():
		if String(key).begins_with(mode + "/"):
			return true
	return false

## Writes the moved and resized controls back, and leaves everything ELSE in the
## file alone.
static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for section in cfg.get_sections():
		for key in cfg.get_section_keys(section):
			if not _overrides.has("%s/%s" % [section, key]):
				cfg.erase_section_key(section, key)
	for key in _overrides.keys():
		var parts := String(key).split("/")
		cfg.set_value(parts[0], parts[1], _overrides[key])
	cfg.save(PATH)

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for section in cfg.get_sections():
		for key in cfg.get_section_keys(section):
			var value = cfg.get_value(section, key)
			if value is Vector2:
				_overrides["%s/%s" % [section, key]] = Vector3(value.x, value.y, 1.0)
			elif value is Vector3:
				_overrides["%s/%s" % [section, key]] = value

## Test seam: start from the defaults, with the saved file ignored.
static func forget() -> void:
	_overrides.clear()
	_loaded = true

## Drop everything held in memory and read the file again on next use.
static func reload() -> void:
	_overrides.clear()
	_loaded = false

# --------------------------------------------------------------- stick detail

static func stick_travel(place: Dictionary) -> float:
	return float(place["radius"]) * STICK_TRAVEL_FRACTION

static func stick_deadzone(place: Dictionary) -> float:
	return stick_travel(place) * STICK_DEADZONE_FRACTION

## A readable name for the layout editor and for failure messages.
static func label(id: String) -> String:
	return {
		"stick": "移動", "jump": "ジャンプ", "sprint": "ダッシュ",
		"slot_1": "足場", "slot_2": "壁", "slot_3": "狙撃", "slot_4": "ワープ",
		"scope": "スコープ", "pan_left": "◀ 見る", "pan_right": "見る ▶",
	}.get(id, id)