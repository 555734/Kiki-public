extends RefCounted
## Reproducible, vertex-coloured low-poly modelling tools. Pixel-sized models;
## only the presentation bridge converts them to metres. No physics resources.
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colours := PackedColorArray()
static var material: StandardMaterial3D

func tri(a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for p in [a, c, b]: # Godot's front faces use clockwise winding.
		vertices.append(p)
		normals.append(normal)
		colours.append(colour.srgb_to_linear())

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	tri(a, b, c, colour)
	tri(a, c, d, colour)

func box(at: Vector3, size: Vector3, colour: Color) -> void:
	var p := at - size * 0.5
	var q := at + size * 0.5
	quad(Vector3(p.x,p.y,q.z), Vector3(q.x,p.y,q.z), Vector3(q.x,q.y,q.z), Vector3(p.x,q.y,q.z), colour)
	quad(Vector3(q.x,p.y,p.z), Vector3(p.x,p.y,p.z), Vector3(p.x,q.y,p.z), Vector3(q.x,q.y,p.z), colour)
	quad(Vector3(p.x,q.y,q.z), Vector3(q.x,q.y,q.z), Vector3(q.x,q.y,p.z), Vector3(p.x,q.y,p.z), colour)
	quad(Vector3(p.x,p.y,p.z), Vector3(q.x,p.y,p.z), Vector3(q.x,p.y,q.z), Vector3(p.x,p.y,q.z), colour)
	quad(Vector3(q.x,p.y,q.z), Vector3(q.x,p.y,p.z), Vector3(q.x,q.y,p.z), Vector3(q.x,q.y,q.z), colour)
	quad(Vector3(p.x,p.y,p.z), Vector3(p.x,p.y,q.z), Vector3(p.x,q.y,q.z), Vector3(p.x,q.y,p.z), colour)

## Cross-sections are (height, x radius, z radius). Unlike capsules, these can
## define a jaw, tailored coat, angular boots, helmet, or a tapered stone.
func loft(at: Vector3, rings: Array, colour: Color, sides: int = 8) -> void:
	for j in range(rings.size() - 1):
		var r: Vector3 = rings[j]
		var s: Vector3 = rings[j + 1]
		for i in sides:
			var a := TAU * float(i) / sides + PI / sides
			var b := TAU * float(i + 1) / sides + PI / sides
			quad(at + Vector3(cos(a)*r.y,r.x,sin(a)*r.z), at + Vector3(cos(a)*s.y,s.x,sin(a)*s.z),
				at + Vector3(cos(b)*s.y,s.x,sin(b)*s.z), at + Vector3(cos(b)*r.y,r.x,sin(b)*r.z), colour)
	for end in [0, rings.size()-1]:
		var r: Vector3 = rings[end]
		for i in sides:
			var a := TAU * float(i) / sides + PI / sides
			var b := TAU * float(i+1) / sides + PI / sides
			var v := at + Vector3(cos(a)*r.y,r.x,sin(a)*r.z)
			var w := at + Vector3(cos(b)*r.y,r.x,sin(b)*r.z)
			if end == 0: tri(at+Vector3(0,r.x,0),v,w,colour)
			else: tri(at+Vector3(0,r.x,0),w,v,colour)

func gem(at: Vector3, size: Vector3, colour: Color, sides: int = 8) -> void:
	loft(at, [Vector3(-size.y*.5,0,0),Vector3(-size.y*.25,size.x*.46,size.z*.46),
		Vector3(size.y*.2,size.x*.5,size.z*.5),Vector3(size.y*.5,0,0)],colour,sides)

## Extrudes a convex silhouette, used for hair locks, scarves, wings and teeth.
func prism(points: Array, z: float, depth: float, colour: Color) -> void:
	var centre := Vector2.ZERO
	for p: Vector2 in points: centre += p
	centre /= points.size()
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		tri(Vector3(centre.x,centre.y,z+depth/2), Vector3(a.x,a.y,z+depth/2), Vector3(b.x,b.y,z+depth/2),colour)
		tri(Vector3(centre.x,centre.y,z-depth/2), Vector3(b.x,b.y,z-depth/2), Vector3(a.x,a.y,z-depth/2),colour)
		quad(Vector3(a.x,a.y,z-depth/2),Vector3(b.x,b.y,z-depth/2),Vector3(b.x,b.y,z+depth/2),Vector3(a.x,a.y,z+depth/2),colour)

func mesh() -> ArrayMesh:
	if material == null:
		material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	out.surface_set_material(0,material)
	return out

func instance(parent: Node3D, label: String = "Mesh") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
