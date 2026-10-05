extends Node2D
## Draws the ground: grass-capped dirt with wavy strata, matching the mockups.
##
## There is no TileSet and no texture. The slabs come from the level data as
## rectangles and are drawn directly, which means no image assets, one draw pass,
## and a level whose geometry can be edited as numbers. Godot caches the result
## of _draw() until queue_redraw(), so this static geometry costs nothing per
## frame no matter how long the stage is.

const GRASS_CAP := 26.0
const BUMP := 22.0

var slabs: Array[Rect2] = []
var _cave_chunks: Array[Node2D] = []
## Each slab is drawn by a child of its own (this script, `is_chunk`), so the
## renderer can cull the ones off screen. One CanvasItem spanning the whole
## stage cannot be culled at all: 1-7's 14,000px tower drew every brick of
## every floor every frame (1,203 draw calls). Callers that assign `slabs`
## directly (the versus arena, the 3D view) still get one node that draws all.
var is_chunk: bool = false
var seed_base: int = 0
var _chunks: Array[Node2D] = []
const CaveSlabScript = preload("res://src/render/cave_slab.gd")

func _ready() -> void:
	# A chunk's z is relative to the terrain it belongs to.
	if not is_chunk:
		z_index = 2
	# Required for draw_texture_rect(..., tile=true) to actually repeat.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _draw() -> void:
	# One CanvasItem spanning the whole 24,000 px cave prevents the renderer
	# from rejecting off-screen ground. Each cave slab has its own bounds below.
	if Stage.is_cave() or not _chunks.is_empty():
		return
	for i in slabs.size():
		_draw_slab(slabs[i], seed_base + i)

func set_slabs(next_slabs: Array[Rect2]) -> void:
	slabs = next_slabs
	if Stage.is_cave():
		for chunk in _cave_chunks:
			remove_child(chunk)
			chunk.queue_free()
		_cave_chunks.clear()
		for i in slabs.size():
			var chunk = CaveSlabScript.new()
			chunk.position = slabs[i].position
			chunk.span = slabs[i].size
			chunk.seed_index = i
			add_child(chunk)
			_cave_chunks.append(chunk)
	else:
		for chunk in _chunks:
			remove_child(chunk)
			chunk.queue_free()
		_chunks.clear()
		for i in slabs.size():
			var chunk: Node2D = get_script().new()
			chunk.is_chunk = true
			chunk.seed_base = i
			chunk.slabs = [slabs[i]] as Array[Rect2]
			add_child(chunk)
			_chunks.append(chunk)
		queue_redraw()

## The colours a slab is painted in when there is no texture for it.
##
## One dictionary rather than four constants because 1-S needs a different set
## and nothing else does: floating rock above a cloud sea cannot be meadow green
## over warm dirt. When the painted island tiles arrive this stops being used at
## all -- _draw_painted_slab returns first.
func _palette() -> Dictionary:
	if Stage.is_sky():
		return {
			"body": Balance.C_SKY_STONE,
			"dark": Balance.C_SKY_STONE_DARK,
			"light": Balance.C_SKY_STONE_LIGHT,
			"cap": Balance.C_SKY_MOSS,
			"cap_dark": Balance.C_SKY_MOSS_DARK,
		}
	return {
		"body": Balance.C_DIRT,
		"dark": Balance.C_DIRT_DARK,
		"light": Balance.C_DIRT_LIGHT,
		"cap": Balance.C_GRASS,
		"cap_dark": Balance.C_GRASS_DARK,
	}

