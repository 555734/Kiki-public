class_name InputHub
extends Node
## Turns raw device events into *intent*, and nothing else.
##
## Both players share one viewport, so touches have to be routed by screen
## region and tracked per finger. Godot's Control buttons cannot do this: the
## moment the runner holds the stick down, a Control-based ability button on the
## other side of the screen stops receiving the guardian's drag. So we take the
## raw InputEventScreenTouch/Drag stream, key it by finger index, and dispatch
## ourselves. `emulate_mouse_from_touch` is off in project.godot for the same
## reason -- it collapses every finger into one pointer.
##
## Desktop keyboard+mouse fills the exact same intent fields, which is what lets
## the game be iterated on in the editor and shipped to touch unchanged.

## Runner intent
var move_axis: float = 0.0
## Down on the stick. Only one thing reads it -- letting go of a ledge -- but
## that one thing needs a deliberate DOWN rather than "not up", or a runner
## resting their thumb at the bottom of the stick would drop off every edge
## they caught.
var move_axis_y: float = 0.0
## Jump can be held from two places at once, so release history is recorded from
## the aggregate rather than from either source individually. The sequence is
## monotonic: a player jump can remember that its original press was released
## even if the button is pressed again before the minimum-jump window expires.
var jump_held: bool = false
var jump_release_sequence: int = 0
var jump_press_release_sequence: int = 0
var _jump_from_button: bool = false
var _jump_from_stick: bool = false
## Sprint is a held modifier on the ground AND in the air.
## The legacy edge is consumed without triggering a vertical-stopping burst.
var dash_held: bool = false
var _jump_latched: bool = false
var _dash_latched: bool = false

## Guardian intent.
##
## The target is kept in WORLD space, not screen space, and that is not a
## detail. The camera follows the runner, so a reticle pinned to a screen point
## slides across the level while the runner moves: the guardian looks at the
## gap, reaches for a tool, and by the time their thumb lands the target has
## drifted. Aim at a place, not at a pixel.
var aim_point: Vector2 = Vector2.ZERO
## The last screen point a finger put the target at. Kept for the router and for
## tests; it is a record of the gesture, not the authority -- read aim_world().
var aim_screen: Vector2 = Vector2.ZERO
var aim_active: bool = false
var _scope_latched: bool = false
var _slot_latched: int = -1
## The tool button currently under a thumb, and whether that thumb has moved.
## Holding a button is aiming with it; letting go is using it. Nothing is
## "selected" in between -- see press_slot.
var _slot_finger: int = -1
var _slot_held: int = -1
var _slot_dragged: bool = false
## Whether the press being consumed right now came with a drag. Latched with
## the slot so the reader sees the two together.
var _slot_latched_dragged: bool = false
var _zoom_latched: int = 0
var _countdown_latched: bool = false

## True when the runner is on the left half (the default seating).
var runner_on_left: bool = true

## "" offline (two players share the screen and the divider matters), or
## "runner" / "guardian" online, where the local player owns the whole display.
## The touch router consults this before the divider: a runner playing alone
## should not be confined to the left 30% just because a guardian used to sit
## there.
var solo_role: String = ""
## Set by HostSession the first time an aim packet arrives. Until then the
## runner's device has no idea where the guardian is looking, and drawing a
## cursor anyway is what put a frozen platform outline at the top-left corner of
## the runner's screen and let them place constructs there.
var remote_aim: bool = false
## Set by the guardian while the scope is engaged, so the zoom slider is live.
var scope_engaged: bool = false

## -1, 0 or +1 while a "look" button is held. Held rather than latched: this is
## a camera being pushed, not an event.
var pan_axis: float = 0.0
var _pan_fingers: Dictionary = {}   ## finger index -> direction
## Sliding sideways off a look button scrubs the view, so a long look is one
## flick rather than a thumb held down for three seconds. Accumulated here and
## consumed by the camera.
var _pan_drag: float = 0.0
var _pan_drag_from: Dictionary = {}  ## finger index -> last x
## A finger on open ground: where it was last frame, and whether it has
## committed to scrolling rather than aiming.
var _aim_from: Dictionary = {}
var _aim_from_y: Dictionary = {}
var _aim_is_scroll: Dictionary = {}
## How far sideways a finger travels before it counts as a scroll rather than a
## nudge of the reticle. Small enough to feel immediate, large enough that
## placing the reticle precisely never turns into a scroll by accident.
const SCROLL_WAKES_UP := 26.0
## World pixels per screen pixel of swipe. One to one reads as dragging the
## ground itself, which is the gesture everyone already knows.
const SCROLL_SCALE := 1.0
## How much world the view moves per pixel of thumb. Above 1 because the whole
## point is to cover ground without a long drag.
const PAN_DRAG_SCALE := 2.2

