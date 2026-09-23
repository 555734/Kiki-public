extends CanvasLayer
## Presentation only. One transparent 3D viewport per game viewport, below all
## 2D gameplay cues and UI. No collision bodies, network fields or input handlers.
const Assets = preload("res://src/render/three/assets.gd")
const Lira = preload("res://src/render/three/lira.gd")
const EnemyModel = preload("res://src/render/three/enemy_model.gd")
const UNIT := .01
## A fixed 10-degree elevation reveals real top faces. Y compensation keeps
## the gameplay plane pixel-exact; depth never changes apparent object size.
const PITCH := PI / 18.0
const MODEL_SCALE := Vector3(UNIT,UNIT / cos(PITCH),UNIT)
var source: Node2D
var viewport3d: SubViewport
var camera3d: Camera3D
var world: Node3D
var display: TextureRect
var bindings: Dictionary = {}
var surfaces: Dictionary = {}
var hidden: Array = []
var coin_models: Array[MeshInstance3D] = []
var arena_models: Array[Node3D] = []
var elapsed := 0.0
var scan_in := 0.0
var active_models := 0
var signal_materials: Dictionary = {}
var build_models: Array[MeshInstance3D] = []
var builds_hash := -1

func _ready() -> void:
	name="World3D"
	layer=-1
	process_priority=1000 # After Camera2D follow, veil changes, remote interpolation.
	source=get_parent()
	viewport3d=SubViewport.new()
	viewport3d.name="RenderViewport"
	viewport3d.own_world_3d=true
	viewport3d.transparent_bg=true
	viewport3d.handle_input_locally=false
	viewport3d.gui_disable_input=true
	viewport3d.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport3d.msaa_3d=Viewport.MSAA_2X
	add_child(viewport3d)
	world=Node3D.new()
	viewport3d.add_child(world)
	camera3d=Camera3D.new()
	camera3d.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera3d.keep_aspect=Camera3D.KEEP_HEIGHT
	camera3d.rotation.x=-PITCH
	camera3d.near=.1
	camera3d.far=60
	world.add_child(camera3d)
	camera3d.current=true
	var environment := Environment.new()
	environment.background_mode=Environment.BG_CLEAR_COLOR
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("c8d5e4")
	environment.ambient_light_energy=.65
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	camera3d.environment=environment
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-32,-28,0)
	sun.light_color=Color("fff1cd")
	sun.light_energy=.95
	sun.shadow_enabled=false
	world.add_child(sun)
	display=TextureRect.new()
	display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	display.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	display.texture=viewport3d.get_texture()
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode=TextureRect.STRETCH_SCALE
	add_child(display)
	_scan(source)
	get_tree().node_added.connect(_node_added)
	_sync_camera()
	if source.get_script().resource_path.ends_with("arena_main.gd"):
		var terrain := Node2D.new()
		terrain.set_script(preload("res://src/render/terrain.gd"))
		terrain.slabs=source.stage.boxes()
		source.add_child(terrain)
		_register(terrain)

static func point(at: Vector2, depth: float = 0) -> Vector3:
	return Vector3(at.x,(-at.y+depth*sin(PITCH))/cos(PITCH),depth)*UNIT

func _sync_camera() -> void:
	var host := get_viewport()
	var size := host.get_visible_rect().size
	if size.x<2 or size.y<2: return
	# Cap render resolution; keep UI at native resolution. Both cameras still
	# cover exactly the same world rectangle, including guardian zoom/pan.
	var ratio := minf(1.0,1280.0/size.x)
	viewport3d.size=Vector2i((size*ratio).round())
	display.size=size
	var canvas := host.get_canvas_transform()
	var inverse := canvas.affine_inverse()
	var centre := inverse*(size*.5)
	camera3d.position=point(centre)
	camera3d.position+=Vector3(0,sin(PITCH),cos(PITCH))*20
	camera3d.size=size.y/canvas.y.length()*UNIT
	camera3d.rotation.z=-canvas.get_rotation()

