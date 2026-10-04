extends "res://test/logic/logic_suite.gd"
## Touch controls and their layout: reachability, the stick, taps against drags.

## The half of the connect-screen bug that headless can see.
##
## Every button on it was dead on Android because a Control receives the mouse
## event Godot emulates from a touch, never the touch itself, and emulation was
## off. Whether a press actually lands cannot be checked here -- headless has no
## GUI picking, and even a synthetic mouse click does nothing -- so that half
## lives in test/ui_probe.tscn under xvfb. What is checkable here is the setting
## that was wrong and the input hand-off around it.
func _test_connect_screen_responds_to_touch() -> void:
	_current = "connect screen"
	await _boot(false)
	check(Input.is_emulating_mouse_from_touch(),
		"touch is emulated as mouse, or no button can ever be pressed")

	var panel: Node = main.get_node_or_null("NetPanel")
	check(panel != null, "the connect screen is shown at startup")
	if panel == null:
		return
	check(_find_button(panel, "1台") != null, "the local-play button exists")
	check(_find_button(panel, "部屋を作る") != null, "the internet host button exists")
	check(not main.input_hub.is_processing_unhandled_input(),
		"the game's input router stands down while the panel is up")

	panel.free()
	await _frames(2)
	check(main.input_hub.is_processing_unhandled_input(),
		"and gets its input back when the panel goes")

## The virtual stick has to respond to a press, not only to a drag.
##
## It originally anchored wherever the thumb landed and derived the axis from the
## drag away from that point, so pressing and holding produced nothing: on a
## phone the runner moved only while the thumb was sliding and then stopped dead.
## These call the touch handlers directly, which is the only way to exercise the
## routing without a device.
func _test_virtual_stick() -> void:
	_current = "virtual stick"
	await _boot()
	var previous_touch_options := Options._cache.duplicate()
	Options._cache["responsive_touch"] = false
	Options._cache["stick_jump"] = true
	var hub: InputHub = main.input_hub
	hub.scripted = false
	var view := Vector2(main.get_viewport().get_visible_rect().size)
	var stick: Dictionary = ControlLayout.layout("shared", view, false)["stick"]
	var anchor: Vector2 = stick["center"]
	var travel: float = ControlLayout.stick_travel(stick)

	# A press to the right of the anchor moves right, with no drag at all.
	hub._touch_down(0, anchor + Vector2(travel, 0.0))
	check(hub.move_axis > 0.85, "press right of the anchor -> full right (%.2f)" % hub.move_axis)
	# Holding still must not decay: no further events arrive while a thumb rests.
	var held := hub.move_axis
	await _physics(20)
	check(is_equal_approx(hub.move_axis, held), "the axis survives a press-and-hold")
	hub._touch_up(0)
	check(is_zero_approx(hub.move_axis), "lifting off stops the runner")

	hub._touch_down(0, anchor - Vector2(travel, 0.0))
	check(hub.move_axis < -0.85, "press left of the anchor -> full left (%.2f)" % hub.move_axis)
	hub._touch_up(0)

	# Dead zone at the anchor itself, so a thumb resting dead centre is neutral.
	hub._touch_down(0, anchor)
	check(is_zero_approx(hub.move_axis), "the anchor itself is neutral")
	hub._touch_up(0)

	# Partial deflection is proportional rather than all-or-nothing.
	hub._touch_down(0, anchor + Vector2(travel * 0.5, 0.0))
	check(hub.move_axis > 0.25 and hub.move_axis < 0.8,
		"half deflection is partial speed (%.2f)" % hub.move_axis)
	hub._touch_up(0)

	# Pushing the stick up used to jump as well as steer, so that one thumb
	# could hold a direction and leave the ground. It cost more than it bought:
	# every steered jump became ambiguous, and a thumb aiming a diagonal got a
	# jump it had not asked for. Jump is the jump button's now -- Options
	# refuses to turn this back on -- so the stick steers however far up it goes.
	var jump_reach: float = travel * ControlLayout.STICK_JUMP_FRACTION
	check(not Options.stick_jump(), "the stick is not a jump source")
	Options.set_stick_jump(true)
	check(not Options.stick_jump(), "and cannot be talked into becoming one")
	hub._touch_down(0, anchor + Vector2(travel * 0.9, -jump_reach * 1.25))
	check(hub.move_axis > 0.6, "a diagonal still moves the runner (%.2f)" % hub.move_axis)
	check(not hub.jump_held, "pushing the stick right up does not hold jump")
	check(not hub.take_jump(), "and does not fire one either")
	hub._touch_move(0, anchor + Vector2(travel * 0.9, 0.0))
	check(hub.move_axis > 0.85, "and the runner keeps moving (%.2f)" % hub.move_axis)
	hub._touch_up(0)

	# The shallow diagonal gives the same answer, which is the point: there is
	# no height at which the stick stops being a stick.
	hub._touch_down(0, anchor + Vector2(travel * 0.9, -jump_reach * 0.5))
	check(not hub.jump_held, "a shallow diagonal does not jump")
	hub._touch_up(0)

	# And a press really does drive the runner, not just the input field.
	var r: Runner = main.runner
	r.global_position = Vector2(-400, 300)
	r.velocity = Vector2.ZERO
	await _physics(24)
	var start := r.global_position.x
	hub._touch_down(0, anchor + Vector2(travel, 0.0))
	await _physics(30)
	hub._touch_up(0)
	check(r.global_position.x - start > 60.0,
		"holding the stick actually moves the runner (%.0fpx)" % (r.global_position.x - start))
	hub.scripted = true
	Options._cache = previous_touch_options

