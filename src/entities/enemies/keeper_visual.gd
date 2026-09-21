extends Node2D
## Draws the Keeper so both players can read the SAME thing from it, which in
## this fight is one question asked twice a cycle:
##
##   is it about to charge, and is the core open?
##
## The runner reads the first and the guardian reads the second, off the same
## picture, on two devices that are ~60ms apart. So the two states that matter
## are separated on every channel at once -- pose, colour, and a mark that is
## drawn nowhere else:
##
##   BRACE    the body drops and leans, the eyes go white-hot, and the charge
##            lane is drawn on the ground in front of it
##   STAGGER  the body slumps the other way, the eyes go dark, and the core
##            (drawn by Keeper.Core, not here) opens
##
## When the painted set arrives this whole file becomes four texture keys and a
## tilt; until then it is the fallback, and the fallback has to be readable on
## its own or the stage cannot be playtested before the art exists.

var keeper: Keeper = null

const STONE := Color(0.36, 0.39, 0.37)
const STONE_DARK := Color(0.22, 0.25, 0.24)
const STONE_LIGHT := Color(0.49, 0.52, 0.49)
const IRON := Color(0.30, 0.27, 0.25)
const EYE_CALM := Color(0.85, 0.50, 0.18)
const EYE_HOT := Color(1.0, 0.95, 0.80)
const LANE := Color(1.0, 0.55, 0.20)

var _phase: float = 0.0

func _ready() -> void:
	z_index = 6

func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()

func _draw() -> void:
	if keeper == null or not is_instance_valid(keeper):
		return
	# Two sizes. The node's origin is the middle of the HITBOX, so the feet are
	# half a hitbox down; the painting is bigger than the hitbox and hangs off
	# it, which is what lets a runner who jumped at the right moment pass
	# through the legs of something that looks too wide to jump. See
	# Balance.KEEPER_HITBOX.
	var size: Vector2 = Balance.KEEPER_SIZE
	var foot := Balance.KEEPER_HITBOX.y * 0.5
	var face := float(keeper.facing)
	var state: int = keeper.state

	# The charge lane, on the ground, during the wind-up. The one piece of UI in
	# the fight, and it is in the world rather than on the HUD because both
	# players need it and only one of them has a HUD worth putting it on.
	if state == Keeper.State.BRACE:
		_draw_lane(face, foot)
	if has_meta("model_3d"):
		if state == Keeper.State.BRACE or state == Keeper.State.CHARGE:
			_draw_dust(size,foot)
		return

	var lean := 0.0
	var drop := 0.0
	match state:
		Keeper.State.BRACE:
			lean = face * 0.14
			drop = 10.0
		Keeper.State.CHARGE:
			lean = face * 0.20
			drop = 14.0
		Keeper.State.STAGGER:
			lean = -face * 0.22
			drop = 6.0
		Keeper.State.SLAM:
			drop = 16.0
		Keeper.State.DYING:
			lean = -face * 0.35
			drop = 22.0

	var key := _texture_key(state)
	draw_set_transform(Vector2(0.0, foot), lean, Vector2.ONE)
	var body := Rect2(-size.x * 0.5, -size.y + drop, size.x, size.y - drop)
	if not Art.draw_stretched_flipped(self, key, body, face > 0.0):
		_draw_vector_body(body, face, state)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Dust at the feet while it is braced or charging, so weight is something
	# the picture claims rather than something the numbers know.
	if state == Keeper.State.BRACE or state == Keeper.State.CHARGE:
		_draw_dust(size, foot)

