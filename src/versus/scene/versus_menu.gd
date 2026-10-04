class_name VersusMenu
extends VBoxContainer
## Real buttons for what the keyboard did before: start, play again, leave.
## A phone has no R and no Esc, and a mode you cannot start or leave from the
## screen is not a mode a phone can play.

var arena = null
var start_button: Button = null
var again_button: Button = null
var leave_button: Button = null

func _init(owner_arena) -> void:
	arena = owner_arena
	name = "VersusMenu"
	add_theme_constant_override("separation", 10)
	custom_minimum_size = Vector2(300, 0)
	start_button = _button("スタート", arena.start_match)
	again_button = _button("もういちど", arena.rematch)
	leave_button = _button("やめる", arena.request_leave)

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(handler)
	add_child(b)
	return b

func refresh() -> void:
	var over: bool = arena.phase() == VersusMatch.Phase.OVER
	var pre: bool = arena.waiting()
	start_button.visible = pre and arena.is_host()
	start_button.disabled = not arena.can_start()
	again_button.visible = over and arena.is_host()
	# Runners have their own 戻る circle during play; a guardian has none.
	var broken: bool = not arena.link_error().is_empty()
	# Always there: the old 戻る circle went with the attack and build buttons.
	leave_button.visible = true
	var view: Vector2 = arena.get_viewport_rect().size
	var shown := 0
	for b in [start_button, again_button, leave_button]:
		if b.visible:
			shown += 1
	size = Vector2(300, shown * 66)
	if pre or over or broken:
		custom_minimum_size = Vector2(300, 0)
		leave_button.custom_minimum_size = Vector2(300, 56)
		position = Vector2(view.x * 0.5 - 150.0, view.y * 0.5 + 90.0)
	else:
		# Top left during play, clear of the stick and of the scoreboard.
		custom_minimum_size = Vector2(130, 0)
		leave_button.custom_minimum_size = Vector2(130, 44)
		size = Vector2(130, 44)
		position = Vector2(16.0, 12.0)
	visible = shown > 0
