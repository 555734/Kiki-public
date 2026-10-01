extends LevelBuilder
## Builds the 2v2 star arena out of 1-1's pieces: its terrain painter, its
## decor painter and its kill plane, fed VersusStageData instead of
## Level01Data. Nothing of 1-1's course is built -- no enemies, no hazards, no
## checkpoints, no goal -- so every machine's world is exactly the data, with
## nothing simulated locally that the other three would have to agree about.
##
## The cooperative builder and Level01Data are unchanged.

func _init() -> void:
	co_op_extras = false

func build() -> void:
	_static_root = Node2D.new()
	_static_root.name = "Static"
	add_child(_static_root)

	# Painted in chunks rather than as one picture: a canvas item is culled
	# as a whole, so one item spanning the loop and its margins was drawn in
	# full every frame (1-5's ground alone was ~600 draw calls). Chunks off
	# screen are skipped by the renderer.
	var slabs := _laps_of_slabs(VersusStageData.painted_slabs())
	for chunk in _chunks(slabs.size(), func(i: int) -> float: return slabs[i].get_center().x):
		var terrain := preload("res://src/render/terrain.gd").new()
		for i in chunk:
			terrain.slabs.append(slabs[i])
		_static_root.add_child(terrain)
		if _terrain == null:
			_terrain = terrain
	_build_ground_bodies()

	var items := _laps_of_decor(VersusStageData.decor())
	for chunk in _chunks(items.size(), func(i: int) -> float: return Vector2(items[i]["pos"]).x):
		var decor := preload("res://src/render/decor.gd").new()
		for i in chunk:
			decor.items.append(items[i])
		_static_root.add_child(decor)
		if _decor == null:
			_decor = decor

	# 1-4's sea and 1-5's poison lie below every floor, so the pits open
	# onto water. Drawn exactly as the stages draw it, with foam where a floor
	# or a footing meets it; the kill plane underneath is the arena's own.
	if Stage.water_y() != INF:
		_build_arena_water()

	_build_kill_plane()
	# Kept, empty, so code that looks for the Dynamic node finds one.
	_dynamic = Node2D.new()
	_dynamic.name = "Dynamic"
	add_child(_dynamic)

## Indices 0..count-1 grouped by which CHUNK-wide band of x they fall in.
const CHUNK := 800.0

static func _chunks(count: int, x_of: Callable) -> Array:
	var bands: Dictionary = {}
	for i in range(count):
		var band := int(floor(float(x_of.call(i)) / CHUNK))
		if not bands.has(band):
			bands[band] = []
		bands[band].append(i)
	var keys := bands.keys()
	keys.sort()
	var out: Array = []
	for k in keys:
		out.append(bands[k])
	return out

func _build_ground_bodies() -> void:
	var body := StaticBody2D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	for rect in VersusStageData.collision_rects():
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)
	_static_root.add_child(body)

func _build_kill_plane() -> void:
	var pit := Hazard.new()
	pit.draw_spikes = false
	pit.span = Vector2(VersusStageData.WIDTH * 3.0 + 800.0, 200)
	pit.global_position = Vector2(VersusStageData.WIDTH * 0.5,
		VersusStageData.kill_y() + 100.0)
	_static_root.add_child(pit)

## The field is a loop, so it is painted past both ends -- the lap you are
## in and LAP_MARGIN of the next one either side -- and the join is never an
## edge on screen. A runner is always brought back into the middle lap
## (versus_main._wrap_bodies), so the margins only ever show what is just
## across the join.
static func _laps_of_slabs(one: Array[Rect2]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for lap in VersusStageData.LAPS:
		for r in one:
			var built := VersusStageData.clip_to_built(
				Rect2(r.position + Vector2(VersusStageData.WIDTH * float(lap), 0.0), r.size))
			if built.size.x > 0.0:
				out.append(built)
	return out

static func _laps_of_decor(one: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lap in VersusStageData.LAPS:
		var shift := Vector2(VersusStageData.WIDTH * float(lap), 0.0)
		for d in one:
			var at: float = Vector2(d["pos"]).x + shift.x
			# Scenery is a few hundred px wide at most; past the margin and
			# that, it can never be on screen.
			if at < VersusStageData.LEFT - VersusStageData.LAP_MARGIN - 300.0 \
					or at > VersusStageData.RIGHT + VersusStageData.LAP_MARGIN + 300.0:
				continue
			var copy: Dictionary = d.duplicate()
			copy["pos"] = Vector2(d["pos"]) + shift
			if d.has("rect"):
				var r: Rect2 = d["rect"]
				copy["rect"] = Rect2(r.position + shift, r.size)
			out.append(copy)
	return out

func _build_arena_water() -> void:
	var sea := preload("res://src/render/sea_water.gd").new()
	sea.name = "PoisonWater" if Stage.is_swamp() else "Sea"
	sea.poison = Stage.is_swamp()
	sea.water_y = Stage.water_y()
	var shore := PackedFloat32Array()
	for r in VersusStageData.collision_rects():
		shore.append(r.position.x)
		shore.append(r.end.x)
	sea.shore_x = shore
	_static_root.add_child(sea)

func rebuild_dynamic() -> void:
	pass # The arena has nothing dynamic of its own.

func reset_to_checkpoint() -> void:
	pass
