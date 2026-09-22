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
var _relay: LineEdit = null
var _code: LineEdit = null

var _root: Control = null
var _screen_host: MarginContainer = null
var _logo: Label = null
var _stage_1_1: Button = null
var _stage_1_2: Button = null
var _local: Button = null
## Everything that starts or changes a connection. Greyed out together while an
## attempt is in flight, which is the whole of "do not let a second tap build a
## second session".
var _actions: Array[Button] = []
static var _open_play_after_reload: bool = false

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

	_logo = _title("SIDE / SKY   ✦", 34, Color("0751a5"))
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

	if _open_play_after_reload:
		_open_play_after_reload = false
		_show_play_screen()
	else:
		_show_stage_screen()

var _phase_label: Label = null
var _cancel: Button = null

func _clear_screen() -> void:
	for child in _screen_host.get_children():
		child.queue_free()
	_actions.clear()
	_stage_1_1 = null
	_stage_1_2 = null
	_local = null
	_relay = null
	_code = null
	_phase_label = null
	_status = null
	_cancel = null

func _show_stage_screen() -> void:
	_clear_screen()
	_logo.show()
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	_screen_host.add_child(box)

	box.add_child(_title("—  ステージを選択  —", 30, Color("073f89")))
	box.add_child(_title("遊ぶステージをタップしてください", 15, Color("37638d")))
	box.add_child(_spacer(8))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)
	_stage_1_1 = _stage_card(
		"1-1", "GREENFIELD PLAINS", "走る・跳ぶ・助け合う最初のステージ",
		preload("res://assets/bg/parallax.png"), Stage.Which.GREENFIELD, Color("15cf8a"))
	_stage_1_2 = _stage_card(
		"1-2", "THE HOLLOW OUTSKIRTS", "月明かりの村を駆け抜ける追跡ステージ",
		preload("res://assets/bg/horror_stage_1_2.svg"), Stage.Which.HORROR, Color("4688ef"))
	row.add_child(_stage_1_1)
	row.add_child(_stage_1_2)
	_refresh_stage_buttons()

	box.add_child(_title("カードを選ぶと、遊び方の画面へ進みます", 14, Color("416b91")))

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
	body.add_child(_selected_stage_preview())

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
	_relay = _field("接続先URL")
	_relay.text = Balance.DEFAULT_RELAY
	choices.add_child(_relay)
	_code = _field("ルーム番号（6桁）")
	_code.max_length = WebSocketTransport.CODE_LENGTH
	_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	choices.add_child(_code)
	var online_row := HBoxContainer.new()
	online_row.add_theme_constant_override("separation", 10)
	var host := _button("＋  部屋を作る", _on_host_relay)
	var join := _button("→  ルームに入る", _on_join_relay)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	online_row.add_child(host)
	online_row.add_child(join)
	choices.add_child(online_row)
	_load_settings()

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
	var versus := _button("1対1 コイン対戦／チーム戦", _on_versus, false)
	var layout := _button("ボタン配置", _on_layout, false)
	var diagnose := _button("接続診断", _on_diagnose, false)
	versus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(back)
	footer.add_child(versus)
	footer.add_child(layout)
	footer.add_child(diagnose)
	box.add_child(footer)

	# The panel renders the connection owner's state; it does not invent a
	# second version of whether a room is connected.
	if main != null and main.link != null:
		if not main.link.phase_changed.is_connected(_on_phase):
			main.link.phase_changed.connect(_on_phase)
		_on_phase(main.link.phase, "")

func _stage_card(number: String, stage_name: String, description: String,
		texture: Texture2D, which: int, accent: Color) -> Button:
	var button := Button.new()
	button.text = number
	button.custom_minimum_size = Vector2(0, 390)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.add_theme_font_size_override("font_size", 1)
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_stylebox_override("normal", _stage_style(Color.WHITE, 0.94, 18, 2))
	button.add_theme_stylebox_override("hover", _stage_style(accent, 0.28, 18, 4))
	button.add_theme_stylebox_override("pressed", _stage_style(accent, 0.42, 18, 4))
	button.pressed.connect(func() -> void: _select_stage(which))
	_actions.append(button)

	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Leave the button's coloured selection rim visible around the artwork.
	art.offset_left = 5
	art.offset_top = 5
	art.offset_right = -5
	art.offset_bottom = -5
	button.add_child(art)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -106
	shade.offset_bottom = 0
	shade.color = Color(0.015, 0.09, 0.18, 0.76)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(shade)
	var caption := _title("%s   %s\n%s" % [number, stage_name, description], 16, Color.WHITE)
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -94
	caption.offset_bottom = -8
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)
	var badge := _title("✓", 32, accent)
	badge.position = Vector2(18, 14)
	badge.size = Vector2(100, 50)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge.add_theme_color_override("font_outline_color", Color.WHITE)
	badge.add_theme_constant_override("outline_size", 7)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)
	button.set_meta("which", which)
	button.set_meta("accent", accent)
	button.set_meta("badge", badge)
	return button