var _touch_owner: Dictionary = {}   ## finger index -> role string
var _stick_finger: int = -1
var _stick_position: Vector2 = Vector2.ZERO
var _aim_finger: int = -1
var _zoom_finger: int = -1
var _has_touch: bool = false
## Test seam. When true, _process stops polling the keyboard and mouse, so a
## headless capture or a unit test can write the intent fields directly. Nothing
## in the shipping game sets this.
var scripted: bool = false
## A versus runner always has the stick on the left; global co-op role-swap
## signals must never mirror the versus touch map independently of its HUD.
var force_runner_left: bool = false

func _ready() -> void:
	process_priority = -100
	Events.roles_swapped.connect(_on_roles_swapped)

func _on_roles_swapped(on_left: bool) -> void:
	if not force_runner_left:
		runner_on_left = on_left
	Events.scope_state_changed.connect(func(active: bool, _z: float) -> void: scope_engaged = active)

# ------------------------------------------------------------------- presses
# Edge-triggered inputs go through these so touch, keyboard and tests all take
# the same path into the latch.

func _latch_jump_press() -> void:
	_jump_latched = true
	jump_press_release_sequence = jump_release_sequence

func press_jump() -> void:
	_jump_from_button = true
	_refresh_jump_held()
	_latch_jump_press()

func release_jump() -> void:
	_jump_from_button = false
	_refresh_jump_held()

## Two thumbs on opposite arrows cancel, which is the only sane answer.
## World pixels of scrub since this was last asked, and then zero.
func take_pan_drag() -> float:
	var value := _pan_drag
	_pan_drag = 0.0
	return value

func _refresh_pan() -> void:
	var sum := 0.0
	for finger in _pan_fingers:
		sum += float(_pan_fingers[finger])
	pan_axis = signf(sum)

func _refresh_jump_held() -> void:
	var was_held := jump_held
	jump_held = _jump_from_button or _jump_from_stick
	if was_held and not jump_held:
		jump_release_sequence += 1

## Drive the RUNNER half of this hub from values the caller already has.
##
## The seam a second player enters through. `_poll_desktop` reads the `p1_*`
## actions, and an action fires for every device and every key bound to it, so
## two runners on one machine cannot be told apart that way -- the arrow keys
## are a second binding on `p1_left`, and a second runner driven from them would
## move the first as well.
##
## Everything still goes through the same latches `_poll_desktop` uses, so the
## jump release sequence, the buffered press and the dash edge behave exactly as
## they do in co-op. A hub being driven should have `scripted = true` set, which
## is what stops it also reading the keyboard for itself.
func drive_runner(axis: float, axis_y: float, jump: bool, dash: bool) -> void:
	move_axis = clampf(axis, -1.0, 1.0)
	move_axis_y = clampf(axis_y, -1.0, 1.0)
	var was_jump := _jump_from_button
	_jump_from_button = jump
	_refresh_jump_held()
	if jump and not was_jump:
		_latch_jump_press()
	var was_dash := dash_held
	dash_held = dash
	if dash and not was_dash:
		press_dash()

func press_dash() -> void:
	_dash_latched = true
	dash_held = true

func release_dash() -> void:
	dash_held = false

## An ability button. One press USES that tool -- there is no selection step, so
## this is the whole interaction. On touch it fires when the thumb LIFTS, which
## is what makes press-drag-release a single gesture: hold the tool, drag to the
## spot, let go to commit.
func press_slot(slot: int) -> void:
	_slot_latched = slot

## The tool whose button is under a thumb right now, or -1. The guardian draws
## the ghost for this rather than for whatever was last used, so what you are
## holding is what you can see you would place.
## How far a finger may travel and still count as a tap rather than a drag.
const TAP_SLOP: float = 18.0

## A finger index no touchscreen will produce, for the mouse to borrow.
const MOUSE_FINGER: int = 90

## Distance covered since the finger went down, per finger. Accumulated rather
## than measured start-to-end: _aim_from holds the PREVIOUS position, not the
## origin -- it is rewritten on every move -- and the reticle itself is rate
## limited, so neither of them can answer "has this finger moved". A finger that
## wanders out and comes back is a drag, and this counts it as one.
var _aim_moved: Dictionary = {}