## Online, each device shows and routes only its own half of the game.
##
## This is the bug behind "the guardian's platform, wall and scope cannot be
## put anywhere, they will not move from where they started". On the runner's
## device the guardian's ability bar was still drawn and still hit-tested, and
## the build ghost was still drawn from a reticle that nothing local could
## move. So a thumb on that bar selected an ability and built a slab at
## whatever point the cursor had been initialised to -- every time, the same
## place. Reproduced with the router itself, which is where it lived.
func _test_device_ownership() -> void:
	_current = "device ownership"
	await _boot()
	var hub: InputHub = main.input_hub
	var g: Guardian = main.guardian
	var view: Vector2 = main.get_viewport().get_visible_rect().size

	hub.solo_role = ""
	check(hub.owns_runner_controls() and hub.owns_guardian_controls(),
		"a shared screen owns both halves")
	check(hub.shows_guardian_cursor(), "and draws the guardian's cursor")

	# --- the runner's device ---
	hub.solo_role = "runner"
	hub.remote_aim = false
	check(hub.owns_runner_controls() and not hub.owns_guardian_controls(),
		"the runner's device owns only the runner's controls")
	check(not hub.shows_guardian_cursor(),
		"and draws no guardian cursor before any aim has arrived")

	g.select_slot(1)
	var aim_before: Vector2 = hub.aim_screen
	for slot in [2, 3]:
		# Where those buttons WOULD be if this device showed them. It does not,
		# so the touch has to fall through to nothing.
		hub._touch_down(7, _place("slot_%d" % slot, view, "guardian"))
		hub._touch_up(7)
	check(hub.take_slot_choice() == -1,
		"a thumb on the guardian's ability bar does nothing on the runner's device")
	hub._touch_down(8, Vector2(view.x * 0.70, view.y * 0.40))
	hub._touch_up(8)
	check(hub.aim_screen == aim_before,
		"and a drag past the old divider does not move the guardian's reticle")

	# The runner's own controls still work, at the solo positions.
	var cluster: Dictionary = hub.cluster(view)
	var anchor: Vector2 = cluster["stick"]["center"]
	hub._touch_down(0, anchor
		+ Vector2(ControlLayout.stick_travel(cluster["stick"]), 0.0))
	check(hub.move_axis > 0.5, "the stick still drives the runner")
	hub._touch_up(0)
	hub._touch_down(1, cluster["jump"]["center"])
	check(hub.take_jump(), "and the jump button, now on the far side, still fires")
	hub._touch_up(1)

	# Once the guardian's aim is arriving over the wire there is something real
	# to draw, and the runner should see it: that ghost is their warning.
	hub.remote_aim = true
	check(hub.shows_guardian_cursor(),
		"a runner whose partner is aiming sees the incoming platform")

	# --- the guardian's device: the mirror image ---
	hub.solo_role = "guardian"
	hub.move_axis = 0.0
	hub.aim_active = false
	hub._touch_down(2, anchor)
	check(is_equal_approx(hub.move_axis, 0.0),
		"the guardian's device has no runner stick to catch a thumb")
	hub._touch_up(2)
	# The guardian's own tools ARE on the left now -- they have two thumbs and
	# both should be doing something -- so "the left side aims" is no longer
	# true, and the empty part of the screen is what has to aim.
	check(ControlLayout.hit("guardian", view, false, anchor) != "",
		"the guardian's left hand has controls of its own where the stick was")
	hub.aim_active = false
	hub._touch_down(2, Vector2(view.x * 0.5, view.y * 0.38))
	check(hub.aim_active, "and the clear middle of the screen aims")
	hub._touch_up(2)
	hub.solo_role = ""

