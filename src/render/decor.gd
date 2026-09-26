extends Node2D
## Non-colliding scenery. The normal stages keep their existing bright props;
## stage 1-2 adds a separate horror dressing set without changing collision.

var items: Array[Dictionary] = []

func _ready() -> void:
	z_index = 1
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _draw() -> void:
	for item in items:
		match String(item.get("type", "")):
			"conduit": _conduit(item["pos"], item.get("size", Vector2(90, 76)))
			"blocks": _blocks(item["pos"], int(item.get("count", 3)),
				float(item.get("cell", 46.0)))
			"ruin_blocks": _ruin_blocks(item["pos"], int(item.get("count", 2)),
				float(item.get("cell", 48.0)))
			"fence": _fence(item["pos"], float(item.get("width", 180.0)))
			"tree": _tree(item["pos"])
			"flowers": _flowers(item["pos"])
			"signpost": _signpost(item["pos"], bool(item.get("flip", false)))
			"crate": _crate(item["pos"], float(item.get("scale", 1.0)))
			"cart": _cart(item["pos"], bool(item.get("flip", false)))
			"lantern": _lantern(item["pos"], float(item.get("scale", 1.0)))
			"puddle": _puddle(item["pos"], float(item.get("width", 190.0)))
			"roots": _roots(item["pos"], bool(item.get("flip", false)))
			"grave": _grave(item["pos"], float(item.get("scale", 1.0)))
			"banner": _banner(item["pos"], bool(item.get("flip", false)))
			"crow": _crow(item["pos"], bool(item.get("flip", false)))
			"brazier": _brazier(item["pos"], float(item.get("scale", 1.0)))
			"rubble": _rubble(item["pos"], float(item.get("scale", 1.0)))
			"keel": _keel(item["pos"], float(item.get("width", 240.0)))
			"streamer": _streamer(item["pos"], float(item.get("scale", 1.0)))
			"arch": _arch(item["pos"], float(item.get("scale", 1.0)))
			# 1-4, the sea.
			"sea_palm", "sea_palm_small":
				Art.draw_sprite(self, String(item["type"]), item["pos"] + Vector2(0, 6.0),
					float(item.get("height", 260.0)), bool(item.get("flip", false)))
			"sea_grass":
				Art.draw_sprite_w(self, "sea_grass", item["pos"] + Vector2(0, 8.0),
					float(item.get("width", 130.0)), bool(item.get("flip", false)))
			"sea_boulder":
				Art.draw_sprite_w(self, "sea_boulder", item["pos"] + Vector2(0, 10.0),
					float(item.get("width", 140.0)), bool(item.get("flip", false)))
			"sea_seaweed":
				Art.draw_sprite_w(self, "sea_seaweed", item["pos"] + Vector2(0, 8.0),
					float(item.get("width", 120.0)), bool(item.get("flip", false)))
			"sea_rock", "sea_pier", "sea_bridge":
				_sea_footing(String(item["type"]), item["rect"])
			"swamp_tree":
				_swamp_prop(Rect2(0, 0, 768, 512), item["pos"],
					float(item.get("height", 260.0)), bool(item.get("flip", false)))
			"swamp_mushroom":
				_swamp_prop(Rect2(768, 0, 768, 512), item["pos"], 120.0)
			"swamp_reeds":
				_swamp_prop(Rect2(0, 512, 768, 512), item["pos"], 115.0)
			"swamp_boulder":
				_swamp_prop(Rect2(768, 512, 768, 512), item["pos"], 130.0)
			"swamp_stone", "swamp_bridge":
				_swamp_footing(String(item["type"]), item["rect"])

