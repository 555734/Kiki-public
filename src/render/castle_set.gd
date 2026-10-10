class_name CastleSet
extends Node2D
## 1-9's look: the road to the king's castle, drawn to read at a glance on a
## phone and in a trailer -- big stone shapes, a thick dark outline, bright
## midday colours.
##
## Two halves. The static functions paint the stage's own ground for
## terrain.gd (the road, the keep wall, and the guardhouse over its passage).
## This node, built by LevelBuilder for 1-9 only, paints what stands BEHIND
## the action: the gorge's cliffs, the cannon's tower, the guardhouse's inner
## wall, the gatehouse towers, the keep's parapet and the castle round the
## goal. The gorge is open: the valley shows through it, so a frame over the
## bridge is all sky and distance, not a black hole.
##
## Every surface first asks Art for its painting (the castle_* keys, see
## docs/art-prompts-castle.md) and draws the code version only while that has
## not arrived, so the paintings drop in without touching this file.

const OUTLINE := Color("3b2a1e")
const ROAD := Color("e2d6bb")
const ROAD_DARK := Color("b9a98a")
const GRASS := Color("74c84e")
const GRASS_DARK := Color("3f9437")
const EARTH := Color("c9a57a")
const EARTH_DARK := Color("a7845d")
const MASONRY := Color("b8b3a6")
const MASONRY_DARK := Color("8f8a7e")
const SANDSTONE := Color("e8d3a2")
const SANDSTONE_DARK := Color("c9b07c")
const INSIDE := Color("4e4a52")
const INSIDE_DARK := Color("38343c")
const PENNANT := Color("d8433b")

func _ready() -> void:
	# Behind the terrain (2) and every actor, in front of the sky.
	z_index = -1

func _draw() -> void:
	_ravine()
	for mass in LevelCastleData.masses():
		_inside(mass)
	_bastion()
	_gatehouse()
	_keep_dressing()
	_castle_front()

# ------------------------------------------------------------- ground (static)

## Paint one of 1-9's ground rectangles. Called by terrain.gd.
static func draw_slab(ci: CanvasItem, rect: Rect2, seed_index: int) -> void:
	var masses := LevelCastleData.masses()
	for i in masses.size():
		if masses[i].is_equal_approx(rect):
			_mass(ci, rect, i)
			return
	if rect.position.y <= LevelCastleData.KEEP_TOP + 1.0:
		_keep(ci, rect, seed_index)
	else:
		_road(ci, rect, seed_index)

## The road: a band of pale paving under a grass lip, packed earth and old
## cobbles below.
static func _road(ci: CanvasItem, rect: Rect2, seed_index: int) -> void:
	var body := Rect2(rect.position + Vector2(0, 30), rect.size - Vector2(0, 30))
	if not Art.draw_tiled(ci, "castle_ground_tile", body, 384.0):
		ci.draw_rect(body, EARTH)
		_courses(ci, Rect2(body.position + Vector2(0, 24), body.size - Vector2(0, 24)),
			Vector2(74, 44), EARTH, EARTH_DARK, seed_index * 97, 0.55)
		# Deeper is darker, so tall slabs do not read as flat.
		for k in 3:
			var y := body.position.y + 140.0 + 120.0 * float(k)
			if y < body.end.y:
				ci.draw_rect(Rect2(body.position.x, y, body.size.x, body.end.y - y),
					Color(0.25, 0.14, 0.06, 0.10))
	if not Art.draw_tiled(ci, "castle_ground_cap",
			Rect2(rect.position.x, rect.position.y - 12.0, rect.size.x, 60.0), 60.0):
		ci.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 30.0), ROAD)
		var n := maxi(1, int(rect.size.x / 46.0))
		for k in n + 1:
			var x := rect.position.x + rect.size.x * float(k) / float(n)
			ci.draw_line(Vector2(x, rect.position.y + 8.0), Vector2(x, rect.position.y + 30.0),
				ROAD_DARK, 2.0)
		ci.draw_line(rect.position + Vector2(0, 30), Vector2(rect.end.x, rect.position.y + 30.0),
			OUTLINE, 4.0)
		ci.draw_rect(Rect2(rect.position.x, rect.position.y - 4.0, rect.size.x, 10.0), GRASS)
		var tufts := maxi(1, int(rect.size.x / 18.0))
		for k in tufts:
			var x := rect.position.x + (float(k) + 0.5) * rect.size.x / float(tufts)
			ci.draw_circle(Vector2(x, rect.position.y - 3.0), 7.0, GRASS)
		ci.draw_rect(Rect2(rect.position.x, rect.position.y + 5.0, rect.size.x, 3.0), GRASS_DARK)
	_depth(ci, Rect2(body.position + Vector2(0, 40), body.size - Vector2(0, 40)))
	_edges(ci, rect)
	var c := LevelCastleData.CHASM
	if absf(rect.end.x - c.x) < 1.0:
		_bridge_end(ci, rect.end.x, rect.position.y, false)
	elif absf(rect.position.x - c.y) < 1.0:
		_bridge_end(ci, rect.position.x, rect.position.y, true)

