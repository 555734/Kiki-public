extends Control
## The title screen is ready immediately while the playable scene loads behind it.
##
## Compiling main.tscn's scripts and building the stage takes a noticeable
## moment on a phone, and nothing can be drawn while it happens on the main
## thread. Keep this scene small, let the player see the game title, and enable
## Start only once the next scene is ready.

const MAIN_SCENE := "res://src/main.tscn"

var _dots: Label = null
var _elapsed: float = 0.0
var _start: Button = null
var _main_scene: PackedScene = null
var _load_failed: bool = false

func _ready() -> void:
	# Japanese remains the source language. All other device locales use the
	# English catalog, including locales for which we do not ship a catalog yet.
	if not OS.get_locale_language().begins_with("ja"):
		TranslationServer.set_locale("en")
	# Once, at the top of the boot screen, before anything is drawn.
	Engine.max_fps = Balance.target_fps()
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
	add_child(_title_content())
	_dots = Label.new()
	_dots.text = tr("冒険の準備をしています…")
	_dots.add_theme_font_size_override("font_size", 18)
	_dots.add_theme_color_override("font_color", Color("37638d"))
	_dots.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dots.offset_top = -54.0
	_dots.offset_bottom = -26.0
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_dots)

	# One loader thread, not sub-threads. Sub-threads compile GDScript on
	# several threads at once, and the Motorola (Vulkan) build crashed on the
	# loading screen with them; the single background thread had been stable.
	ResourceLoader.load_threaded_request(MAIN_SCENE)

## A real first screen rather than a publisher splash. It stays until Start is
## tapped, giving the background load time to finish without a scene change.
func _title_content() -> Control:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	var rule := ColorRect.new()
	rule.color = Color("f3c334")
	rule.custom_minimum_size = Vector2(280, 5)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	var title := Label.new()
	title.text = tr("メロスゲーム")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("0751a5"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = tr("走る人と、世界を描く人。ふたりで越える冒険。")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("37638d"))
	box.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	box.add_child(gap)
	_start = Button.new()
	_start.text = tr("ゲームを始める")
	_start.disabled = true
	_start.custom_minimum_size = Vector2(320, 64)
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start.add_theme_font_size_override("font_size", 24)
	_start.pressed.connect(_on_start_pressed)
	box.add_child(_start)
	return box

func _process(delta: float) -> void:
	if _main_scene != null or _load_failed:
		return
	_elapsed += delta
	_dots.text = tr("冒険の準備をしています…") + ".".repeat(int(_elapsed * 3.0) % 4)
	match ResourceLoader.load_threaded_get_status(MAIN_SCENE):
		ResourceLoader.THREAD_LOAD_LOADED:
			_main_scene = ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene
			print("BOOT: main scene loaded after %d ms" % Time.get_ticks_msec())
			if _main_scene != null:
				_start.disabled = false
				_dots.text = tr("タップして始める")
				set_process(false)
			else:
				_show_load_failure()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_show_load_failure()

func _show_load_failure() -> void:
	_load_failed = true
	_start.text = tr("もう一度試す")
	_start.disabled = false
	_dots.text = tr("読み込みに失敗しました")
	set_process(false)

func _on_start_pressed() -> void:
	if _load_failed:
		_start.disabled = true
		_dots.text = tr("冒険の準備をしています…")
		_main_scene = load(MAIN_SCENE) as PackedScene
		if _main_scene == null:
			_show_load_failure()
			return
	if _main_scene == null:
		return
	_start.disabled = true
	_warm_eos_after_menu()
	get_tree().change_scene_to_packed(_main_scene)

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