## A stone conduit rising out of the ground: the thing the runner stands on
## and the guardian shoots past.
##
## It is drawn entirely INSIDE its rect, which is the rect
## Level01Data.solid_decor() turns into a collider. The shape this replaced
## carried a wide cap 26px above that rect, so its top edge was a lie -- the
## runner landed on a line 26px below the surface they could see. Nothing was
## measuring that, because it was art.
func _conduit(base: Vector2, size: Vector2) -> void:
	var rect := Rect2(base.x - size.x * 0.5, base.y - size.y, size.x, size.y)
	var stone := Balance.C_CONDUIT
	var dark := Balance.C_CONDUIT_DARK
	var collar_h: float = minf(20.0, size.y * 0.26)
	var inset: float = size.x * 0.10

	# Five primitives, and it has to stay five. The painted pipe this replaced
	# was ONE textured quad, and the first version of this function drew twelve
	# -- across 1-1's conduits and block rows that took the stage from 142 draw
	# calls to 225 and put a 48ms spike into a frame that had none. This desktop
	# never showed it, because vsync hid it and the median never moved; the
	# phone it shipped to stuttered. tools/perf_probe.gd is what found it.
	#
	# The silhouette does the work: a shaft narrowing to a flat collar, one
	# shaded face, one dark mouth. No courses, no rounded corners, no highlight
	# -- each was its own primitive, for detail nobody sees at this size.
	var top := rect.position.y + collar_h
	draw_colored_polygon(PackedVector2Array([
		Vector2(rect.position.x, rect.end.y),
		Vector2(rect.position.x + inset, top),
		Vector2(rect.end.x - inset, top),
		Vector2(rect.end.x, rect.end.y),
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(rect.end.x - inset - size.x * 0.20, top),
		Vector2(rect.end.x - inset, top),
		Vector2(rect.end.x, rect.end.y),
		Vector2(rect.end.x - size.x * 0.22, rect.end.y),
	]), dark)
	draw_rect(Rect2(rect.position.x - 4.0, rect.position.y, size.x + 8.0, collar_h), stone)
	draw_rect(Rect2(rect.position.x - 4.0, top - 4.0, size.x + 8.0, 4.0), dark)
	draw_rect(Rect2(base.x - size.x * 0.32, rect.position.y + 4.0,
		size.x * 0.64, collar_h * 0.45), Color("241f1a"))

## A short run of solid masonry with one marked stone in the middle of it.
##
## The marked one is not a container and never was -- nothing in this game
## opens it. It is a landmark: it tells the runner which block of a row they
## are looking at, and it gives the guardian something to name out loud.
func _blocks(at: Vector2, count: int, cell: float) -> void:
	for i in range(count):
		var r := Rect2(at.x + float(i) * cell, at.y, cell, cell)
		if i == count / 2:
			_sigil_block(r)
		else:
			_masonry_block(r)

func _ruin_blocks(at: Vector2, count: int, cell: float) -> void:
	# Chunky square masonry, painted with a top plane and dark right plane.
	# The matching collision rectangles live in level_horror_data.solid_decor;
	# this function is deliberately visual-only like every other decor item.
	for i in range(count):
		var r := Rect2(at.x + float(i) * cell, at.y, cell, cell)
		if Art.draw_stretched(self, "horror_ruin_block", r):
			continue
		var front := Color("303a47")
		var top := Color("526171")
		var side := Color("202a36")
		draw_rect(r, front)
		draw_colored_polygon(PackedVector2Array([
			r.position,
			r.position + Vector2(8.0, -7.0),
			r.position + Vector2(r.size.x + 8.0, -7.0),
			r.position + Vector2(r.size.x, 0.0),
		]), top)
		draw_colored_polygon(PackedVector2Array([
			r.position + Vector2(r.size.x, 0.0),
			r.position + Vector2(r.size.x + 8.0, -7.0),
			r.position + Vector2(r.size.x + 8.0, r.size.y - 7.0),
			r.position + r.size,
		]), side)
		draw_rect(r, Color("17202b"), false, 2.0)
		draw_line(r.position + Vector2(8.0, 9.0),
			r.position + Vector2(r.size.x - 8.0, 9.0), Color("577a61"), 4.0)