## Where the current tool has been asked to go. Cleared when read: it is an
## instruction, not a state.
var _place_latched: Vector2 = Vector2(INF, INF)

func held_slot() -> int:
	return _slot_held

## Whether the thumb currently on a tool button has moved. Read, not consumed:
## the ghost has to ask this every frame while the press is still open, and
## take_slot_was_dragged() is the once-only answer for the commit.
func slot_is_dragged() -> bool:
	return _slot_dragged

## Put the target under a screen point. Everything that aims goes through here
## so the world point and the screen record can never disagree.
func aim_at_screen(position: Vector2) -> void:
	aim_screen = position
	var viewport := get_viewport()
	if viewport != null:
		aim_point = viewport.get_canvas_transform().affine_inverse() * position
	aim_active = true

## Put the target on a world point -- used by the host when the guardian's aim
## arrives over the network, and by tests.
func aim_at_world(point: Vector2) -> void:
	aim_point = point
	var viewport := get_viewport()
	if viewport != null:
		aim_screen = viewport.get_canvas_transform() * point
	aim_active = true

func press_scope() -> void:
	_scope_latched = true

# ---------------------------------------------------------------- consumption
# Edge-triggered inputs are latched and consumed by their reader, so this node
# never has to care whether the runner ticks before or after it.

func take_jump() -> bool:
	var value := _jump_latched
	_jump_latched = false
	return value

func take_dash() -> bool:
	var value := _dash_latched
	_dash_latched = false
	return value

## Which tool the guardian has CHOSEN. Pressing a tool button no longer builds
## anything and spends nothing: it picks the tool, and the world tap that
## follows is what places it. Tapping a button and having a wall appear
## somewhere -- anywhere -- was the thing that made the controls untrustworthy.
func take_slot_choice() -> int:
	var value := _slot_latched
	_slot_latched = -1
	return value

## Where the guardian asked for the current tool to go, or (INF, INF).
##
## Set by a tap on the world, or by releasing a drag that came out of a tool
## button. Both are the same instruction and there is one latch for them, so a
## single gesture can never place twice.
func take_place_at() -> Vector2:
	var value := _place_latched
	_place_latched = Vector2(INF, INF)
	return value

## Did the press that take_slot just returned involve a drag? A tap means "you
## decide"; a drag means "here". Consume this in the same frame as take_slot.
func take_slot_was_dragged() -> bool:
	var value := _slot_latched_dragged
	_slot_latched_dragged = false
	return value

## The guardian correcting themselves, and either player pointing.
##
## Two buttons rather than gestures on the world: the world is where placing
## happens now, and a gesture there would have to be told apart from a
## placement -- which is exactly the ambiguity that made the controls
## untrustworthy in the first place.
var _undo_latched: bool = false
var _ping_latched: int = 0
var _ping_down_ms: int = 0

## A press this long means "wait" instead of "here". One button, two things,
## and the difference is how long you leave your thumb on it.
const PING_HOLD_MS: int = 350

func take_undo() -> bool:
	var value := _undo_latched
	_undo_latched = false
	return value

## 0 none, 1 "here", 2 "wait".
func take_ping() -> int:
	var value := _ping_latched
	_ping_latched = 0
	return value

func take_scope() -> bool:
	var value := _scope_latched
	_scope_latched = false
	return value

func take_zoom() -> int:
	var value := _zoom_latched
	_zoom_latched = 0
	return value

func take_countdown() -> bool:
	var value := _countdown_latched
	_countdown_latched = false
	return value

# ------------------------------------------------------------------ ownership
# Who this device's screen belongs to. Offline both are true, because the two
# players are sitting either side of the same display. Online each device draws
# and routes only its own half of the game -- drawing the other player's
# controls when nothing local can move them is exactly how the guardian's
# outline ended up stuck where it started.

func owns_runner_controls() -> bool:
	return solo_role != "guardian"

func owns_guardian_controls() -> bool:
	return solo_role != "runner"

## The build ghost and the reticle. The runner's device still shows them when
## the guardian's aim is coming in over the wire -- that warning of an incoming
## platform is the point of drawing them in world space at all.
## On the guardian's own device the reticle is ALWAYS up. It used to appear
## only once they had touched something, which meant the first shot of every
## encounter was aimed at a crosshair that was not on screen yet. On the
## runner's device it stays conditional -- there, the reticle is news about
## somebody else, and news that has not arrived should not be drawn.
func shows_guardian_cursor() -> bool:
	return owns_guardian_controls() or remote_aim

