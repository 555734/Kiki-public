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
var _local: Button = null
var _phase_label: Label = null
var _cancel: Button = null
## Which page of stage cards is shown. Kept here, not in the view, so coming
## back from the play screen lands on the same page.
var _stage_page: int = 0
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

## The screens and flows this panel switches between. See src/ui/menu/.
var _select_view: StageSelectView = null
var _play_view: PlayModeView = null
var _purchase := PurchaseFlow.new(self)
## The strip across the live game that shows a host's room code. While it is
## up, _status/_phase_label/_cancel point at its widgets instead of the menu's.
var _banner: RoomBanner = null

# Read-only handles for the probes.
var _stage_view: Control:
	get: return _select_view.row if _select_view != null else null
var _stage_1_1: Button:
	get: return _card(Stage.Which.GREENFIELD)
var _stage_1_2: Button:
	get: return _card(Stage.Which.HORROR)
var _stage_1_3: Button:
	get: return _card(Stage.Which.SKYWARD_RUINS)
var _stage_1_4: Button:
	get: return _card(Stage.Which.SEA)
var _stage_1_5: Button:
	get: return _card(Stage.Which.SWAMP)
var _stage_1_6: Button:
	get: return _card(Stage.Which.DESERT)
var _stage_1_7: Button:
	get: return _card(Stage.Which.TOWER)
var _stage_1_8: Button:
	get: return _card(Stage.Which.CAVE)
var _banner_code: Label:
	get: return _banner.code_label if _banner != null else null

func _card(which: int) -> Button:
	return _select_view.cards.get(which) if _select_view != null else null

func _cards() -> Array[Dictionary]:
	return StageCards.all()

## The card data, for the star battle's stage picker as well.
static func cards() -> Array[Dictionary]:
	return StageCards.all()

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
	# _process has to stop as well as _input, and that is not belt and
	# braces. The desktop poll used to read p2_use, bound to the left mouse
	# button, and touch is emulated as a mouse -- so the single tap that picks a
	# mode was also firing the guardian's ability, spending 30 gauge and
	# dropping a platform on the runner's head before the game had started.
	# Suppressing only the touch path left that one wide open, because the
	# suppression is what kept _has_touch false and the poll running.
	if main != null and main.input_hub != null:
		main.input_hub.set_listening(false)
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

	_logo = UiKit.heading("メロスゲーム   ✦", 34, Color("0751a5"))
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
	_stage_page = StageCards.page_of(Stage.current(), StageSelectView.PER_PAGE)

	# Between stages of a kept room (CoopRoom) this is the stage list, with
	# the room on it, whatever the last screen was.
	CoopRoom.changed.connect(_on_room_changed)
	if _open_play_after_reload and not CoopRoom.holding():
		_open_play_after_reload = false
		_show_play_screen()
	else:
		_open_play_after_reload = false
		_show_stage_screen()

func _clear_screen() -> void:
	for child in _screen_host.get_children():
		child.queue_free()
	_actions.clear()
	_locked_actions.clear()
	_select_view = null
	_play_view = null
	_local = null
	_code = null
	_phase_label = null
	_status = null
	_cancel = null

## A button that starts or changes a connection: disabled while one is in
## flight. Returns it, for chaining.
func guard(button: Button) -> Button:
	_actions.append(button)
	return button

## A guarded button that stays disabled for a reason of its own.
func lock(button: Button) -> void:
	_locked_actions.append(button)
	button.disabled = true

func _show_stage_screen() -> void:
	# Coming back to the list ends the "I am going to join a friend" errand.
	# Leaving it set would quietly let a free player carry a paid stage into a
	# room of their own the next time they picked one.
	_join_only = false
	_clear_screen()
	_logo.show()
	_select_view = StageSelectView.new(self, _stage_page)
	_screen_host.add_child(_select_view)
	_refresh_stage_buttons()

func _on_leave_room() -> void:
	CoopRoom.close()

## The room ended (接続を切る, or the partner went) or moved on.
func _on_room_changed() -> void:
	if is_instance_valid(self) and not CoopRoom.holding():
		_show_stage_screen()

func _change_stage_page(direction: int) -> void:
	var destination := clampi(_stage_page + direction, 0, StageSelectView.page_count() - 1)
	if destination == _stage_page:
		return
	_stage_page = destination
	_show_stage_screen()

func _on_difficulty(value: int) -> void:
	Difficulty.set_level(value)
	if _play_view != null:
		_play_view.refresh_difficulty()

