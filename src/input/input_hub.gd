class_name InputHub
extends Node
## Turns raw device events into *intent*, and nothing else.
##
## Both players share one viewport, so touches have to be routed by screen
## region and tracked per finger. Godot's Control buttons cannot do this: the
## moment the runner holds the stick down, a Control-based ability button on the
## other side of the screen stops receiving the guardian's drag. So we take the
## raw InputEventScreenTouch/Drag stream, key it by finger index, and dispatch
## ourselves. `emulate_mouse_from_touch` is enabled for menu Controls. Gameplay
## keeps raw per-finger ownership and suppresses the emulated mouse after touch
## input; one emulated pointer must never replace the raw touch stream.
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
## Sent with remote runner input so even a tap between 30 Hz packets arrives.
var jump_press_sequence: int = 0
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
## Whether the press being consumed right now came with a drag. Latched with
## the slot so the reader sees the two together.
var _slot_latched_dragged: bool = false
var _zoom_latched: int = 0
var _countdown_latched: bool = false

## True when the runner is on the left half (the default seating).
var runner_on_left: bool = true

## "" offline (two players share the screen and the divider matters), or
## "runner" / "guardian" online, where the local player owns the whole display.
## The star battle's one-person seats use "" too: the same screen as 1-1.
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
## Sliding sideways off a look button scrubs the view, so a long look is one
## flick rather than a thumb held down for three seconds. Accumulated here and
## consumed by the camera.
var _pan_drag: float = 0.0
## How much world the view moves per pixel of thumb. Above 1 because the whole
## point is to cover ground without a long drag.
const PAN_DRAG_SCALE := 2.2

var _has_touch: bool = false
## Mouse-operated virtual controls stay visible without disabling the keyboard.
var _has_pointer_controls: bool = false
## Every finger on the screen, and the gesture each one belongs to.
var touch: TouchRouter = TouchRouter.new(self)
## Which gesture owns each finger, by role name. Read-only: for diagnostics and
## tests.
var _touch_owner: Dictionary:
	get: return touch.roles()
var _stick_finger: int:
	get: return touch.stick.finger
var _slot_finger: int:
	get: return touch.slot.finger
var _zoom_finger: int:
	get: return touch.zoom.finger
## Fingers whose gesture belongs to a real Button (gui_passthrough).
var _gui_fingers: Dictionary:
	get: return touch._gui_fingers
## Test seam. When true, _process stops polling the keyboard and mouse, so a
## headless capture or a unit test can write the intent fields directly. Nothing
## in the shipping game sets this.
var scripted: bool = false
## Authority can move to the guardian's device while the runner stays on the
## other phone. In that state desktop runner bindings must not race the remote
## input stream; guardian mouse/keyboard controls still remain live.
var runner_driven_remotely: bool = false
## A versus runner always has the stick on the left; global co-op role-swap
## signals must never mirror the versus touch map independently of its HUD.
var force_runner_left: bool = false
## Screen points that belong to a real Button over the play field (the star
## battle's スタート / やめる, the quit confirmation). The hub reads presses
## before the GUI, so a press there is left alone -- down, drags and up -- or
## the button never hears it. Unset where every control is painted.
var gui_passthrough: Callable = Callable()

func _ready() -> void:
	process_priority = -100
	Events.roles_swapped.connect(_on_roles_swapped)
	Events.scope_state_changed.connect(func(active: bool, _z: float) -> void: scope_engaged = active)

func _on_roles_swapped(on_left: bool) -> void:
	if not force_runner_left:
		runner_on_left = on_left

# ------------------------------------------------------------------- presses
# Edge-triggered inputs go through these so touch, keyboard and tests all take
# the same path into the latch.

func _latch_jump_press() -> void:
	_jump_latched = true
	jump_press_sequence = (jump_press_sequence + 1) & 0xFFFF
	jump_press_release_sequence = jump_release_sequence

func press_jump() -> void:
	_jump_from_button = true
	_refresh_jump_held()
	_latch_jump_press()

func release_jump() -> void:
	_jump_from_button = false
	_refresh_jump_held()

## World pixels of scrub since this was last asked, and then zero.
func take_pan_drag() -> float:
	var value := _pan_drag
	_pan_drag = 0.0
	return value

func _refresh_jump_held() -> void:
	var was_held := jump_held
	jump_held = _jump_from_button or _jump_from_stick
	if was_held and not jump_held:
		jump_release_sequence += 1

## Drive the RUNNER half of this hub from values the caller already has.
##
## The seam a second player enters through. `DesktopInput.poll` reads the `p1_*`
## actions, and an action fires for every device and every key bound to it, so
## two runners on one machine cannot be told apart that way -- the arrow keys
## are a second binding on `p1_left`, and a second runner driven from them would
## move the first as well.
##
## Everything still goes through the same latches `DesktopInput.poll` uses, so the
## jump release sequence, the buffered press and the dash edge behave exactly as
## they do in co-op. A hub being driven should have `scripted = true` set, which
## is what stops it also reading the keyboard for itself.
## jump_edge: -1 uses the held-state transition (local/legacy callers); 0 or 1
## uses the press counter carried by remote input packets.
func drive_runner(axis: float, axis_y: float, jump: bool, dash: bool,
		jump_edge: int = -1) -> void:
	move_axis = clampf(axis, -1.0, 1.0)
	move_axis_y = clampf(axis_y, -1.0, 1.0)
	var was_jump := _jump_from_button
	_jump_from_button = jump
	_refresh_jump_held()
	if jump_edge > 0 or (jump_edge < 0 and jump and not was_jump):
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

