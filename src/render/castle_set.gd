class_name CastleSet
extends Node2D
## 1-9's look, as its key art paints it: flat shapes with a thick dark
## outline, bright foreground on a soft, pale backdrop (the panorama), so the
## traps are what the eye goes to.
##
## Two halves. The static functions paint the stage's own ground for
## terrain.gd: the road (a strip of pale stones over dark earth), the red brick
## stair, and the keep wall. This node, built by LevelBuilder for 1-9 only,
## paints what stands BEHIND the action: the moat's water, the bushes along
## the road, the gatehouse round the portcullis and the keep's battlements.
##
## Every surface asks Art for its painting (the castle_* keys, cut by
## tools/import_castle_art.py) and draws a plain code version only while that
## is missing, so a missing file never leaves a hole.

const OUTLINE := Color("2a1d1a")
const ROAD := Color("e2c9a0")
const EARTH := Color("5a2a26")
const BRICK := Color("c95a3c")
const SANDSTONE := Color("e89a80")
const WATER := Color("1a8fe0")
const DEEP_WATER := Color("0b5fb4")
## How tall the strip of stones along the road's top is drawn.
const CAP_H := 34.0
## The keep wall is drawn a bay at a time, each this wide.
const BAY_W := 330.0
## Where the walk along the keep's top is in the wall painting: its rows above
## this are the battlements, standing up from the walk.
const WALK_ROW := 210.0
## The gatehouse painting's archway opens this many of its rows up from its foot.
const ARCH_ROWS := 360.0

func _ready() -> void:
	# Behind the terrain (2) and every actor, in front of the sky.
	z_index = -1

func _draw() -> void:
	_moat()
	_bushes()
	_gatehouse()
	_battlements()

# ------------------------------------------------------------- ground (static)

## Paint one of 1-9's ground rectangles. Called by terrain.gd.
static func draw_slab(ci: CanvasItem, rect: Rect2, seed_index: int) -> void:
	for step in LevelCastleData.stair():
		if step.is_equal_approx(rect):
			_bricks(ci, rect)
			return
	if rect.position.y <= LevelCastleData.KEEP_TOP + 1.0:
		_keep(ci, rect)
	else:
		_road(ci, rect, seed_index)

## The road: a strip of pale stones on top, dark earth below.
static func _road(ci: CanvasItem, rect: Rect2, _seed_index: int) -> void:
	var body := Rect2(rect.position + Vector2(0, CAP_H - 4.0), rect.size - Vector2(0, CAP_H - 4.0))
	if not Art.draw_tiled(ci, "castle_ground_tile", body, 300.0):
		ci.draw_rect(body, EARTH)
	var cap := Rect2(rect.position.x, rect.position.y, rect.size.x, CAP_H)
	if not Art.draw_tiled(ci, "castle_ground_cap", cap, CAP_H):
		ci.draw_rect(cap, ROAD)
		ci.draw_line(Vector2(cap.position.x, cap.end.y), cap.end, OUTLINE, 4.0)
	_edges(ci, rect)

## The red brick stair: one brick block per step's square.
static func _bricks(ci: CanvasItem, rect: Rect2) -> void:
	var s := LevelCastleData.STEP_W
	var y := rect.position.y
	while y < rect.end.y - 1.0:
		var block := Rect2(rect.position.x, y, s, s)
		if not Art.draw_stretched(ci, "castle_brick", block):
			ci.draw_rect(block, BRICK)
			ci.draw_rect(block, OUTLINE, false, 4.0)
		y += s