## The snapped-off end of the old bridge, painted over the road where it stops
## at the ravine: on the near side as painted, on the far side mirrored.
static func _bridge_end(ci: CanvasItem, edge: float, top: float, far_side: bool) -> void:
	var t := Art.tex("castle_bridge_end")
	if t == null:
		return
	var h := 190.0
	var w := h * float(t.get_width()) / float(t.get_height())
	# The broken face overhangs the drop by a hand's breadth; the deck is level
	# with the road.
	var x := edge - w + 26.0 if not far_side else edge - 26.0
	var r := Rect2(x, top - 6.0, w, h)
	if far_side:
		ci.draw_set_transform(Vector2(r.get_center().x * 2.0, 0), 0, Vector2(-1, 1))
	ci.draw_texture_rect(t, r, false)
	if far_side:
		ci.draw_set_transform(Vector2.ZERO)

## The keep: a sheer wall of pale sandstone, very regular courses.
static func _keep(ci: CanvasItem, rect: Rect2, seed_index: int) -> void:
	if not Art.draw_tiled(ci, "castle_keep_wall", rect, 384.0):
		ci.draw_rect(rect, SANDSTONE)
		_courses(ci, Rect2(rect.position + Vector2(0, 24), rect.size - Vector2(0, 24)),
			Vector2(96, 48), SANDSTONE, SANDSTONE_DARK, seed_index * 53, 0.9)
	# The walk along its top.
	ci.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 24.0), ROAD)
	ci.draw_line(rect.position + Vector2(0, 24), Vector2(rect.end.x, rect.position.y + 24.0),
		OUTLINE, 4.0)
	# Ivy down the face the slingshot has to clear: green reads as "a wall you
	# could climb if you were a plant".
	for k in 3:
		var x := rect.position.x + 60.0 + 70.0 * float(k)
		for j in 6:
			var y := rect.position.y + 40.0 + 46.0 * float(j) + 12.0 * float(k)
			ci.draw_circle(Vector2(x + sin(float(j) * 1.7 + k) * 10.0, y), 9.0 - float(j), GRASS_DARK)
	_depth(ci, Rect2(rect.position + Vector2(0, 60), rect.size - Vector2(0, 60)))
	_edges(ci, rect)

