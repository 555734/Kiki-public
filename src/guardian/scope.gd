class_name Scope
extends CanvasLayer
## The partial FPS-style scope.
##
## Mockup 3 shows a full-screen optic. On a shared tablet that would take the
## screen away from the runner mid-jump, so the magnification is confined to a
## ring around the reticle and the world outside is only dimmed (capped by
## Balance.SCOPE_DIM_MAX_ALPHA). The artwork inside the ring is the mockup's:
## graduated crosshair, red centre dot, zoom readout, ammo strip.
##
## The magnified image comes from a second Viewport that *shares* the main
## World2D rather than duplicating the scene, and it only renders while the
## scope is up -- rendering the world twice every frame is exactly the kind of
## thing that costs a mobile frame budget.

const RING_PAD := 40.0

var guardian: Guardian = null

var _sub: SubViewport = null
var _cam: Camera2D = null
var _glass: TextureRect = null
var _dim: ColorRect = null
var _ring: Control = null
var _amount: float = 0.0
var _target_amount: float = 0.0
var _zoom: float = 3.0
var _centre: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 4

	var size := float(Balance.SCOPE_VIEWPORT_SIZE)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim_mat := ShaderMaterial.new()
	dim_mat.shader = preload("res://src/render/shaders/scope_dim.gdshader")
	dim_mat.set_shader_parameter("max_alpha", Balance.SCOPE_DIM_MAX_ALPHA)
	_dim.material = dim_mat
	_dim.color = Color(1, 1, 1, 1)
	add_child(_dim)

	_sub = SubViewport.new()
	_sub.size = Vector2i(int(size), int(size))
	# The parallax sky lives on its own CanvasLayer, which a SubViewport sharing
	# World2D does not see -- an opaque background would leave the ring showing
	# the world floating on a void. Transparent lets the normal screen (sky and
	# all) sit behind the magnified world instead.
	_sub.transparent_bg = true
	_sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sub.handle_input_locally = false
	_sub.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_sub)

	_cam = Camera2D.new()
	_cam.enabled = true
	_sub.add_child(_cam)

	_glass = TextureRect.new()
	_glass.texture = _sub.get_texture()
	_glass.size = Vector2(size, size)
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://src/render/shaders/scope_mask.gdshader")
	mask.set_shader_parameter("rect_size", Vector2(size, size))
	mask.set_shader_parameter("radius_px", Balance.SCOPE_RADIUS)
	_glass.material = mask
	add_child(_glass)

	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_script(preload("res://src/guardian/scope_ring.gd"))
	add_child(_ring)
	_ring.scope = self

	Events.scope_state_changed.connect(_on_scope_state)
	visible = false

func _on_scope_state(active: bool, zoom: float) -> void:
	_target_amount = 1.0 if active and _belongs_here() else 0.0
	_zoom = zoom

## Online, the guardian raising the sight arrives on the runner's device as a
## SLOT message and would dim their screen and magnify a ring they cannot move.
## The optic is the guardian's eye; it is drawn only where it can be aimed.
func _belongs_here() -> bool:
	if guardian == null or guardian.input_hub == null:
		return true
	return guardian.input_hub.owns_guardian_controls()

func _process(delta: float) -> void:
	var speed := delta / maxf(Balance.SCOPE_TRANSITION, 0.001)
	_amount = move_toward(_amount, _target_amount, speed)

	if _amount <= 0.001:
		if visible:
			visible = false
			# Stop paying for the second render the moment the scope is down.
			_sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	if not visible:
		visible = true
		_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		# Share the world instead of duplicating the scene into the SubViewport.
		_sub.world_2d = get_viewport().world_2d

	if guardian != null:
		_centre = get_viewport().get_canvas_transform() * guardian.aim_world()
		_cam.global_position = guardian.aim_world()
	# _zoom is a magnification factor relative to the normal view.
	_cam.zoom = Vector2.ONE * Balance.CAMERA_ZOOM * _zoom

	var size := float(Balance.SCOPE_VIEWPORT_SIZE)
	_glass.position = _centre - Vector2(size, size) * 0.5
	(_glass.material as ShaderMaterial).set_shader_parameter("amount", _amount)

	var screen := Vector2(get_viewport().get_visible_rect().size)
	var dim_mat := _dim.material as ShaderMaterial
	dim_mat.set_shader_parameter("centre_px", _centre)
	dim_mat.set_shader_parameter("screen_size", screen)
	dim_mat.set_shader_parameter("radius_px", Balance.SCOPE_RADIUS)
	dim_mat.set_shader_parameter("amount", _amount)

	_ring.position = Vector2.ZERO
	_ring.size = screen
	_ring.queue_redraw()

func amount() -> float:
	return _amount

func centre() -> Vector2:
	return _centre

func zoom() -> float:
	return _zoom