## Coursed stone. Two stones per row, offset row by row, with the top course
## catching the light -- the way the ground blocks in this stage are built.
func _masonry_block(r: Rect2) -> void:
	var stone := Balance.C_MASONRY
	var dark := Balance.C_MASONRY_DARK
	# Four primitives: the stone, its shaded right side, one course line and
	# the lit top edge. See the note in _conduit about why the count matters.
	draw_rect(r, stone)
	draw_rect(Rect2(r.end.x - r.size.x * 0.22, r.position.y, r.size.x * 0.22, r.size.y),
		Color(dark, 0.55))
	var y := r.position.y + r.size.y * 0.5
	draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(dark, 0.7), 2.0)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4.0), Color(1, 1, 1, 0.16))

## The marked stone: the same masonry with a lozenge cut into it and a little
## gold left in the cut. Two polygons, because it is a landmark read from
## across a screen -- the spiral that was here first was a 35-point polyline
## drawn twice, which is 68 segments per block, every frame.
func _sigil_block(r: Rect2) -> void:
	_masonry_block(r)
	var c := r.position + r.size * 0.5
	var w := r.size.x * 0.26
	var h := r.size.y * 0.30
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.0, -h), c + Vector2(w, 0.0), c + Vector2(0.0, h), c + Vector2(-w, 0.0),
	]), Color(0.18, 0.15, 0.11, 0.85))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.0, -h * 0.52), c + Vector2(w * 0.52, 0.0),
		c + Vector2(0.0, h * 0.52), c + Vector2(-w * 0.52, 0.0),
	]), Balance.C_SIGIL)

func _signpost(base: Vector2, flip: bool) -> void:
	if Art.draw_sprite(self, "signpost", base + Vector2(0, 4.0), 92.0, flip):
		return
	var wood := Color("c69660")
	draw_rect(Rect2(base.x - 6.0, base.y - 92.0, 12.0, 92.0), wood)
	var board := Rect2(base.x - 34.0, base.y - 84.0, 68.0, 30.0)
	DrawUtil.rounded_rect(self, board, 3.0, wood)
	var dir := -1.0 if flip else 1.0
	var centre := board.get_center()
	draw_line(centre - Vector2(dir * 20.0, 0.0), centre + Vector2(dir * 14.0, 0.0),
		Color("d13b3b"), 5.0)
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(dir * 22.0, 0.0), centre + Vector2(dir * 10.0, -8.0),
		centre + Vector2(dir * 10.0, 8.0),
	]), Color("d13b3b"))

func _fence(base: Vector2, width: float) -> void:
	if Art.tex("fence") != null:
		if Stage.is_horror():
			# Repeated at a fixed HEIGHT rather than stretched to the width it
			# was asked for. The painted panel is nearly square where the vector
			# one was a long low rail, and stretching it across 240px made a
			# fence almost four times the runner's height.
			var post := 100.0
			var panel: Vector2 = Vector2(Art.tex("fence").get_size())
			var each: float = post * (panel.x / maxf(panel.y, 1.0))
			var copies := maxi(1, int(round(width / maxf(each, 1.0))))
			var step := width / float(copies)
			for i in range(copies):
				Art.draw_sprite(self, "fence",
					Vector2(base.x + step * (float(i) + 0.5), base.y + 4.0),
					post, i % 2 == 1)
			return
		var span := 64.0
		var n := maxi(1, int(round(width / span)))
		for i in range(n):
			Art.draw_sprite(self, "fence",
				Vector2(base.x + span * (float(i) + 0.5), base.y + 4.0), 62.0)
		return
	var wood := Color("c69660")
	var dark := Color("9c7040")
	for rail in range(2):
		var y := base.y - 44.0 + float(rail) * 18.0
		draw_rect(Rect2(base.x, y, width, 8.0), wood)
		draw_rect(Rect2(base.x, y + 6.0, width, 2.0), dark)
	var posts := maxi(2, int(width / 60.0))
	for i in range(posts + 1):
		var x := base.x + width * float(i) / float(posts)
		draw_rect(Rect2(x - 5.0, base.y - 56.0, 10.0, 58.0), wood)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 5.0, base.y - 56.0), Vector2(x + 5.0, base.y - 56.0),
			Vector2(x, base.y - 64.0),
		]), wood)
		draw_rect(Rect2(x + 2.0, base.y - 56.0, 3.0, 58.0), dark)

