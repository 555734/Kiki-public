extends Control
## The スターたいせん screen, in two steps like the stage screen:
##
##   1. あそびかた -- two big picture cards, みんなで (one character each, two to
##      eight people, everyone for themselves) and 2対2 (runner and guardian
##      split between two people per team), with the rules in one line each.
##   2. へや -- the arena's stage as cards, and a panel to make a room or join
##      one by its six digits (2対2 also asks which chair).
##
## Free for everyone. Nothing here -- and nothing in the match -- reads the
## purchase state: a player who has not bought the full version can make a
## room, join a room and play every part of the match
## (docs/versus-2v2-stars.md).
##
## Rooms are EOS lobbies found by six digits, the same way co-op rooms are, so
## there is no server address to type. It does not touch the cooperative
## session: choosing a match is choosing to go somewhere else, and the scene
## change is the whole of that.

const JOIN_SEATS := [
	[VersusRoster.SEAT_B_RUNNER, "Bチーム", "ランナー", "はしって スターを とる"],
	[VersusRoster.SEAT_A_GUARDIAN, "Aチーム", "ガーディアン", "射撃で たすける"],
	[VersusRoster.SEAT_B_GUARDIAN, "Bチーム", "ガーディアン", "射撃で たすける"],
]

const NAVY := Color("073f89")
const INK := Color("23476b")
const GOLD := Color("ffcf4a")
const EMBER := Color("ff7a2f")
const TEAM_A := Color("4fc3ff")
const TEAM_B := Color("ff9b4a")

const MODES := [
	{"mode": VersusRoster.RoomMode.FREE_FOR_ALL, "name": "みんなで",
		"who": "ひとり1キャラの 個人戦・2〜8人",
		"art": preload("res://assets/menu/versus_ffa.png"), "accent": Color("ffcf4a")},
	{"mode": VersusRoster.RoomMode.TEAM_SPLIT, "name": "2対2",
		"who": "ランナーと ガーディアンを 2人で分担・最大4人",
		"art": preload("res://assets/menu/versus_team.png"), "accent": Color("4fc3ff")},
]

var _mode_id: int = VersusRoster.RoomMode.FREE_FOR_ALL
var _stage_id: int = VersusStageData.DEFAULT_THEME
var _seat_id: int = VersusRoster.SEAT_B_RUNNER

var _content: MarginContainer = null
var _back: Button = null
var _subtitle: Label = null
var _backdrop: TextureRect = null
var _time: float = 0.0
## 1: あそびかた, 2: へや.
var _step: int = 1

## Step 2's widgets. `_seat` is the 2v2 chair picker -- みんなで has none, the
## host hands chairs out.
var _code: LineEdit = null
var _seat: Control = null
var _seat_buttons: Array[Button] = []
var _stage_cards: Array[Button] = []
var _status: Label = null
var _rules: Label = null
var _host_button: Button = null

func _ready() -> void:
	# ...and_offsets_, not set_anchors_preset alone: a Control made in code has
	# zero size, and anchors without offsets would keep it that way.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Over the stage screen's logo (z 5), which it is opened on top of.
	z_index = 10
	_build_backdrop()

	_back = _pill("‹  もどる", _on_back)
	_back.position = Vector2(28, 22)
	_back.size = Vector2(170, 50)
	add_child(_back)

	var title := _label("⚔  スターたいせん", 40, Color.WHITE)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 14
	title.offset_bottom = 66
	title.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.20, 0.9))
	title.add_theme_constant_override("outline_size", 10)
	add_child(title)
	_subtitle = _label("", 18, Color(1.0, 0.93, 0.78))
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_subtitle.offset_left = 220
	_subtitle.offset_right = -220
	_subtitle.offset_top = 66
	_subtitle.offset_bottom = 94
	_subtitle.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.20, 0.85))
	_subtitle.add_theme_constant_override("outline_size", 6)
	add_child(_subtitle)

	_content = MarginContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_theme_constant_override("margin_left", 40)
	_content.add_theme_constant_override("margin_right", 40)
	_content.add_theme_constant_override("margin_top", 108)
	_content.add_theme_constant_override("margin_bottom", 24)
	add_child(_content)
	_show_modes()