## Every control, in every mode, on every shape of screen anyone will hold.
##
## This replaces two narrower audits: one checked the runner's cluster and one
## checked that the guardian's buttons stayed on their side of the divider.
## Neither checked the guardian's buttons against EACH OTHER, which is the
## thing that matters once they are on a thumb arc rather than in a row -- and
## neither ran against a layout the player had moved themselves.
func _test_every_control_is_reachable_and_separate() -> void:
	_current = "control layout"
	ControlLayout.forget()
	# 16:9, a tall phone, the squarest tablet anyone ships, and two odd ones.
	var screens := [Vector2(1280, 720), Vector2(2340, 1080), Vector2(960, 720),
		Vector2(2400, 1080), Vector2(1600, 720)]
	for view in screens:
		for mode in ControlLayout.MODES:
			_audit_layout(String(mode), view, "%s %dx%d" % [mode, view.x, view.y])

	# One device: the left thumb only steers (the stick stays left of the
	# divider); everything pressed -- jump and both tools -- is under the
	# right thumb, on the right half.
	for view in screens:
		var shared := ControlLayout.layout("shared", view, false)
		var divider: float = ControlLayout.DIVIDER * view.x
		check(not shared.has("sprint"), "shared %dx%d: no sprint button" % [view.x, view.y])
		var stick: Dictionary = shared["stick"]
		check(stick["center"].x + float(stick["radius"]) * ControlLayout.STICK_CAPTURE < divider,
			"shared %dx%d: the stick stays left of the divider" % [view.x, view.y])
		for id in ["jump", "slot_1", "slot_3"]:
			check(shared.has(id) and shared[id]["center"].x > view.x * 0.5,
				"shared %dx%d: %s is under the right thumb" % [view.x, view.y, id])
		for id in ["slot_1", "slot_2", "slot_3", "slot_4", "scope"]:
			if not shared.has(id):
				continue
			check(shared[id]["center"].x - float(shared[id]["radius"]) > divider,
				"shared %dx%d: the guardian's %s stays right of it"
					% [view.x, view.y, id])

	# A layout the player has moved is still a layout the router agrees with.
	var view := Vector2(1280, 720)
	ControlLayout.set_place("guardian", "slot_1", Vector2(0.42, 0.33))
	var moved: Dictionary = ControlLayout.layout("guardian", view, false)["slot_1"]
	check(moved["center"].distance_to(Vector2(0.42 * 1280.0, 0.33 * 720.0)) < 1.0,
		"a moved button is where it was put (%s)" % moved["center"])
	check(ControlLayout.hit("guardian", view, false, moved["center"]) == "slot_1",
		"and a thumb there presses it")
	check(ControlLayout.has_custom("guardian"), "the layout counts as customised")
	ControlLayout.reset("guardian")
	check(not ControlLayout.has_custom("guardian"), "and resetting clears it")
	var back: Dictionary = ControlLayout.layout("guardian", view, false)["slot_1"]
	check(back["center"].distance_to(moved["center"]) > 50.0,
		"reset really puts it back where it started")

	# A setting that does not survive the app closing is not a setting.
	ControlLayout.set_place("runner", "jump", Vector2(0.33, 0.44))
	ControlLayout.save()
	ControlLayout.reload()
	var kept: Dictionary = ControlLayout.layout("runner", view, false)["jump"]
	check(kept["center"].distance_to(Vector2(0.33 * 1280.0, 0.44 * 720.0)) < 1.0,
		"a moved control is still there after a reload (%s)" % kept["center"])
	ControlLayout.reset("runner")
	ControlLayout.save()
	ControlLayout.reload()
	check(not ControlLayout.has_custom("runner"), "and a reset survives one too")

	# Mirroring for a role swap has to move the runner's half to the far side.
	var normal: Vector2 = ControlLayout.layout("shared", view, false)["stick"]["center"]
	var swapped: Vector2 = ControlLayout.layout("shared", view, true)["stick"]["center"]
	check(normal.x < view.x * 0.5 and swapped.x > view.x * 0.5,
		"a role swap moves the stick to the other edge")
	ControlLayout.forget()

