extends Control
## The actual painting for Sky. Split out so the CanvasLayer stays a container
## and the drawing has a Control's rect to work against.

var sky: Node = null

func _draw() -> void:
	if sky == null:
		return
	var view := size
	var scroll: float = sky.scroll()
	var t: float = sky.time()

	draw_texture_rect(sky.gradient(), Rect2(Vector2.ZERO, view), false)
	if _panorama(view, scroll * PANORAMA_RATE):
		# The painted backdrop already contains its own clouds, hills, castle and
		# bush line. Drawing the procedural ones on top of it would be two of
		# each, at two different rates, so the whole mid-distance is either
		# painted or drawn -- never both.
		return
	_clouds(view, scroll * 0.06 - t * 6.0, _base(view, 0.06) - view.y * 0.63)
	_hills(view, scroll * 0.16, _base(view, 0.16), 0.0)
	_castle(view, scroll * 0.24, _base(view, 0.24))
	_hills(view, scroll * 0.38, _base(view, 0.38), 1.0)
	_bushes(view, scroll * 0.55, _base(view, 0.55))

## How fast the painted backdrop scrolls relative to the world. Between the old
## castle layer (0.24) and the near hills (0.38): the panorama spans that whole
## range of depth, so it takes the middle of it.
const PANORAMA_RATE := 0.30
## Where the grass line sits in the painted backdrop, as a fraction of its
## height. The horizon is pinned to this, so the painted ground meets the real
## ground instead of floating above or below it.
const PANORAMA_HORIZON := 0.735
## Height of the backdrop as a multiple of the screen, so there is painted sky
## left above the horizon when the runner is at the top of the climb.
const PANORAMA_SCALE := 1.30
## The colour of the painted backdrop's bottom row, continued underneath it.
const PANORAMA_FLOOR := Color(0.624, 0.408, 0.286)