func _draw_slab(rect: Rect2, seed_index: int) -> void:
	if Stage.is_tower():
		_draw_tower_slab(rect, seed_index)
		return
	if Stage.is_desert():
		_draw_desert_slab(rect, seed_index)
		return
	if Stage.is_swamp():
		_draw_swamp_slab(rect, seed_index)
		return
	if Balance.USE_TEXTURES and _draw_painted_slab(rect):
		return
	var pal := _palette()

	# Dirt body
	draw_rect(rect, pal["body"])

	# Wavy strata. Amplitude and offset are hashed off the slab index so the
	# bands differ between slabs but never change between frames or runs.
	var bands := 4
	for b in range(bands):
		var t := (float(b) + 0.85) / float(bands + 1)
		var y := rect.position.y + GRASS_CAP + (rect.size.y - GRASS_CAP) * t
		var amp := 4.0 + DrawUtil.hash01(seed_index * 31 + b) * 7.0
		var freq := 0.010 + DrawUtil.hash01(seed_index * 17 + b) * 0.006
		var phase := DrawUtil.hash01(seed_index * 7 + b) * TAU
		var thickness := 7.0 + DrawUtil.hash01(seed_index + b * 13) * 9.0
		var col: Color = pal["dark"] if b % 2 == 0 else pal["light"]
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		var steps := maxi(2, int(rect.size.x / 26.0))
		for s in range(steps + 1):
			var x := rect.position.x + rect.size.x * float(s) / float(steps)
			var wave := sin(x * freq + phase) * amp
			top.append(Vector2(x, y + wave))
			bottom.append(Vector2(x, y + wave + thickness))
		bottom.reverse()
		var poly := PackedVector2Array(top)
		poly.append_array(bottom)
		draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.55))

	# Darker skirt at the very bottom so tall slabs do not read as flat.
	draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - 26.0, rect.size.x, 26.0),
		Color(pal["dark"], 0.5))

	# Vertical edge shading
	draw_rect(Rect2(rect.position.x, rect.position.y, 7.0, rect.size.y),
		Color(0, 0, 0, 0.10))
	draw_rect(Rect2(rect.position.x + rect.size.x - 7.0, rect.position.y, 7.0, rect.size.y),
		Color(0, 0, 0, 0.10))

	# Grass: a solid cap plus a scalloped lip that overhangs the dirt.
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, GRASS_CAP), pal["cap"])
	draw_rect(Rect2(rect.position.x, rect.position.y + GRASS_CAP - 5.0, rect.size.x, 5.0),
		pal["cap_dark"])

	var count := maxi(1, int(round(rect.size.x / BUMP)))
	var step := rect.size.x / float(count)
	for s in range(count):
		var cx := rect.position.x + step * (float(s) + 0.5)
		draw_circle(Vector2(cx, rect.position.y + 2.0), step * 0.56, pal["cap"])
	# Highlight along the top of the lip
	for s in range(count):
		var cx := rect.position.x + step * (float(s) + 0.5)
		draw_arc(Vector2(cx, rect.position.y + 2.0), step * 0.56, PI * 1.15, PI * 1.85, 8,
			Color(1, 1, 1, 0.22), 3.0, true)

## Broad sandstone shapes from the approved cartoon board. The safe top is
## exactly rect.position.y; decoration below it never changes collision.
func _draw_desert_slab(rect: Rect2, seed_index: int) -> void:
	# Reuse the coast's painted sand grain so 1-6 shares its material language.
	# The darker tint and broad seams make this sandstone rather than beach sand.
	if not (Balance.USE_TEXTURES and Art.draw_tiled(self, "sea_sand_tile", rect,
			128.0, Color("dbaa84"))):
		draw_rect(rect, Color("c8793b"))
	draw_rect(rect, Color("a75f36", 0.17))
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 25), Color("ffd06b"))
	draw_rect(Rect2(rect.position.x, rect.position.y + 25, rect.size.x, 7), Color("a95e32"))
	var first := int(floorf(rect.position.x / 105.0))
	var last := int(ceilf(rect.end.x / 105.0))
	for n in range(first, last):
		var x := float(n) * 105.0
		if x < rect.position.x + 8.0 or x > rect.end.x - 30.0:
			continue
		var y := rect.position.y + 80.0 + float(posmod(n + seed_index, 3)) * 76.0
		if y + 25.0 < rect.end.y:
			draw_rect(Rect2(x, y, 56, 8), Color("eaa45b", 0.65))
			draw_rect(Rect2(x + 26, y + 8, 6, 17), Color("a75d34", 0.65))
	draw_rect(Rect2(rect.position.x, rect.position.y + 34, 7, rect.size.y - 34),
		Color("9f5c34", 0.55))
	draw_rect(Rect2(rect.end.x - 7, rect.position.y + 34, 7, rect.size.y - 34),
		Color("9f5c34", 0.55))

