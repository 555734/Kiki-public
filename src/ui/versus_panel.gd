extends Control
## The たいせん screen: pick a seat, make a room or join one.
##
## Its own screen rather than four more rows on the start panel, which pushed
## the buttons off the bottom of a 720-tall display. Everything a player needs
## to start a four-person match is here, and none of it needs a keyboard: the
## mode began life behind command-line flags, and on a phone that is the same
## as not shipping it.
##
## It does not touch the cooperative session. Choosing a match is choosing to
## go somewhere else, and the scene change is the whole of that.

var _relay: LineEdit = null
var _code: LineEdit = null
var _seat: OptionButton = null
var _status: Label = null

func _ready() -> void:
	# ...and_offsets_, not set_anchors_preset alone. Anchors without offsets
	# leave the rect at whatever size it already had, which for a Control made
	# in code is zero -- so the CenterContainer centred inside nothing and the
	# whole screen laid itself out in the top-left corner of the start screen.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.09, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 10)
	centre.add_child(box)

	box.add_child(_title("よにんで たいせん", 30, Color(1, 1, 1)))
	box.add_child(_title("ステージは 1-1。2チームにわかれて コインを とりあいます。",
		15, Color(0.72, 0.85, 0.95)))
	box.add_child(_title("さきに %d まい あつめたチームの かち" % VersusRules.WIN_AT,
		15, Color(0.72, 0.85, 0.95)))

	box.add_child(_spacer(6))
	box.add_child(_title("あなたの せき", 15, Color(0.72, 0.85, 0.95)))
	_seat = OptionButton.new()
	_seat.add_item("Aチーム：ランナー（うごかす）", VersusRoster.SEAT_A_RUNNER)
	_seat.add_item("Aチーム：ガーディアン（たすける）", VersusRoster.SEAT_A_GUARDIAN)
	_seat.add_item("Bチーム：ランナー（うごかす）", VersusRoster.SEAT_B_RUNNER)
	_seat.add_item("Bチーム：ガーディアン（たすける）", VersusRoster.SEAT_B_GUARDIAN)
	_seat.selected = 0
	_seat.custom_minimum_size = Vector2(0, 46)
	box.add_child(_seat)

	_relay = _field("中継サーバーのURL")
	_relay.text = _remembered_relay()
	box.add_child(_relay)
	_code = _field("ルーム番号（6もじ）")
	_code.max_length = VersusWsTransport.CODE_LENGTH
	box.add_child(_code)

	box.add_child(_button("部屋を作る（あなたが Aチームのランナー）", _on_host))
	box.add_child(_button("部屋に入る", _on_join))
	box.add_child(_spacer(4))
	box.add_child(_button("1台で ためす（ランナー2人・通信なし）", _on_solo))
	box.add_child(_button("もどる", func() -> void: queue_free()))

	_status = _title("", 15, Color(0.85, 0.92, 1.0))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(600, 48)
	box.add_child(_status)

## The cooperative screen already remembers a relay; reuse it rather than
## asking the same person for the same URL twice.
func _remembered_relay() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://net.cfg") == OK:
		var kept := String(cfg.get_value("relay", "url", ""))
		if not kept.is_empty():
			return kept
	return Balance.DEFAULT_RELAY

func _on_host() -> void:
	var relay := _relay.text.strip_edges()
	if relay.is_empty():
		_status.text = "中継サーバーのURLを入れてください"
		return
	var code := VersusWsTransport.new_code()
	_code.text = code
	_status.text = "ルーム番号：%s\nこの6もじを ほかの3人に おしえてください。" % code
	_go(VersusLaunch.How.HOST, code, relay, VersusRoster.SEAT_A_RUNNER)

func _on_join() -> void:
	var relay := _relay.text.strip_edges()
	var code := _code.text.strip_edges().to_upper()
	if relay.is_empty():
		_status.text = "中継サーバーのURLを入れてください"
		return
	if not VersusWsTransport.valid_code(code):
		_status.text = "ルーム番号は 6もじです（数字と アルファベット）"
		return
	var seat: int = _seat.get_item_id(_seat.selected)
	if seat == VersusRoster.SEAT_A_RUNNER:
		# Seat 0 belongs to whoever made the room; the host is a runner's
		# device by definition, because a guardian has no body to simulate.
		_status.text = "Aチームのランナーは 部屋を作った人です。ほかのせきを えらんでください"
		return
	_go(VersusLaunch.How.JOIN, code, relay, seat)

func _on_solo() -> void:
	_go(VersusLaunch.How.SOLO, "", "", VersusRoster.SEAT_A_RUNNER)

func _go(how: int, code: String, relay: String, seat: int) -> void:
	VersusLaunch.how = how
	VersusLaunch.code = code
	VersusLaunch.relay = relay
	VersusLaunch.seat = seat
	get_tree().change_scene_to_file("res://src/versus/versus_main.tscn")

# ------------------------------------------------------------------- widgets
func _title(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label

func _field(placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 46)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return edit

func _spacer(h: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, h)
	return gap

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(handler)
	return b