## The supplied backdrop, repeated across the stage.
##
## Every other copy is mirrored. The image does not tile -- there is a tree
## trunk cut off at its left edge and a different one at its right -- and
## mirroring makes the seam match by construction, which for scenery this soft
## is invisible. Only the copies actually on screen are emitted, so a 16,000px
## stage costs the same two draws as a 900px one.
func _panorama(view: Vector2, offset: float) -> bool:
	var t := Art.tex("parallax")
	if not Balance.USE_TEXTURES or t == null:
		return false
	var h := view.y * PANORAMA_SCALE
	var w := h * (float(t.get_width()) / maxf(float(t.get_height()), 1.0))
	var top := _base(view, PANORAMA_RATE) - h * PANORAMA_HORIZON
	var span := _visible_range(offset, w, view.x)
	for i in range(span[0], span[1] + 1):
		var x := float(i) * w - offset
		var mirror := absi(i) % 2 == 1
		if mirror:
			# Flipped by transform, NOT by handing draw_texture_rect a negative
			# width. Godot builds a canvas item's cull rect from the rect it is
			# given without normalising a negative size, so Rect2(x + w, top,
			# -w, h) reports a box starting at x + w -- and as soon as a tile is
			# wide enough for that corner to leave the viewport, the whole tile
			# is culled and the bare sky gradient shows through where half the
			# backdrop should be. Proven in test/ui_probe.gd.
			draw_set_transform(Vector2((x + w * 0.5) * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect(t, Rect2(x, top, w, h), false)
		if mirror:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Below the panorama is the sky gradient again, and where the stage has a pit
	# the player looks straight through the hole in the floor at it: a strip of
	# blue under the distant ground. Continue the panorama's own earth down to
	# the bottom of the screen instead.
	var floor_y := top + h
	if floor_y < view.y:
		draw_rect(Rect2(0.0, floor_y - 1.0, view.x, view.y - floor_y + 1.0), PANORAMA_FLOOR)
	return true

## Screen y of a layer's horizon. Parallax has to work vertically too: when the
## runner jumps, the ground slides down the screen and the background has to
## follow at its own rate, or the hills detach and sit in mid-air.
func _base(view: Vector2, rate: float) -> float:
	var cam_y: float = sky.vertical()
	return view.y * 0.63 + (337.0 - cam_y) * Balance.CAMERA_ZOOM * rate

## Emits only the shapes whose band intersects the screen, so cost is constant
## in stage length. `span` is the world spacing between repeats of a shape.
func _visible_range(offset: float, span: float, width: float) -> Array:
	var first := int(floor((offset - span) / span))
	var last := int(ceil((offset + width + span) / span))
	return [first, last]

const CLOUD_KEYS := ["cloud_a", "cloud_b", "cloud_c"]

func _clouds(view: Vector2, offset: float, vert: float) -> void:
	var span := 340.0
	var range_ := _visible_range(offset, span, view.x)
	if Balance.USE_TEXTURES and Art.tex("cloud_a") != null:
		for i in range(range_[0], range_[1] + 1):
			var cx := float(i) * span - offset
			var hh := DrawUtil.hash01(i * 3 + 11)
			var h2b := DrawUtil.hash01(i * 7 + 5)
			var cy := 70.0 + hh * 160.0 + vert
			var key: String = CLOUD_KEYS[abs(i) % CLOUD_KEYS.size()]
			Art.draw_sprite(self, key, Vector2(cx, cy), 78.0 + h2b * 62.0, i % 2 == 0,
				Color(1, 1, 1, 0.88 + h2b * 0.12))
		return
	for i in range(range_[0], range_[1] + 1):
		var x := float(i) * span - offset
		var h := DrawUtil.hash01(i * 3 + 11)
		var h2 := DrawUtil.hash01(i * 7 + 5)
		var y := 60.0 + h * 150.0 + vert
		var s := 0.7 + h2 * 0.7
		var col := Color(1, 1, 1, 0.82 + h2 * 0.15)
		var lobes := [
			Vector2(0, 0), Vector2(-46, 10), Vector2(46, 8),
			Vector2(-22, -16), Vector2(26, -14), Vector2(78, 16), Vector2(-76, 16),
		]
		for j in lobes.size():
			var l: Vector2 = lobes[j]
			draw_circle(Vector2(x, y) + l * s, (34.0 - float(j) * 2.0) * s, col)

func _hills(view: Vector2, offset: float, base_y: float, near: float) -> void:
	var span := lerpf(300.0, 230.0, near)
	var base := base_y + lerpf(-46.0, 10.0, near)
	var col := Balance.C_HILL_FAR.lerp(Balance.C_HILL_NEAR, near)
	var range_ := _visible_range(offset, span, view.x)
	for i in range(range_[0], range_[1] + 1):
		var x := float(i) * span - offset
		var h := DrawUtil.hash01(i * 13 + int(near * 97) + 3)
		var radius := lerpf(96.0, 138.0, h) * lerpf(1.0, 1.22, near)
		var cy := base + lerpf(30.0, 70.0, DrawUtil.hash01(i * 5 + int(near * 31)))
		draw_circle(Vector2(x, cy), radius, col)
		# The pale speckles the mockup hills carry
		for s in range(3):
			var a := DrawUtil.hash01(i * 29 + s) * TAU
			var d := DrawUtil.hash01(i * 37 + s) * radius * 0.55
			draw_circle(Vector2(x, cy) + Vector2(cos(a), sin(a) * 0.6) * d - Vector2(0, radius * 0.35),
				7.0 + DrawUtil.hash01(i + s) * 6.0, Color(1, 1, 1, 0.13))
	draw_rect(Rect2(0, base + 78.0, view.x, view.y - base), col)

func _castle(view: Vector2, offset: float, base_y: float) -> void:
	# The mockups keep a castle on the skyline throughout, so it repeats on a
	# long period rather than appearing once and sliding away for good.
	var span := 2400.0
	var range_ := _visible_range(offset - 600.0, span, view.x + 1200.0)
	for i in range(range_[0], range_[1] + 1):
		_castle_at(view, float(i) * span + 600.0 - offset, base_y)

func _castle_at(view: Vector2, x: float, base_y: float) -> void:
	if x < -520.0 or x > view.x + 520.0:
		return
	# Sits well above its own parallax line so the nearer hill layers, which are
	# drawn after this one, leave the silhouette showing the way the mockups do.
	if Balance.USE_TEXTURES and Art.draw_sprite(self, "castle", Vector2(x, base_y - 64.0), 232.0):
		return
	# Scaled down from the first pass: at full size it competed with the play
	# field instead of sitting on the horizon like the mockups' castle.
	const K := 0.72
	var base := base_y - 10.0
	var stone := Color("f2ece4")
	var stone_dark := Color("d7cec2")
	var roof := Color("d94b3a")

	DrawUtil.rounded_rect(self, Rect2(x - 130 * K, base - 150 * K, 260 * K, 152 * K), 6.0, stone)
	draw_rect(Rect2(x - 130 * K, base - 150 * K, 260 * K, 12 * K), stone_dark)
	for i in range(3):
		var tx := x - 130.0 * K + float(i) * 110.0 * K
		var tw := 58.0 * K
		var th := (210.0 - absf(float(i) - 1.0) * 46.0) * K
		DrawUtil.rounded_rect(self, Rect2(tx, base - th, tw, th), 4.0, stone)
		draw_rect(Rect2(tx, base - th, tw, 10 * K), stone_dark)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx - 9 * K, base - th), Vector2(tx + tw + 9 * K, base - th),
			Vector2(tx + tw * 0.5, base - th - 54.0 * K),
		]), roof)
		draw_line(Vector2(tx + tw * 0.5, base - th - 54.0 * K),
			Vector2(tx + tw * 0.5, base - th - 76.0 * K), stone_dark, 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx + tw * 0.5, base - th - 76.0 * K),
			Vector2(tx + tw * 0.5 + 22.0 * K, base - th - 70.0 * K),
			Vector2(tx + tw * 0.5, base - th - 64.0 * K),
		]), Color("f2b32c"))
		for w in range(2):
			DrawUtil.rounded_rect(self,
				Rect2(tx + tw * 0.5 - 7.0 * K, base - th + (34.0 + float(w) * 40.0) * K,
					14.0 * K, 22.0 * K),
				7.0 * K, Color("4a6b8a"))

func _bushes(view: Vector2, offset: float, base_y: float) -> void:
	var span := 190.0
	var base := base_y + 34.0
	var col := Balance.C_HILL_NEAR.darkened(0.12)
	var range_ := _visible_range(offset, span, view.x)
	for i in range(range_[0], range_[1] + 1):
		var x := float(i) * span - offset
		var h := DrawUtil.hash01(i * 41 + 7)
		var r := 46.0 + h * 28.0
		draw_circle(Vector2(x, base + 30.0), r, col)
		draw_circle(Vector2(x - r * 0.75, base + 42.0), r * 0.72, col)
		draw_circle(Vector2(x + r * 0.78, base + 40.0), r * 0.68, col)
	draw_rect(Rect2(0, base + 62.0, view.x, view.y - base), col)
