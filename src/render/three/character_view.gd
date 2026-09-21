extends CanvasLayer
## Character-only 2.5D renderer.
##
## The painted backgrounds, terrain, enemies, props and effects remain on the
## original 2D canvas.  This layer renders only controllable characters in one
## small transparent viewport, so a mobile GPU never pays for a second 3D world.

const MODEL: PackedScene = preload("res://assets/models/blender/lira_mobile.glb")
const UNIT := 0.01
const MODEL_SCALE := 0.20
const MODEL_FOOT_OFFSET := 0.70 * MODEL_SCALE
const MAX_RENDER_WIDTH := 720.0
const MAX_RENDER_SCALE := 0.75
const FACING_ANGLE := 52.0

var source: Node
var viewport3d: SubViewport
var camera3d: Camera3D
var world: Node3D
var display: TextureRect
var bindings: Dictionary = {}
var hidden_visuals: Array = []
var arena_models: Array = []
var elapsed := 0.0


func _ready() -> void:
	name = "Character3D"
	layer = 1 # Above the 2D world (runner used z=10), below scope/HUD layers.
	process_priority = 1000
	source = get_parent()
	viewport3d = SubViewport.new()
	viewport3d.name = "CharacterViewport"
	viewport3d.own_world_3d = true
	viewport3d.transparent_bg = true
	viewport3d.handle_input_locally = false
	viewport3d.gui_disable_input = true
	viewport3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport3d.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport3d)

	world = Node3D.new()
	viewport3d.add_child(world)
	camera3d = Camera3D.new()
	camera3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera3d.keep_aspect = Camera3D.KEEP_HEIGHT
	camera3d.near = 0.1
	camera3d.far = 30.0
	world.add_child(camera3d)
	camera3d.current = true

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e4ee")
	environment.ambient_light_energy = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	camera3d.environment = environment
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	light.light_color = Color("fff1db")
	light.light_energy = 0.82
	light.shadow_enabled = false
	world.add_child(light)

	display = TextureRect.new()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	display.texture = viewport3d.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(display)

	_scan(source)
	get_tree().node_added.connect(_node_added)
	_sync_camera()


static func point(at: Vector2, depth: float = 0.0) -> Vector3:
	return Vector3(at.x * UNIT, -at.y * UNIT, depth)


func _sync_camera() -> void:
	var host := get_viewport()
	var size := host.get_visible_rect().size
	if size.x < 2.0 or size.y < 2.0:
		return
	# A character only occupies about 60 screen pixels.  Rendering the whole
	# transparent viewport at native phone resolution would waste fill-rate.
	var ratio := minf(MAX_RENDER_SCALE, MAX_RENDER_WIDTH / size.x)
	viewport3d.size = Vector2i((size * ratio).round())
	display.size = size
	var canvas := host.get_canvas_transform()
	var inverse := canvas.affine_inverse()
	var centre := inverse * (size * 0.5)
	camera3d.position = point(centre, 10.0)
	camera3d.size = size.y / canvas.y.length() * UNIT
	camera3d.rotation.z = -canvas.get_rotation()


func _scan(node: Node) -> void:
	if node == self:
		return
	_register(node)
	for child in node.get_children():
		_scan(child)


func _node_added(node: Node) -> void:
	if node is Runner and source.is_ancestor_of(node) and not is_ancestor_of(node):
		_register_deferred.call_deferred(weakref(node))


func _register_deferred(reference: WeakRef) -> void:
	var node = reference.get_ref()
	if node != null and node.is_inside_tree():
		_register(node)


func _register(node: Node) -> void:
	if not node is Runner or bindings.has(node.get_instance_id()):
		return
	var model := _new_model()
	world.add_child(model)
	var player := _find_animation_player(model)
	var animation_map := _animation_map(player)
	bindings[node.get_instance_id()] = {
		"source": weakref(node),
		"model": model,
		"player": player,
		"animations": animation_map,
		"was_grounded": node.on_ground(),
		"land_time": 0.0,
		"current": "",
	}
	if node.visual != null:
		hidden_visuals.append([weakref(node.visual), node.visual.self_modulate, node.visual.is_processing()])
		node.visual.self_modulate = Color(1, 1, 1, 0)
		node.visual.set_process(false)


func _new_model() -> Node3D:
	var model := MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * MODEL_SCALE
	return model


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _animation_map(player: AnimationPlayer) -> Dictionary:
	var result := {}
	if player == null:
		return result
	for animation_name in player.get_animation_list():
		var simplified := String(animation_name).get_file().get_basename().to_lower()
		# Godot can prefix imported glTF actions with a library or armature name.
		for expected in ["idle", "run", "jump", "fall", "land", "dash", "hurt", "dead"]:
			if simplified.ends_with(expected):
				result[expected] = animation_name
	return result


