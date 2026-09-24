extends Control
## The first thing the app draws, so launch is never a black screen.
##
## Compiling main.tscn's scripts and building the stage takes a noticeable
## moment on a phone, and nothing can be drawn while it happens on the main
## thread. This scene is deliberately tiny: it paints the same backdrop as the
## start screen straight away, loads main.tscn on a worker thread, and starts
## EOS in the background so "部屋を作る" does not pay for login later.

const MAIN_SCENE := "res://src/main.tscn"

var _dots: Label = null
var _elapsed: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := TextureRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture = preload("res://assets/bg/parallax.png")
	backdrop.modulate = Color(1.12, 1.12, 1.12, 1.0)
	add_child(backdrop)
	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.90, 0.97, 1.0, 0.72)
	add_child(veil)
	var logo := Label.new()
	logo.text = "SIDE / SKY   ✦"
	logo.add_theme_font_size_override("font_size", 34)
	logo.add_theme_color_override("font_color", Color("0751a5"))
	logo.position = Vector2(54, 20)
	add_child(logo)
	_dots = Label.new()
	_dots.text = "読み込み中"
	_dots.add_theme_font_size_override("font_size", 18)
	_dots.add_theme_color_override("font_color", Color("37638d"))
	_dots.set_anchors_preset(Control.PRESET_CENTER)
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_dots)

	# Sub-threads let the scene's textures and scripts load side by side
	# instead of one after another.
	ResourceLoader.load_threaded_request(MAIN_SCENE, "", true)

func _process(delta: float) -> void:
	_elapsed += delta
	_dots.text = "読み込み中" + ".".repeat(int(_elapsed * 3.0) % 4)
	match ResourceLoader.load_threaded_get_status(MAIN_SCENE):
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			print("BOOT: main scene loaded after %d ms" % Time.get_ticks_msec())
			get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(MAIN_SCENE))
			_warm_eos_after_menu()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			# Fall back to the ordinary blocking load rather than stranding the
			# player on a loading screen.
			set_process(false)
			get_tree().change_scene_to_file(MAIN_SCENE)

## EOS login warms up once the start screen is on screen rather than during
## the load: native platform start-up competes with the loader for the main
## thread and made the loading screen last longer. It still finishes well
## before anyone reaches "部屋を作る"; ensure_ready is safe to await again from
## host_eos, which simply waits for this attempt instead of starting another.
##
## The 240-frame CI startup probe passes --ci-skip-eos: a native EOS login
## started just before that short-lived headless process exits can segfault
## while its threads shut down.
func _warm_eos_after_menu() -> void:
	if OS.get_cmdline_user_args().has("--ci-skip-eos"):
		return
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		print("BOOT: start screen shown, warming EOS at %d ms" % Time.get_ticks_msec())
		EosRuntime.ensure_ready())
