class_name Shockwave
extends Area2D
## The ridge of broken ground a spent charge throws off, from act two of 1-B.
##
## Deliberately LOW. A standing jump clears 162px and this is 34px tall, so the
## skill it asks for is noticing rather than timing to the frame -- the runner
## already has a telegraph to read, and a second frame-perfect thing in the same
## second would stop being pressure and start being noise.
##
## It is also the reason the guardian's PLATFORM has a job in a fight with no
## gaps in it: a slab 60px off the floor is a place the wave goes under. That is
## the whole of the stage's argument that a boss fight can use the same three
## tools as a traversal stage without any of them meaning the same thing.
##
## BOTH devices spawn one; only the host's can hurt. A wave is a straight line
## from a known place at a known moment, so sending it would be sending
## something the receiver can already work out -- and the runner lives on the
## host, so a guardian-side copy has nobody to hit anyway. Giving it a collision
## layer there would make it a hazard in a world that does not own the person it
## would be a hazard to.

var direction: int = 1
var speed: float = Balance.SHOCKWAVE_SPEED

var _travelled: float = 0.0
var _life: float = 0.0

func _ready() -> void:
	# Hazard layer, but NOT the instant_death group: the runner has two hearts
	# in this fight and both of them are meant to be spendable.
	collision_layer = Hazard.LAYER_HAZARD if Clock.is_host else 0
	collision_mask = 0
	z_index = 3
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Balance.SHOCKWAVE_SIZE
	shape.shape = rect
	add_child(shape)

func _process(delta: float) -> void:
	var step := speed * delta
	global_position.x += float(direction) * step
	_travelled += step
	_life += delta
	queue_redraw()
	if _travelled >= Balance.SHOCKWAVE_RANGE:
		queue_free()

func _draw() -> void:
	var size := Balance.SHOCKWAVE_SIZE
	# Fades as it runs out of ground, so "this one is nearly spent" is readable
	# without counting pixels.
	var strength := clampf(1.0 - _travelled / Balance.SHOCKWAVE_RANGE, 0.15, 1.0)
	var rect := Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y)
	if Art.draw_stretched_flipped(self, "keeper_shockwave", rect, direction > 0):
		return

	# The crest leads, the tail drags: a triangle-ish wedge rather than a block,
	# so which way it is going is legible from the shape alone.
	var lead := float(direction) * size.x * 0.5
	var back := -lead
	var base := size.y * 0.5
	var crest := PackedVector2Array([
		Vector2(back, base),
		Vector2(back * 0.55, base - size.y * 0.35),
		Vector2(lead * 0.2, base - size.y * 0.95),
		Vector2(lead * 0.72, base - size.y * 0.55),
		Vector2(lead, base),
	])
	# A glow under it first, so it separates from whatever ground it is on.
	draw_circle(Vector2(lead * 0.4, base - size.y * 0.3),
		size.x * 0.42, Color(1.0, 0.52, 0.16, 0.22 * strength))
	draw_colored_polygon(crest, Color(0.46, 0.43, 0.38, 0.95 * strength))
	draw_polyline(crest, Color(1.0, 0.76, 0.34, 0.95 * strength), 5.0, true)
	# The amber seam at the foot, which is the only thing that says this is the
	# Keeper's and not falling scenery.
	draw_line(Vector2(back, base - 3.0), Vector2(lead, base - 3.0),
		Color(1.0, 0.66, 0.24, 0.9 * strength), 7.0, true)
	for i in range(4):
		var t := (float(i) + 0.35) / 4.0
		var px := lerpf(back, lead, t)
		var lift := (0.35 + 0.65 * sin(_life * 9.0 + float(i))) * size.y * 0.8
		draw_circle(Vector2(px, base - size.y - lift), 3.0 + float(i % 2),
			Color(0.68, 0.66, 0.60, 0.45 * strength))
