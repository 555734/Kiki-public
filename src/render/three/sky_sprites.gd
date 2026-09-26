class_name SkySprites
extends RefCounted
## Stage 1-3's painted look inside the 3D world.
##
## Every other stage is built from vertex-coloured recipes (assets.gd). 1-3
## instead places the owner's painted pieces (assets/stage_1_3/sprites, cut by
## tools/extract-stage-1-3.py) on flat quads in the same 3D scene, so they sit
## at real depths, scroll with the pitched camera and stay pixel-aligned with
## the 2D colliders. Model space is pixels with +y up, like the recipes.
const DIR := "res://assets/stage_1_3/sprites/"

static var _materials: Dictionary = {}
static var _textures: Dictionary = {}
static var _meshes: Dictionary = {}

static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := DIR + name + ".png"
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]

static func size_of(name: String) -> Vector2:
	var t := texture(name)
	return t.get_size() if t != null else Vector2(64, 64)

## One material per texture and tint, shared by every quad that uses it: the
## whole stage is a few dozen materials however many islands it has.
static func material(name: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "%s:%s" % [name, tint.to_html()]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.albedo_texture = texture(name)
	m.albedo_color = tint
	_materials[key] = m
	return m

## Collects quads and emits one surface per texture.
class Builder:
	var _parts: Dictionary = {}

	## rect is in model pixels with +y up; uv is a 0..1 sub-rectangle of the
	## texture (y down, as images are stored).
	func quad(name: String, rect: Rect2, z: float,
			uv: Rect2 = Rect2(0, 0, 1, 1), tint: Color = Color.WHITE) -> void:
		var key := "%s|%s" % [name, tint.to_html()]
		if not _parts.has(key):
			_parts[key] = {"name": name, "tint": tint, "v": PackedVector3Array(),
				"uv": PackedVector2Array(), "n": PackedVector3Array()}
		var p: Dictionary = _parts[key]
		var x0 := rect.position.x
		var x1 := rect.end.x
		var y0 := rect.position.y
		var y1 := rect.end.y
		var u0 := uv.position.x
		var u1 := uv.end.x
		var v0 := uv.position.y
		var v1 := uv.end.y
		var corners := [Vector3(x0, y1, z), Vector3(x1, y1, z), Vector3(x1, y0, z),
			Vector3(x0, y1, z), Vector3(x1, y0, z), Vector3(x0, y0, z)]
		var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1),
			Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1)]
		for i in 6:
			p.v.append(corners[i])
			p.uv.append(uvs[i])
			p.n.append(Vector3(0, 0, 1))

	## A sprite at its own aspect: `height` pixels tall, anchored at `foot`
	## (bottom centre) unless `centred`.
	func sprite(name: String, foot: Vector2, height: float, z: float,
			flip: bool = false, centred: bool = false, tint: Color = Color.WHITE) -> void:
		var s := SkySprites.size_of(name)
		var w := height * s.x / maxf(1.0, s.y)
		var origin := foot - Vector2(w * 0.5, height * 0.5 if centred else 0.0)
		var uv := Rect2(1, 0, -1, 1) if flip else Rect2(0, 0, 1, 1)
		quad(name, Rect2(origin, Vector2(w, height)), z, uv, tint)

	func mesh() -> ArrayMesh:
		var out := ArrayMesh.new()
		for key in _parts:
			var p: Dictionary = _parts[key]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = p.v
			arrays[Mesh.ARRAY_NORMAL] = p.n
			arrays[Mesh.ARRAY_TEX_UV] = p.uv
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1,
				SkySprites.material(p.name, p.tint))
		return out

