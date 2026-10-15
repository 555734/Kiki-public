class_name FinaleGround
extends RefCounted
## 1-10 ground painting. Collision stays the level's rectangles and slope
## polygons; only the picture changes. Every slab is drawn as a shaped mass
## instead of a box: an exposed side gets a material outline (earth cliffs
## recede under an overhanging grass lip, sandstone steps in eroded ledges,
## basalt and canyon rock are jagged, comb walls are scalloped hex rims),
## floating ledges get a rocky underside, thin bone ledges are bones, and
## the faces are faceted painted rock (assets/stage_1_10/tex_*.png, from
## tools/promotion/make_terrain_textures.py) with depth shading, a dark rim,
## a lit edge, strata and a few props on top.
##
## Sides that touch another slab stay straight and unrimmed, so a cliff made
## of two rectangles still reads as one mass. Everything is a function of the
## rectangle and its index: drawn once per chunk and cached by the renderer.

## Face texture, its world tile size, outline style and colours per skin.
const LOOK := {
	"grass": {"tex": "res://assets/stage_1_10/tex_earth.png", "tile": 360.0, "style": "earth",
		"rim": Color("4a2512"), "lit": Color(1.0, 0.86, 0.62, 0.30), "shade": Color(0.16, 0.05, 0.02)},
	"cliff": {"tex": "res://assets/stage_1_10/tex_mesa.png", "tile": 380.0, "style": "jagged",
		"rim": Color("4a1d10"), "lit": Color(1.0, 0.8, 0.6, 0.30), "shade": Color(0.18, 0.04, 0.02)},
	"sand": {"tex": "res://assets/stage_1_10/tex_sandstone.png", "tile": 340.0, "style": "strata",
		"rim": Color("6a3b16"), "lit": Color(1.0, 0.93, 0.75, 0.35), "shade": Color(0.28, 0.12, 0.03)},
	"lava": {"tex": "res://assets/stage_1_10/tex_basalt.png", "tile": 300.0, "style": "jagged",
		"rim": Color("170a0d"), "lit": Color(1.0, 0.55, 0.25, 0.35), "shade": Color(0.05, 0.0, 0.02)},
	"storm": {"tex": "res://assets/stage_1_10/tex_slate.png", "tile": 320.0, "style": "jagged",
		"rim": Color("141826"), "lit": Color(0.75, 0.85, 1.0, 0.30), "shade": Color(0.02, 0.03, 0.08)},
	"rail": {"tex": "res://assets/props/masonry.png", "tile": 96.0, "style": "masonry",
		"rim": Color("2f2a28"), "lit": Color(1, 1, 1, 0.22), "shade": Color(0.06, 0.05, 0.05)},
	"hive": {"tex": "res://assets/stage_1_10/tex_comb.png", "tile": 300.0, "style": "comb",
		"rim": Color("6b3404"), "lit": Color(1.0, 0.95, 0.6, 0.35), "shade": Color(0.25, 0.08, 0.0)},
	"bone": {"tex": "res://assets/stage_1_10/tex_fossil.png", "tile": 420.0, "style": "jagged",
		"rim": Color("5a4330"), "lit": Color(1.0, 0.97, 0.88, 0.35), "shade": Color(0.22, 0.14, 0.06)},
}

const BONE := Color("f1e6c8")
const BONE_SHADE := Color("bba57e")
const BONE_RIM := Color("5a4330")

static var _ground: Array[Rect2] = []
static var _ground_stage := -1

static func _all_ground() -> Array[Rect2]:
	if _ground_stage != int(Stage.current()) or _ground.is_empty():
		_ground = Stage.data().ground()
		_ground_stage = int(Stage.current())
	return _ground

static func h(n: int) -> float:
	return DrawUtil.hash01(n)

## Smooth 1D value noise in [-1, 1], period-free (hashed lattice).
static func noise1(x: float, seed: int) -> float:
	var i := floori(x)
	var f := x - float(i)
	var a := h(i * 7919 + seed * 104729) * 2.0 - 1.0
	var b := h((i + 1) * 7919 + seed * 104729) * 2.0 - 1.0
	return lerpf(a, b, f * f * (3.0 - 2.0 * f))

## How far down a side of `rect` is open air (0 = covered by a neighbour
## right from the top). Returns the exposed depth below the top.
static func _exposed(rect: Rect2, left: bool) -> float:
	var edge_x := rect.position.x if left else rect.end.x
	var cover := rect.size.y
	for o in _all_ground():
		if o == rect:
			continue
		var touching := absf((o.end.x if left else o.position.x) - edge_x) <= 3.0
		var inside := o.position.x < edge_x - 2.0 and o.end.x > edge_x + 2.0
		if not (touching or inside):
			continue
		if o.end.y <= rect.position.y + 4.0 or o.position.y >= rect.end.y:
			continue
		cover = minf(cover, maxf(0.0, o.position.y - rect.position.y))
	return cover

