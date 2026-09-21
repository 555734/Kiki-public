extends Node
## Run with a real rendering driver for screenshots; headless only verifies
## scene/lifecycle/coordinate mathematics, never visual quality or GPU speed.
var failures := 0
func check(ok: bool, label: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL",label])
	if not ok: failures+=1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	main.get_node("NetPanel").queue_free()
	GameState.running=true
	for i in 35: await get_tree().process_frame
	var view=main.get_node("World3D")
	check(view.bindings.size()>5,"live gameplay objects have actual 3D models")
	check(view.viewport3d.gui_disable_input and view.display.mouse_filter==Control.MOUSE_FILTER_IGNORE,"3D composition never intercepts touch input")
	var b: Dictionary=view.bindings[main.runner.get_instance_id()]
	check(b.model.get_child_count()>0,"LIRA is an articulated mesh hierarchy")
	for zoom in [0.8,1.5,2.4]:
		main.camera.zoom=Vector2.ONE*zoom
		main.camera.force_update_scroll()
		view._sync_camera()
		var screen: Vector2=main.runner.get_global_transform_with_canvas().origin
		var projected: Vector2=view.camera3d.unproject_position(view.point(main.runner.global_position))
		projected*=view.display.size/Vector2(view.viewport3d.size)
		check(screen.distance_to(projected)<1.0,"2D/3D alignment at zoom %.1f" % zoom)
	main.camera.zoom=Vector2.ONE*1.5
	for i in 5: await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/three-greenfield.png")
		print("render driver: ",RenderingServer.get_current_rendering_method(),"; adapter: ",RenderingServer.get_video_adapter_name())
		print("draw calls: ",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"; primitives: ",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var rig=b.model
	main.input_hub.scripted=true
	main.input_hub.set_process(true)
	main.input_hub.move_axis=1.0
	check(rig.animation_player!=null,"LIRA imports a real AnimationPlayer")
	check(rig.available_animation_count()>=6,"LIRA exposes imported humanoid animation clips")
	check(rig._resolve_clip(["Run"])!=&"","rigged LIRA has a run animation")
	var start_x: float=main.runner.position.x
	for i in 20: await get_tree().physics_frame
	check(main.runner.position.x>start_x+20 and rig.pose in ["walk","run","sprint"],"actual Runner movement drives the imported run cycle")
	main.input_hub.move_axis=0.0
	main.input_hub.press_jump()
	var observed: Dictionary={}
	for i in 100:
		if i==18: main.input_hub.release_jump()
		await get_tree().physics_frame
		observed[rig.pose]=true
	check(observed.has("rise") and observed.has("fall") and observed.has("land"),"physical jump transitions through rise, fall and landing poses")
	check(main.runner.on_ground(),"3D presentation preserves ground contact")
	for window_size in [Vector2i(1600,720),Vector2i(960,720)]:
		get_tree().root.size=window_size
		for i in 4: await get_tree().process_frame
		view._sync_camera()
		var screen: Vector2=main.runner.get_global_transform_with_canvas().origin
		var projected: Vector2=view.camera3d.unproject_position(view.point(main.runner.global_position))
		projected*=view.display.size/Vector2(view.viewport3d.size)
		check(screen.distance_to(projected)<1,"resize %s keeps the gameplay plane aligned" % window_size)
	get_tree().root.size=Vector2i(1280,720)
	main.guardian.select_slot(1)
	var count_before: int=get_tree().get_nodes_in_group("hologram").size()
	var build_target: Vector2=main.runner.position+Vector2(-180,-120)
	check(main.guardian.abilities[1].check(main.guardian,build_target).is_empty(),"platform fixture is in range and clear of terrain")
	main.guardian.use_active(build_target)
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("hologram").size()>count_before,"guardian can still create a platform")
	var samples: Array[float]=[]
	var stamp := Time.get_ticks_usec()
	for i in 100:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if i>20: samples.append(float(now-stamp)/1000)
		stamp=now
	samples.sort()
	if DisplayServer.get_name()!="headless":
		print("desktop main frame ms median=%.2f p95=%.2f" % [samples[samples.size()/2],samples[int(samples.size()*.95)]])
	for state in [Runner.State.IDLE,Runner.State.RUN,Runner.State.DASH,Runner.State.JUMP,Runner.State.FALL,Runner.State.HURT,Runner.State.DEAD,Runner.State.HANG]:
		rig.animate(.1,Vector2(200,-100),state==Runner.State.RUN,state,1,false,false,state==Runner.State.HANG,false,1)
		check(not rig.pose.is_empty(),"pose mapping for runner state %d" % state)
	rig.animate(.1,Vector2(-Balance.WALL_JUMP_OUT,Balance.WALL_JUMP_UP),false,Runner.State.JUMP,-1,false,false,false,true,0)
	check(rig.pose=="wall_kick","wall jump selects a distinct kick pose")
	var spin_before: float=rig.spin_root.rotation.z
	rig.animate(.1,Vector2(260,-260),false,Runner.State.JUMP,1,false,false,false,false,3)
	check(absf(rig.spin_root.rotation.z-spin_before)>.2,"third chained jump drives a visual somersault")
	for _i in 20:
		rig.animate(.05,Vector2(260,50),false,Runner.State.FALL,1,false,false,false,false,3)
	check(absf(rig._triple_spin_angle-TAU)<0.01,"third jump somersault is exactly one full visual turn")
	main.queue_free()
	await get_tree().process_frame
	for stage_id in range(1,7):
		Stage.use(stage_id)
		main=load("res://src/main.tscn").instantiate()
		add_child(main)
		main.get_node("NetPanel").queue_free()
		GameState.running=true
		if stage_id==Stage.Which.KEEPER: main.runner.respawn(Vector2(250,340))
		for i in 8: await get_tree().process_frame
		view=main.get_node("World3D")
		check(view.surfaces.size()>0 and view.bindings.size()>0,"stage %d builds 3D geometry" % stage_id)
		if stage_id==Stage.Which.HORROR:
			var kinds: Array=[]
			for bound: Dictionary in view.bindings.values(): kinds.append(bound.kind)
			check(kinds.has("thornmite") and kinds.has("wisp"),"latest horror enemies have distinct 3D models")
		if stage_id==Stage.Which.QUIET:
			main.input_hub.solo_role="runner"
			main.level._veils._refresh()
			await get_tree().process_frame
			var entry: Dictionary=view.surfaces[main.level._terrain.get_instance_id()]
			check(entry.hash==hash(main.level._veils.drawn_slabs()),"3D terrain uses the role-filtered slabs")
			for bound: Dictionary in view.bindings.values():
				var target=bound.source.get_ref()
				if target!=null and not target.visible: check(not bound.model.visible,"veiled object cannot leak into 3D")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/three-stage-%d.png" % stage_id)
		main.queue_free()
		await get_tree().process_frame
	Stage.use(Stage.Which.GREENFIELD)
	print("three view probe: %d failed" % failures)
	get_tree().quit(0 if failures==0 else 1)