func _draw_tower_slab(rect: Rect2, seed_index: int) -> void:
	# Stone courses are sized in world pixels, not stretched from one texture.
	# The cap's top edge is exactly the collision top.
	draw_rect(rect, Color("9c8468"))
	# Every brick, then every mortar line: alternating the two per brick broke
	# the canvas batch on each one. The lines sit inside their own brick, so
	# the order does not change the picture.
	var mortar := PackedVector2Array()
	var rows := maxi(1, int(ceilf(rect.size.y / 48.0)))
	for row in rows:
		var y := rect.position.y + float(row) * 48.0
		var h := minf(47.0, rect.end.y - y)
		if h <= 0.0:
			continue
		var offset := 0.0 if row % 2 == 0 else 38.0
		var left := int(floorf((rect.position.x - offset) / 76.0))
		var right := int(ceilf((rect.end.x - offset) / 76.0))
		for n in range(left, right):
			var x := maxf(rect.position.x, float(n) * 76.0 + offset)
			var end_x := minf(rect.end.x, float(n + 1) * 76.0 + offset - 2.0)
			if end_x <= x:
				continue
			var tint := Color("d0b996") if (n + row + seed_index) % 3 == 0 \
				else Color("bfa582")
			draw_rect(Rect2(x, y, end_x - x, h), tint)
			mortar.append(Vector2(x + 4, y + h - 4))
			mortar.append(Vector2(end_x - 4, y + h - 4))
	if not mortar.is_empty():
		draw_multiline(mortar, Color("75634f", 0.35), 2.0)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 12),
		Color("ead6b2"))
	draw_rect(Rect2(rect.position.x, rect.position.y + 12, rect.size.x, 5),
		Color("8b7358"))
	draw_rect(Rect2(rect.position.x, rect.position.y, 6, rect.size.y),
		Color("777168", 0.35))
	draw_rect(Rect2(rect.end.x - 6, rect.position.y, 6, rect.size.y),
		Color("eee4cf", 0.35))

## The swamp has chunky moss and layered stone/peat, aligned to the same safe
## collision ledge. The details repeat in world coordinates so wide banks never
## stretch a single painted block across several screens.
func _draw_swamp_slab(rect: Rect2, seed_index: int) -> void:
	draw_rect(rect, Color("604b3d"))
	if Balance.USE_TEXTURES and Art.draw_tiled(self, "sky_island_tile", rect,
			180.0, Color("b39770")):
		draw_rect(rect, Color(0.30, 0.19, 0.10, 0.24))
	else:
		draw_rect(Rect2(rect.position.x, rect.position.y + 34.0,
			rect.size.x, rect.size.y - 34.0), Color("514136"))
	# Sparse dark fractures keep the rock legible where it disappears under
	# the poison, without stretching one facet across an entire bank.
	var left := int(floorf(rect.position.x / 76.0))
	var right := int(ceilf(rect.end.x / 76.0))
	for n in range(left, right):
		var x := float(n) * 76.0 + DrawUtil.hash01(n * 17 + seed_index) * 18.0
		var y := rect.position.y + 72.0 + float(posmod(n, 3)) * 60.0
		if y + 28.0 < rect.end.y:
			draw_line(Vector2(x, y), Vector2(x + 28.0, y + 8.0),
				Color(0.19, 0.16, 0.13, 0.30), 2.0)
	# Raised, rounded moss cap; short hanging strands mark the safe top edge.
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 32.0), Color("54852a"))
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 13.0), Color("a6d941"))
	# Drawn kind by kind -- every tuft, then every strand, then every glint --
	# so each kind batches. A strand or glint never overlaps a neighbour's tuft,
	# so the picture is the same as drawing them tuft by tuft.
	var tufts: Array[float] = []
	for n in range(int(floorf(rect.position.x / 30.0)),
			int(ceilf(rect.end.x / 30.0))):
		var x := float(n) * 30.0 + 15.0
		if x < rect.position.x or x > rect.end.x:
			continue
		tufts.append(x)
		draw_circle(Vector2(x, rect.position.y + 20.0), 17.0, Color("6eab28"))
	for x in tufts:
		var h := 18.0 + DrawUtil.hash01(int(roundf((x - 15.0) / 30.0)) * 19 + 7) * 18.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 8.0, rect.position.y + 23.0),
			Vector2(x + 9.0, rect.position.y + 23.0),
			Vector2(x + 2.0, rect.position.y + 23.0 + h)]), Color("559326"))
	var glints := PackedVector2Array()
	for x in tufts:
		glints.append(Vector2(x - 9.0, rect.position.y + 3.0))
		glints.append(Vector2(x + 5.0, rect.position.y + 3.0))
	if not glints.is_empty():
		draw_multiline(glints, Color("c6ee60"), 2.0)
	if Balance.USE_TEXTURES:
		Art.draw_tiled(self, "sky_island_cap", Rect2(rect.position.x,
			rect.position.y - 16.0, rect.size.x, 46.0), 46.0,
			Color("a0ec61"))
	draw_rect(Rect2(rect.position.x, rect.position.y, 7.0, rect.size.y),
		Color(0, 0, 0, 0.12))
	draw_rect(Rect2(rect.end.x - 7.0, rect.position.y, 7.0, rect.size.y),
		Color(0, 0, 0, 0.12))