func _process(delta: float) -> void:
	elapsed += delta
	_sync_camera()
	var canvas := get_viewport().get_canvas_transform().affine_inverse()
	var screen := get_viewport().get_visible_rect().size
	var visible_rect := Rect2(canvas * Vector2.ZERO,
		screen / get_viewport().get_canvas_transform().get_scale()).grow(120.0)
	for id in bindings.keys():
		var binding: Dictionary = bindings[id]
		var runner: Runner = binding.source.get_ref()
		var model: Node3D = binding.model
		if runner == null:
			model.queue_free()
			bindings.erase(id)
			continue
		_sync_runner(binding, runner, delta, visible_rect)
		bindings[id] = binding
	_sync_arena(delta)


func _sync_runner(binding: Dictionary, runner: Runner, delta: float, visible_rect: Rect2) -> void:
	var model: Node3D = binding.model
	model.visible = runner.is_visible_in_tree() and visible_rect.has_point(runner.global_position)
	if runner.is_invulnerable():
		model.visible = model.visible and fmod(elapsed * 9.0, 1.0) > 0.35
	if not model.visible:
		return
	var feet := runner.global_position + Vector2(0.0, Balance.RUNNER_SIZE.y * 0.5)
	model.position = point(feet, 0.0)
	model.position.y += MODEL_FOOT_OFFSET
	# The imported model's positive yaw is screen-right. This deliberately
	# matches Runner.facing; the old negative sign made every run look backwards.
	model.rotation.y = deg_to_rad(FACING_ANGLE * float(runner.facing))

	var grounded := runner.on_ground()
	if grounded and not bool(binding.was_grounded):
		binding.land_time = 0.16
	binding.was_grounded = grounded
	binding.land_time = maxf(0.0, float(binding.land_time) - delta)
	var desired := "idle"
	if runner.state == Runner.State.DEAD:
		desired = "dead"
	elif runner.state == Runner.State.HURT:
		desired = "hurt"
	elif runner.state == Runner.State.DASH:
		desired = "dash"
	elif runner.crouching() or runner.pounding() or float(binding.land_time) > 0.0:
		desired = "land"
	elif not grounded:
		desired = "jump" if runner.velocity.y < 30.0 else "fall"
	elif absf(runner.velocity.x) > 8.0:
		desired = "run"
	_play(binding, desired, clampf(absf(runner.velocity.x) / 180.0, 0.72, 1.75))


func _play(binding: Dictionary, desired: String, speed: float = 1.0) -> void:
	var player: AnimationPlayer = binding.player
	var animations: Dictionary = binding.animations
	if player == null or not animations.has(desired):
		return
	var animation_name: StringName = animations[desired]
	if String(binding.current) != desired:
		player.play(animation_name, 0.10, speed)
		binding.current = desired
	else:
		player.speed_scale = speed


func _sync_arena(delta: float) -> void:
	if source.get_script() == null or not source.get_script().resource_path.ends_with("arena_main.gd"):
		return
	if source.match_state == null:
		return
	while arena_models.size() < source.match_state.fighters.size():
		var model := _new_model()
		world.add_child(model)
		arena_models.append({
			"model": model,
			"player": _find_animation_player(model),
			"animations": {},
			"current": "",
		})
		arena_models[-1].animations = _animation_map(arena_models[-1].player)
	for i in arena_models.size():
		var entry: Dictionary = arena_models[i]
		var fighter: ArenaFighter = source.match_state.fighters[i]
		var model: Node3D = entry.model
		model.visible = fighter.alive
		if fighter.combat.invulnerable():
			model.visible = model.visible and fmod(elapsed * 9.0, 1.0) > 0.35
		if model.visible:
			var feet := fighter.centre() + Vector2(0.0, ArenaRules.BODY_SIZE.y * 0.5)
			model.position = point(feet)
			model.position.y += MODEL_FOOT_OFFSET
			model.rotation.y = deg_to_rad(FACING_ANGLE * float(fighter.motor.facing))
			_play(entry, "run" if absf(fighter.motor.velocity.x) > 8.0 else "idle",
				clampf(absf(fighter.motor.velocity.x) / 180.0, 0.72, 1.75))
		arena_models[i] = entry


func _exit_tree() -> void:
	for record in hidden_visuals:
		var visual = record[0].get_ref()
		if visual != null:
			visual.self_modulate = record[1]
			visual.set_process(record[2])
