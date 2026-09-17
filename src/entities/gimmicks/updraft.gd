class_name Updraft
extends Node2D
## A column of rising air. The one new thing stage 1-S adds.
##
## It is the only height in the game that costs no gauge. The spring needs
## ground under it, the warp pair costs 44, and the guardian's platform costs 30
## and dies in five seconds -- a column just stands there, and the runner
## decides in the air whether to use it.
##
## That decision is a TRADE, not a gift: the column pulls the runner upward and
## drags their horizontal speed down (Balance.UPDRAFT_DRAG). Fly through one and
## you arrive higher and shorter. Fly around it and you keep the whole 679px of
## the launch. Neither is right; which one is right depends on where the next
## landing is, and that is the thing the two of them have to agree about while
## the runner is already in the air.
##
## Built on the same contract as Spring (src/entities/gimmicks/spring.gd):
##
##   * no collider at all -- the runner cannot land on air
##   * process_priority = 10, so it runs AFTER the runner has moved and the
##     velocity it sets survives into the next move_and_slide rather than being
##     overwritten by it
##   * Clock.is_host gates the physics. On the guardian's device the runner is a
##     puppet whose position arrives in snapshots with the lift already in it;
##     a second copy of the lift applied there would fight the interpolation and
##     show the two players different flights.
##
## Nothing about it is sent. The column never moves, so both devices draw the
## same thing from the same level data -- the same reason lasers and moving
## platforms cost zero bytes (docs/netcode.md section 4).

var runner: Runner = null

## The column's footprint. x is its width, y its height; the origin is the
## BOTTOM CENTRE, so a column is authored at the height it rises from.
var span: Vector2 = Vector2(150.0, 420.0)

var _phase: float = 0.0
## Purely cosmetic, and derived rather than sent: the guardian's copy reads
## "somebody is in here" out of the puppet's position, which it already has.
var _occupied: float = 0.0

func _ready() -> void:
	add_to_group("updraft")
	z_index = 4
	process_priority = 10

func _process(delta: float) -> void:
	_phase += delta
	_occupied = maxf(0.0, _occupied - delta * 2.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if runner == null or not is_instance_valid(runner):
		return
	if not holds(runner.global_position):
		return
	_occupied = 1.0
	if not Clock.is_host:
		return
	# Towards the rise speed rather than adding to it, so a runner who drops in
	# at terminal velocity is turned around instead of being launched by however
	# fast they happened to arrive. UPDRAFT_ACCEL is a little above the fall
	# gravity, which is what makes entering one at speed cost a moment of
	# sinking before the column wins.
	runner.velocity.y = move_toward(
		runner.velocity.y, -Balance.UPDRAFT_RISE, Balance.UPDRAFT_ACCEL * delta)
	# Height for distance. See Balance.UPDRAFT_DRAG.
	runner.velocity.x = move_toward(
		runner.velocity.x, 0.0, Balance.UPDRAFT_DRAG * delta)

## Is this point in the column?
##
## Generous above the top edge by UPDRAFT_SOFT_TOP so a runner who rides one all
## the way up is carried clear of it rather than having the lift cut off at a
## line they cannot see.
func holds(at: Vector2) -> bool:
	if absf(at.x - global_position.x) > span.x * 0.5:
		return false
	var top := global_position.y - span.y - Balance.UPDRAFT_SOFT_TOP
	return at.y >= top and at.y <= global_position.y

func _draw() -> void:
	var rect := Rect2(-span.x * 0.5, -span.y, span.x, span.y)
	if Art.draw_tiled(self, "sky_updraft", rect, span.y):
		_draw_motes(rect)
		return

	# The vector fallback, and it has one job: be obviously a COLUMN and
	# obviously RISING, from across the screen, without hiding the runner who
	# is inside it.
	#
	# The first pass was two hairlines and a wash at alpha 0.07, and in a
	# 1280x720 capture it did not read as an object at all -- which for the one
	# thing this stage adds is the whole of the problem. What fixed it is the
	# same thing that fixed 1-B's charge lane: chevrons. A band of colour says
	# "something is here"; arrows say which way it goes.
	var lit := 0.72 + 0.28 * _occupied
	draw_rect(rect, Color(1.0, 0.88, 0.58, 0.13 * lit))
	# Brighter towards the two edges, so the column has sides.
	var band := 14.0
	for i in range(2):
		var x := rect.position.x if i == 0 else rect.position.x + rect.size.x - band
		draw_rect(Rect2(x, rect.position.y, band, rect.size.y),
			Color(1.0, 0.80, 0.38, 0.30 * lit))
		draw_line(Vector2(x + (0.0 if i == 0 else band), rect.position.y),
			Vector2(x + (0.0 if i == 0 else band), rect.position.y + rect.size.y),
			Color(1.0, 0.92, 0.66, 0.70 * lit), 3.0, true)

	# Chevrons, travelling up. Spaced by height rather than by count so a tall
	# column and a short one have the same texture.
	var step := 82.0
	var rungs := maxi(2, int(rect.size.y / step))
	for i in range(rungs):
		var t := fmod((float(i) / float(rungs)) + fmod(_phase * 0.30, 1.0), 1.0)
		var y := rect.position.y + rect.size.y * (1.0 - t)
		# Fades in at the bottom and out at the top, so nothing pops.
		var fade: float = clampf(minf(t, 1.0 - t) * 5.0, 0.0, 1.0)
		var wing := rect.size.x * 0.34
		var lift := 22.0
		var mid := rect.position.x + rect.size.x * 0.5
		var col := Color(1.0, 0.86, 0.48, (0.30 + 0.35 * (1.0 - t)) * fade * lit)
		draw_line(Vector2(mid - wing, y), Vector2(mid, y - lift), col, 5.0, true)
		draw_line(Vector2(mid, y - lift), Vector2(mid + wing, y), col, 5.0, true)

	# Streaks up the lanes, longer the higher they get.
	var lanes := 4
	for i in range(lanes):
		var lane := (float(i) + 0.5) / float(lanes)
		var x := rect.position.x + rect.size.x * lane
		var t := fmod(_phase * 0.55 + float(i) * 0.31, 1.0)
		var y := rect.position.y + rect.size.y * (1.0 - t)
		var length := 30.0 + 62.0 * t
		draw_line(Vector2(x, y), Vector2(x, y - length),
			Color(1.0, 0.90, 0.56, (0.42 - 0.32 * t) * lit), 3.0, true)
	_draw_motes(rect)

## The things being carried up. Drawn over the painting as well as over the
## fallback, because the painted column is a still image and this is what makes
## it move.
func _draw_motes(rect: Rect2) -> void:
	for i in range(11):
		var lane := DrawUtil.hash01(i * 13 + 3)
		var x := rect.position.x + rect.size.x * (0.12 + 0.76 * lane)
		var speed := 0.42 + 0.34 * DrawUtil.hash01(i * 7 + 1)
		var t := fmod(_phase * speed + DrawUtil.hash01(i * 5), 1.0)
		var y := rect.position.y + rect.size.y * (1.0 - t)
		draw_circle(Vector2(x, y), 3.0 + 2.6 * DrawUtil.hash01(i * 3),
			Color(1.0, 0.96, 0.78, 0.80 * (1.0 - t)))
