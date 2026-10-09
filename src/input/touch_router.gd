class_name TouchRouter
extends RefCounted
## Who owns each finger, and the whole life of one: down, drag, up, cancel.
##
## Both players share one viewport, so a finger is routed by where it lands
## and then belongs to one gesture until it lifts. This is the only place that
## tracks fingers. Android drops releases and recycles finger indices, and a
## focus loss leaves fingers nobody will ever lift; handling that here, once,
## is what stops each control from having to get it right on its own.

var hub: InputHub

var stick: StickGesture
var jump: JumpGesture
var scope: ButtonGesture
var undo: ButtonGesture
var ping: PingGesture
var pan: PanGesture
var slot: SlotGesture
var aim: AimGesture
var zoom: ZoomGesture
var hand: HandGesture

## finger index -> the TouchGesture it belongs to.
var _owners: Dictionary = {}
## finger index -> where it was last seen, in screen pixels.
var _last_position: Dictionary = {}
## Fingers whose gesture began on a button hub.gui_passthrough claims: the
## GUI's, from the press to the release.
var _gui_fingers: Dictionary = {}

func _init(owner_hub: InputHub) -> void:
	hub = owner_hub
	stick = StickGesture.new(hub, "stick")
	jump = JumpGesture.new(hub, "jump")
	scope = ButtonGesture.new(hub, "scope")
	undo = ButtonGesture.new(hub, "undo")
	ping = PingGesture.new(hub, "ping")
	pan = PanGesture.new(hub, "pan")
	slot = SlotGesture.new(hub, "slot")
	aim = AimGesture.new(hub, "aim")
	zoom = ZoomGesture.new(hub, "zoom")
	hand = HandGesture.new(hub, "hand")

func gestures() -> Array[TouchGesture]:
	return [stick, jump, scope, undo, ping, pan, slot, aim, zoom, hand]

## finger index -> role name, for diagnostics and tests.
func roles() -> Dictionary:
	var out := {}
	for index in _owners:
		out[index] = (_owners[index] as TouchGesture).role
	return out

func owns(index: int) -> bool:
	return _owners.has(index)

# ------------------------------------------------------------------- events

## Touches are read in two passes, and which pass takes a press is the point.
##
## A press on one of the painted game controls (stick, jump, tool slots, the
## zoom slider) is claimed in the first pass (_input), before any Control sees
## it: an overlapping GUI node used to swallow those, which is how a jump went
## missing. A press on open ground waits for the late pass (_unhandled_input),
## so a real Button over the world still gets it first. Once a finger is ours,
## its drags and its release are claimed in the first pass, wherever they land;
## a finger we never took is left alone in both. Returns whether we kept it.
##
## A mouse event Godot made up from a touch (emulate_mouse_from_touch, for the
## menu Controls) is never ours: it arrives BEFORE the touch it copies, so on a
## hub that has not seen a touch yet it would take the control as the mouse
## finger -- and its release, coming after the touch, would then be ignored,
## leaving that control held for good.
func claim(event: InputEvent, late: bool) -> bool:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) \
			and event.device == InputEvent.DEVICE_ID_EMULATION:
		return false
	if _left_to_gui(event, late):
		return false
	if event is InputEventScreenTouch:
		hub._has_touch = true
		return _claim_finger(event.index, event.position, event.pressed, late)
	if event is InputEventScreenDrag:
		hub._has_touch = true
		if late or not _owners.has(event.index):
			return false
		move(event.index, event.position)
		return true
	# The mouse goes down the same path as a finger -- but only on a device that
	# has never produced a real one.
	if hub._has_touch:
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return _claim_finger(InputHub.MOUSE_FINGER, event.position, event.pressed, late)
	if event is InputEventMouseMotion and not late and _owners.has(InputHub.MOUSE_FINGER):
		move(InputHub.MOUSE_FINGER, event.position)
		return true
	return false

## Whether this event is a press on (or the rest of a gesture that began on) a
## button hub.gui_passthrough claims. Decided in the first pass; the late pass
## only reads the answer.
func _left_to_gui(event: InputEvent, late: bool) -> bool:
	var index := -1
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		index = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not hub._has_touch:
		index = InputHub.MOUSE_FINGER
	elif event is InputEventMouseMotion and not hub._has_touch:
		return _gui_fingers.has(InputHub.MOUSE_FINGER)
	else:
		return false
	if late:
		return _gui_fingers.has(index)
	var down: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) \
		and event.pressed
	if down:
		if hub.gui_passthrough.is_valid() and bool(hub.gui_passthrough.call(event.position)):
			# A recycled index that the hub still owned is a lost release.
			if _owners.has(index):
				up(index, Vector2(INF, INF), true)
			_gui_fingers[index] = true
			return true
		_gui_fingers.erase(index)
		return false
	if not _gui_fingers.has(index):
		return false
	if not (event is InputEventScreenDrag or event is InputEventMouseMotion):
		_gui_fingers.erase(index)
	return true

func _claim_finger(index: int, position: Vector2, pressed: bool, late: bool) -> bool:
	if not pressed:
		if late or not _owners.has(index):
			return false
		up(index, position if index != InputHub.MOUSE_FINGER else Vector2(INF, INF))
		return true
	if not late:
		# A reused index is a new press, whoever ends up taking it -- see down().
		if _owners.has(index):
			up(index, Vector2(INF, INF), true)
		if not on_a_control(position):
			return false
	down(index, position)
	return _owners.has(index)

