class_name NetPanel
extends CanvasLayer
## The screen that decides which stage and how this device is going to be used.
##
## Stage selection lives here so adding 1-2 does not replace 1-1. A fresh app
## starts on 1-1; choosing another stage reloads the current scene once so all
## terrain, enemies and scenery are rebuilt from the selected Stage data before
## the player chooses local or online play.

var main: Node2D = null
## False when this panel only offers recovery for an interrupted match.
var fresh_run: bool = true

var _status: Label = null
var _code: LineEdit = null

var _root: Control = null
var _screen_host: MarginContainer = null
var _logo: Label = null
var _stage_1_1: Button = null
var _stage_1_2: Button = null
var _stage_1_3: Button = null
var _stage_1_4: Button = null
var _stage_1_5: Button = null
var _local: Button = null
const STAGES_PER_PAGE := 3
var _stage_page: int = 0
var _stage_view: Control = null
var _swipe_active: bool = false
var _swipe_touch: bool = false
var _swipe_index: int = -1
var _swipe_start: Vector2 = Vector2.ZERO
var _swipe_consumed: bool = false
## Everything that starts or changes a connection. Greyed out together while an
## attempt is in flight, which is the whole of "do not let a second tap build a
## second session".
var _actions: Array[Button] = []
## Buttons that are disabled for a reason of their own, not because a
## connection is in flight. _on_phase re-enables everything in _actions when an
## attempt ends, and without this it would cheerfully hand a free player the
## "make a room" button back.
var _locked_actions: Array[Button] = []
static var _open_play_after_reload: bool = false
## Set by "購入済みの友達と遊ぶ": the player picked a stage they have not bought
## in order to JOIN somebody who has. They may dial a room; they may not make
## one, and they may not start it alone. Static because choosing the stage
## reloads the scene, and this has to survive that the way the stage does.
static var _join_only: bool = false

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if main != null and main.has_method("suspend_for_home"):
		main.suspend_for_home()
	# While this is up, a touch belongs to the UI. Without this the same press
	# that starts a game also shoves the runner behind the panel, because the
	# emulated mouse event goes to the button and the touch event still reaches
	# the game's input router.
	#
	# _process has to stop as well as _unhandled_input, and that is not belt and
	# braces. The desktop poll used to read p2_use, bound to the left mouse
	# button, and touch is emulated as a mouse -- so the single tap that picks a
	# mode was also firing the guardian's ability, spending 30 gauge and
	# dropping a platform on the runner's head before the game had started.
	# Suppressing only the touch path left that one wide open, because the
	# suppression is what kept _has_touch false and the poll running.
	if main != null and main.input_hub != null:
		main.input_hub.set_process_unhandled_input(false)
		main.input_hub.set_process(false)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var backdrop := TextureRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture = preload("res://assets/bg/parallax.png")
	backdrop.modulate = Color(1.12, 1.12, 1.12, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)

	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.90, 0.97, 1.0, 0.72)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(veil)

	_logo = _title("メロスゲーム   ✦", 34, Color("0751a5"))
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_logo.position = Vector2(54, 20)
	_logo.size = Vector2(310, 96)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.z_index = 5
	_root.add_child(_logo)

	_screen_host = MarginContainer.new()
	_screen_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_host.add_theme_constant_override("margin_left", 54)
	_screen_host.add_theme_constant_override("margin_top", 112)
	_screen_host.add_theme_constant_override("margin_right", 54)
	_screen_host.add_theme_constant_override("margin_bottom", 24)
	_root.add_child(_screen_host)
	if Stage.current() == Stage.Which.SEA or Stage.current() == Stage.Which.SWAMP:
		_stage_page = 1

	if _open_play_after_reload:
		_open_play_after_reload = false
		_show_play_screen()
	else:
		_show_stage_screen()

var _phase_label: Label = null
var _cancel: Button = null
## The strip across the live game that shows a host's room code. While it is
## up, _status/_phase_label/_cancel point at its widgets instead of the menu's.
var _banner: Control = null
var _banner_code: Label = null

func _clear_screen() -> void:
	for child in _screen_host.get_children():
		child.queue_free()
	_actions.clear()
	_locked_actions.clear()
	_difficulty_buttons.clear()
	_stage_1_1 = null
	_stage_1_2 = null
	_stage_1_3 = null
	_stage_1_4 = null
	_stage_1_5 = null
	_stage_view = null
	_swipe_active = false
	_local = null
	_code = null
	_phase_label = null
	_status = null
	_cancel = null