func _selected_stage_preview() -> PanelContainer:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(500, 0)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.clip_contents = true
	var accent := Color("4688ef") if Stage.current() == Stage.Which.HORROR else Color("15cf8a")
	preview.add_theme_stylebox_override("panel", _stage_style(accent, 0.96, 18, 3))
	var art := TextureRect.new()
	art.texture = preload("res://assets/bg/horror_stage_1_2.svg") \
		if Stage.current() == Stage.Which.HORROR else preload("res://assets/bg/parallax.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.add_child(art)
	var label := _title(
		"選択中  1-2\nTHE HOLLOW OUTSKIRTS" if Stage.current() == Stage.Which.HORROR \
		else "選択中  1-1\nGREENFIELD PLAINS", 18, Color.WHITE)
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -76
	label.offset_bottom = -10
	label.add_theme_color_override("font_outline_color", Color("07325f"))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(label)
	return preview

## Stage buttons are selection, not launch. Rebuilding by reloading the current
## scene guarantees every stage-owned object uses the same Stage value; trying
## to swap only terrain in place is how scenery, enemies and checkpoints drift.
func _select_stage(which: int) -> void:
	if main != null and main.link != null and main.link.busy():
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

func _refresh_stage_buttons() -> void:
	if _stage_1_1 == null or _stage_1_2 == null:
		return
	for button in [_stage_1_1, _stage_1_2]:
		var selected: bool = int(button.get_meta("which")) == Stage.current()
		var accent: Color = button.get_meta("accent")
		var badge: Label = button.get_meta("badge")
		badge.visible = selected
		button.add_theme_stylebox_override("normal",
			_stage_style(accent if selected else Color.WHITE, 0.30 if selected else 0.94,
				18, 5 if selected else 2))
	if _local != null:
		_local.disabled = false

## Everything the player sees about the connection comes through here.
func _on_phase(phase: int, detail: String) -> void:
	if not is_instance_valid(self) or _phase_label == null:
		return
	var busy: bool = main.link.busy()
	for b in _actions:
		if is_instance_valid(b):
			b.disabled = busy
	_cancel.visible = busy
	_phase_label.text = NetLink.LABELS.get(phase, "")
	if not detail.is_empty():
		_phase_label.text += "  （%s）" % detail
	match phase:
		NetLink.Phase.DIALLING:
			_status.text = "中継サーバーにつないでいます…"
		NetLink.Phase.WAITING_PEER:
			if main.link.desired_role == "host":
				_status.text = "ルーム番号：%s\n相手にこの6桁を伝えてください。" % main.link.room_code
			elif detail.is_empty():
				_status.text = "部屋に入りました。ホストの応答を待っています…"
			else:
				_failed("このルーム番号の部屋には、まだ誰もいません。\n"
					+ "・相手が『部屋を作る』を押しているか\n"
					+ "・6桁の番号が一つも違っていないか\n"
					+ "を確かめてください（中継サーバー自体は繋がっています）")
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
	_status.text = "接続をやめました。もう一度選んでください。"

func _exit_tree() -> void:
	if main != null and is_instance_valid(main) and main.input_hub != null:
		main.input_hub.set_process_unhandled_input(true)
		main.input_hub.set_process(true)
		if main.has_method("resume_from_home"):
			var local_start: bool = fresh_run \
				and main.host_session == null and main.client_session == null
			main.resume_from_home(local_start)

func _title(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	var f := Art.font()
	if f != null:
		l.add_theme_font_override("font", f)
	return l

func _field(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
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
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color("064d92"))
	b.add_theme_stylebox_override("normal", _control_style(Color("d9f1ff"), 0.96))
	b.add_theme_stylebox_override("hover", _control_style(Color("86dcf4"), 1.0))
	b.add_theme_stylebox_override("pressed", _control_style(Color("4ecbdc"), 1.0))
	var f := Art.font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.pressed.connect(handler)
	if guarded:
		_actions.append(b)
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
func _on_versus() -> void:
	add_child(preload("res://src/ui/versus_panel.gd").new())

func _on_layout() -> void:
	add_child(LayoutEditor.new())

func _on_diagnose() -> void:
	var panel := NetDiagnostics.new()
	panel.relay = _relay.text.strip_edges()
	if panel.relay.is_empty():
		panel.relay = Balance.DEFAULT_RELAY
	add_child(panel)

## Anything that goes wrong offers the report rather than making the player go
## and find it.
func _failed(message: String) -> void:
	_status.text = message + "\n\n下の「接続診断」を押すと、原因を調べて\nコピーできる記録を出します。"

func _on_host_relay() -> void:
	var relay := _relay.text.strip_edges()
	if relay.is_empty():
		_status.text = "中継サーバーのURLを入れてください（server/signaling/README.md に立て方があります）"
		return
	# Generated here rather than typed, so two hosts cannot collide on the same
	# room. If the relay says we joined as the guest, someone already had it.
	var code := WebSocketTransport.new_code()
	_code.text = code
	var err: String = main.host_relay(relay, code)
	if err != "":
		_failed("失敗：" + err)
		return
	_save_settings(relay)
	_wait_for_handshake(main.host_session)

func _on_join_relay() -> void:
	var relay := _relay.text.strip_edges()
	var code := _code.text.strip_edges()
	if relay.is_empty():
		_status.text = "中継サーバーのURLを入れてください"
		return
	if not WebSocketTransport.valid_code(code):
		_status.text = "ルーム番号は6桁の数字で入力してください"
		return
	var err: String = main.join_relay(relay, code)
	if err != "":
		_failed("失敗：" + err)
		return
	_save_settings(relay)
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
func _load_settings() -> void:
	var saved := NetLink.recall("relay")
	if not saved.is_empty():
		_relay.text = saved

## Only the relay URL is remembered. The room code is deliberately not: it is a
## one-session password, and offering a stale one invites joining a dead room.
## Through NetLink, which owns the file. Writing it here meant writing it from
## two places, and this one used to replace the whole file with a single key --
## taking the device's own name down with it.
func _save_settings(relay: String) -> void:
	NetLink.remember("relay", relay)