# ---------------------------------------------------------------- background
## The dusk sky over the cloud sea, drifting slowly, under a wash that keeps
## writing readable and a few motes of starlight rising through it.
func _build_backdrop() -> void:
	var base := ColorRect.new()
	base.color = Color("0b1530")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	_backdrop = TextureRect.new()
	_backdrop.texture = preload("res://assets/sky/panorama.jpg")
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.offset_left = -70
	_backdrop.offset_right = 70
	_backdrop.offset_top = -20
	_backdrop.offset_bottom = 20
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	var wash := TextureRect.new()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.03, 0.07, 0.20, 0.62))
	ramp.add_point(0.30, Color(0.05, 0.08, 0.20, 0.18))
	ramp.add_point(0.62, Color(0.10, 0.06, 0.14, 0.22))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.03, 0.04, 0.12, 0.80))
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	wash.texture = tex
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	var motes := Motes.new()
	motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(motes)

func _process(delta: float) -> void:
	_time += delta
	if _backdrop != null:
		_backdrop.position.x = -70.0 + sin(_time * 0.06) * 60.0

## Small four-pointed sparks drifting up and twinkling. Thirty of them, so
## they cost nothing; redrawn at most thirty times a second.
class Motes extends Control:
	var _seeds: Array = []
	var _t: float = 0.0
	var _since: float = 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 30:
			_seeds.append([rng.randf(), rng.randf(), rng.randf_range(0.6, 1.8),
				rng.randf_range(6.0, 16.0), rng.randf() * TAU])

	func _process(delta: float) -> void:
		_t += delta
		_since += delta
		if _since >= 1.0 / 30.0:
			_since = 0.0
			queue_redraw()

	func _draw() -> void:
		var view := size
		for s in _seeds:
			var y: float = fposmod(float(s[1]) * view.y - _t * float(s[3]), view.y + 40.0) - 20.0
			var x: float = float(s[0]) * view.x + sin(_t * 0.4 + float(s[4])) * 14.0
			var a: float = 0.25 + 0.55 * (0.5 + 0.5 * sin(_t * 2.0 + float(s[4])))
			var r: float = float(s[2]) * 2.2
			var c := Color(1.0, 0.92, 0.70, a)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y - r * 2.0), Vector2(x + r * 0.45, y - r * 0.45),
				Vector2(x + r * 2.0, y), Vector2(x + r * 0.45, y + r * 0.45),
				Vector2(x, y + r * 2.0), Vector2(x - r * 0.45, y + r * 0.45),
				Vector2(x - r * 2.0, y), Vector2(x - r * 0.45, y - r * 0.45)]), c)

# ------------------------------------------------------------ step 1: mode
func _show_modes() -> void:
	_clear()
	_step = 1
	_back.text = tr("‹  もどる")
	_subtitle.text = tr("スターを あつめて かて！  無料版でも すべて あそべます")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_content.add_child(box)
	box.add_child(_label("あそびかたを えらんでください", 22, Color.WHITE, true))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 28)
	box.add_child(row)
	for info in MODES:
		row.add_child(_mode_card(info))
	# A flow, not a row: in English the four of them are wider than a phone.
	var chips := HFlowContainer.new()
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", 12)
	chips.add_theme_constant_override("v_separation", 8)
	box.add_child(chips)
	for text in ["★ 射撃・踏みつけで 当てると スターを 1こ おとす",
			"ぶつかると ふたりとも おとす", "てきは ふむか うつと たおせる"]:
		chips.add_child(_chip(text))
	var solo := _pill("1台で ためす", _on_solo)
	solo.custom_minimum_size = Vector2(190, 46)
	chips.add_child(solo)