## The five stages the menu offers, in order, with the art each card shows.
##
## The pictures are rendered from the stages themselves by
## `tools/capture_stage_cards.gd` -- through a portrait window, because a card
## is twice as tall as it is wide and a centre crop of a 16:9 screenshot is a
## column of sky. That is what these used to be: 1-1 showed the bare parallax
## backdrop with no ground in it at all.
func _cards() -> Array[Dictionary]:
	return [
		{"number": "1-1", "name": "GREENFIELD PLAINS",
			"blurb": "走る・跳ぶ・助け合う最初の一歩",
			"which": Stage.Which.GREENFIELD, "accent": Color("15cf8a"),
			"art": preload("res://assets/menu/card_1_1.png")},
		{"number": "1-2", "name": "THE HOLLOW OUTSKIRTS",
			"blurb": "月明かりの村を駆け抜ける",
			"which": Stage.Which.HORROR, "accent": Color("4688ef"),
			"art": preload("res://assets/menu/card_1_2.png")},
		{"number": "1-3", "name": "THE SKYWARD RUINS",
			"blurb": "足場をつないで天空の頂へ",
			"which": Stage.Which.SKYWARD_RUINS, "accent": Color("8659e8"),
			"art": preload("res://assets/menu/card_1_3.png")},
		{"number": "1-4", "name": "THE SUNLIT COAST",
			"blurb": "岩と桟橋をつないで海の旗へ",
			"which": Stage.Which.SEA, "accent": Color("1fa7d8"),
			"art": preload("res://assets/menu/card_1_4.png")},
		{"number": "1-5", "name": "THE POISON MARSH",
			"blurb": "毒沼の足場を渡り岸の門へ",
			"which": Stage.Which.SWAMP, "accent": Color("75b72b"),
			"art": preload("res://assets/menu/card_1_5.png")},
	]

func _show_stage_screen() -> void:
	# Coming back to the list ends the "I am going to join a friend" errand.
	# Leaving it set would quietly let a free player carry a paid stage into a
	# room of their own the next time they picked one.
	_join_only = false
	_clear_screen()
	_logo.show()
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	_screen_host.add_child(box)

	box.add_child(_title("—  ステージを選択  —", 30, Color("073f89")))
	box.add_child(_title("遊ぶステージをタップ。左右にスワイプして切り替え。", 15, Color("37638d")))
	box.add_child(_spacer(8))

	var row := HBoxContainer.new()
	_stage_view = row
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)
	var cards := _cards()
	var first := _stage_page * STAGES_PER_PAGE
	for i in range(first, mini(first + STAGES_PER_PAGE, cards.size())):
		var info := cards[i]
		var card := _stage_card(info)
		row.add_child(card)
		match int(info["which"]):
			Stage.Which.GREENFIELD: _stage_1_1 = card
			Stage.Which.HORROR: _stage_1_2 = card
			Stage.Which.SKYWARD_RUINS: _stage_1_3 = card
			Stage.Which.SEA: _stage_1_4 = card
			Stage.Which.SWAMP: _stage_1_5 = card
	for i in range(STAGES_PER_PAGE - row.get_child_count()):
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
	_refresh_stage_buttons()

	var navigation := HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation.add_theme_constant_override("separation", 18)
	box.add_child(navigation)
	var previous := _button("‹  前のステージ", func() -> void: _change_stage_page(-1), false)
	previous.disabled = _stage_page == 0
	previous.custom_minimum_size = Vector2(200, 42)
	navigation.add_child(previous)
	var page_label := _title("%d–%d / %d" % [first + 1,
		mini(first + STAGES_PER_PAGE, cards.size()), cards.size()], 16, Color("073f89"))
	page_label.custom_minimum_size.x = 120
	navigation.add_child(page_label)
	var next := _button("次のステージ  ›", func() -> void: _change_stage_page(1), false)
	next.disabled = first + STAGES_PER_PAGE >= cards.size()
	next.custom_minimum_size = Vector2(200, 42)
	navigation.add_child(next)

	box.add_child(_title("カードを選ぶと、遊び方と難易度の画面へ進みます", 14, Color("416b91")))

func _change_stage_page(direction: int) -> void:
	var pages := ceili(float(_cards().size()) / STAGES_PER_PAGE)
	var destination := clampi(_stage_page + direction, 0, pages - 1)
	if destination == _stage_page:
		return
	_stage_page = destination
	_show_stage_screen()