## The guardian has not pointed anywhere yet. Used to park the reticle on the
## runner rather than at the origin the first time it is drawn.
func aim_is_unset() -> bool:
	return not aim_active

## The runner's stick and buttons, sized for whichever of the two layouts
## applies. Single source of truth: the router and the HUD both call this.
func cluster(size: Vector2) -> Dictionary:
	return ControlLayout.layout(layout_mode(), size, not runner_on_left)

## The stick's placement, or an empty dictionary on a device that has no stick.
func stick_place(size: Vector2) -> Dictionary:
	return cluster(size).get("stick", {})

## Where the guardian is pointing, in the world. Fixed to the ground the
## guardian chose, so it does not travel with the camera.
func aim_world() -> Vector2:
	return aim_point

# -------------------------------------------------------------------- desktop

func _process(_delta: float) -> void:
	if _has_touch or scripted:
		return
	_poll_desktop()

func _poll_desktop() -> void:
	move_axis = Input.get_axis("p1_left", "p1_right")
	move_axis_y = Input.get_axis("p1_up", "p1_down") if InputMap.has_action("p1_down") else 0.0
	_jump_from_button = Input.is_action_pressed("p1_jump")
	_refresh_jump_held()
	dash_held = Input.is_action_pressed("p1_dash")
	if Input.is_action_just_pressed("p1_jump"):
		_latch_jump_press()
	if Input.is_action_just_pressed("p1_dash"):
		press_dash()

	var viewport := get_viewport()
	if viewport != null and owns_guardian_controls():
		aim_at_screen(viewport.get_mouse_position())
	if not owns_guardian_controls():
		return
	# No "commit" key. Each tool's own key uses that tool, which is the same
	# rule as the touch buttons -- there is nothing left for a separate fire
	# button, or a left click, to mean. Binding one to "whatever was used last"
	# would be re-inventing the mode this was meant to remove, and on Android,
	# where touch is emulated as a mouse, it is also how a tap on a menu once
	# spent 30 gauge and dropped a slab on the runner's head.
	if Input.is_action_just_pressed("p2_scope"):
		press_scope()
	for slot in range(1, TouchLayout.SLOT_COUNT + 1):
		if Input.is_action_just_pressed("p2_slot_%d" % slot):
			press_slot(slot)
	if Input.is_action_just_pressed("p2_zoom_in"):
		_zoom_latched = 1
	if Input.is_action_just_pressed("p2_zoom_out"):
		_zoom_latched = -1
	if InputMap.has_action("p2_undo") and Input.is_action_just_pressed("p2_undo"):
		_undo_latched = true
	if InputMap.has_action("p2_ping") and Input.is_action_just_pressed("p2_ping"):
		_ping_latched = 1
	if Input.is_action_just_pressed("p2_count"):
		_countdown_latched = true
	pan_axis = Input.get_axis("p2_pan_left", "p2_pan_right")

# ---------------------------------------------------------------------- touch

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_has_touch = true
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_has_touch = true
		_touch_move(event.index, event.position)
		get_viewport().set_input_as_handled()
	# The mouse goes down the same path as a finger -- but only on a device that
	# has never produced a real one.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not _has_touch:
		if event.pressed:
			_touch_down(MOUSE_FINGER, event.position)
		else:
			_touch_up(MOUSE_FINGER)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not _has_touch \
			and _touch_owner.has(MOUSE_FINGER):
		_touch_move(MOUSE_FINGER, event.position)
		get_viewport().set_input_as_handled()

func _world_under(index: int) -> Vector2:
	var at: Vector2 = _last_position.get(index, Vector2(INF, INF))
	var viewport := get_viewport()
	if at.x == INF or viewport == null:
		return aim_point
	return viewport.get_canvas_transform().affine_inverse() * at

func _over_a_control(index: int) -> bool:
	var at: Vector2 = _last_position.get(index, Vector2(-1.0, -1.0))
	if at.x < 0.0:
		return false
	return ControlLayout.hit(layout_mode(), _screen_size(), not runner_on_left, at) != ""

var _last_position: Dictionary = {}

## Android does not always send release events when focus is lost, so release
## held controls and also discard any press edge that has not reached Runner.
func _notification(what: int) -> void:
	var lost := [NOTIFICATION_APPLICATION_FOCUS_OUT,
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]
	if what in lost:
		release_everything()

