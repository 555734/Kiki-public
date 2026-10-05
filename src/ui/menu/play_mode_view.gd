class_name PlayModeView
extends VBoxContainer
## The second screen of the start menu: the chosen stage, the chasers' speed,
## and how to play it -- on this device, or online by room code.
##
## Builds the widgets; NetPanel owns what pressing them does and what the
## connection says on them.

var panel = null
var local_button: Button = null
var host_button: Button = null
var code_field: LineEdit = null
var cancel: Button = null
var phase_label: Label = null
var status: Label = null
var _difficulty_buttons: Array[Button] = []

func _init(owner_panel) -> void:
	panel = owner_panel
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	add_child(UiKit.heading("—  遊び方を選択  —", 28, Color("073f89")))
	add_child(UiKit.heading("一緒に遊ぶ方法を選んでください", 19, Color("37638d")))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	var preview := _stage_preview()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview)
	left.add_child(_difficulty_panel())
	body.add_child(left)

	var play_card := PanelContainer.new()
	play_card.custom_minimum_size = Vector2(570, 0)
	play_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_card.add_theme_stylebox_override("panel", UiKit.panel_style())
	body.add_child(play_card)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	play_card.add_child(margin)
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	margin.add_child(choices)

	choices.add_child(UiKit.heading("この1台で一緒に遊ぶ", 20, Color("073f89")))
	local_button = panel.guard(UiKit.action_button("▶  この1台で 2人プレイを始める", panel._on_local))
	local_button.custom_minimum_size.y = 54
	choices.add_child(local_button)
	choices.add_child(UiKit.heading("オンラインで離れて遊ぶ", 20, Color("073f89")))
	code_field = UiKit.field("ルーム番号（6桁）")
	code_field.max_length = EosCoopLobby.CODE_LENGTH
	code_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	# The iOS number pad has no return key, so a finished code closes the
	# keyboard by itself instead of trapping the player behind it.
	code_field.text_changed.connect(panel._on_code_changed)
	code_field.text_submitted.connect(func(_t: String) -> void: panel._on_join_eos())
	choices.add_child(code_field)
	var online_row := HBoxContainer.new()
	online_row.add_theme_constant_override("separation", 10)
	host_button = panel.guard(UiKit.action_button("＋  部屋を作る", panel._on_host_eos))
	var join: Button = panel.guard(UiKit.action_button("→  ルームに入る", panel._on_join_eos))
	host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	online_row.add_child(host_button)
	online_row.add_child(join)
	choices.add_child(online_row)

	# A free player who came here through "購入済みの友達と遊ぶ" may dial a room
	# and may not make one. Both halves are disabled rather than hidden: the
	# player needs to see that the buttons exist and why they are not theirs to
	# press yet, or the screen just looks broken.
	if not Entitlement.can_host(Stage.current()):
		panel.lock(local_button)
		panel.lock(host_button)
		choices.add_child(UiKit.heading(
			"このステージは完全版です。完全版を持っている友達に部屋を作ってもらい、\n"
			+ "その6桁を入れて「ルームに入る」を押してください。", 18, Color("416b91")))

	cancel = UiKit.action_button("接続をやめる", panel._on_cancel)
	cancel.visible = false
	choices.add_child(cancel)
	phase_label = UiKit.heading("", 18, Color("08796e"))
	choices.add_child(phase_label)
	status = UiKit.heading("", 18, Color("264c70"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 44
	choices.add_child(status)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.add_child(UiKit.action_button("‹  もどる", panel._show_stage_screen))
	# Versus has its own entry on the stage screen (EOS, free for everyone).
	footer.add_child(UiKit.action_button("ボタン配置", panel._on_layout))
	if OS.has_feature("editor"):
		footer.add_child(UiKit.action_button("接続記録", panel._on_diagnose))
	add_child(footer)

## 追跡者の速さ. HARD is the speed the stages were tuned at.
##
## This lives on the play screen rather than the stage screen because the
## question it answers is "how hard is THIS stage going to be", and there is
## no this-stage until one is chosen. It also reads live -- the chasers ask
## `Difficulty.chase_scale()` every frame, and the host's value is the one put
## on the room -- so setting it here, after the stage is picked and before the
## room is made, is the last moment at which it can be set at all.
func _difficulty_panel() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(UiKit.heading("追跡者の速さ", 21, Color("073f89")))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_difficulty_buttons.clear()
	for i in Difficulty.LABELS.size():
		var b := UiKit.action_button(tr(Difficulty.LABELS[i]), panel._on_difficulty.bind(i))
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		_difficulty_buttons.append(b)
	box.add_child(row)
	box.add_child(UiKit.heading("追いかけてくる敵だけが速くなります", 16, Color("416b91")))
	refresh_difficulty()
	return box

func refresh_difficulty() -> void:
	for i in _difficulty_buttons.size():
		var b := _difficulty_buttons[i]
		if not is_instance_valid(b):
			continue
		var on := i == Difficulty.current()
		b.add_theme_stylebox_override("normal",
			UiKit.control_style(Color("35b7ec") if on else Color("d9f1ff"), 1.0 if on else 0.96))
		b.add_theme_color_override("font_color", Color.WHITE if on else Color("064d92"))

func _stage_preview() -> PanelContainer:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(0, 240)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.clip_contents = true
	var stage_info := StageCards.current()
	var accent: Color = stage_info["accent"]
	preview.add_theme_stylebox_override("panel", UiKit.stage_style(accent, 0.96, 18, 3))
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
	layer.add_child(UiKit.scrim(108, false))
	var label := UiKit.heading(tr("選択中  %s\n%s") % [stage_info["number"], tr(String(stage_info["name"]))],
		22, Color.WHITE)
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -74
	label.offset_bottom = -10
	label.add_theme_color_override("font_outline_color", Color("07325f"))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	return preview