## A tap is a tap; a drag of the reticle is not, and neither is a swipe of the
## view. All three end in the same _touch_up.
## Two thumbs, four ways they can tread on each other.
##
## Each of these is one line of the brief, and each is checked on its own so a
## failure says which. They pass today -- the hub records what a finger is for
## when it lands and never re-reads it -- and that is exactly why they are
## worth writing down: the property is invisible, so nothing stops it being
## lost.
func _test_two_thumbs_do_not_interfere() -> void:
	_current = "two thumbs"
	await _boot()
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	hub.solo_role = ""
	var stick_at: Vector2 = Vector2(ControlLayout.layout("shared", view, false)["stick"]["center"])
	var jump_at := _place("jump", view, "shared")

	# 1. Jumping while moving must not interrupt the moving.
	hub._touch_down(71, stick_at + Vector2(70.0, 0.0))
	await _physics(2)
	var walking := hub.move_axis
	check(absf(walking) > 0.1, "the stick is moving the runner (%.2f)" % walking)
	hub._touch_down(72, jump_at)
	await _physics(2)
	check(hub.jump_held, "jumping with the other thumb works")
	check(absf(hub.move_axis - walking) < 0.01,
		"and does not interrupt the walking (%.2f -> %.2f)" % [walking, hub.move_axis])

	# 2. Letting go of one must not release the other.
	hub._touch_up(72, jump_at)
	await _physics(2)
	check(not hub.jump_held, "letting go of jump releases jump")
	check(absf(hub.move_axis) > 0.1,
		"and leaves the stick held (%.2f)" % hub.move_axis)

	# 3. A finger that slides off its control keeps doing its own job. What a
	# touch is FOR is decided where it lands; re-deciding it mid-gesture is how
	# a thumb drifting off the stick starts placing platforms.
	hub._touch_move(71, jump_at)
	await _physics(2)
	check(absf(hub.move_axis) > 0.1,
		"a thumb sliding off the stick is still the stick (%.2f)" % hub.move_axis)
	check(not hub.jump_held,
		"and does not become the jump button it slid onto")
	hub._touch_up(71, jump_at)
	await _physics(2)
	check(absf(hub.move_axis) < 0.01, "releasing it stops the runner")

	# 4. A finger that starts on the controls never places anything, however
	# far it travels before letting go.
	hub.solo_role = "guardian"
	var button := _place("slot_1", view, "guardian")
	hub.take_place_at()
	hub._touch_down(73, button)
	hub._touch_move(73, button + Vector2(10.0, -10.0))
	await _physics(2)
	hub._touch_up(73, _place("scope", view, "guardian"))
	var latched := hub.take_place_at()
	check(latched.x == INF,
		"a thumb that starts and ends on the controls places nothing")
	hub.solo_role = ""

## A phone call in the middle of a jump must not leave the runner running.
##
## Android does not reliably send a release for a finger that is down when the
## app goes away -- a call, the task switcher, the screen locking. Without
## something to catch that, the stick stays held: the runner keeps walking in
## whatever direction the thumb was pointing, off whatever they were standing
## on, and comes back to a control that is stuck until it is touched again.
##
## Nothing the player was NOT holding is disturbed. Losing the reticle or the
## chosen tool to a phone call would be its own small betrayal.
func _test_an_interruption_lets_go_of_everything() -> void:
	_current = "interrupted mid-gesture"
	await _boot()
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	hub.solo_role = ""

	# A thumb on the stick and another on jump, which is the normal way to play.
	var stick: Dictionary = ControlLayout.layout("shared", view, false)["stick"]
	hub._touch_down(61, Vector2(stick["center"]) + Vector2(60.0, 0.0))
	hub._touch_down(62, _place("jump", view, "shared"))
	await _physics(3)
	check(absf(hub.move_axis) > 0.1, "the stick is held (%.2f)" % hub.move_axis)
	check(hub.jump_held, "and so is jump")

	# Remember what was NOT being held, so the recovery can be checked for
	# taking too much with it.
	main.guardian.select_slot(2)
	var chosen: int = main.guardian.active_slot
	hub.aim_at_world(Vector2(4321.0, 210.0))
	var aimed := hub.aim_point

	hub.release_everything()
	await _physics(3)
	check(absf(hub.move_axis) < 0.01,
		"the app going away lets go of the stick (%.2f)" % hub.move_axis)
	check(not hub.jump_held, "and of jump")
	check(not hub.dash_held, "and of sprint")

	# Coming back, the controls answer again rather than needing to be
	# un-stuck. A release that left the finger registered would swallow this.
	hub._touch_down(63, Vector2(stick["center"]) + Vector2(60.0, 0.0))
	await _physics(3)
	check(absf(hub.move_axis) > 0.1,
		"and the stick works again afterwards (%.2f)" % hub.move_axis)
	hub._touch_up(63, Vector2(stick["center"]) + Vector2(60.0, 0.0))
	await _physics(2)

	check(main.guardian.active_slot == chosen,
		"the tool the guardian had chosen is still chosen")
	check(hub.aim_point.distance_to(aimed) < 1.0,
		"and the reticle has not moved")
	check(hub.take_place_at().x == INF,
		"and nothing was placed on the way out")