func _mode_card(info: Dictionary) -> Button:
	var accent: Color = info["accent"]
	var card := Button.new()
	card.name = "Mode%d" % int(info["mode"])
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 380)
	card.clip_contents = true
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", _frame(Color.WHITE, 0.92, 22, 3))
	card.add_theme_stylebox_override("hover", _frame(accent, 0.95, 22, 5))
	card.add_theme_stylebox_override("pressed", _frame(accent, 1.0, 22, 6))
	card.pressed.connect(func() -> void: _choose_mode(int(info["mode"])))
	var art := TextureRect.new()
	art.texture = info["art"]
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 6
	art.offset_top = 6
	art.offset_right = -6
	art.offset_bottom = -6
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)
	card.add_child(_ramp(170))
	var caption := VBoxContainer.new()
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 26
	caption.offset_right = -26
	caption.offset_top = -150
	caption.offset_bottom = -20
	caption.alignment = BoxContainer.ALIGNMENT_END
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(String(info["name"]), 44, accent)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.12, 0.95))
	name_label.add_theme_constant_override("outline_size", 10)
	caption.add_child(name_label)
	var who := _label(String(info["who"]), 20, Color.WHITE)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.add_child(who)
	var rule := _label(_win_line(int(info["mode"])), 17, Color(1.0, 0.88, 0.55))
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.add_child(rule)
	card.add_child(caption)
	var go := _label("えらぶ  ›", 20, Color.WHITE)
	go.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	go.offset_left = -170
	go.offset_right = -20
	go.offset_top = 18
	go.offset_bottom = 56
	go.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.12, 0.9))
	go.add_theme_constant_override("outline_size", 7)
	go.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(go)
	return card

func _win_line(mode: int) -> String:
	if mode == VersusRoster.RoomMode.FREE_FOR_ALL:
		return tr("★ を さきに %d こ もった人の かち") % VersusRules.FFA_WIN_AT
	return tr("★ を さきに %d こ もったチームの かち") % VersusRules.WIN_AT

func _choose_mode(mode: int) -> void:
	_mode_id = mode
	_show_room()

# ------------------------------------------------------------ step 2: room
func _show_room() -> void:
	_clear()
	_step = 2
	_back.text = tr("‹  あそびかた")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	_content.add_child(row)

	# The arena's stage, as the stage screen shows stages.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	left.add_child(_label("ステージ", 24, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT))
	left.add_child(_label("部屋を作る人が えらびます。入る人は 作った人の ステージに なります",
		16, Color(0.86, 0.92, 1.0), false, HORIZONTAL_ALIGNMENT_LEFT))
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 12)
	left.add_child(cards)
	_stage_cards.clear()
	var all := NetPanel.cards()
	all.push_front({"which": Stage.Which.ROYAL_ARENA, "number": "VS",
		"accent": Color("f8c94b"), "crop_top": 140.0,
		"art": preload("res://assets/versus/royal/background/royal_sky_kingdom.png")})
	for which in VersusStageData.THEMES:
		for info in all:
			if int(info["which"]) == which:
				var card := _stage_card(info)
				cards.add_child(card)
				_stage_cards.append(card)
	_refresh_stage_cards()
	_rules = _label("", 17, Color(1.0, 0.88, 0.55), false, HORIZONTAL_ALIGNMENT_LEFT)
	left.add_child(_rules)

	# Make or join.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var plate := NetPanel.panel_style()
	plate.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", plate)
	row.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var mode_info: Dictionary = MODES[0] if _mode_id == VersusRoster.RoomMode.FREE_FOR_ALL else MODES[1]
	var heading := _label(String(mode_info["name"]), 30, NAVY, true)
	box.add_child(heading)
	box.add_child(_label(String(mode_info["who"]), 16, INK))
	_host_button = _primary("", _on_host)
	box.add_child(_host_button)
	box.add_child(_divider("または"))
	box.add_child(_label("友達の部屋に入る", 20, NAVY, true))
	_seat = _seat_picker()
	box.add_child(_seat)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	_code = LineEdit.new()
	_code.placeholder_text = tr("ルーム番号（6けた）")
	_code.max_length = EosVersusLobby.CODE_LENGTH
	_code.custom_minimum_size = Vector2(0, 56)
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code.add_theme_font_size_override("font_size", 20)
	_code.add_theme_color_override("font_color", NAVY)
	_code.add_theme_color_override("font_placeholder_color", Color("7f9bb5"))
	_code.add_theme_stylebox_override("normal", NetPanel.control_style(Color("eef8ff"), 1.0))
	_code.add_theme_stylebox_override("focus", NetPanel.control_style(Color("bfe9fb"), 1.0))
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.text_changed.connect(_on_code_changed)
	join_row.add_child(_code)
	var join := NetPanel.action_button("→  入る", _on_join)
	join.custom_minimum_size = Vector2(112, 56)
	join_row.add_child(join)
	box.add_child(join_row)
	_status = _label("", 16, Color("b8420f"))
	_status.custom_minimum_size = Vector2(0, 24)
	box.add_child(_status)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(filler)
	box.add_child(_steps())
	_update_mode()