## Where the charge is going, drawn flat on the floor.
##
## Stops at KEEPER_CHARGE_DISTANCE, which is the real number the state machine
## uses -- so a runner standing past the end of the stripe is genuinely safe and
## the drawing is not a promise the physics breaks.
func _draw_lane(face: float, foot: float) -> void:
	var half := Balance.KEEPER_HITBOX.x * 0.5
	var from := Vector2(face * half, foot - 6.0)
	var to := Vector2(face * (half + Balance.KEEPER_CHARGE_DISTANCE), foot - 6.0)
	var urgency := 0.0
	if keeper.telegraph_time() > 0.0:
		urgency = 1.0 - clampf(keeper.timer_left() / keeper.telegraph_time(), 0.0, 1.0)
	# Thickens and brightens as the wind-up runs out: "now" is visible without
	# anybody reading a number.
	#
	# All of these numbers went up after the first screenshots. The lane was
	# drawn at alpha 0.18 with arrows that blinked on and off, and in a 1280x720
	# capture of the wind-up it was a faint smudge with one arrow lit -- for the
	# one piece of UI both players are reading, and the only warning the runner
	# gets. It is now a solid band with a bright edge, and the arrows all stay
	# up while a highlight runs along them.
	draw_line(from, to, Color(LANE, 0.34 + 0.34 * urgency), 22.0 + 14.0 * urgency, true)
	draw_line(Vector2(from.x, from.y + 11.0), Vector2(to.x, to.y + 11.0),
		Color(1.0, 0.85, 0.45, 0.55 + 0.35 * urgency), 3.0, true)
	var arrows := 6
	for i in range(arrows):
		var t := (float(i) + 0.5) / float(arrows)
		var at := from.lerp(to, t)
		# A travelling highlight, not a blink: every arrow is always legible and
		# the bright one sweeps the way the charge is going.
		var sweep := maxf(0.0, sin(_phase * 7.0 - float(i) * 0.9))
		var glow := 0.55 + 0.45 * sweep
		var wing := Vector2(-face * 17.0, 12.0)
		draw_line(at, at + wing, Color(1.0, 0.78 + 0.2 * sweep, 0.35, glow), 5.0, true)
		draw_line(at, at + Vector2(wing.x, -wing.y),
			Color(1.0, 0.78 + 0.2 * sweep, 0.35, glow), 5.0, true)

func _draw_dust(size: Vector2, base: float) -> void:
	for i in range(5):
		var t := fmod(_phase * 1.7 + float(i) * 0.37, 1.0)
		var x := lerpf(-size.x * 0.45, size.x * 0.45, float(i) / 4.0)
		draw_circle(Vector2(x, base - 4.0 - t * 26.0), 3.0 + t * 5.0,
			Color(0.62, 0.60, 0.55, 0.30 * (1.0 - t)))

## Which painting this state wants. Four, because four is how many distinct
## things the fight asks the player to tell apart.
func _texture_key(state: int) -> String:
	match state:
		Keeper.State.BRACE: return "keeper_brace"
		Keeper.State.CHARGE: return "keeper_charge"
		Keeper.State.STAGGER, Keeper.State.SLAM, Keeper.State.DYING:
			return "keeper_reel"
		_: return "keeper_stand"