## The guardhouse: a stone building the road runs through. Only its lower
## storeys are drawn -- the solid mass goes on up, past anyone's reach, but
## above its roof it is sky. Its bottom edge is the passage's ceiling, finished
## with a row of arch stones.
static func _mass(ci: CanvasItem, rect: Rect2, _index: int) -> void:
	var base := rect.end.y
	var house := Rect2(rect.position.x, base - 300.0, rect.size.x, 300.0)
	ci.draw_rect(house, MASONRY)
	_courses(ci, house, Vector2(84, 52), MASONRY, MASONRY_DARK, 401, 1.0)
	ci.draw_rect(house, OUTLINE, false, 5.0)
	# Its windows: somebody is on watch.
	var n_win := maxi(2, int(rect.size.x / 140.0))
	for k in n_win:
		var x := rect.position.x + (float(k) + 0.5) * rect.size.x / float(n_win)
		var win := Rect2(x - 16.0, base - 220.0, 32.0, 56.0)
		ci.draw_rect(win, INSIDE_DARK)
		ci.draw_rect(win, OUTLINE, false, 4.0)
	_battlements(ci, rect.position.x - 10.0, rect.end.x + 10.0, house.position.y, MASONRY, MASONRY_DARK)
	# The arch stones along the ceiling: what says "you go under this".
	var n := maxi(2, int(rect.size.x / 64.0))
	var w := rect.size.x / float(n)
	for k in n:
		var block := Rect2(rect.position.x + w * float(k), base - 34.0, w, 34.0)
		ci.draw_rect(block, MASONRY_DARK)
		ci.draw_rect(block, OUTLINE, false, 3.0)
	ci.draw_line(Vector2(rect.position.x, base), Vector2(rect.end.x, base), OUTLINE, 5.0)
	for x in [rect.position.x, rect.end.x]:
		ci.draw_line(Vector2(x, house.position.y), Vector2(x, base), OUTLINE, 5.0)

## The body of the ground falls away into shade below the road, so it reads as
## the ground under the action and never competes with it for the eye.
static func _depth(ci: CanvasItem, rect: Rect2) -> void:
	var steps := 8
	for k in steps:
		var y := rect.position.y + 22.0 * float(k)
		if y >= rect.end.y:
			break
		ci.draw_rect(Rect2(rect.position.x, y, rect.size.x, rect.end.y - y), Color(0.12, 0.08, 0.06, 0.09))

