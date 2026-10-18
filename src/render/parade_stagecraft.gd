extends Node2D
## One bounded piece per act: distant curtains and lights need no redraw.
## Decoration never supplies collision; every visible landing is stage data.
var act: Dictionary = {}
var index := 0
var runner: Runner
var _last_frame := -1
var _age := 0.0
var _floors: Array[Rect2] = []
var _mesh := ArrayMesh.new()
var _vertices := PackedVector3Array()
var _colours := PackedColorArray()
var _indices := PackedInt32Array()

func _ready() -> void:
	z_index = -1
	add_to_group("parade_stagecraft")
	act.sign = Vector2(act.sign.x, maxf(180,act.sign.y))
	for floor_rect in Stage.ground():
		if floor_rect.position.x >= float(act.from) and floor_rect.position.x < float(act.to) and floor_rect.size.y >= 60:
			_floors.append(floor_rect)
	var sign := VBoxContainer.new()
	sign.position = act.sign - position - Vector2(115,90)
	sign.size = Vector2(280,90)
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_theme_constant_override("separation", 5)
	var title := UiKit.heading("%02d  %s" % [index + 1, tr(String(act.name))], 20, act.colour)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sign.add_child(title)
	var hint_text := tr(String(act.hint)).replace("。", "\n").replace("、", "\n")
	var hint := UiKit.heading(hint_text, 18, Color("fff4da"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sign.add_child(hint)
	add_child(sign)
	_build_mesh()

func _process(delta: float) -> void:
	_age += delta
	if index != 5 or not is_instance_valid(runner) or not runner.cleared: return
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		var half_view := get_viewport_rect().size.x / (2.0 * camera.zoom.x)
		if camera.global_position.x + half_view < float(act.from) - 100 or camera.global_position.x - half_view > float(act.to) + 100:
			return
	var frame := int(_age * 8)
	if frame != _last_frame:
		_last_frame = frame
		queue_redraw()

## Static untextured geometry is one mesh per act. Alternating individual
## line/polygon/circle commands broke mobile canvas batching at every bulb.
func _shape(points: PackedVector2Array, colour: Color) -> void:
	var first := _vertices.size()
	for p in points:
		_vertices.append(Vector3(p.x,p.y,0))
		_colours.append(colour)
	for i in range(1,points.size()-1):
		_indices.append_array(PackedInt32Array([first,first+i,first+i+1]))

func _rect(rect: Rect2, colour: Color) -> void:
	_shape(PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]),colour)

func _line(a: Vector2, b: Vector2, colour: Color, width: float) -> void:
	var normal := (b-a).normalized().orthogonal() * width * 0.5
	_shape(PackedVector2Array([a+normal,a-normal,b-normal,b+normal]),colour)

func _disc(at: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 12: points.append(at + Vector2.from_angle(i * TAU / 12) * radius)
	_shape(points,colour)

func _build_mesh() -> void:
	var width := float(act.to) - float(act.from)
	var colour: Color = act.colour
	# A proscenium at each entrance, with the scene number on a lit marquee.
	var sign_at: Vector2 = act.sign - position
	for side in [20.0, width - 30.0]:
		_line(Vector2(side,-25), Vector2(side,710), Color("33273d"), 12)
		for fold in 4:
			_rect(Rect2(side - 14 + fold * 9,-25,10,120 + fold * 12),
				Color("7f344a") if fold % 2 == 0 else Color("542d45"))
		_disc(Vector2(side,135), 9, colour)
	# Suspended bunting, well above the jump line.
	for i in 12:
		var x := 35 + i * (width - 70) / 11
		var y := 28 + sin(float(i) / 11 * PI) * 40
		if i < 11:
			var next_x := 35 + (i + 1) * (width - 70) / 11
			var next_y := 28 + sin(float(i + 1) / 11 * PI) * 40
			_line(Vector2(x,y), Vector2(next_x,next_y), Color("c8a777"), 2)
		var pennant := PackedVector2Array([Vector2(x-12,y),Vector2(x+12,y),Vector2(x,y+35)])
		_shape(pennant, colour if i % 2 == 0 else Color("8f4157"))
	# Draw the board after the curtain poles so no fold crosses its lettering.
	_rect(Rect2(sign_at - Vector2(130,108), Vector2(310,122)), colour)
	_rect(Rect2(sign_at - Vector2(127,105), Vector2(304,116)), Color("272239"))
	for i in 10:
		_disc(sign_at + Vector2(-112 + i * 30,-99), 3, colour)
	# Grounded footlights and struts use the actual floor extents.
	for floor_rect in _floors:
		var local: Vector2 = floor_rect.position - position
		for i in maxi(1, int(floor_rect.size.x / 65)):
			var light := local + Vector2(22 + i * 65,20)
			_disc(light, 7, Color("38263d"))
			_disc(light, 3, colour)
		for i in maxi(1, int(floor_rect.size.x / 130)):
			var support := local + Vector2(30 + i * 130,60)
			_line(support, support + Vector2(0,120), Color("423247"), 12)
	if index == 5:
		var flag := Stage.goal() - position
		for i in 32:
			_line(flag + Vector2(0,-70) + Vector2.from_angle(PI+i*PI/32)*125,
				flag + Vector2(0,-70) + Vector2.from_angle(PI+(i+1)*PI/32)*125,colour,9)
		for side in [-125,125]:
			_line(flag + Vector2(side,-70),flag + Vector2(side,55),colour,8)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colours
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_vertices.clear()
	_colours.clear()
	_indices.clear()

func _draw() -> void:
	draw_mesh(_mesh,null)
	# Celebration stays in the world and never covers either touch pad.
	if index == 5 and is_instance_valid(runner) and runner.cleared:
		var flag := Stage.goal() - position
		for i in 32:
			var at := flag + Vector2(-240 + i * 16, -300 + fposmod(_age * 80 + i * 37,360))
			draw_rect(Rect2(at,Vector2(5,10)), act.colour if i % 2 == 0 else Color("d98aa4"))