static func _node(mesh: ArrayMesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

# ---------------------------------------------------------------- terrain

## A floating island over a ground() rectangle whose walkable top is y=0.
## The painted island is sliced into a left cap, a repeating middle and a right
## cap, so a 300px ledge and a 1240px summit both keep their grass unstretched.
static func terrain(size: Vector2) -> ArrayMesh:
	var b := Builder.new()
	var tex := size_of("island_float")
	var scale := 1.15
	var h := tex.y * scale
	# The grass crown in the painting starts a few pixels below its top edge;
	# lift it so the lip of grass sits exactly on the collider's top.
	var top := 10.0
	var cap_u := 0.22
	var cap_w := tex.x * cap_u * scale
	var mid_u := 1.0 - cap_u * 2.0
	var mid_w := tex.x * mid_u * scale
	var inner := maxf(0.0, size.x - cap_w * 2.0)
	var count := maxi(1, int(round(inner / mid_w)))
	var step := inner / float(count)
	b.quad("island_float", Rect2(0, top - h, cap_w, h), 2, Rect2(0, 0, cap_u, 1))
	for i in count:
		# Alternate mirrored middles so a long ledge does not read as a stamp.
		var uv := Rect2(cap_u, 0, mid_u, 1) if i % 2 == 0 \
			else Rect2(1.0 - cap_u, 0, -mid_u, 1)
		b.quad("island_float", Rect2(cap_w + step * i, top - h, step + 0.5, h), 2, uv)
	b.quad("island_float", Rect2(size.x - cap_w, top - h, cap_w, h), 2,
		Rect2(1.0 - cap_u, 0, cap_u, 1))
	# Hanging rock and vines behind, deterministic from the width.
	var salt := int(size.x) * 7 + int(size.y) * 13
	var n := maxi(1, int(size.x / 260.0))
	for i in n:
		var x := size.x * (float(i) + 0.5) / float(n)
		var pick := (salt + i * 5) % 3
		var cliff := "cliff_a" if pick == 0 else ("cliff_b" if pick == 1 else "rock_island")
		b.sprite(cliff, Vector2(x, -h * 0.55), h * 0.95, -14, i % 2 == 1)
		if (salt + i) % 2 == 0:
			b.sprite(["vine_a", "vine_b", "vine_c"][(salt + i) % 3],
				Vector2(x + 40.0, -h * 0.35 - 110.0), 110.0, 4)
	return b.mesh()

# ---------------------------------------------------------------- decor

const DECOR := {
	"tree": ["tree_big", 1.0], "tree_tall": ["tree_tall", 1.0],
	"arch": ["arch", 1.0], "ruin_column": ["pillar_vine", 1.0],
	"pillar": ["pillar", 1.0], "pillar_broken": ["pillar_broken", 1.0],
	"ruin_pile": ["ruin_pile", 1.0], "ruin_stairs": ["ruin_stairs", 1.0],
	"bush": ["bush", 1.0], "flowers": ["bush_flower", 1.0],
	"rock": ["rock_mossy", 1.0], "sign": ["sign_arrow", 1.0],
	"grass": ["grass_a", 1.0], "stone_wall": ["stone_wall", 1.0],
	"ruin_tower": ["bg_island_ruins", 1.0],
}

## Decor entries keep their data meaning: pos is the foot, size.y the height.
static func decor(kind: String, size: Vector2) -> MeshInstance3D:
	var key := "decor:%s:%s" % [kind, size]
	if not _meshes.has(key):
		var b := Builder.new()
		match kind:
			"waterfall":
				# pos is where the water leaves the island; it falls downward.
				# A stretched body, then the painted foam at the bottom, so the
				# splash stays a splash however long the drop is.
				var foam_h := size.x * 0.55
				var body := maxf(0.0, size.y - foam_h)
				b.quad("waterfall_wide", Rect2(-size.x * 0.5, -body, size.x, body), -20,
					Rect2(0, 0.05, 1, 0.45), Color(1, 1, 1, 0.9))
				b.quad("waterfall_wide", Rect2(-size.x * 0.5, -size.y, size.x, foam_h), -19,
					Rect2(0, 0.62, 1, 0.38))
			"cloud_bank":
				var names := ["bg_cloud_bank_a", "bg_cloud_bank_b", "bg_cloud_long"]
				var n := maxi(1, int(size.x / 420.0))
				for i in n:
					var x := -size.x * 0.5 + size.x * (float(i) + 0.5) / float(n)
					b.sprite(names[i % names.size()], Vector2(x, float(i % 2) * 30.0),
						size.y * (0.8 + float(i % 3) * 0.15), -60 - i * 3)
			"keel":
				b.sprite("island_float", Vector2(0, -size.y * 0.35), size.y, -30)
			"vines":
				b.sprite("vine_b", Vector2(0, -size.y), size.y, 3)
			_:
				if not DECOR.has(kind):
					return null
				var entry: Array = DECOR[kind]
				b.sprite(entry[0], Vector2.ZERO, size.y * float(entry[1]), -26)
		_meshes[key] = b.mesh()
	return _node(_meshes[key])

# ---------------------------------------------------------------- objects

## The painted piece for a gameplay object, centred on its node like the
## recipe it replaces. Returns null for kinds this stage leaves to assets.gd.
static func object(kind: String, size: Vector2) -> MeshInstance3D:
	var key := "obj:%s:%s" % [kind, size]
	if _meshes.has(key):
		return _node(_meshes[key])
	var b := Builder.new()
	match kind:
		"coin":
			b.sprite("coin_0", Vector2.ZERO, size.y * 1.35, 0, false, true)
		"crystal":
			b.sprite("crystal", Vector2.ZERO, 40.0, 0, false, true)
		"goal":
			b.sprite("goal_gate", Vector2(0, -95), 230.0, -6)
		"checkpoint":
			b.sprite("flag_blue", Vector2(0, -75), 150.0, -4)
		"spring":
			b.sprite("spring_low", Vector2.ZERO, size.y + 14.0, -2)
		"switch":
			b.sprite("switch_blue", Vector2.ZERO, 46.0, 0, false, true)
		"hazard":
			_tile(b, "spike_row", size, 0)
		"platform":
			_tile(b, "plate_grey", size, 0)
		"crumbling":
			# The painted bridge has its rails above the deck: hang it so the
			# deck (about two thirds down the picture) is the collider's top.
			var bh := size.y * 1.8
			var bw := bh * size_of("bridge_whole").x / maxf(1.0, size_of("bridge_whole").y)
			var bn := maxi(1, int(round(size.x / bw)))
			for i in bn:
				b.quad("bridge_whole", Rect2(-size.x * 0.5 + size.x / bn * i,
					size.y * 0.5 - bh * 0.68, size.x / bn + 0.5, bh), 0)
		"gate":
			b.quad("stone_vine", Rect2(-size.x * 0.5 - 8, -size.y * 0.5, size.x + 16, size.y), 2)
		"projectile":
			b.sprite("wind_shot", Vector2.ZERO, 30.0, 0, false, true)
		"blink_blue", "blink_purple":
			_tile(b, kind, size, 0)
		"conveyor":
			_tile(b, "conveyor", size, 0)
		"warp_in":
			b.sprite("portal_blue", Vector2(0, -size.y * 0.5), size.y * 1.15, -4)
		"warp_out":
			b.sprite("portal_gold", Vector2(0, -size.y * 0.5), size.y * 1.15, -4)
		_:
			return null
	_meshes[key] = b.mesh()
	return _node(_meshes[key])

## Repeats a horizontal piece across `size` (centred) at the piece's own
## aspect, optionally hanging `drop` times the span's height below the
## collider (rope bridges sag under their deck).
static func _tile(b: Builder, name: String, size: Vector2, z: float,
		drop: float = 0.0) -> void:
	var s := size_of(name)
	var h := size.y * (1.0 + drop)
	var piece := h * s.x / maxf(1.0, s.y)
	var count := maxi(1, int(round(size.x / piece)))
	var w := size.x / float(count)
	for i in count:
		b.quad(name, Rect2(-size.x * 0.5 + w * i, size.y * 0.5 - h, w + 0.5, h), z)

# ---------------------------------------------------------------- enemies

const ENEMY_FRAMES := {
	"sky_predator": ["predator_0", "predator_1", "predator_2", "predator_4"],
	"flyer": ["bird_0", "bird_1", "bird_2", "bird_3"],
	"turret": ["turret_0", "turret_1"],
	"mine": ["mine_0", "mine_1"],
	"seedling": ["seed_0", "seed_1", "seed_2", "seed_3"],
	"golem": ["golem_0", "golem_1", "golem_2", "golem_1"],
}
## Painted art is drawn larger than the collider it stands for.
const ENEMY_SCALE := {
	"sky_predator": 1.35, "flyer": 1.7, "turret": 1.6, "mine": 1.6,
	"seedling": 1.7, "golem": 1.45,
}

static func has_enemy(kind: String) -> bool:
	return ENEMY_FRAMES.has(kind)

## A single centred quad; animation swaps its material between frames.
static func enemy_quad(kind: String, size: Vector2) -> MeshInstance3D:
	var first: String = ENEMY_FRAMES[kind][0]
	var s := size_of(first)
	var h := maxf(size.x, size.y) * float(ENEMY_SCALE.get(kind, 1.6))
	var w := h * s.x / maxf(1.0, s.y)
	var b := Builder.new()
	b.quad(first, Rect2(-w * 0.5, -h * 0.5, w, h), 6)
	return _node(b.mesh())