func _draw_vector_body(body: Rect2, face: float, state: int) -> void:
	var hot := state == Keeper.State.BRACE or state == Keeper.State.CHARGE
	var dazed := state == Keeper.State.STAGGER or state == Keeper.State.DYING

	# Four legs, so the silhouette is a siege engine rather than a box.
	var foot := body.position.y + body.size.y
	for i in range(4):
		var lx := body.position.x + body.size.x * (0.14 + 0.24 * float(i))
		var swing := 0.0
		if state == Keeper.State.CHARGE:
			swing = sin(_phase * 16.0 + float(i) * 1.6) * 11.0
		elif state == Keeper.State.WALK:
			swing = sin(_phase * 3.4 + float(i) * 1.6) * 5.0
		var hip := foot - body.size.y * 0.30
		# A knee, so a leg is a leg rather than a table support. It is the only
		# thing in this silhouette that says the box can move.
		var knee := Vector2(lx + swing * 0.5, hip + (foot - hip) * 0.55
			+ (4.0 if i % 2 == 0 else -3.0))
		draw_line(Vector2(lx, hip), knee, IRON, 15.0)
		draw_line(knee, Vector2(lx + swing, foot), IRON, 12.0)
		draw_circle(knee, 7.5, STONE_DARK)
		draw_circle(Vector2(lx + swing, foot - 3.0), 8.0, STONE_DARK)

	# The slab body: a wedge rather than a rectangle, heavy at the front, so
	# which way it is pointing is legible from the outline alone.
	var hull := Rect2(body.position.x, body.position.y,
		body.size.x, body.size.y * 0.74)
	var front := hull.position.x + hull.size.x if face > 0.0 else hull.position.x
	var back_x := hull.position.x if face > 0.0 else hull.position.x + hull.size.x
	var shoulder := lerpf(front, back_x, 0.30)
	var hump := PackedVector2Array([
		Vector2(front, hull.position.y + hull.size.y * 0.22),
		Vector2(shoulder, hull.position.y - hull.size.y * 0.16),
		Vector2(lerpf(front, back_x, 0.72), hull.position.y - hull.size.y * 0.06),
		Vector2(back_x, hull.position.y + hull.size.y * 0.34),
		Vector2(back_x, hull.position.y + hull.size.y),
		Vector2(front, hull.position.y + hull.size.y),
	])
	draw_colored_polygon(hump, STONE)
	draw_polyline(hump, STONE_DARK, 3.0, true)
	draw_line(hump[0], hump[5], STONE_DARK, 3.0, true)
	draw_rect(Rect2(hull.position.x, hull.position.y + hull.size.y * 0.42,
		hull.size.x, hull.size.y * 0.16), Color(STONE_LIGHT, 0.35))
	# Iron bands.
	for i in range(3):
		var bx := hull.position.x + hull.size.x * (0.20 + 0.28 * float(i))
		draw_rect(Rect2(bx, hull.position.y, 9.0, hull.size.y), Color(IRON, 0.85))
	# Seams glow when there is pressure inside.
	if hot:
		var breath := 0.55 + 0.45 * sin(_phase * 12.0)
		for i in range(3):
			var sy := hull.position.y + hull.size.y * (0.28 + 0.24 * float(i))
			draw_line(Vector2(hull.position.x + 5.0, sy),
				Vector2(hull.position.x + hull.size.x - 5.0, sy),
				Color(1.0, 0.58, 0.20, 0.35 + 0.45 * breath), 3.0, true)

	# The head, out in front, low. This is the part that has to read at a
	# glance: it drops in BRACE and CHARGE and hangs in STAGGER.
	var head_w := body.size.x * 0.34
	var head_h := body.size.y * 0.42
	var head_x: float = body.position.x + body.size.x - head_w if face > 0.0 \
		else body.position.x
	var head_y := hull.position.y + hull.size.y * (0.80 if dazed else 0.42)
	var head := Rect2(head_x, head_y, head_w, head_h)
	draw_rect(head, STONE_DARK)
	draw_rect(head, IRON, false, 3.0)
	# A jaw, thrust the way it is facing. Without it the head is a second box on
	# a stack of boxes, and the thing has no front.
	var jaw_x: float = head.position.x + head.size.x if face > 0.0 else head.position.x
	var jaw := PackedVector2Array([
		Vector2(jaw_x, head.position.y + head.size.y * 0.35),
		Vector2(jaw_x + face * head_w * 0.42, head.position.y + head.size.y * 0.62),
		Vector2(jaw_x, head.position.y + head.size.y),
	])
	draw_colored_polygon(jaw, IRON)
	draw_polyline(jaw, STONE_DARK, 2.5, true)

	# The eyes. Two slits, and their colour is the state -- which, with the
	# pose, is how a player tells a wind-up from a walk without reading a HUD.
	var eye_col := EYE_CALM
	if hot:
		eye_col = EYE_HOT
	elif dazed:
		eye_col = Color(0.35, 0.33, 0.31)
	var eye_x := head.position.x + (head.size.x * 0.14 if face < 0.0 else head.size.x * 0.50)
	for i in range(2):
		var er := Rect2(eye_x, head.position.y + head.size.y * (0.24 + 0.26 * float(i)),
			head.size.x * 0.36, 6.0)
		if hot:
			draw_rect(er.grow(5.0), Color(eye_col, 0.30))
		draw_rect(er, eye_col)

	# Cracks once it is hurt, so six wounds are six visible things.
	var wounds := Balance.KEEPER_HP - keeper.hp
	for i in range(mini(wounds, 6)):
		var cx := hull.position.x + hull.size.x * (0.12 + 0.14 * float(i))
		draw_line(Vector2(cx, hull.position.y + 6.0),
			Vector2(cx + 9.0, hull.position.y + hull.size.y - 8.0),
			Color(0.13, 0.12, 0.11, 0.8), 2.5, true)