func _input(event: InputEvent) -> void:
	if _stage_view == null or not _root.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_stage_swipe(event.position, true, event.index)
		elif _swipe_touch and event.index == _swipe_index:
			_swipe_active = false
	elif event is InputEventScreenDrag:
		if _swipe_active and _swipe_touch and event.index == _swipe_index:
			_track_stage_swipe(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _swipe_active:
			_begin_stage_swipe(event.position, false, -1)
		elif not event.pressed and not _swipe_touch:
			_swipe_active = false
	elif event is InputEventMouseMotion and _swipe_active and not _swipe_touch:
		_track_stage_swipe(event.position)

func _begin_stage_swipe(position: Vector2, touch: bool, index: int) -> void:
	if not _stage_view.get_global_rect().has_point(position):
		return
	_swipe_active = true
	_swipe_touch = touch
	_swipe_index = index
	_swipe_start = position
	_swipe_consumed = false

func _track_stage_swipe(position: Vector2) -> void:
	var distance := position.x - _swipe_start.x
	if absf(distance) < 90.0 or absf(distance) < absf(position.y - _swipe_start.y) * 1.4:
		return
	_swipe_consumed = true
	_swipe_active = false
	_change_stage_page(1 if distance < 0.0 else -1)

var _difficulty_buttons: Array[Button] = []

## 追跡者の速さ. HARD is the speed the stages were tuned at.
##
## This lives on the play screen rather than the stage screen because the
## question it answers is "how hard is THIS stage going to be", and there is
## no this-stage until one is chosen. It also reads live -- the chasers ask
## `Difficulty.chase_scale()` every frame, and the host's value is the one put
## on the room -- so setting it here, after the stage is picked and before the
## room is made, is the last moment at which it can be set at all.
func _difficulty_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)
	panel.add_child(_title("追跡者の速さ", 17, Color("073f89")))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_difficulty_buttons.clear()
	for i in Difficulty.LABELS.size():
		var b := _button(tr(Difficulty.LABELS[i]), _on_difficulty.bind(i), false)
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		_difficulty_buttons.append(b)
	panel.add_child(row)
	panel.add_child(_title("追いかけてくる敵だけが速くなります", 12, Color("416b91")))
	_refresh_difficulty()
	return panel

func _on_difficulty(value: int) -> void:
	Difficulty.set_level(value)
	_refresh_difficulty()

func _refresh_difficulty() -> void:
	for i in _difficulty_buttons.size():
		var b := _difficulty_buttons[i]
		if not is_instance_valid(b):
			continue
		var on := i == Difficulty.current()
		b.add_theme_stylebox_override("normal",
			_control_style(Color("35b7ec") if on else Color("d9f1ff"), 1.0 if on else 0.96))
		b.add_theme_color_override("font_color", Color.WHITE if on else Color("064d92"))