func _scan(node: Node) -> void:
	if node==self: return
	_register(node)
	for child in node.get_children(): _scan(child)

func _node_added(node: Node) -> void:
	if node is Node2D and source.is_ancestor_of(node) and not is_ancestor_of(node):
		_register_after_ready.call_deferred(weakref(node))

func _register_after_ready(reference: WeakRef) -> void:
	var node=reference.get_ref()
	if node!=null and node.is_inside_tree(): _register(node)

func _hide(item: CanvasItem) -> void:
	hidden.append([weakref(item),item.self_modulate])
	item.self_modulate=Color(1,1,1,0)

func _register(node: Node) -> void:
	if not node is Node2D or node.get_script()==null: return
	var id := node.get_instance_id()
	if bindings.has(id) or surfaces.has(id): return
	var path: String=node.get_script().resource_path
	if path.ends_with("/terrain.gd") or path.ends_with("/decor.gd"):
		surfaces[id]={"source":weakref(node),"hash":-1,"models":[]}
		_hide(node)
		return
	var kind := ""
	var size := Vector2(40,40)
	if node is Runner:
		kind="runner"
	elif node is Enemy:
		kind=path.get_file().get_basename()
		if node is Walker and node.skin=="walker_spiky": kind="walker_spiky"
		if node is Flyer and Stage.is_horror(): kind="wisp"
		if kind=="sky_pursuer": kind="sky_predator" if Stage.is_skyward_ruins() else "pursuer"
		if kind=="black_hole_chaser": kind="black_hole"
		size=_body_size(node,size)
	elif node is MovingPlatform: kind="platform"; size=node.span
	elif node is CrumblingFloor: kind="crumbling"; size=node.span
	elif node is Gate: kind="gate"; size=node.span
	elif node is Barricade: kind="barricade"; size=Balance.BARRICADE_SIZE
	elif node is Hazard:
		if not node.draw_spikes: return
		kind="hazard"; size=node.span
	elif node is Coin: kind="coin"; size=Vector2(20,20)
	elif node is Crystal: kind="crystal"
	elif node is Goal: kind="goal"
	elif node is Checkpoint: kind="checkpoint"
	elif node is ShootableSwitch: kind="switch"
	elif node is Spring: kind="spring"; size=Vector2(Spring.WIDTH,Spring.PAD_Y)
	elif node is Projectile: kind="projectile"; size=Vector2(14,14)
	elif node is Shockwave: kind="shockwave"; size=Balance.SHOCKWAVE_SIZE
	# Holograms, lasers, updrafts, telegraphs and aiming remain luminous 2D
	# overlays. They always draw above the 3D terrain, including placement UI.
	if kind.is_empty(): return
	var accent := Lira.CLOTH
	if kind=="runner" and node.visual!=null and node.visual.modulate!=Color.WHITE:
		accent=Color("4a9fcc")
	var model: Node3D = Lira.new(accent) if kind=="runner" else Assets.instance(kind,size)
	if node is Enemy:
		model.free()
		model=EnemyModel.new(kind,size)
	world.add_child(model)
	model.scale=MODEL_SCALE
	bindings[id]={"source":weakref(node),"model":model,"kind":kind,"size":size}
	if node is Gate or node is ShootableSwitch or node is CrumblingFloor:
		node.set_meta("model_3d",true)
	else:
		_hide(node)
	if node is Runner or node is Enemy:
		if node.visual!=null:
			if node is Keeper or node is Shieldbearer or node is Turret or kind=="thornmite":
				node.visual.set_meta("model_3d",true)
			else:
				_hide(node.visual)
				node.visual.set_process(false)

func _body_size(node: Node2D, fallback: Vector2) -> Vector2:
	for child in node.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			return child.shape.size
		if child is CollisionShape2D and child.shape is CircleShape2D:
			return Vector2.ONE*child.shape.radius*2
	return fallback

