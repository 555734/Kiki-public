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

func _ready() -> void:
	z_index = 2
	# Required for draw_texture_rect(..., tile=true) to actually repeat.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _draw() -> void:
	for i in slabs.size():
		_draw_slab(slabs[i], i)

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