func _show_play_screen() -> void:
	_clear_screen()
	_logo.show()
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	_screen_host.add_child(box)
	box.add_child(_title("—  遊び方を選択  —", 28, Color("073f89")))
	box.add_child(_title("一緒に遊ぶ方法を選んでください", 14, Color("37638d")))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	box.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	var preview := _selected_stage_preview()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview)
	left.add_child(_difficulty_panel())
	body.add_child(left)

	var play_card := PanelContainer.new()
	play_card.custom_minimum_size = Vector2(570, 0)
	play_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_card.add_theme_stylebox_override("panel", _panel_style())
	body.add_child(play_card)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	play_card.add_child(margin)
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	margin.add_child(choices)

	choices.add_child(_title("この1台で一緒に遊ぶ", 20, Color("073f89")))
	_local = _button("▶  この1台で 2人プレイを始める", _on_local)
	_local.custom_minimum_size.y = 54
	choices.add_child(_local)
	choices.add_child(_title("オンラインで離れて遊ぶ", 20, Color("073f89")))
	_code = _field("ルーム番号（6桁）")
	_code.max_length = EosCoopLobby.CODE_LENGTH
	_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	# The iOS number pad has no return key, so a finished code closes the
	# keyboard by itself instead of trapping the player behind it.
	_code.text_changed.connect(_on_code_changed)
	_code.text_submitted.connect(func(_t: String) -> void: _on_join_eos())
	choices.add_child(_code)
	var online_row := HBoxContainer.new()
	online_row.add_theme_constant_override("separation", 10)
	var host := _button("＋  部屋を作る", _on_host_eos)
	var join := _button("→  ルームに入る", _on_join_eos)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	online_row.add_child(host)
	online_row.add_child(join)
	choices.add_child(online_row)

	# A free player who came here through "購入済みの友達と遊ぶ" may dial a room
	# and may not make one. Both halves are disabled rather than hidden: the
	# player needs to see that the buttons exist and why they are not theirs to
	# press yet, or the screen just looks broken.
	if not Entitlement.can_host(Stage.current()):
		_locked_actions.append(_local)
		_locked_actions.append(host)
		_local.disabled = true
		host.disabled = true
		choices.add_child(_title(
			"このステージは完全版です。完全版を持っている友達に部屋を作ってもらい、\n"
			+ "その6桁を入れて「ルームに入る」を押してください。", 13, Color("416b91")))

	_cancel = _button("接続をやめる", _on_cancel, false)
	_cancel.visible = false
	choices.add_child(_cancel)
	_phase_label = _title("", 13, Color("08796e"))
	choices.add_child(_phase_label)
	_status = _title("", 13, Color("264c70"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 34
	choices.add_child(_status)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	var back := _button("‹  もどる", _show_stage_screen, false)
	var layout := _button("ボタン配置", _on_layout, false)
	footer.add_child(back)
	# Internet versus still uses the retired Cloudflare relay. Keep its release
	# entry hidden until the separate EOS versus migration is complete.
	footer.add_child(layout)
	if OS.has_feature("editor"):
		footer.add_child(_button("接続記録", _on_diagnose, false))
	box.add_child(footer)

	# The panel renders the connection owner's state; it does not invent a
	# second version of whether a room is connected.
	if main != null and main.link != null:
		if not main.link.phase_changed.is_connected(_on_phase):
			main.link.phase_changed.connect(_on_phase)
		_on_phase(main.link.phase, "")

func _stage_card(info: Dictionary) -> Button:
	var number: String = info["number"]
	var accent: Color = info["accent"]
	var which: int = int(info["which"])
	var button := Button.new()
	button.text = number
	button.custom_minimum_size = Vector2(0, 350)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.add_theme_font_size_override("font_size", 1)
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_stylebox_override("normal", _stage_style(Color.WHITE, 0.94, 18, 2))
	button.add_theme_stylebox_override("hover", _stage_style(accent, 0.28, 18, 4))
	button.add_theme_stylebox_override("pressed", _stage_style(accent, 0.42, 18, 4))
	button.pressed.connect(func() -> void:
		if not _swipe_consumed:
			_select_stage(which))
	_actions.append(button)

	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = info["art"]
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Leave the button's coloured selection rim visible around the artwork.
	art.offset_left = 5
	art.offset_top = 5
	art.offset_right = -5
	art.offset_bottom = -5
	button.add_child(art)

	# A ramp rather than a bar. The flat panel that used to sit here cut the
	# picture in half along a hard horizontal line, which read as two images
	# stacked rather than as one card with writing on it.
	button.add_child(_scrim(152, false))
	button.add_child(_scrim(72, true))

	var caption := VBoxContainer.new()
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 12
	caption.offset_right = -12
	caption.offset_top = -116
	caption.offset_bottom = -12
	caption.alignment = BoxContainer.ALIGNMENT_END
	caption.add_theme_constant_override("separation", 2)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading := _title(number, 22, accent)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.add_theme_color_override("font_outline_color", Color(0, 0.06, 0.12, 0.9))
	heading.add_theme_constant_override("outline_size", 6)
	caption.add_child(heading)
	var stage_title := _title(String(info["name"]), 13, Color.WHITE)
	stage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stage_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_child(stage_title)
	var blurb := _title(tr(String(info["blurb"])), 11, Color("c8dced"))
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_child(blurb)
	button.add_child(caption)

	var badge := _title("✓", 32, accent)
	badge.position = Vector2(18, 10)
	badge.size = Vector2(100, 50)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge.add_theme_color_override("font_outline_color", Color.WHITE)
	badge.add_theme_constant_override("outline_size", 7)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)
	# The lock is built for every card and shown only where it belongs, so
	# _refresh_stage_buttons can turn it on and off after a purchase without
	# rebuilding the screen.
	var lock_shade := ColorRect.new()
	lock_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock_shade.offset_left = 5
	lock_shade.offset_top = 5
	lock_shade.offset_right = -5
	lock_shade.offset_bottom = -5
	lock_shade.color = Color(0.04, 0.12, 0.22, 0.52)
	lock_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(lock_shade)
	var lock := _title("🔒", 30, Color(1, 1, 1, 0.94))
	lock.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lock.offset_top = 92
	lock.offset_bottom = 148
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(lock)

	button.set_meta("which", which)
	button.set_meta("accent", accent)
	button.set_meta("badge", badge)
	button.set_meta("lock", [lock_shade, lock])
	return button

## A soft vertical fade, used to sit writing on top of artwork without
## putting a hard edge across it. `top` flips it to darken the top instead,
## which is what keeps the ✓ readable over a bright sky.
func _scrim(height: int, top: bool) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.012, 0.055, 0.115, 0.0))
	gradient.set_color(1, Color(0.012, 0.055, 0.115, 0.90 if not top else 0.42))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 64
	texture.fill_from = Vector2(0, 0) if not top else Vector2(0, 1)
	texture.fill_to = Vector2(0, 1) if not top else Vector2(0, 0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top:
		rect.set_anchors_preset(Control.PRESET_TOP_WIDE)
		rect.offset_top = 5
		rect.offset_bottom = float(height)
	else:
		rect.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		rect.offset_top = -float(height)
		rect.offset_bottom = -5
	rect.offset_left = 5
	rect.offset_right = -5
	return rect

func _selected_stage_preview() -> PanelContainer:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(0, 240)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.clip_contents = true
	var stage_info := _selected_stage_info()
	var accent: Color = stage_info["accent"]
	preview.add_theme_stylebox_override("panel", _stage_style(accent, 0.96, 18, 3))
	# A PanelContainer stretches its children to fill, which throws away any
	# anchors they set -- that is why the caption used to sit in the middle of
	# the picture. One filling Control, and everything anchors inside that.
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(layer)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = stage_info["art"]
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(art)
	layer.add_child(_scrim(108, false))
	var label := _title(tr("選択中  %s\n%s") % [stage_info["number"], stage_info["name"]],
		18, Color.WHITE)
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -74
	label.offset_bottom = -10
	label.add_theme_color_override("font_outline_color", Color("07325f"))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	return preview

func _selected_stage_info() -> Dictionary:
	var all := _cards()
	for info in all:
		if int(info["which"]) == Stage.current():
			return info
	return all[0]

## Stage buttons are selection, not launch. Rebuilding by reloading the current
## scene guarantees every stage-owned object uses the same Stage value; trying
## to swap only terrain in place is how scenery, enemies and checkpoints drift.
func _select_stage(which: int) -> void:
	if main != null and main.link != null and main.link.busy():
		return
	# A stage this player has not bought does not open the play screen; it
	# opens the three doors. _join_only is what the middle door sets, and it is
	# the one way a free player gets past this line onto a paid stage.
	if not Entitlement.can_play(which) and not _join_only:
		_show_purchase(which)
		return
	if Stage.current() == which:
		_show_play_screen()
		return
	Stage.use(which)
	if main != null:
		_open_play_after_reload = true
		get_tree().reload_current_scene()
	else:
		_show_play_screen()

var _purchase: PurchasePanel = null

func _show_purchase(which: int) -> void:
	if _purchase != null and is_instance_valid(_purchase):
		return
	var info := _card_for(which)
	_purchase = PurchasePanel.new()
	_purchase.stage_number = String(info.get("number", ""))
	_purchase.stage_name = String(info.get("name", ""))
	_purchase.price_text = Iap.price_text()
	_purchase.closed.connect(func() -> void: _purchase = null)
	_purchase.buy_requested.connect(_on_buy)
	_purchase.restore_requested.connect(_on_restore)
	_purchase.join_requested.connect(func() -> void: _on_join_as_guest(which))
	_root.add_child(_purchase)
	if not Iap.available():
		_purchase.say(tr("このビルドではストアに接続できません。")
			+ tr("購入済みの友達の部屋には、このままでも入れます。"))

## The middle door. It does not unlock anything -- it lets the player carry a
## stage they cannot host as far as the room-code field, where the unlock will
## arrive from the person who did buy it. If nobody answers, they have taken
## nothing they should not have.
func _on_join_as_guest(which: int) -> void:
	_join_only = true
	if _purchase != null and is_instance_valid(_purchase):
		_purchase.queue_free()
		_purchase = null
	_select_stage(which)

func _on_buy() -> void:
	if _purchase == null or not is_instance_valid(_purchase):
		return
	if not Iap.available():
		_purchase.say("このビルドではストアに接続できません。")
		return
	_purchase.set_busy(true)
	_purchase.say("ストアに接続しています…")
	var result: String = await Iap.purchase()
	_after_store(result)

func _on_restore() -> void:
	if _purchase == null or not is_instance_valid(_purchase):
		return
	if not Iap.available():
		_purchase.say("このビルドではストアに接続できません。")
		return
	_purchase.set_busy(true)
	_purchase.say("購入履歴を確認しています…")
	var result: String = await Iap.restore()
	_after_store(result)

func _after_store(error: String) -> void:
	if _purchase == null or not is_instance_valid(_purchase):
		return
	_purchase.set_busy(false)
	if error.is_empty() and Entitlement.unlocked():
		_purchase.queue_free()
		_purchase = null
		_join_only = false
		_refresh_stage_buttons()
		return
	_purchase.say(error if not error.is_empty()
		else "購入が見つかりませんでした。別のアカウントで購入した場合は、"
			+ "そのアカウントでストアにログインしてからもう一度お試しください。")

func _card_for(which: int) -> Dictionary:
	for info in _cards():
		if int(info["which"]) == which:
			return info
	return {}

func _refresh_stage_buttons() -> void:
	for button in [_stage_1_1, _stage_1_2, _stage_1_3, _stage_1_4, _stage_1_5]:
		if button == null:
			continue
		var which: int = int(button.get_meta("which"))
		var selected: bool = which == Stage.current()
		var accent: Color = button.get_meta("accent")
		var badge: Label = button.get_meta("badge")
		badge.visible = selected
		# A locked card is still a button: tapping it is how the player finds
		# out what it would take to play, which is the whole point of putting
		# the three doors behind it rather than greying it out and saying no.
		var locked: bool = not Entitlement.can_play(which)
		for node in (button.get_meta("lock") as Array):
			(node as CanvasItem).visible = locked
		button.add_theme_stylebox_override("normal",
			_stage_style(accent if selected else Color.WHITE, 0.30 if selected else 0.94,
				18, 5 if selected else 2))
	if _local != null:
		_local.disabled = _locked_actions.has(_local)

## Everything the player sees about the connection comes through here.
func _on_phase(phase: int, detail: String) -> void:
	if not is_instance_valid(self) or _phase_label == null:
		return
	var busy: bool = main.link.busy()
	for b in _actions:
		if is_instance_valid(b):
			b.disabled = busy or _locked_actions.has(b)
	_cancel.visible = busy
	_phase_label.text = tr(NetLink.LABELS.get(phase, ""))
	if not detail.is_empty():
		_phase_label.text += "  （%s）" % detail
	if _banner != null:
		_on_banner_phase(phase, detail)
		return
	match phase:
		NetLink.Phase.DIALLING:
			_status.text = "EOSに接続しています…"
		NetLink.Phase.WAITING_PEER:
			if main.link.desired_role == "host":
				_status.text = tr("ルーム番号：%s\n相手にこの6桁を伝えてください。") % main.link.room_code
			elif detail.is_empty():
				_status.text = "部屋に入りました。ホストの応答を待っています…"
			else:
				_failed("このルーム番号の部屋には、まだ誰もいません。\n"
					+ "・相手が『部屋を作る』を押しているか\n"
					+ "・6桁の番号が一つも違っていないか\n"
					+ "を確かめてください")
		NetLink.Phase.HANDSHAKING:
			_status.text = "相手が来ました。ゲームを始められるか確認しています…"
		NetLink.Phase.PLAYING:
			# Both roles close the screen at the same moment, and it is the
			# right moment: the host has answered, so a build mismatch has
			# already been refused and said so.
			queue_free()
		NetLink.Phase.RECONNECTING:
			_status.text = "接続が切れました。つなぎ直しています…"
		NetLink.Phase.FAILED:
			if _status.text.is_empty():
				_failed("接続できませんでした：" + detail)

func _on_cancel() -> void:
	main._end_any_session()
	# A room still being made has no session to end yet; the attempt notices
	# and cleans up its lobby when its EOS call returns.
	if main.link.busy():
		main.link.finish()
	_close_banner()
	_status.text = "接続をやめました。もう一度選んでください。"

# ---------------------------------------------------------------- room banner

## Shown the instant "部屋を作る" is pressed: the menu gives way to the stage
## itself, and a strip across the middle carries the room code while EOS
## finishes making the room behind it.
func _show_banner() -> void:
	if _banner != null:
		return
	_root.hide()
	# The world stays suspended; only the 3D view is allowed to run so its
	# camera lines up with the stage and there is something to look at.
	var world := main.get_node_or_null("World3D") if main != null else null
	if world != null:
		world.process_mode = Node.PROCESS_MODE_ALWAYS
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var strip := PanelContainer.new()
	strip.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	strip.anchor_top = 0.5
	strip.anchor_bottom = 0.5
	strip.offset_top = -110
	strip.offset_bottom = 110
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.20, 0.40, 0.82)
	style.border_color = Color(0.41, 0.82, 0.95, 0.9)
	style.border_width_top = 2
	style.border_width_bottom = 2
	strip.add_theme_stylebox_override("panel", style)
	_banner.add_child(strip)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	strip.add_child(box)
	box.add_child(_title("ルーム番号", 16, Color("9fe3f7")))
	_banner_code = _title(_spaced(main.link.room_code), 56, Color.WHITE)
	box.add_child(_banner_code)
	_status = _title("準備中…", 15, Color("e8f4fb"))
	box.add_child(_status)
	_phase_label = _title("", 12, Color("9fe3f7"))
	box.add_child(_phase_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_cancel = _button("やめる", _on_cancel, false)
	_cancel.custom_minimum_size = Vector2(180, 44)
	row.add_child(_cancel)
	_on_phase(main.link.phase, "")

## Back to the menu, e.g. after "やめる" or a failure. Safe to call twice.
func _close_banner() -> void:
	if _banner == null:
		return
	_banner.queue_free()
	_banner = null
	_banner_code = null
	var world := main.get_node_or_null("World3D") if main != null else null
	if world != null:
		world.process_mode = Node.PROCESS_MODE_INHERIT
	_root.show()
	_show_play_screen()

func _on_banner_phase(phase: int, detail: String) -> void:
	_cancel.visible = true
	_phase_label.text = tr(NetLink.LABELS.get(phase, ""))
	match phase:
		NetLink.Phase.DIALLING:
			_status.text = tr("準備中…（番号はもう決まっています）")
		NetLink.Phase.WAITING_PEER:
			_status.text = "相手にこの6桁を伝えてください。"
		NetLink.Phase.HANDSHAKING:
			_status.text = "相手が来ました。ゲームを始められるか確認しています…"
		NetLink.Phase.PLAYING:
			queue_free()
		NetLink.Phase.RECONNECTING:
			_status.text = "接続が切れました。つなぎ直しています…"
		NetLink.Phase.FAILED:
			_close_banner()
			_failed("接続できませんでした：" + detail)

func _process(_delta: float) -> void:
	# The code can change once after it is shown (a rare clash with another
	# live room), so the strip reads it rather than being told.
	if _banner_code != null and main != null:
		var shown := _spaced(main.link.room_code)
		if _banner_code.text != shown:
			_banner_code.text = shown

static func _spaced(code: String) -> String:
	if code.is_empty():
		code = "------"
	var out := PackedStringArray()
	for i in code.length():
		out.append(code[i])
	return " ".join(out)

func _exit_tree() -> void:
	if main != null and is_instance_valid(main) and main.input_hub != null:
		main.input_hub.set_process_unhandled_input(true)
		main.input_hub.set_process(true)
		if main.has_method("resume_from_home"):
			var local_start: bool = fresh_run \
				and main.host_session == null and main.client_session == null
			main.resume_from_home(local_start)

func _title(text: String, size: int, colour: Color) -> Label:
	return heading(text, size, colour)

## The same label, callable from another screen. PurchasePanel is a separate
## file precisely so the store lives in one place, and it has to be able to
## look like it belongs to this one -- a purchase screen in a different visual
## language reads as bolted on.
static func heading(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = TranslationServer.translate(text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	var f := Art.font()
	if f != null:
		l.add_theme_font_override("font", f)
	return l

func _field(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = tr(placeholder)
	e.custom_minimum_size = Vector2(0, 42)
	e.add_theme_font_size_override("font_size", 16)
	e.add_theme_color_override("font_color", Color("123f70"))
	e.add_theme_color_override("font_placeholder_color", Color("8aa5bc"))
	e.add_theme_stylebox_override("normal", _control_style(Color("eaf4fb"), 0.94, 10))
	e.add_theme_stylebox_override("focus", _control_style(Color("bce7fb"), 1.0, 10))
	return e

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _section_title(kicker: String, text: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 1)
	section.add_child(_title(kicker, 11, Color("69d2f1")))
	section.add_child(_title(text, 17, Color("e8f4fb")))
	return section

func _panel_style() -> StyleBoxFlat:
	return panel_style()

static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.90)
	style.border_color = Color(0.50, 0.72, 0.88, 0.50)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.05, 0.30, 0.52, 0.20)
	style.shadow_size = 12
	return style

func _stage_style(colour: Color, alpha: float, radius: int, border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colour.r, colour.g, colour.b, alpha)
	style.border_color = colour
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = border
	style.content_margin_top = border
	style.content_margin_right = border
	style.content_margin_bottom = border
	style.shadow_color = Color(0.05, 0.30, 0.52, 0.22)
	style.shadow_size = 12
	return style

func _control_style(colour: Color, alpha: float, radius: int = 12) -> StyleBoxFlat:
	return control_style(colour, alpha, radius)

static func control_style(colour: Color, alpha: float, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colour.r, colour.g, colour.b, alpha)
	style.border_color = Color(colour.r, colour.g, colour.b, minf(1.0, alpha + 0.35))
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style

func _stage_button(text: String, handler: Callable, colour: Color) -> Button:
	var button := _button(text, handler)
	button.custom_minimum_size = Vector2(0, 104)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _control_style(colour, 0.18, 16))
	button.add_theme_stylebox_override("hover", _control_style(colour, 0.34, 16))
	button.add_theme_stylebox_override("pressed", _control_style(colour, 0.46, 16))
	return button

## Deliberately large: this is a phone held sideways, and the first thing anyone
## touches should not need aiming.
##
## `guarded` buttons are the ones that start a connection or switch a stage.
## They are disabled for as long as one connection attempt is running.
func _button(text: String, handler: Callable, guarded: bool = true) -> Button:
	var b := action_button(text, handler)
	if guarded:
		_actions.append(b)
	return b

## Without the guarded list, which is this panel's own bookkeeping.
static func action_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = TranslationServer.translate(text)
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color("064d92"))
	b.add_theme_stylebox_override("normal", control_style(Color("d9f1ff"), 0.96))
	b.add_theme_stylebox_override("hover", control_style(Color("86dcf4"), 1.0))
	b.add_theme_stylebox_override("pressed", control_style(Color("4ecbdc"), 1.0))
	var f := Art.font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.pressed.connect(handler)
	return b

