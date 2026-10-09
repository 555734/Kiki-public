class_name CastleSet
extends Node2D
## 1-9's look: the road to the king's castle, drawn to read at a glance on a
## phone and in a trailer -- big stone shapes, a thick dark outline, bright
## midday colours.
##
## Two halves. The static functions paint the stage's own ground for
## terrain.gd (the road, the keep wall, and the rock and masonry the tunnels
## and the dungeon are cut through). This node, built by LevelBuilder for 1-9
## only, paints what stands BEHIND the action: the tunnels' inner walls, the
## ravine under the broken bridge, the gatehouse towers, the dungeon's walls,
## the keep's parapet and the castle front round the goal.
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
const ROCK := Color("a99c88")
const ROCK_DARK := Color("847763")
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
	_dungeon_dressing()
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
	if not Art.draw_tiled(ci, "castle_ground_tile", body, 256.0):
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
	_edges(ci, rect)

## The keep: a sheer wall of pale sandstone, very regular courses.
static func _keep(ci: CanvasItem, rect: Rect2, seed_index: int) -> void:
	if not Art.draw_tiled(ci, "castle_keep_wall", rect, 256.0):
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
	_edges(ci, rect)

## The rock (tunnels) or the masonry (dungeon) above a covered stretch. Its
## bottom edge is a ceiling, finished with a row of arch stones.
static func _mass(ci: CanvasItem, rect: Rect2, index: int) -> void:
	var dungeon := index == 2
	var fill := MASONRY if dungeon else ROCK
	var dark := MASONRY_DARK if dungeon else ROCK_DARK
	var key := "castle_dungeon_wall" if dungeon else "castle_ground_tile"
	if not Art.draw_tiled(ci, key, rect, 256.0, Color(0.92, 0.9, 0.88) if not dungeon else Color.WHITE):
		ci.draw_rect(rect, fill)
		if dungeon:
			_courses(ci, rect, Vector2(84, 52), fill, dark, 401, 1.0)
		else:
			_rubble(ci, Rect2(rect.position, rect.size - Vector2(0, 34)), fill, dark, 211 + index * 31)
	# The arch stones along the ceiling: what says "you go under this".
	var base := rect.end.y
	var n := maxi(2, int(rect.size.x / 64.0))
	var w := rect.size.x / float(n)
	for k in n:
		var block := Rect2(rect.position.x + w * float(k), base - 34.0, w, 34.0)
		ci.draw_rect(block, MASONRY_DARK if dungeon else ROCK_DARK)
		ci.draw_rect(block, OUTLINE, false, 3.0)
	ci.draw_line(Vector2(rect.position.x, base), Vector2(rect.end.x, base), OUTLINE, 5.0)
	# The two faces the road goes in and out through.
	for x in [rect.position.x, rect.end.x]:
		var side := 1.0 if x == rect.position.x else -1.0
		ci.draw_rect(Rect2(x if side > 0 else x - 26.0, rect.position.y, 26.0, rect.size.y),
			Color(1, 1, 1, 0.10))
		ci.draw_line(Vector2(x, rect.position.y), Vector2(x, base), OUTLINE, 5.0)
	if dungeon:
		# Battlements: this is the castle's own outer wall.
		_battlements(ci, rect.position.x, rect.end.x, rect.position.y, MASONRY, MASONRY_DARK)

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