func release_everything() -> void:
	for index in _touch_owner.keys():
		_touch_up(int(index), Vector2(INF, INF))
	_touch_owner.clear()
	_last_position.clear()
	_stick_finger = -1
	_aim_finger = -1
	_slot_finger = -1
	_zoom_finger = -1
	_slot_held = -1
	_slot_dragged = false
	move_axis = 0.0
	move_axis_y = 0.0
	dash_held = false
	_jump_from_stick = false
	release_jump()
	_jump_latched = false
	_refresh_pan()

func _screen_size() -> Vector2:
	return Vector2(get_viewport().get_visible_rect().size)

func _touch_down(index: int, position: Vector2) -> void:
	_last_position[index] = position
	# Set here rather than only in _unhandled_input so that every route into the
	# touch handlers switches off desktop polling.
	if index != MOUSE_FINGER:
		_has_touch = true
	var size := _screen_size()
	var mirrored := not runner_on_left

	if solo_role == "guardian":
		_route_guardian_only(index, position, size, mirrored)
		return

	if scope_engaged and TouchLayout.hit_rect(position, TouchLayout.ZOOM_SLIDER, size, mirrored):
		_touch_owner[index] = "zoom"
		_zoom_finger = index
		_apply_zoom_slider(position, size)
		return
	if _route_control(index, position, size, mirrored):
		return
	if solo_role != "runner" and TouchLayout.hit_rect(
			position, TouchLayout.AIM_ZONE, size, mirrored):
		_touch_owner[index] = "aim"
		_aim_finger = index
		_begin_aim(index, position)

func _route_control(index: int, position: Vector2, size: Vector2,
		mirrored: bool) -> bool:
	var id := ControlLayout.hit(layout_mode(), size, mirrored, position)
	match id:
		"":
			return false
		"jump":
			_touch_owner[index] = "jump"
			press_jump()
		"sprint":
			_touch_owner[index] = "dash"
			press_dash()
		"stick":
			_touch_owner[index] = "stick"
			_stick_finger = index
			_apply_stick(position, size)
		"scope":
			_touch_owner[index] = "scope"
			press_scope()
		"undo":
			_touch_owner[index] = "undo"
			_undo_latched = true
		"ping":
			_touch_owner[index] = "ping"
			_ping_down_ms = Time.get_ticks_msec()
		"pan_left", "pan_right":
			_touch_owner[index] = "pan"
			_pan_fingers[index] = -1.0 if id == "pan_left" else 1.0
			_pan_drag_from[index] = position.x
			_refresh_pan()
		_:
			if id.begins_with("slot_"):
				_hold_slot(index, int(id.substr(5)))
			else:
				return false
	return true

func layout_mode() -> String:
	if solo_role == "runner":
		return "runner"
	if solo_role == "guardian":
		return "guardian"
	return "shared"

func _route_guardian_only(index: int, position: Vector2, size: Vector2,
		mirrored: bool) -> void:
	if scope_engaged and TouchLayout.hit_rect(position, TouchLayout.ZOOM_SLIDER, size, mirrored):
		_touch_owner[index] = "zoom"
		_zoom_finger = index
		_apply_zoom_slider(position, size)
		return
	if _route_control(index, position, size, mirrored):
		return
	_touch_owner[index] = "aim"
	_aim_finger = index
	_begin_aim(index, position)

func _begin_aim(index: int, position: Vector2) -> void:
	_aim_from[index] = position.x
	_aim_from_y[index] = position.y
	_aim_is_scroll[index] = false
	_aim_moved[index] = 0.0
	aim_at_screen(position)

func _hold_slot(index: int, slot: int) -> void:
	_touch_owner[index] = "slot"
	_slot_finger = index
	_slot_held = slot
	_slot_dragged = false

func _touch_move(index: int, position: Vector2) -> void:
	_has_touch = true
	_last_position[index] = position
	var size := _screen_size()
	match _touch_owner.get(index, ""):
		"stick":
			_apply_stick(position, size)
		"aim":
			var travel: float = position.x - float(_aim_from.get(index, position.x))
			var lift: float = absf(position.y - float(_aim_from_y.get(index, position.y)))
			_aim_moved[index] = float(_aim_moved.get(index, 0.0)) \
				+ Vector2(travel, position.y - float(_aim_from_y.get(index, position.y))).length()
			if not _aim_is_scroll.get(index, false) \
					and absf(travel) > SCROLL_WAKES_UP and absf(travel) > lift * 1.4:
				_aim_is_scroll[index] = true
			if _aim_is_scroll.get(index, false):
				_pan_drag += travel * -SCROLL_SCALE
			else:
				aim_at_screen(position)
			_aim_from[index] = position.x
			_aim_from_y[index] = position.y
		"pan":
			var from: float = _pan_drag_from.get(index, position.x)
			_pan_drag += (position.x - from) * -PAN_DRAG_SCALE
			_pan_drag_from[index] = position.x
			_pan_fingers.erase(index)
			_refresh_pan()
		"slot":
			_slot_dragged = true
			aim_at_screen(position)
		"zoom":
			_apply_zoom_slider(position, size)

