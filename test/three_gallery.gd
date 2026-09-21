extends Node3D
## Asset inspection/animation sheet. Real renderer required. Also records CPU
## frame intervals after warm-up; these are desktop measurements, not phone FPS.
const Lira=preload("res://src/render/three/lira.gd")
const EnemyModel=preload("res://src/render/three/enemy_model.gd")
const Assets=preload("res://src/render/three/assets.gd")
var models: Array[Node3D]=[]
var frame := 0
var intervals: Array[float]=[]
var previous := 0

func _ready() -> void:
	var camera := Camera3D.new()
	camera.position=Vector3(0,0,900)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=340
	camera.far=2000
	add_child(camera)
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("273e50")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d3e1ea")
	env.ambient_light_energy=.6
	camera.environment=env
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-32,-28,0)
	sun.light_energy=1.0
	add_child(sun)
	for i in 6:
		var model := Lira.new()
		model.position=Vector3(-225+i*86,45,0)
		model.scale=Vector3.ONE*1.45
		add_child(model)
		models.append(model)
	var kinds := ["walker","flyer","shieldbearer","turret","pursuer","keeper","thornmite","wisp"]
	for i in kinds.size():
		var model := EnemyModel.new(kinds[i],Vector2(48,44) if i<4 else Vector2(66,64))
		model.position=Vector3(-252+i*72,-58,0)
		add_child(model)
		models.append(model)
	for i in 9:
		var model := Assets.instance(["coin","crystal","switch","platform","spring","hazard","crate","flowers","checkpoint"][i],Vector2(30,25))
		model.position=Vector3(-240+i*61,-133,0)
		if i==8: model.scale=Vector3.ONE*.4
		add_child(model)
	previous=Time.get_ticks_usec()

func _process(delta: float) -> void:
	frame+=1
	var now := Time.get_ticks_usec()
	if frame>40: intervals.append(float(now-previous)/1000)
	previous=now
	for i in 6:
		var states := [Runner.State.IDLE,Runner.State.RUN,Runner.State.DASH,Runner.State.JUMP,Runner.State.FALL,Runner.State.HURT]
		models[i].animate(delta,Vector2(0 if i==0 else 230,-180 if i==3 else 180),i<3,states[i],1)
	for i in range(6,models.size()): models[i].animate(delta,90,1)
	if frame==90 and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/three-gallery.png")
	if frame==180:
		intervals.sort()
		print("desktop gallery frame ms median=%.2f p95=%.2f; renderer=%s adapter=%s" % [intervals[intervals.size()/2],intervals[int(intervals.size()*.95)],RenderingServer.get_current_rendering_method(),RenderingServer.get_video_adapter_name()])
		get_tree().quit()
