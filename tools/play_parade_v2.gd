extends Node
## Direct local play entry. This uses the actual production stage and UI.
var main: Node2D
func _ready() -> void:
	TranslationServer.set_locale("en")
	Stage.use(Stage.Which.PARADE)
	Clock.is_host = true
	Clock.set_physics_process(true)
	main = preload("res://src/main.tscn").instantiate()
	add_child(main)
	main.get_node("NetPanel").free()
	main.input_hub.solo_role = ""
	main.input_hub.set_listening(true)
	main.input_hub.set_process(true)
	DisplayServer.window_set_title("MELOS - THE TRICKSTER PARADE / 1-9")
	if "--smoke" in OS.get_cmdline_user_args():
		for i in 20: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/promotion/stage-1-9/playable-v2/play-start.png")
		print("PARADE_PLAY input=",main.input_hub.is_listening()," clock=",Clock.is_physics_processing()," home=",main._home_active)
		main.free()
		await get_tree().process_frame
		get_tree().quit()
	# Chapter jumps are a local review convenience, never part of the game.
	if "--review-zone" in OS.get_cmdline_user_args():
		var args := OS.get_cmdline_user_args()
		var index := args.find("--review-zone")
		if index + 1 < args.size():
			var n := clampi(int(args[index+1]),1,6)
			if n > 1: main.runner.respawn(Stage.checkpoints()[n-2])