func _tree(base: Vector2) -> void:
	if Art.draw_sprite(self, "tree", base + Vector2(0, 6.0), 250.0):
		return
	var trunk := Color("7a5433")
	draw_rect(Rect2(base.x - 14.0, base.y - 96.0, 28.0, 98.0), trunk)
	draw_rect(Rect2(base.x + 3.0, base.y - 96.0, 8.0, 98.0), trunk.darkened(0.25))
	var canopy := Balance.C_HILL_NEAR
	var blobs := [
		Vector2(0, -132), Vector2(-56, -108), Vector2(56, -108),
		Vector2(-32, -160), Vector2(34, -158), Vector2(0, -96),
	]
	for i in blobs.size():
		var b: Vector2 = blobs[i]
		draw_circle(base + b, 52.0 - float(i) * 2.0, canopy.darkened(0.12))
	for i in blobs.size():
		var b: Vector2 = blobs[i]
		draw_circle(base + b + Vector2(-4, -6), 44.0 - float(i) * 2.0, canopy)

func _flowers(base: Vector2) -> void:
	if Art.draw_sprite(self, "flowers", base + Vector2(0, 4.0), 38.0):
		return
	for i in range(3):
		var x := base.x + float(i) * 26.0 - 26.0
		var h := 18.0 + DrawUtil.hash01(int(x)) * 10.0
		draw_line(Vector2(x, base.y), Vector2(x, base.y - h), Balance.C_GRASS_DARK, 2.5)
		var centre := Vector2(x, base.y - h)
		for p in range(5):
			var a := TAU * float(p) / 5.0
			draw_circle(centre + Vector2(cos(a), sin(a)) * 5.5, 4.2, Color.WHITE)
		draw_circle(centre, 3.4, Color("f6c945"))

# ---------------------------------------------------------- horror set dressing

func _crate(base: Vector2, scale: float) -> void:
	var s := 54.0 * scale
	if Art.draw_sprite(self, "horror_crate", base, s * 1.12):
		return
	var r := Rect2(base.x - s * 0.5, base.y - s, s, s)
	draw_rect(r, Color("493828"))
	draw_rect(r, Color("211a16"), false, 4.0 * scale)
	draw_line(r.position + Vector2(7, 7) * scale,
		r.position + r.size - Vector2(7, 7) * scale, Color("75583c"), 5.0 * scale)
	draw_line(Vector2(r.position.x + r.size.x - 7 * scale, r.position.y + 7 * scale),
		Vector2(r.position.x + 7 * scale, r.position.y + r.size.y - 7 * scale),
		Color("75583c"), 5.0 * scale)

func _cart(base: Vector2, flip: bool) -> void:
	if Art.draw_sprite(self, "horror_cart", base + Vector2(0.0, 4.0), 94.0, flip):
		return
	var d := -1.0 if flip else 1.0
	draw_circle(base + Vector2(-42 * d, -24), 24.0, Color("241d19"))
	draw_circle(base + Vector2(-42 * d, -24), 18.0, Color("4a382a"), false, 5.0)
	var body := PackedVector2Array([
		base + Vector2(-24*d,-66), base + Vector2(56*d,-76),
		base + Vector2(42*d,-28), base + Vector2(-14*d,-26)])
	draw_colored_polygon(body, Color("493629"))
	draw_polyline(body, Color("211a17"), 5.0, true)
	draw_line(base + Vector2(50*d,-68), base + Vector2(86*d,-88), Color("2b211a"), 7.0)

func _lantern(base: Vector2, scale: float) -> void:
	# It used to borrow the checkpoint's lamp, which made every lantern in the
	# village look like somewhere you could respawn.
	if Art.draw_sprite(self, "horror_lantern", base, 138.0 * scale):
		return
	draw_rect(Rect2(base.x - 4, base.y - 118 * scale, 8, 118 * scale), Color("30271f"))
	draw_circle(base + Vector2(23 * scale, -85 * scale), 15 * scale,
		Color(1.0, 0.62, 0.25, 0.35))