## Horizontal offset of a side at depth d below the top (+ = outward).
static func _side(style: String, d: float, seed: int, depth: float) -> float:
	var lip := 0.0
	# Every material overhangs its top edge a little, then recedes.
	if d < 22.0:
		lip = 5.0
	else:
		lip = -minf(16.0, (d - 22.0) * 0.18)
	match style:
		"earth":
			return lip + noise1(d / 70.0, seed) * 9.0 + noise1(d / 23.0, seed + 3) * 3.5
		"strata":
			var band := floorf(d / 46.0)
			var step := (h(int(band) * 31 + seed) - 0.6) * 26.0
			var nxt := (h(int(band + 1.0) * 31 + seed) - 0.6) * 26.0
			var k := clampf((d - band * 46.0 - 38.0) / 8.0, 0.0, 1.0)
			return lip + lerpf(step, nxt, k) * clampf(d / 60.0, 0.0, 1.0)
		"jagged":
			var j := noise1(d / 44.0, seed) * 15.0 + (h(int(d / 17.0) + seed * 13) - 0.5) * 10.0
			return lip + j * clampf(d / 30.0, 0.3, 1.0)
		"comb":
			var c := absf(sin(d / 36.0 * PI))
			return lip * 0.5 - 6.0 + c * 12.0
		"masonry":
			return 0.0 if d > 4.0 else 2.0
	return lip

## The outline of a slab, clockwise from the top left. Exposed sides follow
## the material; covered sides are straight.
static func outline(rect: Rect2, style: String, seed: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x0 := rect.position.x
	var x1 := rect.end.x
	var y0 := rect.position.y
	var y1 := rect.end.y
	var depth := rect.size.y
	var open_l := _exposed(rect, true)
	var open_r := _exposed(rect, false)
	var thin := depth <= 60.0
	var step := 20.0 if style == "comb" else 24.0
	# Top edge (the walkable line) is straight.
	pts.append(Vector2(x0, y0))
	pts.append(Vector2(x1, y0))
	# Right side, down.
	var floating := depth <= 260.0
	var bottom_y := y1 if not thin else y0 + depth
	var d := step
	while d < depth - 1.0:
		var off := _side(style, d, seed * 2 + 1, depth) if d < open_r else 0.0
		pts.append(Vector2(x1 + off, y0 + d))
		d += step
	pts.append(Vector2(x1 + (_side(style, depth, seed * 2 + 1, depth) if depth < open_r else 0.0), bottom_y))
	# Underside: floating slabs hang a rocky keel; buried ones stay flat.
	if floating and style != "masonry":
		var w := rect.size.x
		var keel := minf(140.0, w * (0.42 if thin else 0.30))
		var n := maxi(4, int(w / 26.0))
		for i in range(1, n):
			var t := float(i) / float(n)
			var sag := pow(sin(t * PI), 0.75) * keel
			var jag := (h(i * 17 + seed * 5) - 0.5) * keel * 0.32
			if style == "comb":
				jag = absf(sin(t * PI * float(n) * 0.5)) * 14.0
			pts.append(Vector2(x1 - t * w, bottom_y + sag + jag))
	pts.append(Vector2(x0 + (_side(style, depth, seed * 2, depth) * -1.0 if depth < open_l else 0.0), bottom_y))
	# Left side, up.
	d = depth - fposmod(depth, step)
	if d >= depth - 1.0:
		d -= step
	while d > 0.0:
		var off := _side(style, d, seed * 2, depth) if d < open_l else 0.0
		pts.append(Vector2(x0 - off, y0 + d))
		d -= step
	return pts

static func _uvs(pts: PackedVector2Array, tile: float) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	uvs.resize(pts.size())
	for i in pts.size():
		uvs[i] = pts[i] / tile
	return uvs

## Paint one ground rectangle. Draw calls: the textured face, one batched
## mesh for every flat-coloured mark (shading, rims, strata, cracks, drips),
## the cap, and the sprites.
static func ground_on(ci: CanvasItem, rect: Rect2, skin: String, seed: int) -> void:
	if skin == "bone" and rect.size.y <= 60.0:
		bone_on(ci, [Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5),
			Vector2(rect.end.x, rect.position.y + rect.size.y * 0.5)], rect.size.y + 6.0, seed)
		return
	var look: Dictionary = LOOK.get(skin, LOOK["grass"])
	var style := String(look["style"])
	var pts := outline(rect, style, seed)
	if Geometry2D.triangulate_polygon(pts).is_empty():
		FinaleArt.slab_on(ci, rect, skin)
		return
	var tex := FinaleArt._load(look["tex"])
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(Color.WHITE)
	if tex != null:
		ci.draw_polygon(pts, cols, _uvs(pts, float(look["tile"])), tex)
	else:
		ci.draw_colored_polygon(pts, FinaleArt.SKINS[skin]["fill"])
	var b := TriBatch.new()
	_shade(b, pts, rect, look)
	_rim(b, pts, rect, look, style)
	_details(b, rect, skin, look, seed)
	b.flush(ci)
	FinaleArt.cap_on(ci, rect, skin)
	_vines(ci, rect, skin, seed)
	_props(ci, rect, skin, seed)