## Rough stone of every size, packed in uneven courses: the hill the road
## tunnels through, a cliff rather than a wall.
static func _rubble(ci: CanvasItem, rect: Rect2, fill: Color, dark: Color, seed: int) -> void:
	var y := rect.position.y
	var r := 0
	while y < rect.end.y:
		var h := minf(46.0 + 30.0 * DrawUtil.hash01(seed + r * 17), rect.end.y - y)
		var x := rect.position.x
		var c := 0
		while x < rect.end.x:
			var w := minf(60.0 + 80.0 * DrawUtil.hash01(seed + r * 131 + c * 7), rect.end.x - x)
			var shade := DrawUtil.hash01(seed + r * 71 + c * 3)
			var block := Rect2(x + 3.0, y + 3.0, w - 6.0, h - 6.0)
			DrawUtil.rounded_rect(ci, block.grow(2.0), 12.0, Color(OUTLINE, 0.65))
			DrawUtil.rounded_rect(ci, block, 11.0, fill.lerp(dark, 0.1 + shade * 0.55))
			ci.draw_rect(Rect2(block.position + Vector2(8, 5), Vector2(maxf(0.0, block.size.x - 16.0), 5.0)),
				Color(1, 1, 1, 0.13))
			x += w
			c += 1
		y += h
		r += 1

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

## Under the broken bridge: the ravine's far wall, darker as it goes down, and
## the snapped-off ends of the bridge.
func _ravine() -> void:
	var c := LevelCastleData.CHASM
	var top := LevelCastleData.GROUND_TOP
	# The far side of the ravine, falling away into shadow: dark from the very
	# lip, so it reads as a drop and never as a floor a little lower down.
	var wall := Rect2(c.x, top + 8.0, c.y - c.x, LevelCastleData.KILL_Y - top)
	draw_rect(wall, INSIDE_DARK)
	_rubble(self, wall, INSIDE, INSIDE_DARK, 733)
	for k in 12:
		var y := top + 8.0 + float(k) * 45.0
		draw_rect(Rect2(c.x, y, c.y - c.x, LevelCastleData.KILL_Y - y), Color(0.03, 0.03, 0.06, 0.16))
	# Mist hanging in it.
	for k in 5:
		var p := Vector2(c.x + 90.0 + 150.0 * float(k), top + 210.0 + 30.0 * sin(float(k) * 2.1))
		draw_circle(p, 70.0, Color(0.85, 0.9, 1.0, 0.10))
	for end in [c.x, c.y]:
		var dir := 1.0 if end == c.x else -1.0
		var key := "castle_bridge_end"
		var t := Art.tex(key)
		if t != null:
			var size := Vector2(150, 150)
			var r := Rect2(Vector2(end - (size.x if dir > 0 else 0.0), top - 6.0), size)
			if dir > 0:
				draw_texture_rect(t, r, false)
			else:
				draw_set_transform(Vector2(r.get_center().x * 2.0, 0), 0, Vector2(-1, 1))
				draw_texture_rect(t, r, false)
				draw_set_transform(Vector2.ZERO)
			continue
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
	var x := 3780.0
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

## Iron rings and dead torches on the dungeon's wall: only the finger's light
## ever shows them.
func _dungeon_dressing() -> void:
	var d := LevelCastleData.DUNGEON
	var x := d.x + 120.0
	while x < d.y - 60.0:
		_torch(Vector2(x, 260.0))
		draw_arc(Vector2(x + 110.0, 330.0), 14.0, 0.0, TAU, 16, Color("5d5a60"), 5.0)
		x += 260.0

func _torch(at: Vector2) -> void:
	var t := Art.tex("castle_torch")
	if t != null:
		draw_texture_rect(t, Rect2(at - Vector2(24, 50), Vector2(48, 96)), false)
		return
	draw_rect(Rect2(at + Vector2(-14, 18), Vector2(28, 8)), Color("2f2a28"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-10, -18), at + Vector2(10, -18),
		at + Vector2(5, 24), at + Vector2(-5, 24)]), Color("5a3b26"))
	draw_circle(at + Vector2(0, -20), 11.0, Color("1d1a1a"))

## A parapet behind the walk along the top of the keep, and banners down its face.
func _keep_dressing() -> void:
	var top := LevelCastleData.KEEP_TOP
	var x0 := LevelCastleData.KEEP_X
	draw_rect(Rect2(x0, top - 54.0, 9300.0 - x0, 54.0), SANDSTONE_DARK)
	_battlements(self, x0, 9300.0, top - 54.0, SANDSTONE, SANDSTONE_DARK)
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
