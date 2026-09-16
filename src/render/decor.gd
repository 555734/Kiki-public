extends Node2D
## Non-colliding scenery. The normal stages keep their existing bright props;
## stage 1-2 adds a separate horror dressing set without changing collision.

var items: Array[Dictionary] = []

func _ready() -> void:
	z_index = 1

func _draw() -> void:
	for item in items:
		match String(item.get("type", "")):
			"pipe": _pipe(item["pos"], item.get("size", Vector2(90, 76)))
			"blocks": _blocks(item["pos"], int(item.get("count", 3)),
				float(item.get("cell", 46.0)))
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

func _pipe(base: Vector2, size: Vector2) -> void:
	var rect := Rect2(base.x - size.x * 0.5, base.y - size.y, size.x, size.y)
	if Art.draw_stretched(self, "pipe", rect):
		return
	var w := size.x
	var height := size.y
	var body := Rect2(rect.position.x, rect.position.y, w, height)
	draw_rect(body, Balance.C_PIPE)
	draw_rect(Rect2(body.position.x + 8, body.position.y, 13, body.size.y),
		Color(1, 1, 1, 0.20))
	draw_rect(Rect2(body.position.x + body.size.x - 16, body.position.y, 12, body.size.y),
		Balance.C_PIPE_DARK)
	var lip := Rect2(base.x - w * 0.5 - 9, base.y - height - 26, w + 18, 28)
	DrawUtil.rounded_rect(self, lip, 6.0, Balance.C_PIPE)
	draw_rect(Rect2(lip.position.x + 8, lip.position.y + 4, 14, lip.size.y - 8),
		Color(1, 1, 1, 0.22))
	draw_rect(Rect2(lip.position.x, lip.position.y + lip.size.y - 6, lip.size.x, 6),
		Balance.C_PIPE_DARK)
	draw_rect(Rect2(lip.position.x + 4, lip.position.y + 4, lip.size.x - 8, 7),
		Color(0.08, 0.24, 0.10, 0.55))

func _blocks(at: Vector2, count: int, cell: float) -> void:
	for i in range(count):
		var r := Rect2(at.x + float(i) * cell, at.y, cell, cell)
		var key := "qblock" if i == count / 2 else "brick"
		if Art.draw_stretched(self, key, r):
			continue
		if i == count / 2:
			_question_block(r)
		else:
			_brick_block(r)

func _brick_block(r: Rect2) -> void:
	draw_rect(r, Balance.C_BRICK)
	draw_rect(r, Color(0.35, 0.16, 0.05, 0.55), false, 2.0)
	for row in range(3):
		var y := r.position.y + (float(row) + 1.0) * r.size.y / 3.0
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x + r.size.x, y),
			Color(0.35, 0.16, 0.05, 0.5), 2.0)
		var offset := 0.0 if row % 2 == 0 else r.size.x * 0.5
		var x := r.position.x + offset + r.size.x * 0.25
		if x < r.position.x + r.size.x:
			draw_line(Vector2(x, y - r.size.y / 3.0), Vector2(x, y),
				Color(0.35, 0.16, 0.05, 0.5), 2.0)
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 5),
		Color(1, 1, 1, 0.18))

func _question_block(r: Rect2) -> void:
	DrawUtil.rounded_rect(self, r, 5.0, Balance.C_QBLOCK)
	draw_rect(r, Color(0.55, 0.33, 0.03, 0.8), false, 2.5)
	for i in range(4):
		var cx := r.position.x + (6.0 if i % 2 == 0 else r.size.x - 6.0)
		var cy := r.position.y + (6.0 if i < 2 else r.size.y - 6.0)
		draw_circle(Vector2(cx, cy), 2.6, Color(0.55, 0.33, 0.03))
	var font := Art.font()
	draw_string(font, r.position + Vector2(r.size.x * 0.5 - 9.0, r.size.y * 0.72), "?",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.45, 0.26, 0.02))

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