func _apply_stick(position: Vector2, size: Vector2) -> void:
	_stick_position = position
	var place := stick_place(size)
	if place.is_empty():
		return
	var anchor: Vector2 = place["center"]
	var travel_px: float = maxf(ControlLayout.stick_travel(place), 1.0)

	var up := anchor.y - position.y
	var in_jump_zone := Options.stick_jump() and up > travel_px * ControlLayout.STICK_JUMP_FRACTION
	var entered_jump_zone := in_jump_zone and not _jump_from_stick
	_jump_from_stick = in_jump_zone
	_refresh_jump_held()
	if entered_jump_zone:
		_latch_jump_press()

	move_axis_y = clampf(-up / travel_px, -1.0, 1.0)
	if Options.responsive_touch() and -up < absf(position.x - anchor.x) * 0.85:
		move_axis_y = minf(move_axis_y, 0.0)

	var dx: float = position.x - anchor.x
	if not runner_on_left:
		dx = -dx
	var dead: float = travel_px * 0.07 if Options.responsive_touch() else ControlLayout.stick_deadzone(place)
	if absf(dx) <= dead:
		move_axis = 0.0
		return
	var travel: float = travel_px * 0.55 if Options.responsive_touch() else travel_px
	var reach := (absf(dx) - dead) / maxf(travel - dead, 1.0)
	move_axis = clampf(reach, 0.0, 1.0) * signf(dx)

func _touch_up(index: int, position: Vector2 = Vector2(INF, INF)) -> void:
	if position.x != INF:
		if _last_position.has(index):
			_aim_moved[index] = float(_aim_moved.get(index, 0.0)) \
				+ (position - Vector2(_last_position[index])).length()
		_last_position[index] = position
		if _touch_owner.get(index, "") in ["aim", "slot"] \
				and not bool(_aim_is_scroll.get(index, false)):
			aim_at_screen(position)
	match _touch_owner.get(index, ""):
		"stick":
			_stick_finger = -1
			move_axis = 0.0
			move_axis_y = 0.0
			_jump_from_stick = false
			_refresh_jump_held()
		"aim":
			if not bool(_aim_is_scroll.get(index, false)) \
					and float(_aim_moved.get(index, 0.0)) <= TAP_SLOP:
				_place_latched = _world_under(index)
			_aim_finger = -1
			_aim_from.erase(index)
			_aim_from_y.erase(index)
			_aim_is_scroll.erase(index)
			_aim_moved.erase(index)
		"slot":
			_slot_latched_dragged = _slot_dragged
			press_slot(_slot_held)
			if _slot_dragged and not _over_a_control(index):
				_place_latched = _world_under(index)
			_slot_finger = -1
			_slot_held = -1
			_slot_dragged = false
		"ping":
			var held := Time.get_ticks_msec() - _ping_down_ms
			_ping_latched = 2 if held >= PING_HOLD_MS else 1
		"zoom":
			_zoom_finger = -1
		"jump":
			release_jump()
		"dash":
			release_dash()
		"pan":
			_pan_fingers.erase(index)
			_pan_drag_from.erase(index)
			_refresh_pan()
	_touch_owner.erase(index)
	_last_position.erase(index)

var _zoom_slider_value: float = -1.0

func _apply_zoom_slider(position: Vector2, size: Vector2) -> void:
	var rect := TouchLayout.ZOOM_SLIDER
	var t := clampf((position.y / size.y - rect.position.y) / rect.size.y, 0.0, 1.0)
	var steps := Balance.SCOPE_ZOOM_STEPS.size()
	var target := int(round((1.0 - t) * float(steps - 1)))
	if _zoom_slider_value < 0.0:
		_zoom_slider_value = float(target)
	var current := int(round(_zoom_slider_value))
	if target != current:
		_zoom_latched = signi(target - current)
		_zoom_slider_value = float(target)

func stick_visual() -> Dictionary:
	return {
		"active": _stick_finger >= 0,
		"thumb": _stick_position,
		"axis": move_axis,
		"jumping": _jump_from_stick,
		"touch_mode": _has_touch,
	}