## How a room comes together, in three lines, at the foot of the panel.
func _steps() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label("すすめかた", 16, NAVY, true, HORIZONTAL_ALIGNMENT_LEFT))
	for line in ["① 部屋を作ると 6けたの 番号が でます",
			"② 友達は その番号を 入れて 入ります",
			"③ そろったら 作った人が スタート"]:
		box.add_child(_label(line, 15, INK, false, HORIZONTAL_ALIGNMENT_LEFT))
	return box

func _stage_card(info: Dictionary) -> Button:
	var which: int = int(info["which"])
	var accent: Color = info["accent"]
	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 300)
	card.clip_contents = true
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(func() -> void:
		_stage_id = which
		_refresh_stage_cards())
	var art := TextureRect.new()
	var source: Texture2D = info["art"]
	var crop := AtlasTexture.new()
	crop.atlas = source
	var top := maxf(0.0, float(info["crop_top"]) - 140.0)
	crop.region = Rect2(0.0, top, float(source.get_width()),
		minf(620.0, float(source.get_height()) - top))
	art.texture = crop
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 5
	art.offset_top = 5
	art.offset_right = -5
	art.offset_bottom = -5
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)
	card.add_child(_ramp(120))
	var caption := VBoxContainer.new()
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 10
	caption.offset_right = -10
	caption.offset_top = -96
	caption.offset_bottom = -10
	caption.alignment = BoxContainer.ALIGNMENT_END
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number := _label(String(info["number"]), 24, accent)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	number.add_theme_color_override("font_outline_color", Color(0, 0.06, 0.12, 0.9))
	number.add_theme_constant_override("outline_size", 6)
	caption.add_child(number)
	var full := tr(VersusStageData.theme_label(which))
	var name_label := _label(full.substr(full.find(" ") + 1), 15, Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_child(name_label)
	card.add_child(caption)
	var tick := _label("✓", 30, accent)
	tick.name = "Tick"
	tick.position = Vector2(12, 6)
	tick.size = Vector2(60, 44)
	tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tick.add_theme_color_override("font_outline_color", Color.WHITE)
	tick.add_theme_constant_override("outline_size", 7)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tick)
	card.set_meta("which", which)
	card.set_meta("accent", accent)
	return card

func _refresh_stage_cards() -> void:
	for card in _stage_cards:
		var chosen: bool = int(card.get_meta("which")) == _stage_id
		var accent: Color = card.get_meta("accent")
		card.add_theme_stylebox_override("normal",
			_frame(accent if chosen else Color.WHITE, 1.0 if chosen else 0.85, 16, 5 if chosen else 2))
		card.add_theme_stylebox_override("hover", _frame(accent, 0.9, 16, 4))
		card.add_theme_stylebox_override("pressed", _frame(accent, 1.0, 16, 5))
		(card.get_node("Tick") as Label).visible = chosen

## 2v2's three free chairs, as three big buttons in their team's colour.
func _seat_picker() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_label("入る席", 16, INK, false, HORIZONTAL_ALIGNMENT_LEFT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_seat_buttons.clear()
	var group := ButtonGroup.new()
	for entry in JOIN_SEATS:
		var seat: int = entry[0]
		var colour: Color = TEAM_B if String(entry[1]) == "Bチーム" else TEAM_A
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 66)
		b.text = "%s\n%s" % [tr(String(entry[1])), tr(String(entry[2]))]
		b.tooltip_text = tr(String(entry[3]))
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", NAVY)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		b.add_theme_stylebox_override("normal", NetPanel.control_style(colour, 0.20))
		b.add_theme_stylebox_override("hover", NetPanel.control_style(colour, 0.38))
		b.add_theme_stylebox_override("pressed", NetPanel.control_style(colour, 0.95))
		b.add_theme_stylebox_override("hover_pressed", NetPanel.control_style(colour, 1.0))
		b.button_pressed = seat == _seat_id
		b.pressed.connect(func() -> void: _seat_id = seat)
		b.set_meta("seat", seat)
		row.add_child(b)
		_seat_buttons.append(b)
	return box