## Where the finger comes up is where it goes.
##
## A touch release is its own event and it carries its own position. That
## position was being dropped -- _touch_up took an index and nothing else -- so
## a commit read the shared reticle, which is wherever the last DRAG event left
## it. Drag slowly and every sample lands near the lift and nothing looks wrong.
## Move quickly and the finger covers real distance between the last sample and
## coming up, so the construct appears behind the thumb.
##
## The latch is read with no frame in between, because the guardian consumes it
## every frame: awaiting first would be asking the game what it did rather than
## what the input decided.
func _test_the_finger_decides_where_it_landed() -> void:
	_current = "placing where the finger lifted"
	await _boot()
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	hub.solo_role = "guardian"
	main.runner.global_position = Vector2(2600, 300)
	main.runner.velocity = Vector2.ZERO
	await _physics(6)
	var to_world := func(p: Vector2) -> Vector2:
		return main.get_viewport().get_canvas_transform().affine_inverse() * p
	# Real events through the real entry point. Calling _touch_up(index, where)
	# by hand would skip the hub's event entry, which is the exact line that was
	# throwing the release position away -- a test that skips it cannot see the
	# bug at all.
	var down := func(i: int, at: Vector2) -> void:
		var e := InputEventScreenTouch.new()
		e.index = i
		e.position = at
		e.pressed = true
		hub.feed(e)
	var drag := func(i: int, at: Vector2) -> void:
		var e := InputEventScreenDrag.new()
		e.index = i
		e.position = at
		hub.feed(e)
	var up := func(i: int, at: Vector2) -> void:
		var e := InputEventScreenTouch.new()
		e.index = i
		e.position = at
		e.pressed = false
		hub.feed(e)

	# A tap: down and up at one place. The release is the ONLY position this
	# gesture ever reports, so a handler that ignores it has nothing at all.
	var spot := Vector2(view.x * 0.62, view.y * 0.52)
	down.call(42, spot)
	await _physics(1)
	up.call(42, spot)
	var tapped := hub.take_place_at()
	check(tapped.x != INF, "a tap on open ground commits")
	if tapped.x != INF:
		check(tapped.distance_to(to_world.call(spot)) < 2.0,
			"exactly where the finger came up (%.1fpx off)"
				% tapped.distance_to(to_world.call(spot)))

	# The same tap, but the finger drifts a few pixels before lifting -- a thumb
	# on glass always does. Still a tap, and it goes where the thumb ENDED.
	var began := Vector2(view.x * 0.50, view.y * 0.46)
	var ended := began + Vector2(7.0, -5.0)
	down.call(44, began)
	await _physics(1)
	up.call(44, ended)
	var drifted := hub.take_place_at()
	check(drifted.x != INF, "a tap that drifts a little is still a tap")
	if drifted.x != INF:
		check(drifted.distance_to(to_world.call(ended)) < 2.0,
			"and lands under the lift, not under the touch-down (%.1fpx off)"
				% drifted.distance_to(to_world.call(ended)))

	# Dragging out of a tool button and letting go: the one gesture that places
	# after real travel, and the one where a stale reticle is most visible. The
	# sample is taken early and the finger comes up a long way past it.
	var button := _place("slot_1", view, "guardian")
	var sampled := button + Vector2(30.0, -20.0)
	# Clear of every control: letting go back ON one is the cancel, and a test
	# that drops onto the scope button is testing the cancel by accident.
	var dropped := Vector2(view.x * 0.55, view.y * 0.25)
	check(ControlLayout.hit("guardian", view, false, dropped) == "",
		"the drop point is open ground, not a button")
	down.call(43, button)
	drag.call(43, sampled)
	await _physics(2)
	up.call(43, dropped)
	var built := hub.take_place_at()
	check(built.x != INF, "dragging out of a tool button commits too")
	if built.x != INF:
		check(built.distance_to(to_world.call(dropped)) < 2.0,
			"at the point the thumb let go (%.1fpx off)"
				% built.distance_to(to_world.call(dropped)))
		check(built.distance_to(to_world.call(sampled)) > 40.0,
			"and not at the last place it was sampled")

	hub.solo_role = ""

