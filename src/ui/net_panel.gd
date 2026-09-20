class_name NetPanel
extends CanvasLayer
## The screen that decides which stage and how this device is going to be used.
##
## Stage selection lives here so adding 1-2 does not replace 1-1. A fresh app
## starts on 1-1; choosing another stage reloads the current scene once so all
## terrain, enemies and scenery are rebuilt from the selected Stage data before
## the player chooses local or online play.

var main: Node2D = null

var _status: Label = null
var _relay: LineEdit = null
var _code: LineEdit = null

var _root: Control = null
var _stage_1_1: Button = null
var _stage_1_2: Button = null
var _stage_1_v: Button = null
var _local: Button = null
## Everything that starts or changes a connection. Greyed out together while an
## attempt is in flight, which is the whole of "do not let a second tap build a
## second session".
var _actions: Array[Button] = []

func _ready() -> void:
	layer = 20
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

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.06, 0.10, 0.92)
	_root.add_child(dim)

	# A CenterContainer rather than an anchor preset plus a hand-computed offset.
	# The offset version put half the panel off the left edge, which is the kind
	# of thing that only shows up once someone actually looks at the screen.
	#
	# And a ScrollContainer around it, because a phone held sideways is about
	# 720px tall. Scrolling keeps the stage picker and connection tools reachable
	# on every aspect ratio.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)

	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 8)
	centre.add_child(box)

	box.add_child(_title("SIDE / SKY", 32, Color(1, 1, 1)))
	box.add_child(_title("ステージを選んでください", 15, Color(0.72, 0.85, 0.95)))

	var stage_row := HBoxContainer.new()
	stage_row.add_theme_constant_override("separation", 10)
	_stage_1_1 = _button("", func() -> void: _select_stage(Stage.Which.GREENFIELD))
	_stage_1_2 = _button("", func() -> void: _select_stage(Stage.Which.HORROR))
	_stage_1_1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_1_2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_row.add_child(_stage_1_1)
	stage_row.add_child(_stage_1_2)
	box.add_child(stage_row)
	_stage_1_v = _button("", func() -> void: _select_stage(Stage.Which.QUIET))
	box.add_child(_stage_1_v)
	# 1-B and 1-S are built and tested but deliberately not offered here. They
	# stay reachable from code (Stage.use), from the probes, and from a build
	# that puts the buttons back -- this is a curtain, not a demolition.
	_refresh_stage_buttons()

	box.add_child(_spacer(4))
	box.add_child(_title("あそびかたを選んでください", 15, Color(0.72, 0.85, 0.95)))
	_local = _button("1台で2人であそぶ", _on_local)
	box.add_child(_local)

	box.add_child(_spacer(4))
	# One way to play apart, not three.
	box.add_child(_title("── ふたりで、はなれてあそぶ ──", 14, Color(0.55, 0.68, 0.80)))
	_relay = _field("中継サーバーのURL")
	_relay.text = Balance.DEFAULT_RELAY
	box.add_child(_relay)
	_code = _field("ルーム番号（6桁）")
	_code.max_length = WebSocketTransport.CODE_LENGTH
	_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	box.add_child(_code)
	box.add_child(_button("部屋を作る（あなたがランナー）", _on_host_relay))
	box.add_child(_button("ルーム番号で入る（あなたがガーディアン）", _on_join_relay))
	_load_settings()

	box.add_child(_spacer(6))
	# たいせん gets one button and its own screen. Everything it needs -- a
	# relay, a room code, and which of four seats you are taking -- is four
	# more controls, and putting them here pushed the buttons below the fold on
	# a 720-tall display. A mode you cannot reach without scrolling is only
	# slightly better than one you cannot reach without a keyboard.
	box.add_child(_button("よにんで たいせん（1-1）", _on_versus, false))

	box.add_child(_spacer(6))
	box.add_child(_button("ボタンの位置を変える", _on_layout, false))
	box.add_child(_button("つながらないときは → 接続診断", _on_diagnose, false))
	_cancel = _button("やめる（接続を切る）", _on_cancel, false)
	_cancel.visible = false
	box.add_child(_cancel)

	box.add_child(_spacer(6))
	_phase_label = _title("", 14, Color(0.62, 0.92, 0.72))
	box.add_child(_phase_label)
	_status = _title("", 15, Color(0.85, 0.92, 1.0))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(560, 66)
	box.add_child(_status)

	# The panel does not track the connection itself. It renders whatever the
	# one owner of that question says, so a stale label cannot outlive the fact.
	if main != null and main.link != null:
		main.link.phase_changed.connect(_on_phase)
		_on_phase(main.link.phase, "")

var _phase_label: Label = null
var _cancel: Button = null

## Stage buttons are selection, not launch. Rebuilding by reloading the current
## scene guarantees every stage-owned object uses the same Stage value; trying
## to swap only terrain in place is how scenery, enemies and checkpoints drift.
func _select_stage(which: int) -> void:
	if main != null and main.link != null and main.link.busy():
		return
	if Stage.current() == which:
		return
	Stage.use(which)
	get_tree().reload_current_scene()

func _refresh_stage_buttons() -> void:
	if _stage_1_1 == null or _stage_1_2 == null:
		return
	_stage_1_1.text = ("✓ " if Stage.current() == Stage.Which.GREENFIELD else "") \
		+ "1-1  GREENFIELD PLAINS"
	_stage_1_2.text = ("✓ " if Stage.current() == Stage.Which.HORROR else "") \
		+ "1-2  THE HOLLOW OUTSKIRTS"
	if _stage_1_v != null:
		_stage_1_v.text = ("✓ " if Stage.current() == Stage.Which.QUIET else "") \
			+ "1-V  THE QUIET　（2台専用・通話しながら）"
	# One screen means nobody to keep a secret from, and a stage built on
	# keeping one becomes a walk. Saying so on the button is kinder than
	# letting a pair play it once and wonder what it was for.
	if _local != null:
		_local.disabled = Stage.needs_two_devices()
		_local.text = "このステージは2台専用です" if Stage.needs_two_devices() \
			else "1台で2人であそぶ"

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
	return e

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

## Deliberately large: this is a phone held sideways, and the first thing anyone
## touches should not need aiming.
##
## `guarded` buttons are the ones that start a connection or switch a stage.
## They are disabled for as long as one connection attempt is running.
func _button(text: String, handler: Callable, guarded: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 18)
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