static func _edges(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_line(rect.position, Vector2(rect.position.x, rect.end.y), OUTLINE, 5.0)
	ci.draw_line(Vector2(rect.end.x, rect.position.y), rect.end, OUTLINE, 5.0)

## Courses of blocks, every other row offset by half a block.
static func _courses(ci: CanvasItem, rect: Rect2, block: Vector2, fill: Color,
		dark: Color, seed: int, alpha: float) -> void:
	var rows := int(ceilf(rect.size.y / block.y))
	for r in rows:
		var y := rect.position.y + float(r) * block.y
		var h := minf(block.y, rect.end.y - y)
		var x := rect.position.x - (block.x * 0.5 if r % 2 == 1 else 0.0)
		var c := 0
		while x < rect.end.x:
			var x0 := maxf(x, rect.position.x)
			var x1 := minf(x + block.x, rect.end.x)
			var shade := DrawUtil.hash01(seed + r * 131 + c * 7)
			var col := fill.lerp(dark, 0.15 + shade * 0.45)
			ci.draw_rect(Rect2(x0 + 2.0, y + 2.0, x1 - x0 - 4.0, h - 4.0), Color(col, alpha))
			ci.draw_rect(Rect2(x0 + 4.0, y + 4.0, x1 - x0 - 8.0, 5.0), Color(1, 1, 1, 0.12 * alpha))
			x += block.x
			c += 1

static func _battlements(ci: CanvasItem, x0: float, x1: float, top: float, fill: Color, dark: Color) -> void:
	var w := 56.0
	var x := x0
	while x + w <= x1 + 0.5:
		var merlon := Rect2(x + 8.0, top - 40.0, w * 0.6, 42.0)
		ci.draw_rect(merlon, fill)
		ci.draw_rect(Rect2(merlon.position, Vector2(merlon.size.x, 8.0)), Color(1, 1, 1, 0.18))
		ci.draw_rect(merlon, OUTLINE, false, 4.0)
		x += w
	ci.draw_rect(Rect2(x0, top - 2.0, x1 - x0, 10.0), dark)

# ------------------------------------------------------------- the back layer

## Under the broken bridge: open air. The valley shows through the gorge, so
## the drop reads as height and not as a hole; only the snapped-off ends of
## the bridge hang over it.
func _ravine() -> void:
	var c := LevelCastleData.CHASM
	var top := LevelCastleData.GROUND_TOP
	for end in [c.x, c.y]:
		var dir := 1.0 if end == c.x else -1.0
		if Art.tex("castle_bridge_end") != null:
			continue   # painted on the road itself, see _bridge_end()
		# The deck's jagged break and a couple of stones about to go.
		var pts := PackedVector2Array([
			Vector2(end, top + 30.0), Vector2(end + dir * 22.0, top + 44.0),
			Vector2(end + dir * 8.0, top + 70.0), Vector2(end + dir * 30.0, top + 96.0),
			Vector2(end, top + 120.0)])
		DrawUtil.poly_outlined(self, pts, ROAD_DARK, OUTLINE, 4.0)
		for s in 3:
			var p := Vector2(end + dir * (36.0 + 22.0 * float(s)), top + 150.0 + 70.0 * float(s))
			draw_rect(Rect2(p - Vector2(9, 7), Vector2(18, 14)), ROAD_DARK)
			draw_rect(Rect2(p - Vector2(9, 7), Vector2(18, 14)), OUTLINE, false, 3.0)

## The far wall of a tunnel or of the dungeon, between its ceiling and the
## road: darker stone, so the hole reads as a hole.
func _inside(mass: Rect2) -> void:
	var r := Rect2(mass.position.x, mass.end.y, mass.size.x, LevelCastleData.GROUND_TOP - mass.end.y)
	draw_rect(r, INSIDE)
	_courses(self, r, Vector2(70, 42), INSIDE, INSIDE_DARK, int(mass.position.x), 1.0)
	# A shadow under the ceiling.
	draw_rect(Rect2(r.position, Vector2(r.size.x, 40.0)), Color(0, 0, 0, 0.25))

## The round tower the cannon fires from, and its pile of shot.
func _bastion() -> void:
	var x := LevelCastleData.CANNON_X
	var ground := LevelCastleData.GROUND_TOP
	var tower := Rect2(x - 40.0, ground - 330.0, 150.0, 330.0)
	draw_rect(tower, MASONRY)
	_courses(self, tower, Vector2(50, 40), MASONRY, MASONRY_DARK, 3780, 1.0)
	draw_rect(tower, OUTLINE, false, 5.0)
	_battlements(self, tower.position.x - 6.0, tower.end.x + 6.0, tower.position.y, MASONRY, MASONRY_DARK)
	_pennant(Vector2(tower.get_center().x, tower.position.y - 40.0), -1.0)
	for k in 3:
		draw_circle(Vector2(x + 76.0 + 22.0 * float(k), ground - 12.0), 12.0, OUTLINE)
		draw_circle(Vector2(x + 76.0 + 22.0 * float(k), ground - 12.0), 9.0, Color("2d2d33"))
	draw_circle(Vector2(x + 98.0, ground - 32.0), 12.0, OUTLINE)
	draw_circle(Vector2(x + 98.0, ground - 32.0), 9.0, Color("2d2d33"))

## Two towers either side of the portcullis, with a pennant each.
func _gatehouse() -> void:
	var x := LevelCastleData.GATE_X
	var ground := LevelCastleData.GROUND_TOP
	var arch := Art.tex("castle_gate_arch")
	if arch != null:
		var h := 640.0
		var w := h * float(arch.get_width()) / float(arch.get_height())
		draw_texture_rect(arch, Rect2(x - w * 0.5, ground - h, w, h), false)
		return
	for side in [-1.0, 1.0]:
		var tower := Rect2(x + side * 150.0 - 70.0, ground - 560.0, 140.0, 560.0)
		draw_rect(tower, MASONRY)
		_courses(self, tower, Vector2(46, 40), MASONRY, MASONRY_DARK, int(tower.position.x), 1.0)
		draw_rect(tower, OUTLINE, false, 5.0)
		_battlements(self, tower.position.x - 6.0, tower.end.x + 6.0, tower.position.y,
			MASONRY, MASONRY_DARK)
		# Arrow slit.
		draw_rect(Rect2(tower.get_center().x - 6.0, tower.position.y + 90.0, 12.0, 54.0), INSIDE_DARK)
		_pennant(Vector2(tower.get_center().x, tower.position.y - 40.0), side)
	# The wall walk joining them over the gate.
	var bridge := Rect2(x - 90.0, ground - 520.0, 180.0, 60.0)
	draw_rect(bridge, MASONRY_DARK)
	draw_rect(bridge, OUTLINE, false, 5.0)

func _pennant(base: Vector2, side: float) -> void:
	draw_line(base, base + Vector2(0, -90), OUTLINE, 5.0)
	DrawUtil.poly_outlined(self, PackedVector2Array([base + Vector2(0, -90),
		base + Vector2(side * 56.0, -74), base + Vector2(0, -58)]), PENNANT, OUTLINE, 3.0)

## A parapet behind the walk along the top of the keep, and banners down its face.
func _keep_dressing() -> void:
	var top := LevelCastleData.KEEP_TOP
	var x0 := LevelCastleData.KEEP_X
	var x1 := LevelCastleData.KEEP_END
	draw_rect(Rect2(x0, top - 54.0, x1 - x0, 54.0), SANDSTONE_DARK)
	_battlements(self, x0, x1, top - 54.0, SANDSTONE, SANDSTONE_DARK)
	for x in [x0 + 300.0, x0 + 560.0]:
		var banner := Rect2(x - 34.0, top + 60.0, 68.0, 170.0)
		draw_rect(banner, PENNANT)
		draw_colored_polygon(PackedVector2Array([banner.position + Vector2(0, banner.size.y),
			banner.end, banner.position + Vector2(banner.size.x * 0.5, banner.size.y - 30.0)]),
			SANDSTONE)
		draw_rect(banner, OUTLINE, false, 4.0)
		_crown(banner.get_center() + Vector2(0, -20))

func _crown(at: Vector2) -> void:
	var gold := Color("f2c14e")
	DrawUtil.poly_outlined(self, PackedVector2Array([at + Vector2(-22, 14), at + Vector2(-22, -10),
		at + Vector2(-11, 2), at + Vector2(0, -16), at + Vector2(11, 2), at + Vector2(22, -10),
		at + Vector2(22, 14)]), gold, OUTLINE, 3.0)

## The castle itself, rising behind the goal: what the whole road was for.
func _castle_front() -> void:
	var top := LevelCastleData.KEEP_TOP
	var goal := LevelCastleData.goal()
	var hall := Rect2(goal.x - 260.0, top - 560.0, 520.0, 560.0)
	draw_rect(hall, SANDSTONE)
	_courses(self, hall, Vector2(80, 44), SANDSTONE, SANDSTONE_DARK, 977, 1.0)
	draw_rect(hall, OUTLINE, false, 5.0)
	_battlements(self, hall.position.x, hall.end.x, hall.position.y, SANDSTONE, SANDSTONE_DARK)
	for side in [-1.0, 1.0]:
		var tower := Rect2(goal.x + side * 300.0 - 80.0, top - 760.0, 160.0, 760.0)
		draw_rect(tower, SANDSTONE)
		_courses(self, tower, Vector2(54, 44), SANDSTONE, SANDSTONE_DARK, int(tower.position.x), 1.0)
		draw_rect(tower, OUTLINE, false, 5.0)
		# A pointed roof.
		DrawUtil.poly_outlined(self, PackedVector2Array([tower.position + Vector2(-16, 0),
			Vector2(tower.get_center().x, tower.position.y - 150.0),
			Vector2(tower.end.x + 16.0, tower.position.y)]), Color("3d6fc4"), OUTLINE, 5.0)
		_pennant(Vector2(tower.get_center().x, tower.position.y - 150.0), side)
		for w in 2:
			draw_rect(Rect2(tower.get_center().x - 12.0, tower.position.y + 120.0 + 200.0 * float(w),
				24.0, 44.0), Color("f7d77a"))
	# Windows lit gold: somebody is home.
	for k in 3:
		draw_rect(Rect2(hall.position.x + 110.0 + 130.0 * float(k), hall.position.y + 120.0, 40.0, 70.0),
			Color("f7d77a"))
		draw_rect(Rect2(hall.position.x + 110.0 + 130.0 * float(k), hall.position.y + 120.0, 40.0, 70.0),
			OUTLINE, false, 4.0)
