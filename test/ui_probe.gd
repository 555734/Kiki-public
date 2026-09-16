extends Node
## Drives the connect screen with real touch events under a real display.
##
## This exists because every button on it was dead on Android and nothing in the
## headless suite could have caught it: a Control never receives a touch, only
## the mouse event Godot emulates from one, and emulation had been switched off
## for the game's own multitouch routing. Headless has no GUI picking at all --
## even a synthetic mouse click does nothing there -- so this has to run under
## xvfb, which is why it is part of `tools/verify.sh --shots` rather than the
## main suite.
##
##   xvfb-run godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 res://test/ui_probe.tscn

var _failures: int = 0

func _ready() -> void:
	# A hard stop. If anything below throws, the coroutine dies without ever
	# reaching quit() and the run hangs forever instead of failing -- which is
	# what happened, and a test that hangs is worse than one that fails.
	get_tree().create_timer(45.0).timeout.connect(func() -> void:
		print("--- ui: TIMED OUT ---")
		get_tree().quit(1))

	var main: Node = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(15)

	var panel: Node = main.get_node_or_null("NetPanel")
	_check(panel != null, "the connect screen is shown at startup")
	_check(Input.is_emulating_mouse_from_touch(),
		"touch is emulated as mouse, or no Control can ever be pressed")
	_check(not main.input_hub.is_processing_unhandled_input(),
		"the game's input router stands down while the panel is up")

	if panel != null:
		var button := _find_button(panel, "1台")
		_check(button != null, "the local-play button exists")
		if button != null:
			await _tap(button.get_global_rect().get_center())
			_check(not is_instance_valid(panel) or panel.is_queued_for_deletion(),
				"a touch on it dismisses the connect screen")
			await _frames(3)
			_check(main.input_hub.is_processing_unhandled_input(),
				"and the game gets its input back")
			# p2_use is bound to the left mouse button, and touch is emulated as a
			# mouse, so this single tap used to fire the guardian's ability as well
			# as dismiss the panel: 30 gauge gone and a platform on the runner's
			# head before the game had begun.
			_check(main.guardian.gauge >= Balance.GAUGE_MAX - 0.5,
				"choosing a mode does not spend the guardian's gauge (%.0f)"
					% main.guardian.gauge)
			_check(main.guardian.holograms_of(Hologram.Kind.PLATFORM).is_empty(),
				"and does not build anything")

	await _aim_belongs_to_its_own_device(main)
	await _the_guardian_can_actually_build(main)
	await _controls_can_be_moved(main)
	await _backdrop_has_no_holes(main)

	print("--- ui: %d failed ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

## A real press: a touch event through Input, which is the path a phone takes.
func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(3)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1

func _find_button(root: Node, contains: String) -> Button:
	if root is Button and String((root as Button).text).contains(contains):
		return root
	for child in root.get_children():
		var found := _find_button(child, contains)
		if found != null:
			return found
	return null

## The guardian's cursor, driven by real fingers.
##
## Reported as "the platform, the wall and the scope cannot be placed freely,
## they will not move from where they started". It reproduces only with the
## whole input path running: the guardian's own device follows the thumb, and
## the runner's device -- where nothing local aims -- used to draw the same
## furniture frozen at its starting point and let a thumb build there.
func _aim_belongs_to_its_own_device(main: Node) -> void:
	var hub = main.input_hub
	var g = main.guardian
	var view: Vector2 = main.get_viewport().get_visible_rect().size

	# --- positive control: the guardian's own device ---
	hub.solo_role = "guardian"
	hub.remote_aim = false
	g.select_slot(1)
	await _frames(3)
	# A TAP puts the reticle where you touched. A long drag no longer does --
	# that gesture scrolls the view now -- so the two are checked separately.
	var d := await _tap_moves_ghost(main)
	_check(float(d["preview"]) > 60.0,
		"guardian device: a tap moves the build ghost (%.0fpx)" % d["preview"])
	main.guardian_pan = 0.0
	var swipe := await _drag_across(main)
	_check(absf(main.guardian_pan) > 100.0,
		"guardian device: a long drag scrolls the view instead (%.0fpx)"
			% main.guardian_pan)
	_check(float(swipe["preview"]) < 40.0,
		"and does not drag the reticle along with it (%.0fpx)" % swipe["preview"])
	main.guardian_pan = 0.0
	# The scope is its own control now; selecting the sniper does not raise it.
	g.set_scope(true)
	await _wait(0.4)
	d = await _tap_moves_ghost(main)
	_check(float(d["scope"]) > 60.0,
		"guardian device: the optic follows a tap (%.0fpx)" % d["scope"])
	main.guardian_pan = 0.0
	_check(main.scope.visible, "and the optic is up on the device that aims it")

	# Lower it before switching devices. set_scope is idempotent -- raising an
	# already-raised scope emits nothing -- so without this the runner-device
	# check below would be looking at an optic left up by the phase before it,
	# and would pass or fail for the wrong reason.
	g.set_scope(false)
	await _wait(0.4)

	# --- the runner's device, before any aim has arrived ---
	hub.solo_role = "runner"
	hub.remote_aim = false
	g.select_slot(1)
	await _wait(0.4)
	_check(not hub.shows_guardian_cursor(),
		"runner device: no guardian cursor until their aim actually arrives")

	# The guardian raising the sight reaches the runner's device as a SLOT
	# message, and used to dim their screen and magnify a ring around a point
	# they could not move. The optic belongs to the eye that aims it.
	g.set_scope(true)
	await _wait(0.4)
	_check(not main.scope.visible,
		"runner device: the guardian's optic does not take over the runner's screen")
	g.set_scope(false)
	g.select_slot(1)
	await _wait(0.4)

	var aim_before: Vector2 = hub.aim_screen
	d = await _tap_moves_ghost(main)
	_check(hub.aim_screen == aim_before and float(d["preview"]) < 0.5,
		"runner device: a touch moves nothing the guardian owns")

	# The symptom itself: a thumb on the ability bar used to select a tool and
	# build a slab at the stale reticle, over and over in the same spot.
	await _tap(_place("slot_3", view, "shared"))
	_check(g.active_slot == 1,
		"runner device: the guardian's ability buttons are not reachable")
	var slabs: int = g.holograms_of(Hologram.Kind.PLATFORM).size()
	await _tap(_place("scope", view, "shared"))
	await _frames(3)
	# "No more than before", not "exactly as before": constructs expire on a
	# timer, so a slab placed earlier in this probe can lapse between the two
	# counts. What is asserted here is that nothing was CREATED.
	_check(g.holograms_of(Hologram.Kind.PLATFORM).size() <= slabs,
		"runner device: and no platform appears at the frozen reticle")

	# --- the runner's device, once the guardian's aim is arriving ---
	hub.remote_aim = true
	_check(hub.shows_guardian_cursor(),
		"runner device: an incoming platform is shown once aim is live")
	hub.solo_role = ""

## One finger TAPPED at two different places, reporting how far the build ghost
## and the optic moved between them. Tapping is how the reticle is placed now;
## dragging scrolls.
func _tap_moves_ghost(main: Node) -> Dictionary:
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	var g = main.guardian
	var a := Vector2(view.x * 0.55, view.y * 0.55)
	var b := Vector2(view.x * 0.85, view.y * 0.25)
	_touch(1, a, true)
	await _frames(3)
	var p1: Dictionary = g.current_preview()
	var s1: Vector2 = main.scope.centre()
	_touch(1, a, false)
	await _frames(2)
	_touch(1, b, true)
	await _frames(3)
	var p2: Dictionary = g.current_preview()
	var s2: Vector2 = main.scope.centre()
	_touch(1, b, false)
	await _frames(2)
	var moved := 0.0
	if p1.has("rect") and p2.has("rect"):
		moved = (p1["rect"] as Rect2).position.distance_to((p2["rect"] as Rect2).position)
	return {"preview": moved, "scope": s1.distance_to(s2)}

## One finger dragged across the guardian's area, reporting how far the build
## ghost and the optic moved with it.
func _drag_across(main: Node) -> Dictionary:
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	var g = main.guardian
	var a := Vector2(view.x * 0.55, view.y * 0.55)
	var b := Vector2(view.x * 0.85, view.y * 0.25)
	_touch(1, a, true)
	await _frames(3)
	var p1: Dictionary = g.current_preview()
	var s1: Vector2 = main.scope.centre()
	_drag(1, b)
	await _frames(3)
	var p2: Dictionary = g.current_preview()
	var s2: Vector2 = main.scope.centre()
	_touch(1, b, false)
	await _frames(2)
	var moved := 0.0
	if p1.has("rect") and p2.has("rect"):
		var r1: Rect2 = p1["rect"]
		var r2: Rect2 = p2["rect"]
		moved = r1.position.distance_to(r2.position)
	return {"preview": moved, "scope": s1.distance_to(s2)}

func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	Input.parse_input_event(e)

func _drag(index: int, to: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = to
	Input.parse_input_event(e)

## Real seconds, not frames: the optic fades in and out over wall-clock time and
## a frame here is nowhere near long enough.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

## The painted backdrop must actually cover the screen.
##
## It is 1663px wide and every other copy is mirrored, so at most camera
## positions one of the two tiles on screen is a mirrored one. Mirroring used to
## be done by handing draw_texture_rect a negative-width Rect2, and Godot builds
## the cull rect from that without normalising the negative size -- so the tile
## reported a box starting at its far corner, off the right of the viewport, and
## was culled entirely. Half the sky was the bare gradient, and no headless
## check could have seen it: it is a question about pixels.
##
## Measured as horizontal detail rather than as colour. The backdrop is hills,
## trees and a waterfall; the gradient it exposes is perfectly uniform across
## any row, so "does this row change as we walk along it" separates them without
## caring what either looks like.
func _backdrop_has_no_holes(main: Node) -> void:
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	# A camera position where the tile boundary lands mid-screen.
	main.runner.global_position = Vector2(2600, 300)
	main.camera.global_position = Vector2(2600, 260)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()

	var x0 := int(view.x * 0.70)
	var x1 := int(view.x) - 6
	var best := 0
	for y in range(int(view.y * 0.20), int(view.y * 0.55), 4):
		var changes := 0
		var previous := img.get_pixel(x0, y)
		for x in range(x0 + 1, x1):
			var here := img.get_pixel(x, y)
			if absf(here.r - previous.r) + absf(here.g - previous.g) \
					+ absf(here.b - previous.b) > 0.03:
				changes += 1
			previous = here
		best = maxi(best, changes)
	_check(best > 70,
		"the backdrop covers the right of the screen (%d columns of detail)" % best)

## Choose a tool, then tap where it goes -- on a real display, with real touch
## events, through the real hit tables.
##
## This is the interaction the whole guardian side rests on, and it has been
## wrong twice. First the tool button WAS the commit, so the place had to come
## from somewhere else and never matched what the player had pointed at. Then
## the drag carried a lift, so even the gesture that did point landed a
## fingertip high. Both are gone; what is left is one rule, checked here.
func _the_guardian_can_actually_build(main: Node) -> void:
	var hub = main.input_hub
	var g = main.guardian
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	main.guardian_pan = 0.0
	hub.solo_role = "guardian"
	hub.remote_aim = false
	main.runner.global_position = Vector2(600, 300)
	main.camera.global_position = Vector2(600, 260)
	await _frames(6)

	var to_world := func(screen: Vector2) -> Vector2:
		return main.get_viewport().get_canvas_transform().affine_inverse() * screen

	# --- the button chooses, and builds nothing ---
	g.gauge = Balance.GAUGE_MAX
	g.clear_constructs()
	g.select_slot(2)                       # a DIFFERENT tool, so a stale one shows
	await _frames(2)
	var before_gauge: float = g.gauge
	await _tap(_place("slot_1", view))
	await _frames(4)
	_check(g.holograms_of(Hologram.Kind.PLATFORM).is_empty(),
		"choosing a tool builds nothing")
	_check(is_equal_approx(g.gauge, before_gauge),
		"and spends nothing (%.0f -> %.0f)" % [before_gauge, g.gauge])
	_check(g.active_slot == 1, "but it IS chosen now (slot %d)" % g.active_slot)

	# --- then a tap on the world puts it exactly there ---
	var spot := Vector2(view.x * 0.62, view.y * 0.50)
	var want: Vector2 = to_world.call(spot)
	await _tap(spot)
	await _frames(6)
	var slabs: Array = g.holograms_of(Hologram.Kind.PLATFORM)
	_check(slabs.size() == 1, "a tap on the world builds one (%d)" % slabs.size())
	if slabs.size() > 0:
		var off: float = slabs.back().global_position.distance_to(want)
		_check(off < 1.0, "exactly under the finger (%.2fpx off)" % off)
		# The lift used to put it a fingertip above. Assert the absence.
		_check(absf(slabs.back().global_position.y - want.y) < 1.0,
			"not lifted clear of it (%.2fpx of y)"
				% absf(slabs.back().global_position.y - want.y))

	# --- the choice sticks: the next one needs no button at all ---
	var second := Vector2(view.x * 0.74, view.y * 0.44)
	var want2: Vector2 = to_world.call(second)
	await _tap(second)
	await _frames(6)
	slabs = g.holograms_of(Hologram.Kind.PLATFORM)
	_check(slabs.size() == 2, "the tool stays chosen for the next tap (%d)" % slabs.size())
	if slabs.size() > 1:
		_check(slabs.back().global_position.distance_to(want2) < 1.0,
			"and that one lands under its finger too")

	# --- drag out of the button and let go: the same thing, one gesture ---
	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	await _frames(2)
	# Clear air. A wall is 190px tall, so a spot that looks open at the slab's
	# centre can still have its feet in the ground -- which is refused, and
	# correctly so.
	var drop := Vector2(view.x * 0.55, view.y * 0.30)
	var want3: Vector2 = to_world.call(drop)
	_touch(2, _place("slot_2", view), true)
	await _frames(3)
	_check(g.holograms_of(Hologram.Kind.WALL).is_empty(),
		"holding a tool button still builds nothing")
	_drag(2, drop)
	await _frames(3)
	var ghost: Dictionary = g.current_preview()
	var shape: Vector2 = ghost["rect"].size if ghost.has("rect") else Vector2.ZERO
	_check(shape.is_equal_approx(Balance.WALL_SIZE),
		"the ghost is the tool being held (%s)" % shape)
	_touch(2, drop, false)
	await _frames(6)
	var walls: Array = g.holograms_of(Hologram.Kind.WALL)
	_check(walls.size() == 1, "letting go builds exactly one (%d)" % walls.size())
	if walls.size() > 0:
		_check(walls.back().global_position.distance_to(want3) < 1.0,
			"where the finger let go (%.2fpx off)"
				% walls.back().global_position.distance_to(want3))

	# --- somewhere it cannot go is refused, not relocated ---
	#
	# The old rule would quietly move a blocked placement to wherever it
	# decided was better. Saying no is the honest answer, and the guardian can
	# see why: the reason is on screen for a moment.
	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(1)
	await _frames(2)
	var held: float = g.gauge
	var into_the_ground := Vector2(view.x * 0.52, view.y * 0.92)
	await _tap(into_the_ground)
	await _frames(6)
	_check(g.holograms_of(Hologram.Kind.PLATFORM).is_empty(),
		"a spot it cannot go is refused")
	_check(is_equal_approx(g.gauge, held), "with nothing spent")
	_check(g._last_refusal != "", "and a reason given (%s)" % g._last_refusal)

	# --- dragging back onto the controls cancels ---
	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	await _frames(2)
	var kept: float = g.gauge
	_touch(2, _place("slot_1", view), true)
	await _frames(2)
	_drag(2, Vector2(view.x * 0.60, view.y * 0.45))
	await _frames(2)
	_drag(2, _place("slot_1", view))
	await _frames(2)
	_touch(2, _place("slot_1", view), false)
	await _frames(6)
	_check(g.holograms_of(Hologram.Kind.PLATFORM).is_empty(),
		"letting go back on the buttons builds nothing")
	_check(is_equal_approx(g.gauge, kept), "and spends nothing")

	# --- a swipe of the view is not a placement ---
	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(1)
	await _frames(2)
	var swipe_from := Vector2(view.x * 0.70, view.y * 0.45)
	_touch(3, swipe_from, true)
	for i in range(6):
		_drag(3, swipe_from + Vector2(-45.0 * float(i + 1), 0.0))
		await _frames(1)
	_touch(3, swipe_from + Vector2(-270.0, 0.0), false)
	await _frames(6)
	_check(g.holograms_of(Hologram.Kind.PLATFORM).is_empty(),
		"scrolling the view does not drop a slab where the finger stopped")
	main.guardian_pan = 0.0

	# --- the rifle is the same two steps ---
	var shots := [0]
	var count := func(_f: Vector2, _t: Vector2, _hit: bool) -> void: shots[0] += 1
	Events.shot_fired.connect(count)
	g.gauge = Balance.GAUGE_MAX
	await _tap(_place("slot_3", view))
	await _frames(4)
	_check(shots[0] == 0, "choosing the rifle does not fire it")
	await _tap(Vector2(view.x * 0.72, view.y * 0.42))
	await _frames(6)
	Events.shot_fired.disconnect(count)
	_check(shots[0] == 1, "and a tap on the world fires once (%d)" % shots[0])

	# --- the target is a place in the world, not a pixel on the screen ---
	#
	# The camera follows the runner. A reticle stored as a screen point drifts
	# across the level while they run, so the guardian aims at the gap and the
	# slab arrives somewhere else -- 32px away in the first run of this probe.
	await _tap(Vector2(view.x * 0.66, view.y * 0.40))
	var pinned: Vector2 = g.aim_world()
	main.camera.global_position += Vector2(260, 0)
	await _frames(4)
	_check(g.aim_world().distance_to(pinned) < 0.5,
		"the target stays on the ground it was put on when the camera moves (%.0fpx)"
			% g.aim_world().distance_to(pinned))
	hub.solo_role = ""


## Where a control actually is, from the same table the game uses.
func _place(id: String, view: Vector2, mode: String = "guardian") -> Vector2:
	return ControlLayout.layout(mode, view, false)[id]["center"]

## Dragging a control somewhere else has to move the thing you PRESS, not just
## the thing you see. They come from one table now, and this is the check that
## keeps them there -- a button drawn where it cannot be pressed is the one bug
## a player has no way to work around.
func _controls_can_be_moved(main: Node) -> void:
	main.guardian_pan = 0.0
	ControlLayout.forget()
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	var editor := LayoutEditor.new()
	add_child(editor)
	await _frames(6)
	_check(editor.mode() == "guardian", "the editor opens on the guardian's layout")

	var before: Vector2 = ControlLayout.layout("guardian", view, false)["slot_1"]["center"]
	var to := Vector2(view.x * 0.40, view.y * 0.30)
	_touch(1, before, true)
	await _frames(3)
	_drag(1, to)
	await _frames(3)
	_touch(1, to, false)
	await _frames(4)

	var after: Vector2 = ControlLayout.layout("guardian", view, false)["slot_1"]["center"]
	_check(after.distance_to(to) < 2.0,
		"the dragged control ends up under the finger (%.0fpx away)"
			% after.distance_to(to))
	_check(ControlLayout.hit("guardian", view, false, after) == "slot_1",
		"and a touch there presses it")
	_check(ControlLayout.hit("guardian", view, false, before) != "slot_1",
		"and a touch where it used to be does not")

	# It survives being written out and read back, which is what "設定できる"
	# has to mean -- a layout that resets when the app closes is not a setting.
	ControlLayout.save()
	ControlLayout.reload()
	var reloaded: Vector2 = ControlLayout.layout("guardian", view, false)["slot_1"]["center"]
	_check(reloaded.distance_to(to) < 2.0,
		"it is still there after a reload (%.0fpx away)" % reloaded.distance_to(to))

	ControlLayout.reset("guardian")
	ControlLayout.save()
	var reset_to: Vector2 = ControlLayout.layout("guardian", view, false)["slot_1"]["center"]
	_check(reset_to.distance_to(before) < 2.0, "and reset puts it back")
	editor.queue_free()
	await _frames(3)
	ControlLayout.forget()
