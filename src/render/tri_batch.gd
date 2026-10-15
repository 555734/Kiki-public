class_name TriBatch
extends RefCounted
## Collects flat-coloured shapes (polygons, thick lines, circles) as
## triangles and draws them as ONE mesh. The canvas renderer issues a draw
## call per polygon, line or circle command; a bone, a skull or a slab's
## rims and marks made of dozens of those cost dozens of calls. Through a
## TriBatch they cost one, in the same painter's order they were added.

var _v := PackedVector2Array()
var _c := PackedColorArray()
var _uv := PackedVector2Array()
var _textured := false

func is_empty() -> bool:
	return _v.is_empty()

func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	_v.append(a)
	_v.append(b)
	_v.append(c)
	_c.append(col)
	_c.append(col)
	_c.append(col)
	_uv.append(Vector2.ZERO)
	_uv.append(Vector2.ZERO)
	_uv.append(Vector2.ZERO)

## A textured triangle (all of a batch's textured shapes share one texture,
## given to flush()).
func tri_uv(a: Vector2, b: Vector2, c: Vector2, ua: Vector2, ub: Vector2, uc: Vector2, col: Color = Color.WHITE) -> void:
	_textured = true
	_v.append(a)
	_v.append(b)
	_v.append(c)
	_c.append(col)
	_c.append(col)
	_c.append(col)
	_uv.append(ua)
	_uv.append(ub)
	_uv.append(uc)

## A textured quad p0-p1-p2-p3 (clockwise) with its UVs.
func quad_uv(p: PackedVector2Array, uv: PackedVector2Array, col: Color = Color.WHITE) -> void:
	tri_uv(p[0], p[1], p[2], uv[0], uv[1], uv[2], col)
	tri_uv(p[0], p[2], p[3], uv[0], uv[2], uv[3], col)

## A simple polygon (any winding, may be concave).
func poly(points: PackedVector2Array, col: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(points)
	for i in range(0, idx.size(), 3):
		tri(points[idx[i]], points[idx[i + 1]], points[idx[i + 2]], col)

## Polygon with a colour per vertex (for gradients).
func poly_colors(points: PackedVector2Array, cols: PackedColorArray) -> void:
	var idx := Geometry2D.triangulate_polygon(points)
	for i in range(0, idx.size(), 3):
		for k in 3:
			_v.append(points[idx[i + k]])
			_c.append(cols[idx[i + k]])
			_uv.append(Vector2.ZERO)

func rect(r: Rect2, col: Color) -> void:
	tri(r.position, Vector2(r.end.x, r.position.y), r.end, col)
	tri(r.position, r.end, Vector2(r.position.x, r.end.y), col)

## Pairs of points, like CanvasItem.draw_multiline.
func multiline(pairs: PackedVector2Array, width: float, col: Color) -> void:
	for i in range(0, pairs.size() - 1, 2):
		line(pairs[i], pairs[i + 1], width, col)

## A textured polygon (UV per point).
func poly_uv(points: PackedVector2Array, uvs: PackedVector2Array, col: Color = Color.WHITE) -> void:
	var idx := Geometry2D.triangulate_polygon(points)
	for i in range(0, idx.size(), 3):
		tri_uv(points[idx[i]], points[idx[i + 1]], points[idx[i + 2]], uvs[idx[i]], uvs[idx[i + 1]], uvs[idx[i + 2]], col)

func circle(c: Vector2, r: float, col: Color, segments: int = 14) -> void:
	var prev := c + Vector2(r, 0)
	for i in range(1, segments + 1):
		var a := TAU * float(i) / float(segments)
		var p := c + Vector2(cos(a), sin(a)) * r
		tri(c, prev, p, col)
		prev = p

func line(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var n := d.normalized().orthogonal() * width * 0.5
	tri(a + n, b + n, b - n, col)
	tri(a + n, b - n, a - n, col)

## A thick polyline with round joins.
func polyline(points: PackedVector2Array, width: float, col: Color, round_joins: bool = true) -> void:
	for i in range(points.size() - 1):
		line(points[i], points[i + 1], width, col)
	if round_joins and width > 4.0:
		for i in range(1, points.size() - 1):
			circle(points[i], width * 0.5, col, 10)

func flush(ci: CanvasItem, texture: Texture2D = null) -> void:
	if _v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_COLOR] = _c
	if _textured:
		arrays[Mesh.ARRAY_TEX_UV] = _uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	ci.draw_mesh(mesh, texture if _textured else null)
	# The canvas keeps only the mesh's RID: hold the mesh for as long as the
	# item's drawing stands (until its next redraw).
	_hold(ci, mesh)
	_v = PackedVector2Array()
	_c = PackedColorArray()
	_uv = PackedVector2Array()
	_textured = false

static var _held := {}

static func _hold(ci: CanvasItem, mesh: ArrayMesh) -> void:
	var id := ci.get_instance_id()
	var frame := Engine.get_process_frames()
	var entry: Array = _held.get(id, [])
	if entry.is_empty() or int(entry[0]) != frame:
		entry = [frame, []]
		_held[id] = entry
		if _held.size() > 4096:
			_prune()
	(entry[1] as Array).append(mesh)

## Forget items that no longer exist.
static func _prune() -> void:
	for id in _held.keys():
		if not is_instance_id_valid(id):
			_held.erase(id)