func _room_mode() -> int:
	return _mode_id

func _update_mode() -> void:
	var ffa := _room_mode() == VersusRoster.RoomMode.FREE_FOR_ALL
	_subtitle.text = tr("みんなで：ひとり1キャラの 個人戦（2〜8人）") if ffa \
		else tr("2対2：ランナーと ガーディアンを 2人で分担（最大4人）")
	if _seat != null:
		_seat.visible = not ffa
	if _rules != null:
		_rules.text = (tr("ランダムに でてくる スターを さきに %d こ もった人の かち。スターは いつも 1こだけ") \
			% VersusRules.FFA_WIN_AT) if ffa \
			else (tr("ランダムに でてくる スターを さきに %d こ もったチームの かち") % VersusRules.WIN_AT)
	if _host_button != null:
		_host_button.text = tr("＋  部屋を作る（2〜8人）") if ffa \
			else tr("＋  部屋を作る（Aチームのランナー）")

func _on_back() -> void:
	if _step == 2:
		_show_modes()
	else:
		queue_free()

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
	var seat := -1 if _room_mode() == VersusRoster.RoomMode.FREE_FOR_ALL else _seat_id
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
	# A guest paints whatever the host chose; the WELCOME says which.
	VersusLaunch.stage = _stage_id if how != VersusLaunch.How.JOIN else VersusStageData.DEFAULT_THEME
	get_tree().change_scene_to_file("res://src/versus/versus_main.tscn")

# ------------------------------------------------------------------- widgets
func _clear() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_seat = null
	_code = null
	_stage_cards.clear()
	_rules = null
	_host_button = null
	_status = null

func _label(text: String, size: int, colour: Color, bold: bool = false,
		align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = tr(text)
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	var f := Art.font()
	if f != null:
		label.add_theme_font_override("font", f)
	if bold:
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _chip(text: String) -> Label:
	var chip := _label(text, 16, Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.20, 0.62)
	style.border_color = Color(1.0, 0.85, 0.45, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(20)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	chip.add_theme_stylebox_override("normal", style)
	chip.autowrap_mode = TextServer.AUTOWRAP_OFF
	return chip

func _pill(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = tr(text)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	for state in [["normal", 0.55], ["hover", 0.75], ["pressed", 0.9]]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.09, 0.22, float(state[1]))
		style.border_color = Color(1, 1, 1, 0.55)
		style.set_border_width_all(2)
		style.set_corner_radius_all(24)
		style.content_margin_left = 18
		style.content_margin_right = 18
		b.add_theme_stylebox_override(String(state[0]), style)
	var f := Art.font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.pressed.connect(handler)
	return b

func _primary(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = tr(text)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in [["normal", EMBER], ["hover", EMBER.lightened(0.12)],
			["pressed", EMBER.darkened(0.12)]]:
		var style := StyleBoxFlat.new()
		style.bg_color = state[1]
		style.border_color = Color(1.0, 0.86, 0.55)
		style.set_border_width_all(2)
		style.set_corner_radius_all(16)
		style.shadow_color = Color(0.55, 0.20, 0.0, 0.35)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(String(state[0]), style)
	var f := Art.font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.pressed.connect(handler)
	return b

func _divider(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in 3:
		if i == 1:
			var word := _label(text, 15, Color("6a8aa8"))
			word.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(word)
			continue
		var line := HSeparator.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)
	return row

func _frame(colour: Color, alpha: float, radius: int, border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colour.r, colour.g, colour.b, alpha)
	style.border_color = colour.lightened(0.2)
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.05, 0.40)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 5)
	return style

## A dark fade up from the bottom of a card, for writing over its picture.
func _ramp(height: int) -> TextureRect:
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.05, 0.12, 0.0))
	g.set_color(1, Color(0.02, 0.05, 0.12, 0.88))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -height
	shade.offset_left = 6
	shade.offset_right = -6
	shade.offset_bottom = -6
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade
