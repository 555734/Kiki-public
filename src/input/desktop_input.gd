class_name DesktopInput
extends RefCounted
## Keyboard and mouse, read into the same intent fields touch fills, which is
## what lets the game be iterated on in the editor and shipped to touch
## unchanged. Polled each frame by InputHub on a device that has never
## produced a real touch.

static func poll(hub: InputHub) -> void:
	if not hub.runner_driven_remotely:
		# The virtual controls own their values until release, including when
		# a mouse is standing in for a finger. Keyboard polling must not erase
		# a held stick or jump between pointer events.
		if hub.touch.stick.finger < 0:
			hub.move_axis = Input.get_axis("p1_left", "p1_right")
			hub.move_axis_y = Input.get_axis("p1_up", "p1_down") if InputMap.has_action("p1_down") else 0.0
		if hub.touch.jump.fingers.is_empty():
			hub._jump_from_button = Input.is_action_pressed("p1_jump")
			hub._refresh_jump_held()
		hub.dash_held = Input.is_action_pressed("p1_dash")
		if Input.is_action_just_pressed("p1_jump"):
			hub._latch_jump_press()
		if Input.is_action_just_pressed("p1_dash"):
			hub.press_dash()

	var viewport := hub.get_viewport()
	if viewport != null and hub.owns_guardian_controls() and not hub.aiming() and hub.held_slot() < 0:
		hub.aim_at_screen(viewport.get_mouse_position())
	if not hub.owns_guardian_controls():
		return
	# No "commit" key. Each tool's own key uses that tool, which is the same
	# rule as the touch buttons -- there is nothing left for a separate fire
	# button, or a left click, to mean. Binding one to "whatever was used last"
	# would be re-inventing the mode this was meant to remove, and on Android,
	# where touch is emulated as a mouse, it is also how a tap on a menu once
	# spent 30 gauge and dropped a slab on the runner's head.
	if Input.is_action_just_pressed("p2_scope"):
		hub.press_scope()
	for slot in range(1, TouchLayout.SLOT_COUNT + 1):
		if Input.is_action_just_pressed("p2_slot_%d" % slot):
			hub.press_slot(slot)
	if Input.is_action_just_pressed("p2_zoom_in"):
		hub._zoom_latched = 1
	if Input.is_action_just_pressed("p2_zoom_out"):
		hub._zoom_latched = -1
	if InputMap.has_action("p2_undo") and Input.is_action_just_pressed("p2_undo"):
		hub._undo_latched = true
	if InputMap.has_action("p2_ping") and Input.is_action_just_pressed("p2_ping"):
		hub._ping_latched = 1
	if Input.is_action_just_pressed("p2_count"):
		hub._countdown_latched = true
	hub.pan_axis = Input.get_axis("p2_pan_left", "p2_pan_right")