func _process(delta: float) -> void:
	elapsed+=delta
	_sync_camera()
	scan_in-=delta
	if scan_in<=0:
		hidden=hidden.filter(func(record: Array) -> bool: return record[0].get_ref()!=null)
		scan_in=1.0
	var canvas := get_viewport().get_canvas_transform().affine_inverse()
	var screen := get_viewport().get_visible_rect().size
	var visible_rect := Rect2(canvas*Vector2.ZERO,screen/get_viewport().get_canvas_transform().get_scale()).grow(220)
	active_models=0
	for id in bindings.keys():
		var b: Dictionary=bindings[id]
		var node=b.source.get_ref()
		var model: Node3D=b.model
		if node==null:
			model.queue_free(); bindings.erase(id); continue
		model.visible=node.is_visible_in_tree() and visible_rect.intersects(Rect2(node.global_position-b.size*.5,b.size))
		if not model.visible: continue
		active_models+=1
		model.position=point(node.global_position,12)
		if b.kind=="runner":
			model.position=point(node.global_position+Vector2(0,Balance.RUNNER_SIZE.y*.5),12)
			model.animate(delta,node.velocity,node.on_ground(),node.state,node.facing,node.crouching(),node.pounding(),(node.movement_flags()&8)!=0,node.wall_kicking(),node.jump_chain())
			model.visible=not node.is_invulnerable() or fmod(elapsed*9,1)>.35
		elif b.kind in ["coin","crystal"]:
			model.rotation.y=elapsed*2
		elif node is Enemy:
			var face: float=signf(node.velocity.x) if absf(node.velocity.x)>1 else 1.0
			if node is Walker: face=node.direction
			if node is Flyer or b.kind=="thornmite": face=node.direction
			if node is Keeper: face=node.facing
			if node is Shieldbearer: face=node.facing_now()
			model.animate(delta,node.velocity.length(),face,node.state if node is Keeper else (node.mode() if b.kind=="thornmite" else 0))
			if b.kind=="sky_predator":
				var pursuit_direction: Vector2 = node.get("chase_direction")
				model.rotation.z=-pursuit_direction.angle()
			if node is Turret:
				model.rotation.y=0
				model.rotation.z=-node.aim_direction.angle()
		elif node is Gate:
			model.position.y+=node._open_amount*node.span.y*.92*MODEL_SCALE.y
			model.visible=model.visible and node._open_amount<.98
		elif node is CrumblingFloor:
			model.visible=model.visible and not node._gone
			model.rotation.z=sin(elapsed*45)*node._shake*.025
		elif node is Barricade:
			model.scale.y=MODEL_SCALE.y*(1.0 if node.standing() else .2)
			if not node.standing(): model.position.y-=Balance.BARRICADE_SIZE.y*.4*MODEL_SCALE.y
		elif node is Spring:
			model.scale.y=MODEL_SCALE.y*(1-node._squash*.34)
			model.scale.x=UNIT*(1+node._squash*.16)
		elif node is Checkpoint:
			_signal(model,node.reached)
		elif node is ShootableSwitch:
			_signal(model,node.active and not node.locked())
	_sync_surfaces(visible_rect)
	_sync_match(delta)

func _signal(model: MeshInstance3D, active: bool) -> void:
	if not signal_materials.has(active):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo=true
		material.roughness=1.0
		material.albedo_color=Color.WHITE if active else Color(.45,.5,.55)
		signal_materials[active]=material
	model.material_override=signal_materials[active]