func _on_local() -> void:
	queue_free()

## Runs every step of the connection on this device and prints what each one
## did. Offered up front rather than buried, because "つながりません" on its own
## has never been enough to tell a blocked port from a wrong URL from a Wi-Fi
## that quietly drops WebSocket upgrades.
## Hands differ and so do phones. The defaults are a guess; this is where the
## guess gets corrected.
# ------------------------------------------------------------------ たいせん
func _on_layout() -> void:
	add_child(load("res://src/ui/layout_editor.gd").new())

func _on_diagnose() -> void:
	var panel = load("res://src/ui/net_diagnostics.gd").new()
	panel.relay = ""
	add_child(panel)

## Anything that goes wrong offers the report rather than making the player go
## and find it.
func _failed(message: String) -> void:
	_status.text = tr(message)
	if OS.has_feature("editor"):
		_status.text += tr("\n\n下の「接続診断」を押すと、原因を調べて\nコピーできる記録を出します。")
	else:
		_status.text += tr("\n\n通信を確認して、もう一度お試しください。")

func _on_code_changed(text: String) -> void:
	var digits := ""
	for i in text.length():
		if text[i] >= "0" and text[i] <= "9":
			digits += text[i]
	digits = digits.substr(0, EosCoopLobby.CODE_LENGTH)
	if digits != text:
		_code.text = digits
		_code.caret_column = digits.length()
	if digits.length() == EosCoopLobby.CODE_LENGTH:
		_close_keyboard()
		if _status != null and not main.link.busy():
			_status.text = "番号がそろいました。「ルームに入る」を押してください"