func _puddle(base: Vector2, width: float) -> void:
	# Painted in perspective, so it is drawn to a squatter rect than its own
	# aspect asks for: seen side-on, a puddle at its natural proportions stands
	# up off the ground like a wall. The tufts of grass at either end keep the
	# squash from reading as a squash.
	if Art.tex("horror_puddle") != null:
		var h := width * 0.30
		if Art.draw_stretched(self, "horror_puddle",
				Rect2(base.x - width * 0.5, base.y - h * 0.74, width, h)):
			return
	_draw_ellipse(base + Vector2(0, -5), Vector2(width * 0.5, 14.0),
		Color(0.25, 0.31, 0.32, 0.55))
	draw_line(base + Vector2(-width * 0.25, -8), base + Vector2(width * 0.15, -8),
		Color(0.8, 0.76, 0.67, 0.2), 3.0)

func _draw_ellipse(centre: Vector2, radius: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * float(i) / 24.0
		pts.append(centre + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, color)

func _roots(base: Vector2, flip: bool) -> void:
	var d := -1.0 if flip else 1.0
	for branch in [Vector2(-62*d,-8), Vector2(-40*d,-42), Vector2(5*d,-58),
		Vector2(44*d,-36), Vector2(67*d,-6)]:
		draw_line(base, base + branch, Color("30251e"), 9.0, true)
		draw_line(base, base + branch, Color("584130"), 3.0, true)

func _grave(base: Vector2, scale: float) -> void:
	if Art.draw_sprite(self, "horror_grave", base, 84.0 * scale):
		return
	var w := 48.0 * scale
	var h := 72.0 * scale
	var r := Rect2(base.x - w * 0.5, base.y - h, w, h)
	DrawUtil.rounded_rect(self, r, 14.0 * scale, Color("4b4c47"))
	draw_line(Vector2(base.x, base.y - h + 16 * scale),
		Vector2(base.x, base.y - 18 * scale), Color("282a28"), 6.0 * scale)
	draw_line(Vector2(base.x - 13 * scale, base.y - h + 34 * scale),
		Vector2(base.x + 13 * scale, base.y - h + 34 * scale), Color("282a28"), 6.0 * scale)

func _banner(base: Vector2, flip: bool) -> void:
	var d := -1.0 if flip else 1.0
	draw_line(base, base + Vector2(0, -146), Color("30251e"), 8.0)
	draw_line(base + Vector2(-35*d,-132), base + Vector2(42*d,-132), Color("30251e"), 8.0)
	var flag := PackedVector2Array([
		base + Vector2(4*d,-126), base + Vector2(42*d,-126),
		base + Vector2(42*d,-64), base + Vector2(29*d,-76),
		base + Vector2(16*d,-62), base + Vector2(4*d,-72)])
	draw_colored_polygon(flag, Color("5b2726"))
	draw_line(base + Vector2(23*d,-114), base + Vector2(23*d,-79), Color("c7b6a0"), 4.0)
	draw_line(base + Vector2(12*d,-97), base + Vector2(34*d,-97), Color("c7b6a0"), 4.0)

func _crow(base: Vector2, flip: bool) -> void:
	var d := -1.0 if flip else 1.0
	var pts := PackedVector2Array([
		base + Vector2(-28*d,-8), base + Vector2(-6*d,-24),
		base + Vector2(9*d,-16), base + Vector2(27*d,-28),
		base + Vector2(20*d,-9), base + Vector2(34*d,-3),
		base + Vector2(7*d,2), base + Vector2(-9*d,0)])
	draw_colored_polygon(pts, Color("15181b"))

## The Keeper's arena, which is dressed with almost nothing (see
## level_keeper_data.decor: in a fight whose whole question is "is there
## something between us", a decorative barrel is a cruel joke). These two are
## what is left -- a fire, which lights the floor, and rubble, which is flat.
func _brazier(base: Vector2, scale: float) -> void:
	if Art.draw_sprite(self, "keeper_brazier", base, 150.0 * scale):
		return
	var s := scale
	# Three legs.
	for dx in [-20.0, 0.0, 20.0]:
		draw_line(base + Vector2(dx * s, 0.0), base + Vector2(0.0, -62.0 * s),
			Color("2b2724"), 6.0 * s)
	var bowl := Rect2(base.x - 30.0 * s, base.y - 84.0 * s, 60.0 * s, 24.0 * s)
	DrawUtil.rounded_rect(self, bowl, 6.0 * s, Color("3a332c"))
	draw_rect(bowl, Color("221e1a"), false, 2.0)
	# Coals, then a small steady flame. Small on purpose: a bonfire here would
	# throw more light than the backdrop it is standing against.
	draw_circle(base + Vector2(0.0, -80.0 * s), 22.0 * s, Color(1.0, 0.45, 0.12, 0.30))
	for i in range(4):
		draw_circle(base + Vector2((float(i) - 1.5) * 13.0 * s, -80.0 * s),
			7.0 * s, Color("e8761f"))
	draw_circle(base + Vector2(0.0, -96.0 * s), 13.0 * s, Color(1.0, 0.68, 0.22, 0.55))
	draw_circle(base + Vector2(0.0, -101.0 * s), 7.0 * s, Color(1.0, 0.90, 0.60, 0.70))

func _rubble(base: Vector2, scale: float) -> void:
	if Art.draw_sprite(self, "keeper_rubble", base, 74.0 * scale):
		return
	var s := scale
	var stone := Color("4b524d")
	var edge := Color("343a36")
	for i in range(5):
		var w := (26.0 + float((i * 7) % 18)) * s
		var h := (14.0 + float((i * 5) % 12)) * s
		var r := Rect2(base.x + (float(i) - 2.2) * 24.0 * s, base.y - h, w, h)
		draw_rect(r, stone)
		draw_rect(r, edge, false, 2.0)
	draw_line(base + Vector2(-46.0 * s, -6.0 * s), base + Vector2(30.0 * s, -30.0 * s),
		Color("5a4a36"), 6.0 * s)

## Stage 1-S. Three pieces, and the first one is not decoration at all.
##
## An island in this game is a Rect2 like every other piece of ground, and a
## Rect2 drawn in a blue room is a platform, not a thing hanging in the sky.
## The keel is what makes the difference: `pos` is the island's BOTTOM edge and
## `width` its width, and the taper under it is the whole claim that there is
## nothing below the runner. Without it the stage reads as 1-1 with the ground
## deleted.
func _keel(base: Vector2, width: float) -> void:
	var depth := clampf(width * 0.62, 90.0, 240.0)
	# No vector chains over the painting: it has its own, hanging off the same
	# rock they are bolted to, and the second set landed a hand's width to the
	# side of the first. The fallback still draws them, because without them the
	# fallback wedge is a triangle rather than something somebody built.
	if Art.draw_stretched(self, "sky_keel",
			Rect2(base.x - width * 0.5, base.y, width, depth)):
		return
	var stone := Color("7b8291")
	var dark := Color("4e5666")
	# A wedge: full width at the island, a quarter of it at the point. Drawn as
	# one polygon so the silhouette stays clean at any width.
	var half := width * 0.5
	var point := width * 0.13
	var wedge := PackedVector2Array([
		Vector2(base.x - half, base.y),
		Vector2(base.x + half, base.y),
		Vector2(base.x + point, base.y + depth * 0.82),
		Vector2(base.x + point * 0.35, base.y + depth),
		Vector2(base.x - point * 0.45, base.y + depth * 0.94),
		Vector2(base.x - point, base.y + depth * 0.7),
	])
	draw_colored_polygon(wedge, stone)
	draw_polyline(wedge, dark, 3.0, true)
	# Strata, following the taper, so it reads as cut rock rather than a cone.
	for i in range(4):
		var t := (float(i) + 1.0) / 5.0
		var w := lerpf(half, point, t)
		var y := base.y + depth * t
		draw_line(Vector2(base.x - w * 0.92, y), Vector2(base.x + w * 0.92, y),
			Color(dark, 0.45), 2.5)
	_keel_chains(base, width, depth)

## Broken chains under an island. A landmark AND the one detail that says
## somebody built this road, rather than it having always been here.
func _keel_chains(base: Vector2, width: float, depth: float) -> void:
	for i in range(2):
		var x := base.x + width * (-0.28 + 0.56 * float(i))
		var drop := depth * (0.55 + 0.25 * float(i % 2))
		draw_line(Vector2(x, base.y), Vector2(x + 6.0, base.y + drop),
			Color("3c3b38"), 4.0)
		for link in range(3):
			var t := (float(link) + 1.0) / 4.0
			draw_circle(Vector2(lerpf(x, x + 6.0, t), base.y + drop * t), 4.0,
				Color("57544e"))

## A pole with three streamers, blown flat. A landmark the pair can NAME, and
## the only thing in the stage that shows which way the air is moving.
func _streamer(base: Vector2, scale: float) -> void:
	if Art.draw_sprite(self, "sky_streamer", base, 190.0 * scale):
		return
	var s := scale
	var top := base + Vector2(0.0, -150.0 * s)
	draw_line(base, top, Color("6c6355"), 5.0 * s)
	# The cairn at the foot, so the pole is planted rather than floating.
	for i in range(3):
		draw_circle(base + Vector2((float(i) - 1.0) * 11.0 * s, -5.0 * s),
			8.0 * s, Color("8a8fa0"))
	var cloth := [Color("e8c06a"), Color("dfa08c"), Color("cdb89a")]
	for i in range(3):
		var y := top.y + 12.0 * s + float(i) * 15.0 * s
		var length := (74.0 - float(i) * 12.0) * s
		var tail := PackedVector2Array([
			Vector2(top.x + 3.0 * s, y),
			Vector2(top.x + length, y - 5.0 * s),
			Vector2(top.x + length, y + 8.0 * s),
			Vector2(top.x + 3.0 * s, y + 10.0 * s),
		])
		draw_colored_polygon(tail, cloth[i])

## A half-fallen gate arch. The big landmark: unevenly broken on purpose, so
## "the second arch" is a thing two people can agree about out loud
## (implementation-plan.md 6.1).
func _arch(base: Vector2, scale: float) -> void:
	var w := 220.0 * scale
	var h := 260.0 * scale
	if Art.draw_stretched(self, "sky_arch",
			Rect2(base.x - w * 0.5, base.y - h, w, h)):
		return
	var stone := Color("9aa0ac")
	var dark := Color("5f6673")
	var pier := w * 0.22
	# The tall pier, the short broken one, and the lintel across the top.
	draw_rect(Rect2(base.x - w * 0.5, base.y - h, pier, h), stone)
	draw_rect(Rect2(base.x - w * 0.5, base.y - h, pier, h), dark, false, 3.0)
	draw_rect(Rect2(base.x + w * 0.5 - pier, base.y - h * 0.74, pier, h * 0.74),
		stone)
	draw_rect(Rect2(base.x + w * 0.5 - pier, base.y - h * 0.74, pier, h * 0.74),
		dark, false, 3.0)
	var lintel := Rect2(base.x - w * 0.5 - 8.0, base.y - h - 22.0, w * 0.86, 24.0)
	draw_rect(lintel, stone)
	draw_rect(lintel, dark, false, 3.0)
	# A carved band, and one crack, so it is a ruin rather than a doorway.
	draw_line(Vector2(lintel.position.x + 6.0, lintel.position.y + 12.0),
		Vector2(lintel.position.x + lintel.size.x - 6.0, lintel.position.y + 12.0),
		Color(dark, 0.7), 2.5)
	draw_line(Vector2(base.x + w * 0.5 - pier * 0.5, base.y - h * 0.74),
		Vector2(base.x + w * 0.5 - pier * 0.2, base.y - h * 0.58),
		Color(dark, 0.8), 2.5)

## A rock, pier or bridge fitted to the slab the runner stands on. The painting
## is widened a little past the collision so its rounded edge does not look like
## something to slip off, and is stretched down to below the waterline so it
## stands IN the sea rather than hovering over it.
func _sea_footing(key: String, rect: Rect2) -> void:
	var water := Stage.water_y()
	var bottom := maxf(rect.position.y + rect.size.y, water + 34.0)
	match key:
		"sea_rock":
			var r := Rect2(rect.position.x - rect.size.x * 0.10, rect.position.y - 12.0,
				rect.size.x * 1.20, bottom - rect.position.y + 12.0)
			Art.draw_stretched(self, key, r)
		"sea_pier":
			# Deck on top, its own legs stretched down into the water.
			Art.draw_stretched(self, key, Rect2(rect.position.x - 8.0, rect.position.y - 5.0,
				rect.size.x + 16.0, bottom - rect.position.y + 5.0))
		"sea_bridge":
			Art.draw_stretched(self, key, Rect2(rect.position.x - 10.0, rect.position.y - 6.0,
				rect.size.x + 20.0, bottom - rect.position.y + 6.0))

func _swamp_prop(region: Rect2, bottom_centre: Vector2, height: float,
		flip_h: bool = false) -> void:
	var atlas := Art.tex("swamp_props_atlas")
	if atlas == null:
		return
	var width := height * region.size.x / region.size.y
	var dest := Rect2(bottom_centre - Vector2(width * 0.5, height),
		Vector2(width, height))
	if flip_h:
		draw_set_transform(Vector2(bottom_centre.x * 2.0, 0.0), 0.0,
			Vector2(-1.0, 1.0))
	draw_texture_rect_region(atlas, dest, region)
	if flip_h:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _swamp_footing(key: String, rect: Rect2) -> void:
	if key == "swamp_stone":
		var bottom := Stage.water_y() + 25.0
		var face := Rect2(rect.position.x - 8.0, rect.position.y + 13.0,
			rect.size.x + 16.0, bottom - rect.position.y - 13.0)
		if not Art.draw_tiled(self, "sky_island_tile", face, 145.0,
				Color("b1a382")):
			draw_rect(face, Color("625c50"))
		draw_rect(face, Color(0.17, 0.14, 0.10, 0.10))
		draw_rect(Rect2(rect.position.x - 9.0, rect.position.y - 8.0,
			rect.size.x + 18.0, 27.0), Color("68a52f"))
		draw_rect(Rect2(rect.position.x - 8.0, rect.position.y - 8.0,
			rect.size.x + 16.0, 8.0), Color("b4dd4f"))
		for n in range(maxi(1, int(rect.size.x / 32.0))):
			var x := rect.position.x + float(n) * 32.0 + 20.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 8.0, rect.position.y + 16.0),
				Vector2(x + 8.0, rect.position.y + 16.0),
				Vector2(x, rect.position.y + 31.0 + float(n % 3) * 5.0)]),
				Color("5f972a"))
		Art.draw_tiled(self, "sky_island_cap", Rect2(rect.position.x - 9.0,
			rect.position.y - 12.0, rect.size.x + 18.0, 35.0), 35.0,
			Color("a0ec61"))
		return
	# The walkable bridge deck follows the collision rectangle exactly.
	for n in range(maxi(1, int(ceilf(rect.size.x / 32.0)))):
		var x := rect.position.x + float(n) * 32.0
		var width := minf(30.0, rect.end.x - x)
		if width > 0.0:
			draw_rect(Rect2(x, rect.position.y, width, rect.size.y), Color("915a31"))
			draw_rect(Rect2(x + 2.0, rect.position.y + 2.0,
				maxf(0.0, width - 4.0), 5.0), Color("c58a4a"))
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y),
		Color("523b29"), 6.0)