func down(index: int, position: Vector2) -> void:
	# Android can cancel a contact without delivering its release when focus or
	# the system gesture layer changes. A reused finger index is a new press.
	if _owners.has(index):
		up(index, Vector2(INF, INF), true)
	_last_position[index] = position
	# Set here too so direct calls switch off desktop polling, just like events
	# routed through claim().
	if index != InputHub.MOUSE_FINGER:
		hub._has_touch = true
	else:
		hub._has_pointer_controls = true
	var size := hub._screen_size()
	var routed := _route(position, size)
	if routed.is_empty():
		return
	var gesture: TouchGesture = routed[0]
	_owners[index] = gesture
	gesture.begin(index, position, size, routed[1])

func move(index: int, position: Vector2) -> void:
	if index != InputHub.MOUSE_FINGER:
		hub._has_touch = true
	_last_position[index] = position
	var gesture: TouchGesture = _owners.get(index)
	if gesture != null:
		gesture.drag(index, position, hub._screen_size())

## `position` is INF for a release that carried none. `cancelled` is a finger
## the device lost rather than one the player lifted: it ends without
## committing anything.
func up(index: int, position: Vector2 = Vector2(INF, INF), cancelled: bool = false) -> void:
	var previous: Variant = _last_position.get(index)
	if position.x != INF:
		_last_position[index] = position
	var gesture: TouchGesture = _owners.get(index)
	if gesture != null:
		gesture.end(index, position, cancelled, previous)
	_owners.erase(index)
	_last_position.erase(index)

## Every finger is gone and none of them will say so: focus loss, a pause, a
## menu taking over. Each owned finger ends cancelled, then every gesture is
## told to forget whatever that left behind.
func release_all() -> void:
	for index in _owners.keys():
		up(int(index), Vector2(INF, INF), true)
	_owners.clear()
	_last_position.clear()
	_gui_fingers.clear()
	for gesture in gestures():
		gesture.reset()

# ------------------------------------------------------------------ routing

## [gesture, control id] for a press here, or [] when it belongs to nobody.
func _route(position: Vector2, size: Vector2) -> Array:
	var mirrored := not hub.runner_on_left
	if hub.scope_engaged and TouchLayout.hit_rect(position, TouchLayout.ZOOM_SLIDER, size, mirrored):
		return [zoom, "zoom"]
	var id := ControlLayout.hit(hub.layout_mode(), size, mirrored, position)
	if id == "stick" and stick.finger >= 0:
		return []
	var control := _gesture_for(id)
	if control != null:
		return [control, id]
	if hub.solo_role == "guardian":
		return _world_gesture(position)
	if hub.solo_role != "runner" and (TouchLayout.hit_rect(
			position, TouchLayout.AIM_ZONE, size, mirrored)
			or _clear_of_runner_controls(position, size, mirrored)):
		return _world_gesture(position)
	return []

## A guardian's finger on the world: the hand, if it landed on something the
## hand can take hold of (and the hand is free), otherwise the aim.
func _world_gesture(position: Vector2) -> Array:
	if hand.finger < 0 and hub.hand_probe.is_valid():
		var target: Dictionary = hub.hand_probe.call(hub._screen_to_world(position))
		if not target.is_empty():
			hub._hand_pending = target
			return [hand, "hand"]
	return [aim, "aim"]

func _gesture_for(id: String) -> TouchGesture:
	match id:
		"jump":
			return jump
		"stick":
			return stick
		"scope":
			return scope
		"undo":
			return undo
		"ping":
			return ping
		"pan_left", "pan_right":
			return pan
	if id.begins_with("slot_"):
		return slot
	return null

## Whether a press here belongs to a painted game control rather than to the
## world under it. Same tests _route uses.
func on_a_control(position: Vector2) -> bool:
	var size := hub._screen_size()
	var mirrored := not hub.runner_on_left
	if hub.scope_engaged and TouchLayout.hit_rect(position, TouchLayout.ZOOM_SLIDER, size, mirrored):
		return true
	return ControlLayout.hit(hub.layout_mode(), size, mirrored, position) != ""

## Whether a finger is over a control right now.
func over_a_control(index: int) -> bool:
	var at: Vector2 = _last_position.get(index, Vector2(-1.0, -1.0))
	if at.x < 0.0:
		return false
	return ControlLayout.hit(hub.layout_mode(), hub._screen_size(), not hub.runner_on_left, at) != ""

## The world point under a finger, or the current aim if it has no position.
func world_under(index: int) -> Vector2:
	var at: Vector2 = _last_position.get(index, Vector2(INF, INF))
	if at.x == INF or hub.get_viewport() == null:
		return hub.aim_point
	return hub._screen_to_world(at)

## On a shared screen, whether a touch on the runner's side is far enough from
## the stick and the jump button to be the guardian drawing rather than the
## runner missing a control.
##
## The runner's side used to be the runner's alone: a touch there that missed
## the stick did nothing. But the world carries on over there, and a platform
## to the runner's LEFT had to be drawn in exactly that third of the screen --
## so building behind the runner mostly failed. Now only a margin round the
## runner's controls stays theirs; the rest of that third is the guardian's.
func _clear_of_runner_controls(position: Vector2, size: Vector2, mirrored: bool) -> bool:
	var places := ControlLayout.layout(hub.layout_mode(), size, mirrored)
	for id in ["stick", "jump", "ping"]:
		if not places.has(id):
			continue
		var place: Dictionary = places[id]
		var reach := float(place["radius"]) \
			* (ControlLayout.STICK_CAPTURE if place["kind"] == "stick" else 1.0)
		if position.distance_to(place["center"]) <= reach * InputHub.RUNNER_CONTROL_MARGIN:
			return false
	return true