func _close_keyboard() -> void:
	if _code != null and is_instance_valid(_code) and _code.has_focus():
		_code.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

## A tap anywhere off the field puts the keyboard away. Watched in _input so
## it works over cards and panels that would swallow the press themselves.
func _input(event: InputEvent) -> void:
	if _code == null or not is_instance_valid(_code) or not _code.has_focus():
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed and not _code.get_global_rect().has_point(event.position):
		_close_keyboard()

func _on_host_eos() -> void:
	_close_keyboard()
	# The button is already disabled when this is true; this is the second
	# lock, on the path rather than on the widget, so a UI that gets rebuilt
	# in some order nobody thought of cannot put a paid room on the wire.
	if not Entitlement.can_host(Stage.current()):
		_failed("このステージの部屋を作るには完全版が必要です。")
		return
	# host_eos puts the code on the link before its first EOS call; the strip
	# reads it from there, so it can go up before anything is awaited.
	_show_banner()
	var err: String = await main.host_eos()
	if err == main.CANCELLED:
		# _on_cancel has already put the menu back, and a newer attempt may
		# own the strip by now.
		return
	if err != "":
		_close_banner()
		_failed("失敗：" + err)
		return
	_wait_for_handshake(main.host_session)

func _on_join_eos() -> void:
	_close_keyboard()
	var code := _code.text.strip_edges()
	if not EosCoopLobby.valid_code(code):
		_status.text = "ルーム番号は6桁の数字で入力してください"
		return
	var err: String = await main.join_eos(code)
	if err != "":
		_failed("失敗：" + err)
		return
	_wait_for_handshake(main.client_session)

## The joining device closes this screen only once the HOST has answered, not
## merely once the two devices can see each other.
##
## They are different moments and the gap between them is where the failures
## live. A build mismatch is refused during the handshake, and the refusal used
## to arrive after this screen had already closed -- so it flashed across the
## HUD for about a second, over a game that was never going to start, and what
## the player saw was a frozen world with no explanation.
func _wait_for_handshake(session: Node) -> void:
	if session == null:
		return
	# Whatever the host says while we are still waiting belongs on this screen
	# rather than flashed over a game that is not going to start -- a build
	# mismatch is refused during the handshake and this is where it lands.
	Events.notice.connect(func(text: String) -> void:
		if is_instance_valid(self):
			_failed(text))

## A saved relay wins over the built-in default, so pointing at a different
## deployment survives a restart.
