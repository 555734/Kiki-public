extends Control
## The スターたいせん screen: choose みんなで (one character each, two to
## eight people, everyone for themselves) or 2対2 (runner and guardian split
## between two people per team), then make a room or join one.
##
## Free for everyone. Nothing here -- and nothing in the match -- reads
## Entitlement: a player who has not bought the full version can make a room,
## join a room and play every part of the match (docs/versus-2v2-stars.md).
##
## Rooms are EOS lobbies found by six digits, the same way co-op rooms are, so
## there is no server address to type. The person who makes the room is team
## A's runner; everyone else picks one of the three other seats.
##
## It does not touch the cooperative session. Choosing a match is choosing to
## go somewhere else, and the scene change is the whole of that.

const JOIN_SEATS := [
	[VersusRoster.SEAT_B_RUNNER, "Bチーム：ランナー（はしって スターを とる）"],
	[VersusRoster.SEAT_A_GUARDIAN, "Aチーム：ガーディアン（足場と壁で たすける）"],
	[VersusRoster.SEAT_B_GUARDIAN, "Bチーム：ガーディアン（足場と壁で たすける）"],
]

var _code: LineEdit = null
var _seat: OptionButton = null
var _mode: OptionButton = null
var _status: Label = null
var _rules: Label = null
var _host_button: Button = null
## Only the 2v2 asks which chair; in みんなで the host hands them out.
var _team_only: Array[Control] = []

func _ready() -> void:
	# ...and_offsets_, not set_anchors_preset alone: a Control made in code has
	# zero size, and anchors without offsets would keep it that way.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.09, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 10)
	centre.add_child(box)

	box.add_child(_title("⚔  スターたいせん", 32, Color(1, 1, 1)))
	_mode = OptionButton.new()
	_mode.add_item("みんなで：ひとり1キャラの 個人戦（2〜8人）",
		VersusRoster.RoomMode.FREE_FOR_ALL)
	_mode.add_item("2対2：ランナーと ガーディアンを 2人で分担（最大4人）",
		VersusRoster.RoomMode.TEAM_SPLIT)
	_mode.selected = 0
	_mode.custom_minimum_size = Vector2(0, 52)
	_mode.add_theme_font_size_override("font_size", 18)
	_mode.item_selected.connect(func(_i: int) -> void: _update_mode())
	box.add_child(_mode)
	_rules = _title("", 16, Color(1.0, 0.85, 0.35))
	box.add_child(_rules)
	box.add_child(_title("こうげきを うけると スターを 1こ おとす。ステージは 1-1 の くさはら。",
		14, Color(0.72, 0.85, 0.95)))
	box.add_child(_title("無料版でも すべて あそべます", 14, Color(0.60, 0.92, 0.70)))

	box.add_child(_spacer(6))
	_host_button = _button("＋  部屋を作る", _on_host)
	box.add_child(_host_button)

	box.add_child(_spacer(4))
	box.add_child(_title("友達の部屋に入る", 18, Color(1, 1, 1)))
	_seat = OptionButton.new()
	_team_only.append(_seat)
	for entry in JOIN_SEATS:
		_seat.add_item(entry[1], entry[0])
	_seat.selected = 0
	_seat.custom_minimum_size = Vector2(0, 50)
	_seat.add_theme_font_size_override("font_size", 18)
	box.add_child(_seat)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_code = LineEdit.new()
	_code.placeholder_text = "ルーム番号（6けた）"
	_code.max_length = EosVersusLobby.CODE_LENGTH
	_code.custom_minimum_size = Vector2(0, 52)
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code.add_theme_font_size_override("font_size", 24)
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.text_changed.connect(_on_code_changed)
	row.add_child(_code)
	var join := _button("→  入る", _on_join)
	join.custom_minimum_size = Vector2(170, 52)
	row.add_child(join)
	box.add_child(row)

	box.add_child(_spacer(4))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	var back := _button("‹  もどる", func() -> void: queue_free())
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(back)
	var solo := _button("1台で ためす", _on_solo)
	solo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(solo)
	box.add_child(footer)

	_status = _title("", 16, Color(0.85, 0.92, 1.0))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(620, 44)
	box.add_child(_status)
	_update_mode()

func _room_mode() -> int:
	return _mode.get_item_id(_mode.selected)

func _update_mode() -> void:
	var ffa := _room_mode() == VersusRoster.RoomMode.FREE_FOR_ALL
	for c in _team_only:
		c.visible = not ffa
	if ffa:
		_rules.text = tr("ランダムに でてくる スターを さきに %d こ もった人の かち。はしって、足場と壁も じぶんで つくる") \
			% VersusRules.FFA_WIN_AT
		_host_button.text = tr("＋  部屋を作る（2〜8人）")
	else:
		_rules.text = tr("ランダムに でてくる スターを さきに %d こ もったチームの かち") \
			% VersusRules.WIN_AT
		_host_button.text = tr("＋  部屋を作る（Aチームのランナー）")

## Digits only, and never more than six: a phone's full keyboard is what most
## people get even when a number pad was asked for.
func _on_code_changed(text: String) -> void:
	var digits := ""
	for i in text.length():
		if text[i] >= "0" and text[i] <= "9":
			digits += text[i]
	digits = digits.substr(0, EosVersusLobby.CODE_LENGTH)
	if digits != text:
		_code.text = digits
		_code.caret_column = digits.length()

func _on_host() -> void:
	_go(VersusLaunch.How.HOST, EosVersusLobby.new_code(), VersusRoster.SEAT_A_RUNNER)

func _on_join() -> void:
	var code := _code.text.strip_edges()
	if not EosVersusLobby.valid_code(code):
		_status.text = tr("ルーム番号は 6けたの 数字です")
		return
	var seat := -1 if _room_mode() == VersusRoster.RoomMode.FREE_FOR_ALL \
		else _seat.get_item_id(_seat.selected)
	_go(VersusLaunch.How.JOIN, code, seat)

func _on_solo() -> void:
	_go(VersusLaunch.How.SOLO, "", VersusRoster.SEAT_A_RUNNER)

func _go(how: int, code: String, seat: int) -> void:
	VersusLaunch.how = how
	VersusLaunch.code = code
	VersusLaunch.relay = ""
	VersusLaunch.seat = seat
	VersusLaunch.room_mode = _room_mode() if how != VersusLaunch.How.SOLO \
		else VersusRoster.RoomMode.TEAM_SPLIT
	VersusLaunch.link = VersusLaunch.Link.EOS
	get_tree().change_scene_to_file("res://src/versus/versus_main.tscn")

# ------------------------------------------------------------------- widgets
func _title(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label

func _spacer(h: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, h)
	return gap

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(handler)
	return b
