class_name Barricade
extends StaticBody2D
## A broken half-wall in the Keeper's arena: the thing a charge ends on.
##
## It is NOT terrain, and that is the whole design.
##
## The first version of this stage used floor-to-sky stone pillars, and
## keeper_probe caught what was wrong with them in one line -- "the runner
## reaches cover inside the wind-up: FAIL, stopped at x=167". The runner had
## sprinted straight into the thing they were meant to get behind. A solid
## column in a side-scroller is not cover; it is a wall that cuts the arena in
## half, for both of them, forever.
##
## So a barricade sits on its own collision layer (Balance.LAYER_BARRICADE) and
## exactly two things look at it:
##
##   the runner        who hops over it -- 128px against a 162px jump -- and can
##                     stand on top of it
##   a CHARGING Keeper which adds the layer to its mask when it puts its head
##                     down, and drops it again when it gets up
##
## A WALKING Keeper steps over one, so the boss owns the whole arena and cannot
## be shut out of a corner of it. Which is also the only reading of the art that
## makes sense: a four-legged siege engine picks its feet up at a walk, and at
## 760px/s with its skull leading, it does not.
##
## It comes down when the ACT changes, not when it is hit. See
## Keeper.barricades_for_act: a respawn rebuilds the whole dynamic layer, so
## anything a barricade remembered for itself would come back with it, and act
## three -- the act with none -- would quietly get its cover back every time
## somebody died.

## The last act this one survives. Act 1 has two standing, act 2 has one, act 3
## has none.
var needed_act: int = 1

var _falling: float = -1.0
var _shape: CollisionShape2D = null

func _ready() -> void:
	add_to_group("barricade")
	collision_layer = Balance.LAYER_BARRICADE
	collision_mask = 0
	z_index = 3
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Balance.BARRICADE_SIZE
	_shape.shape = rect
	add_child(_shape)
	Events.keeper_act_changed.connect(_on_act)

## Built into an act that has already passed: stand up as rubble straight away,
## with no collision and no drama. This is the respawn path.
func settle(current_act: int) -> void:
	if current_act > needed_act:
		_falling = 0.0
		if _shape != null:
			_shape.set_deferred("disabled", true)

func standing() -> bool:
	return _falling < 0.0

func _on_act(new_act: int) -> void:
	if new_act > needed_act and _falling < 0.0:
		_falling = 1.0
		# Deferred: the act changes inside a shot resolving inside a physics
		# query, and pulling a shape out from under that ends the frame with
		# "can't change this state while flushing queries".
		if _shape != null:
			_shape.set_deferred("disabled", true)
		Events.keeper_slammed.emit(
			global_position + Vector2(0.0, Balance.BARRICADE_SIZE.y * 0.5))

func _process(delta: float) -> void:
	if _falling > 0.0:
		_falling = maxf(0.0, _falling - delta * 1.6)
		queue_redraw()

func _draw() -> void:
	var size := Balance.BARRICADE_SIZE
	if standing():
		_draw_whole(Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y))
		return
	# Coming down, then a stump. The collapse is drawn rather than simulated: a
	# rigid body here would be one more thing two devices could disagree about,
	# for a second and a half of scenery.
	var stump_h := size.y * 0.30
	var stump := Rect2(-size.x * 0.60, size.y * 0.5 - stump_h, size.x * 1.20, stump_h)
	if _falling > 0.0:
		var lean := (1.0 - _falling) * 0.75
		draw_set_transform(Vector2(0.0, size.y * 0.5), lean, Vector2.ONE)
		_draw_whole(Rect2(-size.x * 0.5, -size.y, size.x, size.y))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_stump(stump)

func _draw_whole(rect: Rect2) -> void:
	if Art.draw_stretched(self, "keeper_barricade", rect):
		return
	var stone := Color("58615c")
	var light := Color("6d766f")
	var dark := Color("3d443f")
	draw_rect(rect, stone)
	# Courses, so its height reads against a 46px runner at a glance.
	var courses := 4
	for i in range(courses):
		var y := rect.position.y + rect.size.y * (float(i) + 1.0) / float(courses + 1)
		draw_line(Vector2(rect.position.x, y),
			Vector2(rect.position.x + rect.size.x, y), dark, 2.0)
	for i in range(3):
		var x := rect.position.x + rect.size.x * (0.33 + 0.33 * float(i % 2))
		draw_line(Vector2(x, rect.position.y + rect.size.y * 0.2 * float(i)),
			Vector2(x, rect.position.y + rect.size.y * (0.2 * float(i) + 0.2)), dark, 2.0)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x * 0.28, rect.size.y),
		Color(light, 0.40))
	draw_rect(Rect2(rect.position.x + rect.size.x * 0.80, rect.position.y,
		rect.size.x * 0.20, rect.size.y), Color(0, 0, 0, 0.18))
	# A capping course, a little proud, so the top edge is obviously standable.
	draw_rect(Rect2(rect.position.x - 6.0, rect.position.y, rect.size.x + 12.0, 14.0), light)
	draw_rect(Rect2(rect.position.x - 6.0, rect.position.y, rect.size.x + 12.0, 14.0),
		dark, false, 2.0)
	draw_rect(rect, dark, false, 2.0)
	# Moss along one joint: the one warm-cold contrast that keeps it from reading
	# as a grey box against a grey wall.
	draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + rect.size.y * 0.42,
		rect.size.x - 4.0, 4.0), Color("4d6b47"))

func _draw_stump(rect: Rect2) -> void:
	if Art.draw_stretched(self, "keeper_barricade_rubble", rect):
		return
	draw_rect(rect, Color("4b524d"))
	draw_rect(rect, Color("343a36"), false, 2.0)
	# A jagged break face, brighter than the weathered outside: fresh stone.
	var top := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x * 0.28, -9.0),
		rect.position + Vector2(rect.size.x * 0.52, 3.0),
		rect.position + Vector2(rect.size.x * 0.74, -7.0),
		rect.position + Vector2(rect.size.x, 2.0),
		rect.position + Vector2(rect.size.x, 10.0),
		rect.position + Vector2(0.0, 10.0),
	])
	draw_colored_polygon(top, Color("7d867f"))
	for i in range(5):
		var t := (float(i) + 0.5) / 5.0
		draw_circle(Vector2(lerpf(rect.position.x - 14.0,
			rect.position.x + rect.size.x + 14.0, t),
			rect.position.y + rect.size.y - 5.0 - float(i % 3) * 3.0),
			5.0 + float(i % 2) * 3.0, Color("444b46"))
