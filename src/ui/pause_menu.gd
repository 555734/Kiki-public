class_name PauseMenu
extends CanvasLayer
## The in-game menu behind the ≡ button: carry on, or go back to the home
## screen (stage select).
##
## App Review rejected 0.9.0 for having no way back to home once a stage had
## started -- the only exit was clearing the stage. This is that way back, on
## every stage, in every seat, on touch and with a mouse.
##
## Offline the world stands still while it is open, the same way it does
## behind the home screen (Main.suspend_for_home). Online it cannot: the other
## device is still playing, so the menu only covers this screen and leaving
## ends the session for both, exactly as the clear screen's button does.
##
## The look is NetPanel's, for the same reason PurchasePanel's is.

signal closed

var main: Node = null

var _paused_world: bool = false

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.06, 0.12, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 0)
	card.add_theme_stylebox_override("panel", NetPanel.panel_style())
	centre.add_child(card)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 26)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	box.add_child(NetPanel.heading("メニュー", 28, Color("073f89")))
	box.add_child(NetPanel.heading("%s  %s" % [Stage.stage_number(),
		TranslationServer.translate(Stage.stage_name())], 18, Color("37638d")))

	var resume := NetPanel.action_button("▶  ゲームに戻る", close)
	resume.name = "Resume"
	box.add_child(resume)
	var home := NetPanel.action_button("⌂  ホームに戻る（ステージ選択）", go_home)
	home.name = "Home"
	box.add_child(home)
	if _online():
		var note := NetPanel.heading("オンライン中は一時停止しません。\nホームに戻ると接続が終わります。",
			16, Color("416b91"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(note)

	_pause_world()

func _online() -> bool:
	return main != null and is_instance_valid(main) \
		and (main.get("host_session") != null or main.get("client_session") != null)

func _pause_world() -> void:
	if main == null or not is_instance_valid(main):
		return
	if main.input_hub != null:
		main.input_hub.release_everything()
	if _online() or not main.has_method("suspend_for_home"):
		return
	main.suspend_for_home()
	_paused_world = true

func close() -> void:
	if _paused_world and main != null and is_instance_valid(main):
		main.resume_from_home(false)
	_paused_world = false
	closed.emit()
	queue_free()

## Back to the stage list. Reloading the scene is exactly how the clear screen
## does it, and gives the same start state as a fresh launch; any live session
## is closed first so the other device is told rather than left waiting.
func go_home() -> void:
	_paused_world = false
	if main != null and is_instance_valid(main) and main.has_method("_end_any_session"):
		main.call("_end_any_session")
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