func _test_only_a_tap_counts_as_a_tap() -> void:
	_current = "tap, not drag"
	await _boot()
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	hub.solo_role = "guardian"

	var start := Vector2(view.x * 0.6, view.y * 0.45)
	hub._touch_down(1, start)
	hub._touch_up(1)
	check(hub.take_place_at().x != INF, "a finger down and up in one place is a tap")

	hub._touch_down(2, start)
	hub._touch_move(2, start + Vector2(0.0, -140.0))
	hub._touch_up(2)
	check(hub.take_place_at().x == INF, "dragging the reticle is not")

	hub._touch_down(3, start)
	for i in range(6):
		hub._touch_move(3, start + Vector2(-40.0 * float(i + 1), 0.0))
	hub._touch_up(3)
	check(hub.take_place_at().x == INF, "and neither is swiping the view")
	hub.solo_role = ""
	await _frames(2)

## Sizes are a setting too. Hands differ more than screens do.
func _test_controls_can_be_resized() -> void:
	_current = "control size"
	ControlLayout.forget()
	var view := Vector2(1280, 720)
	var before: float = ControlLayout.layout("guardian", view, false)["slot_1"]["radius"]

	ControlLayout.set_size("guardian", "slot_1", 1.5)
	var bigger: Dictionary = ControlLayout.layout("guardian", view, false)["slot_1"]
	check_near(float(bigger["radius"]), before * 1.5, 0.5,
		"a resized control is the size it was set to")
	# The hit area has to grow with the drawing, which is the whole reason the
	# two come from one table.
	var edge: Vector2 = bigger["center"] + Vector2(before * 1.3, 0.0)
	check(ControlLayout.hit("guardian", view, false, edge) == "slot_1",
		"and a thumb on the new edge presses it")

	# Moving it afterwards must not silently undo the size, and vice versa.
	ControlLayout.set_place("guardian", "slot_1", Vector2(0.5, 0.5))
	check_near(ControlLayout.size_of("guardian", "slot_1"), 1.5, 0.01,
		"moving a control keeps its size")
	ControlLayout.set_size("guardian", "slot_1", 0.8)
	var moved: Vector3 = ControlLayout.saved_place("guardian", "slot_1")
	check(is_equal_approx(moved.x, 0.5) and is_equal_approx(moved.y, 0.5),
		"and resizing keeps its place (%s)" % moved)

	# Clamped at both ends: too small to hit, or big enough to swallow its
	# neighbours, are both layouts nobody can use.
	ControlLayout.set_size("guardian", "slot_1", 9.0)
	check_near(ControlLayout.size_of("guardian", "slot_1"), ControlLayout.SIZE_MAX,
		0.01, "a size is capped at the top")
	ControlLayout.set_size("guardian", "slot_1", 0.01)
	check_near(ControlLayout.size_of("guardian", "slot_1"), ControlLayout.SIZE_MIN,
		0.01, "and at the bottom")

	ControlLayout.save()
	ControlLayout.reload()
	check_near(ControlLayout.size_of("guardian", "slot_1"), ControlLayout.SIZE_MIN,
		0.01, "a size survives a reload")
	ControlLayout.reset("guardian")
	ControlLayout.save()
	check_near(ControlLayout.size_of("guardian", "slot_1"), 1.0, 0.01,
		"and reset returns it to the default")
	ControlLayout.forget()