## Paint a group of slabs (one terrain chunk) with as few draw calls as
## possible: one mesh per face texture, one for every flat mark of every slab,
## one per cap texture, then the sprites.
static func ground_group(ci: CanvasItem, rects: Array, seeds: Array) -> void:
	var faces := {}
	var caps := {}
	var flat := TriBatch.new()
	for i in rects.size():
		var rect: Rect2 = rects[i]
		var seed: int = seeds[i]
		var skin := FinaleArt.skin_for(rect)
		if skin == "bone" and rect.size.y <= 60.0:
			bone_into(flat, [Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5),
				Vector2(rect.end.x, rect.position.y + rect.size.y * 0.5)], rect.size.y + 6.0, seed)
			continue
		var look: Dictionary = LOOK.get(skin, LOOK["grass"])
		var style := String(look["style"])
		var pts := outline(rect, style, seed)
		if Geometry2D.triangulate_polygon(pts).is_empty():
			pts = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		var tex_path := String(look["tex"])
		if not faces.has(tex_path):
			faces[tex_path] = TriBatch.new()
		(faces[tex_path] as TriBatch).poly_uv(pts, _uvs(pts, float(look["tile"])))
		_shade(flat, pts, rect, look)
		_rim(flat, pts, rect, look, style)
		_details(flat, rect, skin, look, seed)
		if skin != "bone":
			var s: Dictionary = FinaleArt.SKINS.get(skin, FinaleArt.SKINS["grass"])
			var cap_path := String(s["cap"])
			if cap_path != "":
				if not caps.has(cap_path):
					caps[cap_path] = TriBatch.new()
				FinaleArt._cap_strip(ci, s, [rect.position - Vector2(7, 0), Vector2(rect.end.x + 7.0, rect.position.y)], caps[cap_path])
	for path in faces:
		(faces[path] as TriBatch).flush(ci, FinaleArt._load(path))
	flat.flush(ci)
	for path in caps:
		(caps[path] as TriBatch).flush(ci, FinaleArt._load(path))
	for i in rects.size():
		var rect: Rect2 = rects[i]
		var skin := FinaleArt.skin_for(rect)
		_vines(ci, rect, skin, seeds[i])
		_props(ci, rect, skin, seeds[i])

## Darken with depth (vertex colours over the same outline).
static func _shade(b: TriBatch, pts: PackedVector2Array, rect: Rect2, look: Dictionary) -> void:
	var c: Color = look["shade"]
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in pts.size():
		var d := pts[i].y - rect.position.y
		var a := clampf((d - 30.0) / 520.0, 0.0, 1.0) * 0.55
		cols[i] = Color(c, a)
	b.poly_colors(pts, cols)

