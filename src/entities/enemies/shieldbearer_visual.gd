extends Node2D
## Draws the shield-bearer so both players can read the same thing from it:
## which side the plate is on, whether it is mid-turn, and whether the soft spot
## is open right now.
##
## The runner needs it to know which way to run; the guardian needs it to know
## whether to fire. It is the same picture for both, which is what lets them act
## without speaking.

var bearer: Shieldbearer = null

const BODY := Color(0.34, 0.30, 0.42)
const BODY_EDGE := Color(0.20, 0.17, 0.26)
const PLATE := Color(0.72, 0.76, 0.84)
const PLATE_EDGE := Color(0.45, 0.50, 0.60)
const WEAK_OPEN := Color(1.0, 0.42, 0.38)
const WEAK_SHUT := Color(0.42, 0.40, 0.45)

var _phase: float = 0.0

func _ready() -> void:
	z_index = 6

func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()

func _draw() -> void:
	if bearer == null or not is_instance_valid(bearer):
		return
	var size: Vector2 = Balance.SHIELDBEARER_SIZE
	if not has_meta("model_3d"):
		draw_rect(Rect2(-size * 0.5, size), BODY, true)
		draw_rect(Rect2(-size * 0.5, size), BODY_EDGE, false, 2.0)

	var face := float(bearer.facing_now())

	# The soft spot, on the back. Open is a bright pulse; shut is grey and
	# still, and the difference has to be legible at a glance from across a
	# table or across a network.
	var weak_at := Vector2(-face * Shieldbearer.REACH, 0.0)
	var open := bearer.exposed()
	var r: float = Balance.WEAK_POINT_RADIUS
	if open:
		var breath := 0.5 + 0.5 * sin(_phase * 7.0)
		draw_circle(weak_at, r + 3.0 * breath, Color(WEAK_OPEN, 0.30))
		draw_circle(weak_at, r, WEAK_OPEN)
		draw_arc(weak_at, r + 5.0, 0.0, TAU, 20, Color(WEAK_OPEN, 0.7), 2.0, true)
	else:
		draw_circle(weak_at, r * 0.8, WEAK_SHUT)

	# The plate. Drawn last so it is plainly IN FRONT, and wider than the body
	# so which side it is on is never a judgement call.
	var plate: Vector2 = Balance.SHIELD_PLATE_SIZE
	var plate_at := Vector2(face * Shieldbearer.REACH, 0.0)
	draw_rect(Rect2(plate_at - plate * 0.5, plate), PLATE, true)
	draw_rect(Rect2(plate_at - plate * 0.5, plate), PLATE_EDGE, false, 2.0)

	# Mid-turn: a sweep across the body, so "wait" is something you can see
	# rather than something you have to count.
	if bearer.turning():
		var t: float = 1.0 - clampf(bearer._turn_left / Balance.SHIELDBEARER_TURN_TIME,
			0.0, 1.0)
		var sweep := lerpf(-Shieldbearer.REACH, Shieldbearer.REACH, t) * face
		draw_line(Vector2(sweep, -size.y * 0.5), Vector2(sweep, size.y * 0.5),
			Color(PLATE, 0.55), 3.0)