func _sync_surfaces(visible_rect: Rect2) -> void:
	for id in surfaces.keys():
		var entry: Dictionary=surfaces[id]
		var node=entry.source.get_ref()
		if node==null:
			for part in entry.models: part.model.queue_free()
			surfaces.erase(id); continue
		var is_terrain: bool=node.get_script().resource_path.ends_with("terrain.gd")
		var data: Array=node.slabs if is_terrain else node.items
		var signature := hash(data)
		if entry.hash!=signature:
			for part in entry.models: part.model.queue_free()
			entry.models.clear()
			entry.hash=signature
			if is_terrain:
				for slab: Rect2 in data:
					var x := 0.0
					while x<slab.size.x:
						var rect := Rect2(slab.position+Vector2(x,0),Vector2(minf(512,slab.size.x-x),slab.size.y))
						var part := MeshInstance3D.new()
						part.mesh=Assets.terrain(rect.size)
						_add_surface(entry,part,node.global_position+rect.position,rect)
						x+=512
			else:
				for d: Dictionary in data:
					var at: Vector2=d["pos"]
					var kind: String=d["type"]
					var size: Vector2=d.get("size",Vector2(float(d.get("width",46)),46))
					if kind in ["blocks","ruin_blocks"]:
						var cell: float=d.get("cell",46)
						for k in int(d.get("count",3)):
							_add_surface(entry,Assets.instance(kind,Vector2(cell,cell)),node.global_position+at+Vector2(k*cell+cell/2,cell),Rect2(at,Vector2(cell,cell)))
					else:
						_add_surface(entry,Assets.instance(kind,size),node.global_position+at,
							Rect2(at-size*.5,Vector2(maxf(size.x,200),maxf(size.y,200))))
		for part in entry.models:
			part.model.visible=node.is_visible_in_tree() and visible_rect.intersects(part.bounds)

func _add_surface(entry: Dictionary, model: MeshInstance3D, at: Vector2, bounds: Rect2) -> void:
	world.add_child(model)
	model.scale=MODEL_SCALE
	model.position=point(at,-8)
	model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	entry.models.append({"model":model,"bounds":bounds})

func _sync_match(delta: float) -> void:
	var coins: Array=[]
	var path: String=source.get_script().resource_path
	if path.ends_with("versus_main.gd"):
		coins=source.coins()
		_sync_builds()
	elif path.ends_with("arena_main.gd") and source.match_state!=null:
		for c in source.match_state.ledger.coins:
			coins.append({"state":c.state,"position":c.position,"world_since":c.world_since})
		while arena_models.size()<source.match_state.fighters.size():
			var f: ArenaFighter=source.match_state.fighters[arena_models.size()]
			var model := Lira.new(ArenaRules.TEAM_COLOURS[f.team_id])
			model.scale=MODEL_SCALE
			world.add_child(model)
			arena_models.append(model)
		for i in arena_models.size():
			var f: ArenaFighter=source.match_state.fighters[i]
			var model: Node3D=arena_models[i]
			model.visible=f.alive
			if f.combat.invulnerable(): model.visible=model.visible and fmod(elapsed*9,1)>.35
			model.position=point(f.centre()+Vector2(0,ArenaRules.BODY_SIZE.y/2),12)
			model.animate(delta,f.motor.velocity,f.motor.grounded,Runner.State.RUN,f.motor.facing)
	while coin_models.size()<coins.size():
		var model := Assets.instance("coin",Vector2(22,22))
		model.scale=MODEL_SCALE
		world.add_child(model)
		coin_models.append(model)
	for i in coin_models.size():
		var model := coin_models[i]
		model.visible=i<coins.size() and int(coins[i]["state"])==ArenaCoin.State.WORLD
		if model.visible:
			model.position=point(coins[i]["position"],18)
			model.rotation.y=elapsed*2
			if coins[i].has("world_since"):
				var tick: int=source.world_tick() if path.ends_with("versus_main.gd") else source.match_state.tick
				var lifetime: int=VersusRules.STALE_TICKS if path.ends_with("versus_main.gd") else ArenaRules.COIN_STALE_TICKS
				if lifetime-(tick-int(coins[i]["world_since"]))<90:
					model.visible=fmod(elapsed*7,1)>.3

func _sync_builds() -> void:
	var signature := hash(source._built)
	if signature==builds_hash: return
	builds_hash=signature
	for model in build_models: model.queue_free()
	build_models.clear()
	for rect: Rect2 in source._built:
		var model := Assets.instance("platform",rect.size)
		model.scale=MODEL_SCALE
		model.position=point(rect.get_center(),-4)
		world.add_child(model)
		build_models.append(model)

func _exit_tree() -> void:
	for record in hidden:
		var node=record[0].get_ref()
		if node!=null: node.self_modulate=record[1]