## 1-4's sand and grass are painted larger than 1-1's turf: its pebbles and
## blades would be specks at the 1-1 tile size.
func _dirt_h() -> float:
	return 128.0 if Stage.is_sea() else Balance.DIRT_TILE_H

func _grass_h() -> float:
	return 58.0 if Stage.is_sea() else Balance.GRASS_TILE_H

## Painted terrain: seamless dirt over the slab, the grass lip tiled along its
## top edge, and a little contact shading down the sides so neighbouring slabs
## do not read as one continuous wall.
func _draw_painted_slab(rect: Rect2) -> bool:
	if not Art.draw_tiled(self, "dirt_tile", rect, _dirt_h()):
		return false
	# Ambient occlusion into the ground: darkens with depth, so tall slabs get
	# heavier toward the bottom of the screen the way the mockups do.
	draw_rect(rect, Color(0.16, 0.08, 0.03, 0.0))
	# Measured up from the BOTTOM of the slab, not as a fraction of its height.
	# Every slab is drawn down to the same base line, so measuring from there
	# makes the bands land on the same world rows for all of them; as a fraction
	# they landed wherever each slab's own top happened to put them, and two
	# ledges at different heights met in a hard step -- a dark rectangle a few
	# hundred pixels wide with nothing in the level to explain it.
	for band in range(2):
		var from_bottom := 320.0 - float(band) * 140.0
		var y := rect.position.y + rect.size.y - from_bottom
		if y <= rect.position.y + GRASS_CAP:
			continue
		draw_rect(Rect2(rect.position.x, y, rect.size.x, from_bottom),
			Color(0.20, 0.10, 0.04, 0.09))
	# Vertical edges
	draw_rect(Rect2(rect.position.x, rect.position.y, 9.0, rect.size.y), Color(0, 0, 0, 0.09))
	draw_rect(Rect2(rect.position.x + rect.size.x - 9.0, rect.position.y, 9.0, rect.size.y),
		Color(0, 0, 0, 0.09))
	# Lifted by GRASS_LIP so the solid part of the tile lands on the collision
	# surface and the feathered tips overhang it. The band keeps its height --
	# growing it instead would make draw_tiled repeat vertically and put a second
	# row of blade tips halfway down the slab.
	Art.draw_tiled(self, "grass_tile",
		Rect2(rect.position.x, rect.position.y - _grass_h() * 0.25,
			rect.size.x, _grass_h()),
		_grass_h())
	return true
