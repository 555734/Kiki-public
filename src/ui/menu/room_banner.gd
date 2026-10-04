class_name RoomBanner
extends Control
## The strip across the live game that shows a host's room code while EOS
## finishes making the room behind it. Shown the instant "部屋を作る" is
## pressed: the menu gives way to the stage itself.

var link: NetLink = null
var code_label: Label = null
var status: Label = null
var phase_label: Label = null
var cancel: Button = null

func _init(room_link: NetLink, on_cancel: Callable) -> void:
	link = room_link
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	add_child(strip)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	strip.add_child(box)
	box.add_child(UiKit.heading("ルーム番号", 16, Color("9fe3f7")))
	code_label = UiKit.heading(spaced(link.room_code), 56, Color.WHITE)
	box.add_child(code_label)
	status = UiKit.heading("準備中…", 15, Color("e8f4fb"))
	box.add_child(status)
	phase_label = UiKit.heading("", 12, Color("9fe3f7"))
	box.add_child(phase_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	cancel = UiKit.action_button("やめる", on_cancel)
	cancel.custom_minimum_size = Vector2(180, 44)
	row.add_child(cancel)

## What the strip says for each phase. Returns false when the room failed and
## the strip should go.
func show_phase(phase: int) -> bool:
	cancel.visible = true
	phase_label.text = tr(NetLink.LABELS.get(phase, ""))
	match phase:
		NetLink.Phase.DIALLING:
			status.text = tr("準備中…（番号はもう決まっています）")
		NetLink.Phase.WAITING_PEER:
			status.text = "相手にこの6桁を伝えてください。"
		NetLink.Phase.HANDSHAKING:
			status.text = "相手が来ました。ゲームを始められるか確認しています…"
		NetLink.Phase.RECONNECTING:
			status.text = "接続が切れました。つなぎ直しています…"
		NetLink.Phase.FAILED:
			return false
	return true

func _process(_delta: float) -> void:
	# The code can change once after it is shown (a rare clash with another
	# live room), so the strip reads it rather than being told.
	if link != null:
		var shown := spaced(link.room_code)
		if code_label.text != shown:
			code_label.text = shown

static func spaced(code: String) -> String:
	if code.is_empty():
		code = "------"
	var out := PackedStringArray()
	for i in code.length():
		out.append(code[i])
	return " ".join(out)