## The keep wall: the painting's bays side by side, its walk level with the
## top of the ground; below the painting's foot, its lower courses again.
static func _keep(ci: CanvasItem, rect: Rect2) -> void:
	var t := Art.tex("castle_keep_wall")
	if t == null:
		ci.draw_rect(rect, SANDSTONE)
		_edges(ci, rect)
		return
	var scale := BAY_W / float(t.get_width())
	var lower := float(t.get_height()) * 0.5
	var x := rect.position.x
	while x < rect.end.x - 1.0:
		var w := minf(BAY_W, rect.end.x - x)
		var src_w := w / scale
		var y := rect.position.y
		# The bay itself, from its walk down.
		var h := minf((float(t.get_height()) - WALK_ROW) * scale, rect.end.y - y)
		ci.draw_texture_rect_region(t, Rect2(x, y, w, h), Rect2(0, WALK_ROW, src_w, h / scale))
		y += h
		# Below its foot: its lower half again, as many times as it takes.
		while y < rect.end.y - 1.0:
			var h2 := minf(lower * scale, rect.end.y - y)
			ci.draw_texture_rect_region(t, Rect2(x, y, w, h2), Rect2(0, lower, src_w, h2 / scale))
			y += h2
		x += BAY_W

static func _edges(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_line(rect.position, Vector2(rect.position.x, rect.end.y), OUTLINE, 5.0)
	ci.draw_line(Vector2(rect.end.x, rect.position.y), rect.end, OUTLINE, 5.0)

# ------------------------------------------------------------- the back layer

## The moat: bright water a little below the road, down out of sight.
func _moat() -> void:
	var c := LevelCastleData.CHASM
	var top := LevelCastleData.GROUND_TOP + 46.0
	var bottom := LevelCastleData.KILL_Y + 400.0
	var t := Art.tex("castle_water")
	if t == null:
		draw_rect(Rect2(c.x, top, c.y - c.x, bottom - top), WATER)
		return
	# The wave line once along the top, and the deep water under it.
	var h := 150.0
	var w := h * float(t.get_width()) / float(t.get_height())
	var x := c.x
	while x < c.y - 1.0:
		var cw := minf(w, c.y - x)
		draw_texture_rect_region(t, Rect2(x, top, cw, h), Rect2(0, 0, cw / w * float(t.get_width()), t.get_height()))
		x += w
	draw_rect(Rect2(c.x, top + h - 2.0, c.y - c.x, bottom - top - h), DEEP_WATER)

## Green bushes along the road, behind everyone.
func _bushes() -> void:
	var top := LevelCastleData.GROUND_TOP
	var spots := [[-180.0, 0], [300.0, 1], [720.0, 0], [1340.0, 1], [2190.0, 0],
		[2660.0, 1], [3140.0, 0], [3320.0, 1]]
	for s in spots:
		var t := Art.tex("castle_bush_%d" % int(s[1]))
		if t == null:
			continue
		var h := 46.0 if int(s[1]) == 0 else 34.0
		var w := h * float(t.get_width()) / float(t.get_height())
		draw_texture_rect(t, Rect2(float(s[0]) - w * 0.5, top - h + 4.0, w, h), false)

## The gatehouse round the portcullis: its archway's opening is the gate.
func _gatehouse() -> void:
	var t := Art.tex("castle_gate_arch")
	if t == null:
		return
	var h := LevelCastleData.GATE_HEIGHT / ARCH_ROWS * float(t.get_height())
	var w := h * float(t.get_width()) / float(t.get_height())
	draw_texture_rect(t, Rect2(LevelCastleData.GATE_X - w * 0.5, LevelCastleData.GROUND_TOP - h + 6.0, w, h), false)

## The keep's battlements, standing up from the walk along its top.
func _battlements() -> void:
	var t := Art.tex("castle_keep_wall")
	if t == null:
		return
	var scale := BAY_W / float(t.get_width())
	var walk := WALK_ROW * scale
	var x := LevelCastleData.KEEP_X
	while x < LevelCastleData.KEEP_END - 1.0:
		var w := minf(BAY_W, LevelCastleData.KEEP_END - x)
		draw_texture_rect_region(t, Rect2(x, LevelCastleData.KEEP_TOP - walk, w, walk),
			Rect2(0, 0, w / scale, WALK_ROW))
		x += BAY_W