func _show_play_screen() -> void:
	_clear_screen()
	_logo.show()
	_play_view = PlayModeView.new(self)
	_screen_host.add_child(_play_view)
	_local = _play_view.local_button
	_code = _play_view.code_field
	_cancel = _play_view.cancel
	_phase_label = _play_view.phase_label
	_status = _play_view.status

	# The panel renders the connection owner's state; it does not invent a
	# second version of whether a room is connected.
	if main != null and main.link != null:
		if not main.link.phase_changed.is_connected(_on_phase):
			main.link.phase_changed.connect(_on_phase)
		_on_phase(main.link.phase, "")

## Stage buttons are selection, not launch. Rebuilding by reloading the current
## scene guarantees every stage-owned object uses the same Stage value; trying
## to swap only terrain in place is how scenery, enemies and checkpoints drift.
func _select_stage(which: int) -> void:
	if CoopRoom.holding():
		# In a kept room the host's choice starts the stage on both devices;
		# the guest's cards only show what is coming.
		if not CoopRoom.is_host:
			return
		if not Entitlement.can_play(which):
			_purchase.show(which)
			return
		CoopRoom.start_stage(which)
		return
	if main != null and main.link != null and main.link.busy():
		return
	# A stage this player has not bought does not open the play screen; it
	# opens the three doors. _join_only is what the middle door sets, and it is
	# the one way a free player gets past this line onto a paid stage.
	if not Entitlement.can_play(which) and not _join_only:
		_purchase.show(which)
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
	if _select_view != null:
		_select_view.refresh()
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
		if phase == NetLink.Phase.PLAYING:
			queue_free()
		elif not _banner.show_phase(phase):
			_close_banner()
			_failed("接続できませんでした：" + detail)
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

func _show_banner() -> void:
	if _banner != null:
		return
	_root.hide()
	# The world stays suspended; only the 3D view is allowed to run so its
	# camera lines up with the stage and there is something to look at.
	var world := main.get_node_or_null("World3D") if main != null else null
	if world != null:
		world.process_mode = Node.PROCESS_MODE_ALWAYS
	_banner = RoomBanner.new(main.link, _on_cancel)
	add_child(_banner)
	_status = _banner.status
	_phase_label = _banner.phase_label
	_cancel = _banner.cancel
	_on_phase(main.link.phase, "")

## Back to the menu, e.g. after "やめる" or a failure. Safe to call twice.
func _close_banner() -> void:
	if _banner == null:
		return
	_banner.queue_free()
	_banner = null
	var world := main.get_node_or_null("World3D") if main != null else null
	if world != null:
		world.process_mode = Node.PROCESS_MODE_INHERIT
	_root.show()
	_show_play_screen()

func _exit_tree() -> void:
	if main != null and is_instance_valid(main) and main.input_hub != null:
		main.input_hub.set_listening(true)
		main.input_hub.set_process(true)
		if main.has_method("resume_from_home"):
			var local_start: bool = fresh_run \
				and main.host_session == null and main.client_session == null
			main.resume_from_home(local_start)

## The menu's widgets live in UiKit; these stay for the screens that already
## borrow this panel's look through it (PurchasePanel, versus).
static func heading(text: String, size: int, colour: Color) -> Label:
	return UiKit.heading(text, size, colour)

static func panel_style() -> StyleBoxFlat:
	return UiKit.panel_style()

static func control_style(colour: Color, alpha: float, radius: int = 12) -> StyleBoxFlat:
	return UiKit.control_style(colour, alpha, radius)

static func action_button(text: String, handler: Callable) -> Button:
	return UiKit.action_button(text, handler)

func _on_local() -> void:
	queue_free()

# ------------------------------------------------------------------ たいせん
## The 2v2 star match. No Entitlement check on purpose: versus is free.
func _on_versus() -> void:
	_close_keyboard()
	_root.add_child(load("res://src/ui/versus_panel.gd").new())

## Hands differ and so do phones. The defaults are a guess; this is where the
## guess gets corrected.
func _on_layout() -> void:
	add_child(load("res://src/ui/layout_editor.gd").new())

## Runs every step of the connection on this device and prints what each one
## did. Offered up front rather than buried, because "つながりません" on its own
## has never been enough to tell a blocked port from a wrong URL from a Wi-Fi
## that quietly drops WebSocket upgrades.
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
	if _select_view != null and is_instance_valid(_select_view) and _root.visible:
		_select_view.handle_swipe(event)
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