## Dark rim around the exposed outline, a lit inner edge on the left (light
## comes from the upper left), and a soft occlusion band inside the rim.
static func _rim(b: TriBatch, pts: PackedVector2Array, rect: Rect2, look: Dictionary, style: String) -> void:
	var open_l := _exposed(rect, true)
	var open_r := _exposed(rect, false)
	var line := PackedVector2Array()
	var runs: Array[PackedVector2Array] = []
	for i in range(1, pts.size()):
		var p := pts[i]
		var d := p.y - rect.position.y
		var on_left := p.x < rect.position.x + rect.size.x * 0.5
		var exposed := (d <= open_l + 1.0) if on_left else (d <= open_r + 1.0)
		var underside := p.y > rect.end.y - 1.0 and rect.size.y <= 260.0
		if exposed or underside:
			line.append(p)
		elif line.size() > 1:
			runs.append(line)
			line = PackedVector2Array()
		else:
			line = PackedVector2Array()
	# Close back to the top-left corner when the left side is exposed.
	if open_l > 2.0:
		line.append(pts[0])
	if line.size() > 1:
		runs.append(line)
	var rim: Color = look["rim"]
	for run in runs:
		b.polyline(run, 22.0, Color(0, 0, 0, 0.16), false)
	for run in runs:
		b.polyline(run, 5.0, rim)
	# Lit edge: the left side just inside the rim, fading with depth.
	if open_l > 30.0 and style != "masonry":
		var lit := PackedVector2Array()
		for i in range(pts.size() - 1, 0, -1):
			var p := pts[i]
			if p.x < rect.position.x + rect.size.x * 0.5 and p.y - rect.position.y < minf(open_l, 260.0) and p.y < rect.end.y - 2.0:
				lit.append(p + Vector2(7, 0))
		if lit.size() > 1:
			b.polyline(lit, 5.0, look["lit"])

## Vines and roots over exposed cliff lips (sprites, after the batch).
static func _vines(ci: CanvasItem, rect: Rect2, skin: String, seed: int) -> void:
	if not (skin == "grass" or skin == "cliff") or rect.size.x < 40.0:
		return
	for left in [true, false]:
		if _exposed(rect, left) < 140.0:
			continue
		var n := 1
		for i in n:
			var key := "vine_%s" % ["a", "b", "c"][int(h(seed * 3 + i + (7 if left else 0)) * 3.0) % 3]
			var x := (rect.position.x + 14.0 + float(i) * 34.0) if left else (rect.end.x - 14.0 - float(i) * 34.0)
			var vh := 130.0 + h(seed * 7 + i) * 110.0
			FinaleArt.sprite(ci, key, Vector2(x, rect.position.y + 10.0 + vh), vh, not left)

## Material marks inside the face: strata lines, glowing cracks, honey.
static func _details(b: TriBatch, rect: Rect2, skin: String, look: Dictionary, seed: int) -> void:
	var x0 := rect.position.x + 20.0
	var x1 := rect.end.x - 20.0
	if x1 - x0 < 40.0:
		return
	match skin:
		"grass", "sand", "cliff":
			# Sediment bands across the face.
			var bands := mini(5, int(minf(rect.size.y, 700.0) / 120.0))
			for k in bands:
				var y := rect.position.y + 90.0 + float(k) * 120.0 + h(seed * 7 + k) * 40.0
				var line := PackedVector2Array()
				var n := maxi(2, int((x1 - x0) / 40.0))
				for i in n + 1:
					var x := lerpf(x0, x1, float(i) / float(n))
					line.append(Vector2(x, y + noise1(x / 90.0, seed + k * 3) * 10.0))
				b.polyline(line, 4.0, Color(look["shade"], 0.28), false)
				b.polyline(_shift(line, Vector2(0, 5)), 3.0, Color(1, 0.95, 0.85, 0.10), false)
		"lava":
			# Glowing fissures running down from the top.
			var n := maxi(1, int((x1 - x0) / 160.0))
			for i in n:
				var x := lerpf(x0, x1, (float(i) + 0.3 + h(seed * 3 + i) * 0.4) / float(n))
				var crack := PackedVector2Array([Vector2(x, rect.position.y + 30.0)])
				var y := rect.position.y + 30.0
				for k in 5:
					y += 30.0 + h(seed + i * 11 + k) * 40.0
					x += (h(seed * 5 + i * 7 + k) - 0.5) * 40.0
					crack.append(Vector2(x, minf(y, rect.end.y - 10.0)))
				b.polyline(crack, 9.0, Color(1.0, 0.35, 0.05, 0.35))
				b.polyline(crack, 3.0, Color(1.0, 0.75, 0.25), false)
		"hive":
			# Honey seeping over the lip in drips.
			var n := maxi(1, int((x1 - x0) / 110.0))
			for i in n:
				var x := lerpf(x0, x1, (float(i) + 0.5) / float(n)) + (h(seed * 9 + i) - 0.5) * 50.0
				var len := 26.0 + h(seed * 13 + i) * 60.0
				honey_drip_into(b, Vector2(x, rect.position.y + 6.0), len, 9.0 + h(i + seed) * 6.0)

