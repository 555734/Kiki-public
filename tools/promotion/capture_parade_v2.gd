extends "res://tools/promotion/capture_promo_v3.gd"
## A native six-act implementation preview; camera/inputs only are directed.
const OUT := "res://build/promotion/stage-1-9/playable-v2/"
func _ready() -> void:
	process_priority = 250
	TranslationServer.set_locale("en")
	call_deferred("run")
func device(kind: String) -> ParadeDevice:
	for d in get_tree().get_nodes_in_group("parade_device"):
		if d.kind == kind: return d
	return null
func actor(kind: String) -> ParadeActor:
	for a in get_tree().get_nodes_in_group("parade_actor"):
		if a.kind == kind: return a
	return null
func begin(at: Vector2, center: Vector2, scale: float = 1.0) -> void:
	await new_stage(Stage.Which.PARADE)
	for e in get_tree().get_nodes_in_group("enemy"): e.set_physics_process(true)
	position_runner(at)
	Clock.reset(0)
	focus = center
	zoom = scale
	add_controls()
func still(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
func run() -> void:
	await begin(Vector2(830,270),Vector2(580,290),1.05)
	start_take("01-false-entrance")
	await shoot(device("mask").shot_position())
	drive(0)
	await seconds(1.8)
	drive(0)
	await still("01-entrance")
	await seconds(0.7)
	finish_take()
	await begin(Vector2(1580,250),Vector2(1690,260),0.96)
	start_take("02-backstage")
	await shoot(actor("stilt").shot_position())
	await shoot(device("magnet").shot_position())
	await seconds(2)
	await still("02-backstage")
	finish_take()
	await begin(Vector2(2490,278),Vector2(2690,315),1.03)
	start_take("03-parade-crossing")
	await shoot(device("turntable").shot_position())
	await shoot(device("cannon").shot_position())
	await seconds(1.7)
	await still("03-crossing")
	finish_take()
	await begin(Vector2(3510,450),Vector2(3750,310),0.96)
	start_take("04-accordion-gap")
	await shoot(actor("balloon").shot_position())
	await seconds(0.65)
	await shoot(device("accordion").shot_position())
	drive(1)
	await seconds(0.8)
	await still("04-accordion")
	await seconds(0.8)
	drive(0)
	finish_take()
	await begin(Vector2(4380,275),Vector2(4860,290),0.92)
	start_take("05-spotlight-gallery")
	await shoot(device("mirror").shot_position())
	await shoot(actor("twins").shot_position())
	await seconds(0.55)
	await shoot(device("spot").shot_position())
	await seconds(1.6)
	await still("05-gallery")
	finish_take()
	await begin(Vector2(5705,300),Vector2(5950,285),0.90)
	start_take("06-sky-wheel")
	await shoot(device("moon").shot_position())
	await seconds(1.1)
	await shoot(device("wheel").shot_position())
	await seconds(1.1)
	await still("06-finale")
	finish_take()
	var f := FileAccess.open(OUT + "takes.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps":FPS,"segments":segments,"events":marks,"frame_metrics":frame_metrics},"\t"))
	main.free()
	await frames(2)
	get_tree().quit()
