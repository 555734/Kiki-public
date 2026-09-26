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
	add_child(_company_logo())
	_dots = Label.new()
	_dots.text = tr("読み込み中")
	_dots.add_theme_font_size_override("font_size", 18)
	_dots.add_theme_color_override("font_color", Color("37638d"))
	_dots.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dots.offset_top = -64.0
	_dots.offset_bottom = -36.0
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_dots)

	# One loader thread, not sub-threads. Sub-threads compile GDScript on
	# several threads at once, and the Motorola (Vulkan) build crashed on the
	# loading screen with them; the single background thread had been stable.
	ResourceLoader.load_threaded_request(MAIN_SCENE)

## The "PRESENT SOFT" company mark, centred: a bold wordmark with a drop
## shadow, a gold rule under it, and the game's title beneath. Built from
## Labels and ColorRects only, so it costs nothing to show on the first frame.
func _company_logo() -> Control:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	var mark := Label.new()
	mark.text = "PRESENT SOFT"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 52)
	mark.add_theme_color_override("font_color", Color("0b2f63"))
	mark.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.9))
	mark.add_theme_constant_override("shadow_offset_x", 3)
	mark.add_theme_constant_override("shadow_offset_y", 3)
	mark.add_theme_color_override("font_outline_color", Color("f3c334"))
	mark.add_theme_constant_override("outline_size", 4)
	box.add_child(mark)
	var rule := ColorRect.new()
	rule.color = Color("f3c334")
	rule.custom_minimum_size = Vector2(320, 4)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	var title := Label.new()
	title.text = tr("メロスゲーム")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("37638d"))
	box.add_child(title)
	return box

func _process(delta: float) -> void:
	_elapsed += delta
	_dots.text = tr("読み込み中") + ".".repeat(int(_elapsed * 3.0) % 4)
	match ResourceLoader.load_threaded_get_status(MAIN_SCENE):
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			print("BOOT: main scene loaded after %d ms" % Time.get_ticks_msec())
			# Arm the EOS warm-up first: once the scene changes, this node is
			# out of the tree and get_tree() is null.
			_warm_eos_after_menu()
			get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(MAIN_SCENE))
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