static func _shift(line: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array(line)
	for i in out.size():
		out[i] += by
	return out

## A glossy drip of honey hanging from `top`.
static func honey_drip(ci: CanvasItem, top: Vector2, length: float, width: float) -> void:
	var b := TriBatch.new()
	honey_drip_into(b, top, length, width)
	b.flush(ci)

static func honey_drip_into(b: TriBatch, top: Vector2, length: float, width: float) -> void:
	var c := Color("e88a00")
	var poly := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		poly.append(top + Vector2(-width * (1.0 - t * 0.55), t * length))
	for i in range(8, -1, -1):
		var t := float(i) / 8.0
		poly.append(top + Vector2(width * (1.0 - t * 0.55), t * length))
	b.poly(poly, c)
	b.circle(top + Vector2(0, length), width * 0.85, c)
	b.circle(top + Vector2(-width * 0.25, length - width * 0.2), width * 0.3, Color(1, 0.95, 0.7, 0.8), 8)
	b.line(top + Vector2(-width * 0.45, 2), top + Vector2(-width * 0.3, length * 0.7), 2.5, Color(1, 0.9, 0.5, 0.6))

## Small set dressing on a slab's top, never on the walk line's edges.
static func _props(ci: CanvasItem, rect: Rect2, skin: String, seed: int) -> void:
	if rect.size.x < 180.0 or rect.size.y <= 40.0:
		return
	var kinds: Array = []
	match skin:
		"grass":
			kinds = [["tuft", 34.0], ["bush", 46.0], ["tuft", 30.0], ["rock_mossy", 40.0]]
		"cliff":
			kinds = [["tuft", 30.0], ["desert_grass", 34.0]]
		"sand":
			kinds = [["desert_grass", 30.0], ["rocks", 28.0]]
		_:
			return
	var n := int(rect.size.x / 230.0)
	for i in n:
		if h(seed * 41 + i) < 0.35:
			continue
		var x := rect.position.x + 50.0 + (rect.size.x - 100.0) * (float(i) + h(seed * 17 + i)) / float(maxi(1, n))
		var kind: Array = kinds[int(h(seed * 23 + i) * kinds.size()) % kinds.size()]
		FinaleArt.sprite(ci, String(kind[0]), Vector2(x, rect.position.y + 4.0), float(kind[1]) * (0.85 + h(i + seed) * 0.4),
			h(seed + i * 3) < 0.5)

## A fossil bone laid along `path` (world points): a thick ivory shaft with
## a dark rim, a lit ridge, joint knuckles at each point and knobbed ends.
## One draw call (TriBatch).
static func bone_on(ci: CanvasItem, path: Array, thick: float, seed: int) -> void:
	var b := TriBatch.new()
	bone_into(b, path, thick, seed)
	b.flush(ci)

static func bone_into(b: TriBatch, path: Array, thick: float, seed: int) -> void:
	var line := PackedVector2Array(path)
	var w := thick
	var ends := []
	for p in [line[0], line[-1]]:
		var dir := (line[1] - line[0]).normalized() if p == line[0] else (line[-1] - line[-2]).normalized()
		ends.append([p, Vector2(-dir.y, dir.x)])
	b.polyline(line, w + 8.0, BONE_RIM)
	for e in ends:
		for s in [-1.0, 1.0]:
			b.circle(e[0] + e[1] * s * w * 0.42, w * 0.55 + 4.0, BONE_RIM)
	b.polyline(line, w, BONE_SHADE)
	b.polyline(_shift(line, Vector2(0, -w * 0.16)), w * 0.66, BONE)
	b.polyline(_shift(line, Vector2(0, -w * 0.3)), maxf(2.0, w * 0.14), Color(1, 1, 0.96, 0.85))
	for e in ends:
		for s in [-1.0, 1.0]:
			b.circle(e[0] + e[1] * s * w * 0.42, w * 0.55, BONE_SHADE)
			b.circle(e[0] + e[1] * s * w * 0.42 + Vector2(-2, -3), w * 0.38, BONE)
	# Vertebra joints along the shaft.
	var total := 0.0
	for i in range(1, line.size()):
		total += line[i].distance_to(line[i - 1])
	var spacing := 70.0 if total < 900.0 else 130.0
	var walked := 0.0
	var next := spacing * (0.6 + h(seed) * 0.4)
	for i in range(1, line.size()):
		var a := line[i - 1]
		var c := line[i]
		var seg := a.distance_to(c)
		while walked + seg >= next and next < total - spacing * 0.5:
			var p := a.lerp(c, (next - walked) / maxf(seg, 0.001))
			var dir := (c - a).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			b.line(p + nrm * w * 0.5, p - nrm * w * 0.5, 3.0, Color(BONE_RIM, 0.55))
			b.circle(p - nrm * w * 0.52, w * 0.2, BONE_SHADE, 8)
			next += spacing
		walked += seg