## On a shared screen, how far round each of the runner's controls (as a
## multiple of its reach) a touch still belongs to the runner.
const RUNNER_CONTROL_MARGIN: float = 1.35


## A finger index no touchscreen will produce, for the mouse to borrow.
const MOUSE_FINGER: int = 90

## Where the current tool has been asked to go. Cleared when read: it is an
## instruction, not a state.
var _place_latched: Vector2 = Vector2(INF, INF)
## Shape of a traced platform that goes with _place_latched, relative to it;
## empty means "the standard slab" (a tap rather than a trace).
var _place_path: PackedVector2Array = PackedVector2Array()
## True while the guardian's platform tool is chosen: a finger dragged over the
## world then draws where the platform goes instead of aiming a shot.
var trace_mode: bool = false
## World points of the stroke being drawn right now, for the preview.
var trace_points: PackedVector2Array = PackedVector2Array()

func held_slot() -> int:
	return touch.slot.held

## Whether the thumb currently on a tool button has moved. Read, not consumed:
## the ghost has to ask this every frame while the press is still open, and
## take_slot_was_dragged() is the once-only answer for the commit.
func slot_is_dragged() -> bool:
	return touch.slot.dragged

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

## The traced shape for the placement take_place_at just returned (empty = tap).
func take_place_path() -> PackedVector2Array:
	var value := _place_path
	_place_path = PackedVector2Array()
	return value

## The platform a finished stroke describes; see StrokePath.from_points.
static func path_from_stroke(points: PackedVector2Array) -> Array:
	return StrokePath.from_points(points)

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
## Show the touch controls before the first touch: for a screen that is only
## ever built on a touch device (the star battle's buttons).
func assume_touch() -> void:
	_has_touch = true

## A finger is on the world right now, drawing a platform or aiming.
func aiming() -> bool:
	return touch.aim.finger >= 0

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
	var place: Dictionary = cluster(size).get("stick", {})
	if not place.is_empty() and _stick_finger >= 0 and ControlLayout.floating_stick(layout_mode()):
		place["center"] = touch.stick.anchor
	return place

## Where the guardian is pointing, in the world. Fixed to the ground the
## guardian chose, so it does not travel with the camera.
func aim_world() -> Vector2:
	return aim_point

# -------------------------------------------------------------------- desktop

func _process(_delta: float) -> void:
	if _has_touch or scripted:
		return
	DesktopInput.poll(self)

# ---------------------------------------------------------------------- touch
# The fingers themselves are TouchRouter's; see there for why touches are read
# in two passes.

func _input(event: InputEvent) -> void:
	if touch.claim(event, false):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if touch.claim(event, true):
		get_viewport().set_input_as_handled()

## Both passes in the order the viewport runs them, for callers -- tests -- that
## hand the hub events directly. Returns whether the hub kept the event.
func feed(event: InputEvent) -> bool:
	return touch.claim(event, false) or touch.claim(event, true)

## Switches the hub's reading of touches and the mouse on or off as one. Both
## passes have to go together: turning off only one of them left a stand-in
## hub (or a hub behind a menu) eating every touch through the other.
func set_listening(on: bool) -> void:
	set_process_input(on)
	set_process_unhandled_input(on)

func is_listening() -> bool:
	return is_processing_input() and is_processing_unhandled_input()

## Android does not always send release events when focus is lost, so release
## held controls and also discard any press edge that has not reached Runner.
func _notification(what: int) -> void:
	var lost := [NOTIFICATION_APPLICATION_FOCUS_OUT,
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]
	if what in lost:
		release_everything()

func release_everything() -> void:
	touch.release_all()
	_slot_latched = -1
	_slot_latched_dragged = false
	_place_latched = Vector2(INF, INF)
	_place_path = PackedVector2Array()
	_ping_latched = 0
	move_axis = 0.0
	move_axis_y = 0.0
	dash_held = false
	_jump_from_stick = false
	release_jump()
	_jump_latched = false

func layout_mode() -> String:
	if solo_role == "runner":
		return "runner"
	if solo_role == "guardian":
		return "guardian"
	return "shared"

func _screen_size() -> Vector2:
	return Vector2(get_viewport().get_visible_rect().size)

func _screen_to_world(position: Vector2) -> Vector2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * position if viewport != null else position

# Finger entry points, kept for the many tests that drive fingers directly.
func _touch_down(index: int, position: Vector2) -> void:
	touch.down(index, position)

func _touch_move(index: int, position: Vector2) -> void:
	touch.move(index, position)

func _touch_up(index: int, position: Vector2 = Vector2(INF, INF),
		cancelled: bool = false) -> void:
	touch.up(index, position, cancelled)

func _on_a_control(position: Vector2) -> bool:
	return touch.on_a_control(position)

func _apply_stick(position: Vector2, size: Vector2) -> void:
	touch.stick.apply(position, size)

func stick_visual() -> Dictionary:
	return {
		"active": touch.stick.finger >= 0,
		"thumb": touch.stick.thumb,
		"axis": move_axis,
		"jumping": _jump_from_stick,
		"touch_mode": _has_touch or _has_pointer_controls,
	}
